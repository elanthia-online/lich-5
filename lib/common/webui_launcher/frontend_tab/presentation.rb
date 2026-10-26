# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      class FrontendTab
        # Render helpers were public before extraction; preserve that access level.
        # YARD's private API tags describe usage, not Ruby method visibility.

        # The Frontends tab: the catalog on top, an editor for the selected row
        # below. Retains the editing role of the former GUI::FrontendManagerTab
        # from #1558 -- detection is shown as status only, and nothing here ever
        # launches a frontend or touches account associations.
        # @param ui [WebUI::TreeBuilder] builder receiving this presentation family
        # @return [void] authors the cached frontend catalog and editor
        # @api private
        def render(ui)
          state = @mutex.synchronize { @state.dup }
          launcher = self
          draft = state[:frontend_draft]
          # A new record gets new component identities. Otherwise viewer-local
          # input values from the prior record override the new server defaults.
          ui.stack(key: "frontends-body-#{state[:frontend_revision]}", gap: 8) do
            launcher.__send__(:render_frontend_catalog, self, state)
            launcher.__send__(:render_frontend_editor, self, state, draft)
          end
        end

        # Renders stable frontend rows and selection from a credential-free snapshot.
        # @param ui [WebUI::TreeBuilder] builder receiving this presentation family
        # @param state [Hash] captured credential-free presentation state
        # @return [void]
        def render_frontend_catalog(ui, state)
          launcher = self
          rows = state[:frontends].map do |row|
            { key: row[:id], cells: { 'label' => row[:label], 'type' => row[:type],
                                      'status' => row[:status], 'launch' => row[:launch].to_s,
                                      'arguments' => row[:arguments].to_s } }
          end
          selected = state[:frontend_creating] ? [] : Array(state[:frontend_draft]&.fetch(:id, nil))
          ui.group(label: 'Frontends', key: 'frontends-table-section') do
            table(key: 'frontends-table', max_height: 260, columns: [
                    { key: 'label', label: 'Frontend' }, { key: 'type', label: 'Type' },
                    { key: 'status', label: 'Status' },
                    { key: 'launch', label: 'Executable / command' },
                    { key: 'arguments', label: 'Additional arguments' },
                  ], rows: rows, selection: :single, selected: selected,
                  on: { selection_change: ->(event) { launcher.select_frontend(event) } })
          end
        end

        # Renders explicit Save/Delete actions and keeps Add/Reload available without a selection.
        # Built-in capabilities are displayed read-only.
        # @param ui [WebUI::TreeBuilder] builder receiving this presentation family
        # @param state [Hash] captured credential-free presentation state
        # @param draft [Hash, nil] captured frontend editor fields, or nil without a selection
        # @return [void]
        def render_frontend_editor(ui, state, draft)
          launcher = self
          # With no row selected there is nothing to edit, but Add Custom and
          # Reload must still be reachable -- otherwise an empty catalog, or a
          # failed load, would leave no way back.
          unless draft
            ui.group(label: 'Frontend Settings', key: 'frontend-editor-section', presentation_role: :form) do
              text(content: 'Select a frontend to edit, or choose Add Custom.')
              columns(key: 'frontend-actions', count: 3, weights: [0, 0, 1], gap: 6) do
                button(slot: '0', key: 'frontends-add', label: 'Add Custom',
                       on: { activate: ->(_event) { launcher.begin_new_frontend } })
                button(slot: '1', key: 'frontends-reload', label: 'Reload',
                       on: { activate: ->(_event) { launcher.reload_frontends } })
                text(slot: '2', key: 'frontend-actions-spacer', content: ' ')
              end
            end
            return
          end

          built_in = draft[:built_in]
          ui.group(label: built_in ? "#{draft[:label]} (built-in)" : 'Frontend Settings',
                   key: 'frontend-editor-section', presentation_role: :form) do
            text(content: state[:frontend_error], tone: :danger) if state[:frontend_error]
            fields = launcher.__send__(:render_frontend_fields, self, state, draft, built_in)
            if built_in && !draft[:detected_command].to_s.empty?
              text(key: 'frontend-detected', content: "Detected: #{draft[:detected_command]}", tone: :neutral, presentation_role: :form_hint)
            end
            capability_boxes = launcher.__send__(:render_frontend_capabilities, self, draft, built_in)
            # One row under the editor, in GTK's order, rather than Save alone at
            # the bottom and the other three stranded above the table.
            columns(key: 'frontend-actions', count: 5, weights: [0, 0, 0, 0, 1], gap: 6) do
              button(slot: '0', key: 'frontends-add', label: 'Add Custom',
                     on: { activate: ->(_event) { launcher.begin_new_frontend } })
              button(slot: '1', key: 'frontend-save', label: 'Save', variant: :primary,
                     submit: fields + capability_boxes,
                     on: { activate: ->(event) { launcher.save_frontend(event) } })
              button(slot: '2', key: 'frontends-delete', label: 'Delete Custom', variant: :danger,
                     disabled: !launcher.__send__(:frontend_deletable?, state),
                     on: { activate: ->(_event) { launcher.delete_frontend } })
              button(slot: '3', key: 'frontends-reload', label: 'Reload',
                     on: { activate: ->(_event) { launcher.reload_frontends } })
              text(slot: '4', key: 'frontend-actions-spacer', content: ' ')
            end
          end
        end

        # Emits a flat sequence of text inputs. CSS scoped to the frontend editor
        # lays each field out as a row, with a fixed-width label beside its input,
        # avoiding the doubled form height of stacked labels. Each label remains
        # the input's own `label` prop so the control keeps its accessible name.
        # @param ui [WebUI::TreeBuilder] builder receiving this presentation family
        # @param state [Hash] captured credential-free presentation state
        # @param draft [Hash, nil] captured frontend editor fields, or nil without a selection
        # @param built_in [Boolean] whether frontend identity/capabilities come from a built-in definition
        # @return [Array<WebUI::TreeBuilder::Draft>] text input references submitted by Save
        # @api private
        def render_frontend_fields(ui, state, draft, built_in)
          [
            [:id, 'Stable ID', draft[:id].to_s, !state[:frontend_creating], 64, nil],
            [:label, 'Label', draft[:label].to_s, built_in, 128, nil],
            [:command, built_in ? 'Executable override' : 'Command', draft[:command].to_s, false, 512, nil],
            [:directory, 'Working directory', draft[:directory].to_s, built_in, 512, nil],
            [:arguments, 'Additional arguments', draft[:arguments].to_s, false, 512,
             'Shell quoting, for example: --flag "two words"'],
          ].map do |name, label, value, disabled, max_length, placeholder|
            options = { key: "frontend-#{name}", label: label, value: value,
                        disabled: disabled, max_length: max_length }
            # An absent placeholder is absent, not nil: the contract types it as
            # a String and refuses nil rather than treating it as unset.
            options[:placeholder] = placeholder if placeholder
            ui.text_input(**options)
          end
        end

        # A built-in declares its own protocol capabilities; only a custom
        # frontend may choose them.
        # @param ui [WebUI::TreeBuilder] builder receiving this presentation family
        # @param draft [Hash, nil] captured frontend editor fields, or nil without a selection
        # @param built_in [Boolean] whether frontend identity/capabilities come from a built-in definition
        # @return [Array<WebUI::TreeBuilder::Draft>] allowlisted capability checkbox references submitted by Save
        # @api private
        def render_frontend_capabilities(ui, draft, built_in)
          selected = Array(draft[:capabilities]).map(&:to_s)
          boxes = []
          # GTK lays these out three across; one per line turned six checkboxes
          # into six rows and pushed Save off the bottom of the form.
          Frontend.capability_vocabulary.each_slice(CAPABILITIES_PER_ROW).with_index do |row, index|
            ui.columns(key: "frontend-capability-row-#{index}", count: CAPABILITIES_PER_ROW,
                       weights: Array.new(CAPABILITIES_PER_ROW, 1), gap: 8, presentation_role: :form_choices) do
              row.each_with_index do |capability, column|
                boxes << checkbox(slot: column.to_s, key: "frontend-capability-#{capability}",
                                  label: capability.to_s, checked: selected.include?(capability.to_s),
                                  disabled: built_in)
              end
            end
          end
          boxes
        end
      end
    end
  end
end
