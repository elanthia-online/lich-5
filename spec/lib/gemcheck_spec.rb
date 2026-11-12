# spec/lib/gemcheck_spec.rb
require 'tmpdir'
require 'fileutils'
require 'benchmark'

# TEMP_DIR is referenced by GemCheck#write_log; it must exist before that
# method runs. Constants are resolved at call time (not require time),
# so defining it here in the spec is sufficient.
unless defined?(TEMP_DIR)
  TEMP_DIR = Dir.mktmpdir('lich-gemcheck-spec')
  RSpec.configure do |config|
    config.after(:suite) { FileUtils.remove_entry(TEMP_DIR) if Dir.exist?(TEMP_DIR) }
  end
end

require_relative '../../lib/gemcheck'

RSpec.describe Lich::GemCheck do
  # Declaration-provider seam: these unit tests never evaluate a Gemfile or
  # load Bundler. CI separately runs the real Bundler/RubyGems fixture lane.
  let(:bundler) { double('declaration provider', default_gemfile: 'Gemfile', default_lockfile: 'Gemfile.lock', definition: double('default declarations', groups: [:default], current_dependencies: [])) }
  before { allow(described_class).to receive(:bundler).and_return(bundler) }

  describe '.startup_groups' do
    it 'checks default and GTK dependencies for a Windows graphical launch' do
      allow(described_class).to receive(:self_healing_supported?).and_return(true)
      expect(described_class.startup_groups([])).to eq(%i[default gtk])
    end

    it 'omits GTK for an explicit no-GUI switch on Windows' do
      allow(described_class).to receive(:self_healing_supported?).and_return(true)
      expect(described_class.startup_groups(['--no-gui'])).to eq([:default])
      expect(described_class.startup_groups(['--no-gtk'])).to eq([:default])
    end

    it 'does not treat unrelated arguments as a headless request on Windows' do
      allow(described_class).to receive(:self_healing_supported?).and_return(true)
      expect(described_class.startup_groups(['--home=C:/Lich5'])).to eq(%i[default gtk])
    end

    it 'leaves GTK to init.rb on non-Windows platforms' do
      allow(described_class).to receive(:self_healing_supported?).and_return(false)
      expect(described_class.startup_groups([])).to eq([:default])
      expect(described_class.startup_groups(['--gtk'])).to eq([:default])
    end
  end

  describe '.verify!' do
    before do
      allow(described_class).to receive(:configure_gemfile!)
      allow(described_class).to receive(:self_healing_supported?).and_return(false)
      allow(described_class).to receive(:bundler_recovery_supported?).and_return(false)
      allow(described_class).to receive(:alert)
    end

    it 'retains the non-Windows presence check without a manifest fetch' do
      allow(described_class).to receive(:missing_gems).with([:default]).and_return([])
      expect(Lich::DependencyRecovery).not_to receive(:new)
      expect(bundler).not_to receive(:setup)
      expect(described_class).not_to receive(:alert)
      expect { described_class.verify! }.not_to raise_error
    end

    it 'retains the non-Windows missing-gem alert and failure exit' do
      allow(described_class).to receive(:missing_gems).and_return(['ox'])
      expect(described_class).to receive(:alert).with(missing: ['ox'], groups: [:default])
      expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    end

    it 'retains consented macOS Bundler recovery for default gems' do
      allow(described_class).to receive(:missing_gems).and_return(['ox'])
      allow(described_class).to receive(:bundler_recovery_supported?).and_return(true)
      result = Lich::BundlerRecovery::Result.new(log_path: '/tmp/fixture', restart_required: true)
      expect(described_class).to receive(:recover_with_bundler_consent!).with(['ox'], groups: [:default]).and_return(result)
      expect(described_class).to receive(:write_bundler_recovery_log)
      expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
    end

    {
      'a macOS Bundler preflight refusal'   => 'Xcode Command Line Tools are required to build native Ruby gems',
      'a failed macOS Bundler installation' => 'Bundler install failed (see fixture log)'
    }.each do |scenario, reason|
      it "preserves the missing gems and original reason for #{scenario}" do
        allow(described_class).to receive(:missing_gems).and_return(['sqlite3'])
        allow(described_class).to receive(:bundler_recovery_supported?).and_return(true)
        result = Lich::BundlerRecovery::Result.new(error: reason)
        expect(described_class).to receive(:recover_with_bundler_consent!).with(['sqlite3'], groups: [:default]).and_return(result)
        expect(Lich::DependencyRecovery).not_to receive(:new)
        expect(described_class).to receive(:alert) do |args|
          expect(args.fetch(:missing)).to eq(['sqlite3'])
          expect(args.fetch(:groups)).to eq([:default])
          expect(args.fetch(:error)).to be_an_instance_of(Lich::DependencyRecovery::Error)
          expect(args.fetch(:error).message).to eq(reason)
        end
        expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end
    end

    context 'Windows accepted versions' do
      let(:dependencies) { [Gem::Dependency.new('sqlite3')] }
      let(:recovery) { instance_double(Lich::DependencyRecovery) }
      let(:policy) { instance_double(Lich::AcceptedGemPolicy) }
      let(:units) { [{ 'id' => 'sqlite3', 'members' => ['sqlite3'] }] }
      let(:plan) { Lich::DependencyRecovery::Plan.new(units: units) }
      let(:check) { Lich::AcceptedGemPolicy::Check.new(plan: plan, needed: [], specs: []) }

      before do
        allow(described_class).to receive(:self_healing_supported?).and_return(true)
        allow(described_class).to receive(:required_dependencies).and_return(dependencies)
        allow(Lich::DependencyRecovery).to receive(:new).and_return(recovery)
        allow(Lich::AcceptedGemPolicy).to receive(:new).with(recovery: recovery).and_return(policy)
        allow(policy).to receive(:check).with(dependencies).and_return(check)
        allow(policy).to receive(:activate!).with(check).and_return(true)
        allow(described_class).to receive(:recovery_units_approved?).and_return(true)
        allow(described_class).to receive(:write_recovery_log)
      end

      it 'always evaluates and activates accepted versions even if no gem is missing' do
        expect(described_class).not_to receive(:missing_gems)
        expect(policy).to receive(:check).with(dependencies).and_return(check)
        expect(policy).to receive(:activate!).with(check)
        expect(bundler).not_to receive(:setup)
        expect { described_class.verify! }.not_to raise_error
      end

      it 'uses requested groups when reading required declarations' do
        expect(described_class).to receive(:required_dependencies).with(%i[default gtk]).and_return(dependencies)
        described_class.verify!(:default, :gtk)
      end

      it 'requires consent and forces the complete planned repair before restarting' do
        check.needed = ['sqlite3']
        expect(described_class).to receive(:recovery_units_approved?).with(units, [:default]).and_return(true)
        expect(recovery).to receive(:recover).with(['sqlite3'], force: true, plan: plan, restart: true, preserve_newer: true)
                                             .and_return(Lich::DependencyRecovery::Result.new(installed_gems: [], restart_required: true))
        expect(policy).not_to receive(:activate!)
        expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
      end

      it 'preserves the staging timeout type through Windows startup failure reporting' do
        check.needed = ['sqlite3']
        allow(recovery).to receive(:recover).and_return(Lich::DependencyRecovery::Result.new(installed_gems: [], error: 'staging timed out', error_kind: :timeout))
        expect(described_class).to receive(:alert) do |**args|
          expect(args.fetch(:error)).to be_a(Lich::DependencyRecovery::StagingTimeoutError)
        end
        expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end

      it 'preserves the unwritable gem home type through Windows startup failure reporting' do
        check.needed = ['sqlite3']
        allow(recovery).to receive(:recover).and_return(
          Lich::DependencyRecovery::Result.new(installed_gems: [], error: 'C:\\gems\\plugins is marked read-only', error_kind: :gem_home_not_writable)
        )
        expect(described_class).to receive(:alert) do |**args|
          expect(args.fetch(:error)).to be_a(Lich::DependencyRecovery::GemHomeNotWritableError)
          expect(args.fetch(:error).message).to eq('C:\\gems\\plugins is marked read-only')
        end
        expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end

      it 'does not repair or continue when consent is refused' do
        check.needed = ['sqlite3']
        allow(described_class).to receive(:recovery_units_approved?).and_return(false)
        expect(recovery).not_to receive(:recover)
        expect(policy).not_to receive(:activate!)
        expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end

      it 'fails closed on an unavailable or invalid accepted manifest' do
        allow(policy).to receive(:check).and_raise(Lich::DependencyRecovery::Error, 'manifest unavailable')
        expect(described_class).to receive(:alert) { |**args| expect(args.fetch(:error).message).to include('manifest unavailable') }
        expect(recovery).not_to receive(:recover)
        expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end

      context 'when the accepted manifest has no target for this runtime' do
        let(:unsupported) { Lich::AcceptedGemPolicy::UnsupportedRuntimeError.new('manifest has no target for Ruby 4.0 on aarch64-mingw-ucrt') }

        before { allow(policy).to receive(:check).and_raise(unsupported) }

        it 'starts without enforcement when no declared gem is missing' do
          expect(described_class).to receive(:missing_gems).with([:default]).and_return([])
          expect(described_class).not_to receive(:alert)
          expect(policy).not_to receive(:activate!)
          expect(recovery).not_to receive(:recover)
          expect { described_class.verify! }.not_to raise_error
        end

        it 'checks the requested groups' do
          expect(described_class).to receive(:missing_gems).with(%i[default gtk]).and_return([])
          described_class.verify!(:default, :gtk)
        end

        it 'reports missing gems without attempting a repair' do
          allow(described_class).to receive(:missing_gems).and_return(['ox'])
          expect(recovery).not_to receive(:recover)
          expect(described_class).not_to receive(:recovery_units_approved?)
          expect(described_class).to receive(:alert).with(missing: ['ox'], groups: [:default], error: unsupported)
          expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
        end
      end

      it 'still fails closed on an invalid policy even when no gem is missing' do
        allow(policy).to receive(:check).and_raise(Lich::AcceptedGemPolicy::InvalidPolicyError, 'duplicate targets')
        allow(described_class).to receive(:missing_gems).and_return([])
        expect(described_class).to receive(:alert) { |**args| expect(args.fetch(:error)).to be_a(Lich::AcceptedGemPolicy::InvalidPolicyError) }
        expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end

      it 'fails closed when reading declarations fails instead of accepting an empty missing list' do
        allow(described_class).to receive(:required_dependencies).and_raise(Lich::DependencyRecovery::Error, 'invalid Gemfile')
        expect(described_class).to receive(:alert) { |**args| expect(args.fetch(:error).message).to include('invalid Gemfile') }
        expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end

      context 'with a package minimum' do
        let(:package) { { 'name' => 'sqlite3', 'version' => '2.10.2', 'minimum' => '2.10.1', 'filename' => 'sqlite3-2.10.2.gem', 'sha256' => "sha256:#{'a' * 64}" } }
        let(:units) { [{ 'id' => 'sqlite3', 'members' => ['sqlite3'], 'install_order' => ['sqlite3'], 'packages' => [package] }] }
        let(:plan) { Lich::DependencyRecovery::Plan.new(units: units, target: { 'platform' => Gem::Platform.local.to_s, 'contract' => { 'ruby_inventory' => { 'gems' => {} } } }) }
        let(:installed) { {} }
        let(:loaded) { {} }
        let(:policy) { Lich::AcceptedGemPolicy.new(recovery: recovery, find_specs: ->(name) { installed.fetch(name, []) }, loaded_specs: loaded) }
        let(:log) { File.join(TEMP_DIR, described_class::LOG_FILENAME) }

        def installed_spec(name, version, dependencies = {})
          Gem::Specification.new do |item|
            item.name = name
            item.version = version
            dependencies.each { |child, requirement| item.add_runtime_dependency(child, requirement) }
          end.tap do |result|
            activated = loaded
            result.define_singleton_method(:activate) { activated[name] = self; true }
          end
        end

        before do
          allow(recovery).to receive(:policy_plan).and_return(plan)
          allow(policy).to receive(:check).and_call_original
          allow(policy).to receive(:activate!).and_call_original
          FileUtils.rm_f(log)
        end

        it 'starts on a recommended-only gap with no dialog or repair and logs it' do
          installed['sqlite3'] = [installed_spec('sqlite3', '2.10.1')]
          expect(described_class).not_to receive(:alert)
          expect(described_class).not_to receive(:recovery_units_approved?)
          expect(described_class).not_to receive(:show_notice)
          expect(recovery).not_to receive(:recover)
          expect { described_class.verify! }.not_to raise_error
          expect(loaded.fetch('sqlite3').version.to_s).to eq('2.10.1')
          entry = File.read(log)
          expect(entry).to include('Lich5 GemCheck recommended update')
          expect(entry).to include('- sqlite3: installed 2.10.1, accepted 2.10.2 (minimum 2.10.1), sqlite3 gem')
          expect(entry).not_to include('Lich5 GemCheck failure')
        end

        it 'writes one recommended entry for repeated identical starts' do
          installed['sqlite3'] = [installed_spec('sqlite3', '2.10.1')]
          3.times do
            loaded.clear
            described_class.verify!
          end
          expect(File.read(log).scan('Lich5 GemCheck recommended update').length).to eq(1)
        end

        it 'writes a new recommended entry when its content changes, even after another entry' do
          installed['sqlite3'] = [installed_spec('sqlite3', '2.10.1')]
          described_class.verify!
          File.open(log, 'a') { |f| f.puts "[#{Time.now}] Lich5 GemCheck failure", '  something else', '' }
          loaded.clear
          described_class.verify!
          expect(File.read(log).scan('Lich5 GemCheck recommended update').length).to eq(1)
          package['minimum'] = '2.10.0'
          loaded.clear
          described_class.verify!
          entries = File.read(log).lines.grep(/- sqlite3:/).map(&:strip)
          expect(entries).to eq(['- sqlite3: installed 2.10.1, accepted 2.10.2 (minimum 2.10.1), sqlite3 gem',
                                 '- sqlite3: installed 2.10.1, accepted 2.10.2 (minimum 2.10.0), sqlite3 gem'])
        end

        it 'still writes the recommended entry and starts when the log cannot be read' do
          installed['sqlite3'] = [installed_spec('sqlite3', '2.10.1')]
          described_class.verify!
          allow(File).to receive(:foreach).and_call_original
          allow(File).to receive(:foreach).with(log).and_raise(Errno::EACCES)
          loaded.clear
          expect { described_class.verify! }.not_to raise_error
          expect(loaded.fetch('sqlite3').version.to_s).to eq('2.10.1')
          expect(File.read(log).scan('Lich5 GemCheck recommended update').length).to eq(2)
        end

        it 'starts without raising when the recommended entry cannot be written' do
          installed['sqlite3'] = [installed_spec('sqlite3', '2.10.1')]
          allow(File).to receive(:open).and_call_original
          allow(File).to receive(:open).with(log, 'a').and_raise(Errno::EACCES)
          expect { described_class.verify! }.not_to raise_error
          expect(loaded.fetch('sqlite3').version.to_s).to eq('2.10.1')
        end

        it 'writes no recommended entry when the accepted version is installed' do
          installed['sqlite3'] = [installed_spec('sqlite3', '2.10.1'), installed_spec('sqlite3', '2.10.2')]
          described_class.verify!
          expect(File.exist?(log) ? File.read(log) : '').not_to include('recommended update')
          expect(loaded.fetch('sqlite3').version.to_s).to eq('2.10.2')
        end

        it 'runs one consented repair of the whole unit when a needed member shares it with a recommended one' do
          units.first['members'] << 'closure'
          units.first['install_order'].unshift('closure')
          units.first['packages'] << { 'name' => 'closure', 'version' => '1.0', 'filename' => 'closure-1.0.gem', 'sha256' => "sha256:#{'b' * 64}" }
          installed['sqlite3'] = [installed_spec('sqlite3', '2.10.1', 'closure' => '>= 1')]
          expect(described_class).to receive(:recovery_units_approved?).once.with(units, [:default]).and_return(true)
          expect(recovery).to receive(:recover).once do |names, force:, plan:, restart:, preserve_newer:|
            expect(names).to eq(['closure'])
            expect([force, restart, preserve_newer]).to eq([true, true, true])
            expect(plan.units).to eq(units)
            Lich::DependencyRecovery::Result.new(installed_gems: [], restart_required: true)
          end
          expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
          expect(File.exist?(log) ? File.read(log) : '').not_to include('recommended update')
        end
      end

      it 'reports an unwritable runtime instead of continuing after a failed repair' do
        check.needed = ['sqlite3']
        allow(recovery).to receive(:recover).and_return(Lich::DependencyRecovery::Result.new(error: 'Cannot write Gem.dir'))
        expect(described_class).to receive(:alert) { |**args| expect(args.fetch(:error).message).to include('Cannot write Gem.dir') }
        expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end
    end
  end

  describe '.recovery_units_approved?' do
    let(:unit) { { 'id' => 'sqlite3', 'members' => ['sqlite3'] } }

    it 'logs and warns when native consent UI is unavailable' do
      allow(described_class).to receive(:confirm_recovery_units).with([unit]).and_return(:unavailable)
      expect(described_class).to receive(:report_consent_failure)
        .with([unit], [:default], 'user consent not available')

      expect(described_class.recovery_units_approved?([unit], [:default])).to be(false)
    end

    it 'requires one approval covering every planned unit before downloading any artifact' do
      second = { 'id' => 'gtk3-runtime', 'members' => %w[glib2 gtk3] }
      expect(described_class).to receive(:confirm_recovery_units).with([unit, second]).and_return(:approved)

      expect(described_class.recovery_units_approved?([unit, second], [:default])).to be(true)
    end

    it 'logs a timeout distinctly from a declined or unavailable prompt' do
      allow(described_class).to receive(:confirm_recovery_units).with([unit]).and_return(:timed_out)
      expect(described_class).to receive(:report_consent_failure)
        .with([unit], [:default], 'user consent timed out')

      expect(described_class.recovery_units_approved?([unit], [:default])).to be(false)
    end
  end

  describe '.build_recovery_prompt' do
    it 'uses real line breaks between the explanatory sentence and the question' do
      unit = { 'id' => 'ox', 'members' => ['ox'] }

      expect(described_class.build_recovery_prompt([unit]))
        .to include("restarts Lich before continuing.\n\nInstall now?")
    end
  end

  describe '.confirm_windows' do
    it 'maps the bounded WScript timeout result to a fail-closed outcome' do
      expect(described_class).to receive(:windows_popup)
        .with('consent', 4 + 32).and_return(-1)

      expect(described_class.confirm_windows('consent')).to eq(:timed_out)
    end

    it 'maps Yes and No result codes to approval and decline' do
      allow(described_class).to receive(:windows_popup).with('consent', 4 + 32).and_return(6)
      expect(described_class.confirm_windows('consent')).to eq(:approved)

      allow(described_class).to receive(:windows_popup).with('consent', 4 + 32).and_return(7)
      expect(described_class.confirm_windows('consent')).to eq(:declined)
    end
  end

  describe '.confirm_recovery_units' do
    it 'does not offer recovery consent on unsupported platforms' do
      allow(described_class).to receive(:self_healing_supported?).and_return(false)
      expect(described_class).not_to receive(:confirm_windows)

      expect(described_class.confirm_recovery_units([])).to eq(:unavailable)
    end
  end

  describe 'Windows notices' do
    let(:shell) { double('WScript.Shell') }

    before do
      stub_const('WIN32OLE', Class.new)
      allow(described_class).to receive(:require).with('win32ole').and_return(true)
      allow(WIN32OLE).to receive(:new).with('WScript.Shell').and_return(shell)
    end

    it 'bounds informational notices' do
      expect(shell).to receive(:Popup)
        .with('notice', described_class::CONSENT_TIMEOUT_SECONDS, described_class::TITLE, 64)

      described_class.notice_windows('notice')
    end

    it 'waits for the release-page alert and opens the URL only after OK' do
      expect(shell).to receive(:Popup)
        .with("alert\nClick OK to open the download page.", described_class::ALERT_TIMEOUT_SECONDS,
              described_class::TITLE, 1 + 64).and_return(1)
      expect(shell).to receive(:Run).with(described_class::RELEASE_URL)

      described_class.alert_windows('alert')
    end

    it 'does not open the release page when Cancel is selected' do
      allow(shell).to receive(:Popup).and_return(2)
      expect(shell).not_to receive(:Run)

      described_class.alert_windows('alert')
    end
  end

  describe '.macos_dialog_body' do
    it 'preserves multiline body content as AppleScript return expressions' do
      expect(described_class.macos_dialog_body("first\nsecond")).to eq('"first" & return & "second"')
    end
  end

  describe '.configure_gemfile!' do
    around do |example|
      original = ENV.fetch('BUNDLE_GEMFILE', nil)
      example.run
    ensure
      if original.nil?
        ENV.delete('BUNDLE_GEMFILE')
      else
        ENV['BUNDLE_GEMFILE'] = original
      end
    end

    it 'points Bundler at the Lich Gemfile when launched from another directory' do
      Dir.mktmpdir('lich-gemcheck-home') do |dir|
        gemfile = File.join(dir, 'Gemfile')
        File.write(gemfile, "source 'https://rubygems.org'\n")
        stub_const('LICH_DIR', dir)
        ENV.delete('BUNDLE_GEMFILE')

        described_class.configure_gemfile!

        expect(ENV.fetch('BUNDLE_GEMFILE')).to eq(gemfile)
      end
    end

    it 'preserves an existing BUNDLE_GEMFILE override' do
      Dir.mktmpdir('lich-gemcheck-home') do |dir|
        File.write(File.join(dir, 'Gemfile'), "source 'https://rubygems.org'\n")
        stub_const('LICH_DIR', dir)
        ENV['BUNDLE_GEMFILE'] = '/custom/Gemfile'

        described_class.configure_gemfile!

        expect(ENV.fetch('BUNDLE_GEMFILE')).to eq('/custom/Gemfile')
      end
    end

    it 'leaves BUNDLE_GEMFILE unset when LICH_DIR is undefined' do
      hide_const('LICH_DIR')
      ENV.delete('BUNDLE_GEMFILE')

      described_class.configure_gemfile!

      expect(ENV['BUNDLE_GEMFILE']).to be_nil
    end

    it 'leaves BUNDLE_GEMFILE unset when the Lich Gemfile does not exist' do
      Dir.mktmpdir('lich-gemcheck-home') do |dir|
        stub_const('LICH_DIR', dir)
        ENV.delete('BUNDLE_GEMFILE')

        described_class.configure_gemfile!

        expect(ENV['BUNDLE_GEMFILE']).to be_nil
      end
    end
  end

  describe '.self_healing_supported?' do
    it 'follows RubyGems Windows platform detection without loading the os gem' do
      allow(Gem).to receive(:win_platform?).and_return(true)
      expect(described_class.self_healing_supported?).to be(true)

      allow(Gem).to receive(:win_platform?).and_return(false)
      expect(described_class.self_healing_supported?).to be(false)
    end
  end

  describe '.bundler_recovery_supported?' do
    before { allow(Lich::BundlerRecovery).to receive(:supported?).and_return(true) }

    it 'is limited to the default runtime group so GTK cannot enter this path' do
      expect(described_class.bundler_recovery_supported?([:default])).to be(true)
      expect(described_class.bundler_recovery_supported?([:default, :gtk])).to be(false)
      expect(described_class.bundler_recovery_supported?([:gtk])).to be(false)
    end
  end

  describe '.required_dependencies on Windows' do
    it 'reads runtime groups without evaluating Gemfile plugins or requiring a shipped lockfile' do
      allow(described_class).to receive(:self_healing_supported?).and_return(true)
      source = "plugin 'must-not-run'\ngem 'sqlite3'\ngroup :gtk do\n gem 'gtk3'\nend\n"
      allow(File).to receive(:binread).and_return(source)
      expect(bundler).not_to receive(:definition)
      expect(described_class.required_dependencies([:default]).map(&:name)).to eq(['sqlite3'])
      expect(described_class.required_dependencies(%i[default gtk]).map(&:name)).to eq(%w[sqlite3 gtk3])
    end
  end

  describe '.missing_gems' do
    let(:default_present) do
      double('dep', name: 'sqlite3', requirement: Gem::Requirement.default, groups: [:default])
    end
    let(:default_missing) do
      double('dep', name: 'ox', requirement: Gem::Requirement.default, groups: [:default])
    end
    let(:dev_missing) do
      double('dep', name: 'rspec', requirement: Gem::Requirement.default, groups: [:development])
    end
    let(:definition) do
      double('definition', current_dependencies: [default_present, default_missing, dev_missing])
    end

    before do
      allow(bundler).to receive(:definition).and_return(definition)
      allow(Gem::Specification).to receive(:find_all_by_name)
        .with('sqlite3', anything).and_return([double('spec')])
      allow(Gem::Specification).to receive(:find_all_by_name)
        .with('ox', anything).and_return([])
      allow(Gem::Specification).to receive(:find_all_by_name)
        .with('rspec', anything).and_return([])
    end

    it 'returns only missing gems in the requested groups' do
      expect(described_class.missing_gems([:default])).to eq(['ox'])
    end

    it 'includes gems from all requested groups' do
      expect(described_class.missing_gems([:default, :development])).to eq(%w[ox rspec])
    end

    it 'excludes gems from groups not requested' do
      expect(described_class.missing_gems([:default])).not_to include('rspec')
    end

    it 'defaults to :default when no groups are given' do
      expect(described_class.missing_gems).to eq(['ox'])
    end

    it 'sorts and uniqs the result' do
      dup_missing = double('dep', name: 'ox', requirement: Gem::Requirement.default, groups: [:default])
      other_missing = double('dep', name: 'atk', requirement: Gem::Requirement.default, groups: [:default])
      allow(definition).to receive(:current_dependencies)
        .and_return([default_missing, dup_missing, other_missing])
      allow(Gem::Specification).to receive(:find_all_by_name)
        .with('atk', anything).and_return([])

      expect(described_class.missing_gems([:default])).to eq(%w[atk ox])
    end

    it 'surfaces declaration lookup failures instead of returning an empty missing list' do
      allow(bundler).to receive(:definition).and_raise(StandardError)
      expect { described_class.missing_gems([:default]) }.to raise_error(Lich::DependencyRecovery::Error, /could not read required gem declarations/)
    end
  end

  describe '.all_groups' do
    it 'returns the groups from Bundler.definition' do
      allow(bundler).to receive(:definition)
        .and_return(double('definition', groups: [:default, :development, :gtk]))
      expect(described_class.all_groups).to eq([:default, :development, :gtk])
    end

    it 'returns [:default] when Bundler.definition raises' do
      allow(bundler).to receive(:definition).and_raise(StandardError)
      expect(described_class.all_groups).to eq([:default])
    end
  end

  describe '.alert' do
    before { allow(described_class).to receive(:write_log) }

    it 'writes the log before dispatching' do
      stub_const('RUBY_PLATFORM', 'x86_64-linux')
      allow(described_class).to receive(:alert_linux)
      expect(described_class).to receive(:write_log).ordered
      expect(described_class).to receive(:alert_linux).ordered
      described_class.alert
    end

    {
      'x64-mingw-ucrt'  => :alert_windows,
      'i386-mswin32'    => :alert_windows,
      'x86_64-cygwin'   => :alert_windows,
      'x86_64-darwin23' => :alert_macos,
      'x86_64-linux'    => :alert_linux,
      'amd64-freebsd14' => :alert_linux
    }.each do |platform, handler|
      it "dispatches #{platform.inspect} to #{handler}" do
        stub_const('RUBY_PLATFORM', platform)
        expect(described_class).to receive(handler)
        described_class.alert
      end
    end

    it 'forwards the composed body to the platform handler' do
      stub_const('RUBY_PLATFORM', 'x86_64-linux')
      expect(described_class).to receive(:alert_linux) do |body|
        expect(body).to include('- ox')
      end
      described_class.alert(missing: ['ox'])
    end
  end

  describe '.message' do
    it 'returns the Windows message on mingw' do
      stub_const('RUBY_PLATFORM', 'x64-mingw-ucrt')
      expect(described_class.message).to eq(described_class::WINDOWS_MESSAGE)
    end

    it 'returns the Windows message on mswin' do
      stub_const('RUBY_PLATFORM', 'i386-mswin32')
      expect(described_class.message).to eq(described_class::WINDOWS_MESSAGE)
    end

    it 'returns the Unix message on darwin' do
      stub_const('RUBY_PLATFORM', 'x86_64-darwin23')
      expect(described_class.message).to eq(described_class::UNIX_MESSAGE)
    end

    it 'returns the Unix message on linux' do
      stub_const('RUBY_PLATFORM', 'x86_64-linux')
      expect(described_class.message).to eq(described_class::UNIX_MESSAGE)
    end
  end

  describe '.build_alert_body' do
    before { stub_const('RUBY_PLATFORM', 'x86_64-linux') }

    it 'includes only the platform message when nothing else is given' do
      body = described_class.build_alert_body([], nil)
      expect(body).to include(described_class::UNIX_MESSAGE)
      expect(body).not_to include('Missing gems:')
      expect(body).not_to include('Underlying error:')
    end

    it 'appends a bulleted list when gems are provided' do
      body = described_class.build_alert_body(%w[ox sqlite3], nil)
      expect(body).to include('Missing gems:')
      expect(body).to include('- ox')
      expect(body).to include('- sqlite3')
    end

    it 'shows the underlying error when no gems were detected' do
      error = double('error', message: "Could not find gem 'transitive' in locally installed gems.")
      body = described_class.build_alert_body([], error)
      expect(body).to include('Underlying error:')
      expect(body).to include("Could not find gem 'transitive'")
    end

    it 'shows both the detected list and the underlying error when both are present' do
      error = double('error', message: 'cannot load such file -- glib2.so')
      body = described_class.build_alert_body(['gtk3'], error)
      expect(body).to include('Missing gems:')
      expect(body).to include('Underlying error:')
      expect(body).to include('cannot load such file -- glib2.so')
    end

    it 'points at the log file when TEMP_DIR is defined' do
      body = described_class.build_alert_body([], nil)
      expect(body).to include(described_class::LOG_FILENAME)
    end
  end

  describe '.write_log' do
    let(:log_path) { File.join(TEMP_DIR, described_class::LOG_FILENAME) }

    before { FileUtils.rm_f(log_path) }
    after  { FileUtils.rm_f(log_path) }

    it 'writes the platform message to TEMP_DIR' do
      described_class.write_log
      expect(File.read(log_path)).to include("You're missing required Ruby gems")
    end

    it 'writes missing gem names when provided' do
      described_class.write_log(missing: %w[ox sqlite3])
      contents = File.read(log_path)
      expect(contents).to include('Missing gems (detected):')
      expect(contents).to include('- ox')
      expect(contents).to include('- sqlite3')
    end

    it 'notes when the detector identified nothing' do
      described_class.write_log
      expect(File.read(log_path)).to include('none identified by GemCheck')
    end

    it 'writes the Bundler error details when provided' do
      error = double('error',
                     class: StandardError,
                     message: "Could not find gem 'foo' in locally installed gems.")
      described_class.write_log(error: error)
      contents = File.read(log_path)
      expect(contents).to include('Underlying error:')
      expect(contents).to include("Could not find gem 'foo'")
    end

    it 'includes diagnostic information' do
      described_class.write_log(groups: [:default, :gtk])
      contents = File.read(log_path)
      expect(contents).to include('Ruby:')
      expect(contents).to include('Bundler:')
      expect(contents).to include('Groups checked:  [:default, :gtk]')
      expect(contents).to include('Working dir:')
    end

    it 'includes the release URL on Windows' do
      stub_const('RUBY_PLATFORM', 'x64-mingw-ucrt')
      described_class.write_log
      expect(File.read(log_path)).to include(described_class::RELEASE_URL)
    end

    it 'omits the release URL on Unix platforms' do
      stub_const('RUBY_PLATFORM', 'x86_64-linux')
      described_class.write_log
      expect(File.read(log_path)).not_to include(described_class::RELEASE_URL)
    end

    it 'includes an ISO-style timestamp' do
      described_class.write_log
      expect(File.read(log_path)).to match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/)
    end

    it 'appends across multiple calls rather than overwriting' do
      2.times { described_class.write_log }
      expect(File.read(log_path).scan('Lich5 GemCheck failure').size).to eq(2)
    end

    it 'records approved recovery units without labelling the entry a failure' do
      units = [{ 'id' => 'gtk3-runtime', 'members' => %w[glib2 gtk3] }]
      described_class.write_recovery_log(missing: ['gtk3'], groups: [:gtk], units: units)

      contents = File.read(log_path)
      expect(contents).to include('Lich5 GemCheck recovery')
      expect(contents).to include('Approved manifest recovery units:')
      expect(contents).to include('GTK3 runtime bundle: glib2, gtk3')
      expect(contents).not_to include('Lich5 GemCheck failure')
    end

    it 'swallows filesystem errors silently' do
      allow(File).to receive(:open).and_raise(Errno::EACCES)
      expect { described_class.write_log }.not_to raise_error
    end
  end

  describe '.dependency_report' do
    let(:present_dep) do
      double('dep', name: 'ox', requirement: Gem::Requirement.default, groups: [:default])
    end
    let(:missing_dep) do
      double('dep', name: 'atk', requirement: Gem::Requirement.default, groups: [:default])
    end
    let(:out_of_scope_dep) do
      double('dep', name: 'rspec', requirement: Gem::Requirement.default, groups: [:development])
    end

    before do
      allow(bundler).to receive(:definition).and_return(
        double('definition', current_dependencies: [present_dep, missing_dep, out_of_scope_dep])
      )
      allow(Gem::Specification).to receive(:find_all_by_name)
        .with('ox', anything).and_return([double('spec', version: Gem::Version.new('2.14.28'))])
      allow(Gem::Specification).to receive(:find_all_by_name)
        .with('atk', anything).and_return([])
    end

    it 'reports OK with version for installed gems in scope' do
      expect(described_class.dependency_report([:default])).to include('ox').and include('OK')
    end

    it 'reports MISSING for uninstalled gems in scope' do
      expect(described_class.dependency_report([:default])).to include('atk').and include('MISSING')
    end

    it 'excludes gems from non-requested groups' do
      expect(described_class.dependency_report([:default])).not_to include('rspec')
    end

    it 'returns (none) when no dependencies match the requested groups' do
      expect(described_class.dependency_report([:nonexistent])).to eq('(none)')
    end
  end

  describe '.alert_linux' do
    def stub_only_available(tool)
      allow(described_class).to receive(:cmd_available?).and_return(false)
      allow(described_class).to receive(:cmd_available?).with(tool).and_return(true)
    end

    # The dialog chain is only reached with no terminal attached. Stub both
    # streams explicitly rather than inheriting whatever the runner happens to
    # have -- rspec's stdout is a tty when run directly in a terminal and a
    # pipe under CI, which would otherwise make these pass or fail by accident.
    before do
      allow($stdout).to receive(:isatty).and_return(false)
      allow($stderr).to receive(:isatty).and_return(false)
      allow(described_class).to receive(:warn)
    end

    it 'always warns, whether or not a dialog follows' do
      stub_only_available('zenity')
      allow(described_class).to receive(:run_with_timeout)

      expect(described_class).to receive(:warn).with(/!!ALERT!!.*body text/m).twice

      described_class.alert_linux('body text')             # no tty: warn + dialog
      allow($stdout).to receive(:isatty).and_return(true)
      described_class.alert_linux('body text')             # tty: warn only
    end

    context 'when a terminal is attached' do
      it 'does not wait on a dialog, even when zenity is available' do
        stub_only_available('zenity')
        allow($stdout).to receive(:isatty).and_return(true)

        expect(described_class).not_to receive(:run_with_timeout)
        expect(described_class).to receive(:warn).with(/!!ALERT!!.*body text/m)

        described_class.alert_linux('body text')
      end

      it 'treats a terminal on stderr alone as interactive' do
        stub_only_available('zenity')
        allow($stderr).to receive(:isatty).and_return(true)

        expect(described_class).not_to receive(:run_with_timeout)

        described_class.alert_linux('body text')
      end
    end

    context 'when no dialog tool is available and no terminal is attached' do
      it 'still reports on stderr' do
        allow(described_class).to receive(:cmd_available?).and_return(false)

        expect(described_class).to receive(:warn).with(/!!ALERT!!.*body text/m)

        described_class.alert_linux('body text')
      end
    end

    context 'when zenity is available' do
      before { stub_only_available('zenity') }

      it 'shows a zenity info dialog bounded by a timeout' do
        expect(described_class).to receive(:run_with_timeout)
          .with(['zenity', '--info', '--title', described_class::TITLE, '--text', 'body text'],
                described_class::ALERT_TIMEOUT_SECONDS)
        described_class.alert_linux('body text')
      end
    end

    context 'when only kdialog is available' do
      before { stub_only_available('kdialog') }

      it 'shows a kdialog msgbox bounded by a timeout' do
        expect(described_class).to receive(:run_with_timeout)
          .with(['kdialog', '--title', described_class::TITLE, '--msgbox', 'body text'],
                described_class::ALERT_TIMEOUT_SECONDS)
        described_class.alert_linux('body text')
      end
    end

    context 'when only xmessage is available' do
      before { stub_only_available('xmessage') }

      it 'shows an xmessage dialog bounded by a timeout' do
        expect(described_class).to receive(:run_with_timeout)
          .with(['xmessage', '-center', 'body text'], described_class::ALERT_TIMEOUT_SECONDS)
        described_class.alert_linux('body text')
      end
    end
  end

  describe '.cmd_available?' do
    it 'returns true when `which` exits successfully' do
      allow(described_class).to receive(:system)
        .with('which', 'ls', out: File::NULL, err: File::NULL).and_return(true)
      expect(described_class.cmd_available?('ls')).to be(true)
    end

    it 'returns false when `which` fails' do
      allow(described_class).to receive(:system)
        .with('which', 'definitely-not-a-real-command', out: File::NULL, err: File::NULL)
        .and_return(false)
      expect(described_class.cmd_available?('definitely-not-a-real-command')).to be(false)
    end
  end

  describe '.run_with_timeout' do
    it 'returns true when the command exits on its own before the timeout' do
      expect(described_class.run_with_timeout(['true'], 5)).to be(true)
    end

    it 'kills the process and returns false when it outlives the timeout' do
      elapsed = Benchmark.realtime do
        expect(described_class.run_with_timeout(['sleep', '30'], 1)).to be(false)
      end
      expect(elapsed).to be < 5
    end

    it 'leaves no child behind once it has timed out' do
      pid = nil
      allow(Process).to(receive(:spawn).and_wrap_original { |m, *args, **kw| pid = m.call(*args, **kw) })
      expect(described_class.run_with_timeout(['sleep', '30'], 1)).to be(false)
      expect { Process.kill(0, pid) }.to raise_error(Errno::ESRCH)
    end

    it 'ends the child with KILL on Windows, where TERM raises Errno::EINVAL' do
      allow(Gem).to receive(:win_platform?).and_return(true)
      expect(Process).to receive(:kill).with('KILL', kind_of(Integer)).and_call_original
      expect(described_class.run_with_timeout(['sleep', '30'], 1)).to be(false)
    end

    it 'ends the child with TERM off Windows' do
      skip 'Windows Ruby cannot deliver TERM to a real child' if Gem.win_platform?
      allow(Gem).to receive(:win_platform?).and_return(false)
      expect(Process).to receive(:kill).with('TERM', kind_of(Integer)).and_call_original
      expect(described_class.run_with_timeout(['sleep', '30'], 1)).to be(false)
    end

    it 'does not signal a child that exits before the timeout' do
      expect(Process).not_to receive(:kill)
      expect(described_class.run_with_timeout(['true'], 5)).to be(true)
    end
  end

  describe 'policy diagnostics and native repair guidance' do
    before do
      stub_const('RUBY_PLATFORM', 'x64-mingw-ucrt')
      allow(described_class).to receive(:write_log)
    end

    it 'stops an offline healthy installation with retry guidance and no installer link' do
      error = Lich::AcceptedGemPolicy::AcquisitionError.new('SocketError: offline')
      body = described_class.build_alert_body([], error)
      expect(body).to include('Check your network connection and retry', 'Startup requires reachable policy')
      expect(body).not_to include("You're missing", 'Missing gems:')
      expect(described_class).to receive(:alert_windows).with(body, download: false)
      described_class.alert(error: error)
    end

    it 'gives a staging timeout retry guidance without an installer link' do
      error = Lich::DependencyRecovery::StagingTimeoutError.new('staging timed out')
      body = described_class.build_alert_body([], error)
      expect(body).to include('download timed out', 'Check your connection and retry')
      expect(body).not_to include('reinstall', "You're missing")
      expect(described_class).to receive(:alert_windows).with(body, download: false)
      described_class.alert(error: error)
    end

    it 'names the unwritable gem folder fix without offering an installer' do
      error = Lich::DependencyRecovery::GemHomeNotWritableError.new(
        'C:\\Ruby4Lich5\\4.0.9\\lib\\ruby\\gems\\4.0.0\\plugins is marked read-only, so gems cannot be installed. ' \
        'Open a Command Prompt and run: attrib -R "C:\\Ruby4Lich5\\4.0.9\\lib\\ruby\\gems\\4.0.0\\plugins"'
      )
      body = described_class.build_alert_body(['sqlite3'], error)
      expect(body).to start_with('Lich cannot write to its Ruby gem folder')
      expect(body).to include('attrib -R "C:\\Ruby4Lich5\\4.0.9\\lib\\ruby\\gems\\4.0.0\\plugins"')
      expect(body).not_to include("You're missing", 'reinstall')
      expect(described_class).to receive(:alert_windows).with(body, download: false)
      described_class.alert(error: error, missing: ['sqlite3'])
    end

    it 'explains missing server coverage without offering an installer' do
      error = Lich::AcceptedGemPolicy::CoverageError.new('missing root')
      body = described_class.build_alert_body([], error)
      expect(body).to include('release maintainer', 'reinstalling Ruby will not fix')
      expect(described_class).to receive(:alert_windows).with(body, download: false)
      described_class.alert(error: error)
    end

    it 'explains an unsupported runtime with manual install guidance and the installer link' do
      error = Lich::AcceptedGemPolicy::UnsupportedRuntimeError.new('manifest has no target for Ruby 4.0 on aarch64-mingw-ucrt')
      body = described_class.build_alert_body(['ox'], error)
      expect(body).to start_with("Automatic gem repair is not available for Ruby #{RUBY_VERSION} on #{Gem::Platform.local}.")
      expect(body).to include('gem install', 'Ruby4Lich5 installer (on ARM64, Windows 11 only)', 'Missing gems:', 'no target')
      expect(body).not_to include('release maintainer')
      expect(described_class).to receive(:alert_windows).with(body, download: true)
      described_class.alert(error: error, missing: ['ox'])
    end

    it 'explains malformed policy separately from missing installed gems' do
      body = described_class.build_alert_body([], Lich::AcceptedGemPolicy::InvalidPolicyError.new('schema'))
      expect(body).to include('invalid or incompatible', 'published policy')
      expect(body).not_to include("You're missing")
    end

    it 'offers repair guidance and the installer link for a damaged local dependency' do
      error = Lich::AcceptedGemPolicy::LocalInstallationError.new('local-child is missing')
      body = described_class.build_alert_body([], error)
      expect(body).to include('missing gem dependency', 'Repair or reinstall Ruby4Lich5', 'local-child is missing')
      expect(body).not_to include('release maintainer', 'could not retrieve')
      expect(described_class).to receive(:alert_windows).with(body, download: true)
      described_class.alert(error: error)
    end

    it 'does not open a browser when a policy-only Windows notice is acknowledged' do
      allow(described_class).to receive(:require).with('win32ole').and_return(true)
      shell = double('shell')
      stub_const('WIN32OLE', Class.new)
      allow(WIN32OLE).to receive(:new).with('WScript.Shell').and_return(shell)
      expect(shell).to receive(:Popup).with('retry', described_class::ALERT_TIMEOUT_SECONDS, described_class::TITLE, 64).and_return(1)
      expect(shell).not_to receive(:Run)
      described_class.alert_windows('retry', download: false)
    end

    it 'tells the user to close other instances before consenting to native repair' do
      prompt = described_class.build_recovery_prompt([{ 'id' => 'sqlite3', 'members' => ['sqlite3'] }])
      expect(prompt).to include('Close all other Lich instances', 'native DLLs', 'restarts Lich')
      expect(prompt.index('Close all other Lich instances')).to be < prompt.index('Install now?')
    end

    it 'retains fail-closed non-Windows startup for a missing Gemfile without fetching policy' do
      allow(described_class).to receive(:self_healing_supported?).and_return(false)
      allow(described_class).to receive(:configure_gemfile!)
      allow(bundler).to receive(:definition).and_raise(Errno::ENOENT, 'Gemfile')
      expect(Lich::DependencyRecovery).not_to receive(:new)
      expect(described_class).to receive(:alert) do |missing:, groups:, error:|
        expect(missing).to be_empty
        expect(groups).to eq([:default])
        expect(error).to be_a(described_class::DeclarationError)
        expect(described_class.build_alert_body(missing, error)).to include('Restore the Gemfile')
      end
      expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    end
  end

  it 'logs policy failures without a misleading download link or loading Bundler on Windows' do
    stub_const('RUBY_PLATFORM', 'x64-mingw-ucrt')
    allow(described_class).to receive(:self_healing_supported?).and_return(true)
    allow(described_class).to receive(:required_dependencies).and_return([])
    expect(described_class).not_to receive(:bundler)
    described_class.write_log(error: Lich::AcceptedGemPolicy::AcquisitionError.new('offline'))
    contents = File.read(File.join(TEMP_DIR, described_class::LOG_FILENAME))
    latest = contents.split('Lich5 GemCheck failure').last
    expect(latest).to include('Check your network connection', 'Underlying error:')
    expect(latest).not_to include('Download:', "You're missing")
  end

  describe 'policy diagnostics and native repair guidance' do
    before do
      stub_const('RUBY_PLATFORM', 'x64-mingw-ucrt')
      allow(described_class).to receive(:write_log)
    end

    it 'stops an offline healthy installation with retry guidance and no installer link' do
      error = Lich::AcceptedGemPolicy::AcquisitionError.new('SocketError: offline')
      body = described_class.build_alert_body([], error)
      expect(body).to include('Check your network connection and retry', 'Startup requires reachable policy')
      expect(body).not_to include("You're missing", 'Missing gems:')
      expect(described_class).to receive(:alert_windows).with(body, download: false)
      described_class.alert(error: error)
    end

    it 'gives a staging timeout retry guidance without an installer link' do
      error = Lich::DependencyRecovery::StagingTimeoutError.new('staging timed out')
      body = described_class.build_alert_body([], error)
      expect(body).to include('download timed out', 'Check your connection and retry')
      expect(body).not_to include('reinstall', "You're missing")
      expect(described_class).to receive(:alert_windows).with(body, download: false)
      described_class.alert(error: error)
    end

    it 'explains missing server coverage without offering an installer' do
      error = Lich::AcceptedGemPolicy::CoverageError.new('missing root')
      body = described_class.build_alert_body([], error)
      expect(body).to include('release maintainer', 'reinstalling Ruby will not fix')
      expect(described_class).to receive(:alert_windows).with(body, download: false)
      described_class.alert(error: error)
    end

    it 'explains malformed policy separately from missing installed gems' do
      body = described_class.build_alert_body([], Lich::AcceptedGemPolicy::InvalidPolicyError.new('schema'))
      expect(body).to include('invalid or incompatible', 'published policy')
      expect(body).not_to include("You're missing")
    end

    it 'offers repair guidance and the installer link for a damaged local dependency' do
      error = Lich::AcceptedGemPolicy::LocalInstallationError.new('local-child is missing')
      body = described_class.build_alert_body([], error)
      expect(body).to include('missing gem dependency', 'Repair or reinstall Ruby4Lich5', 'local-child is missing')
      expect(body).not_to include('release maintainer', 'could not retrieve')
      expect(described_class).to receive(:alert_windows).with(body, download: true)
      described_class.alert(error: error)
    end

    it 'does not open a browser when a policy-only Windows notice is acknowledged' do
      allow(described_class).to receive(:require).with('win32ole').and_return(true)
      shell = double('shell')
      stub_const('WIN32OLE', Class.new)
      allow(WIN32OLE).to receive(:new).with('WScript.Shell').and_return(shell)
      expect(shell).to receive(:Popup).with('retry', described_class::ALERT_TIMEOUT_SECONDS, described_class::TITLE, 64).and_return(1)
      expect(shell).not_to receive(:Run)
      described_class.alert_windows('retry', download: false)
    end

    it 'tells the user to close other instances before consenting to native repair' do
      prompt = described_class.build_recovery_prompt([{ 'id' => 'sqlite3', 'members' => ['sqlite3'] }])
      expect(prompt).to include('Close all other Lich instances', 'native DLLs', 'restarts Lich')
      expect(prompt.index('Close all other Lich instances')).to be < prompt.index('Install now?')
    end

    it 'retains fail-closed non-Windows startup for a missing Gemfile without fetching policy' do
      allow(described_class).to receive(:self_healing_supported?).and_return(false)
      allow(described_class).to receive(:configure_gemfile!)
      allow(bundler).to receive(:definition).and_raise(Errno::ENOENT, 'Gemfile')
      expect(Lich::DependencyRecovery).not_to receive(:new)
      expect(described_class).to receive(:alert) do |missing:, groups:, error:|
        expect(missing).to be_empty
        expect(groups).to eq([:default])
        expect(error).to be_a(described_class::DeclarationError)
        expect(described_class.build_alert_body(missing, error)).to include('Restore the Gemfile')
      end
      expect { described_class.verify! }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    end
  end

  it 'logs policy failures without a misleading download link or loading Bundler on Windows' do
    stub_const('RUBY_PLATFORM', 'x64-mingw-ucrt')
    allow(described_class).to receive(:self_healing_supported?).and_return(true)
    allow(described_class).to receive(:required_dependencies).and_return([])
    expect(described_class).not_to receive(:bundler)
    described_class.write_log(error: Lich::AcceptedGemPolicy::AcquisitionError.new('offline'))
    contents = File.read(File.join(TEMP_DIR, described_class::LOG_FILENAME))
    latest = contents.split('Lich5 GemCheck failure').last
    expect(latest).to include('Check your network connection', 'Underlying error:')
    expect(latest).not_to include('Download:', "You're missing")
  end
end
