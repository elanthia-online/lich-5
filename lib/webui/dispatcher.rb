# frozen_string_literal: true

require_relative 'errors'
require_relative 'work_item'

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

      class OwnerState
        attr_accessor :running, :current
        attr_accessor :thread
        attr_reader :events, :mutex, :condition

        # Creates the isolated queue, synchronization, and worker state for one owner.
        def initialize
          @events = []
          @mutex = Mutex.new
          @condition = ConditionVariable.new
          @running = true
          @current = nil
          @thread = nil
        end
      end

      # Creates bounded owner queues; workers start only when work is admitted.
      # @param logger [#call, nil] diagnostic sink accepting level and message
      # @param thread_factory [#call, nil] worker constructor accepting a block
      def initialize(logger: nil, thread_factory: nil)
        @logger = logger || proc { |_level, _message| }
        @thread_factory = thread_factory || ->(&block) { Thread.new(&block) }
        @owners = {}.compare_by_identity
        @terminated_owners = ObjectSpace::WeakMap.new
        @mutex = Mutex.new
        @stopped = false
      end

      # Queues owner work and owns cleanup through execution, refusal or removal.
      # @param owner [Object] callback lifecycle owner
      # @param page_id [String] owning page identifier
      # @param viewer_id [String] submitting attachment identifier
      # @param cid [String] submitting component identifier
      # @param event [Symbol] event name
      # @param coalescable [Boolean] whether a later matching event can replace this one
      # @param cleanup [Proc, nil] resource disposal, including canceled submissions
      # @yield callback to execute on the owner's worker
      # @return [Symbol] :queued or :coalesced
      # @raise [Error] when the owner is stopped or its queue is full
      def enqueue(owner:, page_id:, viewer_id:, cid:, event:, coalescable:, cleanup: nil, &callable)
        work = WorkItem.new(cleanup: cleanup, &callable)
        discarded = []
        accepted = false
        raise ArgumentError, 'owner is required' unless owner

        state = owner_state(owner)
        queued = Event.new(owner, page_id, viewer_id, cid, event, coalescable, work)
        state.mutex.synchronize do
          raise Error, 'owner dispatcher is terminated' unless state.running

          if coalescable && coalesce_last!(state.events, queued, discarded)
            accepted = true
            return :coalesced
          end
          enforce_bounds!(state.events, queued, discarded)
          state.events << queued
          accepted = true
          state.condition.signal
        end
        :queued
      ensure
        work&.cancel unless accepted
        dispose_events(discarded || [])
      end

      # Refuses future work, disposes queued callbacks, and allows current work to finish.
      # @param owner [Object] lifecycle owner to stop
      # @return [Boolean] whether an active owner worker existed
      def shutdown_owner(owner)
        state = @mutex.synchronize do
          @terminated_owners[owner] = true
          @owners.delete(owner)
        end
        return false unless state

        discarded = state.mutex.synchronize do
          state.running = false
          pending = state.events.dup
          state.events.clear
          state.condition.broadcast
          pending
        end
        dispose_events(discarded)
        unless state.thread.equal?(Thread.current)
          state.thread.join(SHUTDOWN_JOIN_TIMEOUT)
          log(:warning, "WebUI callback thread did not stop within #{SHUTDOWN_JOIN_TIMEOUT}s") if state.thread.alive?
        end
        true
      end

      # Closes admission before collecting workers, including not-yet-seen owners.
      # @return [void]
      def shutdown
        owners = @mutex.synchronize do
          @stopped = true
          @owners.keys
        end
        owners.each { |owner| shutdown_owner(owner) }
      end

      # Rejects synchronous event waits, including same-page callback re-entry.
      # @raise [ReentryError] always; callbacks must compose asynchronous work
      def await(page_id)
        context = Thread.current.thread_variable_get(THREAD_CONTEXT_KEY)
        if context&.page_id == page_id
          raise ReentryError.new('synchronous event re-entry is refused', page_id: page_id)
        end

        raise ReentryError.new('dispatcher does not provide synchronous event waits', page_id: page_id)
      end

      # Returns callback attribution for the current thread only.
      # @return [Context, nil] active dispatch context, or nil outside a callback
      def current_context
        Thread.current.thread_variable_get(THREAD_CONTEXT_KEY)
      end

      private

      # Finds or creates a worker under the same admission lock used by shutdown.
      # @api private
      # @param owner [Object] callback lifecycle identity
      # @return [OwnerState] live worker state
      # @raise [Error] when the dispatcher or owner has terminated
      def owner_state(owner)
        @mutex.synchronize do
          raise Error, 'dispatcher is stopped' if @stopped
          raise Error, 'owner dispatcher is terminated' if @terminated_owners[owner]

          @owners[owner] ||= begin
            state = OwnerState.new
            state.thread = @thread_factory.call { run_owner(state) }
            state
          end
        end
      end

      # Executes queued owner callbacks sequentially and clears thread attribution on every exit.
      # Standard callback failures are reported without aborting the next queued event.
      # @return [void]
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
            log(:error, "WebUI callback failed owner=#{owner_label(queued.owner)} error=#{error.class} at=#{error.backtrace&.first}")
          ensure
            Thread.current.thread_variable_set(THREAD_CONTEXT_KEY, nil)
            state.current = nil
          end
        end
      end

      # Replaces a matching tail while deferring cleanup until after queue unlock.
      # @api private
      # @param events [Array<Event>] pending queue
      # @param queued [Event] new event
      # @param discarded [Array<Event>] removed events awaiting disposal
      # @return [Boolean] whether replacement occurred
      def coalesce_last!(events, queued, discarded)
        last = events.last
        return false unless last&.coalescable
        return false unless last.viewer_id == queued.viewer_id
        return false unless last.page_id == queued.page_id && last.cid == queued.cid && last.event == queued.event

        discarded << last
        events[-1] = queued
        true
      end

      # Evicts replaceable events before refusing an overflowing terminal event.
      # @api private
      # @param events [Array<Event>] pending queue
      # @param queued [Event] incoming event
      # @param discarded [Array<Event>] evictions awaiting disposal
      # @return [void]
      # @raise [OverflowError] when terminal events occupy the available capacity
      def enforce_bounds!(events, queued, discarded)
        while viewer_count(events, queued.viewer_id) >= VIEWER_LIMIT || page_count(events, queued.page_id) >= PAGE_LIMIT
          index = events.index(&:coalescable)
          break unless index

          discarded << events.delete_at(index)
        end
        return if viewer_count(events, queued.viewer_id) < VIEWER_LIMIT && page_count(events, queued.page_id) < PAGE_LIMIT

        raise OverflowError.new(
          'WebUI event queue overflow', owner: owner_label(queued.owner),
          page_id: queued.page_id, cid: queued.cid, field: queued.event
        )
      end

      # Disposes removed callbacks without holding queue locks or skipping later ones.
      # @api private
      # @param events [Array<Event>] callbacks no longer owned by a queue
      # @return [void]
      def dispose_events(events)
        events.each do |event|
          event.callable.cancel
        rescue StandardError => error
          log(:error, "WebUI callback cleanup failed error=#{error.class}")
        end
      end

      def viewer_count(events, viewer_id)
        events.count { |event| event.viewer_id == viewer_id }
      end

      def page_count(events, page_id)
        events.count { |event| event.page_id == page_id }
      end

      def owner_label(owner)
        Diagnostics.owner_label(owner)
      end

      # Isolates diagnostic-sink failures from dispatch and shutdown.
      # @return [void]
      def log(level, message)
        Diagnostics.log(@logger, level, message)
      end
    end
  end
end
