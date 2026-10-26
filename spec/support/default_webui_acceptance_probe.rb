# frozen_string_literal: true

require 'base64'
require 'fileutils'
require 'json'
require 'socket'
require 'timeout'
require 'uri'

acceptance_root = ENV.fetch('LICH_CI_DEFAULT_WEBUI_ROOT')
FileUtils.mkdir_p(acceptance_root)
DATA_DIR = File.join(acceptance_root, 'data').freeze unless defined?(DATA_DIR)
TEMP_DIR = File.join(acceptance_root, 'temp').freeze unless defined?(TEMP_DIR)
FileUtils.mkdir_p(DATA_DIR)
FileUtils.mkdir_p(TEMP_DIR)

module LichCiDefaultWebUIAcceptance
  module_function

  REQUIRED_TABS = ['Saved Entry', 'Manual Entry', 'Account Management', 'Frontends'].freeze
  GTK_FAMILY_PATTERN = /(?:gtk|gdk|gobject|glib)/i

  # Intercepts only browser opening after its class loads; leaves production startup/await intact.
  # This subprocess probe uses authenticated HTTP/WebSocket traffic, not a browser cookie jar.
  # @return [void]
  def install!
    @installer = TracePoint.new(:end) do |trace|
      next unless trace.path.end_with?('/webui/browser_launcher.rb')
      next unless defined?(Lich::WebUI::BrowserLauncher)
      next unless trace.self.equal?(Lich::WebUI::BrowserLauncher)

      client = Module.new do
        define_method(:open) do |url, **_options|
          LichCiDefaultWebUIAcceptance.start_client(url)
          true
        end
      end
      Lich::WebUI::BrowserLauncher.singleton_class.prepend(client)
      @installer.disable
    end
    @installer.enable
  end

  # Starts the probe client and writes a structured success/failure report to the parent pipe.
  # @return [Thread] client worker
  def start_client(url)
    @client = Thread.new do
      result = exercise(url)
      report(result)
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
    key = Base64.strict_encode64('lich-r3-acceptance')
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

  # Writes one JSON result to the inherited report descriptor, then closes that writer.
  # @return [void]
  def report(result)
    writer = IO.for_fd(Integer(ENV.fetch('LICH_CI_DEFAULT_WEBUI_FD')), 'w')
    writer.puts(JSON.generate(result))
    writer.flush
    writer.close
  end
end

LichCiDefaultWebUIAcceptance.install!
