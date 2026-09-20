# frozen_string_literal: true

require "socket"
require "openssl"
require_relative "frame"
require_relative "handshake"

module Lich
  module Common
    module WebSocket
      # A WebSocket connection presented as a drop-in replacement for the
      # TCPSocket that {Lich::Common::Games::Game.open} normally hands to
      # +@socket+: #puts, #gets, #wait_readable, #close, #closed?, #sync=,
      # #to_io. Everything above the transport (line-based XML parsing,
      # the reader/parser threads) stays unaware that the bytes underneath
      # are riding inside RFC 6455 frames over TLS on 443 instead of a raw
      # game-port socket -- see Genie5#356 phase 2.
      #
      # @see Lich::Common::GameTransport
      class Stream
        # Raised when the underlying TCP connect, TLS handshake, or
        # WebSocket upgrade fails. Callers (see {Lich::Common::GameTransport})
        # treat this the same as any other failed {.open} attempt.
        class ConnectionError < StandardError; end

        # Opens a TCP connection, wraps it in TLS, performs the WebSocket
        # opening handshake, and returns a ready-to-use Stream.
        #
        # @param host [String] hostname to dial, present via SNI, verify the
        #   TLS certificate against, and send as the handshake's Host header
        #   -- all four uses share the one value, exactly like a browser's
        #   `new WebSocket(url)` derives all of them from the URL's host.
        #   Callers that need a different hostname than the raw GAMEHOST
        #   (see {Lich::Common::GameTransport}, which knows the real client
        #   dials a fixed per-family host rather than the literal GAMEHOST)
        #   are expected to resolve that before calling here, not pass the
        #   unresolved GAMEHOST and expect this method to compensate.
        # @param port [Integer] TCP port to connect to (443 for the shim)
        # @param path [String] request path, e.g. "/shim/1234"
        # @param origin [String, nil] Origin header for the handshake
        # @param subprotocol [String, nil] Sec-WebSocket-Protocol to request
        # @param user_agent [String, nil] User-Agent header for the handshake
        # @param extra_headers [Hash] extra handshake headers
        # @param connect_timeout [Numeric] seconds to bound the TCP connect
        # @yield [TCPSocket] the raw, not-yet-TLS-wrapped socket, immediately
        #   after connect -- the hook {Lich::Common::GameTransport} uses to
        #   apply {Lich::Common::SocketConfigurator} before TLS/WS overhead begins
        # @return [Stream]
        # @raise [ConnectionError] on a TCP/TLS failure or handshake rejection
        def self.connect(host:, port:, path:, origin: nil, subprotocol: nil,
                         user_agent: nil, extra_headers: {}, connect_timeout: 10)
          raw_socket = Socket.tcp(host, port, connect_timeout: connect_timeout)
          yield raw_socket if block_given?

          ssl_socket = wrap_tls(raw_socket, host)
          key = Handshake.generate_key
          ssl_socket.write(Handshake.request(host: host, path: path, key: key, origin: origin,
                                             subprotocol: subprotocol, user_agent: user_agent,
                                             extra_headers: extra_headers))

          header_block, remainder = read_handshake_response(ssl_socket)
          Handshake.validate_response(header_block, key: key, subprotocol: subprotocol)

          new(ssl_socket, prefill: remainder)
        rescue StandardError => e
          raw_socket&.close rescue nil
          raise ConnectionError, "#{e.class}: #{e.message}"
        end

        # @api private
        def self.wrap_tls(raw_socket, host)
          ctx = OpenSSL::SSL::SSLContext.new
          ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
          ssl_socket = OpenSSL::SSL::SSLSocket.new(raw_socket, ctx)
          ssl_socket.hostname = host # enables SNI and post-connect hostname verification
          ssl_socket.sync_close = true
          ssl_socket.connect
          ssl_socket
        end
        private_class_method :wrap_tls

        # Reads raw bytes until the "\r\n\r\n" header terminator is seen.
        # Whatever arrives past it in the same read is already WebSocket
        # frame data, not handshake header -- it's handed back as +remainder+
        # so the caller can feed it straight into the frame reader instead
        # of losing it.
        #
        # @return [Array(String, String)] [header_block, remainder]
        def self.read_handshake_response(io)
          buffer = +"".b
          until buffer.include?("\r\n\r\n")
            chunk = io.readpartial(4096)
            buffer << chunk
          end
          header_block, _sep, remainder = buffer.partition("\r\n\r\n")
          [header_block, remainder]
        rescue EOFError
          raise Handshake::Error, "connection closed during handshake"
        end
        private_class_method :read_handshake_response

        # @param io [OpenSSL::SSL::SSLSocket] a connected socket, past the WS opening handshake
        # @param prefill [String] any frame bytes already read past the handshake response
        def initialize(io, prefill: "".b)
          @io = io
          @reader = Frame::Reader.new
          @line_buffer = +"".b
          @write_mutex = Mutex.new
          @closed = false
          @eof = false
          ingest(@reader.feed(prefill)) unless prefill.empty?
        end

        # Sends +str+ as a single text frame, appending "\n" if it doesn't
        # already end with one -- mirroring IO#puts, which is what callers
        # (Game._puts) expect.
        #
        # @param str [String]
        # @return [true]
        def puts(str)
          line = str.to_s
          line = "#{line}\n" unless line.end_with?("\n")
          write_frame(line, opcode: Frame::OPCODE_TEXT)
          true
        end

        # Blocks until a full line is available and returns it (including
        # its trailing newline, matching IO#gets), or returns nil at EOF.
        # A final, non-newline-terminated fragment left over at EOF is
        # returned once, then subsequent calls return nil -- also matching
        # IO#gets.
        #
        # @return [String, nil]
        def gets
          loop do
            line = extract_line!
            return line if line
            return flush_remaining! if @eof

            pump_until_readable!
          end
        end

        # @param timeout [Numeric, nil] seconds to wait; nil blocks indefinitely
        # @return [Boolean] true once a #gets call can return without blocking on the network
        def wait_readable(timeout = nil)
          return true if line_ready? || @eof

          deadline = timeout ? monotonic_now + timeout : nil
          loop do
            return true if line_ready? || @eof

            remaining = deadline ? deadline - monotonic_now : nil
            return false if deadline && remaining <= 0

            return true if pump_once(remaining)
          end
        end

        # Best-effort close handshake, then tears down the underlying socket.
        def close
          write_frame([1000].pack("n"), opcode: Frame::OPCODE_CLOSE) unless @closed
        rescue StandardError
          nil
        ensure
          @closed = true
          @io.close rescue nil
        end

        def closed?
          @closed || @io.closed?
        end

        # No-op: every #puts already writes one complete frame in a single
        # #write call, so there's no internal buffering to flush.
        def sync=(_value)
          true
        end

        def to_io
          @io.to_io
        end

        private

        def write_frame(payload, opcode:)
          @write_mutex.synchronize { @io.write(Frame.encode(payload, opcode: opcode)) }
        end

        def line_ready?
          @line_buffer.include?("\n")
        end

        def extract_line!
          idx = @line_buffer.index("\n")
          return nil unless idx

          line = @line_buffer.byteslice(0, idx + 1)
          @line_buffer = @line_buffer.byteslice((idx + 1)..-1) || +"".b
          line
        end

        def flush_remaining!
          return nil if @line_buffer.empty?

          line = @line_buffer
          @line_buffer = +"".b
          line
        end

        # Blocks (optionally bounded by +timeout+) until at least one pump
        # has run, then reports whether that made a line available.
        def pump_until_readable!
          loop do
            return if line_ready? || @eof

            return if pump_once(nil)
          end
        end

        # Waits for readable data (network wait, or an immediate return if
        # OpenSSL already has undelivered plaintext buffered -- see #pump!)
        # and pumps it into the frame reader once.
        #
        # @return [Boolean] true if a line became ready or EOF was reached
        def pump_once(timeout)
          unless @io.pending.positive?
            ready = @io.wait_readable(timeout)
            return false if ready.nil?
          end
          pump!
          line_ready? || @eof
        end

        # Drains everything currently available -- both freshly-arrived raw
        # bytes and any plaintext OpenSSL already decrypted but hadn't
        # handed back (OpenSSL::SSL::SSLSocket#pending) -- into the frame
        # reader. Looping on #pending here, rather than reading once per
        # wakeup, avoids the classic TLS-plus-select trap: #wait_readable
        # only reports the raw socket's readiness and knows nothing about
        # data OpenSSL is already holding internally, so leaving pending
        # data undrained can stall the next #wait_readable call until more
        # bytes happen to arrive on the wire.
        def pump!
          loop do
            chunk = @io.readpartial(8192)
            ingest(@reader.feed(chunk))
            break unless @io.pending.positive?
          end
        rescue IOError # covers EOFError, a subclass, too
          @eof = true
        rescue IO::WaitReadable
          nil # spurious wakeup mid-TLS-record; caller's loop will wait again
        end

        def ingest(messages)
          messages.each do |message|
            case message.opcode
            when Frame::OPCODE_TEXT, Frame::OPCODE_BINARY
              @line_buffer << message.payload
            when Frame::OPCODE_PING
              write_frame(message.payload, opcode: Frame::OPCODE_PONG)
            when Frame::OPCODE_PONG
              nil
            when Frame::OPCODE_CLOSE
              respond_to_close(message.payload)
              @eof = true
            end
          end
        end

        def respond_to_close(payload)
          return if @closed

          code = payload.bytesize >= 2 ? payload.byteslice(0, 2) : [1000].pack("n")
          write_frame(code, opcode: Frame::OPCODE_CLOSE)
        rescue StandardError
          nil
        ensure
          @closed = true
        end

        def monotonic_now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
