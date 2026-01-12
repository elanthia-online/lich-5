# frozen_string_literal: true

require_relative 'master_password_manager'
require_relative 'master_password_prompt_ui'
require_relative 'password_cipher'
require_relative 'yaml_state'
require_relative 'accessibility'

module Lich
  module Common
    module GUI
      # Provides master password change functionality for the Lich GUI login system
      # Implements secure master password change with automatic re-encryption of all accounts
      module MasterPasswordChange
        # Shows a change master password dialog
        # Creates and displays a dialog for changing the master password
        # Validates current password, prompts for new password, and re-encrypts all accounts
        #
        # @param parent [Gtk::Window] Parent window
        # @param data_dir [String] Directory containing account data
        # @return [Boolean] true if password changed successfully, false if cancelled
        def self.show_change_master_password_dialog(parent, data_dir)
          # Create dialog
          dialog = Gtk::Dialog.new(
            title: "Change Master Password",
            parent: parent,
            flags: :modal,
            buttons: [
              ["Change Password", Gtk::ResponseType::APPLY],
              ["Cancel", Gtk::ResponseType::CANCEL]
            ]
          )

          dialog.set_default_size(400, -1)
          dialog.border_width = 10

          # Set accessible properties for screen readers
          Accessibility.make_window_accessible(
            dialog,
            "Master Password Change Dialog",
            "Dialog for changing the master password"
          )

          # Create content area
          content_area = dialog.content_area
          content_area.spacing = 10

          # Add header
          header_label = Gtk::Label.new
          header_label.set_markup("<span weight='bold'>Change Master Password</span>")
          header_label.set_xalign(0)

          Accessibility.make_accessible(
            header_label,
            "Change Master Password Header",
            "Title for the master password change dialog",
            :label
          )

          content_area.add(header_label)

          # Add current password entry
          current_password_box = Gtk::Box.new(:horizontal, 5)
          current_password_label = Gtk::Label.new("Current Master Password:")
          current_password_label.set_xalign(0)
          current_password_box.pack_start(current_password_label, expand: false, fill: false, padding: 0)

          current_password_entry = Gtk::Entry.new
          current_password_entry.visibility = false

          Accessibility.make_entry_accessible(
            current_password_entry,
            "Current Master Password Entry",
            "Enter your current master password"
          )

          current_password_box.pack_start(current_password_entry, expand: true, fill: true, padding: 0)
          content_area.add(current_password_box)

          # Add new password entry
          new_password_box = Gtk::Box.new(:horizontal, 5)
          new_password_label = Gtk::Label.new("New Master Password:")
          new_password_label.set_xalign(0)
          new_password_box.pack_start(new_password_label, expand: false, fill: false, padding: 0)

          new_password_entry = Gtk::Entry.new
          new_password_entry.visibility = false

          Accessibility.make_entry_accessible(
            new_password_entry,
            "New Master Password Entry",
            "Enter your new master password (minimum 8 characters)"
          )

          new_password_box.pack_start(new_password_entry, expand: true, fill: true, padding: 0)
          content_area.add(new_password_box)

          # Add confirm password entry
          confirm_password_box = Gtk::Box.new(:horizontal, 5)
          confirm_password_label = Gtk::Label.new("Confirm New Password:")
          confirm_password_label.set_xalign(0)
          confirm_password_box.pack_start(confirm_password_label, expand: false, fill: false, padding: 0)

          confirm_password_entry = Gtk::Entry.new
          confirm_password_entry.visibility = false

          Accessibility.make_entry_accessible(
            confirm_password_entry,
            "Confirm Master Password Entry",
            "Confirm your new master password"
          )

          confirm_password_box.pack_start(confirm_password_entry, expand: true, fill: true, padding: 0)
          content_area.add(confirm_password_box)

          # Add status label
          status_label = Gtk::Label.new("")
          status_label.set_xalign(0)

          Accessibility.make_accessible(
            status_label,
            "Status Message",
            "Shows status messages during password change",
            :label
          )

          content_area.add(status_label)

          # Add show password checkbox
          MasterPasswordPromptUI.new.create_and_wire_show_password_checkbox(
            content_area,
            [current_password_entry, new_password_entry, confirm_password_entry]
          )

          # Show all widgets
          dialog.show_all

          # Track whether password was changed successfully
          password_changed = false

          # Set up response handler
          dialog.signal_connect('response') do |dlg, response|
            if response == Gtk::ResponseType::APPLY
              current_password = current_password_entry.text
              new_password = new_password_entry.text
              confirm_password = confirm_password_entry.text

              # Validate inputs
              if current_password.empty?
                status_label.set_markup("<span foreground='red'>Current password cannot be empty.</span>")
                next
              end

              if new_password.empty?
                status_label.set_markup("<span foreground='red'>New password cannot be empty.</span>")
                next
              end

              if new_password.length < 8
                status_label.set_markup("<span foreground='red'>New password must be at least 8 characters.</span>")
                next
              end

              if new_password != confirm_password
                status_label.set_markup("<span foreground='red'>New passwords do not match.</span>")
                next
              end

              # Validate current password
              yaml_file = YamlState.yaml_file_path(data_dir)
              unless File.exist?(yaml_file)
                status_label.set_markup("<span foreground='red'>No account data found.</span>")
                next
              end

              unless validate_current_password(current_password, yaml_file)
                status_label.set_markup("<span foreground='red'>Current password is incorrect.</span>")
                next
              end

              # Load YAML data
              begin
                yaml_data = YAML.load_file(yaml_file)

                # Perform re-encryption
                if re_encrypt_all_accounts(yaml_data, data_dir, current_password, new_password)
                  password_changed = true

                  # Show success message
                  success_dialog = Gtk::MessageDialog.new(
                    parent: parent,
                    flags: :modal,
                    type: :info,
                    buttons: :ok,
                    message: "Master password changed successfully."
                  )

                  Accessibility.make_window_accessible(
                    success_dialog,
                    "Success Message",
                    "Master password change success notification"
                  )

                  success_dialog.run
                  success_dialog.destroy

                  # Close dialog
                  dlg.destroy
                else
                  status_label.set_markup("<span foreground='red'>Failed to change master password. Please try again.</span>")
                end
              rescue StandardError => e
                Lich.log "error: Error during master password change: #{e.message}"
                status_label.set_markup("<span foreground='red'>An error occurred: #{e.message}</span>")
              end
            elsif response == Gtk::ResponseType::CANCEL
              dlg.destroy
            end
          end

          password_changed
        end

        class << self
          private

          # Validates the current master password against the stored validation test
          #
          # @param current_password [String] Password to validate
          # @param yaml_file [String] Path to YAML file
          # @return [Boolean] true if password is correct
          def validate_current_password(current_password, yaml_file)
            begin
              yaml_data = YAML.load_file(yaml_file)
              validation_test = yaml_data['master_password_validation_test']

              return false if validation_test.nil?

              # Also validate against keychain as additional verification
              stored_password = MasterPasswordManager.retrieve_master_password
              return false if stored_password.nil?

              # Validate using PBKDF2 test
              MasterPasswordManager.validate_master_password(current_password, validation_test)
            rescue StandardError => e
              Lich.log "error: Error validating current password: #{e.message}"
              false
            end
          end

          # Re-encrypts all Enhanced mode accounts with a new master password
          #
          # @param yaml_data [Hash] YAML data structure
          # @param data_dir [String] Directory containing account data
          # @param old_password [String] Current master password
          # @param new_password [String] New master password
          # @return [Boolean] true if re-encryption successful
          def re_encrypt_all_accounts(yaml_data, data_dir, old_password, new_password)
            yaml_file = YamlState.yaml_file_path(data_dir)

            # Create backup first
            backup_file = "#{yaml_file}.backup"
            FileUtils.cp(yaml_file, backup_file)

            Lich.log "info: Starting master password change, backup created at #{backup_file}"

            begin
              # Get all accounts if encryption mode is Enhanced (mode is global, not per-account)
              enhanced_accounts = if yaml_data['encryption_mode'] == 'enhanced' && yaml_data['accounts']
                                    yaml_data['accounts'].values
                                  else
                                    []
                                  end

              Lich.log "info: Re-encrypting #{enhanced_accounts.length} Enhanced mode account(s)"

              # Re-encrypt each account
              enhanced_accounts.each do |account|
                # Decrypt with old password
                plaintext = PasswordCipher.decrypt(
                  account['password'],
                  mode: :enhanced,
                  master_password: old_password
                )

                # Encrypt with new password
                new_encrypted = PasswordCipher.encrypt(
                  plaintext,
                  mode: :enhanced,
                  master_password: new_password
                )

                # Update account
                account['password'] = new_encrypted
              end

              # Create new validation test
              new_validation = MasterPasswordManager.create_validation_test(new_password)
              yaml_data['master_password_validation_test'] = new_validation

              # Save YAML with password preservation
              content = YamlState.generate_yaml_content(yaml_data)
              File.open(yaml_file, 'w', 0600) do |file|
                file.write(content)
              end

              # Update keychain
              unless MasterPasswordManager.store_master_password(new_password)
                Lich.log "error: Failed to update keychain with new master password"
                FileUtils.rm(backup_file) if File.exist?(backup_file)
                restore_from_backup(yaml_file, backup_file)
                return false
              end

              # Clean up backup on success
              FileUtils.rm(backup_file) if File.exist?(backup_file)

              Lich.log "info: Master password changed successfully"
              true
            rescue StandardError => e
              # CRITICAL: Only log e.message, NEVER log password values
              Lich.log "error: Failed to change master password: #{e.message}"
              Lich.log "warning: Rolling back master password change"
              restore_from_backup(yaml_file, backup_file)
              false
            end
          end

          # Restores YAML file from backup
          #
          # @param yaml_file [String] Path to main YAML file
          # @param backup_file [String] Path to backup file
          # @return [void]
          def restore_from_backup(yaml_file, backup_file)
            return unless File.exist?(backup_file)

            FileUtils.cp(backup_file, yaml_file)
            FileUtils.rm(backup_file)
            Lich.log "info: Restored from backup"
          end
        end
      end
    end
  end
end
