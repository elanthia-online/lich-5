# frozen_string_literal: true

require_relative 'authenticator'
require_relative 'launch_data'

module Lich
  module Common
    module Authentication
      # GUI-specific authentication handling
      # Manages button state, error dialogs, and success callbacks for GUI login
      module GUI
        # Debounce duration (ms) before restoring Play button after successful launch.
        # This limits accidental rapid repeat launches while keeping persistent UI usable.
        BUTTON_REENABLE_DEBOUNCE_MS = 2000

        # Authenticates and launches game from GUI button click
        # Handles button state, error dialogs, and success callback
        #
        # @param button [Gtk::Button] The play button (for state management)
        # @param login_info [Hash] Character login info (user_id, password, char_name, game_code, frontend)
        # @param on_success [Proc, nil] Callback with launch_data on successful auth.
        #   If nil, authentication succeeds but launch_data is discarded (no-op).
        # @param on_error [Proc, nil] Optional callback for error handling (default: show dialog)
        def self.authenticate_and_launch(button:, login_info:, on_success:, on_error: nil)
          button.sensitive = false

          begin
            # Authenticate with game server
            auth_data = Authentication.authenticate(
              account: login_info[:user_id],
              password: login_info[:password],
              character: login_info[:char_name],
              game_code: login_info[:game_code]
            )

            # Format launch data for frontend
            launch_data = LaunchData.prepare(
              auth_data,
              login_info[:frontend],
              login_info[:custom_launch],
              login_info[:custom_launch_dir]
            )

            if on_success
              # Backward compatibility: existing callbacks may still expect 1 arg.
              if on_success.respond_to?(:arity) && on_success.arity == 1
                on_success.call(launch_data)
              else
                on_success.call(launch_data, login_info)
              end
            end

            schedule_button_reenable(button)
          rescue FatalAuthError => e
            handle_auth_error(button, e, on_error)
          rescue StandardError => e
            Lich.log "error: GUI auth unexpected error: #{e.class}: #{e.message}"
            Lich.log e.backtrace.join("\n\t") if e.backtrace
            handle_auth_error(button, StandardError.new("Unexpected login error. See debug log for details."), on_error)
            raise
          end
        end

        # @api private
        # Handles authentication errors by re-enabling button and showing error
        #
        # @param button [Gtk::Button] The play button to re-enable
        # @param error [StandardError] The error that occurred
        # @param on_error [Proc, nil] Optional custom error handler
        def self.handle_auth_error(button, error, on_error)
          button.sensitive = true

          if on_error
            on_error.call(error.message)
          else
            show_error_dialog(button, error.message)
          end
        end

        # @api private
        # Shows an error dialog for authentication failures
        #
        # @param button [Gtk::Button] Parent button for dialog positioning
        # @param message [String] Error message to display
        def self.show_error_dialog(button, message)
          dialog = Gtk::MessageDialog.new(
            parent: button.toplevel,
            flags: :modal,
            type: :error,
            buttons: :ok,
            message: "Authentication Failed"
          )
          dialog.secondary_text = message
          dialog.run
          dialog.destroy
        end

        # @api private
        # Restores button sensitivity after a successful launch using a small debounce.
        #
        # @param button [Gtk::Button] The play button to restore
        # @return [void]
        def self.schedule_button_reenable(button)
          GLib::Timeout.add(BUTTON_REENABLE_DEBOUNCE_MS) do
            button.sensitive = true unless button.respond_to?(:destroyed?) && button.destroyed?
            false
          end
        end
      end
    end
  end
end
