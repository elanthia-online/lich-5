require 'tmpdir'
require 'fileutils'

# TEMP_DIR is referenced by GemCheck#write_log; it must exist before that
# method runs. Constants are resolved at call time (not require time),
# so defining it here in the spec is sufficient.
TEMP_DIR = Dir.mktmpdir('lich-gemcheck-spec') unless defined?(TEMP_DIR)

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

  describe '.write_log' do
    let(:log_path) { File.join(TEMP_DIR, described_class::LOG_FILENAME) }

    before { FileUtils.rm_f(log_path) }
    after  { FileUtils.rm_f(log_path) }

    it 'writes the message and URL to TEMP_DIR' do
      described_class.write_log
      contents = File.read(log_path)
      expect(contents).to include('Missing required Ruby gems')
      expect(contents).to include(described_class::RELEASE_URL)
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
    let(:url) { described_class::RELEASE_URL }

    def stub_only_available(tool)
      allow(described_class).to receive(:cmd_available?).and_return(false)
      allow(described_class).to receive(:cmd_available?).with(tool).and_return(true)
    end

    context 'when zenity is available' do
      before { stub_only_available('zenity') }

      it 'prompts with zenity and opens the URL on confirmation' do
        expect(described_class).to receive(:system)
          .with('zenity', '--question', '--title', described_class::TITLE, '--text', kind_of(String))
          .and_return(true)
        expect(described_class).to receive(:system).with('xdg-open', url)
        described_class.alert_linux
      end

      it 'does not open the URL when the user declines' do
        allow(described_class).to receive(:system)
          .with('zenity', any_args).and_return(false)
        expect(described_class).not_to receive(:system).with('xdg-open', anything)
        described_class.alert_linux
      end
    end

    context 'when only kdialog is available' do
      before { stub_only_available('kdialog') }

      it 'prompts with kdialog' do
        expect(described_class).to receive(:system)
          .with('kdialog', '--title', described_class::TITLE, '--yesno', kind_of(String))
          .and_return(true)
        allow(described_class).to receive(:system).with('xdg-open', anything)
        described_class.alert_linux
      end
    end

    context 'when only xmessage is available' do
      before { stub_only_available('xmessage') }

      it 'shows xmessage and does not open a URL' do
        expect(described_class).to receive(:system)
          .with('xmessage', '-center', kind_of(String))
        expect(described_class).not_to receive(:system).with('xdg-open', anything)
        described_class.alert_linux
      end
    end

    context 'when no dialog tool is available' do
      before { allow(described_class).to receive(:cmd_available?).and_return(false) }

      it 'falls back to warn' do
        expect(described_class).to receive(:warn).at_least(:once)
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
