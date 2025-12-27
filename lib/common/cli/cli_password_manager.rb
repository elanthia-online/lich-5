# frozen_string_literal: true

require 'yaml'
require File.join(LIB_DIR, 'common', 'gui', 'yaml_state.rb')
require File.join(LIB_DIR, 'common', 'gui', 'utilities.rb')
require File.join(LIB_DIR, 'common', 'gui', 'account_manager.rb')

module Lich
  module Common
    module CLI
      # Headless password management operations for CLI execution
      # Thin wrapper around YamlState and PasswordCipher
      # Handles: change account password, add account, change master password
      #
      # @example
      #   Lich::Common::CLI::PasswordManager.change_account_password('DOUG', 'NewPass123')
      module PasswordManager
        # Changes account password in entry.yaml
        # Handles all encryption modes (plaintext, standard, enhanced)
        #
        # @param account [String] Account username
        # @param new_password [String] New plaintext password
        # @return [Integer] Exit code (0=success, 1=error, 2=not found)
        def self.change_account_password(account, new_password)
          # Validate master password availability before attempting change
          unless validate_master_password_available
            return 1
          end

          data_dir = DATA_DIR
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)

          unless File.exist?(yaml_file)
            puts "error: entry.yaml not found at #{yaml_file}"
            return 2
          end

          begin
            yaml_data = YAML.load_file(yaml_file)
            encryption_mode = (yaml_data['encryption_mode'] || 'plaintext').to_sym

            # Find account
            unless yaml_data['accounts'] && yaml_data['accounts'][account]
              puts "error: Account '#{account}' not found"
              Lich.log "error: CLI change password failed - account '#{account}' not found"
              return 2
            end

            Lich.log "info: Changing password for account '#{account}' (mode: #{encryption_mode})"

            # Encrypt password based on mode
            encrypted = case encryption_mode
                        when :plaintext
                          new_password
                        when :standard
                          Lich::Common::GUI::PasswordCipher.encrypt(
                            new_password,
                            mode: :standard,
                            account_name: account
                          )
                        when :enhanced
                          master_password = Lich::Common::GUI::MasterPasswordManager.retrieve_master_password
                          if master_password.nil?
                            puts 'error: Enhanced mode requires master password in keychain'
                            Lich.log 'error: CLI change password failed - master password not in keychain'
                            return 1
                          end
                          Lich::Common::GUI::PasswordCipher.encrypt(
                            new_password,
                            mode: :enhanced,
                            account_name: account,
                            master_password: master_password
                          )
                        else
                          puts "error: Unknown encryption mode: #{encryption_mode}"
                          Lich.log "error: CLI change password failed - unknown encryption mode: #{encryption_mode}"
                          return 1
                        end

            # Update account password
            yaml_data['accounts'][account]['password'] = encrypted

            # Save YAML
            File.open(yaml_file, 'w', 0o600) do |file|
              file.write(YAML.dump(yaml_data))
            end

            puts "success: Password changed for account '#{account}'"
            Lich.log "info: Password changed successfully for account '#{account}'"
            0
          rescue StandardError => e
            # CRITICAL: Only log e.message, NEVER log password values
            puts "error: #{e.message}"
            Lich.log "error: CLI change password failed for '#{account}': #{e.message}"
            1
          end
        end

        # Adds new account to entry.yaml
        # Authenticates with game servers to fetch all characters
        # Mimics GUI "Add Account" behavior
        #
        # @param account [String] Account username
        # @param password [String] Account password
        # @param frontend [String, nil] Frontend (wizard, stormfront, avalon, or nil)
        # @return [Integer] Exit code (0=success, 1=error, 2=auth failed)
        def self.add_account(account, password, frontend = nil)
          # Validate master password availability before attempting add
          unless validate_master_password_available
            return 1
          end

          data_dir = DATA_DIR
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)

          begin
            # Check if account already exists
            if File.exist?(yaml_file)
              yaml_data = YAML.load_file(yaml_file)
              if yaml_data['accounts'] && yaml_data['accounts'][account]
                puts "error: Account '#{account}' already exists"
                puts "Use --change-account-password to update the password."
                Lich.log "error: CLI add account failed - account '#{account}' already exists"
                return 1
              end
            end

            Lich.log "info: Adding account '#{account}' via CLI"

            # Authenticate with game servers to fetch characters (like GUI does)
            puts "Authenticating with game servers..."
            Lich.log "info: Authenticating account '#{account}' with game servers"
            auth_data = Lich::Common::GUI::Authentication.authenticate(
              account: account,
              password: password,
              legacy: true
            )

            unless auth_data && auth_data.is_a?(Array) && !auth_data.empty?
              puts "error: Authentication failed or no characters found"
              Lich.log "error: CLI add account failed - game server authentication failed for '#{account}'"
              return 2
            end

            Lich.log "info: Authentication successful - found #{auth_data.length} character(s)"

            # Determine frontend
            selected_frontend = if frontend
                                  # Frontend provided via --frontend flag
                                  Lich.log "info: Using provided frontend: #{frontend}"
                                  frontend
                                else
                                  # Check predominant frontend in YAML, or prompt
                                  predominant = determine_predominant_frontend(yaml_file)
                                  if predominant
                                    puts "Using predominant frontend: #{predominant}"
                                    Lich.log "info: Using predominant frontend: #{predominant}"
                                    predominant
                                  else
                                    # Prompt user
                                    prompt_for_frontend
                                  end
                                end

            # Convert authentication data to character list
            character_list = Lich::Common::GUI::AccountManager.convert_auth_data_to_characters(
              auth_data,
              selected_frontend || 'stormfront'
            )

            # Save account + characters using AccountManager
            if Lich::Common::GUI::AccountManager.add_or_update_account(data_dir, account, password, character_list)
              puts "success: Account '#{account}' added with #{character_list.length} character(s)"
              Lich.log "info: Account '#{account}' added successfully with #{character_list.length} character(s)"
              if selected_frontend.nil? || selected_frontend.empty?
                puts "note: Frontend not set - use GUI to configure or rerun with --frontend"
                Lich.log "warning: No frontend set for account '#{account}'"
              end
              0
            else
              puts "error: Failed to save account"
              Lich.log "error: CLI add account failed - could not save account '#{account}'"
              1
            end
          rescue StandardError => e
            # CRITICAL: Only log e.message, NEVER log password values
            puts "error: #{e.message}"
            Lich.log "error: CLI add account failed for '#{account}': #{e.message}"
            1
          end
        end

        # Changes master password and re-encrypts all accounts
        # Only works in Enhanced encryption mode
        # Prompts for new password if not provided
        #
        # @param old_password [String] Current master password
        # @param new_password [String, nil] New master password (optional, will prompt if nil)
        # @return [Integer] Exit code (0=success, 1=error, 3=wrong mode)
        def self.change_master_password(old_password, new_password = nil)
          data_dir = DATA_DIR
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)

          unless File.exist?(yaml_file)
            puts "error: entry.yaml not found at #{yaml_file}"
            return 2
          end

          begin
            yaml_data = YAML.load_file(yaml_file)
            encryption_mode = (yaml_data['encryption_mode'] || 'plaintext').to_sym

            unless encryption_mode == :enhanced
              puts "error: Master password only used in Enhanced encryption mode"
              puts "Current mode: #{encryption_mode}"
              Lich.log "error: CLI change master password failed - wrong encryption mode: #{encryption_mode}"
              return 3
            end

            Lich.log "info: Starting CLI master password change"

            # Validate old password
            validation_test = yaml_data['master_password_validation_test']
            unless Lich::Common::GUI::MasterPasswordManager.validate_master_password(old_password, validation_test)
              puts 'error: Current master password incorrect'
              Lich.log 'error: CLI change master password failed - incorrect current password'
              return 1
            end

            Lich.log "info: Current master password validated successfully"

            # Use provided password or prompt for new password
            if new_password.nil?
              print "Enter new master password: "
              input = $stdin.gets
              if input.nil?
                puts 'error: Unable to read password from STDIN / terminal'
                puts 'Please run this command interactively (not in a pipe or automated script without input)'
                Lich.log 'error: CLI change master password failed - stdin unavailable'
                return 1
              end
              new_password = input.strip

              print "Confirm new master password: "
              input = $stdin.gets
              if input.nil?
                puts 'error: Unable to read password from STDIN / terminal'
                puts 'Please run this command interactively (not in a pipe or automated script without input)'
                Lich.log 'error: CLI change master password failed - stdin unavailable'
                return 1
              end
              confirm_password = input.strip

              unless new_password == confirm_password
                puts "error: Passwords do not match"
                Lich.log "error: CLI change master password failed - password confirmation mismatch"
                return 1
              end
            end

            if new_password.length < 8
              puts "error: Password must be at least 8 characters"
              Lich.log "error: CLI change master password failed - password too short"
              return 1
            end

            account_count = yaml_data['accounts'].length
            Lich.log "info: Re-encrypting #{account_count} account(s) with new master password"

            # Re-encrypt all accounts
            yaml_data['accounts'].each do |_username, account_data|
              # Decrypt with old password
              plaintext = Lich::Common::GUI::PasswordCipher.decrypt(
                account_data['password'],
                mode: :enhanced,
                master_password: old_password
              )

              # Encrypt with new password
              new_encrypted = Lich::Common::GUI::PasswordCipher.encrypt(
                plaintext,
                mode: :enhanced,
                master_password: new_password
              )

              account_data['password'] = new_encrypted
            end

            # Update validation test
            new_validation = Lich::Common::GUI::MasterPasswordManager.create_validation_test(new_password)
            yaml_data['master_password_validation_test'] = new_validation

            # Update keychain
            unless Lich::Common::GUI::MasterPasswordManager.store_master_password(new_password)
              puts 'error: Failed to update keychain'
              Lich.log 'error: CLI change master password failed - keychain update failed'
              return 1
            end

            # Save YAML
            File.open(yaml_file, 'w', 0o600) do |file|
              file.write(YAML.dump(yaml_data))
            end

            puts 'success: Master password changed'
            Lich.log 'info: Master password changed successfully via CLI'
            0
          rescue StandardError => e
            # CRITICAL: Only log e.message, NEVER log password values
            puts "error: #{e.message}"
            Lich.log "error: CLI change master password failed: #{e.message}"
            1
          end
        end

        # Determines predominant frontend from existing YAML accounts
        #
        # @param yaml_file [String] Path to entry.yaml
        # @return [String, nil] Predominant frontend or nil
        def self.determine_predominant_frontend(yaml_file)
          return nil unless File.exist?(yaml_file)

          yaml_data = YAML.load_file(yaml_file)
          return nil unless yaml_data['accounts']

          frontend_counts = Hash.new(0)
          yaml_data['accounts'].each do |_username, account_data|
            next unless account_data['characters']

            account_data['characters'].each do |char|
              fe = char['frontend']
              frontend_counts[fe] += 1 if fe && !fe.empty?
            end
          end

          return nil if frontend_counts.empty?

          frontend_counts.max_by { |_fe, count| count }&.first
        end

        # Prompts user for frontend selection
        #
        # @return [String, nil] Selected frontend or nil (user skipped)
        def self.prompt_for_frontend
          puts "\nSelect frontend (or press Enter to skip):"
          puts "  1. wizard"
          puts "  2. stormfront"
          puts "  3. avalon"
          print "Choice (1-3 or Enter): "

          input = $stdin.gets
          if input.nil?
            puts 'error: Unable to read input from STDIN / terminal'
            puts 'Please run this command interactively (not in a pipe or automated script without input)'
            return nil
          end
          choice = input.strip
          return nil if choice.empty?

          case choice
          when '1' then 'wizard'
          when '2' then 'stormfront'
          when '3' then 'avalon'
          else
            puts "Invalid choice, skipping frontend selection"
            nil
          end
        end

        # Validates if master password is available in keychain for enhanced mode
        # Checks: YAML exists, validation test present, keychain available with password
        #
        # @return [Boolean] true if ready for operations, false if issues found
        def self.validate_master_password_available
          data_dir = DATA_DIR
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)

          unless File.exist?(yaml_file)
            puts "error: entry.yaml not found"
            return false
          end

          begin
            yaml_data = YAML.load_file(yaml_file)
            encryption_mode = (yaml_data['encryption_mode'] || 'plaintext').to_sym

            # Non-enhanced modes don't need master password
            return true unless encryption_mode == :enhanced

            # Check if validation test exists (indicator of Enhanced mode setup)
            unless yaml_data['master_password_validation_test']
              puts "error: No validation test found in entry.yaml"
              puts "Master password recovery may be needed"
              return false
            end

            # Check if keychain is available and has the password
            unless Lich::Common::GUI::MasterPasswordManager.keychain_available?
              puts "error: Keychain not available on this system"
              return false
            end

            master_password = Lich::Common::GUI::MasterPasswordManager.retrieve_master_password
            if master_password.nil? || master_password.empty?
              puts "error: Master password not found in keychain"
              puts "Use: lich --recover-master-password"
              puts "     to restore the master password from your accounts"
              Lich.log "info: Master password validation failed - keychain missing, user can recover"
              return false
            end

            true
          rescue StandardError => e
            Lich.log "error: Master password validation failed: #{e.message}"
            false
          end
        end

        # Recovers access to keychain by validating and restoring original master password
        # User re-enters original master password which is validated against validation_test
        # Account passwords remain unchanged (already encrypted with original password)
        # Only works in Enhanced encryption mode when validation test exists
        #
        # @param master_password [String, nil] Original master password (optional, will prompt if nil)
        # @return [Integer] Exit code (0=success, 1=error, 2=not found, 3=wrong mode)
        def self.recover_master_password(master_password = nil)
          data_dir = DATA_DIR
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)

          unless File.exist?(yaml_file)
            puts "error: entry.yaml not found at #{yaml_file}"
            return 2
          end

          begin
            yaml_data = YAML.load_file(yaml_file)
            encryption_mode = (yaml_data['encryption_mode'] || 'plaintext').to_sym

            unless encryption_mode == :enhanced
              puts "error: Master password recovery only works in Enhanced encryption mode"
              puts "Current mode: #{encryption_mode}"
              Lich.log "error: CLI recover master password failed - wrong encryption mode: #{encryption_mode}"
              return 3
            end

            # Must have validation test to validate password
            validation_test = yaml_data['master_password_validation_test']
            unless validation_test
              puts "error: No validation test found - cannot recover master password"
              Lich.log "error: CLI recover master password failed - no validation test"
              return 1
            end

            Lich.log "info: Starting master password recovery"

            # Get password to validate
            if master_password.nil?
              print "Enter master password: "
              input = $stdin.gets
              if input.nil?
                puts 'error: Unable to read password from STDIN / terminal'
                puts 'Please run this command interactively (not in a pipe or automated script without input)'
                Lich.log 'error: CLI recover master password failed - stdin unavailable'
                return 1
              end
              master_password = input.strip
            end

            if master_password.length < 8
              puts "error: Password must be at least 8 characters"
              Lich.log "error: CLI recover master password failed - password too short"
              return 1
            end

            # Validate password against validation test
            unless Lich::Common::GUI::MasterPasswordManager.validate_master_password(master_password, validation_test)
              puts "error: Password validation failed"
              Lich.log "error: CLI recover master password failed - password validation failed"
              return 1
            end

            Lich.log "info: Password validated successfully"

            # Store validated password in keychain
            unless Lich::Common::GUI::MasterPasswordManager.store_master_password(master_password)
              puts 'error: Failed to store master password in keychain'
              Lich.log 'error: CLI recover master password failed - keychain storage failed'
              return 1
            end

            puts 'success: Master password recovered and restored to keychain'
            Lich.log 'info: Master password recovered successfully via CLI'
            0
          rescue StandardError => e
            # CRITICAL: Only log e.message, NEVER log password values
            puts "error: #{e.message}"
            Lich.log "error: CLI recover master password failed: #{e.message}"
            1
          end
        end

        # Helper: Prompts user for a password with confirmation
        # Used for creating new master passwords or changing existing ones
        #
        # @param prompt [String] Prompt to show user (default: "Enter password")
        # @return [String, nil] Password if valid, nil if cancelled or error
        def self.prompt_and_confirm_password(prompt = "Enter password")
          print "#{prompt}: "
          input = $stdin.gets
          if input.nil?
            puts 'error: Unable to read password from STDIN / terminal'
            puts 'Please run this command interactively (not in a pipe or automated script without input)'
            Lich.log 'error: Password prompt failed - stdin unavailable'
            return nil
          end
          password = input.strip

          print "Confirm #{prompt.downcase}: "
          input = $stdin.gets
          if input.nil?
            puts 'error: Unable to read password from STDIN / terminal'
            puts 'Please run this command interactively (not in a pipe or automated script without input)'
            Lich.log 'error: Password confirmation failed - stdin unavailable'
            return nil
          end
          confirm_password = input.strip

          unless password == confirm_password
            puts "error: Passwords do not match"
            Lich.log "error: Password confirmation mismatch"
            return nil
          end

          if password.length < 8
            puts "error: Password must be at least 8 characters"
            Lich.log "error: Password too short (minimum 8 characters)"
            return nil
          end

          password
        rescue StandardError => e
          Lich.log "error: Password prompt failed: #{e.message}"
          nil
        end

        # Gets master password from keychain or prompts user if not available
        # Used when entering Enhanced mode - checks keychain first, prompts if missing
        #
        # @return [String, nil] Master password or nil if unavailable/cancelled
        def self.get_master_password_from_keychain_or_prompt
          # Check if password already exists in keychain
          existing = Lich::Common::GUI::MasterPasswordManager.retrieve_master_password
          return existing if existing

          # Not in keychain, prompt user to create one
          puts "Creating new master password for Enhanced encryption mode..."
          prompt_and_confirm_password("Enter new master password")
        end

        # Prompts for master password (single prompt, no confirmation)
        # Used when validating current password when leaving Enhanced mode
        #
        # @return [String, nil] Master password or nil if unavailable
        def self.prompt_for_master_password
          print "Enter master password: "
          input = $stdin.gets
          if input.nil?
            puts 'error: Unable to read password from STDIN / terminal'
            Lich.log 'error: Master password prompt failed - stdin unavailable'
            return nil
          end
          input.strip
        rescue StandardError => e
          Lich.log "error: Master password prompt failed: #{e.message}"
          nil
        end
      end
    end
  end
end
