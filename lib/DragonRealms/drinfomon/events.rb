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
    end
  end
end
