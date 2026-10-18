# Refactored Ruby-compatible Settings Implementation

module Lich
  module Common
    require 'sequel'
    # rubocop:disable Lint/RedundantRequireStatement
    require 'set' # Ensure Set is required for Ruby < 3.2, may be removed in future versions
    # rubocop:enable Lint/RedundantRequireStatement

    # settings_proxy.rb is now loaded after Settings module is defined, to allow it to call Settings._log
    # require_relative 'settings/settings_proxy'
    require_relative 'settings/database_adapter'
    require_relative 'settings/path_navigator'

    module Settings
      class CircularReferenceError < StandardError
        def initialize(msg = "Circular Reference Detected")
          super(msg)
        end
      end

      # Logging Configuration
      LOG_LEVEL_NONE = 0
      LOG_LEVEL_ERROR = 1
      LOG_LEVEL_INFO = 2
      LOG_LEVEL_DEBUG = 3

      @@log_level = LOG_LEVEL_NONE # Default: logging disabled
      @@log_prefix = "[SettingsModule]".freeze

      def self.set_log_level(level)
        numeric_level = case level
                        when :none, LOG_LEVEL_NONE then LOG_LEVEL_NONE
                        when :error, LOG_LEVEL_ERROR then LOG_LEVEL_ERROR
                        when :info, LOG_LEVEL_INFO then LOG_LEVEL_INFO
                        when :debug, LOG_LEVEL_DEBUG then LOG_LEVEL_DEBUG
                        else
                          _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "Invalid log level specified: #{level.inspect}. Defaulting to NONE." })
                          LOG_LEVEL_NONE
                        end
        @@log_level = numeric_level
      end

      def self.get_log_level
        @@log_level
      end

      # Internal logging method
      # message_proc is a lambda/proc to delay string construction
      def self._log(level, prefix, message_proc)
        return unless Lich.respond_to?(:log)
        return unless level <= @@log_level

        level_str = case level
                    when LOG_LEVEL_ERROR then "[ERROR]"
                    when LOG_LEVEL_INFO  then "[INFO]"
                    when LOG_LEVEL_DEBUG then "[DEBUG]"
                    else "[UNKNOWN]"
                    end

        begin
          message = message_proc.call
          Lich.log("#{prefix} #{level_str} #{message}")
        rescue => e
          Lich.log("#{prefix} [ERROR] Logging failed: #{e.message} - Original message proc: #{message_proc.source_location if message_proc.respond_to?(:source_location)}")
        end
      end

      # Internal non-destructive correction method (issue from Lich 5.12.6)
      # non-destructive methods (.sort) cannot own a proxy that requires update (.push)
      def self._reattach_live!(proxy)
        script_name = Script.current.name
        scope       = proxy.scope
        path        = proxy.path

        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "reattach_live!: scope=#{scope.inspect} path=#{path.inspect}" })

        @path_navigator.reset_path
        @path_navigator.set_path(path)
        live, _root = @path_navigator.navigate_to_path(script_name, true, scope)

        if live.nil?
          _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "reattach_live!: failed to resolve live target for path=#{path.inspect} scope=#{scope.inspect}" })
          return false
        end

        # Swap the proxy onto the live object via SettingsProxy API (encapsulated)
        # Centralizes invariants/logging within SettingsProxy itself.
        proxy.rebind_to_live!(live)
        true
      end

      @db_adapter = DatabaseAdapter.new(DATA_DIR, :script_auto_settings)
      @path_navigator = PathNavigator.new(@db_adapter)
      @settings_cache = {}
      # cache_key => [data_version, root]: the database's data_version just
      # before root was read into @settings_cache (see cached_root).
      @cache_versions = {}
      # Held while a root is put in (or dropped from) @settings_cache, so that
      # cached_root can cache a re-read row only if no other thread has
      # changed the cache entry since the read began (see store_in_cache).
      @cache_mutex = Mutex.new
      DEFAULT_SCOPE = ":".freeze
      @safe_navigation_active = false

      def self.container?(value)
        value.is_a?(Hash) || value.is_a?(Array)
      end

      def self.unwrap_proxies(data, visited = Set.new)
        if visited.include?(data.object_id) && (data.is_a?(Hash) || data.is_a?(Array) || data.is_a?(SettingsProxy))
          _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "unwrap_proxies: Circular reference detected for object_id: #{data.object_id}" })
          raise CircularReferenceError.new("Circular reference detected during unwrap_proxies for object_id: #{data.object_id}")
        end

        visited.add(data.object_id) if data.is_a?(Hash) || data.is_a?(Array) || data.is_a?(SettingsProxy)

        result = case data
                 when SettingsProxy
                   _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "unwrap_proxies: Unwrapping SettingsProxy (target_object_id: #{data.target.object_id})" })
                   unwrap_proxies(data.target, visited)
                 when Hash
                   _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "unwrap_proxies: Unwrapping Hash (object_id: #{data.object_id})" })
                   new_hash = {}
                   data.each do |key, value|
                     new_hash[key] = unwrap_proxies(value, visited)
                   end
                   new_hash
                 when Array
                   _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "unwrap_proxies: Unwrapping Array (object_id: #{data.object_id})" })
                   data.map { |item| unwrap_proxies(item, visited) }
                 else
                   data
                 end

        visited.delete(data.object_id) if data.is_a?(Hash) || data.is_a?(Array) || data.is_a?(SettingsProxy)
        result
      end
      private_class_method :unwrap_proxies

      # Creates a root-level SettingsProxy for the given scope.
      #
      # This factory ensures the proxy directly targets the cached root object
      # for the (script_name, scope) pair. By using the cached root, it avoids
      # "identity drift" bugs where the proxy's @target differs from the object
      # being persisted by save_proxy_changes.
      #
      # @param scope [String] A logical scope identifier (for example,
      #   "#{XMLData.game}:#{XMLData.name}").
      # @param script_name [String, nil] The script namespace; defaults to
      #   Script.current.name. Pass nil to fall back to the empty string.
      #
      # @return [SettingsProxy] a proxy wrapping the cached root object.
      #
      # @raise [ArgumentError] if scope is nil or empty.
      #
      # @example Create a root proxy for the current character
      #   settings = Lich::Common::Settings.root_proxy_for("#{XMLData.game}:#{XMLData.name}")
      #
      def self.root_proxy_for(scope, script_name: Script.current.name)
        raise ArgumentError, "scope must be a non-empty String" if scope.nil? || scope.to_s.strip.empty?

        script_name ||= ""
        root = cached_root(script_name, scope)

        SettingsProxy.new(self, scope, [], root, script_name: script_name)
      end

      # Saves a change made through +proxy+ without losing what other sessions
      # saved in the meantime, in the same container or elsewhere in the row.
      #
      # Every Lich session is a separate process, and a proxy holds this
      # session's copy of one container, read some time before the write. So
      # the operation itself (+method+ with +args+ and +block+, already applied
      # to proxy.target) is applied again to the container at proxy.path in the
      # row as it is stored now, and the row is stored only if no one changed
      # it in between (DatabaseAdapter#update_settings starts over otherwise).
      # Missing containers on the way are created, as before.
      #
      # This session's copy of the container is stored instead (as every
      # nested write did before) when there is no operation to replay
      # (+method+ nil), when the proxy is a detached view with a path (its
      # contents are not the container's), when the stored row has no
      # container of the proxy's class at its path (another session removed or
      # replaced it), or when the operation raises on the stored container. A
      # detached view without a path (an element yielded by each) is not
      # stored at all, as before. Nor is the proxy of a view's element that
      # can't be found in the settings (SettingsProxy#unlocated?), and the
      # user is told.
      #
      # On success the cache takes the row as stored. On failure the cache is
      # left as it was, and the next read checks the database again.
      #
      # @param proxy [SettingsProxy] the proxy the change was made through
      # @param method [Symbol, nil] the operation applied to proxy.target
      # @param args [Array] its arguments; they are stored as copies (proxies
      #   unwrapped, everything copied as a read of the stored row would give
      #   it back), so the stored and cached row share no object with them
      # @param block [Proc, nil] its block
      # @return [Array(Object, Hash|Array), nil] when the operation was
      #   replayed and stored: its result on the stored container, and that
      #   container (part of the row now cached); nil otherwise
      def self.save_proxy_changes(proxy, method = nil, args = [], block = nil)
        path        = proxy.path
        scope       = proxy.scope
        # Use proxy.script_name if available (for InstanceSettings), fall back to Script.current.name
        script_name = proxy.respond_to?(:script_name) && proxy.script_name ? proxy.script_name : Script.current.name
        cache_key   = "#{script_name || ""}::#{scope}"
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "save_proxy_changes: scope: #{scope.inspect}, path: #{path.inspect}, method: #{method.inspect}, script_name: #{script_name.inspect}" })
        # Whatever happens below (a save, a failed save, an early return), the
        # next read checks the database again instead of trusting the cache.
        @cache_versions.delete(cache_key)

        if script_name.nil? || script_name.empty?
          _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "save_proxy_changes: Aborting save. script_name is nil or empty. Scope: #{scope.inspect}. Data will NOT be persisted." })
          return nil
        end

        if proxy.respond_to?(:detached?) && proxy.detached?
          if proxy.respond_to?(:unlocated?) && proxy.unlocated?
            return refuse_proxy_save(script_name, proxy, "this element of a view (select, sort, each, ...) is not found in the settings it was taken from")
          end
          if path.empty?
            _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "save_proxy_changes: Detached view without a path; nothing to save." })
            return nil
          end
          method = nil
        end

        begin
          stored_args = stored_copy(args)
        rescue TypeError => e
          return refuse_proxy_save(script_name, proxy, "an argument of #{method} can't be stored (#{e.message})")
        end
        replayed = nil
        stored = @db_adapter.update_settings(script_name, scope) do |fresh_root|
          replayed = nil
          apply_to_stored_row(fresh_root, proxy, method, stored_args, block, script_name) { |result| replayed = result }
        end
        return nil unless stored

        store_in_cache(cache_key, stored)
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "save_proxy_changes: Saved #{path.inspect} for #{cache_key} (#{replayed ? "replayed #{method}" : "this session's copy"}); cache now holds the stored row." })
        replayed
      end

      # Applies a proxy's change to +root+, the row as stored. Yields
      # [result, container] when +method+ was replayed on the container.
      #
      # @return [Hash, nil] the row to store, or nil to store nothing
      def self.apply_to_stored_row(root, proxy, method, args, block, script_name)
        path = proxy.path
        unless root.is_a?(Hash)
          return refuse_proxy_save(script_name, proxy, "settings are stored as #{root.class}, not a Hash")
        end

        parent = path.empty? ? nil : container_at(root, path[0...-1])
        unless path.empty? || parent.is_a?(Hash) || (parent.is_a?(Array) && path.last.is_a?(Integer) && path.last >= 0)
          return refuse_proxy_save(script_name, proxy, "#{path.inspect} does not lead to a container")
        end

        existing = path.empty? ? root : parent[path.last]
        if method && existing.instance_of?(proxy.target.class)
          begin
            result = existing.public_send(method, *args, &block)
            yield [result, existing]
            return root
          rescue StandardError => e
            _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "save_proxy_changes: #{method} raised #{e.class} (#{e.message}) on the stored container at #{path.inspect}; storing this session's copy" })
          end
        end

        begin
          copy = stored_copy(proxy.target)
        rescue TypeError => e
          return refuse_proxy_save(script_name, proxy, "#{path.inspect} can't be stored (#{e.message})")
        end
        if path.empty?
          return copy if copy.is_a?(Hash)

          return refuse_proxy_save(script_name, proxy, "a #{copy.class} can't be the whole row")
        end

        parent[path.last] = copy
        root
      end
      private_class_method :apply_to_stored_row

      # A copy of +value+, with proxies unwrapped, that shares no object with
      # it (not even a String), as a read of the stored row would give it back.
      #
      # @raise [TypeError] when +value+ can't be stored (a Proc, a Hash with a
      #   default proc, an object with singleton methods, ...)
      def self.stored_copy(value)
        Marshal.load(Marshal.dump(unwrap_proxies(value)))
      end
      private_class_method :stored_copy

      # The container at +segments+ under +root+, creating missing (or nil)
      # Hash and Array entries on the way, as nested saves always have. An
      # Integer segment that comes next makes an Array, anything else a Hash.
      #
      # @return [Hash, Array, nil] nil when a segment can't be followed: a
      #   value that is not a container, or an Array index that is not a
      #   non-negative Integer
      def self.container_at(root, segments)
        segments.each_with_index.reduce(root) do |node, (seg, idx)|
          return nil unless node.is_a?(Hash) || (node.is_a?(Array) && seg.is_a?(Integer) && seg >= 0)

          node[seg] = segments[idx + 1].is_a?(Integer) ? [] : {} if node[seg].nil?
          node[seg]
        end
      end
      private_class_method :container_at

      # Tells the user that a write through a proxy could not be saved.
      #
      # @return nil
      def self.refuse_proxy_save(script_name, proxy, reason)
        message = "--- Error: settings for #{script_name} (#{proxy.scope}) not saved: #{reason} ---"
        _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "save_proxy_changes: #{message}" })
        Lich::Messaging.msg("error", message) if defined?(Lich::Messaging)
        nil
      end
      private_class_method :refuse_proxy_save

      def self.current_script_settings(scope = DEFAULT_SCOPE, script_name: nil)
        # Use provided script_name or fall back to Script.current.name
        script_name = script_name || Script.current.name
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "current_script_settings: Request for scope: #{scope.inspect}, script_name: #{script_name.inspect}" })
        cached_root(script_name, scope).dup
      end

      # Returns this process's cached root for (script_name, scope), reading it
      # from the database first when it is not cached or may have changed.
      #
      # Every Lich session is a separate process with its own cache, and all
      # of them share lich.db3. A cached row is used only while the database's
      # data_version (DatabaseAdapter#data_version) is the one seen just before
      # the row was read; any commit since then, by another session or by this
      # one, changes it, and the row is read again. The check is one pragma on
      # an idle connection, so a read of an unchanged database still costs no
      # query of the settings table. The version is only good for the object
      # it was taken for: code that puts another object in the cache (a write)
      # makes the next read check again.
      #
      # When the version can't be read (another process is committing or holds
      # the lock), the cached row is used, as it was before this check
      # existed. When the row itself can't be read for a database error, a
      # cached row is used rather than raising into the script; with nothing
      # cached, the error is raised as before.
      #
      # A re-read row is cached only if no other thread changed the cache
      # entry while it was read; a later row (a write, a newer re-read) is
      # never replaced by an older one. The row is returned either way.
      #
      # @return [Hash, Array, Object] the cached root itself (not a copy), or
      #   a freshly read row that another thread's change kept out of the cache
      def self.cached_root(script_name, scope)
        cache_key = "#{script_name || ""}::#{scope}"
        version = @db_adapter.data_version
        cached = @settings_cache[cache_key]
        if cached
          stamp = @cache_versions[cache_key]
          if version.nil? || (stamp && stamp[0] == version && stamp[1].equal?(cached))
            _log(LOG_LEVEL_INFO, @@log_prefix, -> { "cached_root: Cache hit for #{cache_key} (object_id: #{cached.object_id}, data_version: #{version.inspect})" })
            return cached
          end
        end

        begin
          root = @db_adapter.get_settings(script_name, scope)
        rescue Sequel::Error, SQLite3::Exception => e
          raise unless cached

          _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "cached_root: Could not re-read #{cache_key} (#{e.class}: #{e.message}); using the cached row." })
          return cached
        end
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "cached_root: Loaded #{cache_key} from DB (object_id: #{root.object_id}, data_version: #{version.inspect})" })
        # Another thread may have put a newer row in the cache while this one
        # was reading (its own write, or a re-read that began later), or
        # dropped it (Settings.load). This row is cached only if the entry is
        # still the one seen above; otherwise it is returned without caching.
        cached_now = @cache_mutex.synchronize do
          next false unless @settings_cache[cache_key].equal?(cached)

          @settings_cache[cache_key] = root
          @cache_versions[cache_key] = [version, root]
          true
        end
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "cached_root: #{cache_key} changed in the cache while it was read; not caching this copy" }) unless cached_now
        root
      end
      private_class_method :cached_root

      # Puts root in the cache for cache_key. Every write that replaces a
      # cached root goes through here, holding @cache_mutex, so that it can't
      # land between cached_root's check that the entry is unchanged and its
      # own assignment (which would put an older row over this one).
      #
      # @return root
      def self.store_in_cache(cache_key, root)
        @cache_mutex.synchronize { @settings_cache[cache_key] = root }
      end
      private_class_method :store_in_cache

      def self.save_to_database(data_to_save, scope = DEFAULT_SCOPE, script_name: nil)
        # Use provided script_name or fall back to Script.current.name
        script_name = script_name || Script.current.name

        if script_name.nil? || script_name.empty?
          _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "save_to_database: Aborting save. script_name is nil or empty. Scope: #{scope.inspect}. Data will NOT be persisted." })
          return nil # Explicitly return nil
        end

        cache_key = "#{script_name}::#{scope}" # script_name is guaranteed to be non-nil/non-empty here
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "save_to_database: Saving for script: '#{script_name}', scope: #{scope.inspect}, cache_key: #{cache_key}" })
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "save_to_database: Data BEFORE unwrap_proxies (object_id: #{data_to_save.object_id}): #{data_to_save.inspect}" })

        unwrapped_settings = unwrap_proxies(data_to_save)
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "save_to_database: Data AFTER unwrap_proxies (object_id: #{unwrapped_settings.object_id}): #{unwrapped_settings.inspect}" })

        @db_adapter.save_settings(script_name, unwrapped_settings, scope)
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "save_to_database: Data saved to DB for script '#{script_name}'." })

        store_in_cache(cache_key, unwrapped_settings)
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "save_to_database: Cache updated for #{cache_key} with saved data (object_id: #{@settings_cache[cache_key].object_id})." })
      end

      def self.refresh_data(scope = DEFAULT_SCOPE)
        script_name = Script.current.name
        cache_key = "#{script_name || ""}::#{scope}" # Use an empty string if script_name is nil
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "refresh_data: Deleting cache for scope: #{scope.inspect}, cache_key: #{cache_key}" })
        @cache_mutex.synchronize do
          @settings_cache.delete(cache_key)
          @cache_versions.delete(cache_key)
        end
        current_script_settings(scope)
      end

      def self.reset_path_and_return(value)
        @path_navigator.reset_path_and_return(value)
      end

      def self.navigate_to_path(create_missing = true, scope = DEFAULT_SCOPE)
        root_for_scope = current_script_settings(scope)
        return [root_for_scope, root_for_scope] if @path_navigator.path.empty?

        target = root_for_scope
        @path_navigator.path.each do |key|
          if target.is_a?(Hash) && target.key?(key)
            target = target[key]
          elsif target.is_a?(Array) && key.is_a?(Integer) && key >= 0 && key < target.length
            target = target[key]
          elsif create_missing && (target.is_a?(Hash) || target.is_a?(Array))
            _log(LOG_LEVEL_INFO, @@log_prefix, -> { "navigate_to_path: Creating missing segment '#{key}' in DUPPED structure for scope #{scope.inspect}" })
            new_node = key.is_a?(Integer) ? [] : {}
            if target.is_a?(Hash)
              target[key] = new_node
            elsif target.is_a?(Array) && key.is_a?(Integer)
              target[key] = new_node
            end
            target = new_node
          else
            return [nil, root_for_scope]
          end
        end
        [target, root_for_scope]
      end

      def self.set_script_settings(scope = DEFAULT_SCOPE, name, value, script_name: nil)
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "set_script_settings: scope: #{scope.inspect}, name: #{name.inspect}, value: #{value.inspect}, script_name: #{script_name.inspect}, current_path: #{@path_navigator.path.inspect}" })
        unwrapped_value = unwrap_proxies(value)
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "set_script_settings: unwrapped_value: #{unwrapped_value.inspect}" })

        unless @path_navigator.path.empty?
          _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "set_script_settings: WARNING: Called with non-empty path_navigator path: #{@path_navigator.path.inspect}. This is unusual for Char/GameSettings direct assignment." })
        end

        write_top_level_key(scope, name, unwrapped_value, script_name: script_name)
        reset_path_and_return(value)
      end

      # Stores one top-level key without rewriting the rest of the row.
      #
      # Other Lich sessions (separate processes) write the same row, and this
      # process's cached copy does not know about their keys. So the key is
      # applied to the row as it is in the database right now, and stored only
      # if no one changed the row in between (DatabaseAdapter#update_settings
      # retries otherwise). The cache then takes the row as stored. If the
      # write fails, the cache is left as it was: it never received the value
      # (the block changes the row just read, not the cached one), and
      # dropping it would send the next read to a database that may still be
      # locked, where get_settings raises into the script. Changes made only to
      # the cached row (for example through SettingsProxy#to_h) are not saved
      # by this write; the stored row replaces them.
      #
      # @return [Hash, nil] the stored row, or nil when nothing was written
      def self.write_top_level_key(scope, name, value, script_name: nil)
        script_name ||= Script.current.name
        if script_name.nil? || script_name.empty?
          _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "write_top_level_key: Aborting save. script_name is nil or empty. Scope: #{scope.inspect}. Data will NOT be persisted." })
          return nil
        end

        cache_key = "#{script_name}::#{scope}"
        stored = @db_adapter.update_settings(script_name, scope) do |fresh_root|
          if fresh_root.is_a?(Hash)
            fresh_root[name] = value
            fresh_root
          else
            _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "write_top_level_key: stored root for scope #{scope.inspect} is not a Hash. Cannot set key '#{name}'. Root class: #{fresh_root.class}" })
            Lich::Messaging.msg("error", "--- Error: Report this - settings for #{script_name} (#{scope}) are stored as #{fresh_root.class}, not a Hash; '#{name}' was not saved ---")
            nil
          end
        end

        if stored
          store_in_cache(cache_key, stored)
          _log(LOG_LEVEL_INFO, @@log_prefix, -> { "write_top_level_key: Saved '#{name}' for #{cache_key}; cache now holds the stored row." })
        else
          _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "write_top_level_key: '#{name}' was NOT saved for #{cache_key}; cache left as it was." })
        end
        stored
      end
      private_class_method :write_top_level_key

      def self.[](name)
        scope_to_use = DEFAULT_SCOPE
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "Settings.[]: name: #{name.inspect}, current_path: #{@path_navigator.path.inspect}, safe_nav: #{@safe_navigation_active}" })

        if @path_navigator.path.empty?
          data_for_scope = current_script_settings(scope_to_use)
          _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "Settings.[] (top-level): data_for_scope (DUP) (object_id: #{data_for_scope.object_id}): #{data_for_scope.inspect}" })
          value = get_value_from_container(data_for_scope, name)
          _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "Settings.[] (top-level): value for '#{name}': #{value.inspect}" })
          if value.nil? && !data_for_scope.is_a?(Array) && (!data_for_scope.is_a?(Hash) || !data_for_scope.key?(name))
            _log(LOG_LEVEL_INFO, @@log_prefix, -> { "Settings.[] (top-level): Key '#{name}' not found or value is nil. Activating safe_navigation." })
            @safe_navigation_active = true
          end
          return reset_path_and_return(wrap_value_if_container(value, scope_to_use, [name]))
        else
          current_target, _ = navigate_to_path(false, scope_to_use)
          _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "Settings.[] (path-based): current_target: #{current_target.inspect}" })
          value = get_value_from_container(current_target, name)
          _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "Settings.[] (path-based): value for '#{name}': #{value.inspect}" })
          new_path = @path_navigator.path + [name]
          if value.nil? && !current_target.is_a?(Array) && (!current_target.is_a?(Hash) || !current_target.key?(name))
            _log(LOG_LEVEL_INFO, @@log_prefix, -> { "Settings.[] (path-based): Key '#{name}' not found or value is nil in path. Activating safe_navigation." })
            @safe_navigation_active = true
          end
          return reset_path_and_return(wrap_value_if_container(value, scope_to_use, new_path))
        end
      end

      def self.[]=(name, value)
        scope_to_use = DEFAULT_SCOPE
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "Settings.[]=: name: #{name.inspect}, value: #{value.inspect}, current_path: #{@path_navigator.path.inspect}" })
        @safe_navigation_active = false # Reset safe navigation on assignment

        if @path_navigator.path.empty?
          set_script_settings(scope_to_use, name, value)
        else
          target, root_settings = navigate_to_path(true, scope_to_use)
          if target && (target.is_a?(Hash) || target.is_a?(Array))
            actual_value = value.is_a?(SettingsProxy) ? unwrap_proxies(value) : value
            target[name] = actual_value
            save_to_database(root_settings, scope_to_use)
            reset_path_and_return(value)
          else
            _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "Settings.[]=: Cannot assign to non-container or nil target at path #{@path_navigator.path.inspect}" })
            reset_path_and_return(nil)
          end
        end
      end

      def self.get_scoped_setting(scope_string, key_name, script_name: nil)
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "get_scoped_setting: scope: #{scope_string.inspect}, key: #{key_name.inspect}, script_name: #{script_name.inspect}" })
        data_for_scope = current_script_settings(scope_string, script_name: script_name)
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "get_scoped_setting: data_for_scope (DUP) (object_id: #{data_for_scope.object_id}): #{data_for_scope.inspect}" })
        value = get_value_from_container(data_for_scope, key_name)
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "get_scoped_setting: value for '#{key_name}': #{value.inspect}" })

        if value.nil? && key_name
          key_absent_in_hash = data_for_scope.is_a?(Hash) && !data_for_scope.key?(key_name)
          key_invalid_for_array = data_for_scope.is_a?(Array) && (!key_name.is_a?(Integer) || key_name < 0 || key_name >= data_for_scope.length)

          if key_absent_in_hash || key_invalid_for_array || (data_for_scope.nil? || (data_for_scope.is_a?(Hash) && data_for_scope.empty?))
            _log(Settings::LOG_LEVEL_INFO, @@log_prefix, -> { "get_scoped_setting: Key '#{key_name}' not found in scope '#{scope_string}'. Value will be nil, supporting '|| default' idiom." })
          end
        end
        wrap_value_if_container(value, scope_string, key_name ? [key_name] : [], script_name: script_name)
      end

      def self.wrap_value_if_container(value, scope, path_array, script_name: nil)
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "wrap_value_if_container: value_class: #{value.class}, scope: #{scope.inspect}, path: #{path_array.inspect}, script_name: #{script_name.inspect}" })
        if container?(value)
          proxy = SettingsProxy.new(self, scope, path_array, value, script_name: script_name)
          _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "wrap_value_if_container: Wrapped in proxy: #{proxy.inspect}" })
          return proxy
        else
          return value
        end
      end

      def self.to_hash(scope = DEFAULT_SCOPE)
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "to_hash: scope: #{scope.inspect}" })
        data = current_script_settings(scope)
        unwrapped_data = unwrap_proxies(data)
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "to_hash: Returning unwrapped data (snapshot): #{unwrapped_data.inspect}" })
        return unwrapped_data
      end

      # Legacy Support Methods
      def self.save
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "Settings.save called (legacy no-op)." })
        :noop
      end

      def self.load
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "Settings.load called (legacy, aliasing to refresh_data)." })
        refresh_data
      end

      def self.to_h(scope = DEFAULT_SCOPE) # Added scope to match to_hash for consistency if used directly
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "Settings.to_h called (legacy, aliasing to to_hash)." })
        self.to_hash(scope)
      end

      # Deprecated No-Op Methods from Original
      def self.save_all
        Lich.deprecated('Settings.save_all', 'not using, not applicable,', caller[0], fe_log: true) if Lich.respond_to?(:deprecated)
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "Settings.save_all called (legacy deprecated no-op)." })
        nil
      end

      def self.clear
        Lich.deprecated('Settings.clear', 'not using, not applicable,', caller[0], fe_log: true) if Lich.respond_to?(:deprecated)
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "Settings.clear called (legacy deprecated no-op)." })
        nil
      end

      def self.auto=(_val)
        Lich.deprecated('Settings.auto=(val)', 'not using, not applicable,', caller[0], fe_log: true) if Lich.respond_to?(:deprecated)
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "Settings.auto= called (legacy deprecated no-op)." })
      end

      def self.auto
        Lich.deprecated('Settings.auto', 'not using, not applicable,', caller[0], fe_log: true) if Lich.respond_to?(:deprecated)
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "Settings.auto called (legacy deprecated no-op)." })
        nil
      end

      def self.autoload
        Lich.deprecated('Settings.autoload', 'not using, not applicable,', caller[0], fe_log: true) if Lich.respond_to?(:deprecated)
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "Settings.autoload called (legacy deprecated no-op)." })
        nil
      end
      # End Legacy Support Methods

      def self.method_missing(method, *args, &block)
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "method_missing: method: #{method}, args: #{args.inspect}, path: #{@path_navigator.path.inspect}" })
        if @safe_navigation_active && !@path_navigator.path.empty?
          if method.to_s.end_with?("=")
            _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "method_missing: Attempted assignment (#{method}) on a nil path due to safe navigation." })
            return reset_path_and_return(nil)
          end
          return reset_path_and_return(nil)
        end

        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "method_missing: Delegating to path_navigator: #{method}" })
        @path_navigator.send(method, *args, &block)
      end

      def self.respond_to_missing?(method_name, include_private = false)
        @path_navigator.respond_to?(method_name, include_private) || super
      end

      def self.get_value_from_container(container, key)
        if container.is_a?(Hash)
          container[key]
        elsif container.is_a?(Array) && key.is_a?(Integer)
          container[key]
        elsif container.is_a?(Array) && !key.is_a?(Integer)
          _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "get_value_from_container: Attempted to access Array with non-Integer key: #{key.inspect}" })
          nil
        else
          nil
        end
      end
    end
  end
end

require_relative 'settings/settings_proxy'
require_relative 'settings/instance_settings'
# Loads row-oriented session summary reporting facade.
# Kept at top-level require boundary so consumers can call
# `Lich::Common::SessionsSettings` without separately requiring internals.
require_relative 'settings/sessions_settings'
