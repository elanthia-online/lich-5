# frozen_string_literal: true

require 'base64'
require 'digest/sha1'

module Lich
  module WebUI
    # Bounded RFC 6455 framing used by the loopback transport.
    module WebSocket
      HANDSHAKE_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
      MAX_PAYLOAD_BYTES = 65_536

      OPCODE_CONTINUATION = 0x0
      OPCODE_TEXT = 0x1
      OPCODE_BINARY = 0x2
      OPCODE_CLOSE = 0x8
      OPCODE_PING = 0x9
      OPCODE_PONG = 0xA
      ALLOWED_OPCODES = [OPCODE_TEXT, OPCODE_CLOSE, OPCODE_PING, OPCODE_PONG].freeze
      OUTBOUND_OPCODES = [OPCODE_CONTINUATION, *ALLOWED_OPCODES].freeze

      class ProtocolError < StandardError; end

      Frame = Data.define(:opcode, :payload) do
        def text? = opcode == OPCODE_TEXT
        def close? = opcode == OPCODE_CLOSE
        def ping? = opcode == OPCODE_PING
        def pong? = opcode == OPCODE_PONG
      end

      module_function

      def accept_key(client_key)
        Base64.strict_encode64(Digest::SHA1.digest(client_key.to_s.strip + HANDSHAKE_GUID))
      end

      def encode_frame(payload, opcode: OPCODE_TEXT, final: true)
        data = payload.to_s.b
        raise ProtocolError, 'server frame too large' if data.bytesize > MAX_PAYLOAD_BYTES
        raise ProtocolError, 'unsupported opcode' unless OUTBOUND_OPCODES.include?(opcode)
        raise ProtocolError, 'control frames cannot be fragmented' if opcode >= OPCODE_CLOSE && !final

        head = [(final ? 0x80 : 0) | opcode].pack('C')
        head << if data.bytesize < 126
                  [data.bytesize].pack('C')
                elsif data.bytesize <= 65_535
                  [126, data.bytesize].pack('Cn')
                else
                  [127, data.bytesize].pack('CQ>')
                end
        head << data
      end

      # Browsers reassemble a fragmented WebSocket message before firing the
      # message event. Keep every frame bounded without imposing the inbound
      # event limit on a valid rendered page.
      def encode_text_message(payload)
        data = payload.to_s.b
        return encode_frame(data) if data.bytesize <= MAX_PAYLOAD_BYTES

        chunks = []
        offset = 0
        while offset < data.bytesize
          chunks << data.byteslice(offset, MAX_PAYLOAD_BYTES)
          offset += MAX_PAYLOAD_BYTES
        end
        chunks.each_with_index.map do |chunk, index|
          encode_frame(
            chunk,
            opcode: index.zero? ? OPCODE_TEXT : OPCODE_CONTINUATION,
            final: index == chunks.length - 1
          )
        end.join
      end

      def encode_client_frame(payload, opcode: OPCODE_TEXT, mask_key: "\x01\x02\x03\x04".b)
        raise ArgumentError, 'mask_key must contain four bytes' unless mask_key.bytesize == 4
        data = payload.to_s.b
        raise ProtocolError, 'client frame too large' if data.bytesize > MAX_PAYLOAD_BYTES

        head = [0x80 | opcode].pack('C')
        head << if data.bytesize < 126
                  [0x80 | data.bytesize].pack('C')
                elsif data.bytesize <= 65_535
                  [0x80 | 126, data.bytesize].pack('Cn')
                else
                  [0x80 | 127, data.bytesize].pack('CQ>')
                end
        head << mask_key << unmask(data, mask_key)
      end

      def read_frame(io, require_mask: true)
        head = read_exact(io, 2)
        return nil unless head

        byte1, byte2 = head.unpack('CC')
        fin = (byte1 & 0x80) != 0
        rsv = byte1 & 0x70
        opcode = byte1 & 0x0F
        masked = (byte2 & 0x80) != 0
        length = byte2 & 0x7F

        raise ProtocolError, 'reserved bits are set' unless rsv.zero?
        raise ProtocolError, 'fragmented frames are unsupported' unless fin
        raise ProtocolError, 'unsupported opcode' unless ALLOWED_OPCODES.include?(opcode)
        raise ProtocolError, 'client frames must be masked' if require_mask && !masked

        length = read_exact!(io, 2).unpack1('n') if length == 126
        length = read_exact!(io, 8).unpack1('Q>') if length == 127
        raise ProtocolError, "frame exceeds #{MAX_PAYLOAD_BYTES} bytes" if length > MAX_PAYLOAD_BYTES
        raise ProtocolError, 'control frame exceeds 125 bytes' if opcode >= OPCODE_CLOSE && length > 125

        mask_key = read_exact!(io, 4) if masked
        payload = length.zero? ? +'' : read_exact!(io, length)
        payload = unmask(payload, mask_key) if masked
        if opcode == OPCODE_TEXT
          payload.force_encoding(Encoding::UTF_8)
          raise ProtocolError, 'text frame is not valid UTF-8' unless payload.valid_encoding?
        end
        Frame.new(opcode, payload)
      end

      def unmask(payload, mask_key)
        mask = mask_key.bytes
        payload.bytes.each_with_index.map { |byte, index| byte ^ mask[index % 4] }.pack('C*')
      end

      def read_exact(io, count)
        buffer = +''
        while buffer.bytesize < count
          chunk = io.read(count - buffer.bytesize)
          return buffer.empty? ? nil : raise(ProtocolError, 'stream ended mid-frame') if chunk.nil? || chunk.empty?

          buffer << chunk
        end
        buffer
      end
      private_class_method :read_exact

      def read_exact!(io, count)
        read_exact(io, count) || raise(ProtocolError, 'stream ended mid-frame')
      end
      private_class_method :read_exact!
    end
  end
end
