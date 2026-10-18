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

      # Changes one row as a single read-modify-write that no other process
      # can interleave with.
      #
      # Every Lich session is a separate process with its own settings cache,
      # and all of them share lich.db3. Writing a cached copy of the row back
      # erases whatever other sessions saved in between. This method instead
      # takes SQLite's write lock first (BEGIN IMMEDIATE, which waits up to the
      # busy timeout), reads the row as it is now, lets the block change it,
      # and writes it before releasing the lock.
      #
      # @param script_name [String] the script namespace
      # @param scope [String] the settings scope
      # @yieldparam fresh [Object] the stored row ({} when there is none)
      # @yieldreturn [Hash, nil] the row to store, or nil to store nothing
      # @return [Hash, nil] the row as stored, or nil when the block returned
      #   nil or the write failed (failures are reported and rolled back)
      def update_settings(script_name, scope = ":")
        stored = nil
        @db.transaction(mode: :immediate) do
          updated = yield get_settings(script_name, scope)
          raise Sequel::Rollback if updated.nil?

          blob = serialize_settings(script_name, updated)
          raise Sequel::Rollback unless blob

          upsert_settings(script_name, scope, blob)
          stored = updated
        end
        stored
      rescue Sequel::DatabaseError => db_err
        report_database_error(db_err)
        nil
      end

      private

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
