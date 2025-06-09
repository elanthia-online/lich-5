# frozen_string_literal: true

require_relative 'favorites_manager'
require_relative 'parameter_objects'
require_relative 'login_tab_utils'
require_relative 'theme_utils'

module Lich
  module Common
    module GUI
      # Handles the "Saved Entry" tab functionality for the Lich GUI login system
      # Enhanced with integrated favorites functionality for seamless user experience
      # Now includes data refresh capability for cross-tab synchronization
      class SavedLoginTab
        # Initializes a new SavedLoginTab instance with favorites support
        #
        # @param parent [Object] Parent window or container
        # @param entry_data [Array] Array of saved login entries
        # @param theme_state [Boolean] Whether dark theme is enabled
        # @param tab_layout_state [Boolean] Whether tab layout is enabled
        # @param autosort_state [Boolean] Whether auto-sorting is enabled
        # @param default_icon [Gdk::Pixbuf] Default icon for dialogs
        # @param data_dir [String] Directory containing entry data for favorites management
        # @param callbacks [Hash, CallbackParams] Callback handlers for various events
        # @return [SavedLoginTab] New instance
        def initialize(parent, entry_data, theme_state, tab_layout_state, autosort_state, default_icon, data_dir, callbacks = {})
          @parent = parent
          @entry_data = entry_data
          @default_icon = default_icon
          @data_dir = data_dir

          # Convert UI configuration to UIConfig object
          @ui_config = UIConfig.new(
            theme_state: theme_state,
            tab_layout_state: tab_layout_state,
            autosort_state: autosort_state
          )

          # Convert callbacks hash to CallbackParams if needed
          @callbacks = if callbacks.is_a?(CallbackParams)
                         callbacks
                       else
                         CallbackParams.new(callbacks)
                       end

          # Initialize favorites functionality
          @favorites_enabled = FavoritesManager.favorites_available?(@data_dir)
          @show_favorites_first = true # Default to showing favorites first

          # Apply theme settings
          ThemeUtils.apply_theme_settings(@ui_config.theme_state)

          # Create the tab content
          create_tab_content
        end

        # Refreshes the tab data while preserving UI state
        # Reloads entry data from YAML and rebuilds data-dependent UI elements
        # while maintaining user's current selections and scroll position
        #
        # @return [void]
        def refresh_data
          # Save current UI state before refresh
          saved_state = save_current_ui_state

          # Reload data from YAML
          @entry_data = Lich::Common::GUI::YamlState.load_saved_entries(@data_dir, @ui_config.autosort_state)

          # Rebuild the tab content with new data
          rebuild_tab_content

          # Restore UI state after rebuild
          restore_ui_state(saved_state)

          # Hide the global settings slider box to ensure proper visibility state
          @slider_box.visible = false if @slider_box

          # Show brief refresh notification
          show_refresh_notification
        end

        # Returns the tab widget for adding to a notebook
        #
        # @return [Gtk::Widget] The tab widget
        def tab_widget
          @quick_game_entry_tab
        end

        # Returns references to UI elements that need to be accessed externally
        #
        # @return [Hash] Hash of UI element references
        def ui_elements
          {
            custom_launch_entry: @custom_launch_entry,
            custom_launch_dir: @custom_launch_dir,
            bonded_pair_char: @bonded_pair_char,
            bonded_pair_inst: @bonded_pair_inst,
            slider_box: @slider_box,
            notebook: @notebook,
            account_book: @account_book
          }
        end

        # Updates the theme state and refreshes UI elements accordingly
        #
        # @param theme_state [Boolean] New theme state
        # @return [void]
        def update_theme_state(theme_state)
          @ui_config.theme_state = theme_state
          apply_theme_to_ui_elements
        end

        private

        # Saves the current UI state for restoration after refresh
        # Captures selection state, scroll position, and expanded sections
        #
        # @return [Hash] Hash containing current UI state
        def save_current_ui_state
          state = {
            selected_entry: nil,
            scroll_position: nil,
            expanded_sections: [],
            active_tab: nil
          }

          # Save scroll position if scrolled window exists
          if @quick_game_entry_tab && @quick_game_entry_tab.children.first.is_a?(Gtk::ScrolledWindow)
            scrolled_window = @quick_game_entry_tab.children.first
            state[:scroll_position] = scrolled_window.vadjustment.value if scrolled_window.vadjustment
          end

          # Save active tab if using tabbed layout
          if @account_book
            state[:active_tab] = @account_book.page
          end

          state
        end

        # Rebuilds the tab content with current entry data
        # Clears existing content and recreates all UI elements
        #
        # @return [void]
        def rebuild_tab_content
          # Clear existing content
          @quick_game_entry_tab.children.each { |child| @quick_game_entry_tab.remove(child) }

          # Recreate tab content with current data
          if @entry_data.empty?
            create_empty_tab_content
          else
            create_populated_tab_content
          end

          # Show all new content
          @quick_game_entry_tab.show_all
        end

        # Restores UI state after refresh
        # Restores selections, scroll position, and other UI state
        #
        # @param saved_state [Hash] Previously saved UI state
        # @return [void]
        def restore_ui_state(saved_state)
          return unless saved_state

          # Restore scroll position
          if saved_state[:scroll_position] && @quick_game_entry_tab.children.first.is_a?(Gtk::ScrolledWindow)
            scrolled_window = @quick_game_entry_tab.children.first
            Gtk.queue do
              scrolled_window.vadjustment.value = saved_state[:scroll_position] if scrolled_window.vadjustment
            end
          end

          # Restore active tab
          if saved_state[:active_tab] && @account_book
            Gtk.queue do
              @account_book.page = saved_state[:active_tab] if saved_state[:active_tab] < @account_book.n_pages
            end
          end
        end

        # Shows a brief notification that refresh occurred
        # Provides visual feedback to user that data was refreshed
        #
        # @return [void]
        def show_refresh_notification
          # Create temporary status message
          # This could be enhanced with a status bar or toast notification
          Lich.log "info: Saved entries refreshed from YAML data"
        end

        # Creates empty tab content when no saved entries exist
        # Displays a simple message when no saved entries are available
        #
        # @return [void]
        def create_empty_tab_content
          box = Gtk::Box.new(:horizontal)
          box.pack_start(Gtk::Label.new('You have no saved login info.'), expand: true, fill: true, padding: 5)
          @quick_game_entry_tab.pack_start(box, expand: true, fill: true, padding: 0)
        end

        # Creates populated tab content with saved login entries
        # Builds a tab with all saved login entries organized by account
        # Includes refresh button for manual data refresh
        #
        # @return [void]
        def create_populated_tab_content
          last_user_id = nil

          # Create the appropriate layout based on settings
          quick_sw = if @ui_config.tab_layout_state
                       create_tabbed_layout
                     else
                       create_list_layout(last_user_id)
                     end

          # Create toggle button styling
          @togglebutton_provider = LoginTabUtils.create_toggle_button_css_provider

          # Create character management components
          create_character_management_components

          # Add main content to tab
          @quick_game_entry_tab.pack_start(quick_sw, expand: true, fill: true, padding: 5)

          # Create and add refresh button
          create_refresh_button

          # Create and add global settings components
          create_global_settings_components
        end

        # Creates a refresh button for manual data refresh
        # Adds a button that allows users to manually refresh the saved entries
        #
        # @return [void]
        def create_refresh_button
          refresh_button = Gtk::Button.new(label: "Refresh Entries")
          refresh_button.tooltip_text = "Reload saved entries from file"

          # Apply button styling if available
          if @button_provider
            refresh_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)
          end

          # Set up refresh button handler
          refresh_button.signal_connect('clicked') do
            refresh_data
          end

          # Create button container
          button_container = Gtk::Box.new(:horizontal)
          button_container.pack_start(refresh_button, expand: false, fill: false, padding: 5)

          # Add to tab
          @quick_game_entry_tab.pack_start(button_container, expand: false, fill: false, padding: 5)
        end

        # Applies the current theme state to all UI elements
        # Updates the appearance of UI elements based on dark/light theme setting
        #
        # @return [void]
        def apply_theme_to_ui_elements
          ui_elements = {
            play_button: @play_button,
            account_book: @account_book,
            notebook: @notebook
          }

          providers = {
            button: @button_provider,
            tab: @tab_provider
          }

          LoginTabUtils.apply_theme_to_ui_elements(@ui_config.theme_state, ui_elements, providers)
        end

        # Creates the tab content
        # Builds the main UI elements for the saved login tab
        #
        # @return [void]
        def create_tab_content
          if @entry_data.empty?
            create_empty_tab
          else
            create_populated_tab
          end
        end

        # Creates an empty tab when no saved entries exist
        # Displays a simple message when no saved entries are available
        #
        # @return [void]
        def create_empty_tab
          box = Gtk::Box.new(:horizontal)
          box.pack_start(Gtk::Label.new('You have no saved login info.'), expand: true, fill: true, padding: 5)
          @quick_game_entry_tab = Gtk::Box.new(:vertical)
          @quick_game_entry_tab.border_width = 5
          @quick_game_entry_tab.pack_start(box, expand: true, fill: true, padding: 0)
        end

        # Creates a populated tab with saved login entries
        # Builds a tab with all saved login entries organized by account
        #
        # @return [void]
        def create_populated_tab
          last_user_id = nil

          # Create the appropriate layout based on settings
          quick_sw = if @ui_config.tab_layout_state
                       create_tabbed_layout
                     else
                       create_list_layout(last_user_id)
                     end

          # Create toggle button styling
          @togglebutton_provider = LoginTabUtils.create_toggle_button_css_provider

          # Create character management components
          create_character_management_components

          # Create main tab container
          @quick_game_entry_tab = Gtk::Box.new(:vertical)
          @quick_game_entry_tab.border_width = 5
          @quick_game_entry_tab.pack_start(quick_sw, expand: true, fill: true, padding: 5)

          # Create and add refresh button
          create_refresh_button

          # Create and add global settings components
          create_global_settings_components
        end

        # Creates a tabbed layout for accounts with favorites support
        # Organizes saved entries in tabs by account, with a dedicated FAVORITES tab
        #
        # @return [Gtk::ScrolledWindow] Scrolled window containing the account notebook
        def create_tabbed_layout
          @account_book = Gtk::Notebook.new
          @account_book.set_tab_pos(:left)
          @account_book.show_border = true

          # Apply theme styling
          unless @ui_config.theme_state
            @account_book.override_background_color(:normal, ThemeUtils.light_theme_background)
            @tab_provider = Utilities.create_tab_css_provider
          end

          # Create FAVORITES tab if favorites are enabled and exist
          if @favorites_enabled
            create_favorites_tab
          end

          # Process each unique account
          account_array = @entry_data.map { |x| x[:user_id] }.uniq
          account_array.each { |account|
            last_game_name = nil
            account_box = Gtk::Box.new(:vertical, 0)

            # Process each login entry for this account
            @entry_data.each { |login_info|
              next if login_info[:user_id] != account

              # Add separator between different games
              if login_info[:game_name] != last_game_name
                horizontal_separator = Gtk::Separator.new(:horizontal)
                account_box.pack_start(horizontal_separator, expand: false, fill: false, padding: 3)
              end
              last_game_name = login_info[:game_name]

              # Create character entry
              create_character_entry(account_box, login_info)
            }

            # Add account tab to notebook
            @account_book.append_page(account_box, Gtk::Label.new(account.upcase))
            @account_book.set_tab_reorderable(account_box, true)
          }

          # Create scrolled window for account book
          quick_sw = Gtk::ScrolledWindow.new
          quick_sw.set_policy(:never, :automatic)
          quick_sw.add(@account_book)

          quick_sw
        end

        # Creates a dedicated favorites tab showing all favorite characters
        # @return [void]
        def create_favorites_tab
          favorites_box = Gtk::Box.new(:vertical, 0)

          # Get all favorite characters with frontend precision
          favorite_entries = @entry_data.select do |login_info|
            FavoritesManager.is_favorite?(@data_dir, login_info[:user_id], login_info[:char_name], login_info[:game_code], login_info[:frontend])
          end

          # Sort favorites by favorite_order if available, then by character name
          favorite_entries.sort! do |a, b|
            a_order = a[:favorite_order] || 999999
            b_order = b[:favorite_order] || 999999

            if a_order == b_order
              a[:char_name] <=> b[:char_name]
            else
              a_order <=> b_order
            end
          end

          # Add favorites to the tab
          if favorite_entries.empty?
            # Show message when no favorites exist
            no_favorites_label = Gtk::Label.new("No favorite characters yet.\n\nMark characters as favorites using the ★ button\nin the account tabs or saved entries list.")
            no_favorites_label.set_justify(:center)
            no_favorites_label.set_margin_top(50)
            no_favorites_label.set_margin_bottom(50)
            favorites_box.pack_start(no_favorites_label, expand: true, fill: true, padding: 20)
          else
            # Add each favorite character directly without account grouping
            favorite_entries.each do |login_info|
              create_character_entry(favorites_box, login_info)
            end
          end

          # Create scrolled window and add to notebook
          scrolled_window = Gtk::ScrolledWindow.new
          scrolled_window.set_policy(:never, :automatic)
          scrolled_window.add(favorites_box)

          @account_book.prepend_page(scrolled_window, Gtk::Label.new("★ FAVORITES"))
        end

        # Creates a list layout for accounts (non-tabbed)
        # Organizes saved entries in a flat list grouped by account
        #
        # @param last_user_id [String] Last processed user ID
        # @return [Gtk::ScrolledWindow] Scrolled window containing the account list
        def create_list_layout(last_user_id)
          quick_box = Gtk::Box.new(:vertical, 0)

          # Process each login entry
          @entry_data.each { |login_info|
            # Convert to LoginParams object for consistency
            login_params = LoginParams.new(login_info)

            # Add account header if this is a new account
            if login_params.user_id.downcase != last_user_id
              last_user_id = login_params.user_id.downcase
              quick_box.pack_start(Gtk::Label.new("Account: " + last_user_id), expand: false, fill: false, padding: 6)
            end

            # Create character entry with play and remove buttons
            if login_params.custom_launch && !login_params.custom_launch.empty?
              frontend_display = 'Custom'
            else
              frontend_display = login_params.frontend.capitalize == 'Stormfront' ? 'Wrayth' : login_params.frontend.capitalize
            end

            label = Gtk::Label.new("#{login_params.char_name} (#{login_params.game_name}, #{frontend_display})")
            play_button = Components.create_button(label: 'Play')
            remove_button = Components.create_button(label: 'X')

            # Apply button styling
            @button_provider = LoginTabUtils.create_button_css_provider
            remove_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)
            play_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)

            # Create character box with label and buttons
            char_box = Gtk::Box.new(:horizontal)
            char_box.pack_start(label, expand: false, fill: false, padding: 0)
            char_box.pack_end(remove_button, expand: false, fill: false, padding: 0)
            char_box.pack_end(play_button, expand: false, fill: false, padding: 0)
            quick_box.pack_start(char_box, expand: false, fill: false, padding: 0)

            # Set up button handlers
            LoginTabUtils.setup_play_button_handler(play_button, login_params.to_h, @callbacks.on_play)
            LoginTabUtils.setup_remove_button_handler(remove_button, login_params.to_h, char_box, @default_icon, @callbacks.on_remove)
          }

          # Create scrolled viewport for character list
          adjustment = Gtk::Adjustment.new(0, 0, 1000, 5, 20, 500)
          quick_vp = Gtk::Viewport.new(adjustment, adjustment)
          quick_vp.add(quick_box)

          quick_sw = Gtk::ScrolledWindow.new
          quick_sw.set_policy(:never, :automatic)
          quick_sw.add(quick_vp)

          quick_sw
        end

        # Creates a character entry in the tabbed layout
        # Builds a UI element for a single character entry
        #
        # @param account_box [Gtk::Box] Box to add the character entry to
        # @param login_info [Hash] Login information for the character
        # Creates a character entry with favorites support
        # Builds UI elements for a single character with play, remove, and favorites buttons
        # Enhanced with favorites functionality and visual indicators
        #
        # @param account_box [Gtk::Box] Container for the character entry
        # @param login_info [Hash] Character login information
        # @return [void]
        def create_character_entry(account_box, login_info)
          # Convert to LoginParams object for consistency
          login_params = LoginParams.new(login_info)

          # Check if this character is a favorite with frontend precision
          is_favorite = @favorites_enabled &&
                        FavoritesManager.is_favorite?(@data_dir, login_info[:user_id], login_info[:char_name], login_info[:game_code], login_info[:frontend])

          # Get realm name from game code
          realm = Utilities.game_code_to_realm(login_params.game_code)

          # Create button styling
          @button_provider = LoginTabUtils.create_button_css_provider(font_size: 14)

          # Create play button with character info
          @play_button = Gtk::Button.new()

          # Add favorite indicator to character name if it's a favorite
          char_name_text = is_favorite ? "★ #{login_params.char_name}" : login_params.char_name
          char_label = Gtk::Label.new(char_name_text)
          char_label.set_width_chars(15)

          if login_params.custom_launch && !login_params.custom_launch.empty?
            frontend_display = 'Custom'
          else
            frontend_display = login_params.frontend.capitalize == 'Stormfront' ? 'Wrayth' : login_params.frontend.capitalize
          end

          fe_label = Gtk::Label.new("(#{frontend_display})")
          fe_label.set_width_chars(15)
          instance_label = Gtk::Label.new(realm)
          instance_label.set_width_chars(10)
          char_label.set_alignment(0, 0.5)

          # Apply favorite styling to play button if character is a favorite
          if is_favorite
            @play_button.style_context.add_class('favorite-character')
          end

          # Layout button contents
          button_row = Gtk::Paned.new(:horizontal)
          button_inset = Gtk::Paned.new(:horizontal)
          button_inset.pack1(instance_label, shrink: false)
          button_inset.pack2(fe_label, shrink: false)
          button_row.pack1(char_label, shrink: false)
          button_row.pack2(button_inset, shrink: false)

          @play_button.add(button_row)
          @play_button.set_alignment(0.0, 0.5)

          # Create remove button
          @remove_button = Gtk::Button.new()
          remove_label = Gtk::Label.new('<span foreground="red"><b>Remove</b></span>')
          remove_label.use_markup = true
          remove_label.set_width_chars(10)
          @remove_button.add(remove_label)

          # Create favorites button if favorites are enabled
          @favorite_button = nil
          if @favorites_enabled
            @favorite_button = Gtk::Button.new()
            favorite_text = is_favorite ? '★' : '☆'
            favorite_label = Gtk::Label.new(favorite_text)
            favorite_label.set_width_chars(3)
            @favorite_button.add(favorite_label)
            @favorite_button.tooltip_text = is_favorite ? 'Remove from favorites' : 'Add to favorites'
          end

          # Apply styling
          @remove_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)
          @play_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)
          if @favorite_button
            @favorite_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)
          end
          @account_book.style_context.add_provider(@tab_provider, Gtk::StyleProvider::PRIORITY_USER) unless @ui_config.theme_state

          # Create character box with play, favorites, and remove buttons
          char_box = Gtk::Box.new(:horizontal)
          char_box.pack_start(@play_button, expand: true, fill: true, padding: 0)
          if @favorite_button
            char_box.pack_end(@favorite_button, expand: false, fill: false, padding: 2)
          end
          char_box.pack_end(@remove_button, expand: false, fill: false, padding: 0)
          account_box.pack_start(char_box, expand: false, fill: false, padding: 0)

          # Set up button handlers
          LoginTabUtils.setup_play_button_handler(@play_button, login_params.to_h, @callbacks.on_play)
          LoginTabUtils.setup_remove_button_handler(@remove_button, login_params.to_h, char_box, @default_icon, @callbacks.on_remove)

          # Set up favorites button handler
          if @favorite_button
            setup_favorite_button_handler(@favorite_button, login_params, char_box, char_label, favorite_label)
          end
        end

        # Sets up the favorite button handler
        # Configures the click event for toggling favorite status
        #
        # @param favorite_button [Gtk::Button] Favorite button
        # @param login_params [LoginParams] Character login parameters
        # @param char_box [Gtk::Box] Character container box
        # @param char_label [Gtk::Label] Character name label
        # @param favorite_label [Gtk::Label] Favorite button label
        # @return [void]
        def setup_favorite_button_handler(favorite_button, login_params, _char_box, char_label, favorite_label)
          favorite_button.signal_connect('clicked') do
            begin
              # Toggle favorite status with frontend precision
              new_status = FavoritesManager.toggle_favorite(@data_dir, login_params.user_id, login_params.char_name, login_params.game_code, login_params.frontend)

              # Update button appearance
              favorite_text = new_status ? '★' : '☆'
              favorite_label.text = favorite_text
              favorite_button.tooltip_text = new_status ? 'Remove from favorites' : 'Add to favorites'

              # Update character name display
              char_name_text = new_status ? "★ #{login_params.char_name}" : login_params.char_name
              char_label.text = char_name_text

              # Update play button styling
              if new_status
                @play_button.style_context.add_class('favorite-character')
              else
                @play_button.style_context.remove_class('favorite-character')
              end

              # Trigger refresh if callback is available
              if @callbacks.on_favorites_change
                @callbacks.on_favorites_change.call(
                  username: login_params.user_id,
                  char_name: login_params.char_name,
                  game_code: login_params.game_code,
                  is_favorite: new_status
                )
              end
            rescue StandardError => e
              Lich.log "error: Error toggling favorite status: #{e.message}"

              # Show error dialog
              dialog = Gtk::MessageDialog.new(
                parent: @parent,
                flags: :modal,
                type: :error,
                buttons: :ok,
                message: "Failed to update favorite status: #{e.message}"
              )
              dialog.set_icon(@default_icon) if @default_icon
              dialog.run
              dialog.destroy
            end
          end
        end

        # Creates character management components
        # Builds UI elements for adding new characters to accounts
        #
        # @return [void]
        def create_character_management_components
          # Character entry
          add_character_pane = Gtk::Paned.new(:horizontal)
          add_char_entry = Gtk::Entry.new
          add_char_label = Gtk::Label.new("Character")
          add_char_label.set_width_chars(15)

          add_character_pane.add1(add_char_label)
          add_character_pane.add2(add_char_entry)

          # Instance selection
          add_instance_pane = Gtk::Paned.new(:horizontal)
          add_inst_select = Gtk::ComboBoxText.new(entry: true)
          add_inst_select.append_text("GemStone IV")
          add_inst_select.append_text("GemStone IV Platinum")
          add_inst_select.append_text("GemStone IV Shattered")
          add_inst_select.append_text("GemStone IV Prime Test")
          add_inst_select.append_text("DragonRealms")
          add_inst_select.append_text("DragonRealms The Fallen")
          add_inst_select.append_text("DragonRealms Prime Test")
          add_inst_label = Gtk::Label.new("Instance")
          add_inst_label.set_width_chars(15)

          add_instance_pane.add1(add_inst_label)
          add_instance_pane.add2(add_inst_select)

          # Frontend options
          q_stormfront_option = Gtk::RadioButton.new(label: 'Stormfront')
          q_wizard_option = Gtk::RadioButton.new(label: 'Wizard', member: q_stormfront_option)
          q_avalon_option = Gtk::RadioButton.new(label: 'Avalon', member: q_stormfront_option)

          # Add character button
          add_char_button = Gtk::Button.new(label: "Add to this account")

          # Frontend selection box
          q_frontend_box = Gtk::Box.new(:horizontal, 10)
          if RUBY_PLATFORM =~ /darwin/i
            q_frontend_box.pack_end(q_avalon_option, expand: false, fill: false, padding: 0)
          else
            q_frontend_box.pack_end(q_wizard_option, expand: false, fill: false, padding: 0)
            q_frontend_box.pack_end(q_stormfront_option, expand: false, fill: false, padding: 0)
          end

          # Character and instance panes
          @bonded_pair_char = Gtk::Paned.new(:horizontal)
          @bonded_pair_char.set_position(350)
          @bonded_pair_char.add1(add_character_pane)
          @bonded_pair_char.add2(q_frontend_box)

          @bonded_pair_inst = Gtk::Paned.new(:horizontal)
          @bonded_pair_inst.set_position(350)
          @bonded_pair_inst.add1(add_instance_pane)
          @bonded_pair_inst.add2(add_char_button)

          # Set up add character button handler
          setup_add_character_handler(add_char_button, add_char_entry, add_inst_select, q_stormfront_option, q_wizard_option, q_avalon_option)
        end

        # Sets up the add character button handler
        # Configures the click event for adding a new character
        #
        # @param add_char_button [Gtk::Button] Add character button
        # @param add_char_entry [Gtk::Entry] Character name entry
        # @param add_inst_select [Gtk::ComboBoxText] Instance selection
        # @param q_stormfront_option [Gtk::RadioButton] Stormfront radio button
        # @param q_wizard_option [Gtk::RadioButton] Wizard radio button
        # @param q_avalon_option [Gtk::RadioButton] Avalon radio button
        # @return [void]
        def setup_add_character_handler(add_char_button, add_char_entry, add_inst_select, q_stormfront_option, q_wizard_option, q_avalon_option)
          add_char_button.signal_connect('clicked') {
            # Handle adding a character
            if @callbacks.on_add_character
              frontend = if q_wizard_option.active?
                           'wizard'
                         elsif q_avalon_option.active?
                           'avalon'
                         elsif q_stormfront_option.active?
                           'stormfront'
                         else # default to
                           'stormfront'
                         end

              @callbacks.on_add_character.call(
                character: add_char_entry.text,
                instance: add_inst_select.child.text,
                frontend: frontend
              )
            end
          }
        end

        # Creates global settings components
        # Builds UI elements for global application settings
        #
        # @return [void]
        def create_global_settings_components
          # Use shared utility method to create settings components
          settings = LoginTabUtils.create_global_settings_components(
            @quick_game_entry_tab,
            @ui_config.theme_state,
            @ui_config.tab_layout_state,
            @ui_config.autosort_state,
            {
              on_theme_change: @callbacks.on_theme_change,
              on_layout_change: @callbacks.on_layout_change,
              on_sort_change: @callbacks.on_sort_change
            }
          )

          # Store slider box reference for external access
          @slider_box = settings[:slider_box]
        end

        # Creates a custom launch entry
        # Builds a combo box for custom launch commands
        #
        # @return [Gtk::ComboBoxText] The custom launch entry widget
        def create_custom_launch_entry
          @custom_launch_entry = LoginTabUtils.create_custom_launch_entry
        end

        # Creates a custom launch directory entry
        # Builds a combo box for custom launch directories
        #
        # @return [Gtk::ComboBoxText] The custom launch directory widget
        def create_custom_launch_dir
          @custom_launch_dir = LoginTabUtils.create_custom_launch_dir
        end
      end
    end
  end
end
