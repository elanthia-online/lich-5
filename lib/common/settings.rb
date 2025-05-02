# Refactored Ruby-compatible Settings Implementation

module Lich
  module Common
    require 'sequel'

    require_relative 'settings/settings_proxy'
    require_relative 'settings/database_adapter'
    require_relative 'settings/path_navigator'

    module Settings
      # Initialize database adapter and path navigator
      @db_adapter = DatabaseAdapter.new(DATA_DIR, :script_auto_settings)
      @path_navigator = PathNavigator.new(@db_adapter)
      @settings_cache = {}

      # Check if a value is a container (Hash or Array)
      def self.container?(value)
        value.is_a?(Hash) || value.is_a?(Array)
      end

      # Recursively unwraps SettingsProxy instances within a data structure
      def self.unwrap_proxies(data)
        case data
        when SettingsProxy
          # If it's a proxy, unwrap its target recursively
          unwrap_proxies(data.target)
        when Hash
          # If it's a hash, create a new hash with unwrapped values
          data.each_with_object({}) do |(key, value), new_hash|
            new_hash[key] = unwrap_proxies(value)
          end
        when Array
          # If it's an array, create a new array with unwrapped elements
          data.map { |item| unwrap_proxies(item) }
        else
          # Otherwise (scalar), return the data as is
          data
        end
      end
      private_class_method :unwrap_proxies

      # Save changes from a proxy back to the database
      def self.save_proxy_changes(proxy)
        path = proxy.path
        return if path.empty?

        # Get the root settings hash from cache or database
        script_name = Script.current.name
        scope = ":"
        cache_key = "#{script_name}::#{scope}"

        # Use cached settings if available
        current = @settings_cache[cache_key] || current_script_settings(scope)

        # Navigate to the parent container
        parent = current
        parent_path = path[0...-1]

        parent_path.each do |key|
          parent = parent[key]
        end

        # Update the value at the final location with the unwrapped target
        parent[path.last] = proxy.target

        # Update cache and save to database (save_to_database will handle further unwrapping if needed)
        @settings_cache[cache_key] = current
        save_to_database(current, scope)
      end

      # Database operations
      def self.current_script_settings(scope = ":")
        script_name = Script.current.name
        cache_key = "#{script_name}::#{scope}"

        # Check cache first
        return @settings_cache[cache_key] if @settings_cache[cache_key]

        # Get from database and update cache
        settings = @db_adapter.get_settings(script_name, scope)
        @settings_cache[cache_key] = settings
        settings
      end

      def self.save_to_database(current, scope = ":")
        script_name = Script.current.name
        cache_key = "#{script_name}::#{scope}"

        # Recursively unwrap any SettingsProxy instances before saving
        unwrapped_settings = unwrap_proxies(current)

        # Pass the unwrapped settings to the database adapter
        @db_adapter.save_settings(script_name, unwrapped_settings, scope)

        # Expire cache key to force reload of saved values
        @settings_cache.delete(cache_key) if @settings_cache.has_key?(cache_key)
      end

      def self.refresh_data(scope = ":")
        # Requests made directly to this method want a refreshed set of data.
        # Aliased to Settings.load for backwards compatibility.
        script_name = Script.current.name
        cache_key = "#{script_name}::#{scope}"
        @settings_cache.delete(cache_key) if @settings_cache.has_key?(cache_key)

        current_script_settings(scope)
      end

      # Path navigation helpers
      def self.reset_path_and_return(value)
        @path_navigator.reset_path_and_return(value)
      end

      def self.navigate_to_path(create_missing = true, scope = ":")
        script_name = Script.current.name
        cache_key = "#{script_name}::#{scope}"

        # Use cached settings if available
        if @settings_cache[cache_key]
          root = @settings_cache[cache_key]
          return [root, root] if @path_navigator.path.empty?

          target = root
          @path_navigator.path.each do |key|
            if target.is_a?(Hash) && target.key?(key)
              target = target[key]
            elsif target.is_a?(Array) && key.is_a?(Integer) && key < target.length
              target = target[key]
            elsif create_missing
              # Path doesn't exist yet, create it
              target[key] = key.is_a?(Integer) ? [] : {}
              target = target[key]
            else
              # Path doesn't exist and we're not creating it
              return [nil, root]
            end
          end

          [target, root]
        else
          # If not in cache, use the PathNavigator's method which reads from DB
          @path_navigator.navigate_to_path(script_name, create_missing, scope)
        end
      end

      # Core methods
      def self.set_script_settings(scope = ":", name, value)
        # Unwrap the value before assigning it to prevent proxies from entering the structure
        unwrapped_value = unwrap_proxies(value)

        if @path_navigator.path.empty?
          # Direct assignment to top-level key
          current = current_script_settings(scope)
          current[name] = unwrapped_value
          save_to_database(current, scope)
        else
          # Navigate to the correct location in the hash
          target, current = navigate_to_path(true, scope)

          # Set the unwrapped value at the final location
          target[name] = unwrapped_value

          # Save the updated hash to the database
          save_to_database(current, scope)
        end

        # Reset path after setting
        reset_path_and_return(value) # Return original value/proxy as per convention
      end

      def self.[](name)
        if @path_navigator.path.empty?
          # Top-level access
          value = current_script_settings[name]

          if value.nil?
            # For nil values, return nil but set up for safe navigation
            # This allows Settings[:non_existent][:deeper] to return nil without errors
            @safe_navigation_active = true
            return nil
          else
            @safe_navigation_active = false
            return wrap_value_if_container(value, [name])
          end
        else
          # Check if we're in safe navigation mode (previous access returned nil)
          if @safe_navigation_active
            @path_navigator.reset_path
            return nil
          end

          # Normal nested access
          target, _ = navigate_to_path(false) # Don't create missing paths

          # If target is nil, return nil and activate safe navigation
          if target.nil?
            @path_navigator.reset_path
            @safe_navigation_active = true
            return nil
          end

          # Access the requested key
          if container?(target)
            value = get_value_from_container(target, name)

            if value.nil?
              @path_navigator.reset_path
              @safe_navigation_active = true
              return nil
            else
              @safe_navigation_active = false
              new_path = @path_navigator.path.dup
              new_path << name
              @path_navigator.reset_path
              return wrap_value_if_container(value, new_path)
            end
          else
            # Reset path if target is not a container
            @path_navigator.reset_path
            @safe_navigation_active = true
            return nil
          end
        end
      end

      # Helper method to get a value from a container
      def self.get_value_from_container(container, key)
        if container.is_a?(Hash) && container.key?(key)
          container[key]
        elsif container.is_a?(Array) && key.is_a?(Integer) && key < container.length
          container[key]
        else
          nil
        end
      end

      # Helper method to wrap a value in a proxy if it's a container
      def self.wrap_value_if_container(value, path)
        if container?(value)
          SettingsProxy.new(self, path, value)
        else
          value
        end
      end

      def self.[]=(name, value)
        set_script_settings(name, value)
      end

      def self.method_missing(method, *args, &block)
        # Only handle method_missing if we're in a path context
        return super if @path_navigator.path.empty?

        # Navigate to the current path
        target, current = navigate_to_path(true)

        # Handle the method call
        if target.respond_to?(method)
          # For non-destructive methods, operate on a duplicate to avoid modifying original
          if SettingsProxy::NON_DESTRUCTIVE_METHODS.include?(method)
            # Create a duplicate of the target for non-destructive operations
            target_dup = target.dup
            result = target_dup.send(method, *args, &block)

            # Return the result without saving changes
            return handle_non_destructive_result(result)
          else
            # For destructive methods, operate on the original and save changes
            # Unwrap arguments if they are SettingsProxy instances
            unwrapped_args = args.map { |arg| unwrap_proxies(arg) }
            result = target.send(method, *unwrapped_args, &block)
            save_to_database(current)
            return handle_method_result(result)
          end
        else
          # Method not supported
          reset_path_and_return(nil)
          super
        end
      end

      # Helper method to handle results of non-destructive methods
      def self.handle_non_destructive_result(result)
        # Reset path immediately
        @path_navigator.reset_path

        if result.is_a?(Hash) || result.is_a?(Array)
          # For container results, wrap in a new proxy with empty path
          SettingsProxy.new(self, [], result)
        else
          result
        end
      end

      # Helper method to handle results of destructive methods
      def self.handle_method_result(result)
        path = @path_navigator.path.dup
        @path_navigator.reset_path

        if result.is_a?(Hash) || result.is_a?(Array)
          # For container results, wrap in a new proxy with current path
          SettingsProxy.new(self, path, result)
        else
          result
        end
      end

      def self.respond_to_missing?(method, include_private = false)
        return true if !@path_navigator.path.empty?

        super
      end

      def self.to_h
        # Return unwrapped hash
        unwrap_proxies(current_script_settings)
      end

      def self.to_hash(scope = ":")
        # Return unwrapped hash
        unwrap_proxies(current_script_settings(scope))
      end

      def self.save
        # :noop
      end

      # Query methods
      def self.empty?
        return false if @path_navigator.path.empty?

        target, _ = navigate_to_path(false)
        return reset_path_and_return(true) if target.nil?

        reset_path_and_return(target.empty?)
      end

      def self.include?(item)
        return false if @path_navigator.path.empty?

        target, _ = navigate_to_path(false)
        return reset_path_and_return(false) if target.nil?

        # Unwrap item before checking inclusion
        unwrapped_item = unwrap_proxies(item)
        reset_path_and_return(target.is_a?(Array) ? target.include?(unwrapped_item) : false)
      end

      def self.load # pulled from Deprecated calls to alias to refresh_data()
        refresh_data()
      end

      # Deprecated calls
      def Settings.save_all
        Lich.deprecated('Settings.save_all', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end

      def Settings.clear
        Lich.deprecated('Settings.clear', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end

      def Settings.auto=(_val)
        Lich.deprecated('Settings.auto=(val)', 'not using, not applicable,', caller[0], fe_log: true)
      end

      def Settings.auto
        Lich.deprecated('Settings.auto', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end

      def Settings.autoload
        Lich.deprecated('Settings.autoload', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end
    end
  end
end
# This code is a refactored Sequel based version of the original Lich settings implementation.
