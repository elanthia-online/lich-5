# frozen_string_literal: true

require 'openssl' # default gem, but upgrade via RubyGems available
require 'securerandom' # default gem
require 'base64' # bundled gem Ruby >= 3.4, default gem Ruby < 3.4
Lich::Util.install_gem_requirements({ 'os' => true })
require 'shellwords' # default gem
require_relative 'windows_credential_manager'

module Lich
  module Common
    module Authentication
      # Master password manager - Keychain integration for secure credential storage
      # Provides one-time validation test creation and runtime password management
      # CRITICAL: Validation test uses 100k iterations (one-time)
      #           Runtime decryption uses 10k iterations (via PasswordCipher)
      module MasterPasswordManager
        # Service name the master password is stored under in the OS keychain.
        KEYCHAIN_SERVICE = 'lich5.master_password'
        # PBKDF2 iterations for the validation test (one-time, deliberately slow).
        VALIDATION_ITERATIONS = 100_000
        # Derived key length in bytes for the validation test.
        VALIDATION_KEY_LENGTH = 32
        # Fixed prefix combined with the random per-test salt.
        VALIDATION_SALT_PREFIX = 'lich5-master-password-validation-v1'

        # Whether this platform has a keychain Lich can store the master password in.
        #
        # macOS uses the `security` CLI, Linux `secret-tool`, and Windows the
        # Credential Manager via {WindowsCredentialManager}.
        #
        # @return [Boolean] false on an unsupported platform or when the backend is missing
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

        # Stores the master password in the OS keychain, replacing any existing entry.
        #
        # @param master_password [String] the master password to store
        # @return [Boolean] true when stored; false when no keychain is available or the
        #   backend fails (the failure is logged)
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

        # Reads the master password back from the OS keychain.
        #
        # @return [String, nil] the stored password, or nil when no keychain is available,
        #   nothing is stored, or the backend fails (the failure is logged)
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

        # Builds the validation test stored in the saved-login file for a new master password.
        #
        # The test is a SHA-256 digest of a PBKDF2 key derived with {VALIDATION_ITERATIONS}
        # iterations over a fresh random salt; it lets a later entry be checked without
        # storing the password itself.
        #
        # @param master_password [String] the master password to derive the test from
        # @return [Hash{String => Object}] 'validation_salt' and 'validation_hash' (both Base64) and
        #   'validation_version' (Integer, currently 1)
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

        # Checks an entered master password against a stored validation test.
        #
        # @param entered_password [String] the password to check
        # @param validation_test [Hash{String => Object}, nil] a test from {.create_validation_test}
        # @return [Boolean] true when the password reproduces the stored hash; false for a
        #   malformed test, a mismatch, or a decoding error (the error is logged)
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

        # Removes the master password from the OS keychain.
        #
        # @return [Boolean] the backend's result; false when no keychain is available or the
        #   backend fails (the failure is logged)
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

        # Returns whether the macOS Keychain CLI is available for launcher use.
        #
        # On some macOS + Ruby/GTK combinations, spawning a shell command here can
        # raise during GUI startup before the launcher is fully built. Prefer a
        # direct executable check for the system Keychain CLI.
        private_class_method def self.macos_keychain_available?
          File.executable?('/usr/bin/security')
        rescue StandardError => e
          Lich.log "error: Failed to check macOS keychain availability: #{e.message}"
          false
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
          response = system('command -v secret-tool >/dev/null 2>&1')
          Lich.log "debug: secret-tool command not found; Linux keychain unavailable" if response == false
          response
        end

        private_class_method def self.store_linux_keychain(password)
          # Delete existing entry (ignore result) to ensure a clean update
          system("secret-tool clear service #{KEYCHAIN_SERVICE.shellescape} user lich5 >/dev/null 2>&1")

          # Add new entry using a pipe to avoid shell escaping issues
          # This ensures the raw password is sent directly to secret-tool's stdin
          IO.popen(["secret-tool", "store", "--label=Lich 5 Master", "service", KEYCHAIN_SERVICE, "user", "lich5"], "w") do |io|
            io.write(password)
          end
          $?.success?
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
