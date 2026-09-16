# frozen_string_literal: true

require 'json'
require_relative 'errors'

module Lich
  module WebUI
    # One-shot carrier for viewer- and server-originated sensitive values.
    #
    # Ordinary conversion and serialization always produce REDACTION. The plaintext is available
    # only inside #consume's block and is cleared when that block exits.
    class SensitiveValue
      REDACTION = '[REDACTED]'
      ORIGINS = %i[viewer server].freeze

      attr_reader :origin

      def self.viewer(value)
        new(value, origin: :viewer)
      end

      def self.server(value)
        new(value, origin: :server)
      end

      def initialize(value, origin:)
        raise ArgumentError, 'sensitive value must be a String' unless value.is_a?(String)
        raise ArgumentError, "unknown sensitive origin: #{origin.inspect}" unless ORIGINS.include?(origin)

        @value = value.dup
        @origin = origin
        @consumed = false
      end

      def consumed?
        @consumed
      end

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

      def discard!
        return false if @consumed

        @consumed = true
        clear_value!
        true
      end

      def to_s
        REDACTION
      end

      def inspect
        REDACTION
      end

      def as_json(*)
        REDACTION
      end

      def to_json(*)
        REDACTION.to_json
      end

      def encode_with(coder)
        coder.scalar = REDACTION
      end

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
