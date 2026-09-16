# frozen_string_literal: true

module Lich
  module WebUI
    # Base class for attributed WebUI contract failures.
    class Error < StandardError
      attr_reader :owner, :page_id, :cid, :field

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

    class DuplicatePageError < Error; end
    class UnknownTypeError < Error; end
    class UnknownPropertyError < Error; end
    class UnknownEventError < Error; end
    class SchemaViolationError < Error; end
    class IdentityError < Error; end
    class VersionError < Error; end
    class AmbiguousViewerError < Error; end
    class SensitiveReadError < Error; end
    class ConsumedSensitiveValueError < Error; end
  end
end
