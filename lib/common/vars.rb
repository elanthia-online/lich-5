module Lich
  module Common
    # Provides persistent variable storage per game/character combination.
    # Variables are automatically loaded from SQLite database on first access
    # and periodically saved every 5 minutes via background thread.
    #
    # All keys are normalized to strings for consistent access regardless of
    # whether they're accessed via bracket notation or method syntax.
    #
    # @example Basic usage
    #   Vars['my_var'] = 'value'
    #   Vars['my_var']  #=> 'value'
    #   Vars[:my_var]   #=> 'value' (symbols are converted to strings)
    #
    # @example Using method syntax
    #   Vars.my_var = 'value'
    #   Vars.my_var  #=> 'value'
    #
    # @example Using ||= operator
    #   Vars['config'] ||= { setting: 'default' }
    #
    module Vars
      # @!visibility private
      # Load states for the variables system
      module LoadState
        UNLOADED = :unloaded
        LOADING  = :loading
        LOADED   = :loaded
      end

      @@vars       = Hash.new
      @@md5        = nil
      @@load_state = LoadState::UNLOADED

      # Normalizes a key to a string for consistent storage and retrieval
      #
      # @param key [String, Symbol, Object] the key to normalize
      # @return [String] the normalized string key
      # @api private
      def self.normalize_key(key)
        key.to_s
      end

      # Proc that loads variables from database on first access
      @@load = proc {
        Lich.db_mutex.synchronize {
          if @@load_state == LoadState::UNLOADED
            @@load_state = LoadState::LOADING
            begin
              h = Lich.db.get_first_value(
                'SELECT hash FROM uservars WHERE scope=?;',
                ["#{XMLData.game}:#{XMLData.name}".encode('UTF-8')]
              )
            rescue SQLite3::BusyException
              sleep 0.1
              retry
            end

            if h
              begin
                hash = Marshal.load(h)
                # Normalize all keys to strings during load
                hash.each { |k, v| @@vars[normalize_key(k)] = v }
                @@md5 = Digest::MD5.hexdigest(hash.to_s)
              rescue StandardError => e
                respond "--- Lich: error: #{e}"
                respond e.backtrace[0..2]
              end
            end
            @@load_state = LoadState::LOADED
          end
        }
        nil
      }

      # Proc that saves variables to database if modified
      @@save = proc {
        Lich.db_mutex.synchronize {
          if @@load_state == LoadState::LOADED
            current_md5 = Digest::MD5.hexdigest(@@vars.to_s)
            if current_md5 != @@md5
              @@md5 = current_md5
              blob = SQLite3::Blob.new(Marshal.dump(@@vars))
              begin
                Lich.db.execute(
                  'INSERT OR REPLACE INTO uservars(scope,hash) VALUES(?,?);',
                  ["#{XMLData.game}:#{XMLData.name}".encode('UTF-8'), blob]
                )
              rescue SQLite3::BusyException
                sleep 0.1
                retry
              end
            end
          end
        }
        nil
      }

      # Background thread that auto-saves variables every 5 minutes
      Thread.new {
        loop {
          sleep 300
          begin
            @@save.call
          rescue StandardError => e
            Lich.log "error: #{e}\n\t#{e.backtrace.join("\n\t")}"
            respond "--- Lich: error: #{e}\n\t#{e.backtrace[0..1].join("\n\t")}"
          end
        }
      }

      # Retrieves a variable value by name
      #
      # Keys are normalized to strings, so symbols and strings are equivalent.
      #
      # @param name [String, Symbol] the variable name
      # @return [Object, nil] the variable value, or nil if not set
      #
      # @example
      #   Vars['my_setting']  #=> "some value"
      #   Vars[:my_setting]   #=> "some value" (same result)
      #
      def Vars.[](name)
        @@load.call unless @@load_state == LoadState::LOADED
        @@vars[normalize_key(name)]
      end

      # Sets a variable value by name
      #
      # Keys are normalized to strings, so symbols and strings are equivalent.
      #
      # @param name [String, Symbol] the variable name
      # @param val [Object, nil] the value to set; nil deletes the variable
      # @return [Object, nil] the value that was set
      #
      # @example
      #   Vars['my_setting'] = 'new value'
      #   Vars[:my_setting] = 'new value'  # equivalent
      #   Vars['my_setting'] = nil  # deletes the variable
      #
      def Vars.[]=(name, val)
        @@load.call unless @@load_state == LoadState::LOADED
        key = normalize_key(name)
        if val.nil?
          @@vars.delete(key)
        else
          @@vars[key] = val
        end
      end

      # Returns a duplicate of all variables as a Hash
      #
      # @return [Hash] a copy of all stored variables with string keys
      #
      # @example
      #   all_vars = Vars.list
      #   all_vars.keys  #=> ['var1', 'var2', ...]
      #
      def Vars.list
        @@load.call unless @@load_state == LoadState::LOADED
        @@vars.dup
      end

      # Immediately saves all variables to the database
      #
      # @return [nil]
      #
      # @example
      #   Vars['important'] = 'data'
      #   Vars.save  # Force immediate save instead of waiting for auto-save
      #
      def Vars.save
        @@save.call
      end

      # Handles dynamic method calls for variable access
      #
      # Supports both getter and setter syntax. All keys are normalized to strings.
      # - `Vars.my_var` retrieves variable named "my_var"
      # - `Vars.my_var = value` sets variable named "my_var"
      # - `Vars['key']` and `Vars['key'] = value` also work through this
      #
      # @param method_name [Symbol] the method name being called
      # @param args [Array] arguments passed to the method
      # @return [Object, nil] the variable value or result of setter
      #
      # @example
      #   Vars.my_setting = 'value'
      #   Vars.my_setting  #=> 'value'
      #
      def Vars.method_missing(method_name, *args)
        @@load.call unless @@load_state == LoadState::LOADED

        # Handle []= called through method_missing
        if method_name == :[]= && args.length == 2
          key = normalize_key(args[0])
          if args[1].nil?
            @@vars.delete(key)
          else
            @@vars[key] = args[1]
          end
        # Handle [] called through method_missing
        elsif method_name == :[] && args.length == 1
          @@vars[normalize_key(args[0])]
        # Handle setter methods (e.g., foo=)
        elsif method_name.to_s.end_with?('=')
          key = normalize_key(method_name.to_s.chop)
          if args[0].nil?
            @@vars.delete(key)
          else
            @@vars[key] = args[0]
          end
        # Handle getter methods
        else
          @@vars[normalize_key(method_name.to_s)]
        end
      end

      # Declares that method_missing can respond to valid Ruby method names
      #
      # Only returns true for method names that could be valid Ruby identifiers
      # or the bracket operators. This helps catch obvious typos while still
      # allowing dynamic variable access.
      #
      # @param method_name [Symbol] the method name to check
      # @param include_private [Boolean] whether to include private methods
      # @return [Boolean] true if the method name is a valid variable name
      #
      def Vars.respond_to_missing?(method_name, _include_private = false)
        method_str = method_name.to_s

        # Allow bracket operators
        return true if method_name == :[] || method_name == :[]=

        # Allow valid Ruby method names (with or without trailing =)
        # Valid: starts with letter or underscore, contains letters/digits/underscores
        # and optionally ends with = for setters
        method_str.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*=?\z/)
      end
    end
  end
end
