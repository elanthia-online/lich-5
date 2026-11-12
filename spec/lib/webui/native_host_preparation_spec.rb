# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'tmpdir'
require 'rbconfig'
require 'open3'
require 'timeout'
require_relative '../../../lib/main/webui_startup'

RSpec.describe Lich::WebUI::NativeHost do
  let(:executable) { File.join(@directory, 'helper.exe') }
  let(:marker) { File.join(@directory, 'builds') }
  let(:lock_path) { File.join(@directory, 'prepare.lock') }
  let(:build_script) { File.join(@directory, 'build.rb') }
  let(:notification_script) { File.join(@directory, 'notify.rb') }
  let(:notification_marker) { File.join(@directory, 'notifications') }
  let(:notification_command) { [RbConfig.ruby, notification_script, notification_marker] }
  let(:bridge) { File.join(@directory, 'window.js') }
  let(:info) { File.join(@directory, 'Info.plist') }
  let(:build_command) { [RbConfig.ruby, build_script, executable, marker, bridge, info] }
  let(:build_source) do
    <<~RUBY
      File.open(ARGV.fetch(1), 'a') { |file| file.puts 'built' }
      File.write(ARGV.fetch(2), 'fixture bridge')
      File.write(ARGV.fetch(3), 'fixture bundle metadata')
      File.write(ARGV.fetch(0), 'fixture executable')
      File.chmod(0o755, ARGV.fetch(0))
    RUBY
  end

  around do |example|
    Dir.mktmpdir('native helper preparation ') do |directory|
      @directory = directory
      existing_waiters = Thread.list.grep(Process::Waiter)
      begin
        example.run
      ensure
        (Thread.list.grep(Process::Waiter) - existing_waiters).each { |waiter| waiter.join(10) }
      end
    end
  end

  before do
    allow(Lich).to receive(:log)
    File.write(notification_script, "File.open(ARGV.fetch(0), 'a') { |file| file.puts ARGV.fetch(1) }\n")
    File.write(build_script, build_source)
    stub_const('Lich::WebUI::NativeHost::HELPERS', {
      macos: { name: 'macOS', executable: executable, resources: [bridge, info], lock: lock_path,
               notification: notification_command, build: build_command },
    })
  end

  it 'builds a missing helper once and retains the resulting executable' do
    expect(described_class.prepare!(platform: 'darwin')).to be(true)
    expect(File.executable?(executable)).to be(true)
    expect(described_class.prepare!(platform: 'darwin')).to be(true)
    expect(File.readlines(marker)).to eq(["built\n"])
  end

  it 'logs and detaches the desktop notice before starting the build' do
    logged = File.join(@directory, 'logged-notice')
    release = File.join(@directory, 'release-notice')
    finished = File.join(@directory, 'finished-notice')
    message = 'Building the macOS WebUI helper for the first start after install or update; this may take a minute or two.'
    allow(Lich).to receive(:log) { |notice| File.write(logged, notice) }
    File.write(notification_script, <<~RUBY)
      require 'timeout'
      abort 'notification ran before its log' unless File.read(#{logged.dump}) == #{message.dump}
      File.write(ARGV.fetch(0), ARGV.fetch(1))
      begin
        Timeout.timeout(5) { sleep 0.01 until File.exist?(#{release.dump}) }
      ensure
        File.write(#{finished.dump}, 'notification finished')
      end
    RUBY
    File.write(build_script, <<~RUBY + build_source)
      require 'timeout'
      Timeout.timeout(5) { sleep 0.01 until File.exist?(#{notification_marker.dump}) }
      abort 'notification blocked the builder' if File.exist?(#{finished.dump})
    RUBY
    existing_waiters = Thread.list.grep(Process::Waiter)

    expect(described_class.prepare!(platform: 'darwin')).to be(true)
    expect(Lich).to have_received(:log).with(message)
    expect(File.read(notification_marker)).to eq("display notification #{message.dump} with title \"Lich WebUI\"")
    expect(File.exist?(finished)).to be(false)
    expect(Thread.list.grep(Process::Waiter) - existing_waiters).to contain_exactly(an_instance_of(Process::Waiter))
    expect(File.readlines(marker)).to eq(["built\n"])
  ensure
    File.write(release, 'release notification') if release
  end

  it 'still builds when the desktop notification command cannot start' do
    described_class::HELPERS.fetch(:macos)[:notification] = [File.join(@directory, 'missing notification')]

    expect(described_class.prepare!(platform: 'darwin')).to be(true)
    expect(File.readlines(marker)).to eq(["built\n"])
  end

  it 'sends real build stdout and stderr to the debug stream without writing to the client stream' do
    File.write(build_script, "puts 'build stdout'\nwarn 'build stderr'\n" + build_source)
    original_stdout = $stdout
    original_stderr = $stderr
    File.open(File.join(@directory, 'client-stream'), 'w+') do |client|
      File.open(File.join(@directory, 'debug-log'), 'w+') do |debug|
        begin
          $stdout = client
          $stderr = debug
          expect(described_class.prepare!(platform: 'darwin')).to be(true)
        ensure
          $stdout = original_stdout
          $stderr = original_stderr
        end
        client.rewind
        debug.rewind
        expect(client.read).to eq('')
        expect(debug.read).to include("build stdout\n", "build stderr\n")
      end
    end
  end

  it 'retains an already installed executable without running the build' do
    File.write(executable, 'existing helper')
    File.chmod(0o755, executable)
    File.write(bridge, 'existing bridge')
    File.write(info, 'existing bundle metadata')

    expect(described_class.prepare!(platform: 'darwin')).to be(true)
    expect(File.read(executable)).to eq('existing helper')
    expect(File.exist?(marker)).to be(false)
  end

  context 'when the installed helper is shared without a writable lock' do
    # Opening a directory as a writable lock fails even on hosts that ignore
    # POSIX permission bits, so this checks reuse without a writable lock path.
    let(:lock_path) { @directory }

    it 'reuses the complete prebuilt bundle without opening the lock' do
      File.write(executable, 'existing helper')
      File.chmod(0o755, executable)
      File.write(bridge, 'existing bridge')
      File.write(info, 'existing bundle metadata')

      expect(described_class.prepare!(platform: 'darwin')).to be(true)
      expect(File.read(executable)).to eq('existing helper')
      expect(File.exist?(marker)).to be(false)
    end
  end

  it 'repairs an installed executable whose required bridge is missing' do
    File.write(executable, 'incomplete helper')
    File.chmod(0o755, executable)
    File.write(info, 'existing bundle metadata')

    expect(described_class.prepare!(platform: 'darwin')).to be(true)
    expect(File.read(bridge)).to eq('fixture bridge')
    expect(File.readlines(marker)).to eq(["built\n"])
  end

  it 'rechecks the executable after resources change during a completeness check' do
    File.write(executable, 'existing helper')
    File.chmod(0o755, executable)
    File.write(bridge, 'existing bridge')
    File.write(info, 'existing bundle metadata')
    start = Queue.new
    checking = Queue.new
    release = Queue.new
    startup = Thread.new do
      start.pop
      described_class.prepare!(platform: 'darwin')
    end
    paused = false
    trace = TracePoint.new(:b_call) do |event|
      next if paused || !event.path.end_with?('/lib/webui/native_host.rb')
      next unless event.binding.local_variable_defined?(:path)
      next unless event.binding.local_variable_get(:path) == bridge

      paused = true
      checking << true
      raise 'completeness barrier timed out' unless release.pop(timeout: 5)
    end
    trace.enable(target_thread: startup)
    start << true
    expect(checking.pop(timeout: 5)).to be(true)
    # A repair removes the old executable, then starts copying its resources.
    File.delete(executable)
    File.write(bridge, 'partial replacement bridge')
    release << true

    expect(startup.join(10)).to equal(startup)
    expect(startup.value).to be(true)
    expect(File.readlines(marker)).to eq(["built\n"])
    expect(File.executable?(executable)).to be(true)
    expect(File.read(bridge)).to eq('fixture bridge')
  ensure
    trace&.disable
    release << true if release
    startup&.kill&.join if startup&.alive?
  end

  it 'publishes the macOS executable only after its resources and validation' do
    source = File.read(File.expand_path('../../../lib/webui/native/macos/build.sh', __dir__))
    commands = source.lines.reject { |line| line.start_with?('#') || line.strip.empty? }

    expect(commands.last.strip).to eq('mv build/LichWebUI.universal build/LichWebUI.app/Contents/MacOS/LichWebUI')
    expect(source.index('cp Info.plist')).to be < source.index('mv build/LichWebUI.universal')
    expect(source.index('cp window.js')).to be < source.index('mv build/LichWebUI.universal')
    expect(source.index('xcrun lipo -info build/LichWebUI.universal')).to be < source.index('mv build/LichWebUI.universal')
  end

  %w[linux mingw].each do |platform|
    it "does no native build work on #{platform}" do
      expect(described_class.prepare!(platform: platform)).to be(false)
      expect(File.exist?(marker)).to be(false)
      expect(File.exist?(executable)).to be(false)
    end
  end

  context 'when the build exits unsuccessfully' do
    let(:build_source) { "exit 1\n" }

    it 'reports failure instead of accepting the missing executable' do
      expect { described_class.prepare!(platform: 'darwin') }
        .to raise_error(Lich::WebUI::Error, /macOS WebUI helper build failed/)
      expect(File.exist?(executable)).to be(false)
    end
  end

  it 'invalidates an executable left by a failed build and retries the next time' do
    File.write(build_script, <<~RUBY)
      File.open(ARGV.fetch(1), 'a') { |file| file.puts 'built' }
      File.write(ARGV.fetch(0), 'incomplete helper')
      File.chmod(0o755, ARGV.fetch(0))
      exit 1
    RUBY

    expect { described_class.prepare!(platform: 'darwin') }
      .to raise_error(Lich::WebUI::Error, /helper build failed/)
    expect(File.exist?(executable)).to be(false)
    expect(File.exist?(bridge)).to be(false)

    File.write(build_script, build_source)
    expect(described_class.prepare!(platform: 'darwin')).to be(true)
    expect(File.executable?(executable)).to be(true)
    expect(File.read(bridge)).to eq('fixture bridge')
    expect(File.readlines(marker)).to eq(["built\n", "built\n"])
  end

  it 'serializes repair of an incomplete bundle while resources are being written' do
    release = File.join(@directory, 'release')
    started = File.join(@directory, 'build-started')
    File.write(executable, 'incomplete installed helper')
    File.chmod(0o755, executable)
    File.write(info, 'existing bundle metadata')
    File.write(build_script, <<~RUBY + build_source)
      require 'timeout'
      File.write(#{bridge.dump}, 'partial bridge')
      File.write(#{started.dump}, 'started')
      Timeout.timeout(5) { sleep 0.01 until File.exist?(#{release.dump}) }
    RUBY
    child = <<~RUBY
      require #{File.expand_path('../../../lib/webui/native_host', __dir__).dump}
      host = Lich::WebUI::NativeHost
      def Lich.log(message)
        File.open(ARGV.fetch(1), 'a') { |file| file.puts message }
      end
      host.send(:remove_const, :HELPERS)
      host.const_set(:HELPERS, #{described_class::HELPERS.inspect})
      locking = TracePoint.new(:c_call) do |event|
        File.write(ARGV.fetch(0), 'locking') if event.method_id == :flock
      end
      locking.enable
      host.prepare!(platform: 'darwin')
      locking.disable
      Thread.list.grep(Process::Waiter).each(&:join)
    RUBY
    children = []
    2.times do |index|
      ready = File.join(@directory, "ready-#{index}")
      children << Open3.popen3(RbConfig.ruby, '-e', child, ready, File.join(@directory, 'child-debug.log'))
      children.last.first.close
      Timeout.timeout(5) { sleep 0.01 until File.exist?(ready) }
      if index.zero?
        Timeout.timeout(5) { sleep 0.01 until File.exist?(started) }
        expect(File.exist?(executable)).to be(false)
        expect(File.read(bridge)).to eq('partial bridge')
      end
    end
    File.write(release, 'release builder')
    children.each do |_input, output, errors, waiter|
      expect(waiter.join(10)).to equal(waiter)
      expect(waiter.value).to be_success, errors.read
      expect(output.read).to eq('')
    end
    expect(File.readlines(marker)).to eq(["built\n"])
    expect(File.readlines(notification_marker).length).to eq(1)
    expect(File.executable?(executable)).to be(true)
    expect(File.read(bridge)).to eq('fixture bridge')
  ensure
    children&.each do |input, output, errors, waiter|
      Process.kill('KILL', waiter.pid) if waiter.alive?
      waiter.join
      [input, output, errors].each { |stream| stream.close unless stream.closed? }
    end
  end

  context 'when the build reports success without supplying the helper' do
    let(:build_source) { "exit 0\n" }

    it 'requires the executable postcondition' do
      expect { described_class.prepare!(platform: 'darwin') }
        .to raise_error(Lich::WebUI::Error, /macOS WebUI helper build failed/)
    end
  end

  context 'when the build command cannot start' do
    let(:build_command) { [File.join(@directory, 'missing compiler')] }

    it 'reports a safe build failure' do
      expect { described_class.prepare!(platform: 'darwin') }
        .to raise_error(Lich::WebUI::Error, /macOS WebUI helper (?:build|preparation) failed/)
    end
  end

  describe 'common startup preparation' do
    before do
      allow(OS).to receive(:mac?).and_return(true)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('LICH_WEBUI_BROWSER').and_return(nil)
      allow(Lich).to receive(:log)
      allow(Lich).to receive(:msgbox_alert).and_return(false) if Lich.respond_to?(:msgbox_alert)
    end

    after { Lich::WebUI.configure_presentation(enabled: nil) }

    it 'prepares native hosting before either login route can continue' do
      Lich::WebUI.configure_presentation(enabled: true)

      expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

      expect(File.executable?(executable)).to be(true)
      expect(File.readlines(marker)).to eq(["built\n"])
    end

    it 'keeps disabled presentation free of native builds' do
      Lich::WebUI.configure_presentation(enabled: false)

      expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

      expect(File.exist?(marker)).to be(false)
      expect(File.exist?(executable)).to be(false)
    end

    it 'uses the configured browser without requiring the native build' do
      browser = File.join(@directory, 'browser.exe')
      File.write(browser, '')
      File.chmod(0o755, browser)
      File.write(build_script, "exit 1\n")
      allow(ENV).to receive(:[]).with('LICH_WEBUI_BROWSER').and_return(" #{browser} ")
      Lich::WebUI.configure_presentation(enabled: true)

      expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

      expect(Lich::WebUI::BrowserLauncher.command_for('http://127.0.0.1:1234/').first).to eq(browser)
      expect(File.exist?(marker)).to be(false)
      expect(File.exist?(executable)).to be(false)
    end

    context 'when the required build fails' do
      let(:build_source) { "exit 1\n" }

      it 'logs the fatal reason and exits before login or script startup' do
        Lich::WebUI.configure_presentation(enabled: true)

        expect { Lich::Main::WebUIStartup.prepare }
          .to raise_error(SystemExit) { |exit| expect(exit.status).to eq(1) }
        expect(Lich).to have_received(:log).with('error: macOS WebUI helper build failed; check the debug log and retry')
        expect(File.exist?(executable)).to be(false)
      end
    end
  end
end
