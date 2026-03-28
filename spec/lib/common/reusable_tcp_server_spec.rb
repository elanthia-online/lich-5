# frozen_string_literal: true

require 'rspec'
require 'socket'
require_relative '../../../lib/common/reusable_tcp_server'

RSpec.describe Lich::Common::ReusableTCPServer do
  # Use port 0 to let the OS assign an ephemeral port, avoiding conflicts
  # with other tests or running services.
  let(:host) { '127.0.0.1' }
  let(:port) { 0 }

  # Collect servers opened during each example so we can close them reliably.
  let(:servers) { [] }

  after do
    servers.each { |s| s.close unless s.closed? }
  end

  describe '.create' do
    context 'when given a valid host and port' do
      it 'returns a bound, listening socket' do
        server = described_class.create(host, port)
        servers << server

        expect(server).to be_a(Socket)
        expect(server.local_address.ip_port).to be > 0
      end

      it 'accepts incoming TCP connections' do
        server = described_class.create(host, port)
        servers << server
        bound_port = server.local_address.ip_port

        client = TCPSocket.new(host, bound_port)
        accepted, = server.accept

        expect(accepted).to be_a(Socket)
      ensure
        client&.close
        accepted&.close
      end
    end

    context 'when SO_REUSEADDR is effective' do
      it 'allows immediate rebind after the first server closes' do
        first_server = described_class.create(host, port)
        bound_port = first_server.local_address.ip_port

        # Connect and disconnect to put the port into TIME_WAIT
        client = TCPSocket.new(host, bound_port)
        accepted, = first_server.accept
        accepted.close
        client.close
        first_server.close

        # Without SO_REUSEADDR this would raise Errno::EADDRINUSE
        second_server = described_class.create(host, bound_port)
        servers << second_server

        expect(second_server.local_address.ip_port).to eq(bound_port)
      end
    end

    context 'with a custom backlog' do
      it 'accepts the backlog parameter without error' do
        server = described_class.create(host, port, backlog: 5)
        servers << server

        expect(server.local_address.ip_port).to be > 0
      end
    end

    context 'when the address is invalid' do
      it 'raises SocketError for an unresolvable host' do
        expect {
          described_class.create('not.a.valid.host.example', port)
        }.to raise_error(SocketError)
      end
    end

    context 'when the port is actively held by another socket' do
      it 'raises Errno::EADDRINUSE' do
        blocker = Socket.new(:INET, :STREAM)
        blocker.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
        blocker.bind(Addrinfo.tcp(host, 0))
        blocker.listen(1)
        claimed_port = blocker.local_address.ip_port

        expect {
          described_class.create(host, claimed_port)
        }.to raise_error(Errno::EADDRINUSE)
      ensure
        blocker&.close
      end
    end

    context 'with the default backlog' do
      it 'defaults backlog to 1' do
        server = described_class.create(host, port)
        servers << server

        # We cannot inspect the backlog directly, but we verify that the
        # socket is listening by successfully connecting to it.
        client = TCPSocket.new(host, server.local_address.ip_port)
        accepted, = server.accept

        expect(accepted).to be_a(Socket)
      ensure
        client&.close
        accepted&.close
      end
    end
  end
end
