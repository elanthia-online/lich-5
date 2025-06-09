# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Utility module for theme handling and UI element styling
      # Contains shared methods for consistent theme application across the application
      module ThemeUtils
        # Applies theme settings to the application
        #
        # @param theme_state [Boolean] Whether dark theme is enabled
        # @return [void]
        def self.apply_theme_settings(theme_state)
          Gtk::Settings.default.gtk_application_prefer_dark_theme = theme_state
        end

        # Creates a consistent color for light theme backgrounds
        #
        # @return [Gdk::RGBA] Light grey color for backgrounds
        def self.light_theme_background
          Gdk::RGBA::parse("#d3d3d3")
        end

        # Creates a consistent color for light theme buttons
        #
        # @return [Gdk::RGBA] Light color for buttons
        def self.light_theme_button
          Gdk::RGBA::parse("#f0f0f0")
        end

        # Creates a consistent color for transparent backgrounds
        #
        # @return [Gdk::RGBA] Transparent color for backgrounds
        def self.darkmode_background
          Gdk::RGBA::parse("rgba(40,40,40,1)")
        end

        # Applies theme to a window and its components
        #
        # @param window [Gtk::Window] Window to apply theme to
        # @param theme_state [Boolean] Whether dark theme is enabled
        # @return [void]
        def self.apply_theme_to_window(window, theme_state)
          if theme_state
            window.override_background_color(:normal, darkmode_background)
          else
            window.override_background_color(:normal, light_theme_background)
          end
        end

        # Applies theme to a notebook and its tabs
        #
        # @param notebook [Gtk::Notebook] Notebook to apply theme to
        # @param theme_state [Boolean] Whether dark theme is enabled
        # @return [void]
        def self.apply_theme_to_notebook(notebook, theme_state)
          if theme_state
            notebook.override_background_color(:normal, darkmode_background)
          else
            notebook.override_background_color(:normal, light_theme_background)
          end
        end

        # Applies style to all buttons in a UI element collection
        #
        # @param ui_elements [Hash] Hash of UI elements
        # @param color [Gdk::RGBA] Color to apply to buttons
        # @return [void]
        def self.apply_style_to_buttons(ui_elements, color)
          ui_elements.each do |_key, element|
            if element.is_a?(Gtk::Button)
              element.override_background_color(:normal, color)
            end
          end
        end

        # Creates CSS styling for favorite characters
        # Provides visual distinction for favorite characters in the UI
        #
        # @param theme_state [Boolean] Whether dark theme is enabled
        # @return [String] CSS styling for favorite characters
        def self.create_favorites_css(theme_state)
          if theme_state
            # Dark theme favorites styling
            <<~CSS
              .favorite-character {
                background: linear-gradient(135deg, #2d3748 0%, #4a5568 100%);
                border: 2px solid #ffd700;
                border-radius: 4px;
                box-shadow: 0 2px 4px rgba(255, 215, 0, 0.3);
              }

              .favorite-character:hover {
                background: linear-gradient(135deg, #4a5568 0%, #2d3748 100%);
                border-color: #ffed4e;
                box-shadow: 0 4px 8px rgba(255, 215, 0, 0.4);
              }

              .favorite-button {
                color: #ffd700;
                font-weight: bold;
                font-size: 16px;
              }

              .favorite-button:hover {
                color: #ffed4e;
                background: rgba(255, 215, 0, 0.1);
              }
            CSS
          else
            # Light theme favorites styling
            <<~CSS
              .favorite-character {
                background: linear-gradient(135deg, #fff8dc 0%, #f0f8ff 100%);
                border: 2px solid #daa520;
                border-radius: 4px;
                box-shadow: 0 2px 4px rgba(218, 165, 32, 0.3);
              }

              .favorite-character:hover {
                background: linear-gradient(135deg, #f0f8ff 0%, #fff8dc 100%);
                border-color: #b8860b;
                box-shadow: 0 4px 8px rgba(218, 165, 32, 0.4);
              }

              .favorite-button {
                color: #b8860b;
                font-weight: bold;
                font-size: 16px;
              }

              .favorite-button:hover {
                color: #daa520;
                background: rgba(218, 165, 32, 0.1);
              }
            CSS
          end
        end

        # Creates a CSS provider for favorites styling
        # Provides a GTK CSS provider with favorites-specific styles
        #
        # @param theme_state [Boolean] Whether dark theme is enabled
        # @return [Gtk::CssProvider] CSS provider for favorites styling
        def self.create_favorites_css_provider(theme_state)
          provider = Gtk::CssProvider.new
          css_data = create_favorites_css(theme_state)

          begin
            provider.load_from_data(css_data)
          rescue StandardError => e
            Lich.log "Error loading favorites CSS: #{e.message}"
          end

          provider
        end

        # Applies favorites styling to a widget
        # Adds favorites-specific CSS classes and styling to a widget
        #
        # @param widget [Gtk::Widget] Widget to apply styling to
        # @param theme_state [Boolean] Whether dark theme is enabled
        # @param is_favorite [Boolean] Whether the widget represents a favorite
        # @return [void]
        def self.apply_favorites_styling(widget, theme_state, is_favorite = false)
          provider = create_favorites_css_provider(theme_state)
          widget.style_context.add_provider(provider, Gtk::StyleProvider::PRIORITY_USER)

          if is_favorite
            widget.style_context.add_class('favorite-character')
          end
        end

        # Creates a color for favorite indicators
        # Provides a consistent color for favorite stars and indicators
        #
        # @param theme_state [Boolean] Whether dark theme is enabled
        # @return [Gdk::RGBA] Color for favorite indicators
        def self.favorite_indicator_color(theme_state)
          if theme_state
            Gdk::RGBA::parse("#ffd700")  # Gold for dark theme
          else
            Gdk::RGBA::parse("#b8860b")  # Dark goldenrod for light theme
          end
        end

        # Creates a color for favorite button backgrounds
        # Provides a consistent background color for favorite buttons
        #
        # @param theme_state [Boolean] Whether dark theme is enabled
        # @return [Gdk::RGBA] Background color for favorite buttons
        def self.favorite_button_background(theme_state)
          if theme_state
            Gdk::RGBA::parse("rgba(255, 215, 0, 0.1)") # Transparent gold
          else
            Gdk::RGBA::parse("rgba(218, 165, 32, 0.1)") # Transparent goldenrod
          end
        end
      end
    end
  end
end
