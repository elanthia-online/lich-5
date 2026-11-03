# frozen_string_literal: true

require_relative '../../spec_helper'
require 'tmpdir'
require 'webui/browser_launcher'

# A user-set browser path (for example Chromium) is accepted and launched with an
# isolated profile; a path that cannot run fails at open time with a message that
# names the setting. LICH_WEBUI_BROWSER and Linux Chromium discovery give a host
# without Chrome a route to a window. Snap-packaged Chromium cannot read the launch
# file in its private /tmp, so discovery skips it and an explicit path naming it is
# refused. Environments are injected, never the real ENV. Snap browsers are
# stand-in files in a tmpdir. File tests only, so the examples hold on Windows as well.
RSpec.describe Lich::WebUI::BrowserLauncher, 'configured browser path' do
  let(:url) { "http://127.0.0.1:4567/auth?token=#{'f' * 64}&to=%2F" }
  let(:directory) { Dir.mktmpdir('webui-browser-path') }
  let(:logs) { [] }
  let(:failures) { [] }
  let(:chromium) do
    File.join(directory, 'chromium.exe').tap do |path|
      File.write(path, '')
      File.chmod(0o755, path)
    end
  end

  # Windows decides executability by extension, so the stand-in carries .exe there.
  let(:snap_wrapper) do
    File.join(directory, OS.windows? ? 'chromium-browser.exe' : 'chromium-browser').tap do |path|
      File.write(path, "#!/bin/sh\nexec /snap/bin/chromium \"$@\"\n")
      File.chmod(0o755, path)
    end
  end

  before { allow(Lich).to receive(:log) { |message| logs << message } }

  # Makes discovery see one conventional path as an installed browser file.
  # Only the named browser exists: every other fixed candidate reads as absent, so a
  # browser installed on the host (CI images ship Chrome) cannot answer discovery.
  def pretend_installed(path)
    allow(File).to receive(:executable?).and_call_original
    allow(File).to receive(:file?).and_call_original
    (described_class::MACOS_PATHS + described_class::LINUX_PATHS + described_class::LINUX_CHROMIUM_PATHS).each do |candidate|
      allow(File).to receive(:executable?).with(candidate).and_return(candidate == path)
      allow(File).to receive(:file?).with(candidate).and_return(candidate == path)
    end
    allow(File).to receive(:executable?).with(path).and_return(true)
    allow(File).to receive(:file?).with(path).and_return(true)
  end

  after { FileUtils.remove_entry(directory) if File.directory?(directory) }

  def open_with(**options)
    described_class.open(url, on_failure: ->(message) { failures << message }, environment: {},
                              thread_factory: ->(&work) { work.call }, waitpid: ->(_pid, _flags) {}, **options)
  end

  it 'launches a configured Chromium with an isolated profile and removes the profile after exit' do
    argv = nil
    profile = nil
    spawn = lambda do |*arguments, **_options|
      argv = arguments
      profile = arguments.find { |argument| argument.start_with?('--user-data-dir=') }.delete_prefix('--user-data-dir=')
      expect(File.directory?(profile)).to be(true)
      4242
    end

    expect(open_with(browser_path: chromium, platform: 'x86_64-linux', spawn: spawn)).to be(true)
    expect(argv.first).to eq(chromium)
    expect(argv).to include('--new-window', '--no-first-run', '--no-default-browser-check')
    expect(argv.last).to start_with('--app=file://')
    expect(File.exist?(profile)).to be(false)
    expect(failures).to be_empty
  end

  it 'refuses a browser path that does not exist, naming the setting, without spawning' do
    missing = File.join(directory, 'absent', 'chromium')
    expect(Dir).not_to receive(:mktmpdir)

    expect(open_with(browser_path: missing, platform: 'x86_64-linux', spawn: ->(*) { raise 'must not spawn' })).to be(false)
    expect(failures.size).to eq(1)
    expect(failures.first).to include('unable to open WebUI window', "'#{missing}' does not exist", 'Browser path', 'Settings')
    expect(failures.first).not_to include('ENOENT', 'Errno')
  end

  it 'refuses a browser path that is not an executable file, naming the setting' do
    plain = File.join(directory, 'notes.txt')
    File.write(plain, '')
    File.chmod(0o644, plain)

    [plain, directory].each do |path|
      failures.clear
      expect(open_with(browser_path: path, platform: 'x86_64-linux', spawn: ->(*) { raise 'must not spawn' })).to be(false)
      expect(failures.first).to include("'#{path}' is not an executable file", 'Browser path', 'Settings')
    end
  end

  it 'applies the same check to the legacy chrome_path alias' do
    missing = File.join(directory, 'absent')

    expect(open_with(chrome_path: missing, platform: 'x86_64-linux', spawn: ->(*) { raise 'must not spawn' })).to be(false)
    expect(failures.first).to include("'#{missing}' does not exist")
  end

  it 'does not echo control characters from the configured path' do
    expect(open_with(browser_path: "/nope/chro\nmium", platform: 'x86_64-linux', spawn: ->(*) {})).to be(false)
    expect(failures.first).to include("'/nope/chro?mium'")
    expect(failures.first).not_to include("\n")
  end

  it 'names the setting when automatic discovery finds no browser' do
    allow(File).to receive(:executable?).and_return(false)

    expect(open_with(platform: 'x86_64-linux', spawn: ->(*) { raise 'must not spawn' })).to be(false)
    expect(failures.first).to include('Google Chrome or Chromium is required', 'Browser path', 'Settings',
                                      'LICH_WEBUI_BROWSER')
  end

  it 'refuses a snap-packaged browser path, naming the setting and LICH_WEBUI_BROWSER, without spawning' do
    snap_wrapper # created before launch directories are watched
    expect(Dir).not_to receive(:mktmpdir)

    expect(open_with(browser_path: snap_wrapper, platform: 'x86_64-linux', spawn: ->(*) { raise 'must not spawn' })).to be(false)
    expect(failures.size).to eq(1)
    expect(failures.first).to include("'#{snap_wrapper}'", 'snap-packaged Chromium cannot open the WebUI launch files',
                                      'Browser path', 'Settings', 'non-snap Chrome or Chromium', 'LICH_WEBUI_BROWSER')
  end

  it 'leaves automatic discovery unchanged when no path is set' do
    detected = '/usr/bin/google-chrome'
    pretend_installed(detected)
    argv = nil

    expect(open_with(platform: 'x86_64-linux', spawn: ->(*arguments, **) { (argv = arguments) && 7 })).to be(true)
    expect(argv.first).to eq(detected)
  end

  describe 'Linux Chromium discovery' do
    let(:linux) { 'x86_64-linux' }
    let(:chrome) { '/usr/bin/google-chrome' }

    def discover(present, platform: linux, environment: {})
      described_class.app_browser_path(platform: platform, environment: environment,
                                       executable: ->(path) { present.include?(path) }, snap: ->(_path) { false })
    end

    # Discovery over stand-in files in the tmpdir only, with the real admission
    # and snap probes, so browsers installed on the host cannot answer.
    def discover_in_directory(environment)
      described_class.app_browser_path(
        platform: linux, environment: environment,
        executable: ->(path) { path.start_with?(directory) && described_class.executable_file?(path) }
      )
    end

    def stand_in(*parts, content: '')
      File.join(directory, *parts).tap do |path|
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
        File.chmod(0o755, path)
      end
    end

    it 'discovers distro Chromium on a Chromium-only host' do
      %w[/usr/bin/chromium /usr/bin/chromium-browser].each do |path|
        expect(discover([path])).to eq(path)
      end
    end

    it 'never discovers /snap/bin/chromium, by list or by PATH' do
      snap = '/snap/bin/chromium'
      expect(described_class::LINUX_CHROMIUM_PATHS).not_to include(snap)
      expect(described_class.snap_browser?(snap)).to be(true)
      expect(described_class.app_browser_path(platform: linux, environment: { 'PATH' => '/snap/bin' },
                                              executable: ->(path) { path == snap })).to be_nil
    end

    it 'skips a script wrapper that execs snap Chromium and finds a later non-snap Chromium' do
      skip 'Linux PATH discovery: extensionless stand-ins are never executable on Windows' if OS.windows?
      wrapper = stand_in('wrap', 'chromium', content: "#!/bin/sh\nexec /snap/bin/chromium \"$@\"\n")
      real = stand_in('real', 'chromium', content: "\x7FELF")
      path = [File.dirname(wrapper), File.dirname(real)].join(File::PATH_SEPARATOR)

      expect(described_class.snap_browser?(wrapper)).to be(true)
      expect(described_class.snap_browser?(real)).to be(false)
      expect(discover_in_directory('PATH' => path)).to eq(real)
      expect(discover_in_directory('PATH' => File.dirname(wrapper))).to be_nil
    end

    it 'flags a candidate that resolves under /snap/ or to the snap launcher' do
      plain = stand_in('bin', 'chromium')

      expect(described_class.snap_browser?(plain, realpath: ->(_) { '/snap/chromium/3000/usr/lib/chromium/chrome' }))
        .to be(true)
      expect(described_class.snap_browser?(plain, realpath: ->(_) { '/usr/bin/snap' })).to be(true)
      expect(described_class.snap_browser?(plain, realpath: ->(_) { '/usr/lib/chromium/chromium' })).to be(false)
    end

    it 'does not read a large file or a script without a /snap/ path as a snap wrapper' do
      large = stand_in('large', 'chromium', content: "#!/bin/sh\n# /snap/\n#{'x' * described_class::SNAP_WRAPPER_LIMIT}")
      distro = stand_in('distro', 'chromium', content: "#!/bin/sh\nexec /usr/lib/chromium/chromium \"$@\"\n")

      expect(described_class.snap_browser?(large)).to be(false)
      expect(described_class.snap_browser?(distro)).to be(false)
    end

    it 'skips a directory named chromium on PATH and finds a later executable' do
      skip 'Linux PATH discovery: extensionless stand-ins are never executable on Windows' if OS.windows?
      FileUtils.mkdir_p(File.join(directory, 'dirs', 'chromium'))
      real = stand_in('real', 'chromium')
      path = [File.join(directory, 'dirs'), File.dirname(real)].join(File::PATH_SEPARATOR)

      expect(described_class.executable_file?(File.join(directory, 'dirs', 'chromium'))).to be(false)
      expect(discover_in_directory('PATH' => path)).to eq(real)
    end

    it 'falls back to a PATH lookup for chromium and chromium-browser' do
      environment = { 'PATH' => "relative/bin#{File::PATH_SEPARATOR}/opt/bin#{File::PATH_SEPARATOR}/home/u/bin" }

      expect(discover(['/opt/bin/chromium'], environment: environment)).to eq('/opt/bin/chromium')
      expect(discover(['/home/u/bin/chromium-browser'], environment: environment)).to eq('/home/u/bin/chromium-browser')
      expect(discover(['relative/bin/chromium'], environment: environment)).to be_nil
    end

    it 'prefers Chrome over Chromium when both exist' do
      expect(discover([chrome, '/usr/bin/chromium'])).to eq(chrome)
      expect(discover(['/usr/bin/chromium', '/opt/google/chrome/google-chrome'])).to eq('/opt/google/chrome/google-chrome')
    end

    it 'adds no Chromium discovery on macOS or Windows' do
      environment = { 'PATH' => '/usr/bin', 'PROGRAMFILES' => 'C:/Program Files' }

      expect(discover(['/usr/bin/chromium', '/usr/bin/chromium-browser'], platform: 'arm64-darwin24',
                                                                          environment: environment)).to be_nil
      expect(discover(['/usr/bin/chromium'], platform: 'x64-mingw-ucrt', environment: environment)).to be_nil
    end

    it 'launches a Chromium-only host through open' do
      chromium = '/usr/bin/chromium'
      pretend_installed(chromium)
      allow(described_class).to receive(:snap_browser?).and_return(false)
      argv = nil

      expect(open_with(platform: linux, spawn: ->(*arguments, **) { (argv = arguments) && 7 })).to be(true)
      expect(argv.first).to eq(chromium)
      expect(failures).to be_empty
    end
  end

  describe 'LICH_WEBUI_BROWSER' do
    let(:variable) { 'LICH_WEBUI_BROWSER' }
    let(:other) do
      File.join(directory, 'other-browser').tap do |path|
        File.write(path, '')
        File.chmod(0o755, path)
      end
    end

    def spawned_argv(**options)
      argv = nil
      result = open_with(platform: 'x86_64-linux', spawn: ->(*arguments, **) { (argv = arguments) && 7 }, **options)
      [result, argv]
    end

    it 'overrides automatic discovery' do
      pretend_installed('/usr/bin/google-chrome')

      result, argv = spawned_argv(environment: { variable => chromium })
      expect(result).to be(true)
      expect(argv.first).to eq(chromium)
      expect(argv).to include('--new-window', '--no-first-run')
    end

    it 'yields to an explicit browser path argument' do
      result, argv = spawned_argv(browser_path: chromium, environment: { variable => other })
      expect(result).to be(true)
      expect(argv.first).to eq(chromium)

      _, legacy = spawned_argv(chrome_path: chromium, environment: { variable => other })
      expect(legacy.first).to eq(chromium)
    end

    it 'ignores an empty or blank value and keeps automatic discovery' do
      detected = '/usr/bin/google-chrome'
      pretend_installed(detected)

      ['', '  '].each do |value|
        _, argv = spawned_argv(environment: { variable => value })
        expect(argv.first).to eq(detected)
      end
    end

    it 'fails an unusable value with a message naming the variable, without spawning' do
      missing = File.join(directory, 'absent', 'chromium')
      expect(Dir).not_to receive(:mktmpdir)

      expect(open_with(platform: 'x86_64-linux', environment: { variable => missing },
                       spawn: ->(*) { raise 'must not spawn' })).to be(false)
      expect(failures.size).to eq(1)
      expect(failures.first).to include('unable to open WebUI window', variable, "'#{missing}'", 'does not exist',
                                        "fix or unset #{variable}")
      expect(failures.first).not_to include('ENOENT', 'Errno', 'Settings')
    end

    it 'names the variable for a value that is not an executable file and strips control characters' do
      plain = File.join(directory, 'notes.txt')
      File.write(plain, '')
      File.chmod(0o644, plain)

      [plain, directory].each do |value|
        failures.clear
        expect(open_with(platform: 'x86_64-linux', environment: { variable => value },
                         spawn: ->(*) { raise 'must not spawn' })).to be(false)
        expect(failures.first).to include(variable, "'#{value}'", 'is not an executable file')
      end

      failures.clear
      open_with(platform: 'x86_64-linux', environment: { variable => "/nope/chro\nmium" }, spawn: ->(*) {})
      expect(failures.first).to include("'/nope/chro?mium'")
      expect(failures.first).not_to include("\n")
    end

    it 'refuses a snap-packaged value with a message naming the variable, without spawning' do
      snap_wrapper # created before launch directories are watched
      expect(Dir).not_to receive(:mktmpdir)

      expect(open_with(platform: 'x86_64-linux', environment: { variable => snap_wrapper },
                       spawn: ->(*) { raise 'must not spawn' })).to be(false)
      expect(failures.first).to include(variable, "'#{snap_wrapper}'",
                                        'snap-packaged Chromium cannot open the WebUI launch files',
                                        "point #{variable} at a non-snap Chrome or Chromium")
      expect(failures.first).not_to include('Settings')
    end

    it 'bypasses the native host like any explicit browser' do
      command = described_class.command_for('file:///x', platform: 'arm64-darwin24', environment: { variable => chromium })

      expect(command.first).to eq(chromium)
    end
  end
end
