# frozen_string_literal: true

require_relative '../authentication/entry_store'
require_relative '../gui/master_password_manager'
require_relative '../authentication/cli_password'

module Lich
  module Common
    module CLI
      # Handles encryption mode changes via CLI
      # Manages prompting for passwords and calls EntryStore domain logic
      module EncryptionModeChange
        # Change encryption mode for all accounts
        #
        # @param new_mode [Symbol] Target encryption mode (:plaintext, :standard, :enhanced)
        # @param provided_password [String, nil] New master password for Enhanced
        #   mode, when the caller already has it (the deprecated --master-password)
        # @param password_stdin [Boolean] true when --password-stdin was given: the
        #   master password this change needs is the next line of stdin
        # @return [Integer] Exit code (0=success, 1=error, 2=not found, 3=invalid mode, 4=cancelled)
        def self.change_mode(new_mode, provided_password = nil, password_stdin: false)
          data_dir = DATA_DIR
          yaml_file = Lich::Common::Authentication::EntryStore.yaml_file_path(data_dir)

          # Validate file exists
          unless File.exist?(yaml_file)
            puts "error: Login file not found: #{yaml_file}"
            Lich.log "error: CLI encryption mode change failed - file not found"
            return 2
          end

          # Validate mode
          valid_modes = [:plaintext, :standard, :enhanced]
          unless valid_modes.include?(new_mode)
            puts "error: Invalid encryption mode: #{new_mode}"
            puts "Valid modes: plaintext, standard, enhanced"
            Lich.log "error: CLI encryption mode change failed - invalid mode: #{new_mode}"
            return 3
          end

          # Load current mode
          begin
            yaml_data = YAML.load_file(yaml_file)
            current_mode = yaml_data['encryption_mode']&.to_sym || :plaintext
            account_count = yaml_data['accounts']&.length || 0
          rescue StandardError => e
            puts "error: Failed to read login file: #{e.message}"
            Lich.log "error: CLI encryption mode change failed - read error: #{e.message}"
            return 1
          end

          # Check if already in target mode
          if current_mode == new_mode
            puts "info: Already using #{new_mode} encryption mode"
            Lich.log "info: CLI encryption mode change - already in target mode"
            return 0
          end

          puts "Changing encryption mode: #{current_mode} -> #{new_mode}"
          puts "Accounts to re-encrypt: #{account_count}"
          puts ""

          # Handle password requirements based on mode transition
          new_master_password = nil

          # A change needs at most one master password: the current one when
          # leaving Enhanced mode, the new one when entering it. With
          # --password-stdin that one is read here, before anything is asked.
          piped_password = nil
          if password_stdin && [current_mode, new_mode].include?(:enhanced)
            piped_password = read_piped_master_password(new_mode == :enhanced ? 'Enter new master password: ' : 'Enter master password: ')
            return 1 if piped_password.nil?

            provided_password = piped_password if new_mode == :enhanced
          end

          # If leaving Enhanced mode, validate current password
          if current_mode == :enhanced
            puts "Current mode is Enhanced encryption."
            master_password = piped_password || Lich::Common::Authentication::CLIPassword.prompt_for_master_password
            if master_password.nil?
              puts "Cancelled"
              Lich.log "info: CLI encryption mode change cancelled by user"
              return 4
            end

            # Validate the password
            validation_test = yaml_data['master_password_validation_test']
            unless Lich::Common::GUI::MasterPasswordManager.validate_master_password(
              master_password, validation_test
            )
              puts "error: Incorrect master password"
              Lich.log "error: CLI encryption mode change failed - password validation failed"
              return 1
            end

            puts "ok: Master password validated"
            puts ""
          end

          # If entering Enhanced mode, get/create master password
          if new_mode == :enhanced
            refusal = provided_password && Lich::Common::GUI::MasterPasswordManager.new_password_refusal(provided_password)
            if refusal
              puts "error: #{refusal}"
              Lich.log "error: CLI encryption mode change failed - #{refusal}"
              return 1
            end

            new_master_password = if provided_password
                                    provided_password
                                  else
                                    Lich::Common::Authentication::CLIPassword.get_master_password_from_keychain_or_prompt
                                  end

            if new_master_password.nil?
              puts "Cancelled"
              Lich.log "info: CLI encryption mode change cancelled by user"
              return 4
            end

            puts "ok: Master password accepted"
            puts ""
          end

          # Warn about plaintext mode
          if new_mode == :plaintext
            puts "warning: Plaintext mode disables encryption"
            puts "Passwords will be stored unencrypted and visible in the file."
            puts ""
            print "Continue? (yes/no): "
            input = $stdin.gets
            if input.nil? || input.strip.downcase != 'yes'
              puts "Cancelled"
              Lich.log "info: CLI encryption mode change cancelled by user"
              return 4
            end
            puts ""
          end

          # Call domain method to perform the change
          success = Lich::Common::Authentication::EntryStore.change_encryption_mode(
            data_dir,
            new_mode,
            new_master_password
          )

          unless success
            puts "error: Failed to change encryption mode"
            Lich.log "error: CLI encryption mode change failed at domain level"
            return 1
          end

          puts "ok: Encryption mode changed: #{current_mode} -> #{new_mode}"
          puts "ok: #{account_count} accounts re-encrypted" if account_count > 0

          Lich.log "info: CLI encryption mode change successful: #{current_mode} -> #{new_mode}"
          0
        rescue StandardError => e
          puts "error: Unexpected error during encryption mode change: #{e.message}"
          Lich.log "error: CLI encryption mode change failed: #{e.class}: #{e.message}"
          1
        end

        # @api private
        # Reads the master password from stdin for --password-stdin. The prompt
        # is shown only when stdin is a terminal; a pipe is read silently.
        #
        # @param prompt [String] prompt shown on a terminal
        # @return [String, nil] the password, or nil after printing why it could not be read
        def self.read_piped_master_password(prompt)
          Lich::Common::Authentication::CLIPassword.read_secret(prompt, from_stdin: true)
        rescue Lich::Common::Authentication::CLIPassword::SecretInputError => e
          puts "error: #{e.message}"
          Lich.log "error: CLI encryption mode change failed - #{e.message}"
          nil
        end
        private_class_method :read_piped_master_password
      end
    end
  end
end
