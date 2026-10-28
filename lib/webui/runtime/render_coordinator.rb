# frozen_string_literal: true

require_relative '../errors'
require_relative '../dispatcher'
require_relative '../host_thread'

module Lich
  module WebUI
    class Runtime
      # Owns coalesced render workers and their cancellation admission.
      # Runtime retains page validity, delivery, scheduling calls and diagnostics.
      # @api private
      class RenderCoordinator
        STOP_TIMEOUT = 2

        # Reported for a worker still running when cancellation's deadline passed.
        class StopTimeout < Error; end

        # Creates one independent worker domain for its enclosing runtime.
        # @param on_error [#call] reports the original owner and worker exception
        # @param stop_timeout [Numeric] total seconds cancellation waits for workers
        # @return [RenderCoordinator] initialized coordinator
        # @api private
        def initialize(on_error:, stop_timeout: STOP_TIMEOUT)
          @on_error = on_error
          @stop_timeout = stop_timeout
          @refresh_mutex = Mutex.new
          @publication_done = ConditionVariable.new
          @publishing = {}.compare_by_identity
          @refresh_state = {}.compare_by_identity
          @closed_owners = ObjectSpace::WeakMap.new
          @stopping = false
        end

        # Coalesces changes behind the exact key's existing worker and first callable.
        # Workers are host threads, so their lifetime never follows the script that
        # happened to trigger publication.
        # @param key [Object] render source identified by object identity
        # @param owner [Object] lifecycle owner used for admission and cancellation
        # @param delay [Numeric] existing batching delay in seconds
        # @param render [Proc] first callable retained until the record retires
        # @return [nil]
        # @raise [Error] when the owner or host stopped admitting renders
        # @api private
        def schedule_render(key, owner:, delay: 0.01, &render)
          @refresh_mutex.synchronize do
            raise Error, 'render owner is terminated' if @stopping || @closed_owners[owner]

            state = (@refresh_state[key] ||= {
              dirty: false, thread: nil, owner: owner, work: render, delay: delay, cancelled: false
            })
            if state[:thread]&.alive?
              state[:dirty] = true
              return
            end
            state[:thread] = HostThread.start { refresh_loop(key, state) }
          end
          nil
        end

        # Runs one delivery only while the owner still admits publication.
        # Admission is checked and the delivery counted under the state lock, and
        # cancellation waits (bounded) for counted deliveries, so no delivery can
        # start after cancel_renders returns, even from a worker that outlived its
        # bounded join. Deliveries never run author code and may run concurrently.
        # @param owner [Object] lifecycle owner of the delivered page
        # @yield delivery to perform while admitted
        # @return [Object] block result
        # @raise [Error] when the owner or host stopped admitting renders
        # @api private
        def publish(owner)
          @refresh_mutex.synchronize do
            raise Error, 'render owner is terminated' if @stopping || @closed_owners[owner]

            @publishing[owner] = @publishing.fetch(owner, 0) + 1
          end
          begin
            yield
          ensure
            @refresh_mutex.synchronize do
              remaining = @publishing.fetch(owner) - 1
              remaining.zero? ? @publishing.delete(owner) : @publishing[owner] = remaining
              @publication_done.broadcast
            end
          end
        end

        # Closes admission, cancels matching workers and waits a bounded time for them.
        # Workers still running at the deadline are marked stop_failed and reported;
        # closed publication admission keeps their late results from being delivered.
        # The current worker is never joined by itself; retired owner keys stay weak.
        # @param owner [Object, nil] exact owner, or nil to stop the entire domain
        # @return [Array<Thread>] workers whose cancellation was requested
        # @api private
        def cancel_renders(owner = nil)
          states = @refresh_mutex.synchronize do
            owner ? @closed_owners[owner] = true : @stopping = true
            @refresh_state.values.select do |state|
              next false if owner && !state[:owner].equal?(owner)

              state[:cancelled] = true
              state[:thread]
            end
          end
          deadline = monotonic_time + @stop_timeout
          # Admitted deliveries finish first; later ones are refused.
          @refresh_mutex.synchronize do
            while (owner ? @publishing.key?(owner) : !@publishing.empty?) && (remaining = deadline - monotonic_time).positive?
              @publication_done.wait(@refresh_mutex, remaining)
            end
          end
          states.each do |state|
            thread = state[:thread]
            next if thread.equal?(Thread.current)

            join_worker(thread, deadline)
            next unless thread.alive?

            @refresh_mutex.synchronize { state[:stop_failed] = true }
            report(state[:owner], StopTimeout.new("render worker did not stop within #{@stop_timeout}s; publication refused"))
          end
          states.map { |state| state[:thread] }
        end

        private

        # Repeats dirty work and removes only the current record during final cleanup.
        # Script failures and SystemExit end this worker and are reported against the
        # owner; fatal VM exceptions outside that set keep propagating.
        # @param key [Object] exact source key retained by this worker
        # @param state [Hash] scheduling record admitted for that key
        # @return [void]
        # @api private
        def refresh_loop(key, state)
          loop do
            sleep(state[:delay]) if state[:delay].positive?
            break if @refresh_mutex.synchronize { state[:cancelled] }

            state[:work].call
            repeat = @refresh_mutex.synchronize do
              dirty = state[:dirty] && !state[:cancelled]
              state[:dirty] = false
              @refresh_state.delete(key) unless dirty
              dirty
            end
            break unless repeat
          end
        rescue SystemExit, *Dispatcher::CONTAINED_EXCEPTIONS => error
          report(state[:owner], error)
        ensure
          @refresh_mutex.synchronize do
            @refresh_state.delete(key) if @refresh_state[key].equal?(state)
          end
        end

        # Waits until the shared deadline without letting a worker's terminal
        # exception abort the caller's remaining cleanup.
        # @param thread [Thread] render worker
        # @param deadline [Float] monotonic deadline shared by this cancellation
        # @return [void]
        # @api private
        def join_worker(thread, deadline)
          thread.join([deadline - monotonic_time, 0].max)
        rescue SystemExit, *Dispatcher::CONTAINED_EXCEPTIONS
          nil # refresh_loop already reported this worker's failure.
        end

        # Isolates the runtime's diagnostic/owner-stop hook from worker control flow.
        # @return [void]
        # @api private
        def report(owner, error)
          @on_error.call(owner, error)
        rescue StandardError
          nil
        end

        def monotonic_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
      private_constant :RenderCoordinator
    end
  end
end
