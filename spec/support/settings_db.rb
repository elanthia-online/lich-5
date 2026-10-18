# frozen_string_literal: true

# Helpers for specs that use a real on-disk settings database (lich.db3).
#
# The table is created with the schema Lich.init_db uses in lib/lich.rb
# (lib/lich.rb can't be loaded in specs). Its PRIMARY KEY matters: the
# settings adapter's upsert relies on it.

require 'sequel'
require 'sqlite3'

module SettingsSpecDB
  SCHEMA = 'CREATE TABLE IF NOT EXISTS script_auto_settings ' \
           '(script TEXT NOT NULL, scope TEXT, hash BLOB, PRIMARY KEY(script, scope));'

  module_function

  def path(data_dir)
    File.join(data_dir, 'lich.db3')
  end

  def with_db(data_dir)
    db = Sequel.sqlite(path(data_dir), timeout: 5000)
    yield db
  ensure
    db&.disconnect
  end

  # Creates the settings table in data_dir/lich.db3.
  def prepare(data_dir)
    with_db(data_dir) { |db| db.run(SCHEMA) }
  end

  # Writes one row, as any Lich version would.
  def write(data_dir, script, scope, value)
    with_db(data_dir) do |db|
      blob = Sequel::SQL::Blob.new(Marshal.dump(value))
      db[:script_auto_settings]
        .insert_conflict(target: %i[script scope], update: { hash: blob })
        .insert(script: script, scope: scope, hash: blob)
    end
  end

  # Writes raw bytes into a row (for unreadable-row cases).
  def write_raw(data_dir, script, scope, bytes)
    with_db(data_dir) do |db|
      db[:script_auto_settings].insert(script: script, scope: scope, hash: Sequel::SQL::Blob.new(bytes))
    end
  end

  # @return [Hash{Array(String, String) => Object}] [script, scope] => stored value
  def rows(data_dir)
    with_db(data_dir) do |db|
      db[:script_auto_settings].all.to_h { |r| [[r[:script], r[:scope]], Marshal.load(r[:hash])] }
    end
  end
end
