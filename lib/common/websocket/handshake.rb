# frozen_string_literal: true

require "base64"
require "digest/sha1"
require "securerandom"

module Lich
  module Common
    module WebSocket
      # Builds the RFC 6455 HTTP/1.1 Upgrade request and validates the
      # server's response -- the opening handshake that precedes framed
      # WebSocket traffic (see {Lich::Common::WebSocket::Frame}).
      module Handshake
        # RFC 6455 1.3: fixed GUID concatenated with the client's key before
        # hashing to produce Sec-WebSocket-Accept.
        MAGIC_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

        # Raised when the server's response isn't a valid 101 upgrade, or
        # its Sec-WebSocket-Accept doesn't match what this request's key
        # requires -- including the play.net shim rejecting a non-browser
        # Origin/subprotocol/User-Agent, which Genie5#356 flags as an open
        # question never confirmed against the live endpoint.
        class Error < StandardError; end

        # @return [String] a fresh, base64-encoded 16-byte Sec-WebSocket-Key
        def self.generate_key
          Base64.strict_encode64(SecureRandom.bytes(16))
        end

        # @param key [String] the Sec-WebSocket-Key a request sent
        # @return [String] the Sec-WebSocket-Accept value a compliant server must answer with
        def self.accept_for(key)
          Base64.strict_encode64(Digest::SHA1.digest("#{key}#{MAGIC_GUID}"))
        end

        # Builds the raw HTTP request bytes for the opening handshake.
        #
        # @param host [String] Host header value (the game host, not the shim path)
        # @param path [String] request path, e.g. "/shim/1234"
        # @param key [String] this request's Sec-WebSocket-Key (see {generate_key})
        # @param origin [String, nil] Origin header -- play.net's WAF has previously
        #   been observed rejecting requests missing a browser-like identity (see
        #   docs/web-login-protocol-analysis.md); unconfirmed whether the shim itself checks it
        # @param subprotocol [String, nil] Sec-WebSocket-Protocol to request
        # @param user_agent [String, nil]
        # @param extra_headers [Hash] additional/overriding headers, applied last
        # @return [String] the full request, including the trailing blank line
        def self.request(host:, path:, key:, origin: nil, subprotocol: nil, user_agent: nil, extra_headers: {})
          headers = {
            "Host"                  => host,
            "Upgrade"               => "websocket",
            "Connection"            => "Upgrade",
            "Sec-WebSocket-Key"     => key,
            "Sec-WebSocket-Version" => "13"
          }
          headers["Origin"] = origin if origin
          headers["Sec-WebSocket-Protocol"] = subprotocol if subprotocol
          headers["User-Agent"] = user_agent if user_agent
          headers.merge!(extra_headers)

          lines = ["GET #{path} HTTP/1.1"]
          headers.each { |name, value| lines << "#{name}: #{value}" }
          "#{lines.join("\r\n")}\r\n\r\n"
        end

        # Parses and validates the server's handshake response.
        #
        # @param raw_response [String] the status line + headers block,
        #   WITHOUT the trailing "\r\n\r\n" or any bytes beyond it -- the
        #   caller (see {Stream.connect}) is responsible for splitting the
        #   header block off from whatever frame bytes may follow it in the
        #   same read
        # @param key [String] the Sec-WebSocket-Key the matching request sent
        # @param subprotocol [String, nil] if given, the response's
        #   negotiated Sec-WebSocket-Protocol must match exactly
        # @return [Hash{String => String}] lower-cased response headers
        # @raise [Error] on a non-101 status, a missing/mismatched Upgrade or
        #   Connection header, an accept-key mismatch, or an unexpected subprotocol
        def self.validate_response(raw_response, key:, subprotocol: nil)
          lines = raw_response.split("\r\n")
          status_line = lines.shift.to_s
          raise Error, "handshake rejected: #{status_line.empty? ? '(empty response)' : status_line}" unless status_line =~ %r{\AHTTP/1\.[01]\s+101\b}

          headers = parse_headers(lines)

          unless headers["upgrade"]&.downcase == "websocket"
            raise Error, "handshake response missing 'Upgrade: websocket' header: #{headers.inspect}"
          end
          unless headers["connection"]&.downcase&.split(/,\s*/)&.include?("upgrade")
            raise Error, "handshake response missing 'Connection: Upgrade' header: #{headers.inspect}"
          end

          expected_accept = accept_for(key)
          actual_accept = headers["sec-websocket-accept"]
          if actual_accept != expected_accept
            raise Error, "Sec-WebSocket-Accept mismatch (expected #{expected_accept.inspect}, got #{actual_accept.inspect})"
          end

          if subprotocol && headers["sec-websocket-protocol"] != subprotocol
            raise Error, "server did not accept subprotocol #{subprotocol.inspect} (got #{headers['sec-websocket-protocol'].inspect})"
          end

          headers
        end

        # @api private
        def self.parse_headers(lines)
          lines.each_with_object({}) do |line, headers|
            next if line.empty?

            name, value = line.split(":", 2)
            next unless name && value

            headers[name.strip.downcase] = value.strip
          end
        end
        private_class_method :parse_headers
      end
    end
  end
end
