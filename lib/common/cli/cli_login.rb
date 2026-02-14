# frozen_string_literal: true

require_relative '../gui/yaml_state'
require_relative '../gui/authentication'
require_relative '../../util/login_helpers'
require_relative 'cli_password_manager'

module Lich
  module Common
    module CLI
      # CLI login handler for character authentication
      #
      # Handles the CLI login flow: load saved entries, find character,
      # decrypt password, and authenticate with game server.
      # Reuses GUI infrastructure (YamlState, Authentication, LoginHelpers)
      # to ensure consistent password decryption and authentication logic.
      module CLILogin
        # Retry configuration for transient SSL/network errors
        # These errors are often temporary and resolve on retry:
        # - SSL_read: unexpected eof while reading (server closed connection)
        # - Connection reset by peer
        # - Connection timed out
        MAX_AUTH_RETRIES = 3
        AUTH_RETRY_BASE_DELAY = 5 # seconds, doubles each retry: 5s, 10s, 20s
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
        #   launch_data = CLILogin.execute('MyCharacter', 'GS3', 'stormfront', '/path/to/data')
        #   # => ["GAME=GS3", "GAMEHOST=eaccess.play.net", ...]
        def self.execute(character_name, game_code: nil, frontend: nil, custom_launch: nil, data_dir: nil)
          data_dir ||= DATA_DIR

          # Validate inputs
          unless character_name && !character_name.empty?
            Lich.log "error: Character name is required"
            return nil
          end

          # Validate master password availability before attempting login (required for Enhanced encryption mode)
          unless PasswordManager.validate_master_password_available
            Lich.log "error: Master password validation failed during CLI login"
            return nil
          end

          # Load raw YAML data (not decrypted yet)
          yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)
          unless File.exist?(yaml_file)
            Lich.log "error: No saved entries YAML file found"
            return nil
          end

          begin
            yaml_data = YAML.load_file(yaml_file)
            entry_data = Lich::Util::LoginHelpers.symbolize_keys(yaml_data)
          rescue StandardError => e
            Lich.log "error: Failed to load YAML data: #{e.message}"
            return nil
          end

          # Find matching character(s) using login_helpers
          matching_entries = Lich::Util::LoginHelpers.find_character_by_name_game_and_frontend(
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
          char_entry = Lich::Util::LoginHelpers.select_best_fit(
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

        def self.decrypt_and_authenticate(char_entry, entry_data)
          # Get encryption mode from YAML
          encryption_mode = (entry_data[:encryption_mode] || 'plaintext').to_sym

          # Decrypt the password
          begin
            plaintext_password = Lich::Common::GUI::YamlState.decrypt_password(
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

          # Authenticate with game server (with retry for transient errors)
          authenticate_with_retry(char_entry, plaintext_password)
        end

        # Authenticates with retry logic for transient SSL/network errors
        #
        # @param char_entry [Hash] Character entry data
        # @param plaintext_password [String] Decrypted password
        # @return [Array<String>, nil] Launch data if successful, nil on failure
        def self.authenticate_with_retry(char_entry, plaintext_password)
          last_error = nil

          MAX_AUTH_RETRIES.times do |attempt|
            begin
              launch_data_hash = Lich::Common::GUI::Authentication.authenticate(
                account: char_entry[:username],
                password: plaintext_password,
                character: char_entry[:char_name],
                game_code: char_entry[:game_code]
              )

              # Success - log if this was a retry
              if attempt.positive?
                Lich.log "info: Authentication succeeded on attempt #{attempt + 1}"
              end

              return format_launch_data(launch_data_hash, char_entry)
            rescue StandardError => e
              last_error = e

              if attempt < MAX_AUTH_RETRIES - 1
                delay = AUTH_RETRY_BASE_DELAY * (2**attempt)
                Lich.log "warn: Authentication attempt #{attempt + 1}/#{MAX_AUTH_RETRIES} failed: " \
                         "#{e.message}, retrying in #{delay}s..."
                sleep(delay)
              end
            end
          end

          # All retries exhausted
          Lich.log "error: Authentication failed after #{MAX_AUTH_RETRIES} attempts: #{last_error&.message}"
          nil
        end

        def self.format_launch_data(launch_data_hash, char_entry)
          launch_data = launch_data_hash.map { |k, v| "#{k.upcase}=#{v}" }

          # Apply frontend-specific modifications
          frontend = char_entry[:frontend]
          if frontend == 'wizard'
            launch_data.collect! do |line|
              line.sub(/GAMEFILE=.+/, 'GAMEFILE=WIZARD.EXE')
                  .sub(/GAME=.+/, 'GAME=WIZ')
                  .sub(/FULLGAMENAME=.+/, 'FULLGAMENAME=Wizard Front End')
            end
          elsif frontend == 'avalon'
            launch_data.collect! { |line| line.sub(/GAME=.+/, 'GAME=AVALON') }
          end

          # Add custom launch parameters if present
          if char_entry[:custom_launch]
            launch_data.push "CUSTOMLAUNCH=#{char_entry[:custom_launch]}"
            if char_entry[:custom_launch_dir]
              launch_data.push "CUSTOMLAUNCHDIR=#{char_entry[:custom_launch_dir]}"
            end
          end

          launch_data
        end
      end
    end
  end
end
