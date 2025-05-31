# frozen_string_literal: true

require_relative 'parameter_objects'
require_relative 'login_tab_utils'
require_relative 'theme_utils'

module Lich
  module Common
    module GUI
      # Handles the "Saved Entry" tab functionality for the Lich GUI login system
      # Provides a class-based implementation for the saved login tab
      class SavedLoginTab
        # Initializes a new SavedLoginTab instance
        #
        # @param parent [Object] Parent window or container
        # @param entry_data [Array] Array of saved login entries
        # @param theme_state [Boolean] Whether dark theme is enabled
        # @param tab_layout_state [Boolean] Whether tab layout is enabled
        # @param autosort_state [Boolean] Whether auto-sorting is enabled
        # @param default_icon [Gdk::Pixbuf] Default icon for dialogs
        # @param callbacks [Hash, CallbackParams] Callback handlers for various events
        # @return [SavedLoginTab] New instance
        def initialize(parent, entry_data, theme_state, tab_layout_state, autosort_state, default_icon, callbacks = {})
          @parent = parent
          @entry_data = entry_data
          @default_icon = default_icon

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

          # Apply theme settings
          ThemeUtils.apply_theme_settings(@ui_config.theme_state)

          # Create the tab content
          create_tab_content
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

          # Create and add global settings components
          create_global_settings_components
        end

        # Creates a tabbed layout for accounts
        # Organizes saved entries by account in a tabbed interface
        #
        # @return [Gtk::ScrolledWindow] Scrolled window containing the account book
        def create_tabbed_layout
          @account_book = Gtk::Notebook.new
          @account_book.set_tab_pos(:left)
          @account_book.show_border = true

          # Apply theme styling
          unless @ui_config.theme_state
            @account_book.override_background_color(:normal, ThemeUtils.light_theme_background)
            @tab_provider = Utilities.create_tab_css_provider
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
          quick_sw.set_policy(:automatic, :automatic)
          quick_sw.add(@account_book)

          quick_sw
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
            frontend_display = login_params.frontend.capitalize == 'Stormfront' ? 'Wrayth' : login_params.frontend.capitalize
            custom_indicator = login_params.custom_launch ? ' custom' : ''

            label = Gtk::Label.new("#{login_params.char_name} (#{login_params.game_name}, #{frontend_display}#{custom_indicator})")
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
          quick_sw.set_policy(:automatic, :automatic)
          quick_sw.add(quick_vp)

          quick_sw
        end

        # Creates a character entry in the tabbed layout
        # Builds a UI element for a single character entry
        #
        # @param account_box [Gtk::Box] Box to add the character entry to
        # @param login_info [Hash] Login information for the character
        # @return [void]
        def create_character_entry(account_box, login_info)
          # Convert to LoginParams object for consistency
          login_params = LoginParams.new(login_info)

          # Get realm name from game code
          realm = Utilities.game_code_to_realm(login_params.game_code)

          # Create button styling
          @button_provider = LoginTabUtils.create_button_css_provider(font_size: 14)

          # Create play button with character info
          @play_button = Gtk::Button.new()
          char_label = Gtk::Label.new(login_params.char_name)
          char_label.set_width_chars(15)

          frontend_display = login_params.frontend.capitalize == 'Stormfront' ? 'Wrayth' : login_params.frontend.capitalize
          custom_indicator = login_params.custom_launch ? ' custom' : ''

          fe_label = Gtk::Label.new("(#{frontend_display})#{custom_indicator}")
          fe_label.set_width_chars(15)
          instance_label = Gtk::Label.new(realm)
          instance_label.set_width_chars(10)
          char_label.set_alignment(0, 0.5)

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

          # Apply styling
          @remove_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)
          @play_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)
          @account_book.style_context.add_provider(@tab_provider, Gtk::StyleProvider::PRIORITY_USER) unless @ui_config.theme_state

          # Create character box with play and remove buttons
          char_box = Gtk::Box.new(:horizontal)
          char_box.pack_end(@remove_button, expand: true, fill: false, padding: 0)
          char_box.pack_start(@play_button, expand: true, fill: true, padding: 0)
          account_box.pack_start(char_box, expand: false, fill: false, padding: 0)

          # Set up button handlers
          LoginTabUtils.setup_play_button_handler(@play_button, login_params.to_h, @callbacks.on_play)
          LoginTabUtils.setup_remove_button_handler(@remove_button, login_params.to_h, char_box, @default_icon, @callbacks.on_remove)
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
