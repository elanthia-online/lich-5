# frozen_string_literal: true

module Lich
  module Common
    module Authentication
      # Seam between the saved-login store and whichever front end can ask
      # the user for a master password. Core never opens a dialog itself: a
      # front end that can (the GTK launcher today) registers a provider,
      # and the store asks through this module. With no provider registered
      # the prompts report nothing, so an unattended run behaves as if the
      # user declined.
      #
      # A provider responds to:
      # - +show_create_master_password_dialog+ -> String password or nil
      # - +show_password_for_data_access(validation_test)+ ->
      #   { password:, continue_session: } or nil
      # - +quit_session+ -> ends the interactive session after a cancel
      module MasterPasswordPrompts
        class << self
          # @return [Object, nil] the registered interactive provider
          attr_accessor :provider

          # @return [Boolean] whether a front end can prompt the user
          def available?
            !provider.nil?
          end

          # Asks the user to create a master password.
          #
          # @return [String, nil] the new password, or nil when declined or unavailable
          def show_create_master_password_dialog
            return nil unless available?

            provider.show_create_master_password_dialog
          end

          # Asks the user to re-enter a master password missing from the keychain.
          #
          # @param validation_test [Hash] validation test from the saved-login file
          # @return [Hash, nil] { password:, continue_session: }, or nil when cancelled or unavailable
          def show_password_for_data_access(validation_test)
            return nil unless available?

            provider.show_password_for_data_access(validation_test)
          end

          # Ends the interactive session after the user cancels recovery.
          #
          # @return [Object, nil] the provider's result, or nil when unavailable
          def quit_session
            return nil unless available? && provider.respond_to?(:quit_session)

            provider.quit_session
          end
        end
      end
    end
  end
end
