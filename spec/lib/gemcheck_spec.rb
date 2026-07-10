# spec/lib/gemcheck_spec.rb
require 'tmpdir'
require 'fileutils'

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
  describe '.startup_groups' do
    it 'checks default and GTK dependencies for a graphical launch' do
      expect(described_class.startup_groups([])).to eq(%i[default gtk])
    end

    it 'omits GTK only for an explicit no-GUI switch' do
      expect(described_class.startup_groups(['--no-gui'])).to eq([:default])
      expect(described_class.startup_groups(['--no-gtk'])).to eq([:default])
    end

    it 'does not treat unrelated arguments as a headless request' do
      expect(described_class.startup_groups(['--home=C:/Lich5'])).to eq(%i[default gtk])
    end
  end

  describe '.verify!' do
    let(:recovery_result) { Lich::DependencyRecovery::Result.new(installed_gems: []) }

    before do
      allow(described_class).to receive(:configure_gemfile!)
      allow(described_class).to receive(:self_healing_supported?).and_return(true)
      allow(described_class).to receive(:recover_with_consent!).and_return(recovery_result)
    end

    context 'when nothing is missing' do
      before { allow(described_class).to receive(:missing_gems).and_return([]) }

      it 'does not alert' do
        expect(described_class).not_to receive(:alert)
        described_class.verify!
      end

      it 'returns without exiting' do
        expect { described_class.verify! }.not_to raise_error
      end

      it 'never locks the load path via Bundler.setup' do
        expect(Bundler).not_to receive(:setup)
        described_class.verify!
      end

      it 'configures the Gemfile path before checking' do
        expect(described_class).to receive(:configure_gemfile!)
        described_class.verify!
      end

      it 'defaults to the :default group when none is given' do
        expect(described_class).to receive(:missing_gems).with([:default]).and_return([])
        described_class.verify!
      end

      it 'forwards custom groups to the detector' do
        expect(described_class).to receive(:missing_gems).with([:default, :gtk]).and_return([])
        described_class.verify!(:default, :gtk)
      end
    end

    context 'when required gems are missing' do
      before do
        allow(described_class).to receive(:missing_gems).with([:default]).and_return(['ox'])
      end

      it 'alerts with the detected list and exits 1' do
        expect(described_class).to receive(:alert)
          .with(missing: ['ox'], groups: [:default])
        expect { described_class.verify! }.to raise_error(SystemExit) do |e|
          expect(e.status).to eq(1)
        end
      end

      it 'does not lock the load path via Bundler.setup' do
        allow(described_class).to receive(:alert)
        expect(Bundler).not_to receive(:setup)
        expect { described_class.verify! }.to raise_error(SystemExit)
      end
    end

    context 'when self-healing is unsupported on the running platform' do
      before do
        allow(described_class).to receive(:missing_gems)
          .with([:default]).and_return(['ox'])
        allow(described_class).to receive(:self_healing_supported?).and_return(false)
      end

      it 'uses the ordinary missing-gem alert without fetching a manifest' do
        expect(described_class).not_to receive(:recover_with_consent!)
        expect(described_class).to receive(:alert).with(missing: ['ox'], groups: [:default])
        expect { described_class.verify! }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end

    context 'when manifest recovery restores the missing gems' do
      before do
        allow(described_class).to receive(:missing_gems)
          .with([:default]).and_return(['ox'], [])
      end

      it 'rechecks the requested groups and continues without alerting' do
        expect(described_class).to receive(:recover_with_consent!)
          .with(['ox'], groups: [:default]).and_return(recovery_result)
        expect(described_class).not_to receive(:alert)

        expect { described_class.verify! }.not_to raise_error
      end
    end

    context 'when native runtime replacement is scheduled' do
      let(:recovery_result) { Lich::DependencyRecovery::Result.new(installed_gems: [], restart_required: true) }

      before do
        allow(described_class).to receive(:missing_gems).with([:default]).and_return(['ox'])
      end

      it 'exits cleanly so the hidden helper can replace files and relaunch Lich' do
        expect { described_class.verify! }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(0)
        end
      end
    end

    context 'when manifest recovery cannot restore a detected gem' do
      let(:recovery_result) do
        Lich::DependencyRecovery::Result.new(installed_gems: [], error: 'manifest unavailable')
      end

      before do
        allow(described_class).to receive(:missing_gems)
          .with([:default]).and_return(['ox'])
      end

      it 'logs the recovery reason and exits' do
        expect(described_class).to receive(:alert) do |missing:, groups:, error:|
          expect(missing).to eq(['ox'])
          expect(groups).to eq([:default])
          expect(error.message).to eq('manifest unavailable')
        end
        expect { described_class.verify! }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end

    context 'when user consent is declined or unavailable' do
      before do
        allow(described_class).to receive(:missing_gems)
          .with([:default]).and_return(['ox'])
        allow(described_class).to receive(:recover_with_consent!).and_return(nil)
      end

      it 'exits without a second generic missing-gem dialog' do
        expect(described_class).not_to receive(:alert)
        expect { described_class.verify! }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
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
        .to include("packages now.\n\nInstall now?")
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
      allow(Bundler).to receive(:definition).and_return(definition)
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

    it 'returns an empty array when Bundler.definition raises' do
      allow(Bundler).to receive(:definition).and_raise(StandardError)
      expect(described_class.missing_gems([:default])).to eq([])
    end
  end

  describe '.all_groups' do
    it 'returns the groups from Bundler.definition' do
      allow(Bundler).to receive(:definition)
        .and_return(double('definition', groups: [:default, :development, :gtk]))
      expect(described_class.all_groups).to eq([:default, :development, :gtk])
    end

    it 'returns [:default] when Bundler.definition raises' do
      allow(Bundler).to receive(:definition).and_raise(StandardError)
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
      expect(body).not_to include('Bundler reported:')
    end

    it 'appends a bulleted list when gems are provided' do
      body = described_class.build_alert_body(%w[ox sqlite3], nil)
      expect(body).to include('Missing gems:')
      expect(body).to include('- ox')
      expect(body).to include('- sqlite3')
    end

    it 'falls back to the Bundler error when no gems were detected' do
      error = double('error', message: "Could not find gem 'transitive' in locally installed gems.")
      body = described_class.build_alert_body([], error)
      expect(body).to include('Bundler reported:')
      expect(body).to include("Could not find gem 'transitive'")
    end

    it 'prefers the detected list over the Bundler error when both are present' do
      error = double('error', message: 'some bundler message')
      body = described_class.build_alert_body(['ox'], error)
      expect(body).to include('Missing gems:')
      expect(body).not_to include('Bundler reported:')
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
                     class: Bundler::GemNotFound,
                     message: "Could not find gem 'foo' in locally installed gems.")
      described_class.write_log(error: error)
      contents = File.read(log_path)
      expect(contents).to include('Bundler error:')
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
      allow(Bundler).to receive(:definition).and_return(
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

    context 'when zenity is available' do
      before { stub_only_available('zenity') }

      it 'shows a zenity info dialog with the given body' do
        expect(described_class).to receive(:system)
          .with('zenity', '--info', '--title', described_class::TITLE, '--text', 'body text')
        described_class.alert_linux('body text')
      end
    end

    context 'when only kdialog is available' do
      before { stub_only_available('kdialog') }

      it 'shows a kdialog msgbox' do
        expect(described_class).to receive(:system)
          .with('kdialog', '--title', described_class::TITLE, '--msgbox', 'body text')
        described_class.alert_linux('body text')
      end
    end

    context 'when only xmessage is available' do
      before { stub_only_available('xmessage') }

      it 'shows an xmessage dialog' do
        expect(described_class).to receive(:system)
          .with('xmessage', '-center', 'body text')
        described_class.alert_linux('body text')
      end
    end

    context 'when no dialog tool is available' do
      before { allow(described_class).to receive(:cmd_available?).and_return(false) }

      it 'falls back to warn' do
        expect(described_class).to receive(:warn).with(/!!ALERT!!/)
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
end
