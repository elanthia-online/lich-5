# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      # Selects a saved character as the edit/removal target and refreshes its form.
      # @param event [WebUI::Runtime::EventContext] originating viewer payload and declared submission
      # @return [void]
      def select_managed_entry(event)
        @mutex.synchronize { @draft_entry_key = event.payload.fetch(:rows).first }
        refresh
      end

      # Refreshes the editor using the currently selected character.
      # @return [void]
      def begin_edit = refresh

      # Clears the character edit target without modifying catalog data.
      # @return [void]
      def cancel_edit
        @mutex.synchronize { @draft_entry_key = nil }
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
        entry = @mutex.synchronize { @entries.find { |candidate| candidate.key == @draft_entry_key } }
        return unless entry

        @mutex.synchronize do
          @modal = { kind: :confirm_delete, account: entry.user_id,
                     body: "Remove account #{entry.user_id} and all saved characters?" }
        end
        refresh
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
