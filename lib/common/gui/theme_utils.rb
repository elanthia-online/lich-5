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
        def self.transparent_background
          Gdk::RGBA::parse("rgba(0,0,0,0)")
        end

        # Applies theme to a window and its components
        #
        # @param window [Gtk::Window] Window to apply theme to
        # @param theme_state [Boolean] Whether dark theme is enabled
        # @return [void]
        def self.apply_theme_to_window(window, theme_state)
          if theme_state
            window.override_background_color(:normal, transparent_background)
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
            notebook.override_background_color(:normal, transparent_background)
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
      end
    end
  end
end
