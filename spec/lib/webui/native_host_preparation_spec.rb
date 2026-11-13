# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'tmpdir'
require 'rbconfig'
require 'open3'
require 'timeout'
require 'stringio'
require_relative '../../../lib/main/webui_startup'

RSpec.describe Lich::WebUI::NativeHost do
  let(:data_directory) { File.join(@directory, 'data') }
  let(:failure_marker) { File.join(data_directory, 'webui-helper-build-failed.json') }
  let(:toolchain_identity) { 'Apple Swift version fixture' }
  let(:sample_clock) { { now: Time.utc(2026, 11, 13, 12) } }
  let(:toolchain_result) { { output: toolchain_identity } }
  let(:toolchain_process) { double('toolchain process', value: nil, join: true, pid: 12_345) }
  let(:source_paths) do
    %w[Host.swift ExternalLinks.swift Info.plist window.js].map { |name| File.join(@directory, "source-#{name}") } + [build_script]
  end
  let(:executable) { File.join(@directory, 'helper', 'helper.exe') }
  let(:marker) { File.join(@directory, 'builds') }
  let(:lock_path) { File.join(@directory, 'lock', 'prepare.lock') }
  let(:build_script) { File.join(@directory, 'build.rb') }
  let(:notification_script) { File.join(@directory, 'notify.rb') }
  let(:notification_marker) { File.join(@directory, 'notifications') }
  let(:notification_command) { [RbConfig.ruby, notification_script, notification_marker] }
  let(:bridge) { File.join(File.dirname(executable), 'window.js') }
  let(:info) { File.join(File.dirname(executable), 'Info.plist') }
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
    FileUtils.mkdir_p([data_directory, File.dirname(executable)])
    stub_const('DATA_DIR', data_directory)
    allow(Time).to receive(:now) { sample_clock.fetch(:now) }
    allow(Process).to receive(:kill).and_call_original
    allow(Process).to receive(:kill).with('KILL', toolchain_process.pid).and_return(1)
    allow(Process).to receive(:kill).with('KILL', -toolchain_process.pid).and_return(1)
    allow(Open3).to receive(:popen3).and_wrap_original do |original, *arguments, **options, &operation|
      if arguments.first == 'xcrun'
        expect(arguments).to eq(%w[xcrun swiftc --version])
        expect(options).to eq(pgroup: true)
        raise toolchain_result.fetch(:error) if toolchain_result[:error]

        operation.call(StringIO.new, StringIO.new(toolchain_result.fetch(:output)), StringIO.new, toolchain_process)
      else
        original.call(*arguments, **options, &operation)
      end
    end
    source_paths[0...-1].each { |path| File.write(path, "fixture source #{File.basename(path)}") }
    File.write(notification_script, "File.open(ARGV.fetch(0), 'a') { |file| file.puts ARGV.fetch(1) }\n")
    File.write(build_script, build_source)
    stub_const('Lich::WebUI::NativeHost::HELPERS', {
      macos: { name: 'macOS', executable: executable, sources: source_paths, resources: [bridge, info], lock: lock_path,
               notification: notification_command, build: build_command },
    })
  end

  it 'builds a missing helper once and retains the resulting executable' do
    expect(described_class.prepare!(platform: 'darwin')).to be(true)
    expect(File.executable?(executable)).to be(true)
    expect(described_class.prepare!(platform: 'darwin')).to be(true)
    expect(File.readlines(marker)).to eq(["built\n"])
    expect(Open3).not_to have_received(:popen3)
  end

  it 'kills a sleeping probe child after its leader exits and returns within the discovery bound' do
    skip 'POSIX process groups and fork are unavailable on native Windows' if OS.windows?
    child_file = File.join(@directory, 'probe-child.pid')
    probe = nil
    fixture = <<~RUBY
      child = fork { sleep 30 }
      File.write(ARGV.fetch(0), child.to_s)
      exit! 0
    RUBY
    allow(Open3).to receive(:popen3).and_wrap_original do |original, *arguments, **options, &operation|
      expect(arguments).to eq(%w[xcrun swiftc --version])
      expect(options).to eq(pgroup: true)
      original.call(RbConfig.ruby, '-e', fixture, child_file, **options) do |input, output, errors, waiter|
        probe = waiter
        operation.call(input, output, errors, waiter)
      end
    end
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    result = Timeout.timeout(6) { described_class.toolchain_identity }

    expect(result).to be_nil
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 5
    expect(probe.value).to be_success
    child_pid = Integer(File.read(child_file))
    running = lambda do
      state, status = Open3.capture2('ps', '-o', 'stat=', '-p', child_pid.to_s)
      status.success? && !state.strip.empty? && !state.strip.start_with?('Z')
    end
    stopped = begin
      Timeout.timeout(2) { sleep 0.01 while running.call }
      true
    rescue Timeout::Error
      false
    end
    expect(stopped).to be(true), 'the sleeping probe child outlived toolchain discovery'
  ensure
    if probe
      Process.kill('KILL', -probe.pid) rescue nil
      probe.join
    end
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
    File.write(failure_marker, '{}')

    expect(described_class.prepare!(platform: 'darwin')).to be(true)
    expect(File.read(executable)).to eq('existing helper')
    expect(File.exist?(marker)).to be(false)
    expect(File.exist?(failure_marker)).to be(false)
    expect(Open3).not_to have_received(:popen3)
  end

  it 'clears a remembered failure when another startup completes the helper before the lock recheck' do
    File.write(failure_marker, '{}')
    allow(described_class).to receive(:complete?).and_wrap_original do |original, helper|
      ready = original.call(helper)
      unless ready
        File.write(executable, 'concurrently completed helper')
        File.chmod(0o755, executable)
        File.write(bridge, 'concurrently completed bridge')
        File.write(info, 'concurrently completed metadata')
      end
      ready
    end

    expect(described_class.prepare!(platform: 'darwin')).to be(true)

    expect(File.exist?(marker)).to be(false)
    expect(File.exist?(failure_marker)).to be(false)
    expect(Open3).not_to have_received(:popen3)
  end

  it 'accepts a complete helper when another startup already removed the failure marker' do
    File.write(executable, 'existing helper')
    File.chmod(0o755, executable)
    File.write(bridge, 'existing bridge')
    File.write(info, 'existing bundle metadata')
    File.write(failure_marker, '{}')
    allow(File).to receive(:delete).and_call_original
    allow(File).to receive(:delete).with(failure_marker).and_wrap_original do |original, path|
      original.call(path)
      original.call(path)
    end

    expect(described_class.prepare!(platform: 'darwin')).to be(true)

    expect(File.exist?(failure_marker)).to be(false)
    expect(File.exist?(marker)).to be(false)
    expect(Open3).not_to have_received(:popen3)
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

    it 'records the combined source and toolchain fingerprint and failed build status in DATA_DIR' do
      expect { described_class.prepare!(platform: 'darwin') }.to raise_error(described_class::BuildFailure)

      expected = Digest::SHA256.new
      source_paths.each do |path|
        contents = File.binread(path)
        expected << File.basename(path) << "\0" << contents.bytesize.to_s << "\0" << contents
      end
      record = JSON.parse(File.read(failure_marker))
      expect(record.fetch('source_fingerprint')).to eq(expected.hexdigest)
      expect(record.fetch('fingerprint')).to eq(Digest::SHA256.hexdigest("#{expected.hexdigest}\0#{toolchain_identity}"))
      expect(record.fetch('build_exit_status')).to eq(1)
      expect(Time.iso8601(record.fetch('time'))).to be_within(5).of(Time.now)
      expect(record).to have_key('debug_log_path')
      expect(Time.iso8601(record.fetch('toolchain_sampled_at'))).to eq(sample_clock.fetch(:now))
      expect(File.exist?(File.join(File.dirname(executable), 'webui-helper-build-failed.json'))).to be(false)
      expect(File.exist?(File.join(File.dirname(lock_path), 'webui-helper-build-failed.json'))).to be(false)
      expect(Open3).to have_received(:popen3).with('xcrun', 'swiftc', '--version', pgroup: true).once
    end
  end

  it 'fingerprints exactly the five macOS build inputs' do
    expect(described_class::SOURCES.map { |path| File.basename(path) }).to eq(
      %w[Host.swift ExternalLinks.swift Info.plist window.js build.sh]
    )
  end

  it 'invalidates an executable left by a failed build and retries when build sources change' do
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
      DATA_DIR = #{data_directory.dump}
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

  it 'rechecks a concurrent failed build marker under the preparation lock' do
    release = File.join(@directory, 'release-failure')
    started = File.join(@directory, 'failure-started')
    File.write(build_script, <<~RUBY)
      require 'timeout'
      File.open(ARGV.fetch(1), 'a') { |file| file.puts 'built' }
      File.write(#{started.dump}, 'started')
      Timeout.timeout(5) { sleep 0.01 until File.exist?(#{release.dump}) }
      exit 1
    RUBY
    attempt = lambda do
      described_class.prepare!(platform: 'darwin')
    rescue described_class::BuildFailure => error
      error.skipped
    end
    first = Thread.new(&attempt)
    Timeout.timeout(5) { sleep 0.01 until File.exist?(started) }
    locking = Queue.new
    start = Queue.new
    second = Thread.new { start.pop; attempt.call }
    trace = TracePoint.new(:c_call) do |event|
      locking << true if event.method_id == :flock
    end
    trace.enable(target_thread: second)
    start << true
    expect(locking.pop(timeout: 5)).to be(true)
    File.write(release, 'release failed builder')

    expect(first.join(10)).to equal(first)
    expect(second.join(10)).to equal(second)
    expect(first.value).to be(false)
    expect(second.value).to be(true)
    expect(File.readlines(marker)).to eq(["built\n"])
  ensure
    trace&.disable
    File.write(release, 'release failed builder') if release
    [first, second].compact.each { |thread| thread.kill.join if thread.alive? }
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
    around do |example|
      original_stderr = $stderr
      File.open(File.join(@directory, 'debug-2026-11-12-12-00-00-000.log'), 'w') do |debug|
        $stderr = debug
        example.run
      ensure
        $stderr = original_stderr
      end
    end

    before do
      allow(OS).to receive(:mac?).and_return(true)
      allow(OS).to receive(:windows?).and_return(false)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('LICH_WEBUI_BROWSER').and_return(nil)
      allow(Lich).to receive(:log)
      allow(Lich).to receive(:msgbox_alert).and_return(false) if Lich.respond_to?(:msgbox_alert)
      allow(Lich::Main::WebUIStartup).to receive(:system).and_return(true)
      allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(nil)
      Lich::WebUI::BrowserLauncher.native_unavailable = false
    end

    after do
      Lich::WebUI.configure_presentation(enabled: nil)
      Lich::WebUI::BrowserLauncher.native_unavailable = false
    end

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
      let(:browser) { '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' }

      before do
        Lich::WebUI.configure_presentation(enabled: true)
        # Replace external commands only; preparation, hashing and marker decisions run.
        allow(described_class).to receive(:system).with(*build_command, out: $stderr, err: $stderr).and_return(false)
        allow(Process).to receive(:spawn).with(*notification_command, anything, out: $stderr, err: $stderr).and_return(321)
        allow(Process).to receive(:detach).with(321).and_return(nil)
      end

      it 'continues through a discovered browser with one logged Continue dialog and disables native selection for the session' do
        launcher = Lich::WebUI::BrowserLauncher
        allow(launcher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)

        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        expect(launcher).to have_received(:app_browser_path).once

        message = 'Building the macOS WebUI helper failed. Lich will start in degraded mode with Google Chrome; windows will not stay on top.'
        expect(Lich).to have_received(:log).with(message).once
        expect(Lich::Main::WebUIStartup).to have_received(:system).with(
          'osascript', '-e', "display dialog #{message.dump} with title \"Lich WebUI\" buttons {\"Continue\"} default button \"Continue\"", out: $stderr, err: $stderr
        ).once
        expect(launcher.native_host('darwin', nil)).to be_nil
        expect(launcher.command_for('file:///launch.html', platform: 'darwin', environment: {}).first).to eq(browser)
        expect(ENV['LICH_WEBUI_BROWSER']).to be_nil
        expect(JSON.parse(File.read(failure_marker)).fetch('debug_log_path')).to eq($stderr.path)
      end

      it 'skips a repeated failed source fingerprint with one log line and no new dialog or build' do
        allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        Lich::WebUI::BrowserLauncher.native_unavailable = false
        notices = []
        allow(Lich).to receive(:log) { |message| notices << message }

        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

        expect(described_class).to have_received(:system).once
        expect(Lich::Main::WebUIStartup).to have_received(:system).once
        expect(Open3).to have_received(:popen3).once
        expect(notices).to eq(['macOS WebUI helper build skipped: these sources previously failed; using browser degraded mode if available.'])
        expect(Lich::WebUI::BrowserLauncher.native_host('darwin', nil)).to be_nil
      end

      it 'retries once after the toolchain identity changes and remembers the new failure' do
        allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        original = JSON.parse(File.read(failure_marker)).fetch('fingerprint')
        Lich::WebUI::BrowserLauncher.native_unavailable = false
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        toolchain_result[:output] = 'repaired Swift compiler'
        sample_clock[:now] += 86_401
        Lich::WebUI::BrowserLauncher.native_unavailable = false

        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        updated = JSON.parse(File.read(failure_marker)).fetch('fingerprint')
        Lich::WebUI::BrowserLauncher.native_unavailable = false
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

        expect(updated).not_to eq(original)
        expect(described_class).to have_received(:system).twice
        expect(Lich::Main::WebUIStartup).to have_received(:system).twice
        expect(Open3).to have_received(:popen3).twice
      end

      it 'skips without sampling a toolchain identity less than a day old' do
        allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        original = JSON.parse(File.read(failure_marker))
        sample_clock[:now] += 86_399
        toolchain_result[:output] = 'repaired Swift compiler'
        Lich::WebUI::BrowserLauncher.native_unavailable = false

        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

        expect(Open3).to have_received(:popen3).with('xcrun', 'swiftc', '--version', pgroup: true).once
        expect(described_class).to have_received(:system).once
        expect(JSON.parse(File.read(failure_marker))).to eq(original)
      end

      it 'resamples a future toolchain timestamp and retries once when its identity changed' do
        allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        record = JSON.parse(File.read(failure_marker))
        record['toolchain_sampled_at'] = (sample_clock.fetch(:now) + 3600).iso8601
        File.write(failure_marker, JSON.generate(record))
        toolchain_result[:output] = 'repaired Swift compiler'
        Lich::WebUI::BrowserLauncher.native_unavailable = false

        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        updated = JSON.parse(File.read(failure_marker))
        Lich::WebUI::BrowserLauncher.native_unavailable = false
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

        expect(updated.fetch('fingerprint')).not_to eq(record.fetch('fingerprint'))
        expect(Time.iso8601(updated.fetch('toolchain_sampled_at'))).to eq(sample_clock.fetch(:now))
        expect(Open3).to have_received(:popen3).with('xcrun', 'swiftc', '--version', pgroup: true).twice
        expect(described_class).to have_received(:system).twice
      end

      it 'refreshes an unchanged daily sample and skips the next immediate check' do
        allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        original = JSON.parse(File.read(failure_marker)).fetch('fingerprint')
        sample_clock[:now] += 86_400
        Lich::WebUI::BrowserLauncher.native_unavailable = false

        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        updated = JSON.parse(File.read(failure_marker))
        Lich::WebUI::BrowserLauncher.native_unavailable = false
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

        expect(updated.fetch('fingerprint')).to eq(original)
        expect(Time.iso8601(updated.fetch('toolchain_sampled_at'))).to eq(sample_clock.fetch(:now))
        expect(Open3).to have_received(:popen3).with('xcrun', 'swiftc', '--version', pgroup: true).twice
        expect(described_class).to have_received(:system).once
      end

      it 'kills and reaps a timed out daily sample without retrying or immediately sampling again' do
        allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        original = JSON.parse(File.read(failure_marker)).fetch('fingerprint')
        sample_clock[:now] += 86_401
        toolchain_result[:output] = 'unobserved replacement compiler'
        allow(Timeout).to receive(:timeout).and_call_original
        allow(Timeout).to receive(:timeout).with(3).and_raise(Timeout::Error)
        allow(toolchain_process).to receive(:join).with(0).and_return(nil)
        allow(toolchain_process).to receive(:join).with(no_args).and_return(true)
        allow(Process).to receive(:kill).with('KILL', -toolchain_process.pid).and_return(1)
        Lich::WebUI::BrowserLauncher.native_unavailable = false

        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        updated = JSON.parse(File.read(failure_marker))
        Lich::WebUI::BrowserLauncher.native_unavailable = false
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

        expect(updated.fetch('fingerprint')).to eq(original)
        expect(Time.iso8601(updated.fetch('toolchain_sampled_at'))).to eq(sample_clock.fetch(:now))
        expect(Process).to have_received(:kill).with('KILL', -toolchain_process.pid).once
        expect(toolchain_process).to have_received(:join).with(no_args).once
        expect(Open3).to have_received(:popen3).with('xcrun', 'swiftc', '--version', pgroup: true).twice
        expect(described_class).to have_received(:system).once
      end

      it 'remembers a first-failure timeout until the next daily sample' do
        allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)
        allow(Timeout).to receive(:timeout).and_call_original
        allow(Timeout).to receive(:timeout).with(3).and_raise(Timeout::Error)

        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        record = JSON.parse(File.read(failure_marker))
        Lich::WebUI::BrowserLauncher.native_unavailable = false
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

        expect(record.fetch('fingerprint')).to eq(record.fetch('source_fingerprint'))
        expect(Open3).to have_received(:popen3).with('xcrun', 'swiftc', '--version', pgroup: true).once
        expect(described_class).to have_received(:system).once
      end

      it 'retries when a sampled marker has no usable combined fingerprint' do
        allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)
        source = described_class.source_fingerprint(described_class::HELPERS.fetch(:macos))
        File.write(failure_marker, JSON.generate(source_fingerprint: source, toolchain_sampled_at: sample_clock.fetch(:now).iso8601))

        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

        expect(described_class).to have_received(:system).once
        expect(JSON.parse(File.read(failure_marker)).fetch('fingerprint')).to be_a(String)
      end

      %w[unsuccessful missing].each do |failure|
        it "retries once after #{failure} toolchain discovery becomes available" do
          allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)
          if failure == 'missing'
            toolchain_result[:error] = Errno::ENOENT.new('xcrun')
          else
            toolchain_result[:output] = 'xcrun: compiler unavailable'
          end
          expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
          original = JSON.parse(File.read(failure_marker)).fetch('fingerprint')
          Lich::WebUI::BrowserLauncher.native_unavailable = false
          expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
          toolchain_result.delete(:error)
          toolchain_result[:output] = toolchain_identity
          sample_clock[:now] += 86_401
          Lich::WebUI::BrowserLauncher.native_unavailable = false

          expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
          updated = JSON.parse(File.read(failure_marker)).fetch('fingerprint')
          Lich::WebUI::BrowserLauncher.native_unavailable = false
          expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

          expect(updated).not_to eq(original)
          expect(described_class).to have_received(:system).twice
          expect(Open3).to have_received(:popen3).twice
        end
      end

      it 'retries when a marker has no source fingerprint' do
        allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)
        source = described_class.source_fingerprint(described_class::HELPERS.fetch(:macos))
        File.write(failure_marker, JSON.generate(fingerprint: source))
        expect(described_class.failed_fingerprint(source)).to be_nil

        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        migrated = JSON.parse(File.read(failure_marker))
        Lich::WebUI::BrowserLauncher.native_unavailable = false
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

        expect(migrated.fetch('source_fingerprint')).to eq(source)
        expect(migrated.fetch('fingerprint')).not_to eq(source)
        expect(described_class).to have_received(:system).once
        expect(Open3).to have_received(:popen3).once
      end

      it 'reports browser capabilities and presentation degradations after native preparation falls back' do
        allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)
        registry = Lich::WebUI::Registry.new
        runtime = Lich::WebUI::Runtime.new(registry: registry)
        page = registry.register(Lich::WebUI::Page.new(owner: Object.new, id: 'degraded', title: 'Degraded') do
          presentation(always_on_top: true, borderless: true, hidden: true, minimized: true)
        end)
        expect(runtime.presentation_support).to include(always_on_top: true, borderless: true, hidden: true, minimized: true)

        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        runtime.refresh(page)

        expect(described_class.platform).to be_nil
        expect(page.presentation_support).to eq(
          always_on_top: false, borderless: false, hidden: false, minimized: false, minimized_revision: false, opacity: true, scrollbars: true
        )
        expect(page.degradations).to contain_exactly(
          { facility: :presentation, property: :always_on_top, reason: :unsupported_by_browser_host },
          { facility: :presentation, property: :borderless, reason: :unsupported_by_browser_host },
          { facility: :presentation, property: :hidden, reason: :unsupported_by_browser_host },
          { facility: :presentation, property: :minimized, reason: :unsupported_by_browser_host }
        )
      ensure
        runtime&.shutdown
      end

      5.times do |index|
        it "retries after changing source input #{index + 1} and clears the marker on success" do
          allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)
          expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
          failed = JSON.parse(File.read(failure_marker)).fetch('source_fingerprint')
          File.open(source_paths.fetch(index), 'a') { |file| file.write('\nchanged source') }
          Lich::WebUI::BrowserLauncher.native_unavailable = false
          allow(described_class).to receive(:system).with(*build_command, out: $stderr, err: $stderr) do
            File.write(bridge, 'updated bridge')
            File.write(info, 'updated metadata')
            File.write(executable, 'updated helper')
            File.chmod(0o755, executable)
            true
          end

          expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

          expect(described_class.source_fingerprint(described_class::HELPERS.fetch(:macos))).not_to eq(failed)
          expect(described_class).to have_received(:system).twice
          expect(Open3).to have_received(:popen3).once
          expect(File.exist?(failure_marker)).to be(false)
          expect(File.executable?(executable)).to be(true)
          expect(Lich::WebUI::BrowserLauncher.native_host('darwin', nil)).to eq(:macos)
        end
      end

      it 'retries once after deleting the marker even when source contents are unchanged' do
        allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        File.delete(failure_marker)
        Lich::WebUI::BrowserLauncher.native_unavailable = false

        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

        expect(described_class).to have_received(:system).twice
        expect(Lich::Main::WebUIStartup).to have_received(:system).twice
        expect(File.exist?(failure_marker)).to be(true)
      end

      it 'remembers a newly failed fingerprint after a source change and skips its next attempt' do
        allow(Lich::WebUI::BrowserLauncher).to receive(:app_browser_path).with(hash_including(platform: 'darwin')).and_return(browser)
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        original = JSON.parse(File.read(failure_marker)).fetch('fingerprint')
        File.write(source_paths.first, 'updated source that still fails to build')
        Lich::WebUI::BrowserLauncher.native_unavailable = false
        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error
        updated = JSON.parse(File.read(failure_marker)).fetch('fingerprint')
        Lich::WebUI::BrowserLauncher.native_unavailable = false

        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

        expect(updated).not_to eq(original)
        expect(described_class).to have_received(:system).twice
        expect(Lich::Main::WebUIStartup).to have_received(:system).twice
      end

      it 'exits only without a browser and names the exact debug file and Elanthia Online support' do
        message = "error: macOS WebUI helper build failed. See #{$stderr.path} and contact Elanthia Online support. " \
                  'To start anyway, set LICH_WEBUI_BROWSER to the Chrome, Edge, Brave or Arc application ' \
                  '(other browsers are not actively supported), or start with --no-gui.'

        expect { Lich::Main::WebUIStartup.prepare }
          .to raise_error(SystemExit) { |exit| expect(exit.status).to eq(1) }
        expect(Lich).to have_received(:log).with(message)
        expect(Lich::Main::WebUIStartup).not_to have_received(:system)
        expect(File.exist?(executable)).to be(false)
      end

      it 'retries a remembered failure on every start without a browser and names that start\'s debug file' do
        expect { Lich::Main::WebUIStartup.prepare }.to raise_error(SystemExit)
        expect(File.exist?(failure_marker)).to be(true)
        message = "error: macOS WebUI helper build failed. See #{$stderr.path} and contact Elanthia Online support. " \
                  'To start anyway, set LICH_WEBUI_BROWSER to the Chrome, Edge, Brave or Arc application ' \
                  '(other browsers are not actively supported), or start with --no-gui.'

        expect { Lich::Main::WebUIStartup.prepare }
          .to raise_error(SystemExit) { |exit| expect(exit.status).to eq(1) }

        expect(described_class).to have_received(:system).twice
        expect(Lich).to have_received(:log).with(message).twice
        expect(Lich).not_to have_received(:log).with(a_string_including('build skipped'))
      end

      it 'clears the remembered failure when a later start without a browser builds the helper' do
        expect { Lich::Main::WebUIStartup.prepare }.to raise_error(SystemExit)
        allow(described_class).to receive(:system).with(*build_command, out: $stderr, err: $stderr).and_call_original

        expect { Lich::Main::WebUIStartup.prepare }.not_to raise_error

        expect(File.executable?(executable)).to be(true)
        expect(File.exist?(failure_marker)).to be(false)
        expect(Lich::WebUI::BrowserLauncher.native_host('darwin', nil)).to eq(:macos)
      end
    end
  end
end
