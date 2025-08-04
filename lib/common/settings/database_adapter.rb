module Lich
  module Common
    # Database adapter to separate database concerns
    class DatabaseAdapter
      def initialize(data_dir, table_name)
        @file = File.join(data_dir, "lich.db3")
        @db = Sequel.sqlite(@file)
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
          @table
            .insert_conflict(target: [:script, :scope], update: { hash: blob })
            .insert(script: script_name, scope: scope, hash: blob)
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
    end
  end
end
