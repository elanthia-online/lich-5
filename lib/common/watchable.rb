# frozen_string_literal: true

# Watchable module provides a common interface for self-watching modules
# that manage their own lifecycle through background threads.
#
# Modules that include Watchable must implement a .watch! class method
# that spawns a background thread to monitor conditions and trigger
# initialization when ready.
#
# Example:
#   module MyModule
#     extend Lich::Common::Watchable
#
#     def self.watch!
#       @thread ||= Thread.new do
#         sleep 0.1 until conditions_met?
#         initialize!
#       end
#     end
#   end

module Lich
  module Common
    module Watchable
      # Called when a module extends Watchable
      # Validates that the module implements required methods
      def watch!
        raise NotImplementedError, "#{self.name} must implement .watch! to use Watchable"
      end
    end
  end
end
