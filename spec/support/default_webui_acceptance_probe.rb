# frozen_string_literal: true

require 'base64'
require 'fileutils'
require 'json'
require 'socket'
require 'timeout'
require 'uri'
require 'rbconfig'
require_relative 'default_webui_acceptance_report'

acceptance_root = ENV.fetch('LICH_CI_DEFAULT_WEBUI_ROOT')
FileUtils.mkdir_p(acceptance_root)
# Every writable root lib/constants.rb would derive from the checkout points into
# the temporary root; only LIB_DIR stays on the checkout, as the code under test.
LIB_DIR = File.expand_path('../../lib', __dir__).freeze unless defined?(LIB_DIR)
LICH_DIR = File.join(acceptance_root, 'home').freeze unless defined?(LICH_DIR)
DATA_DIR = File.join(acceptance_root, 'data').freeze unless defined?(DATA_DIR)
TEMP_DIR = File.join(acceptance_root, 'temp').freeze unless defined?(TEMP_DIR)
SCRIPT_DIR = File.join(acceptance_root, 'scripts').freeze unless defined?(SCRIPT_DIR)
MAP_DIR = File.join(acceptance_root, 'maps').freeze unless defined?(MAP_DIR)
LOG_DIR = File.join(acceptance_root, 'logs').freeze unless defined?(LOG_DIR)
BACKUP_DIR = File.join(acceptance_root, 'backup').freeze unless defined?(BACKUP_DIR)
FileUtils.mkdir_p([LICH_DIR, DATA_DIR, TEMP_DIR, SCRIPT_DIR, MAP_DIR, LOG_DIR, BACKUP_DIR])

module LichCiDefaultWebUIAcceptance
  module_function

  REQUIRED_TABS = ['Saved Entry', 'Manual Entry', 'Account Management', 'Frontends'].freeze
  GTK_FAMILY_PATTERN = /(?:gtk|gdk|gobject|glib)/i

  # Isolates helper build inputs and intercepts browser opening after classes load.
  # Production helper preparation, startup and await methods remain intact.
  # This subprocess probe uses authenticated HTTP/WebSocket traffic, not a browser cookie jar.
  # @return [void]
  def install!
    @installer = TracePoint.new(:end) do |trace|
      if trace.path.end_with?('/webui/native_host.rb') && defined?(Lich::WebUI::NativeHost) &&
         trace.self.equal?(Lich::WebUI::NativeHost)
        install_native_fixture(Lich::WebUI::NativeHost)
      end
      next unless trace.path.end_with?('/webui/browser_launcher.rb')
      next unless defined?(Lich::WebUI::BrowserLauncher)
      next unless trace.self.equal?(Lich::WebUI::BrowserLauncher)

      client = Module.new do
        define_method(:open) do |url, **options|
          LichCiDefaultWebUIAcceptance.start_client(url, on_exit: options[:on_exit])
          true
        end
      end
      Lich::WebUI::BrowserLauncher.singleton_class.prepend(client)
      @installer.disable
    end
    @installer.enable
  end

  # Supplies local fixture build and notification commands without replacing
  # native preparation or announcement logic.
  # The fixture executable supplies no native-window behavior.
  # @param host [Module] production native host with its methods already defined
  # @return [void]
  def install_native_fixture(host)
    directory = File.join(TEMP_DIR, 'native-helper')
    FileUtils.mkdir_p(directory)
    executable = File.join(directory, 'helper.exe')
    builder = File.join(directory, 'build.rb')
    notifier = File.join(directory, 'notify.rb')
    notification = File.join(directory, 'notifications')
    marker = File.join(directory, 'builds')
    lock = File.join(directory, 'prepare.lock')
    bridge = File.join(directory, 'window.js')
    sources = %w[Host.swift ExternalLinks.swift Info.plist window.js build.sh].map do |name|
      path = File.join(directory, "source-#{name}")
      File.write(path, "fixture source #{name}")
      path
    end.freeze
    program = <<~'SH'
      #!/bin/sh
      printf '%s\n' '{"source":"unavailable","screens":[]}'
    SH
    File.write(notifier, "File.open(ARGV.fetch(0), 'a') { |file| file.puts ARGV.fetch(1) }\n")
    File.write(builder, <<~RUBY)
      require 'timeout'
      Timeout.timeout(5) { sleep 0.01 until File.exist?(#{notification.dump}) }
      File.open(ARGV.fetch(1), 'a') { |file| file.puts 'built' }
      File.write(ARGV.fetch(2), 'fixture bridge')
      File.write(ARGV.fetch(0), #{program.dump})
      File.chmod(0o755, ARGV.fetch(0))
    RUBY
    host.send(:remove_const, :EXECUTABLE)
    host.const_set(:EXECUTABLE, executable.freeze)
    host.send(:remove_const, :HELPERS)
    host.const_set(:HELPERS, {
      macos: { name: 'macOS', executable: executable, sources: sources, resources: [bridge].freeze, lock: lock,
               notification: [{ 'RUBYOPT' => nil }, RbConfig.ruby, notifier, notification].freeze,
               build: [{ 'RUBYOPT' => nil }, RbConfig.ruby, builder, executable, marker, bridge].freeze }.freeze,
    }.freeze)
    @native_fixture = { executable: executable, lock: lock, marker: marker }
  end

  # Requires production preparation and records its isolated fixture outcome.
  # @return [Hash] native preparation evidence
  # @raise [RuntimeError] if preparation was replaced or its outcome is wrong
  def native_preparation_evidence
    host = Lich::WebUI::NativeHost
    startup_source = Lich::Main::WebUIStartup.method(:prepare).source_location.first
    helper_source = host.method(:prepare!).source_location.first
    raise 'startup preparation was replaced' unless startup_source.end_with?('/lib/main/webui_startup.rb')
    raise 'native preparation was replaced' unless helper_source.end_with?('/lib/webui/native_host.rb')

    required = !host.platform.nil?
    builds = File.exist?(@native_fixture.fetch(:marker)) ? File.readlines(@native_fixture.fetch(:marker)).length : 0
    available = File.executable?(@native_fixture.fetch(:executable))
    raise 'native fixture preparation did not run as required' unless builds == (required ? 1 : 0) && available == required

    { 'required' => required, 'builds' => builds, 'available' => available,
      'startup_replaced' => false, 'helper_replaced' => false }
  end

  # Starts the probe client and publishes a structured success/failure report for the parent.
  # @return [Thread] client worker
  def start_client(url, on_exit: nil)
    @client = Thread.new do
      result = exercise(url)
      report(result)
      # An owned browser window closes the launcher by exiting; a viewer detach
      # alone leaves the page open, so report the substitute's exit.
      on_exit&.call
    rescue StandardError => error
      report(
        'verdict'   => 'fail',
        'error'     => "#{error.class}: #{error.message}",
        'backtrace' => Array(error.backtrace).first(8)
      )
    end
  end

  # Checks no-argument startup, authentication, launcher tabs, and one real event/refresh cycle.
  # This proves transport/startup integration, not rendering or OS-window behavior.
  # @return [Hash] acceptance evidence
  # @raise [RuntimeError] when an expected protocol or launcher step fails
  def exercise(url)
    raise 'default acceptance unexpectedly received arguments' unless ARGV.empty?

    start_source = launcher_source(:start)
    await_source = launcher_source(:await_launch)
    uri = URI(url)
    auth_response = http_get(uri, uri.request_uri, 'Sec-Fetch-Site' => 'none', 'Sec-Fetch-Mode' => 'navigate')
    cookie = auth_response[/^Set-Cookie: ([^;]+)/i, 1]
    raise 'launch-token authentication failed' unless auth_response.start_with?('HTTP/1.1 302 Found') && cookie

    page_response = http_get(
      uri, '/', 'Cookie' => cookie, 'Sec-Fetch-Site' => 'same-origin', 'Sec-Fetch-Mode' => 'navigate'
    )
    raise 'authenticated page request failed' unless page_response.start_with?('HTTP/1.1 200 OK')

    socket = websocket(uri, cookie)
    hello = read_message(socket)
    raise 'authenticated WebSocket hello missing' unless hello['type'] == 'hello' &&
                                                         hello['contract_version'] == Lich::WebUI::Contract::VERSION

    address = hello.fetch('pages').first.fetch('address')
    send_message(socket, type: 'attach', page: address, version: hello.fetch('contract_version'))
    render = read_until(socket) { |message| message['type'] == 'render' }
    tabs = find_component(render.fetch('tree')) do |component|
      component['type'] == 'tabs' && component.dig('props', 'names') == REQUIRED_TABS
    end
    raise 'required launcher tabs missing from authenticated render' unless tabs

    toggle = find_component(render.fetch('tree')) { |component| component['cid'].end_with?('toggle:gui-settings-toggle') }
    raise 'GUI Settings interaction target missing' unless toggle

    send_message(
      socket, type: 'event', page: address, cid: toggle.fetch('cid'), event: 'change',
              generation: render.fetch('generation'), payload: { value: true }
    )
    changed = read_until(socket) do |message|
      next false unless message['type'] == 'render'

      panel = find_component(message.fetch('tree')) do |component|
        component['cid'].end_with?('stack:gui-settings-options')
      end
      panel && panel.dig('props', 'hidden') == false
    end
    send_message(socket, type: 'detach', page: address, generation: changed.fetch('generation'))
    socket.close

    {
      'verdict'                    => 'pass',
      'authenticated_http'         => true,
      'authenticated_websocket'    => true,
      'page_address'               => address,
      'required_tabs'              => REQUIRED_TABS,
      'interaction'                => 'GUI Settings changed from hidden to visible',
      'launcher_start_replaced'    => false,
      'launcher_await_replaced'    => false,
      'launcher_start_source'      => start_source,
      'launcher_await_source'      => await_source,
      'entrypoint_argv'            => ARGV.dup,
      'native_preparation'         => native_preparation_evidence,
      'effective_roots'            => effective_roots,
      'gtk_family_loaded_features' => $LOADED_FEATURES.grep(GTK_FAMILY_PATTERN)
    }
  ensure
    socket&.close unless socket&.closed?
  end

  # Makes one loopback request with explicit headers and a bounded response wait.
  # @return [String] raw HTTP response
  def http_get(uri, target, headers)
    socket = TCPSocket.new(uri.host, uri.port)
    lines = ["GET #{target} HTTP/1.1", "Host: #{uri.host}:#{uri.port}", 'Connection: close']
    headers.each { |name, value| lines << "#{name}: #{value}" }
    socket.write(lines.join("\r\n") + "\r\n\r\n")
    Timeout.timeout(5) { socket.read }
  ensure
    socket&.close
  end

  # Performs the authenticated loopback WebSocket upgrade used by the probe.
  # @return [TCPSocket] upgraded connection
  # @raise [RuntimeError] if the server refuses the upgrade
  def websocket(uri, cookie)
    socket = TCPSocket.new(uri.host, uri.port)
    key = Base64.strict_encode64('lich-webui-probe')
    socket.write([
      'GET /ws HTTP/1.1', "Host: #{uri.host}:#{uri.port}", 'Upgrade: websocket',
      'Connection: Upgrade', 'Sec-WebSocket-Version: 13', "Sec-WebSocket-Key: #{key}",
      "Origin: http://#{uri.host}:#{uri.port}", "Cookie: #{cookie}", '', ''
    ].join("\r\n"))
    response = +''
    Timeout.timeout(5) { response << socket.read(1) until response.end_with?("\r\n\r\n") }
    raise 'WebSocket upgrade failed' unless response.start_with?('HTTP/1.1 101 Switching Protocols')

    socket
  end

  # Reads one text frame with a timeout and parses its JSON payload.
  # @return [Hash] server message
  def read_message(socket)
    frame = Timeout.timeout(5) { Lich::WebUI::WebSocket.read_frame(socket, require_mask: false) }
    raise 'WebSocket closed before acceptance completed' unless frame&.text?

    JSON.parse(frame.payload)
  end

  # Reads messages until the predicate accepts one or the probe deadline expires.
  # @yield [message] acceptance predicate
  # @return [Hash] accepted message
  def read_until(socket)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    loop do
      raise 'timed out waiting for WebUI message' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      message = read_message(socket)
      return message if yield(message)
    end
  end

  # Sends a JSON protocol message using the masked fixture frame encoder.
  # @return [Integer] bytes written
  def send_message(socket, payload)
    socket.write(Lich::WebUI::WebSocket.encode_client_frame(JSON.generate(payload)))
  end

  # Searches the delivered tree depth-first for the first predicate match.
  # @return [Hash, nil] matching component
  def find_component(component, &predicate)
    return component if predicate.call(component)

    component.fetch('children', []).each do |child|
      found = find_component(child, &predicate)
      return found if found
    end
    nil
  end

  # Verifies that the probed launcher method still comes from production source.
  # @return [String] repository-relative file and line
  # @raise [RuntimeError] if the method was replaced
  def launcher_source(method_name)
    path, line = Lich::Common::WebUILauncher.instance_method(method_name).source_location
    raise "launcher #{method_name} was replaced" unless path&.end_with?('/lib/common/webui_launcher.rb')

    "lib/common/webui_launcher.rb:#{line}"
  end

  # Reports the writable roots the entrypoint actually resolved, plus its working
  # directory, so the supervisor can verify each one lies in the temporary root.
  # @return [Hash{String => String}] root name to expanded path
  def effective_roots
    roots = %i[LICH_DIR DATA_DIR TEMP_DIR SCRIPT_DIR MAP_DIR LOG_DIR BACKUP_DIR].to_h do |name|
      [name.to_s, File.expand_path(Object.const_get(name).to_s)]
    end
    roots['ACTIVE_SESSION_DIR'] = File.expand_path(ACTIVE_SESSION_DIR.to_s) if defined?(ACTIVE_SESSION_DIR)
    roots['NATIVE_HELPER_DIR'] = File.dirname(@native_fixture.fetch(:executable))
    roots['working_directory'] = Dir.pwd
    roots
  end

  # Publishes one complete JSON result in the parent's isolated temporary root.
  # @param result [Hash] acceptance result
  # @return [void]
  def report(result)
    DefaultWebUIAcceptanceReport.publish(ENV.fetch('LICH_CI_DEFAULT_WEBUI_REPORT'), result)
  end
end

LichCiDefaultWebUIAcceptance.install!
