# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      private

      # Prepares a manual login, then independently admits optional save and launch.
      # @api private
      # @param operation [Operation] cancelable launch token
      # @param account [String] account to authenticate
      # @param character [Hash] selected character metadata
      # @param credential [WebUI::SensitiveValue] worker-owned one-shot password
      # @param values [Hash] submitted frontend and save choices
      # @return [void]
      def perform_manual_launch(operation, account, character, credential, values)
        launch = nil
        save_notice = nil
        credential.consume do |password|
          auth = @authenticator.authenticate(account: account, password: password,
                                             character: character[:char_name], game_code: character[:game_code])
          frontend = submitted(values, 'select:manual-frontend')
          custom_enabled = submitted(values, 'checkbox:manual-custom-enabled')
          custom = custom_enabled ? blank(submitted(values, 'text_input:manual-custom')) : nil
          custom_dir = custom_enabled ? blank(submitted(values, 'text_input:manual-custom-dir')) : nil
          launch = @launch_data.prepare(auth, frontend, custom, custom_dir)
          save = submitted(values, 'checkbox:manual-save')
          favorite = submitted(values, 'checkbox:manual-favorite')
          if save || favorite
            entry = character.merge(user_id: account, frontend: frontend, custom_launch: custom, custom_launch_dir: custom_dir)
            commit(operation) { save_notice = save_manual_entry(entry, password, favorite: favorite) }
          end
        end
        report_feedback(save_notice) if save_notice && operation_live?(operation)
        terminal_launch(operation, launch, :manual)
      rescue StandardError => error
        fail_operation(operation, error, manual: 'Launch failed. Retry from Manual Entry.')
      end

      # Saving is optional after authentication succeeds. A locked catalog or
      # failed write must not discard a valid game launch. Record only the
      # exception class and return an authored notice for reporting outside the
      # commit gate, after the temporary plaintext has been disposed.
      # @param entry [Hash] selected character and launch options
      # @param password [String] temporary account password used by persistence
      # @param favorite [Boolean] whether to also mark the saved entry as a favorite
      # @return [String, nil] authored failure notice, or nil after successful saving
      # @api private
      def save_manual_entry(entry, password, favorite:)
        raise 'manual entry save failed' unless @catalog.upsert_manual_entry(entry, password)
        return unless favorite

        saved_entry = find_entry(entry)
        raise 'saved entry was not found' unless saved_entry
        return if saved_entry.favorite

        raise 'favorite save failed' unless @catalog.toggle_favorite(saved_entry.key)
      rescue StandardError => error
        notice = 'Login succeeded, but the entry or favorite was not saved.'
        notice += " #{Catalog::LEGACY_CONVERSION_NOTICE}" if error.is_a?(Catalog::LegacyConversionRequired)
        log_diagnostic(:warning, "#{notice} error=#{error.class}")
        notice
      end

      # Authenticates a saved configuration and gates child/terminal launch against close.
      # Rechecks discovered frontend availability before unlocking/authenticating,
      # including unlock retries. Explicit custom commands retain their own launch path.
      # @api private
      # @param operation [Operation] cancelable launch token
      # @param entry_key [String] configuration identity, never a list position
      # @param credential [WebUI::SensitiveValue, nil] previously unlocked credential
      # @return [void]
      def perform_saved_launch(operation, entry_key, credential: nil)
        failure_notice = 'The saved entry could not be read. Refresh Entries and retry.'
        entry = @mutex.synchronize { @entries.find { |candidate| candidate.key == entry_key } }
        raise KeyError, 'saved entry no longer exists' unless entry

        if SagaLaunchPolicy.custom_launch_conflict?(frontend: entry.frontend, custom_launch: entry.custom_launch)
          raise ArgumentError, SagaLaunchPolicy::CUSTOM_LAUNCH_CONFLICT
        end
        if Frontend.canonical_name(entry.frontend) == 'saga'
          failure_notice = 'Saga could not be launched. Check its configuration in Frontends and the debug log.'
          return perform_saga_launch(operation, entry)
        end
        if entry.custom_launch.to_s.strip.empty? && !frontend_available?(entry.frontend, refresh: true)
          failure_notice = 'The selected front end is unavailable. Check its configuration in Frontends, or choose another front end.'
          raise 'saved frontend is unavailable'
        end

        failure_notice = 'The saved account password could not be unlocked. Check the encryption settings and retry.'
        credential ||= @catalog.credential(entry_key)
        launch = nil
        credential.consume do |password|
          failure_notice = 'Saved account authentication failed. Check the account credentials and service availability, then retry.'
          auth = @authenticator.authenticate(account: entry.user_id, password: password,
                                             character: entry.char_name, game_code: entry.game_code)
          failure_notice = 'Login succeeded, but launch preparation failed. Check the front end configuration and debug log.'
          launch = @launch_data.prepare(auth, entry.frontend, entry.custom_launch, entry.custom_launch_dir)
        end
        failure_notice = 'Login succeeded, but the session could not be launched. Check the front end configuration and debug log.'
        if @persistent
          result = nil
          return unless commit(operation) { result = @session_launcher.launch(launch, launch_context: launch_context(entry)) }
          raise 'session launch failed' unless result[:ok]
          complete(operation) { @modal = nil }
          set_notice('Session launched.', :info)
        else
          terminal_launch(operation, launch, :saved_entry)
        end
      rescue Catalog::MasterPasswordRequired
        complete(operation) { @modal = { kind: :unlock, entry_key: entry_key, error: nil } }
      rescue StandardError => error
        notice = if entry && SagaLaunchPolicy.custom_launch_conflict?(frontend: entry.frontend, custom_launch: entry.custom_launch)
                   SagaLaunchPolicy::CUSTOM_LAUNCH_CONFLICT
                 else
                   failure_notice
                 end
        fail_operation(operation, error, modal: nil, notice: notice)
      ensure
        credential&.discard!
      end

      # Lets Saga own saved-entry authentication and its Via-Lich child process.
      # @param operation [Operation] cancelable saved-launch token
      # @param entry [Catalog::Entry] selected Saga configuration
      # @return [void]
      # @api private
      def perform_saga_launch(operation, entry)
        raise 'Saga is unavailable' unless frontend_available?('saga', refresh: true)

        result = nil
        return unless commit(operation) do
          result = SagaManagedLauncher.launch(account: entry.user_id, character: entry.char_name, game_code: entry.game_code)
        end
        raise 'Saga launch failed' unless result[:ok]

        complete(operation) { @modal = nil }
        @persistent ? set_notice('Saga session launched.', :info) : close(reason: :launch)
      end
    end
  end
end
