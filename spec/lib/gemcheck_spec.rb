# spec/lib/gemcheck_spec.rb
require 'tmpdir'
require 'fileutils'

# TEMP_DIR is referenced by GemCheck#write_log; it must exist before that
# method runs. Constants are resolved at call time (not require time),
# so defining it here in the spec is sufficient.
TEMP_DIR = Dir.mktmpdir('lich-gemcheck-spec') unless defined?(TEMP_DIR)

require_relative '../../lib/gemcheck'

RSpec.describe Lich::GemCheck do
  describe '.verify!' do
    let(:settings) { double('settings') }

    before do
      allow(Bundler).to receive(:settings).and_return(settings)
      allow(settings).to receive(:temporary).and_yield
      allow(Bundler).to receive(:definition).with(true)
      allow(described_class).to receive(:all_groups)
        .and_return([:default, :development, :gtk])
    end

    context 'when nothing is missing and Bundler.setup succeeds' do
      before do
        allow(described_class).to receive(:missing_gems).and_return([])
        allow(Bundler).to receive(:setup)
      end

      it 'does not alert' do
        expect(described_class).not_to receive(:alert)
        described_class.verify!
      end

      it 'passes :default when no groups are given' do
        expect(Bundler).to receive(:setup).with(:default)
        described_class.verify!
      end

      it 'forwards custom groups to Bundler.setup' do
        expect(Bundler).to receive(:setup).with(:default, :gtk)
        described_class.verify!(:default, :gtk)
      end

      it 'excludes non-requested groups via Bundler.settings.temporary' do
        expect(settings).to receive(:temporary)
          .with(without: %w[development gtk]).and_yield
        described_class.verify!(:default)
      end

      it 'forces definition rebuild under the temporary settings' do
        expect(Bundler).to receive(:definition).with(true)
        described_class.verify!(:default)
      end
    end

    context 'when our detector finds missing gems in scope' do
      before do
        allow(described_class).to receive(:missing_gems)
          .with([:default]).and_return(['ox'])
      end

      it 'alerts with the detected list and exits 1 before calling Bundler.setup' do
        expect(described_class).to receive(:alert)
          .with(missing: ['ox'], groups: [:default])
        expect(Bundler).not_to receive(:setup)
        expect { described_class.verify! }.to raise_error(SystemExit) do |e|
          expect(e.status).to eq(1)
        end
      end
    end

    context 'when Bundler.setup raises for an in-scope gem' do
      before do
        allow(described_class).to receive(:missing_gems)
          .with([:default]).and_return([], ['transitive-gem'])
        allow(described_class).to receive(:bundler_error_out_of_scope?)
          .and_return(false)
      end

      it 'alerts and exits 1 on GemNotFound' do
        error = Bundler::GemNotFound.new("Could not find gem 'transitive-gem'")
        allow(Bundler).to receive(:setup).and_raise(error)
        expect(described_class).to receive(:alert)
          .with(missing: ['transitive-gem'], groups: [:default], error: error)
        expect { described_class.verify! }.to raise_error(SystemExit) do |e|
          expect(e.status).to eq(1)
        end
      end

      it 'alerts and exits 1 on GitError' do
        error = Bundler::GitError.new('git clone failed')
        allow(Bundler).to receive(:setup).and_raise(error)
        expect(described_class).to receive(:alert)
          .with(missing: ['transitive-gem'], groups: [:default], error: error)
        expect { described_class.verify! }.to raise_error(SystemExit) do |e|
          expect(e.status).to eq(1)
        end
      end
    end

    context 'when Bundler.setup raises for an out-of-scope gem' do
      before do
        allow(described_class).to receive(:missing_gems)
          .with([:default]).and_return([])
        allow(described_class).to receive(:bundler_error_out_of_scope?)
          .and_return(true)
      end

      it 'silently continues without alerting or exiting' do
        allow(Bundler).to receive(:setup)
          .and_raise(Bundler::GemNotFound.new("Could not find gem 'rspec'"))
        expect(described_class).not_to receive(:alert)
        expect { described_class.verify! }.not_to raise_error
      end

      it 'does not write to the log' do
        allow(Bundler).to receive(:setup)
          .and_raise(Bundler::GemNotFound.new("Could not find gem 'rspec'"))
        expect(described_class).not_to receive(:write_log)
        described_class.verify!
      end
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

  describe '.bundler_error_out_of_scope?' do
    let(:dev_dep) { double('dep', name: 'rspec', groups: [:development]) }
    let(:default_dep) { double('dep', name: 'ox', groups: [:default]) }
    let(:definition) { double('definition', current_dependencies: [dev_dep, default_dep]) }

    before { allow(Bundler).to receive(:definition).and_return(definition) }

    it 'returns true when the errored gem is in a non-requested group' do
      error = double('error', message: "Could not find gem 'rspec' in locally installed gems.")
      expect(described_class.bundler_error_out_of_scope?(error, [:default])).to be(true)
    end

    it 'returns false when the errored gem is in a requested group' do
      error = double('error', message: "Could not find gem 'ox' in locally installed gems.")
      expect(described_class.bundler_error_out_of_scope?(error, [:default])).to be(false)
    end

    it 'returns false when the errored gem is unknown to the Gemfile' do
      error = double('error', message: "Could not find gem 'not-in-gemfile' in locally installed gems.")
      expect(described_class.bundler_error_out_of_scope?(error, [:default])).to be(false)
    end

    it 'returns false when the gem name cannot be extracted' do
      error = double('error', message: 'some unexpected error format')
      expect(described_class.bundler_error_out_of_scope?(error, [:default])).to be(false)
    end
  end

  describe '.extract_gem_name' do
    it 'extracts from the standard "Could not find gem" message' do
      msg = "Could not find gem 'rspec' in locally installed gems."
      expect(described_class.extract_gem_name(msg)).to eq('rspec')
    end

    it 'extracts from the variant without the word "gem"' do
      msg = "Could not find 'rspec' in any of the sources"
      expect(described_class.extract_gem_name(msg)).to eq('rspec')
    end

    it 'extracts from double-quoted variants' do
      msg = 'Could not find gem "rspec" in locally installed gems.'
      expect(described_class.extract_gem_name(msg)).to eq('rspec')
    end

    it 'returns nil when no gem name is present' do
      expect(described_class.extract_gem_name('some other error')).to be_nil
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
      expect(File.read(log_path)).to include('Missing required Ruby gems')
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
