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
        when :confirm_delete
          ui.dialog(key: 'delete-dialog', title: 'Confirm Removal', body: modal[:body], no_viewer: :abort,
                    buttons: [{ id: 'cancel', label: 'Cancel' }, { id: 'remove', label: 'Remove', variant: 'danger' }],
                    on: { response: ->(event) { launcher.delete_response(event) } })
        end
      end
    end
  end
end
