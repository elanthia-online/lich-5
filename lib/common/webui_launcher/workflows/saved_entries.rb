# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      # Queues a saved configuration by stable identity and checks liveness before launch.
      # @param event [WebUI::Runtime::EventContext] requesting viewer
      # @param entry_key [String] saved configuration identity
      # @return [Boolean] whether work was accepted
      def saved_launch(event, entry_key)
        operation = begin_operation(:saved_launch, event)
        post_operation(operation) { perform_saved_launch(operation, entry_key) }
      end

      # Validates an unlock password without allowing keychain writes after cancellation.
      # @param event [WebUI::Runtime::EventContext] unlock modal response
      # @param password_cid [String] submitted master-password field
      # @return [void]
      def unlock_response(event, password_cid)
        return cancel_modal if event.payload[:button] == 'cancel'

        entry_key = @mutex.synchronize { @modal&.fetch(:entry_key, nil) }
        return event.submission.discard_sensitive! unless entry_key

        operation = begin_operation(:saved_launch, event)
        master = transfer_secret(event.submission.fetch(password_cid))
        post_operation(operation, secrets: [master]) do
          credential = nil
          master.consume do |password|
            next unless commit(operation) do
              raise StandardError, 'Master password was not accepted.' unless @catalog.validate_master_password(password)

              credential = @catalog.credential(entry_key, master_password: password)
            end
          end
          next unless credential
          perform_saved_launch(operation, entry_key, credential: credential)
        rescue StandardError => error
          credential&.discard!
          fail_operation(operation, error, modal: { kind: :unlock, entry_key: entry_key, error: 'Master password was not accepted.' })
        end
      end

      # Queues a favorite mutation through the launcher's tracked operation lifecycle.
      # @param event [WebUI::Runtime::EventContext] originating viewer payload and declared submission
      # @param entry_key [String] stable saved-configuration identity
      # @return [void]
      def toggle_favorite(event, entry_key)
        mutate(:favorite, event, 'Favorite update failed.') do
          raise 'favorite update failed' if @catalog.toggle_favorite(entry_key).nil?
        end
      end

      # Opens the character-removal confirmation; persistence waits for its response.
      # @param _event [WebUI::Runtime::EventContext] unused originating event; selection is server-owned
      # @param entry_key [String] stable saved-configuration identity
      # @return [void]
      def remove_entry(_event, entry_key)
        @mutex.synchronize { @modal = { kind: :confirm_delete, entry_key: entry_key, body: 'Remove this saved character?' } }
        refresh
      end
    end
  end
end
