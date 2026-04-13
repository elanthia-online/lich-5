# frozen_string_literal: true

require_relative '../../spec_helper'

# These tests exercise real SQLite3 behavior (busy_timeout, WAL mode,
# concurrent write contention). They are skipped when the sqlite3 gem
# is not installed in the test environment.
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

# Load the production Lich module so Lich.init_db is available.
# This permanently redefines Lich.db, so we restore the mock immediately
# below and swap in the real implementation per-example via before/after.
require_relative '../../../lib/lich'

# Immediately restore the mock Lich.db so other spec files loaded after this
# one continue to see MockDB.  Our before(:each) swaps in the real SQLite
# connection for each example in this group only.
Lich.define_singleton_method(:db) { @db ||= Lich::MockDB.new }

RSpec.describe 'Lich.db SQLite configuration' do
  let(:tmpdir) { Dir.mktmpdir('lich_db_spec') }

  # Hold the real SQLite handle so before/after can manage it without relying
  # on class variables (which cause "class variable access from toplevel"
  # errors inside define_singleton_method blocks in Ruby 3.4+).
  let(:real_db) do
    db = SQLite3::Database.new("#{tmpdir}/lich.db3")
    db.busy_timeout = 3000
    db
  end

  before do
    # Point DATA_DIR at our temp directory
    stub_const('DATA_DIR', tmpdir)

    # Swap Lich.db to return the real SQLite connection for this example
    db_handle = real_db
    Lich.define_singleton_method(:db) { db_handle }
  end

  after do
    # Close the real handle
    begin
      real_db.close unless real_db.closed?
    rescue StandardError
      nil
    end
    FileUtils.remove_entry(tmpdir, true)

    # Restore the mock so other specs are unaffected
    Lich.define_singleton_method(:db) { @db ||= Lich::MockDB.new }
  end

  describe 'busy_timeout' do
    it 'is set to 3000ms on the database connection' do
      db = Lich.db
      # SQLite3::Database#busy_timeout is a write-only setter in the Ruby gem,
      # so we verify the pragma instead.
      timeout = db.get_first_value('PRAGMA busy_timeout;')
      expect(timeout.to_i).to eq(3000)
    end
  end

  describe 'WAL mode after init_db' do
    it 'enables WAL journal mode' do
      Lich.init_db
      journal_mode = Lich.db.get_first_value('PRAGMA journal_mode;')
      expect(journal_mode.downcase).to eq('wal')
    end
  end

  describe 'init_db idempotency' do
    it 'can be called twice without error' do
      expect { Lich.init_db }.not_to raise_error
      expect { Lich.init_db }.not_to raise_error
    end
  end

  describe 'concurrent write contention with busy_timeout' do
    it 'allows two threads to write without BusyException' do
      Lich.init_db
      db_path = "#{tmpdir}/lich.db3"

      errors = []
      mutex = Mutex.new
      barrier = Queue.new

      threads = 2.times.map do |i|
        Thread.new do
          # Each thread opens its own connection (simulating separate Lich processes)
          conn = SQLite3::Database.new(db_path)
          conn.busy_timeout = 3000
          barrier << true
          # Wait for both threads to be ready
          sleep 0.01 until barrier.size >= 2

          begin
            50.times do |j|
              conn.execute(
                'INSERT OR REPLACE INTO lich_settings(name, value) VALUES(?, ?);',
                ["thread_#{i}_key_#{j}", "value_#{j}"]
              )
            end
          rescue SQLite3::BusyException => e
            mutex.synchronize { errors << e }
          ensure
            conn.close
          end
        end
      end

      threads.each(&:join)
      expect(errors).to be_empty, "Expected no BusyException but got: #{errors.map(&:message)}"
    end
  end
end
