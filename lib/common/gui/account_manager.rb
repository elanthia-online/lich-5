# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Manages account-related operations for the Lich GUI login system
      # Provides functionality for adding, removing, and modifying accounts and characters
      module AccountManager
        # Adds or updates an account with password and optional characters
        # Normalizes account and character names for consistent storage
        # When updating existing accounts, merges characters to preserve existing metadata (favorites, etc.)
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username (will be normalized to UPCASE)
        # @param password [String] Account password
        # @param characters [Array<Hash>] Optional array of character data hashes (will be normalized to Title case)
        #   Character hash format: { char_name:, game_code:, game_name:, frontend:, custom_launch:, custom_launch_dir: }
        # @return [Boolean] True if operation was successful
        #
        # @note For existing accounts:
        #   - Password is always updated
        #   - Characters are merged (existing preserved, new ones added if not duplicates)
        #   - Existing character metadata (favorites, custom settings) is preserved
        #   - Duplicate detection uses normalized char_name + game_code + frontend
        # @note For new accounts:
        #   - Account created with normalized username (UPCASE)
        #   - Characters added with normalized names (Title case)
        def self.add_or_update_account(data_dir, username, password, characters = [])
          yaml_file = File.join(data_dir, "entry.yml")

          # Normalize username to UPCASE for consistent storage
          normalized_username = username.to_s.upcase

          # Load existing data or create new structure
          yaml_data = if File.exist?(yaml_file)
                        begin
                          YAML.load_file(yaml_file)
                        rescue StandardError => e
                          Lich.log "error: Error loading YAML entry file: #{e.message}"
                          { 'accounts' => {} }
                        end
                      else
                        { 'accounts' => {} }
                      end

          # Initialize accounts hash if not present
          yaml_data['accounts'] ||= {}

          # Normalize character data if provided
          normalized_characters = characters.map do |char|
            {
              'char_name'         => char[:char_name].to_s.capitalize,
              'game_code'         => char[:game_code],
              'game_name'         => char[:game_name],
              'frontend'          => char[:frontend],
              'custom_launch'     => char[:custom_launch],
              'custom_launch_dir' => char[:custom_launch_dir]
            }
          end

          # Add or update account using normalized username
          if yaml_data['accounts'][normalized_username]
            # Update existing account password
            yaml_data['accounts'][normalized_username]['password'] = password

            # Merge characters: preserve existing characters and their metadata (like favorites)
            # while adding any new characters from the provided list
            if !characters.empty?
              existing_characters = yaml_data['accounts'][normalized_username]['characters'] || []

              # Add new characters that don't already exist
              characters.each do |new_char|
                normalized_new_char_name = new_char[:char_name].to_s.capitalize

                # Check if character already exists (by char_name, game_code, frontend)
                existing_char = existing_characters.find do |existing|
                  existing['char_name'] == normalized_new_char_name &&
                    existing['game_code'] == new_char[:game_code] &&
                    existing['frontend'] == new_char[:frontend]
                end

                # Only add if character doesn't already exist
                unless existing_char
                  existing_characters << {
                    'char_name'         => normalized_new_char_name,
                    'game_code'         => new_char[:game_code],
                    'game_name'         => new_char[:game_name],
                    'frontend'          => new_char[:frontend],
                    'custom_launch'     => new_char[:custom_launch],
                    'custom_launch_dir' => new_char[:custom_launch_dir]
                  }
                end
              end

              yaml_data['accounts'][normalized_username]['characters'] = existing_characters
            end
          else
            # Create new account with normalized data
            yaml_data['accounts'][normalized_username] = {
              'password'   => password,
              'characters' => normalized_characters
            }
          end

          # Save updated data with verification
          Utilities.verified_file_operation(yaml_file, :write, YAML.dump(yaml_data))
        end

        # Removes an account and all associated characters
        # Uses normalized account name for consistent lookup
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username to remove
        # @return [Boolean] True if operation was successful
        def self.remove_account(data_dir, username)
          yaml_file = File.join(data_dir, "entry.yml")

          # Load existing data
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)

            # Normalize username to UPCASE for consistent lookup
            normalized_username = username.to_s.upcase

            # Check if account exists
            return false unless yaml_data['accounts'] && yaml_data['accounts'][normalized_username]

            # Remove account
            yaml_data['accounts'].delete(normalized_username)

            # Save updated data with verification
            Utilities.verified_file_operation(yaml_file, :write, YAML.dump(yaml_data))
          rescue StandardError => e
            Lich.log "error: Error removing account: #{e.message}"
            false
          end
        end

        # Changes the password for an account
        # Updates the password for the specified account using normalized account name
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param new_password [String] New password for the account
        # @return [Boolean] True if operation was successful
        def self.change_password(data_dir, username, new_password)
          # Normalize username to UPCASE for consistent storage
          normalized_username = username.to_s.upcase
          add_or_update_account(data_dir, normalized_username, new_password)
        end

        # Adds a character to an account
        # Normalizes account and character names for consistent storage
        # Prevents duplicate characters using normalized comparison
        # Returns detailed result information for user-friendly error messages
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param character_data [Hash] Character data (char_name, game_code, game_name, frontend, etc.)
        # @return [Hash] Result hash with :success (Boolean) and :message (String) keys
        #   Success: { success: true, message: "Character added successfully" }
        #   Failure: { success: false, message: "Specific reason for failure" }
        def self.add_character(data_dir, username, character_data)
          yaml_file = File.join(data_dir, "entry.yml")

          # Check if YAML file exists
          unless File.exist?(yaml_file)
            return { success: false, message: "No account data file found. Please add an account first." }
          end

          begin
            yaml_data = YAML.load_file(yaml_file)

            # Normalize username to UPCASE for consistent lookup
            normalized_username = username.to_s.upcase
            normalized_char_name = character_data[:char_name].to_s.capitalize

            # Check if account exists
            unless yaml_data['accounts'] && yaml_data['accounts'][normalized_username]
              return { success: false, message: "Account '#{username}' not found. Please add the account first." }
            end

            # Initialize characters array if not present
            yaml_data['accounts'][normalized_username]['characters'] ||= []

            # Check for duplicate character using normalized comparison
            existing_character = yaml_data['accounts'][normalized_username]['characters'].find do |char|
              char['char_name'] == normalized_char_name &&
                char['game_code'] == character_data[:game_code] &&
                char['frontend'] == character_data[:frontend]
            end

            # Return specific message if character already exists
            if existing_character
              return {
                success: false,
                message: "Character '#{normalized_char_name}' already exists for #{character_data[:game_code]} (#{character_data[:frontend]}). Duplicates are not allowed."
              }
            end

            # Add character data with normalized character name
            yaml_data['accounts'][normalized_username]['characters'] << {
              'char_name'         => normalized_char_name,
              'game_code'         => character_data[:game_code],
              'game_name'         => character_data[:game_name],
              'frontend'          => character_data[:frontend],
              'custom_launch'     => character_data[:custom_launch],
              'custom_launch_dir' => character_data[:custom_launch_dir]
            }

            # Save updated data with verification
            if Utilities.verified_file_operation(yaml_file, :write, YAML.dump(yaml_data))
              return { success: true, message: "Character '#{normalized_char_name}' added successfully." }
            else
              return { success: false, message: "Failed to save character data. Please check file permissions." }
            end
          rescue StandardError => e
            Lich.log "error: Error adding character: #{e.message}"
            return { success: false, message: "Error adding character: #{e.message}" }
          end
        end

        # Removes a character from an account with frontend precision
        # Uses normalized account and character names for consistent lookup
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param frontend [String] Frontend identifier (optional for backward compatibility)
        # @return [Boolean] True if operation was successful
        def self.remove_character(data_dir, username, char_name, game_code, frontend = nil)
          yaml_file = File.join(data_dir, "entry.yml")

          # Load existing data
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)

            # Normalize username and character name for consistent lookup
            normalized_username = username.to_s.upcase
            normalized_char_name = char_name.to_s.capitalize

            # Check if account exists
            return false unless yaml_data['accounts'] &&
                                yaml_data['accounts'][normalized_username] &&
                                yaml_data['accounts'][normalized_username]['characters']

            # Find and remove character with frontend precision
            characters = yaml_data['accounts'][normalized_username]['characters']
            initial_count = characters.size

            characters.reject! do |char|
              matches_basic = char['char_name'] == normalized_char_name && char['game_code'] == game_code

              if frontend.nil?
                # Backward compatibility: if no frontend specified, match any frontend
                matches_basic
              else
                # Frontend precision: must match exact frontend
                matches_basic && char['frontend'] == frontend
              end
            end

            # Check if any characters were removed
            return false if characters.size == initial_count

            # Save updated data with verification
            Utilities.verified_file_operation(yaml_file, :write, YAML.dump(yaml_data))
          rescue StandardError => e
            Lich.log "error: Error removing character: #{e.message}"
            false
          end
        end

        # Updates a character's properties
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param updates [Hash] Properties to update
        # @return [Boolean] True if operation was successful
        def self.update_character(data_dir, username, char_name, game_code, updates)
          yaml_file = File.join(data_dir, "entry.yml")

          # Load existing data
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)

            # Check if account exists
            return false unless yaml_data['accounts'] &&
                                yaml_data['accounts'][username] &&
                                yaml_data['accounts'][username]['characters']

            # Find and update character
            characters = yaml_data['accounts'][username]['characters']
            character = characters.find { |char| char['char_name'] == char_name && char['game_code'] == game_code }

            return false unless character

            # Update properties
            updates.each do |key, value|
              character[key.to_s] = value
            end

            # Save updated data with verification
            Utilities.verified_file_operation(yaml_file, :write, YAML.dump(yaml_data))
          rescue StandardError => e
            Lich.log "error: Error updating character: #{e.message}"
            false
          end
        end

        # Gets all accounts
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Array] Array of account usernames
        def self.get_accounts(data_dir)
          yaml_file = File.join(data_dir, "entry.yml")

          # Load existing data
          return [] unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data['accounts']&.keys || []
          rescue StandardError => e
            Lich.log "error: Error getting accounts: #{e.message}"
            []
          end
        end

        # Gets all accounts with their characters
        # This method is used by AccountManagerUI.populate_accounts_view
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Hash] Hash of accounts with their characters
        def self.get_all_accounts(data_dir)
          yaml_file = File.join(data_dir, "entry.yml")

          # Load existing data
          return {} unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            return {} unless yaml_data['accounts']

            # Build accounts hash with characters
            accounts = {}
            yaml_data['accounts'].each do |username, account_data|
              accounts[username] = account_data['characters']&.map do |char|
                {
                  char_name: char['char_name'],
                  game_code: char['game_code'],
                  game_name: char['game_name'],
                  frontend: char['frontend'],
                  custom_launch: char['custom_launch'],
                  custom_launch_dir: char['custom_launch_dir']
                }
              end || []
            end

            accounts
          rescue StandardError => e
            Lich.log "error: Error getting all accounts: #{e.message}"
            {}
          end
        end

        # Gets all characters for an account
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @return [Array] Array of character data hashes
        def self.get_characters(data_dir, username)
          yaml_file = File.join(data_dir, "entry.yml")

          # Load existing data
          return [] unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)

            # Normalize username to UPCASE for consistent lookup
            normalized_username = username.to_s.upcase

            # Check if account exists
            return [] unless yaml_data['accounts'] &&
                             yaml_data['accounts'][normalized_username] &&
                             yaml_data['accounts'][normalized_username]['characters']

            # Return characters with symbolized keys
            yaml_data['accounts'][normalized_username]['characters'].map do |char|
              char.transform_keys(&:to_sym)
            end
          rescue StandardError => e
            Lich.log "error: Error getting characters: #{e.message}"
            []
          end
        end

        # Converts the YAML data to legacy format for compatibility
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Array] Array of entry data in legacy format
        def self.to_legacy_format(data_dir)
          yaml_file = File.join(data_dir, "entry.yml")

          # Load existing data
          return [] unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            YamlState.convert_yaml_to_legacy_format(yaml_data)
          rescue StandardError => e
            Lich.log "error: Error converting to legacy format: #{e.message}"
            []
          end
        end
      end
    end
  end
end
