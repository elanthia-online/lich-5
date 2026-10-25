# frozen_string_literal: true

require_relative 'errors'
require_relative '../util/deep_freeze'

module Lich
  module WebUI
    # Machine-readable authority for the shared host/browser component contract.
    module Contract
      VERSION = '2.51.0'
      MAJOR_VERSION = 2

      # Serialized UTF-8 JSON budgets. A maximum-length field can require six
      # bytes per character when escaped; the envelope has separate headroom.
      WIRE_LIMITS = { message_bytes: 2_097_152, event_payload_bytes: 524_288, submission_bytes: 1_048_576 }.freeze

      TYPES = %i[
        page group stack columns grid tabs expander split overlay scroll divider
        text markdown log progress image
        button toggle checkbox radio radio_option text_input password_input textarea number_input slider select
        table dialog composite
      ].freeze

      STRUCTURE_TYPES = TYPES.first(11).freeze
      DISPLAY_TYPES = TYPES.slice(11, 5).freeze
      INPUT_TYPES = TYPES.slice(16, 10).freeze

      TONES = %w[neutral positive caution danger].freeze
      EMPHASES = %w[normal strong subtle].freeze
      ALIGNS = %w[start center end stretch].freeze
      IDENTIFIER = /\A[A-Za-z0-9_.:-]{1,128}\z/
      CID_PATTERN = /\A[A-Za-z0-9_.:-]+(?:\/[A-Za-z0-9_.:-]+)*\z/

      BOUNDS = {
        identifier: 128,
        short_text: 512,
        body_text: 8192,
        display_text: 65_536,
        rich_text: 65_536,
        input_text: 8192,
        multiline_text: 65_536,
        log_line: 4096,
        log_lines: 10_000,
        collection: 512,
        table_rows: 10_000,
        table_columns: 64,
        children: 1024,
        components: 20_000,
        tree_depth: 64,
        geometry: (-65_536..65_536),
        timeout: (1..86_400),
        event_payload_bytes: WIRE_LIMITS[:event_payload_bytes],
      }.freeze

      require_relative 'contract/shapes'
      require_relative 'contract/attributes'
      require_relative 'contract/components/structure'
      require_relative 'contract/components/display'
      require_relative 'contract/components/inputs'

      BASE_SCHEMAS = {
        **structure_schemas,
        **display_schemas,
        **inputs_schemas,
        table: { properties: {}, children: :none, events: {}, value: nil, special: :table },
        dialog: {
          properties: {
            title: property(SHORT, required: true), show_title: property(BOOL, default: true), body: property(BODY),
            buttons: property(array(BUTTON_DEF, min: 1, max: BOUNDS[:collection]), required: true),
            no_viewer: property(enum(:wait, :default, :abort), required: true),
            cancel_button: property(IDENT), default_button: property(IDENT), timeout: property(integer(min: 1, max: 86_400)),
          }, children: :many,
          events: { response: event(record(button: property(IDENT, required: true)), terminal: true) }, value: nil,
        },
        composite: { properties: {}, children: :none, events: {}, value: nil, special: :composite },
      }.freeze

      require_relative 'contract/table'
      require_relative 'contract/composite'
      require_relative 'contract/facilities'
      require_relative 'contract/schema_assembly'

      module_function

      # Retains a visible selected page, otherwise selects the first visible page.
      # All-hidden notebooks keep a bounded index while displaying no page.
      def visible_tab_index(headers, index)
        return index unless headers&.dig(index, :hidden)

        headers.index { |header| !header[:hidden] } || 0
      end

      # Preserves stable tab identity before falling back to a bounded visible index.
      # Callers retain their own missing-index defaults and selection state.
      # @param previous_headers [Array<Hash>, nil] previously authored/delivered headers
      # @param headers [Array<Hash>] replacement headers
      # @param index [Integer] caller-defaulted previous selection
      # @param page_count [Integer] number of replacement named pages
      # @return [Integer] remapped selection, including zero for an empty/all-hidden set
      def remap_tab_index(previous_headers, headers, index, page_count)
        old_key = previous_headers&.dig(index, :key)
        found = headers.index { |header| header[:key] == old_key } if old_key
        visible_tab_index(headers, found || index.clamp(0, [page_count - 1, 0].max))
      end

      # Derives the named slots declared by a parent's validated child rule.
      # Capacity admission and imperative numbering outside that capacity stay in callers.
      # @param rule [Hash, Symbol] schema child declaration
      # @param props [Hash] validated parent properties
      # @return [Array<String>] declared slots, or an empty list for unnamed children
      def child_slots(rule, props)
        return [] unless rule.is_a?(Hash)

        case rule.fetch(:kind)
        when :named then rule.fetch(:slots)
        when :named_dynamic then Array.new(props.fetch(rule.fetch(:count_property))) { |index| index.to_s }
        when :named_from_property then props.fetch(rule.fetch(:property)).map(&:to_s)
        else []
        end
      end

      # Resolves a parent-relative placement bound without mutating its schema.
      # @param shape [Hash] declared placement shape
      # @param parent_props [Hash] validated parent properties
      # @return [Hash] copied shape with any parent-provided maximum resolved
      def child_placement_shape(shape, parent_props)
        resolved = shape.dup
        resolved[:max] = parent_props.fetch(resolved.delete(:max_property)) if resolved[:max_property]
        resolved
      end

      # Identifies the common relational placement refusal after shape validation.
      # Error attribution/order and additional caller-specific checks remain in callers.
      # @param type [Symbol] normalized parent component type
      # @param props [Hash] validated parent properties
      # @param placement [Hash] shape-validated child placement
      # @return [Symbol, nil] :grid_row_overflow, :unpositioned_coordinates, or nil
      def child_placement_condition(type, props, placement)
        if type == :grid && placement.fetch(:row, 1) + placement.fetch(:row_span, 1) - 1 > BOUNDS[:children]
          return :grid_row_overflow
        end
        if type == :overlay && !props[:positioned] && (placement.keys & %i[x y]).any?
          return :unpositioned_coordinates
        end
        nil
      end

      # Looks up a supported type after identifier normalization.
      # @return [Hash] frozen schema
      # @raise [UnknownTypeError] if the type is outside the contract
      def schema(type)
        normalized = normalize_type(type)
        schemas.fetch(normalized)
      rescue KeyError
        raise UnknownTypeError, "unknown component type #{type.inspect}"
      end

      # Converts identifier-shaped strings to symbols; leaves other inputs for rejection.
      # @return [Object] normalized candidate type
      def normalize_type(type)
        return type if type.is_a?(Symbol)
        return type.to_sym if type.is_a?(String) && type.match?(IDENTIFIER)

        type
      end

      # Preserve a literal string while dividing it across bounded wire fields.
      # The receiver still owns the collection bound and presentation policy.
      def fragment_text(value, bound:)
        limit = BOUNDS.fetch(bound)
        value.length <= limit ? value : value.scan(/.{1,#{limit}}/m)
      end

      # Accepts the current major protocol version and returns the server version.
      # Minor version differences do not prevent attachment.
      # @return [String] server contract version
      # @raise [VersionError] for malformed or incompatible major versions
      def negotiate!(client_version)
        version = client_version.to_s
        major = Integer(version.split('.').first, exception: false)
        raise VersionError, "invalid contract version #{client_version.inspect}" unless major
        raise VersionError, "unsupported contract major #{major}; server requires #{MAJOR_VERSION}" unless major == MAJOR_VERSION

        VERSION
      end

      # Recursively freezes schema hashes, arrays, keys, and leaf values.
      # @return [Object] the supplied object
      def deep_freeze(value)
        Lich::Util.deep_freeze(value)
      end

      # Copies hash/array containers recursively, retaining scalar objects.
      # This is a schema composition helper, not a general mutable deep copy.
      # @return [Object] copied container or original scalar
      def deep_dup(value)
        case value
        when Hash
          value.to_h { |key, child| [key, deep_dup(child)] }
        when Array
          value.map { |child| deep_dup(child) }
        else
          value
        end
      end
    end
  end
end
