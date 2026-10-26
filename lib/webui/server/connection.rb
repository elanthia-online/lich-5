# frozen_string_literal: true

require 'securerandom'
require 'socket'
require_relative '../websocket'

module Lich
  module WebUI
    class Server
      # Authenticated WebSocket connection. The viewer id is generated server-side.
      class Connection
        WRITE_TIMEOUT = 10.0

        attr_reader :socket, :viewer_id

        # Wraps an accepted socket with server-generated viewer identity and serialized writes.
        # @param socket [Socket] accepted WebSocket transport
        # @return [Connection] initialized transport with its own writer lock
        def initialize(socket)
          @socket = socket
          @viewer_id = "viewer-#{SecureRandom.hex(16)}"
          @write_mutex = Mutex.new
          @alive = true
        end

        # Reports whether this transport has been marked open.
        # @return [Boolean]
        def alive? = @alive

        # Writes a text message using the transport's bounded fragmentation encoder.
        # @param payload [String] JSON message text
        # @return [Object] underlying write result
        def send_text(payload)
          write(WebSocket.encode_text_message(payload))
        end

        # Writes a pong control frame through the same serialized connection writer.
        # @param payload [String] ping payload to echo
        # @return [Object] underlying write result
        def send_pong(payload)
          write(WebSocket.encode_frame(payload, opcode: WebSocket::OPCODE_PONG))
        end

        # Sends a best-effort normal Close frame, then shuts down the socket.
        # Never waits for a busy writer or appends a control frame inside a data
        # frame. A blocked/broken connection is instead retired immediately.
        # @return [nil] after shutdown, including repeated calls
        def close
          return unless @alive

          locked = @write_mutex.try_lock
          if locked
            frame = WebSocket.encode_frame([1000].pack('n'), opcode: WebSocket::OPCODE_CLOSE)
            @socket.write_nonblock(frame, exception: false)
          end
          nil
        rescue IOError, SystemCallError
          nil
        ensure
          abort_connection
          @write_mutex.unlock if locked
        end

        private

        # Serializes a complete outbound message within a bounded write deadline.
        # If cancellation unwinds an admitted writer, retire the incomplete stream
        # before releasing its lock so later writers cannot append corrupt frames.
        # @param bytes [String] encoded WebSocket frame bytes
        # @return [Boolean] whether the whole message was written
        # @api private
        def write(bytes)
          return false unless @alive

          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + WRITE_TIMEOUT
          locked = false
          until (locked = @write_mutex.try_lock)
            remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
            return failed_write if !@alive || remaining <= 0

            sleep([remaining, 0.005].min)
          end
          offset = 0
          while offset < bytes.bytesize
            remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
            return failed_write if !@alive || remaining <= 0

            written = @socket.write_nonblock(bytes.byteslice(offset..), exception: false)
            if written == :wait_writable
              return failed_write unless IO.select(nil, [@socket], nil, remaining)
            elsif written.positive?
              offset += written
            else
              return failed_write
            end
          end
          completed = true
        rescue IOError, SystemCallError
          failed_write
        ensure
          if locked
            abort_connection unless completed
            @write_mutex.unlock
          end
        end

        # Retires failed writes without attempting another frame on the stream.
        # @return [false] delivery failed
        # @api private
        def failed_write
          abort_connection
          false
        end

        # Ends transport I/O without acquiring the writer's lock or sending bytes.
        # @return [nil] after socket shutdown or an already-closed socket
        # @api private
        def abort_connection
          @alive = false
          @socket.shutdown(Socket::SHUT_RDWR)
          nil
        rescue IOError, SystemCallError
          nil
        end
      end
    end
  end
end
