# frozen_string_literal: true

# SQLite connection helpers from lib/common/sqlite_connection.rb.
#
# lib/lich.rb cannot be loaded in specs (it redefines Lich.log and other
# methods that spec_helper and login_spec_helper stub). Settings and its
# DatabaseAdapter call Lich.open_sequel_sqlite while settings.rb is loading, and
# SessionDatabaseAdapter calls Lich.open_sqlite_db, so specs that load them need
# these first. lib/lich.rb requires the same file.

require 'sqlite3'
require 'sequel'

require_relative '../../lib/common/sqlite_connection'
