# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Provides UI for handling entry.dat to entry.yml conversion
      # This module detects when entry.yml is missing but entry.dat exists
      # and provides a simple UI for conversion
      module ConversionUI
        # Checks if conversion is needed
        # Determines if the legacy data format needs to be converted to the new YAML format
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Boolean] True if conversion is needed (entry.dat exists but entry.yml doesn't)
        def self.conversion_needed?(data_dir)
          dat_file = File.join(data_dir, "entry.dat")
          yml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)

          # TODO: need a guard for new installs with no dat_file
          File.exist?(dat_file) && !File.exist?(yml_file)
        end

        # Creates a conversion dialog
        # Displays a UI for converting legacy data format to the new YAML format
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

          dialog.set_default_size(400, -1)
          dialog.border_width = 10

          # Set accessible properties for screen readers
          Accessibility.make_window_accessible(
            dialog,
            "Data Conversion Dialog",
            "Dialog for converting entry.dat to entry.yaml format"
          )

          # Create content area
          content_area = dialog.content_area
          content_area.spacing = 10

          # Add explanatory text
          info_label = Gtk::Label.new
          info_label.set_markup(
            "<span size='x-large'>Data Format Conversion\n\n</span>" +
            "<span size='large'>To take advantage of all new features your\n" +
            "data will be converted to a new format.\n\n" +
            "This is a one-time process to improve your experience.\n" +
            "Your original data will be retained unmodified.</span>"
          )
          info_label.set_line_wrap(true)
          info_label.set_justify(:center)

          # Set accessible properties for screen readers
          Accessibility.make_accessible(
            info_label,
            "Conversion Information",
            "Information about converting account data from entry.dat to entry.yml format",
            :label
          )

          content_area.add(info_label)

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

                  # Perform the actual conversion using existing method
                  success = YamlState.migrate_from_legacy(data_dir)

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
              Gtk.queue {
                @done = true
                Gtk.main_quit
              }
            end
          end
        end
      end
    end
  end
end
