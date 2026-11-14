# frozen_string_literal: true

require_relative 'cli_options_registry'
require_relative 'one_shot_commands'
require_relative 'active_sessions_query'
require_relative '../authentication/cli_password'
require_relative 'cli_conversion'
require_relative 'cli_encryption_mode_change'
require_relative '../authentication/cli'
require_relative '../authentication/login_helpers'
require_relative '../authentication/web_login'
require_relative '../gui/game_selection'
require_relative 'cli_option_validator'

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
          ActiveSessionsQuery.execute

          ARGV.each do |arg|
            handler = OneShotCommands::HANDLERS[arg]
            send(handler) if handler
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

          lich_script = File.join(LICH_DIR, 'lich.rbw')
          usage = "Usage: ruby #{lich_script} --change-account-password ACCOUNT [--password-stdin]\n" \
                  "   or: ruby #{lich_script} -cap ACCOUNT [--password-stdin]\n" \
                  'Prompts for the new password; with --password-stdin, reads one line from stdin instead.'

          account = CliOptionValidator.require_positional(account, name: 'ACCOUNT', usage: usage)

          password_stdin = ARGV.include?(PASSWORD_STDIN_FLAG)
          new_password = command_line_secret(ARGV[idx + 2], name: 'NEWPASSWORD', after: 'ACCOUNT', command: ARGV[idx],
                                                            password_stdin: password_stdin, usage: usage)
          new_password ||= if password_stdin
                             read_secret_or_exit('', from_stdin: true, usage: usage)
                           else
                             read_confirmed_secret_or_exit('New password: ', 'Confirm new password: ', usage: usage)
                           end

          exit Lich::Common::Authentication::CLIPassword.change_account_password(account, new_password)
        end

        # Returns a secret given on the command line, after warning that the
        # form is deprecated, or nil when the slot holds no secret.
        #
        # RETIRE in 5.26.0 (POSITIONAL_PASSWORD_REMOVAL): once a command-line
        # secret is an error, the callers stop reading these slots and this
        # method goes away with its warning.
        #
        # Until then the slot keeps the meaning it has always had: whatever word
        # is there is the secret, option-shaped or not. The one exception is
        # --password-stdin, which is new, so no existing command changes meaning.
        # The warning never includes the secret.
        #
        # @param slot [String, nil] the word in the secret's position
        # @param name [String] the secret's name in the usage text
        # @param after [String, nil] what the slot follows, when the user may
        #   have meant the word there as another option
        # @param command [String] the command flag as typed
        # @param password_stdin [Boolean] true when --password-stdin was given
        # @param usage [String] usage text printed with an error
        # @return [String, nil] the secret, or nil if none was given
        def self.command_line_secret(slot, name:, command:, password_stdin:, usage:, after: nil)
          return nil if slot.nil? || slot == PASSWORD_STDIN_FLAG

          if password_stdin
            $stdout.puts 'error: Give the password either on the command line or with --password-stdin, not both'
            $stdout.puts usage
            exit 1
          end
          if slot.empty?
            $stdout.puts 'error: Password cannot be empty'
            $stdout.puts usage
            exit 1
          end

          # On $stdout like every other CLI message: lib/init.rb has already
          # pointed $stderr at the debug log, where the user would never see it.
          $stdout.puts "warning: Passing #{name} on the command line is deprecated: it is saved in your shell history " \
                       'and visible to other users in the process list.'
          $stdout.puts "warning: It will be an error starting with Lich #{POSITIONAL_PASSWORD_REMOVAL}. " \
                       "Leave #{name} off to be prompted for it, or pipe it in with --password-stdin."
          $stdout.puts "warning: The word after #{after} was read as #{name}. Put any other option before #{command}." if after
          slot
        end

        # Reads a secret for a command handler, exiting with the usage text
        # when it cannot be read.
        #
        # @param prompt [String] prompt shown on the terminal
        # @param from_stdin [Boolean] true when --password-stdin was given
        # @param usage [String] usage text printed with an error
        # @return [String] the secret
        def self.read_secret_or_exit(prompt, from_stdin:, usage:)
          Lich::Common::Authentication::CLIPassword.read_secret(prompt, from_stdin: from_stdin)
        rescue Lich::Common::Authentication::CLIPassword::SecretInputError => e
          $stdout.puts "error: #{e.message}"
          $stdout.puts usage
          exit 1
        end

        # Prompts on the terminal for a new secret and its confirmation. What
        # is typed is hidden, so a mistyped secret would otherwise be stored
        # unseen.
        #
        # @param prompt [String] prompt for the secret
        # @param confirm_prompt [String] prompt for the confirmation
        # @param usage [String] usage text printed with an error
        # @return [String] the confirmed secret
        def self.read_confirmed_secret_or_exit(prompt, confirm_prompt, usage:)
          secret = read_secret_or_exit(prompt, from_stdin: false, usage: usage)
          return secret if secret == read_secret_or_exit(confirm_prompt, from_stdin: false, usage: usage)

          $stdout.puts 'error: Passwords do not match'
          exit 1
        end

        # Flag that tells a command to read its password from stdin.
        PASSWORD_STDIN_FLAG = '--password-stdin'

        # Release in which a password given on the command line stops being
        # accepted. Named in the deprecation warnings.
        POSITIONAL_PASSWORD_REMOVAL = '5.26.0'

        def self.handle_add_account
          idx = ARGV.index { |a| a =~ /^--add-account$|^-aa$/ }
          account = ARGV[idx + 1]

          lich_script = File.join(LICH_DIR, 'lich.rbw')
          usage = "Usage: ruby #{lich_script} --add-account ACCOUNT [--password-stdin] [--frontend FRONTEND]\n" \
                  "   or: ruby #{lich_script} -aa ACCOUNT [--password-stdin] [--frontend FRONTEND]\n" \
                  'Prompts for the password; with --password-stdin, reads one line from stdin instead.'

          account = CliOptionValidator.require_positional(account, name: 'ACCOUNT', usage: usage)

          password_stdin = ARGV.include?(PASSWORD_STDIN_FLAG)
          positional_password = positional_add_account_password(ARGV, idx)
          if positional_password && password_stdin
            $stdout.puts 'error: Give the password either on the command line or with --password-stdin, not both'
            $stdout.puts usage
            exit 1
          end

          # Validated before the password is read and before the legacy conversion
          # below, so a malformed command exits without prompting or writing
          # entry.yaml. ACCOUNT, and PASSWORD when one was given, are left out of
          # the search so a password of literally '--frontend' isn't read as the flag.
          password_slots = positional_password ? 2 : 1
          frontend = CliOptionValidator.extract_flag_value(
            '--frontend',
            usage: usage,
            valid_values: Lich::Common::Authentication::LoginHelpers::VALID_FRONTENDS,
            argv: ARGV[0..idx] + ARGV.drop(idx + 1 + password_slots)
          )

          if positional_password
            # On $stdout like every other CLI message: lib/init.rb has already
            # pointed $stderr at the debug log, where the user would never see it.
            $stdout.puts 'warning: Passing PASSWORD on the command line is deprecated: it is saved in your shell history ' \
                         'and visible to other users in the process list.'
            $stdout.puts "warning: It will be an error starting with Lich #{POSITIONAL_PASSWORD_REMOVAL}. " \
                         'Leave PASSWORD off to be prompted for it, or pipe it in with --password-stdin.'
            password = positional_password
          else
            begin
              password = Lich::Common::Authentication::CLIPassword.read_secret('Password: ', from_stdin: password_stdin)
            rescue Lich::Common::Authentication::CLIPassword::SecretInputError => e
              $stdout.puts "error: #{e.message}"
              $stdout.puts usage
              exit 1
            end
          end

          # Check if YAML file exists; if not, check for DAT and auto-convert to plaintext
          yaml_file = Lich::Common::Authentication::EntryStore.yaml_file_path(DATA_DIR)
          unless File.exist?(yaml_file)
            if Lich::Common::CLI::CLIConversion.conversion_needed?(DATA_DIR)
              $stdout.puts ''
              $stdout.puts '=' * 80
              $stdout.puts 'WARNING: No YAML entry file found. Legacy entry.dat detected.'
              $stdout.puts 'Creating plaintext YAML file to support this operation.'
              $stdout.puts '=' * 80
              $stdout.puts ''
              $stdout.puts 'SECURITY NOTICE: Plaintext storage is not recommended except for'
              $stdout.puts 'accessibility requirements. Passwords will be stored in clear text.'
              $stdout.puts ''
              $stdout.puts 'To upgrade encryption later, use:'
              $stdout.puts "  ruby #{File.join(LICH_DIR, 'lich.rbw')} --change-encryption-mode enhanced"
              $stdout.puts '  or: -cem enhanced'
              $stdout.puts '=' * 80
              $stdout.puts ''

              # Perform plaintext conversion
              success = Lich::Common::CLI::CLIConversion.convert(DATA_DIR, :plaintext)
              unless success
                $stdout.puts 'error: Failed to create YAML file from legacy data.'
                exit 1
              end
              # Continue with add-account operation below
            end
            # No DAT file either - CLIPassword.add_account will create new YAML
          end

          exit Lich::Common::Authentication::CLIPassword.add_account(
            account, password, frontend, prompt_frontend: !password_stdin
          )
        end

        # Returns the PASSWORD given on the --add-account command line, or nil
        # when the user left it off.
        #
        # RETIRE in 5.26.0 (POSITIONAL_PASSWORD_REMOVAL): once a command-line
        # password is an error, ARGV[idx + 2] is never a password and this
        # method goes away with its ambiguity.
        #
        # Until then the slot after ACCOUNT is the password, with two exceptions.
        # --password-stdin is always the flag; it is new, so no existing
        # command changes meaning. --frontend is the flag when a value follows it
        # and no later --frontend exists; reading it as the password there would
        # leave that value unused. Every other command that parsed fully before
        # keeps its meaning: `-aa DOUG --frontend` and
        # `-aa DOUG --frontend --frontend wizard` still use '--frontend' as the
        # password.
        #
        # @param argv [Array<String>] the command line
        # @param idx [Integer] index of --add-account / -aa in +argv+
        # @return [String, nil] the positional password, or nil if none was given
        def self.positional_add_account_password(argv, idx)
          slot = argv[idx + 2]
          return nil if slot.nil? || slot == PASSWORD_STDIN_FLAG

          if slot == '--frontend'
            value = argv[idx + 3]
            return nil if value && !value.start_with?('-') && !argv.drop(idx + 3).include?('--frontend')
          end

          slot
        end

        def self.handle_refresh_characters
          idx = ARGV.index { |a| a =~ /^--refresh-characters$|^-rc$/ }
          account = ARGV[idx + 1]

          lich_script = File.join(LICH_DIR, 'lich.rbw')
          usage = "Usage: ruby #{lich_script} --refresh-characters ACCOUNT [--frontend FRONTEND]\n" \
                  "   or: ruby #{lich_script} -rc ACCOUNT [--frontend FRONTEND]"

          account = CliOptionValidator.require_positional(account, name: 'ACCOUNT', usage: usage)

          frontend = CliOptionValidator.extract_flag_value(
            '--frontend',
            usage: usage,
            valid_values: Lich::Common::Authentication::LoginHelpers::VALID_FRONTENDS
          )
          exit Lich::Common::Authentication::CLIPassword.refresh_characters(account, frontend)
        end

        def self.handle_add_character
          idx = ARGV.index { |a| a =~ /^--add-character$|^-ac$/ }
          account = ARGV[idx + 1]
          char_name = ARGV[idx + 2]

          lich_script = File.join(LICH_DIR, 'lich.rbw')
          usage = "Usage: ruby #{lich_script} --add-character ACCOUNT CHAR_NAME --game-code CODE [--frontend FRONTEND]\n" \
                  "   or: ruby #{lich_script} -ac ACCOUNT CHAR_NAME --game-code CODE [--frontend FRONTEND]"

          account = CliOptionValidator.require_positional(account, name: 'ACCOUNT', usage: usage)
          char_name = CliOptionValidator.require_positional(char_name, name: 'CHAR_NAME', usage: usage)

          game_code = CliOptionValidator.extract_flag_value('--game-code', usage: usage)
          if game_code.nil?
            $stdout.puts 'error: --game-code is required'
            $stdout.puts usage
            exit 1
          end

          unless Lich::Common::Authentication::LoginHelpers.valid_game_code?(game_code)
            CliOptionValidator.reject_invalid_value(
              '--game-code',
              game_code,
              valid_values: Lich::Common::Authentication::LoginHelpers::VALID_GAME_CODES,
              usage: usage
            )
          end

          frontend = CliOptionValidator.extract_flag_value(
            '--frontend',
            usage: usage,
            valid_values: Lich::Common::Authentication::LoginHelpers::VALID_FRONTENDS
          )

          exit Lich::Common::Authentication::CLIPassword.add_character(
            account,
            char_name,
            game_code: game_code,
            frontend: frontend
          )
        end

        def self.handle_change_master_password
          idx = ARGV.index { |a| a =~ /^--change-master-password$|^-cmp$/ }

          lich_script = File.join(LICH_DIR, 'lich.rbw')
          usage = "Usage: ruby #{lich_script} --change-master-password [--password-stdin]\n" \
                  "   or: ruby #{lich_script} -cmp [--password-stdin]\n" \
                  "Prompts for the current master password, then the new one.\n" \
                  'With --password-stdin, reads the current password from the first line of stdin and the new one from the second.'

          password_stdin = ARGV.include?(PASSWORD_STDIN_FLAG)
          old_password = command_line_secret(ARGV[idx + 1], name: 'OLDPASSWORD', after: ARGV[idx], command: ARGV[idx],
                                                            password_stdin: password_stdin, usage: usage)
          new_password = nil
          if old_password
            # NEWPASSWORD is only read behind an OLDPASSWORD; the warning above covers both.
            new_password = ARGV[idx + 2]
          elsif password_stdin
            old_password = read_secret_or_exit('', from_stdin: true, usage: usage)
            new_password = read_secret_or_exit('', from_stdin: true, usage: usage)
          else
            # The new password is prompted for once this one has been checked.
            old_password = read_secret_or_exit('Current master password: ', from_stdin: false, usage: usage)
          end

          exit Lich::Common::Authentication::CLIPassword.change_master_password(old_password, new_password)
        end

        def self.handle_recover_master_password
          idx = ARGV.index { |a| a =~ /^--recover-master-password$|^-rmp$/ }

          lich_script = File.join(LICH_DIR, 'lich.rbw')
          usage = "Usage: ruby #{lich_script} --recover-master-password [--password-stdin]\n" \
                  "   or: ruby #{lich_script} -rmp [--password-stdin]\n" \
                  'Prompts for the master password; with --password-stdin, reads one line from stdin instead.'

          password_stdin = ARGV.include?(PASSWORD_STDIN_FLAG)
          master_password = command_line_secret(ARGV[idx + 1], name: 'PASSWORD', after: ARGV[idx], command: ARGV[idx],
                                                               password_stdin: password_stdin, usage: usage)
          master_password ||= read_secret_or_exit('', from_stdin: true, usage: usage) if password_stdin

          # Left nil, recover_master_password prompts for it.
          exit Lich::Common::Authentication::CLIPassword.recover_master_password(master_password)
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
            require_relative '../gui/master_password_manager'
            master_password = if ARGV.include?(PASSWORD_STDIN_FLAG)
                                piped_new_master_password
                              else
                                Lich::Common::Authentication::CLIPassword.prompt_and_confirm_password('Enter new master password for enhanced encryption')
                              end
            if master_password.nil?
              puts 'error: Master password creation cancelled'
              exit 1
            end

            # Store password in keychain so ensure_master_password_exists finds it
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

        # Reads the new master password for --convert-entries enhanced from
        # stdin and applies the rule every new master password must pass.
        #
        # @return [String] the accepted password
        def self.piped_new_master_password
          lich_script = File.join(LICH_DIR, 'lich.rbw')
          usage = "Usage: ruby #{lich_script} --convert-entries enhanced [--password-stdin]\n" \
                  'Prompts for the new master password; with --password-stdin, reads one line from stdin instead.'
          password = read_secret_or_exit('', from_stdin: true, usage: usage)
          refusal = Lich::Common::GUI::MasterPasswordManager.new_password_refusal(password)
          return password unless refusal

          $stdout.puts "error: #{refusal}"
          exit 1
        end

        def self.handle_change_encryption_mode
          idx = ARGV.index { |a| a =~ /^--change-encryption-mode$|^-cem$/ }
          mode_arg = ARGV[idx + 1]

          lich_script = File.join(LICH_DIR, 'lich.rbw')
          usage = "Usage: ruby #{lich_script} --change-encryption-mode MODE [--password-stdin]\n" \
                  "       ruby #{lich_script} -cem MODE [--password-stdin]\n" \
                  "Modes: plaintext, standard, enhanced\n" \
                  'Prompts for the master password when the change needs one; with --password-stdin, reads it from stdin instead.'

          if mode_arg.nil?
            $stdout.puts 'error: Missing encryption mode'
            $stdout.puts usage
            exit 1
          end

          new_mode = mode_arg.to_sym

          # The deprecated way to supply the new master password for Enhanced mode.
          password_stdin = ARGV.include?(PASSWORD_STDIN_FLAG)
          mp_index = ARGV.index('--master-password') || ARGV.index('-mp')
          master_password = if mp_index
                              command_line_secret(ARGV[mp_index + 1], name: "#{ARGV[mp_index]} PASSWORD", command: ARGV[idx],
                                                                      password_stdin: password_stdin, usage: usage)
                            end

          exit Lich::Common::CLI::EncryptionModeChange.change_mode(new_mode, master_password, password_stdin: password_stdin)
        end

        # Standalone probe of the HTTPS web-login fallback path (see
        # docs/connection/web-login-protocol-analysis.md). Exercises
        # WebLogin.auth_with_timeout directly against play.net -- independent
        # of the real login path (Authenticator.authenticate), which also
        # uses WebLogin, either forced via --auth-provider=web or
        # automatically as a fallback when EAccess is unreachable.
        #
        # @return [void] exits the process; never returns normally
        def self.handle_web_login_test
          idx = ARGV.index('--web-login-test')
          account = ARGV[idx + 1]
          char_name = ARGV[idx + 2]

          lich_script = File.join(LICH_DIR, 'lich.rbw')
          usage = "Usage: ruby #{lich_script} --web-login-test ACCOUNT CHAR_NAME --game-code CODE\n" \
                  "Reads the account's password from data/entry.yaml (ACCOUNT must already be saved there).\n" \
                  'This is a standalone probe of the HTTPS web-login fallback path -- it does NOT ' \
                  'touch the normal EAccess login flow.'

          account = CliOptionValidator.require_positional(account, name: 'ACCOUNT', usage: usage)
          char_name = CliOptionValidator.require_positional(char_name, name: 'CHAR_NAME', usage: usage)

          game_code = CliOptionValidator.extract_flag_value(
            '--game-code',
            usage: usage,
            valid_values: Lich::Common::Authentication::LoginHelpers::VALID_GAME_CODES
          )
          if game_code.nil?
            $stdout.puts 'error: --game-code is required'
            $stdout.puts usage
            exit 1
          end

          entries = Lich::Common::Authentication::EntryStore.load_saved_entries(DATA_DIR, false)
          entry = entries.find { |e| e[:user_id].to_s.casecmp?(account) }
          if entry.nil?
            $stdout.puts "error: Account '#{account}' not found in #{Lich::Common::Authentication::EntryStore.yaml_file_path(DATA_DIR)}"
            exit 1
          end

          $stdout.puts "Probing web login fallback for #{account} / #{char_name} (#{game_code})..."

          begin
            login_info = Lich::Common::Authentication::WebLogin.auth_with_timeout(
              account: account,
              password: entry[:password],
              character: char_name,
              game_code: game_code
            )
            $stdout.puts 'Success:'
            # KEY is a live, usable one-time game-server credential -- printing
            # it would leave a real secret in terminal scrollback/log capture
            # for a probe that never consumes it. Only non-secret connection
            # metadata is shown.
            login_info.each { |k, v| $stdout.puts "  #{k.upcase}=#{k == 'key' ? '[scrubbed]' : v}" }
            exit 0
          rescue Lich::Common::Authentication::WebLogin::AuthenticationError => e
            $stdout.puts "error: web login failed: #{e.error_code}"
            exit 1
          rescue StandardError => e
            $stdout.puts "error: #{e.class}: #{e.message}"
            exit 1
          end
        end
      end
    end
  end
end
