# frozen_string_literal: true

require_relative 'errors'

module Lich
  module WebUI
    # Machine-readable authority for SPEC-WEBUI-CONTRACT 2.5.0 SS10 and SS14.
    module Contract
      VERSION = '2.15.1'
      MAJOR_VERSION = 2

      TYPES = %i[
        page group stack columns grid tabs expander split overlay scroll divider
        text markdown log progress image
        button toggle checkbox radio text_input password_input textarea number_input slider select
        table dialog composite
        menu menu_item
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
        page: %i[key width height key_events],
        group: %i[key tooltip hidden align margin width height tone context_menu],
        stack: %i[key hidden align margin width height context_menu],
        columns: %i[key hidden align margin width height context_menu],
        grid: %i[key hidden align margin width height context_menu],
        tabs: %i[key disabled hidden align margin width height],
        expander: %i[key tooltip disabled hidden align margin width height context_menu],
        split: %i[key hidden align margin width height],
        overlay: %i[key hidden align margin width height context_menu],
        scroll: %i[key hidden align margin width height context_menu],
        divider: %i[key hidden margin width tone],
        text: %i[key tooltip hidden align margin width emphasis tone context_menu],
        markdown: %i[key hidden align margin width],
        log: %i[key hidden align margin width height context_menu],
        progress: %i[key tooltip hidden align margin width tone],
        image: %i[key tooltip hidden align margin width height context_menu],
        button: %i[key tooltip disabled hidden align margin width emphasis tone context_menu],
        toggle: %i[key tooltip disabled hidden align margin width tone],
        checkbox: %i[key tooltip disabled hidden align margin width tone],
        radio: %i[key tooltip disabled hidden align margin width tone],
        text_input: %i[key tooltip disabled hidden align margin width tone sensitive],
        password_input: %i[key tooltip disabled hidden align margin width sensitive],
        textarea: %i[key tooltip disabled hidden align margin width height sensitive],
        number_input: %i[key tooltip disabled hidden align margin width tone sensitive],
        slider: %i[key tooltip disabled hidden align margin width tone],
        select: %i[key tooltip disabled hidden align margin width tone sensitive],
        table: %i[key disabled hidden align margin width height context_menu],
        dialog: %i[key width height tone],
        composite: %i[key tooltip hidden align margin width height context_menu],
        menu: %i[key hidden align margin width],
        menu_item: %i[key tooltip disabled hidden],
      }.freeze

      ATTRIBUTE_SCHEMAS = {
        key: property(IDENT),
        tooltip: property(SHORT),
        disabled: property(BOOL),
        hidden: property(BOOL),
        align: property(enum(*ALIGNS)),
        # 2.11: either one integer for all four sides, or the sides that
        # differ. GTK sets one edge at a time -- bigshot's glade has 518
        # one-sided margins -- and collapsing them to a single number put a
        # 100px indent on all four sides of the widget.
        margin: property(union(
                           integer(min: 0, max: 512),
                           record(
                             top: property(integer(min: 0, max: 512)), right: property(integer(min: 0, max: 512)),
                             bottom: property(integer(min: 0, max: 512)), left: property(integer(min: 0, max: 512))
                           )
                         )),
        width: property(GEOMETRY),
        height: property(GEOMETRY),
        emphasis: property(enum(*EMPHASES)),
        tone: property(enum(*TONES)),
        sensitive: property(BOOL),
        # 2.7: key of a `menu` node on the same page, opened by the viewer's
        # secondary-button gesture on this component.
        context_menu: property(IDENT),
        # 2.14: a page opts in to receiving key events. Named key_events, not
        # `key`, so it cannot shadow the identifier `key` attribute the page
        # already carries. The validator refuses a `key` event unless this is
        # set, and the browser only attaches its keydown listener when it is.
        key_events: property(BOOL),
      }.freeze

      # 2.7: pointer gestures on the surfaces scripts hang popup menus on.
      POINTER_PAYLOAD = record(
        button: property(enum(:primary, :middle, :secondary), required: true),
        x: property(GEOMETRY, required: true), y: property(GEOMETRY, required: true),
        modifiers: property(array(enum(:ctrl, :shift, :alt), max: 3), required: true)
      ).freeze
      POINTER_EVENTS = {
        press: event(POINTER_PAYLOAD), release: event(POINTER_PAYLOAD),
      }.freeze
      POINTER_TYPES = %i[group stack text image].freeze

      # 2.7: the Pango subset a `text` may carry in `markup`. The validator
      # parses it; the client builds nodes from the parse, never from HTML.
      MARKUP_TAGS = %w[b i u s tt big small span].freeze
      MARKUP_SPAN_ATTRIBUTES = %w[
        foreground color fgcolor background bgcolor size weight style underline font_desc font
      ].freeze
      MARKUP_SIZES = %w[xx-small x-small small medium large x-large xx-large smaller larger].freeze
      MARKUP_WEIGHTS = %w[ultralight light normal bold ultrabold heavy].freeze
      MARKUP_STYLES = %w[normal oblique italic].freeze
      MARKUP_UNDERLINES = %w[none single double low error].freeze
      MARKUP_COLOR = /\A(?:#\h{3}|#\h{6}|[a-z]{3,20})\z/i

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
          children: :many, child_properties: {
            # 2.8: a child that takes a share of the leftover space along the
            # stack's axis, and extra space around it. Together these are
            # GTK's box packing, which every legacy script relies on.
            grow: property(integer(min: 0, max: 64)),
            pad: property(integer(min: 0, max: 512)),
          }, events: {}, value: nil,
        },
        columns: {
          properties: {
            count: property(integer(min: 1, max: 12), required: true),
            weights: property(array(integer(min: 0), max: 12)), compact: property(BOOL, default: false),
            gap: property(integer(min: 0, max: 64), default: 8),
          }, children: { kind: :named_dynamic, count_property: :count },
          # 2.8: extra space around a child, the other half of box packing.
          # A column's share of the width is its weight, not a placement.
          child_properties: { pad: property(integer(min: 0, max: 512)) },
          events: {}, value: nil,
        },
        grid: {
          properties: {
            cols: property(integer(min: 1, max: 24), required: true),
            cells: property(integer(min: 0, max: BOUNDS[:children])),
            gap: property(integer(min: 0, max: 64), default: 8),
            # 2.10: per-column share of the leftover width, as on `columns`.
            # Without it every column shares equally, so a label column is as
            # wide as the entry beside it. Weight 0 is natural width.
            weights: property(array(integer(min: 0), max: 24)),
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
          properties: {
            max_height: property(GEOMETRY), scroll_to: property(IDENT, scope: :viewer),
            # Where the viewer is scrolled, in pixels. `scroll_to` names a cid
            # to bring into view; this is the raw offset GTK's Adjustment
            # speaks, and `bottom` is the scroll-to-bottom scripts actually
            # write (they compute `upper - page_size`, which only the viewer
            # knows).
            scroll_position: property(record(
                                        x: property(GEOMETRY), y: property(GEOMETRY), bottom: property(BOOL)
                                      ), scope: :viewer),
          },
          children: :many,
          # `upper` and `page_size` are the content extent and the visible
          # height. Only the viewer knows them, and scripts read them back to
          # work out where the bottom is.
          events: {
            # 2.13: the horizontal axis, as `position_x`/`upper_x`/
            # `page_size_x`. GTK's Adjustment is per-axis and a script that
            # pans or centres a wide canvas reads both; without these the
            # horizontal half was a constructor default. Optional, so a
            # client that reports only the vertical axis stays valid.
            scrolled: event(record(
                              position: property(GEOMETRY, required: true),
                              upper: property(GEOMETRY), page_size: property(GEOMETRY),
                              position_x: property(GEOMETRY), upper_x: property(GEOMETRY),
                              page_size_x: property(GEOMETRY)
                            )),
          }, value: nil,
        },
        divider: { properties: { label: property(SHORT) }, children: :none, events: {}, value: nil },
        text: {
          properties: {
            content: property(BODY, required: true), wrap: property(BOOL, default: true),
            markup: property(BODY),
          },
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
            focus: event(nil),
            blur: event(nil),
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
          events: {
            change: event(record(value: property(string(:multiline_text), required: true))),
            focus: event(nil),
            blur: event(nil),
          },
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
        menu: {
          properties: {
            bar: property(BOOL, default: false),
            open: property(BOOL, default: false, scope: :viewer),
          }, children: :many, events: { close: event(nil) }, value: nil,
        },
        menu_item: {
          properties: {
            label: property(SHORT),
            kind: property(enum(:normal, :check, :radio, :separator), default: 'normal'),
            active: property(BOOL, default: false, scope: :viewer),
            group: property(IDENT),
          }, children: :many,
          events: {
            activate: event(nil, terminal: true),
            change: event(record(value: property(BOOL, required: true))),
          }, value: nil,
        },
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
        # 2.12: GTK's headers-visible. A tree view used as a plain list --
        # eloot has twelve -- names its columns for the model's sake and
        # never shows them, so the label is internal, not a heading.
        headers: property(BOOL, default: true),
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
                                  region: property(IDENT),
                                  # 2.15: the enclosing scroller's live offset at the moment of
                                  # the gesture. x and y are viewport-relative, as a real
                                  # Gtk::Layout's bin-window pointer is, and the shim seeds the
                                  # ScrolledWindow's adjustments from these -- so a script's
                                  # `(hadjustment.value + pointer - offset) / scale` reconstructs
                                  # the layout-absolute pixel at any scroll offset. Optional: a
                                  # composite outside a scroller simply omits them.
                                  scroll_x: property(GEOMETRY), scroll_y: property(GEOMETRY)
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
        # 2.14: a key press aimed at the window itself, not a control. A page
        # root has no per-cid binding channel -- its bindings are routed
        # wholesale to the lifecycle validator -- so a key event has to live
        # here to be bound at all, and is dispatched through the same
        # lifecycle path (which is non-coalescable, so distinct keys pressed
        # in quick succession are never folded into one). It is deliberately
        # not terminal: it fires repeatedly over the page's life.
        # A page must set key_events before it may emit one; the browser only
        # sends it when a script connected key-press-event.
        key: event(record(
                     keyval: property(IDENT, required: true),
                     modifiers: property(array(enum(:ctrl, :shift, :alt), max: 3), required: true)
                   ), lifecycle: true),
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
            base[:events].merge!(deep_dup(POINTER_EVENTS)) if POINTER_TYPES.include?(type)
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
