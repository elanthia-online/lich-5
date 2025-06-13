# frozen_string_literal: true

require_relative 'favorites_manager'
require_relative 'parameter_objects'
require_relative 'theme_utils'

module Lich
  module Common
    module GUI
      # Handles the "Manual Entry" tab functionality for the Lich GUI login system
      # Provides a class-based implementation for the manual login tab
      # Enhanced with cache management methods to support cross-tab data synchronization
      class ManualLoginTab
        # Initializes a new ManualLoginTab instance with favorites support
        #
        # @param parent [Gtk::Window] Parent window
        # @param entry_data [Array] Array of saved login entries
        # @param theme_state [Boolean] Whether dark theme is enabled
        # @param default_icon [Gdk::Pixbuf] Default icon for dialogs
        # @param data_dir [String] Data directory for favorites storage
        # @param callbacks [Hash, CallbackParams] Callback handlers for various events
        # @return [ManualLoginTab] New instance
        def initialize(parent, entry_data, theme_state, default_icon, data_dir, callbacks = {})
          @parent = parent
          @entry_data = entry_data
          @theme_state = theme_state
          @default_icon = default_icon
          @data_dir = data_dir

          # Convert callbacks hash to CallbackParams if needed
          @callbacks = if callbacks.is_a?(CallbackParams)
                         callbacks
                       else
                         CallbackParams.new(callbacks)
                       end

          # Initialize variables
          @launch_data = nil

          # Create the tab content
          create_tab_content
        end

        # Returns the tab widget for adding to a notebook
        #
        # @return [Gtk::Widget] The tab widget
        def tab_widget
          @game_entry_tab
        end

        # Returns references to UI elements that need to be accessed externally
        #
        # @return [Hash] Hash of UI element references
        def ui_elements
          {
            custom_launch_entry: @custom_launch_entry,
            custom_launch_dir: @custom_launch_dir
          }
        end

        # Updates the theme state and refreshes UI elements accordingly
        #
        # @param theme_state [Boolean] New theme state
        # @return [void]
        def update_theme_state(theme_state)
          @theme_state = theme_state
          apply_theme_to_ui_elements
        end

        # Refreshes the cached entry data from YAML file
        # This method is called when other tabs modify the data to ensure cache consistency.
        # Prevents stale data issues when accounts or characters are removed via account management.
        #
        # @return [void]
        def refresh_entry_data
          # Reload data from YAML file
          @entry_data = Lich::Common::GUI::YamlState.load_saved_entries(@data_dir, false)
        end

        # Updates the entry data reference (for external updates)
        # This method allows the main GUI to update the cached data directly.
        # Used for immediate cache updates without file I/O operations.
        #
        # @param new_entry_data [Array] New entry data array
        # @return [void]
        def update_entry_data(new_entry_data)
          @entry_data = new_entry_data
        end

        private

        # Applies the current theme state to all UI elements
        #
        # @return [void]
        def apply_theme_to_ui_elements
          # Removed useless assignment to ui_elements

          # Removed useless assignment to providers

          if @theme_state
            # Enable dark theme
            Gtk::Settings.default.gtk_application_prefer_dark_theme = true
            # Remove styling providers that might conflict with dark theme
            if defined?(@button_provider)
              @treeview_buttons&.each do |button|
                button.style_context.remove_provider(@button_provider) if button
              end
            end
            # Reset background colors to transparent for dark theme
            # Do not reset the treeview features, they should remain default
            @game_entry_tab.override_background_color(:normal, ThemeUtils.darkmode_background) if @game_entry_tab
          else
            # Disable dark theme
            Gtk::Settings.default.gtk_application_prefer_dark_theme = false
            # Set light grey background for light theme
            @game_entry_tab.override_background_color(:normal, ThemeUtils.light_theme_background) if @game_entry_tab
            # Re-apply styling providers for light theme
            if defined?(@button_provider)
              @treeview_buttons&.each do |button|
                button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER) if button
              end
            end
          end
        end

        # Creates the tab content
        #
        # @return [void]
        def create_tab_content
          # Initialize button collection for theme updates
          @treeview_buttons = []

          # Create user ID and password entry fields
          user_id_entry, pass_entry, login_table = create_login_fields

          # Create connect and disconnect buttons
          connect_button, disconnect_button, login_button_box = create_login_buttons
          @treeview_buttons << connect_button << disconnect_button

          # Create character list
          liststore, @treeview, sw = create_character_list

          # Create frontend selection
          frontend_box, _stormfront_option, wizard_option, avalon_option, suks_option = create_frontend_selection

          # Create custom launch options
          custom_launch_option = create_custom_launch_options

          # Create quick entry save option
          @make_quick_option = Gtk::CheckButton.new('Save this info for quick game entry')

          # Create favorites option
          @make_favorite_option = Gtk::CheckButton.new('★ Mark as favorite')
          @make_favorite_option.set_tooltip_text('Mark this character as a favorite for quick access')

          # Create play button
          play_button, play_button_box = create_play_button
          @treeview_buttons << play_button

          # Create main tab container
          @game_entry_tab = Gtk::Box.new(:vertical)
          @game_entry_tab.border_width = 5
          @game_entry_tab.pack_start(login_table, expand: false, fill: false, padding: 0)
          @game_entry_tab.pack_start(login_button_box, expand: false, fill: false, padding: 0)
          @game_entry_tab.pack_start(sw, expand: true, fill: true, padding: 3)
          @game_entry_tab.pack_start(frontend_box, expand: false, fill: false, padding: 3)
          @game_entry_tab.pack_start(custom_launch_option, expand: false, fill: false, padding: 3)
          @game_entry_tab.pack_start(@custom_launch_entry, expand: false, fill: false, padding: 3)
          @game_entry_tab.pack_start(@custom_launch_dir, expand: false, fill: false, padding: 3)
          @game_entry_tab.pack_start(@make_quick_option, expand: false, fill: false, padding: 3)
          @game_entry_tab.pack_start(@make_favorite_option, expand: false, fill: false, padding: 3)
          @game_entry_tab.pack_start(play_button_box, expand: false, fill: false, padding: 3)

          # Apply initial theme
          unless @theme_state
            @game_entry_tab.override_background_color(:normal, ThemeUtils.light_theme_background)
          end

          # Set up event handlers
          setup_custom_launch_handler(custom_launch_option)
          setup_avalon_option_handler(avalon_option, custom_launch_option)
          setup_connect_button_handler(connect_button, disconnect_button, user_id_entry, pass_entry, liststore)
          setup_treeview_handler(@treeview, play_button)
          setup_disconnect_button_handler(disconnect_button, play_button, connect_button, user_id_entry, pass_entry, liststore)
          setup_play_button_handler(play_button, @treeview, user_id_entry, pass_entry, wizard_option, avalon_option, suks_option, custom_launch_option)
          setup_entry_key_handlers(user_id_entry, pass_entry, connect_button)
        end

        # Creates login fields (user ID and password)
        #
        # @return [Array] Array containing user_id_entry, pass_entry, and login_table
        def create_login_fields
          user_id_entry = Gtk::Entry.new

          pass_entry = Gtk::Entry.new
          pass_entry.visibility = false

          login_table = Gtk::Table.new(2, 2, false)
          login_table.attach(Gtk::Label.new('User ID:'), 0, 1, 0, 1, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, 5, 5)
          login_table.attach(user_id_entry, 1, 2, 0, 1, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, 5, 5)
          login_table.attach(Gtk::Label.new('Password:'), 0, 1, 1, 2, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, 5, 5)
          login_table.attach(pass_entry, 1, 2, 1, 2, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, 5, 5)

          [user_id_entry, pass_entry, login_table]
        end

        # Creates login buttons (connect and disconnect)
        #
        # @return [Array] Array containing connect_button, disconnect_button, and login_button_box
        def create_login_buttons
          disconnect_button = Components.create_button(label: ' Disconnect ')
          disconnect_button.sensitive = false

          connect_button = Components.create_button(label: ' Connect ')

          # Apply button styling
          @button_provider = LoginTabUtils.create_button_css_provider
          disconnect_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER) unless @theme_state
          connect_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER) unless @theme_state

          login_button_box = Components.create_button_box(
            [connect_button, disconnect_button],
            expand: false,
            fill: false,
            padding: 5
          )

          [connect_button, disconnect_button, login_button_box]
        end

        # Creates character list components
        #
        # @return [Array] Array containing liststore, treeview, and sw
        def create_character_list
          liststore = Gtk::ListStore.new(String, String, String, String)
          liststore.set_sort_column_id(1, :ascending)

          renderer = Gtk::CellRendererText.new

          treeview = Gtk::TreeView.new(liststore)
          treeview.height_request = 160

          # Add game column
          col = Gtk::TreeViewColumn.new("Game", renderer, text: 1)
          col.resizable = true
          treeview.append_column(col)

          # Add character column
          col = Gtk::TreeViewColumn.new("Character", renderer, text: 3)
          col.resizable = true
          treeview.append_column(col)

          # Create scrolled window for tree view
          sw = Gtk::ScrolledWindow.new
          sw.set_policy(:automatic, :automatic)
          sw.add(treeview)

          [liststore, treeview, sw]
        end

        # Creates frontend selection components
        #
        # @return [Array] Array containing frontend_box and radio buttons
        def create_frontend_selection
          stormfront_option = Gtk::RadioButton.new(label: 'Wrayth')
          wizard_option = Gtk::RadioButton.new(label: 'Wizard', member: stormfront_option)
          avalon_option = Gtk::RadioButton.new(label: 'Avalon', member: stormfront_option)
          suks_option = Gtk::RadioButton.new(label: 'suks', member: stormfront_option)

          frontend_box = Gtk::Box.new(:horizontal, 10)
          frontend_box.pack_start(stormfront_option, expand: false, fill: false, padding: 0)
          frontend_box.pack_start(wizard_option, expand: false, fill: false, padding: 0)
          if RUBY_PLATFORM =~ /darwin/i
            frontend_box.pack_start(avalon_option, expand: false, fill: false, padding: 0)
          end
          # frontend_box.pack_start(suks_option, false, false, 0)

          [frontend_box, stormfront_option, wizard_option, avalon_option, suks_option]
        end

        # Creates custom launch options
        #
        # @return [Gtk::CheckButton] Custom launch option checkbox
        def create_custom_launch_options
          custom_launch_option = Gtk::CheckButton.new('Custom launch command')

          # Use shared utility methods for creating custom launch entries
          @custom_launch_entry = LoginTabUtils.create_custom_launch_entry
          @custom_launch_dir = LoginTabUtils.create_custom_launch_dir

          # Initially hide custom launch options
          @custom_launch_entry.visible = false
          @custom_launch_dir.visible = false

          custom_launch_option
        end

        # Creates play button components
        #
        # @return [Array] Array containing play_button and play_button_box
        def create_play_button
          play_button = Components.create_button(label: ' Play ')
          play_button.sensitive = false

          # Apply button styling
          play_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER) unless @theme_state

          play_button_box = Components.create_button_box(
            [play_button],
            expand: false,
            fill: false,
            padding: 5
          )

          [play_button, play_button_box]
        end

        # Sets up custom launch option toggle handler
        #
        # @param custom_launch_option [Gtk::CheckButton] Custom launch option checkbox
        # @return [void]
        def setup_custom_launch_handler(custom_launch_option)
          custom_launch_option.signal_connect('toggled') {
            @custom_launch_entry.visible = custom_launch_option.active?
            @custom_launch_dir.visible = custom_launch_option.active?
          }
        end

        # Sets up avalon option toggle handler
        #
        # @param avalon_option [Gtk::RadioButton] Avalon radio button
        # @param custom_launch_option [Gtk::CheckButton] Custom launch option checkbox
        # @return [void]
        def setup_avalon_option_handler(avalon_option, custom_launch_option)
          avalon_option.signal_connect('toggled') {
            if avalon_option.active?
              custom_launch_option.active = false
              custom_launch_option.sensitive = false
            else
              custom_launch_option.sensitive = true
            end
          }
        end

        # Sets up connect button click handler
        #
        # @param connect_button [Gtk::Button] Connect button
        # @param disconnect_button [Gtk::Button] Disconnect button
        # @param user_id_entry [Gtk::Entry] User ID entry field
        # @param pass_entry [Gtk::Entry] Password entry field
        # @param liststore [Gtk::ListStore] List store for character list
        # @return [void]
        def setup_connect_button_handler(connect_button, disconnect_button, user_id_entry, pass_entry, liststore)
          connect_button.signal_connect('clicked') {
            connect_button.sensitive = false
            user_id_entry.sensitive = false
            pass_entry.sensitive = false
            iter = liststore.append
            iter[1] = 'working...'
            Gtk.queue {
              begin
                # Authenticate with legacy mode - normalize account name to UPCASE
                login_info = Authentication.authenticate(
                  account: user_id_entry.text.upcase,
                  password: pass_entry.text,
                  legacy: true
                )
              end
              if login_info.to_s =~ /error/i
                # Call the error callback if provided
                if @callbacks.on_error
                  @callbacks.on_error.call("\nSomething went wrong... probably invalid user ID or password.\n\nserver response: #{login_info}")
                end
                connect_button.sensitive = true
                disconnect_button.sensitive = false
                user_id_entry.sensitive = true
                pass_entry.sensitive = true
              else
                # Populate character list
                liststore.clear
                login_info.each do |row|
                  iter = liststore.append
                  iter[0] = row[:game_code]
                  iter[1] = row[:game_name]
                  iter[2] = row[:char_code]
                  iter[3] = row[:char_name]
                end
                disconnect_button.sensitive = true
              end
              true
            }
          }
        end

        # Sets up tree view selection handler
        #
        # @param treeview [Gtk::TreeView] Tree view for character list
        # @param play_button [Gtk::Button] Play button
        # @return [void]
        def setup_treeview_handler(treeview, play_button)
          treeview.signal_connect('cursor-changed') {
            selection = treeview.selection
            play_button.sensitive = !selection.selected.nil?
          }
        end

        # Sets up disconnect button click handler
        #
        # @param disconnect_button [Gtk::Button] Disconnect button
        # @param play_button [Gtk::Button] Play button
        # @param connect_button [Gtk::Button] Connect button
        # @param user_id_entry [Gtk::Entry] User ID entry field
        # @param pass_entry [Gtk::Entry] Password entry field
        # @param liststore [Gtk::ListStore] List store for character list
        # @return [void]
        def setup_disconnect_button_handler(disconnect_button, play_button, connect_button, user_id_entry, pass_entry, liststore)
          disconnect_button.signal_connect('clicked') {
            disconnect_button.sensitive = false
            play_button.sensitive = false
            connect_button.sensitive = true
            user_id_entry.sensitive = true
            pass_entry.sensitive = true
            liststore.clear
          }
        end

        # Sets up play button click handler with synchronized save and favorite operations
        #
        # Handles character login with optional quick entry saving and favorite marking.
        # Implements synchronization to prevent race conditions between save and favorite
        # operations by ensuring save completes successfully before favorite marking begins.
        #
        # Duplicate Detection Logic:
        # - Entries are uniquely identified by: char_name + game_code + user_id + frontend
        # - If identical entry exists: skips save (prevents true duplicates)
        # - If entry exists with different data: updates existing entry in-place
        # - If no matching entry exists: adds new entry to collection
        # - Favorite marking always operates on the final entry state
        #
        # @param play_button [Gtk::Button] Play button
        # @param treeview [Gtk::TreeView] Tree view for character list
        # @param user_id_entry [Gtk::Entry] User ID entry field
        # @param pass_entry [Gtk::Entry] Password entry field
        # @param wizard_option [Gtk::RadioButton] Wizard radio button
        # @param avalon_option [Gtk::RadioButton] Avalon radio button
        # @param suks_option [Gtk::RadioButton] Suks radio button
        # @param custom_launch_option [Gtk::CheckButton] Custom launch option checkbox
        # @return [void]
        def setup_play_button_handler(play_button, treeview, user_id_entry, pass_entry, wizard_option, avalon_option, suks_option, custom_launch_option)
          play_button.signal_connect('clicked') {
            play_button.sensitive = false

            # Get selected character
            selection = treeview.selection
            # Fixed assignment in condition
            selected_iter = selection.selected
            if selected_iter
              # Determine frontend
              if wizard_option.active?
                frontend = 'wizard'
              elsif avalon_option.active?
                frontend = 'avalon'
              elsif suks_option.active?
                frontend = 'suks'
              else
                frontend = 'stormfront' # default frontend
              end

              # Determine custom launch settings
              custom_launch = custom_launch_option.active? ? @custom_launch_entry.child.text : nil
              custom_launch_dir = custom_launch_option.active? ? @custom_launch_dir.child.text : nil

              # Normalize account name to UPCASE and character name to Title case
              normalized_account = user_id_entry.text.upcase
              normalized_character = selected_iter[3].capitalize

              launch_data_hash = Authentication.authenticate(
                account: normalized_account,
                password: pass_entry.text,
                character: normalized_character,
                game_code: selected_iter[0]
              )

              launch_data = Authentication.prepare_launch_data(
                launch_data_hash,
                frontend,
                custom_launch,
                custom_launch_dir
              )
              # Prep login data
              @launch_data = launch_data

              # Initialize save success tracking for synchronization
              save_success = true

              # Save quick entry if selected
              if @make_quick_option.active?
                entry_data = { :char_name => normalized_character, :game_code => selected_iter[0], :game_name => selected_iter[1], :user_id => normalized_account, :password => pass_entry.text, :frontend => frontend, :custom_launch => custom_launch, :custom_launch_dir => custom_launch_dir }

                # Check for duplicate entries using normalized comparison for consistent matching
                existing_entry = @entry_data.find do |entry|
                  entry[:char_name].to_s.capitalize == entry_data[:char_name] &&
                    entry[:game_code] == entry_data[:game_code] &&
                    entry[:user_id].to_s.upcase == entry_data[:user_id] &&
                    entry[:frontend] == entry_data[:frontend]
                end

                if existing_entry
                  # Check if data is identical (excluding potential favorite fields)
                  data_identical = existing_entry[:game_name] == entry_data[:game_name] &&
                                   existing_entry[:password] == entry_data[:password] &&
                                   existing_entry[:custom_launch] == entry_data[:custom_launch] &&
                                   existing_entry[:custom_launch_dir] == entry_data[:custom_launch_dir]

                  if data_identical
                    save_success = true # Consider this a successful "save" since entry already exists
                  else
                    # Update existing entry with new data
                    existing_entry[:game_name] = entry_data[:game_name]
                    existing_entry[:password] = entry_data[:password]
                    existing_entry[:custom_launch] = entry_data[:custom_launch]
                    existing_entry[:custom_launch_dir] = entry_data[:custom_launch_dir]
                    @save_entry_data = true

                    save_success = Lich::Common::GUI::YamlState.save_entries(@data_dir, @entry_data)
                  end
                else
                  @entry_data.push entry_data
                  @save_entry_data = true

                  # Trigger save through main GUI's save mechanism with synchronization
                  save_success = Lich::Common::GUI::YamlState.save_entries(@data_dir, @entry_data)
                end

                if save_success
                  # Reset save flag to prevent duplicate save on window destruction
                  @save_entry_data = false
                  # Refresh local cache with normalized data after successful save
                  @entry_data = Lich::Common::GUI::YamlState.load_saved_entries(@data_dir, @autosort_state)
                  # Trigger main GUI cache refresh only once after successful save
                  @callbacks.on_save.call(entry_data) if @callbacks.on_save
                else
                  # Log save failure for debugging
                  Lich.log "error: Failed to save entry data for character '#{normalized_character}' (#{selected_iter[0]})"
                end
              end

              # Handle favorites if selected - only proceed if save was successful or not required
              if @make_favorite_option.active? && save_success
                begin
                  # Add character to favorites with precise frontend matching - use normalized values
                  favorite_success = FavoritesManager.add_favorite(@data_dir, normalized_account, normalized_character, selected_iter[0], frontend)

                  if favorite_success
                    # Single optimized cache refresh after favorite marking
                    # This replaces multiple redundant refresh operations
                    @entry_data = Lich::Common::GUI::YamlState.load_saved_entries(@data_dir, @autosort_state)

                    # Critical: Trigger on_save callback again to refresh main GUI cache with favorite data
                    # This ensures the main GUI cache contains the updated favorite information
                    @callbacks.on_save.call(entry_data) if @callbacks.on_save

                    # Notify main GUI of the change without triggering additional cache refresh
                    # The main GUI will use the notification to update UI without reloading from disk
                    if @callbacks.on_favorites_change
                      @callbacks.on_favorites_change.call(
                        username: normalized_account,
                        char_name: normalized_character,
                        game_code: selected_iter[0],
                        is_favorite: true
                      )
                    end
                  else
                    # Log favorite marking failure for debugging
                    Lich.log "warning: Failed to mark character '#{normalized_character}' (#{selected_iter[0]}) as favorite"
                  end
                rescue StandardError => e
                  Lich.log "error: Error adding character to favorites: #{e.message}"

                  # Show error dialog to user
                  dialog = Gtk::MessageDialog.new(
                    parent: @parent,
                    flags: :modal,
                    type: :error,
                    buttons: :ok,
                    message: "Failed to add character to favorites: #{e.message}"
                  )
                  dialog.set_icon(@default_icon) if @default_icon
                  dialog.run
                  dialog.destroy
                end
              end

              # Call the play callback if provided
              if @callbacks.on_play

                @callbacks.on_play.call(launch_data) # (login_params)
              end

            end
          }
        end

        # Sets up key press handlers for entry fields
        #
        # @param user_id_entry [Gtk::Entry] User ID entry field
        # @param pass_entry [Gtk::Entry] Password entry field
        # @param connect_button [Gtk::Button] Connect button
        # @return [void]
        def setup_entry_key_handlers(user_id_entry, pass_entry, connect_button)
          # Trigger connect button on Enter key in user ID field
          user_id_entry.signal_connect('key-press-event') { |_widget, event|
            if event.keyval == Gdk::Keyval::KEY_Return
              connect_button.clicked
              true
            else
              false
            end
          }

          # Trigger connect button on Enter key in password field
          pass_entry.signal_connect('key-press-event') { |_widget, event|
            if event.keyval == Gdk::Keyval::KEY_Return
              connect_button.clicked
              true
            else
              false
            end
          }
        end
      end
    end
  end
end
