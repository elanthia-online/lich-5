# frozen_string_literal: true

require 'rspec'
require_relative '../../../../lib/common/websocket/frame'

RSpec.describe Lich::Common::WebSocket::Frame do
  described_class = Lich::Common::WebSocket::Frame

  def unmask(frame_bytes)
    second = frame_bytes.getbyte(1)
    len = second & 0x7F
    offset = 2
    case len
    when 126
      len = frame_bytes.byteslice(2, 2).unpack1('n')
      offset = 4
    when 127
      len = frame_bytes.byteslice(2, 8).unpack1('Q>')
      offset = 10
    end
    key = frame_bytes.byteslice(offset, 4)
    payload = frame_bytes.byteslice(offset + 4, len)
    described_class.apply_mask(payload, key)
  end

  describe '.encode' do
    it 'sets the FIN bit and opcode in the first byte' do
      frame = described_class.encode('hi', opcode: described_class::OPCODE_TEXT)
      expect(frame.getbyte(0)).to eq(0x81) # FIN=1, opcode=0x1
    end

    it 'sets the mask bit on every client frame' do
      frame = described_class.encode('hi')
      expect(frame.getbyte(1) & 0x80).not_to eq(0)
    end

    it 'round-trips a short payload (7-bit length)' do
      frame = described_class.encode('look')
      expect(unmask(frame)).to eq('look')
    end

    it 'round-trips a payload requiring the 16-bit extended length (126..65535)' do
      payload = 'x' * 200
      frame = described_class.encode(payload)
      expect(frame.getbyte(1) & 0x7F).to eq(126)
      expect(unmask(frame)).to eq(payload)
    end

    it 'round-trips a payload requiring the 64-bit extended length (>65535)' do
      payload = 'x' * 70_000
      frame = described_class.encode(payload)
      expect(frame.getbyte(1) & 0x7F).to eq(127)
      expect(unmask(frame)).to eq(payload)
    end

    it 'uses a different mask key on each call' do
      frame_a = described_class.encode('hi')
      frame_b = described_class.encode('hi')
      expect(frame_a.byteslice(2, 4)).not_to eq(frame_b.byteslice(2, 4))
    end
  end

  describe '.apply_mask' do
    it 'is its own inverse' do
      key = "\x01\x02\x03\x04"
      original = 'round trip me'
      masked = described_class.apply_mask(original, key)
      expect(described_class.apply_mask(masked, key)).to eq(original)
    end
  end

  describe described_class::Reader do
    subject(:reader) { described_class::Reader.new }

    def unmasked_server_frame(payload, opcode: Lich::Common::WebSocket::Frame::OPCODE_TEXT, fin: true)
      first = (fin ? 0x80 : 0x00) | opcode
      len = payload.bytesize
      length_bytes =
        case len
        when 0..125
          [len].pack('C')
        when 126..0xFFFF
          [126, len].pack('Cn')
        else
          [127, len].pack('CQ>')
        end
      "#{first.chr}#{length_bytes}#{payload}"
    end

    it 'decodes a single unfragmented text frame' do
      messages = reader.feed(unmasked_server_frame('hello'))
      expect(messages.size).to eq(1)
      expect(messages.first.opcode).to eq(described_class::OPCODE_TEXT)
      expect(messages.first.payload).to eq('hello')
      expect(messages.first.data?).to be(true)
    end

    it 'buffers a partial frame across multiple feeds' do
      full = unmasked_server_frame('partial')
      expect(reader.feed(full.byteslice(0, 2))).to eq([])
      messages = reader.feed(full.byteslice(2..-1))
      expect(messages.first.payload).to eq('partial')
    end

    it 'decodes multiple frames delivered in a single feed' do
      combined = unmasked_server_frame('one') + unmasked_server_frame('two')
      messages = reader.feed(combined)
      expect(messages.map(&:payload)).to eq(%w[one two])
    end

    it 'reassembles a fragmented message across continuation frames' do
      first = unmasked_server_frame('Hello, ', opcode: described_class::OPCODE_TEXT, fin: false)
      cont  = unmasked_server_frame('world!', opcode: described_class::OPCODE_CONTINUATION, fin: true)
      messages = reader.feed(first + cont)
      expect(messages.size).to eq(1)
      expect(messages.first.payload).to eq('Hello, world!')
    end

    it 'surfaces a ping as a control message' do
      messages = reader.feed(unmasked_server_frame('', opcode: described_class::OPCODE_PING))
      expect(messages.first.opcode).to eq(described_class::OPCODE_PING)
      expect(messages.first.control?).to be(true)
    end

    it 'raises on a masked frame from the server (RFC 6455 5.1)' do
      masked = described_class.encode('spoofed', opcode: described_class::OPCODE_TEXT)
      expect { reader.feed(masked) }.to raise_error(described_class::ProtocolError, /masked/)
    end

    it 'raises on reserved bits set' do
      bad = [0xC1, 0x00].pack('C*') # FIN=1, RSV1=1, opcode=text, len=0
      expect { reader.feed(bad) }.to raise_error(described_class::ProtocolError, /reserved/)
    end

    it 'raises on an oversized control frame' do
      bad = unmasked_server_frame('x' * 126, opcode: described_class::OPCODE_PING)
      expect { reader.feed(bad) }.to raise_error(described_class::ProtocolError, /too large/)
    end

    it 'raises on a fragmented control frame' do
      bad = unmasked_server_frame('x', opcode: described_class::OPCODE_PING, fin: false)
      expect { reader.feed(bad) }.to raise_error(described_class::ProtocolError, /fragmented/)
    end

    it 'raises on a continuation frame with no message in progress' do
      bad = unmasked_server_frame('x', opcode: described_class::OPCODE_CONTINUATION, fin: true)
      expect { reader.feed(bad) }.to raise_error(described_class::ProtocolError, /no message in progress/)
    end
  end
end
