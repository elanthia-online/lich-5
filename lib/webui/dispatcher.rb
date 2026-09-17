# frozen_string_literal: true

require_relative 'errors'

module Lich
  module WebUI
    # One bounded, ordered UI callback thread per owner.
    #
    # Every event a viewer raises against an owner's pages is queued here and
    # run, in order, on that owner's own thread, so a script's callbacks never
    # run concurrently with each other and a slow one cannot stall another
    # owner. The queue is bounded per viewer and per page; coalescable events
    # (a slider dragging) fold into their predecessor and are the first to go
    # when the bound is hit.
    class Dispatcher
      # Most queued events one viewer may have outstanding for an owner.
      VIEWER_LIMIT = 256
      # Most queued events one page may have outstanding for an owner.
      PAGE_LIMIT = 1024
      # Seconds a shutdown waits for the owner's thread to finish its current callback.
      SHUTDOWN_JOIN_TIMEOUT = 2
      # Thread-variable key under which a running callback finds its {Context}.
      THREAD_CONTEXT_KEY = :lich_webui_dispatch_context

      # A queued callback and what it is about.
      #
      # @!attribute [r] owner
      #   @return [Object] the owner whose thread runs it
      # @!attribute [r] page_id
      #   @return [String] the page
      # @!attribute [r] viewer_id
      #   @return [String, nil] the viewer that raised it
      # @!attribute [r] cid
      #   @return [String, nil] the component
      # @!attribute [r] event
      #   @return [Symbol, String] the event name
      # @!attribute [r] coalescable
      #   @return [Boolean] whether a later event of the same kind may replace it
      # @!attribute [r] callable
      #   @return [Proc] the callback
      Event = Data.define(:owner, :page_id, :viewer_id, :cid, :event, :coalescable, :callable)
      # What a running callback can learn about the event it is handling; see {#current_context}.
      #
      # @!attribute [r] owner
      #   @return [Object] the owner
      # @!attribute [r] page_id
      #   @return [String] the page
      # @!attribute [r] viewer_id
      #   @return [String, nil] the viewer
      # @!attribute [r] cid
      #   @return [String, nil] the component
      # @!attribute [r] event
      #   @return [Symbol, String] the event name
      Context = Data.define(:owner, :page_id, :viewer_id, :cid, :event)

      # The queue bound was hit and nothing coalescable could be evicted.
      class OverflowError < Error; end
      # A callback tried to block waiting on the page it is a callback for.
      class ReentryError < Error; end
      # An enqueue for an owner that has been shut down.
      class TerminatedError < Error; end

      # The queue, thread, and lock for one owner.
      class OwnerState
        # @!attribute running
        #   @return [Boolean] false once the owner is shut down
        # @!attribute current
        #   @return [Event, nil] the event being run right now
        attr_accessor :running, :current
        # @return [Thread, nil] the owner's callback thread
        attr_accessor :thread
        # @!attribute [r] events
        #   @return [Array<Event>] the queue
        # @!attribute [r] mutex
        #   @return [Mutex] guards the queue and flags
        # @!attribute [r] condition
        #   @return [ConditionVariable] signalled when the queue changes
        attr_reader :events, :mutex, :condition

        # Builds a running state with an empty queue and no thread yet.
        #
        # @return [OwnerState]
        def initialize
          @events = []
          @mutex = Mutex.new
          @condition = ConditionVariable.new
          @running = true
          @current = nil
          @thread = nil
        end
      end

      # Builds a dispatcher with no owners.
      #
      # @param logger [#call, nil] receives `(level, message)`; silent when nil
      # @param thread_factory [#call, nil] builds an owner's thread from a block; `Thread.new` by default
      # @param notifier [#call, nil] receives `(owner, message)` when a callback raises; nil uses
      #   {#notify_script}, which tells a script owner through its own output
      # @return [Dispatcher] the dispatcher
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

      # Queues a callback on the owner's thread, starting the thread on first use.
      #
      # @param owner [Object] the owner whose thread runs the callback
      # @param page_id [String] the page the event concerns
      # @param viewer_id [String, nil] the viewer that raised it
      # @param cid [String, nil] the component it concerns
      # @param event [Symbol, String] the event name
      # @param coalescable [Boolean] whether a later event of the same kind may replace this one
      # @yield the callback, run later on the owner's thread
      # @return [Symbol] `:queued`, or `:coalesced` when it replaced the previous queued event
      # @raise [ArgumentError] when the owner or block is missing
      # @raise [TerminatedError] when the owner has been shut down
      # @raise [Error] when the owner's state is no longer running
      # @raise [OverflowError] when the queue is full and nothing can be evicted
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

      # Stops an owner's thread, dropping its queued events, and refuses it from then on.
      #
      # @param owner [Object] the owner
      # @return [Boolean] whether the owner had a thread to stop
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

      # Shuts every owner down.
      #
      # @return [void]
      def shutdown
        owners = @mutex.synchronize { @owners.keys }
        owners.each { |owner| shutdown_owner(owner) }
      end

      # Always refused: the dispatcher provides no synchronous wait at all.
      # Whether the caller is the page's own callback only changes the
      # message, so a script author can tell a deadlock they nearly wrote
      # from a wait they simply cannot have.
      #
      # @param page_id [String] the page the caller wanted to wait on
      # @return [void] never returns
      # @raise [ReentryError] always
      def await(page_id)
        context = Thread.current.thread_variable_get(THREAD_CONTEXT_KEY)
        message = +'synchronous event waits are refused'
        message << "; this is a re-entry from the page's own callback" if context&.page_id == page_id
        raise ReentryError.new(message, page_id: page_id)
      end

      # The event the calling thread is handling, if it is a dispatcher thread mid-callback.
      #
      # @return [Context, nil]
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

      # The owner thread's loop: take the next event, run it with its context set, until shut down.
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
            report_failure(queued, error)
          ensure
            Thread.current.thread_variable_set(THREAD_CONTEXT_KEY, nil)
            state.current = nil
          end
        end
      end

      # Replaces the last queued event with this one when both are the same coalescable event.
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
      def report_failure(queued, error)
        label = owner_label(queued.owner)
        backtrace = Array(error.backtrace)
        origin = script_origin(backtrace, label)
        where = origin ? " at #{script_frame(origin)}" : ''
        detail = "error in WebUI handler #{queued.event} on #{queued.cid}: #{error.message}#{where}"
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
