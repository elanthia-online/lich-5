# frozen_string_literal: true

require 'json'
require_relative 'contract'

module Lich
  module WebUI
    # Strict, server-routed WebUI wire envelopes.
    module Protocol
      MAX_MESSAGE_BYTES = Contract::WIRE_LIMITS[:message_bytes]
      TYPES = %w[attach detach event].freeze
      FIELDS = {
        'attach' => %i[type page version resume],
        'detach' => %i[type page generation geometry],
        'event'  => %i[type page cid event generation payload submission request],
      }.freeze
      REQUIRED = {
        'attach' => %i[type page version],
        'detach' => %i[type page generation],
        'event'  => %i[type page cid event generation],
      }.freeze

      class Refusal < Error
        attr_reader :reason

        # Retains a machine-readable refusal reason alongside attributed diagnostics.
        # @param reason [Symbol] protocol refusal category
        # @param message [String] human-readable explanation
        def initialize(reason, message, **context)
          @reason = reason
          super(message, **context)
        end
      end

      module_function

      # Serializes server version, viewer ID, pages and negotiated input byte budgets.
      # @param viewer_id [String] assigned viewer identity
      # @param pages [Array<Hash>] visible page descriptors
      # @return [String] JSON wire message
      def hello(viewer_id:, pages:)
        JSON.generate(
          type: 'hello', contract_version: Contract::VERSION,
          viewer: viewer_id, pages: pages, limits: Contract::WIRE_LIMITS
        )
      end

      # Encodes a delivered page with the native properties the browser must not duplicate.
      # @param address [String] opaque registered page address
      # @param generation [Integer] delivered render generation
      # @param tree [Hash] serialized component tree with viewer-local values
      # @param facilities [Hash] page-level rendering facilities
      # @param bindings [Hash] component IDs mapped to accepted event names
      # @param submissions [Hash] terminal controls mapped to submitted input IDs
      # @param resume [String, nil] private viewer reconnection token
      # @param window_presentation [Hash] properties handled by the owned OS window
      # @param input_requests [Hash] latest accepted text-input request per viewer-local CID
      # @return [String] JSON render message
      def render(address:, generation:, tree:, facilities: {}, bindings: {}, submissions: {}, resume: nil, window_presentation: {}, input_requests: {})
        payload = {
          type: 'render', page: address, generation: generation,
          tree: tree, facilities: facilities, bindings: bindings, submissions: submissions,
          input_requests: input_requests
        }
        payload[:resume] = resume if resume
        payload[:window_presentation] = window_presentation unless window_presentation.empty?
        JSON.generate(payload)
      end

      # Serializes a refusal, retaining supplied request/component correlation.
      # @return [String] JSON wire message
      def refusal(reason:, message:, page: nil, cid: nil, event: nil, request: nil)
        JSON.generate(type: 'refusal', reason: reason.to_s, message: message, page: page, cid: cid,
                      event: event, request: request)
      end

      # Serializes a terminal notification for a registered page address.
      # @return [String] JSON wire message
      def page_closed(address:, reason:)
        JSON.generate(type: 'page_closed', page: address, reason: reason.to_s)
      end

      # Parses a bounded client frame and validates routing fields before dispatch.
      # Containers are frozen; leaf strings remain mutable for secret disposal.
      # @param raw [String] JSON text frame
      # @return [Hash] validated message with symbol keys
      # @raise [Refusal] for oversized, malformed, or unsupported messages
      def parse_client_message(raw)
        unless raw.is_a?(String) && raw.bytesize <= MAX_MESSAGE_BYTES
          raise Refusal.new(:frame_size, "message exceeds #{MAX_MESSAGE_BYTES} bytes")
        end

        message = JSON.parse(raw, symbolize_names: true, max_nesting: 32)
        raise Refusal.new(:malformed, 'message must be an object') unless message.is_a?(Hash)

        type = message[:type]
        raise Refusal.new(:malformed, 'message type is not allowed') unless TYPES.include?(type)

        unknown = message.keys - FIELDS.fetch(type)
        raise Refusal.new(:routing_field, "message contains forbidden field #{unknown.first}") unless unknown.empty?

        missing = REQUIRED.fetch(type) - message.keys
        raise Refusal.new(:malformed, "message is missing #{missing.first}") unless missing.empty?

        validate_budgets!(message)
        validate_common!(message)
        validate_type!(message)
        deep_freeze_containers(message)
      rescue JSON::ParserError => error
        raise Refusal.new(:malformed, "invalid JSON: #{error.class}")
      end

      # Compares equal-length byte sequences without stopping at the first mismatch.
      # Unequal lengths are rejected immediately.
      # @return [Boolean] whether all bytes match
      def secure_compare(expected, actual)
        expected = expected.to_s
        actual = actual.to_s
        return false unless expected.bytesize == actual.bytesize

        result = 0
        expected.bytes.zip(actual.bytes) { |left, right| result |= left ^ right }
        result.zero?
      end

      # Bounds serialized event data separately from routing-envelope overhead.
      # @param message [Hash] parsed client envelope
      # @return [void]
      # @raise [Refusal] if payload or aggregate submission exceeds its byte budget
      def validate_budgets!(message)
        { payload: :event_payload_bytes, submission: :submission_bytes }.each do |field, limit|
          next unless message.key?(field)
          next if JSON.generate(message[field]).bytesize <= Contract::WIRE_LIMITS.fetch(limit)

          raise Refusal.new(:frame_size, "#{field} exceeds the serialized byte limit; reduce the input size")
        end
      end
      private_class_method :validate_budgets!

      def validate_common!(message)
        unless message[:page].is_a?(String) && message[:page].match?(Contract::IDENTIFIER)
          raise Refusal.new(:malformed, 'page must be an opaque registered address')
        end
        return if message[:type] == 'attach'
        unless message[:generation].is_a?(Integer) && message[:generation].positive?
          raise Refusal.new(:malformed, 'generation must be a positive integer')
        end
      end
      private_class_method :validate_common!

      def validate_type!(message)
        case message[:type]
        when 'attach'
          Contract.negotiate!(message[:version])
          if message.key?(:resume) && !(message[:resume].is_a?(String) && message[:resume].match?(Contract::IDENTIFIER))
            raise Refusal.new(:malformed, 'resume token has invalid syntax')
          end
        when 'event'
          if message.key?(:request) && !(message[:request].is_a?(Integer) && message[:request].between?(1, 9_007_199_254_740_991))
            raise Refusal.new(:malformed, 'request must be a positive safe integer')
          end
          unless message[:cid].is_a?(String) && message[:cid].match?(Contract::CID_PATTERN)
            raise Refusal.new(:malformed, 'cid has invalid syntax')
          end
          unless message[:event].is_a?(String) && message[:event].match?(Contract::IDENTIFIER)
            raise Refusal.new(:malformed, 'event has invalid syntax')
          end
          if message.key?(:payload) && !message[:payload].is_a?(Hash)
            raise Refusal.new(:malformed, 'payload must be an object')
          end
          if message.key?(:submission) && !message[:submission].is_a?(Array)
            raise Refusal.new(:malformed, 'submission must be an ordered array')
          end
        end
      rescue VersionError => error
        raise Refusal.new(:version, error.message)
      end
      private_class_method :validate_type!

      # Freezes routing containers while preserving mutable secret-bearing leaf strings.
      # @return [Object] supplied value
      def deep_freeze_containers(value)
        case value
        when Hash then value.each { |key, child| key.freeze; deep_freeze_containers(child) }
        when Array then value.each { |child| deep_freeze_containers(child) }
        else return value
        end
        value.freeze
      end
      private_class_method :deep_freeze_containers
    end
  end
end
