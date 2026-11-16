# frozen_string_literal: true

module Lich
  module WebUI
    # Host workers must not inherit a script's kill-on-exit thread group. Gate
    # execution until ownership is transferred, including any child workers.
    module HostThread
      # Starts host work outside script-owned thread groups.
      # The gate prevents work from running until transfer to ThreadGroup::Default
      # succeeds; a failed transfer kills the waiting worker and re-raises.
      # @param arguments [Array<Object>] arguments forwarded to the block
      # @yield work to execute on the host thread
      # @return [Thread] started worker
      def self.start(*arguments, &work)
        gate = Queue.new
        worker = Thread.new { gate.pop; work.call(*arguments) }
        begin
          ThreadGroup::Default.add(worker)
          gate << true
          worker
        # Even an interrupt during transfer must not strand a gated worker.
        rescue Exception # rubocop:disable Lint/RescueException
          worker.kill
          raise
        end
      end
    end
  end
end
