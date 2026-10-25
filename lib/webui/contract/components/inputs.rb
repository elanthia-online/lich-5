# frozen_string_literal: true

module Lich
  module WebUI
    module Contract
      class << self
        private

        # Supplies the inputs component declarations to the Contract facade.
        # @return [Hash] base schemas in declaration order
        def inputs_schemas
          {
            button: {
              properties: {
                label: property(SHORT, required: true),
                variant: property(enum(:default, :primary, :danger), default: 'default'), confirm: property(SHORT),
                indicator: property(enum(:check, :radio)), checked: property(BOOL, default: false),
              }, children: { kind: :named, slots: %w[content], types: %i[text] }, events: { activate: event(nil, terminal: true) }, value: nil,
            },
            toggle: {
              properties: { label: property(SHORT), checked: property(BOOL, required: true, scope: :viewer),
                            appearance: property(enum(:checkbox, :button, :menu, :switch), default: :checkbox) },
              children: :none, events: { change: event(record(value: property(BOOL, required: true))), activate: event(nil, terminal: true) }, value: BOOL,
            },
            checkbox: {
              properties: { label: property(SHORT, required: true), checked: property(BOOL, required: true, scope: :viewer) },
              children: :none, events: { change: event(record(value: property(BOOL, required: true))) }, value: BOOL,
            },
            # Independently placed members share exclusive selection within one page/viewer.
            radio_option: {
              properties: { appearance: property(enum(:radio, :menu), default: :radio), label: property(SHORT, required: true), group: property(IDENT, required: true),
                            checked: property(BOOL, required: true, scope: :viewer) },
              children: :none, events: { change: event(record(value: property(BOOL, required: true))), activate: event(nil, terminal: true) }, value: BOOL,
            },
            radio: {
              properties: {
                label: property(SHORT, required: true), group: property(IDENT, required: true),
                orientation: property(enum(:horizontal, :vertical), default: 'horizontal'),
                gap: property(integer(min: 0, max: 64), default: 12),
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
                read_only: property(BOOL, default: false),
                has_frame: property(BOOL, default: true),
                # GTK changed handlers and activate/focus-out handlers have different
                # timing. Keep existing committed changes unless explicitly opted in.
                change_mode: property(enum(:commit, :input), default: :commit),
              }, children: :none,
              events: {
                change: event(record(value: property(string(:input_text), required: true))),
                # Focus changes can execute source logic; never coalesce them.
                focus: event(nil, lifecycle: true),
                blur: event(record(value: property(string(:input_text), required: true)), lifecycle: true),
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
                read_only: property(BOOL, default: false), cursor_visible: property(BOOL, default: true),
                wrap: property(enum(:word, :word_char, :none), default: :word), follow: property(BOOL, default: false),
                label: property(SHORT), value: property(string(:multiline_text), required: true, scope: :viewer),
                rows: property(integer(min: 1, max: 64), default: 5),
                max_length: property(integer(min: 1, max: 65_536)),
              }, children: :none,
              events: { change: event(record(value: property(string(:multiline_text), required: true))),
                        blur: event(record(value: property(string(:multiline_text), required: true)), lifecycle: true) },
              value: string(:multiline_text), value_scope: :viewer,
            },
            number_input: {
              properties: {
                stepper_buttons: property(BOOL, default: false),
                digits: property(integer(min: 0, max: 20)),
                acceleration: property(number(min: 0)), page_step: property(number(min: 0)),
                snap_to_step: property(BOOL, default: true),
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
                editable: property(BOOL, default: false), placeholder: property(SHORT),
                # Optional disjoint encoding for free text when labels and option IDs differ.
                free_text_prefix: property(SHORT),
                empty_value: property(string(:input_text)),
                value: property(string(:input_text), scope: :viewer),
              }, children: :none,
              events: { change: event(record(value: property(string(:input_text), required: true))) },
              value: string(:input_text), value_scope: :viewer,
            },
          }
        end
      end
    end
  end
end
