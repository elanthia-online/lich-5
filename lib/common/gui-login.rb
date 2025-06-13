# frozen_string_literal: true

require_relative 'gui/accessibility'
require_relative 'gui/account_manager'
require_relative 'gui/account_manager_ui'
require_relative 'gui/authentication'
require_relative 'gui/components'
require_relative 'gui/conversion_ui'
require_relative 'gui/favorites_manager'
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
require_relative 'gui/tab_communicator'

module Lich
  module Common
    # Provides graphical login functionality for the Lich application
    #
    # This module contains the main entry point for the GUI login system
    # and coordinates the interaction between saved and manual login tabs.
    # It also provides account management functionality.
    # Enhanced with cross-tab communication for data synchronization and
    # targeted refresh capability for post-conversion scenarios.
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
    # from the YAML state file. Also initializes cross-tab communication.
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

      # Initialize cross-tab communication
      @tab_communicator = Lich::Common::GUI::TabCommunicator.new

      # Initialize account manager UI
      @account_manager_ui = Lich::Common::GUI::AccountManagerUI.new(DATA_DIR)
    end

    # Refreshes the window after conversion without creating duplicate windows
    #
    # Reloads entry data and refreshes existing UI elements while preserving
    # the current window structure. This prevents duplicate window creation
    # that occurs with full reinitialization. Enhanced to properly enable
    # favorites display and populate account management data.
    #
    # @return [void]
    def refresh_window_after_conversion
      begin
        # Reload entry data from newly created YAML file
        @entry_data = Lich::Common::GUI::YamlState.load_saved_entries(DATA_DIR, @autosort_state)

        # Enable favorites in saved login tab if YAML file now exists
        if @saved_login_tab
          # Force enable favorites since YAML file now exists
          @saved_login_tab.favorites_enabled = true
          @saved_login_tab.refresh_data
        end

        # Refresh manual login tab if it needs entry data updates
        if @manual_login_tab && @manual_login_tab.respond_to?(:refresh_data)
          @manual_login_tab.refresh_data
        end

        # Update entry data reference for manual login tab
        if @manual_login_tab && @manual_login_tab.respond_to?(:update_entry_data)
          @manual_login_tab.update_entry_data(@entry_data)
        end

        # Trigger account management refresh by programmatically clicking refresh button
        trigger_account_management_refresh

        # Update UI elements visibility based on new data
        update_ui_elements_after_conversion

        # Ensure window is visible and properly displayed
        if @window
          @window.show_all
          @window.present # Bring window to front
        end

        # Hide optional elements after show_all to ensure proper visibility state
        hide_optional_elements

        # Switch to saved entry tab if we now have data
        if @notebook && !@entry_data.empty?
          @notebook.set_page(0) # Switch to Saved Entry tab
        end

        # Notify via tab communicator that conversion refresh occurred
        @tab_communicator.notify_data_changed(:conversion_complete, {
          entries_count: @entry_data.length
        })

        Lich.log "info: Window refreshed after conversion with #{@entry_data.length} entries"
      rescue StandardError => e
        Lich.log "error: Error refreshing window after conversion: #{e.message}"

        # Fallback to showing error message
        if @msgbox
          @msgbox.call("Conversion completed but failed to refresh window: #{e.message}")
        end
      end
    end

    # Triggers the account management refresh by finding and clicking the refresh button
    #
    # Locates the refresh button in the account management tab and programmatically
    # triggers it to populate the accounts view with the new YAML data.
    #
    # @return [void]
    def trigger_account_management_refresh
      return unless @account_mgmt_tab

      begin
        # Find the refresh button in the account management tab
        refresh_button = find_refresh_button_in_container(@account_mgmt_tab)

        if refresh_button
          # Programmatically click the refresh button
          refresh_button.clicked
          Lich.log "info: Account management refresh triggered successfully"
        else
          Lich.log "warning: Could not find refresh button in account management tab"
        end
      rescue StandardError => e
        Lich.log "error: Error triggering account management refresh: #{e.message}"
      end
    end

    # Recursively finds the refresh button in a container widget
    #
    # Searches through the widget hierarchy to locate the refresh button
    # in the account management tab.
    #
    # @param container [Gtk::Container] Container to search
    # @return [Gtk::Button, nil] Found refresh button or nil
    def find_refresh_button_in_container(container)
      return nil unless container.respond_to?(:each)

      container.each do |child|
        # Check if this child is a refresh button
        if child.is_a?(Gtk::Button) && child.label == "Refresh"
          return child
        end

        # Recursively search in child containers
        if child.respond_to?(:each)
          result = find_refresh_button_in_container(child)
          return result if result
        end
      end

      nil
    end

    # Updates UI element visibility after conversion
    #
    # Adjusts the visibility and state of UI elements based on the
    # newly loaded entry data after conversion.
    #
    # @return [void]
    def update_ui_elements_after_conversion
      return unless @entry_data

      # Show/hide optional elements based on data availability
      if @entry_data.empty?
        # No data - keep elements hidden and show manual entry tab
        hide_optional_elements
      else
        # Data available - elements should still be hidden initially
        # Optional elements visibility is managed by individual tabs
        # but we ensure they start in the correct hidden state
      end
    end

    # Sets up the main GUI window and tabs
    #
    # Creates the main window, initializes all tabs, and configures
    # the notebook and window properties. Also sets up cross-tab communication.
    #
    # @return [void]
    def setup_gui_window
      Gtk.queue {
        @window = nil

        # Create message dialog utility
        @msgbox = Lich::Common::GUI::Utilities.create_message_dialog(parent: @window, icon: @default_icon)

        # Create tab instances
        create_tab_instances

        # Set up cross-tab communication
        setup_cross_tab_communication

        # Set up notebook with tabs
        setup_notebook

        # Configure window properties
        configure_window

        # Hide optional elements initially
        hide_optional_elements
      }
    end

    # Sets up cross-tab communication between tabs
    #
    # Configures the communication system that allows tabs to notify
    # each other of data changes for real-time synchronization.
    # Enhanced to include manual login tab cache refresh for account/character removal events.
    #
    # @return [void]
    def setup_cross_tab_communication
      # Register saved login tab for data change notifications
      @tab_communicator.register_data_change_callback(->(change_type, data) {
        # Refresh main GUI entry data cache to prevent stale data issues
        @entry_data = Lich::Common::GUI::YamlState.load_saved_entries(DATA_DIR, @autosort_state)

        # Refresh saved login tab for all data changes to ensure synchronization
        @saved_login_tab.refresh_data if @saved_login_tab

        # Refresh manual login tab cache when accounts are removed to prevent stale data
        if @manual_login_tab && (change_type == :account_removed || change_type == :character_removed)
          @manual_login_tab.refresh_entry_data
        end

        Lich.log "info: Data change notification (cache and UI refreshed): #{change_type} - #{data}"
      })

      # Set up account manager to notify of data changes
      @account_manager_ui.set_data_change_callback(->(change_type, data) {
        @tab_communicator.notify_data_changed(change_type, data)
      })

      # Register account manager to receive data change notifications
      @account_manager_ui.register_for_notifications(@tab_communicator)
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
          # Find entry by key identifying fields instead of exact hash equality
          entry_to_remove = GUI::YamlState.find_entry_in_legacy_format(
            @entry_data,
            login_info[:user_id],
            login_info[:char_name],
            login_info[:game_code],
            login_info[:frontend]
          )

          if entry_to_remove
            @entry_data.delete(entry_to_remove)

            # IMMEDIATELY save to YAML before notifying to ensure refresh_data sees updated file
            Lich::Common::GUI::YamlState.save_entries(DATA_DIR, @entry_data)

            # Create sanitized entry for notification (without password)
            sanitized_entry = login_info.dup
            sanitized_entry.delete(:password)
            @tab_communicator.notify_data_changed(:character_removed, { entry: sanitized_entry })
          else
            Lich.log "warning: Could not find entry to remove: #{login_info}"
          end
        },
        on_add_character: ->(character:, instance:, frontend:) {
          # Handle adding a character
        },
        on_theme_change: ->(state) {
          # Update theme state for all components
          @theme_state = state
          @manual_login_tab.update_theme_state(state)
          @saved_login_tab.update_theme_state(state)

          # Apply theme to notebook and window
          if state
            @notebook.override_background_color(:normal, GUI::ThemeUtils.darkmode_background)
            @window.override_background_color(:normal, GUI::ThemeUtils.darkmode_background)
          else
            @notebook.override_background_color(:normal, GUI::ThemeUtils.light_theme_background)
            @window.override_background_color(:normal, GUI::ThemeUtils.light_theme_background)
            # Apply button style for light mode
            apply_button_style_for_light_mode
          end
        },
        on_layout_change: ->(state) {
          # Handle layout change
        },
        on_sort_change: ->(state) {
          # Handle sort change
        },
        on_favorites_change: ->(username:, char_name:, game_code:, is_favorite:) {
          # Handle favorite status change - notify other tabs
          @tab_communicator.notify_data_changed(:favorite_toggled, {
            account: username,
            character: char_name,
            game_code: game_code,
            is_favorite: is_favorite
          })
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
        # Handles successful login data saving from manual login tab
        # Optimized to reduce redundant cache refreshes
        #
        # @param launch_data [Hash] Login data that was saved (for notification only)
        on_save: ->(launch_data) {
          # Only refresh cache if we don't already have the latest data
          # This prevents redundant file I/O operations
          @entry_data = Lich::Common::GUI::YamlState.load_saved_entries(DATA_DIR, @autosort_state)
          @save_entry_data = true

          # Notify other tabs of data change
          @tab_communicator.notify_data_changed(:entry_added, { entry: launch_data })
        },
        on_error: ->(message) {
          @msgbox.call(message)
        }
      }

      # Create tab instances with favorites support
      @saved_login_tab = Lich::Common::GUI::SavedLoginTab.new(
        @window,
        @entry_data,
        @theme_state,
        @tab_layout_state,
        @autosort_state,
        @default_icon,
        DATA_DIR,
        saved_login_callbacks
      )

      @manual_login_tab = Lich::Common::GUI::ManualLoginTab.new(
        @window,
        @entry_data,
        @theme_state,
        @default_icon,
        DATA_DIR,
        manual_login_callbacks,
        @autosort_state
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
        @notebook.override_background_color(:normal, GUI::ThemeUtils.darkmode_background)
      else
        @notebook.override_background_color(:normal, GUI::ThemeUtils.light_theme_background)
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
    # Enhanced with targeted refresh for post-conversion scenarios.
    #
    # @return [void]
    def configure_window
      @window = Gtk::Window.new(:toplevel)
      @window.set_icon(@default_icon)
      @window.title = "Lich v#{LICH_VERSION}"
      @window.border_width = 5
      @window.add(@notebook)
      @window.signal_connect('delete_event') {
        # Clean up cross-tab communication
        @tab_communicator.clear_callbacks if @tab_communicator
        @window.destroy
        @done = true
      }

      # Apply initial theme to window
      if @theme_state
        @window.override_background_color(:normal, GUI::ThemeUtils.darkmode_background)
      else
        @window.override_background_color(:normal, GUI::ThemeUtils.light_theme_background)
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
        # YAML file conversion required
        # Show conversion dialog with targeted refresh callback
        Lich::Common::GUI::ConversionUI.show_conversion_dialog(@window, DATA_DIR, -> {
          # After conversion, refresh existing window instead of creating new one
          refresh_window_after_conversion
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
    # Enhanced to ensure proper visibility state after window refresh.
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
    # Saves the entry data to the YAML file if there are unsaved changes.
    # Optimized to avoid redundant operations.
    #
    # @return [void]
    def save_entry_data_if_needed
      if @save_entry_data
        # Save entry data - optimized to avoid redundant cache refresh
        Lich::Common::GUI::YamlState.save_entries(DATA_DIR, @entry_data)
        @save_entry_data = false
      end
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
