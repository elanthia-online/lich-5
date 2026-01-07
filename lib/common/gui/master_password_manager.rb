# frozen_string_literal: true

require 'openssl' # default gem, but upgrade via RubyGems available
require 'securerandom' # default gem
require 'base64' # bundled gem Ruby >= 3.4, default gem Ruby < 3.4
Lich::Util.install_gem_requirements({ 'os' => true })
require 'shellwords' # default gem
require_relative 'windows_credential_manager'

module Lich
  module Common
    module GUI
      # Master password manager - Keychain integration for secure credential storage
      # Provides one-time validation test creation and runtime password management
      # CRITICAL: Validation test uses 100k iterations (one-time)
      #           Runtime decryption uses 10k iterations (via PasswordCipher)
      module MasterPasswordManager
        KEYCHAIN_SERVICE = 'lich5.master_password'
        VALIDATION_ITERATIONS = 100_000
        VALIDATION_KEY_LENGTH = 32
        VALIDATION_SALT_PREFIX = 'lich5-master-password-validation-v1'

        def self.keychain_available?
          if OS.mac?
            macos_keychain_available?
          elsif OS.linux?
            linux_keychain_available?
          elsif OS.windows?
            windows_keychain_available?
          else
            false
          end
        end

        def self.store_master_password(master_password)
          return false unless keychain_available?

          if OS.mac?
            store_macos_keychain(master_password)
          elsif OS.linux?
            store_linux_keychain(master_password)
          elsif OS.windows?
            store_windows_keychain(master_password)
          else
            false
          end
        rescue StandardError => e
          Lich.log "error: Failed to store master password: #{e.message}"
          false
        end

        def self.retrieve_master_password
          return nil unless keychain_available?

          if OS.mac?
            retrieve_macos_keychain
          elsif OS.linux?
            retrieve_linux_keychain
          elsif OS.windows?
            retrieve_windows_keychain
          else
            nil
          end
        rescue StandardError => e
          Lich.log "error: Failed to retrieve master password: #{e.message}"
          nil
        end

        def self.create_validation_test(master_password)
          random_salt = SecureRandom.random_bytes(16)
          full_salt = VALIDATION_SALT_PREFIX + random_salt

          validation_key = OpenSSL::PKCS5.pbkdf2_hmac(
            master_password, full_salt, VALIDATION_ITERATIONS,
            VALIDATION_KEY_LENGTH, OpenSSL::Digest.new('SHA256')
          )

          validation_hash = OpenSSL::Digest::SHA256.digest(validation_key)

          {
            'validation_salt'    => Base64.strict_encode64(random_salt),
            'validation_hash'    => Base64.strict_encode64(validation_hash),
            'validation_version' => 1
          }
        end

        def self.validate_master_password(entered_password, validation_test)
          return false unless validation_test.is_a?(Hash)
          return false unless validation_test['validation_salt'] && validation_test['validation_hash']

          begin
            random_salt = Base64.strict_decode64(validation_test['validation_salt'])
            stored_hash = Base64.strict_decode64(validation_test['validation_hash'])
            full_salt = VALIDATION_SALT_PREFIX + random_salt

            validation_key = OpenSSL::PKCS5.pbkdf2_hmac(
              entered_password, full_salt, VALIDATION_ITERATIONS,
              VALIDATION_KEY_LENGTH, OpenSSL::Digest.new('SHA256')
            )

            computed_hash = OpenSSL::Digest::SHA256.digest(validation_key)
            secure_compare(computed_hash, stored_hash)
          rescue StandardError => e
            Lich.log "error: Validation failed: #{e.message}"
            false
          end
        end

        def self.delete_master_password
          return false unless keychain_available?

          if OS.mac?
            delete_macos_keychain
          elsif OS.linux?
            delete_linux_keychain
          elsif OS.windows?
            delete_windows_keychain
          else
            false
          end
        rescue StandardError => e
          Lich.log "error: Failed to delete master password: #{e.message}"
          false
        end

        private_class_method def self.macos_keychain_available?
          system('which security >/dev/null 2>&1')
        end

        private_class_method def self.store_macos_keychain(password)
          escaped = password.shellescape
          # Delete existing entry (ignore result)
          system("security delete-generic-password -s #{KEYCHAIN_SERVICE.shellescape} 2>/dev/null")
          # Add new entry and return actual result
          system("security add-generic-password -s #{KEYCHAIN_SERVICE.shellescape} -a lich5 -w #{escaped}")
        end

        private_class_method def self.retrieve_macos_keychain
          output = `security find-generic-password -s #{KEYCHAIN_SERVICE.shellescape} -w 2>/dev/null`.strip
          output.empty? ? nil : output
        rescue
          nil
        end

        private_class_method def self.delete_macos_keychain
          system("security delete-generic-password -s #{KEYCHAIN_SERVICE.shellescape} 2>/dev/null")
        end

        private_class_method def self.linux_keychain_available?
          system('which secret-tool >/dev/null 2>&1')
        end

        private_class_method def self.store_linux_keychain(password)
          escaped = password.shellescape
          # Delete existing entry (ignore result)
          system("secret-tool clear service #{KEYCHAIN_SERVICE.shellescape} user lich5 2>/dev/null")
          # Add new entry and return actual result
          system("secret-tool store --label='Lich 5 Master' service #{KEYCHAIN_SERVICE.shellescape} user lich5 <<< #{escaped}")
        end

        private_class_method def self.retrieve_linux_keychain
          output = `secret-tool lookup service #{KEYCHAIN_SERVICE.shellescape} user lich5 2>/dev/null`.strip
          output.empty? ? nil : output
        rescue
          nil
        end

        private_class_method def self.delete_linux_keychain
          system("secret-tool clear service #{KEYCHAIN_SERVICE.shellescape} user lich5 2>/dev/null")
        end

        private_class_method def self.windows_keychain_available?
          return false unless OS.windows?

          # Check if Credential Manager is available via FFI
          WindowsCredentialManager.available?
        end

        private_class_method def self.store_windows_keychain(password)
          WindowsCredentialManager.store_credential(
            KEYCHAIN_SERVICE,
            'lich5',
            password,
            'Lich 5 Master Password',
            WindowsCredentialManager::CRED_PERSIST_LOCAL_MACHINE
          )
        end

        private_class_method def self.retrieve_windows_keychain
          WindowsCredentialManager.retrieve_credential(KEYCHAIN_SERVICE)
        end

        private_class_method def self.delete_windows_keychain
          WindowsCredentialManager.delete_credential(KEYCHAIN_SERVICE)
        end

        private_class_method def self.secure_compare(a, b)
          return false if a.nil? || b.nil? || a.length != b.length
          result = 0
          a.each_byte.with_index { |x, i| result |= x ^ b.getbyte(i) }
          result.zero?
        end
      end
    end
  end
end
