# frozen_string_literal: true

require_relative 'password_cipher'
require_relative 'yaml_state'

module Lich
  module Common
    module GUI
      # Manages password operations across different encryption modes
      # Coordinates between YamlState and PasswordCipher for mode-aware password handling
      #
      # @example Change password in standard mode
      #   PasswordManager.change_password(
      #     entry: entry_data,
      #     new_password: 'newpass123',
      #     account_name: 'user123'
      #   )
      module PasswordManager
        # Changes a password for an entry based on its encryption mode
        #
        # @param entry [Hash] Entry data containing :encryption_mode and :password
        # @param new_password [String] New plaintext password
        # @param account_name [String, nil] Account name for account_name mode
        # @param master_password [String, nil] Master password for master_password mode
        # @return [Hash] Updated entry with new password
        # @raise [ArgumentError] If required parameters are missing
        def self.change_password(entry:, new_password:, account_name: nil, master_password: nil)
          mode = entry[:encryption_mode]&.to_sym || :plaintext

          case mode
          when :plaintext
            # Plaintext mode - store password directly
            entry[:password] = new_password
          when :standard
            # Standard mode - encrypt with account name
            raise ArgumentError, 'account_name required for standard mode' if account_name.nil?

            entry[:password] = PasswordCipher.encrypt(
              new_password,
              mode: :standard,
              account_name: account_name
            )
          when :enhanced
            # Enhanced encryption mode - encrypt with master password
            raise ArgumentError, 'master_password required for enhanced mode' if master_password.nil?

            entry[:password] = PasswordCipher.encrypt(
              new_password,
              mode: :enhanced,
              master_password: master_password
            )
          when :ssh_key
            # Certificate encryption mode - future feature, not yet implemented
            raise NotImplementedError, "#{mode} mode not yet implemented"
          else
            raise ArgumentError, "Unknown encryption mode: #{mode}"
          end

          entry
        end

        # Retrieves a decrypted password from an entry
        #
        # @param entry [Hash] Entry data containing :encryption_mode and :password
        # @param account_name [String, nil] Account name for account_name mode
        # @param master_password [String, nil] Master password for master_password mode
        # @return [String] Decrypted plaintext password
        # @raise [ArgumentError] If required parameters are missing
        # @raise [PasswordCipher::DecryptionError] If decryption fails
        def self.get_password(entry:, account_name: nil, master_password: nil)
          mode = entry[:encryption_mode]&.to_sym || :plaintext
          encrypted_password = entry[:password]

          case mode
          when :plaintext
            # Plaintext mode - return password directly
            encrypted_password
          when :standard
            # Standard mode - decrypt with account name
            raise ArgumentError, 'account_name required for standard mode' if account_name.nil?

            PasswordCipher.decrypt(
              encrypted_password,
              mode: :standard,
              account_name: account_name
            )
          when :enhanced
            # Enhanced encryption mode - decrypt with master password
            raise ArgumentError, 'master_password required for enhanced mode' if master_password.nil?

            PasswordCipher.decrypt(
              encrypted_password,
              mode: :enhanced,
              master_password: master_password
            )
          when :ssh_key
            # Certificate encryption mode - future feature, not yet implemented
            raise NotImplementedError, "#{mode} mode not yet implemented"
          else
            raise ArgumentError, "Unknown encryption mode: #{mode}"
          end
        end
      end
    end
  end
end
