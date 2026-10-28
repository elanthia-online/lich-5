# frozen_string_literal: true

require 'securerandom'
require 'socket'
require_relative '../host_thread'
require_relative '../protocol'
require_relative '../websocket'

module Lich
  module WebUI
    class Server
      # Authenticated WebSocket connection. The viewer id is generated server-side.
      # Sends are queued and written in order by one host-owned writer, so a slow
      # peer delays only its own messages, never the caller or other viewers.
      class Connection
        WRITE_TIMEOUT = 10.0
        # Encoded bytes a peer may leave unread before it is disconnected: two
        # largest renders plus framing. Overflow retires the connection rather
        # than silently dropping one message from an ordered stream.
        MAX_QUEUED_BYTES = (2 * Protocol::MAX_RENDER_BYTES) + 65_536

        attr_reader :socket, :viewer_id

        # Wraps an accepted socket with server-generated viewer identity and an ordered writer.
        # @param socket [Socket] accepted WebSocket transport
        # @param thread_factory [#call] creates the host-owned writer thread
        # @return [Connection] initialized transport with its own writer lock
        def initialize(socket, thread_factory: HostThread.method(:start))
          @socket = socket
          @viewer_id = "viewer-#{SecureRandom.hex(16)}"
          @write_mutex = Mutex.new
          @queue_mutex = Mutex.new
          @queue_ready = ConditionVariable.new
          @queue = []
          @queued_bytes = 0
          @alive = true
          @writer = thread_factory.call { drain }
        end

        # Reports whether this transport has been marked open.
        # @return [Boolean]
        def alive? = @alive

        # Queues a text message using the transport's bounded fragmentation encoder.
        # Outbound messages share the render budget (Protocol::MAX_RENDER_BYTES),
        # not the 2 MiB client message budget.
        # @param payload [String] JSON message text
        # @return [Boolean] whether the message was queued; false once retired
        # @raise [Protocol::Refusal] when the message exceeds Protocol::MAX_RENDER_BYTES
        def send_text(payload)
          if payload.to_s.bytesize > Protocol::MAX_RENDER_BYTES
            raise Protocol::Refusal.new(:frame_size,
                                        "outbound message exceeds #{Protocol::MAX_RENDER_BYTES} bytes; reduce page content")
          end

          enqueue(WebSocket.encode_text_message(payload))
        end

        # Queues a pong control frame behind earlier messages on the same writer.
        # @param payload [String] ping payload to echo
        # @return [Boolean] whether the frame was queued
        def send_pong(payload)
          enqueue(WebSocket.encode_frame(payload, opcode: WebSocket::OPCODE_PONG))
        end

        # Queues a ping control frame used for idle-connection liveness.
        # @param payload [String] opaque payload of at most 125 bytes
        # @return [Boolean] whether the frame was queued
        def send_ping(payload = '')
          enqueue(WebSocket.encode_frame(payload, opcode: WebSocket::OPCODE_PING))
        end

        # Sends a best-effort normal Close frame, then shuts down the socket.
        # Never waits for a busy writer or appends a control frame inside a data
        # frame. A blocked/broken connection is instead retired immediately.
        # Undelivered queued messages are discarded and their bytes cleared.
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

        # Appends encoded bytes to the bounded queue and wakes the writer.
        # @param bytes [String] encoded frame bytes owned by this connection
        # @return [Boolean] whether the bytes were queued
        # @api private
        def enqueue(bytes)
          overflow = @queue_mutex.synchronize do
            next nil unless @alive

            if @queued_bytes + bytes.bytesize > MAX_QUEUED_BYTES
              true
            else
              @queue << bytes
              @queued_bytes += bytes.bytesize
              @queue_ready.signal
              false
            end
          end
          if overflow.nil? || overflow
            bytes.clear
            abort_connection if overflow
            return false
          end
          true
        end

        # Writes queued messages in order until the connection is retired.
        # @return [void]
        # @api private
        def drain
          loop do
            bytes = @queue_mutex.synchronize do
              @queue_ready.wait(@queue_mutex) while @alive && @queue.empty?
              next nil unless @alive

              item = @queue.shift
              @queued_bytes -= item.bytesize
              item
            end
            break unless bytes

            written = write(bytes)
            bytes.clear
            break unless written
          end
        ensure
          abort_connection
        end

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
          discarded = @queue_mutex.synchronize do
            @alive = false
            @queued_bytes = 0
            @queue_ready.broadcast
            @queue.slice!(0..)
          end
          discarded.each(&:clear)
          @socket.shutdown(Socket::SHUT_RDWR)
          nil
        rescue IOError, SystemCallError
          nil
        end
      end
    end
  end
end
