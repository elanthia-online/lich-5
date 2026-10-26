# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      private

      # Composes the launcher with its current preference and workflow state.
      # @return [WebUI::Page] unregistered launcher page
      # @api private
      def build_page
        launcher = self
        Lich::WebUI::Page.new(
          owner: self, id: 'launcher', title: "Lich v#{defined?(LICH_VERSION) ? LICH_VERSION : ''}".strip,
          props: { bare: true },
          on: {
            attach: ->(_event) { launcher.viewer_attached },
            close: ->(event) { launcher.browser_window_closed(event.viewer_id) },
            detach: ->(event) { launcher.viewer_gone(event.viewer_id) },
          }
        ) do
          state = launcher.__send__(:render_state)
          theme(state[:dark_theme] ? :dark : :light)
          manual_controls = nil
          tabs(key: 'launcher-tabs', names: TABS, selected: state[:initial_tab],
               on: { select: ->(_event) {} }) do
            stack(slot: TABS[0], key: 'saved-panel') { launcher.__send__(:render_saved, self, state) }
            stack(slot: TABS[1], key: 'manual-panel') do
              manual_controls = launcher.__send__(:render_manual, self, state)
            end
            stack(slot: TABS[2], key: 'accounts-panel') { launcher.__send__(:render_accounts, self, state) }
            stack(slot: TABS[3], key: 'frontends-panel') { launcher.__send__(:render_frontends, self) }
          end
          manual_default = state[:manual][:phase] == :editing ? manual_controls[:connect] : manual_controls[:play]
          accelerators([{ keys: 'enter', target: manual_default.cid, event: 'activate' }])
          text_input(key: 'window-geometry', value: JSON.generate(state[:window_geometry]), hidden: true,
                     max_length: 256, on: { change: ->(event) { launcher.window_geometry_changed(event) } })
          launcher.__send__(:render_modal, self, state[:modal]) if state[:modal]
          text(key: 'catalog-error', content: state[:catalog_error], tone: :caution) if state[:catalog_error]
          notify(state[:notice]) if state[:notice]
          geometry_options = {
            width: state[:window_geometry][:width], height: state[:window_geometry][:height]
          }
          if state[:window_geometry][:position]
            geometry_options.merge!(x: state[:window_geometry][:position][0], y: state[:window_geometry][:position][1])
          end
          geometry(**geometry_options)
          presentation(always_on_top: false, scrollbars: true)
        end
      end

      # The tab owns frontend editing; the launcher only composes its surface.
      # @param ui [WebUI::TreeBuilder] builder receiving this presentation family
      # @return [void] delegates presentation to the existing frontend editor
      # @api private
      def render_frontends(ui)
        @frontend_tab.render(ui)
      end
    end
  end
end
