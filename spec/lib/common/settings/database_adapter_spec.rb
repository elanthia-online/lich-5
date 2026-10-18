# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'sqlite3'
require 'sequel'

require_relative '../../../support/lich_sqlite'

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

  describe '#update_settings' do
    let(:messages) { [] }
    let(:db_file) { File.join(tmp_dir, 'lich.db3') }

    before do
      captured = messages
      stub_const('Lich::Messaging', Module.new { define_singleton_method(:msg) { |kind, text| captured << [kind, text] } })
      allow(Lich).to receive(:log)
    end

    # The production table, as Lich.init_db creates it before Settings loads.
    def create_production_table
      db = SQLite3::Database.new(db_file)
      db.execute('CREATE TABLE IF NOT EXISTS script_auto_settings (script TEXT NOT NULL, scope TEXT, hash BLOB, PRIMARY KEY(script, scope));')
    ensure
      db&.close
    end

    def stored_row(script, scope)
      db = SQLite3::Database.new(db_file)
      blob = db.get_first_value('SELECT hash FROM script_auto_settings WHERE script = ? AND scope = ?', [script, scope])
      blob ? Marshal.load(blob) : nil
    ensure
      db&.close
    end

    context 'with the production table' do
      before do
        create_production_table
        @adapter = described_class.new(tmp_dir, :script_auto_settings)
      end

      it 'yields an empty Hash when the row does not exist yet and stores what the block returns' do
        yielded = nil
        result = @adapter.update_settings('go2', 'DR') { |fresh| yielded = fresh.dup; fresh.merge('a' => 1) }

        expect(yielded).to eq({})
        expect(result).to eq('a' => 1)
        expect(stored_row('go2', 'DR')).to eq('a' => 1)
      end

      it 'yields the row as stored by another connection, not a copy this adapter read earlier' do
        @adapter.save_settings('go2', { 'mine' => 1 }, 'DR')
        other = described_class.new(tmp_dir, :script_auto_settings)
        other.save_settings('go2', { 'mine' => 1, 'theirs' => 2 }, 'DR')
        other.instance_variable_get(:@db).disconnect

        result = @adapter.update_settings('go2', 'DR') { |fresh| fresh.merge('new' => 3) }

        expect(result).to eq('mine' => 1, 'theirs' => 2, 'new' => 3)
        expect(stored_row('go2', 'DR')).to eq('mine' => 1, 'theirs' => 2, 'new' => 3)
      end

      it 'only touches the requested (script, scope) row' do
        @adapter.save_settings('go2', { 'game' => 1 }, 'DR')
        @adapter.save_settings('go2', { 'char' => 1 }, 'DR:Alpha')

        @adapter.update_settings('go2', 'DR') { |fresh| fresh.merge('game2' => 2) }

        expect(stored_row('go2', 'DR:Alpha')).to eq('char' => 1)
      end

      it 'stores nothing when the block returns nil' do
        @adapter.save_settings('go2', { 'keep' => 1 }, 'DR')

        expect(@adapter.update_settings('go2', 'DR') { |_fresh| nil }).to be_nil
        expect(stored_row('go2', 'DR')).to eq('keep' => 1)
      end

      it 'stores false as a value (only a nil row aborts)' do
        result = @adapter.update_settings('go2', 'DR') { |fresh| fresh['off'] = false; fresh }

        expect(result).to eq('off' => false)
        expect(stored_row('go2', 'DR')).to eq('off' => false)
      end

      it 'refuses a block result that is not a Hash and reports it' do
        @adapter.save_settings('go2', { 'keep' => 1 }, 'DR')

        expect(@adapter.update_settings('go2', 'DR') { |_fresh| [1, 2] }).to be_nil
        expect(stored_row('go2', 'DR')).to eq('keep' => 1)
        expect(messages).to include(['error', a_string_including('settings must be a Hash, got Array')])
      end

      it 'refuses a row that cannot be serialized and reports it' do
        expect(@adapter.update_settings('go2', 'DR') { |fresh| fresh.merge('io' => $stdout) }).to be_nil
        expect(stored_row('go2', 'DR')).to be_nil
        expect(messages).to include(['error', a_string_including('failed to serialize settings')])
      end

      it 'rolls back and re-raises when the block raises' do
        @adapter.save_settings('go2', { 'keep' => 1 }, 'DR')

        expect {
          @adapter.update_settings('go2', 'DR') { |_fresh| raise KeyError, 'boom' }
        }.to raise_error(KeyError, 'boom')
        expect(stored_row('go2', 'DR')).to eq('keep' => 1)
        expect(@adapter.update_settings('go2', 'DR') { |fresh| fresh.merge('after' => 2) }).to eq('keep' => 1, 'after' => 2)
      end

      context 'when the stored row cannot be read' do
        def store_raw(bytes)
          db = SQLite3::Database.new(db_file)
          db.execute('INSERT OR REPLACE INTO script_auto_settings (script, scope, hash) VALUES (?, ?, ?)', ['go2', 'DR', SQLite3::Blob.new(bytes)])
        ensure
          db&.close
        end

        def raw_row
          db = SQLite3::Database.new(db_file)
          db.get_first_value('SELECT hash FROM script_auto_settings WHERE script = ? AND scope = ?', %w[go2 DR])
        ensure
          db&.close
        end

        it 'leaves a truncated row untouched and reports it' do
          store_raw("\x04\x08")
          yielded = false

          expect(@adapter.update_settings('go2', 'DR') { |fresh| yielded = true; fresh }).to be_nil
          expect(yielded).to be(false)
          expect(raw_row.b).to eq("\x04\x08".b)
          expect(messages).to include(['error', a_string_including('Database error while saving settings')])
        end

        it 'leaves a row in a foreign format untouched and raises like a read does' do
          store_raw('not marshal')

          expect { @adapter.update_settings('go2', 'DR') { |fresh| fresh } }.to raise_error(TypeError)
          expect { @adapter.get_settings('go2', 'DR') }.to raise_error(TypeError)
          expect(raw_row).to eq('not marshal')
        end
      end

      it 'holds the write lock while the block runs' do
        observed = nil
        @adapter.update_settings('go2', 'DR') do |fresh|
          probe = SQLite3::Database.new(db_file)
          begin
            probe.execute('BEGIN IMMEDIATE')
            observed = :acquired
            probe.execute('ROLLBACK')
          rescue SQLite3::BusyException
            observed = :busy
          ensure
            probe.close
          end
          fresh
        end

        expect(observed).to eq(:busy)
      end

      it 'reports a lock it cannot get within the busy timeout and stores nothing' do
        db = @adapter.instance_variable_get(:@db)
        db.run('PRAGMA busy_timeout = 100')
        blocker = SQLite3::Database.new(db_file)
        blocker.execute('BEGIN IMMEDIATE')
        yielded = false

        result = @adapter.update_settings('go2', 'DR') { |fresh| yielded = true; fresh.merge('a' => 1) }

        expect(result).to be_nil
        expect(yielded).to be(false)
        expect(messages).to include(['error', a_string_including('Database error while saving settings')])
      ensure
        blocker&.execute('ROLLBACK')
        blocker&.close
      end
    end

    it 'reports a database error and returns nil instead of raising' do
      # The adapter's own table has no (script, scope) key, so the upsert fails.
      @adapter = described_class.new(tmp_dir, :script_auto_settings)

      expect(@adapter.update_settings('go2', 'DR') { |fresh| fresh.merge('a' => 1) }).to be_nil
      expect(stored_row('go2', 'DR')).to be_nil
      expect(messages).to include(['error', a_string_including('Database error while saving settings')])
    end
  end

  describe '#save_settings' do
    before do
      allow(Lich).to receive(:log)
      stub_const('Lich::Messaging', Module.new { def self.msg(*); end })
    end

    it 'still refuses a non-Hash and returns false' do
      @adapter = described_class.new(tmp_dir, :script_auto_settings)

      expect(@adapter.save_settings('go2', [1], 'DR')).to be(false)
    end
  end
end
