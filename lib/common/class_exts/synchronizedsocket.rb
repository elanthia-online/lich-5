# frozen_string_literal: true

module Lich
  module Common
    # Thread-safe socket wrapper with write-side resilience.
    #
    # Wraps a delegate socket (typically +TCPSocket+) with a mutex to
    # serialize writes and an internal liveness flag that transitions
    # irreversibly to dead on any fatal write error.
    #
    # When a fatal write error occurs the wrapper:
    # 1. Sets +@alive+ to +false+
    # 2. Closes the delegate socket (unblocking any blocked readers)
    # 3. Logs the error via +Lich.log+
    #
    # Subsequent writes short-circuit without touching the delegate.
    # Reads still delegate via +method_missing+ so lifecycle threads
    # can detect the closed socket through normal +IOError+ propagation.
    #
    # Frontend writes are queued through one socket-local writer thread so a
    # slow frontend cannot block the game parser. Main-stream output is deferred
    # while a frontend stream is open and released after the matching popStream
    # or prompt has entered the queue.
    class SynchronizedSocket
      class WriteQueueOverflow < StandardError; end

      # Errors that indicate a permanently broken write path.
      FATAL_WRITE_ERRORS = [
        Errno::ECONNRESET,
        Errno::EPIPE,
        Errno::ECONNABORTED,
        Errno::ENOTCONN,
        IOError,
      ].freeze

      WRITER_INIT_MUTEX = Mutex.new
      DEFAULT_WRITE_QUEUE_CAPACITY = 2_048
      ROLES = %i[primary detachable].freeze
      ATTACHMENT_STREAM_SENTINEL = Object.new.freeze

      # @param delegate [#puts, #write, #gets, #close] the underlying socket
      # @param role [Symbol] whether failure should end the session or only the
      #   detachable connection
      # @param write_queue_capacity [Integer] maximum pending writes
      def initialize(delegate, role: :primary, write_queue_capacity: DEFAULT_WRITE_QUEUE_CAPACITY)
        raise ArgumentError, "unknown socket role: #{role.inspect}" unless ROLES.include?(role)
        unless write_queue_capacity.is_a?(Integer) && write_queue_capacity.positive?
          raise ArgumentError, 'write_queue_capacity must be a positive Integer'
        end

        @delegate = delegate
        @mutex = Mutex.new
        @state_mutex = Mutex.new
        @alive = true
        @role = role
        @write_queue_capacity = write_queue_capacity
      end

      # Whether the socket is usable for I/O.
      #
      # Returns +false+ once a fatal write error has occurred or the
      # delegate has been closed by any means. This transition is
      # one-way -- a dead socket cannot be revived.
      #
      # @return [Boolean]
      def alive?
        @alive && !@delegate.closed?
      end

      # Queue a newline-terminated write for the writer thread.
      #
      # @return [nil] the write happens asynchronously
      def puts(*args, &block)
        enqueue_write(:puts, args, block)
      end

      # Queue output for the next main-stream opportunity.
      #
      # @return [Boolean] +true+ if accepted, +false+ if the socket is dead
      def puts_main_stream(*args)
        return false unless @alive

        ensure_writer!
        queued_args = copy_args(args)

        @stream_mutex.synchronize do
          return false unless alive?

          if stream_open?
            ensure_pending_capacity!
            @deferred_main_stream << queued_args
          else
            queue_puts_locked(queued_args)
          end
        end
        true
      rescue StandardError => e
        handle_enqueue_error('puts_main_stream', e)
        false
      end

      # Compatibility alias for scripts using the historical name. Blocks were
      # never part of the asynchronous contract and are intentionally ignored.
      def puts_if(*args)
        puts_main_stream(*args)
      end

      # Queue a raw write for the writer thread.
      #
      # @return [nil] the write happens asynchronously
      def write(*args, &block)
        enqueue_write(:write, args, block)
      end

      # Marks the socket dead, closes the delegate, and stops the writer.
      def close(*args, &block)
        @alive = false
        @delegate.close(*args, &block) unless @delegate.closed?
        @write_queue.push([:stop, [], nil], true) if @write_queue.is_a?(Queue)
      rescue ThreadError
        nil
      end

      # Delegates all non-write methods to the underlying socket.
      #
      # Read-side errors propagate normally so that connection
      # lifecycle threads can detect disconnects.
      def method_missing(method, *args, &block)
        @delegate.__send__(method, *args, &block)
      end

      # @return [Boolean] whether the delegate responds to +method+
      def respond_to_missing?(method, include_private = false)
        @delegate.respond_to?(method, include_private) || super
      end

      private

      def ensure_writer_state
        return if @write_queue.is_a?(SizedQueue) && @stream_mutex &&
                  @deferred_main_stream.is_a?(Array) && @stream_stack.is_a?(Array)

        WRITER_INIT_MUTEX.synchronize do
          @write_queue = SizedQueue.new(@write_queue_capacity) unless @write_queue.is_a?(SizedQueue)
          @stream_mutex ||= Mutex.new
          @stream_stack ||= (@role == :detachable ? [ATTACHMENT_STREAM_SENTINEL] : [])
          @deferred_main_stream ||= []
        end
      end

      def writer_alive?
        @writer_thread&.alive?
      end

      def ensure_writer!
        ensure_writer_state
        return if writer_alive?

        WRITER_INIT_MUTEX.synchronize do
          return if writer_alive?

          @writer_thread = Thread.new { writer_loop }
          @writer_thread.name = 'client socket writer' if @writer_thread.respond_to?(:name=)
        end
      end

      def writer_loop
        loop do
          kind, args, block = @write_queue.pop
          begin
            @mutex.synchronize do
              return unless alive?

              case kind
              when :puts
                @delegate.puts(*args, &block)
              when :write
                @delegate.write(*args, &block)
              when :stop
                return
              end
            end
          rescue *FATAL_WRITE_ERRORS => e
            handle_write_failure(e)
            return
          rescue StandardError => e
            log_writer_error('writer', e)
          end
        end
      end

      def enqueue_write(kind, args, block = nil)
        return nil unless alive?

        ensure_writer!
        queued_args = copy_args(args)

        @stream_mutex.synchronize do
          queued_args.each { |arg| note_stream_xml!(arg) }
          enqueue_item_locked([kind, queued_args, block])
          flush_deferred_locked
        end
        nil
      rescue StandardError => e
        handle_enqueue_error(kind, e)
        nil
      end

      def copy_args(args)
        args.map { |arg| arg.is_a?(String) ? arg.dup : arg }
      end

      def queue_puts_locked(queued_args)
        queued_args.each { |arg| note_stream_xml!(arg) }
        enqueue_item_locked([:puts, queued_args, nil])
      end

      def flush_deferred_locked
        return false if stream_open?

        flushed = false
        while (queued_args = @deferred_main_stream.shift)
          queue_puts_locked(queued_args)
          flushed = true
          break if stream_open?
        end
        flushed
      rescue WriteQueueOverflow
        raise
      rescue StandardError => e
        log_writer_error('deferred main-stream output', e)
        false
      end

      def stream_open?
        !@stream_stack.empty?
      end

      def note_stream_xml!(payload)
        payload.to_s.scan(/<[^>]+>/) do |tag|
          if tag.match?(/\A<pushStream\b/i)
            @stream_stack << (tag[/\bid=(["'])(.*?)\1/, 2] || true)
          elsif tag.match?(/\A<popStream\b/i)
            stream_id = tag[/\bid=(["'])(.*?)\1/, 2]
            if stream_id && (index = @stream_stack.rindex(stream_id))
              @stream_stack.delete_at(index)
            else
              @stream_stack.pop
            end
          elsif tag.match?(/\A<prompt\b/i)
            @stream_stack.clear
          end
        end
      end

      def ensure_pending_capacity!
        return if @write_queue.length + @deferred_main_stream.length < @write_queue_capacity

        raise WriteQueueOverflow, "pending frontend writes exceeded #{@write_queue_capacity}"
      end

      def enqueue_item_locked(item)
        ensure_pending_capacity!
        @write_queue.push(item, true)
      rescue ThreadError
        raise WriteQueueOverflow, "pending frontend writes exceeded #{@write_queue_capacity}"
      end

      def handle_enqueue_error(operation, error)
        if error.is_a?(WriteQueueOverflow)
          handle_write_failure(error)
        else
          log_writer_error(operation, error)
        end
      end

      def log_writer_error(operation, error)
        Lich.log "error: client socket #{operation} failed: #{error.class} - #{error.message}\n\t#{error.backtrace&.first}"
      end

      # Marks the socket permanently dead, closes the delegate, and
      # logs the error.
      #
      # Closing the delegate is the key architectural decision: it
      # unblocks any thread stuck in a blocking read (+gets+), which
      # lets the detachable client thread's reconnection loop restart
      # the TCP listener. Without this, a dead-but-open socket leaves
      # readers blocked indefinitely (the zombie state from issue #594).
      #
      # @api private
      # @param error [Exception] the fatal write error that triggered death
      # @return [void]
      def handle_write_failure(error)
        transitioned = @state_mutex.synchronize do
          next false unless @alive

          @alive = false
          true
        end
        return unless transitioned

        @delegate.close rescue nil
        if @role == :primary && defined?(Lich::Common::ShutdownCoordinator) && Lich::Common::ShutdownCoordinator.respond_to?(:record_client_socket_write_failure)
          Lich::Common::ShutdownCoordinator.record_client_socket_write_failure(error: error)
        end
        message = "client socket write failed: #{error.class} - #{error.message} (role=#{@role})"
        if defined?(Lich::Common::ShutdownLog) && Lich::Common::ShutdownLog.respond_to?(:error)
          Lich::Common::ShutdownLog.error(message)
        else
          Lich.log "error: #{message}"
        end
      end
    end
  end
end
