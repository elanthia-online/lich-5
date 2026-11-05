module Lich
  module Common
    # Database adapter to separate database concerns
    class DatabaseAdapter
      # A lock that hands itself to the thread that has waited longest.
      #
      # Ruby's Mutex and Monitor are not fair: a thread that releases one and
      # asks again at once usually takes it back before a woken waiter runs.
      # On release this lock passes ownership straight to the first waiter, so
      # a thread that calls in a tight loop cannot keep others out.
      #
      # Interrupts (Thread#kill, Thread#raise, Timeout) are deferred for the
      # whole call: while the thread waits for its turn, while it holds the
      # lock, and until it has released it. None is ever delivered inside, so
      # a caller's own deferral (update_settings holds a kill back until
      # on_stored has returned) is never overridden, and a waiter can never
      # be interrupted out of the queue and strand the lock. The cost is that
      # a thread waiting here can't be interrupted until its turn has come and
      # gone; the wait is bounded by the calls queued ahead of it. Not
      # re-entrant.
      class HandoffLock
        def initialize
          @mutex = Mutex.new
          @held = false
          @waiters = []
        end

        def synchronize
          Thread.handle_interrupt(Object => :never) do
            acquire
            begin
              yield
            ensure
              release
            end
          end
        end

        private

        # Takes the lock, or joins the queue and waits until release hands
        # it over. With interrupts deferred the wait can't be cut short, so
        # once pop returns this thread owns the lock.
        def acquire
          ticket = @mutex.synchronize do
            if @held
              Thread::Queue.new.tap { |queue| @waiters << queue }
            else
              @held = true
              nil
            end
          end
          ticket&.pop
        end

        # The lock stays held while it is handed over, so no thread arriving
        # meanwhile can take it ahead of the waiter.
        def release
          @mutex.synchronize do
            if (successor = @waiters.shift)
              successor << true
            else
              @held = false
            end
          end
        end
      end

      def initialize(data_dir, table_name)
        @file = File.join(data_dir, "lich.db3")
        @db = Lich.open_sequel_sqlite(@file)
        @table_name = table_name
        @version_mutex = Mutex.new
        @version_call_lock = HandoffLock.new
        @version_db = nil
        @version_base = 0
        @version_epoch = -1
        @version_error_reported = false
        setup!
      end

      def setup!
        @db.create_table?(@table_name) do
          text :script
          text :scope
          blob :hash
        end
        @table = @db[@table_name]
      end

      def table
        @table
      end

      def get_settings(script_name, scope = ":")
        entry = @table.first(script: script_name, scope: scope)
        entry.nil? ? {} : Marshal.load(entry[:hash])
      end

      # A number that changes whenever lich.db3 has had a commit since it was
      # last read, or nil when that can't be told right now.
      #
      # Every Lich session is a separate process, and Settings caches rows per
      # process. SQLite's PRAGMA data_version changes when another connection
      # commits, so a cache can compare it with the value seen when a row was
      # read and re-read the row only when it may have changed. The pragma
      # reports changes by *other* connections only, and Sequel may hand each
      # thread a different connection, so it is read on a connection of its
      # own that never writes: every commit, from another process or from this
      # one, changes it.
      #
      # The connection does not wait for locks. While another process holds
      # the database's exclusive lock (a commit in progress, or a script
      # holding it), the read fails at once and this returns nil instead of
      # waiting out a busy timeout. Callers then keep what they have; a read
      # that overlaps a commit may see the database as it was before it. The
      # read runs in one C call (sqlite3_exec), so no SQLite lock is held
      # while Ruby code runs.
      #
      # Every thread of the process shares this one connection, so only one
      # thread at a time may be inside a sqlite3 call on it
      # (@version_call_lock). The GVL does not keep threads out of the C call.
      # On Windows the sqlite3 gem resolves SQLite's Sleep() to Ruby's
      # rb_w32_Sleep, which releases the GVL, and SQLite sleeps while it holds
      # the connection's mutex even with no busy timeout: winLock retries a
      # lock that another process holds, with a 1 ms sleep between tries. A
      # second thread that entered the call meanwhile would block on that
      # mutex with the GVL held, and the sleeping thread could never get the
      # GVL back. Every thread of the process would then stop for good (#2254).
      # With the lock, the second thread waits in Ruby, with the GVL released.
      #
      # rb_w32_Sleep also delivers pending interrupts. A Thread#kill or
      # Timeout landing in that sleep would unwind through SQLite's C frames
      # and leave the connection's mutex locked, with the same result for the
      # next caller. The lock defers interrupts until the call has returned,
      # and while a thread waits for its turn, so a caller that defers them
      # itself (update_settings around on_stored) keeps that guarantee.
      #
      # The pragma counts per connection, starting again from 1 on a new one,
      # so after an error has closed the connection the reopened one could
      # repeat a value already handed out while the database has since
      # changed. Each connection therefore gets a range of its own: its values
      # are offset by 2**40 times the number of connections opened before it.
      # No value is handed out twice for different states of the database,
      # and every value from a reopened connection is greater than every
      # earlier one (a connection would need 2**40 commits to reach the next
      # range).
      #
      # @version_call_lock is held only for the C call itself, and hands
      # itself to the longest-waiting thread, because Ruby's Mutex is not fair.
      # A thread calling this in a tight loop would otherwise take the lock
      # back before a waiting thread got to run, and stall other threads'
      # Settings reads (measured: up to seconds with a Mutex held around the
      # pragma). @version_mutex guards only opening and closing the
      # connection; a value read on a connection that another thread has
      # closed or replaced meanwhile is discarded (nil). Closing also takes
      # @version_call_lock, so it waits for a call in progress instead of
      # closing the connection under it.
      #
      # @return [Integer, nil]
      def data_version
        db = @version_db || open_version_connection
        # Read after db: a connection is published only after its offset is
        # set, and a connection replaced after this point fails the identity
        # check below.
        base = @version_base
        rows = @version_call_lock.synchronize { db.execute_batch2('PRAGMA data_version') }
        raw = Integer(rows.dig(0, 0))
        return nil unless @version_db.equal?(db)

        base + raw
      rescue SQLite3::BusyException
        nil
      rescue SQLite3::Exception, ArgumentError, TypeError => e
        if close_version_connection(db) && !@version_error_reported
          @version_error_reported = true
          Lich.log("--- Error: cannot tell whether settings changed in lich.db3 (#{e.class}: #{e.message}); settings may not show other sessions' changes ---")
        end
        nil
      end

      def save_settings(script_name, settings, scope = ":")
        blob = serialize_settings(script_name, settings)
        return false unless blob

        begin
          statement { upsert_settings(script_name, scope, blob) }
          return true
        rescue StatementFailed => e
          report_database_error(e.cause)
        rescue => e
          Lich::Messaging.msg("error", "--- Unexpected error while saving settings ---")
          Lich.log("--- Unexpected error while saving settings ---")
          Lich.log("#{e.message}\n#{e.backtrace.join("\n")}")
        end

        false
      end

      # update_settings keeps reading a row and trying to store it, while other
      # writers keep changing it in between, for as long as a write would wait
      # for SQLite's lock (Lich.sqlite_busy_timeout_ms), and at least this many
      # times. A writer whose row takes longer to rebuild than its rivals' does
      # loses more often, so a fixed count would give up on it first.
      MIN_UPDATE_ATTEMPTS = 3

      # Longest pause, in seconds, before trying again. Each pause is random,
      # up to 4 ms before the second attempt and doubling from there, so that
      # competing writers drift apart.
      MAX_RETRY_PAUSE = 0.05

      # Raised internally to carry a Sequel error out of a statement, so that
      # save_settings and update_settings report every database failure (a
      # lock timeout, a full connection pool) the same way, and update_settings
      # lets the block's own exceptions through unchanged.
      class StatementFailed < StandardError; end
      private_constant :StatementFailed

      # Changes one row without losing what other writers saved in the
      # meantime.
      #
      # Every Lich session is a separate process with its own settings cache,
      # and all of them share lich.db3. Writing a cached copy of the row back
      # erases whatever other sessions saved in between. This method reads the
      # row as it is now, lets the block change it, and stores the result only
      # if the row still holds exactly the bytes it read: one conditional
      # UPDATE (or, for a new row, an INSERT that does nothing on conflict).
      # If another writer got in first, it pauses briefly, reads the row again
      # and calls the block again, until the busy timeout has passed (see
      # MIN_UPDATE_ATTEMPTS).
      #
      # Each statement takes and releases SQLite's write lock by itself, so the
      # lock is never held while Ruby code (the block, Marshal) runs. Holding it
      # there would make every other writer in this process wait out its busy
      # timeout inside SQLite, which keeps the GVL and stalls every thread.
      #
      # on_stored, when given, is called with the stored row right after the
      # store succeeds, with Thread#kill and Thread#raise held back from the
      # store until on_stored returns. A caller that caches the row passes its
      # cache update here: a script killed (Script#kill) just after the row was
      # committed still leaves its cache holding what the database holds. Only
      # the store is covered, not the block or the pauses between attempts, so
      # a kill waits at most for that one statement (which SQLite already
      # runs without letting other Ruby code in).
      #
      # A stored row that cannot be read (NULL, truncated, or holding a class
      # this process does not have) is never overwritten: another session may
      # still be able to read it. The error is reported and raised, as a read
      # of that row (get_settings) raises it.
      #
      # @param script_name [String] the script namespace
      # @param scope [String] the settings scope
      # @param on_stored [#call, nil] called with the stored row (see above)
      # @yieldparam fresh [Object] the stored row ({} when there is none). The
      #   block may be called more than once and must only build the new row.
      # @yieldreturn [Hash, nil] the row to store, or nil to store nothing
      # @return [Hash, nil] the block's row as stored, or nil when the block
      #   returned nil or nothing could be stored (reported, nothing written)
      # @raise whatever the block raises, and what get_settings raises for a
      #   stored row it cannot read (such as TypeError or ArgumentError)
      def update_settings(script_name, scope = ":", on_stored: nil)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        budget = Lich.sqlite_busy_timeout_ms.to_f / 1000
        attempts = 0
        loop do
          sleep(rand * [0.002 * (2**[attempts, 5].min), MAX_RETRY_PAUSE].min) if attempts.positive?
          attempts += 1
          row = statement { read_row_in_one_call(script_name, scope) }
          old_blob = row && row[:hash]
          updated = yield(row.nil? ? {} : load_stored_row(script_name, scope, old_blob))
          return nil if updated.nil?

          new_blob = serialize_settings(script_name, updated)
          return nil unless new_blob

          stored = Thread.handle_interrupt(Object => :never) do
            next false unless statement { store_if_unchanged(script_name, scope, old_blob, row.nil?, new_blob) }

            on_stored&.call(updated)
            true
          end
          return updated if stored

          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
          break if attempts >= MIN_UPDATE_ATTEMPTS && elapsed >= budget
        end

        message = "--- Error while saving settings: #{script_name} (#{scope}) kept changing, gave up after #{attempts} attempts ---"
        Lich::Messaging.msg("error", message)
        Lich.log(message)
        nil
      rescue StatementFailed => e
        report_database_error(e.cause)
        nil
      end

      # Runs the block inside one SQLite write transaction (BEGIN IMMEDIATE).
      # The write lock is taken before the first read, so a read-modify-write
      # inside the block cannot interleave with another process's write.
      # A nested call joins the outer transaction. If the block raises, nothing
      # it wrote is kept. (Sequel's SQLite adapter re-raises an ArgumentError
      # from the block as Sequel::DatabaseError.)
      #
      # @raise [Sequel::DatabaseError] if the database stays locked past the
      #   busy timeout.
      def transaction(&block)
        @db.transaction(mode: :immediate, &block)
      end

      # Lists the scopes of every row for script_name whose scope starts with
      # scope_prefix, without loading the stored values (so a row that can't
      # be loaded is still listed).
      #
      # @param script_name [String]
      # @param scope_prefix [String] matched literally (not as a LIKE pattern)
      # @return [Array<String>]
      def scopes_by_prefix(script_name, scope_prefix)
        prefix = scope_prefix.to_s
        @table.where(script: script_name).select_map(:scope).map(&:to_s).select { |scope| scope.start_with?(prefix) }
      end

      # Reads every row for script_name whose scope starts with scope_prefix,
      # straight from the database (no cache).
      #
      # A row whose stored value can't be loaded is skipped and logged, so one
      # bad row doesn't hide the others.
      #
      # @param script_name [String]
      # @param scope_prefix [String] matched literally (not as a LIKE pattern)
      # @return [Hash{String => Object}] scope => stored settings
      def get_settings_by_scope_prefix(script_name, scope_prefix)
        prefix = scope_prefix.to_s
        @table.where(script: script_name).select(:scope, :hash).each_with_object({}) do |row, result|
          scope = row[:scope].to_s
          next unless scope.start_with?(prefix)

          begin
            result[scope] = Marshal.load(row[:hash])
          rescue StandardError => e
            Lich.log("--- Error: skipping unreadable settings row script=#{script_name} scope=#{scope}: #{e.class}: #{e.message} ---")
          end
        end
      end

      # Writes one settings row without reading it first.
      #
      # Unlike #save_settings, which reports errors and returns false, this
      # raises, so a caller inside #transaction gets the whole transaction
      # rolled back and can tell that nothing was written.
      #
      # @param script_name [String]
      # @param settings [Hash]
      # @param scope [String]
      # @return [Hash] settings
      # @raise [TypeError] if settings is not a Hash or can't be serialized
      # @raise [Sequel::DatabaseError] if the database is locked or the write fails
      def save_settings!(script_name, settings, scope)
        raise TypeError, "settings must be a Hash, got #{settings.class}" unless settings.is_a?(Hash)

        upsert_settings(script_name, scope, Sequel::SQL::Blob.new(Marshal.dump(settings)))
        settings
      end

      # Atomically reads, changes and writes one settings row.
      #
      # Yields a fresh copy of the stored hash ({} when there is no row) inside
      # #transaction. If the block returns a Hash, that Hash is written to the
      # row; if it returns nil, the row is left as it was.
      #
      # Raises on every failure, like #save_settings!, so the caller can tell
      # that nothing was written.
      #
      # @return [Hash, nil] what the block returned
      # @raise [Sequel::DatabaseError] if the database is locked or the write
      #   fails, or if loading the stored row raises ArgumentError (truncated
      #   Marshal data, for example; Sequel re-raises an ArgumentError from
      #   the block as Sequel::DatabaseError, with the ArgumentError as cause)
      # @raise [StandardError] whatever else Marshal.load raises on a stored
      #   row that can't be loaded (usually TypeError), without yielding
      # @raise [TypeError] if the block returns something other than a Hash or nil
      def update_settings!(script_name, scope)
        transaction do
          updated = yield(get_settings(script_name, scope))
          unless updated.nil? || updated.is_a?(Hash)
            raise TypeError, "update_settings! block must return a Hash or nil, got #{updated.class}"
          end

          save_settings!(script_name, updated, scope) if updated
          updated
        end
      end

      private

      # Opens the version connection unless another thread already has. Its
      # offset is set before the connection is published, so a thread that
      # sees the new connection also sees its offset.
      def open_version_connection
        @version_mutex.synchronize do
          @version_db || begin
            fresh = SQLite3::Database.new(@file).tap { |conn| conn.busy_timeout(0) }
            @version_base = (@version_epoch += 1) << 40
            @version_db = fresh
          end
        end
      end

      # Closes the version connection if it is still +db+, so that the next
      # check opens a new one. A thread whose read failed on a connection
      # another thread has already replaced leaves the new one alone. +db+ is
      # required, so no caller can skip that check by closing "whatever is
      # current". It is nil when opening the connection failed; with no
      # connection open, that counts as current.
      #
      # @param db [SQLite3::Database, nil] the connection the failed read used
      # @return [Boolean] whether +db+ was the current connection
      def close_version_connection(db)
        @version_mutex.synchronize do
          return false unless @version_db.equal?(db)

          @version_db = nil
        end
        # Wait for a call in progress on db to return before closing it.
        @version_call_lock.synchronize do
          db&.close
        rescue SQLite3::Exception
          nil
        end
        true
      end

      # Unmarshals a stored row for update_settings, reporting a row that
      # cannot be read before raising its error.
      def load_stored_row(script_name, scope, blob)
        Marshal.load(blob)
      rescue StandardError => e
        message = "--- Error: settings for #{script_name} (#{scope}) cannot be read (#{e.class}: #{e.message}); nothing was saved ---"
        Lich::Messaging.msg("error", message)
        Lich.log(message)
        raise
      end

      def serialize_settings(script_name, settings)
        unless settings.is_a?(Hash)
          Lich::Messaging.msg("error", "--- Error: Report this - settings must be a Hash, got #{settings.class} ---")
          Lich.log("--- Error: settings must be a Hash, got #{settings.class} from call initiated by #{script_name} ---")
          Lich.log(settings.inspect)
          return nil
        end

        Sequel::SQL::Blob.new(Marshal.dump(settings))
      rescue => e
        Lich::Messaging.msg("error", "--- Error: failed to serialize settings ---")
        Lich.log("--- Error: failed to serialize settings ---")
        Lich.log("#{e.message}\n#{e.backtrace.join("\n")}")
        nil
      end

      # Runs one statement, turning a Sequel or SQLite error (a lock timeout, a
      # full connection pool) into StatementFailed.
      def statement
        yield
      rescue Sequel::Error, SQLite3::Exception
        raise StatementFailed
      end

      # Reads one row as { hash: bytes-or-nil }, or nil when there is none.
      #
      # A SELECT holds SQLite's shared lock from its first row until the
      # statement finishes. Read row by row from Ruby, the thread can be
      # switched out in between, and then a writer in this process that waits
      # inside SQLite (Lich.db keeps the GVL while it waits) never lets it
      # finish: both stall until the busy timeout ends, and writers in other
      # processes stall behind them. sqlite3_exec (execute_batch2) runs the
      # whole query in one C call, so the lock is released before any Ruby code
      # runs. Its results are C strings, so the blob is read as hex.
      def read_row_in_one_call(script_name, scope)
        sql = @table.where(script: script_name, scope: scope)
                    .select(Sequel.function(:typeof, :hash), Sequel.function(:hex, :hash)).sql
        rows = @db.synchronize { |conn| conn.execute_batch2(sql) }
        return nil if rows.empty?

        type, hex = rows.first
        { hash: type == 'null' ? nil : [hex].pack('H*') }
      end

      # Stores new_blob only if the row still holds old_blob (or, when
      # missing is true, still does not exist). Returns whether it stored.
      def store_if_unchanged(script_name, scope, old_blob, missing, new_blob)
        if missing
          @db.synchronize do
            @table.insert_conflict(target: [:script, :scope]).insert(script: script_name, scope: scope, hash: new_blob)
            @db.get(Sequel.function(:changes)) == 1
          end
        else
          # CAST so a row stored with TEXT affinity still compares by its bytes.
          @table.where(script: script_name, scope: scope)
                .where(Sequel.lit('CAST(hash AS BLOB) = ?', Sequel.blob(old_blob)))
                .update(hash: new_blob) == 1
        end
      end

      def upsert_settings(script_name, scope, blob)
        @table
          .insert_conflict(target: [:script, :scope], update: { hash: blob })
          .insert(script: script_name, scope: scope, hash: blob)
      end

      def report_database_error(db_err)
        Lich::Messaging.msg("error", "--- Database error while saving settings ---")
        Lich.log("--- Database error while saving settings ---")
        Lich.log("#{db_err.message}\n#{db_err.backtrace.join("\n")}")
      end
    end
  end
end
