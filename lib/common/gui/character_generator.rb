# frozen_string_literal: true

require_relative '../authentication/account_characters'
require_relative '../authentication/gui'
require_relative '../frontend'
require_relative 'accessibility'
require_relative 'frontend_selector'
require_relative 'game_selection'
require_relative 'login_tab_utils'

module Lich
  module Common
    module GUI
      # Launches the character generator for a saved account from the launcher -
      # the GUI counterpart of `--login NEW --account=ACCOUNT`.
      #
      # The launch always goes through Lich's own authentication and game-key
      # handoff (Saga included): Saga-managed auto-login has no generator form.
      module CharacterGenerator
        REFRESH_HINT = "When you've finished creating your character, select the account " \
                       "and click Refresh Characters to add it to your saved entries."

        SAGA_NOTE = 'Saga must be closed before you start: a running Saga ignores the new session.'

        # Shows the Create Character dialog and launches the generator when confirmed.
        #
        # @param parent [Gtk::Window, nil] parent window for the dialog
        # @param data_dir [String] directory containing entry.yaml
        # @param account [String] account key as stored in entry.yaml
        # @param button [Gtk::Button] button disabled while authenticating
        # @param on_play [Proc] launcher play callback (launch_data, login_context)
        # @param msgbox [Proc] callback that shows a message to the user
        # @return [void]
        def self.show_dialog(parent:, data_dir:, account:, button:, on_play:, msgbox:)
          dialog = Gtk::Dialog.new(
            title: 'Create Character',
            parent: parent,
            flags: :modal,
            buttons: [
              ['Create Character', Gtk::ResponseType::OK],
              ['Cancel', Gtk::ResponseType::CANCEL]
            ]
          )
          dialog.set_default_size(420, -1)
          dialog.border_width = 10
          Accessibility.make_window_accessible(
            dialog,
            'Create Character Dialog',
            'Enter the character generator for this account'
          )

          content_area = dialog.content_area
          content_area.spacing = 10

          account_label = Gtk::Label.new
          account_label.set_markup("<span weight='bold'>Account:</span> #{account}")
          account_label.set_xalign(0)
          content_area.add(account_label)

          game_box = Gtk::Box.new(:horizontal, 5)
          game_box.pack_start(Gtk::Label.new('Game:'), expand: false, fill: false, padding: 0)
          game_combo = GameSelection.create_game_selection_combo(
            Authentication::AccountCharacters.predominant_game_code(data_dir, account)
          )
          game_box.pack_start(game_combo, expand: true, fill: true, padding: 0)
          content_area.add(game_box)

          frontend_box = Gtk::Box.new(:horizontal, 5)
          frontend_box.pack_start(Gtk::Label.new('Frontend:'), expand: false, fill: false, padding: 0)
          frontend_selector = FrontendSelector.new(
            selected_id: Authentication::AccountCharacters.default_frontend(data_dir, account),
            refresh: false
          )
          frontend_box.pack_start(frontend_selector.widget, expand: true, fill: true, padding: 0)
          content_area.add(frontend_box)

          saga_label = Gtk::Label.new(SAGA_NOTE)
          saga_label.set_xalign(0)
          saga_label.line_wrap = true
          content_area.add(saga_label)

          hint_label = Gtk::Label.new(REFRESH_HINT)
          hint_label.set_xalign(0)
          hint_label.line_wrap = true
          content_area.add(hint_label)

          dialog.show_all
          update_saga_note = ->(selector) { saga_label.visible = saga?(selector.selected_id) }
          frontend_selector.on_change { |selector| update_saga_note.call(selector) }
          update_saga_note.call(frontend_selector)

          response = dialog.run
          game_code = GameSelection.get_selected_game_code(game_combo)
          frontend = frontend_selector.selected_id
          dialog.destroy
          return unless response == Gtk::ResponseType::OK

          launch(
            data_dir: data_dir,
            account: account,
            game_code: game_code,
            frontend: frontend,
            button: button,
            on_play: on_play,
            msgbox: msgbox
          )
        end

        # Authenticates into the character generator and hands the launch data to
        # the launcher's play callback.
        #
        # The login context is flagged saved_entry so persistent launcher mode
        # applies, and generator so a persistent child is spawned with
        # `--login NEW --account=`.
        #
        # @param data_dir [String] directory containing entry.yaml
        # @param account [String] account key as stored in entry.yaml
        # @param game_code [String] game instance code
        # @param frontend [String, nil] selected frontend identifier
        # @param button [Gtk::Button] button disabled while authenticating
        # @param on_play [Proc] launcher play callback (launch_data, login_context)
        # @param msgbox [Proc] callback that shows a message to the user
        # @return [void]
        def self.launch(data_dir:, account:, game_code:, frontend:, button:, on_play:, msgbox:)
          unless frontend
            msgbox.call('No supported frontend is available.')
            return
          end

          # char_name matches the CLI's generator entry: Account.character names the
          # session file and setup files until the new character's name is known.
          login_info = {
            user_id: account,
            char_name: 'NEW',
            game_code: game_code,
            game_name: GameSelection.get_game_name(game_code),
            frontend: frontend,
            custom_launch: nil,
            custom_launch_dir: nil,
            generator: true,
            saved_entry: true
          }

          unless LoginTabUtils.launchable_frontend?(login_info, refresh: true)
            msgbox.call("#{Frontend.display_name(frontend)} is not available on this computer. " \
                        'Choose another frontend, or configure the client in the Frontends tab.')
            return
          end

          begin
            password = Authentication::AccountCharacters.stored_password(data_dir, account)
          rescue Authentication::AccountCharacters::Error => e
            msgbox.call("Could not read the saved password for #{account}: #{e.message}")
            return
          end

          Authentication::GUI.authenticate_and_launch(
            button: button,
            login_info: login_info.merge(password: password),
            on_success: on_play,
            on_error: ->(message) { msgbox.call(error_message(message, login_info[:game_name])) }
          )
        end

        # Turns an authentication error into a message for the user.
        #
        # @param message [String] error message from authentication
        # @param game_name [String] display name of the selected game
        # @return [String]
        def self.error_message(message, game_name)
          if message.to_s.include?('GENERATOR_NOT_AVAILABLE')
            "This account can't create a character on #{game_name}. " \
              'It needs a subscription or trial for that game.'
          else
            "Could not start the character generator: #{message}"
          end
        end

        # @param frontend [String, nil] frontend identifier
        # @return [Boolean] true when the frontend is Saga
        # @api private
        def self.saga?(frontend)
          Frontend.canonical_name(frontend) == 'saga'
        end
      end
    end
  end
end
