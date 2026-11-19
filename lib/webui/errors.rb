# frozen_string_literal: true

module Lich
  module WebUI
    # Script failures contained per callback, matching the script runner's set.
    # SystemExit is handled apart (it stops the owner, never Lich) and fatal VM
    # exceptions outside this set keep propagating.
    CONTAINED_EXCEPTIONS = [ScriptError, NoMemoryError, SecurityError, SystemStackError, StandardError].freeze

    # Diagnostic formatting and sink isolation; labels never establish ownership.
    module Diagnostics
      # Preserves explicit owner IDs and truthy names, including an empty name.
      # @param owner [Object] lifecycle owner used only for diagnostic attribution
      # @return [Object] explicit ID/name, or class and object ID fallback
      def self.owner_label(owner)
        return owner.webui_owner_id if owner.respond_to?(:webui_owner_id)
        return owner.name if owner.respond_to?(:name) && owner.name

        "#{owner.class}:#{owner.object_id}"
      end

      # Characters of a label kept by display_label.
      DISPLAY_LABEL_CHARACTERS = 80

      # Renders a label for inspection text and log lines: one line of printable
      # ASCII, at most DISPLAY_LABEL_CHARACTERS long. Whitespace and control runs
      # collapse to a space and any other character becomes "?". For display
      # only; lookups keep using the owner identity itself.
      # @param label [Object] owner label or other diagnostic identity
      # @return [String] bounded single-line text
      def self.display_label(label)
        label.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: '?')
             .gsub(/[\x00-\x20\x7F]+/, ' ').gsub(/[^\x20-\x7E]/, '?').strip[0, DISPLAY_LABEL_CHARACTERS]
      end

      # Advances one once-per-interval log window. The caller keeps the returned
      # state under its own lock and logs only when a report count is returned.
      # @param logged_at [Float, nil] monotonic time of the window's last logged line
      # @param suppressed [Integer] occurrences counted since that line
      # @param now [Float] current monotonic time
      # @param interval [Numeric] seconds one logged line covers
      # @return [Array] new logged_at, new suppressed count, and the suppressed
      #   count to report now, or nil when this occurrence is suppressed
      def self.log_window(logged_at, suppressed, now:, interval:)
        return [logged_at, suppressed + 1, nil] if logged_at && now - logged_at < interval

        [now, 0, suppressed]
      end

      # Keeps ordinary diagnostic-sink failures out of runtime control flow.
      # @param logger [#call] sink accepting level and message
      # @param level [Symbol] diagnostic severity
      # @param message [String] already formatted diagnostic text
      # @return [Object, nil] sink result, or nil after a StandardError
      def self.log(logger, level, message)
        logger.call(level, message)
      rescue StandardError
        nil
      end
    end

    # Base class for attributed WebUI contract failures.
    class Error < StandardError
      attr_reader :owner, :page_id, :cid, :field

      # Adds available owner, page, component, and field attribution to an error.
      # Context is diagnostic information, not authority supplied by a viewer.
      # @param message [String] failure description
      # @param owner [Object, nil] diagnostic owner label
      # @param page_id [String, nil] affected page
      # @param cid [String, nil] affected component
      # @param field [Object, nil] affected property or event field
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
