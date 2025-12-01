require 'socket'

module Lich
  module Common
    # Provides platform-specific TCP socket configuration for reliable network connections.
    #
    # This module configures TCP sockets with optimal settings for game client connections,
    # handling the significant differences between Windows and Unix-like operating systems.
    # It provides comprehensive error handling and logging for troubleshooting connection issues.
    #
    # @example Basic usage
    #   socket = TCPSocket.open('game.server.com', 4000)
    #   SocketConfigurator.configure(socket)
    #
    # @example Custom configuration for unstable connections
    #   SocketConfigurator.configure(socket,
    #     keepalive: { enable: true, idle: 180, interval: 60 },
    #     timeout: { recv: 60, send: 60 }
    #   )
    #
    # @note Windows support requires the 'ffi' gem for low-level socket operations
    # @note Configuration failures are logged but won't prevent socket usage
    #
    # @since 5.0.0
    module SocketConfigurator
      if Gem.win_platform?
        Lich::Util.install_gem_requirements({ "ffi" => true })

        # Windows-specific FFI bindings for low-level socket operations.
        #
        # This module provides access to Windows Winsock2 (Ws2_32.dll) functions
        # that aren't directly available through Ruby's standard Socket library.
        # It defines the necessary constants, structures, and function bindings
        # for advanced TCP socket configuration on Windows.
        #
        # @note This module is only loaded on Windows platforms
        # @api private
        module WinFFI
          extend FFI::Library
          ffi_lib 'Ws2_32', 'msvcrt'

          # WSAIoctl command code for setting TCP keep-alive parameters
          SIO_KEEPALIVE_VALS = 0x98000004

          # Socket option level for socket-level options
          SOL_SOCKET = 0xffff

          # Socket option to enable/disable keep-alive
          SO_KEEPALIVE = 0x0008

          # Socket option to control connection linger on close
          SO_LINGER   = 0x0080

          # Socket option to set receive timeout
          SO_RCVTIMEO = 0x1006

          # Socket option to set send timeout
          SO_SNDTIMEO = 0x1005

          # Socket option to set receive buffer size
          SO_RCVBUF   = 0x1002

          # Socket option to set send buffer size
          SO_SNDBUF   = 0x1003

          # Protocol number for TCP
          IPPROTO_TCP = 6

          # TCP option to disable Nagle's algorithm
          TCP_NODELAY = 0x0001

          # TCP option to set maximum retransmission time
          TCP_MAXRT   = 5

          # Structure for configuring TCP keep-alive parameters on Windows.
          #
          # @!attribute [rw] onoff
          #   @return [Integer] 1 to enable keep-alive, 0 to disable
          # @!attribute [rw] keepalivetime
          #   @return [Integer] Time in milliseconds before first keep-alive probe
          # @!attribute [rw] keepaliveinterval
          #   @return [Integer] Time in milliseconds between keep-alive probes
          class TcpKeepalive < FFI::Struct
            layout :onoff, :ulong,
                   :keepalivetime, :ulong,
                   :keepaliveinterval, :ulong
          end

          # Structure for configuring connection linger behavior on Windows.
          #
          # @!attribute [rw] l_onoff
          #   @return [Integer] 1 to enable linger, 0 to disable
          # @!attribute [rw] l_linger
          #   @return [Integer] Linger timeout in seconds
          class Linger < FFI::Struct
            layout :l_onoff, :ushort,
                   :l_linger, :ushort
          end

          # Structure for timeout values on Windows.
          #
          # @!attribute [rw] tv_sec
          #   @return [Integer] Seconds component of timeout
          # @!attribute [rw] tv_usec
          #   @return [Integer] Microseconds component of timeout
          class Timeval < FFI::Struct
            layout :tv_sec, :long,
                   :tv_usec, :long
          end

          # Performs control operations on a socket (Windows-specific).
          #
          # @param socket [Integer] Socket file descriptor
          # @param dwIoControlCode [Integer] Control code for the operation
          # @param lpvInBuffer [FFI::Pointer] Pointer to input buffer
          # @param cbInBuffer [Integer] Size of input buffer
          # @param lpvOutBuffer [FFI::Pointer] Pointer to output buffer
          # @param cbOutBuffer [Integer] Size of output buffer
          # @param lpcbBytesReturned [FFI::Pointer] Pointer to bytes returned
          # @param lpOverlapped [FFI::Pointer] Pointer to overlapped structure
          # @param lpCompletionRoutine [FFI::Pointer] Pointer to completion routine
          # @return [Integer] 0 on success, SOCKET_ERROR on failure
          attach_function :WSAIoctl, [:int, :ulong, :pointer, :ulong,
                                      :pointer, :ulong, :pointer,
                                      :pointer, :pointer], :int

          # Sets socket options (Windows-specific).
          #
          # @param socket [Integer] Socket file descriptor
          # @param level [Integer] Protocol level (e.g., SOL_SOCKET, IPPROTO_TCP)
          # @param optname [Integer] Option name
          # @param optval [FFI::Pointer] Pointer to option value
          # @param optlen [Integer] Size of option value
          # @return [Integer] 0 on success, SOCKET_ERROR on failure
          attach_function :setsockopt, [:int, :int, :int, :pointer, :int], :int

          # Converts a C runtime file descriptor to a Windows OS file handle.
          # This is critical because Ruby's socket.fileno returns a CRT file descriptor,
          # but Winsock2 functions need the actual Windows SOCKET handle.
          #
          # @param fd [Integer] C runtime file descriptor
          # @return [Integer] Windows OS file handle (SOCKET handle)
          attach_function :_get_osfhandle, [:int], :long
        end
      end

      # -------------------------
      # Public interface
      # -------------------------

      # Configures a TCP socket with optimal settings for reliable game connections.
      #
      # This method applies platform-specific socket options to improve connection
      # reliability, especially under network stress conditions. It automatically
      # detects the platform and applies appropriate settings.
      #
      # @param sock [TCPSocket] The socket to configure
      # @param keepalive [Hash] TCP keep-alive configuration
      # @option keepalive [Boolean] :enable (true) Enable TCP keep-alive probes
      # @option keepalive [Integer] :idle (120) Seconds before first keep-alive probe
      # @option keepalive [Integer] :interval (30) Seconds between keep-alive probes
      # @param linger [Hash] Connection linger configuration
      # @option linger [Boolean] :enable (true) Enable connection linger on close
      # @option linger [Integer] :timeout (5) Seconds to wait for data to send on close
      # @param timeout [Hash] Socket timeout configuration
      # @option timeout [Integer] :recv (30) Receive timeout in seconds
      # @option timeout [Integer] :send (30) Send timeout in seconds
      # @param buffer_size [Hash] Socket buffer size configuration
      # @option buffer_size [Integer] :recv (32768) Receive buffer size in bytes
      # @option buffer_size [Integer] :send (32768) Send buffer size in bytes
      # @param tcp_nodelay [Boolean] (true) Disable Nagle's algorithm for low latency
      # @param tcp_maxrt [Integer] (10) Maximum TCP retransmissions (Windows only)
      #
      # @return [void]
      #
      # @raise [SystemCallError] If socket configuration fails critically
      #
      # @example Configure with default settings
      #   socket = TCPSocket.open('server.com', 4000)
      #   SocketConfigurator.configure(socket)
      #
      # @example Configure for unstable connections
      #   SocketConfigurator.configure(socket,
      #     keepalive: { enable: true, idle: 180, interval: 60 },
      #     timeout: { recv: 60, send: 60 }
      #   )
      #
      # @example Configure for low-latency connections
      #   SocketConfigurator.configure(socket,
      #     keepalive: { enable: true, idle: 60, interval: 10 },
      #     timeout: { recv: 10, send: 10 },
      #     buffer_size: { recv: 65536, send: 65536 }
      #   )
      #
      # @note Configuration failures are logged but won't prevent socket usage
      # @note Windows requires the 'ffi' gem for advanced configuration
      # @note Keep-alive times on Windows are converted from seconds to milliseconds
      def self.configure(sock,
                         keepalive: { enable: true, idle: 120, interval: 30 },
                         linger: { enable: true, timeout: 5 },
                         timeout: { recv: 30, send: 30 },
                         buffer_size: { recv: 32768, send: 32768 },
                         tcp_nodelay: true,
                         tcp_maxrt: 10)
        Lich.log("Configuring socket: keepalive=#{keepalive}, linger=#{linger}, timeout=#{timeout}, buffer_size=#{buffer_size}, tcp_nodelay=#{tcp_nodelay}, tcp_maxrt=#{tcp_maxrt}") if ARGV.include?("--debug")

        begin
          if Gem.win_platform?
            configure_windows(sock, keepalive, linger, timeout, buffer_size, tcp_nodelay, tcp_maxrt)
          else
            configure_unix(sock, keepalive, linger, timeout, buffer_size, tcp_nodelay)
          end
          Lich.log("Socket configuration successful") if ARGV.include?("--debug")
        rescue => e
          Lich.log("Socket configuration failed: #{e.class} - #{e.message}\n\t#{e.backtrace.join("\n\t")}") if ARGV.include?("--debug")
          raise
        end
      end

      # -------------------------
      # Unix / Linux / macOS
      # -------------------------

      # Configures socket for Unix-like operating systems (Linux, macOS, BSD).
      #
      # This method uses Ruby's native Socket API to configure socket options.
      # It handles platform-specific constant availability (e.g., TCP_KEEPIDLE vs
      # TCP_KEEPALIVE on different Unix variants).
      #
      # @param sock [TCPSocket] The socket to configure
      # @param keepalive [Hash] Keep-alive configuration
      # @param linger [Hash] Linger configuration
      # @param timeout [Hash] Timeout configuration
      # @param buffer_size [Hash] Buffer size configuration
      # @param tcp_nodelay [Boolean] TCP_NODELAY flag
      #
      # @return [void]
      #
      # @raise [SystemCallError] If a critical socket option cannot be set
      #
      # @note Linux supports TCP_USER_TIMEOUT for controlling retransmission timeout
      # @note macOS uses TCP_KEEPALIVE instead of TCP_KEEPIDLE
      # @api private
      def self.configure_unix(sock, keepalive, linger, timeout, buffer_size, tcp_nodelay)
        # Helper: error-checked setsockopt
        check_setsockopt = lambda do |level, option, value, size|
          begin
            ret = sock.setsockopt(level, option, value, size)
            if ret != 0
              errno_val = defined?(Errno.errno) ? Errno.errno : 0
              raise SystemCallError.new("setsockopt(level=#{level}, option=#{option})", errno_val)
            end
          rescue => e
            Lich.log("Unix setsockopt failed: level=#{level}, option=#{option}, error=#{e.message}") if ARGV.include?("--debug")
            raise
          end
        end

        # Keepalive
        if keepalive[:enable]
          check_setsockopt.call(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, 1, 4)
          if Socket.const_defined?(:TCP_KEEPIDLE)
            check_setsockopt.call(Socket::IPPROTO_TCP, Socket::TCP_KEEPIDLE, keepalive[:idle], 4)
          elsif Socket.const_defined?(:TCP_KEEPALIVE)
            check_setsockopt.call(Socket::IPPROTO_TCP, Socket::TCP_KEEPALIVE, keepalive[:idle], 4)
          end
          check_setsockopt.call(Socket::IPPROTO_TCP, Socket::TCP_KEEPINTVL, keepalive[:interval], 4) if Socket.const_defined?(:TCP_KEEPINTVL)
          check_setsockopt.call(Socket::IPPROTO_TCP, Socket::TCP_KEEPCNT, 5, 4) if Socket.const_defined?(:TCP_KEEPCNT)
        end

        # Linger
        if linger
          linger_struct = [linger[:enable] ? 1 : 0, linger[:timeout]].pack("ii")
          check_setsockopt.call(Socket::SOL_SOCKET, Socket::SO_LINGER, linger_struct, linger_struct.bytesize)
        end

        # Timeouts
        if timeout
          check_setsockopt.call(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, [timeout[:recv], 0].pack("l!l!"), 8)
          check_setsockopt.call(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, [timeout[:send], 0].pack("l!l!"), 8)
        end

        # Buffer sizes
        if buffer_size
          check_setsockopt.call(Socket::SOL_SOCKET, Socket::SO_RCVBUF, [buffer_size[:recv]].pack('l'), 4) if buffer_size[:recv]
          check_setsockopt.call(Socket::SOL_SOCKET, Socket::SO_SNDBUF, [buffer_size[:send]].pack('l'), 4) if buffer_size[:send]
        end

        # TCP_NODELAY
        check_setsockopt.call(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1, 4) if tcp_nodelay

        # TCP_USER_TIMEOUT (Linux only - how long to retry before giving up)
        if Socket.const_defined?(:TCP_USER_TIMEOUT)
          user_timeout_ms = 120000 # 120 seconds
          check_setsockopt.call(Socket::IPPROTO_TCP, Socket::TCP_USER_TIMEOUT, user_timeout_ms, 4)
        end
      rescue => e
        Lich.log("Unix socket configuration error: #{e.class} - #{e.message}") if ARGV.include?("--debug")
        raise
      end

      # -------------------------
      # Windows
      # -------------------------

      # Configures socket for Windows operating systems.
      #
      # This method uses FFI to access Winsock2 functions directly, as Ruby's
      # Socket API has limited support for advanced Windows socket options.
      # It handles the significant differences in Windows TCP stack behavior,
      # particularly around keep-alive configuration.
      #
      # @param sock [TCPSocket] The socket to configure
      # @param keepalive [Hash] Keep-alive configuration (times converted to milliseconds)
      # @param linger [Hash] Linger configuration
      # @param timeout [Hash] Timeout configuration
      # @param buffer_size [Hash] Buffer size configuration
      # @param tcp_nodelay [Boolean] TCP_NODELAY flag
      # @param tcp_maxrt [Integer] Maximum retransmission count
      #
      # @return [void]
      #
      # @raise [SystemCallError] If a critical socket option cannot be set
      #
      # @note Keep-alive is configured in two steps: enable SO_KEEPALIVE, then WSAIoctl
      # @note All time values are converted from seconds to milliseconds for Windows
      # @note TCP_MAXRT may not be supported on older Windows versions
      # @api private
      # Configures socket for Windows operating systems.
      #
      # This method uses Ruby's Socket API with platform-specific packing for most options,
      # only falling back to FFI for WSAIoctl (keep-alive parameters). This approach works
      # with Ruby 3.x on Windows which uses UCRT and doesn't map sockets to CRT file descriptors.
      #
      # @param sock [TCPSocket] The socket to configure
      # @param keepalive [Hash] Keep-alive configuration (times converted to milliseconds)
      # @param linger [Hash] Linger configuration
      # @param timeout [Hash] Timeout configuration
      # @param buffer_size [Hash] Buffer size configuration
      # @param tcp_nodelay [Boolean] TCP_NODELAY flag
      # @param tcp_maxrt [Integer] Maximum retransmission count
      #
      # @return [void]
      #
      # @raise [SystemCallError] If a critical socket option cannot be set
      #
      # @note Uses Ruby's Socket API for most options, FFI only for WSAIoctl
      # @note All time values are converted from seconds to milliseconds for Windows
      # @note TCP_MAXRT may not be supported on older Windows versions
      # @api private
      def self.configure_windows(sock, keepalive, linger, timeout, buffer_size, tcp_nodelay, tcp_maxrt)
        # Helper: error-checked setsockopt using Ruby's Socket API
        check_setsockopt = lambda do |level, option, value|
          begin
            sock.setsockopt(level, option, value)
            Lich.log("Windows setsockopt succeeded: level=#{level}, option=#{option}") if ARGV.include?("--debug")
          rescue => e
            Lich.log("Windows setsockopt failed: level=#{level}, option=#{option}, error=#{e.class}: #{e.message}") if ARGV.include?("--debug")
            raise SystemCallError.new("setsockopt(level=#{level}, option=#{option})", 0)
          end
        end

        # Keepalive - Step 1: Enable SO_KEEPALIVE using Ruby's API
        if keepalive[:enable]
          check_setsockopt.call(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, [1].pack('i'))

          # Step 2: Try to configure keep-alive parameters via WSAIoctl
          # This may fail on Ruby 3.x, so we'll catch and log but continue
          begin
            crt_fd = sock.fileno
            fd = WinFFI._get_osfhandle(crt_fd)

            if fd != -1
              ka = WinFFI::TcpKeepalive.new
              ka[:onoff] = 1
              ka[:keepalivetime] = keepalive[:idle] * 1000
              ka[:keepaliveinterval] = keepalive[:interval] * 1000
              bytes_returned = FFI::MemoryPointer.new(:ulong)

              ret = WinFFI.WSAIoctl(fd, WinFFI::SIO_KEEPALIVE_VALS, ka.to_ptr, ka.size,
                                    nil, 0, bytes_returned, nil, nil)
              if ret == 0
                Lich.log("WSAIoctl keepalive configuration succeeded") if ARGV.include?("--debug")
              else
                errno = FFI.errno
                Lich.log("WSAIoctl keepalive failed (errno=#{errno}), using default Windows keepalive settings") if ARGV.include?("--debug")
              end
            else
              Lich.log("Could not get OS handle for WSAIoctl, using default Windows keepalive settings") if ARGV.include?("--debug")
            end
          rescue => e
            Lich.log("WSAIoctl keepalive configuration failed: #{e.class} - #{e.message}") if ARGV.include?("--debug")
            Lich.log("Continuing with basic keepalive enabled (default Windows settings)") if ARGV.include?("--debug")
          end
        end

        # Linger - using Ruby's Socket API
        if linger
          linger_bytes = [linger[:enable] ? 1 : 0, linger[:timeout]].pack('SS')
          check_setsockopt.call(Socket::SOL_SOCKET, Socket::SO_LINGER, linger_bytes)
        end

        # Timeouts - using Ruby's Socket API
        if timeout
          # Windows expects timeout in milliseconds as a DWORD (4 bytes)
          recv_timeout_ms = timeout[:recv] * 1000
          send_timeout_ms = timeout[:send] * 1000
          check_setsockopt.call(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, [recv_timeout_ms].pack('L'))
          check_setsockopt.call(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, [send_timeout_ms].pack('L'))
        end

        # Buffer sizes - using Ruby's Socket API
        if buffer_size
          check_setsockopt.call(Socket::SOL_SOCKET, Socket::SO_RCVBUF, [buffer_size[:recv]].pack('i')) if buffer_size[:recv]
          check_setsockopt.call(Socket::SOL_SOCKET, Socket::SO_SNDBUF, [buffer_size[:send]].pack('i')) if buffer_size[:send]
        end

        # TCP_NODELAY - using Ruby's Socket API
        if tcp_nodelay
          check_setsockopt.call(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, [1].pack('i'))
        end

        # TCP_MAXRT - Windows-specific, may not be supported
        if tcp_maxrt
          begin
            # Try using Ruby's API first
            if defined?(Socket::TCP_MAXRT)
              check_setsockopt.call(Socket::IPPROTO_TCP, Socket::TCP_MAXRT, [tcp_maxrt].pack('i'))
            else
              Lich.log("TCP_MAXRT constant not available in Ruby's Socket API") if ARGV.include?("--debug")
            end
          rescue => e
            Lich.log("TCP_MAXRT not supported on this Windows version: #{e.message}") if ARGV.include?("--debug")
          end
        end

        Lich.log("Windows socket configuration completed successfully") if ARGV.include?("--debug")
      rescue => e
        Lich.log("Windows socket configuration error: #{e.class} - #{e.message}") if ARGV.include?("--debug")
        raise
      end
    end
  end
end
