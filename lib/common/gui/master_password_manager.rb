# frozen_string_literal: true

require 'openssl' # default gem, but upgrade via RubyGems available
require 'securerandom' # default gem
require 'base64' # bundled gem Ruby >= 3.4, default gem Ruby < 3.4
Lich::Util.install_gem_requirements({ 'os' => true })
require 'shellwords' # default gem
require 'open3' # default gem
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
        # Shortest master password the CLI accepts when one is created or replaced.
        # The GTK dialogs keep their own length checks. Applies to new passwords
        # only: an existing password is checked against the stored validation
        # test, never by length.
        MIN_PASSWORD_LENGTH = 8
        # Fixed refusals for a new master password; none includes the password.
        NEW_PASSWORD_EMPTY = 'Master password cannot be empty.'
        NEW_PASSWORD_TOO_SHORT = "New master password must be at least #{MIN_PASSWORD_LENGTH} characters."
        NEW_PASSWORD_EDGE_WHITESPACE = 'New master password cannot begin or end with whitespace.'

        # The one entry rule for every CLI master-password prompt: removes only the
        # line terminator, never surrounding whitespace, so an existing password is
        # checked exactly as typed.
        # @param input [String] line read from the prompt
        # @return [String] entered password
        def self.normalize_entry(input)
          input.chomp
        end

        # The one acceptance rule for a new master password on every CLI create and
        # change path. The GTK dialogs keep their own checks. Existing passwords
        # (unlock and recovery) are never checked here; the validation test
        # decides them.
        # @param password [String, nil] proposed new master password
        # @return [String, nil] fixed refusal message, or nil when acceptable
        def self.new_password_refusal(password)
          return NEW_PASSWORD_EMPTY if password.nil? || password.empty?
          return NEW_PASSWORD_TOO_SHORT if password.length < MIN_PASSWORD_LENGTH
          return NEW_PASSWORD_EDGE_WHITESPACE if password.match?(/\A[[:space:]]|[[:space:]]\z/)

          nil
        end

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

        # Strict reads are required for transaction snapshots and rollback checks:
        # nil means confirmed absence, while unavailable or failed reads raise.
        # Legacy callers retain the nil-on-error contract.
        def self.retrieve_master_password(strict: false)
          return retrieve_master_password_strict if strict

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
          raise if strict

          Lich.log "error: Failed to retrieve master password: #{e.message}"
          nil
        end

        # @return [String, nil] password or confirmed absence
        # @raise [IOError] if the previous keychain state cannot be established
        private_class_method def self.retrieve_master_password_strict
          raise IOError, "Keychain unavailable; previous master password state is unknown" unless keychain_available?

          if OS.windows?
            return WindowsCredentialManager.retrieve_credential(KEYCHAIN_SERVICE, strict: true)
          elsif OS.mac?
            password, status = read_macos_keychain
            # errSecItemNotFound (-25300), represented as an 8-bit process status.
            return nil if status.exitstatus == 44
            raise IOError, "Keychain read failed; previous master password state is unknown" unless status.success? && password && !password.empty?

            return password
          elsif OS.linux?
            attributes = ['service', KEYCHAIN_SERVICE, 'user', 'lich5']
            output, error, status = Open3.capture3('secret-tool', 'lookup', *attributes)
            if status.exitstatus == 1 && output.empty? && error.empty?
              # Lookup can also return no value for a locked item. Only a successful
              # empty search (including locked items) establishes actual absence.
              items, error, search_status = Open3.capture3('secret-tool', 'search', '--all', *attributes)
              return nil if search_status.success? && items.empty? && error.empty?
            end
          else
            raise IOError, "Unsupported keychain; previous master password state is unknown"
          end

          # Remove only the tool's line terminator; the stored password is returned as stored.
          password = normalize_entry(output)
          raise IOError, "Keychain read failed; previous master password state is unknown" unless status.success? && !password.empty?

          password
        rescue StandardError
          # Never propagate command output or credential values into diagnostics.
          raise IOError, "Keychain read failed; previous master password state is unknown"
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

        # Stores the password without putting it on a command line, where the
        # process list would show it. The security tool reads the command from
        # its standard input, and the password travels as hexadecimal so no
        # character in it needs quoting. -U replaces an existing item in place.
        # @param password [String] master password to store
        # @return [Boolean] true when the tool reports the item stored
        private_class_method def self.store_macos_keychain(password)
          return false if password.nil? || password.empty?

          command = ['add-generic-password', '-U', '-s', KEYCHAIN_SERVICE, '-a', 'lich5',
                     '-X', password.unpack1('H*'), *macos_keychain_target].join(' ')
          _output, _diagnostics, status = Open3.capture3('/usr/bin/security', '-i', stdin_data: "#{command}\n")
          status.success?
        end

        private_class_method def self.retrieve_macos_keychain
          password, _status = read_macos_keychain
          password.nil? || password.empty? ? nil : password
        rescue
          nil
        end

        # Reads the stored password with the tool's -g form. Its -w form prints
        # a password as text or, when any byte is not plain printable ASCII, as
        # bare hexadecimal, and the two cannot be told apart. -g marks which
        # one it printed.
        # @return [Array(String, Process::Status), Array(nil, Process::Status)]
        #   the password as stored (nil when the tool printed none) and the
        #   tool's exit status
        private_class_method def self.read_macos_keychain
          _attributes, password_report, status = Open3.capture3(
            '/usr/bin/security', 'find-generic-password', '-s', KEYCHAIN_SERVICE, '-g', *macos_keychain_target
          )
          [status.success? ? macos_reported_password(password_report) : nil, status]
        end

        # Extracts the password from the line -g prints: `password: "text"` for
        # plain printable ASCII, otherwise `password: 0xHEX  "escaped text"`.
        # The hexadecimal form is exact, so it is decoded and the escaped text
        # is ignored.
        # @param report [String] what the tool printed about the password
        # @return [String, nil] the stored password, or nil when none is reported
        private_class_method def self.macos_reported_password(report)
          line = report.each_line(chomp: true).find { |candidate| candidate.start_with?('password: ') }
          return nil unless line

          if (hex = line[/\Apassword: 0x([0-9A-Fa-f]+)/, 1])
            [hex].pack('H*').force_encoding(Encoding::UTF_8)
          else
            line[/\Apassword: "(.*)"\z/, 1]
          end
        end

        # Keychain the macOS store and read act on. Empty selects the user's
        # default keychain.
        # @return [Array<String>] trailing keychain argument for the security tool
        private_class_method def self.macos_keychain_target
          []
        end

        # Reads a keychain tool's output as the stored password: only the line
        # terminator the tool prints is removed, so edge whitespace survives.
        # @param output [String] tool output
        # @return [String, nil] stored password, or nil when the output is empty
        private_class_method def self.stored_password(output)
          password = normalize_entry(output)
          password.empty? ? nil : password
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
          stored_password(`secret-tool lookup service #{KEYCHAIN_SERVICE.shellescape} user lich5 2>/dev/null`)
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
