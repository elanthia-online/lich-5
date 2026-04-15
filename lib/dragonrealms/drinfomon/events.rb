# frozen_string_literal: true

module Lich
  module DragonRealms
    class Flags
      @@flags = {}
      @@matchers = {}
      @@counts = {}

      def self.[](key)
        @@flags[key]
      end

      def self.[]=(key, value)
        @@flags[key] = value
      end

      def self.add(key, *matchers)
        @@flags[key] = false
        @@counts[key] = 0
        @@matchers[key] = matchers.map { |item| item.is_a?(Regexp) ? item : /#{item}/i }
      end

      def self.reset(key)
        @@counts[key] = 0
        @@flags[key] = false
      end

      def self.delete(key)
        @@matchers.delete key
        @@counts.delete key
        @@flags.delete key    
      end

      def self.flags
        @@flags
      end

      def self.matchers
        @@matchers
      end

      def self.count(key)
        @@counts[key] || 0
      end

      def self.counts
        @@counts
      end
    end
  end
end
