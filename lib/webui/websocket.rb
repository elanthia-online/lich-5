# frozen_string_literal: true

require 'base64'
require 'digest/sha1'
require_relative 'contract'

module Lich
  module WebUI
    # Bounded RFC 6455 framing used by the loopback transport.
    module WebSocket
      HANDSHAKE_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
      MAX_PAYLOAD_BYTES = 65_536
      MAX_CLIENT_PAYLOAD_BYTES = Contract::WIRE_LIMITS[:message_bytes]

      OPCODE_CONTINUATION = 0x0
      OPCODE_TEXT = 0x1
      OPCODE_BINARY = 0x2
      OPCODE_CLOSE = 0x8
      OPCODE_PING = 0x9
      OPCODE_PONG = 0xA
      ALLOWED_OPCODES = [OPCODE_TEXT, OPCODE_CLOSE, OPCODE_PING, OPCODE_PONG].freeze
      OUTBOUND_OPCODES = [OPCODE_CONTINUATION, *ALLOWED_OPCODES].freeze

      class ProtocolError < StandardError; end

      # Decoded frame data; final identifies the last fragment of a message.
      Frame = Data.define(:opcode, :payload, :final) do
        # Identifies a text-message opcode for JSON protocol dispatch.
        # @return [Boolean]
        def text? = opcode == OPCODE_TEXT
        # Identifies a close control frame ending the connection loop.
        # @return [Boolean]
        def close? = opcode == OPCODE_CLOSE
        # Identifies a ping control frame requiring an echoed pong.
        # @return [Boolean]
        def ping? = opcode == OPCODE_PING
      end

      module_function

      # Computes the RFC 6455 server accept value from the client handshake key.
      # @return [String] base64-encoded handshake response
      def accept_key(client_key)
        Base64.strict_encode64(Digest::SHA1.digest(client_key.to_s.strip + HANDSHAKE_GUID))
      end

      # Encodes a bounded, unmasked server frame with a supported opcode.
      # @return [String] binary frame
      # @raise [ProtocolError] for excessive size, unsupported opcode, or fragmented control frames
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

      # Encodes a masked client frame for probes and tests.
      # The deterministic default mask is for fixtures, not a production browser client.
      # @param payload [Object] payload converted to binary text
      # @param opcode [Integer] frame opcode
      # @param final [Boolean] whether this is the final message fragment
      # @param mask_key [String] exactly four mask bytes
      # @return [String] binary frame
      def encode_client_frame(payload, opcode: OPCODE_TEXT, final: true, mask_key: "\x01\x02\x03\x04".b)
        raise ArgumentError, 'mask_key must contain four bytes' unless mask_key.bytesize == 4
        data = payload.to_s.b
        raise ProtocolError, 'client frame too large' if data.bytesize > MAX_CLIENT_PAYLOAD_BYTES

        head = [(final ? 0x80 : 0) | opcode].pack('C')
        head << if data.bytesize < 126
                  [0x80 | data.bytesize].pack('C')
                elsif data.bytesize <= 65_535
                  [0x80 | 126, data.bytesize].pack('Cn')
                else
                  [0x80 | 127, data.bytesize].pack('CQ>')
                end
        head << mask_key << unmask(data, mask_key)
      end

      # Reads one bounded frame and validates masking, opcode and control limits.
      # Client frames admit the protocol envelope budget; server frames stay 64 KiB.
      # @param io [#read] input stream
      # @param require_mask [Boolean] require client masking; false for test-client reads
      # @param allow_fragments [Boolean] defer message assembly and UTF-8 validation to read_message
      # @param remaining [Integer] remaining aggregate message byte budget
      # @param deadline [Float, nil] CLOCK_MONOTONIC limit for every byte of the frame
      # @return [Frame, nil] decoded frame, or nil at clean EOF
      # @raise [ProtocolError] for invalid or unsupported frames, or an expired deadline
      def read_frame(io, require_mask: true, allow_fragments: false, remaining: MAX_CLIENT_PAYLOAD_BYTES, deadline: nil)
        head = read_exact(io, 2, deadline)
        return nil unless head

        byte1, byte2 = head.unpack('CC')
        fin = (byte1 & 0x80) != 0
        rsv = byte1 & 0x70
        opcode = byte1 & 0x0F
        masked = (byte2 & 0x80) != 0
        length = byte2 & 0x7F

        raise ProtocolError, 'reserved bits are set' unless rsv.zero?
        raise ProtocolError, 'fragmented frames are unsupported' unless fin || allow_fragments
        allowed = allow_fragments ? OUTBOUND_OPCODES : ALLOWED_OPCODES
        raise ProtocolError, 'unsupported opcode' unless allowed.include?(opcode)
        raise ProtocolError, 'control frames cannot be fragmented' if opcode >= OPCODE_CLOSE && !fin
        raise ProtocolError, 'client frames must be masked' if require_mask && !masked

        length = read_exact!(io, 2, deadline).unpack1('n') if length == 126
        length = read_exact!(io, 8, deadline).unpack1('Q>') if length == 127
        limit = require_mask ? MAX_CLIENT_PAYLOAD_BYTES : MAX_PAYLOAD_BYTES
        raise ProtocolError, "frame exceeds #{limit} bytes" if length > limit
        raise ProtocolError, 'message exceeds aggregate byte limit' if opcode < OPCODE_CLOSE && length > remaining
        raise ProtocolError, 'control frame exceeds 125 bytes' if opcode >= OPCODE_CLOSE && length > 125

        mask_key = read_exact!(io, 4, deadline) if masked
        payload = length.zero? ? +'' : read_exact!(io, length, deadline)
        payload = unmask(payload, mask_key) if masked
        if opcode == OPCODE_TEXT && !allow_fragments
          payload.force_encoding(Encoding::UTF_8)
          raise ProtocolError, 'text frame is not valid UTF-8' unless payload.valid_encoding?
        end
        Frame.new(opcode, payload, fin)
      end

      # Reassembles bounded client text messages, permitting interleaved controls.
      # UTF-8 is checked after assembly because fragments may split a codepoint.
      # With a deadline, a control frame received outside a fragmented message
      # is returned after yielding, so an idle peer's ping or pong cannot hold
      # the read open until the deadline expires.
      # @param io [#read] client stream
      # @param deadline [Float, nil] CLOCK_MONOTONIC limit for the whole message
      # @yield [frame] interleaved control for immediate transport handling
      # @yieldparam frame [Frame] ping or pong received between data fragments
      # @return [Frame, nil] complete text, close control, standalone control (deadline only), or clean EOF
      # @raise [ProtocolError] for invalid sequencing, encoding, truncation, size or an expired deadline
      def read_message(io, deadline: nil)
        data = nil
        loop do
          frame = read_frame(io, allow_fragments: true, remaining: MAX_CLIENT_PAYLOAD_BYTES - (data&.bytesize || 0),
                                 deadline: deadline)
          raise ProtocolError, 'stream ended mid-message' if !frame && data
          return frame unless frame
          return frame if frame.close?
          if frame.opcode >= OPCODE_CLOSE
            yield frame if block_given?
            return frame if deadline && !data

            next
          end
          if frame.opcode == OPCODE_TEXT
            raise ProtocolError, 'new text during fragmented message' if data
            data = frame.payload.b
          else
            raise ProtocolError, 'unexpected continuation frame' unless data
            data << frame.payload
          end
          next unless frame.final

          data.force_encoding(Encoding::UTF_8)
          raise ProtocolError, 'text message is not valid UTF-8' unless data.valid_encoding?
          return Frame.new(OPCODE_TEXT, data, true)
        end
      end

      # Applies the repeating four-byte XOR mask (also usable to mask fixture payloads).
      # Whole eight-byte words are transformed together, so a 2 MiB message
      # allocates one word per eight bytes instead of two Integers per byte.
      # @return [String] transformed binary payload
      def unmask(payload, mask_key)
        data = payload.to_s.b
        mask = mask_key.b * 2
        whole = data.bytesize - (data.bytesize % 8)
        word = mask.unpack1('Q>')
        result = data.byteslice(0, whole).unpack('Q>*').map! { |value| value ^ word }.pack('Q>*')
        data.byteslice(whole, data.bytesize - whole).each_byte.with_index do |byte, index|
          result << (byte ^ mask.getbyte(index))
        end
        result
      end

      # Reads exactly count bytes. With a deadline, every read (length, mask and
      # payload bytes alike) waits only until that one monotonic instant.
      # @param deadline [Float, nil] CLOCK_MONOTONIC limit, or nil to block
      # @return [String, nil] bytes, or nil at clean EOF before any byte
      # @raise [ProtocolError] on EOF mid-read or an expired deadline
      def read_exact(io, count, deadline = nil)
        buffer = +''
        while buffer.bytesize < count
          chunk = deadline ? read_before(io, count - buffer.bytesize, deadline) : io.read(count - buffer.bytesize)
          return buffer.empty? ? nil : raise(ProtocolError, 'stream ended mid-frame') if chunk.nil? || chunk.empty?

          buffer << chunk
        end
        buffer
      end
      private_class_method :read_exact

      def read_exact!(io, count, deadline = nil)
        read_exact(io, count, deadline) || raise(ProtocolError, 'stream ended mid-frame')
      end
      private_class_method :read_exact!

      # Waits for readable bytes without passing the deadline.
      # @return [String, nil] available bytes, or nil at EOF
      # @raise [ProtocolError] when the deadline expires first
      def read_before(io, count, deadline)
        loop do
          chunk = io.read_nonblock(count, exception: false)
          return chunk unless chunk == :wait_readable

          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          raise ProtocolError, 'frame read deadline expired' unless remaining.positive? && IO.select([io], nil, nil, remaining)
        end
      end
      private_class_method :read_before
    end
  end
end
