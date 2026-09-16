# frozen_string_literal: true

require_relative '../../spec_helper'
require 'stringio'
require 'webui/websocket'

RSpec.describe Lich::WebUI::WebSocket do
  it 'round-trips bounded masked client and unmasked server frames' do
    client_frame = described_class.encode_client_frame('hello')
    server_frame = described_class.encode_frame('world')

    expect(described_class.read_frame(StringIO.new(client_frame)).payload).to eq('hello')
    expect(described_class.read_frame(StringIO.new(server_frame), require_mask: false).payload).to eq('world')
  end

  it 'encodes the largest allowed frame with the RFC 64-bit length form' do
    payload = 'x' * described_class::MAX_PAYLOAD_BYTES
    frame = described_class.encode_frame(payload)
    client_frame = described_class.encode_client_frame(payload)

    expect(frame.byteslice(0, 2).unpack('CC')).to eq([0x81, 127])
    expect(described_class.read_frame(StringIO.new(frame), require_mask: false).payload).to eq(payload)
    expect(client_frame.byteslice(0, 2).unpack('CC')).to eq([0x81, 0x80 | 127])
    expect(described_class.read_frame(StringIO.new(client_frame)).payload).to eq(payload)
  end

  it 'fragments larger server messages into individually bounded frames' do
    payload = 'x' * (described_class::MAX_PAYLOAD_BYTES + 10)
    io = StringIO.new(described_class.encode_text_message(payload))
    first_header = io.read(2).unpack('CC')
    first_length = io.read(8).unpack1('Q>')
    first_payload = io.read(first_length)
    second_header = io.read(2).unpack('CC')
    second_payload = io.read(second_header.last & 0x7F)

    expect(first_header).to eq([described_class::OPCODE_TEXT, 127])
    expect(first_length).to eq(described_class::MAX_PAYLOAD_BYTES)
    expect(second_header).to eq([0x80 | described_class::OPCODE_CONTINUATION, 10])
    expect(first_payload + second_payload).to eq(payload)
  end

  it 'refuses an oversized frame from its length header before reading the body', security_id: 'sec-frame-size' do
    frame = [0x81, 0xFF, 65_537].pack('CCQ>')

    expect { described_class.read_frame(StringIO.new(frame)) }
      .to raise_error(Lich::WebUI::WebSocket::ProtocolError, /exceeds 65536/)
  end

  it 'refuses unmasked, binary, fragmented, and invalid UTF-8 client frames' do
    expect { described_class.read_frame(StringIO.new(described_class.encode_frame('plain'))) }
      .to raise_error(Lich::WebUI::WebSocket::ProtocolError, /must be masked/)

    binary = described_class.encode_client_frame('data', opcode: described_class::OPCODE_BINARY)
    expect { described_class.read_frame(StringIO.new(binary)) }
      .to raise_error(Lich::WebUI::WebSocket::ProtocolError, /unsupported opcode/)

    fragmented = described_class.encode_client_frame('part').dup
    fragmented.setbyte(0, fragmented.getbyte(0) & 0x7F)
    expect { described_class.read_frame(StringIO.new(fragmented)) }
      .to raise_error(Lich::WebUI::WebSocket::ProtocolError, /fragmented/)

    invalid_utf8 = described_class.encode_client_frame([255].pack('C'))
    expect { described_class.read_frame(StringIO.new(invalid_utf8)) }
      .to raise_error(Lich::WebUI::WebSocket::ProtocolError, /valid UTF-8/)
  end
end
