# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      private

      # Composes the existing account-management tabs and their captured forms.
      # @param ui [WebUI::TreeBuilder] builder receiving this presentation family
      # @param state [Hash] captured credential-free presentation state
      # @return [void] authors the existing nested account tabs
      # @api private
      def render_accounts(ui, state)
        launcher = self
        ui.tabs(key: 'account-management-tabs', names: ACCOUNT_TABS, selected: 0, presentation_role: :inset,
                on: { select: ->(_event) {} }) do
          stack(slot: 'Accounts', key: 'accounts-list-panel') { launcher.__send__(:render_accounts_list, self, state) }
          stack(slot: 'Add Character', key: 'add-character-panel') { launcher.__send__(:render_character_form, self, state) }
          stack(slot: 'Add Account', key: 'add-account-panel') { launcher.__send__(:render_account_form, self, state) }
          stack(slot: 'Encryption Management', key: 'encryption-panel') { launcher.__send__(:render_encryption, self, state) }
        end
      end

      # Builds saved-account rows and their selected-record actions.
      # @param ui [WebUI::TreeBuilder] builder receiving this presentation family
      # @param state [Hash] captured credential-free presentation state
      # @return [void] authors the account table and its actions
      # @api private
      def render_accounts_list(ui, state)
        launcher = self
        rows = state[:entries].map do |entry|
          { key: entry.key, cells: { 'account' => entry.user_id, 'character' => entry.char_name,
                                     'game' => entry.game_code, 'frontend' => display_frontend(entry),
                                     'favorite' => entry.favorite ? 'Yes' : 'No' } }
        end
        ui.group(label: 'Saved Accounts and Characters', key: 'accounts-table-section') do
          table(key: 'accounts-table', columns: [
                  { key: 'account', label: 'Account' }, { key: 'character', label: 'Character' },
                  { key: 'game', label: 'Game' }, { key: 'frontend', label: 'Frontend' },
                  { key: 'favorite', label: 'Favorite' },
                ], rows: rows, selection: :single, selected: Array(state[:draft_entry_key]),
                on: { selection_change: ->(event) { launcher.select_managed_entry(event) } })
          columns(count: 4, weights: [1, 1, 1, 1]) do
            button(slot: '0', key: 'accounts-refresh', label: 'Refresh', on: { activate: ->(_event) { launcher.refresh_catalog } })
            button(slot: '1', key: 'accounts-edit', label: 'Edit Character', disabled: state[:draft_entry_key].nil?,
                   on: { activate: ->(_event) { launcher.begin_edit } })
            button(slot: '2', key: 'accounts-remove-character', label: 'Remove Character', variant: :danger,
                   disabled: state[:draft_entry_key].nil?, on: { activate: ->(event) { launcher.remove_selected_entry(event) } })
            button(slot: '3', key: 'accounts-remove-account', label: 'Remove Account', variant: :danger,
                   disabled: state[:draft_entry_key].nil?, on: { activate: ->(event) { launcher.remove_selected_account(event) } })
          end
        end
      end
    end
  end
end
