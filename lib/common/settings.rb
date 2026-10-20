# Refactored Ruby-compatible Settings Implementation

module Lich
  module Common
    require 'sequel'
    # rubocop:disable Lint/RedundantRequireStatement
    require 'set' # Ensure Set is required for Ruby < 3.2, may be removed in future versions
    # rubocop:enable Lint/RedundantRequireStatement
    require 'monitor'

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
      #
      # Binds +proxy+, a detached view with a path (what sort or select
      # returned), to the container at its path in the row of the proxy's
      # own script (InstanceSettings has its own) as stored now, so that the
      # destructive +method+ about to be called through it changes that
      # container and is stored there (list.sort.push(4) appends 4 to list).
      #
      # When the stored row holds nothing there (another session removed the
      # container, or a container on the way), the view is bound to this
      # session's copy of the container it was taken from, when that is of
      # the view's kind, and the call is stored from that copy, as through a
      # proxy for the container itself (Settings[:list].push(4) after another
      # session removed list stores this session's list with 4 appended).
      #
      # The path is passed to the navigator, not set on it: the navigator is
      # shared by every script's Settings[] calls, and a path left on it
      # would send the next top-level write somewhere else.
      #
      # Returns false, binding nothing, and tells the user, when the stored
      # row holds a container of another kind there (a Hash where values
      # returned an Array) or something that is not a container, or holds
      # nothing there and the copy the view was taken from is of another
      # kind.
      def self._reattach_live!(proxy, method = nil)
        script_name = proxy_script_name(proxy)
        scope       = proxy.scope
        path        = proxy.path

        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "reattach_live!: scope=#{scope.inspect} path=#{path.inspect}" })

        live, _root = @path_navigator.navigate_to_path(script_name, false, scope, path)
        if live.nil?
          own_copy = proxy.__send__(:view_source)
          live = own_copy if own_copy.instance_of?(proxy.target.class)
        end

        unless live.instance_of?(proxy.target.class)
          _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "reattach_live!: failed to resolve live target for path=#{path.inspect} scope=#{scope.inspect}" })
          what = live.nil? ? "nothing there" : "#{live.class} there, and the view is #{proxy.target.class}"
          refuse_proxy_save(script_name, proxy, "#{method || "the call"} on a view (sort, select, values, ...) of #{path.inspect} was not applied: the settings hold #{what}", kind: :view_not_applied)
          return false
        end

        # Swap the proxy onto the live object via SettingsProxy API (encapsulated)
        # Centralizes invariants/logging within SettingsProxy itself. The
        # rebinding (and view_source) is private to SettingsProxy; this is
        # its one caller.
        proxy.__send__(:rebind_to_live!, live)
        true
      end

      @db_adapter = DatabaseAdapter.new(DATA_DIR, :script_auto_settings)
      @path_navigator = PathNavigator.new(@db_adapter)
      @settings_cache = {}
      # cache_key => [data_version, root]: the database's data_version just
      # before root was read into @settings_cache (see cached_root).
      @cache_versions = {}
      # cache_key => [data_version, root]: the data_version taken just before
      # the read that put root in @settings_cache (cached_root's re-read or
      # cache-miss fill), whether or not it was also recorded in
      # @cache_versions. A write compares it with the version seen after its
      # own store (see store_after_database).
      @reread_versions = {}
      # Held while a root is put in @settings_cache, so that cached_root can
      # cache a re-read row only if no other thread has changed the cache
      # entry since the read began (see store_in_cache).
      @cache_mutex = Mutex.new
      # One lock per cache entry (script and scope), see with_cache_lock.
      @cache_locks = {}
      @cache_locks_guard = Mutex.new
      DEFAULT_SCOPE = ":".freeze
      @safe_navigation_active = false

      # Runs the block holding the lock for one cache entry.
      #
      # Every write (top-level, nested through a SettingsProxy, or a whole row)
      # and every fill after a cache miss runs its database calls and its cache
      # update under the entry's lock. Without it, two threads can finish in
      # one order in the database and in the other order in the cache: the
      # cache then holds an older row over a newer one, and this process's
      # reads miss the newer keys until the row is written again. Cache hits
      # do not take the lock, and neither does re-reading a cached row after a
      # commit (see cached_root), so it never waits for a write in progress:
      # that re-read is cached only if the entry is unchanged, and while
      # another thread holds the lock it is cached without a version (the
      # lock is taken without waiting, then @cache_mutex).
      #
      # Lock order: an entry's lock, then @cache_mutex. @cache_mutex is never
      # held while taking an entry's lock.
      #
      # The lock is per entry, so a top-level write retrying while another
      # session keeps changing the row holds up only threads using the same
      # script and scope, not every script (its pauses release the GVL). A
      # write waiting for a locked database is different: SQLite's busy
      # timeout waits with the GVL held, so it stalls every thread of the
      # process whatever lock it holds.
      #
      # A Monitor, so a write that calls another write for the same entry in
      # the same thread does not deadlock. Lich's own code never takes two
      # entries' locks at once. The block of an in-place method called through
      # a SettingsProxy (delete_if { ... }) runs under its entry's lock, on
      # this session's copy and again when it is replayed (see
      # with_proxy_lock and save_proxy_changes); a block that reads another
      # entry not yet cached takes that entry's lock as well. Such blocks must
      # have no side effects (SettingsProxy::MUTATING_METHODS), and shipped
      # scripts' are plain predicates.
      def self.with_cache_lock(cache_key, &block)
        cache_lock(cache_key).synchronize(&block)
      end
      private_class_method :with_cache_lock

      # The Monitor behind with_cache_lock for cache_key, created on first use.
      def self.cache_lock(cache_key)
        @cache_locks_guard.synchronize { @cache_locks[cache_key] ||= Monitor.new }
      end
      private_class_method :cache_lock

      # The adapter for the shared script_auto_settings table. For core code
      # that needs a fresh read or an atomic write, which the cached
      # Settings API doesn't offer (see DRBanking).
      # @return [DatabaseAdapter]
      def self.db_adapter
        @db_adapter
      end

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
      # replaced it), or when the operation raises on the stored container.
      # Nothing is stored, and the user is told, for a detached proxy without
      # a path (a view of a root proxy, the default fetch returned, or a
      # container built from one), nor for the
      # proxy of a view's element that can't be found in the settings
      # (SettingsProxy#unlocated?), nor for a new container built from an
      # element SettingsProxy#each yielded (SettingsProxy#copy?). Nothing is
      # stored either, and the user is told, when +block+ leaves early (break, throw or return), is
      # interrupted or its thread is killed while it runs on the stored
      # container.
      #
      # On success the cache takes the row as stored, unless another thread
      # has re-read a newer one after the store (see store_after_database). On
      # failure the cache is left as it was, and the next read checks the
      # database again. All of it runs under the cache entry's lock (see
      # with_cache_lock).
      #
      # @param proxy [SettingsProxy] the proxy the change was made through
      # @param method [Symbol, nil] the operation applied to proxy.target, or
      #   REPLAY_ENTRY_CHANGES for the entries a script's call changed
      # @param args [Array] its arguments; they are stored as copies (proxies
      #   unwrapped, everything copied as a read of the stored row would give
      #   it back), so the stored and cached row share no object with them
      # @param block [Proc, nil] its block
      # @param label [Symbol, nil] the script's method that made the change,
      #   named in messages (defaults to +method+)
      # @return [Array(Object, Hash|Array), nil] when the operation was
      #   replayed and stored: its result on the stored container, and that
      #   container (part of the row now cached); nil otherwise
      def self.save_proxy_changes(proxy, method = nil, args = [], block = nil, label: nil)
        script_name = proxy_script_name(proxy)
        with_cache_lock("#{script_name || ""}::#{proxy.scope}") { store_proxy_changes(proxy, script_name, method, args, block, label) }
      end

      # Runs the block holding the lock of +proxy+'s cache entry, the one
      # save_proxy_changes takes (see with_cache_lock). SettingsProxy holds
      # it from the change to its copy until it shows the stored container,
      # so that two threads writing through proxies of one entry show the
      # stored containers in the order they were stored: a slower thread
      # can't put an older one over a newer one.
      def self.with_proxy_lock(proxy, &block)
        with_cache_lock("#{proxy_script_name(proxy) || ""}::#{proxy.scope}", &block)
      end

      # The script whose row +proxy+ writes to: proxy.script_name if it has
      # one (InstanceSettings), otherwise the current script's name.
      def self.proxy_script_name(proxy)
        proxy.respond_to?(:script_name) && proxy.script_name ? proxy.script_name : Script.current.name
      end
      private_class_method :proxy_script_name

      # save_proxy_changes's database write and cache update, under the cache
      # entry's lock (see with_cache_lock). The replayed block runs under that
      # lock too, inside DatabaseAdapter#update_settings.
      def self.store_proxy_changes(proxy, script_name, method, args, block, label)
        path        = proxy.path
        scope       = proxy.scope
        cache_key   = "#{script_name || ""}::#{scope}"
        _log(LOG_LEVEL_DEBUG, @@log_prefix, -> { "save_proxy_changes: scope: #{scope.inspect}, path: #{path.inspect}, method: #{method.inspect}, script_name: #{script_name.inspect}" })
        # Whatever happens below (a save, a failed save, an early return), the
        # next read checks the database again instead of trusting the cache.
        @cache_versions.delete(cache_key)

        if script_name.nil? || script_name.empty?
          _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "save_proxy_changes: Aborting save. script_name is nil or empty. Scope: #{scope.inspect}. Data will NOT be persisted." })
          return nil
        end

        if proxy.respond_to?(:moved?) && proxy.moved?
          return refuse_proxy_save(script_name, proxy, "#{proxy.anchor_path.inspect} no longer holds the element this each loop yielded there (it was removed, replaced or moved in this session), so the write would land on another element", kind: :element_moved)
        end

        if proxy.respond_to?(:copy?) && proxy.copy?
          copied_by = proxy.respond_to?(:copied_by) && proxy.copied_by
          what = copied_by ? "what ##{copied_by} returned" : "a copy (what merge, select, first(2), ... returned)"
          return refuse_proxy_save(script_name, proxy, "this is #{what}, a new container built from an element an each loop yielded: a plain copy, not part of the settings (to store a change, write to the element itself)")
        end

        if proxy.respond_to?(:detached?) && proxy.detached?
          if proxy.respond_to?(:unlocated?) && proxy.unlocated?
            return refuse_proxy_save(script_name, proxy, "this element of a view (select, sort, each, ...) is not found in the settings it was taken from")
          end
          if path.empty?
            cause = proxy.respond_to?(:pathless_cause) && proxy.pathless_cause
            return refuse_proxy_save(script_name, proxy, cause ? "this is #{cause}, not part of the settings" : "this is not part of the settings (a view of the whole settings, the default fetch returned, or a container built from one)")
          end
          label ||= method
          method = nil
        end

        begin
          stored_args = stored_copy(args)
        rescue TypeError => e
          what = method == REPLAY_ENTRY_CHANGES ? "a value changed by #{label || "a method"}" : "an argument of #{label || method}"
          return refuse_proxy_save(script_name, proxy, "#{what} can't be stored (#{e.message})", kind: :argument_not_storable)
        end
        replayed = nil
        # The adapter updates the cache as part of the store (on_stored), as
        # for a top-level write, so a script killed right after the row was
        # committed does not leave the cache without it, and a newer row
        # another thread re-read after the store is kept (see
        # store_after_database).
        cache_stored_row = ->(row) { store_after_database(cache_key, row, @db_adapter.data_version) }
        stored = @db_adapter.update_settings(script_name, scope, on_stored: cache_stored_row) do |fresh_root|
          replayed = nil
          apply_to_stored_row(fresh_root, proxy, method, stored_args, block, script_name, label) { |result| replayed = result }
        end
        return nil unless stored

        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "save_proxy_changes: Saved #{path.inspect} for #{cache_key} (#{replayed ? "replayed #{label || method}" : "this session's copy"})." })
        replayed
      end
      private_class_method :store_proxy_changes

      # Applies a proxy's change to +root+, the row as stored. Yields
      # [result, container] when +method+ was replayed on the container.
      #
      # @return [Hash, nil] the row to store, or nil to store nothing
      def self.apply_to_stored_row(root, proxy, method, args, block, script_name, label = nil)
        path = proxy.path
        unless root.is_a?(Hash)
          return refuse_proxy_save(script_name, proxy, "settings are stored as #{root.class}, not a Hash", kind: :row_not_hash)
        end

        # An element of an Array is addressed by its position. When the stored
        # Array no longer reaches that position, the element this session saw
        # there has moved or gone, so storing this session's copy there would
        # pad the Array with nil or store an element twice.
        classes = proxy.respond_to?(:path_classes) ? proxy.path_classes : nil
        if (array_path = position_gone(root, path, classes))
          return refuse_proxy_save(script_name, proxy, "#{path.inspect} is no longer there (another session removed elements from #{array_path.inspect})", kind: :position_gone)
        end

        parent = path.empty? ? nil : container_at(root, path, classes)
        unless path.empty? || parent.is_a?(Hash) || (parent.is_a?(Array) && path.last.is_a?(Integer) && path.last >= 0)
          return refuse_proxy_save(script_name, proxy, "#{path.inspect} does not lead to a container", kind: :no_container)
        end

        existing = path.empty? ? root : parent[path.last]
        if method && existing.instance_of?(proxy.target.class)
          # A break, throw or return in +block+ that fires only here, on the
          # stored container, leaves this method (and update_settings) before
          # anything is stored, and the rescue below can't catch it. So the
          # user is told that nothing was saved, as for an interrupt.
          # The exception is taken from the rescue clause, not $!, which in a
          # script's own rescue clause is the exception that clause handles.
          finished = false
          begin
            result = case method
                     when REPLAY_ENTRY_CHANGES then replay_entry_changes(existing, *args)
                     when REPLAY_AT_POSITIONS then replay_at_positions(existing, *args, &block)
                     else existing.public_send(method, *args, &block)
                     end
            finished = true
            yield [result, existing]
            return root
          rescue PositionGoneError
            finished = true
            return refuse_proxy_save(script_name, proxy, "#{label || method} changed a position of #{path.inspect} that is no longer there (another session removed elements from it)", kind: :position_gone)
          rescue StandardError => e
            finished = true
            _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "save_proxy_changes: #{label || method} raised #{e.class} (#{e.message}) on the stored container at #{path.inspect}; storing this session's copy" })
          rescue Exception => e # rubocop:disable Lint/RescueException -- reported, then raised again
            finished = true
            refuse_proxy_save(script_name, proxy, "#{label || method} was interrupted (#{e.class}) while it ran on the stored settings", kind: :interrupted)
            raise
          ensure
            unless finished
              how = Thread.current.status == "aborting" ? "was stopped (its thread was killed)" : "left early (break, throw or return)"
              refuse_proxy_save(script_name, proxy, "#{label || method} #{how} while it ran on the stored settings", kind: :left_early)
            end
          end
        end

        begin
          copy = stored_copy(proxy.target)
        rescue TypeError => e
          return refuse_proxy_save(script_name, proxy, "#{path.inspect} can't be stored (#{e.message})", kind: :copy_not_storable)
        end
        if path.empty?
          return copy if copy.is_a?(Hash)

          return refuse_proxy_save(script_name, proxy, "a #{copy.class} can't be the whole row", kind: :copy_not_hash)
        end

        parent[path.last] = copy
        root
      end
      private_class_method :apply_to_stored_row

      # The operation save_proxy_changes replays for a method outside both of
      # SettingsProxy's method lists that changed several entries of a
      # container (SettingsProxy#save_changes_since). Its one argument is the
      # list of [operation, args] entry changes ([:delete, [key]] or
      # [:[]=, [key_or_index, value]]); they are all applied, in order, in one
      # update of the row (see #replay_entry_changes).
      REPLAY_ENTRY_CHANGES = :replay_entry_changes

      # The operation save_proxy_changes replays for an Array method whose
      # arguments include a position (SettingsProxy::POSITION_METHODS). Its
      # arguments are [size, first_changed, method, args]: the size of this
      # session's copy before the call, the first position the call changed
      # in that copy (nil when it changed none), and the call itself, its
      # positions counted from the start of that copy (see
      # #replay_at_positions).
      REPLAY_AT_POSITIONS = :replay_at_positions

      # Raised by replay_at_positions when the call changed a position of
      # this session's copy that the stored Array no longer has; nothing is
      # stored, and the user is told (see #apply_to_stored_row).
      class PositionGoneError < StandardError; end
      private_constant :PositionGoneError

      # Replays +method+ (with +args+ and +block+) on +container+, a stored
      # Array, the way it ran on this session's copy of +size+ elements.
      #
      # When the stored Array has at least +size+ elements, the call runs on
      # its first +size+ elements only, and the elements past them (those
      # another session appended) follow what it leaves. So a position at or
      # past this session's end (list.delete_at(5), list.slice!(2..),
      # list.fill('z', 1, 9), list[size] = v) reaches none of them, and the
      # call returns what it returned on this session's copy, as the
      # positions counted from the end already do.
      #
      # When the stored Array is shorter (another session removed elements),
      # the call runs on it as it is, unless the first position it changed in
      # this session's copy (+first_changed+) is past the stored Array's end:
      # the element this session saw there is gone, so PositionGoneError is
      # raised, rather than padding the Array with nil or changing nothing.
      #
      # @return the call's result
      def self.replay_at_positions(container, size, first_changed, method, args, &block)
        if container.size >= size
          appended = container.slice!(size..)
          begin
            container.public_send(method, *args, &block)
          ensure
            container.concat(appended)
          end
        elsif first_changed && first_changed >= container.size
          raise PositionGoneError
        else
          container.public_send(method, *args, &block)
        end
      end
      private_class_method :replay_at_positions

      # The part of +path+ that leads to the stored Array that no longer has
      # the position +path+ goes through next (an Array that another session
      # removed counts as an empty one); nil when every position along +path+
      # is still there. Whether a removed container was an Array is told by
      # +classes+ (SettingsProxy#path_classes), else by the segment (see
      # #container_class_at).
      def self.position_gone(root, path, classes = nil)
        node = root
        path.each_with_index do |segment, i|
          if node.is_a?(Array) || (node.nil? && container_class_at(path, classes, i) == Array)
            return nil unless segment.is_a?(Integer) && segment >= 0 # refused by apply_to_stored_row

            return path[0...i] if segment >= (node.nil? ? 0 : node.size)
          elsif !node.nil? && !node.is_a?(Hash)
            return nil
          end
          node = node.nil? ? nil : node[segment]
        end
        nil
      end
      private_class_method :position_gone

      # Applies +changes+, a list of [operation, args] entry changes, to
      # +container+, in order.
      #
      # @return nil
      def self.replay_entry_changes(container, changes)
        changes.each { |operation, args| container.public_send(operation, *args) }
        nil
      end
      private_class_method :replay_entry_changes

      # A copy of +value+, with proxies unwrapped, that shares no object with
      # it (not even a String), as a read of the stored row would give it back.
      #
      # @raise [TypeError] when +value+ can't be stored (a Proc, a Hash with a
      #   default proc, an object with singleton methods, ...)
      def self.stored_copy(value)
        Marshal.load(Marshal.dump(unwrap_proxies(value)))
      end
      private_class_method :stored_copy

      # The container under +root+ that holds the last segment of +path+
      # (the container at all the segments before it), creating missing (or
      # nil) Hash and Array entries on the way, as nested saves always have,
      # of the class #container_class_at gives.
      #
      # @return [Hash, Array, nil] nil when a segment can't be followed: a
      #   value that is not a container, or an Array index that is not a
      #   non-negative Integer
      def self.container_at(root, path, classes = nil)
        path[0...-1].each_with_index.reduce(root) do |node, (seg, idx)|
          return nil unless node.is_a?(Hash) || (node.is_a?(Array) && seg.is_a?(Integer) && seg >= 0)

          node[seg] = container_class_at(path, classes, idx + 1).new if node[seg].nil?
          node[seg]
        end
      end
      private_class_method :container_at

      # The class (Hash or Array) of the container that +path+[+i+] indexes:
      # the one this session's copy held there (+classes+, from
      # SettingsProxy#path_classes) when known, otherwise an Array for an
      # Integer segment and a Hash for anything else.
      def self.container_class_at(path, classes, i)
        classes&.at(i) || (path[i].is_a?(Integer) ? Array : Hash)
      end
      private_class_method :container_class_at

      # Tells the user that a write through a proxy could not be saved.
      #
      # For writes through what one call to SettingsProxy#each yielded, or a
      # container taken from it (SettingsProxy#refusals), made while the
      # loop runs, the user is told about the first one refused for each
      # +kind+ of reason, and that any other refused for it in the loop is
      # only logged; each of them is still logged. After the loop, each
      # refused write is told (the loop's refusals are frozen then). A reason
      # that names a path or a method passes a +kind+, so that the writes
      # through each element of one loop (each with its own path) count as
      # one kind. A loop can also yield elements whose writes are stored (an
      # element of a view that is found in the settings), so the message
      # speaks of the refused ones only.
      #
      # @return nil
      def self.refuse_proxy_save(script_name, proxy, reason, kind: reason)
        refusals = proxy.respond_to?(:refusals) ? proxy.refusals : nil
        tell = true
        if refusals && !refusals.frozen?
          refusals[kind] = refusals.fetch(kind, 0) + 1
          tell = refusals[kind] == 1
          reason = "#{reason}; the same goes for any other such write in this each loop, which is only logged" if tell
        end
        message = "--- Error: settings for #{script_name} (#{proxy.scope}) not saved: #{reason} ---"
        _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "save_proxy_changes: #{message}" })
        Lich::Messaging.msg("error", message) if defined?(Lich::Messaging) && tell
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
      # A row read after a cache miss is read and cached under the entry's lock
      # (see with_cache_lock), keeping a row another thread cached while this
      # one waited. A cached row read again after a commit is read without
      # that lock, so a write in progress in this process doesn't hold up the
      # read; it is cached only if no other thread changed the cache entry
      # while it was read, so a later row (a write, a newer re-read,
      # Settings.load) is never replaced by an older one. While another thread
      # writes the entry, the row is cached without a version: a write that
      # changes the cached root in place never leaves it with a version it
      # doesn't match, and a thread that read a newer row doesn't go back to
      # the older one when the version can't be read next. The write then
      # caches its own row only if this re-read may have begun before its
      # store (see store_after_database). The row is returned either way.
      #
      # @return [Hash, Array, Object] the cached root itself (not a copy), or
      #   a freshly read row that another thread's change kept out of the cache
      def self.cached_root(script_name, scope)
        cache_key = "#{script_name || ""}::#{scope}"
        version = @db_adapter.data_version
        cached = @settings_cache[cache_key]
        unless cached
          return with_cache_lock(cache_key) do
            # Another thread may have filled the entry while this one waited.
            # Otherwise the version is read again, as the database may have
            # changed while this thread waited for the lock.
            @settings_cache[cache_key] || read_into_cache(script_name, scope, cache_key, @db_adapter.data_version, nil)
          end
        end

        stamp = @cache_versions[cache_key]
        if version.nil? || (stamp && stamp[0] == version && stamp[1].equal?(cached))
          _log(LOG_LEVEL_INFO, @@log_prefix, -> { "cached_root: Cache hit for #{cache_key} (object_id: #{cached.object_id}, data_version: #{version.inspect})" })
          return cached
        end

        read_into_cache(script_name, scope, cache_key, version, cached)
      end
      private_class_method :cached_root

      # Reads the row for cached_root and caches it if the cache entry is
      # still cached (the root cached_root saw, nil after a miss). version is
      # recorded with it only if no other thread holds the entry's lock.
      # Returns the row read; on a database error, returns cached, or raises
      # when cached is nil.
      def self.read_into_cache(script_name, scope, cache_key, version, cached)
        begin
          root = @db_adapter.get_settings(script_name, scope)
        rescue Sequel::Error, SQLite3::Exception => e
          raise unless cached

          _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "cached_root: Could not re-read #{cache_key} (#{e.class}: #{e.message}); using the cached row." })
          return cached
        end
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "cached_root: Loaded #{cache_key} from DB (object_id: #{root.object_id}, data_version: #{version.inspect})" })
        # Another thread may have put a newer row in the cache while this one
        # was reading (its own write, a re-read that began later, or
        # Settings.load). This row is cached only if the entry is still the one
        # seen before the read; otherwise it is returned without caching.
        #
        # While another thread holds the entry's lock, the row is cached with
        # no version: a write in progress may change the cached root in place
        # (Settings.[]= under a path changes a container it shares with the
        # cached root before it saves the row), and a version recorded for
        # that root now would vouch for whatever the write leaves in it, even
        # when the write saves nothing. Without a version, the next read
        # checks the database again, and while the
        # version can't be read it serves this row, not the older one it
        # replaced. Taking the lock without waiting here (a miss fill already
        # holds it) means no write starts between this check and recording
        # the version, and every write drops or replaces what is recorded
        # here once it has the lock. The version is recorded in
        # @reread_versions either way, so that a write finishing later can
        # tell whether this read began after its store (see
        # store_after_database).
        lock = cache_lock(cache_key)
        free = lock.try_enter
        begin
          cached_now = @cache_mutex.synchronize do
            next false unless @settings_cache[cache_key].equal?(cached)

            @settings_cache[cache_key] = root
            @reread_versions[cache_key] = [version, root]
            if free
              @cache_versions[cache_key] = [version, root]
            else
              @cache_versions.delete(cache_key)
            end
            true
          end
        ensure
          lock.exit if free
        end
        if !cached_now
          _log(LOG_LEVEL_INFO, @@log_prefix, -> { "cached_root: #{cache_key} changed in the cache while it was read; not caching this copy" })
        elsif !free
          _log(LOG_LEVEL_INFO, @@log_prefix, -> { "cached_root: #{cache_key} is being written; cached this copy without a version" })
        end
        root
      end
      private_class_method :read_into_cache

      # Puts root in the cache for cache_key. Every write that replaces a
      # cached root goes through here or store_after_database, holding
      # @cache_mutex, so that it can't land between cached_root's check that
      # the entry is unchanged and its own assignment (which would put an
      # older row over this one).
      #
      # @return root
      def self.store_in_cache(cache_key, root)
        @cache_mutex.synchronize { @settings_cache[cache_key] = root }
      end
      private_class_method :store_in_cache

      # Puts a row in the cache once this thread, holding the entry's lock,
      # has finished with the database: the row it just stored (a write), or
      # the row it just read (refresh_data). The row is not cached when
      # another thread's re-read (cached_root, which doesn't wait for the
      # lock) has cached a row that holds at least what this thread stored or
      # read. This is the write's last change to the cache entry: nothing
      # after it may change the cached row, which may by then be that re-read.
      #
      # Without this check, a re-read in the gap between the store and the
      # cache update could see a commit another session made in that gap, and
      # the cache update would then put this thread's older row over it.
      # While the version can't be read, the re-reading thread would be
      # served that older row and lose sight of the newer one it had read.
      #
      # version tells which re-reads hold this thread's row:
      # - A write passes data_version read after its commit. A re-read whose
      #   version (taken before its SELECT) is at least that value saw no
      #   commit between its version and this one, so it began after the
      #   store and its row includes it: this thread's reads still see its
      #   own write.
      # - refresh_data passes data_version read before its own read, with
      #   newer_only. Only a re-read whose version is greater saw a commit
      #   this read may have missed; one at the same version read the same
      #   database state, and refresh_data's row replaces it, dropping changes
      #   made only to the cached row (Settings.load's contract).
      # Every other case caches this row, as before: a re-read that began
      # earlier, a commit by another session after the re-read's version, or
      # a version that can't be read. In those cases the re-reading thread
      # may be served this row until the version can be read again.
      #
      # @return [Boolean] whether the cache now holds row
      def self.store_after_database(cache_key, row, version, newer_only: false)
        @cache_mutex.synchronize do
          seen = @reread_versions[cache_key]
          current = @settings_cache[cache_key]
          if version && seen && seen[0] && current && seen[1].equal?(current)
            next false if newer_only ? seen[0] > version : seen[0] >= version
          end

          @settings_cache[cache_key] = row
          true
        end
      end
      private_class_method :store_after_database

      # Saves a whole row and caches it (see store_after_database).
      #
      # @return [Boolean, nil] whether the cache took the saved row (false
      #   when a newer row another thread re-read after the save is kept), or
      #   nil when nothing was saved for lack of a script name
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

        with_cache_lock(cache_key) do
          @db_adapter.save_settings(script_name, unwrapped_settings, scope)
          _log(LOG_LEVEL_INFO, @@log_prefix, -> { "save_to_database: Data saved to DB for script '#{script_name}'." })

          if store_after_database(cache_key, unwrapped_settings, @db_adapter.data_version)
            _log(LOG_LEVEL_INFO, @@log_prefix, -> { "save_to_database: Cache updated for #{cache_key} with saved data (object_id: #{unwrapped_settings.object_id})." })
            true
          else
            _log(LOG_LEVEL_INFO, @@log_prefix, -> { "save_to_database: Kept the newer row another thread re-read for #{cache_key} after the save." })
            false
          end
        end
      end

      def self.refresh_data(scope = DEFAULT_SCOPE)
        script_name = Script.current.name
        cache_key = "#{script_name || ""}::#{scope}" # Use an empty string if script_name is nil
        _log(LOG_LEVEL_INFO, @@log_prefix, -> { "refresh_data: Reloading cache for scope: #{scope.inspect}, cache_key: #{cache_key}" })
        # Reload under the entry's lock, replacing whatever is cached. A cache
        # miss fill keeps a row another thread cached while it waited, which
        # could be one read before this call began. If the read raises, the
        # cached row and its recorded version stay as they were.
        settings = with_cache_lock(cache_key) do
          version = @db_adapter.data_version
          root = @db_adapter.get_settings(script_name, scope)
          # The version recorded for the old root no longer matches the
          # cached object, so the next read checks the database again (see
          # cached_root). A row another thread re-read after a commit this
          # read may have missed is kept (see store_after_database); this
          # call still returns its own.
          store_after_database(cache_key, root, version, newer_only: true)
          root
        end
        settings.dup
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
        with_cache_lock(cache_key) { store_top_level_key(script_name, cache_key, scope, name, value) }
      end
      private_class_method :write_top_level_key

      # write_top_level_key's database write and cache update, under the cache
      # entry's lock (see with_cache_lock). The adapter updates the cache as
      # part of the store (on_stored), so a script killed right after the row
      # was committed does not leave the cache without it.
      def self.store_top_level_key(script_name, cache_key, scope, name, value)
        cache_stored_row = ->(row) { store_after_database(cache_key, row, @db_adapter.data_version) }
        stored = @db_adapter.update_settings(script_name, scope, on_stored: cache_stored_row) do |fresh_root|
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
          _log(LOG_LEVEL_INFO, @@log_prefix, -> { "write_top_level_key: Saved '#{name}' for #{cache_key}; cache now holds the stored row." })
        else
          _log(LOG_LEVEL_ERROR, @@log_prefix, -> { "write_top_level_key: '#{name}' was NOT saved for #{cache_key}; cache left as it was." })
        end
        stored
      end
      private_class_method :store_top_level_key

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
          # This saves the whole row it navigated, so the read and the save run
          # under one hold of the entry's lock (see with_cache_lock). Otherwise
          # a write another thread stores in between is erased by the save.
          with_cache_lock("#{Script.current.name || ""}::#{scope_to_use}") do
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
