# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Utilities module for common functionality used across the GUI system
      # Provides helper methods for styling, dialogs, game code conversion, and file operations
      module Utilities
        # Creates a button CSS provider for styling buttons
        # Generates a CSS provider with custom styling for buttons
        #
        # @param font_size [Integer] Font size for the button
        # @return [Gtk::CssProvider] CSS provider for button styling
        def self.create_button_css_provider(font_size: 12)
          css = Gtk::CssProvider.new
          css.load_from_data("button {border-radius: 5px; font-size: #{font_size}px;}")
          css
        end

        # Creates a tab CSS provider for styling notebook tabs
        # Generates a CSS provider with custom styling for notebook tabs
        #
        # @return [Gtk::CssProvider] CSS provider for tab styling
        def self.create_tab_css_provider
          css = Gtk::CssProvider.new
          css.load_from_data("notebook {border-width: 1px; border-color: #999999; border-style: solid;}")
          css
        end

        # Creates a message dialog for displaying messages
        # Returns a callable proc that displays a message dialog when invoked
        #
        # @param parent [Gtk::Window] Parent window for the dialog
        # @param icon [Gdk::Pixbuf] Icon for the dialog
        # @return [Proc] Proc that displays a message dialog when called
        def self.create_message_dialog(parent: nil, icon: nil)
          ->(message) {
            dialog = Gtk::MessageDialog.new(
              parent: parent,
              flags: :modal,
              type: :info,
              buttons: :ok,
              message: message
            )
            dialog.title = "Message"
            dialog.set_icon(icon) if icon
            dialog.run
            dialog.destroy
          }
        end

        # Converts a game code to a realm name
        # Translates internal game codes to user-friendly realm names
        #
        # @param game_code [String] Game code (e.g., "GS3", "GSX")
        # @return [String] Realm name
        def self.game_code_to_realm(game_code)
          case game_code
          when "GS3"
            "Prime"
          when "GSF"
            "Shattered"
          when "GSX"
            "Platinum"
          when "GST"
            "Test"
          when "DR"
            "DR Prime"
          when "DRF"
            "DR Fallen"
          when "DRT"
            "DR Test"
          else
            game_code
          end
        end

        # Converts a realm name to a game code
        # Translates user-friendly realm names to internal game codes
        #
        # @param realm [String] Realm name
        # @return [String] Game code
        def self.realm_to_game_code(realm)
          case realm.downcase
          when "gemstone iv", "prime"
            "GS3"
          when "gemstone iv shattered", "shattered"
            "GSF"
          when "gemstone iv platinum", "platinum"
            "GSX"
          when "gemstone iv prime test", "test"
            "GST"
          when "dragonrealms", "dr prime"
            "DR"
          when "dragonrealms the fallen", "dr fallen"
            "DRF"
          when "dragonrealms prime test", "dr test"
            "DRT"
          else
            "GS3" # Default to GS3 if unknown
          end
        end

        # Handles file operations with error handling and backups
        # Provides a safe way to read, write, and backup files
        #
        # @param file_path [String] Path to the file
        # @param operation [Symbol] Operation to perform (:read, :write, :backup)
        # @param content [String] Content to write (for :write operation)
        # @return [String, Boolean] File content for :read, success status for others
        def self.safe_file_operation(file_path, operation, content = nil)
          case operation
          when :read
            File.read(file_path)
          when :write
            # Create backup if file exists
            safe_file_operation(file_path, :backup) if File.exist?(file_path)

            # Write content to file
            File.write(file_path, content)
            true
          when :backup
            return false unless File.exist?(file_path)

            backup_file = "#{file_path}.bak"
            FileUtils.cp(file_path, backup_file)
            true
          end
        rescue StandardError => e
          Lich.log "Error in file operation (#{operation}): #{e.message}"
          operation == :read ? "" : false
        end

        # Sorts entries based on autosort setting
        # Provides consistent sorting of entry data based on user preference
        #
        # @param entries [Array] Array of entry data
        # @param autosort_state [Boolean] Whether to use auto-sorting
        # @return [Array] Sorted array of entry data
        def self.sort_entries(entries, autosort_state)
          if autosort_state
            # Sort by game name, account name, and character name
            entries.sort do |a, b|
              [a[:game_name], a[:user_id], a[:char_name]] <=> [b[:game_name], b[:user_id], b[:char_name]]
            end
          else
            # Sort by account name and character name (old Lich 4 style)
            entries.sort do |a, b|
              [a[:user_id].downcase, a[:char_name]] <=> [b[:user_id].downcase, b[:char_name]]
            end
          end
        end
      end
    end
  end
end
