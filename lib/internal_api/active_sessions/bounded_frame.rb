# frozen_string_literal: true

module Lich
  module InternalAPI
    module ActiveSessions
      # Optional newline framing with one monotonic deadline for all socket I/O.
      # Frame limits include the terminating newline. This helper never extends
      # a deadline when a peer supplies another partial chunk.
      # @api private
      module BoundedFrame
        # @return [Integer] default frame limit when only a timeout is supplied
        DEFAULT_MAX_BYTES = 65_536

        # @return [Float] current monotonic time in seconds
        def self.now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        # @param deadline [Numeric] absolute local monotonic deadline
        # @return [Numeric] remaining seconds
        # @raise [IOError] if the deadline has elapsed
        def self.remaining(deadline)
          seconds = deadline - now
          raise IOError, 'transport timeout' unless seconds.positive?

          seconds
        end

        # @param socket [IO] connected nonblocking-capable socket
        # @param deadline [Numeric] absolute local monotonic deadline
        # @param max_bytes [Integer] maximum frame size including newline
        # @return [String] complete frame
        # @raise [IOError] for incomplete, oversized, or timed-out frames
        def self.read(socket, deadline:, max_bytes:)
          buffer = +''.b
          loop do
            raise IOError, 'transport timeout' unless IO.select([socket], nil, nil, remaining(deadline))

            chunk = socket.read_nonblock([4096, max_bytes + 1 - buffer.bytesize].min, exception: false)
            next if chunk == :wait_readable
            raise IOError, 'incomplete frame' unless chunk

            buffer << chunk
            newline = buffer.index("\n")
            size = newline ? newline + 1 : buffer.bytesize
            raise IOError, 'frame too large' if size > max_bytes

            return buffer.byteslice(0, size) if newline
          end
        end

        # @param socket [IO] connected nonblocking-capable socket
        # @param frame [String] complete newline-terminated frame
        # @param deadline [Numeric] absolute local monotonic deadline
        # @param max_bytes [Integer] maximum frame size including newline
        # @return [void]
        # @raise [IOError] for oversized frames or elapsed deadlines
        def self.write(socket, frame, deadline:, max_bytes:)
          raise IOError, 'frame too large' if frame.bytesize > max_bytes

          offset = 0
          while offset < frame.bytesize
            remaining(deadline)
            count = socket.write_nonblock(frame.byteslice(offset, frame.bytesize - offset), exception: false)
            if count == :wait_writable
              raise IOError, 'transport timeout' unless IO.select(nil, [socket], nil, remaining(deadline))
            else
              raise IOError, 'socket write failed' unless count.positive?

              offset += count
            end
          end
        end

        # @param timeout [Numeric] total exchange duration
        # @param max_bytes [Integer] frame cap
        # @return [void]
        # @raise [ArgumentError] unless the supplied bounds are positive and finite
        def self.validate!(timeout, max_bytes)
          unless timeout.is_a?(Numeric) && timeout.real? && timeout.finite? && timeout.positive?
            raise ArgumentError, 'timeout must be positive and finite'
          end
          raise ArgumentError, 'max_frame_bytes must be a positive integer' unless max_bytes.is_a?(Integer) && max_bytes.positive?
        end
      end
    end
  end
end
