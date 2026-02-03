# frozen_string_literal: true

require_relative 'yaml_state'
require_relative 'master_password_manager'
require_relative 'master_password_prompt_ui'
require_relative 'accessibility'

module Lich
  module Common
    module GUI
      # Provides encryption mode change functionality for the Lich GUI
      # Allows users to change between plaintext, standard, and enhanced encryption modes
      # Reuses existing UI components and domain logic
      module EncryptionModeChange
        # Shows a change encryption mode dialog
        # Displays mode selection with current mode and handles all mode change workflows
        #
        # @param parent [Gtk::Window] Parent window
        # @param data_dir [String] Directory containing account data
        # @param on_completion [Proc, nil] Optional callback to call when mode change completes successfully
        # @return [Boolean] true if mode changed successfully, false if cancelled
        def self.show_change_mode_dialog(parent, data_dir, on_completion = nil)
          yaml_file = YamlState.yaml_file_path(data_dir)

          # Load current mode
          begin
            yaml_data = YAML.load_file(yaml_file)
            current_mode = yaml_data['encryption_mode']&.to_sym || :plaintext
          rescue StandardError => e
            Lich.log "error: Failed to load YAML for mode change dialog: #{e.message}"
            show_error_dialog(parent, "Failed to load account data: #{e.message}")
            return false
          end

          # Create dialog
          dialog = Gtk::Dialog.new(
            title: "Change Encryption Mode",
            parent: parent,
            flags: :modal,
            buttons: [
              ["Change Mode", Gtk::ResponseType::APPLY],
              ["Cancel", Gtk::ResponseType::CANCEL]
            ]
          )

          dialog.set_default_size(450, 350)
          dialog.border_width = 10

          Accessibility.make_window_accessible(
            dialog,
            "Change Encryption Mode Dialog",
            "Dialog for changing the encryption mode"
          )

          # Create content area
          content_area = dialog.content_area
          content_area.spacing = 10

          # Add header
          header_label = Gtk::Label.new
          header_label.set_markup("<span weight='bold'>Change Encryption Mode</span>")
          header_label.set_xalign(0)

          Accessibility.make_accessible(
            header_label,
            "Change Encryption Mode Header",
            "Title for the encryption mode change dialog",
            :label
          )

          content_area.add(header_label)

          # Add current mode display
          current_mode_label = Gtk::Label.new
          current_mode_text = mode_display_text(current_mode)
          current_mode_label.set_markup("Current Mode: <b>#{current_mode_text}</b>")
          current_mode_label.set_xalign(0)

          Accessibility.make_accessible(
            current_mode_label,
            "Current Mode Display",
            "Shows the current encryption mode",
            :label
          )

          content_area.add(current_mode_label)

          # Add separator
          separator = Gtk::Separator.new(:horizontal)
          content_area.add(separator)

          # Add mode selection label
          selection_label = Gtk::Label.new("Select new encryption mode:")
          selection_label.set_xalign(0)

          Accessibility.make_accessible(
            selection_label,
            "Mode Selection Instruction",
            "Instruction to select a new encryption mode",
            :label
          )

          content_area.add(selection_label)

          # Create radio button group for mode selection
          plaintext_radio = Gtk::RadioButton.new(label: "Plaintext (No Encryption)")
          plaintext_radio.tooltip_text = "Passwords stored unencrypted (accessibility mode)"

          Accessibility.make_accessible(
            plaintext_radio,
            "Plaintext Mode Option",
            "Select plaintext encryption mode",
            :button
          )

          standard_radio = Gtk::RadioButton.new(member: plaintext_radio,
                                                label: "Standard Encryption (Account Name)")
          standard_radio.tooltip_text = "Encrypt with account name"

          Accessibility.make_accessible(
            standard_radio,
            "Standard Mode Option",
            "Select standard encryption mode",
            :button
          )

          enhanced_radio = Gtk::RadioButton.new(member: plaintext_radio,
                                                label: "Enhanced Encryption (Master Password)")
          enhanced_radio.tooltip_text = "Encrypt with master password (strongest security)"

          Accessibility.make_accessible(
            enhanced_radio,
            "Enhanced Mode Option",
            "Select enhanced encryption mode",
            :button
          )

          # Set currently selected mode
          case current_mode
          when :plaintext
            plaintext_radio.active = true
          when :standard
            standard_radio.active = true
          when :enhanced
            enhanced_radio.active = true
          end

          content_area.add(plaintext_radio)
          content_area.add(standard_radio)
          content_area.add(enhanced_radio)

          # Add warning note
          warning_label = Gtk::Label.new
          warning_label.set_markup("<i>All passwords will be decrypted and re-encrypted\nwith the new method.</i>")
          warning_label.set_xalign(0)
          warning_label.set_line_wrap(true)

          Accessibility.make_accessible(
            warning_label,
            "Re-encryption Warning",
            "Warning that all passwords will be re-encrypted",
            :label
          )

          content_area.add(warning_label)

          # Track mode change result
          mode_changed = false

          # Set up response handler
          dialog.signal_connect('response') do |dlg, response|
            Lich.log "debug: change_encryption_mode response handler, response=#{response}"
            if response == Gtk::ResponseType::APPLY
              # Determine selected mode
              selected_mode = if plaintext_radio.active?
                                :plaintext
                              elsif standard_radio.active?
                                :standard
                              elsif enhanced_radio.active?
                                :enhanced
                              end

              Lich.log "debug: selected_mode=#{selected_mode}, current_mode=#{current_mode}"

              # If mode didn't change, just close dialog
              if selected_mode == current_mode
                Lich.log "debug: mode unchanged, closing"
                dlg.destroy
                next
              end

              dlg.destroy
              Lich.log "debug: spawning thread for dialogs and mode change"

              # Spawn thread to run dialogs and mode change
              # Dialogs use Gtk.queue internally, so they need a non-GTK thread
              Thread.new do
                Lich.log "debug: thread starting"
                new_master_password = nil
                validation_passed = true

                # Validate leaving current mode
                if current_mode == :enhanced
                  Lich.log "debug: showing password confirmation dialog for leaving enhanced mode"
                  validation_result = MasterPasswordPromptUI.show_password_confirmation_for_mode_change(
                    yaml_data['master_password_validation_test'],
                    leaving_enhanced: true
                  )
                  Lich.log "debug: validation_result=#{validation_result.inspect}"
                  unless validation_result && validation_result[:password]
                    Lich.log "debug: password confirmation cancelled"
                    validation_passed = false
                  end
                end

                if validation_passed
                  # Validate entering new mode
                  if selected_mode == :enhanced
                    Lich.log "debug: showing password dialog"
                    new_master_password = MasterPasswordPromptUI.show_dialog
                    Lich.log "debug: password_nil?=#{new_master_password.nil?}"
                    unless new_master_password
                      Lich.log "debug: password entry cancelled"
                      validation_passed = false
                    end
                  elsif selected_mode == :plaintext
                    Lich.log "debug: showing plaintext confirmation"
                    unless confirm_plaintext_mode_dialog(parent)
                      Lich.log "debug: plaintext confirmation cancelled"
                      validation_passed = false
                    end
                  end
                  # selected_mode == :standard needs nothing special
                end

                # All validations passed, queue the actual mode change
                if validation_passed
                  Lich.log "debug: all validations passed, queuing mode change"
                  Gtk.queue do
                    Lich.log "debug: in Gtk.queue, calling YamlState.change_encryption_mode"
                    success = YamlState.change_encryption_mode(
                      data_dir,
                      selected_mode,
                      new_master_password
                    )
                    Lich.log "debug: change_encryption_mode returned #{success}"

                    if success
                      mode_changed = true
                      success_dialog = Gtk::MessageDialog.new(
                        parent: parent,
                        flags: :modal,
                        type: :info,
                        buttons: :ok,
                        message: "Encryption mode changed successfully."
                      )

                      Accessibility.make_window_accessible(
                        success_dialog,
                        "Success Message",
                        "Encryption mode change success notification"
                      )

                      success_dialog.run
                      success_dialog.destroy
                      # Call completion callback after mode change succeeds
                      on_completion.call if on_completion
                    else
                      error_dialog = Gtk::MessageDialog.new(
                        parent: parent,
                        flags: :modal,
                        type: :error,
                        buttons: :ok,
                        message: "Failed to change encryption mode. Please check the logs."
                      )

                      Accessibility.make_window_accessible(
                        error_dialog,
                        "Error Message",
                        "Encryption mode change failed notification"
                      )

                      error_dialog.run
                      error_dialog.destroy
                    end
                  end
                end
                Lich.log "debug: thread complete"
              end
              Lich.log "debug: thread spawned, signal handler returning"
            elsif response == Gtk::ResponseType::CANCEL
              Lich.log "debug: mode change cancelled"
              dlg.destroy
            end
          end

          # Show dialog
          dialog.show_all

          # Return true to indicate dialog was shown (actual result will be async)
          true
        end

        class << self
          private

          # Returns display text for encryption mode
          def mode_display_text(mode)
            case mode
            when :plaintext
              "Plaintext (No Encryption)"
            when :standard
              "Standard Encryption (Account Name)"
            when :enhanced
              "Enhanced Encryption (Master Password)"
            else
              "Unknown"
            end
          end

          # Confirms plaintext mode selection with warning
          # Uses Gtk.queue for thread-safe dialog operations
          def confirm_plaintext_mode_dialog(parent)
            result = nil
            mutex = Mutex.new
            condition = ConditionVariable.new

            Gtk.queue do
              dialog = Gtk::MessageDialog.new(
                parent: parent,
                flags: :modal,
                type: :warning,
                buttons: :none,
                message: "Plaintext Mode Warning"
              )

              dialog.secondary_text = "You are about to disable encryption.\n\n" \
                                     "Plaintext mode stores passwords unencrypted.\n" \
                                     "Anyone with access to your file system can read your passwords.\n\n" \
                                     "This mode is provided for accessibility purposes.\n\n" \
                                     "Continue with Plaintext mode?"

              dialog.add_button("Yes, Disable Encryption", Gtk::ResponseType::YES)
              dialog.add_button("Cancel", Gtk::ResponseType::CANCEL)

              Accessibility.make_window_accessible(
                dialog,
                "Plaintext Mode Warning",
                "Warning about plaintext mode security implications"
              )

              response = dialog.run
              dialog.destroy

              result = response == Gtk::ResponseType::YES
              mutex.synchronize { condition.signal }
            end

            mutex.synchronize { condition.wait(mutex) }
            result
          end

          # Shows error dialog
          def show_error_dialog(parent, message)
            dialog = Gtk::MessageDialog.new(
              parent: parent,
              flags: :modal,
              type: :error,
              buttons: :ok,
              message: "Error"
            )

            dialog.secondary_text = message

            Accessibility.make_window_accessible(
              dialog,
              "Error Dialog",
              "Error notification"
            )

            dialog.run
            dialog.destroy
          end
        end
      end
    end
  end
end
