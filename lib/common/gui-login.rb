# frozen_string_literal: true

require_relative 'gui/accessibility'
require_relative 'gui/account_manager'
require_relative 'gui/account_manager_ui'
require_relative 'gui/authentication'
require_relative 'gui/components'
require_relative 'gui/conversion_ui'
require_relative 'gui/game_selection'
require_relative 'gui/login_tab_utils'
require_relative 'gui/manual_login_tab'
require_relative 'gui/parameter_objects'
require_relative 'gui/password_change'
require_relative 'gui/saved_login_tab'
require_relative 'gui/state'
require_relative 'gui/theme_utils'
require_relative 'gui/utilities'
require_relative 'gui/yaml_state'
require_relative 'gui/yaml_validator'

module Lich
  module Common
    # Provides graphical login functionality for the Lich application
    #
    # This module contains the main entry point for the GUI login system
    # and coordinates the interaction between saved and manual login tabs.
    # It also provides account management functionality.
    def gui_login
      initialize_login_state
      setup_gui_window

      wait_until { @done }

      save_entry_data_if_needed

      return_launch_data_or_exit
    end

    private

    # Initializes the login state variables
    #
    # Sets up all necessary state tracking variables and loads saved entries
    # from the YAML state file.
    #
    # @return [void]
    def initialize_login_state
      @autosort_state = Lich.track_autosort_state
      @tab_layout_state = Lich.track_layout_state
      @theme_state = Lich.track_dark_mode

      # Initialize accessibility support
      Lich::Common::GUI::Accessibility.initialize_accessibility if defined?(Lich::Common::GUI::Accessibility)

      # Use YamlState instead of State for loading saved entries
      @entry_data = Lich::Common::GUI::YamlState.load_saved_entries(DATA_DIR, @autosort_state)
      @launch_data = nil
      @save_entry_data = false
      @done = false

      # Initialize account manager UI
      @account_manager_ui = Lich::Common::GUI::AccountManagerUI.new(DATA_DIR)
    end

    # Sets up the main GUI window and tabs
    #
    # Creates the main window, initializes all tabs, and configures
    # the notebook and window properties.
    #
    # @return [void]
    def setup_gui_window
      Gtk.queue {
        @window = nil

        # Create message dialog utility
        @msgbox = Lich::Common::GUI::Utilities.create_message_dialog(parent: @window, icon: @default_icon)

        # Create tab instances
        create_tab_instances

        # Set up notebook with tabs
        setup_notebook

        # Configure window properties
        configure_window

        # Hide optional elements initially
        hide_optional_elements
      }
    end

    # Creates tab instances for the notebook
    #
    # Initializes the saved login tab, manual login tab, and account management tab
    # with appropriate callbacks and UI elements.
    #
    # @return [void]
    def create_tab_instances
      # Create callbacks for saved login tab
      saved_login_callbacks = {
        on_play: ->(launch_data) {
          @launch_data = launch_data
          # Wrap window destruction in Gtk.queue to ensure it runs on the GTK main thread
          Gtk.queue {
            @window.destroy
            @done = true
          }
        },
        on_remove: ->(login_info) {
          @entry_data.delete(login_info)
          @save_entry_data = true
        },
        on_add_character: ->(character:, instance:, frontend:) {
          # Handle adding a character
        },
        on_theme_change: ->(state) {
          # Update theme state for all components
          @theme_state = state
          @manual_login_tab.update_theme_state(state)

          # Apply theme to notebook and window
          if state
            @notebook.override_background_color(:normal, Gdk::RGBA::parse("rgba(0,0,0,0)"))
            @window.override_background_color(:normal, Gdk::RGBA::parse("rgba(0,0,0,0)"))
          else
            lightgrey = Gdk::RGBA::parse("#d3d3d3")
            @notebook.override_background_color(:normal, lightgrey)
            # Apply button style for light mode
            apply_button_style_for_light_mode
          end
        },
        on_layout_change: ->(state) {
          # Handle layout change
        },
        on_sort_change: ->(state) {
          # Handle sort change
        }
      }

      # Create callbacks for manual login tab
      manual_login_callbacks = {
        on_play: ->(launch_data) {
          @launch_data = launch_data
          # Wrap window destruction in Gtk.queue to ensure it runs on the GTK main thread
          Gtk.queue {
            @window.destroy
            @done = true
          }
        },
        # Audit this function for use in other modules / removal
        on_save: ->(launch_data) {
          @entry_data.push(launch_data)
          @save_entry_data = true
        },
        on_error: ->(message) {
          @msgbox.call(message)
        }
      }

      # Create tab instances
      @saved_login_tab = Lich::Common::GUI::SavedLoginTab.new(
        @window,
        @entry_data,
        @theme_state,
        @tab_layout_state,
        @autosort_state,
        @default_icon,
        saved_login_callbacks
      )

      @manual_login_tab = Lich::Common::GUI::ManualLoginTab.new(
        @window,
        @entry_data,
        @theme_state,
        @default_icon,
        manual_login_callbacks
      )

      # Get UI elements from tabs
      @saved_login_ui = @saved_login_tab.ui_elements
      @manual_login_ui = @manual_login_tab.ui_elements

      # Set references to UI elements
      @quick_game_entry_tab = @saved_login_tab.tab_widget
      @game_entry_tab = @manual_login_tab.tab_widget
      @custom_launch_entry = @manual_login_ui[:custom_launch_entry]
      @custom_launch_dir = @manual_login_ui[:custom_launch_dir]
      @bonded_pair_char = @saved_login_ui[:bonded_pair_char]
      @bonded_pair_inst = @saved_login_ui[:bonded_pair_inst]
      @slider_box = @saved_login_ui[:slider_box]
    end

    # Sets up the notebook with tabs
    #
    # Creates the notebook widget and adds all tabs to it.
    #
    # @return [void]
    def setup_notebook
      @notebook = Gtk::Notebook.new

      # Apply initial theme
      if @theme_state
        @notebook.override_background_color(:normal, Gdk::RGBA::parse("rgba(0,0,0,0)"))
      else
        lightgrey = Gdk::RGBA::parse("#d3d3d3")
        @notebook.override_background_color(:normal, lightgrey)
        # Apply button style for light mode
        apply_button_style_for_light_mode
      end

      # Add the saved entry and manual entry tabs
      @notebook.append_page(@quick_game_entry_tab, Gtk::Label.new('Saved Entry'))
      @notebook.append_page(@game_entry_tab, Gtk::Label.new('Manual Entry'))

      # Create account management tab using AccountManagerUI
      account_notebook = Gtk::Notebook.new
      @account_mgmt_tab = Gtk::Box.new(:vertical, 10)
      @account_mgmt_tab.border_width = 10

      # Delegate account management tab creation to AccountManagerUI
      @account_manager_ui.create_accounts_tab(account_notebook)
      @account_manager_ui.create_add_character_tab(account_notebook)
      @account_manager_ui.create_add_account_tab(account_notebook)

      # Add the notebook to the box
      @account_mgmt_tab.pack_start(account_notebook, expand: true, fill: true, padding: 0)

      # Add the account management tab to the main notebook
      @notebook.append_page(@account_mgmt_tab, Gtk::Label.new('Account Management'))

      # Set tab position
      @notebook.set_tab_pos(:top)

      # Add keyboard navigation support for accessibility
      if defined?(Lich::Common::GUI::Accessibility)
        Lich::Common::GUI::Accessibility.add_keyboard_navigation(@notebook)
      end
    end

    # Configures the main window properties
    #
    # Sets up the window title, size, and other properties.
    #
    # @return [void]
    def configure_window
      @window = Gtk::Window.new(:toplevel)
      @window.set_icon(@default_icon)
      @window.title = "Lich v#{LICH_VERSION}"
      @window.border_width = 5
      @window.add(@notebook)
      @window.signal_connect('delete_event') { @window.destroy; @done = true }
      @window.default_width = 590
      @window.default_height = 550

      # Apply initial theme to window
      if @theme_state
        @window.override_background_color(:normal, Gdk::RGBA::parse("rgba(0,0,0,0)"))
      else
        lightgrey = Gdk::RGBA::parse("#d3d3d3")
        @window.override_background_color(:normal, lightgrey)
        # Apply button style for light mode
        apply_button_style_for_light_mode
      end

      # Add accessibility support for the window
      if defined?(Lich::Common::GUI::Accessibility)
        Lich::Common::GUI::Accessibility.make_window_accessible(
          @window,
          "Lich Login",
          "Login window for Lich"
        )
      end

      unless Lich::Common::GUI::ConversionUI.conversion_needed?(DATA_DIR)
        @window.show_all
      else
        # no YAML file, conversion required
        # Show conversion dialog first
        Lich::Common::GUI::ConversionUI.show_conversion_dialog(@window, DATA_DIR, -> {
          # After conversion, create the account management tab
          initialize_login_state
          setup_gui_window
          @window.show_all
        })
      end
    end

    # Applies button style for light mode
    #
    # Sets a lighter background color for buttons when in light mode.
    #
    # @return [void]
    def apply_button_style_for_light_mode
      # Use a slightly whiter shade for buttons in light mode
      whitergrey = Gdk::RGBA::parse("#f0f0f0")

      # Apply to all buttons in saved login tab
      apply_style_to_buttons(@saved_login_ui, whitergrey)

      # Apply to all buttons in manual login tab
      apply_style_to_buttons(@manual_login_ui, whitergrey)
    end

    # Applies style to buttons in a UI element collection
    #
    # @param ui_elements [Hash] Hash of UI elements
    # @param color [Gdk::RGBA] Color to apply to buttons
    # @return [void]
    def apply_style_to_buttons(ui_elements, color)
      ui_elements.each do |_key, element|
        if element.is_a?(Gtk::Button)
          element.override_background_color(:normal, color)
        end
      end
    end

    # Hides optional UI elements
    #
    # Hides UI elements that are not needed initially.
    #
    # @return [void]
    def hide_optional_elements
      @custom_launch_entry.visible = false
      @custom_launch_dir.visible = false
      @bonded_pair_char.visible = false
      @bonded_pair_inst.visible = false
      @slider_box.visible = false

      @notebook.set_page(1) if @entry_data.empty?
    end

    # Saves entry data if needed
    #
    # Saves the entry data to the YAML state file if changes were made.
    #
    # @return [void]
    def save_entry_data_if_needed
      if @save_entry_data
        # Use YamlState instead of State for saving entries
        Lich::Common::GUI::YamlState.save_entries(DATA_DIR, @entry_data)
      end
      @entry_data = nil
    end

    # Returns launch data or exits
    #
    # Returns the launch data if available, otherwise exits the application.
    #
    # @return [Array, nil] Launch data if available
    def return_launch_data_or_exit
      if @launch_data.nil?
        Gtk.queue { Gtk.main_quit }
        exit
      end

      @launch_data
    end
  end
end
