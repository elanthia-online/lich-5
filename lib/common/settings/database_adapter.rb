module Lich
  module Common
    # Database adapter to separate database concerns
    class DatabaseAdapter
      def initialize(data_dir, table_name)
        @file = File.join(data_dir, "lich.db3")
        @db = Lich.open_sequel_sqlite(@file)
        @table_name = table_name
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

      def save_settings(script_name, settings, scope = ":")
        unless settings.is_a?(Hash)
          Lich::Messaging.msg("error", "--- Error: Report this - settings must be a Hash, got #{settings.class} ---")
          Lich.log("--- Error: settings must be a Hash, got #{settings.class} from call initiated by #{script_name} ---")
          Lich.log(settings.inspect)
          return false
        end

        begin
          blob = Sequel::SQL::Blob.new(Marshal.dump(settings))
        rescue => e
          Lich::Messaging.msg("error", "--- Error: failed to serialize settings ---")
          Lich.log("--- Error: failed to serialize settings ---")
          Lich.log("#{e.message}\n#{e.backtrace.join("\n")}")
          return false
        end

        begin
          upsert_settings(script_name, scope, blob)
          return true
        rescue Sequel::DatabaseError => db_err
          Lich::Messaging.msg("error", "--- Database error while saving settings ---")
          Lich.log("--- Database error while saving settings ---")
          Lich.log("#{db_err.message}\n#{db_err.backtrace.join("\n")}")
        rescue => e
          Lich::Messaging.msg("error", "--- Unexpected error while saving settings ---")
          Lich.log("--- Unexpected error while saving settings ---")
          Lich.log("#{e.message}\n#{e.backtrace.join("\n")}")
        end

        false
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
      # @raise [Sequel::DatabaseError] if the database is locked or the write fails
      # @raise [TypeError] if the stored row can't be loaded, or the block
      #   returns something other than a Hash or nil
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

      def upsert_settings(script_name, scope, blob)
        @table
          .insert_conflict(target: [:script, :scope], update: { hash: blob })
          .insert(script: script_name, scope: scope, hash: blob)
      end
    end
  end
end
