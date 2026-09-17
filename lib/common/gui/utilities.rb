# frozen_string_literal: true

require_relative '../authentication/utilities'

module Lich
  module Common
    module GUI
      # Utilities module for common functionality used across the GUI system
      # Provides helper methods for styling and dialogs; game code conversion,
      # file operations and entry sorting live in
      # Lich::Common::Authentication::Utilities and are delegated to it here.
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
        #
        # @see Lich::Common::Authentication::Utilities.game_code_to_realm
        def self.game_code_to_realm(game_code)
          Authentication::Utilities.game_code_to_realm(game_code)
        end

        # Converts a realm name to a game code
        #
        # @see Lich::Common::Authentication::Utilities.realm_to_game_code
        def self.realm_to_game_code(realm)
          Authentication::Utilities.realm_to_game_code(realm)
        end

        # Handles file operations with error handling and backups
        #
        # @see Lich::Common::Authentication::Utilities.safe_file_operation
        def self.safe_file_operation(file_path, operation, content = nil)
          Authentication::Utilities.safe_file_operation(file_path, operation, content)
        end

        # Handles file operations with verification to ensure data persistence
        #
        # @see Lich::Common::Authentication::Utilities.verified_file_operation
        def self.verified_file_operation(file_path, operation, content = nil)
          Authentication::Utilities.verified_file_operation(file_path, operation, content)
        end

        # Sorts entries based on autosort setting
        #
        # @see Lich::Common::Authentication::Utilities.sort_entries
        def self.sort_entries(entries, autosort_state)
          Authentication::Utilities.sort_entries(entries, autosort_state)
        end
      end
    end
  end
end
