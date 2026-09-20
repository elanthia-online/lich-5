# frozen_string_literal: true

require 'rspec'
require_relative '../../../../lib/common/websocket/handshake'

RSpec.describe Lich::Common::WebSocket::Handshake do
  described_class = Lich::Common::WebSocket::Handshake

  describe '.accept_for' do
    it 'matches the RFC 6455 4.2.2 worked example' do
      key = 'dGhlIHNhbXBsZSBub25jZQ=='
      expect(described_class.accept_for(key)).to eq('s3pPLMBiTxaQ9kYGzzhZRbK+xOo=')
    end
  end

  describe '.generate_key' do
    it 'generates a fresh base64 key each time' do
      expect(described_class.generate_key).not_to eq(described_class.generate_key)
    end
  end

  describe '.request' do
    it 'builds a GET upgrade request with the required headers' do
      request = described_class.request(host: 'storm.dr.game.play.net', path: '/shim/1234',
                                        key: 'testkey==', origin: 'https://storm.dr.game.play.net',
                                        subprotocol: 'websocket_shim-protocol', user_agent: 'TestAgent/1.0')
      expect(request).to start_with("GET /shim/1234 HTTP/1.1\r\n")
      expect(request).to include("Host: storm.dr.game.play.net\r\n")
      expect(request).to include("Upgrade: websocket\r\n")
      expect(request).to include("Connection: Upgrade\r\n")
      expect(request).to include("Sec-WebSocket-Key: testkey==\r\n")
      expect(request).to include("Sec-WebSocket-Version: 13\r\n")
      expect(request).to include("Origin: https://storm.dr.game.play.net\r\n")
      expect(request).to include("Sec-WebSocket-Protocol: websocket_shim-protocol\r\n")
      expect(request).to include("User-Agent: TestAgent/1.0\r\n")
      expect(request).to end_with("\r\n\r\n")
    end

    it 'omits optional headers when not given' do
      request = described_class.request(host: 'h', path: '/p', key: 'k')
      expect(request).not_to include('Origin:')
      expect(request).not_to include('Sec-WebSocket-Protocol:')
      expect(request).not_to include('User-Agent:')
    end

    it 'lets extra_headers override defaults' do
      request = described_class.request(host: 'h', path: '/p', key: 'k', extra_headers: { 'Host' => 'override' })
      expect(request).to include("Host: override\r\n")
      expect(request).not_to include("Host: h\r\n")
    end
  end

  describe '.validate_response' do
    let(:key) { described_class.generate_key }
    let(:accept) { described_class.accept_for(key) }

    def response(status: 'HTTP/1.1 101 Switching Protocols', headers: {})
      lines = [status]
      headers.each { |k, v| lines << "#{k}: #{v}" }
      lines.join("\r\n")
    end

    it 'accepts a valid 101 response' do
      resp = response(headers: {
        'Upgrade'              => 'websocket',
        'Connection'           => 'Upgrade',
        'Sec-WebSocket-Accept' => accept
      })
      expect(described_class.validate_response(resp, key: key)).to include('sec-websocket-accept' => accept)
    end

    it 'raises on a non-101 status' do
      resp = response(status: 'HTTP/1.1 403 Forbidden')
      expect { described_class.validate_response(resp, key: key) }.to raise_error(described_class::Error, /403/)
    end

    it 'raises on an empty response' do
      expect { described_class.validate_response('', key: key) }.to raise_error(described_class::Error, /empty response/)
    end

    it 'raises when Upgrade header is missing' do
      resp = response(headers: { 'Connection' => 'Upgrade', 'Sec-WebSocket-Accept' => accept })
      expect { described_class.validate_response(resp, key: key) }.to raise_error(described_class::Error, /Upgrade/)
    end

    it 'raises when Connection header does not include upgrade' do
      resp = response(headers: { 'Upgrade' => 'websocket', 'Connection' => 'keep-alive', 'Sec-WebSocket-Accept' => accept })
      expect { described_class.validate_response(resp, key: key) }.to raise_error(described_class::Error, /Connection/)
    end

    it 'raises on an accept-key mismatch' do
      resp = response(headers: {
        'Upgrade'              => 'websocket',
        'Connection'           => 'Upgrade',
        'Sec-WebSocket-Accept' => 'wrong=='
      })
      expect { described_class.validate_response(resp, key: key) }.to raise_error(described_class::Error, /Accept mismatch/)
    end

    it 'raises when the requested subprotocol was not accepted' do
      resp = response(headers: {
        'Upgrade'              => 'websocket',
        'Connection'           => 'Upgrade',
        'Sec-WebSocket-Accept' => accept
      })
      expect { described_class.validate_response(resp, key: key, subprotocol: 'websocket_shim-protocol') }
        .to raise_error(described_class::Error, /subprotocol/)
    end

    it 'passes when the accepted subprotocol matches' do
      resp = response(headers: {
        'Upgrade'                => 'websocket',
        'Connection'             => 'Upgrade',
        'Sec-WebSocket-Accept'   => accept,
        'Sec-WebSocket-Protocol' => 'websocket_shim-protocol'
      })
      expect { described_class.validate_response(resp, key: key, subprotocol: 'websocket_shim-protocol') }.not_to raise_error
    end
  end
end
