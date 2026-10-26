# frozen_string_literal: true

require_relative 'errors'
require_relative 'host_thread'

module Lich
  module WebUI
    # One host timing worker; script callbacks execute only on the owner dispatcher.
    class Scheduler
      OWNER_LIMIT = 256
      HOST_LIMIT = 4096
      MAX_INTERVAL_MS = 4_294_967_295
      MIN_INTERVAL = 0.001

      # Captures an owner and host without allowing stale handles to recreate either.
      class Handle
        # @param scheduler [Scheduler] retained host scheduler
        # @param owner [Object] identity used for admission and cancellation
        def initialize(scheduler, owner)
          @scheduler, @owner = scheduler, owner
        end

        # @return [Integer] cancellable source ID; truthy callback results repeat
        def schedule(interval_ms, &work) = @scheduler.schedule(@owner, interval_ms, scope: self, &work)
        # @return [Boolean] whether this owner had a live source with the ID
        def cancel(id) = @scheduler.cancel(@owner, id)
        # Cancels sources registered through this handle, preserving other owner facilities.
        # @return [void]
        def cancel_all = @scheduler.cancel_owner(@owner, scope: self)
      end

      # @param dispatcher [Dispatcher] existing callback execution authority
      # @param admission [#call] validates owner admission against the host registry
      # @param logger [#call] diagnostic sink accepting level and message
      def initialize(dispatcher:, admission:, logger:)
        @dispatcher, @admission, @logger = dispatcher, admission, logger
        @mutex, @condition = Mutex.new, ConditionVariable.new
        @sources = {}
        @terminated = ObjectSpace::WeakMap.new
        @next_id = 0
        @stopped = false
      end

      # @return [Handle] owner-bound schedule/cancel capability, without starting a worker
      def for_owner(owner)
        raise ArgumentError, 'owner is required' unless owner

        Handle.new(self, owner)
      end

      # Registers one bounded source. Zero intervals defer with a 1ms fairness floor.
      # @return [Integer] monotonic ID, never reused by this host
      # @raise [ArgumentError, Error] for malformed, overflowing or stopped registrations
      def schedule(owner, interval_ms, scope: nil, &work)
        unless owner && work && interval_ms.is_a?(Integer) && interval_ms.between?(0, MAX_INTERVAL_MS)
          raise ArgumentError, 'owner, work and bounded integer interval are required'
        end
        @admission.call(owner)
        @mutex.synchronize do
          raise Error, 'scheduler or owner is stopped' if @stopped || @terminated[owner]
          if @sources.size >= HOST_LIMIT || @sources.values.count { |source| source[:owner].equal?(owner) } >= OWNER_LIMIT
            raise Error, 'scheduled source limit exceeded'
          end

          interval = [interval_ms / 1000.0, MIN_INTERVAL].max
          id = (@next_id += 1)
          @sources[id] = { owner: owner, scope: scope, interval: interval, due: now + interval, state: :waiting, work: work }
          @thread ||= HostThread.start { run }
          @condition.signal
          id
        end
      end

      # Cancellation suppresses queued work and rearming; a running callback may finish.
      # @return [Boolean] false for an unknown/finished ID
      # @raise [Error] when attempting to cancel another owner's live source
      def cancel(owner, id)
        raise ArgumentError, 'positive source ID required' unless id.is_a?(Integer) && id.positive?

        @mutex.synchronize do
          source = @sources[id]
          raise Error, 'scheduled source belongs to another owner' if source && !source[:owner].equal?(owner)

          removed = @sources.delete(id)
          @condition.signal
          !removed.nil?
        end
      end

      # Drops pending/running source records; terminal removal also closes admission.
      # @param owner [Object] identity to retire
      # @param terminal [Boolean] permanently refuse subsequent sources for this owner
      # @return [void]
      def cancel_owner(owner, terminal: false, scope: nil)
        @mutex.synchronize do
          @terminated[owner] = true if terminal
          @sources.delete_if { |_id, source| source[:owner].equal?(owner) && (!scope || source[:scope].equal?(scope)) }
          @condition.signal
        end
        nil
      end

      # Stops the timing worker and invalidates queued callbacks before dispatcher shutdown.
      # @return [void]
      def shutdown
        thread = @mutex.synchronize do
          @stopped = true
          @sources.clear
          @condition.broadcast
          @thread
        end
        thread&.join
        nil
      end

      private

      # @return [Float] monotonic time, independent of wall-clock changes
      def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Waits for deadlines without executing user callbacks or holding dispatch locks.
      # @return [void]
      def run
        loop do
          ready = @mutex.synchronize do
            loop do
              break if @stopped

              entry = @sources.select { |_id, source| source[:state] == :waiting }.min_by { |_id, source| source[:due] }
              delay = entry && entry.last[:due] - now
              if delay && delay <= 0
                entry.last[:state] = :queued
                break entry
              end
              @condition.wait(@mutex, delay)
            end
          end
          break unless ready

          submit(*ready)
          ready.clear # Do not retain the previous source while waiting for another deadline.
        end
      end

      # A discarded/rejected dispatcher item retires its still-queued source.
      # @return [void]
      def submit(id, source)
        executed = false
        @dispatcher.enqueue(owner: source[:owner], page_id: nil, viewer_id: nil, cid: nil,
                            event: :scheduled, coalescable: false,
                            cleanup: -> { discard(id, source) unless executed }) do
          executed = true
          execute(id, source)
        end
      rescue StandardError => error
        discard(id, source)
        @logger.call(:warning, "WebUI scheduled callback refused error=#{error.class}") rescue nil
      end

      # Rechecks cancellation at execution, then rearms only after successful completion.
      # @return [void]
      def execute(id, source)
        work = @mutex.synchronize do
          next unless @sources[id].equal?(source) && source[:state] == :queued

          source[:state] = :running
          source[:work]
        end
        return unless work

        repeat = false
        begin
          repeat = work.call
        ensure
          @mutex.synchronize do
            if @sources[id].equal?(source)
              if repeat
                source[:state], source[:due] = :waiting, now + source[:interval]
              else
                @sources.delete(id)
              end
              @condition.signal
            end
          end
        end
        nil
      end

      # @return [void] release canceled/rejected queued source references
      def discard(id, source)
        @mutex.synchronize do
          @sources.delete(id) if @sources[id].equal?(source) && source[:state] == :queued
          @condition.signal
        end
        nil
      end
    end
  end
end
