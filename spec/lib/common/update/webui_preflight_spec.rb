# frozen_string_literal: true

require_relative 'update_spec_helper'

# Browser discovery is answered from the +installed+ and +snaps+ lists, so the
# examples do not depend on what the machine running them has installed.
# Paths under +tmpdir+ are real files and get the real file tests.
RSpec.describe Lich::Util::Update::WebUIPreflight do
  let(:tmpdir) { Dir.mktmpdir('webui-preflight') }
  let(:launcher) { described_class.launcher }
  let(:installed) { [] }
  let(:snaps) { [] }
  let(:toolchain) { [false] }
  let(:chrome_linux) { '/usr/bin/google-chrome' }
  let(:chrome_macos) { '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' }
  let(:windows_environment) { { 'PROGRAMFILES' => 'C:/Program Files', 'LOCALAPPDATA' => 'C:/Users/me/AppData/Local' } }

  before do
    allow(launcher).to receive(:executable_file?).and_wrap_original do |original, path|
      installed.include?(path) || (path.start_with?(tmpdir) && original.call(path))
    end
    allow(launcher).to receive(:snap_browser?) { |path, **| snaps.include?(path) }
    allow(described_class).to receive(:swift_toolchain?) { toolchain.first }
  end

  after { FileUtils.remove_entry(tmpdir, true) }

  # A real file, also listed as installed: Windows only takes a file for an
  # executable by its extension, which a macOS bundle's executable lacks.
  def executable(name = 'chrome.exe')
    path = File.join(tmpdir, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, '')
    File.chmod(0o755, path)
    installed << path
    path
  end

  def refusal(platform, environment = {})
    described_class.refusal(platform: platform, environment: environment)
  end

  describe '.headless_session?' do
    it 'is true for a session started without windows, under either spelling of the option' do
      expect(described_class.headless_session?(argv: ['--login', 'Someone', '--no-gui'])).to be(true)
      expect(described_class.headless_session?(argv: ['--NO-GTK'])).to be(true)
    end

    it 'is not fooled by an option that only starts the same way' do
      expect(described_class.headless_session?(argv: ['--no-guild', '--gui'])).to be(false)
      expect(described_class.headless_session?(argv: [])).to be(false)
    end

    it 'does not change the answer about the computer, which windowed sessions share' do
      stub_const('ARGV', ['--no-gui'])

      expect(refusal('linux')).to match(/Google Chrome or Chromium is required/)
    end
  end

  describe 'on Linux' do
    it 'refuses when no browser is installed, naming what is needed and the variable' do
      expect(refusal('linux')).to eq(
        'Google Chrome or Chromium is required to open the WebUI launcher window; install it, ' \
        'or set the LICH_WEBUI_BROWSER environment variable to another browser'
      )
    end

    it 'accepts Google Chrome' do
      installed << chrome_linux

      expect(refusal('linux')).to be_nil
    end

    it 'accepts distro Chromium, and Chromium found on PATH' do
      installed << '/usr/bin/chromium'
      expect(refusal('linux')).to be_nil

      installed.replace(['/opt/tools/chromium-browser'])
      expect(refusal('linux', { 'PATH' => '/opt/tools' })).to be_nil
    end

    it 'refuses snap-packaged Chromium and says a non-snap browser is needed' do
      installed << '/usr/bin/chromium-browser'
      snaps << '/usr/bin/chromium-browser'

      expect(refusal('linux')).to eq(
        "the discovered browser '/usr/bin/chromium-browser' is unusable: snap-packaged Chromium cannot open the WebUI " \
        'launch files; set the LICH_WEBUI_BROWSER environment variable to a non-snap Chrome or Chromium'
      )
    end

    it 'refuses when only Firefox is installed' do
      installed.push('/usr/bin/firefox', '/opt/tools/firefox')

      expect(refusal('linux', { 'PATH' => '/usr/bin:/opt/tools' })).to match(/Google Chrome or Chromium is required/)
    end

    it 'does not count a browser saved in the launcher settings, which script windows do not use' do
      db = double('db', get_first_value: '/opt/brave/brave')
      allow(Lich).to receive(:db).and_return(db)
      installed << '/opt/brave/brave'

      expect(refusal('linux')).to match(/Google Chrome or Chromium is required/)
      expect(db).not_to have_received(:get_first_value)
    end
  end

  describe 'on Windows' do
    it 'refuses when neither Chrome nor Edge is installed' do
      expect(refusal('x64-mingw-ucrt', windows_environment)).to eq(
        'Google Chrome or Microsoft Edge is required to open the WebUI launcher window; install it, ' \
        'or set the LICH_WEBUI_BROWSER environment variable to another browser'
      )
    end

    it 'accepts Chrome or Edge under an installation root' do
      installed << 'C:/Users/me/AppData/Local/Google/Chrome/Application/chrome.exe'
      expect(refusal('x64-mingw-ucrt', windows_environment)).to be_nil

      installed.replace(['C:/Program Files/Microsoft/Edge/Application/msedge.exe'])
      expect(refusal('x64-mingw-ucrt', windows_environment)).to be_nil
    end
  end

  describe 'on macOS' do
    it 'accepts a Mac that can build the window helper, with no browser at all' do
      toolchain[0] = true

      expect(refusal('darwin')).to be_nil
    end

    it 'accepts Google Chrome in place of the helper' do
      installed << chrome_macos

      expect(refusal('darwin')).to be_nil
    end

    it 'accepts Chromium in place of the helper, as the beta does' do
      installed << '/Applications/Chromium.app/Contents/MacOS/Chromium'

      expect(refusal('darwin')).to be_nil
    end

    it 'refuses with neither, naming the compiler and the browsers' do
      expect(refusal('darwin')).to include('needs the Swift compiler', 'xcode-select --install', 'Google Chrome or Chromium')
    end

    it 'does not count a helper built for the running Lich, which an update removes' do
      installed << Lich::WebUI::NativeHost::EXECUTABLE

      expect(refusal('darwin')).to be_a(String)
    end

    it 'does not count the browser saved in the launcher settings, which startup never reaches' do
      brave = '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'
      allow(Lich).to receive(:db).and_return(double('db', get_first_value: brave))
      installed << brave

      expect(refusal('darwin')).to be_a(String)
    end
  end

  describe 'with LICH_WEBUI_BROWSER set' do
    it 'accepts an executable file on every platform, without any other requirement' do
      environment = { 'LICH_WEBUI_BROWSER' => executable }

      %w[linux darwin x64-mingw-ucrt].each { |platform| expect(refusal(platform, environment)).to be_nil }
    end

    it 'refuses a path that does not exist, even when a browser could be discovered' do
      installed.push(chrome_linux, chrome_macos)
      toolchain[0] = true
      missing = File.join(tmpdir, 'gone.exe')

      %w[linux darwin].each do |platform|
        expect(refusal(platform, { 'LICH_WEBUI_BROWSER' => missing })).to eq(
          "LICH_WEBUI_BROWSER names '#{missing}', which does not exist; fix or unset LICH_WEBUI_BROWSER"
        )
      end
    end

    it 'refuses a path that is not an executable file' do
      expect(refusal('linux', { 'LICH_WEBUI_BROWSER' => tmpdir })).to eq(
        "LICH_WEBUI_BROWSER names '#{tmpdir}', which is not an executable file; fix or unset LICH_WEBUI_BROWSER"
      )
    end

    it 'refuses snap-packaged Chromium' do
      path = executable
      snaps << path

      expect(refusal('linux', { 'LICH_WEBUI_BROWSER' => path })).to include('snap-packaged Chromium cannot open the WebUI launch files')
    end

    it 'treats a blank value as unset' do
      installed << chrome_linux

      expect(refusal('linux', { 'LICH_WEBUI_BROWSER' => '  ' })).to be_nil
    end

    context 'when it names a macOS application bundle' do
      let(:bundle) { File.join(tmpdir, 'Brave Browser.app') }

      def write_plist(content)
        FileUtils.mkdir_p(File.join(bundle, 'Contents'))
        File.binwrite(File.join(bundle, 'Contents', 'Info.plist'), content)
      end

      def xml_plist(name)
        "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>CFBundleExecutable</key><string>#{name}</string></dict></plist>"
      end

      it 'accepts the bundle when its Info.plist names an executable inside it' do
        write_plist(xml_plist('Brave Browser'))
        executable('Brave Browser.app/Contents/MacOS/Brave Browser')

        expect(refusal('darwin', { 'LICH_WEBUI_BROWSER' => "#{bundle}/" })).to be_nil
      end

      it 'reads a binary Info.plist through plutil' do
        write_plist("bplist00\x00\x01\x02")
        executable('Brave Browser.app/Contents/MacOS/Brave Browser')
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3)
          .with('/usr/bin/plutil', '-extract', 'CFBundleExecutable', 'raw', '--', File.join(bundle, 'Contents', 'Info.plist'))
          .and_return(["Brave Browser\n", '', status])

        expect(refusal('darwin', { 'LICH_WEBUI_BROWSER' => bundle })).to be_nil
      end

      it 'refuses a bundle whose named executable is missing' do
        write_plist(xml_plist('Brave Browser'))

        expect(refusal('darwin', { 'LICH_WEBUI_BROWSER' => bundle })).to eq(
          "LICH_WEBUI_BROWSER names '#{bundle}', which has no executable; fix or unset LICH_WEBUI_BROWSER"
        )
      end

      it 'refuses a bundle whose Info.plist points outside it' do
        write_plist(xml_plist('../../../chrome.exe'))
        executable

        expect(refusal('darwin', { 'LICH_WEBUI_BROWSER' => bundle })).to include('which has no executable')
      end

      it 'refuses a bundle with no Info.plist' do
        FileUtils.mkdir_p(bundle)

        expect(refusal('darwin', { 'LICH_WEBUI_BROWSER' => bundle })).to include('which has no executable')
      end

      it 'is an ordinary path, and so not an executable file, on other platforms' do
        write_plist(xml_plist('Brave Browser'))
        executable('Brave Browser.app/Contents/MacOS/Brave Browser')

        expect(refusal('linux', { 'LICH_WEBUI_BROWSER' => bundle })).to include('which is not an executable file')
      end
    end
  end

  it 'only reads: it starts no build and opens no window' do
    allow(Process).to receive(:spawn)
    allow(described_class).to receive(:system)
    allow(launcher).to receive(:open)
    allow(Lich::WebUI::NativeHost).to receive(:command_for)

    %w[linux darwin x64-mingw-ucrt].each do |platform|
      [[], [chrome_linux, chrome_macos]].each do |browsers|
        installed.replace(browsers)
        [false, true].each do |compiler|
          toolchain[0] = compiler
          refusal(platform, windows_environment)
        end
      end
    end

    expect(Process).not_to have_received(:spawn)
    expect(described_class).not_to have_received(:system)
    expect(launcher).not_to have_received(:open)
    expect(Lich::WebUI::NativeHost).not_to have_received(:command_for)
    expect(Dir.children(tmpdir)).to be_empty
  end

  it 'checks the running platform when none is given' do
    expect(described_class.refusal(environment: {})).to be_a(String)
  end

  describe '.swift_toolchain?' do
    let(:succeeded) { instance_double(Process::Status, success?: true) }

    before { allow(described_class).to receive(:swift_toolchain?).and_call_original }

    it 'finds the compiler where the Command Line Tools keep it' do
      allow(Open3).to receive(:capture2e).with('/usr/bin/xcode-select', '-p').and_return(["/Library/Developer/CommandLineTools\n", succeeded])
      installed << '/Library/Developer/CommandLineTools/usr/bin/swiftc'

      expect(described_class.swift_toolchain?).to be(true)
    end

    it 'finds the compiler where Xcode keeps it' do
      allow(Open3).to receive(:capture2e).and_return(["/Applications/Xcode.app/Contents/Developer\n", succeeded])
      installed << '/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'

      expect(described_class.swift_toolchain?).to be(true)
    end

    it 'is false when the developer directory has no compiler' do
      allow(Open3).to receive(:capture2e).and_return(["/Library/Developer/CommandLineTools\n", succeeded])

      expect(described_class.swift_toolchain?).to be(false)
    end

    it 'is false when no developer directory is selected' do
      allow(Open3).to receive(:capture2e).and_return(["xcode-select: error: unable to get active developer directory\n", instance_double(Process::Status, success?: false)])

      expect(described_class.swift_toolchain?).to be(false)
    end

    it 'is false where xcode-select does not exist' do
      allow(Open3).to receive(:capture2e).and_raise(Errno::ENOENT)

      expect(described_class.swift_toolchain?).to be(false)
    end
  end
end
