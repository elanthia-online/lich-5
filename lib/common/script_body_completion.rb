# frozen_string_literal: true

module Lich
  module Common
    # Registry of callbacks to run when a script's body finishes, before the
    # script is stopped.
    #
    # A subsystem that may need a finished script to stay registered a little
    # longer (for example until work the body left behind has run) registers a
    # handler here at its own load site. The handler runs on the script's own
    # thread and may block; the script is stopped once every handler returns.
    # Script therefore keeps one completion point and never names a subscriber.
    module ScriptBodyCompletion
      @handlers = []

      class << self
        # Registers a callback invoked with each script whose body has finished.
        # The body may have returned, exited or raised; the handler reads the
        # outcome from the script.
        #
        # @yieldparam script [Script] the script whose body has finished
        # @return [void]
        def on_complete(&block)
          @handlers << block if block
        end

        # Runs every registered handler with the finished script. A handler
        # that raises is logged and skipped so one bad callback cannot keep
        # the script from stopping or block sibling handlers.
        #
        # @param script [Script] the script whose body has finished
        # @return [void]
        def run(script)
          @handlers.each do |handler|
            handler.call(script)
          rescue StandardError => e
            Lich.log("error: ScriptBodyCompletion handler: #{e.class}") if defined?(Lich) && Lich.respond_to?(:log)
          end
        end
      end
    end
  end
end
