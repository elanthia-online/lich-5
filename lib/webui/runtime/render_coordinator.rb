# frozen_string_literal: true

require_relative '../errors'

module Lich
  module WebUI
    class Runtime
      # Owns coalesced render workers and their cancellation admission.
      # Runtime retains page validity, delivery, scheduling calls and diagnostics.
      # @api private
      class RenderCoordinator
        # Creates one independent worker domain for its enclosing runtime.
        # @param on_error [#call] reports the original owner and worker exception
        # @return [RenderCoordinator] initialized coordinator
        # @api private
        def initialize(on_error:)
          @on_error = on_error
          @refresh_mutex = Mutex.new
          @refresh_state = {}.compare_by_identity
          @closed_owners = ObjectSpace::WeakMap.new
          @stopping = false
        end

        # Coalesces changes behind the exact key's existing worker and first callable.
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
            state[:thread] = Thread.new { refresh_loop(key, state) }
          end
          nil
        end

        # Closes admission and joins matching workers outside the state mutex.
        # The current worker is never joined by itself; retired owner keys stay weak.
        # @param owner [Object, nil] exact owner, or nil to stop the entire domain
        # @return [Array<Thread>] workers whose cancellation was requested
        # @api private
        def cancel_renders(owner = nil)
          threads = @refresh_mutex.synchronize do
            owner ? @closed_owners[owner] = true : @stopping = true
            @refresh_state.values.filter_map do |state|
              next if owner && !state[:owner].equal?(owner)

              state[:cancelled] = true
              state[:thread]
            end
          end
          threads.each { |thread| thread.join unless thread.equal?(Thread.current) }
        end

        private

        # Repeats dirty work and removes only the current record during final cleanup.
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
              dirty = state[:dirty]
              state[:dirty] = false
              @refresh_state.delete(key) unless dirty
              dirty
            end
            break unless repeat
          end
        rescue StandardError => error
          @on_error.call(state[:owner], error)
        ensure
          @refresh_mutex.synchronize do
            @refresh_state.delete(key) if @refresh_state[key].equal?(state)
          end
        end
      end
      private_constant :RenderCoordinator
    end
  end
end
