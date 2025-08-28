=begin
util.rb: Core lich file for collection of utilities to extend Lich capabilities.
Entries added here should always be accessible from Lich::Util.feature namespace.
=end

module Lich
  module Util
    include Enumerable

    # Normalizes and performs a lookup for an effect based on the provided value.
    #
    # Depending on the type of `val`, this method will:
    # - For String: Check if the normalized string matches any key in the effect's hash (case-insensitive, underscores replaced with spaces).
    # - For Integer: Check if the effect is active for the given integer value.
    # - For Symbol: Check if the normalized symbol matches any key in the effect's hash (case-insensitive, underscores replaced with spaces).
    #
    # @param effect [String] The name of the effect class (without the "Effects::" prefix).
    # @param val [String, Integer, Symbol] The value to look up; can be a string, integer, or symbol.
    # @return [Boolean] True if the lookup is successful, false otherwise.
    # @raise [RuntimeError] If `val` is not a String, Integer, or Symbol.
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

    # Normalizes a given name by converting it to a lowercase string and replacing or removing certain characters.
    #
    # The normalization process handles the following cases:
    # - Converts spaces and hyphens to underscores.
    # - Removes colons and apostrophes.
    # - Converts symbols to strings.
    # - Converts all characters to lowercase.
    #
    # Examples:
    #   normalize_name("vault_kick")      #=> "vault_kick"
    #   normalize_name("vault kick")      #=> "vault_kick"
    #   normalize_name("vault-kick")      #=> "vault_kick"
    #   normalize_name(:vault_kick)       #=> "vault_kick"
    #   normalize_name(:vaultkick)        #=> "vaultkick"
    #   normalize_name("predator's eye")  #=> "predators_eye"
    #
    # @param name [String, Symbol] The name to normalize.
    # @return [String] The normalized name.
    def self.normalize_name(name)
      normal_name = name.to_s.downcase
      normal_name.gsub!(' ', '_') if name =~ (/\s/)
      normal_name.gsub!('-', '_') if name =~ (/-/)
      normal_name.gsub!(":", '') if name =~ (/:/)
      normal_name.gsub!("'", '') if name =~ (/'/)
      normal_name
    end

    # Generates a unique anonymous hook identifier string.
    #
    # @param prefix [String] an optional prefix to include in the identifier (default: '')
    # @return [String] a unique identifier in the format "Util::<prefix>-<timestamp>-<random_number>"
    # @example
    #   Util.anon_hook('event') #=> "Util::event-2024-06-13 12:34:56 +0000-1234"
    def self.anon_hook(prefix = '')
      now = Time.now
      "Util::#{prefix}-#{now}-#{Random.rand(10000)}"
    end

    # Issues a command to the game and captures output between start and end patterns.
    #
    # @param command [String] The command to send.
    # @param start_pattern [Regexp] Pattern marking the start of output capture.
    # @param end_pattern [Regexp, Symbol] Pattern marking the end of output capture. Defaults to /<prompt/. Use :ignore for single-line capture.
    # @param include_end [Boolean] Whether to include the end line in the result. Defaults to true.
    # @param timeout [Integer] Timeout in seconds for the command. Defaults to 5.
    # @param silent [Boolean, nil] Whether to silence script output. Defaults to nil (no change).
    # @param usexml [Boolean] Whether to use XML downstream. Defaults to true.
    # @param quiet [Boolean] If true, suppresses output of lines to FE starting with the start_pattern and ending with the end_pattern. Defaults to false.
    # @param use_fput [Boolean] If true, uses fput to send the command; otherwise uses put. Defaults to true.
    # @return [Array<String>] Lines of output captured between start and end patterns.
    def self.issue_command(command, start_pattern, end_pattern = /<prompt/, include_end: true, timeout: 5, silent: nil, usexml: true, quiet: false, use_fput: true)
      result = []
      name = self.anon_hook
      filter = false
      ignore_end = end_pattern.eql?(:ignore)

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
              if ignore_end || line =~ end_pattern
                DownstreamHook.remove(name)
                filter = false
                if quiet && !ignore_end
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
          unless ignore_end
            until (line = get) =~ end_pattern
              result << line.rstrip
            end
          end
          unless ignore_end
            if include_end
              result << line.rstrip
            end
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

    # Retrieves the current silver count from the game output by issuing the 'info' command
    # and parsing the response. Uses a downstream hook to filter and extract the silver value.
    #
    # @param timeout [Integer] the maximum number of seconds to wait for a response (default: 3)
    # @return [Integer] the amount of silver, or 0 if not found or on timeout
    #
    # @example
    #   silver = Util.silver_count
    #
    # This method temporarily silences output, sets up a downstream hook to capture the relevant
    # lines, and restores the previous silence state after completion.
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

    # Installs and optionally requires a set of Ruby gems specified in a Hash.
    #
    # @param gems_to_install [Hash{String => Boolean}]
    #   A hash where each key is the name of a gem to install (as a String),
    #   and each value is a Boolean indicating whether to require the gem after installation.
    #
    # @raise [ArgumentError]
    #   If the argument is not a Hash, or if the hash contains keys that are not Strings
    #   or values that are not TrueClass/FalseClass.
    #
    # @raise [RuntimeError]
    #   If any gems fail to install, raises an error listing the failed gems.
    #
    # @example
    #   install_gem_requirements({ "json" => true, "colorize" => false })
    #
    # This method will attempt to install any gems that are not already installed.
    # If a gem is installed and its value is true, it will be required.
    # If installation fails for any gem, an error will be raised listing all failed gems.
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
  end
end
