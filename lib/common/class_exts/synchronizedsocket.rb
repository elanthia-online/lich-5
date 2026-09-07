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
    # A +WriteQueueOverflow+ additionally dumps every still-pending write to
    # +Lich.log+, so a stalled frontend can be diagnosed from the queue contents
    # rather than from the summary line alone.
    #
    # When the pending-write budget is exhausted the queue is first compacted by
    # discarding the oldest prompt-delimited groups; the session only ends if
    # compaction cannot free space. Compaction drops display data the parser has
    # already consumed, so a slow frontend costs a gap in its scrollback rather
    # than the whole session.
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
      DEFAULT_WRITE_QUEUE_CAPACITY = 4_096
      # Number of trailing prompt-delimited groups retained when the write queue
      # is compacted. A +<prompt>+ clears the stream stack, so a group boundary
      # is a point where stream nesting is balanced and older output can be
      # discarded without orphaning a pushStream in the frontend.
      OVERFLOW_KEEP_PROMPT_GROUPS = 10
      # Items injected ahead of the retained groups on compaction: the replayed
      # resync prompt and the client-visible notice. Kept in sync with
      # +drop_preamble+, which never returns more than this many items.
      DROP_PREAMBLE_SIZE = 2
      PROMPT_TAG = /<prompt\b/i
      # Per-argument byte cap applied when dumping pending writes after an
      # overflow. Longer payloads are truncated with their full byte size noted.
      OVERFLOW_DUMP_MAX_BYTES_PER_ARG = 1_024
      # Leading and trailing entries emitted per section by the overflow dump.
      # Bounds a single log record at roughly 400 entries per section instead of
      # the full queue capacity.
      OVERFLOW_DUMP_EDGE_ENTRIES = 200
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
        return if pending_length < @write_queue_capacity

        compact_write_queue!
        return if pending_length < @write_queue_capacity

        raise WriteQueueOverflow, "pending frontend writes exceeded #{@write_queue_capacity}"
      end

      # @api private
      # @return [Integer] queued writes plus deferred main-stream writes
      def pending_length
        @write_queue.length + @deferred_main_stream.length
      end

      # Discards the oldest prompt-delimited groups from the write queue.
      #
      # Cutting at a +<prompt>+ boundary is what makes this safe: a prompt
      # clears the stream stack, so the retained tail cannot begin inside an
      # unbalanced pushStream and leave the frontend with an orphaned window.
      #
      # Only display data is discarded. The parser has already consumed every
      # dropped record, so game state, GameObj, and Map are unaffected -- the
      # frontend simply shows a gap instead of the session ending.
      #
      # Writes after the final prompt form a trailing group that is always
      # retained, and any +:stop+ sentinel is preserved so the writer thread
      # cannot be left blocked.
      #
      # Two items are injected ahead of the retained groups. First the prompt
      # that terminated the last dropped group is replayed: the writer thread
      # was blocked mid-write, so the frontend may still hold an open stream,
      # and a prompt returns it to main-window context. Then a plain-text
      # notice, which would otherwise be swallowed by that open stream.
      #
      # @api private
      # @return [Boolean] whether anything was dropped
      def compact_write_queue!
        return false unless @write_queue.is_a?(SizedQueue)

        stops, groups = grouped_pending_writes
        kept = retained_groups(groups)
        if kept.length == groups.length
          report_unrequeued(requeue_writes(groups, stops))
          return false
        end

        dropped = groups[0...-kept.length]
        total_writes = groups.sum(&:length)
        dropped_writes = total_writes - kept.sum(&:length)
        unrequeued = requeue_writes(kept, stops, drop_preamble(dropped, dropped_writes))
        message = "warning: client socket write queue reached #{@write_queue_capacity}; dropped " \
                  "#{dropped_writes} of #{total_writes} pending display writes " \
                  "(#{dropped.length} prompt groups, role=#{@role})"
        message += "; #{unrequeued} retained writes could not be requeued" if unrequeued.positive?
        Lich.log message
        true
      rescue StandardError => e
        log_writer_error('write queue compaction', e)
        false
      end

      # @api private
      # @return [void]
      def report_unrequeued(unrequeued)
        return unless unrequeued.positive?

        Lich.log "error: client socket requeue lost #{unrequeued} pending writes (role=#{@role})"
      end

      # Selects the trailing groups to retain.
      #
      # Bounded by +OVERFLOW_KEEP_PROMPT_GROUPS+ and, separately, by the space
      # left once the injected preamble, the write that triggered compaction,
      # and any already-queued deferred main-stream writes are accounted for.
      # +ensure_pending_capacity!+ counts +@deferred_main_stream+ toward
      # capacity, so the retained queue must reserve room for it too --
      # otherwise compaction can report success while leaving pending_length
      # unchanged, and the very next capacity check fails anyway. Without the
      # budget bound at all, a small capacity or large groups could leave the
      # queue full again and end the session anyway.
      #
      # The newest group is always retained even if it alone exceeds the budget:
      # showing the most recent output beats showing none.
      #
      # @api private
      # @return [Array<Array>] retained groups, oldest first
      def retained_groups(groups)
        budget = @write_queue_capacity - DROP_PREAMBLE_SIZE - 1 - @deferred_main_stream.length
        kept = []
        total = 0
        groups.reverse_each do |group|
          break if kept.length >= OVERFLOW_KEEP_PROMPT_GROUPS
          break if kept.any? && total + group.length > budget

          kept.unshift(group)
          total += group.length
        end
        kept
      end

      # Builds the resync prompt and client-visible notice for a compaction.
      #
      # Every dropped group is prompt-terminated (the trailing partial group is
      # always retained), so the last item of the last dropped group is a
      # reliable resync point.
      #
      # The notice deliberately contains no XML-special characters, so it needs
      # no entity encoding and this class needs no knowledge of the frontend
      # dialect.
      #
      # @api private
      # @return [Array<Array>] queue items to enqueue before the retained groups
      def drop_preamble(dropped, dropped_writes)
        preamble = []
        resync = dropped.last&.last
        preamble << resync if resync
        preamble << [:write, ["--- Lich: frontend fell behind; dropped #{dropped_writes} " \
                              "lines of display output ---\r\n"], nil]
        preamble
      end

      # Drains the queue and splits it into prompt-terminated groups.
      #
      # @api private
      # @return [Array(Array, Array<Array>)] stop sentinels and write groups
      def grouped_pending_writes
        stops = []
        groups = []
        current = []
        drain_write_queue_items.each do |item|
          if item.first == :stop
            stops << item
            next
          end

          current << item
          next unless prompt_boundary?(item)

          groups << current
          current = []
        end
        groups << current unless current.empty?
        [stops, groups]
      end

      # @api private
      # @return [Boolean] whether the item ends a prompt group
      def prompt_boundary?(item)
        Array(item[1]).any? { |arg| PROMPT_TAG.match?(arg.to_s) }
      end

      # Requeues surviving writes in order.
      #
      # +note_stream_xml!+ is deliberately not re-run on these items:
      # +@stream_stack+ models the stream state at the *tail* of the queue, and
      # the tail is unchanged by compaction. Re-scanning would corrupt it.
      #
      # Pushes are non-blocking. The retention budget in +retained_groups+ is
      # sized so the queue cannot refill here, but that guarantee lives in
      # another method; if it is ever broken, report how many writes were lost
      # rather than aborting compaction with a generic error and silently
      # discarding the remainder.
      #
      # @api private
      # @return [Integer] number of items that could not be requeued
      def requeue_writes(groups, stops, preamble = [])
        items = preamble + groups.flatten(1) + stops
        items.each_with_index do |item, index|
          @write_queue.push(item, true)
        rescue ThreadError
          return items.length - index
        end
        0
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
        log_pending_writes if error.is_a?(WriteQueueOverflow)
      end

      # Drains and logs every still-pending write after a queue overflow.
      #
      # +SizedQueue+ has no non-destructive peek, so the queue is drained in
      # order to be inspected. That is safe here because the socket has already
      # been marked dead and the delegate closed, which makes the drained
      # entries undeliverable either way.
      #
      # The dump is emitted as a single +Lich.log+ call so it stays contiguous
      # in the log and does not stall the calling parser thread with thousands
      # of separate file writes.
      #
      # Two writes are necessarily absent from the dump: the one the writer
      # thread is currently blocked on (the writer holds that item, not the
      # queue), and the one the capacity check just rejected.
      #
      # @api private
      # @return [void]
      def log_pending_writes
        queued = drain_write_queue
        deferred = drain_deferred_main_stream
        lines = ["error: client socket overflow dump: #{queued.length} queued, #{deferred.length} deferred " \
                 "(capacity=#{@write_queue_capacity}, role=#{@role})"]
        lines.concat(dump_section('queued', queued) { |(kind, args)| "#{kind} #{format_pending_args(args)}" })
        lines.concat(dump_section('deferred', deferred) { |args| "puts #{format_pending_args(args)}" })
        Lich.log lines.join("\n")
      rescue StandardError => e
        log_writer_error('pending write dump', e)
      end

      # Renders one dump section, bounded to the leading and trailing
      # +OVERFLOW_DUMP_EDGE_ENTRIES+ entries with a count of what was omitted.
      #
      # At the default capacity an unbounded dump approaches several megabytes
      # in a single log record. The head shows what started the flood and the
      # tail shows what was in flight when the socket died, which is what the
      # dump is actually read for.
      #
      # @api private
      # @return [Array<String>]
      def dump_section(label, entries)
        edge = OVERFLOW_DUMP_EDGE_ENTRIES
        omitted = entries.length - (edge * 2)
        lines = []
        entries.each_with_index do |entry, index|
          lines << "\t... #{omitted} #{label} entries omitted ..." if omitted.positive? && index == edge
          next if omitted.positive? && index >= edge && index < entries.length - edge

          lines << "\t#{label}[#{index}] #{yield(entry)}"
        end
        lines
      end

      # @api private
      # @return [Array<Array(Symbol, Array, Proc)>] raw drained queue items, FIFO
      def drain_write_queue_items
        return [] unless @write_queue.is_a?(SizedQueue)

        drained = []
        begin
          loop { drained << @write_queue.pop(true) }
        rescue ThreadError
          nil
        end
        drained
      end

      # @api private
      # @return [Array<Array(Symbol, Array)>] drained queue entries in FIFO order
      def drain_write_queue
        drained = drain_write_queue_items
        requeue_stop_sentinel(drained)
        drained.filter_map { |kind, args, _block| [kind, args] unless kind == :stop }
      end

      # Re-arms the writer thread's exit signal after a destructive drain.
      #
      # +compact_write_queue!+ preserves stop sentinels for the same reason: a
      # discarded +:stop+ can leave a writer blocked in +pop+ with nothing left
      # to wake it. The queue is empty at this point so the push cannot fail,
      # but a lost exit signal is worse than a redundant rescue.
      #
      # @api private
      # @return [void]
      def requeue_stop_sentinel(drained)
        return unless drained.any? { |item| item.first == :stop }

        @write_queue.push([:stop, [], nil], true)
      rescue ThreadError
        nil
      end

      # @api private
      # @return [Array<Array>] drained deferred main-stream argument lists
      def drain_deferred_main_stream
        return [] unless @stream_mutex.is_a?(Mutex) && @deferred_main_stream.is_a?(Array)

        @stream_mutex.synchronize { @deferred_main_stream.shift(@deferred_main_stream.length) }
      end

      # @api private
      # @return [String] log-safe rendering of one queued write's arguments
      def format_pending_args(args)
        Array(args).map { |arg| dump_for_log(arg) }.join(' ')
      end

      # Renders a payload as an escaped, ASCII-only, single-line literal so
      # embedded newlines and control bytes cannot corrupt the log.
      #
      # @api private
      # @return [String]
      def dump_for_log(arg)
        text = arg.to_s
        return text.scrub.dump if text.bytesize <= OVERFLOW_DUMP_MAX_BYTES_PER_ARG

        "#{text.byteslice(0, OVERFLOW_DUMP_MAX_BYTES_PER_ARG).scrub.dump}...(#{text.bytesize} bytes total)"
      end
    end
  end
end
