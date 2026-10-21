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

  # Makes every insert or update of the row with this scope fail inside
  # SQLite, as a real write failure would (the upsert can take either path).
  def fail_writes_to(data_dir, scope)
    with_db(data_dir) do |db|
      %w[INSERT UPDATE].each do |event|
        db.run("CREATE TRIGGER fail_#{event.downcase}_#{scope.gsub(/\W/, '_')} BEFORE #{event} ON script_auto_settings " \
               "WHEN NEW.scope = #{db.literal(scope)} BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END")
      end
    end
  end

  # @return [Hash{Array(String, String) => Object}] [script, scope] => stored
  #   value, or :unreadable for a row that can't be loaded
  def rows(data_dir)
    with_db(data_dir) do |db|
      db[:script_auto_settings].all.to_h do |r|
        value = begin
          Marshal.load(r[:hash])
        rescue StandardError
          :unreadable
        end
        [[r[:script], r[:scope]], value]
      end
    end
  end
end
