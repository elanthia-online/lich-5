# frozen_string_literal: true

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
        # @param callbacks [Hash] Callback handlers for various events
        def initialize(parent, entry_data, theme_state, tab_layout_state, autosort_state, default_icon, callbacks = {})
          @parent = parent
          @entry_data = entry_data
          @theme_state = theme_state
          @tab_layout_state = tab_layout_state
          @autosort_state = autosort_state
          @default_icon = default_icon
          @callbacks = callbacks

          # Apply theme settings
          State.apply_theme_settings(@theme_state)

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
          @theme_state = theme_state
          apply_theme_to_ui_elements
        end

        private

        # Applies the current theme state to all UI elements
        #
        # @return [void]
        def apply_theme_to_ui_elements
          if @theme_state
            # Enable dark theme
            Gtk::Settings.default.gtk_application_prefer_dark_theme = true
            # Remove styling providers that might conflict with dark theme
            @play_button.style_context.remove_provider(@button_provider) if defined?(@button_provider) && @play_button
            @account_book.style_context.remove_provider(@tab_provider) if defined?(@tab_provider) && @account_book
            # Reset background colors to transparent for dark theme
            @account_book.override_background_color(:normal, Gdk::RGBA::parse("rgba(0,0,0,0)")) if defined?(@account_book) && @account_book
            @notebook.override_background_color(:normal, Gdk::RGBA::parse("rgba(0,0,0,0)")) if defined?(@notebook) && @notebook
          else
            # Disable dark theme
            Gtk::Settings.default.gtk_application_prefer_dark_theme = false
            # Set light grey background for light theme
            lightgrey = Gdk::RGBA::parse("#d3d3d3")
            @account_book.override_background_color(:normal, lightgrey) if defined?(@account_book) && @account_book
            @notebook.override_background_color(:normal, lightgrey) if defined?(@notebook) && @notebook
            # Re-apply styling providers for light theme
            if defined?(@button_provider) && @play_button
              @play_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)
            end
            if defined?(@tab_provider) && @account_book
              @account_book.style_context.add_provider(@tab_provider, Gtk::StyleProvider::PRIORITY_USER)
            end
          end
        end

        # Creates the tab content
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
        #
        # @return [void]
        def create_populated_tab
          last_user_id = nil

          # Create the appropriate layout based on settings
          quick_sw = if @tab_layout_state == true
                       create_tabbed_layout
                     else
                       create_list_layout(last_user_id)
                     end

          # Create toggle button styling
          @togglebutton_provider = Utilities.create_button_css_provider

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
        #
        # @return [Gtk::ScrolledWindow] Scrolled window containing the account book
        def create_tabbed_layout
          @account_book = Gtk::Notebook.new
          @account_book.set_tab_pos(:left)
          @account_book.show_border = true

          # Apply theme styling
          unless @theme_state == true
            lightgrey = Gdk::RGBA::parse("#d3d3d3")
            @account_book.override_background_color(:normal, lightgrey)

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
        #
        # @param last_user_id [String] Last processed user ID
        # @return [Gtk::ScrolledWindow] Scrolled window containing the account list
        def create_list_layout(last_user_id)
          quick_box = Gtk::Box.new(:vertical, 0)

          # Process each login entry
          @entry_data.each { |login_info|
            # Add account header if this is a new account
            if login_info[:user_id].downcase != last_user_id
              last_user_id = login_info[:user_id].downcase
              quick_box.pack_start(Gtk::Label.new("Account: " + last_user_id), expand: false, fill: false, padding: 6)
            end

            # Create character entry with play and remove buttons
            label = Gtk::Label.new("#{login_info[:char_name]} (#{login_info[:game_name]}, #{login_info[:frontend].capitalize == 'Stormfront' ? 'Wrayth' : login_info[:frontend].capitalize}#{login_info[:custom_launch] ? ' custom' : ''})")
            play_button = Components.create_button(label: 'Play')
            remove_button = Components.create_button(label: 'X')

            # Apply button styling
            @button_provider = Utilities.create_button_css_provider
            remove_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)
            play_button.style_context.add_provider(@button_provider, Gtk::StyleProvider::PRIORITY_USER)

            # Create character box with label and buttons
            char_box = Gtk::Box.new(:horizontal)
            char_box.pack_start(label, expand: false, fill: false, padding: 0)
            char_box.pack_end(remove_button, expand: false, fill: false, padding: 0)
            char_box.pack_end(play_button, expand: false, fill: false, padding: 0)
            quick_box.pack_start(char_box, expand: false, fill: false, padding: 0)

            # Set up button handlers
            setup_play_button_handler(play_button, login_info)
            setup_remove_button_handler(remove_button, login_info, char_box)
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
        #
        # @param account_box [Gtk::Box] Box to add the character entry to
        # @param login_info [Hash] Login information for the character
        # @return [void]
        def create_character_entry(account_box, login_info)
          # Get realm name from game code
          realm = Utilities.game_code_to_realm(login_info[:game_code])

          # Create button styling
          @button_provider = Utilities.create_button_css_provider(font_size: 14)

          # Create play button with character info
          @play_button = Gtk::Button.new()
          char_label = Gtk::Label.new(login_info[:char_name])
          char_label.set_width_chars(15)
          fe_label = Gtk::Label.new("(#{login_info[:frontend].capitalize == 'Stormfront' ? 'Wrayth' : login_info[:frontend].capitalize})#{login_info[:custom_launch] ? ' custom' : ''}")
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
          @account_book.style_context.add_provider(@tab_provider, Gtk::StyleProvider::PRIORITY_USER) unless @theme_state == true

          # Create character box with play and remove buttons
          char_box = Gtk::Box.new(:horizontal)
          char_box.pack_end(@remove_button, expand: true, fill: false, padding: 0)
          char_box.pack_start(@play_button, expand: true, fill: true, padding: 0)
          account_box.pack_start(char_box, expand: false, fill: false, padding: 0)

          # Set up button handlers
          setup_play_button_handler(@play_button, login_info)
          setup_remove_button_handler(@remove_button, login_info, char_box)
        end

        # Sets up the play button handler
        #
        # @param button [Gtk::Button] The play button
        # @param login_info [Hash] Login information for the character
        # @return [void]
        def setup_play_button_handler(button, login_info)
          button.signal_connect('button-release-event') { |_owner, ev|
            if (ev.event_type == Gdk::EventType::BUTTON_RELEASE)
              if (ev.button == 1)
                button.sensitive = false

                # Authenticate and prepare launch data
                launch_data_hash = Authentication.authenticate(
                  account: login_info[:user_id],
                  password: login_info[:password],
                  character: login_info[:char_name],
                  game_code: login_info[:game_code]
                )

                launch_data = Authentication.prepare_launch_data(
                  launch_data_hash,
                  login_info[:frontend],
                  login_info[:custom_launch],
                  login_info[:custom_launch_dir]
                )

                # Call the play callback if provided
                if @callbacks[:on_play]
                  @callbacks[:on_play].call(launch_data)
                end
              elsif (ev.button == 3)
                pp "I would be adding to a team tab"
              end
            end
          }
        end

        # Sets up the remove button handler
        #
        # @param button [Gtk::Button] The remove button
        # @param login_info [Hash] Login information for the character
        # @param char_box [Gtk::Box] The character box containing the button
        # @return [void]
        def setup_remove_button_handler(button, login_info, char_box)
          button.signal_connect('button-release-event') { |_owner, ev|
            if (ev.event_type == Gdk::EventType::BUTTON_RELEASE) and (ev.button == 1)
              if (ev.state.inspect =~ /shift-mask/)
                # Call the remove callback if provided
                if @callbacks[:on_remove]
                  @callbacks[:on_remove].call(login_info)
                end
                char_box.visible = false
              else
                dialog = Gtk::MessageDialog.new(
                  parent: nil,
                  flags: :modal,
                  type: :question,
                  buttons: :yes_no,
                  message: "Delete record?"
                )
                dialog.title = "Confirm"
                dialog.set_icon(@default_icon)
                response = dialog.run
                dialog.destroy
                if response == Gtk::ResponseType::YES
                  # Call the remove callback if provided
                  if @callbacks[:on_remove]
                    @callbacks[:on_remove].call(login_info)
                  end
                  char_box.visible = false
                end
              end
            end
          }
        end

        # Creates character management components
        #
        # @return [void]
        def create_character_management_components
          # Character management components
          add_character_pane = Gtk::Paned.new(:horizontal)
          add_instance_pane = Gtk::Paned.new(:horizontal)

          # Character input
          add_char_label = Gtk::Label.new("Character")
          add_char_label.set_width_chars(15)
          add_char_entry = Gtk::Entry.new
          add_char_entry.set_width_chars(15)
          add_character_pane.add1(add_char_label)
          add_character_pane.pack2(add_char_entry)

          # Instance selection
          add_inst_select = Gtk::ComboBoxText.new(entry: true)
          add_inst_select.child.text = "Prime"
          add_inst_select.append_text("Prime")
          add_inst_select.append_text("Platinum")
          add_inst_select.append_text("Shattered")
          add_inst_select.append_text("Test")
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
          add_char_button.signal_connect('clicked') {
            # Handle adding a character
            if @callbacks[:on_add_character]
              frontend = if q_wizard_option.active?
                           'wizard'
                         elsif q_avalon_option.active?
                           'avalon'
                         else
                           'stormfront'
                         end

              @callbacks[:on_add_character].call(
                character: add_char_entry.text,
                instance: add_inst_select.child.text,
                frontend: frontend
              )
            end
          }
        end

        # Creates global settings components
        #
        # @return [void]
        def create_global_settings_components
          # Global settings components
          @slider_box = Gtk::Box.new(:horizontal, 5)
          theme_select = Gtk::Switch.new
          tab_select = Gtk::Switch.new
          sort_select = Gtk::Switch.new
          theme_select_label = Gtk::Label.new('Dark Theme')
          tab_select_label = Gtk::Label.new('Tab Layout')
          sort_select_label = Gtk::Label.new(' AutoSort   ')
          theme_select.set_active(true) if @theme_state == true
          tab_select.set_active(true) if @tab_layout_state == true
          sort_select.set_active(true) if @autosort_state == true

          # Add switches to slider box
          @slider_box.pack_start(theme_select, expand: true, fill: false, padding: 0)
          @slider_box.pack_start(theme_select_label, expand: true, fill: false, padding: 0)
          @slider_box.pack_start(tab_select, expand: true, fill: false, padding: 0)
          @slider_box.pack_start(tab_select_label, expand: true, fill: false, padding: 0)
          @slider_box.pack_start(sort_select, expand: true, fill: false, padding: 0)
          @slider_box.pack_start(sort_select_label, expand: true, fill: false, padding: 0)

          # Settings toggle button
          @settings_option = Gtk::ToggleButton.new(label: 'Change global GUI settings')
          @settings_option.style_context.add_provider(@togglebutton_provider, Gtk::StyleProvider::PRIORITY_USER)
          @quick_game_entry_tab.pack_start(@settings_option, expand: false, fill: false, padding: 5)
          @quick_game_entry_tab.pack_start(@slider_box, expand: false, fill: false, padding: 5)

          # Settings toggle handler
          @settings_option.signal_connect('toggled') {
            @slider_box.visible = @settings_option.active?
          }

          # Theme switch handler - restored full functionality while maintaining proper variable naming
          theme_select.signal_connect('notify::active') { |_s|
            if theme_select.active?
              # Enable dark theme
              Gtk::Settings.default.gtk_application_prefer_dark_theme = true
              # Remove styling providers that might conflict with dark theme
              @play_button.style_context.remove_provider(@button_provider) if defined?(@button_provider) && @play_button
              @account_book.style_context.remove_provider(@tab_provider) if defined?(@tab_provider) && @account_book
              # Reset background colors to transparent for dark theme
              @account_book.override_background_color(:normal, Gdk::RGBA::parse("rgba(0,0,0,0)")) if defined?(@account_book) && @account_book
              @notebook.override_background_color(:normal, Gdk::RGBA::parse("rgba(0,0,0,0)")) if defined?(@notebook) && @notebook
              # Update state tracking variable
              Lich.track_dark_mode = true

              # Call the theme change callback if provided
              if @callbacks[:on_theme_change]
                @callbacks[:on_theme_change].call(true)
              end
            else
              # Disable dark theme
              Gtk::Settings.default.gtk_application_prefer_dark_theme = false
              # Set light grey background for light theme
              lightgrey = Gdk::RGBA::parse("#d3d3d3")
              @account_book.override_background_color(:normal, lightgrey) if defined?(@account_book) && @account_book
              @notebook.override_background_color(:normal, lightgrey) if defined?(@notebook) && @notebook
              # Update state tracking variable
              Lich.track_dark_mode = false

              # Call the theme change callback if provided
              if @callbacks[:on_theme_change]
                @callbacks[:on_theme_change].call(false)
              end
            end
          }

          # Tab layout switch handler - using proper track_XXX_state= convention
          tab_select.signal_connect('state-set') { |_widget, state|
            Lich.track_layout_state = state

            # Call the layout change callback if provided
            if @callbacks[:on_layout_change]
              @callbacks[:on_layout_change].call(state)
            end

            false
          }

          # Auto sort switch handler - using proper track_XXX_state= convention
          sort_select.signal_connect('state-set') { |_widget, state|
            Lich.track_autosort_state = state

            # Call the sort change callback if provided
            if @callbacks[:on_sort_change]
              @callbacks[:on_sort_change].call(state)
            end

            false
          }

          # Initially hide the slider box
          @slider_box.visible = false
        end

        # Creates a custom launch entry
        #
        # @return [Gtk::ComboBoxText] The custom launch entry widget
        def create_custom_launch_entry
          @custom_launch_entry = Gtk::ComboBoxText.new(entry: true)
          @custom_launch_entry.child.set_placeholder_text("(enter custom launch command)")
          @custom_launch_entry.append_text("Wizard.Exe /GGS /H127.0.0.1 /P%port% /K%key%")
          @custom_launch_entry.append_text("Stormfront.exe /GGS/Hlocalhost/P%port%/K%key%")
          @custom_launch_entry
        end

        # Creates a custom launch directory entry
        #
        # @return [Gtk::ComboBoxText] The custom launch directory widget
        def create_custom_launch_dir
          @custom_launch_dir = Gtk::ComboBoxText.new(entry: true)
          @custom_launch_dir.child.set_placeholder_text("(enter working directory for command)")
          @custom_launch_dir.append_text("../wizard")
          @custom_launch_dir.append_text("../StormFront")
          @custom_launch_dir
        end
      end
    end
  end
end
