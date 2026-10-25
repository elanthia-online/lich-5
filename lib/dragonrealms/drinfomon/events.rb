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
      # two writers from both copying the same hash and losing an update, and
      # makes record_match's check-and-write atomic against add and delete.
      @@matchers = {}.freeze
      @@matchers_lock = Mutex.new

      def self.[](key)
        @@flags[key]
      end

      def self.[]=(key, value)
        @@flags[key] = value
      end

      def self.add(key, *matchers)
        regexes = matchers.map { |item| item.is_a?(Regexp) ? item : /#{item}/i }.freeze
        @@matchers_lock.synchronize do
          @@flags[key] = false
          @@matchers = @@matchers.merge(key => regexes).freeze
        end
        regexes
      end

      def self.reset(key)
        @@flags[key] = false
      end

      def self.delete(key)
        @@matchers_lock.synchronize do
          @@matchers = @@matchers.reject { |k, _| k == key }.freeze
          @@flags.delete key
        end
      end

      # Sets a flag to a match DRParser.check_events found, unless the flag was
      # deleted or added again since check_events took its snapshot of the
      # matchers. Without the check, a line matching a stale snapshot puts a
      # deleted flag back into flags, or sets a re-added flag from its old
      # patterns.
      # @param key [String] the flag
      # @param regexes [Array<Regexp>] the matchers check_events matched against
      # @param matches [MatchData] the match
      # @return [void]
      def self.record_match(key, regexes, matches)
        @@matchers_lock.synchronize do
          @@flags[key] = matches if @@matchers[key].equal?(regexes)
        end
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
