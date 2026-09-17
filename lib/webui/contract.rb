# frozen_string_literal: true

require_relative 'errors'

module Lich
  module WebUI
    # Machine-readable authority for SPEC-WEBUI-CONTRACT 2.5.0 SS10 and SS14.
    #
    # Every component type, attribute, event, facility and bound the WebUI
    # contract names is declared here as data. The shape helpers ({.scalar},
    # {.string}, {.record}, ...) build the small schema hashes the
    # {Validator} interprets; {.schemas} assembles the per-type tables from
    # the base definitions, the attribute applicability list and the
    # per-type extras (table, composite, pointer and lifecycle events).
    # Nothing here is behaviour: the module is the single place the server,
    # the validator and the browser client agree on what is permitted.
    module Contract
      # @return [String] the contract version this server speaks, in `major.minor.patch` form
      VERSION = '2.20.0'
      # @return [Integer] the contract major a client must match to be admitted by {.negotiate!}
      MAJOR_VERSION = 2

      # @return [Array<Symbol>] every component type, in the order structure, display, input, then the rest
      TYPES = %i[
        page group stack columns grid tabs expander split overlay scroll divider
        text markdown log progress image
        button toggle checkbox radio text_input password_input textarea number_input slider select chips nav
        table dialog composite
        menu menu_item
      ].freeze

      # @return [Array<Symbol>] the layout types (page through divider)
      STRUCTURE_TYPES = TYPES.first(11).freeze
      # @return [Array<Symbol>] the read-only display types (text through image)
      DISPLAY_TYPES = TYPES.slice(11, 5).freeze
      # @return [Array<Symbol>] the viewer-operable input types (button through nav)
      INPUT_TYPES = TYPES.slice(16, 11).freeze

      # @return [Array<String>] permitted values of the `tone` attribute
      TONES = %w[neutral positive caution danger].freeze
      # @return [Array<String>] permitted values of the `emphasis` attribute
      EMPHASES = %w[normal strong subtle].freeze
      # @return [Array<String>] permitted values of the `align` attribute
      ALIGNS = %w[start center end stretch].freeze
      # @return [Regexp] the syntax of a contract identifier (keys, ids, event and property names)
      IDENTIFIER = /\A[A-Za-z0-9_.:-]{1,128}\z/
      # @return [Regexp] the syntax of a component id: identifiers joined by `/`
      CID_PATTERN = /\A[A-Za-z0-9_.:-]+(?:\/[A-Za-z0-9_.:-]+)*\z/

      # @return [Hash{Symbol => Integer, Range}] the named size and range limits the validator enforces
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

      # Builds the base shape hash every other shape helper wraps.
      #
      # @param kind [Symbol] the shape kind the validator dispatches on (`:string`, `:record`, ...)
      # @param constraints [Hash{Symbol => Object}] kind-specific constraints merged into the shape
      # @return [Hash{Symbol => Object}] a shape hash with `:kind` and the constraints
      def scalar(kind, **constraints)
        { kind: kind, **constraints }
      end

      # Builds a string shape, optionally capped by a named {BOUNDS} entry.
      #
      # @param bound [Symbol, nil] a {BOUNDS} key giving the maximum length, or nil for no cap
      # @param constraints [Hash{Symbol => Object}] extra constraints such as `pattern:`
      # @return [Hash{Symbol => Object}] a `:string` shape
      def string(bound = nil, **constraints)
        scalar(:string, **({ bound: bound }.compact), **constraints)
      end

      # Builds an integer shape with optional inclusive limits.
      #
      # @param min [Integer, nil] the smallest permitted value
      # @param max [Integer, nil] the largest permitted value
      # @param constraints [Hash{Symbol => Object}] extra constraints such as `max_property:`
      # @return [Hash{Symbol => Object}] an `:integer` shape
      def integer(min: nil, max: nil, **constraints)
        scalar(:integer, **({ min: min, max: max }.compact), **constraints)
      end

      # Builds a finite numeric shape with optional inclusive limits.
      #
      # @param min [Numeric, nil] the smallest permitted value
      # @param max [Numeric, nil] the largest permitted value
      # @return [Hash{Symbol => Object}] a `:number` shape
      def number(min: nil, max: nil)
        scalar(:number, finite: true, **({ min: min, max: max }.compact))
      end

      # Builds an enumeration shape whose permitted values are stored as strings.
      #
      # @param values [Array<Symbol, String, Array>] the permitted values; nested arrays are flattened
      # @return [Hash{Symbol => Object}] an `:enum` shape
      def enum(*values)
        scalar(:enum, values: values.flatten.map(&:to_s))
      end

      # Builds an array shape whose items share one shape.
      #
      # @param items [Hash{Symbol => Object}] the shape every item must satisfy
      # @param min [Integer] the fewest items permitted
      # @param max [Integer, nil] the most items permitted, or nil for no cap
      # @return [Hash{Symbol => Object}] an `:array` shape
      def array(items, min: 0, max: nil)
        scalar(:array, items: items, min: min, **({ max: max }.compact))
      end

      # Builds a record shape from named fields, given either as a hash or as keywords.
      #
      # @param fields [Hash{Symbol => Hash}, nil] field name to {.property} definition
      # @param allow_extra [Boolean] whether fields outside the definition are tolerated
      # @param field_keywords [Hash{Symbol => Hash}] the fields as keywords, when `fields` is nil
      # @return [Hash{Symbol => Object}] a `:record` shape
      # @raise [ArgumentError] when fields are given both positionally and as keywords
      def record(fields = nil, allow_extra: false, **field_keywords)
        raise ArgumentError, 'record fields supplied twice' if fields && !field_keywords.empty?

        scalar(:record, fields: fields || field_keywords, allow_extra: allow_extra)
      end

      # Builds a union shape satisfied by the first variant the value matches.
      #
      # @param variants [Array<Hash{Symbol => Object}>] the candidate shapes, tried in order
      # @return [Hash{Symbol => Object}] a `:union` shape
      def union(*variants)
        scalar(:union, variants: variants)
      end

      # Builds a property definition: a shape plus how the property is held and defaulted.
      #
      # @param shape [Hash{Symbol => Object}] the shape the value must satisfy
      # @param required [Boolean] whether the property must be supplied
      # @param scope [Symbol] who owns the value: `:shared`, `:viewer`, `:transient`,
      #   `:ephemeral_client` or `:sensitive_write_only`
      # @param default [Object] the value used when the property is absent; omitted when not given
      # @return [Hash{Symbol => Object}] a property definition with `:shape`, `:required`, `:scope`
      #   and, when supplied, `:default`
      def property(shape, required: false, scope: :shared, default: :__none__)
        result = { shape: shape, required: required, scope: scope }
        result[:default] = default unless default == :__none__
        result
      end

      # Builds an event definition: its payload shape and its dispatch flags.
      #
      # @param payload [Hash{Symbol => Object}, nil] the payload shape, or nil when the event carries none
      # @param terminal [Boolean] whether the event completes an interaction and is never coalesced
      # @param lifecycle [Boolean] whether the event is a page lifecycle event rather than a control event
      # @param structural [Boolean] whether the event changes what the viewer sees (tabs, expansion)
      # @return [Hash{Symbol => Object}] an event definition
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

      # 2.20: an option may name a `group`. Options sharing one are listed
      # under that heading, in the order the group is first seen; ungrouped
      # options list as before. `select`, `radio` and `chips` all honour it
      # -- "what you have readied" above "everything you own" was one run
      # of options with no seam between them.
      OPTION = record(
        value: property(string(:input_text), required: true),
        label: property(SHORT, required: true),
        group: property(SHORT)
      ).freeze
      OPTIONS = array(OPTION, max: BOUNDS[:collection]).freeze
      CHIP_VALUES = array(string(:input_text), max: BOUNDS[:collection]).freeze

      BUTTON_DEF = record(
        id: property(IDENT, required: true),
        label: property(SHORT, required: true),
        variant: property(enum(:default, :primary, :danger), default: 'default')
      ).freeze

      # @return [Hash{Symbol => Array<Symbol>}] for each type, the {ATTRIBUTE_SCHEMAS} keys it accepts
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
        chips: %i[key tooltip disabled hidden align margin width tone],
        nav: %i[key tooltip disabled hidden align margin width height context_menu],
        table: %i[key disabled hidden align margin width height context_menu],
        dialog: %i[key width height tone],
        composite: %i[key tooltip hidden align margin width height context_menu],
        menu: %i[key hidden align margin width],
        menu_item: %i[key tooltip disabled hidden],
      }.freeze

      # @return [Hash{Symbol => Hash}] the common attributes, as {.property} definitions
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
      # The subset of MARKUP_SIZES that reads as a type scale rather than a
      # relative nudge: `smaller`/`larger` depend on context, which a
      # first-class property should not.
      TEXT_SIZES = %w[xx-small x-small small medium large x-large xx-large].freeze
      MARKUP_WEIGHTS = %w[ultralight light normal bold ultrabold heavy].freeze
      MARKUP_STYLES = %w[normal oblique italic].freeze
      MARKUP_UNDERLINES = %w[none single double low error].freeze
      MARKUP_COLOR = /\A(?:#\h{3}|#\h{6}|[a-z]{3,20})\z/i

      # @return [Hash{Symbol => Hash}] the accessibility properties every type accepts
      ACCESSIBILITY_SCHEMAS = {
        a11y_label: property(SHORT),
        a11y_description: property(BODY),
        a11y_role: property(IDENT),
      }.freeze

      # @return [Hash{Symbol => Hash}] per-type base definitions: `:properties`, `:children`
      #   (`:none`, `:many` or a named-slot rule), `:events`, `:value` and optional extras,
      #   before {.schemas} merges the attributes and the table/composite tables in
      BASE_SCHEMAS = {
        page: {
          properties: {
            title: property(SHORT, required: true), bare: property(BOOL, default: false),
            size: property(array(GEOMETRY, min: 2, max: 2)),
            position: property(array(GEOMETRY, min: 2, max: 2)),
          }, children: :many, events: {}, value: nil,
        },
        group: {
          # 2.16: `selectable` turns a group into a card -- a bordered block
          # the viewer can choose. A new node type would duplicate everything
          # a group already does (label, border, children, collapsible) to add
          # one state, so the state goes here instead. `selected` is
          # viewer-scoped, as every other selection in the contract is.
          properties: {
            label: property(SHORT, required: true), collapsible: property(BOOL, default: false),
            selectable: property(BOOL, default: false), selected: property(BOOL, default: false, scope: :viewer)
          },
          children: :many,
          events: { select: event(record(selected: property(BOOL, required: true))) },
          value: nil,
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
            # 2.16: a type scale, so a heading does not need a markup span
            # wrapped round it to be one size larger. The vocabulary is
            # Pango's own, which the markup path already accepts, so the two
            # spellings agree rather than competing.
            size: property(enum(*TEXT_SIZES)),
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
          }, children: :none,
          # 2.18: `change` says only that the value changed -- it carries
          # nothing, so a script can drive a strength meter without the
          # password ever leaving the browser except through a submission.
          events: { change: event(nil), submit: event(nil, terminal: true) },
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
        # 2.20: `size` shows that many rows as a list box instead of a
        # closed dropdown, for a short list where the choice is the point
        # of the screen.
        select: {
          properties: {
            label: property(SHORT), options: property(OPTIONS, required: true),
            value: property(string(:input_text), scope: :viewer),
            size: property(integer(min: 2, max: 24)),
          }, children: :none,
          events: { change: event(record(value: property(string(:input_text), required: true))) },
          value: string(:input_text), value_scope: :viewer,
        },
        # 2.20: several values from a list. `select` is one value and a
        # multi-select `table` is rows in a pane, so picking a few short
        # values from a long list -- areas, creatures, room numbers -- had
        # to be built from one row per entry with Add and Remove buttons.
        # The chosen values are chips, each removable inline. The options
        # are filtered by what is typed and listed only while something is
        # typed (`searchable`, the default); with it off the whole list
        # opens on focus. `allow_custom` admits a typed value that is not
        # an option: a room number has no candidate list to offer. `max`
        # caps the count. `value` is the viewer's, as every selection is.
        chips: {
          properties: {
            label: property(SHORT), options: property(OPTIONS, default: []),
            value: property(CHIP_VALUES, default: [], scope: :viewer),
            placeholder: property(SHORT), searchable: property(BOOL, default: true),
            allow_custom: property(BOOL, default: false),
            max: property(integer(min: 1, max: BOUNDS[:collection])),
          }, children: :none,
          events: { change: event(record(values: property(CHIP_VALUES, required: true))) },
          value: CHIP_VALUES, value_scope: :viewer,
        },
        # 2.16: a selection list, which neither `tabs` nor `split` gives an
        # author. `tabs` is flat and carries no per-item state; building a
        # rail out of `split` plus buttons means hand-rolling the list and
        # losing keyboard navigation and ARIA with it. An item may name a
        # `section` to group under, carry a `detail` subtitle, a `status` the
        # client renders as a marker, and a `badge` for a count.
        #
        # Sections are flat headers rather than nested items: selection stays
        # one-dimensional, which is what makes arrow-key navigation and a
        # single `selected` identifier work.
        nav: {
          properties: {
            items: property(array(record(
                                    id: property(IDENT, required: true),
                                    label: property(SHORT, required: true),
                                    section: property(SHORT), detail: property(SHORT),
                                    status: property(enum(:none, :done, :current, :blocked), default: 'none'),
                                    badge: property(SHORT), disabled: property(BOOL, default: false)
                                  ), max: BOUNDS[:collection]), required: true),
            selected: property(IDENT, scope: :viewer),
          }, children: :none,
          events: { select: event(record(id: property(IDENT, required: true))) },
          value: IDENT, value_scope: :viewer,
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

      # @return [Hash{Symbol => Hash}] the properties merged into the `table` schema
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

      # @return [Hash{Symbol => Hash}] the events merged into the `table` schema
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
      # 2.17: drawn shapes. A script that marked a map with a circle or an X
      # had to rasterise it with Cairo into a pixbuf, encode that to PNG and
      # ship it inline under a size cap -- for a dozen pixels. A shape is
      # data the browser draws crisp at any zoom: `line` between two points,
      # `rect` and `ellipse` inscribed in a box. Stroke and fill are optional
      # tints; a shape with neither draws nothing. Every one of the three
      # scripts that drew with Cairo used exactly these -- stroked circle,
      # stroked box, two crossed lines -- and nothing else.
      SHAPE_STYLE = {
        stroke: property(TINT), fill: property(TINT),
        stroke_width: property(number(min: 0.0, max: 64.0), default: 1.0),
        opacity: property(number(min: 0.0, max: 1.0), default: 1.0),
      }.freeze
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
        ),
        record({
          kind: property(enum(:line), required: true),
          x1: property(GEOMETRY, required: true), y1: property(GEOMETRY, required: true),
          x2: property(GEOMETRY, required: true), y2: property(GEOMETRY, required: true),
          **SHAPE_STYLE,
        }),
        record({
          kind: property(enum(:rect), required: true), **POINT_FIELDS,
          w: property(GEOMETRY, required: true), h: property(GEOMETRY, required: true),
          **SHAPE_STYLE,
        }),
        record({
          kind: property(enum(:ellipse), required: true), **POINT_FIELDS,
          w: property(GEOMETRY, required: true), h: property(GEOMETRY, required: true),
          **SHAPE_STYLE,
        })
      ).freeze

      # @return [Hash{Symbol => Hash}] the properties merged into the `composite` schema
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

      # @return [Hash{Symbol => Hash}] the events merged into the `composite` schema
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
        # 2.19: ctrl+wheel over the surface. GTK scripts zoom a map from
        # scroll-event with the control mask; the client turns that gesture
        # into a direction plus the same viewport pixel and scroll offset a
        # click carries, so the script can keep the point under the pointer
        # where it was after rescaling. Plain wheel stays the scroller's.
        surface_zoom: event(record(
                              direction: property(enum(:in, :out), required: true),
                              x: property(GEOMETRY, required: true), y: property(GEOMETRY, required: true),
                              modifiers: property(array(enum(:ctrl, :shift, :alt), max: 3), required: true),
                              scroll_x: property(GEOMETRY), scroll_y: property(GEOMETRY)
                            )),
      }.freeze

      # @return [Hash{Symbol => Hash}] page facilities (accelerators, geometry, notify, focus,
      #   announce, presentation), each with its `:shape` and `:scope`
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

      # @return [Hash{Symbol => Hash}] the lifecycle events merged into the `page` schema
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

      # Assembles and memoises the complete, deep-frozen schema table for every component type.
      #
      # Each type starts from its {BASE_SCHEMAS} entry and gains: page lifecycle events (page),
      # table properties and events (table), the attributes {ATTRIBUTE_APPLICABILITY} grants it,
      # composite properties and events (composite), pointer events ({POINTER_TYPES}) and the
      # accessibility properties. A password input's `sensitive` attribute is forced true.
      #
      # @return [Hash{Symbol => Hash}] type to schema, each with `:properties`, `:children`,
      #   `:events`, `:value` and, where declared, `:value_scope`, `:child_properties`, `:special`
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

      # Looks up the schema for one component type.
      #
      # @param type [Symbol, String] the component type, as a symbol or an identifier string
      # @return [Hash{Symbol => Object}] the type's entry in {.schemas}
      # @raise [UnknownTypeError] when the type is not in {TYPES}
      def schema(type)
        normalized = normalize_type(type)
        schemas.fetch(normalized)
      rescue KeyError
        raise UnknownTypeError, "unknown component type #{type.inspect}"
      end

      # Converts a type name to the symbol the schema tables are keyed by.
      #
      # @param type [Symbol, String, Object] a symbol, an identifier-shaped string, or anything else
      # @return [Symbol, Object] the symbol form, or the input unchanged when it cannot be a type name
      def normalize_type(type)
        return type if type.is_a?(Symbol)
        return type.to_sym if type.is_a?(String) && type.match?(IDENTIFIER)

        type
      end

      # Checks a client's contract version against this server's and returns the server's.
      #
      # @param client_version [String, #to_s] the version the client announced, `major.minor.patch`
      # @return [String] {VERSION}, the version the server speaks
      # @raise [VersionError] when the version has no integer major or the major differs from {MAJOR_VERSION}
      def negotiate!(client_version)
        version = client_version.to_s
        major = Integer(version.split('.').first, exception: false)
        raise VersionError, "invalid contract version #{client_version.inspect}" unless major
        raise VersionError, "unsupported contract major #{major}; server requires #{MAJOR_VERSION}" unless major == MAJOR_VERSION

        VERSION
      end

      # Freezes a value and, for hashes and arrays, everything nested inside it.
      #
      # @param value [Object] the value to freeze in place
      # @return [Object] the same value, frozen
      def deep_freeze(value)
        case value
        when Hash
          value.each { |key, child| deep_freeze(key); deep_freeze(child) }
        when Array
          value.each { |child| deep_freeze(child) }
        end
        value.freeze
      end

      # Copies a value and, for hashes and arrays, everything nested inside it; other objects are shared.
      #
      # @param value [Object] the value to copy
      # @return [Object] an unfrozen structural copy
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
