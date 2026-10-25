# frozen_string_literal: true

module Lich
  module WebUI
    module Contract
      module_function

      # Describes a scalar kind and its validator constraints.
      # @return [Hash] shape definition
      def scalar(kind, **constraints)
        { kind: kind, **constraints }
      end

      # Describes a string, optionally using a named contract length bound.
      # @return [Hash] shape definition
      def string(bound = nil, **constraints)
        scalar(:string, **({ bound: bound }.compact), **constraints)
      end

      # Describes an integer with optional inclusive limits.
      # @return [Hash] shape definition
      def integer(min: nil, max: nil, **constraints)
        scalar(:integer, **({ min: min, max: max }.compact), **constraints)
      end

      # Describes a finite number with optional inclusive limits.
      # @return [Hash] shape definition
      def number(min: nil, max: nil)
        scalar(:number, finite: true, **({ min: min, max: max }.compact))
      end

      # Describes a closed set of string values, accepting nested value lists.
      # @return [Hash] shape definition
      def enum(*values)
        scalar(:enum, values: values.flatten.map(&:to_s))
      end

      # Describes an ordered collection with cardinality and item constraints.
      # @return [Hash] shape definition
      def array(items, min: 0, max: nil)
        scalar(:array, items: items, min: min, **({ max: max }.compact))
      end

      # Describes named fields; unknown fields are refused unless explicitly allowed.
      # Supply fields as either a positional hash or keywords, never both.
      # @return [Hash] shape definition
      # @raise [ArgumentError] if fields are supplied twice
      def record(fields = nil, allow_extra: false, **field_keywords)
        raise ArgumentError, 'record fields supplied twice' if fields && !field_keywords.empty?

        scalar(:record, fields: fields || field_keywords, allow_extra: allow_extra)
      end

      # Describes alternatives accepted when any one shape validates.
      # @return [Hash] shape definition
      def union(*variants)
        scalar(:union, variants: variants)
      end

      # Describes property ownership, requiredness, and an optional default.
      # The sentinel distinguishes no default from an explicit nil default.
      # @return [Hash] property definition
      def property(shape, required: false, scope: :shared, default: :__none__)
        result = { shape: shape, required: required, scope: scope }
        result[:default] = default unless default == :__none__
        result
      end

      # Describes an event payload and its dispatch/lifecycle classification.
      # @return [Hash] event definition
      def event(payload = nil, terminal: false, lifecycle: false, structural: false, ordered: false)
        { payload: payload, terminal: terminal, lifecycle: lifecycle, structural: structural, ordered: ordered }
      end

      SHORT = string(:short_text).freeze
      BODY = string(:body_text).freeze
      IDENT = string(:identifier, pattern: IDENTIFIER).freeze
      CID = string(:body_text, pattern: CID_PATTERN).freeze
      BOOL = scalar(:boolean).freeze
      ANY_NUMBER = number.freeze
      GEOMETRY = integer(min: BOUNDS[:geometry].begin, max: BOUNDS[:geometry].end).freeze
      SCROLL_PIXELS = integer(min: 0, max: BOUNDS[:geometry].end).freeze

      # One shape for declarative facilities and imperative shim window state.
      PRESENTATION = record(
        always_on_top: property(BOOL), borderless: property(BOOL), hidden: property(BOOL), minimized: property(BOOL),
        minimized_revision: property(integer(min: 1, max: 2_147_483_647)),
        opacity: property(number(min: 0.1, max: 1.0)), scrollbars: property(BOOL)
      ).freeze

      OPTION = record(
        value: property(string(:input_text), required: true),
        label: property(SHORT, required: true)
      ).freeze
      OPTIONS = array(OPTION, max: BOUNDS[:collection]).freeze

      BUTTON_DEF = record(
        id: property(IDENT, required: true),
        label: property(SHORT, required: true),
        variant: property(enum(:default, :primary, :danger), default: 'default')
      ).freeze

      RGBA = record(
        r: property(integer(min: 0, max: 255), required: true),
        g: property(integer(min: 0, max: 255), required: true),
        b: property(integer(min: 0, max: 255), required: true),
        a: property(number(min: 0.0, max: 1.0), required: true)
      ).freeze
    end
  end
end
