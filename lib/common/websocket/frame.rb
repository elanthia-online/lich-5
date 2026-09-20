# frozen_string_literal: true

require "securerandom"

module Lich
  module Common
    module WebSocket
      # Hand-rolled RFC 6455 frame encode/decode.
      #
      # Deliberately not pulled from a gem: this is the piece Genie5#356
      # flags as needing to be bent to whatever the shim's real handshake and
      # framing behavior turns out to be once probed live (subprotocol,
      # Origin enforcement, fragmentation quirks). A small, self-contained
      # implementation is easier to adjust for that than a general-purpose
      # WebSocket client built around browser semantics.
      #
      # @see Lich::Common::WebSocket::Handshake
      # @see Lich::Common::WebSocket::Stream
      module Frame
        # Opcodes defined by RFC 6455 5.2.
        OPCODE_CONTINUATION = 0x0
        OPCODE_TEXT         = 0x1
        OPCODE_BINARY       = 0x2
        OPCODE_CLOSE        = 0x8
        OPCODE_PING         = 0x9
        OPCODE_PONG         = 0xA

        CONTROL_OPCODES = [OPCODE_CLOSE, OPCODE_PING, OPCODE_PONG].freeze
        DATA_OPCODES    = [OPCODE_CONTINUATION, OPCODE_TEXT, OPCODE_BINARY].freeze

        # A single reassembled message (data: :text/:binary with any
        # continuation frames already merged; control: :close/:ping/:pong,
        # always a single frame per RFC 6455 5.5).
        Message = Struct.new(:opcode, :payload) do
          def data?
            DATA_OPCODES.include?(opcode) && opcode != OPCODE_CONTINUATION
          end

          def control?
            CONTROL_OPCODES.include?(opcode)
          end
        end

        # Raised for any structural framing violation: reserved bits set, an
        # unsupported opcode, an oversized/fragmented control frame, a
        # continuation frame with no message in progress, or -- per RFC 6455
        # 5.1 -- a masked frame arriving from the server.
        class ProtocolError < StandardError; end

        # Builds a single, unfragmented, masked client-to-server frame.
        # Client frames MUST be masked (RFC 6455 5.1); the mask key is
        # generated fresh per frame.
        #
        # @param payload [String] frame payload; sent as raw (ASCII-8BIT)
        #   bytes regardless of the input string's own encoding
        # @param opcode [Integer] one of the OPCODE_* constants
        # @return [String] raw bytes ready to write to the socket
        def self.encode(payload, opcode: OPCODE_TEXT)
          payload = payload.to_s.b
          mask_key = SecureRandom.bytes(4)

          frame = +"".b
          frame << (0x80 | (opcode & 0x0F)) # FIN=1, RSV1-3=0
          frame << length_byte_sequence(payload.bytesize)
          frame << mask_key
          frame << apply_mask(payload, mask_key)
          frame
        end

        # XORs +bytes+ against a repeating 4-byte +key+ (RFC 6455 5.3). The
        # operation is its own inverse, so this both masks and unmasks.
        #
        # @param bytes [String]
        # @param key [String] exactly 4 bytes
        # @return [String] a new, masked/unmasked copy of +bytes+
        def self.apply_mask(bytes, key)
          out = bytes.b
          size = out.bytesize
          i = 0
          while i < size
            out.setbyte(i, out.getbyte(i) ^ key.getbyte(i % 4))
            i += 1
          end
          out
        end

        # @api private
        def self.length_byte_sequence(size)
          case size
          when 0..125
            (0x80 | size).chr
          when 126..0xFFFF
            "#{(0x80 | 126).chr}#{[size].pack('n')}"
          else
            "#{(0x80 | 127).chr}#{[size].pack('Q>')}"
          end
        end
        private_class_method :length_byte_sequence

        # Incremental frame decoder. Feed it raw bytes as they arrive off the
        # socket; it returns whatever complete, reassembled messages became
        # available, and holds on to any trailing partial frame until the
        # next call.
        class Reader
          def initialize
            @buffer = +"".b
            @fragment = nil # [opcode, +payload]
          end

          # @param bytes [String] newly-received raw bytes
          # @return [Array<Message>] zero or more complete messages
          # @raise [ProtocolError]
          def feed(bytes)
            @buffer << bytes
            messages = []
            while (frame = take_frame!)
              messages.concat(handle_frame(frame))
            end
            messages
          end

          private

          RawFrame = Struct.new(:fin, :opcode, :payload)

          # Pulls one complete frame off the front of @buffer, or nil if the
          # buffer doesn't yet hold a full frame's header + length + payload.
          def take_frame!
            return nil if @buffer.bytesize < 2

            first  = @buffer.getbyte(0)
            second = @buffer.getbyte(1)

            raise ProtocolError, "reserved bits set (#{first & 0x70})" unless (first & 0x70).zero?
            raise ProtocolError, "server frame was masked (RFC 6455 5.1)" unless (second & 0x80).zero?

            fin    = (first & 0x80) != 0
            opcode = first & 0x0F
            len    = second & 0x7F
            header_len = 2

            case len
            when 126
              return nil if @buffer.bytesize < 4
              len = @buffer.byteslice(2, 2).unpack1("n")
              header_len = 4
            when 127
              return nil if @buffer.bytesize < 10
              len = @buffer.byteslice(2, 8).unpack1("Q>")
              header_len = 10
            end

            if CONTROL_OPCODES.include?(opcode)
              raise ProtocolError, "control frame payload too large (#{len} bytes)" if len > 125
              raise ProtocolError, "control frame (opcode 0x#{opcode.to_s(16)}) must not be fragmented" unless fin
            end

            return nil if @buffer.bytesize < header_len + len

            payload = @buffer.byteslice(header_len, len)
            @buffer = @buffer.byteslice((header_len + len)..-1) || +"".b
            RawFrame.new(fin, opcode, payload)
          end

          def handle_frame(frame)
            case frame.opcode
            when OPCODE_CONTINUATION
              raise ProtocolError, "continuation frame with no message in progress" unless @fragment

              @fragment[1] << frame.payload
              return [] unless frame.fin

              opcode, payload = @fragment
              @fragment = nil
              [Message.new(opcode, payload)]
            when OPCODE_TEXT, OPCODE_BINARY
              if frame.fin
                [Message.new(frame.opcode, frame.payload)]
              else
                raise ProtocolError, "new data frame while a fragmented message is already in progress" if @fragment

                @fragment = [frame.opcode, frame.payload.dup]
                []
              end
            when OPCODE_CLOSE, OPCODE_PING, OPCODE_PONG
              [Message.new(frame.opcode, frame.payload)]
            else
              raise ProtocolError, "unsupported opcode 0x#{frame.opcode.to_s(16)}"
            end
          end
        end
      end
    end
  end
end
