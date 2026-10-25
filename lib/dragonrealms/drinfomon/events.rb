# frozen_string_literal: true

module Lich
  module DragonRealms
    class Flags
      @@flags = {}
      # DRParser.check_events iterates @@matchers on the game thread while
      # scripts add and delete flags from their own threads. Inserting a key
      # into a hash another thread is iterating raises "can't add a new key
      # into hash during iteration", so writers never mutate @@matchers in
      # place: they build a new hash and swap the reference, and an iteration
      # in progress keeps walking the hash it started with. The mutex stops
      # two writers from both copying the same hash and losing an update.
      @@matchers = {}.freeze
      @@matchers_lock = Mutex.new

      def self.[](key)
        @@flags[key]
      end

      def self.[]=(key, value)
        @@flags[key] = value
      end

      def self.add(key, *matchers)
        regexes = matchers.map { |item| item.is_a?(Regexp) ? item : /#{item}/i }
        @@flags[key] = false
        @@matchers_lock.synchronize { @@matchers = @@matchers.merge(key => regexes).freeze }
      end

      def self.reset(key)
        @@flags[key] = false
      end

      def self.delete(key)
        @@matchers_lock.synchronize { @@matchers = @@matchers.reject { |k, _| k == key }.freeze }
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
