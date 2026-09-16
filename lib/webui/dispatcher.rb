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

      class OwnerState
        attr_accessor :running, :current
        attr_accessor :thread
        attr_reader :events, :mutex, :condition

        def initialize
          @events = []
          @mutex = Mutex.new
          @condition = ConditionVariable.new
          @running = true
          @current = nil
          @thread = nil
        end
      end

      def initialize(logger: nil, thread_factory: nil)
        @logger = logger || proc { |_level, _message| }
        @thread_factory = thread_factory || ->(&block) { Thread.new(&block) }
        @owners = {}.compare_by_identity
        @mutex = Mutex.new
      end

      def enqueue(owner:, page_id:, viewer_id:, cid:, event:, coalescable:, &callable)
        raise ArgumentError, 'owner is required' unless owner
        raise ArgumentError, 'callback block is required' unless callable

        state = owner_state(owner)
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
        state = @mutex.synchronize { @owners.delete(owner) }
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

      def await(page_id)
        context = Thread.current.thread_variable_get(THREAD_CONTEXT_KEY)
        if context&.page_id == page_id
          raise ReentryError.new('synchronous event re-entry is refused', page_id: page_id)
        end

        raise ReentryError.new('dispatcher does not provide synchronous event waits', page_id: page_id)
      end

      def current_context
        Thread.current.thread_variable_get(THREAD_CONTEXT_KEY)
      end

      private

      def owner_state(owner)
        @mutex.synchronize do
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
            log(:error, "WebUI callback failed owner=#{owner_label(queued.owner)} error=#{error.class}")
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

      def enforce_bounds!(events, queued)
        while viewer_count(events, queued.viewer_id) >= VIEWER_LIMIT || page_count(events, queued.page_id) >= PAGE_LIMIT
          index = events.index(&:coalescable)
          break unless index

          events.delete_at(index)
        end
        return if viewer_count(events, queued.viewer_id) < VIEWER_LIMIT && page_count(events, queued.page_id) < PAGE_LIMIT

        raise OverflowError.new(
          'WebUI event queue overflow', owner: owner_label(queued.owner),
          page_id: queued.page_id, cid: queued.cid, field: queued.event
        )
      end

      def viewer_count(events, viewer_id)
        events.count { |event| event.viewer_id == viewer_id }
      end

      def page_count(events, page_id)
        events.count { |event| event.page_id == page_id }
      end

      def owner_label(owner)
        return owner.webui_owner_id if owner.respond_to?(:webui_owner_id)
        return owner.name if owner.respond_to?(:name) && owner.name

        "#{owner.class}:#{owner.object_id}"
      end

      def log(level, message)
        @logger.call(level, message)
      rescue StandardError
        nil
      end
    end
  end
end
