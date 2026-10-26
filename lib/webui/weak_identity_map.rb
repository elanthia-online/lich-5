# frozen_string_literal: true

module Lich
  module WebUI
    # Non-owning identity bookkeeping. Callers must strongly own live payloads;
    # Ruby's WeakMap weakens values as well as keys. Never use this as storage.
    # @api private
    class WeakIdentityMap
      include Enumerable

      def initialize
        @entries = ObjectSpace::WeakMap.new
      end

      def [](key) = @entries[key]

      def []=(key, value)
        @entries[key] = value
      end

      def delete(key) = @entries.delete(key)
      def key?(key) = @entries.key?(key)
      def size = @entries.size
      def empty? = size.zero?

      def fetch(key)
        return self[key] if key?(key)
        raise KeyError, 'unknown weak identity'
      end

      # Enumeration holds each yielded key/value alive for that operation only.
      def each
        return enum_for(:each) unless block_given?
        @entries.each_pair { |key, value| yield key, value }
        self
      end
      alias each_pair each
      def keys = map { |key, _value| key }
      def values = map { |_key, value| value }
      def each_key(&block) = keys.each(&block)
      def each_value(&block) = values.each(&block)
    end
  end
end
