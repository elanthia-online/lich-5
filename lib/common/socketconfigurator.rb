require 'socket'

module Lich
  module Common
    module SocketConfigurator
      if Gem.win_platform?
        Lich::Util.install_gem_requirements({ "ffi" => true })

        module WinFFI
          extend FFI::Library
          ffi_lib 'Ws2_32'

          SIO_KEEPALIVE_VALS = 0x98000004
          SOL_SOCKET  = 0xffff
          SO_LINGER   = 0x0080
          SO_RCVTIMEO = 0x1006
          SO_SNDTIMEO = 0x1005
          IPPROTO_TCP = 6
          TCP_NODELAY = 0x0001

          class TcpKeepalive < FFI::Struct
            layout :onoff, :ulong,
                   :keepalivetime, :ulong,
                   :keepaliveinterval, :ulong
          end

          class Linger < FFI::Struct
            layout :l_onoff, :ushort,
                   :l_linger, :ushort
          end

          class Timeval < FFI::Struct
            layout :tv_sec, :long,
                   :tv_usec, :long
          end

          attach_function :WSAIoctl, [:int, :ulong, :pointer, :ulong,
                                      :pointer, :ulong, :pointer,
                                      :pointer, :pointer], :int
          attach_function :setsockopt, [:int, :int, :int, :pointer, :int], :int
        end
      end

      # -------------------------
      # Public interface
      # -------------------------
      def self.configure(sock,
                         keepalive: { enable: true, idle: 60, interval: 10 },
                         linger: { enable: false, timeout: 5 },
                         timeout: { recv: 10, send: 10 },
                         buffer_size: { recv: nil, send: nil },
                         tcp_nodelay: true)
        if Gem.win_platform?
          configure_windows(sock, keepalive, linger, timeout, buffer_size, tcp_nodelay)
        else
          configure_unix(sock, keepalive, linger, timeout, buffer_size, tcp_nodelay)
        end
      end

      # -------------------------
      # Unix / Linux / macOS
      # -------------------------
      def self.configure_unix(sock, keepalive, linger, timeout, buffer_size, tcp_nodelay)
        # Helper: error-checked setsockopt
        check_setsockopt = lambda do |level, option, value, size|
          ret = sock.setsockopt(level, option, value, size)
          raise SystemCallError.new("setsockopt(#{option})", Errno::errno) if ret != 0
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
      end

      # -------------------------
      # Windows
      # -------------------------
      def self.configure_windows(sock, keepalive, linger, timeout, buffer_size, tcp_nodelay)
        fd = sock.fileno

        # Helper: error-checked setsockopt
        check_setsockopt = lambda do |level, option, ptr, size|
          ret = WinFFI.setsockopt(fd, level, option, ptr, size)
          raise SystemCallError.new("setsockopt(#{option})", FFI.errno) if ret != 0
        end

        # Keepalive
        if keepalive[:enable]
          ka = WinFFI::TcpKeepalive.new
          ka[:onoff] = 1
          ka[:keepalivetime] = keepalive[:idle] * 1000
          ka[:keepaliveinterval] = keepalive[:interval] * 1000
          bytes_returned = FFI::MemoryPointer.new(:ulong)
          ret = WinFFI.WSAIoctl(fd, WinFFI::SIO_KEEPALIVE_VALS, ka.to_ptr, ka.size,
                                nil, 0, bytes_returned, nil, nil)
          raise SystemCallError.new("WSAIoctl", FFI.errno) if ret != 0
        end

        # Linger
        if linger
          l = WinFFI::Linger.new
          l[:l_onoff] = linger[:enable] ? 1 : 0
          l[:l_linger] = linger[:timeout]
          check_setsockopt.call(WinFFI::SOL_SOCKET, WinFFI::SO_LINGER, l.to_ptr, l.size)
        end

        # Timeouts
        if timeout
          tv = WinFFI::Timeval.new
          tv[:tv_sec] = timeout[:recv]
          tv[:tv_usec] = 0
          check_setsockopt.call(WinFFI::SOL_SOCKET, WinFFI::SO_RCVTIMEO, tv.to_ptr, tv.size)

          tv[:tv_sec] = timeout[:send]
          check_setsockopt.call(WinFFI::SOL_SOCKET, WinFFI::SO_SNDTIMEO, tv.to_ptr, tv.size)
        end

        # Buffer sizes
        if buffer_size
          check_setsockopt.call(WinFFI::SOL_SOCKET, Socket::SO_RCVBUF, [buffer_size[:recv]].pack('l'), 4) if buffer_size[:recv]
          check_setsockopt.call(WinFFI::SOL_SOCKET, Socket::SO_SNDBUF, [buffer_size[:send]].pack('l'), 4) if buffer_size[:send]
        end

        # TCP_NODELAY
        check_setsockopt.call(WinFFI::IPPROTO_TCP, WinFFI::TCP_NODELAY, [1].pack('l'), 4) if tcp_nodelay
      end
    end
  end
end
