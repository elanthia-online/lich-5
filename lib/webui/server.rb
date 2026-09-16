# frozen_string_literal: true

require 'digest/sha1'
require 'securerandom'
require 'socket'
require 'uri'
require_relative 'file_service'
require_relative 'protocol'
require_relative 'websocket'

module Lich
  module WebUI
    # Authenticated loopback-only HTTP/WebSocket service for native WebUI pages.
    class Server
      COOKIE_NAME = 'lich_webui'
      MAX_HEADER_BYTES = 8192
      READ_TIMEOUT = 5
      WS_POLL_INTERVAL = 0.25
      LAUNCH_TOKEN_LIFETIME = 60
      CSP = "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; " \
            "connect-src 'self'; frame-src 'none'; object-src 'none'; base-uri 'none'; " \
            "form-action 'self'; frame-ancestors 'none'"
      ASSET_ROUTES = {
        '/'               => ['index.html', 'text/html; charset=utf-8'],
        '/assets/app.js'  => ['app.js', 'text/javascript; charset=utf-8'],
        '/assets/app.css' => ['app.css', 'text/css; charset=utf-8'],
      }.freeze
      LOOPBACK_HOSTS = %w[127.0.0.1 ::1].freeze

      attr_reader :host, :port

      def initialize(assets_dir:, pages_provider:, message_handler:, disconnect_handler: nil, file_service: nil,
                     host: '127.0.0.1', port: 0, logger: nil,
                     server_factory: nil, thread_factory: nil)
        raise ArgumentError, "WebUI host must be loopback, got #{host.inspect}" unless LOOPBACK_HOSTS.include?(host)
        raise ArgumentError, 'port must be an Integer from 0 through 65535' unless port.is_a?(Integer) && port.between?(0, 65_535)
        raise ArgumentError, 'pages_provider must respond to call' unless pages_provider.respond_to?(:call)
        raise ArgumentError, 'message_handler must respond to call' unless message_handler.respond_to?(:call)
        if disconnect_handler && !disconnect_handler.respond_to?(:call)
          raise ArgumentError, 'disconnect_handler must respond to call'
        end
        raise ArgumentError, 'assets_dir must be a directory' unless File.directory?(assets_dir)

        @host = host
        @port = port
        @assets_dir = File.realpath(assets_dir)
        @pages_provider = pages_provider
        @message_handler = message_handler
        @disconnect_handler = disconnect_handler
        @file_service = file_service
        @logger = logger || proc { |_level, _message| }
        @server_factory = server_factory || ->(bind_host, bind_port) { TCPServer.new(bind_host, bind_port) }
        @thread_factory = thread_factory || ->(*args, &block) { Thread.new(*args, &block) }
        @session_token = SecureRandom.hex(32)
        @launch_tokens = {}
        @server = nil
        @accept_thread = nil
        @client_threads = []
        @connections = []
        @mutex = Mutex.new
        @stopping = false
      end

      def start
        @mutex.synchronize do
          return self if running_locked?

          @stopping = false
          @server = @server_factory.call(host, port)
          bound = @server.addr
          unless loopback_address?(bound[3])
            @server.close
            @server = nil
            raise Error, "WebUI listener resolved outside loopback: #{bound[3]}"
          end
          @port = bound[1]
          @accept_thread = @thread_factory.call { accept_loop }
        end
        self
      rescue StandardError
        stop
        raise
      end

      def running?
        @mutex.synchronize { running_locked? }
      end

      def connection_count
        @mutex.synchronize { @connections.count(&:alive?) }
      end

      def launch_url(to: '/')
        raise Error, 'WebUI server is not running' unless running?
        target = valid_redirect_target?(to) ? to : '/'
        token = SecureRandom.hex(32)
        @mutex.synchronize do
          expire_launch_tokens!
          @launch_tokens[token] = monotonic_time + LAUNCH_TOKEN_LIFETIME
        end
        "http://#{url_host}:#{port}/auth?token=#{token}&to=#{URI.encode_www_form_component(target)}"
      end

      def broadcast(payload)
        json = payload.is_a?(String) ? payload : JSON.generate(payload)
        connections = @mutex.synchronize { @connections.dup }
        connections.each { |connection| connection.send_text(json) }
      end

      def stop
        server = nil
        accept_thread = nil
        clients = nil
        connections = nil
        @mutex.synchronize do
          @stopping = true
          server = @server
          accept_thread = @accept_thread
          clients = @client_threads.dup
          connections = @connections.dup
          @server = nil
          @accept_thread = nil
          @client_threads.clear
          @connections.clear
          @launch_tokens.clear
        end
        connections.each(&:close)
        server&.close
        join_or_kill(accept_thread)
        clients.each { |thread| join_or_kill(thread) }
        nil
      rescue IOError, SystemCallError
        nil
      end

      # Authenticated WebSocket connection. The viewer id is generated server-side.
      class Connection
        attr_reader :socket, :viewer_id

        def initialize(socket)
          @socket = socket
          @viewer_id = "viewer-#{SecureRandom.hex(16)}"
          @write_mutex = Mutex.new
          @alive = true
        end

        def alive? = @alive

        def send_text(payload)
          write(WebSocket.encode_text_message(payload))
        end

        def send_pong(payload)
          write(WebSocket.encode_frame(payload, opcode: WebSocket::OPCODE_PONG))
        end

        def close
          return unless @alive

          @alive = false
          @socket.shutdown(Socket::SHUT_RDWR)
        rescue IOError, SystemCallError
          nil
        end

        private

        def write(bytes)
          return false unless @alive

          @write_mutex.synchronize { @socket.write(bytes) }
          true
        rescue IOError, SystemCallError
          @alive = false
          false
        end
      end

      private

      def accept_loop
        loop do
          listener = @mutex.synchronize { @server }
          break unless listener

          socket = listener.accept
          thread = @thread_factory.call(socket) { |client| handle_client_thread(client) }
          @mutex.synchronize { @client_threads << thread }
        rescue IOError, Errno::EBADF
          break if stopping?
          raise
        rescue StandardError => error
          socket&.close
          log(:warning, "WebUI accept refusal=#{error.class}")
        end
      end

      def handle_client_thread(socket)
        handle_client(socket)
      ensure
        @mutex.synchronize { @client_threads.delete(Thread.current) }
      end

      def handle_client(socket)
        websocket = false
        request = read_request(socket)
        return unless request
        return respond_error(socket, 403, 'Forbidden') unless host_allowed?(request)
        return respond_error(socket, 403, 'Forbidden') unless fetch_metadata_allowed?(request)

        case request[:path]
        when '/auth' then handle_auth(socket, request)
        when '/ws'
          websocket = true
          return handle_websocket(socket, request)
        when *ASSET_ROUTES.keys then handle_asset(socket, request)
        when %r{\A/files/([A-Za-z0-9_-]{1,128})/(.+)\z}
          handle_file(socket, request, Regexp.last_match(1), Regexp.last_match(2))
        else
          respond_error(socket, 404, 'Not Found')
        end
      rescue StandardError => error
        log(:warning, "WebUI request refused=#{error.class}")
        respond_error(socket, 400, 'Bad Request') unless websocket
      ensure
        begin
          socket.close unless websocket
        rescue IOError, SystemCallError
          nil
        end
      end

      def read_request(socket)
        deadline = monotonic_time + READ_TIMEOUT
        buffer = +''
        until buffer.include?("\r\n\r\n")
          remaining = deadline - monotonic_time
          return nil unless remaining.positive? && IO.select([socket], nil, nil, remaining)

          chunk = socket.read_nonblock(4096, exception: false)
          return nil if chunk.nil?
          next if chunk == :wait_readable

          buffer << chunk
          raise Error, 'HTTP request headers are too large' if buffer.bytesize > MAX_HEADER_BYTES
        end
        parse_request(buffer)
      end

      def parse_request(raw)
        head = raw.split("\r\n\r\n", 2).first
        lines = head.split("\r\n")
        method, target, version = lines.shift.to_s.split(' ', 3)
        raise Error, 'malformed request line' unless method && target&.start_with?('/') && version == 'HTTP/1.1'
        raise Error, 'absolute or scheme-relative request target refused' if target.start_with?('//')

        headers = {}
        lines.each do |line|
          name, value = line.split(':', 2)
          raise Error, 'malformed header' unless name && value
          key = name.strip.downcase
          raise Error, "duplicate HTTP header #{key}" if headers.key?(key)
          headers[key] = value.strip
        end
        content_length = Integer(headers.fetch('content-length', '0'), exception: false)
        raise Error, 'invalid Content-Length' unless content_length&.between?(0, Protocol::MAX_MESSAGE_BYTES)
        raise Error, 'request bodies are not accepted' unless content_length.zero?

        path, query = target.split('?', 2)
        { method: method, path: path, query: query, headers: headers }
      end

      def handle_auth(socket, request)
        return respond_error(socket, 405, 'Method Not Allowed') unless request[:method] == 'GET'

        params = URI.decode_www_form(request[:query].to_s).to_h
        token = params['token'].to_s
        accepted = @mutex.synchronize do
          expire_launch_tokens!
          expiry = @launch_tokens.delete(token)
          expiry && expiry >= monotonic_time
        end
        return respond_error(socket, 403, 'Forbidden') unless accepted

        target = valid_redirect_target?(params['to']) ? params['to'] : '/'
        respond(
          socket, 302, 'Found', '',
          extra_headers: [
            "Location: #{target}",
            "Set-Cookie: #{COOKIE_NAME}=#{@session_token}; HttpOnly; SameSite=Strict; Path=/",
            'Referrer-Policy: no-referrer',
          ]
        )
      rescue ArgumentError
        respond_error(socket, 400, 'Bad Request')
      end

      def handle_asset(socket, request)
        return respond_error(socket, 405, 'Method Not Allowed') unless request[:method] == 'GET'
        return respond_error(socket, 403, 'Forbidden') unless authorized?(request)
        return respond_error(socket, 403, 'Forbidden') unless origin_allowed_if_present?(request)

        filename, content_type = ASSET_ROUTES.fetch(request[:path])
        path = File.join(@assets_dir, filename)
        return respond_error(socket, 404, 'Not Found') unless File.file?(path)

        body = File.binread(path)
        etag = %Q("#{Digest::SHA1.hexdigest(body)}")
        if request[:headers]['if-none-match'] == etag
          respond(socket, 304, 'Not Modified', '', extra_headers: ["ETag: #{etag}"])
        else
          respond(socket, 200, 'OK', body, content_type: content_type, extra_headers: ["ETag: #{etag}"])
        end
      end

      def handle_file(socket, request, alias_name, relative_path)
        return respond_error(socket, 405, 'Method Not Allowed') unless request[:method] == 'GET'
        return respond_error(socket, 403, 'Forbidden') unless authorized?(request)
        return respond_error(socket, 403, 'Forbidden') unless origin_allowed_if_present?(request)
        return respond_error(socket, 404, 'Not Found') unless @file_service

        resolved = @file_service.resolve(alias_name, relative_path)
        return respond_error(socket, 404, 'Not Found') unless resolved

        path, content_type, = resolved
        respond(socket, 200, 'OK', File.binread(path), content_type: content_type, cache_control: 'private, max-age=60')
      end

      def handle_websocket(socket, request)
        unless request[:method] == 'GET' && authorized?(request) && origin_allowed?(request)
          return respond_error(socket, 403, 'Forbidden')
        end
        headers = request[:headers]
        unless headers['upgrade'].to_s.casecmp('websocket').zero? &&
               headers['connection'].to_s.downcase.split(/\s*,\s*/).include?('upgrade') &&
               headers['sec-websocket-version'] == '13' && headers['sec-websocket-key']
          return respond_error(socket, 400, 'Bad Request')
        end

        socket.write(
          "HTTP/1.1 101 Switching Protocols\r\n" \
          "Upgrade: websocket\r\n" \
          "Connection: Upgrade\r\n" \
          "Sec-WebSocket-Accept: #{WebSocket.accept_key(headers['sec-websocket-key'])}\r\n\r\n"
        )
        connection = Connection.new(socket)
        @mutex.synchronize { @connections << connection }
        connection.send_text(Protocol.hello(viewer_id: connection.viewer_id, pages: @pages_provider.call))
        websocket_loop(connection)
      ensure
        if connection
          begin
            @disconnect_handler&.call(connection)
          rescue StandardError => error
            log(:warning, "WebUI disconnect handler failed=#{error.class}")
          end
          connection.close
          @mutex.synchronize { @connections.delete(connection) }
        end
        begin
          socket.close
        rescue IOError, SystemCallError
          nil
        end
      end

      def websocket_loop(connection)
        while connection.alive?
          next unless IO.select([connection.socket], nil, nil, WS_POLL_INTERVAL)

          frame = WebSocket.read_frame(connection.socket)
          break unless frame
          break if frame.close?
          if frame.ping?
            connection.send_pong(frame.payload)
          elsif frame.text?
            dispatch_message(connection, frame.payload)
          end
        end
      rescue WebSocket::ProtocolError => error
        log(:warning, "WebUI websocket refusal=#{error.class}")
      end

      def dispatch_message(connection, raw)
        message = Protocol.parse_client_message(raw)
        @message_handler.call(connection, message)
      rescue Protocol::Refusal => error
        log(:warning, "WebUI message refusal=#{error.reason}")
        connection.send_text(Protocol.refusal(reason: error.reason, message: 'Message refused'))
      rescue StandardError => error
        log(:warning, "WebUI handler refusal=#{error.class}")
        connection.send_text(Protocol.refusal(reason: :handler, message: 'Message refused'))
      end

      def authorized?(request)
        Protocol.secure_compare(@session_token, cookie_token(request))
      end

      def cookie_token(request)
        request[:headers]['cookie'].to_s.split(';').each do |pair|
          name, value = pair.split('=', 2)
          return value.to_s.strip if name.to_s.strip == COOKIE_NAME
        end
        nil
      end

      def host_allowed?(request)
        allowed_hosts.include?(request[:headers]['host'].to_s)
      end

      def allowed_hosts
        hosts = ["127.0.0.1:#{port}", "localhost:#{port}"]
        hosts << "[::1]:#{port}" if host == '::1'
        hosts
      end

      def origin_allowed?(request)
        origin = request[:headers]['origin'].to_s
        allowed_hosts.any? { |allowed| origin == "http://#{allowed}" }
      end

      def origin_allowed_if_present?(request)
        origin = request[:headers]['origin']
        origin.nil? || origin_allowed?(request)
      end

      def fetch_metadata_allowed?(request)
        site = request[:headers]['sec-fetch-site']
        return false if site && !%w[same-origin none].include?(site)

        mode = request[:headers]['sec-fetch-mode']
        return true unless mode
        return %w[websocket cors].include?(mode) if request[:path] == '/ws'
        return mode == 'navigate' if request[:path] == '/auth' || request[:path] == '/'

        %w[no-cors same-origin cors].include?(mode)
      end

      def websocket_upgrade?(request)
        request && request[:path] == '/ws' && request[:headers]['upgrade'].to_s.casecmp('websocket').zero?
      end

      def respond(socket, status, reason, body, content_type: 'text/plain; charset=utf-8',
                  cache_control: 'no-store', extra_headers: [])
        headers = [
          "HTTP/1.1 #{status} #{reason}", "Content-Length: #{body.bytesize}",
          'Connection: close', "Cache-Control: #{cache_control}", 'Referrer-Policy: no-referrer',
          'X-Content-Type-Options: nosniff', "Content-Security-Policy: #{CSP}",
        ]
        headers << "Content-Type: #{content_type}" unless body.empty?
        headers.concat(extra_headers)
        socket.write(headers.join("\r\n") + "\r\n\r\n" + body)
      end

      def respond_error(socket, status, reason)
        respond(socket, status, reason, reason)
      end

      def expire_launch_tokens!
        now = monotonic_time
        @launch_tokens.delete_if { |_token, expiry| expiry < now }
      end

      def valid_redirect_target?(target)
        target.is_a?(String) && target.start_with?('/') && !target.start_with?('//') && !target.match?(/[\r\n]/)
      end

      def loopback_address?(address)
        LOOPBACK_HOSTS.include?(address)
      end

      def url_host
        host == '::1' ? '[::1]' : host
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def running_locked?
        @accept_thread&.alive? || false
      end

      def stopping?
        @mutex.synchronize { @stopping }
      end

      def join_or_kill(thread)
        return unless thread

        thread.join(0.5)
        thread.kill if thread.alive?
      end

      def log(level, message)
        @logger.call(level, message)
      rescue StandardError
        nil
      end
    end
  end
end
