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
    #   port. The connection method Lich has always used. Automatically
    #   falls back to {WEBSOCKET} if the raw TCP connect itself can't reach
    #   the host -- the shape a firewall blocking the game port while
    #   leaving 443 open actually takes. Mirrors
    #   Authenticator.authenticate's EAccess -> WebLogin fallback from #1570.
    # - {WEBSOCKET} (also selectable explicitly) -- the game host's browser
    #   WebSocket-to-TCP shim, reached over TLS on port 443. See
    #   https://github.com/GenieClient/Genie5/issues/356 (phase 2): the shim
    #   relays whatever bytes the client sends, so nothing above the
    #   transport layer needs to change -- only how the bytes get there.
    #   Confirmed live end-to-end against both production DragonRealms and
    #   GemStone IV: first via a standalone script sending the web client's
    #   own "<c>{key}\n<c>/FE:WebFE .../XML" handshake, then via a real Lich
    #   session -- whose frontend sends a plain "{key}\n/FE:WRAYTH .../XML"
    #   (no "<c>" prefix, a different /FE: value) -- played for an extended,
    #   interactive session and shut down cleanly. See
    #   docs/websocket-shim-probe-findings.md (pass 3) for the full writeup.
    #
    # @see Lich::Common::WebSocket::Stream
    module GameTransport
      DIRECT    = :direct
      WEBSOCKET = :websocket
      MODES = [DIRECT, WEBSOCKET].freeze

      # Raised by {.open} for any +mode+ other than {DIRECT} or {WEBSOCKET}.
      class UnknownModeError < ArgumentError; end

      # Bounds {DIRECT}'s TCP connect so a firewalled/blocked port (packets
      # silently dropped, no RST) fails in seconds instead of the OS's
      # default SYN-retry timeout (commonly 60s+ on Linux) -- same rationale
      # as EAccess::CONNECT_TIMEOUT. Without this, the fallback below would
      # still work, just not "fail fast" in any meaningful sense.
      DIRECT_CONNECT_TIMEOUT = 10

      # Berkeley-socket-level errors consistent with "this host/port isn't
      # reachable" -- a blocked port, a captive network, a DNS resolver that
      # only permits certain domains -- as opposed to a fatal problem the
      # WebSocket transport would hit identically (in which case falling
      # back would just delay the real error). Mirrors
      # Authenticator.authenticate's EAccess -> WebLogin fallback: only
      # falls back on transport-level unreachability.
      #
      # IO::TimeoutError is in this list, not just Errno::ETIMEDOUT:
      # Socket.tcp's fast-fallback connector (Ruby 3.4+) raises
      # IO::TimeoutError -- an IOError, not an Errno class -- for a connect
      # timeout against a hostname (a bare IP literal still raises
      # Errno::ETIMEDOUT). Since GAMEHOST is always a hostname, this is the
      # exception a blocked-port firewall actually produces.
      #
      # EACCES/EPERM are POSIX connect(2)'s documented errors for "a local
      # firewall rule forbids this connection" -- deliberately included, not
      # just a leftover reachability code: Lich is normally run by the same
      # person the local block (if any) belongs to, most often their own
      # Windows Firewall, VPN client, or a work laptop's MDM policy getting
      # in the way of their own tool, not a third party's restriction this
      # transport should respect blindly. A local block that genuinely is
      # someone else's deliberate policy still fails, just after a slightly
      # slower detour through the WebSocket attempt.
      DIRECT_CONNECTIVITY_ERRORS = [
        Errno::ETIMEDOUT,
        Errno::ECONNREFUSED,
        Errno::EHOSTUNREACH,
        Errno::ENETUNREACH,
        Errno::EACCES,
        Errno::EPERM,
        IO::TimeoutError,
        SocketError
      ].freeze

      # The same fast-fallback connector can also raise a bare
      # SystemCallError -- not the matching Errno subclass -- carrying only
      # the raw platform errno, observed on Windows for a refused port (WSA
      # 10061) where Errno::ECONNREFUSED above never matches. These are the
      # WSA codes for the classes in DIRECT_CONNECTIVITY_ERRORS: WSAENETUNREACH,
      # WSAETIMEDOUT, WSAECONNREFUSED, WSAEHOSTUNREACH, WSAEACCES (Windows
      # Firewall blocking the connection).
      WINDOWS_CONNECTIVITY_ERRNOS = [10_051, 10_060, 10_061, 10_065, 10_013].freeze

      # @return [Boolean] whether +error+ is one {.open_direct} should fall
      #   back to {WEBSOCKET} for -- either a class in
      #   {DIRECT_CONNECTIVITY_ERRORS} or a bare {SystemCallError} carrying
      #   one of {WINDOWS_CONNECTIVITY_ERRNOS} (see its comment)
      def self.direct_connectivity_error?(error)
        return true if DIRECT_CONNECTIVITY_ERRORS.any? { |klass| error.is_a?(klass) }

        error.is_a?(SystemCallError) && WINDOWS_CONNECTIVITY_ERRNOS.include?(error.errno)
      end

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
      # @param opts [Hash] forwarded to {.open_websocket} -- either directly
      #   (+mode: WEBSOCKET+) or if {DIRECT} falls back to it
      # @return [Socket, Lich::Common::WebSocket::Stream] a connected,
      #   configured, drop-in-compatible game socket -- #puts, #gets,
      #   #wait_readable, #close, #closed?, #sync=
      # @raise [UnknownModeError]
      def self.open(host, port, mode: DIRECT, **opts)
        case mode
        when DIRECT
          open_direct(host, port, **opts)
        when WEBSOCKET
          open_websocket(host, port, **opts)
        else
          raise UnknownModeError, "unknown game transport mode: #{mode.inspect} (expected one of #{MODES.inspect})"
        end
      end

      # @api private
      # Automatically falls back to {.open_websocket} if the raw TCP connect
      # can't reach +host+:+port+ at all -- see {DIRECT_CONNECTIVITY_ERRORS}
      # for exactly which failures count, and the module doc for why.
      # @param websocket_opts [Hash] forwarded to {.open_websocket} if the
      #   direct connect fails and a fallback is attempted
      def self.open_direct(host, port, **websocket_opts)
        socket = Socket.tcp(host, port, connect_timeout: DIRECT_CONNECT_TIMEOUT)
        configure_socket(socket, host)
        Lich.log "info: connected via direct TCP transport (#{host}:#{port})"
        socket
      rescue SystemCallError, IO::TimeoutError, SocketError => e
        raise unless direct_connectivity_error?(e)

        Lich.log "warn: direct TCP transport unreachable (#{host}:#{port}, #{e.class}: #{e.message}); " \
                 "falling back to WebSocket transport"
        begin
          open_websocket(host, port, fallback: true, **websocket_opts)
        rescue Lich::Common::WebSocket::Stream::ConnectionError => ws_error
          # Left alone, only ws_error would reach the caller -- naming port
          # 443 and the WebSocket host, not the game host:port that actually
          # failed. Whoever reads this (a log, a console error, a bug
          # report) needs the real failure, not just where the fallback
          # gave up.
          raise ws_error.class, "direct #{host}:#{port} unreachable (#{e.class}: #{e.message}); " \
                                 "WebSocket fallback also failed (#{ws_error.message})"
        end
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
      # @param fallback [Boolean] true when called from {.open_direct}'s
      #   automatic fallback rather than an explicit +mode: WEBSOCKET+ --
      #   purely a log-message annotation, no behavioral effect
      def self.open_websocket(host, port,
                              shim_port: DEFAULT_SHIM_PORT,
                              ws_host: websocket_host_for(host),
                              path: format(DEFAULT_SHIM_PATH_FORMAT, port: port),
                              origin: format(DEFAULT_ORIGIN_FORMAT, host: ws_host),
                              subprotocol: DEFAULT_SUBPROTOCOL,
                              user_agent: DEFAULT_USER_AGENT,
                              extra_headers: {},
                              connect_timeout: 10,
                              fallback: false)
        stream = Lich::Common::WebSocket::Stream.connect(
          host: ws_host,
          port: shim_port,
          path: path,
          origin: origin,
          subprotocol: subprotocol,
          user_agent: user_agent,
          extra_headers: extra_headers,
          connect_timeout: connect_timeout
        ) { |raw_socket| configure_socket(raw_socket, ws_host) }

        remap_note = ws_host == host ? "" : " (remapped from GAMEHOST #{host})"
        fallback_note = fallback ? " (fallback from direct TCP)" : ""
        Lich.log "info: connected via WebSocket transport (wss://#{ws_host}:#{shim_port}#{path}#{remap_note}#{fallback_note})"
        stream
      rescue Lich::Common::WebSocket::Stream::ConnectionError => e
        Lich.log "warn: WebSocket transport connect failed (wss://#{ws_host}:#{shim_port}#{path}): #{e.message}"
        raise
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
