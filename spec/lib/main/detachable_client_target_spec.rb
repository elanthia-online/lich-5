# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/main/detachable_client_target'

RSpec.describe Lich::Main::DetachableClientTarget do
  describe '.parse' do
    it 'parses a bare port with no host' do
      target = described_class.parse('8000')

      expect(target.host).to be_nil
      expect(target.port).to eq(8000)
    end

    it 'parses auto as OS-assigned port zero' do
      expect(described_class.parse('auto').port).to eq(0)
      expect(described_class.parse('AUTO').port).to eq(0)
      expect(described_class.parse('0').port).to eq(0)
    end

    it 'parses keyword host with port' do
      target = described_class.parse('tailscale:8000')

      expect(target.host).to eq('tailscale')
      expect(target.port).to eq(8000)
    end

    it 'parses host with auto port' do
      target = described_class.parse('lan:auto')

      expect(target.host).to eq('lan')
      expect(target.port).to eq(0)
    end

    it 'parses IPv4 host:port' do
      target = described_class.parse('192.168.1.20:8123')

      expect(target.host).to eq('192.168.1.20')
      expect(target.port).to eq(8123)
    end

    it 'parses bracketed IPv6 host:port' do
      target = described_class.parse('[::1]:8000')

      expect(target.host).to eq('::1')
      expect(target.port).to eq(8000)
    end

    it 'parses hostname:port' do
      target = described_class.parse('mypc.tailnet.ts.net:8000')

      expect(target.host).to eq('mypc.tailnet.ts.net')
      expect(target.port).to eq(8000)
    end

    it 'rejects an empty value' do
      expect { described_class.parse('') }.to raise_error(described_class::ParseError, /requires PORT, auto, or HOST:PORT/)
    end

    it 'rejects a host without a port' do
      expect { described_class.parse('tailscale') }.to raise_error(described_class::ParseError)
    end

    it 'rejects an empty host before the colon' do
      expect { described_class.parse(':8000') }.to raise_error(described_class::ParseError)
    end

    it 'rejects a non-numeric port' do
      expect { described_class.parse('lan:web') }.to raise_error(described_class::ParseError)
    end

    it 'rejects out-of-range ports' do
      expect { described_class.parse('99999') }.to raise_error(described_class::ParseError, /between 0 and 65535/)
      expect { described_class.parse('lan:99999') }.to raise_error(described_class::ParseError, /between 0 and 65535/)
    end
  end
end
