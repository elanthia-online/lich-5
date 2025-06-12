# util.rb: Core lich file for collection of utilities to extend Lich capabilities.
# Entries added here should always be accessible from Lich::Util.feature namespace.

module Lich
  module Util
    include Enumerable

    def self.normalize_lookup(effect, val)
      caller_type = "Effects::#{effect}"
      case val
      when String
        (eval caller_type).to_h.transform_keys(&:to_s).transform_keys(&:downcase).include?(val.downcase.gsub('_', ' '))
      when Integer
        #      seek = mappings.fetch(val, nil)
        (eval caller_type).active?(val)
      when Symbol
        (eval caller_type).to_h.transform_keys(&:to_s).transform_keys(&:downcase).include?(val.to_s.downcase.gsub('_', ' '))
      else
        fail "invalid lookup case #{val.class.name}"
      end
    end

    def self.normalize_name(name)
      # there are five cases to normalize
      # "vault_kick", "vault kick", "vault-kick", :vault_kick, :vaultkick
      # "predator's eye"
      # if present, convert spaces to underscore; convert all to downcase string
      normal_name = name.to_s.downcase
      normal_name.gsub!(' ', '_') if name =~ (/\s/)
      normal_name.gsub!('-', '_') if name =~ (/-/)
      normal_name.gsub!(":", '') if name =~ (/:/)
      normal_name.gsub!("'", '') if name =~ (/'/)
      normal_name
    end

    ## Lifted from LR foreach.lic

    def self.anon_hook(prefix = '')
      now = Time.now
      "Util::#{prefix}-#{now}-#{Random.rand(10000)}"
    end

    def self.issue_command(command, start_pattern, end_pattern = /<prompt/, include_end: true, timeout: 5, silent: nil, usexml: true, quiet: false, use_fput: true)
      result = []
      name = self.anon_hook
      filter = false

      save_script_silent = Script.current.silent
      save_want_downstream = Script.current.want_downstream
      save_want_downstream_xml = Script.current.want_downstream_xml

      Script.current.silent = silent if !silent.nil?
      Script.current.want_downstream = !usexml
      Script.current.want_downstream_xml = usexml

      begin
        Timeout::timeout(timeout, Interrupt) {
          DownstreamHook.add(name, proc { |line|
            if filter
              if line =~ end_pattern
                DownstreamHook.remove(name)
                filter = false
                if quiet
                  next(nil)
                else
                  line
                end
              else
                if quiet
                  next(nil)
                else
                  line
                end
              end
            elsif line =~ start_pattern
              filter = true
              if quiet
                next(nil)
              else
                line
              end
            else
              line
            end
          })
          use_fput ? fput(command) : put(command)

          until (line = get) =~ start_pattern; end
          result << line.rstrip
          until (line = get) =~ end_pattern
            result << line.rstrip
          end
          if include_end
            result << line.rstrip
          end
        }
      rescue Interrupt
        nil
      ensure
        DownstreamHook.remove(name)
        Script.current.silent = save_script_silent if !silent.nil?
        Script.current.want_downstream = save_want_downstream
        Script.current.want_downstream_xml = save_want_downstream_xml
      end
      return result
    end

    def self.quiet_command_xml(command, start_pattern, end_pattern = /<prompt/, include_end = true, timeout = 5, silent = true)
      return issue_command(command, start_pattern, end_pattern, include_end: include_end, timeout: timeout, silent: silent, usexml: true, quiet: true)
    end

    def self.quiet_command(command, start_pattern, end_pattern, include_end = true, timeout = 5, silent = true)
      return issue_command(command, start_pattern, end_pattern, include_end: include_end, timeout: timeout, silent: silent, usexml: false, quiet: true)
    end

    def self.silver_count(timeout = 3)
      silence_me unless (undo_silence = silence_me)
      result = ''
      name = self.anon_hook
      filter = false

      start_pattern = /^\s*Name\:/
      end_pattern = /^\s*Mana\:\s+\-?[0-9]+\s+Silver\:\s+([0-9,]+)/
      ttl = Time.now + timeout
      begin
        # main thread
        DownstreamHook.add(name, proc { |line|
          if filter
            if line =~ end_pattern
              result = $1.dup
              DownstreamHook.remove(name)
              filter = false
            else
              next(nil)
            end
          elsif line =~ start_pattern
            filter = true
            next(nil)
          else
            line
          end
        })
        # script thread
        fput 'info'
        loop {
          # non-blocking check, this allows us to
          # check the time even when the buffer is empty
          line = get?
          break if line && line =~ end_pattern
          break if Time.now > ttl
          sleep(0.01) # prevent a tight-loop
        }
      ensure
        DownstreamHook.remove(name)
        silence_me if undo_silence
      end
      return result.gsub(',', '').to_i
    end

    # Expects hash to be passed to the method.
    # Each keypair should consist of a gem name and whether to require it after attempting to install gem
    def self.install_gem_requirements(gems_to_install)
      raise ArgumentError, "install_gem_requirements must be passed a Hash" unless gems_to_install.is_a?(Hash)
      require "rubygems"
      require "rubygems/dependency_installer"
      installer = Gem::DependencyInstaller.new({ :user_install => true, :document => nil })
      installed_gems = Gem::Specification.map { |gem| gem.name }.sort.uniq
      failed_gems = []

      gems_to_install.each do |gem_name, should_require|
        unless gem_name.is_a?(String) && (should_require.is_a?(TrueClass) || should_require.is_a?(FalseClass))
          raise ArgumentError, "install_gem_requirements must be passed a Hash with String key and TrueClass/FalseClass as value"
        end
        begin
          unless installed_gems.include?(gem_name)
            respond("--- Lich: Installing missing ruby gem '#{gem_name}' now, please wait!")
            installer.install(gem_name)
            respond("--- Lich: Done installing '#{gem_name}' gem!")
          end
          require gem_name if should_require
        rescue StandardError
          respond("--- Lich: error: Failed to install Ruby gem: #{gem_name}")
          respond("--- Lich: error: #{$!}")
          Lich.log("error: Failed to install Ruby gem: #{gem_name}")
          Lich.log("error: #{$!}")
          failed_gems.push(gem_name)
        end
      end
      unless failed_gems.empty?
        raise("Please install the failed gems: #{failed_gems.join(', ')} to run #{$lich_char}#{Script.current.name}")
      end
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
      matches = Hash.new

      symbolized_data[:accounts].each do |account_name, account_data|
        account_data[:characters].each do |character|
          # Check if character matches all specified criteria
          match = true

          match = false if char_name && character[:char_name] != char_name
          match = false if game_code && character[:game_code] != game_code
          match = false if frontend && character[:frontend] != frontend

          if match
            matches.merge!(build_character_result(account_name, account_data, character))
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
