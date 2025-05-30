# frozen_string_literal: true

# Lich5 Carve out - GTK3 lich-login code stuff
require_relative 'gui/utilities'
require_relative 'gui/authentication'
require_relative 'gui/components'
require_relative 'gui/state'

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

        # Load tab implementations
        require_relative 'gui-saved-login'
        require_relative 'gui-manual-login'

        # Set up notebook with tabs
        setup_notebook

        # Configure window properties
        configure_window

        # Hide optional elements initially
        hide_optional_elements
      }
    end

    # Sets up the notebook with tabs
    #
    # @return [void]
    def setup_notebook
      lightgrey = Gdk::RGBA::parse("#d3d3d3")
      @notebook = Gtk::Notebook.new
      @notebook.override_background_color(:normal, lightgrey) unless @theme_state == true
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
      unless !@launch_data.nil?
        Gtk.queue { Gtk.main_quit }
        Lich.log "info: exited without selection"
        exit
      end

      @launch_data
    end
  end
end
