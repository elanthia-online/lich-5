module Lich
  module Common
    # Database adapter to separate database concerns
    class DatabaseAdapter
      def initialize(data_dir, table_name)
        @file = File.join(data_dir, "lich.db3")
        @db = Lich.open_sequel_sqlite(@file)
        @table_name = table_name
        @version_mutex = Mutex.new
        @version_db = nil
        @version_base = 0
        @last_version = 0
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
      # The connection has no busy timeout. While another process holds the
      # database's exclusive lock (a commit in progress, or a script holding
      # it), the read fails at once and this returns nil, rather than waiting
      # inside SQLite, which keeps the GVL and would stall every thread of
      # this process. Callers then keep what they have; a read that overlaps a
      # commit may see the database as it was before it. The read runs in one
      # C call (sqlite3_exec), so no lock is held while Ruby code runs.
      #
      # The pragma counts per connection, starting again from 1 on a new one,
      # so after an error has closed the connection the reopened one could
      # repeat a value already handed out while the database has since
      # changed. Values from each new connection are therefore offset past the
      # last one returned: no value is handed out twice for different states
      # of the database, and the first value after a reopen differs from every
      # earlier one.
      #
      # The pragma is read without holding @version_mutex. Ruby's Mutex is not
      # fair: a thread calling this in a tight loop would take the lock back
      # before a waiting thread got to run, and stall every other thread's
      # Settings reads for up to seconds. The GVL already keeps two threads out
      # of the C call at once. The mutex guards only opening and closing the
      # connection and recording the value; a value read on a connection that
      # another thread has closed or replaced meanwhile is discarded (nil).
      #
      # @return [Integer, nil]
      def data_version
        db = @version_db || open_version_connection
        value = @version_base + Integer(db.execute_batch2('PRAGMA data_version').dig(0, 0))
        @version_mutex.synchronize do
          return nil unless @version_db.equal?(db)

          @last_version = value if value > @last_version
        end
        value
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
          upsert_settings(script_name, scope, blob)
          return true
        rescue Sequel::DatabaseError => db_err
          report_database_error(db_err)
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
      # update_settings reports database failures but lets the block's own
      # exceptions through unchanged.
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
      # @param script_name [String] the script namespace
      # @param scope [String] the settings scope
      # @yieldparam fresh [Object] the stored row ({} when there is none). The
      #   block may be called more than once and must only build the new row.
      # @yieldreturn [Hash, nil] the row to store, or nil to store nothing
      # @return [Hash, nil] the block's row as stored, or nil when the block
      #   returned nil or nothing could be stored (reported, nothing written)
      # @raise whatever the block raises, and what get_settings raises for a
      #   stored row it cannot read (such as TypeError or ArgumentError)
      def update_settings(script_name, scope = ":")
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        budget = Lich.sqlite_busy_timeout_ms.to_f / 1000
        attempts = 0
        loop do
          sleep(rand * [0.002 * (2**[attempts, 5].min), MAX_RETRY_PAUSE].min) if attempts.positive?
          attempts += 1
          row = statement { read_row_in_one_call(script_name, scope) }
          old_blob = row && row[:hash]
          updated = yield(row.nil? ? {} : Marshal.load(old_blob))
          return nil if updated.nil?

          new_blob = serialize_settings(script_name, updated)
          return nil unless new_blob

          return updated if statement { store_if_unchanged(script_name, scope, old_blob, row.nil?, new_blob) }

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

      private

      # Opens the version connection unless another thread already has. Its
      # offset is set before the connection is published, so a thread that
      # sees the new connection also sees its offset.
      def open_version_connection
        @version_mutex.synchronize do
          @version_db || begin
            fresh = SQLite3::Database.new(@file).tap { |conn| conn.busy_timeout(0) }
            @version_base = @last_version + 1
            @version_db = fresh
          end
        end
      end

      # Closes the version connection if it is still +db+, so that the next
      # check opens a new one. A thread whose read failed on a connection
      # another thread has already replaced leaves the new one alone.
      #
      # @return [Boolean] whether +db+ was the current connection
      def close_version_connection(db = @version_db)
        @version_mutex.synchronize do
          return false unless @version_db.equal?(db)

          @version_db = nil
        end
        begin
          db&.close
        rescue SQLite3::Exception
          nil
        end
        true
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
