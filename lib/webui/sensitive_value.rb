# frozen_string_literal: true

require 'json'
require_relative 'errors'

module Lich
  module WebUI
    # One-shot carrier for viewer- and server-originated sensitive values.
    #
    # Ordinary conversion and serialization always produce REDACTION. The plaintext is available
    # only inside #consume's block and is cleared when that block exits.
    #
    # Clearing is best-effort defence in depth, not a guarantee: clear_value! zeroes the buffer
    # this object dup'd for itself, but copies the VM made along the way -- the caller's original
    # String, an interned or frozen copy, anything the GC has already moved -- are not scrubbed.
    class SensitiveValue
      # What every ordinary conversion of a carrier produces.
      REDACTION = '[REDACTED]'
      # Where a value may come from: typed by a viewer, or set by the server.
      ORIGINS = %i[viewer server].freeze

      # @return [Symbol] `:viewer` or `:server`
      attr_reader :origin

      # Wraps a value a viewer typed.
      #
      # @param value [String] the plaintext
      # @return [SensitiveValue] the carrier
      # @raise [ArgumentError] when +value+ is not a String
      def self.viewer(value)
        new(value, origin: :viewer)
      end

      # Wraps a value the server set.
      #
      # @param value [String] the plaintext
      # @return [SensitiveValue] the carrier
      # @raise [ArgumentError] when +value+ is not a String
      def self.server(value)
        new(value, origin: :server)
      end

      # Wraps a private copy of the plaintext.
      #
      # @param value [String] the plaintext
      # @param origin [Symbol] one of {ORIGINS}
      # @return [SensitiveValue] the carrier
      # @raise [ArgumentError] when +value+ is not a String or +origin+ is unknown
      def initialize(value, origin:)
        raise ArgumentError, 'sensitive value must be a String' unless value.is_a?(String)
        raise ArgumentError, "unknown sensitive origin: #{origin.inspect}" unless ORIGINS.include?(origin)

        @value = value.dup
        @origin = origin
        @consumed = false
      end

      # Whether the plaintext has been consumed or discarded.
      #
      # @return [Boolean]
      def consumed?
        @consumed
      end

      # Yields the plaintext once, then clears it.
      #
      # @yield [value] with the plaintext, which is cleared when the block exits
      # @yieldparam value [String]
      # @return [Object] the block's result
      # @raise [ArgumentError] when no block is given
      # @raise [ConsumedSensitiveValueError] when already consumed
      def consume
        raise ArgumentError, 'a consuming block is required' unless block_given?
        raise ConsumedSensitiveValueError, 'sensitive value has already been consumed' if @consumed

        @consumed = true
        begin
          yield @value
        ensure
          clear_value!
        end
      end

      # Clears the plaintext without yielding it.
      #
      # @return [Boolean] whether there was anything left to discard
      def discard!
        return false if @consumed

        @consumed = true
        clear_value!
        true
      end

      # @return [String] {REDACTION}
      def to_s
        REDACTION
      end

      # @return [String] {REDACTION}
      def inspect
        REDACTION
      end

      # @return [String] {REDACTION}
      def as_json(*)
        REDACTION
      end

      # @return [String] {REDACTION} as a JSON string literal
      def to_json(*)
        REDACTION.to_json
      end

      # Emits {REDACTION} when serialized by Psych.
      #
      # @param coder [Psych::Coder] the YAML coder
      # @return [void]
      def encode_with(coder)
        coder.scalar = REDACTION
      end

      # @return [String] {REDACTION}, so a Marshal dump carries no plaintext
      def marshal_dump
        REDACTION
      end

      private

      def clear_value!
        return unless @value

        @value.replace("\0" * @value.bytesize)
        @value.clear
      end
    end
  end
end
