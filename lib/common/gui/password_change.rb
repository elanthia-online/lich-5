# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Provides password change functionality for the Lich GUI login system
      # Implements password change that operates solely on the YAML file
      module PasswordChange
        # Shows a password change dialog
        # Creates and displays a dialog for changing account passwords
        #
        # @param parent [Gtk::Window] Parent window
        # @param data_dir [String] Directory containing account data
        # @param username [String] Username of the account to change password for
        # @return [void]
        def self.show_password_change_dialog(parent, data_dir, username)
          # Create dialog
          dialog = Gtk::Dialog.new(
            title: "Change Password",
            parent: parent,
            flags: :modal,
            buttons: [
              ["Cancel", Gtk::ResponseType::CANCEL],
              ["Change Password", Gtk::ResponseType::APPLY]
            ]
          )

          dialog.set_default_size(400, -1)
          dialog.border_width = 10

          # Set accessible properties for screen readers
          Accessibility.make_window_accessible(
            dialog,
            "Password Change Dialog",
            "Dialog for changing account password"
          )

          # Create content area
          content_area = dialog.content_area
          content_area.spacing = 10

          # Add username label
          username_label = Gtk::Label.new
          username_label.set_markup("<span weight='bold'>Account:</span> #{username}")
          username_label.set_xalign(0)

          # Set accessible properties for screen readers
          Accessibility.make_accessible(
            username_label,
            "Account Username",
            "The username of the account being modified",
            :label
          )

          content_area.add(username_label)

          # Add current password entry
          current_password_box = Gtk::Box.new(:horizontal, 5)
          current_password_label = Gtk::Label.new("Current Password:")
          current_password_label.set_xalign(0)
          current_password_box.pack_start(current_password_label, expand: false, fill: false, padding: 0)

          current_password_entry = Gtk::Entry.new
          current_password_entry.visibility = false

          # Set accessible properties for screen readers
          Accessibility.make_entry_accessible(
            current_password_entry,
            "Current Password Entry",
            "Enter your current account password"
          )

          current_password_box.pack_start(current_password_entry, expand: true, fill: true, padding: 0)
          content_area.add(current_password_box)

          # Add new password entry
          new_password_box = Gtk::Box.new(:horizontal, 5)
          new_password_label = Gtk::Label.new("New Password:")
          new_password_label.set_xalign(0)
          new_password_box.pack_start(new_password_label, expand: false, fill: false, padding: 0)

          new_password_entry = Gtk::Entry.new
          new_password_entry.visibility = false

          # Set accessible properties for screen readers
          Accessibility.make_entry_accessible(
            new_password_entry,
            "New Password Entry",
            "Enter your new account password"
          )

          new_password_box.pack_start(new_password_entry, expand: true, fill: true, padding: 0)
          content_area.add(new_password_box)

          # Add confirm password entry
          confirm_password_box = Gtk::Box.new(:horizontal, 5)
          confirm_password_label = Gtk::Label.new("Confirm Password:")
          confirm_password_label.set_xalign(0)
          confirm_password_box.pack_start(confirm_password_label, expand: false, fill: false, padding: 0)

          confirm_password_entry = Gtk::Entry.new
          confirm_password_entry.visibility = false

          # Set accessible properties for screen readers
          Accessibility.make_entry_accessible(
            confirm_password_entry,
            "Confirm Password Entry",
            "Confirm your new account password"
          )

          confirm_password_box.pack_start(confirm_password_entry, expand: true, fill: true, padding: 0)
          content_area.add(confirm_password_box)

          # Add status label
          status_label = Gtk::Label.new("")
          status_label.set_xalign(0)

          # Set accessible properties for screen readers
          Accessibility.make_accessible(
            status_label,
            "Status Message",
            "Shows status messages during password change",
            :label
          )

          content_area.add(status_label)

          # Show all widgets
          dialog.show_all

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

              if new_password != confirm_password
                status_label.set_markup("<span foreground='red'>New passwords do not match.</span>")
                next
              end

              # Verify current password
              if verify_current_password(data_dir, username, current_password)
                # Change password
                if change_password(data_dir, username, new_password)
                  # Show success message
                  success_dialog = Gtk::MessageDialog.new(
                    parent: parent,
                    flags: :modal,
                    type: :info,
                    buttons: :ok,
                    message: "Password changed successfully."
                  )

                  # Set accessible properties for screen readers
                  Accessibility.make_window_accessible(
                    success_dialog,
                    "Success Message",
                    "Password change success notification"
                  )

                  success_dialog.run
                  success_dialog.destroy

                  # Close dialog
                  dlg.destroy
                else
                  status_label.set_markup("<span foreground='red'>Failed to change password. Please try again.</span>")
                end
              else
                status_label.set_markup("<span foreground='red'>Current password is incorrect.</span>")
              end
            elsif response == Gtk::ResponseType::CANCEL
              dlg.destroy
            end
          end
        end

        class << self
          private

          # Verifies the current password for an account
          # Checks if the provided password matches the stored password
          # Uses normalized account name for consistent lookup
          #
          # @param data_dir [String] Directory containing account data
          # @param username [String] Username of the account
          # @param password [String] Password to verify
          # @return [Boolean] True if password is correct
          def verify_current_password(data_dir, username, password)
            yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)

            # Check if YAML file exists
            return false unless File.exist?(yaml_file)

            begin
              # Load YAML data
              yaml_data = YAML.load_file(yaml_file)

              # Normalize username to UPCASE for consistent lookup
              normalized_username = username.to_s.upcase

              # Check if account exists
              return false unless yaml_data['accounts'] && yaml_data['accounts'][normalized_username]

              # Verify password
              yaml_data['accounts'][normalized_username]['password'] == password
            rescue StandardError => e
              Lich.log "error: Error verifying password: #{e.message}"
              false
            end
          end

          # Changes the password for an account
          # Updates the password in the YAML file
          # Uses normalized account name for consistent operation
          #
          # @param data_dir [String] Directory containing account data
          # @param username [String] Username of the account
          # @param new_password [String] New password
          # @return [Boolean] True if password was changed successfully
          def change_password(data_dir, username, new_password)
            # Normalize username before passing to AccountManager
            normalized_username = username.to_s.upcase
            # Use the existing AccountManager method to change password
            AccountManager.change_password(data_dir, normalized_username, new_password)
          end
        end
      end
    end
  end
end
