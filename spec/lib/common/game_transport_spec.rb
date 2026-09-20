# frozen_string_literal: true

require 'rspec'
require 'tmpdir'
require 'stringio'

DATA_DIR = Dir.tmpdir unless defined?(DATA_DIR)

module Lich
  def self.log(_message)
    # no-op for tests
  end unless respond_to?(:log)
end

require_relative '../../../lib/common/game_transport'

RSpec.describe Lich::Common::GameTransport do
  describe '.open' do
    it 'raises UnknownModeError for anything other than :direct or :websocket' do
      expect { described_class.open('host', 1234, mode: :carrier_pigeon) }
        .to raise_error(described_class::UnknownModeError, /carrier_pigeon/)
    end

    it 'dispatches :direct to .open_direct' do
      allow(described_class).to receive(:open_direct).with('host', 1234).and_return(:direct_socket)
      expect(described_class.open('host', 1234, mode: described_class::DIRECT)).to eq(:direct_socket)
    end

    it 'dispatches :websocket to .open_websocket, forwarding extra options' do
      allow(described_class).to receive(:open_websocket).with('host', 1234, subprotocol: nil).and_return(:ws_stream)
      expect(described_class.open('host', 1234, mode: described_class::WEBSOCKET, subprotocol: nil)).to eq(:ws_stream)
    end
  end

  describe '.open_websocket' do
    it 'derives the shim path from the game port and defaults the shim TCP port to 443' do
      expect(Lich::Common::WebSocket::Stream).to receive(:connect) do |**kwargs, &block|
        expect(kwargs[:port]).to eq(443)
        expect(kwargs[:path]).to eq('/shim/10024')
        expect(kwargs[:origin]).to eq('https://storm.dr.game.play.net')
        expect(kwargs[:subprotocol]).to eq(described_class::DEFAULT_SUBPROTOCOL)
        block.call(double('raw_socket')) # exercise the configure_socket hook without a real socket
        :ws_stream
      end
      allow(described_class).to receive(:configure_socket)

      result = described_class.open_websocket('storm.dr.game.play.net', 10_024)
      expect(result).to eq(:ws_stream)
    end

    it 'lets callers override the shim path/origin/subprotocol for live probing' do
      expect(Lich::Common::WebSocket::Stream).to receive(:connect) do |**kwargs|
        expect(kwargs[:path]).to eq('/custom-shim/10024')
        expect(kwargs[:subprotocol]).to be_nil
        :ws_stream
      end

      described_class.open_websocket('host', 10_024, path: '/custom-shim/10024', subprotocol: nil)
    end
  end

  describe '.configure_socket' do
    it 'logs a warning and does not raise if SocketConfigurator fails' do
      allow(Lich::Common::SocketConfigurator).to receive(:configure).and_raise(StandardError, 'boom')
      expect { described_class.configure_socket(double('socket'), 'host') }.not_to raise_error
    end
  end
end
