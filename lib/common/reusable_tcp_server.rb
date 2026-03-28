require 'socket'

module Lich
  module Common
    # Factory for creating TCP server sockets with SO_REUSEADDR set before binding.
    #
    # Ruby's +TCPServer.new+ calls +bind+ and +listen+ internally during construction,
    # so any +setsockopt+ call made after construction is too late — the port is already
    # bound without the reuse flag. This causes "Address already in use" failures when
    # restarting quickly because the kernel holds the port in TIME_WAIT for ~60 seconds.
    #
    # This module separates socket creation from binding so that SO_REUSEADDR takes
    # effect before the port is claimed.
    #
    # @example Create a reusable listener on a specific port
    #   server = Lich::Common::ReusableTCPServer.create('127.0.0.1', 8000)
    #   client = server.accept
    #
    # @see Lich::Common::SocketConfigurator for post-creation socket tuning
    # @since 5.12.0
    module ReusableTCPServer
      # Creates a TCP server socket with SO_REUSEADDR enabled before binding.
      #
      # @param host [String] the address to bind to
      # @param port [Integer] the port to listen on
      # @param backlog [Integer] the listen queue depth (default: 1)
      # @return [Socket] a bound, listening socket ready for +accept+
      # @raise [Errno::EADDRINUSE] if the port is unavailable even with SO_REUSEADDR
      # @raise [SocketError] if the address is invalid
      def self.create(host, port, backlog: 1)
        server = Socket.new(:INET, :STREAM)
        begin
          server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
          server.bind(Addrinfo.tcp(host, port))
          server.listen(backlog)
          server
        rescue
          server.close rescue nil
          raise
        end
      end
    end
  end
end
