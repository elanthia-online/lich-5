# frozen_string_literal: true

require_relative 'errors'

module Lich
  module WebUI
    # One bounded, ordered UI callback thread per owner.
    class Dispatcher
      VIEWER_LIMIT = 256
      PAGE_LIMIT = 1024
      SHUTDOWN_JOIN_TIMEOUT = 2
      THREAD_CONTEXT_KEY = :lich_webui_dispatch_context

      Event = Data.define(:owner, :page_id, :viewer_id, :cid, :event, :coalescable, :callable)
      Context = Data.define(:owner, :page_id, :viewer_id, :cid, :event)

      class OverflowError < Error; end
      class ReentryError < Error; end
      class TerminatedError < Error; end

      class OwnerState
        attr_accessor :running, :current
        attr_accessor :thread
        # The last failure reported for this owner, so an identical one that
        # follows it is not reported again in full. One string per owner,
        # dropped with the owner.
        attr_accessor :last_failure
        attr_reader :events, :mutex, :condition

        def initialize
          @events = []
          @mutex = Mutex.new
          @condition = ConditionVariable.new
          @running = true
          @current = nil
          @thread = nil
          @last_failure = nil
        end
      end

      # @param logger [#call, nil] receives `(level, message)`; nil discards
      # @param thread_factory [#call, nil] builds an owner's thread from a block; nil uses Thread.new
      # @param notifier [#call, nil] receives `(owner, message)` when a callback raises; nil uses
      #   {#notify_script}, which tells a script owner through its own output
      def initialize(logger: nil, thread_factory: nil, notifier: nil)
        @logger = logger || proc { |_level, _message| }
        @thread_factory = thread_factory || ->(&block) { Thread.new(&block) }
        @notifier = notifier || method(:notify_script)
        @owners = {}.compare_by_identity
        # Owners that have been shut down. Weak, so a dead script's object is
        # not kept alive by the record that it died. Checked before an owner
        # state is looked up, because owner_state creates one on demand: a
        # late enqueue for a shut-down owner -- a browser-exit callback, a
        # timer -- used to start a fresh worker for it, running beside the
        # one still blocked in the callback shutdown timed out waiting for.
        @terminated = ObjectSpace::WeakKeyMap.new
        @mutex = Mutex.new
      end

      def enqueue(owner:, page_id:, viewer_id:, cid:, event:, coalescable:, &callable)
        raise ArgumentError, 'owner is required' unless owner
        raise ArgumentError, 'callback block is required' unless callable
        # The tombstone check and the state lookup are one critical section:
        # done as two, a shutdown could mark the owner terminal and drop its
        # state between them, and the lookup then created a fresh worker for
        # a dead owner.
        state = owner_state(owner, page_id: page_id, cid: cid)
        queued = Event.new(owner, page_id, viewer_id, cid, event, coalescable, callable)
        state.mutex.synchronize do
          raise Error, 'owner dispatcher is terminated' unless state.running

          if coalescable && coalesce_last!(state.events, queued)
            return :coalesced
          end
          enforce_bounds!(state.events, queued)
          state.events << queued
          state.condition.signal
        end
        :queued
      end

      def shutdown_owner(owner)
        # Marked terminal before the state goes, under the same lock enqueue
        # checks it under, so no enqueue can slip in between and revive it.
        state = @mutex.synchronize do
          @terminated[owner] = true
          @owners.delete(owner)
        end
        return false unless state

        state.mutex.synchronize do
          state.running = false
          state.events.clear
          state.condition.broadcast
        end
        unless state.thread.equal?(Thread.current)
          state.thread.join(SHUTDOWN_JOIN_TIMEOUT)
          log(:warning, "WebUI callback thread did not stop within #{SHUTDOWN_JOIN_TIMEOUT}s") if state.thread.alive?
        end
        true
      end

      def shutdown
        owners = @mutex.synchronize { @owners.keys }
        owners.each { |owner| shutdown_owner(owner) }
      end

      # Always refused: the dispatcher provides no synchronous wait at all.
      # Whether the caller is the page's own callback only changes the
      # message, so a script author can tell a deadlock they nearly wrote
      # from a wait they simply cannot have.
      def await(page_id)
        context = Thread.current.thread_variable_get(THREAD_CONTEXT_KEY)
        message = +'synchronous event waits are refused'
        message << "; this is a re-entry from the page's own callback" if context&.page_id == page_id
        raise ReentryError.new(message, page_id: page_id)
      end

      def current_context
        Thread.current.thread_variable_get(THREAD_CONTEXT_KEY)
      end

      private

      # The owner's worker state, created on first use. Refused, under the
      # same lock, for an owner that has been shut down: creating a state for
      # one would start a new worker beside whatever its old one is still
      # finishing.
      def owner_state(owner, page_id: nil, cid: nil)
        @mutex.synchronize do
          if @terminated.key?(owner)
            raise TerminatedError.new('owner has been shut down', owner: owner_label(owner), page_id: page_id, cid: cid)
          end

          @owners[owner] ||= begin
            state = OwnerState.new
            state.thread = @thread_factory.call { run_owner(state) }
            state
          end
        end
      end

      def run_owner(state)
        loop do
          queued = state.mutex.synchronize do
            state.condition.wait(state.mutex) while state.running && state.events.empty?
            state.events.shift if state.running || !state.events.empty?
          end
          break unless queued

          state.current = queued
          context = Context.new(queued.owner, queued.page_id, queued.viewer_id, queued.cid, queued.event)
          Thread.current.thread_variable_set(THREAD_CONTEXT_KEY, context)
          begin
            queued.callable.call
          rescue StandardError => error
            report_failure(state, queued, error)
          ensure
            Thread.current.thread_variable_set(THREAD_CONTEXT_KEY, nil)
            state.current = nil
          end
        end
      end

      def coalesce_last!(events, queued)
        last = events.last
        return false unless last&.coalescable
        # Per viewer: two viewers editing the same control are two events,
        # and folding them together dropped one viewer's update.
        return false unless last.page_id == queued.page_id && last.cid == queued.cid &&
                            last.event == queued.event && last.viewer_id == queued.viewer_id

        events[-1] = queued
        true
      end

      # Both counts are taken once and then kept current as events are
      # evicted; recounting the queue on every pass made a full eviction
      # walk quadratic in the queue length.
      def enforce_bounds!(events, queued)
        viewers = events.count { |event| event.viewer_id == queued.viewer_id }
        pages = events.count { |event| event.page_id == queued.page_id }
        while viewers >= VIEWER_LIMIT || pages >= PAGE_LIMIT
          index = events.index(&:coalescable)
          break unless index

          evicted = events.delete_at(index)
          viewers -= 1 if evicted.viewer_id == queued.viewer_id
          pages -= 1 if evicted.page_id == queued.page_id
        end
        return if viewers < VIEWER_LIMIT && pages < PAGE_LIMIT

        raise OverflowError.new(
          'WebUI event queue overflow', owner: owner_label(queued.owner),
          page_id: queued.page_id, cid: queued.cid, field: queued.event
        )
      end

      def owner_label(owner)
        return owner.webui_owner_id if owner.respond_to?(:webui_owner_id)
        return owner.name if owner.respond_to?(:name) && owner.name

        "#{owner.class}:#{owner.object_id}"
      end

      # What a callback raised, told to the log and to the owner. It used to
      # be one log line naming only the exception class, through a logger
      # that Lich never supplied: every handler error in every native WebUI
      # script was discarded, and the player saw a control that did nothing.
      # The shim already reported its handlers' errors with the script frame
      # (Session#report); this is the same for the pages a script builds
      # itself.
      #
      # The same failure again, straight after itself, is one log line and
      # no notification: a broken control clicked twenty times is twenty
      # events, and the player has read the message once. A different
      # failure in between is reported in full again, so a second distinct
      # error is never hidden behind the first.
      def report_failure(state, queued, error)
        label = owner_label(queued.owner)
        backtrace = Array(error.backtrace)
        origin = script_origin(backtrace, label)
        where = origin ? " at #{script_frame(origin)}" : ''
        detail = "error in WebUI handler #{queued.event} on #{queued.cid}: #{error.message}#{where}"
        if state.last_failure == detail
          log(:error, "#{detail} owner=#{label} (again)")
          return
        end

        state.last_failure = detail
        log(:error, "#{detail} owner=#{label} error=#{error.class}\n\t#{backtrace.first(8).join("\n\t")}")
        @notifier.call(queued.owner, detail)
      rescue StandardError
        nil
      end

      # The default notifier: a script owner hears about the error in its
      # own output, through Lich's `respond`, the way a script error does.
      # Any other owner (the launcher) has the log.
      def notify_script(owner, message)
        return unless defined?(::Script) && owner.is_a?(::Script)
        return unless respond_to?(:respond, true)

        respond(message)
      end

      # The first backtrace frame inside the owner's script. Lich evals a
      # script under its bare name, so its frames read "map:2466" rather
      # than ".../map.lic:2466"; both spellings are matched.
      def script_origin(backtrace, name)
        unless name.to_s.empty?
          named = backtrace.find { |frame| frame.match?(/(\A|[\\\/])#{Regexp.escape(name.to_s)}(\.lic)?:\d+/) }
          return named if named
        end
        backtrace.find { |frame| frame.include?('.lic:') }
      end

      # ".../scripts/map.lic:2462:in 'block'" -> "map.lic:2462".
      def script_frame(frame)
        file, line, = frame.split(':in ').first.to_s.rpartition(':').values_at(0, 2)
        base = file.to_s.split(%r{[\\/]}).last
        base && line ? "#{base}:#{line}" : frame
      end

      def log(level, message)
        @logger.call(level, message)
      rescue StandardError
        nil
      end
    end
  end
end
