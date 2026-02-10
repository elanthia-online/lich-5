# frozen_string_literal: true

module Lich
  module DragonRealms
    class Flags
      @@flags = {}
      @@matchers = {}

      def self.[](key)
        @@flags[key]
      end

      def self.[]=(key, value)
        @@flags[key] = value
      end

      # BUG FIX: Use Regexp.escape to prevent regex injection attacks.
      # If `item` contains special regex characters like ".*" or "(foo|bar)",
      # those would be interpreted as regex metacharacters, potentially
      # matching unintended strings or causing ReDoS attacks.
      def self.add(key, *matchers)
        @@flags[key] = false
        @@matchers[key] = matchers.map { |item| item.is_a?(Regexp) ? item : /#{Regexp.escape(item)}/i }
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
    end
  end
end
