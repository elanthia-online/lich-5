# frozen_string_literal: true

module Lich
  module Common
    module GUI
      # Manages favorites-related operations for the Lich GUI login system
      # Provides a high-level interface for favorites management operations
      # following the established patterns from AccountManager
      module FavoritesManager
        # Adds a character to the favorites list
        # Marks the specified character as a favorite with proper ordering
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param frontend [String] Frontend identifier (optional for backward compatibility)
        # @return [Boolean] True if operation was successful
        def self.add_favorite(data_dir, username, char_name, game_code, frontend = nil)
          return false if data_dir.nil? || username.nil? || char_name.nil? || game_code.nil?

          begin
            result = YamlState.add_favorite(data_dir, username, char_name, game_code, frontend)

            if result
              frontend_info = frontend ? " (#{frontend})" : ""
              Lich.log "info: Added character '#{char_name}' (#{game_code})#{frontend_info} from account '#{username}' to favorites"
            else
              frontend_info = frontend ? " (#{frontend})" : ""
              Lich.log "warning: Failed to add character '#{char_name}' (#{game_code})#{frontend_info} from account '#{username}' to favorites"
            end

            result
          rescue StandardError => e
            Lich.log "error: Error in FavoritesManager.add_favorite: #{e.message}"
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
          return false if data_dir.nil? || username.nil? || char_name.nil? || game_code.nil?

          begin
            result = YamlState.remove_favorite(data_dir, username, char_name, game_code, frontend)

            if result
              frontend_info = frontend ? " (#{frontend})" : ""
              Lich.log "info: Removed character '#{char_name}' (#{game_code})#{frontend_info} from account '#{username}' from favorites"
            else
              frontend_info = frontend ? " (#{frontend})" : ""
              Lich.log "warning: Failed to remove character '#{char_name}' (#{game_code})#{frontend_info} from account '#{username}' from favorites"
            end

            result
          rescue StandardError => e
            Lich.log "error: Error in FavoritesManager.remove_favorite: #{e.message}"
            false
          end
        end

        # Toggles the favorite status of a character
        # Adds to favorites if not currently a favorite, removes if it is a favorite
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param frontend [String] Frontend identifier (optional for backward compatibility)
        # @return [Boolean] True if character is now a favorite, false if not
        def self.toggle_favorite(data_dir, username, char_name, game_code, frontend = nil)
          return false if data_dir.nil? || username.nil? || char_name.nil? || game_code.nil?

          begin
            if is_favorite?(data_dir, username, char_name, game_code, frontend)
              remove_favorite(data_dir, username, char_name, game_code, frontend)
              false
            else
              add_favorite(data_dir, username, char_name, game_code, frontend)
              true
            end
          rescue StandardError => e
            Lich.log "error: Error in FavoritesManager.toggle_favorite: #{e.message}"
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
          return false if data_dir.nil? || username.nil? || char_name.nil? || game_code.nil?

          begin
            YamlState.is_favorite?(data_dir, username, char_name, game_code, frontend)
          rescue StandardError => e
            Lich.log "error: Error in FavoritesManager.is_favorite?: #{e.message}"
            false
          end
        end

        # Gets all favorite characters across all accounts
        # Returns an array of favorite characters sorted by favorite order
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Array] Array of favorite character data in legacy format
        def self.get_all_favorites(data_dir)
          return [] if data_dir.nil?

          begin
            YamlState.get_favorites(data_dir)
          rescue StandardError => e
            Lich.log "error: Error in FavoritesManager.get_all_favorites: #{e.message}"
            []
          end
        end

        # Reorders favorites based on provided character list
        # Updates the favorite order for all favorites based on new ordering
        #
        # @param data_dir [String] Directory containing entry data
        # @param ordered_favorites [Array] Array of hashes with username, char_name, game_code
        # @return [Boolean] True if operation was successful
        def self.reorder_favorites(data_dir, ordered_favorites)
          return false if data_dir.nil? || ordered_favorites.nil?

          begin
            result = YamlState.reorder_favorites(data_dir, ordered_favorites)

            if result
              Lich.log "info: Successfully reordered #{ordered_favorites.length} favorites"
            else
              Lich.log "warning: Failed to reorder favorites"
            end

            result
          rescue StandardError => e
            Lich.log "error: Error in FavoritesManager.reorder_favorites: #{e.message}"
            false
          end
        end

        # Gets the count of favorite characters
        # Returns the total number of characters marked as favorites
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Integer] Number of favorite characters
        def self.favorites_count(data_dir)
          return 0 if data_dir.nil?

          begin
            get_all_favorites(data_dir).length
          rescue StandardError => e
            Lich.log "error: Error in FavoritesManager.favorites_count: #{e.message}"
            0
          end
        end

        # Gets favorites for a specific account
        # Returns an array of favorite characters for the specified account
        #
        # @param data_dir [String] Directory containing entry data
        # @param username [String] Account username
        # @return [Array] Array of favorite character data for the account
        def self.get_account_favorites(data_dir, username)
          return [] if data_dir.nil? || username.nil?

          begin
            all_favorites = get_all_favorites(data_dir)
            all_favorites.select { |fav| fav[:user_id] == username }
          rescue StandardError => e
            Lich.log "error: Error in FavoritesManager.get_account_favorites: #{e.message}"
            []
          end
        end

        # Gets favorites for a specific game
        # Returns an array of favorite characters for the specified game
        #
        # @param data_dir [String] Directory containing entry data
        # @param game_code [String] Game code
        # @return [Array] Array of favorite character data for the game
        def self.get_game_favorites(data_dir, game_code)
          return [] if data_dir.nil? || game_code.nil?

          begin
            all_favorites = get_all_favorites(data_dir)
            all_favorites.select { |fav| fav[:game_code] == game_code }
          rescue StandardError => e
            Lich.log "error: Error in FavoritesManager.get_game_favorites: #{e.message}"
            []
          end
        end

        # Validates favorites data integrity
        # Checks that all favorites reference valid characters and removes orphaned favorites
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Hash] Hash with validation results and cleanup statistics
        def self.validate_and_cleanup_favorites(data_dir)
          return { valid: false, cleaned: 0, errors: ['Invalid data directory'] } if data_dir.nil?

          begin
            # Load all entry data to validate against
            entry_data = YamlState.load_saved_entries(data_dir, false)
            favorites = get_all_favorites(data_dir)

            cleaned_count = 0
            errors = []

            favorites.each do |favorite|
              # Check if the character still exists in the entry data
              character_exists = entry_data.any? do |entry|
                entry[:user_id] == favorite[:user_id] &&
                  entry[:char_name] == favorite[:char_name] &&
                  entry[:game_code] == favorite[:game_code] &&
                  (favorite[:frontend].nil? || entry[:frontend] == favorite[:frontend])
              end

              unless character_exists
                # Remove orphaned favorite
                if remove_favorite(data_dir, favorite[:user_id], favorite[:char_name], favorite[:game_code], favorite[:frontend])
                  cleaned_count += 1
                  frontend_info = favorite[:frontend] ? " (#{favorite[:frontend]})" : ""
                  Lich.log "info: Removed orphaned favorite: #{favorite[:char_name]} (#{favorite[:game_code]})#{frontend_info} from #{favorite[:user_id]}"
                else
                  frontend_info = favorite[:frontend] ? " (#{favorite[:frontend]})" : ""
                  errors << "Failed to remove orphaned favorite: #{favorite[:char_name]} (#{favorite[:game_code]})#{frontend_info} from #{favorite[:user_id]}"
                end
              end
            end

            {
              valid: true,
              total_favorites: favorites.length,
              cleaned: cleaned_count,
              remaining: favorites.length - cleaned_count,
              errors: errors
            }
          rescue StandardError => e
            Lich.log "error: Error in FavoritesManager.validate_and_cleanup_favorites: #{e.message}"
            { valid: false, cleaned: 0, errors: [e.message] }
          end
        end

        # Creates a character identifier hash for favorites operations
        # Provides a consistent way to identify characters across favorites operations
        #
        # @param username [String] Account username
        # @param char_name [String] Character name
        # @param game_code [String] Game code
        # @param frontend [String] Frontend identifier (optional)
        # @return [Hash] Character identifier hash
        def self.create_character_id(username, char_name, game_code, frontend = nil)
          {
            username: username,
            char_name: char_name,
            game_code: game_code,
            frontend: frontend
          }
        end

        # Extracts character identifier from entry data
        # Converts entry data hash to character identifier format
        #
        # @param entry_data [Hash] Character entry data
        # @return [Hash] Character identifier hash
        def self.extract_character_id(entry_data)
          return {} unless entry_data.is_a?(Hash)

          {
            username: entry_data[:user_id],
            char_name: entry_data[:char_name],
            game_code: entry_data[:game_code],
            frontend: entry_data[:frontend]
          }
        end

        # Checks if favorites functionality is available
        # Verifies that the data directory and required files exist
        #
        # @param data_dir [String] Directory containing entry data
        # @return [Boolean] True if favorites functionality is available
        def self.favorites_available?(data_dir)
          return false if data_dir.nil?

          yaml_file = File.join(data_dir, "entry.yml")
          File.exist?(yaml_file)
        end
      end
    end
  end
end
