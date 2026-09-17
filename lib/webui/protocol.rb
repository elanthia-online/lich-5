# frozen_string_literal: true

require 'json'
require_relative 'contract'

module Lich
  module WebUI
    # Strict, server-routed WebUI wire envelopes.
    #
    # Builds every message the server sends (`hello`, `render`, `refusal`,
    # `page_closed`) and parses the three a client may send (`attach`,
    # `detach`, `event`), refusing anything oversized, malformed, or carrying
    # a field the server routes itself.
    module Protocol
      # Largest client message accepted, in bytes.
      MAX_MESSAGE_BYTES = 65_536
      # The message types a client may send.
      TYPES = %w[attach detach event].freeze
      # Every field each client message type may carry.
      FIELDS = {
        'attach' => %i[type page version resume],
        'detach' => %i[type page generation],
        # `request` is the client's own id for the send; a refusal echoes it
        # so the client replays exactly the record it names (two sends from
        # one button are two records). Optional: an older client omits it.
        'event'  => %i[type page cid event generation payload submission request],
      }.freeze
      # The fields each client message type must carry.
      REQUIRED = {
        'attach' => %i[type page version],
        'detach' => %i[type page generation],
        'event'  => %i[type page cid event generation],
      }.freeze

      # A client message the server will not act on, with a machine-readable reason.
      class Refusal < Error
        # @return [Symbol] `:frame_size`, `:malformed`, `:routing_field`, `:version`, or a runtime reason
        attr_reader :reason

        # Builds a refusal.
        #
        # @param reason [Symbol] the machine-readable reason
        # @param message [String] the human-readable explanation
        # @param context [Hash{Symbol => Object}] attribution, as {Error#initialize} takes it
        # @return [Refusal] the refusal
        def initialize(reason, message, **context)
          @reason = reason
          super(message, **context)
        end
      end

      module_function

      # The first message on a connection: the viewer's id and the pages it may open.
      #
      # @param viewer_id [String] the connection's viewer id
      # @param pages [Array<Hash>] page descriptors, as {Registry#descriptors} gives them
      # @return [String] the JSON envelope
      def hello(viewer_id:, pages:)
        JSON.generate(
          type: 'hello', contract_version: Contract::VERSION,
          viewer: viewer_id, pages: pages
        )
      end

      # A rendered page for one viewer.
      #
      # @param address [String] the page's wire address
      # @param generation [Integer] the render generation
      # @param tree [Hash] the serialized component tree
      # @param facilities [Hash] page facilities
      # @param bindings [Hash] which events the server listens for
      # @param submissions [Hash] which inputs each terminal submits
      # @param resume [String, nil] a resume token, sent on first attach
      # @return [String] the JSON envelope
      def render(address:, generation:, tree:, facilities: {}, bindings: {}, submissions: {}, resume: nil)
        payload = {
          type: 'render', page: address, generation: generation,
          tree: tree, facilities: facilities, bindings: bindings, submissions: submissions
        }
        payload[:resume] = resume if resume
        JSON.generate(payload)
      end

      # Tells the client a message was refused and why.
      #
      # `event` names the event refused, so the client can find the record it
      # kept for that exact send -- a refusal for A must never replay B.
      #
      # @param reason [Symbol, String] the machine-readable reason
      # @param message [String] the human-readable explanation
      # @param page [String, nil] the page address the refused message named
      # @param cid [String, nil] the component the refused message named
      # @param event [String, nil] the event the refused message named
      # @param request [Integer, nil] the client's own id for the refused send
      # @return [String] the JSON envelope
      def refusal(reason:, message:, page: nil, cid: nil, event: nil, request: nil)
        body = { type: 'refusal', reason: reason.to_s, message: message, page: page, cid: cid, event: event }
        body[:request] = request if request
        JSON.generate(body)
      end

      # Tells the client a page it had open is gone.
      #
      # @param address [String] the page's wire address
      # @param reason [Symbol, String] why it closed
      # @return [String] the JSON envelope
      def page_closed(address:, reason:)
        JSON.generate(type: 'page_closed', page: address, reason: reason.to_s)
      end

      # Parses and validates a raw client message.
      #
      # @param raw [String] the text frame payload
      # @return [Hash{Symbol => Object}] the message, symbol-keyed, with every container frozen
      # @raise [Refusal] when the message is too large, not JSON, not an object, of a type the client may
      #   not send, carrying a forbidden or malformed field, missing a required one, or from an
      #   incompatible contract version
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

      # Compares two strings in time independent of where they differ.
      #
      # @param expected [String, #to_s] the secret
      # @param actual [String, #to_s] the candidate
      # @return [Boolean] whether they are byte-for-byte equal
      def secure_compare(expected, actual)
        expected = expected.to_s
        actual = actual.to_s
        return false unless expected.bytesize == actual.bytesize

        result = 0
        expected.bytes.zip(actual.bytes) { |left, right| result |= left ^ right }
        result.zero?
      end

      # Checks the page address and, except on attach, the generation.
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

      # Checks the fields particular to attach and event messages.
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
          if message.key?(:request) && !(message[:request].is_a?(Integer) && message[:request].positive?)
            raise Refusal.new(:malformed, 'request must be a positive integer')
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

      # Freezes every Hash and Array in the parsed message, and every Hash key.
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
