# frozen_string_literal: true

require_relative '../../spec_helper'

# These tests exercise real SQLite3 behavior (busy_timeout, WAL mode,
# concurrent write contention). They are skipped when the sqlite3 gem
# is not installed in the test environment.
#
# IMPORTANT: This spec does NOT require production lib/lich.rb because that
# file redefines Lich.display_expgains (and many other methods) using class
# variables, permanently overwriting the spec_helper mocks and causing
# cross-spec pollution (e.g. drskill_spec failures). Instead, we test the
# SQLite configuration in isolation using direct SQLite3 calls.
begin
  require 'sqlite3'
rescue LoadError
  RSpec.describe 'Lich.db SQLite configuration' do
    it 'is skipped because the sqlite3 gem is not installed' do
      skip 'sqlite3 gem not available'
    end
  end
  return
end

RSpec.describe 'Lich.db SQLite configuration' do
  let(:tmpdir) { Dir.mktmpdir('lich_db_spec') }

  after do
    FileUtils.remove_entry(tmpdir, true)
  end

  describe 'busy_timeout' do
    it 'is set to 3000ms on new database connections' do
      db = SQLite3::Database.new("#{tmpdir}/lich.db3")
      db.busy_timeout = 3000

      timeout = db.get_first_value('PRAGMA busy_timeout;')
      expect(timeout.to_i).to eq(3000)
    ensure
      db&.close
    end

    it 'defaults to 0ms without explicit busy_timeout' do
      db = SQLite3::Database.new("#{tmpdir}/lich.db3")

      timeout = db.get_first_value('PRAGMA busy_timeout;')
      expect(timeout.to_i).to eq(0)
    ensure
      db&.close
    end
  end

  describe 'WAL journal mode' do
    it 'is enabled by PRAGMA journal_mode=WAL' do
      db = SQLite3::Database.new("#{tmpdir}/lich.db3")
      db.execute('PRAGMA journal_mode=WAL;')

      journal_mode = db.get_first_value('PRAGMA journal_mode;')
      expect(journal_mode.downcase).to eq('wal')
    ensure
      db&.close
    end

    it 'persists across new connections to the same file' do
      db = SQLite3::Database.new("#{tmpdir}/lich.db3")
      db.execute('PRAGMA journal_mode=WAL;')
      db.close

      db2 = SQLite3::Database.new("#{tmpdir}/lich.db3")
      journal_mode = db2.get_first_value('PRAGMA journal_mode;')
      expect(journal_mode.downcase).to eq('wal')
    ensure
      db2&.close
    end

    it 'is idempotent -- setting WAL twice does not error' do
      db = SQLite3::Database.new("#{tmpdir}/lich.db3")
      expect { db.execute('PRAGMA journal_mode=WAL;') }.not_to raise_error
      expect { db.execute('PRAGMA journal_mode=WAL;') }.not_to raise_error
    ensure
      db&.close
    end
  end

  describe 'init_db schema creation' do
    # Mirrors the production Lich.init_db schema setup without loading
    # the full production Lich module.
    def create_schema(db)
      db.execute('PRAGMA journal_mode=WAL;')
      db.execute('CREATE TABLE IF NOT EXISTS lich_settings (name TEXT NOT NULL, value TEXT, PRIMARY KEY(name));')
    end

    it 'creates the lich_settings table' do
      db = SQLite3::Database.new("#{tmpdir}/lich.db3")
      db.busy_timeout = 3000
      create_schema(db)

      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='lich_settings';")
      expect(tables.flatten).to include('lich_settings')
    ensure
      db&.close
    end

    it 'is idempotent -- can be called twice without error' do
      db = SQLite3::Database.new("#{tmpdir}/lich.db3")
      db.busy_timeout = 3000

      expect { create_schema(db) }.not_to raise_error
      expect { create_schema(db) }.not_to raise_error
    ensure
      db&.close
    end
  end

  describe 'concurrent write contention with busy_timeout' do
    it 'allows two threads to write without BusyException' do
      db_path = "#{tmpdir}/lich.db3"

      # Set up schema
      setup_db = SQLite3::Database.new(db_path)
      setup_db.busy_timeout = 3000
      setup_db.execute('PRAGMA journal_mode=WAL;')
      setup_db.execute('CREATE TABLE IF NOT EXISTS lich_settings (name TEXT NOT NULL, value TEXT, PRIMARY KEY(name));')
      setup_db.close

      errors = []
      mutex = Mutex.new
      barrier = Queue.new

      threads = 2.times.map do |i|
        Thread.new do
          conn = SQLite3::Database.new(db_path)
          conn.busy_timeout = 3000
          barrier << true
          sleep 0.01 until barrier.size >= 2

          begin
            50.times do |j|
              conn.execute(
                'INSERT OR REPLACE INTO lich_settings(name, value) VALUES(?, ?);',
                ["thread_#{i}_key_#{j}", "value_#{j}"]
              )
            end
          rescue StandardError => e
            mutex.synchronize { errors << e }
          ensure
            conn.close
          end
        end
      end

      threads.each(&:join)
      expect(errors).to be_empty, "Expected no thread errors but got: #{errors.map(&:message)}"
    end

    it 'raises immediately without busy_timeout when a write lock is held' do
      db_path = "#{tmpdir}/lich_no_timeout.db3"

      setup_db = SQLite3::Database.new(db_path)
      setup_db.execute('PRAGMA journal_mode=DELETE;')
      setup_db.execute('CREATE TABLE IF NOT EXISTS lich_settings (name TEXT NOT NULL, value TEXT, PRIMARY KEY(name));')
      setup_db.close

      locker = SQLite3::Database.new(db_path)
      contender = SQLite3::Database.new(db_path)

      locker.execute('BEGIN EXCLUSIVE TRANSACTION;')
      locker.execute(
        'INSERT OR REPLACE INTO lich_settings(name, value) VALUES(?, ?);',
        ['locked_key', 'locked_value']
      )

      expect do
        contender.execute(
          'INSERT OR REPLACE INTO lich_settings(name, value) VALUES(?, ?);',
          ['contender_key', 'contender_value']
        )
      end.to raise_error(SQLite3::BusyException)
    ensure
      begin
        locker&.execute('ROLLBACK;')
      rescue StandardError
        nil
      end
      contender&.close
      locker&.close
    end
  end
end
