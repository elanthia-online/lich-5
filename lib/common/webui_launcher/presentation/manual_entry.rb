# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      private

      # Authors manual credentials, character selection and launch options from one snapshot.
      # @param ui [WebUI::TreeBuilder] builder receiving this presentation family
      # @param state [Hash] captured credential-free presentation state
      # @return [Hash{Symbol => WebUI::TreeBuilder::Draft}] Connect/Play references for the existing default accelerator
      # @api private
      def render_manual(ui, state)
        launcher = self
        manual = state[:manual]
        connect = nil
        play = nil
        ui.group(label: 'Credentials', key: 'manual-credentials') do
          account = text_input(key: 'manual-account', label: 'User ID', value: manual[:account],
                               disabled: manual[:phase] != :editing)
          password = password_input(key: 'manual-password', label: 'Password', disabled: manual[:phase] != :editing)
          columns(count: 2, weights: [1, 1]) do
            connect = button(slot: '0', key: 'manual-connect', label: 'Connect', variant: :primary,
                             disabled: manual[:phase] != :editing, submit: [account, password],
                             on: { activate: ->(event) { launcher.manual_connect(event, account.cid, password.cid) } })
            button(slot: '1', key: 'manual-disconnect', label: 'Disconnect',
                   disabled: manual[:phase] == :editing,
                   on: { activate: ->(event) { launcher.manual_disconnect(event.viewer_id) } })
          end
          text(content: manual[:error], tone: :danger, key: 'manual-error') if manual[:error]
        end
        ui.group(label: 'Character', key: 'manual-character') do
          rows = manual[:characters].map.with_index do |character, index|
            { key: "character-#{index}", cells: { 'game' => character[:game_name], 'character' => character[:char_name] } }
          end
          table(key: 'manual-character-list', columns: [{ key: 'game', label: 'Game' }, { key: 'character', label: 'Character' }],
                rows: rows, selection: :single, selected: Array(manual[:selected]), disabled: rows.empty?,
                on: { selection_change: ->(event) { launcher.manual_select(event) } })
        end
        ui.group(label: 'Launch Options', key: 'manual-launch-options') do
          frontend_props = {
            key: 'manual-frontend', label: 'Front end', options: state[:frontend_options],
            disabled: state[:frontend_options].empty?,
            on: { change: ->(event) { launcher.manual_option_changed(event, :frontend) } }
          }
          frontend_props[:value] = manual[:frontend] if manual[:frontend]
          frontend = select(**frontend_props)
          custom_enabled = checkbox(
            key: 'manual-custom-enabled', label: 'Custom launch command', checked: manual[:custom_enabled],
            disabled: launcher.__send__(:native_launch_only?, manual[:frontend]),
            on: { change: ->(event) { launcher.manual_option_changed(event, :custom_enabled) } }
          )
          custom_fields = stack(key: 'manual-custom-fields', hidden: !manual[:custom_enabled]) do
            text_input(key: 'manual-custom', label: 'Custom command', value: '')
            text_input(key: 'manual-custom-dir', label: 'Custom launch directory', value: '')
          end
          custom = custom_fields.children[0]
          custom_dir = custom_fields.children[1]
          save = checkbox(key: 'manual-save', label: 'Save this info for quick game entry', checked: false)
          favorite = checkbox(key: 'manual-favorite', label: 'Mark as favorite', checked: false)
          columns(key: 'manual-play-actions', count: 2, weights: [4, 1]) do
            play = button(slot: '1', key: 'manual-play', label: 'Play', variant: :primary,
                          disabled: !launcher.__send__(:manual_playable?, manual, state[:frontend_options]),
                          submit: [frontend, custom_enabled, custom, custom_dir, save, favorite],
                          on: { activate: ->(event) { launcher.manual_play(event) } })
          end
        end
        { connect: connect, play: play }
      end
    end
  end
end
