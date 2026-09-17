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
    #
    # The server owns the listening socket and one thread per client. It serves the
    # static client assets and registered files over HTTP, hands a browser its session
    # cookie through a one-shot launch token, upgrades `/ws` to a WebSocket, and passes
    # every parsed client message to the `message_handler` (the {Runtime}). It never
    # binds outside loopback and refuses requests whose Host, Origin or Fetch Metadata
    # headers say they came from anywhere else.
    class Server
      # The session cookie's name carries the port, because a browser keys
      # cookies by host and ignores the port: two Lich sessions on
      # 127.0.0.1, both setting `lich_webui`, overwrote each other's token
      # and the first session's next authenticated request was refused.
      #
      # @return [String] the cookie name prefix; the port is appended per instance
      COOKIE_NAME = 'lich_webui'
      # @return [Integer] the most bytes of request head accepted before the request is refused
      MAX_HEADER_BYTES = 8192
      # A served file is read whole into memory before it goes out. Anything
      # a page could sensibly show fits in this; anything larger is refused
      # with a stat, not a read.
      #
      # @return [Integer] the largest file `/files/` will serve, in bytes
      MAX_FILE_BYTES = 32 * 1024 * 1024
      # @return [Integer] seconds a client has to send its request head
      READ_TIMEOUT = 5
      # @return [Float] seconds the WebSocket loop waits on select between liveness checks
      WS_POLL_INTERVAL = 0.25
      # @return [Integer] seconds a launch token from {#launch_url} stays valid
      LAUNCH_TOKEN_LIFETIME = 60
      # For a URL a player has to carry somewhere: printed to a console or a
      # game window, tunnelled, pasted. Sixty seconds covered a browser Lich
      # opened itself and not this (review 2026-09-17 (c), Major 2).
      #
      # @return [Integer] seconds a carried launch URL stays valid
      REMOTE_LAUNCH_TOKEN_LIFETIME = 600
      # @return [String] the 403 body for an expired or reused launch link
      EXPIRED_LAUNCH_MESSAGE = 'This launch link has expired or was already used. Have Lich print a fresh one: ' \
                               'reopen the window, or call Lich::API.webui_launch_url.'
      # @return [String] the Content-Security-Policy every response carries
      CSP = "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; " \
            "connect-src 'self'; frame-src 'none'; object-src 'none'; base-uri 'none'; " \
            "form-action 'self'; frame-ancestors 'none'"
      # @return [Hash{String => Array(String, String)}] request path to `[asset filename, content type]`
      ASSET_ROUTES = {
        '/'               => ['index.html', 'text/html; charset=utf-8'],
        '/assets/app.js'  => ['app.js', 'text/javascript; charset=utf-8'],
        '/assets/app.css' => ['app.css', 'text/css; charset=utf-8'],
      }.freeze
      # @return [Array<String>] the only addresses the server may bind
      LOOPBACK_HOSTS = %w[127.0.0.1 ::1].freeze

      # @!attribute [r] host
      #   @return [String] the loopback address the server binds
      # @!attribute [r] port
      #   @return [Integer] the bound port; 0 until {#start} when an ephemeral port was requested
      attr_reader :host, :port

      # Creates a server; nothing listens until {#start}.
      #
      # @param assets_dir [String] directory holding `index.html`, `app.js` and `app.css`
      # @param pages_provider [#call] returns the page list sent in the WebSocket `hello`
      # @param message_handler [#call] receives `(connection, message)` for every parsed client message
      # @param disconnect_handler [#call, nil] receives `(connection)` when a WebSocket closes
      # @param file_service [FileService, nil] resolves `/files/<alias>/<path>` requests; nil serves none
      # @param host [String] a {LOOPBACK_HOSTS} address to bind
      # @param port [Integer] the port to bind, 0 for an ephemeral one
      # @param logger [#call, nil] receives `(level, message)`; nil discards
      # @param server_factory [#call, nil] builds the listener from `(host, port)`; defaults to TCPServer
      # @param thread_factory [#call, nil] spawns threads like `Thread.new`; defaults to Thread.new
      # @return [Server] the new server
      # @raise [ArgumentError] when the host is not loopback, the port is out of range, a handler does
      #   not respond to call, or assets_dir is not a directory
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

      # Binds the listener and starts the accept thread; a no-op when already running.
      #
      # @return [Server] self
      # @raise [Error] when the bound address resolved outside loopback
      # @raise [SystemCallError] when the port cannot be bound
      def start
        @mutex.synchronize do
          return self if running_locked?

          # A listener whose accept loop died (killed thread) still holds the
          # port; release it before binding again.
          begin
            @server&.close
          rescue IOError, SystemCallError
            nil
          end
          @server = nil
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

      # Whether the accept thread is alive.
      #
      # @return [Boolean] true while the server is accepting connections
      def running?
        @mutex.synchronize { running_locked? }
      end

      # Counts the WebSocket connections that are still alive.
      #
      # @return [Integer] the live connection count
      def connection_count
        @mutex.synchronize { @connections.count(&:alive?) }
      end

      # Mints a one-shot launch URL that sets the session cookie and redirects into the client.
      #
      # @param to [String] the path to land on after authentication; anything that is not a plain
      #   local path falls back to `/`
      # @param lifetime [Integer] seconds the token stays valid; {LAUNCH_TOKEN_LIFETIME} for a
      #   browser opened at once, {REMOTE_LAUNCH_TOKEN_LIFETIME} for a URL the player carries
      # @return [String] an `http://<host>:<port>/auth?token=...&to=...` URL
      # @raise [Error] when the server is not running
      def launch_url(to: '/', lifetime: LAUNCH_TOKEN_LIFETIME)
        raise Error, 'WebUI server is not running' unless running?
        target = valid_redirect_target?(to) ? to : '/'
        token = SecureRandom.hex(32)
        @mutex.synchronize do
          expire_launch_tokens!
          @launch_tokens[token] = monotonic_time + lifetime
        end
        "http://#{url_host}:#{port}/auth?token=#{token}&to=#{URI.encode_www_form_component(target)}"
      end

      # Sends one text message to every current WebSocket connection.
      #
      # @param payload [String, Object] JSON text, or an object to encode with `JSON.generate`
      # @return [Array<Connection>] the connections the message was sent to
      def broadcast(payload)
        json = payload.is_a?(String) ? payload : JSON.generate(payload)
        connections = @mutex.synchronize { @connections.dup }
        connections.each { |connection| connection.send_text(json) }
      end

      # Closes every connection and the listener, and joins or kills the server's threads.
      #
      # Safe to call when not running.
      #
      # @return [nil]
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
      #
      # One per upgraded socket. Writes are serialised and bounded by {WRITE_TIMEOUT}; a
      # write that cannot complete in time marks the connection dead rather than blocking
      # the caller, and the server's loop then closes it.
      class Connection
        # How long a write may wait for the peer to drain its socket before the
        # connection is declared dead. Runtime#refresh writes synchronously on
        # whatever thread asked for it -- in the shim that is a script's own
        # session thread -- so a browser that stopped reading (a suspended
        # laptop, a frozen tab) used to park that script forever.
        #
        # @return [Float] the default write budget in seconds
        WRITE_TIMEOUT = 10.0

        # @!attribute [r] socket
        #   @return [BasicSocket] the upgraded client socket
        # @!attribute [r] viewer_id
        #   @return [String] the server-minted id that names this connection to the runtime
        attr_reader :socket, :viewer_id

        # Wraps an upgraded socket as a live connection with a fresh viewer id.
        #
        # @param socket [BasicSocket] the client socket after the WebSocket handshake
        # @param write_timeout [Numeric] seconds a single write may take before the connection is dead
        # @return [Connection] the new connection
        def initialize(socket, write_timeout: WRITE_TIMEOUT)
          @socket = socket
          @viewer_id = "viewer-#{SecureRandom.hex(16)}"
          @write_mutex = Mutex.new
          @write_timeout = write_timeout
          @alive = true
        end

        # Whether the connection is still usable.
        #
        # @return [Boolean] false once closed or once a write failed or timed out
        def alive? = @alive

        # Sends one WebSocket text frame.
        #
        # @param payload [String] the text to send, normally JSON
        # @return [Boolean] true when fully written; false when the connection is or became dead
        def send_text(payload)
          write(WebSocket.encode_text_message(payload))
        end

        # Answers a ping with a pong carrying the same payload.
        #
        # @param payload [String] the ping frame's payload
        # @return [Boolean] true when fully written; false when the connection is or became dead
        def send_pong(payload)
          write(WebSocket.encode_frame(payload, opcode: WebSocket::OPCODE_PONG))
        end

        # Marks the connection dead and shuts the socket down in both directions.
        #
        # @return [nil]
        def close
          return unless @alive

          @alive = false
          @socket.shutdown(Socket::SHUT_RDWR)
        rescue IOError, SystemCallError
          nil
        end

        private

        # Writes the bytes under the write lock within one deadline; false and dead on failure.
        def write(bytes)
          return false unless @alive

          # One deadline for the whole operation, taken before waiting for the
          # writer's turn: a write queued behind a stalled one is stalled too,
          # and the budget is the caller's, not each wait's.
          deadline = monotonic_time + @write_timeout
          return give_up! unless acquire_write_lock(deadline)

          begin
            write_within_deadline(bytes, deadline)
          ensure
            @write_mutex.unlock
          end
        rescue IOError, SystemCallError
          @alive = false
          false
        end

        # Never blocks past the deadline: a full send buffer waits on select
        # for only what is left of the budget, so a peer that drains slowly
        # cannot keep a large render write alive by making progress a byte at
        # a time. The connection is dead when the budget runs out.
        def write_within_deadline(bytes, deadline)
          remaining = bytes.b
          until remaining.empty?
            written = begin
              @socket.write_nonblock(remaining, exception: false)
            rescue IO::WaitWritable
              :wait_writable
            end
            if written == :wait_writable
              budget = deadline - monotonic_time
              return give_up! if budget <= 0 || !IO.select(nil, [@socket], nil, budget)

              next
            end
            remaining = remaining.byteslice(written, remaining.bytesize - written)
          end
          true
        end

        # Mutex has no timed lock; the wait for it is polled against the
        # deadline so that a writer stuck behind a stalled peer's write gives
        # up on schedule too instead of queueing forever.
        #
        # @return [Float] seconds between attempts to take the write lock
        LOCK_POLL_INTERVAL = 0.005

        # Polls for the write lock until taken or the deadline passes.
        def acquire_write_lock(deadline)
          until @write_mutex.try_lock
            return false if monotonic_time >= deadline

            sleep(LOCK_POLL_INTERVAL)
          end
          true
        end

        # Declares the connection dead; returns false so a write can return it directly.
        def give_up!
          @alive = false
          false
        end

        # The monotonic clock, in seconds.
        def monotonic_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end

      private

      # Accepts clients until the listener is closed, one handler thread each.
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

      # Runs handle_client and drops the thread from the client list when done.
      def handle_client_thread(socket)
        handle_client(socket)
      ensure
        @mutex.synchronize { @client_threads.delete(Thread.current) }
      end

      # Reads one request, checks its origin headers, and routes it by path.
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

      # Reads the request head within READ_TIMEOUT and MAX_HEADER_BYTES; nil when the client goes quiet.
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

      # Parses an HTTP/1.1 request head into method, path, query and lower-cased headers; bodies are refused.
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

      # Exchanges a live launch token for the session cookie and redirects to the requested path.
      def handle_auth(socket, request)
        return respond_error(socket, 405, 'Method Not Allowed') unless request[:method] == 'GET'

        params = URI.decode_www_form(request[:query].to_s).to_h
        token = params['token'].to_s
        accepted = @mutex.synchronize do
          expire_launch_tokens!
          expiry = @launch_tokens.delete(token)
          expiry && expiry >= monotonic_time
        end
        return respond(socket, 403, 'Forbidden', EXPIRED_LAUNCH_MESSAGE) unless accepted

        target = valid_redirect_target?(params['to']) ? params['to'] : '/'
        respond(
          socket, 302, 'Found', '',
          extra_headers: [
            "Location: #{target}",
            "Set-Cookie: #{cookie_name}=#{@session_token}; HttpOnly; SameSite=Strict; Path=/",
            'Referrer-Policy: no-referrer',
          ]
        )
      rescue ArgumentError
        respond_error(socket, 400, 'Bad Request')
      end

      # Serves one of ASSET_ROUTES to an authenticated client, honouring If-None-Match.
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

      # Serves a registered file through the file service, refusing anything over MAX_FILE_BYTES.
      def handle_file(socket, request, alias_name, relative_path)
        return respond_error(socket, 405, 'Method Not Allowed') unless request[:method] == 'GET'
        return respond_error(socket, 403, 'Forbidden') unless authorized?(request)
        return respond_error(socket, 403, 'Forbidden') unless origin_allowed_if_present?(request)
        return respond_error(socket, 404, 'Not Found') unless @file_service

        resolved = @file_service.resolve(alias_name, relative_path)
        return respond_error(socket, 404, 'Not Found') unless resolved

        path, content_type, = resolved
        return respond_error(socket, 413, 'Payload Too Large') if File.size(path) > MAX_FILE_BYTES

        respond(socket, 200, 'OK', File.binread(path), content_type: content_type, cache_control: 'private, max-age=60')
      end

      # Completes the WebSocket handshake, sends hello, and runs the frame loop until the socket closes.
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

      # Reads frames while the connection lives: pongs pings, dispatches text, stops on close.
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

      # Parses one text frame and hands it to the message handler; failures answer with a refusal.
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

      # Whether the request carries this instance's session cookie.
      def authorized?(request)
        Protocol.secure_compare(@session_token, cookie_token(request))
      end

      # The value of this instance's session cookie in the request, or nil.
      def cookie_token(request)
        request[:headers]['cookie'].to_s.split(';').each do |pair|
          name, value = pair.split('=', 2)
          return value.to_s.strip if name.to_s.strip == cookie_name
        end
        nil
      end

      # Per server instance: see COOKIE_NAME.
      def cookie_name
        "#{COOKIE_NAME}_#{port}"
      end

      # Whether the Host header names this server on loopback.
      def host_allowed?(request)
        allowed_hosts.include?(request[:headers]['host'].to_s)
      end

      # The host:port spellings a request may address this server by.
      def allowed_hosts
        hosts = ["127.0.0.1:#{port}", "localhost:#{port}"]
        hosts << "[::1]:#{port}" if host == '::1'
        hosts
      end

      # Whether the Origin header is one of this server's own origins.
      def origin_allowed?(request)
        origin = request[:headers]['origin'].to_s
        allowed_hosts.any? { |allowed| origin == "http://#{allowed}" }
      end

      # Like origin_allowed?, but a request without an Origin header passes.
      def origin_allowed_if_present?(request)
        origin = request[:headers]['origin']
        origin.nil? || origin_allowed?(request)
      end

      # Checks Sec-Fetch-Site and Sec-Fetch-Mode against what each route legitimately sees.
      def fetch_metadata_allowed?(request)
        site = request[:headers]['sec-fetch-site']
        return false if site && !%w[same-origin none].include?(site)

        mode = request[:headers]['sec-fetch-mode']
        return true unless mode
        return %w[websocket cors].include?(mode) if request[:path] == '/ws'
        return mode == 'navigate' if request[:path] == '/auth' || request[:path] == '/'

        %w[no-cors same-origin cors].include?(mode)
      end

      # Writes a complete HTTP/1.1 response with the hardening headers every response carries.
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

      # A plain-text error response whose body is the reason phrase.
      def respond_error(socket, status, reason)
        respond(socket, status, reason, reason)
      end

      # Drops launch tokens past their expiry. Caller holds @mutex.
      def expire_launch_tokens!
        now = monotonic_time
        @launch_tokens.delete_if { |_token, expiry| expiry < now }
      end

      # A local absolute path with no scheme-relative prefix or header-breaking newlines.
      def valid_redirect_target?(target)
        target.is_a?(String) && target.start_with?('/') && !target.start_with?('//') && !target.match?(/[\r\n]/)
      end

      # Whether an address is one of LOOPBACK_HOSTS.
      def loopback_address?(address)
        LOOPBACK_HOSTS.include?(address)
      end

      # The host as it appears in a URL: IPv6 loopback is bracketed.
      def url_host
        host == '::1' ? '[::1]' : host
      end

      # The monotonic clock, in seconds.
      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # Whether the accept thread is alive. Caller holds @mutex.
      def running_locked?
        @accept_thread&.alive? || false
      end

      # Whether stop has begun.
      def stopping?
        @mutex.synchronize { @stopping }
      end

      # Joins a thread briefly, killing it if it does not finish.
      def join_or_kill(thread)
        return unless thread

        thread.join(0.5)
        thread.kill if thread.alive?
      end

      # Hands a line to the logger; a logger that raises is ignored.
      def log(level, message)
        @logger.call(level, message)
      rescue StandardError
        nil
      end
    end
  end
end
