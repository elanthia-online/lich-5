# frozen_string_literal: true

require 'base64'
require 'digest/sha1'

module Lich
  module WebUI
    # Bounded RFC 6455 framing used by the loopback transport.
    #
    # Just enough of the protocol for one browser on loopback: text, close,
    # ping and pong frames, every one bounded in size, with outbound messages
    # fragmented so a large render never breaks the bound.
    module WebSocket
      # The GUID RFC 6455 appends to the client key in the handshake.
      HANDSHAKE_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
      # Largest single frame payload accepted or produced, in bytes.
      MAX_PAYLOAD_BYTES = 65_536
      # Longest a reader waits for the next byte of a frame it has started.
      # Readable means one byte, not a whole frame, so a sender that stops
      # mid-frame is cut off here rather than parking the connection thread.
      READ_TIMEOUT = 30

      OPCODE_CONTINUATION = 0x0
      OPCODE_TEXT = 0x1
      OPCODE_BINARY = 0x2
      OPCODE_CLOSE = 0x8
      OPCODE_PING = 0x9
      OPCODE_PONG = 0xA
      # The opcodes a client frame may carry.
      ALLOWED_OPCODES = [OPCODE_TEXT, OPCODE_CLOSE, OPCODE_PING, OPCODE_PONG].freeze
      # The opcodes a server frame may carry.
      OUTBOUND_OPCODES = [OPCODE_CONTINUATION, *ALLOWED_OPCODES].freeze

      # A frame that breaks the protocol, or breaks this transport's bounds.
      class ProtocolError < StandardError; end

      # One decoded frame.
      #
      # @!attribute [r] opcode
      #   @return [Integer] the frame's opcode
      # @!attribute [r] payload
      #   @return [String] the unmasked payload; UTF-8 for a text frame
      Frame = Data.define(:opcode, :payload) do
        # @return [Boolean] whether this is a text frame
        def text? = opcode == OPCODE_TEXT
        # @return [Boolean] whether this is a close frame
        def close? = opcode == OPCODE_CLOSE
        # @return [Boolean] whether this is a ping frame
        def ping? = opcode == OPCODE_PING
        # @return [Boolean] whether this is a pong frame
        def pong? = opcode == OPCODE_PONG
      end

      module_function

      # The `Sec-WebSocket-Accept` value for a client's `Sec-WebSocket-Key`.
      #
      # @param client_key [String, #to_s] the client's key header
      # @return [String] the accept value
      def accept_key(client_key)
        Base64.strict_encode64(Digest::SHA1.digest(client_key.to_s.strip + HANDSHAKE_GUID))
      end

      # Encodes one unmasked server frame.
      #
      # @param payload [String, #to_s] the payload
      # @param opcode [Integer] one of {OUTBOUND_OPCODES}
      # @param final [Boolean] whether this frame ends its message
      # @return [String] the binary frame
      # @raise [ProtocolError] when the payload exceeds {MAX_PAYLOAD_BYTES}, the opcode is not allowed
      #   outbound, or a control frame is marked non-final
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

      # Encodes a text message, fragmented into bounded frames when it is large.
      #
      # Browsers reassemble a fragmented WebSocket message before firing the
      # message event. Keep every frame bounded without imposing the inbound
      # event limit on a valid rendered page.
      #
      # @param payload [String, #to_s] the message text
      # @return [String] one or more concatenated binary frames
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

      # Encodes one masked client frame, as a browser would send it (used by specs and probes).
      #
      # @param payload [String, #to_s] the payload
      # @param opcode [Integer] the frame's opcode
      # @param mask_key [String] four masking bytes
      # @return [String] the binary frame
      # @raise [ArgumentError] when +mask_key+ is not four bytes
      # @raise [ProtocolError] when the payload exceeds {MAX_PAYLOAD_BYTES}
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

      # Reads and decodes one complete frame.
      #
      # @param io [IO, StringIO] the stream to read from
      # @param require_mask [Boolean] whether an unmasked frame is refused, as it must be from a client
      # @param read_timeout [Numeric] seconds to wait for each byte once a frame has started
      # @return [Frame, nil] the frame, or nil at a clean end of stream before any frame began
      # @raise [ProtocolError] on reserved bits, fragmentation, an unsupported opcode, a missing mask, an
      #   oversized payload, invalid UTF-8 in a text frame, or a stream that ends or stalls mid-frame
      def read_frame(io, require_mask: true, read_timeout: READ_TIMEOUT)
        head = read_exact(io, 2, read_timeout)
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

        length = read_exact!(io, 2, read_timeout).unpack1('n') if length == 126
        length = read_exact!(io, 8, read_timeout).unpack1('Q>') if length == 127
        raise ProtocolError, "frame exceeds #{MAX_PAYLOAD_BYTES} bytes" if length > MAX_PAYLOAD_BYTES
        raise ProtocolError, 'control frame exceeds 125 bytes' if opcode >= OPCODE_CLOSE && length > 125

        mask_key = read_exact!(io, 4, read_timeout) if masked
        payload = length.zero? ? +'' : read_exact!(io, length, read_timeout)
        payload = unmask(payload, mask_key) if masked
        if opcode == OPCODE_TEXT
          payload.force_encoding(Encoding::UTF_8)
          raise ProtocolError, 'text frame is not valid UTF-8' unless payload.valid_encoding?
        end
        Frame.new(opcode, payload)
      end

      # Applies (or removes) the four-byte XOR mask.
      #
      # @param payload [String] the bytes
      # @param mask_key [String] four masking bytes
      # @return [String] the masked or unmasked bytes
      def unmask(payload, mask_key)
        mask = mask_key.bytes
        payload.bytes.each_with_index.map { |byte, index| byte ^ mask[index % 4] }.pack('C*')
      end

      # Exactly +count+ bytes, nil at a clean end of stream before the first
      # byte, ProtocolError at an end or a stall after it. A real IO is read
      # non-blocking under select so a stalled sender is bounded by +timeout+;
      # an in-memory stream (specs read from StringIO) has nothing to select
      # on and is read directly.
      def read_exact(io, count, timeout)
        buffer = +''
        selectable = io.respond_to?(:to_io)
        while buffer.bytesize < count
          wanted = count - buffer.bytesize
          if selectable
            raise ProtocolError, 'stream stalled mid-frame' unless IO.select([io], nil, nil, timeout)

            chunk = io.read_nonblock(wanted, exception: false)
            next if chunk == :wait_readable
          else
            chunk = io.read(wanted)
          end
          return buffer.empty? ? nil : raise(ProtocolError, 'stream ended mid-frame') if chunk.nil? || chunk.empty?

          buffer << chunk
        end
        buffer
      end
      private_class_method :read_exact

      # As read_exact, but an end of stream is always an error.
      def read_exact!(io, count, timeout)
        read_exact(io, count, timeout) || raise(ProtocolError, 'stream ended mid-frame')
      end
      private_class_method :read_exact!
    end
  end
end
