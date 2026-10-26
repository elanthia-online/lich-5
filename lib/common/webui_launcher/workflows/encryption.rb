# frozen_string_literal: true

module Lich
  module Common
    class WebUILauncher
      # Validates confirmed creation or an explicit plaintext acknowledgement before writing.
      # Existing GTK creation policy requires nonempty matching values; the separate
      # replacement-password workflow retains its existing minimum length.
      # @param event [WebUI::Runtime::EventContext] mode, master password and confirmations
      # @return [void]
      def change_encryption(event)
        values = submission_values(event.submission)
        mode = submitted(values, 'radio:encryption-mode').to_s.to_sym
        current_mode = @mutex.synchronize { @encryption_mode }
        unless %i[plaintext standard enhanced].include?(mode)
          event.submission.discard_sensitive!
          return set_notice('Choose a supported encryption mode.', :error)
        end
        if mode == current_mode
          event.submission.discard_sensitive!
          return set_notice('Encryption mode is unchanged.', :info)
        end
        if mode == :plaintext && submitted(values, 'checkbox:encryption-plaintext-confirm') != true
          event.submission.discard_sensitive!
          return set_notice('Confirm that saved passwords will be stored without encryption.', :error)
        end
        if mode == :enhanced && !@catalog.enhanced_encryption_available?
          event.submission.discard_sensitive!
          return set_notice('Enhanced Encryption is unavailable because no secure keychain is present.', :error)
        end
        master = submitted(values, 'password_input:encryption-master')
        confirmation = submitted(values, 'password_input:encryption-confirm')
        unless master && (mode != :enhanced || confirmation)
          event.submission.discard_sensitive!
          return set_notice('Master password submission is incomplete.', :error)
        end

        operation = begin_operation(:encryption, event)
        secret = transfer_secret(master)
        confirmed = confirmation && transfer_secret(confirmation)
        post_operation(operation, secrets: [secret, confirmed].compact) do
          secret.consume do |password|
            if mode == :enhanced
              raise 'password cannot be empty' if password.empty?
              confirmed.consume { |value| raise 'passwords do not match' unless secure_equal?(password, value) }
            end
            commit(operation) do
              if @catalog.encryption_mode == :enhanced && mode != :enhanced
                raise 'current master password was not accepted' if password.empty? || !@catalog.validate_master_password(password)
              end
              raise 'encryption change failed' unless @catalog.change_encryption_mode(mode, master_password: mode == :enhanced ? password : nil)
            end
          end
          complete(operation) { reload_catalog_locked }
        rescue StandardError => error
          fail_operation(operation, error, notice: 'Encryption mode change failed. Check the password and confirmation.')
        end
      end

      # Validates replacement fields and gates re-encryption against launcher closure.
      # @param event [WebUI::Runtime::EventContext] current, replacement and confirmation
      # @return [void]
      def change_master_password(event)
        values = submission_values(event.submission)
        pairs = %w[master-current master-new master-confirm].map do |key|
          values.find { |cid, _| cid.end_with?("password_input:#{key}") }
        end
        if pairs.any?(&:nil?)
          event.submission.discard_sensitive!
          return set_notice('Master password change requires all three fields.', :error)
        end

        operation = begin_operation(:master_password, event)
        carriers = pairs.map { |pair| transfer_secret(pair.last) }
        post_operation(operation, secrets: carriers) do
          consume_three(carriers) do |current, replacement, confirmation|
            raise 'passwords do not match' unless secure_equal?(replacement, confirmation)
            raise 'password too short' if replacement.length < 8
            commit(operation) do
              raise 'master password change failed' unless @catalog.change_master_password(current, replacement)
            end
          end
          complete(operation) { reload_catalog_locked }
          set_notice('Encryption password changed.', :info)
        rescue StandardError => error
          fail_operation(operation, error, notice: 'Master password change failed.')
        end
      end
    end
  end
end
