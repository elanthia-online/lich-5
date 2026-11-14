# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      # Authenticates manual credentials and retains them only for a live operation.
      # @param event [WebUI::Runtime::EventContext] credential submission
      # @param account_cid [String] submitted account field
      # @param password_cid [String] submitted sensitive field
      # @return [void]
      def manual_connect(event, account_cid, password_cid)
        account = event.submission.fetch(account_cid).to_s.strip.upcase
        return manual_error('User ID is required.') if account.empty?

        operation = begin_operation(:manual_auth, event)
        credential = transfer_secret(event.submission.fetch(password_cid))
        @mutex.synchronize { @manual.merge!(phase: :authenticating, account: account, error: nil, owner: event.viewer_id) }
        refresh
        post_operation(operation, secrets: [credential]) do
          characters = nil
          retained = nil
          credential.consume do |password|
            characters = @authenticator.authenticate(account: account, password: password, legacy: true)
            retained = Lich::WebUI::SensitiveValue.viewer(password)
          end
          accepted = complete(operation) do
            @manual_credentials[event.viewer_id]&.discard!
            @manual_credentials[event.viewer_id] = retained
            @manual.merge!(phase: :selecting_character, characters: normalize_characters(characters), selected: nil)
          end
          retained&.discard! unless accepted
        rescue StandardError => error
          retained&.discard!
          fail_operation(operation, error, manual: 'Authentication failed. Check the account credentials and service availability, then retry.')
        end
      end

      # Records the selected authenticated character row and refreshes launch availability.
      # @param event [WebUI::Runtime::EventContext] originating viewer payload and declared submission
      # @return [void]
      def manual_select(event)
        selected = event.payload.fetch(:rows).first
        @mutex.synchronize { @manual[:selected] = selected }
        refresh
      end

      # Accepts known frontend choices and disables custom launch for native-only adapters.
      # @param event [WebUI::Runtime::EventContext] originating viewer payload and declared submission
      # @param option [Symbol] :frontend or :custom_enabled manual preference
      # @return [void]
      # @raise [ArgumentError] for an unsupported manual option
      def manual_option_changed(event, option)
        value = event.payload.fetch(:value)
        @mutex.synchronize do
          case option
          when :frontend
            available = @frontend_options.any? { |entry| entry[:value] == value }
            @manual[:frontend] = value if available
            @manual[:custom_enabled] = false if available && native_launch_only?(value)
          when :custom_enabled
            @manual[:custom_enabled] = value == true && !native_launch_only?(@manual[:frontend])
          else
            raise ArgumentError, "unknown manual option: #{option}"
          end
        end
        refresh
      end

      # Cancels the viewer's pending manual work and disposes retained credentials.
      # @param viewer_id [String] attachment abandoning manual entry
      # @return [void]
      def manual_disconnect(viewer_id)
        @commit_mutex.synchronize do
          @mutex.synchronize do
            @active.delete_if { |kind, operation| operation.viewer_id == viewer_id && %i[manual_auth manual_launch].include?(kind) }
            @manual_credentials.delete(viewer_id)&.discard!
            @manual = default_manual_state
          end
        end
        refresh
      end

      # Queues a selected character launch with worker-owned credential disposal.
      # @param event [WebUI::Runtime::EventContext] manual launch options
      # @return [void]
      def manual_play(event)
        state = @mutex.synchronize do
          selected = @manual[:selected].to_s
          index = selected.start_with?('character-') ? Integer(selected.delete_prefix('character-'), exception: false) : nil
          character = index && @manual[:characters][index]
          [@manual[:account], character, @manual_credentials[event.viewer_id], @manual[:frontend]]
        end
        account, character, credential, frontend = state
        unless character && credential && frontend
          return manual_error('Enter credentials, select a character, and choose an available front end before playing.')
        end
        unless frontend_available?(frontend, refresh: true)
          return manual_error('The selected front end is unavailable. Check its configuration in Frontends, or choose another front end.')
        end

        values = submission_values(event.submission)
        return manual_error('The selected front end changed. Choose it again.') unless submitted(values, 'select:manual-frontend') == frontend
        if submitted(values, 'checkbox:manual-custom-enabled') && submitted(values, 'text_input:manual-custom').to_s.strip.empty?
          return manual_error('Custom launch command is required when Custom launch command is checked. Enter a command or uncheck it.')
        end

        operation = begin_operation(:manual_launch, event)
        @mutex.synchronize { @manual_credentials.delete(event.viewer_id) }
        @mutex.synchronize { @manual[:phase] = :launching }
        refresh
        post_operation(operation, secrets: [credential]) { perform_manual_launch(operation, account, character, credential, values) }
      end
    end
  end
end
