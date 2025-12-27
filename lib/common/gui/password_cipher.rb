# frozen_string_literal: true

require 'openssl'
require 'securerandom'
require 'base64'

module Lich
  module Common
    module GUI
      # Handles password encryption and decryption using AES-256-CBC
      # Supports multiple encryption modes for different requirements
      #
      # @example Encrypt with standard mode
      #   encrypted = PasswordCipher.encrypt('mypassword', mode: :standard, account_name: 'user123')
      #
      # @example Decrypt with standard mode
      #   decrypted = PasswordCipher.decrypt(encrypted, mode: :standard, account_name: 'user123')
      #
      # @example Encrypt with enhanced encryption
      #   encrypted = PasswordCipher.encrypt('mypassword', mode: :enhanced, master_password: 'secret123')
      module PasswordCipher
        # Custom exception for decryption failures
        class DecryptionError < StandardError; end

        # AES cipher algorithm
        CIPHER_ALGORITHM = 'AES-256-CBC'

        # PBKDF2 iteration count for key derivation
        KEY_ITERATIONS = 10_000

        # Key length for AES-256 (32 bytes = 256 bits)
        KEY_LENGTH = 32

        # Encrypts a password using the specified mode
        #
        # @param password [String] The plaintext password to encrypt
        # @param mode [Symbol] Encryption mode (:standard or :enhanced)
        # @param account_name [String, nil] Account name for :standard mode
        # @param master_password [String, nil] Master password for :enhanced mode
        # @return [String] Base64-encoded encrypted password (IV + ciphertext)
        # @raise [ArgumentError] If required parameters are missing or mode is invalid
        def self.encrypt(password, mode:, account_name: nil, master_password: nil)
          validate_encryption_params(mode, account_name, master_password)

          # Derive encryption key based on mode
          key = derive_key(mode, account_name, master_password)

          # Initialize cipher
          cipher = OpenSSL::Cipher.new(CIPHER_ALGORITHM)
          cipher.encrypt
          cipher.key = key

          # Generate random IV
          iv = cipher.random_iv

          # Encrypt password
          encrypted = cipher.update(password) + cipher.final

          # Combine IV + encrypted data and encode as Base64
          Base64.strict_encode64(iv + encrypted)
        end

        # Decrypts a password using the specified mode
        #
        # @param encrypted_password [String] Base64-encoded encrypted password
        # @param mode [Symbol] Encryption mode (:standard or :enhanced)
        # @param account_name [String, nil] Account name for :standard mode
        # @param master_password [String, nil] Master password for :enhanced mode
        # @return [String] Decrypted plaintext password
        # @raise [ArgumentError] If required parameters are missing or mode is invalid
        # @raise [DecryptionError] If decryption fails
        def self.decrypt(encrypted_password, mode:, account_name: nil, master_password: nil)
          validate_encryption_params(mode, account_name, master_password)

          # Derive decryption key based on mode
          key = derive_key(mode, account_name, master_password)

          # Decode from Base64
          encrypted_data = Base64.strict_decode64(encrypted_password)

          # Extract IV and ciphertext
          cipher = OpenSSL::Cipher.new(CIPHER_ALGORITHM)
          iv_length = cipher.iv_len
          iv = encrypted_data[0...iv_length]
          ciphertext = encrypted_data[iv_length..]

          # Initialize cipher for decryption
          cipher.decrypt
          cipher.key = key
          cipher.iv = iv

          # Decrypt password
          decrypted = cipher.update(ciphertext) + cipher.final
          decrypted.force_encoding('UTF-8')
        rescue OpenSSL::Cipher::CipherError, ArgumentError => e
          raise DecryptionError, "Failed to decrypt password: #{e.message}"
        end

        # Validates encryption parameters
        #
        # @param mode [Symbol] Encryption mode
        # @param account_name [String, nil] Account name
        # @param master_password [String, nil] Master password
        # @raise [ArgumentError] If parameters are invalid
        def self.validate_encryption_params(mode, account_name, master_password)
          unless %i[standard enhanced].include?(mode)
            raise ArgumentError, "Unsupported encryption mode: #{mode}"
          end

          if mode == :standard && account_name.nil?
            raise ArgumentError, 'account_name required for :standard mode'
          end

          if mode == :enhanced && master_password.nil?
            raise ArgumentError, 'master_password required for :enhanced mode'
          end
        end
        private_class_method :validate_encryption_params

        # Derives encryption key using PBKDF2
        #
        # @param mode [Symbol] Encryption mode
        # @param account_name [String, nil] Account name for :standard mode
        # @param master_password [String, nil] Master password for :enhanced mode
        # @return [String] Derived encryption key
        def self.derive_key(mode, account_name, master_password)
          # Select passphrase based on mode
          passphrase = case mode
                       when :standard
                         account_name
                       when :enhanced
                         master_password
                       end

          # Use a fixed salt for deterministic key derivation
          # In production, consider using a stored random salt per account
          salt = "lich5-password-encryption-#{mode}"

          # Derive key using PBKDF2
          OpenSSL::PKCS5.pbkdf2_hmac(
            passphrase,
            salt,
            KEY_ITERATIONS,
            KEY_LENGTH,
            OpenSSL::Digest.new('SHA256')
          )
        end
        private_class_method :derive_key
      end
    end
  end
end
