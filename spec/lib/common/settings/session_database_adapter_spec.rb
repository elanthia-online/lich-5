# frozen_string_literal: true

require 'rspec'
require 'sqlite3'
require 'tmpdir'

# Contract spec for the row-oriented session summary adapter.
# This verifies DB-level behavior independently from higher-level Settings proxies.
require_relative '../../../../lib/common/settings/session_database_adapter'

RSpec.describe Lich::Common::SessionDatabaseAdapter do
  let(:tmp_dir) { Dir.mktmpdir('session-db-spec') }
  let(:db_path) { File.join(tmp_dir, 'lich.db3') }
  let(:sqlite_db) { SQLite3::Database.new(db_path) }

  # Keep row access ergonomic for assertions.
  before(:each) do
    sqlite_db.results_as_hash = true
    create_session_summary_schema!(sqlite_db)
  end

  after(:each) do
    sqlite_db.close if sqlite_db
    File.delete(db_path) if File.exist?(db_path)
    Dir.rmdir(tmp_dir) if Dir.exist?(tmp_dir)
  end

  # Mirrors `Lich.init_db` behavior so adapter specs validate CRUD-only concerns.
  def create_session_summary_schema!(db)
    db.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS session_summary_state (
        pid INTEGER PRIMARY KEY,
        session_name TEXT,
        role TEXT,
        state TEXT,
        frontend TEXT,
        game_code TEXT,
        hidden INTEGER DEFAULT 0,
        started_at INTEGER,
        last_heartbeat_at INTEGER,
        os_seen_at INTEGER,
        os_seen INTEGER,
        os_name INTEGER,
        last_utilization_at INTEGER,
        metadata_json TEXT
      );
    SQL
    db.execute('CREATE INDEX IF NOT EXISTS idx_session_summary_state_session_name ON session_summary_state(session_name);')
    db.execute('CREATE INDEX IF NOT EXISTS idx_session_summary_state_heartbeat ON session_summary_state(last_heartbeat_at);')
  end

  describe '#initialize' do
    it 'does not mutate schema during adapter construction' do
      expect { described_class.new(db: sqlite_db) }.not_to raise_error
      row = sqlite_db.get_first_row("SELECT name FROM sqlite_master WHERE type='table' AND name='session_summary_state';")
      expect(row['name']).to eq('session_summary_state')
    end
  end

  describe '#upsert_session' do
    it 'inserts a new session row' do
      adapter = described_class.new(db: sqlite_db)

      adapter.upsert_session(
        pid: 11_111,
        session_name: 'Tsetem',
        role: 'session',
        state: 'running',
        started_at: 1_700_000_000,
        os_seen_at: 1_700_000_001,
        os_seen: 1,
        os_name: 1,
        last_heartbeat_at: 1_700_000_005
      )

      row = sqlite_db.get_first_row('SELECT * FROM session_summary_state WHERE pid = ?;', [11_111])
      expect(row['session_name']).to eq('Tsetem')
      expect(row['state']).to eq('running')
      expect(row['os_seen']).to eq(1)
      expect(row['os_name']).to eq(1)
      expect(row['pid']).to eq(11_111)
    end

    it 'updates an existing row with the same pid' do
      adapter = described_class.new(db: sqlite_db)

      adapter.upsert_session(pid: 22_222, session_name: 'Initial', role: 'session', state: 'starting', started_at: 10, last_heartbeat_at: 10, os_seen: 1)
      adapter.upsert_session(pid: 22_222, session_name: 'Updated', role: 'session', state: 'running', started_at: 10, last_heartbeat_at: 20, os_seen: 0)

      row = sqlite_db.get_first_row('SELECT * FROM session_summary_state WHERE pid = ?;', [22_222])
      expect(row['session_name']).to eq('Updated')
      expect(row['state']).to eq('running')
      expect(row['os_seen']).to eq(0)
      expect(row['last_heartbeat_at']).to eq(20)
    end
  end

  describe '#active_sessions' do
    it 'returns all registered rows (report-time staleness classification)' do
      adapter = described_class.new(db: sqlite_db)

      adapter.upsert_session(pid: 1, session_name: 'One', role: 'session', state: 'running', started_at: 1, last_heartbeat_at: 1)
      adapter.upsert_session(pid: 2, session_name: 'Two', role: 'session', state: 'running', started_at: 1, last_heartbeat_at: 1)

      rows = adapter.active_sessions
      expect(rows.map { |r| r['pid'] }).to contain_exactly(1, 2)
    end
  end

  describe '#delete_session' do
    # Added for regression coverage of explicit row deletion behavior.
    it 'removes the requested pid from row and duplicate reports' do
      adapter = described_class.new(db: sqlite_db)

      adapter.upsert_session(pid: 201, session_name: 'Tsetem', role: 'session', state: 'running', started_at: 1, last_heartbeat_at: 1)
      adapter.upsert_session(pid: 202, session_name: 'Tsetem', role: 'session', state: 'running', started_at: 1, last_heartbeat_at: 1)

      adapter.delete_session(pid: 201)

      expect(adapter.find_session(pid: 201)).to be_nil
      expect(adapter.active_sessions.map { |r| r['pid'] }).not_to include(201)
      expect(adapter.duplicate_active_session_names.map { |r| r['session_name'] }).not_to include('Tsetem')
    end
  end

  describe '#find_session' do
    it 'returns a single row by pid when present' do
      adapter = described_class.new(db: sqlite_db)

      adapter.upsert_session(pid: 3, session_name: 'Three', role: 'session', state: 'running', started_at: 1, last_heartbeat_at: 1)
      row = adapter.find_session(pid: 3)

      expect(row).not_to be_nil
      expect(row['pid']).to eq(3)
    end
  end

  describe '#duplicate_active_session_names' do
    it 'reports duplicate active session names without enforcing uniqueness' do
      adapter = described_class.new(db: sqlite_db)

      adapter.upsert_session(pid: 101, session_name: 'Tsetem', role: 'session', state: 'running', started_at: 1, last_heartbeat_at: 1)
      adapter.upsert_session(pid: 102, session_name: 'Tsetem', role: 'session', state: 'running', started_at: 1, last_heartbeat_at: 1)
      adapter.upsert_session(pid: 103, session_name: 'Other', role: 'session', state: 'running', started_at: 1, last_heartbeat_at: 1)

      duplicates = adapter.duplicate_active_session_names

      tsetem = duplicates.find { |row| row['session_name'] == 'Tsetem' }
      expect(tsetem).not_to be_nil
      expect(tsetem['duplicate_count']).to eq(2)
    end
  end
end
