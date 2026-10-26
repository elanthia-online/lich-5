# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      private

      # Authors a new account submission using captured frontend choices.
      # @param ui [WebUI::TreeBuilder] builder receiving this presentation family
      # @param state [Hash] captured credential-free presentation state
      # @return [void] authors the declared account fields and submission scope
      # @api private
      def render_account_form(ui, state)
        launcher = self
        ui.group(label: 'Add Account', key: 'account-form-section') do
          account = text_input(key: 'account-name', label: 'Username', value: '')
          password = password_input(key: 'account-password', label: 'Password')
          frontend_props = {
            key: 'account-frontend', label: 'Frontend', options: state[:frontend_options],
            disabled: state[:frontend_options].empty?
          }
          frontend_props[:value] = state[:frontend_options].first[:value] unless state[:frontend_options].empty?
          frontend = select(**frontend_props)
          columns(count: 2, weights: [1, 1]) do
            button(slot: '0', key: 'account-back', label: 'Back to Accounts', on: { activate: ->(_event) { launcher.cancel_edit } })
            button(slot: '1', key: 'account-add', label: 'Add Account', variant: :primary,
                   disabled: state[:frontend_options].empty?,
                   submit: [account, password, frontend],
                   on: { activate: ->(event) { launcher.save_account(event) } })
          end
        end
      end
    end
  end
end
