# frozen_string_literal: true

# Lich5 Carve out - GTK3 lich-login code stuff
require_relative 'gui/utilities'
require_relative 'gui/authentication'
require_relative 'gui/components'
require_relative 'gui/state'
require_relative 'gui/saved_login_tab'
require_relative 'gui/manual_login_tab'

module Lich
  module Common
    # Provides graphical login functionality for the Lich application
    #
    # This module contains the main entry point for the GUI login system
    # and coordinates the interaction between saved and manual login tabs.
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
    # @return [void]
    def initialize_login_state
      @autosort_state = Lich.track_autosort_state
      @tab_layout_state = Lich.track_layout_state
      @theme_state = Lich.track_dark_mode

      @entry_data = GUI::State.load_saved_entries(DATA_DIR, @autosort_state)
      @launch_data = nil
      @save_entry_data = false
      @done = false

      # Initialize install_tab_loaded as an instance variable to ensure proper scope
      @install_tab_loaded = false
    end

    # Sets up the main GUI window and tabs
    #
    # @return [void]
    def setup_gui_window
      Gtk.queue {
        @window = nil

        # Create message dialog utility
        @msgbox = GUI::Utilities.create_message_dialog(parent: @window, icon: @default_icon)

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

    # Creates tab instances
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
            @window.override_background_color(:normal, lightgrey)
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
        on_save_entry: ->(entry_data) {
          @entry_data.push(entry_data)
          @save_entry_data = true
        },
        on_error: ->(message) {
          @msgbox.call(message)
        }
      }

      # Create tab instances
      @saved_login_tab = GUI::SavedLoginTab.new(
        @window,
        @entry_data,
        @theme_state,
        @tab_layout_state,
        @autosort_state,
        @default_icon,
        saved_login_callbacks
      )

      @manual_login_tab = GUI::ManualLoginTab.new(
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
    # @return [void]
    def setup_notebook
      @notebook = Gtk::Notebook.new

      # Apply initial theme
      if @theme_state
        @notebook.override_background_color(:normal, Gdk::RGBA::parse("rgba(0,0,0,0)"))
      else
        lightgrey = Gdk::RGBA::parse("#d3d3d3")
        @notebook.override_background_color(:normal, lightgrey)
      end

      @notebook.append_page(@quick_game_entry_tab, Gtk::Label.new('Saved Entry'))
      @notebook.append_page(@game_entry_tab, Gtk::Label.new('Manual Entry'))

      @notebook.signal_connect('switch-page') { |_who, _page, page_num|
        if (page_num == 2) and not @install_tab_loaded
          refresh_button.clicked
        end
      }
    end

    # Configures the main window properties
    #
    # @return [void]
    def configure_window
      @window = Gtk::Window.new
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
      end

      @window.show_all
    end

    # Hides optional UI elements
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
    # @return [void]
    def save_entry_data_if_needed
      if @save_entry_data
        GUI::State.save_entries(DATA_DIR, @entry_data)
      end
      @entry_data = nil
    end

    # Returns launch data or exits
    #
    # @return [Array, nil] Launch data if available
    def return_launch_data_or_exit
      if @launch_data.nil?
        Gtk.queue { Gtk.main_quit }
        Lich.log "info: exited without selection"
        exit
      end

      @launch_data
    end
  end
end
