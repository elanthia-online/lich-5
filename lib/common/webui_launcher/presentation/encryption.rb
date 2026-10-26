# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      private

      # Renders confirmed password creation and an explicit plaintext acknowledgement.
      # @param ui [WebUI::TreeBuilder] parent builder
      # @param state [Hash] current launcher state
      # @return [Object] authored controls or the catalog recovery notice
      # @api private
      def render_encryption(ui, state)
        return ui.text(content: state[:catalog_error], tone: :caution) if state[:catalog_error]

        launcher = self
        ui.group(label: 'Encryption Management', key: 'encryption-section') do
          text(content: "Current mode: #{state[:encryption_mode]}", emphasis: :strong)
          text(content: state[:keychain] ? 'Secure keychain available.' : 'Secure keychain unavailable.',
               tone: state[:keychain] ? :positive : :caution)
          modes = [
            { value: 'plaintext', label: 'Plaintext' }, { value: 'standard', label: 'Standard Encryption' },
            { value: 'enhanced', label: 'Enhanced Encryption' },
          ]
          mode = radio(key: 'encryption-mode', label: 'Encryption mode', group: 'encryption-mode',
                       options: modes, selected: state[:encryption_mode].to_s)
          master = password_input(key: 'encryption-master', label: 'Master Password')
          confirmation = password_input(key: 'encryption-confirm', label: 'Confirm New Master Password (for Enhanced Encryption)')
          plaintext = checkbox(key: 'encryption-plaintext-confirm', label: 'I understand Plaintext stores saved passwords without encryption.', checked: false)
          button(key: 'encryption-change', label: 'Change Encryption Mode', variant: :primary,
                 submit: [mode, master, confirmation, plaintext], on: { activate: ->(event) { launcher.change_encryption(event) } })
          divider(label: 'Change Master Password')
          current = password_input(key: 'master-current', label: 'Current Master Password')
          replacement = password_input(key: 'master-new', label: 'New Master Password')
          confirmation = password_input(key: 'master-confirm', label: 'Confirm New Master Password')
          button(key: 'master-change', label: 'Change Encryption Password', variant: :primary,
                 submit: [current, replacement, confirmation],
                 on: { activate: ->(event) { launcher.change_master_password(event) } })
        end
      end
    end
  end
end
