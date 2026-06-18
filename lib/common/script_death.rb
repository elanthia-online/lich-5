# frozen_string_literal: true

module Lich
  module Common
    # Registry of callbacks to run when a script dies.
    #
    # Subsystems that keep per-script state in a global registry (e.g. the hook
    # registries) register a cleanup here at load time, so the Script kill path
    # iterates handlers instead of naming each subsystem and reaching into its
    # internals. Adding a new per-script registry means registering one handler
    # at its own load site, not editing Script#kill.
    module ScriptDeath
      @handlers = []

      class << self
        # Registers a cleanup callback invoked with the dying Script on death.
        #
        # @yieldparam script [Script] the script being torn down
        # @return [void]
        def on_death(&block)
          @handlers << block if block
        end

        # Runs every registered handler with the dying script. A handler that
        # raises is logged and skipped so one bad callback cannot abort kill
        # cleanup or block sibling handlers.
        #
        # @param script [Script] the script being torn down
        # @return [void]
        def run(script)
          @handlers.each do |handler|
            handler.call(script)
          rescue StandardError => e
            Lich.log("error: ScriptDeath handler: #{e}") if defined?(Lich) && Lich.respond_to?(:log)
          end
        end
      end
    end
  end
end
