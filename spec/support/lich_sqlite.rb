# frozen_string_literal: true

# Test copies of the SQLite connection helpers defined in lib/lich.rb.
#
# lib/lich.rb cannot be loaded in specs (it redefines Lich.log and other
# methods that spec_helper and login_spec_helper stub). Settings and its
# DatabaseAdapter call Lich.open_sequel_sqlite while settings.rb is loading, and
# SessionDatabaseAdapter calls Lich.open_sqlite_db, so specs that load them need
# these first. Keep in step with lib/lich.rb.

require 'sqlite3'
require 'sequel'

module Lich
  DEFAULT_SQLITE_BUSY_TIMEOUT_MS = 5000 unless const_defined?(:DEFAULT_SQLITE_BUSY_TIMEOUT_MS)

  unless respond_to?(:sqlite_busy_timeout_ms)
    def self.sqlite_busy_timeout_ms
      DEFAULT_SQLITE_BUSY_TIMEOUT_MS
    end
  end

  unless respond_to?(:open_sqlite_db)
    def self.open_sqlite_db(path)
      db = SQLite3::Database.new(path)
      db.busy_timeout(sqlite_busy_timeout_ms)
      db
    end
  end

  unless respond_to?(:open_sequel_sqlite)
    def self.open_sequel_sqlite(path)
      db = Sequel.sqlite(path)
      db.run("PRAGMA busy_timeout = #{sqlite_busy_timeout_ms.to_i}")
      db
    end
  end
end
