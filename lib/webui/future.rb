# frozen_string_literal: true

require_relative 'dispatcher'

module Lich
  module WebUI
    # Single-assignment completion used by non-blocking core and blocking shim modals.
    class Future
      Result = Data.define(:button, :reason)

      def initialize
        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @result = nil
        @callbacks = []
      end

      def resolved?
        @mutex.synchronize { !@result.nil? }
      end

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

      def cancel(reason: :cancelled)
        resolve(reason: reason)
      end

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
