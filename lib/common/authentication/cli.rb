# frozen_string_literal: true

require_relative 'entry_store'
require_relative 'authenticator'
require_relative 'launch_data'
require_relative 'login_helpers'
require_relative 'cli_password'

module Lich
  module Common
    module Authentication
      # CLI login handler for character authentication
      #
      # Handles the CLI login flow: load saved entries, find character,
      # decrypt password, and authenticate with game server.
      module CLI
        # Executes CLI login flow for a specified character
        #
        # @param character_name [String] Character name to login with
        # @param game_code [String, nil] Game code/instance (GS3, GS4, DR, etc.)
        # @param frontend [String, nil] Frontend type (stormfront, avalon, wizard)
        # @param custom_launch [String, nil] Custom launch filter (if provided, frontend is ignored for matching)
        # @param data_dir [String] Directory containing saved login entries
        # @return [Array<String>, nil] Launch data strings if successful, nil if login fails
        #
        # @example
        #   launch_data = CLI.execute('MyCharacter', game_code: 'GS3', frontend: 'stormfront', data_dir: '/path/to/data')
        #   # => ["GAME=GS3", "GAMEHOST=eaccess.play.net", ...]
        def self.execute(character_name, game_code: nil, frontend: nil, custom_launch: nil, data_dir: nil)
          data_dir ||= DATA_DIR

          # Validate inputs
          unless character_name && !character_name.empty?
            Lich.log "error: Character name is required"
            return nil
          end

          entry_data = load_entry_data(data_dir)
          return nil unless entry_data

          # Find matching character(s) using login_helpers
          matching_entries = LoginHelpers.find_character_by_name_game_and_frontend(
            entry_data,
            character_name,
            game_code,
            frontend,
            custom_launch
          )

          if matching_entries.nil? || matching_entries.empty?
            Lich.log "error: No matching character found for: #{character_name}"
            return nil
          end

          # Select best match from candidates
          char_entry = LoginHelpers.select_best_fit(
            char_data_sets: matching_entries,
            requested_character: character_name,
            requested_instance: game_code,
            requested_fe: frontend
          )

          unless char_entry
            Lich.log "error: Could not select character entry from matches"
            return nil
          end

          # Decrypt password and authenticate
          decrypt_and_authenticate(char_entry, entry_data)
        end

        # Executes CLI login flow to enter the character generator on an existing account.
        #
        # Looks up the account by name in saved entries, decrypts its password,
        # and authenticates with character name "NEW" to reach the character
        # creation flow on the game server.
        #
        # @param account_name [String] account name as stored in entry.yaml
        # @param game_code [String, nil] game instance code (e.g. "DR", "GS3")
        # @param frontend [String, Symbol, nil] requested frontend for the launched session
        #   (nil or the :__unset sentinel default to 'profanity')
        # @param custom_launch [String, Symbol, nil] custom launch command (the :__unset sentinel is treated as none)
        # @param custom_launch_dir [String, Symbol, nil] custom launch directory (the :__unset sentinel is treated as none)
        # @param data_dir [String, nil] directory containing saved login entries
        # @return [Array<String>, nil] launch data strings if successful, nil on failure
        #
        # @example
        #   launch_data = CLI.execute_new_character('MYACCOUNT', game_code: 'DR', data_dir: '/path/to/data')
        def self.execute_new_character(account_name, game_code: nil, frontend: nil, custom_launch: nil, custom_launch_dir: nil, data_dir: nil)
          data_dir ||= DATA_DIR

          unless account_name && !account_name.empty?
            Lich.log "error: Account name is required for new character creation"
            return nil
          end

          unless game_code && LoginHelpers::VALID_GAME_CODES.include?(game_code.to_s)
            Lich.log "error: A valid game code is required for new character creation (e.g. --dr, --gemstone). Got: #{game_code.inspect}"
            return nil
          end

          entry_data = load_entry_data(data_dir)
          return nil unless entry_data

          canonical_name, account_data = find_account(entry_data, account_name)
          return nil unless account_data

          char_entry = {
            username: canonical_name,
            password: account_data[:password],
            char_name: 'NEW',
            game_code: game_code,
            frontend: unset_login_value?(frontend) ? 'profanity' : frontend,
            custom_launch: unset_login_value?(custom_launch) ? nil : custom_launch,
            custom_launch_dir: unset_login_value?(custom_launch_dir) ? nil : custom_launch_dir,
            generator: true,
          }

          decrypt_and_authenticate(char_entry, entry_data)
        end

        # Treats nil and the :__unset CLI sentinel as "value not provided".
        #
        # @param value [Object] a parsed CLI login value
        # @return [Boolean] true when the value should be treated as absent
        # @api private
        def self.unset_login_value?(value)
          value.nil? || value == :__unset
        end

        # Loads and parses entry.yaml from the given data directory.
        #
        # @param data_dir [String] directory containing entry.yaml
        # @return [Hash, nil] symbolized entry data, or nil on failure
        # @api private
        def self.load_entry_data(data_dir)
          unless CLIPassword.validate_master_password_available(data_dir: data_dir)
            Lich.log "error: Master password validation failed during CLI login"
            return nil
          end

          yaml_file = EntryStore.yaml_file_path(data_dir)
          unless File.exist?(yaml_file)
            Lich.log "error: No saved entries YAML file found"
            return nil
          end

          yaml_data = YAML.safe_load_file(yaml_file, permitted_classes: [Symbol])
          LoginHelpers.symbolize_keys(yaml_data)
        rescue StandardError => e
          Lich.log "error: Failed to load YAML data: #{e.message}"
          nil
        end

        # Finds an account by name in the entry data (case-insensitive).
        #
        # Returns the stored canonical account key alongside the account data so
        # callers authenticate with the canonical identifier rather than the
        # caller-supplied casing.
        #
        # @param entry_data [Hash] symbolized entry data with :accounts key
        # @param account_name [String] account name to search for
        # @return [Array(String, Hash), nil] [canonical account name, account data], or nil if not found
        # @api private
        def self.find_account(entry_data, account_name)
          # New character creation requires the accounts-based YAML format. Legacy
          # array-format entries have no account container to look up by name.
          unless entry_data.is_a?(Hash)
            Lich.log "error: New character creation requires the accounts-based entry format"
            return nil
          end

          accounts = entry_data[:accounts]
          unless accounts.is_a?(Hash)
            Lich.log "error: No accounts found in saved entries"
            return nil
          end

          canonical_name, account_data = accounts.find { |key, _v| key.to_s.casecmp?(account_name) }
          unless account_data
            Lich.log "error: Account not found: #{account_name}"
            return nil
          end

          unless account_data[:password]
            Lich.log "error: No password saved for account: #{account_name}"
            return nil
          end

          [canonical_name.to_s, account_data]
        end

        # Decrypts the password from a character entry and authenticates with the game server.
        #
        # @param char_entry [Hash] character entry with :username, :password, :char_name, :game_code, :frontend keys
        #   and an optional :generator flag for character-generator entry
        # @param entry_data [Hash] full entry data (needed for encryption mode)
        # @return [Array<String>, nil] launch data strings if successful, nil on failure
        def self.decrypt_and_authenticate(char_entry, entry_data)
          # Get encryption mode from YAML
          encryption_mode = (entry_data[:encryption_mode] || 'plaintext').to_sym

          # Decrypt the password
          begin
            plaintext_password = EntryStore.decrypt_password(
              char_entry[:password],
              mode: encryption_mode,
              account_name: char_entry[:username]
            )
          rescue StandardError => e
            Lich.log "error: Failed to decrypt password: #{e.message}"
            return nil
          end

          unless plaintext_password
            Lich.log "error: No password available for character"
            return nil
          end

          # Authenticate with game server
          begin
            auth_data = Authentication.authenticate(
              account: char_entry[:username],
              password: plaintext_password,
              character: char_entry[:char_name],
              game_code: char_entry[:game_code],
              generator: char_entry[:generator] || false
            )

            # Format and return launch data
            LaunchData.prepare(
              auth_data,
              char_entry[:frontend],
              char_entry[:custom_launch],
              char_entry[:custom_launch_dir]
            )
          rescue StandardError => e
            Lich.log "error: Authentication failed: #{e.message}"
            return nil
          end
        end
      end
    end
  end
end
