# frozen_string_literal: true

module Lich
  module WebUI
    # Owns one queued callback and its cleanup until execution or cancellation.
    # Cancellation never disposes resources already in use by a running callback.
    class WorkItem
      # Captures work without running it; cleanup must be safe to call once.
      # @param cleanup [Proc, nil] resource disposal on every terminal path
      # @yield the work to execute at most once
      def initialize(cleanup: nil, &work)
        raise ArgumentError, 'work block is required' unless work

        @work = work
        @cleanup = cleanup
        @state = :pending
        @mutex = Mutex.new
      end

      # Claims pending work and disposes its resources even when it raises.
      # @return [Object, nil] callback result, or nil if already claimed/canceled
      def call
        work = @mutex.synchronize do
          next unless @state == :pending

          @state = :running
          @work
        end
        return unless work

        begin
          work.call
        ensure
          finish(:running)
        end
      end

      # Disposes work that has not started, leaving running work to its ensure.
      # @return [void]
      def cancel
        finish(:pending)
      end

      private

      # Releases references under lock and invokes disposal outside the lock.
      # @api private
      # @param expected [Symbol] state this caller is allowed to finish
      # @return [void]
      def finish(expected)
        cleanup = @mutex.synchronize do
          next unless @state == expected

          @state = :finished
          @work = nil
          callback = @cleanup
          @cleanup = nil
          callback
        end
        cleanup&.call
        nil
      end
    end
  end
end
