# frozen_string_literal: true

module Lich
  module WebUI
    module Contract
      ATTRIBUTE_APPLICABILITY = {
        page: %i[key disabled width height min_height],
        group: %i[key tooltip disabled hidden align margin width height min_height tone],
        stack: %i[key tooltip disabled hidden align margin width height opacity],
        columns: %i[key disabled hidden align margin width height],
        grid: %i[key tooltip disabled hidden align margin width height],
        tabs: %i[key tooltip disabled hidden align margin width height],
        expander: %i[key tooltip disabled hidden align margin width height],
        split: %i[key disabled hidden align margin width height],
        overlay: %i[key disabled hidden align margin width height],
        scroll: %i[key tooltip disabled hidden align margin width height min_height],
        divider: %i[key hidden margin width tone],
        text: %i[key tooltip hidden align margin width height emphasis tone opacity],
        markdown: %i[key disabled hidden align margin width],
        log: %i[key tooltip hidden align margin width height],
        progress: %i[key tooltip hidden align margin width height tone],
        image: %i[key tooltip hidden align margin width height],
        button: %i[key tooltip disabled hidden align margin width min_height emphasis tone opacity],
        toggle: %i[key tooltip disabled hidden align margin width tone],
        checkbox: %i[key tooltip disabled hidden align margin width tone],
        radio: %i[key tooltip disabled hidden align margin width tone],
        radio_option: %i[key tooltip disabled hidden align margin width tone],
        text_input: %i[key tooltip disabled hidden align margin width tone sensitive],
        password_input: %i[key tooltip disabled hidden align margin width sensitive],
        textarea: %i[key tooltip disabled hidden align margin width height sensitive],
        number_input: %i[key tooltip disabled hidden align margin width tone sensitive],
        slider: %i[key tooltip disabled hidden align margin width tone],
        select: %i[key tooltip disabled hidden align margin width min_height tone sensitive],
        table: %i[key tooltip disabled hidden align margin width height min_height],
        dialog: %i[key width height min_height tone],
        composite: %i[key tooltip hidden align margin width height],
      }.freeze

      ATTRIBUTE_SCHEMAS = {
        key: property(IDENT),
        tooltip: property(string(:body_text)),
        disabled: property(BOOL),
        hidden: property(BOOL),
        opacity: property(number(min: 0.0, max: 1.0)),
        align: property(enum(*ALIGNS)),
        margin: property(union(integer(min: 0, max: 512), record(
                                                            top: property(integer(min: 0, max: 512)),
                                                            right: property(integer(min: 0, max: 512)),
                                                            bottom: property(integer(min: 0, max: 512)),
                                                            left: property(integer(min: 0, max: 512))
                                                          ))),
        width: property(GEOMETRY),
        height: property(GEOMETRY),
        min_height: property(GEOMETRY),
        emphasis: property(enum(*EMPHASES)),
        tone: property(enum(*TONES)),
        sensitive: property(BOOL),
      }.freeze

      # Bounded presentation shapes, independent of component identity and labels.
      # Omission retains ordinary styling; no arbitrary CSS or class names are accepted.
      PRESENTATION_ROLES = {
        tabs: %i[inset].freeze,
        group: %i[record form].freeze,
        button: %i[record_primary record_secondary record_favorite refresh].freeze,
        toggle: %i[settings].freeze,
        columns: %i[form_choices].freeze,
        text: %i[form_hint].freeze,
      }.freeze

      ACCESSIBILITY_SCHEMAS = {
        a11y_label: property(SHORT),
        a11y_description: property(BODY),
        a11y_role: property(IDENT),
      }.freeze

      # Shared typography uses literal font properties and the bounded color shape.
      # Source markup is never forwarded to the browser.
      FONT_STYLE_PROPERTIES = {
        font_size: property(number(min: 6, max: 96)),
        font_unit: property(enum(:pt, :px), default: 'pt'),
        font_family: property(string(:identifier)),
        font_style: property(enum(:normal, :italic)),
      }.freeze
      TEXT_STYLE_PROPERTIES = {
        **FONT_STYLE_PROPERTIES,
        foreground: property(RGBA), background: property(RGBA),
      }.freeze
      TEXT_FRAGMENT = record(
        content: property(BODY, required: true), emphasis: property(enum(*EMPHASES)),
        font_style: property(enum(:normal, :italic)), foreground: property(RGBA),
        scale: property(number(min: 0.5, max: 2)), underline: property(BOOL),
        font_size: property(number(min: 6, max: 96)), font_unit: property(enum(:pt, :px)),
        font_family: property(enum(:monospace, :'sans-serif', :serif)),
        font_weight: property(integer(min: 100, max: 1000)), letter_spacing: property(number(min: -16, max: 64))
      ).freeze
    end
  end
end
