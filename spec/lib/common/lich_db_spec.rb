# frozen_string_literal: true

require_relative '../../spec_helper'

# These tests exercise real SQLite3 behavior (WAL mode, schema creation).
# They are skipped when the sqlite3 gem is not installed in the test
# environment.
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

    it 'allows concurrent reads during writes' do
      db_path = "#{tmpdir}/lich.db3"

      setup_db = SQLite3::Database.new(db_path)
      setup_db.execute('PRAGMA journal_mode=WAL;')
      setup_db.execute('CREATE TABLE IF NOT EXISTS lich_settings (name TEXT NOT NULL, value TEXT, PRIMARY KEY(name));')
      setup_db.execute("INSERT INTO lich_settings(name, value) VALUES('test_key', 'test_value');")
      setup_db.close

      writer = SQLite3::Database.new(db_path)
      reader = SQLite3::Database.new(db_path)

      writer.execute('BEGIN IMMEDIATE TRANSACTION;')
      writer.execute("INSERT OR REPLACE INTO lich_settings(name, value) VALUES('writer_key', 'writer_value');")

      value = reader.get_first_value("SELECT value FROM lich_settings WHERE name='test_key';")
      expect(value).to eq('test_value')
    ensure
      begin
        writer&.execute('ROLLBACK;')
      rescue StandardError
        nil
      end
      reader&.close
      writer&.close
    end
  end

  describe 'init_db schema creation' do
    def create_schema(db)
      db.execute('PRAGMA journal_mode=WAL;')
      db.execute('CREATE TABLE IF NOT EXISTS lich_settings (name TEXT NOT NULL, value TEXT, PRIMARY KEY(name));')
    end

    it 'creates the lich_settings table' do
      db = SQLite3::Database.new("#{tmpdir}/lich.db3")
      create_schema(db)

      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='lich_settings';")
      expect(tables.flatten).to include('lich_settings')
    ensure
      db&.close
    end

    it 'is idempotent -- can be called twice without error' do
      db = SQLite3::Database.new("#{tmpdir}/lich.db3")

      expect { create_schema(db) }.not_to raise_error
      expect { create_schema(db) }.not_to raise_error
    ensure
      db&.close
    end
  end
end
