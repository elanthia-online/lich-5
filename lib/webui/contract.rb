# frozen_string_literal: true

require_relative 'errors'

module Lich
  module WebUI
    # Machine-readable authority for SPEC-WEBUI-CONTRACT 2.5.0 SS10 and SS14.
    module Contract
      VERSION = '2.5.0'
      MAJOR_VERSION = 2

      TYPES = %i[
        page group stack columns grid tabs expander split overlay scroll divider
        text markdown log progress image
        button toggle checkbox radio text_input password_input textarea number_input slider select
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
        event_payload_bytes: 65_536,
      }.freeze

      module_function

      def scalar(kind, **constraints)
        { kind: kind, **constraints }
      end

      def string(bound = nil, **constraints)
        scalar(:string, **({ bound: bound }.compact), **constraints)
      end

      def integer(min: nil, max: nil, **constraints)
        scalar(:integer, **({ min: min, max: max }.compact), **constraints)
      end

      def number(min: nil, max: nil)
        scalar(:number, finite: true, **({ min: min, max: max }.compact))
      end

      def enum(*values)
        scalar(:enum, values: values.flatten.map(&:to_s))
      end

      def array(items, min: 0, max: nil)
        scalar(:array, items: items, min: min, **({ max: max }.compact))
      end

      def record(fields = nil, allow_extra: false, **field_keywords)
        raise ArgumentError, 'record fields supplied twice' if fields && !field_keywords.empty?

        scalar(:record, fields: fields || field_keywords, allow_extra: allow_extra)
      end

      def union(*variants)
        scalar(:union, variants: variants)
      end

      def property(shape, required: false, scope: :shared, default: :__none__)
        result = { shape: shape, required: required, scope: scope }
        result[:default] = default unless default == :__none__
        result
      end

      def event(payload = nil, terminal: false, lifecycle: false, structural: false)
        { payload: payload, terminal: terminal, lifecycle: lifecycle, structural: structural }
      end

      SHORT = string(:short_text).freeze
      BODY = string(:body_text).freeze
      IDENT = string(:identifier, pattern: IDENTIFIER).freeze
      CID = string(:body_text, pattern: CID_PATTERN).freeze
      BOOL = scalar(:boolean).freeze
      ANY_NUMBER = number.freeze
      GEOMETRY = integer(min: BOUNDS[:geometry].begin, max: BOUNDS[:geometry].end).freeze

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

      ATTRIBUTE_APPLICABILITY = {
        page: %i[key width height],
        group: %i[key tooltip hidden align margin width height tone],
        stack: %i[key hidden align margin width height],
        columns: %i[key hidden align margin width height],
        grid: %i[key hidden align margin width height],
        tabs: %i[key disabled hidden align margin width height],
        expander: %i[key tooltip disabled hidden align margin width height],
        split: %i[key hidden align margin width height],
        overlay: %i[key hidden align margin width height],
        scroll: %i[key hidden align margin width height],
        divider: %i[key hidden margin width tone],
        text: %i[key tooltip hidden align margin width emphasis tone],
        markdown: %i[key hidden align margin width],
        log: %i[key hidden align margin width height],
        progress: %i[key tooltip hidden align margin width tone],
        image: %i[key tooltip hidden align margin width height],
        button: %i[key tooltip disabled hidden align margin width emphasis tone],
        toggle: %i[key tooltip disabled hidden align margin width tone],
        checkbox: %i[key tooltip disabled hidden align margin width tone],
        radio: %i[key tooltip disabled hidden align margin width tone],
        text_input: %i[key tooltip disabled hidden align margin width tone sensitive],
        password_input: %i[key tooltip disabled hidden align margin width sensitive],
        textarea: %i[key tooltip disabled hidden align margin width height sensitive],
        number_input: %i[key tooltip disabled hidden align margin width tone sensitive],
        slider: %i[key tooltip disabled hidden align margin width tone],
        select: %i[key tooltip disabled hidden align margin width tone sensitive],
        table: %i[key disabled hidden align margin width height],
        dialog: %i[key width height tone],
        composite: %i[key tooltip hidden align margin width height],
      }.freeze

      ATTRIBUTE_SCHEMAS = {
        key: property(IDENT),
        tooltip: property(SHORT),
        disabled: property(BOOL),
        hidden: property(BOOL),
        align: property(enum(*ALIGNS)),
        margin: property(integer(min: 0, max: 512)),
        width: property(GEOMETRY),
        height: property(GEOMETRY),
        emphasis: property(enum(*EMPHASES)),
        tone: property(enum(*TONES)),
        sensitive: property(BOOL),
      }.freeze

      ACCESSIBILITY_SCHEMAS = {
        a11y_label: property(SHORT),
        a11y_description: property(BODY),
        a11y_role: property(IDENT),
      }.freeze

      BASE_SCHEMAS = {
        page: {
          properties: {
            title: property(SHORT, required: true), bare: property(BOOL, default: false),
            size: property(array(GEOMETRY, min: 2, max: 2)),
            position: property(array(GEOMETRY, min: 2, max: 2)),
          }, children: :many, events: {}, value: nil,
        },
        group: {
          properties: { label: property(SHORT, required: true), collapsible: property(BOOL, default: false) },
          children: :many, events: {}, value: nil,
        },
        stack: {
          properties: { gap: property(integer(min: 0, max: 64), default: 8) },
          children: :many, events: {}, value: nil,
        },
        columns: {
          properties: {
            count: property(integer(min: 1, max: 12), required: true),
            weights: property(array(integer(min: 0), max: 12)), compact: property(BOOL, default: false),
            gap: property(integer(min: 0, max: 64), default: 8),
          }, children: { kind: :named_dynamic, count_property: :count }, events: {}, value: nil,
        },
        grid: {
          properties: {
            cols: property(integer(min: 1, max: 24), required: true),
            cells: property(integer(min: 0, max: BOUNDS[:children])),
            gap: property(integer(min: 0, max: 64), default: 8),
          }, children: :many, child_properties: {
            span: property(integer(min: 1, max_property: :cols)),
            row_span: property(integer(min: 1, max: 24)),
          }, events: {}, value: nil,
        },
        tabs: {
          properties: {
            names: property(array(SHORT, min: 1, max: BOUNDS[:collection]), required: true),
            vertical: property(BOOL, default: false), selected: property(integer(min: 0), scope: :viewer),
          }, children: { kind: :named_from_property, property: :names },
          events: { select: event(record(index: property(integer(min: 0), required: true)), structural: true) }, value: nil,
        },
        expander: {
          properties: { label: property(SHORT, required: true), open: property(BOOL, default: false, scope: :viewer) },
          children: :many, events: { toggle: event(record(open: property(BOOL, required: true)), structural: true) }, value: nil,
        },
        split: {
          properties: {
            orientation: property(enum(:horizontal, :vertical), required: true),
            position: property(integer(min: 0, max: 100), scope: :viewer),
          }, children: { kind: :named, slots: %w[first second] },
          events: { move: event(record(position: property(integer(min: 0, max: 100), required: true))) }, value: nil,
        },
        overlay: {
          properties: {}, children: :many,
          child_properties: { z: property(integer(min: 0, max: 99)) }, events: {}, value: nil,
        },
        scroll: {
          properties: { max_height: property(GEOMETRY), scroll_to: property(IDENT, scope: :viewer) },
          children: :many, events: { scrolled: event(record(position: property(GEOMETRY, required: true))) }, value: nil,
        },
        divider: { properties: { label: property(SHORT) }, children: :none, events: {}, value: nil },
        text: {
          properties: { content: property(BODY, required: true), wrap: property(BOOL, default: true) },
          children: :none, events: {}, value: nil,
        },
        markdown: {
          properties: { content: property(string(:rich_text), required: true) }, children: :none, events: {}, value: nil,
        },
        log: {
          properties: {
            lines: property(array(string(:log_line), max: BOUNDS[:log_lines]), required: true),
            max_lines: property(integer(min: 1, max: BOUNDS[:log_lines]), required: true),
            follow: property(BOOL, default: true),
          }, children: :none, events: {}, value: nil,
        },
        progress: {
          properties: {
            value: property(number(min: 0.0, max: 1.0)), label: property(SHORT),
            indeterminate: property(BOOL, default: false),
          }, children: :none, events: {}, value: nil,
        },
        image: {
          properties: {
            src: property(string(:body_text), required: true), alt: property(SHORT),
            scale: property(number(min: 0.1, max: 8.0), default: 1.0),
          }, children: :none, events: {}, value: nil,
        },
        button: {
          properties: {
            label: property(SHORT, required: true),
            variant: property(enum(:default, :primary, :danger), default: 'default'), confirm: property(SHORT),
          }, children: :none, events: { activate: event(nil, terminal: true) }, value: nil,
        },
        toggle: {
          properties: { label: property(SHORT), checked: property(BOOL, required: true, scope: :viewer) },
          children: :none, events: { change: event(record(value: property(BOOL, required: true))) }, value: BOOL,
        },
        checkbox: {
          properties: { label: property(SHORT, required: true), checked: property(BOOL, required: true, scope: :viewer) },
          children: :none, events: { change: event(record(value: property(BOOL, required: true))) }, value: BOOL,
        },
        radio: {
          properties: {
            label: property(SHORT, required: true), group: property(IDENT, required: true),
            options: property(OPTIONS, required: true), selected: property(string(:input_text), scope: :viewer),
          }, children: :none,
          events: { change: event(record(value: property(string(:input_text), required: true))) },
          value: string(:input_text), value_scope: :viewer,
        },
        text_input: {
          properties: {
            label: property(SHORT), value: property(string(:input_text), required: true, scope: :viewer),
            placeholder: property(SHORT), max_length: property(integer(min: 1, max: 8192)),
            search: property(BOOL, default: false),
          }, children: :none,
          events: {
            change: event(record(value: property(string(:input_text), required: true))),
            submit: event(nil, terminal: true),
          }, value: string(:input_text), value_scope: :viewer,
        },
        password_input: {
          properties: {
            label: property(SHORT), placeholder: property(SHORT),
            max_length: property(integer(min: 1, max: 8192)),
            revealable: property(BOOL, default: false, scope: :ephemeral_client),
          }, children: :none, events: { submit: event(nil, terminal: true) },
          value: string(:input_text), value_scope: :sensitive_write_only, sensitive: true,
        },
        textarea: {
          properties: {
            label: property(SHORT), value: property(string(:multiline_text), required: true, scope: :viewer),
            rows: property(integer(min: 1, max: 64), default: 5),
            max_length: property(integer(min: 1, max: 65_536)),
          }, children: :none,
          events: { change: event(record(value: property(string(:multiline_text), required: true))) },
          value: string(:multiline_text), value_scope: :viewer,
        },
        number_input: {
          properties: {
            label: property(SHORT), value: property(ANY_NUMBER, required: true, scope: :viewer),
            min: property(ANY_NUMBER, required: true), max: property(ANY_NUMBER, required: true),
            step: property(ANY_NUMBER, default: 1),
          }, children: :none,
          events: { change: event(record(value: property(ANY_NUMBER, required: true))) },
          value: ANY_NUMBER, value_scope: :viewer,
        },
        slider: {
          properties: {
            label: property(SHORT), value: property(ANY_NUMBER, required: true, scope: :viewer),
            min: property(ANY_NUMBER, required: true), max: property(ANY_NUMBER, required: true),
            step: property(ANY_NUMBER, default: 1),
          }, children: :none,
          events: { change: event(record(value: property(ANY_NUMBER, required: true))) },
          value: ANY_NUMBER, value_scope: :viewer,
        },
        select: {
          properties: {
            label: property(SHORT), options: property(OPTIONS, required: true),
            value: property(string(:input_text), scope: :viewer),
          }, children: :none,
          events: { change: event(record(value: property(string(:input_text), required: true))) },
          value: string(:input_text), value_scope: :viewer,
        },
        table: { properties: {}, children: :none, events: {}, value: nil, special: :table },
        dialog: {
          properties: {
            title: property(SHORT, required: true), body: property(BODY),
            buttons: property(array(BUTTON_DEF, min: 1, max: BOUNDS[:collection]), required: true),
            no_viewer: property(enum(:wait, :default, :abort), required: true),
            default_button: property(IDENT), timeout: property(integer(min: 1, max: 86_400)),
          }, children: :many,
          events: { response: event(record(button: property(IDENT, required: true)), terminal: true) }, value: nil,
        },
        composite: { properties: {}, children: :none, events: {}, value: nil, special: :composite },
      }.freeze

      TABLE_COLUMN = record(
        key: property(IDENT, required: true), label: property(SHORT, required: true),
        align: property(enum(:start, :center, :end), default: 'start'), width: property(GEOMETRY),
        sortable: property(BOOL, default: false), editor: property(scalar(:editor), default: nil)
      ).freeze
      TABLE_ROW = record(
        key: property(IDENT, required: true), parent: property(IDENT),
        expanded: property(BOOL, default: false, scope: :viewer),
        cells: property(scalar(:cell_map), required: true)
      ).freeze

      TABLE_PROPERTIES = {
        columns: property(array(TABLE_COLUMN, min: 1, max: BOUNDS[:table_columns]), required: true),
        rows: property(array(TABLE_ROW, max: BOUNDS[:table_rows]), required: true),
        selection: property(enum(:none, :single, :multi), default: 'none'),
        selected: property(array(IDENT, max: BOUNDS[:table_rows]), scope: :viewer),
        sortable: property(BOOL, default: false),
        sort: property(record(
                         column: property(IDENT, required: true), direction: property(enum(:asc, :desc), required: true)
                       ), scope: :viewer),
        max_height: property(GEOMETRY),
      }.freeze

      TABLE_EVENTS = {
        row_activate: event(record(row: property(IDENT, required: true)), terminal: true),
        selection_change: event(record(rows: property(array(IDENT, max: BOUNDS[:table_rows]), required: true)), structural: true),
        cell_edit: event(record(
                           row: property(IDENT, required: true), column: property(IDENT, required: true),
                           value: property(scalar(:editor_value), required: true)
                         )),
        row_toggle: event(record(
                            row: property(IDENT, required: true), expanded: property(BOOL, required: true)
                          ), structural: true),
        sort_change: event(record(
                             column: property(IDENT, required: true), direction: property(enum(:asc, :desc), required: true)
                           )),
      }.freeze

      RGBA = record(
        r: property(integer(min: 0, max: 255), required: true),
        g: property(integer(min: 0, max: 255), required: true),
        b: property(integer(min: 0, max: 255), required: true),
        a: property(number(min: 0.0, max: 1.0), required: true)
      ).freeze
      TINT = union(record(tone: property(enum(*TONES), required: true)), RGBA).freeze
      POINT_FIELDS = {
        x: property(GEOMETRY, required: true), y: property(GEOMETRY, required: true),
      }.freeze
      COMPOSITE_LAYER = union(
        record({
          kind: property(enum(:image), required: true), src: property(string(:body_text), required: true),
          **POINT_FIELDS, w: property(GEOMETRY), h: property(GEOMETRY),
          opacity: property(number(min: 0.0, max: 1.0), default: 1.0),
          tint: property(TINT), mask: property(string(:body_text)),
        }),
        record({
          kind: property(enum(:bar), required: true), **POINT_FIELDS,
          w: property(GEOMETRY, required: true), h: property(GEOMETRY, required: true),
          value: property(number(min: 0.0, max: 1.0), required: true),
          tone: property(union(enum(*TONES), RGBA), default: 'neutral'),
          orientation: property(enum(:horizontal, :vertical), default: 'horizontal'),
        }),
        record({
          kind: property(enum(:label), required: true), **POINT_FIELDS,
          text: property(SHORT, required: true), emphasis: property(enum(*EMPHASES), default: 'normal'),
          tone: property(enum(*TONES), default: 'neutral'),
          align: property(enum(:start, :center, :end), default: 'start'),
        }),
        record(
          kind: property(enum(:region), required: true), key: property(IDENT, required: true),
          x1: property(GEOMETRY, required: true), y1: property(GEOMETRY, required: true),
          x2: property(GEOMETRY, required: true), y2: property(GEOMETRY, required: true),
          label: property(SHORT), activates: property(BOOL, default: false)
        )
      ).freeze

      COMPOSITE_PROPERTIES = {
        width: property(GEOMETRY, required: true), height: property(GEOMETRY, required: true),
        scale: property(number(min: 0.1, max: 8.0), default: 1.0),
        scroll_to: property(IDENT, scope: :viewer),
        popup: property(record(
                          page: property(IDENT, required: true), size: property(array(GEOMETRY, min: 2, max: 2))
                        )),
        surface_events: property(BOOL, default: false),
        layers: property(array(COMPOSITE_LAYER, max: BOUNDS[:collection]), required: true),
      }.freeze

      COMPOSITE_EVENTS = {
        region_activate: event(record(region: property(IDENT, required: true)), terminal: true),
        surface_activate: event(record(
                                  x: property(GEOMETRY, required: true), y: property(GEOMETRY, required: true),
                                  button: property(enum(:primary, :secondary), required: true),
                                  modifiers: property(array(enum(:ctrl, :shift, :alt), max: 3), required: true),
                                  region: property(IDENT)
                                ), terminal: true),
      }.freeze

      FACILITIES = {
        accelerators: {
          shape: array(record(
                         keys: property(SHORT, required: true), target: property(CID, required: true),
                         event: property(IDENT, required: true)
                       ), max: BOUNDS[:collection]), scope: :shared,
        },
        geometry: {
          shape: record(
            width: property(GEOMETRY), height: property(GEOMETRY),
            x: property(GEOMETRY), y: property(GEOMETRY)
          ), scope: :viewer,
        },
        notify: {
          shape: record(
            text: property(BODY, required: true), level: property(enum(:info, :warn, :error), required: true)
          ), scope: :transient,
        },
        focus: { shape: CID, scope: :viewer },
        announce: {
          shape: record(
            text: property(BODY, required: true),
            politeness: property(enum(:polite, :assertive), required: true)
          ), scope: :viewer,
        },
        presentation: {
          shape: record(
            always_on_top: property(BOOL), borderless: property(BOOL),
            opacity: property(number(min: 0.1, max: 1.0)), scrollbars: property(BOOL)
          ), scope: :viewer,
        },
      }.freeze

      PAGE_LIFECYCLE_EVENTS = {
        close: event(record(reason: property(enum(:user, :owner, :timeout), required: true)), terminal: true, lifecycle: true),
        attach: event(nil, lifecycle: true),
        detach: event(nil, lifecycle: true),
      }.freeze

      def schemas
        @schemas ||= begin
          schemas = {}
          TYPES.each do |type|
            base = deep_dup(BASE_SCHEMAS.fetch(type))
            base[:events].merge!(deep_dup(PAGE_LIFECYCLE_EVENTS)) if type == :page
            base[:properties].merge!(TABLE_PROPERTIES) if type == :table
            base[:events].merge!(TABLE_EVENTS) if type == :table
            ATTRIBUTE_APPLICABILITY.fetch(type).each do |attribute|
              next if base[:properties].key?(attribute)

              base[:properties][attribute] = deep_dup(ATTRIBUTE_SCHEMAS.fetch(attribute))
            end
            base[:properties].merge!(COMPOSITE_PROPERTIES) if type == :composite
            base[:events].merge!(COMPOSITE_EVENTS) if type == :composite
            base[:properties].merge!(deep_dup(ACCESSIBILITY_SCHEMAS))
            if type == :password_input
              base[:properties][:sensitive][:forced] = true
              base[:properties][:sensitive][:default] = true
            end
            schemas[type] = base
          end
          deep_freeze(schemas)
        end
      end

      def schema(type)
        normalized = normalize_type(type)
        schemas.fetch(normalized)
      rescue KeyError
        raise UnknownTypeError, "unknown component type #{type.inspect}"
      end

      def normalize_type(type)
        return type if type.is_a?(Symbol)
        return type.to_sym if type.is_a?(String) && type.match?(IDENTIFIER)

        type
      end

      def negotiate!(client_version)
        version = client_version.to_s
        major = Integer(version.split('.').first, exception: false)
        raise VersionError, "invalid contract version #{client_version.inspect}" unless major
        raise VersionError, "unsupported contract major #{major}; server requires #{MAJOR_VERSION}" unless major == MAJOR_VERSION

        VERSION
      end

      def deep_freeze(value)
        case value
        when Hash
          value.each { |key, child| deep_freeze(key); deep_freeze(child) }
        when Array
          value.each { |child| deep_freeze(child) }
        end
        value.freeze
      end

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
