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
  describe '.verify!' do
    context 'when Bundler.setup succeeds' do
      before { allow(Bundler).to receive(:setup) }

      it 'does not alert' do
        expect(described_class).not_to receive(:alert)
        described_class.verify!
      end

      it 'passes :default when no groups are given' do
        expect(Bundler).to receive(:setup).with(:default)
        described_class.verify!
      end

      it 'forwards custom groups to Bundler.setup' do
        expect(Bundler).to receive(:setup).with(:default, :production)
        described_class.verify!(:default, :production)
      end
    end

    context 'when Bundler.setup raises' do
      before { allow(described_class).to receive(:alert) }

      it 'alerts and exits 1 on GemNotFound' do
        allow(Bundler).to receive(:setup).and_raise(Bundler::GemNotFound)
        expect(described_class).to receive(:alert)
        expect { described_class.verify! }.to raise_error(SystemExit) do |e|
          expect(e.status).to eq(1)
        end
      end

      it 'alerts and exits 1 on GitError' do
        allow(Bundler).to receive(:setup).and_raise(Bundler::GitError)
        expect(described_class).to receive(:alert)
        expect { described_class.verify! }.to raise_error(SystemExit) do |e|
          expect(e.status).to eq(1)
        end
      end
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

  describe '.write_log' do
    let(:log_path) { File.join(TEMP_DIR, described_class::LOG_FILENAME) }

    before { FileUtils.rm_f(log_path) }
    after  { FileUtils.rm_f(log_path) }

    it 'writes the platform message to TEMP_DIR' do
      described_class.write_log
      expect(File.read(log_path)).to include('Missing required Ruby gems')
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
      expect(File.read(log_path).scan('Missing required Ruby gems').size).to eq(2)
    end

    it 'swallows filesystem errors silently' do
      allow(File).to receive(:open).and_raise(Errno::EACCES)
      expect { described_class.write_log }.not_to raise_error
    end
  end

  describe '.alert_linux' do
    def stub_only_available(tool)
      allow(described_class).to receive(:cmd_available?).and_return(false)
      allow(described_class).to receive(:cmd_available?).with(tool).and_return(true)
    end

    context 'when zenity is available' do
      before { stub_only_available('zenity') }

      it 'shows a zenity info dialog' do
        expect(described_class).to receive(:system)
          .with('zenity', '--info', '--title', described_class::TITLE,
                '--text', described_class::UNIX_MESSAGE)
        described_class.alert_linux
      end
    end

    context 'when only kdialog is available' do
      before { stub_only_available('kdialog') }

      it 'shows a kdialog msgbox' do
        expect(described_class).to receive(:system)
          .with('kdialog', '--title', described_class::TITLE,
                '--msgbox', described_class::UNIX_MESSAGE)
        described_class.alert_linux
      end
    end

    context 'when only xmessage is available' do
      before { stub_only_available('xmessage') }

      it 'shows an xmessage dialog' do
        expect(described_class).to receive(:system)
          .with('xmessage', '-center', described_class::UNIX_MESSAGE)
        described_class.alert_linux
      end
    end

    context 'when no dialog tool is available' do
      before { allow(described_class).to receive(:cmd_available?).and_return(false) }

      it 'falls back to warn with the unix message' do
        expect(described_class).to receive(:warn).with(/bundle install/)
        described_class.alert_linux
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
