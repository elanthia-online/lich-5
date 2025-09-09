require 'socket'

module Lich
  module Common
    module SocketConfigurator
      if Gem.win_platform?
        Lich::Util.install_gem_requirements({ "ffi" => false })
        require 'ffi'

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
        # Keepalive
        if keepalive[:enable]
          sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, 1)
          if Socket.const_defined?(:TCP_KEEPIDLE)
            sock.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_KEEPIDLE, keepalive[:idle])
          elsif Socket.const_defined?(:TCP_KEEPALIVE) # macOS
            sock.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_KEEPALIVE, keepalive[:idle])
          end
          sock.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_KEEPINTVL, keepalive[:interval]) if Socket.const_defined?(:TCP_KEEPINTVL)
          sock.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_KEEPCNT, 5) if Socket.const_defined?(:TCP_KEEPCNT)
        end

        # Linger
        if linger
          sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_LINGER, [linger[:enable] ? 1 : 0, linger[:timeout]].pack("ii"))
        end

        # Timeouts
        if timeout
          sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, [timeout[:recv], 0].pack("l!l!"))
          sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, [timeout[:send], 0].pack("l!l!"))
        end

        # Buffer sizes
        if buffer_size
          sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVBUF, [buffer_size[:recv]].pack('l')) if buffer_size[:recv]
          sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDBUF, [buffer_size[:send]].pack('l')) if buffer_size[:send]
        end

        # TCP_NODELAY
        sock.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) if tcp_nodelay
      end

      # -------------------------
      # Windows
      # -------------------------
      def self.configure_windows(sock, keepalive, linger, timeout, buffer_size, tcp_nodelay)
        fd = sock.fileno

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
          ret = WinFFI.setsockopt(fd, WinFFI::SOL_SOCKET, WinFFI::SO_LINGER, l.to_ptr, l.size)
          raise SystemCallError.new("setsockopt(SO_LINGER)", FFI.errno) if ret != 0
        end

        # Timeouts
        if timeout
          tv = WinFFI::Timeval.new
          tv[:tv_sec] = timeout[:recv]
          tv[:tv_usec] = 0
          ret = WinFFI.setsockopt(fd, WinFFI::SOL_SOCKET, WinFFI::SO_RCVTIMEO, tv.to_ptr, tv.size)
          raise SystemCallError.new("setsockopt(SO_RCVTIMEO)", FFI.errno) if ret != 0

          tv[:tv_sec] = timeout[:send]
          ret = WinFFI.setsockopt(fd, WinFFI::SOL_SOCKET, WinFFI::SO_SNDTIMEO, tv.to_ptr, tv.size)
          raise SystemCallError.new("setsockopt(SO_SNDTIMEO)", FFI.errno) if ret != 0
        end

        # Buffer sizes
        if buffer_size
          if buffer_size[:recv]
            ret = WinFFI.setsockopt(fd, WinFFI::SOL_SOCKET, Socket::SO_RCVBUF, [buffer_size[:recv]].pack('l'), 4)
            raise SystemCallError.new("setsockopt(SO_RCVBUF)", FFI.errno) if ret != 0
          end
          if buffer_size[:send]
            ret = WinFFI.setsockopt(fd, WinFFI::SOL_SOCKET, Socket::SO_SNDBUF, [buffer_size[:send]].pack('l'), 4)
            raise SystemCallError.new("setsockopt(SO_SNDBUF)", FFI.errno) if ret != 0
          end
        end

        # TCP_NODELAY
        if tcp_nodelay
          ret = WinFFI.setsockopt(fd, WinFFI::IPPROTO_TCP, WinFFI::TCP_NODELAY, [1].pack('l'), 4)
          raise SystemCallError.new("setsockopt(TCP_NODELAY)", FFI.errno) if ret != 0
        end
      end
    end
  end
end
