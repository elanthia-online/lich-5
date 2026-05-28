# frozen_string_literal: true

require 'tmpdir'
require 'sqlite3'

# Minimal DATA_DIR for database creation
DATA_DIR = Dir.tmpdir unless defined?(DATA_DIR)

require_relative '../../lib/lich'

RSpec.describe 'Lich.db' do
  before do
    # Reset the cached handle so each example creates a fresh connection
    Lich.class_variable_set(:@@lich_db, nil)
  end

  after do
    db = Lich.class_variable_get(:@@lich_db)
    db&.close unless db.nil? || db.closed?
    Lich.class_variable_set(:@@lich_db, nil)
    db_path = File.join(DATA_DIR, 'lich.db3')
    File.delete(db_path) if File.exist?(db_path)
  end

  it 'returns a SQLite3::Database instance' do
    expect(Lich.db).to be_a(SQLite3::Database)
  end

  it 'sets a busy_timeout on the database handle' do
    db = Lich.db
    timeout = db.get_first_value('PRAGMA busy_timeout;')
    expect(timeout).to eq(5000)
  end

  it 'reuses the same handle on subsequent calls' do
    first = Lich.db
    second = Lich.db
    expect(first).to be(second)
  end

  it 'only sets busy_timeout once during initialization' do
    db = Lich.db
    original_timeout = db.get_first_value('PRAGMA busy_timeout;')
    expect(original_timeout).to eq(5000)

    db.busy_timeout = 1000
    expect(db.get_first_value('PRAGMA busy_timeout;')).to eq(1000)

    second = Lich.db
    expect(second.get_first_value('PRAGMA busy_timeout;')).to eq(1000)
  end
end
