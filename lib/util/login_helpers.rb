# login_helpers.rb: Core lich file for collection of utilities to extend Lich capabilities.
# Entries added here should always be accessible from Lich::Util::LoginHelpers.method namespace.

module Lich
  module Util
    module LoginHelpers
      # Valid game codes
      VALID_GAME_CODES = %w[GS3 GS4 GSX GSF GST DR DRX DRF DRT].freeze

      # Valid frontend flags
      VALID_FRONTENDS = %w[avalon stormfront wizard].freeze

      # Valid realms for elogin support
      VALID_REALMS = %w[prime platinum shattered test].freeze

      # Frontend pattern for regex matching
      FRONTEND_PATTERN = /^--(?<fe>avalon|stormfront|wizard)$/i.freeze
      INSTANCE_PATTERN = /^--(?<inst>GS.?$|DR.?$)/i.freeze

      # Game code to realm mappings
      GAME_CODE_TO_REALM = {
        'GSX' => 'platinum',
        'GSF' => 'shattered',
        'GST' => 'test'
      }.freeze

      # Realm to game code mappings
      REALM_TO_GAME_CODE = {
        'prime'     => 'GS3',
        'platinum'  => 'GSX',
        'shattered' => 'GSF',
        'test'      => 'GST'
      }.freeze

      # Game code to human-readable name mappings
      GAME_CODE_TO_NAME = {
        'GS3' => 'GemStone IV',
        'GSX' => 'GemStone IV Platinum',
        'GSF' => 'GemStone IV Shattered',
        'GST' => 'GemStone IV Test',
        'DR'  => 'DragonRealms',
        'DRX' => 'DragonRealms Platinum',
        'DRF' => 'DragonRealms Fallen',
        'DRT' => 'DragonRealms Test'
      }.freeze

      def self.realm_from_game_code(code)
        GAME_CODE_TO_REALM.fetch(code.to_s.upcase, GameConfig::DEFAULT_REALM)
      end

      def self.realm_to_game_code(realm)
        REALM_TO_GAME_CODE[realm]
      end

      def self.game_name_from_game_code(game_code)
        GAME_CODE_TO_NAME.fetch(game_code, GameConfig::DEFAULT_GAME_NAME)
      end

      def self.valid_realm?(realm)
        VALID_REALMS.include?(realm)
      end

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

      # Detects the data format of the provided symbolized structure.
      #
      # @param data [Object] The symbolized data to analyze
      # @return [Symbol] :yaml_accounts, :legacy_array, or :unknown
      def self.data_format(data)
        return :legacy_array if data.is_a?(Array)
        return :yaml_accounts if data.is_a?(Hash) && data.key?(:accounts)
        :unknown
      end

      # Extracts character hashes and their owning account context from any supported data structure.
      #
      # @param data [Object] The symbolized data (YAML or legacy entry format)
      # @return [Array<Array>] An array of [account_name, account_data, character_hash]
      def self.extract_candidate_characters_with_accounts(data)
        case data_format(data)
        when :legacy_array
          data.map { |char| { account_name: nil, account_data: nil, character: char } }
        when :yaml_accounts
          data[:accounts].flat_map do |account_name, account_data|
            (account_data[:characters] || []).map do |character|
              { account_name: account_name, account_data: account_data, character: character }
            end
          end
        else
          echo "[WARN] Unsupported character data structure."
          []
        end
      end

      # Searches for characters across all accounts based on specified criteria.
      #
      # This method filters a symbolized account data structure to return character
      # records that match the provided character name, game code, and frontend.
      # All parameters are optional except for the symbolized data and character name,
      # allowing for flexible search patterns.
      #
      # Matching Rules:
      # - `char_name` must match to include a record.
      # - If `game_code` is provided, it must match exactly OR fall back to a substitute:
      #     - 'GST' falls back to 'GS3'
      #     - 'DRT' falls back to 'DR'
      # - If `frontend` is provided, it must match exactly.
      #
      # All parameters are optional except `symbolized_data` and character name. If no
      # other parameters are provided, multiple character records may be returned.
      #
      # @param symbolized_data [Object] The symbolized YAML or legacy data structure.
      # @param char_name [String] The character name to match against `:char_name`. If nil, all names are considered.
      # @param game_code [String, Symbol, nil] The desired game instance (`:__unset` by default). Supports fallbacks for 'GST' and 'DRT'.
      # @param frontend [String, Symbol, nil] The frontend to match against `:frontend`. If nil, all frontends are considered.
      # @return [Array<Hash>] An array of character result hashes matching the provided criteria.
      def self.find_character_by_attributes(symbolized_data, char_name: nil, game_code: :__unset, frontend: :__unset)
        candidates = extract_candidate_characters_with_accounts(symbolized_data)

        # Step 1: Try to find exact matches only
        exact_matches = candidates.filter_map do |entry|
          character = entry[:character] || entry # supports flat and nested formats
          account_name = entry[:account_name] rescue nil
          account_data = entry[:account_data] rescue nil

          next unless character[:char_name].casecmp?(char_name)
          next unless game_code == :__unset || character[:game_code].to_s.casecmp?(game_code.to_s)

          build_character_result(account_name, account_data, character)
        end
        echo "RETURNING EXACT MATCHES ONLY: #{exact_matches.inspect}"
        return exact_matches unless exact_matches.empty?

        # Step 2: Fallback match (if needed)
        fallback_code = case game_code.to_s.upcase
                        when 'GST' then 'GS3'
                        when 'DRT' then 'DR'
                        else nil
                        end

        candidates.filter_map do |entry|
          account_name = entry[:account_name]
          account_data = entry[:account_data]
          character    = entry[:character]

          next unless character[:char_name].casecmp?(char_name)

          char_code = character[:game_code].to_s.upcase

          # Fallback logic
          next unless fallback_code && char_code == fallback_code

          # Optional: mark that this was a fallback
          character = character.dup
          character[:_requested_game_code] = game_code

          # Frontend filter
          if frontend != :__unset && !frontend.nil?
            next unless character[:frontend].to_s == frontend.to_s
          end

          build_character_result(account_name, account_data, character)
        end
      end

      # Constructs a unified character hash with necessary login metadata.
      #
      # For legacy data (no account context), the character hash is returned as-is.
      # For YAML-sourced data, it extracts username/password and flattens the result.
      #
      # @param account_name [String, nil] The owning account's name (YAML mode)
      # @param account_data [Hash, nil] The owning account's data hash (YAML mode)
      # @param character [Hash] The raw character data hash
      # @return [Hash] A flattened login entry hash suitable for authentication
      def self.build_character_result(account_name, account_data, character)
        return character if account_name.nil? && account_data.nil?

        {
          username: account_name.to_s,
          password: account_data[:password],
          char_name: character[:char_name],
          game_code: character[:_requested_game_code] || character[:game_code],
          game_name: character[:game_name],
          frontend: character[:frontend],
          custom_launch: character[:custom_launch],
          custom_launch_dir: character[:custom_launch_dir],
          is_favorite: character[:is_favorite],
          favorite_order: character[:favorite_order],
          favorite_added: character[:favorite_added],
        }.compact
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

      # Selects the best matching character data hash from an array based on weighted criteria.
      #
      # Rules:
      # - A match on `:char_name` is required for any record to be considered.
      # - If `requested_instance` is provided, a match on `:game_code` is also required.
      # - Among valid matches, `:frontend` improves the match but is not required.
      #
      # Scoring:
      # - Matching `:frontend` = 1 point
      #
      # The highest-scoring matching record is returned. If scores are tied,
      # the first encountered is returned. If no valid instance match, returns nil.
      # The hash with the highest cumulative score is returned. If there is a tie,
      # the first highest-scoring hash encountered is returned.
      #
      # @param char_data_sets [Array<Hash>] An array of character data hashes, each containing keys :char_name, :game_code, and :frontend.
      # @param requested_character [String] The character name to match against `:char_name`.
      # @param requested_instance [String, nil] The game instance to match against if provided `:game_code` or nil.
      # @param requested_fe [String, nil] The frontend to optionally match against `:frontend` or nil.
      # @return [Hash, nil] The best matching character hash, or nil if the input array is nil or empty.
      def self.select_best_fit(char_data_sets:, requested_character:, requested_instance: :__unset, requested_fe: :__unset)
        return nil if char_data_sets.nil? || char_data_sets.empty?
        return nil unless requested_character

        # Filter by required character match
        matching_chars = char_data_sets.select { |char| char[:char_name] == requested_character }
        return nil if matching_chars.empty?

        # Filter by game instance if explicitly provided and valid, includes fallback GST -> GS3
        if requested_instance != :__unset
          if requested_instance.nil? || !VALID_GAME_CODES.include?(requested_instance)
            Lich.log "error: Probable invalid instance detected. Valid instances: #{VALID_GAME_CODES.join(', ')}"
            $stdout.puts "Error: Probable invalid instance detected. Valid instances: #{VALID_GAME_CODES.join(', ')}"
            return nil
          end

          matching_chars.select! do |char|
            echo char[:game_code]
            effective_code = char[:_requested_game_code] || char[:game_code]
            effective_code == requested_instance
          end
          return nil if matching_chars.empty?
        end

        # Rank by frontend if provided
        best_match = matching_chars.first
        highest_score = 0

        matching_chars.each do |char|
          score = 0
          score += 1 if requested_fe != :__unset && char[:frontend] == requested_fe

          if score > highest_score
            best_match = char
            highest_score = score
          end
        end

        best_match
      end

      # Resolves the game instance from command line arguments
      # @param argv [Array<String>] command line arguments
      # @return [String, nil] game instance code or nil if no valid pattern found
      def self.resolve_instance(argv)
        instance_flags_seen = false
        resolved_instance = nil

        # Check for --gemstone with variants
        if argv.include?('--gemstone')
          instance_flags_seen = true
          resolved_instance ||= 'GST' if argv.include?('--test')
          resolved_instance ||= 'GSX' if argv.include?('--platinum')
          resolved_instance ||= 'GSF' if argv.include?('--shattered')
          resolved_instance ||= 'GS3' # default gemstone
        end

        if argv.include?('--dragonrealms')
          instance_flags_seen = true
          resolved_instance ||= 'DRT' if argv.include?('--test')
          resolved_instance ||= 'DRX' if argv.include?('--platinum')
          resolved_instance ||= 'DRF' if argv.include?('--fallen')
          resolved_instance ||= 'DR' # default dragonrealms
        end

        # Check for standalone --shattered
        if argv.include?('--shattered')
          instance_flags_seen = true
          resolved_instance ||= 'GSF'
        end
        if argv.include?('--fallen')
          instance_flags_seen = true
          resolved_instance ||= 'DRF'
        end

        # Check for direct instance codes (GS3, GS4, GST, GSX, etc.)
        # this filter ignores --login, --start-scripts=, and captures valid game codes
        # if anything else is sent with a --flag, it is processed as an incorrect instance
        if resolved_instance.nil?
          argv.each do |arg|
            next unless arg.start_with?('--')
            flag = arg.sub('--', '').downcase
            if VALID_GAME_CODES.include?(flag.upcase)
              instance_flags_seen = true
              resolved_instance = flag.upcase
              break
            elsif VALID_FRONTENDS.include?(flag) # ignore anything else that isn't a valid game code
              next
            elsif flag =~ /^(?:start-scripts|login)$/
              next
            else
              instance_flags_seen = true # set to true so that we fall through to returning nil
            end
          end
        end

        return resolved_instance unless resolved_instance.nil?
        return :__unset unless instance_flags_seen
        nil
      end

      # Parses Lich CLI args to determine game instance and frontend.
      #
      # Returns [instance, frontend] (both may be nil). Invalid game codes are not rejected here;
      # call site can choose to validate against VALID_GAME_CODES.
      #
      # Examples:
      #   --gemstone --platinum   → ['GSX', nil]
      #   --dragonrealms --fallen → ['DRF', nil]
      #   --GS4 --wizard          → ['GS3', 'wizard']
      #
      # @param argv [Array<String>] e.g. ARGV
      # @return [Array(String, String)] [game_code, frontend]
      def self.resolve_login_args(argv)
        frontend = :__unset
        instance = resolve_instance(argv)

        argv.each do |arg|
          case arg
          when FRONTEND_PATTERN
            frontend = Regexp.last_match[:fe].downcase
          end
        end

        Lich.log "debug: Login arguments from CLI login -> #{argv.inspect}"
        Lich.log "debug: Resolved instance: #{instance.inspect}, frontend: #{frontend.inspect}"
        # $stdout.puts "[DEBUG] ARGV: #{argv.inspect}"
        # $stdout.puts "[DEBUG] Resolved instance: #{instance.inspect}, frontend: #{frontend.inspect}"

        [instance, frontend]
      end

      # Formats the game instance launch flag for Lich based on version.
      #
      # Older versions of Lich (pre-5.12) only recognize specific lowercase flags
      # (e.g., `--gst`, `--drt`). Newer versions (5.12+) accept generalized `--GAMECODE` format.
      #
      # @param game_code [String, Symbol] the game instance code (e.g., 'GS3', 'GST', 'GSX')
      # @return [String, nil] the correctly formatted launch flag (e.g., '--gst', '--GSX'), or nil if not needed
      def self.format_launch_flag(game_code)
        return nil if game_code.to_s.strip.empty?

        normalized_code = game_code.to_s.upcase

        if lich_version_at_least?(5, 12, 0)
          "--#{normalized_code}"
        else
          case normalized_code
          when 'GST' then '--gst'
          when 'DRT' then '--drt'
          else nil
          end
        end
      end

      # Spawns a Lich login session using a saved entry.
      #
      # This constructs and launches a Ruby + Lich command line with proper login arguments.
      # It is aware of the Lich version and formats launch flags (e.g., `--gst`, `--GSX`) accordingly.
      # Only the character name and game instance are passed — all sensitive data is handled by Lich internally.
      #
      # @param entry [Hash] the login entry (must include :char_name and :game_code)
      # @param lich_path [String, nil] optional path to lich.rbw; defaults to LICH_DIR/lich.rbw
      # @param startup_scripts [Array<String>] optional scripts to autostart post-login
      # @param instance_override [String, Symbol, nil] optional instance override (e.g., 'GST', 'GSX')
      # @param frontend_override [String, nil] optional frontend (e.g., 'avalon', 'wizard')
      # @return [Process::Waiter, nil] detached process handle if successful, nil otherwise
      def self.spawn_login(entry, lich_path: nil, startup_scripts: [], instance_override: nil, frontend_override: nil)
        ruby_path = RbConfig.ruby
        lich_path ||= File.join(LICH_DIR, 'lich.rbw')

        spawn_cmd = [
          "#{ruby_path}",
          "#{lich_path}",
          '--login', entry[:char_name]
        ]
        if instance_override
          flag = format_launch_flag(instance_override)
          spawn_cmd << flag if flag
        end
        spawn_cmd << "--#{frontend_override}" unless frontend_override.nil?
        spawn_cmd << "--start-scripts=#{startup_scripts.join(',')}" if startup_scripts.any?

        echo "[INFO] Spawning login: #{spawn_cmd}"

        begin
          pid = Process.spawn(*spawn_cmd)
          Process.detach(pid)
        rescue Errno::ENOENT => e
          echo "[ERROR] Executable not found: #{e.message}"
          nil
        rescue StandardError => e
          echo "[ERROR] Failed to launch login session: #{e.class} - #{e.message}"
          nil
        end
      end
    end
  end
end
