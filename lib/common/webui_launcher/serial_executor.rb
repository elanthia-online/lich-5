# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      # One launcher-owned worker. It keeps blocking authentication and catalog
      # mutations off the WebUI dispatcher while preserving mutation order.
      class SerialExecutor
        STOP = Object.new.freeze

        def initialize
          @queue = Queue.new
          @thread = Thread.new { run }
          @thread.report_on_exception = false
        end

        def post(&work)
          raise ArgumentError, 'work block is required' unless work

          @queue << work
          true
        end

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
