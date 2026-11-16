# frozen_string_literal: true

require_relative '../../spec_helper'
require 'socket'
require 'stringio'
require 'timeout'
require 'webui/websocket'

RSpec.describe Lich::WebUI::WebSocket do
  it 'assembles split UTF-8 and handles interleaved control frames' do
    # The split lies inside a supplementary Unicode codepoint.
    bytes = [0x1f512].pack('U').b
    wire = described_class.encode_client_frame(bytes.byteslice(0, 2), final: false)
    wire << described_class.encode_client_frame('ping', opcode: described_class::OPCODE_PING)
    wire << described_class.encode_client_frame(bytes.byteslice(2, 2), opcode: described_class::OPCODE_CONTINUATION)
    controls = []
    message = described_class.read_message(StringIO.new(wire)) { |frame| controls << frame.payload }
    expect(message.payload).to eq(bytes.force_encoding(Encoding::UTF_8))
    expect(controls).to eq(['ping'])
  end

  it 'refuses invalid fragment sequencing and aggregate overflow before reading a body' do
    start = described_class.encode_client_frame('part', final: false)
    continuation = described_class.encode_client_frame('end', opcode: described_class::OPCODE_CONTINUATION)
    [continuation, start, start + described_class.encode_client_frame('new'),
     described_class.encode_client_frame('ping', opcode: described_class::OPCODE_PING, final: false),
     start + [0x80, 0xff, described_class::MAX_CLIENT_PAYLOAD_BYTES].pack('CCQ>')].each do |wire|
      expect { described_class.read_message(StringIO.new(wire)) }.to raise_error(described_class::ProtocolError)
    end
  end

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
    frame = [0x81, 0xFF, described_class::MAX_CLIENT_PAYLOAD_BYTES + 1].pack('CCQ>')

    expect { described_class.read_frame(StringIO.new(frame)) }
      .to raise_error(Lich::WebUI::WebSocket::ProtocolError, /exceeds 2097152/)
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

  it 'unmasks every length, tail and binary byte exactly like a per-byte reference' do
    reference = lambda do |payload, mask_key|
      mask = mask_key.bytes
      payload.bytes.each_with_index.map { |byte, index| byte ^ mask[index % 4] }.pack('C*')
    end
    random = Random.new(1834)
    lengths = (0..33).to_a + [125, 126, 65_535, 65_536, 65_537]
    keys = [[0, 0, 0, 0], [255, 255, 255, 255], [1, 128, 127, 254]].map { |bytes| bytes.pack('C*') }
    lengths.each do |length|
      payload = random.bytes(length)
      (keys + [random.bytes(4)]).each do |key|
        result = described_class.unmask(payload, key)
        expect(result).to eq(reference.call(payload, key)), "length #{length}"
        expect(result.encoding).to eq(Encoding::BINARY)
        expect(described_class.unmask(result, key)).to eq(payload.b)
      end
    end
  end

  it 'bounds a stalled partial header, extended length, mask and payload by one message deadline' do
    frame = described_class.encode_client_frame('x' * 200)
    # Cut points: inside the 2-byte head, the 16-bit length, the mask and the payload.
    [1, 3, 6, 20].each do |cut|
      client, server = Socket.pair(:UNIX, :STREAM, 0)
      client.write(frame.byteslice(0, cut))
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      deadline = started + 0.2
      expect { described_class.read_message(server, deadline: deadline) }
        .to raise_error(described_class::ProtocolError, /deadline expired/)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      expect(elapsed).to be_between(0.15, 1.5), "cut #{cut}"
    ensure
      client&.close
      server&.close
    end
  end

  it 'bounds a fragmented message by its first deadline and ends promptly when the peer closes' do
    client, server = Socket.pair(:UNIX, :STREAM, 0)
    client.write(described_class.encode_client_frame('part', final: false))
    expect { described_class.read_message(server, deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + 0.2) }
      .to raise_error(described_class::ProtocolError, /deadline expired/)

    stalled = described_class.encode_client_frame('y' * 50).byteslice(0, 10)
    client.write(stalled)
    reader = Thread.new do
      described_class.read_message(server, deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30)
    rescue described_class::ProtocolError => error
      error
    end
    Timeout.timeout(2) { Thread.pass until reader.status == 'sleep' || !reader.alive? }
    # Close the writing peer so the reader sees end of stream. A local shutdown of the
    # reading socket does not wake a blocked IO.select on Windows AF_UNIX sockets.
    client.close
    expect(reader.join(2)).not_to be_nil
    expect(reader.value).to be_a(described_class::ProtocolError)
  ensure
    reader&.kill&.join
    client&.close
    server&.close
  end

  it 'returns a standalone control frame under a deadline but keeps controls inside a fragmented message' do
    client, server = Socket.pair(:UNIX, :STREAM, 0)
    client.write(described_class.encode_client_frame('', opcode: described_class::OPCODE_PONG))
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1
    controls = []
    frame = described_class.read_message(server, deadline: deadline) { |control| controls << control.opcode }
    expect(frame.opcode).to eq(described_class::OPCODE_PONG)
    expect(controls).to eq([described_class::OPCODE_PONG])

    client.write(described_class.encode_client_frame('a', final: false))
    client.write(described_class.encode_client_frame('p', opcode: described_class::OPCODE_PING))
    client.write(described_class.encode_client_frame('b', opcode: described_class::OPCODE_CONTINUATION))
    message = described_class.read_message(server, deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1)
    expect(message).to be_text
    expect(message.payload).to eq('ab')
  ensure
    client&.close
    server&.close
  end
end
