# frozen_string_literal: true

require 'json'
require_relative 'contract'

module Lich
  module WebUI
    # Strict, server-routed WebUI wire envelopes.
    module Protocol
      MAX_MESSAGE_BYTES = 65_536
      TYPES = %w[attach detach event].freeze
      FIELDS = {
        'attach' => %i[type page version resume],
        'detach' => %i[type page generation],
        'event'  => %i[type page cid event generation payload submission],
      }.freeze
      REQUIRED = {
        'attach' => %i[type page version],
        'detach' => %i[type page generation],
        'event'  => %i[type page cid event generation],
      }.freeze

      class Refusal < Error
        attr_reader :reason

        def initialize(reason, message, **context)
          @reason = reason
          super(message, **context)
        end
      end

      module_function

      def hello(viewer_id:, pages:)
        JSON.generate(
          type: 'hello', contract_version: Contract::VERSION,
          viewer: viewer_id, pages: pages
        )
      end

      def render(address:, generation:, tree:, facilities: {}, bindings: {}, submissions: {}, resume: nil)
        payload = {
          type: 'render', page: address, generation: generation,
          tree: tree, facilities: facilities, bindings: bindings, submissions: submissions
        }
        payload[:resume] = resume if resume
        JSON.generate(payload)
      end

      def refusal(reason:, message:, page: nil, cid: nil)
        JSON.generate(type: 'refusal', reason: reason.to_s, message: message, page: page, cid: cid)
      end

      def page_closed(address:, reason:)
        JSON.generate(type: 'page_closed', page: address, reason: reason.to_s)
      end

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

        validate_common!(message)
        validate_type!(message)
        deep_freeze_containers(message)
      rescue JSON::ParserError => error
        raise Refusal.new(:malformed, "invalid JSON: #{error.class}")
      end

      def secure_compare(expected, actual)
        expected = expected.to_s
        actual = actual.to_s
        return false unless expected.bytesize == actual.bytesize

        result = 0
        expected.bytes.zip(actual.bytes) { |left, right| result |= left ^ right }
        result.zero?
      end

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
