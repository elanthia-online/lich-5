# frozen_string_literal: true

require_relative 'master_password_prompt_ui'

module Lich
  module Common
    module GUI
      # Handles master password prompting and creation flow
      # Orchestrates UI display (via MasterPasswordPromptUI) and business logic
      # Manages validation, Keychain integration, and error handling
      module MasterPasswordPrompt
        # Shows master password creation dialog and handles the full flow
        # Validates user input, stores in Keychain, creates validation test
        #
        # @return [String, nil] Master password if successful, nil if cancelled/failed
        def self.show_create_master_password_dialog
          # Show UI dialog to user
          master_password = MasterPasswordPromptUI.show_dialog

          return nil if master_password.nil?

          # ====================================================================
          # VALIDATION: Check password requirements
          # ====================================================================
          if master_password.length < 8
            if show_warning_dialog(
              "Short Password",
              "Password is shorter than 8 characters.\n" +
              "Longer passwords (12+ chars) are stronger.\n\n" +
              "Continue with this password?"
            )
              # User chose to continue with weak password
              Lich.log "info: Master password strength validated (user override)"
              return master_password
            else
              # User declined weak password, restart
              Lich.log "info: User rejected weak password, prompting again"
              return show_create_master_password_dialog
            end
          end

          Lich.log "info: Master password strength validated"

          master_password
        end

        # Shows dialog to enter existing master password for recovery
        # Used when master password is missing from Keychain but encryption data exists
        # User enters password which will be validated against stored validation test
        #
        # @param validation_test [Hash, nil] Validation test for password correctness
        # @return [Hash, nil] Hash with password and continue_session, or nil if cancelled
        #   { password: String, continue_session: Boolean } if successful
        #   nil if user cancelled
        def self.show_enter_master_password_dialog(validation_test = nil)
          # Show recovery UI dialog to user
          # Clearly indicates password recovery vs creation
          result = MasterPasswordPromptUI.show_recovery_dialog(validation_test)

          return nil if result.nil?

          Lich.log "info: Master password entered and validated for recovery"

          result
        end

        # Validates an existing master password against stored validation test
        # Uses the one-time 100k iteration validation test
        #
        # @param master_password [String] Master password to validate
        # @param validation_test [String] Validation test hash from keychain
        # @return [Boolean] True if password is valid
        def self.validate_master_password(master_password, validation_test)
          return false if master_password.nil? || validation_test.nil?

          MasterPasswordManager.validate_master_password(master_password, validation_test)
        end

        def self.show_warning_dialog(title, message)
          # Block until dialog completes
          response = nil
          mutex = Mutex.new
          condition = ConditionVariable.new

          Gtk.queue do
            dialog = Gtk::MessageDialog.new(
              parent: nil,
              flags: :modal,
              type: :warning,
              buttons: :yes_no,
              message: title
            )
            dialog.secondary_text = message
            response = dialog.run
            dialog.destroy

            # Signal waiting thread
            mutex.synchronize { condition.signal }
          end

          # Wait for dialog to complete
          mutex.synchronize { condition.wait(mutex) }

          response == Gtk::ResponseType::YES
        end
      end
    end
  end
end
