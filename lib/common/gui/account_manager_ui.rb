# frozen_string_literal: true

require 'yaml'
require 'gtk3'

module Lich
  module Common
    module GUI
      # Provides a user interface for managing accounts and characters
      # Implements the account management feature for the Lich GUI login system
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
        end

        # Creates the accounts tab
        #
        # @param notebook [Gtk::Notebook] Notebook to add tab to
        # @return [void]
        def create_accounts_tab(notebook)
          # Create tab content
          accounts_box = Gtk::Box.new(:vertical, 10)
          accounts_box.border_width = 10

          # Create accounts treeview
          accounts_store = Gtk::TreeStore.new(String, String, String, String, String) # Added hidden column for game_code
          accounts_view = Gtk::TreeView.new(accounts_store)

          # Add columns
          renderer = Gtk::CellRendererText.new

          # Account column
          col = Gtk::TreeViewColumn.new("Account", renderer, text: 0)
          col.resizable = true
          accounts_view.append_column(col)

          # Character column (was incorrectly labeled as Game column)
          col = Gtk::TreeViewColumn.new("Character", renderer, text: 1)
          col.resizable = true
          accounts_view.append_column(col)

          # Game column (was incorrectly labeled as Character column)
          col = Gtk::TreeViewColumn.new("Game", renderer, text: 2)
          col.resizable = true
          accounts_view.append_column(col)

          # Frontend column
          col = Gtk::TreeViewColumn.new("Frontend", renderer, text: 3)
          col.resizable = true
          accounts_view.append_column(col)

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
                  # Remove character
                  if AccountManager.remove_character(@data_dir, account, character, game_code)
                    @msgbox.call("Character removed successfully.")
                    populate_accounts_view(accounts_store)
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
              require_relative 'gui/password_change'
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
          profanity_option = Gtk::RadioButton.new(label: 'Profanity', member: stormfront_option)

          frontend_radio_box.pack_start(stormfront_option, expand: false, fill: false, padding: 0)
          frontend_radio_box.pack_start(wizard_option, expand: false, fill: false, padding: 0)
          frontend_radio_box.pack_start(profanity_option, expand: false, fill: false, padding: 0)
          frontend_radio_box.pack_start(avalon_option, expand: false, fill: false, padding: 0)

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
            profanity_option,
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

          # Set up add button handler
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

            # Add account
            if AccountManager.add_or_update_account(@data_dir, username, password)
              @msgbox.call("Account added successfully.")
              username_entry.text = ""
              password_entry.text = ""

              # Return to accounts tab and refresh
              notebook.set_page(0)
              # Find the accounts store in the first tab and refresh it
              accounts_tab = notebook.get_nth_page(0)
              accounts_view = find_treeview_in_container(accounts_tab)
              if accounts_view
                populate_accounts_view(accounts_view.model)
              end
            else
              @msgbox.call("Failed to add account.")
            end
          end
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
              char_iter[3] = character[:frontend].capitalize == 'Stormfront' ? 'Wrayth' : character[:frontend].capitalize
              char_iter[4] = character[:game_code] # Store game_code in hidden column
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
          combo.active = 0 if accounts_data.keys.any?
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

        # Sets up event handlers for the add character tab
        #
        # @param add_button [Gtk::Button] Add character button
        # @param account_combo [Gtk::ComboBoxText] Account selection combo box
        # @param refresh_button [Gtk::Button] Refresh button
        # @param char_name_entry [Gtk::Entry] Character name entry
        # @param game_combo [Gtk::ComboBoxText] Game selection combo box
        # @param stormfront_option [Gtk::RadioButton] Stormfront radio button
        # @param wizard_option [Gtk::RadioButton] Wizard radio button
        # @param avalon_option [Gtk::RadioButton] Avalon radio button
        # @param profanity_option [Gtk::RadioButton] Profanity radio button
        # @param custom_launch_entry [Gtk::Entry] Custom launch entry
        # @param custom_launch_dir_entry [Gtk::Entry] Custom launch directory entry
        # @param notebook [Gtk::Notebook] Notebook containing the tabs
        # @return [void]
        def setup_add_character_handlers(
          add_button,
          account_combo,
          refresh_button,
          char_name_entry,
          game_combo,
          stormfront_option,
          wizard_option,
          avalon_option,
          profanity_option,
          custom_launch_entry,
          custom_launch_dir_entry,
          notebook
        )
          # Refresh button handler
          refresh_button.signal_connect('clicked') do
            populate_account_combo(account_combo)
          end

          # Add character button handler
          add_button.signal_connect('clicked') do
            username = account_combo.active_text
            char_name = char_name_entry.text
            game_name = game_combo.active_text
            custom_launch = custom_launch_entry.text
            custom_launch_dir = custom_launch_dir_entry.text

            if username.nil? || username.empty?
              @msgbox.call("Please select an account.")
              next
            end

            if char_name.empty?
              @msgbox.call("Character name cannot be empty.")
              next
            end

            # Determine frontend
            frontend = if wizard_option.active?
                         'wizard'
                       elsif avalon_option.active?
                         'avalon'
                       elsif profanity_option.active?
                         'profanity'
                       elsif stormfront_option.active?
                         'stormfront'
                       else
                         'stormfront' # Default fallback
                       end

            # Determine game code
            game_code = Utilities.realm_to_game_code(game_name)

            # Create character data
            character_data = {
              char_name: char_name,
              game_code: game_code,
              game_name: game_name,
              frontend: frontend
            }

            # Only add custom_launch and custom_launch_dir if they're not empty
            character_data[:custom_launch] = custom_launch unless custom_launch.empty?
            character_data[:custom_launch_dir] = custom_launch_dir unless custom_launch_dir.empty?

            # Add character
            if AccountManager.add_character(@data_dir, username, character_data)
              @msgbox.call("Character added successfully.")
              char_name_entry.text = ""
              custom_launch_entry.text = ""
              custom_launch_dir_entry.text = ""

              # Return to accounts tab and refresh
              notebook.set_page(0)
              # Find the accounts store in the first tab and refresh it
              accounts_tab = notebook.get_nth_page(0)
              accounts_view = find_treeview_in_container(accounts_tab)
              if accounts_view
                populate_accounts_view(accounts_view.model)
              end
            else
              @msgbox.call("Failed to add character.")
            end
          end
        end
      end
    end
  end
end
