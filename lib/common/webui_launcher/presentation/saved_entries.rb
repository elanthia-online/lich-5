# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      private

      # Renders saved account order and the independently ordered Favorites panel.
      # @param ui [WebUI::TreeBuilder] parent builder
      # @param state [Hash] captured launcher state
      # @return [Object] authored saved-entry controls
      # @api private
      def render_saved(ui, state)
        launcher = self
        account_names = state[:accounts].select { |account| state[:entries].any? { |entry| entry.user_id == account } }
        names = ['FAVORITES'] + account_names
        if state[:tab_layout]
          ui.tabs(key: 'saved-account-tabs', names: names, selected: 0, vertical: true,
                  on: { select: ->(_event) {} }) do
            stack(slot: 'FAVORITES', key: 'favorites-panel') do
              launcher.__send__(:render_entry_rows, self,
                                state[:entries].select(&:favorite).sort_by { |entry| [entry.favorite_order || 999999, entry.char_name] }, state,
                                empty: 'No favorite characters yet.')
            end
            account_names.each do |account|
              stack(slot: account, key: "saved-#{Catalog.account_key(account)}") do
                launcher.__send__(:render_entry_rows, self,
                                  state[:entries].select { |entry| entry.user_id == account }, state,
                                  empty: 'No saved characters for this account.')
              end
            end
          end
        else
          ui.stack(key: 'saved-list-layout') do
            account_names.each do |account|
              group(key: "saved-list-#{Catalog.account_key(account)}", label: "Account: #{account.downcase}") do
                launcher.__send__(:render_entry_rows, self,
                                  state[:entries].select { |entry| entry.user_id == account }, state,
                                  empty: 'No saved characters for this account.')
              end
            end
          end
        end
        ui.button(key: 'refresh-entries', label: 'Refresh Entries', presentation_role: :refresh,
                  on: { activate: ->(_event) { launcher.refresh_catalog } })
        ui.toggle(key: 'gui-settings-toggle', label: 'GUI Settings', checked: state[:settings_visible], presentation_role: :settings,
                  on: { change: ->(event) { launcher.setting_changed(event, :settings_visible) } })
        ui.stack(key: 'gui-settings-options', hidden: !state[:settings_visible]) do
          group(label: 'GUI Settings', key: 'gui-settings') do
            columns(count: 4, weights: [1, 1, 1, 1]) do
              toggle(slot: '0', key: 'dark-theme', label: 'Dark Theme', checked: state[:dark_theme],
                     on: { change: ->(event) { launcher.setting_changed(event, :dark_theme) } })
              toggle(slot: '1', key: 'tab-layout', label: 'Tab Layout', checked: state[:tab_layout],
                     on: { change: ->(event) { launcher.setting_changed(event, :tab_layout) } })
              toggle(slot: '2', key: 'autosort', label: 'AutoSort', checked: state[:autosort],
                     on: { change: ->(event) { launcher.setting_changed(event, :autosort) } })
              toggle(slot: '3', key: 'persistent', label: 'Multi-Launch', checked: state[:persistent],
                     on: { change: ->(event) { launcher.setting_changed(event, :persistent) } })
            end
            text(key: 'sort-order-description',
                 content: state[:autosort] ? 'Sort order: favorites first, then account/game/character.' :
                                            'Sort order: saved entry order.')
            browser = text_input(key: 'browser-path', label: 'Browser path (optional)', value: state[:browser_path].to_s,
                                 max_length: 1024)
            text(key: 'browser-support', content: BROWSER_SUPPORT_NOTE)
            button(key: 'browser-path-save', label: 'Save Browser Path', submit: [browser],
                   on: { activate: ->(event) { launcher.browser_path_changed(event, browser.cid) } })
          end
        end
      end

      # Builds keyed Play/Remove/Favorite rows in the captured saved-entry layout.
      # @param ui [WebUI::TreeBuilder] builder receiving this presentation family
      # @param entries [Array<Catalog::Entry>] saved configurations in the caller-selected order
      # @param state [Hash] captured credential-free presentation state
      # @param empty [String] authored notice when this collection has no rows
      # @return [void] authors the ordered row collection or empty notice
      # @api private
      def render_entry_rows(ui, entries, state, empty:)
        launcher = self
        if entries.empty?
          ui.text(content: empty, emphasis: :subtle)
          return
        end

        ui.collection(entries) do |entry|
          realm = launcher.__send__(:display_realm, entry)
          ui.group(key: entry.key, label: "#{entry.char_name} (#{realm})", presentation_role: :record) do
            if state[:tab_layout]
              columns(count: 3, weights: [7, 2, 1], gap: 4) do
                launch_parts = [entry.char_name, realm, launcher.__send__(:display_frontend, entry)]
                launch_label = launch_parts.join('  |  ')
                button(slot: '0', key: "play-#{entry.key}", label: launch_label, variant: :primary,
                       presentation_role: :record_primary,
                       tooltip: "Play #{entry.char_name}", a11y_label: "Play #{entry.char_name}",
                       disabled: state[:active].include?(:saved_launch),
                       on: { activate: ->(event) { launcher.saved_launch(event, entry.key) } }) do
                  text(key: 'content', slot: 'content', content: '', fragments: launch_parts.map { |part| { content: part } })
                end
                button(slot: '1', key: "remove-#{entry.key}", label: 'Remove', variant: :danger, presentation_role: :record_secondary,
                       confirm: "Remove #{entry.char_name}?",
                       on: { activate: ->(event) { launcher.remove_entry(event, entry.key) } })
                button(slot: '2', key: "favorite-#{entry.key}", checked: entry.favorite, presentation_role: :record_favorite,
                       label: entry.favorite ? 'filled_star' : 'empty_star',
                       tooltip: entry.favorite ? "Unfavorite #{entry.char_name}" : "Favorite #{entry.char_name}",
                       a11y_label: entry.favorite ? "Unfavorite #{entry.char_name}" : "Favorite #{entry.char_name}",
                       on: { activate: ->(event) { launcher.toggle_favorite(event, entry.key) } }) do
                  text(key: 'content', slot: 'content', content: [entry.favorite ? 0x2605 : 0x2606].pack('U'))
                end
              end
            else
              columns(count: 2, weights: [8, 1], gap: 4) do
                play_label = ["Play #{entry.char_name}", realm,
                              launcher.__send__(:display_frontend, entry)].join(' | ')
                button(slot: '0', key: "play-#{entry.key}", label: play_label, variant: :primary,
                       presentation_role: :record_primary,
                       tooltip: "Play #{entry.char_name}", a11y_label: "Play #{entry.char_name}",
                       disabled: state[:active].include?(:saved_launch),
                       on: { activate: ->(event) { launcher.saved_launch(event, entry.key) } })
                button(slot: '1', key: "remove-#{entry.key}", label: 'Remove', variant: :danger, presentation_role: :record_secondary,
                       confirm: "Remove #{entry.char_name}?",
                       on: { activate: ->(event) { launcher.remove_entry(event, entry.key) } })
              end
            end
          end
        end
      end
    end
  end
end
