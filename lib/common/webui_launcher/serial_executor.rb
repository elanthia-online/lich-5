# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      # One launcher-owned worker. It keeps blocking authentication and catalog
      # mutations off the WebUI dispatcher while preserving mutation order.
      class SerialExecutor
        # Sentinel queued by {#stop} to end the worker loop.
        STOP = Object.new.freeze

        # Starts the worker thread; queued work runs on it in the order posted.
        #
        # @return [SerialExecutor]
        def initialize
          @queue = Queue.new
          @thread = Thread.new { run }
          @thread.report_on_exception = false
        end

        # Queues a unit of work for the worker thread.
        #
        # An error raised by the work is logged and does not stop the worker.
        #
        # @yield the work to run, with no arguments, on the worker thread
        # @return [Boolean] true once the work is queued
        # @raise [ArgumentError] when no block is given
        def post(&work)
          raise ArgumentError, 'work block is required' unless work

          @queue << work
          true
        end

        # Asks the worker to finish the work already queued and then exit.
        #
        # Work in flight is not interrupted; callers that need to refuse a late
        # side effect check for themselves (see WebUILauncher#commit).
        #
        # @param wait [Boolean] whether to join the worker thread before returning; never joins
        #   when called from the worker itself
        # @return [nil]
        def stop(wait: true)
          @queue << STOP if @thread&.alive?
          @thread.join if wait && !@thread.equal?(Thread.current)
          nil
        end

        private

        def run
          while (work = @queue.pop) != STOP
            begin
              work.call
            rescue StandardError => error
              Lich.log("error: WebUI launcher operation failed: #{error.class}: #{error.message}") if Lich.respond_to?(:log)
            end
          end
        end
      end
    end
  end
end
