# lgoin_helpers.rb: Core lich file for collection of utilities to extend Lich capabilities.
# Entries added here should always be accessible from Lich::Util::LoginHelpers.method namespace.

module Lich
  module Util
    module LoginHelpers
      # Recursively converts string keys to symbols in nested hash and array structures.
      #
      # This method ensures that YAML data loaded with string keys can be accessed
      # using Ruby symbols, which is the preferred approach for hash keys in Ruby.
      #
      # @param obj [Hash, Array, Object] The object to process
      # @return [Hash, Array, Object] The object with string keys converted to symbols
      #
      def self.symbolize_keys(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(key, value), result|
            symbol_key = key.respond_to?(:to_sym) ? key.to_sym : key
            result[symbol_key] = symbolize_keys(value)
          end
        when Array
          obj.map { |element| symbolize_keys(element) }
        else
          obj
        end
      end

      # Searches for characters across all accounts based on specified criteria.
      #
      # This is the primary search method that scans through all accounts and their
      # characters to find matches based on any combination of character name,
      # game code, and frontend. All parameters are optional, allowing for flexible
      # search patterns.
      #
      # @param symbolized_data [Hash] The symbolized YAML data structure
      # @param char_name [String, nil] The character name to search for (optional)
      # @param game_code [String, nil] The game code/instance to filter by (optional)
      # @param frontend [String, nil] The frontend type to filter by (optional)
      # @return [Hash] of character result with account and character data
      def self.find_character_by_attributes(symbolized_data, char_name: nil, game_code: nil, frontend: nil)
        matches = Array.new

        symbolized_data[:accounts].each do |account_name, account_data|
          account_data[:characters].each do |character|
            # Check if character matches all specified criteria
            match = true

            match = false if char_name && character[:char_name] != char_name
            match = false if game_code && character[:game_code] != game_code
            match = false if frontend && character[:frontend] != frontend

            if match
              matches << build_character_result(account_name, account_data, character)
            end
          end
        end

        matches
      end

      # Constructs a standardized character result hash with account and character data.
      #
      # This helper method ensures consistent structure across all search results,
      # combining account-level information (name, password) with character-specific
      # data in a flattened, easily accessible format.
      #
      # @param account_name [Symbol] The account name/identifier
      # @param account_data [Hash] The account data hash containing password and characters
      # @param character [Hash] The individual character data hash
      # @return [Hash] Standardized result hash with both account and character information
      def self.build_character_result(username, account_data, character)
        {
          # account_name: account_name,
          username: username.to_s,
          password: account_data[:password],
          #      character: character,
          # Flattened character data for easy access
          char_name: character[:char_name],
          game_code: character[:game_code],
          game_name: character[:game_name],
          frontend: character[:frontend],
          custom_launch: character[:custom_launch],
          custom_launch_dir: character[:custom_launch_dir],
          is_favorite: character[:is_favorite],
          favorite_order: character[:favorite_order],
          favorite_added: character[:favorite_added]
        }
      end

      # Returns the first character matching the specified criteria, or nil if none found.
      #
      # This convenience method wraps find_character_by_attributes to return only the
      # first match, which is useful when you expect a unique result or only need one
      # character from potentially multiple matches.
      #
      # @param symbolized_data [Hash] The symbolized YAML data structure
      # @param char_name [String, nil] The character name to search for (optional)
      # @param game_code [String, nil] The game code/instance to filter by (optional)
      # @param frontend [String, nil] The frontend type to filter by (optional)
      # @return [Hash, nil] First matching character result hash, or nil if no matches
      def self.find_first_character_by_attributes(symbolized_data, char_name: nil, game_code: nil, frontend: nil)
        matches = find_character_by_attributes(symbolized_data, char_name: char_name, game_code: game_code, frontend: frontend)
        matches.first
      end

      # Finds all characters with the specified name across all accounts and games.
      #
      # @param symbolized_data [Hash] The symbolized YAML data structure
      # @param char_name [String] The character name to search for
      # @return [Array<Hash>] Array of all characters with the specified name
      def self.find_character_by_name(symbolized_data, char_name)
        find_character_by_attributes(symbolized_data, char_name: char_name)
      end

      # Finds all characters with the specified name in the specified game.
      #
      # @param symbolized_data [Hash] The symbolized YAML data structure
      # @param char_name [String] The character name to search for
      # @param game_code [String] The game code/instance to filter by
      # @return [Array<Hash>] Array of characters matching name and game
      def self.find_character_by_name_and_game(symbolized_data, char_name, game_code)
        find_character_by_attributes(symbolized_data, char_name: char_name, game_code: game_code)
      end

      # Finds characters matching all three criteria: name, game code, and frontend.
      #
      # This method provides the most specific search, useful when you need to find
      # a character with exact specifications across all three dimensions.
      #
      # @param symbolized_data [Hash] The symbolized YAML data structure
      # @param char_name [String] The character name to search for
      # @param game_code [String] The game code/instance to filter by
      # @param frontend [String] The frontend type to filter by
      # @return [Array<Hash>] Array of characters matching all three criteria
      def self.find_character_by_name_game_and_frontend(symbolized_data, char_name, game_code, frontend)
        find_character_by_attributes(symbolized_data, char_name: char_name, game_code: game_code, frontend: frontend)
      end
    end
  end
end
