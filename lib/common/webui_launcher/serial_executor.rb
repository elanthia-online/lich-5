# frozen_string_literal: true

require_relative '../../webui/work_item'

module Lich
  module Common
    class WebUILauncher
      # One launcher-owned worker. It keeps blocking authentication and catalog
      # mutations off the WebUI dispatcher while preserving mutation order.
      class SerialExecutor
        STOP = Object.new.freeze

        # Starts one worker; posting and stopping share an admission lock.
        # @return [SerialExecutor] a running executor
        def initialize
          @queue = Queue.new
          @mutex = Mutex.new
          @stopped = false
          @thread = Thread.new { run }
          @thread.report_on_exception = false
        end

        # Accepts work while open, disposing rejected work immediately.
        # @param cleanup [Proc, nil] resource disposal on execution or cancellation
        # @yield blocking launcher work
        # @return [Boolean] whether the worker accepted the item
        def post(cleanup: nil, &work)
          item = Lich::WebUI::WorkItem.new(cleanup: cleanup, &work)
          accepted = @mutex.synchronize do
            next false if @stopped

            @queue << item
            true
          end
          item.cancel unless accepted
          accepted
        end

        # Cancels queued work and rejects new posts; running work finishes normally.
        # @param wait [Boolean] join the worker unless called from that worker
        # @return [void]
        def stop(wait: true)
          pending = @mutex.synchronize do
            next [] if @stopped

            @stopped = true
            items = []
            begin
              loop { items << @queue.pop(true) }
            rescue ThreadError
              # The worker may take the last item while stop drains the queue.
            end
            @queue << STOP
            items
          end
          pending.each(&:cancel)
          @thread.join if wait && !@thread.equal?(Thread.current)
          nil
        end

        private

        # Runs accepted work in order, preserving the worker after callback failures.
        # @api private
        # @return [void]
        def run
          while (work = @queue.pop) != STOP
            begin
              stopped = @mutex.synchronize { @stopped }
              stopped ? work.cancel : work.call
            rescue StandardError => error
              Lich.log("error: WebUI launcher operation failed: #{error.class}") if Lich.respond_to?(:log)
            end
          end
        end
      end
    end
  end
end
