# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Manages account-related operations for the Lich GUI login system
      # Provides functionality for adding, removing, and modifying accounts and characters
      module AccountManager
        # Adds a new account or updates an existing one
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param password [String] Account password
        # @return [Boolean] True if operation was successful
        def self.add_or_update_account(data_dir, username, password)
          yaml_file = File.join(data_dir, "entry.yml")

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

          # Add or update account
          if yaml_data['accounts'][username]
            # Update existing account password
            yaml_data['accounts'][username]['password'] = password
          else
            # Create new account
            yaml_data['accounts'][username] = {
              'password'   => password,
              'characters' => []
            }
          end

          # Save updated data
          Utilities.safe_file_operation(yaml_file, :write, YAML.dump(yaml_data))
        end

        # Removes an account and all associated characters
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

            # Check if account exists
            return false unless yaml_data['accounts'] && yaml_data['accounts'][username]

            # Remove account
            yaml_data['accounts'].delete(username)

            # Save updated data
            Utilities.safe_file_operation(yaml_file, :write, YAML.dump(yaml_data))
          rescue StandardError => e
            Lich.log "error: Error removing account: #{e.message}"
            false
          end
        end

        # Changes the password for an account
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param new_password [String] New password for the account
        # @return [Boolean] True if operation was successful
        def self.change_password(data_dir, username, new_password)
          add_or_update_account(data_dir, username, new_password)
        end

        # Adds a character to an account
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param character_data [Hash] Character data (char_name, game_code, game_name, frontend, etc.)
        # @return [Boolean] True if operation was successful
        def self.add_character(data_dir, username, character_data)
          yaml_file = File.join(data_dir, "entry.yml")

          # Load existing data
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)

            # Check if account exists
            return false unless yaml_data['accounts'] && yaml_data['accounts'][username]

            # Initialize characters array if not present
            yaml_data['accounts'][username]['characters'] ||= []

            # Add character data
            yaml_data['accounts'][username]['characters'] << {
              'char_name'         => character_data[:char_name],
              'game_code'         => character_data[:game_code],
              'game_name'         => character_data[:game_name],
              'frontend'          => character_data[:frontend],
              'custom_launch'     => character_data[:custom_launch],
              'custom_launch_dir' => character_data[:custom_launch_dir]
            }

            # Save updated data
            Utilities.safe_file_operation(yaml_file, :write, YAML.dump(yaml_data))
          rescue StandardError => e
            Lich.log "error: Error adding character: #{e.message}"
            false
          end
        end

        # Removes a character from an account
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @return [Boolean] True if operation was successful
        def self.remove_character(data_dir, username, char_name, game_code)
          yaml_file = File.join(data_dir, "entry.yml")

          # Load existing data
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)

            # Check if account exists
            return false unless yaml_data['accounts'] &&
                                yaml_data['accounts'][username] &&
                                yaml_data['accounts'][username]['characters']

            # Find and remove character
            characters = yaml_data['accounts'][username]['characters']
            initial_count = characters.size

            characters.reject! do |char|
              char['char_name'] == char_name && char['game_code'] == game_code
            end

            # Check if any characters were removed
            return false if characters.size == initial_count

            # Save updated data
            Utilities.safe_file_operation(yaml_file, :write, YAML.dump(yaml_data))
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

            # Save updated data
            Utilities.safe_file_operation(yaml_file, :write, YAML.dump(yaml_data))
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
                  frontend: char['frontend']
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

            # Check if account exists
            return [] unless yaml_data['accounts'] &&
                             yaml_data['accounts'][username] &&
                             yaml_data['accounts'][username]['characters']

            # Return characters with symbolized keys
            yaml_data['accounts'][username]['characters'].map do |char|
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
