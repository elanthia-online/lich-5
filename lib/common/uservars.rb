module Lich
  module Common
    # Provides a compatibility layer and additional convenience methods for Vars.
    # This module delegates most operations to {Vars} while providing legacy method
    # support and some additional functionality like comma-separated list management.
    #
    # @see Vars
    #
    # @example Basic delegation
    #   UserVars['my_var'] = 'value'
    #   UserVars.my_var  #=> 'value'
    #
    # @example Managing comma-separated lists
    #   UserVars.change('tags', 'foo, bar')
    #   UserVars.add('tags', 'baz')  #=> 'foo, bar, baz'
    #
    module UserVars
      # Returns a duplicate of all variables as a Hash
      #
      # Delegates to {Vars.list}.
      #
      # @return [Hash] a copy of all stored variables with string keys
      #
      # @example
      #   all_vars = UserVars.list
      #   all_vars.keys  #=> ['var1', 'var2', ...]
      #
      def UserVars.list
        Vars.list
      end

      # Retrieves a variable value by name (bracket notation)
      #
      # Delegates to {Vars.[]}.
      #
      # @param name [String, Symbol] the variable name
      # @return [Object, nil] the variable value, or nil if not set
      #
      def UserVars.[](name)
        Vars[name]
      end

      # Sets a variable value by name (bracket notation)
      #
      # Delegates to {Vars.[]=}.
      #
      # @param name [String, Symbol] the variable name
      # @param val [Object, nil] the value to set; nil deletes the variable
      # @return [Object, nil] the value that was set
      #
      def UserVars.[]=(name, val)
        Vars[name] = val
      end

      # Handles dynamic method calls for variable access
      #
      # Delegates to {Vars.method_missing} to support both getter and setter syntax.
      #
      # @param method_name [Symbol] the method name being called
      # @param args [Array] arguments passed to the method
      # @return [Object, nil] the variable value or result of setter
      #
      # @example
      #   UserVars.my_setting = 'value'
      #   UserVars.my_setting  #=> 'value'
      #
      def UserVars.method_missing(method_name, *args)
        Vars.method_missing(method_name, *args)
      end

      # Declares that method_missing can respond to valid Ruby method names
      #
      # Delegates to {Vars.respond_to_missing?}.
      #
      # @param method_name [Symbol] the method name to check
      # @param include_private [Boolean] whether to include private methods
      # @return [Boolean] true if the method name is a valid variable name
      #
      def UserVars.respond_to_missing?(method_name, include_private = false)
        Vars.respond_to_missing?(method_name, include_private)
      end

      # Sets a variable to a new value
      #
      # This is a convenience method for backward compatibility.
      # The third parameter is ignored and exists for legacy API compatibility.
      #
      # @param var_name [String, Symbol] the variable name
      # @param value [Object] the new value
      # @param _t [Object] unused legacy parameter (ignored)
      # @return [Object] the value that was set
      #
      # @example
      #   UserVars.change('my_var', 'new value')
      #
      def UserVars.change(var_name, value, _t = nil)
        Vars[var_name] = value
      end

      # Adds a value to a comma-separated list variable
      #
      # If the variable contains a comma-separated string, this method appends
      # the new value to the list. If the variable doesn't exist or is nil,
      # it creates a new single-value string.
      #
      # The third parameter is ignored and exists for legacy API compatibility.
      #
      # @param var_name [String, Symbol] the variable name
      # @param value [String] the value to add to the list
      # @param _t [Object] unused legacy parameter (ignored)
      # @return [String] the updated comma-separated list
      #
      # @example
      #   UserVars['tags'] = 'foo, bar'
      #   UserVars.add('tags', 'baz')  #=> 'foo, bar, baz'
      #
      # @note This method assumes the variable contains a comma-separated string.
      #   If the variable contains a different data type, this will raise an error.
      #
      def UserVars.add(var_name, value, _t = nil)
        current = Vars[var_name]
        if current.nil? || current.empty?
          Vars[var_name] = value.to_s
        else
          Vars[var_name] = current.to_s.split(', ').push(value.to_s).join(', ')
        end
      end

      # Deletes a variable by setting it to nil
      #
      # This is a convenience method for backward compatibility.
      # The second parameter is ignored and exists for legacy API compatibility.
      #
      # @param var_name [String, Symbol] the variable name
      # @param _t [Object] unused legacy parameter (ignored)
      # @return [nil]
      #
      # @example
      #   UserVars.delete('my_var')
      #
      def UserVars.delete(var_name, _t = nil)
        Vars[var_name] = nil
      end

      # Returns an empty array (legacy global variables are not supported)
      #
      # This method exists for backward compatibility with older code that
      # expected separate global and character-specific variables. In the
      # current implementation, all variables are character-specific.
      #
      # @return [Array] always returns an empty array
      # @deprecated Use {#list} or {#list_char} instead
      #
      def UserVars.list_global
        Array.new
      end

      # Returns a duplicate of all character-specific variables as a Hash
      #
      # This is an alias for {#list} provided for backward compatibility.
      #
      # @return [Hash] a copy of all stored variables with string keys
      #
      # @example
      #   char_vars = UserVars.list_char
      #   char_vars.keys  #=> ['var1', 'var2', ...]
      #
      def UserVars.list_char
        Vars.list
      end
    end
  end
end
