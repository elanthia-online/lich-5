# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      # Selects a saved character as the edit/removal target and refreshes its form.
      # @param event [WebUI::Runtime::EventContext] originating viewer payload and declared submission
      # @return [void]
      def select_managed_entry(event)
        row = event.payload.fetch(:rows).first
        @mutex.synchronize do
          # An account with no characters has a row of its own, keyed by the account.
          @draft_account_key = @accounts.any? { |account| Catalog.account_key(account) == row } ? row : nil
          @draft_entry_key = @draft_account_key ? nil : row
        end
        refresh
      end

      # Refreshes the editor using the currently selected character.
      # @return [void]
      def begin_edit = refresh

      # Clears the character edit target without modifying catalog data.
      # @return [void]
      def cancel_edit
        @mutex.synchronize { @draft_entry_key = @draft_account_key = nil }
        refresh
      end

      # Requests confirmation for the selected character, if any.
      # @param event [WebUI::Runtime::EventContext] originating viewer payload and declared submission
      # @return [void]
      def remove_selected_entry(event)
        key = @mutex.synchronize { @draft_entry_key }
        remove_entry(event, key) if key
      end

      # Requests confirmation before removing the selected character's entire account.
      # @param _event [WebUI::Runtime::EventContext] unused originating event; selection is server-owned
      # @return [void]
      def remove_selected_account(_event)
        account = @mutex.synchronize { selected_account_locked }
        return unless account

        @mutex.synchronize do
          @modal = { kind: :confirm_delete, account: account,
                     body: "Remove account #{account} and all saved characters?" }
        end
        refresh
      end

      # Opens the per-account password change dialog for the selected character's account.
      # @param _event [WebUI::Runtime::EventContext] unused originating event; selection is server-owned
      # @return [void]
      def begin_change_password(_event)
        account = @mutex.synchronize { selected_account_locked }
        return unless account

        @mutex.synchronize { @modal = { kind: :change_password, account: account, error: nil } }
        refresh
      end

      # Verifies the current account password and stores its replacement through
      # the catalog's existing change_account_password provider. Validation
      # reasons are fixed, secret-free messages shown in the dialog.
      # @param event [WebUI::Runtime::EventContext] dialog response with three password fields
      # @param password_cids [Array<String>] current, new and confirmation field IDs
      # @return [void]
      def change_password_response(event, password_cids)
        unless event.payload[:button] == 'change'
          event.submission.discard_sensitive!
          return cancel_modal
        end
        account = @mutex.synchronize { @modal[:account] if @modal&.fetch(:kind, nil) == :change_password }
        return event.submission.discard_sensitive! unless account

        operation = begin_operation(:account_password, event)
        carriers = password_cids.map { |cid| transfer_secret(event.submission.fetch(cid)) }
        post_operation(operation, secrets: carriers) do
          consume_three(carriers) do |current, replacement, confirmation|
            raise ValidationRefused, 'Current password is required.' if current.empty?
            raise ValidationRefused, 'New password is required.' if replacement.empty?
            raise ValidationRefused, 'New passwords do not match.' unless secure_equal?(replacement, confirmation)
            commit(operation) do
              unless @catalog.change_account_password(account, current, replacement)
                raise ValidationRefused, 'Current password was not accepted.'
              end
            end
          end
          complete(operation) do
            @modal = nil
            reload_catalog_locked
          end
          set_notice("Password changed for account #{account}.", :info)
        rescue StandardError => error
          message = case error
                    when ValidationRefused then error.message
                    when Catalog::MasterPasswordRequired then MASTER_PASSWORD_LOCKED_HINT
                    else 'Password change failed.'
                    end
          fail_operation(operation, error, modal: { kind: :change_password, account: account, error: message })
        end
      end

      # Cancels or queues the confirmed account/character removal from a modal response.
      # @param event [WebUI::Runtime::EventContext] originating viewer payload and declared submission
      # @return [void]
      def delete_response(event)
        return cancel_modal unless event.payload[:button] == 'remove'

        target = @mutex.synchronize { @modal&.dup }
        return unless target

        cancel_modal
        mutate(:delete, event, 'Removal failed.') do
          result = target[:account] ? @catalog.remove_account(target[:account]) : @catalog.remove_entry(target[:entry_key])
          raise 'removal failed' unless result

          # The removed row can no longer be selected; a stale selection refuses the next render.
          @mutex.synchronize { @draft_entry_key = @draft_account_key = nil }
        end
      end

      # Saves a supported frontend even when it is not installed on this machine.
      # Native-only frontends still reject a conflicting custom launch command.
      # @param event [WebUI::Runtime::EventContext] character configuration submission
      # @return [void]
      def save_character(event)
        values = submission_values(event.submission)
        entry_key = @mutex.synchronize { @draft_entry_key }
        character = {
          char_name: submitted(values, 'text_input:character-name').to_s,
          game_code: submitted(values, 'select:character-game').to_s,
          frontend: submitted(values, 'select:character-frontend').to_s,
          custom_launch: blank(submitted(values, 'text_input:character-custom')),
          custom_launch_dir: blank(submitted(values, 'text_input:character-custom-dir')),
        }
        character[:game_name] = GAME_NAMES.fetch(character[:game_code], character[:game_code])
        account = submitted(values, 'select:character-account').to_s
        return set_notice('Character name is required.', :error) if character[:char_name].empty?
        return set_notice('Choose a supported game.', :error) unless GAMES.any? { |option| option[:value] == character[:game_code] }
        return set_notice('Choose a supported front end.', :error) unless @frontend_options.any? { |option| option[:value] == character[:frontend] }
        if native_launch_only?(character[:frontend]) && character[:custom_launch]
          return set_notice('This front end requires native launch; remove the Custom Launch command.', :error)
        end

        mutate(:character, event, 'Character could not be saved.') do
          success = entry_key ? @catalog.update_character(entry_key, character) : @catalog.add_character(account, character)
          raise 'character save failed' unless success
          @mutex.synchronize { @draft_entry_key = nil }
        end
      end

      # Authenticates outside the close gate, then conditionally persists the account.
      # @param event [WebUI::Runtime::EventContext] account submission
      # @return [void]
      def save_account(event)
        values = submission_values(event.submission)
        account = submitted(values, 'text_input:account-name').to_s.strip.upcase
        frontend = submitted(values, 'select:account-frontend').to_s
        password_pair = values.find { |key, _| key.end_with?('password_input:account-password') }
        return set_notice('Account name is required.', :error) if account.empty?
        return set_notice('Choose a supported front end.', :error) unless @frontend_options.any? { |option| option[:value] == frontend }
        return set_notice('Password is required.', :error) unless password_pair

        operation = begin_operation(:account, event)
        secret = transfer_secret(password_pair.last)
        post_operation(operation, secrets: [secret]) do
          secret.consume do |password|
            characters = @authenticator.authenticate(account: account, password: password, legacy: true)
            commit(operation) do
              raise 'account persistence failed' unless @catalog.add_or_update_account(account, password, characters, frontend: frontend)
            end
          end
          complete(operation) { reload_catalog_locked }
        rescue StandardError => error
          fail_operation(operation, error, notice: 'Account authentication or save failed.')
        end
      end
    end
  end
end
