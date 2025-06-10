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
        blob = Sequel::SQL::Blob.new(Marshal.dump(settings))

        if @table.where(script: script_name, scope: scope).count > 0
          @table
            .where(script: script_name, scope: scope)
            .insert_conflict(:replace)
            .update(hash: blob)
        else
          @table.insert(
            script: script_name,
            scope: scope,
            hash: blob
          )
        end
      end
    end
  end
end
