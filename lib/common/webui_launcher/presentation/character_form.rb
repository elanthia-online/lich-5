# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      private

      # Builds the character editor, retaining a removed frontend for explicit repair.
      # @param ui [WebUI::TreeBuilder] builder receiving the form widgets
      # @param state [Hash] account, entry and available-frontend snapshot
      # @return [void]
      # @api private
      def render_character_form(ui, state)
        launcher = self
        options = state[:accounts].map { |account| { value: account, label: account } }
        draft = state[:entries].find { |entry| entry.key == state[:draft_entry_key] }
        ui.group(label: draft ? 'Edit Character' : 'Add Character', key: 'character-form-section') do
          account_props = { key: 'character-account', label: 'Account', options: options,
                            disabled: !draft.nil? || options.empty? }
          account_props[:value] = draft&.user_id || state[:accounts].first unless options.empty?
          account = select(**account_props)
          name = text_input(key: 'character-name', label: 'Character', value: draft&.char_name.to_s)
          game = select(key: 'character-game', label: 'Game', options: GAMES, value: draft&.game_code || 'GS3')
          frontend_options = state[:frontend_options].map(&:dup)
          if draft && !frontend_options.any? { |option| option[:value] == draft.frontend }
            frontend_options << { value: draft.frontend, label: "#{draft.frontend} (removed; choose a replacement)" }
          end
          frontend_props = {
            key: 'character-frontend', label: 'Frontend', options: frontend_options,
            disabled: state[:frontend_options].empty?
          }
          unless frontend_options.empty?
            frontend_props[:value] = draft&.frontend || frontend_options.first[:value]
          end
          frontend = select(**frontend_props)
          custom = text_input(key: 'character-custom', label: 'Custom Launch', value: draft&.custom_launch.to_s)
          custom_dir = text_input(key: 'character-custom-dir', label: 'Custom Launch Dir', value: draft&.custom_launch_dir.to_s)
          columns(count: 2, weights: [1, 1]) do
            button(slot: '0', key: 'character-back', label: 'Back to Accounts', on: { activate: ->(_event) { launcher.cancel_edit } })
            button(slot: '1', key: 'character-save', label: draft ? 'Save Character' : 'Add Character', variant: :primary,
                   disabled: options.empty? || state[:frontend_options].empty?,
                   submit: [account, name, game, frontend, custom, custom_dir],
                   on: { activate: ->(event) { launcher.save_character(event) } })
          end
        end
      end
    end
  end
end
