# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      private

      # Builds the active launcher dialog and binds its response handler.
      # Unlock input belongs to the dialog and is submitted on its response.
      # @param ui [WebUI::TreeBuilder] builder receiving the dialog widgets
      # @param modal [Hash] dialog kind and optional error or confirmation body
      # @return [void]
      # @api private
      def render_modal(ui, modal)
        launcher = self
        case modal[:kind]
        when :unlock
          secret = nil
          dialog = ui.dialog(key: 'unlock-dialog', title: 'Enter Master Password', body: modal[:error].to_s,
                             no_viewer: :abort, cancel_button: 'cancel', default_button: 'unlock', buttons: [
                               { id: 'cancel', label: 'Cancel' }, { id: 'unlock', label: 'Unlock', variant: 'primary' },
                             ], on: { response: ->(event) { launcher.unlock_response(event, secret.cid) } }) do
            secret = password_input(key: 'unlock-master', label: 'Master Password')
          end
          ui.submit(dialog, [secret])
        when :change_password
          fields = []
          body = ["Account: #{modal[:account]}", modal[:error]].compact.join("\n")
          dialog = ui.dialog(key: 'change-password-dialog', title: 'Change Password', body: body,
                             no_viewer: :abort, cancel_button: 'cancel', default_button: 'change', buttons: [
                               { id: 'cancel', label: 'Cancel' }, { id: 'change', label: 'Change Password', variant: 'primary' },
                             ], on: { response: ->(event) { launcher.change_password_response(event, fields.map(&:cid)) } }) do
            fields << password_input(key: 'change-password-current', label: 'Current Password')
            fields << password_input(key: 'change-password-new', label: 'New Password')
            fields << password_input(key: 'change-password-confirm', label: 'Confirm Password')
          end
          ui.submit(dialog, fields)
        when :confirm_delete
          ui.dialog(key: 'delete-dialog', title: 'Confirm Removal', body: modal[:body], no_viewer: :abort,
                    cancel_button: 'cancel',
                    buttons: [{ id: 'cancel', label: 'Cancel' }, { id: 'remove', label: 'Remove', variant: 'danger' }],
                    on: { response: ->(event) { launcher.delete_response(event) } })
        end
      end
    end
  end
end
