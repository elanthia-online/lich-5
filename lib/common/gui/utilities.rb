# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Provides common utility functions for the Lich GUI components
      module Utilities
        # Creates a standard message dialog
        #
        # @param parent [Gtk::Window, nil] Parent window for the dialog
        # @param message [String] Message to display
        # @param type [Gtk::MessageType] Message type (default: ERROR)
        # @param buttons [Gtk::ButtonsType] Button configuration (default: CLOSE)
        # @param icon [Gdk::Pixbuf, nil] Window icon
        # @return [Proc] A callable that displays the message dialog
        def self.create_message_dialog(parent: nil, type: Gtk::MessageType::ERROR, buttons: Gtk::ButtonsType::CLOSE, icon: nil)
          proc { |msg|
            dialog = Gtk::MessageDialog.new(
              parent: parent,
              flags: Gtk::DialogFlags::DESTROY_WITH_PARENT,
              type: type,
              buttons: buttons,
              message: msg
            )
            dialog.set_icon(icon) if icon
            dialog.run
            dialog.destroy
          }
        end

        # Maps game code to realm name
        #
        # @param game_code [String] Game code
        # @return [String] Human-readable realm name
        def self.game_code_to_realm(game_code)
          case game_code
          when /^GS3$/
            'GS Prime'
          when /^GSX$/
            'GS Platinum'
          when /^GST$/
            'GS Test'
          when /^GSF$/
            'GS Shattered'
          when /^DR$/
            'DR Prime'
          when /^DRX$/
            'DR Platinum'
          when /^DRT$/
            'DR Test'
          when /^DRF$/
            'DR Fallen'
          else
            'Unknown'
          end
        end

        # Creates a CSS provider for buttons with consistent styling
        #
        # @param font_size [Integer] Font size in pixels
        # @param hover_color [String] Color for hover state
        # @return [Gtk::CssProvider] Configured CSS provider
        def self.create_button_css_provider(font_size: 12, hover_color: 'darkgrey')
          provider = Gtk::CssProvider.new
          provider.load(data:
            "button { font-size: #{font_size}px; padding-top: 0px; " \
            "padding-bottom: 0px; margin-top: 0px; margin-bottom: 0px; " \
            "background-image: none; }" \
            "button:hover { background-color: #{hover_color}; }")
          provider
        end

        # Creates a CSS provider for tabs with consistent styling
        #
        # @param background_color [String] Background color for tabs
        # @param hover_color [String] Color for hover state
        # @return [Gtk::CssProvider] Configured CSS provider
        def self.create_tab_css_provider(background_color: 'silver', hover_color: 'darkgrey')
          provider = Gtk::CssProvider.new
          provider.load(data:
            "tab { background-image: none; background-color: #{background_color}; }" \
            "tab:hover { background-color: #{hover_color}; }")
          provider
        end
      end
    end
  end
end
