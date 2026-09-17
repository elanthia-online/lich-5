# frozen_string_literal: true

module Lich
  module WebUI
    # Base class for attributed WebUI contract failures.
    #
    # Every subclass carries the same attribution -- which owner, page,
    # component and field the failure concerns -- appended to the message so a
    # log line names the culprit without the reader having to reconstruct it.
    class Error < StandardError
      # @!attribute [r] owner
      #   @return [Object, nil] the owner label the failure was attributed to
      # @!attribute [r] page_id
      #   @return [String, nil] the page id the failure was attributed to
      # @!attribute [r] cid
      #   @return [String, nil] the component identity the failure was attributed to
      # @!attribute [r] field
      #   @return [Symbol, String, nil] the property or field the failure was attributed to
      attr_reader :owner, :page_id, :cid, :field

      # Builds an error whose message carries the given attribution.
      #
      # @param message [String] what went wrong
      # @param owner [Object, nil] owner label
      # @param page_id [String, nil] page id
      # @param cid [String, nil] component identity
      # @param field [Symbol, String, nil] property or field name
      # @return [Error] the error
      def initialize(message, owner: nil, page_id: nil, cid: nil, field: nil)
        @owner = owner
        @page_id = page_id
        @cid = cid
        @field = field
        attribution = [
          ("owner=#{owner}" if owner),
          ("page=#{page_id}" if page_id),
          ("cid=#{cid}" if cid),
          ("field=#{field}" if field),
        ].compact.join(' ')
        super(attribution.empty? ? message : "#{message} (#{attribution})")
      end
    end

    # An owner registered a second page with an id it already uses.
    class DuplicatePageError < Error; end
    # A component type the contract does not define.
    class UnknownTypeError < Error; end
    # A property the component's schema does not define.
    class UnknownPropertyError < Error; end
    # An event the component or page does not emit.
    class UnknownEventError < Error; end
    # A value, child, or bound outside what the schema allows.
    class SchemaViolationError < Error; end
    # A component identity that collides or is missing where a key is required.
    class IdentityError < Error; end
    # A client contract version the server cannot serve.
    class VersionError < Error; end
    # A viewer-scoped read or write with more than one viewer attached and none named.
    class AmbiguousViewerError < Error; end
    # A read of a write-only sensitive property.
    class SensitiveReadError < Error; end
    # A second consume of a {SensitiveValue} already consumed.
    class ConsumedSensitiveValueError < Error; end
  end
end
