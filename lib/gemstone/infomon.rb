# frozen_string_literal: true

# Replacement for the venerable infomon.lic script used in Lich4 and Lich5 (03/01/23)
# Supports Ruby 3.X builds
#
#     maintainer: elanthia-online
#   contributors: Tillmen, Shaelun, Athias
#           game: Gemstone
#           tags: core
#       required: Lich > 5.6.2
#        version: 2.0
#         Source: https://github.com/elanthia-online/scripts

require 'sequel'
require 'tmpdir'
require 'logger'
require 'timeout'
require_relative '../common/sqlite_connection'
require_relative 'infomon/cache'
require_relative '../common/watchable'

module Lich
  module Gemstone
    module Infomon
      extend Lich::Common::Watchable
      $infomon_debug = ENV["DEBUG"]
      # use temp dir in ci context
      @root = defined?(DATA_DIR) ? DATA_DIR : Dir.tmpdir
      @file = File.join(@root, "infomon.db")
      # Same Ruby busy handler as lich.db3, so a lock held by another Lich process
      # (infomon.db is shared by every character's process) doesn't freeze this one.
      @db   = Lich.open_sequel_sqlite(@file)
      @cache ||= Infomon::Cache.new
      @cache_loaded = false
      @db.loggers << Logger.new($stdout) if ENV["DEBUG"]
      @sql_queue ||= Queue.new
      @sql_mutex ||= Mutex.new
      # keys whose last attempted write failed; cleared by a later successful write.
      # Plain Hash like Cache: mutated by the worker thread and reset!; single ops are GVL-atomic.
      @unpersisted ||= {}
      # true once a write failure has been shown in game; any successful write clears it
      @failure_reported = false
      # Writes held back while the database is busy (locked by another Lich process).
      # Replayed in order once the lock frees, so a stuck lock costs one lock wait
      # per backoff window instead of one per queued write. Guarded by @deferred_lock.
      BUSY_BACKOFF_START_S = 2.0 unless const_defined?(:BUSY_BACKOFF_START_S)
      BUSY_BACKOFF_MAX_S = 30.0 unless const_defined?(:BUSY_BACKOFF_MAX_S)
      MAX_DEFERRED_WRITES = 5000 unless const_defined?(:MAX_DEFERRED_WRITES)
      @deferred ||= []
      @deferred_lock ||= Mutex.new
      @busy_until = nil # CLOCK_MONOTONIC time before which no write is attempted
      @busy_backoff = nil # next backoff in seconds; nil = BUSY_BACKOFF_START_S (no busy streak)

      def self.cache
        @cache
      end

      def self.file
        @file
      end

      def self.db
        @db
      end

      def self.mutex
        @sql_mutex
      end

      def self.mutex_lock
        begin
          self.mutex.lock unless self.mutex.owned?
        rescue StandardError
          respond "--- Lich: error: Infomon.mutex_lock: #{$!}"
          Lich.log "error: Infomon.mutex_lock: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        end
      end

      def self.mutex_unlock
        begin
          self.mutex.unlock if self.mutex.owned?
        rescue StandardError
          respond "--- Lich: error: Infomon.mutex_unlock: #{$!}"
          Lich.log "error: Infomon.mutex_unlock: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        end
      end

      # Runs the block holding the Infomon mutex. Re-entrant: a caller that already
      # owns it (the parser holds it across a section) keeps it afterwards.
      def self.with_mutex(&block)
        return yield if self.mutex.owned?

        self.mutex.synchronize(&block)
      end

      def self.queue
        @sql_queue
      end

      def self.current_timestamp
        Time.now.utc.to_f
      end

      def self.context!
        return unless XMLData.name.empty? or XMLData.name.nil?
        puts Exception.new.backtrace
        fail "cannot access Infomon before XMLData.name is loaded"
      end

      def self.table_name
        self.context!
        ("%s_%s" % [XMLData.game, XMLData.name]).to_sym
      end

      def self.reset!
        self.with_mutex do
          Infomon.db.drop_table?(self.table_name)
          self.cache.clear
          @unpersisted.clear
          # pending writes were for the table just dropped
          @deferred_lock.synchronize { @deferred.clear }
          # the drop above just wrote to the file, so any busy streak is over
          @busy_until = nil
          @busy_backoff = nil
          @failure_reported = false
          @cache_loaded = false
          Infomon.setup!
        end
      end

      def self.table
        @_table ||= self.setup!
      end

      def self.setup!
        stale = false
        # with_mutex releases the lock if a DB call raises (e.g. the database is busy)
        self.with_mutex do
          # Check if table exists but missing updated_at column
          if @db.table_exists?(self.table_name)
            columns = @db.schema(self.table_name).map { |col| col[0] }
            stale = !columns.include?(:updated_at)
          end

          unless stale
            @db.create_table?(self.table_name) do
              text :key, primary_key: true
              any :value
              float :updated_at
            end
          end
        end
        return self.reset! if stale

        @_table = @db[self.table_name]
      end

      def self.cache_load
        sleep(0.01) if XMLData.name.empty?
        dataset = Infomon.table
        h = dataset.map(:key).zip(dataset.map(:value)).to_h
        # Disk only fills keys this session hasn't touched. A cached value was set this
        # session, so it is newer than the row, even if its write is still queued or held
        # back while the database is busy; a key with a deferred write and no cached
        # value is a pending delete!.
        pending = @deferred_lock.synchronize { @deferred.flat_map { |_sql, keys| keys } }.to_h { |key| [key, true] }
        h.each { |key, value| self.cache.put(key, value) unless self.cache.include?(key) || pending.key?(key) }
        @cache_loaded = true
      end

      def self._key(key)
        key.to_s.downcase.tr(' -', '_').gsub(/_+/, '_')
      end

      def self._value(val)
        return true if val.to_s == "true"
        return false if val.to_s == "false"
        return val
      end

      AllowedTypes = [Integer, String, NilClass, FalseClass, TrueClass]
      def self._validate!(key, value)
        return self._value(value) if AllowedTypes.include?(value.class)
        raise "infomon:insert(%s) was called with %s\nmust be %s\nvalue=%s" % [key, value.class, AllowedTypes.map(&:name).join("|"), value]
      end

      def self.get(key)
        self.cache_load if !@cache_loaded
        key = self._key(key)
        val = self.cache.get(key) {
          # Flush queue before reading from DB to ensure we see latest writes
          self.flush
          # A write for this key is still deferred (database busy). A pending set keeps the
          # key cached, so this is a pending delete!: the row on disk is about to go, and
          # caching it would outlive the DELETE.
          next nil if self.pending_write?(key)

          begin
            self.mutex.synchronize do
              begin
                db_result = self.table[key: key]
                if db_result
                  db_result[:value]
                else
                  nil
                end
              rescue => exception
                pp(exception)
                nil
              end
            end
          rescue StandardError
            respond "--- Lich: error: Infomon.get(#{key}): #{$!}"
            Lich.log "error: Infomon.get(#{key}): #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          end
        }
        return self._value(val)
      end

      def self.get_bool(key)
        value = Infomon.get(key)
        if value.is_a?(TrueClass) || value.is_a?(FalseClass)
          return value
        elsif value == 1
          return true
        else
          return false
        end
      end

      def self.get_updated_at(key)
        key = self._key(key)
        begin
          self.mutex.synchronize do
            db_result = self.table[key: key]
            if db_result
              db_result[:updated_at]
            else
              nil
            end
          end
        rescue StandardError
          respond "--- Lich: error: Infomon.get_updated_at(#{key}): #{$!}"
          Lich.log "error: Infomon.get_updated_at(#{key}): #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          nil
        end
      end

      def self.upsert(*args)
        self.table
            .insert_conflict(:replace)
            .insert(*args)
      end

      def self.set(key, value)
        key = self._key(key)
        value = self._validate!(key, value)
        return :noop if !@unpersisted.key?(key) && self.cache.include?(key) && self.cache.get(key) == value
        self.cache.put(key, value)
        # queue items are [sql, keys] so a failed write can mark its keys unpersisted
        self.queue << ["INSERT OR REPLACE INTO %s (`key`, `value`, `updated_at`) VALUES (%s, %s, %s)
      on conflict(`key`) do update set value = excluded.value, updated_at = excluded.updated_at;" % [self.db.literal(self.table_name), self.db.literal(key), self.db.literal(value), current_timestamp], [key]]
      end

      def self.delete!(key)
        key = self._key(key)
        self.cache.delete(key)
        self.queue << ["DELETE FROM %s WHERE key = (%s);" % [self.db.literal(self.table_name), self.db.literal(key)], [key]]
      end

      # Flush all pending SQL operations and wait for completion.
      # This is a barrier: when it returns, every write queued before it has run,
      # except while the database is busy, when some may still be held back for
      # retry and have not landed yet (see drain_writes).
      # Returns true once the barrier is reached, false on timeout.
      def self.flush(timeout_seconds: 5)
        return true if self.queue.empty?

        # Create a barrier token - a Queue that the worker will signal when reached
        barrier = ::Queue.new
        self.queue << barrier

        # Wait for the worker to signal completion (with timeout)
        begin
          ::Timeout.timeout(timeout_seconds) { barrier.pop }
          true
        rescue ::Timeout::Error
          Lich.log "warning: Infomon.flush timed out after #{timeout_seconds}s"
          false
        end
      end

      def self.upsert_batch(*blob)
        updated = (blob.first.map { |k, v| [self._key(k), self._validate!(k, v)] } - self.cache.to_a.reject { |k, _| @unpersisted.key?(k) })
        return :noop if updated.empty?
        now = current_timestamp
        pairs = updated.map { |key, value|
          (value.is_a?(Integer) or value.is_a?(String)) or fail "upsert_batch only works with Integer or String types"
          # add the value to the cache
          self.cache.put(key, value)
          %[(%s, %s, %s)] % [self.db.literal(key), self.db.literal(value), now]
        }.join(", ")
        # queue sql statement to run async
        self.queue << ["INSERT OR REPLACE INTO %s (`key`, `value`, `updated_at`) VALUES %s
      on conflict(`key`) do update set value = excluded.value, updated_at = excluded.updated_at;" % [self.db.literal(self.table_name), pairs], updated.map(&:first)]
      end

      # True when the failure is SQLite's "database is locked" (Sequel wraps it).
      def self.busy_error?(error)
        defined?(::SQLite3::BusyException) &&
          (error.is_a?(::SQLite3::BusyException) || error.cause.is_a?(::SQLite3::BusyException))
      end

      def self.monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # True when a write for `key` is held back while the database is busy.
      def self.pending_write?(key)
        @deferred_lock.synchronize do
          @deferred.any? { |_sql, keys| keys.include?(key) }
        end
      end

      def self.write_cooling_down?
        !@busy_until.nil? && self.monotonic_now < @busy_until
      end

      # Next item for the writer thread. While writes are deferred it waits only until
      # the backoff ends, so they are retried even if nothing new is queued. nil = timed out.
      def self.next_queue_item
        wait = @deferred_lock.synchronize do
          next nil if @deferred.empty?

          @busy_until ? [@busy_until - self.monotonic_now, 0].max : 0
        end
        wait.nil? ? self.queue.pop : self.queue.pop(timeout: wait)
      end

      # Adds a write to the pending list; past the cap the oldest are dropped and marked
      # unpersisted, like any other failed write.
      def self.defer_write(item)
        dropped = 0
        @deferred_lock.synchronize do
          @deferred << item
          while @deferred.size > MAX_DEFERRED_WRITES
            @deferred.shift[1].each { |key| @unpersisted[key] = true }
            dropped += 1
          end
        end
        Lich.log "warning: Infomon dropped #{dropped} pending write(s) while the database stayed busy" if dropped > 0
      end

      # Runs pending writes in order until one finds the database busy.
      def self.drain_writes
        loop do
          return if self.write_cooling_down?

          item = @deferred_lock.synchronize { @deferred.first }
          return unless item

          outcome = self.attempt_write(item)
          return if outcome == :busy

          @deferred_lock.synchronize { @deferred.shift if @deferred.first.equal?(item) }
        end
      end

      # One attempt at one pending write (the head of @deferred). Returns :ok, :busy (keep
      # it pending, back off), :failed (drop it; its keys are marked unpersisted so a later
      # set retries) or :stale (reset! cleared it while this thread waited for the mutex).
      def self.attempt_write(item)
        sql, keys = item
        write_error = nil
        report_in_game = false
        busy = false
        stale = false
        Infomon.mutex.synchronize do
          # reset! clears @deferred and rebuilds the table under this mutex. If it ran
          # while this thread waited here, the write was for the dropped table and must
          # not land in the new one.
          stale = !@deferred_lock.synchronize { @deferred.first.equal?(item) }
          next if stale

          begin
            Infomon.db.run(sql)
            # Safe to clear: the queue is FIFO, so any later write for these keys
            # runs after this and re-marks them if it fails.
            keys.each { |key| @unpersisted.delete(key) }
            @failure_reported = false
            @busy_until = nil
            @busy_backoff = nil
          rescue StandardError => e
            # Keep the cached value (Infomon's view of the game) and mark the keys so
            # the next set/upsert_batch of the same value is retried instead of a :noop.
            report_in_game = !@failure_reported
            @failure_reported = true
            keys.each { |key| @unpersisted[key] = true }
            write_error = e
            if self.busy_error?(e)
              busy = true
              backoff = @busy_backoff || BUSY_BACKOFF_START_S
              @busy_until = self.monotonic_now + backoff
              @busy_backoff = [backoff * 2, BUSY_BACKOFF_MAX_S].min
            end
          end
        end
        return :stale if stale
        return :ok unless write_error

        # Reported after releasing the DB mutex so a slow client write can't hold it.
        # The game window gets one short line per failure streak (a streak ends at
        # the next successful write); the log gets every failure in full.
        if report_in_game
          if busy
            respond "--- Lich: warning: Infomon database is busy (locked by another Lich session); writes are delayed and will be retried"
          else
            shown = keys.first(3).join(', ')
            shown += ', ...' if keys.size > 3
            respond "--- Lich: error: Infomon write failed for #{keys.size} key(s) (#{shown}): #{write_error.message}"
          end
        end
        Lich.log "error: Infomon write #{busy ? 'deferred (database busy)' : 'failed'} for #{keys.join(', ')}: #{write_error.class}: #{write_error.message}\n\t#{write_error.backtrace.join("\n\t")}"
        busy ? :busy : :failed
      end

      Thread.new do
        loop do
          item = Infomon.next_queue_item
          begin
            # Handle flush barrier tokens - signal completion and continue
            if item.is_a?(Queue)
              item << :flushed
              next
            end

            # Normal SQL statement processing; a nil item is the backoff timing out
            Infomon.defer_write(item) if item
            Infomon.drain_writes
          rescue StandardError
            respond "--- Lich: error: Infomon ThreadQueue: #{$!}"
            Lich.log "error: Infomon ThreadQueue: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          end
        end
      end

      # Self-watching thread that triggers initialization when ready
      # Follows the ActiveSpell.watch! pattern for lifecycle management
      def self.watch!
        @init_thread ||= Thread.new do
          begin
            # Wait for character to be ready and dialogs to load
            sleep 0.1 until GameBase::Game.autostarted? && XMLData.name && !XMLData.name.empty? &&
                            !XMLData.dialogs.empty?

            # Run initial setup if needed (GS-specific only, skip for DR)
            if XMLData.game !~ /^DR/ && db_refresh_needed?
              ExecScript.start("Infomon.redo!", { quiet: true, name: "infomon_reset" })
            end

            PostLoad.game_loaded! if defined?(PostLoad)
          rescue StandardError => e
            respond 'Error in Infomon initialization thread'
            respond e.inspect
          end
        end
      end

      require_relative 'infomon/parser'
      require_relative 'infomon/xmlparser'
      require_relative 'infomon/cli'
    end
  end
end
