# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Handles YAML-based state management for the Lich GUI login system
      # Provides a more maintainable alternative to the Marshal-based state system
      module YamlState
        # Loads saved entry data from YAML file
        # Reads and deserializes entry data from the entry.yml file, with fallback to entry.dat
        # Enhanced to support favorites functionality with backward compatibility
        #
        # @param data_dir [String] Directory containing entry data
        # @param autosort_state [Boolean] Whether to use auto-sorting
        # @return [Array] Array of saved login entries in the legacy format with favorites info
        def self.load_saved_entries(data_dir, autosort_state)
          # Guard against nil data_dir
          return [] if data_dir.nil?

          yaml_file = File.join(data_dir, "entry.yml")
          dat_file = File.join(data_dir, "entry.dat")

          if File.exist?(yaml_file)
            # Load from YAML format
            begin
              yaml_data = YAML.load_file(yaml_file)

              # Migrate data structure if needed to support favorites
              yaml_data = migrate_to_favorites_format(yaml_data)

              entries = convert_yaml_to_legacy_format(yaml_data)

              # Apply sorting with favorites priority if enabled
              sort_entries_with_favorites(entries, autosort_state)
            rescue StandardError => e
              Lich.log "error: Error loading YAML entry file: #{e.message}"
              []
            end
          elsif File.exist?(dat_file)
            # Fall back to legacy format if YAML doesn't exist
            Lich.log "info: YAML entry file not found, falling back to legacy format"
            State.load_saved_entries(data_dir, autosort_state)
          else
            # No entry file exists
            []
          end
        end

        # Saves entry data to YAML file
        # Converts and serializes entry data to the entry.yml file
        #
        # @param data_dir [String] Directory to save entry data
        # @param entry_data [Array] Array of entry data in legacy format
        # @return [Boolean] True if save was successful
        def self.save_entries(data_dir, entry_data)
          yaml_file = File.join(data_dir, "entry.yml")

          # Convert legacy format to YAML structure
          yaml_data = convert_legacy_to_yaml_format(entry_data)

          # Create backup of existing file if it exists
          if File.exist?(yaml_file)
            backup_file = "#{yaml_file}.bak"
            FileUtils.cp(yaml_file, backup_file)
          end

          # Write YAML data to file
          begin
            File.open(yaml_file, 'w') do |file|
              file.puts "# Lich 5 Login Entries - YAML Format"
              file.puts "# Generated: #{Time.now}"
              file.puts "# WARNING: Passwords are stored in plain text"
              file.write(YAML.dump(yaml_data))
            end

            true
          rescue StandardError => e
            Lich.log "error: Error saving YAML entry file: #{e.message}"
            false
          end
        end

        # Migrates from legacy Marshal format to YAML format
        # Converts entry.dat to entry.yml format for improved maintainability
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Boolean] True if migration was successful
        def self.migrate_from_legacy(data_dir)
          dat_file = File.join(data_dir, "entry.dat")
          yaml_file = File.join(data_dir, "entry.yml")

          # Skip if YAML file already exists or DAT file doesn't exist
          return false unless File.exist?(dat_file)
          return false if File.exist?(yaml_file)

          # Load legacy data
          legacy_entries = State.load_saved_entries(data_dir, false)

          # Save as YAML
          save_entries(data_dir, legacy_entries)
        rescue StandardError => e
          Lich.log "error: Error migrating to YAML format: #{e.message}"
          false
        end

        # Validates the YAML data structure
        # Ensures the YAML data conforms to the expected structure
        # Enhanced to support favorites fields in character records
        #
        # @param yaml_data [Hash] YAML data structure
        # @return [Boolean] True if structure is valid
        def self.validate_yaml_structure(yaml_data)
          return false unless yaml_data.is_a?(Hash)
          return false unless yaml_data.key?('accounts')
          return false unless yaml_data['accounts'].is_a?(Hash)

          yaml_data['accounts'].each do |_username, account_data|
            return false unless account_data.is_a?(Hash)
            return false unless account_data.key?('password')
            return false unless account_data.key?('characters')
            return false unless account_data['characters'].is_a?(Array)

            account_data['characters'].each do |character|
              return false unless character.is_a?(Hash)
              return false unless character.key?('char_name')
              return false unless character.key?('game_code')
              return false unless character.key?('game_name')
              return false unless character.key?('frontend')

              # Validate favorites fields if present (optional for backward compatibility)
              if character.key?('is_favorite')
                return false unless [true, false].include?(character['is_favorite'])
              end
              if character.key?('favorite_order')
                return false unless character['favorite_order'].is_a?(Integer)
              end
            end
          end

          true
        end

        # Adds a character to favorites
        # Marks the specified character as a favorite and assigns it an order
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @return [Boolean] True if operation was successful
        def self.add_favorite(data_dir, username, char_name, game_code)
          yaml_file = File.join(data_dir, "entry.yml")
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data = migrate_to_favorites_format(yaml_data)

            # Find the character
            character = find_character(yaml_data, username, char_name, game_code)
            return false unless character

            # Don't add if already a favorite
            return true if character['is_favorite']

            # Mark as favorite and assign order
            character['is_favorite'] = true
            character['favorite_order'] = get_next_favorite_order(yaml_data)
            character['favorite_added'] = Time.now.iso8601

            # Save updated data
            save_yaml_data(yaml_file, yaml_data)
          rescue StandardError => e
            Lich.log "error: Error adding favorite: #{e.message}"
            false
          end
        end

        # Removes a character from favorites
        # Unmarks the specified character as a favorite and reorders remaining favorites
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @return [Boolean] True if operation was successful
        def self.remove_favorite(data_dir, username, char_name, game_code)
          yaml_file = File.join(data_dir, "entry.yml")
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data = migrate_to_favorites_format(yaml_data)

            # Find the character
            character = find_character(yaml_data, username, char_name, game_code)
            return false unless character

            # Don't remove if not a favorite
            return true unless character['is_favorite']

            # Remove favorite status
            character['is_favorite'] = false
            character.delete('favorite_order')
            character.delete('favorite_added')

            # Reorder remaining favorites
            reorder_all_favorites(yaml_data)

            # Save updated data
            save_yaml_data(yaml_file, yaml_data)
          rescue StandardError => e
            Lich.log "error: Error removing favorite: #{e.message}"
            false
          end
        end

        # Reorders favorites based on provided character list
        # Updates the favorite_order field for all favorites based on new ordering
        #
        # @param data_dir [String] Directory containing entry data
        # @param ordered_favorites [Array] Array of hashes with username, char_name, game_code
        # @return [Boolean] True if operation was successful
        def self.reorder_favorites(data_dir, ordered_favorites)
          yaml_file = File.join(data_dir, "entry.yml")
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data = migrate_to_favorites_format(yaml_data)

            # Update favorite orders based on provided list
            ordered_favorites.each_with_index do |fav_info, index|
              character = find_character(yaml_data, fav_info[:username], fav_info[:char_name], fav_info[:game_code])
              next unless character && character['is_favorite']

              character['favorite_order'] = index + 1
            end

            # Save updated data
            save_yaml_data(yaml_file, yaml_data)
          rescue StandardError => e
            Lich.log "error: Error reordering favorites: #{e.message}"
            false
          end
        end

        # Gets all favorite characters across all accounts
        # Returns an array of favorite characters sorted by favorite_order
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Array] Array of favorite character data in legacy format
        def self.get_favorites(data_dir)
          yaml_file = File.join(data_dir, "entry.yml")
          return [] unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data = migrate_to_favorites_format(yaml_data)

            favorites = []
            yaml_data['accounts'].each do |username, account_data|
              password = account_data['password']

              account_data['characters'].each do |character|
                next unless character['is_favorite']

                favorites << {
                  char_name: character['char_name'],
                  game_code: character['game_code'],
                  game_name: character['game_name'],
                  user_id: username,
                  password: password,
                  frontend: character['frontend'],
                  custom_launch: character['custom_launch'],
                  custom_launch_dir: character['custom_launch_dir'],
                  is_favorite: true,
                  favorite_order: character['favorite_order'] || 999,
                  favorite_added: character['favorite_added']
                }
              end
            end

            # Sort by favorite order
            favorites.sort_by { |fav| fav[:favorite_order] }
          rescue StandardError => e
            Lich.log "error: Error getting favorites: #{e.message}"
            []
          end
        end

        # Checks if a character is marked as favorite
        # Returns true if the specified character is in the favorites list
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @return [Boolean] True if character is a favorite
        def self.is_favorite?(data_dir, username, char_name, game_code)
          yaml_file = File.join(data_dir, "entry.yml")
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data = migrate_to_favorites_format(yaml_data)

            character = find_character(yaml_data, username, char_name, game_code)
            character && character['is_favorite'] == true
          rescue StandardError => e
            Lich.log "error: Error checking favorite status: #{e.message}"
            false
          end
        end

        class << self
          private

          # Converts YAML format to legacy array of hashes format
          # Transforms the hierarchical YAML structure to the flat legacy format
          # Enhanced to include favorites information in legacy format
          #
          # @param yaml_data [Hash] YAML data structure
          # @return [Array] Array of entry data in legacy format with favorites info
          def convert_yaml_to_legacy_format(yaml_data)
            return [] unless validate_yaml_structure(yaml_data)

            legacy_entries = []

            yaml_data['accounts'].each do |username, account_data|
              password = account_data['password']

              account_data['characters'].each do |character|
                legacy_entries << {
                  char_name: character['char_name'],
                  game_code: character['game_code'],
                  game_name: character['game_name'],
                  user_id: username,
                  password: password,
                  frontend: character['frontend'],
                  custom_launch: character['custom_launch'],
                  custom_launch_dir: character['custom_launch_dir'],
                  is_favorite: character['is_favorite'] || false,
                  favorite_order: character['favorite_order'],
                  favorite_added: character['favorite_added']
                }
              end
            end

            legacy_entries
          end

          # Converts legacy array of hashes format to YAML structure
          # Transforms the flat legacy format to a hierarchical YAML structure
          # Enhanced to preserve favorites information in YAML format
          #
          # @param legacy_entries [Array] Array of entry data in legacy format
          # @return [Hash] YAML data structure with favorites support
          def convert_legacy_to_yaml_format(legacy_entries)
            yaml_data = { 'accounts' => {} }

            legacy_entries.each do |entry|
              username = entry[:user_id]

              # Initialize account if it doesn't exist
              unless yaml_data['accounts'].key?(username)
                yaml_data['accounts'][username] = {
                  'password'   => entry[:password],
                  'characters' => []
                }
              end

              # Build character hash with favorites support
              character_data = {
                'char_name'         => entry[:char_name],
                'game_code'         => entry[:game_code],
                'game_name'         => entry[:game_name],
                'frontend'          => entry[:frontend],
                'custom_launch'     => entry[:custom_launch],
                'custom_launch_dir' => entry[:custom_launch_dir]
              }

              # Add favorites fields if present
              if entry[:is_favorite]
                character_data['is_favorite'] = entry[:is_favorite]
                character_data['favorite_order'] = entry[:favorite_order] if entry[:favorite_order]
                character_data['favorite_added'] = entry[:favorite_added] if entry[:favorite_added]
              end

              # Add character to account
              yaml_data['accounts'][username]['characters'] << character_data
            end

            yaml_data
          end

          # Sorts entries based on autosort setting with favorites priority
          # Provides consistent sorting of entry data with favorites appearing first
          #
          # @param entries [Array] Array of entry data
          # @param autosort_state [Boolean] Whether to use auto-sorting
          # @return [Array] Sorted array of entry data with favorites first
          def sort_entries_with_favorites(entries, autosort_state)
            # Separate favorites and non-favorites
            favorites = entries.select { |entry| entry[:is_favorite] }
            non_favorites = entries.reject { |entry| entry[:is_favorite] }

            # Sort favorites by favorite_order
            favorites.sort_by! { |entry| entry[:favorite_order] || 999 }

            # Sort non-favorites using existing logic
            sorted_non_favorites = if autosort_state
                                     # Sort by game name, account name, and character name
                                     non_favorites.sort do |a, b|
                                       [a[:user_id], a[:game_name], a[:char_name]] <=> [b[:user_id], b[:game_name], b[:char_name]]
                                     end
                                   else
                                     # Sort by account name and character name (old Lich 4 style)
                                     non_favorites.sort do |a, b|
                                       [a[:user_id].downcase, a[:char_name]] <=> [b[:user_id].downcase, b[:char_name]]
                                     end
                                   end

            # Return favorites first, then non-favorites
            favorites + sorted_non_favorites
          end

          # Migrates YAML data to support favorites format
          # Adds favorites fields to existing character records if not present
          #
          # @param yaml_data [Hash] YAML data structure
          # @return [Hash] YAML data structure with favorites support
          def migrate_to_favorites_format(yaml_data)
            return yaml_data unless yaml_data.is_a?(Hash) && yaml_data['accounts']

            yaml_data['accounts'].each do |_username, account_data|
              next unless account_data['characters'].is_a?(Array)

              account_data['characters'].each do |character|
                # Add favorites fields if not present
                character['is_favorite'] ||= false
                # Don't add favorite_order or favorite_added unless character is actually a favorite
              end
            end

            yaml_data
          end

          # Finds a character in the YAML data structure
          # Locates a specific character by username, character name, and game code
          #
          # @param yaml_data [Hash] YAML data structure
          # @param username [String] Account username
          # @param char_name [String] Character name
          # @param game_code [String] Game code
          # @return [Hash, nil] Character hash if found, nil otherwise
          def find_character(yaml_data, username, char_name, game_code)
            return nil unless yaml_data['accounts'] && yaml_data['accounts'][username]

            account_data = yaml_data['accounts'][username]
            return nil unless account_data['characters']

            account_data['characters'].find do |character|
              character['char_name'] == char_name && character['game_code'] == game_code
            end
          end

          # Gets the next available favorite order number
          # Finds the highest current favorite order and returns the next number
          #
          # @param yaml_data [Hash] YAML data structure
          # @return [Integer] Next available favorite order number
          def get_next_favorite_order(yaml_data)
            max_order = 0

            yaml_data['accounts'].each do |_username, account_data|
              next unless account_data['characters']

              account_data['characters'].each do |character|
                if character['is_favorite'] && character['favorite_order']
                  max_order = [max_order, character['favorite_order']].max
                end
              end
            end

            max_order + 1
          end

          # Reorders all favorites to have consecutive order numbers
          # Ensures favorite_order values are consecutive starting from 1
          #
          # @param yaml_data [Hash] YAML data structure
          # @return [void]
          def reorder_all_favorites(yaml_data)
            # Collect all favorites
            all_favorites = []

            yaml_data['accounts'].each do |_username, account_data|
              next unless account_data['characters']

              account_data['characters'].each do |character|
                if character['is_favorite']
                  all_favorites << character
                end
              end
            end

            # Sort by current order and reassign consecutive numbers
            all_favorites.sort_by! { |char| char['favorite_order'] || 999 }
            all_favorites.each_with_index do |character, index|
              character['favorite_order'] = index + 1
            end
          end

          # Saves YAML data to file with backup
          # Writes YAML data to file with proper formatting and backup creation
          #
          # @param yaml_file [String] Path to YAML file
          # @param yaml_data [Hash] YAML data structure
          # @return [Boolean] True if save was successful
          def save_yaml_data(yaml_file, yaml_data)
            # Create backup of existing file if it exists
            if File.exist?(yaml_file)
              backup_file = "#{yaml_file}.bak"
              FileUtils.cp(yaml_file, backup_file)
            end

            # Write YAML data to file
            File.open(yaml_file, 'w') do |file|
              file.puts "# Lich 5 Login Entries - YAML Format with Favorites Support"
              file.puts "# Generated: #{Time.now}"
              file.puts "# WARNING: Passwords are stored in plain text"
              file.write(YAML.dump(yaml_data))
            end

            true
          end

          # Legacy method maintained for backward compatibility
          # Sorts entries based on autosort setting (original implementation)
          #
          # @param entries [Array] Array of entry data
          # @param autosort_state [Boolean] Whether to use auto-sorting
          # @return [Array] Sorted array of entry data
          def sort_entries(entries, autosort_state)
            if autosort_state
              # Sort by game name, account name, and character name
              entries.sort do |a, b|
                [a[:user_id], a[:game_name], a[:char_name]] <=> [b[:user_id], b[:game_name], b[:char_name]]
              end
            else
              # Sort by account name and character name (old Lich 4 style)
              entries.sort do |a, b|
                [a[:user_id].downcase, a[:char_name]] <=> [b[:user_id].downcase, b[:char_name]]
              end
            end
          end
        end
      end
    end
  end
end
