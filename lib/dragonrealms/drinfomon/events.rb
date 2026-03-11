# frozen_string_literal: true

module Lich
  module DragonRealms
    class Flags
      @@flags = {}
      @@matchers = {}
      @@pending = {}

      def self.[](key)
        # Move pending value to flags on first access (for testing)
        if @@pending.key?(key)
          @@flags[key] = @@pending.delete(key)
        end
        @@flags[key]
      end

      def self.[]=(key, value)
        @@flags[key] = value
      end

      def self.add(key, *matchers)
        @@flags[key] = false
        @@matchers[key] = matchers.map { |item| item.is_a?(Regexp) ? item : /#{item}/i }
      end

      def self.reset(key)
        @@flags[key] = false
      end

      def self.delete(key)
        @@matchers.delete key
        @@flags.delete key
      end

      def self.flags
        @@flags
      end

      def self.matchers
        @@matchers
      end

      # For testing: set a flag value that survives Flags.add calls
      # The value is moved from pending to flags on first access via Flags[]
      def self.set_pending(key, value)
        @@pending[key] = value
      end

      # Full reset for test isolation - clears all state
      def self.reset!
        @@flags = {}
        @@matchers = {}
        @@pending = {}
      end
    end
  end
end
