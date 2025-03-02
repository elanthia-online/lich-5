# Carve out from Lich5 for the module Settings
# 2024-06-13

module Lich
  module Common
    require 'sequel'
    module Settings
      @file       = File.join(DATA_DIR, "lich.db3")
      @db         = Sequel.sqlite(@file)
      @table_name = :script_auto_settings

      def self.setup!
        @db.create_table?(@table_name) do
          text :script
          text :scope
          blob :hash
        end
        @_table = @db[@table_name]
        @_table
      end

      def self.table
        return @_table if @_table
        self.setup!
      end

      def self.current_script_settings(scope = ":")
        entry = self.table.first(script: Script.current.name, scope: scope)
        return {} if entry.nil?
        Marshal.load(entry[:hash])
      end

      def self.set_script_settings(scope = ":", name, value)
        current = self.current_script_settings(scope)
        current[name] = value
        updated = Sequel::SQL::Blob.new(Marshal.dump(current))
        self.table
            .where(script: Script.current.name, scope: scope)
            .insert_conflict(:replace)
            .insert(script: Script.current.name, scope: scope, hash: updated)
      end

      def self.[](name)
        self.current_script_settings[name]
      end

      def self.[]=(name, value)
        self.set_script_settings(name, value)
      end

      def self.to_h
        self.current_script_settings
      end

      def self.to_hash(scope = ":")
        self.current_script_settings(scope)
      end

      def self.char
        self.current_script_settings("#{XMLData.game}:#{XMLData.name}")
      end

      def self.save
        # :noop
      end
    end
  end
end
