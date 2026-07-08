# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/common/bind_host_resolver'

RSpec.describe Lich::Common::BindHostResolver do
  def address_list(*addresses)
    addresses.map { |address| Addrinfo.ip(address) }
  end

  let(:no_route) { -> { nil } }

  describe '.resolve with tailscale' do
    it 'finds the CGNAT-range address among local interfaces' do
      addresses = address_list('127.0.0.1', '192.168.1.20', '100.101.102.103')

      resolution = described_class.resolve('tailscale', address_list: addresses, route_probe: no_route)

      expect(resolution.host).to eq('100.101.102.103')
      expect(resolution.warning).to be_nil
    end

    it 'is case-insensitive' do
      addresses = address_list('100.64.0.5')

      expect(described_class.resolve('TAILSCALE', address_list: addresses, route_probe: no_route).host).to eq('100.64.0.5')
    end

    it 'does not mistake ordinary public 100.x addresses for Tailscale' do
      # 100.63.255.255 is just below the CGNAT range; 100.128.0.1 is above it.
      addresses = address_list('100.63.255.255', '100.128.0.1')

      expect {
        described_class.resolve('tailscale', address_list: addresses, route_probe: no_route)
      }.to raise_error(described_class::Error, /Tailscale doesn't appear to be running/)
    end

    it 'fails with guidance when no CGNAT address exists' do
      addresses = address_list('127.0.0.1', '192.168.1.20')

      expect {
        described_class.resolve('tailscale', address_list: addresses, route_probe: no_route)
      }.to raise_error(described_class::Error, /start Tailscale or use lan:PORT/)
    end
  end

  describe '.resolve with lan' do
    it 'prefers the default-route address when it is private' do
      addresses = address_list('127.0.0.1', '172.17.0.1', '192.168.1.20', '10.0.0.7')

      resolution = described_class.resolve('lan', address_list: addresses, route_probe: -> { '10.0.0.7' })

      expect(resolution.host).to eq('10.0.0.7')
      expect(resolution.warning).to match(/unauthenticated/)
    end

    it 'ignores a default-route address that is not a local private address' do
      addresses = address_list('127.0.0.1', '192.168.1.20')

      resolution = described_class.resolve('lan', address_list: addresses, route_probe: -> { '203.0.113.9' })

      expect(resolution.host).to eq('192.168.1.20')
    end

    it 'prefers household ranges over the Docker/VM 172.16/12 range when no route is known' do
      addresses = address_list('172.17.0.1', '192.168.1.20')

      resolution = described_class.resolve('lan', address_list: addresses, route_probe: no_route)

      expect(resolution.host).to eq('192.168.1.20')
    end

    it 'falls back to 172.16/12 when it is the only private range present' do
      addresses = address_list('127.0.0.1', '172.20.5.9')

      resolution = described_class.resolve('lan', address_list: addresses, route_probe: no_route)

      expect(resolution.host).to eq('172.20.5.9')
    end

    it 'survives a raising route probe' do
      addresses = address_list('192.168.1.20')

      resolution = described_class.resolve('lan', address_list: addresses, route_probe: -> { raise SocketError })

      expect(resolution.host).to eq('192.168.1.20')
    end

    it 'fails when the machine has no private IPv4 address' do
      addresses = address_list('127.0.0.1', '203.0.113.9')

      expect {
        described_class.resolve('lan', address_list: addresses, route_probe: no_route)
      }.to raise_error(described_class::Error, /no private \(LAN\) IPv4 address/)
    end
  end

  describe '.resolve with any' do
    it 'binds the wildcard address with a warning' do
      resolution = described_class.resolve('any', address_list: [], route_probe: no_route)

      expect(resolution.host).to eq('0.0.0.0')
      expect(resolution.warning).to match(/every network/)
    end
  end

  describe '.resolve with explicit hosts' do
    it 'passes private addresses through without warning' do
      resolution = described_class.resolve('192.168.1.20', address_list: [], route_probe: no_route)

      expect(resolution.host).to eq('192.168.1.20')
      expect(resolution.warning).to be_nil
    end

    it 'passes loopback and tailnet addresses through without warning' do
      expect(described_class.resolve('127.0.0.1', address_list: [], route_probe: no_route).warning).to be_nil
      expect(described_class.resolve('100.101.102.103', address_list: [], route_probe: no_route).warning).to be_nil
    end

    it 'warns on public addresses' do
      resolution = described_class.resolve('203.0.113.9', address_list: [], route_probe: no_route)

      expect(resolution.host).to eq('203.0.113.9')
      expect(resolution.warning).to match(/not a private address/)
    end

    it 'warns on an explicit wildcard address' do
      expect(described_class.resolve('0.0.0.0', address_list: [], route_probe: no_route).warning).to match(/every network/)
      expect(described_class.resolve('::', address_list: [], route_probe: no_route).warning).to match(/every network/)
    end

    it 'passes IPv6 loopback and link-local addresses through without warning' do
      expect(described_class.resolve('::1', address_list: [], route_probe: no_route).warning).to be_nil
      expect(described_class.resolve('fe80::1', address_list: [], route_probe: no_route).warning).to be_nil
    end

    it 'warns on public IPv6 addresses' do
      resolution = described_class.resolve('2001:db8::1', address_list: [], route_probe: no_route)

      expect(resolution.host).to eq('2001:db8::1')
      expect(resolution.warning).to match(/not a private address/)
    end

    it 'passes hostnames through without warning' do
      resolution = described_class.resolve('mypc.tailnet.ts.net', address_list: [], route_probe: no_route)

      expect(resolution.host).to eq('mypc.tailnet.ts.net')
      expect(resolution.warning).to be_nil
    end
  end
end
