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
        end

        # Adds a character to the favorites list
        # Marks the specified character as a favorite with proper ordering
        # Optimized to preserve account ordering in YAML structure
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param frontend [String] Frontend identifier (optional for backward compatibility)
        # @return [Boolean] True if operation was successful
        def self.add_favorite(data_dir, username, char_name, game_code, frontend = nil)
          yaml_file = File.join(data_dir, "entry.yml")
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data = migrate_to_favorites_format(yaml_data)

            # Find the character with frontend precision
            character = find_character(yaml_data, username, char_name, game_code, frontend)
            return false unless character

            # Don't add if already a favorite
            return true if character['is_favorite']

            # Mark as favorite and assign order
            character['is_favorite'] = true
            character['favorite_order'] = get_next_favorite_order(yaml_data)
            character['favorite_added'] = Time.now.to_s

            # Save updated data directly without conversion round-trip
            # This preserves the original YAML structure and account ordering
            Utilities.safe_file_operation(yaml_file, :write, YAML.dump(yaml_data))

            true
          rescue StandardError => e
            Lich.log "error: Error adding favorite: #{e.message}"
            false
          end
        end

        # Removes a character from the favorites list
        # Unmarks the specified character as a favorite and reorders remaining favorites
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param frontend [String] Frontend identifier (optional for backward compatibility)
        # @return [Boolean] True if operation was successful
        def self.remove_favorite(data_dir, username, char_name, game_code, frontend = nil)
          yaml_file = File.join(data_dir, "entry.yml")
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data = migrate_to_favorites_format(yaml_data)

            # Find the character with frontend precision
            character = find_character(yaml_data, username, char_name, game_code, frontend)
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
            Utilities.safe_file_operation(yaml_file, :write, YAML.dump(yaml_data))
          rescue StandardError => e
            Lich.log "error: Error removing favorite: #{e.message}"
            false
          end
        end

        # Checks if a character is marked as a favorite
        # Returns true if the specified character is in the favorites list
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param frontend [String] Frontend identifier (optional for backward compatibility)
        # @return [Boolean] True if character is a favorite
        def self.is_favorite?(data_dir, username, char_name, game_code, frontend = nil)
          yaml_file = File.join(data_dir, "entry.yml")
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data = migrate_to_favorites_format(yaml_data)

            character = find_character(yaml_data, username, char_name, game_code, frontend)
            character && character['is_favorite'] == true
          rescue StandardError => e
            Lich.log "error: Error checking favorite status: #{e.message}"
            false
          end
        end

        # Gets all favorite characters across all accounts
        # Returns an array of favorite characters sorted by favorite order
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
              next unless account_data['characters']

              account_data['characters'].each do |character|
                if character['is_favorite']
                  favorites << {
                    user_id: username,
                    char_name: character['char_name'],
                    game_code: character['game_code'],
                    game_name: character['game_name'],
                    frontend: character['frontend'],
                    favorite_order: character['favorite_order'] || 999,
                    favorite_added: character['favorite_added']
                  }
                end
              end
            end

            # Sort by favorite order
            favorites.sort_by { |fav| fav[:favorite_order] }
          rescue StandardError => e
            Lich.log "error: Error getting favorites: #{e.message}"
            []
          end
        end

        # Reorders favorites based on provided character list
        # Updates the favorite order for all favorites based on new ordering
        #
        # @param data_dir [String] Directory containing entry data
        # @param ordered_favorites [Array] Array of hashes with username, char_name, game_code, frontend
        # @return [Boolean] True if operation was successful
        def self.reorder_favorites(data_dir, ordered_favorites)
          yaml_file = File.join(data_dir, "entry.yml")
          return false unless File.exist?(yaml_file)

          begin
            yaml_data = YAML.load_file(yaml_file)
            yaml_data = migrate_to_favorites_format(yaml_data)

            # Update favorite order for each character in the provided order
            ordered_favorites.each_with_index do |favorite_info, index|
              character = find_character(
                yaml_data,
                favorite_info[:username] || favorite_info['username'],
                favorite_info[:char_name] || favorite_info['char_name'],
                favorite_info[:game_code] || favorite_info['game_code'],
                favorite_info[:frontend] || favorite_info['frontend']
              )

              if character && character['is_favorite']
                character['favorite_order'] = index + 1
              end
            end

            # Save updated data
            Utilities.safe_file_operation(yaml_file, :write, YAML.dump(yaml_data))
          rescue StandardError => e
            Lich.log "error: Error reordering favorites: #{e.message}"
            false
          end
        end

        # Converts YAML data structure to legacy format
        # Transforms the YAML structure into the format expected by existing code
        #
        # @param yaml_data [Hash] YAML data structure
        # @return [Array] Array of entry data in legacy format
        def self.convert_yaml_to_legacy_format(yaml_data)
          entries = []

          return entries unless yaml_data['accounts']

          yaml_data['accounts'].each do |username, account_data|
            next unless account_data['characters']

            account_data['characters'].each do |character|
              entry = {
                user_id: username,
                password: account_data['password'], # Password is at account level
                char_name: character['char_name'],
                game_code: character['game_code'],
                game_name: character['game_name'],
                frontend: character['frontend'],
                custom_launch: character['custom_launch'],
                custom_launch_dir: character['custom_launch_dir'],
                is_favorite: character['is_favorite'] || false,
                favorite_order: character['favorite_order']
              }

              entries << entry
            end
          end

          entries
        end

        # Converts legacy format to YAML data structure
        # Transforms legacy entry data into the YAML structure for storage
        #
        # @param entry_data [Array] Array of entry data in legacy format
        # @return [Hash] YAML data structure
        def self.convert_legacy_to_yaml_format(entry_data)
          yaml_data = { 'accounts' => {} }

          entry_data.each do |entry|
            username = entry[:user_id]

            # Initialize account if not exists, with password at account level
            yaml_data['accounts'][username] ||= {
              'password'   => entry[:password],
              'characters' => []
            }

            character_data = {
              'char_name'         => entry[:char_name],
              'game_code'         => entry[:game_code],
              'game_name'         => entry[:game_name],
              'frontend'          => entry[:frontend],
              'custom_launch'     => entry[:custom_launch],
              'custom_launch_dir' => entry[:custom_launch_dir],
              'is_favorite'       => entry[:is_favorite] || false
            }

            # Add favorite metadata if character is a favorite
            if entry[:is_favorite]
              character_data['favorite_order'] = entry[:favorite_order]
              character_data['favorite_added'] = entry[:favorite_added] || Time.now.to_s
            end

            yaml_data['accounts'][username]['characters'] << character_data
          end

          yaml_data
        end

        # Sorts entries with favorites priority based on autosort setting
        # When autosort is enabled, favorites are placed first and all entries are sorted
        # When autosort is disabled, original order is preserved without reordering
        #
        # @param entries [Array] Array of entry data
        # @param autosort_state [Boolean] Whether to use auto-sorting
        # @return [Array] Sorted array of entries (if autosort enabled) or original order (if disabled)
        def self.sort_entries_with_favorites(entries, autosort_state)
          # If autosort is disabled, preserve original order without any reordering
          return entries unless autosort_state

          # Autosort enabled: apply favorites-first sorting
          # Separate favorites and non-favorites
          favorites = entries.select { |entry| entry[:is_favorite] }
          non_favorites = entries.reject { |entry| entry[:is_favorite] }

          # Sort favorites by favorite_order
          favorites.sort_by! { |entry| entry[:favorite_order] || 999 }

          # Sort non-favorites by account name (upcase), game name, and character name
          sorted_non_favorites = non_favorites.sort do |a, b|
            [a[:user_id].upcase, a[:game_name], a[:char_name]] <=> [b[:user_id].upcase, b[:game_name], b[:char_name]]
          end

          # Return favorites first, then non-favorites
          favorites + sorted_non_favorites
        end

        # Migrates YAML data to support favorites format
        # Adds favorites fields to existing character records if not present
        #
        # @param yaml_data [Hash] YAML data structure
        # @return [Hash] YAML data structure with favorites support
        def self.migrate_to_favorites_format(yaml_data)
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

        # Finds a character in the YAML data with precise matching
        # Prioritizes exact frontend matches for newly added characters
        #
        # @param yaml_data [Hash] YAML data structure
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param frontend [String, nil] Frontend identifier
        # @return [Hash, nil] Character hash or nil if not found
        def self.find_character(yaml_data, username, char_name, game_code, frontend = nil)
          return nil unless yaml_data['accounts'] && yaml_data['accounts'][username]
          account_data = yaml_data['accounts'][username]
          return nil unless account_data['characters']

          # If frontend is specified, find exact match first
          if frontend
            exact_match = account_data['characters'].find do |character|
              character['char_name'] == char_name &&
                character['game_code'] == game_code &&
                character['frontend'] == frontend
            end
            return exact_match if exact_match
          end

          # Fallback to basic matching only if no exact match found and frontend is nil
          if frontend.nil?
            account_data['characters'].find do |character|
              character['char_name'] == char_name && character['game_code'] == game_code
            end
          else
            # If frontend was specified but no exact match found, return nil
            nil
          end
        end

        # Gets the next available favorite order number
        # Finds the highest current favorite order and returns the next number
        #
        # @param yaml_data [Hash] YAML data structure
        # @return [Integer] Next available favorite order number
        def self.get_next_favorite_order(yaml_data)
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

        # Finds an entry in legacy format array using the same matching logic as find_character
        # Searches for an entry based on key identifying fields rather than exact hash equality
        # This method reuses the proven matching logic from find_character for consistency
        #
        # @param entry_data [Array] Array of entry data in legacy format
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param frontend [String] Frontend identifier (optional for backward compatibility)
        # @return [Hash, nil] Entry hash if found, nil otherwise
        def self.find_entry_in_legacy_format(entry_data, username, char_name, game_code, frontend = nil)
          entry_data.find do |entry|
            # Match on username first
            next unless entry[:user_id] == username

            # Apply same matching logic as find_character
            matches_basic = entry[:char_name] == char_name && entry[:game_code] == game_code

            if frontend.nil?
              # Backward compatibility: if no frontend specified, match any frontend
              matches_basic
            else
              # Frontend precision: must match exact frontend
              matches_basic && entry[:frontend] == frontend
            end
          end
        end

        # Reorders all favorites to have consecutive order numbers
        # Ensures favorite_order values are consecutive starting from 1
        #
        # @param yaml_data [Hash] YAML data structure
        # @return [void]
        def self.reorder_all_favorites(yaml_data)
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
      end
    end
  end
end
