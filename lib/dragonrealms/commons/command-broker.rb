# frozen_string_literal: true

module Lich
  module DragonRealms
    # Command Broker (Stage 1 infra).
    #
    # Serializes exclusive access to the single game connection with a *lease*
    # instead of by pausing peer scripts. A caller that cannot get the lease
    # parks itself on a condition variable (pausing no one) until the lease
    # frees or its bounded timeout elapses.
    #
    # This is the structural fix for the "$safe_pause_lock deadlock": pausing in
    # Lich is cooperative, so a paused script is a live thread that keeps every
    # mutex it holds. Coordinating with a lease -- where waiters park instead of
    # pausing the holder, and acquisition is bounded -- removes the ability for
    # one coordination mechanism to suspend the holder of another.
    #
    # Design notes (see docs/command-broker-design.md):
    #   * The critical section is guarded by broker STATE (@owner), not by a
    #     mutex held across the section. @mutex guards only the acquire/release
    #     state transitions and is NEVER held across a yield or any call that can
    #     reach Script.current. This is what makes bounded acquisition,
    #     dead-holder reclamation, and the watchdog possible.
    #   * Ownership is keyed by Thread.current (non-blocking, reentrant, and
    #     supports death detection via Thread#alive?).
    #   * Bail semantics: #exclusive returns :broker_timeout without running the
    #     block on acquisition timeout; #exclusive! raises LeaseTimeout instead.
    #   * Priority is a two-band queue (:high jumps ahead of :normal); there is
    #     NO preemption of an in-flight lease.
    #   * Watchdog reclaims leases held by a dead thread and logs (never revokes)
    #     an over-long live holder.
    #
    # Stage 1 wires this into DRC.bput only; direct fput/put remain unbrokered
    # until a later stage. Callers are migrated off safe_pause_list/pause_script
    # incrementally.
    class Broker
      # Raised by #exclusive! when the lease cannot be acquired in time.
      class LeaseTimeout < StandardError; end

      # Default bounded wait for a lease, in seconds. Matches the dominant
      # `pause 30` idiom in the callers being migrated. Override per call.
      DEFAULT_TIMEOUT = 30

      # How often the watchdog thread wakes, in seconds.
      WATCHDOG_INTERVAL = 5

      # How long a live holder may hold the lease before the watchdog logs a
      # (non-fatal) warning, in seconds. Sized to tolerate long roundtimes/casts
      # and fput's up-to-60s resend loop.
      WATCHDOG_WARN_AFTER = 90

      VALID_PRIORITIES = %i[high normal].freeze

      # Guards creation/reset of the process-wide default instance so a first-use
      # race between script threads cannot construct two brokers -- which would
      # split serialization across two independent leases.
      CLASS_MUTEX = Mutex.new

      class << self
        # The process-wide default broker instance used by the commons. Tests
        # construct their own with .new and do not touch this. Double-checked so
        # the hot path stays lock-free once initialized.
        def instance
          @instance || CLASS_MUTEX.synchronize { @instance ||= new }
        end

        # Test/lifecycle hook: stop the default instance's watchdog and drop it.
        # Swap under the class mutex, then stop the watchdog outside it so the
        # thread join can't block a concurrent #instance caller.
        def reset_instance!
          old = CLASS_MUTEX.synchronize do
            instance = @instance
            @instance = nil
            instance
          end
          old&.stop_watchdog!
        end

        def start_watchdog!(**opts)
          instance.start_watchdog!(**opts)
        end

        def stop_watchdog!
          instance.stop_watchdog!
        end

        def exclusive(**opts, &block)
          instance.exclusive(**opts, &block)
        end

        def exclusive!(**opts, &block)
          instance.exclusive!(**opts, &block)
        end

        def held?
          instance.held?
        end

        def mine?
          instance.mine?
        end

        def owner_name
          instance.owner_name
        end
      end

      def initialize
        @mutex = Mutex.new
        @free = ConditionVariable.new
        @owner = nil          # Thread currently holding the lease
        @depth = 0            # reentrancy count for @owner
        @acquired_at = nil    # monotonic time the lease was taken
        @holder_name = nil    # script name, for logs
        @intent = nil         # caller-supplied label, for logs
        @warned_age = nil     # last age (s) the watchdog warned at
        @waiters = []         # [{thread:, priority:, seq:}], grant order via #next_token_locked
        @seq = 0
        @watchdog = nil
      end

      # Run the block while holding an exclusive lease on the send channel.
      #
      # @param timeout [Numeric] bounded seconds to wait for the lease
      # @param intent [String, nil] short label for logging/watchdog
      # @param priority [:high, :normal] queue band; :high jumps ahead
      # @return the block's value, or :broker_timeout if the lease was not
      #   acquired in time (in which case the block does NOT run)
      def exclusive(timeout: DEFAULT_TIMEOUT, intent: nil, priority: :normal)
        return :broker_timeout unless acquire(timeout, intent, priority)

        guarded { yield }
      end

      # Like #exclusive but raises LeaseTimeout instead of returning the sentinel.
      def exclusive!(timeout: DEFAULT_TIMEOUT, intent: nil, priority: :normal)
        unless acquire(timeout, intent, priority)
          raise LeaseTimeout, "could not acquire command lease within #{timeout}s (held by #{owner_name || 'nobody'})"
        end

        guarded { yield }
      end

      # @return [Boolean] whether any lease is currently held
      def held?
        @mutex.synchronize { !@owner.nil? }
      end

      # @return [Boolean] whether the calling thread holds the lease
      def mine?
        @mutex.synchronize { @owner.equal?(Thread.current) }
      end

      # @return [String, nil] the holder's script name, or nil if free
      def owner_name
        @mutex.synchronize { @holder_name }
      end

      # One watchdog pass: reclaim a dead holder's lease, and warn (without
      # revoking) when a live holder has held past +warn_after+. Exposed so the
      # background thread and tests can drive it identically.
      #
      # @param warn_after [Numeric] seconds before a live holder is warned about
      def tick_watchdog(warn_after: WATCHDOG_WARN_AFTER)
        @mutex.synchronize do
          reclaim_if_dead_locked
          break if @owner.nil? || @acquired_at.nil?

          age = now - @acquired_at
          break if age < warn_after
          # Warn at most once per warn_after window so we don't spam.
          break if @warned_age && (age - @warned_age) < warn_after

          @warned_age = age
          log('bold', "DRC: Broker lease held #{age.round}s by #{describe_holder} -- possible stuck holder#{holder_backtrace}")
        end
      end

      # Start the background watchdog thread (idempotent). Started once at
      # runtime by the bput integration; never at load. The thread is a plain
      # background thread (the interpreter reaps it on exit) and is named for
      # diagnosability; use #stop_watchdog! for an orderly stop.
      def start_watchdog!(interval: WATCHDOG_INTERVAL)
        @mutex.synchronize do
          return @watchdog if @watchdog&.alive?

          @watchdog = Thread.new do
            Thread.current.name = 'dr-command-broker-watchdog' if Thread.current.respond_to?(:name=)
            loop do
              sleep interval
              begin
                tick_watchdog
              rescue StandardError => e
                Lich.log("error: broker watchdog: #{e}") if defined?(Lich) && Lich.respond_to?(:log)
              end
            end
          end
        end
      end

      # Stop the watchdog thread if running. Safe to call when not started.
      def stop_watchdog!
        thread = @mutex.synchronize do
          t = @watchdog
          @watchdog = nil
          t
        end
        return unless thread

        thread.kill
        thread.join(1)
        nil
      end

      private

      # Acquire the lease or time out. Returns true if held on return (including
      # a reentrant re-acquire), false on timeout.
      def acquire(timeout, intent, priority)
        me = Thread.current
        name = current_script_name

        @mutex.synchronize do
          reclaim_if_dead_locked

          if @owner.equal?(me) # reentrant: already ours
            @depth += 1
            return true
          end

          deadline = now + timeout
          token = enqueue_waiter_locked(me, priority)
          took = false
          begin
            until grantable_locked?(token)
              remaining = deadline - now
              return false if remaining <= 0

              @free.wait(@mutex, remaining)
              reclaim_if_dead_locked
            end
            take_lease_locked(me, name, intent)
            took = true
            return true
          ensure
            remove_waiter_locked(token)
            # If we did not take the lease (timeout/exception), a successor may
            # now be at the front of the queue -- wake waiters to re-check.
            @free.broadcast unless took
          end
        end
      end

      # Run a block under an already-held lease, releasing exactly once after.
      def guarded
        yield
      ensure
        release
      end

      def release
        @mutex.synchronize do
          return unless @owner.equal?(Thread.current)

          @depth -= 1
          return if @depth.positive?

          log('plain', "DRC: Broker lease released by #{describe_holder}")
          clear_lease_locked
          @free.broadcast
        end
      end

      def take_lease_locked(thread, name, intent)
        @owner = thread
        @depth = 1
        @acquired_at = now
        @holder_name = name
        @intent = intent
        @warned_age = nil
        log('plain', "DRC: Broker lease granted to #{describe_holder}")
      end

      def clear_lease_locked
        @owner = nil
        @depth = 0
        @acquired_at = nil
        @holder_name = nil
        @intent = nil
        @warned_age = nil
      end

      # Reclaim the lease if its holder thread has died without releasing.
      def reclaim_if_dead_locked
        return if @owner.nil? || @owner.alive?

        log('bold', "DRC: Broker reclaiming lease from dead holder #{describe_holder}")
        clear_lease_locked
        @free.broadcast
      end

      def grantable_locked?(token)
        @owner.nil? && next_token_locked.equal?(token)
      end

      # The waiter that should be granted next: highest priority first, then
      # FIFO by arrival sequence within a band.
      def next_token_locked
        @waiters.min_by { |w| [w[:priority] == :high ? 0 : 1, w[:seq]] }
      end

      def enqueue_waiter_locked(thread, priority)
        @seq += 1
        token = { thread: thread, priority: normalize_priority(priority), seq: @seq }
        @waiters << token
        token
      end

      def remove_waiter_locked(token)
        @waiters.delete(token)
      end

      def normalize_priority(priority)
        VALID_PRIORITIES.include?(priority) ? priority : :normal
      end

      def describe_holder
        @intent ? "#{@holder_name} (#{@intent})" : @holder_name.to_s
      end

      # A bounded snapshot of the holder thread's stack, appended to the stuck-
      # holder warning so an operator can see where it is wedged. Empty when
      # unavailable (e.g. the holder just died). Runs under @mutex, so it never
      # races the holder into a nil @owner.
      def holder_backtrace
        frames = Array(@owner&.backtrace).first(15)
        return '' if frames.empty?

        "\n    #{frames.join("\n    ")}"
      end

      # Monotonic clock so deadlines/ages are immune to wall-clock jumps.
      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # Best-effort current script name for logs. Uses Script.self (== the
      # running script) to match the commons convention; never raises.
      def current_script_name
        return '(unknown)' unless defined?(Script) && Script.respond_to?(:self)

        Script.self&.name || '(unknown)'
      rescue StandardError
        '(unknown)'
      end

      def log(style, message)
        return unless defined?(Lich::Messaging) && Lich::Messaging.respond_to?(:msg)

        Lich::Messaging.msg(style, message)
      rescue StandardError
        nil
      end
    end
  end
end
