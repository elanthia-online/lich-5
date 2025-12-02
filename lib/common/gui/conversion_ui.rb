# frozen_string_literal: true

require_relative 'master_password_manager'

module Lich
  module Common
    module GUI
      # Provides UI for handling entry.dat to entry.yaml conversion
      # This module detects when entry.yaml is missing but entry.dat exists
      # and provides a UI for conversion with encryption mode selection
      module ConversionUI
        # Checks if conversion is needed
        # Determines if the legacy data format needs to be converted to the new YAML format
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Boolean] True if conversion is needed (entry.dat exists but entry.yaml doesn't)
        def self.conversion_needed?(data_dir)
          dat_file = File.join(data_dir, "entry.dat")
          yml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)

          # TODO: need a guard for new installs with no dat_file
          File.exist?(dat_file) && !File.exist?(yml_file)
        end

        # Creates a conversion dialog with encryption mode selection
        # Displays a UI for converting legacy data format to the new YAML format
        # with radio buttons for selecting encryption mode
        #
        # @param parent [Gtk::Window] Parent window
        # @param data_dir [String] Directory containing entry data
        # @param on_conversion_complete [Proc] Callback to execute when conversion is complete
        # @return [void]
        def self.show_conversion_dialog(parent, data_dir, on_conversion_complete)
          # Create dialog
          dialog = Gtk::Dialog.new(
            title: "Data Conversion Required",
            parent: parent,
            flags: :modal,
            buttons: [
              ["Convert Data", Gtk::ResponseType::APPLY]
            ]
          )

          dialog.set_default_size(500, -1)
          dialog.border_width = 10

          # Set accessible properties for screen readers
          Accessibility.make_window_accessible(
            dialog,
            "Data Conversion Dialog",
            "Dialog for converting entry.dat to entry.yaml format with encryption mode selection"
          )

          # Create content area
          content_area = dialog.content_area
          content_area.spacing = 10

          # Add explanatory text
          header_label = Gtk::Label.new
          info_label = Gtk::Label.new
          header_label.set_markup(
            "<span size='x-large'>Saved Entries Data Conversion\n\n</span>"
          )

          # Build info text - only show entry.dat info if it still exists (not yet converted)
          info_text = "<span size='large'>Your existing saved entries data will be converted to a new format. This is a one-time process and your original saved entries data will be retained unmodified."

          # Only show entry.dat file info if conversion hasn't happened yet
          unless File.exist?(Lich::Common::GUI::YamlState.yaml_file_path(LIB_DIR))
            info_text += "\n\nExisting:\t\t#{LIB_DIR}/entry.dat\n" +
                         "Converted:\t#{LIB_DIR}/entry.yaml\n\n" +
                         "entry.dat will no longer be used, and may be deleted at your convenience"
          end

          info_text += "</span>"

          info_label.set_markup(info_text)
          header_label.set_line_wrap(false)
          info_label.set_line_wrap(true)
          header_label.set_justify(:center)
          info_label.set_justify(:left)

          # Set accessible properties for screen readers
          Accessibility.make_accessible(
            info_label,
            "Conversion Information",
            "Information about converting account data from entry.dat to entry.yaml format",
            :label
          )

          content_area.add(header_label)
          content_area.add(info_label)

          # Add encryption mode selection
          mode_frame = Gtk::Frame.new("Select Password Security Mode")
          mode_frame.border_width = 10
          mode_box = Gtk::Box.new(:vertical, 5)
          mode_box.border_width = 10
          mode_frame.add(mode_box)

          # Radio buttons for mode selection
          plaintext_radio = Gtk::RadioButton.new(label: "Plaintext (no encryption - least secure)")
          standard_radio = Gtk::RadioButton.new(member: plaintext_radio, label: "Standard Encryption (basic encryption)")
          enhanced_radio = Gtk::RadioButton.new(member: plaintext_radio, label: "Enhanced Encryption (recommended)")

          # Set standard encryption as default
          standard_radio.active = true

          # Disable/hide modes if keychain not available
          unless MasterPasswordManager.keychain_available?
            enhanced_radio.sensitive = false
            enhanced_radio.visible = false if OS.windows? # Hide on Windows if unavailable
            Lich.log "info: Enhanced encryption mode disabled - Keychain tools not available on this system"
          end

          # Set accessible properties
          Accessibility.make_accessible(
            plaintext_radio,
            "Plaintext Mode",
            "Store passwords without encryption - not recommended",
            :radio_button
          )
          Accessibility.make_accessible(
            standard_radio,
            "Standard Encryption Mode",
            "Encrypt passwords using account name as encryption key",
            :radio_button
          )
          Accessibility.make_accessible(
            enhanced_radio,
            "Enhanced Encryption Mode",
            "Encrypt passwords using an enhanced method - most secure option",
            :radio_button
          )

          mode_box.add(plaintext_radio)
          mode_box.add(standard_radio)
          mode_box.add(enhanced_radio)

          content_area.add(mode_frame)

          # Add progress bar (initially hidden)
          progress_bar = Gtk::ProgressBar.new
          progress_bar.visible = false

          # Set accessible properties for screen readers
          Accessibility.make_accessible(
            progress_bar,
            "Conversion Progress",
            "Shows progress of the data conversion process"
          )

          content_area.add(progress_bar)

          # Add status label (initially hidden)
          status_label = Gtk::Label.new("")
          status_label.visible = false

          # Set accessible properties for screen readers
          Accessibility.make_accessible(
            status_label,
            "Conversion Status",
            "Shows the current status of the conversion process",
            :label
          )

          content_area.add(status_label)

          # Show all widgets
          dialog.show_all

          # Set up response handler
          dialog.signal_connect('response') do |dlg, response|
            if response == Gtk::ResponseType::APPLY
              # Determine selected mode
              selected_mode = if plaintext_radio.active?
                                :plaintext
                              elsif standard_radio.active?
                                :standard
                              else
                                :enhanced # Default to enhanced if somehow neither plaintext nor standard
                              end

              # Show warning for plaintext mode
              if selected_mode == :plaintext
                warning = Gtk::MessageDialog.new(
                  parent: dialog,
                  flags: :modal,
                  type: :warning,
                  buttons: :ok_cancel,
                  message: "Encryption Warning"
                )
                warning.secondary_text = "You have selected plaintext mode. Your passwords will be stored WITHOUT encryption.\n\n" +
                                         "This is NOT recommended for password protection.\n\n" +
                                         "Are you sure you want to continue?"

                Accessibility.make_window_accessible(
                  warning,
                  "Plaintext Warning",
                  "Warning dialog about encryption risks of plaintext password storage"
                )

                warning_response = warning.run
                warning.destroy

                # If user cancels, skip to next iteration
                if warning_response != Gtk::ResponseType::OK
                  next
                end
              end

              # Disable buttons during conversion
              dialog.set_response_sensitive(Gtk::ResponseType::CANCEL, false)
              dialog.set_response_sensitive(Gtk::ResponseType::APPLY, false)

              # Show progress bar and status
              progress_bar.visible = true
              status_label.visible = true

              # Use a separate thread for conversion to keep UI responsive
              Thread.new do
                begin
                  # Simulate progress (actual conversion is quick but we want to show progress)
                  Gtk.queue do
                    progress_bar.fraction = 0.2
                    status_label.text = "Reading existing data..."
                  end
                  sleep(0.5)

                  Gtk.queue do
                    progress_bar.fraction = 0.5
                    status_label.text = "Converting data format..."
                  end
                  sleep(0.5)

                  # Perform the actual conversion using existing method with selected mode
                  success = YamlState.migrate_from_legacy(data_dir, encryption_mode: selected_mode)

                  Gtk.queue do
                    progress_bar.fraction = 0.8
                    status_label.text = "Validating conversion..."
                  end
                  sleep(0.5)

                  # Update UI based on result
                  Gtk.queue do
                    if success
                      progress_bar.fraction = 1.0
                      status_label.text = "Conversion completed successfully!"

                      # Wait a moment before closing dialog
                      GLib::Timeout.add(1500) do
                        dlg.destroy
                        on_conversion_complete.call if on_conversion_complete
                        false # Don't repeat the timeout
                      end
                    else
                      progress_bar.fraction = 0.0
                      status_label.text = "Conversion failed. Please try again."

                      # Re-enable buttons
                      dialog.set_response_sensitive(Gtk::ResponseType::CANCEL, true)
                      dialog.set_response_sensitive(Gtk::ResponseType::APPLY, true)
                    end
                  end
                rescue StandardError => e
                  # Handle any exceptions
                  Gtk.queue do
                    progress_bar.fraction = 0.0
                    status_label.text = "Error during conversion: #{e.message}"

                    # Re-enable buttons
                    dialog.set_response_sensitive(Gtk::ResponseType::CANCEL, true)
                    dialog.set_response_sensitive(Gtk::ResponseType::APPLY, true)
                  end
                end
              end
            elsif response == Gtk::ResponseType::CANCEL
              # user opted not to use new YAML / account management
              # too harsh?
              dlg.destroy
              Gtk.queue do
                @done = true
                Gtk.main_quit
              end
            end
          end
        end
      end
    end
  end
end
