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

    it 'dispatches :direct to .open_direct, forwarding extra options for a possible fallback' do
      allow(described_class).to receive(:open_direct).with('host', 1234, subprotocol: nil).and_return(:direct_socket)
      expect(described_class.open('host', 1234, mode: described_class::DIRECT, subprotocol: nil)).to eq(:direct_socket)
    end

    it 'dispatches :websocket to .open_websocket, forwarding extra options' do
      allow(described_class).to receive(:open_websocket).with('host', 1234, subprotocol: nil).and_return(:ws_stream)
      expect(described_class.open('host', 1234, mode: described_class::WEBSOCKET, subprotocol: nil)).to eq(:ws_stream)
    end
  end

  describe '.websocket_host_for' do
    it 'remaps a GemStone-family GAMEHOST to chimera.play.net' do
      expect(described_class.websocket_host_for('storm.gs4.game.play.net')).to eq('chimera.play.net')
      expect(described_class.websocket_host_for('chimera.simutronics.com')).to eq('chimera.play.net')
    end

    it 'remaps a DragonRealms-family GAMEHOST to hydra.play.net' do
      expect(described_class.websocket_host_for('dr.simutronics.net')).to eq('hydra.play.net')
      expect(described_class.websocket_host_for('storm.dr.game.play.net')).to eq('hydra.play.net')
      expect(described_class.websocket_host_for('hydra.simutronics.com')).to eq('hydra.play.net')
    end

    it 'checks the GemStone pattern first, matching the source order' do
      # a hypothetical host matching both patterns should resolve as GemStone-family
      expect(described_class.websocket_host_for('gsdr.example.com')).to eq('chimera.play.net')
    end

    it 'leaves an unrecognized GAMEHOST unchanged' do
      expect(described_class.websocket_host_for('unknown.example.com')).to eq('unknown.example.com')
    end
  end

  describe '.open_direct' do
    it 'connects with a bounded timeout, configures the socket, logs the transport used, and returns the socket' do
      socket = double('socket')
      expect(Socket).to receive(:tcp).with('host', 1234, connect_timeout: described_class::DIRECT_CONNECT_TIMEOUT)
                                     .and_return(socket)
      allow(described_class).to receive(:configure_socket)
      expect(Lich).to receive(:log).with('info: connected via direct TCP transport (host:1234)')

      expect(described_class.open_direct('host', 1234)).to eq(socket)
    end

    described_class::DIRECT_CONNECTIVITY_ERRORS.each do |error_class|
      it "falls back to .open_websocket on #{error_class}" do
        # Errno::* classes prepend their own system message to whatever's
        # passed in (e.g. "Connection timed out - unreachable"); build the
        # expectation the same way rather than assume a bare passthrough.
        expected_message = error_class.new('unreachable').message
        allow(Socket).to receive(:tcp).and_raise(error_class, 'unreachable')
        expect(described_class).to receive(:open_websocket).with('host', 1234, fallback: true).and_return(:ws_stream)
        expect(Lich).to receive(:log)
          .with("warn: direct TCP transport unreachable (host:1234, #{error_class}: #{expected_message}); " \
                'falling back to WebSocket transport')

        expect(described_class.open_direct('host', 1234)).to eq(:ws_stream)
      end
    end

    it 'does not fall back on an error unrelated to reachability' do
      allow(Socket).to receive(:tcp).and_raise(StandardError, 'something else entirely')
      expect(described_class).not_to receive(:open_websocket)

      expect { described_class.open_direct('host', 1234) }.to raise_error(StandardError, 'something else entirely')
    end

    it 'forwards extra options to .open_websocket on fallback' do
      allow(Socket).to receive(:tcp).and_raise(Errno::ETIMEDOUT, 'timed out')
      allow(Lich).to receive(:log)
      expect(described_class).to receive(:open_websocket)
        .with('host', 1234, fallback: true, subprotocol: nil).and_return(:ws_stream)

      described_class.open_direct('host', 1234, subprotocol: nil)
    end
  end

  describe '.open_websocket' do
    it "derives the shim path from the game port, remaps GAMEHOST to the WebSocket transport's real host, and logs which transport connected" do
      expect(Lich::Common::WebSocket::Stream).to receive(:connect) do |**kwargs, &block|
        expect(kwargs[:host]).to eq('hydra.play.net') # remapped from storm.dr.game.play.net
        expect(kwargs[:port]).to eq(443)
        expect(kwargs[:path]).to eq('/shim/10024')
        expect(kwargs[:origin]).to eq('https://hydra.play.net')
        expect(kwargs[:subprotocol]).to eq(described_class::DEFAULT_SUBPROTOCOL)
        block.call(double('raw_socket')) # exercise the configure_socket hook without a real socket
        :ws_stream
      end
      allow(described_class).to receive(:configure_socket)
      expect(Lich).to receive(:log)
        .with('info: connected via WebSocket transport (wss://hydra.play.net:443/shim/10024 ' \
              '(remapped from GAMEHOST storm.dr.game.play.net))')

      result = described_class.open_websocket('storm.dr.game.play.net', 10_024)
      expect(result).to eq(:ws_stream)
    end

    it 'omits the remap note when ws_host matches the literal GAMEHOST' do
      allow(Lich::Common::WebSocket::Stream).to receive(:connect).and_return(:ws_stream)
      expect(Lich).to receive(:log).with('info: connected via WebSocket transport (wss://host:443/shim/10024)')

      described_class.open_websocket('host', 10_024, ws_host: 'host')
    end

    it 'lets callers override ws_host/path/origin/subprotocol for live probing' do
      allow(Lich).to receive(:log)
      expect(Lich::Common::WebSocket::Stream).to receive(:connect) do |**kwargs|
        expect(kwargs[:host]).to eq('custom.example.com')
        expect(kwargs[:path]).to eq('/custom-shim/10024')
        expect(kwargs[:subprotocol]).to be_nil
        :ws_stream
      end

      described_class.open_websocket('host', 10_024, ws_host: 'custom.example.com',
                                                       path: '/custom-shim/10024', subprotocol: nil)
    end

    it 'annotates the log line when called as a fallback from direct TCP' do
      allow(Lich::Common::WebSocket::Stream).to receive(:connect).and_return(:ws_stream)
      expect(Lich).to receive(:log)
        .with('info: connected via WebSocket transport (wss://hydra.play.net:443/shim/10024 ' \
              '(remapped from GAMEHOST storm.dr.game.play.net) (fallback from direct TCP))')

      described_class.open_websocket('storm.dr.game.play.net', 10_024, fallback: true)
    end

    it 'logs a warning and re-raises when the WebSocket connect fails' do
      error = Lich::Common::WebSocket::Stream::ConnectionError.new('boom')
      allow(Lich::Common::WebSocket::Stream).to receive(:connect).and_raise(error)
      expect(Lich).to receive(:log)
        .with('warn: WebSocket transport connect failed (wss://hydra.play.net:443/shim/10024): boom')

      expect { described_class.open_websocket('storm.dr.game.play.net', 10_024) }
        .to raise_error(Lich::Common::WebSocket::Stream::ConnectionError, 'boom')
    end
  end

  describe '.configure_socket' do
    it 'logs a warning and does not raise if SocketConfigurator fails' do
      allow(Lich::Common::SocketConfigurator).to receive(:configure).and_raise(StandardError, 'boom')
      expect { described_class.configure_socket(double('socket'), 'host') }.not_to raise_error
    end
  end
end
