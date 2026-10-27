# frozen_string_literal: true

require 'json'
require_relative 'errors'

module Lich
  module WebUI
    # One-shot carrier for viewer- and server-originated sensitive values.
    #
    # Ordinary conversion and serialization always produce REDACTION. The plaintext is available
    # only inside #consume's block, and the owned String is cleared on a best-effort basis when
    # that block exits.
    #
    # Sensitive-value policy (one policy for every WebUI layer): ordinary interfaces are redacted,
    # the owned carrier is consumed once, and its String is cleared best-effort. This is not
    # zero-copy handling and does not guarantee erasure of process memory. The incoming frame, the
    # parsed JSON, the validator's copy, the byte-budget measurement and any String the caller
    # retains are Ruby-managed copies that disposal neither tracks nor erases. Input byte limits
    # still apply to sensitive values as to any other input.
    class SensitiveValue
      REDACTION = '[REDACTED]'
      ORIGINS = %i[viewer server].freeze

      attr_reader :origin

      # Wraps a copied viewer submission for one-time consumption.
      # @param value [String] plaintext copied into the carrier; the caller's string is unchanged
      # @return [SensitiveValue] viewer-origin carrier
      # @raise [ArgumentError] if value is not a String
      def self.viewer(value)
        new(value, origin: :viewer)
      end

      # Wraps a copied server value for one-time consumption.
      # @param value [String] plaintext copied into the carrier; the caller's string is unchanged
      # @return [SensitiveValue] server-origin carrier
      # @raise [ArgumentError] if value is not a String
      def self.server(value)
        new(value, origin: :server)
      end

      # Owns a separate string buffer and records its trusted origin classification.
      # @param value [String] plaintext to copy
      # @param origin [Symbol] :viewer or :server
      # @raise [ArgumentError] for non-string values or an unknown origin
      def initialize(value, origin:)
        raise ArgumentError, 'sensitive value must be a String' unless value.is_a?(String)
        raise ArgumentError, "unknown sensitive origin: #{origin.inspect}" unless ORIGINS.include?(origin)

        @value = value.dup
        @origin = origin
        @consumed = false
      end

      # Reports whether the value has been consumed or explicitly discarded.
      # @return [Boolean]
      def consumed?
        @consumed
      end

      # Yields plaintext once, then clears the owned buffer best-effort, even on failure.
      # Callers must not retain plaintext copies; disposal cannot erase those copies.
      # @yield [value] operation needing the secret
      # @yieldparam value [String] owned plaintext buffer, cleared best-effort on block exit
      # @return [Object] block result
      # @raise [ArgumentError] when no block is supplied
      # @raise [ConsumedSensitiveValueError] after consumption or disposal
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

      # Disposes an unused carrier without exposing its plaintext; clearing is best-effort.
      # @return [Boolean] false if already consumed or discarded
      def discard!
        return false if @consumed

        @consumed = true
        clear_value!
        true
      end

      # Returns the redaction marker for ordinary string conversion.
      # @return [String] redaction marker
      def to_s
        REDACTION
      end

      # Keeps inspection and diagnostic output free of plaintext.
      # @return [String] redaction marker
      def inspect
        REDACTION
      end

      # Supplies only the redaction marker to JSON serializers.
      # @return [String] redaction marker
      def as_json(*)
        REDACTION
      end

      # Encodes the redaction marker, never the owned plaintext buffer.
      # @return [String] JSON string literal
      def to_json(*)
        REDACTION.to_json
      end

      # Supplies only a redacted scalar to YAML serialization.
      # @param coder [Object] YAML coder supporting scalar=
      # @return [void]
      def encode_with(coder)
        coder.scalar = REDACTION
      end

      # Excludes the plaintext buffer from Ruby Marshal output.
      # @return [String] redaction marker
      def marshal_dump
        REDACTION
      end

      private

      # Best-effort clearing of this carrier's own Ruby String: it is overwritten and emptied, but
      # that does not prove an earlier heap allocation was erased, and other copies are untouched.
      # @return [void]
      def clear_value!
        return unless @value

        @value.replace("\0" * @value.bytesize)
        @value.clear
      end
    end
  end
end
