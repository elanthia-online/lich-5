# frozen_string_literal: true

require_relative 'dispatcher'

module Lich
  module WebUI
    # Single-assignment completion used by non-blocking core and blocking shim modals.
    #
    # A modal resolves its Future exactly once, with the button pressed or
    # the reason nobody pressed one. Core code chains {#then}; the GTK shim,
    # which must give a synchronous answer, blocks in {#await} -- except from
    # a WebUI callback thread, where blocking would deadlock the page.
    class Future
      # The completion value: the button pressed, or the reason the dialog closed without one.
      #
      # @!attribute [r] button
      #   @return [String, nil] the button id the viewer pressed
      # @!attribute [r] reason
      #   @return [Symbol, nil] `:timeout`, `:dismissed`, `:no_viewer`, `:terminated`, `:cancelled`, `:error`
      Result = Data.define(:button, :reason)

      # Builds an unresolved future.
      #
      # @return [Future] the future
      def initialize
        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @result = nil
        @callbacks = []
      end

      # Whether a result has been assigned.
      #
      # @return [Boolean]
      def resolved?
        @mutex.synchronize { !@result.nil? }
      end

      # Assigns the result, wakes waiters, and runs the callbacks; a second call is ignored.
      #
      # @param button [String, nil] the button pressed
      # @param reason [Symbol, nil] why the dialog closed without a button
      # @return [Boolean] whether this call was the one that resolved the future
      def resolve(button: nil, reason: nil)
        callbacks = nil
        result = Result.new(button, reason)
        accepted = @mutex.synchronize do
          next false if @result

          @result = result
          callbacks = @callbacks
          @callbacks = []
          @condition.broadcast
          true
        end
        callbacks&.each { |callback| callback.call(result) }
        accepted
      end

      # Resolves with a reason and no button.
      #
      # @param reason [Symbol] why the future is being cancelled
      # @return [Boolean] whether this call was the one that resolved the future
      def cancel(reason: :cancelled)
        resolve(reason: reason)
      end

      # Runs a callback with the result: now if resolved, otherwise when it is.
      #
      # @yield [result] once, when the future resolves
      # @yieldparam result [Result]
      # @return [Future] self
      # @raise [ArgumentError] when no block is given
      def then(&callback)
        raise ArgumentError, 'completion callback is required' unless callback

        result = @mutex.synchronize do
          if @result
            @result
          else
            @callbacks << callback
            nil
          end
        end
        callback.call(result) if result
        self
      end

      # Blocks the calling thread until the future resolves or the timeout passes.
      #
      # @param timeout [Numeric, nil] seconds to wait, or nil to wait indefinitely
      # @return [Result, nil] the result, or nil when the timeout passed first
      # @raise [Dispatcher::ReentryError] when called from a WebUI callback thread
      def await(timeout: nil)
        if Thread.current.thread_variable_get(Dispatcher::THREAD_CONTEXT_KEY)
          raise Dispatcher::ReentryError, 'a WebUI callback cannot block awaiting a modal'
        end

        deadline = timeout && monotonic_time + timeout
        @mutex.synchronize do
          until @result
            remaining = deadline && deadline - monotonic_time
            return nil if remaining && !remaining.positive?

            @condition.wait(@mutex, remaining)
          end
          @result
        end
      end

      private

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
