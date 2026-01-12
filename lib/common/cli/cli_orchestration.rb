# frozen_string_literal: true

require_relative 'cli_options_registry'
require_relative 'cli_password_manager'
require_relative 'cli_conversion'
require_relative 'cli_encryption_mode_change'
require_relative 'cli_login'

module Lich
  module Common
    module CLI
      # Orchestrates CLI operations: early-exit handlers for password management,
      # data conversion, and login flow. Uses CliOptionsRegistry for declarative
      # option registration and handler execution.
      module CLIOrchestration
        # Execute registered CLI operations
        # Processes ARGV for early-exit CLI operations (password mgmt, conversion)
        # Also handles conversion detection for login attempts
        def self.execute
          ARGV.each do |arg|
            case arg
            when /^--change-account-password$/, /^-cap$/
              handle_change_account_password
            when /^--add-account$/, /^-aa$/
              handle_add_account
            when /^--change-master-password$/, /^-cmp$/
              handle_change_master_password
            when /^--recover-master-password$/, /^-rmp$/
              handle_recover_master_password
            when /^--convert-entries$/
              handle_convert_entries
            when /^--change-encryption-mode$/, /^-cem$/
              handle_change_encryption_mode
            end
          end

          # Check for conversion needed before login attempt
          # This is not an early-exit operation - it detects a precondition for login
          if ARGV.include?('--login')
            check_conversion_needed_for_login
          end
        end

        def self.check_conversion_needed_for_login
          # Check if conversion is required
          if Lich::Common::CLI::CLIConversion.conversion_needed?(DATA_DIR)
            Lich::Common::CLI::CLIConversion.print_conversion_help_message
            exit 1
          end
        end

        def self.handle_change_account_password
          idx = ARGV.index { |a| a =~ /^--change-account-password$|^-cap$/ }
          account = ARGV[idx + 1]
          new_password = ARGV[idx + 2]

          if account.nil? || new_password.nil?
            lich_script = File.join(LICH_DIR, 'lich.rbw')
            $stdout.puts 'error: Missing required arguments'
            $stdout.puts "Usage: ruby #{lich_script} --change-account-password ACCOUNT NEWPASSWORD"
            $stdout.puts "   or: ruby #{lich_script} -cap ACCOUNT NEWPASSWORD"
            exit 1
          end

          exit Lich::Common::CLI::PasswordManager.change_account_password(account, new_password)
        end

        def self.handle_add_account
          idx = ARGV.index { |a| a =~ /^--add-account$|^-aa$/ }
          account = ARGV[idx + 1]
          password = ARGV[idx + 2]

          if account.nil? || password.nil?
            lich_script = File.join(LICH_DIR, 'lich.rbw')
            $stdout.puts 'error: Missing required arguments'
            $stdout.puts "Usage: ruby #{lich_script} --add-account ACCOUNT PASSWORD [--frontend FRONTEND]"
            $stdout.puts "   or: ruby #{lich_script} -aa ACCOUNT PASSWORD [--frontend FRONTEND]"
            exit 1
          end

          frontend = ARGV[ARGV.index('--frontend') + 1] if ARGV.include?('--frontend')
          exit Lich::Common::CLI::PasswordManager.add_account(account, password, frontend)
        end

        def self.handle_change_master_password
          idx = ARGV.index { |a| a =~ /^--change-master-password$|^-cmp$/ }
          old_password = ARGV[idx + 1]
          new_password = ARGV[idx + 2]

          if old_password.nil?
            lich_script = File.join(LICH_DIR, 'lich.rbw')
            $stdout.puts 'error: Missing required arguments'
            $stdout.puts "Usage: ruby #{lich_script} --change-master-password OLDPASSWORD [NEWPASSWORD]"
            $stdout.puts "   or: ruby #{lich_script} -cmp OLDPASSWORD [NEWPASSWORD]"
            $stdout.puts 'Note: If NEWPASSWORD is not provided, you will be prompted for confirmation'
            exit 1
          end

          exit Lich::Common::CLI::PasswordManager.change_master_password(old_password, new_password)
        end

        def self.handle_recover_master_password
          idx = ARGV.index { |a| a =~ /^--recover-master-password$|^-rmp$/ }
          new_password = ARGV[idx + 1]

          # new_password is optional - if not provided, user will be prompted interactively
          exit Lich::Common::CLI::PasswordManager.recover_master_password(new_password)
        end

        def self.handle_convert_entries
          idx = ARGV.index('--convert-entries')
          encryption_mode_str = ARGV[idx + 1]

          if encryption_mode_str.nil?
            lich_script = File.join(LICH_DIR, 'lich.rbw')
            $stdout.puts 'error: Missing required argument'
            $stdout.puts "Usage: ruby #{lich_script} --convert-entries [plaintext|standard|enhanced]"
            exit 1
          end

          unless %w[plaintext standard enhanced].include?(encryption_mode_str)
            $stdout.puts "error: Invalid encryption mode: #{encryption_mode_str}"
            $stdout.puts 'Valid modes: plaintext, standard, enhanced'
            exit 1
          end

          # For enhanced mode, prompt for master password and store in keychain before conversion
          # This way migrate_from_legacy will find it in keychain and not try to show GUI dialog
          if encryption_mode_str == 'enhanced'
            master_password = Lich::Common::CLI::PasswordManager.prompt_and_confirm_password('Enter new master password for enhanced encryption')
            if master_password.nil?
              puts 'error: Master password creation cancelled'
              exit 1
            end

            # Store password in keychain so ensure_master_password_exists finds it
            require_relative '../gui/master_password_manager'
            stored = Lich::Common::GUI::MasterPasswordManager.store_master_password(master_password)
            unless stored
              puts 'error: Failed to store master password in keychain'
              exit 1
            end
          end

          # Perform conversion
          success = Lich::Common::CLI::CLIConversion.convert(
            DATA_DIR,
            encryption_mode_str
          )

          if success
            $stdout.puts 'Conversion completed successfully!'
            exit 0
          else
            $stdout.puts 'Conversion failed. Please check the logs for details.'
            exit 1
          end
        end

        def self.handle_change_encryption_mode
          idx = ARGV.index { |a| a =~ /^--change-encryption-mode$|^-cem$/ }
          mode_arg = ARGV[idx + 1]

          if mode_arg.nil?
            lich_script = File.join(LICH_DIR, 'lich.rbw')
            $stdout.puts 'error: Missing encryption mode'
            $stdout.puts "Usage: ruby #{lich_script} --change-encryption-mode MODE [--master-password PASSWORD]"
            $stdout.puts "       ruby #{lich_script} -cem MODE [-mp PASSWORD]"
            $stdout.puts 'Modes: plaintext, standard, enhanced'
            exit 1
          end

          new_mode = mode_arg.to_sym

          # Check for optional master password (for Enhanced mode, if automating)
          mp_index = ARGV.index('--master-password') || ARGV.index('-mp')
          master_password = ARGV[mp_index + 1] if mp_index

          exit Lich::Common::CLI::EncryptionModeChange.change_mode(new_mode, master_password)
        end
      end
    end
  end
end
