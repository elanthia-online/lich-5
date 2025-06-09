# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Shared UI utilities for login tabs
      # Contains common functionality used by both manual and saved login tabs
      module LoginTabUtils
        # Creates a button CSS provider for styling buttons
        #
        # @param font_size [Integer] Font size for the button
        # @return [Gtk::CssProvider] CSS provider for button styling
        def self.create_button_css_provider(font_size: 12)
          css = Gtk::CssProvider.new
          css.load_from_data("button {border-radius: 5px; font-size: #{font_size}px;}")
          css
        end

        # Creates a toggle button CSS provider for styling toggle buttons
        #
        # @return [Gtk::CssProvider] CSS provider for toggle button styling
        def self.create_toggle_button_css_provider
          css = Gtk::CssProvider.new
          css.load_from_data("togglebutton {border-radius: 5px; font-size: 12px;}")
          css
        end

        # Applies theme settings to UI elements
        #
        # @param theme_state [Boolean] Whether dark theme is enabled
        # @param ui_elements [Hash] Hash of UI elements to apply theme to
        # @param providers [Hash] Hash of CSS providers
        # @return [void]
        def self.apply_theme_to_ui_elements(theme_state, ui_elements, providers)
          if theme_state
            # Enable dark theme
            Gtk::Settings.default.gtk_application_prefer_dark_theme = true
            # Remove styling providers that might conflict with dark theme
            ui_elements[:play_button]&.style_context&.remove_provider(providers[:button]) if providers[:button] && ui_elements[:play_button]
            ui_elements[:account_book]&.style_context&.remove_provider(providers[:tab]) if providers[:tab] && ui_elements[:account_book]
            # Reset background colors to transparent for dark theme
            ui_elements[:account_book]&.override_background_color(:normal, Gdk::RGBA::parse("rgba(0,0,0,1)")) if ui_elements[:account_book]
            ui_elements[:notebook]&.override_background_color(:normal, Gdk::RGBA::parse("rgba(0,0,0,1)")) if ui_elements[:notebook]
          else
            # Disable dark theme
            Gtk::Settings.default.gtk_application_prefer_dark_theme = false
            # Set light grey background for light theme
            lightgrey = Gdk::RGBA::parse("#d3d3d3")
            ui_elements[:account_book]&.override_background_color(:normal, lightgrey) if ui_elements[:account_book]
            ui_elements[:notebook]&.override_background_color(:normal, lightgrey) if ui_elements[:notebook]
            # Re-apply styling providers for light theme
            if providers[:button] && ui_elements[:play_button]
              ui_elements[:play_button].style_context.add_provider(providers[:button], Gtk::StyleProvider::PRIORITY_USER)
            end
            if providers[:tab] && ui_elements[:account_book]
              ui_elements[:account_book].style_context.add_provider(providers[:tab], Gtk::StyleProvider::PRIORITY_USER)
            end
          end
        end

        # Sets up the play button handler
        # Configures the click event for the play button to launch the game
        #
        # @param button [Gtk::Button] The play button
        # @param login_info [Hash] Login information for the character
        # @param callback [Proc] Callback to execute when play button is clicked
        # @return [void]
        def self.setup_play_button_handler(button, login_info, callback)
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
                callback.call(launch_data) if callback
              elsif (ev.button == 3)
                pp "I would be adding to a team tab"
              end
            end
          }
        end

        # Sets up the remove button handler
        # Configures the click event for the remove button to delete a saved entry
        #
        # @param button [Gtk::Button] The remove button
        # @param login_info [Hash] Login information for the character
        # @param char_box [Gtk::Box] The character box containing the button
        # @param default_icon [Gdk::Pixbuf] Default icon for dialogs
        # @param callback [Proc] Callback to execute when remove button is clicked
        # @return [void]
        def self.setup_remove_button_handler(button, login_info, char_box, default_icon, callback)
          button.signal_connect('button-release-event') { |_owner, ev|
            if (ev.event_type == Gdk::EventType::BUTTON_RELEASE) and (ev.button == 1)
              if (ev.state & Gdk::ModifierType::SHIFT_MASK) != 0
                # Call the remove callback if provided
                callback.call(login_info) if callback
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
                dialog.set_icon(default_icon) if default_icon
                response = dialog.run
                dialog.destroy
                if response == Gtk::ResponseType::YES
                  # Call the remove callback if provided
                  callback.call(login_info) if callback
                  char_box.visible = false
                end
              end
            end
          }
        end

        # Creates global settings components
        # Builds UI elements for global application settings
        #
        # @param parent_container [Gtk::Container] Container to add settings to
        # @param theme_state [Boolean] Current theme state
        # @param tab_layout_state [Boolean] Current tab layout state
        # @param autosort_state [Boolean] Current autosort state
        # @param callbacks [Hash] Callbacks for settings changes
        # @return [Hash] Hash containing created UI elements
        def self.create_global_settings_components(parent_container, theme_state, tab_layout_state, autosort_state, callbacks)
          # Create toggle button styling
          togglebutton_provider = create_toggle_button_css_provider

          # Global settings components
          slider_box = Gtk::Box.new(:horizontal, 5)
          theme_select = Gtk::Switch.new
          tab_select = Gtk::Switch.new
          sort_select = Gtk::Switch.new
          theme_select_label = Gtk::Label.new('Dark Theme')
          tab_select_label = Gtk::Label.new('Tab Layout')
          sort_select_label = Gtk::Label.new('AutoSort')
          theme_select.set_active(true) if theme_state == true
          tab_select.set_active(true) if tab_layout_state == true
          sort_select.set_active(true) if autosort_state == true

          # Add switches to slider box
          slider_box.pack_start(theme_select, expand: true, fill: false, padding: 0)
          slider_box.pack_start(theme_select_label, expand: true, fill: false, padding: 0)
          slider_box.pack_start(tab_select, expand: true, fill: false, padding: 0)
          slider_box.pack_start(tab_select_label, expand: true, fill: false, padding: 0)
          slider_box.pack_start(sort_select, expand: true, fill: false, padding: 0)
          slider_box.pack_start(sort_select_label, expand: true, fill: false, padding: 0)

          # Settings toggle button
          settings_option = Gtk::ToggleButton.new(label: 'Change global GUI settings')
          settings_option.style_context.add_provider(togglebutton_provider, Gtk::StyleProvider::PRIORITY_USER)
          parent_container.pack_start(settings_option, expand: false, fill: false, padding: 5)
          parent_container.pack_start(slider_box, expand: false, fill: false, padding: 5)

          # Settings toggle handler
          settings_option.signal_connect('toggled') {
            slider_box.visible = settings_option.active?
          }

          # Theme switch handler
          theme_select.signal_connect('notify::active') { |_s|
            if theme_select.active?
              # Update state tracking variable
              Lich.track_dark_mode = true

              # Call the theme change callback if provided
              callbacks[:on_theme_change]&.call(true)
            else
              # Update state tracking variable
              Lich.track_dark_mode = false

              # Call the theme change callback if provided
              callbacks[:on_theme_change]&.call(false)
            end
          }

          # Tab layout switch handler
          tab_select.signal_connect('state-set') { |_widget, state|
            Lich.track_layout_state = state
            callbacks[:on_layout_change]&.call(state)
            false
          }

          # Auto sort switch handler
          sort_select.signal_connect('state-set') { |_widget, state|
            Lich.track_autosort_state = state
            callbacks[:on_sort_change]&.call(state)
            false
          }

          # Initially hide the slider box
          slider_box.visible = false

          # Return created elements
          {
            slider_box: slider_box,
            settings_option: settings_option,
            theme_select: theme_select,
            tab_select: tab_select,
            sort_select: sort_select
          }
        end

        # Creates a custom launch entry
        # Builds a combo box for custom launch commands
        #
        # @return [Gtk::ComboBoxText] The custom launch entry widget
        def self.create_custom_launch_entry
          custom_launch_entry = Gtk::ComboBoxText.new(entry: true)
          custom_launch_entry.child.set_placeholder_text("(enter custom launch command)")
          custom_launch_entry.append_text("Wizard.Exe /GGS /H127.0.0.1 /P%port% /K%key%")
          custom_launch_entry.append_text("Stormfront.exe /GGS /Hlocalhost /P%port% /K%key%")
          custom_launch_entry
        end

        # Creates a custom launch directory entry
        # Builds a combo box for custom launch directories
        #
        # @return [Gtk::ComboBoxText] The custom launch directory widget
        def self.create_custom_launch_dir
          custom_launch_dir = Gtk::ComboBoxText.new(entry: true)
          custom_launch_dir.child.set_placeholder_text("(enter working directory for command)")
          custom_launch_dir.append_text("../wizard")
          custom_launch_dir.append_text("../StormFront")
          custom_launch_dir
        end
      end
    end
  end
end
