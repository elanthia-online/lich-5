# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'sqlite3'
require 'sequel'

module Lich
  DEFAULT_SQLITE_BUSY_TIMEOUT_MS = 5000 unless const_defined?(:DEFAULT_SQLITE_BUSY_TIMEOUT_MS)

  def self.sqlite_busy_timeout_ms
    DEFAULT_SQLITE_BUSY_TIMEOUT_MS
  end

  def self.open_sequel_sqlite(path)
    db = Sequel.sqlite(path)
    db.run("PRAGMA busy_timeout = #{sqlite_busy_timeout_ms}")
    db
  end
end

require_relative '../../../../lib/common/settings/database_adapter'

RSpec.describe Lich::Common::DatabaseAdapter do
  let(:tmp_dir) { Dir.mktmpdir('settings-db-adapter-spec') }

  after do
    db = @adapter&.instance_variable_get(:@db)
    db&.disconnect
    FileUtils.remove_entry(tmp_dir) if Dir.exist?(tmp_dir)
  end

  it 'opens settings storage with the core sqlite busy timeout' do
    @adapter = described_class.new(tmp_dir, :script_auto_settings)
    db = @adapter.instance_variable_get(:@db)

    expect(db.fetch('PRAGMA busy_timeout;').first[:timeout]).to eq(Lich.sqlite_busy_timeout_ms)
  end
end
