# frozen_string_literal: true

require_relative 'account_manager'
require_relative 'favorites_manager'
require_relative 'theme_utils'

module Lich
  module Common
    module GUI
      # Provides a user interface for managing accounts and characters
      # Implements the account management feature for the Lich GUI login system
      # Enhanced with data change notification capability for cross-tab synchronization
      class AccountManagerUI
        # Creates and displays the account management window
        #
        # @param data_dir [String] Directory containing account data
        # @return [void]
        def self.create_management_window(data_dir)
          # Create instance with data directory
          manager = new(data_dir)

          # Create and show the management window
          manager.show_management_window
        end

        # Initializes a new AccountManagerUI instance
        #
        # @param data_dir [String] Directory containing account data
        # @return [AccountManagerUI] New instance
        def initialize(data_dir)
          @data_dir = data_dir
          @msgbox = ->(message) { show_message_dialog(message) }
          @data_change_callback = nil
        end

        # Sets the data change callback for cross-tab communication
        # Allows other tabs to be notified when data changes occur
        #
        # @param callback [Proc] Callback to execute when data changes
        # @return [void]
        def set_data_change_callback(callback)
          @data_change_callback = callback
        end

        # Registers with tab communicator to receive data change notifications
        # Allows this UI to refresh when other tabs make changes
        #
        # @param tab_communicator [TabCommunicator] Tab communicator instance
        # @return [void]
        def register_for_notifications(tab_communicator)
          @tab_communicator = tab_communicator
          @accounts_store = nil # Will be set when accounts tab is created

          # Register callback to handle incoming notifications
          @tab_communicator.register_data_change_callback(->(change_type, data) {
            case change_type
            when :favorite_toggled
              # Refresh accounts view to reflect favorite changes
              refresh_accounts_display if @accounts_store
              Lich.log "info: Account manager refreshed for favorite change: #{data}"
            when :character_added, :character_removed, :account_added, :account_removed
              # Refresh accounts view for structural changes
              refresh_accounts_display if @accounts_store
              Lich.log "info: Account manager refreshed for data change: #{change_type}"
            end
          })
        end

        # Refreshes the accounts display to reflect data changes
        # Reloads and repopulates the accounts tree view
        #
        # @return [void]
        def refresh_accounts_display
          return unless @accounts_store

          begin
            # Clear existing data
            @accounts_store.clear

            # Repopulate with current data
            populate_accounts_view(@accounts_store)
          rescue StandardError => e
            Lich.log "error: Error refreshing accounts display: #{e.message}"
          end
        end

        # Creates the accounts tab
        #
        # @param notebook [Gtk::Notebook] Notebook to add tab to
        # @return [void]
        def create_accounts_tab(notebook)
          # Create tab content
          accounts_box = Gtk::Box.new(:vertical, 10)
          accounts_box.border_width = 10

          # Create accounts treeview with favorites support
          accounts_store = Gtk::TreeStore.new(String, String, String, String, String, String) # Added favorites column
          @accounts_store = accounts_store # Store reference for refresh operations
          accounts_view = Gtk::TreeView.new(accounts_store)

          # Enable sortable columns
          accounts_view.set_headers_clickable(true)
          accounts_store.set_default_sort_func { |_model, _a, _b| 0 } # Default no-op sort

          # Add columns with sorting
          renderer = Gtk::CellRendererText.new

          # Account column (not sortable - maintains account grouping)
          col = Gtk::TreeViewColumn.new("Account", renderer, text: 0)
          col.resizable = true
          accounts_view.append_column(col)

          # Character column - sortable
          col = Gtk::TreeViewColumn.new("Character", renderer, text: 1)
          col.resizable = true
          col.set_sort_column_id(1)
          col.clickable = true
          accounts_view.append_column(col)

          # Game column - sortable
          col = Gtk::TreeViewColumn.new("Game", renderer, text: 2)
          col.resizable = true
          col.set_sort_column_id(2)
          col.clickable = true
          accounts_view.append_column(col)

          # Frontend column - sortable
          col = Gtk::TreeViewColumn.new("Frontend", renderer, text: 3)
          col.resizable = true
          col.set_sort_column_id(3)
          col.clickable = true
          accounts_view.append_column(col)

          # Favorites column with clickable star (not sortable)
          favorites_renderer = Gtk::CellRendererText.new
          favorites_col = Gtk::TreeViewColumn.new("Favorite", favorites_renderer, text: 5)
          favorites_col.resizable = true
          accounts_view.append_column(favorites_col)

          # Set up custom sort functions that maintain account grouping
          setup_account_aware_sorting(accounts_store)

          # Set up sort state persistence
          setup_sort_state_persistence(accounts_store)

          # Set up favorites column click handler
          setup_favorites_column_handler(accounts_view, favorites_col, @data_dir)

          # Create scrolled window
          sw = Gtk::ScrolledWindow.new
          sw.set_policy(:automatic, :automatic)
          sw.add(accounts_view)
          accounts_box.pack_start(sw, expand: true, fill: true, padding: 0)

          # Create button box
          button_box = Gtk::Box.new(:horizontal, 5)

          # Create refresh button
          refresh_button = Gtk::Button.new(label: "Refresh")
          button_box.pack_start(refresh_button, expand: false, fill: false, padding: 0)

          # Create remove button
          remove_button = Gtk::Button.new(label: "Remove")
          remove_button.sensitive = false
          button_box.pack_start(remove_button, expand: false, fill: false, padding: 0)

          # Create add account button
          add_account_button = Gtk::Button.new(label: "Add Account")
          button_box.pack_start(add_account_button, expand: false, fill: false, padding: 0)

          # Create add character button
          add_character_button = Gtk::Button.new(label: "Add Character")
          button_box.pack_start(add_character_button, expand: false, fill: false, padding: 0)

          # Create change password button
          change_password_button = Gtk::Button.new(label: "Change Password")
          change_password_button.sensitive = false

          # Set accessible properties for screen readers
          Accessibility.make_button_accessible(
            change_password_button,
            "Change Password Button",
            "Change the password for the selected account"
          )

          button_box.pack_start(change_password_button, expand: false, fill: false, padding: 0)

          accounts_box.pack_start(button_box, expand: false, fill: false, padding: 0)

          # Add tab to notebook
          notebook.append_page(accounts_box, Gtk::Label.new("Accounts"))

          # Set up refresh button handler
          refresh_button.signal_connect('clicked') do
            populate_accounts_view(accounts_store)
          end

          # Set up selection handler
          selection = accounts_view.selection
          selection.signal_connect('changed') do
            iter = selection.selected
            if iter
              account = iter[0]
              character = iter[1] # Character is in column 1, not 2

              # Enable remove button for all selections
              remove_button.sensitive = !iter.nil?

              # Only enable change password for account nodes (not character nodes)
              change_password_button.sensitive = !account.nil? && (character.nil? || character.empty?)
            else
              remove_button.sensitive = false
              change_password_button.sensitive = false
            end
          end

          # Set up remove button handler
          remove_button.signal_connect('clicked') do
            iter = selection.selected
            if iter
              account = iter[0]
              character = iter[1] # Character is in column 1, not 2
              _game_name = iter[2] # Game name is in column 2, not character
              frontend_display = iter[3] # Frontend display name
              game_code = iter[4] # Game code is in hidden column 4

              if character.nil? || character.empty?
                # This is an account node
                # Confirm deletion
                dialog = Gtk::MessageDialog.new(
                  parent: @window,
                  flags: :modal,
                  type: :question,
                  buttons: :yes_no,
                  message: "Delete account #{account} and all its characters?"
                )
                response = dialog.run
                dialog.destroy

                if response == Gtk::ResponseType::YES
                  # Remove account
                  if AccountManager.remove_account(@data_dir, account)
                    @msgbox.call("Account removed successfully.")
                    populate_accounts_view(accounts_store)
                    # Notify other tabs of data change
                    notify_data_changed(:account_removed, { account: account })
                  else
                    @msgbox.call("Failed to remove account.")
                  end
                end
              else
                # This is a character node
                # Confirm deletion
                dialog = Gtk::MessageDialog.new(
                  parent: @window,
                  flags: :modal,
                  type: :question,
                  buttons: :yes_no,
                  message: "Delete #{character} from #{account}?"
                )
                response = dialog.run
                dialog.destroy

                if response == Gtk::ResponseType::YES
                  # Convert display name back to internal frontend format for precise removal
                  frontend = case frontend_display.downcase
                             when 'custom'
                               'stormfront' # Custom launches use stormfront as base
                             when 'wrayth'
                               'stormfront' # Wrayth is display name for stormfront
                             when 'wizard'
                               'wizard'
                             when 'avalon'
                               'avalon'
                             else
                               frontend_display.downcase
                             end

                  # Remove character with frontend precision
                  if AccountManager.remove_character(@data_dir, account, character, game_code, frontend)
                    @msgbox.call("Character removed successfully.")
                    populate_accounts_view(accounts_store)
                    # Notify other tabs of data change
                    notify_data_changed(:character_removed, {
                      account: account,
                      character: character,
                      game_code: game_code,
                      frontend: frontend
                    })
                  else
                    @msgbox.call("Failed to remove character.")
                  end
                end
              end
            end
          end

          # Set up add account button handler - switch to Add Account tab
          add_account_button.signal_connect('clicked') do
            # Switch to Add Account tab (index 2)
            notebook.set_page(2)
          end

          # Set up add character button handler - switch to Add Character tab
          add_character_button.signal_connect('clicked') do
            # Switch to Add Character tab (index 1)
            notebook.set_page(1)
          end
          # Set up change password button handler
          change_password_button.signal_connect('clicked') do
            iter = selection.selected
            if iter
              account = iter[0]
              PasswordChange.show_password_change_dialog(@window, @data_dir, account)
            end
          end
          # Populate accounts view
          populate_accounts_view(accounts_store)
        end

        # Creates the add character tab
        #
        # @param notebook [Gtk::Notebook] Notebook to add tab to
        # @return [void]
        def create_add_character_tab(notebook)
          # Create tab content
          add_box = Gtk::Box.new(:vertical, 10)
          add_box.border_width = 10

          # Create account selection
          account_box = Gtk::Box.new(:horizontal, 5)
          account_box.pack_start(Gtk::Label.new("Account:"), expand: false, fill: false, padding: 0)

          account_combo = Gtk::ComboBoxText.new
          account_box.pack_start(account_combo, expand: true, fill: true, padding: 0)

          refresh_button = Gtk::Button.new(label: "Refresh")
          account_box.pack_start(refresh_button, expand: false, fill: false, padding: 0)

          add_box.pack_start(account_box, expand: false, fill: false, padding: 0)

          # Create character name entry
          char_box = Gtk::Box.new(:horizontal, 5)
          char_box.pack_start(Gtk::Label.new("Character:"), expand: false, fill: false, padding: 0)

          char_name_entry = Gtk::Entry.new
          char_box.pack_start(char_name_entry, expand: true, fill: true, padding: 0)

          add_box.pack_start(char_box, expand: false, fill: false, padding: 0)

          # Create game selection
          game_box = Gtk::Box.new(:horizontal, 5)
          game_box.pack_start(Gtk::Label.new("Game:"), expand: false, fill: false, padding: 0)

          game_combo = GameSelection.create_game_selection_combo
          game_box.pack_start(game_combo, expand: true, fill: true, padding: 0)
          add_box.pack_start(game_box, expand: false, fill: false, padding: 0)

          # Create frontend selection
          frontend_box = Gtk::Box.new(:horizontal, 5)
          frontend_box.pack_start(Gtk::Label.new("Frontend:"), expand: false, fill: false, padding: 0)

          frontend_radio_box = Gtk::Box.new(:horizontal, 5)
          stormfront_option = Gtk::RadioButton.new(label: 'Wrayth')
          wizard_option = Gtk::RadioButton.new(label: 'Wizard', member: stormfront_option)
          avalon_option = Gtk::RadioButton.new(label: 'Avalon', member: stormfront_option)

          frontend_radio_box.pack_start(stormfront_option, expand: false, fill: false, padding: 0)
          frontend_radio_box.pack_start(wizard_option, expand: false, fill: false, padding: 0)
          frontend_radio_box.pack_start(avalon_option, expand: false, fill: false, padding: 0) if RUBY_PLATFORM =~ /darwin/i

          frontend_box.pack_start(frontend_radio_box, expand: true, fill: true, padding: 0)

          add_box.pack_start(frontend_box, expand: false, fill: false, padding: 0)

          # Create custom launch options
          custom_launch_box = Gtk::Box.new(:horizontal, 5)
          custom_launch_box.pack_start(Gtk::Label.new("Custom Launch:"), expand: false, fill: false, padding: 0)

          custom_launch_entry = Gtk::Entry.new
          custom_launch_box.pack_start(custom_launch_entry, expand: true, fill: true, padding: 0)

          add_box.pack_start(custom_launch_box, expand: false, fill: false, padding: 0)

          # Create custom launch dir options
          custom_launch_dir_box = Gtk::Box.new(:horizontal, 5)
          custom_launch_dir_box.pack_start(Gtk::Label.new("Custom Launch Dir:"), expand: false, fill: false, padding: 0)

          custom_launch_dir_entry = Gtk::Entry.new
          custom_launch_dir_box.pack_start(custom_launch_dir_entry, expand: true, fill: true, padding: 0)

          add_box.pack_start(custom_launch_dir_box, expand: false, fill: false, padding: 0)

          # Create add button
          button_box = Gtk::Box.new(:horizontal, 5)
          add_button = Gtk::Button.new(label: "Add Character")
          button_box.pack_end(add_button, expand: false, fill: false, padding: 0)

          # Create back button to return to accounts tab
          back_button = Gtk::Button.new(label: "Back to Accounts")
          button_box.pack_start(back_button, expand: false, fill: false, padding: 0)

          add_box.pack_start(button_box, expand: false, fill: false, padding: 0)

          # Add tab to notebook
          notebook.append_page(add_box, Gtk::Label.new("Add Character"))

          # Set up back button handler
          back_button.signal_connect('clicked') do
            # Switch to Accounts tab (index 0)
            notebook.set_page(0)
          end

          # Set up event handlers
          setup_add_character_handlers(
            add_button,
            account_combo,
            refresh_button,
            char_name_entry,
            game_combo,
            stormfront_option,
            wizard_option,
            avalon_option,
            custom_launch_entry,
            custom_launch_dir_entry,
            notebook
          )

          # Populate account combo
          populate_account_combo(account_combo)
        end

        # Creates the add account tab
        #
        # @param notebook [Gtk::Notebook] Notebook to add tab to
        # @return [void]
        def create_add_account_tab(notebook)
          # Create tab content
          add_account_box = Gtk::Box.new(:vertical, 10)
          add_account_box.border_width = 10

          # Create username entry
          username_box = Gtk::Box.new(:horizontal, 5)
          username_box.pack_start(Gtk::Label.new("Username:"), expand: false, fill: false, padding: 0)

          username_entry = Gtk::Entry.new

          # Set accessible properties for screen readers
          Accessibility.make_entry_accessible(
            username_entry,
            "Username Entry",
            "Enter your account username"
          )

          username_box.pack_start(username_entry, expand: true, fill: true, padding: 0)

          add_account_box.pack_start(username_box, expand: false, fill: false, padding: 0)

          # Create password entry
          password_box = Gtk::Box.new(:horizontal, 5)
          password_box.pack_start(Gtk::Label.new("Password:"), expand: false, fill: false, padding: 0)

          password_entry = Gtk::Entry.new
          password_entry.visibility = false
          password_box.pack_start(password_entry, expand: true, fill: true, padding: 0)

          add_account_box.pack_start(password_box, expand: false, fill: false, padding: 0)

          # Create button box
          button_box = Gtk::Box.new(:horizontal, 5)

          # Create back button to return to accounts tab
          back_button = Gtk::Button.new(label: "Back to Accounts")
          button_box.pack_start(back_button, expand: false, fill: false, padding: 0)

          # Create add button
          add_button = Gtk::Button.new(label: "Add Account")
          button_box.pack_end(add_button, expand: false, fill: false, padding: 0)

          add_account_box.pack_start(button_box, expand: false, fill: false, padding: 0)

          # Add tab to notebook
          notebook.append_page(add_account_box, Gtk::Label.new("Add Account"))

          # Set up back button handler
          back_button.signal_connect('clicked') do
            # Switch to Accounts tab (index 0)
            notebook.set_page(0)
          end

          # Set up add button handler with automatic account information collection
          add_button.signal_connect('clicked') do
            username = username_entry.text
            password = password_entry.text

            if username.empty?
              @msgbox.call("Username cannot be empty.")
              next
            end

            if password.empty?
              @msgbox.call("Password cannot be empty.")
              next
            end

            # Step 1: Check if account already exists in YAML structure
            if account_already_exists?(username)
              @msgbox.call("Account '#{username}' already exists. Use 'Change Password' to update the password.")
              next
            end

            # Step 2: Perform authentication like manual login to collect account information
            begin
              # Authenticate with legacy mode to get character list (returns array of character hashes)
              auth_data = Authentication.authenticate(
                account: username,
                password: password,
                legacy: true
              )

              # Step 3: Collect all account information and convert to YAML format
              if auth_data && auth_data.is_a?(Array) && !auth_data.empty?
                # Show frontend selection dialog
                selected_frontend = show_frontend_selection_dialog
                return if selected_frontend.nil? # User cancelled

                # Convert character data to the format expected by YAML storage
                character_list = convert_auth_data_to_characters(auth_data, selected_frontend)

                # Step 4: Save account and characters to entry.yml file
                if AccountManager.add_or_update_account(@data_dir, username, password, character_list)
                  @msgbox.call("Account '#{username}' added successfully with #{character_list.length} character(s).")
                  username_entry.text = ""
                  password_entry.text = ""

                  # Step 5: Reset window interface to display results
                  # Notify other tabs of data change
                  notify_data_changed(:account_added, {
                    account: username,
                    characters: character_list
                  })

                  notebook.set_page(0)
                  # Find the accounts store in the first tab and refresh it
                  accounts_tab = notebook.get_nth_page(0)
                  accounts_view = find_treeview_in_container(accounts_tab)
                  if accounts_view
                    populate_accounts_view(accounts_view.model)
                  end
                else
                  @msgbox.call("Failed to save account information.")
                end
              elsif auth_data && auth_data.is_a?(Array) && auth_data.empty?
                @msgbox.call("No characters found for account '#{username}'. Account will be added without characters.")
                # Save account without characters
                if AccountManager.add_or_update_account(@data_dir, username, password, [])
                  username_entry.text = ""
                  password_entry.text = ""
                  # Notify other tabs of data change
                  notify_data_changed(:account_added, {
                    account: username,
                    characters: []
                  })

                  notebook.set_page(0)
                  accounts_tab = notebook.get_nth_page(0)
                  accounts_view = find_treeview_in_container(accounts_tab)
                  if accounts_view
                    populate_accounts_view(accounts_view.model)
                  end
                else
                  @msgbox.call("Failed to save account information.")
                end
              else
                @msgbox.call("Authentication failed or returned unexpected data format.")
              end
            rescue StandardError => e
              @msgbox.call("Authentication failed: #{e.message}")
            end
          end
          # Set up ENTER key handlers for username and password fields
          username_entry.signal_connect('key-press-event') { |_widget, event|
            if event.keyval == Gdk::Keyval::KEY_Return
              add_button.clicked
              true
            else
              false
            end
          }

          password_entry.signal_connect('key-press-event') { |_widget, event|
            if event.keyval == Gdk::Keyval::KEY_Return
              add_button.clicked
              true
            else
              false
            end
          }
        end

        private

        # Notifies other tabs of data changes
        # Triggers the data change callback if one is registered
        #
        # @param change_type [Symbol] Type of change that occurred
        # @param data [Hash] Additional data about the change
        # @return [void]
        def notify_data_changed(change_type = :general, data = {})
          if @data_change_callback
            begin
              @data_change_callback.call(change_type, data)
            rescue StandardError => e
              Lich.log "error: Error in data change callback: #{e.message}"
            end
          end
        end

        # Sets up the add character handlers with data change notification
        # Configures event handlers for the add character functionality
        #
        # @param add_button [Gtk::Button] Add character button
        # @param account_combo [Gtk::ComboBoxText] Account selection combo
        # @param refresh_button [Gtk::Button] Refresh button
        # @param char_name_entry [Gtk::Entry] Character name entry
        # @param game_combo [Gtk::ComboBoxText] Game selection combo
        # @param stormfront_option [Gtk::RadioButton] Stormfront radio button
        # @param wizard_option [Gtk::RadioButton] Wizard radio button
        # @param avalon_option [Gtk::RadioButton] Avalon radio button
        # @param custom_launch_entry [Gtk::Entry] Custom launch entry
        # @param custom_launch_dir_entry [Gtk::Entry] Custom launch directory entry
        # @param notebook [Gtk::Notebook] Parent notebook
        # @return [void]
        def setup_add_character_handlers(add_button, account_combo, refresh_button, char_name_entry, game_combo, _stormfront_option, wizard_option, avalon_option, custom_launch_entry, custom_launch_dir_entry, notebook)
          # Set up refresh button handler
          refresh_button.signal_connect('clicked') do
            populate_account_combo(account_combo)
          end

          # Set up add button handler
          add_button.signal_connect('clicked') do
            account = account_combo.active_text
            character = char_name_entry.text
            game_text = game_combo.active_text
            custom_launch = custom_launch_entry.text
            custom_launch_dir = custom_launch_dir_entry.text

            if account.nil? || account.empty?
              @msgbox.call("Please select an account.")
              next
            end

            if character.empty?
              @msgbox.call("Character name cannot be empty.")
              next
            end

            if game_text.nil? || game_text.empty?
              @msgbox.call("Please select a game.")
              next
            end

            # Determine frontend
            frontend = if wizard_option.active?
                         'wizard'
                       elsif avalon_option.active?
                         'avalon'
                       else
                         'stormfront'
                       end

            # Get game code from game text
            game_code = GameSelection.get_selected_game_code(game_combo)

            # Create character data
            character_data = {
              char_name: character,
              game_code: game_code,
              game_name: game_text,
              frontend: frontend,
              custom_launch: custom_launch.empty? ? nil : custom_launch,
              custom_launch_dir: custom_launch_dir.empty? ? nil : custom_launch_dir
            }

            # Add character to account
            result = AccountManager.add_character(@data_dir, account, character_data)

            if result[:success]
              @msgbox.call(result[:message])
              char_name_entry.text = ""
              custom_launch_entry.text = ""
              custom_launch_dir_entry.text = ""

              # Notify other tabs of data change
              notify_data_changed(:character_added, {
                account: account,
                character: character,
                game_code: game_code,
                game_name: game_text,
                frontend: frontend
              })

              # Refresh the accounts view to show the new character
              notebook.set_page(0)
              accounts_tab = notebook.get_nth_page(0)
              accounts_view = find_treeview_in_container(accounts_tab)
              if accounts_view
                populate_accounts_view(accounts_view.model)
              end
            else
              @msgbox.call(result[:message])
            end
          end
        end

        # Sets up the favorites column click handler with data change notification
        # Configures click handling for the favorites column in the accounts view
        #
        # @param accounts_view [Gtk::TreeView] Accounts tree view
        # @param favorites_col [Gtk::TreeViewColumn] Favorites column
        # @param data_dir [String] Data directory
        # @return [void]
        def setup_favorites_column_handler(accounts_view, favorites_col, data_dir)
          accounts_view.signal_connect('button-press-event') do |_widget, event|
            if event.button == 1 # Left click
              path, column = accounts_view.get_path_at_pos(event.x, event.y)
              if path && column == favorites_col
                iter = accounts_view.model.get_iter(path)
                if iter && !iter[1].nil? && !iter[1].empty? # Character row (has character name)
                  account = iter[0]
                  character = iter[1]
                  game_code = iter[4]
                  frontend_display = iter[3]

                  # Convert display name back to internal frontend format
                  frontend = case frontend_display.downcase
                             when 'wrayth', 'custom'
                               'stormfront'
                             when 'wizard'
                               'wizard'
                             when 'avalon'
                               'avalon'
                             else
                               frontend_display.downcase
                             end

                  # Toggle favorite status with frontend precision
                  new_status = FavoritesManager.toggle_favorite(data_dir, account, character, game_code, frontend)
                  iter[5] = new_status ? '★' : '☆'

                  # Notify other tabs of data change
                  notify_data_changed(:favorite_toggled, {
                    account: account,
                    character: character,
                    game_code: game_code,
                    is_favorite: new_status
                  })
                end
              end
            end
            false # Allow other handlers to process the event
          end
        end

        # Checks if an account already exists in the YAML structure
        #
        # @param username [String] Account username to check
        # @return [Boolean] True if account exists
        def account_already_exists?(username)
          yaml_file = File.join(@data_dir, "entry.yml")
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            return false unless yaml_data && yaml_data['accounts']

            yaml_data['accounts'].key?(username)
          rescue StandardError => e
            Lich.log "error: Error checking if account exists: #{e.message}"
            false
          end
        end

        # Converts authentication data to character format for YAML storage
        #
        # @param auth_data [Array] Array of character hashes from authentication
        # @param frontend [String] Selected frontend for all characters
        # @return [Array] Array of character data hashes formatted for YAML storage
        def convert_auth_data_to_characters(auth_data, frontend = 'stormfront')
          characters = []
          return characters unless auth_data.is_a?(Array)

          auth_data.each do |char_data|
            # Ensure we have the required fields with symbol keys (as returned by authentication)
            next unless char_data.is_a?(Hash) &&
                        char_data.key?(:char_name) &&
                        char_data.key?(:game_name) &&
                        char_data.key?(:game_code)

            characters << {
              char_name: char_data[:char_name],
              game_code: char_data[:game_code],
              game_name: char_data[:game_name],
              frontend: frontend
            }
          end

          characters
        end

        # Shows a frontend selection dialog similar to manual login
        #
        # @return [String, nil] Selected frontend or nil if cancelled
        def show_frontend_selection_dialog
          # Create dialog
          dialog = Gtk::Dialog.new(
            title: "Select Frontend",
            parent: @window,
            flags: :modal,
            buttons: [
              [Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL],
              [Gtk::Stock::OK, Gtk::ResponseType::OK]
            ]
          )

          # Create content area
          content_area = dialog.content_area
          content_area.border_width = 10

          # Add instruction label
          label = Gtk::Label.new("Select the frontend to use for all characters:")
          content_area.pack_start(label, expand: false, fill: false, padding: 10)

          # Create frontend selection radio buttons (similar to manual login)
          stormfront_option = Gtk::RadioButton.new(label: 'Wrayth')
          wizard_option = Gtk::RadioButton.new(label: 'Wizard', member: stormfront_option)
          avalon_option = Gtk::RadioButton.new(label: 'Avalon', member: stormfront_option)

          # Set Wrayth (stormfront) as default
          stormfront_option.active = true

          # Create radio button container
          frontend_box = Gtk::Box.new(:vertical, 5)
          frontend_box.pack_start(stormfront_option, expand: false, fill: false, padding: 0)
          frontend_box.pack_start(wizard_option, expand: false, fill: false, padding: 0)

          # Only show Avalon on macOS (consistent with manual login)
          if RUBY_PLATFORM =~ /darwin/i
            frontend_box.pack_start(avalon_option, expand: false, fill: false, padding: 0)
          end

          content_area.pack_start(frontend_box, expand: false, fill: false, padding: 10)

          # Show dialog and get response
          dialog.show_all
          response = dialog.run

          # Determine selected frontend
          selected_frontend = nil
          if response == Gtk::ResponseType::OK
            if wizard_option.active?
              selected_frontend = 'wizard'
            elsif avalon_option.active?
              selected_frontend = 'avalon'
            else
              selected_frontend = 'stormfront' # Default/Wrayth
            end
          end

          dialog.destroy
          selected_frontend
        end

        # Sets up sort state persistence for the account management treeview
        # Saves and restores user's sort column and direction preferences
        #
        # @param store [Gtk::TreeStore] Tree store to set up persistence for
        # @return [void]
        def setup_sort_state_persistence(store)
          # Load saved sort state
          sort_state = load_sort_state

          if sort_state[:column] && sort_state[:order]
            # Convert symbol to GTK constant
            gtk_order = symbol_to_gtk_sort_type(sort_state[:order])
            store.set_sort_column_id(sort_state[:column], gtk_order) if gtk_order
          end

          # Save sort state when it changes
          store.signal_connect('sort-column-changed') do
            column_id, order = store.sort_column_id
            if column_id && order
              # Convert GTK constant to symbol for storage
              symbol_order = gtk_sort_type_to_symbol(order)
              save_sort_state(column_id, symbol_order) if symbol_order
            end
          end
        end

        # Converts a symbol to GTK sort type constant
        #
        # @param symbol [Symbol] Sort order symbol (:ascending or :descending)
        # @return [Gtk::SortType, nil] GTK sort type constant or nil if invalid
        def symbol_to_gtk_sort_type(symbol)
          case symbol
          when :ascending
            Gtk::SortType::ASCENDING
          when :descending
            Gtk::SortType::DESCENDING
          else
            nil
          end
        end

        # Converts a GTK sort type constant to symbol
        #
        # @param gtk_type [Gtk::SortType] GTK sort type constant
        # @return [Symbol, nil] Sort order symbol or nil if invalid
        def gtk_sort_type_to_symbol(gtk_type)
          case gtk_type
          when Gtk::SortType::ASCENDING
            :ascending
          when Gtk::SortType::DESCENDING
            :descending
          else
            nil
          end
        end

        # Loads the saved sort state from user preferences
        #
        # @return [Hash] Hash containing :column and :order keys
        def load_sort_state
          begin
            settings_file = File.join(@data_dir, 'account_manager_sort.yml')
            if File.exist?(settings_file)
              YAML.load_file(settings_file) || {}
            else
              {}
            end
          rescue StandardError => e
            Lich.log "warning: Could not load sort state: #{e.message}"
            {}
          end
        end

        # Saves the current sort state to user preferences
        #
        # @param column_id [Integer] Sort column ID
        # @param order [Symbol] Sort order symbol (:ascending or :descending)
        # @return [void]
        def save_sort_state(column_id, order)
          begin
            settings_file = File.join(@data_dir, 'account_manager_sort.yml')
            sort_state = {
              column: column_id,
              order: order
            }

            File.open(settings_file, 'w') do |file|
              file.write(YAML.dump(sort_state))
            end
          rescue StandardError => e
            Lich.log "warning: Could not save sort state: #{e.message}"
          end
        end

        # Sets up account-aware sorting that maintains account grouping
        # Characters are sorted within their account groups, but accounts remain grouped
        #
        # @param store [Gtk::TreeStore] Tree store to set up sorting for
        # @return [void]
        def setup_account_aware_sorting(store)
          # Character column sorting (column 1)
          store.set_sort_func(1) do |model, a, b|
            account_aware_sort_compare(model, a, b, 1)
          end

          # Game column sorting (column 2)
          store.set_sort_func(2) do |model, a, b|
            account_aware_sort_compare(model, a, b, 2)
          end

          # Frontend column sorting (column 3)
          store.set_sort_func(3) do |model, a, b|
            account_aware_sort_compare(model, a, b, 3)
          end
        end

        # Custom sort comparison that maintains account grouping
        # Account nodes always sort before character nodes
        # Character nodes sort within their account group by the specified column
        #
        # @param model [Gtk::TreeModel] Tree model
        # @param a [Gtk::TreeIter] First iterator
        # @param b [Gtk::TreeIter] Second iterator
        # @param sort_column [Integer] Column to sort by
        # @return [Integer] Sort comparison result (-1, 0, 1)
        def account_aware_sort_compare(model, a, b, sort_column)
          # Check if either is an account node (has no parent)
          a_is_account = model.iter_parent(a).nil?
          b_is_account = model.iter_parent(b).nil?

          # Account nodes always come before character nodes
          return -1 if a_is_account && !b_is_account
          return 1 if !a_is_account && b_is_account

          # Both are account nodes - sort by account name
          if a_is_account && b_is_account
            return model.get_value(a, 0) <=> model.get_value(b, 0)
          end

          # Both are character nodes - check if they're in the same account
          a_parent = model.iter_parent(a)
          b_parent = model.iter_parent(b)

          a_account = model.get_value(a_parent, 0)
          b_account = model.get_value(b_parent, 0)

          # If different accounts, sort by account name first
          account_comparison = a_account <=> b_account
          return account_comparison unless account_comparison == 0

          # Same account - sort by the specified column
          a_value = model.get_value(a, sort_column) || ""
          b_value = model.get_value(b, sort_column) || ""

          # Case-insensitive comparison for better user experience
          a_value.downcase <=> b_value.downcase
        end

        # Helper method to find a TreeView widget within a container
        #
        # @param container [Gtk::Container] Container to search
        # @return [Gtk::TreeView, nil] Found TreeView or nil
        def find_treeview_in_container(container)
          return nil unless container.is_a?(Gtk::Container)

          container.each do |child|
            if child.is_a?(Gtk::TreeView)
              return child
            elsif child.is_a?(Gtk::Container)
              result = find_treeview_in_container(child)
              return result if result
            end
          end

          nil
        end

        # Populates the accounts view with data from the YAML file
        #
        # @param store [Gtk::TreeStore] Tree store to populate
        # @return [void]
        def populate_accounts_view(store)
          store.clear

          # Get accounts data
          accounts_data = AccountManager.get_all_accounts(@data_dir)

          # Add accounts to tree store
          accounts_data.each do |account, characters|
            account_iter = store.append(nil)
            account_iter[0] = account

            # Add characters to account
            characters.each do |character|
              char_iter = store.append(account_iter)
              char_iter[0] = account
              char_iter[1] = character[:char_name]
              char_iter[2] = character[:game_name]
              # Set frontend display with custom handling
              if character[:custom_launch] && !character[:custom_launch].empty?
                char_iter[3] = 'Custom'
              else
                char_iter[3] = character[:frontend].capitalize == 'Stormfront' ? 'Wrayth' : character[:frontend].capitalize
              end
              char_iter[4] = character[:game_code] # Store game_code in hidden column

              # Add favorites information with frontend precision
              is_favorite = FavoritesManager.is_favorite?(@data_dir, account, character[:char_name], character[:game_code], character[:frontend])
              char_iter[5] = is_favorite ? '★' : '☆'
            end
          end
        end

        # Populates the account combo box with account names
        #
        # @param combo [Gtk::ComboBoxText] Combo box to populate
        # @return [void]
        def populate_account_combo(combo)
          combo.remove_all

          # Get accounts data
          accounts_data = AccountManager.get_all_accounts(@data_dir)

          # Add accounts to combo box
          accounts_data.keys.sort.each do |account|
            combo.append_text(account)
          end

          # Select first account if available
          combo.active = 0 if accounts_data.any?
        end

        # Shows a message dialog
        #
        # @param message [String] Message to display
        # @return [void]
        def show_message_dialog(message)
          dialog = Gtk::MessageDialog.new(
            parent: @window,
            flags: :modal,
            type: :info,
            buttons: :ok,
            message: message
          )
          dialog.run
          dialog.destroy
        end

        # Shows the management window
        #
        # @return [void]
        def show_management_window
          @window = Gtk::Window.new(:toplevel)
          @window.title = "Account Management"
          @window.set_default_size(800, 600)
          @window.border_width = 10

          # Create notebook for tabs
          notebook = Gtk::Notebook.new

          # Create tabs
          create_accounts_tab(notebook)
          create_add_character_tab(notebook)
          create_add_account_tab(notebook)

          @window.add(notebook)
          @window.show_all

          # Handle window close
          @window.signal_connect('delete_event') do
            @window.destroy
            false
          end
        end
      end
    end
  end
end
