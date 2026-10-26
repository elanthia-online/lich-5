# frozen_string_literal: true

require_relative 'dispatcher'

module Lich
  module WebUI
    # Single-assignment completion used by non-blocking core and blocking shim modals.
    class Future
      Result = Data.define(:button, :reason)

      # Creates an unresolved completion with isolated callback diagnostics.
      # @param logger [#call, nil] sink accepting level and sanitized message
      def initialize(logger: nil)
        @logger = logger || proc { |level, message| Lich.log("#{level}: #{message}") if Lich.respond_to?(:log) }
        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @result = nil
        @callbacks = []
      end

      # Reports whether a result has been recorded under the future lock.
      # @return [Boolean]
      def resolved?
        @mutex.synchronize { !@result.nil? }
      end

      # Completes once and runs every callback, logging individual callback failures.
      # @param button [Object, nil] accepted response or submitted form result
      # @param reason [Symbol, nil] cancellation or completion reason
      # @return [Boolean] whether this call won completion
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
        callbacks&.each { |callback| invoke(callback, result) }
        accepted
      end

      # Resolves an unresolved future with a cancellation reason.
      # @param reason [Symbol] terminal cancellation status
      # @return [Boolean] whether this call resolved the future
      def cancel(reason: :cancelled)
        resolve(reason: reason)
      end

      # Registers a completion callback, invoking it immediately if already resolved.
      # Callback exceptions are isolated consistently for early and late registration.
      # @param callback [Proc] observer receiving the winning completion
      # @yieldparam result [Result] winning completion
      # @return [Future] this completion
      # @raise [ArgumentError] if no callback is supplied
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
        invoke(callback, result) if result
        self
      end

      # Waits for a result without canceling the future on timeout.
      # Never call from an owner callback: that worker must remain free to resolve it.
      # @param timeout [Numeric, nil] maximum monotonic wait in seconds
      # @return [Result, nil] result, or nil when the deadline expires
      # @raise [Dispatcher::ReentryError] when called from dispatcher context
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

      # Prevents a script callback or diagnostic sink from interrupting other cleanup.
      # @param callback [#call] completion observer
      # @param result [Result] winning completion
      # @return [void]
      # @api private
      def invoke(callback, result)
        callback.call(result)
      rescue StandardError => error
        begin
          @logger.call(:error, "WebUI completion callback failed: #{error.class}")
        rescue StandardError
          nil
        end
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
