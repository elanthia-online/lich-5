# frozen_string_literal: true

require "socket"
require_relative "socketconfigurator"
require_relative "websocket/stream"

module Lich
  module Common
    # Chooses and opens the transport {Game.open} speaks the wire protocol
    # over. Two modes:
    #
    # - {DIRECT} (default) -- a raw TCP socket to the game host's native
    #   port. The connection method Lich has always used.
    # - {WEBSOCKET} (opt-in) -- the game host's browser WebSocket-to-TCP
    #   shim, reached over TLS on port 443. See
    #   https://github.com/GenieClient/Genie5/issues/356 (phase 2): once
    #   connected, the shim speaks the same "<c>{key}\n<c>/FE:.../XML"
    #   handshake a native client sends over raw TCP, so nothing above the
    #   transport layer needs to change -- only how the bytes get there.
    #
    # WEBSOCKET is opt-in, not a fallback attempted automatically on a
    # failed DIRECT connect: the shim's tolerance of a non-browser client
    # (Origin / subprotocol / User-Agent enforcement) has not been confirmed
    # against the live endpoint -- see the "open questions" in Genie5#356.
    # Promoting it to an automatic fallback is a follow-up once that's
    # verified, not a default to ship blind.
    #
    # @see Lich::Common::WebSocket::Stream
    module GameTransport
      DIRECT    = :direct
      WEBSOCKET = :websocket
      MODES = [DIRECT, WEBSOCKET].freeze

      # Raised by {.open} for any +mode+ other than {DIRECT} or {WEBSOCKET}.
      class UnknownModeError < ArgumentError; end

      # Defaults for the WebSocket shim path/headers. Confirmed live against
      # play.net's own web client (`style/js/all_web_fe_min.js`,
      # `SimuSocket.tryWebSocket`) -- see docs/websocket-shim-probe-findings.md
      # for the full writeup and how these were pulled directly from that
      # bundle rather than guessed.
      DEFAULT_SHIM_PORT        = 443
      DEFAULT_SHIM_PATH_FORMAT = "/shim/%<port>d"
      DEFAULT_ORIGIN_FORMAT    = "https://%<host>s"
      DEFAULT_SUBPROTOCOL      = "websocket_shim-protocol"
      DEFAULT_USER_AGENT       = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " \
                                  "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

      # The real web client does not open its WebSocket against the literal
      # GAMEHOST -- `DynamicData.actualHost` in `all_web_fe_min.js` remaps it
      # to one of two fixed hostnames by matching a pattern against GAMEHOST,
      # in this order (first match wins, mirroring the source's own
      # if/elsif-equivalent ternary chain):
      #
      #   GAMEHOST =~ /gs|chimera/i  -> "chimera.play.net"  (GemStone family)
      #   GAMEHOST =~ /dr|hydra/i    -> "hydra.play.net"    (DragonRealms family)
      #   otherwise                  -> GAMEHOST unchanged (dead in practice --
      #                                 every known instance matches one of the above)
      #
      # This isn't a workaround for a TLS quirk -- it's what the shim actually
      # expects to be dialed at. It also happens to explain the TLS hostname
      # mismatch a naive literal-GAMEHOST connect hits: hydra.play.net and
      # chimera.play.net are both covered by the shared edge certificate's
      # *.play.net SAN; the raw GAMEHOST (e.g. dr.simutronics.net, a .net
      # name) is not. See docs/websocket-shim-probe-findings.md.
      WEBSOCKET_HOST_OVERRIDES = [
        [/gs|chimera/i, "chimera.play.net"],
        [/dr|hydra/i,   "hydra.play.net"]
      ].freeze

      # @param gamehost [String] the literal GAMEHOST from auth
      # @return [String] the hostname to actually dial/verify/Host-header for
      #   the WebSocket transport -- see {WEBSOCKET_HOST_OVERRIDES}
      def self.websocket_host_for(gamehost)
        _pattern, override = WEBSOCKET_HOST_OVERRIDES.find { |pattern, _| gamehost.match?(pattern) }
        override || gamehost
      end

      # @param host [String] game server hostname (GAMEHOST)
      # @param port [Integer] game server port (GAMEPORT) -- the real
      #   target port for {WEBSOCKET} mode (embedded in the shim path);
      #   the port actually dialed for {DIRECT} mode
      # @param mode [Symbol] {DIRECT} or {WEBSOCKET}
      # @param opts [Hash] forwarded to {.open_websocket} (ignored for {DIRECT})
      # @return [TCPSocket, Lich::Common::WebSocket::Stream] a connected,
      #   configured, drop-in-compatible game socket -- #puts, #gets,
      #   #wait_readable, #close, #closed?, #sync=
      # @raise [UnknownModeError]
      def self.open(host, port, mode: DIRECT, **opts)
        case mode
        when DIRECT
          open_direct(host, port)
        when WEBSOCKET
          open_websocket(host, port, **opts)
        else
          raise UnknownModeError, "unknown game transport mode: #{mode.inspect} (expected one of #{MODES.inspect})"
        end
      end

      # @api private
      def self.open_direct(host, port)
        socket = TCPSocket.open(host, port)
        configure_socket(socket, host)
        socket
      end

      # @api private
      # @param shim_port [Integer] TCP port to dial for the shim (443)
      # @param ws_host [String] hostname to actually dial/verify/Host-header;
      #   defaults to {.websocket_host_for}'s remap of +host+ (the literal
      #   GAMEHOST) -- override only to bypass that remap deliberately
      # @param path [String] shim request path; defaults to "/shim/{port}"
      # @param origin [String] Origin header; defaults to "https://{ws_host}"
      # @param subprotocol [String, nil] Sec-WebSocket-Protocol to request;
      #   pass nil to omit it entirely while probing the shim's requirements
      # @param user_agent [String, nil]
      # @param extra_headers [Hash]
      # @param connect_timeout [Numeric]
      def self.open_websocket(host, port,
                              shim_port: DEFAULT_SHIM_PORT,
                              ws_host: websocket_host_for(host),
                              path: format(DEFAULT_SHIM_PATH_FORMAT, port: port),
                              origin: format(DEFAULT_ORIGIN_FORMAT, host: ws_host),
                              subprotocol: DEFAULT_SUBPROTOCOL,
                              user_agent: DEFAULT_USER_AGENT,
                              extra_headers: {},
                              connect_timeout: 10)
        Lich::Common::WebSocket::Stream.connect(
          host: ws_host,
          port: shim_port,
          path: path,
          origin: origin,
          subprotocol: subprotocol,
          user_agent: user_agent,
          extra_headers: extra_headers,
          connect_timeout: connect_timeout
        ) { |raw_socket| configure_socket(raw_socket, ws_host) }
      end

      # Applies the same keepalive/linger/timeout/buffer tuning to +socket+
      # regardless of transport. For {WEBSOCKET} mode this runs on the raw
      # pre-TLS TCP socket (see the block passed to
      # {Lich::Common::WebSocket::Stream.connect} in {.open_websocket}) --
      # these are Berkeley-socket options, meaningless on the WebSocket
      # framing layered on top, so they have to land on the underlying fd
      # before it gets wrapped.
      #
      # @api private
      def self.configure_socket(socket, host)
        SocketConfigurator.configure(socket,
                                     keepalive: {
                                       enable: true,
                                       idle: 30,
                                       interval: 30
                                     },
                                     linger: {
                                       enable: true,
                                       timeout: 5
                                     },
                                     timeout: {
                                       recv: 30,
                                       send: 30
                                     },
                                     buffer_size: {
                                       recv: 32768,
                                       send: 32768
                                     },
                                     tcp_nodelay: true,
                                     tcp_maxrt: 10)
        Lich.log("Socket configured successfully for #{host}") if ARGV.include?("--debug")
      rescue StandardError => e
        Lich.log("Socket configuration error (continuing with defaults): #{e.class}: #{e.message}")
        Lich.log("WARNING: Socket running with default OS settings - may be less reliable under network stress")
      end
    end
  end
end
