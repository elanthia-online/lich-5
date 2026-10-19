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

      it 're-raises an ArgumentError from the block as itself, not as a database error' do
        @adapter.save_settings('go2', { 'keep' => 1 }, 'DR')

        expect {
          @adapter.update_settings('go2', 'DR') { |_fresh| raise ArgumentError, 'bad arg' }
        }.to raise_error(ArgumentError, 'bad arg')
        expect(stored_row('go2', 'DR')).to eq('keep' => 1)
        expect(messages).to be_empty
      end

      it 'stores nothing and re-raises when the block raises' do
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

        it 'leaves a truncated row untouched and raises like a read does' do
          store_raw("\x04\x08")
          yielded = false

          expect { @adapter.update_settings('go2', 'DR') { |fresh| yielded = true; fresh } }.to raise_error(ArgumentError, /marshal data too short/)
          expect { @adapter.get_settings('go2', 'DR') }.to raise_error(ArgumentError, /marshal data too short/)
          expect(yielded).to be(false)
          expect(raw_row.b).to eq("\x04\x08".b)
        end

        it 'leaves a row in a foreign format untouched and raises like a read does' do
          store_raw('not marshal')

          expect { @adapter.update_settings('go2', 'DR') { |fresh| fresh } }.to raise_error(TypeError)
          expect { @adapter.get_settings('go2', 'DR') }.to raise_error(TypeError)
          expect(raw_row).to eq('not marshal')
        end

        it 'updates a row whose bytes were stored as TEXT, comparing them as bytes' do
          db = SQLite3::Database.new(db_file)
          db.execute('INSERT OR REPLACE INTO script_auto_settings (script, scope, hash) VALUES (?, ?, ?)',
                     ['go2', 'DR', Marshal.dump({ 'old' => 1 }).force_encoding(Encoding::UTF_8)])
          expect(db.get_first_value("SELECT typeof(hash) FROM script_auto_settings WHERE script = 'go2'")).to eq('text')
          db.close

          expect(@adapter.update_settings('go2', 'DR') { |fresh| fresh.merge('new' => 2) }).to eq('old' => 1, 'new' => 2)
          expect(stored_row('go2', 'DR')).to eq('old' => 1, 'new' => 2)
        end
      end

      context 'when another writer changes the row' do
        # Commits through a separate raw connection, as another Lich process does.
        def commit_from_other_connection(sql, binds = [])
          db = SQLite3::Database.new(db_file)
          db.busy_timeout(200)
          db.execute(sql, binds)
        ensure
          db&.close
        end

        def put_row(script, scope, hash)
          commit_from_other_connection('INSERT OR REPLACE INTO script_auto_settings (script, scope, hash) VALUES (?, ?, ?)',
                                       [script, scope, SQLite3::Blob.new(Marshal.dump(hash))])
        end

        it 'does not hold the write lock while the block runs, so other writers are not held up' do
          observed = nil
          @adapter.update_settings('go2', 'DR') do |fresh|
            probe = SQLite3::Database.new(db_file)
            probe.busy_timeout(200)
            begin
              probe.execute('BEGIN IMMEDIATE')
              observed = :acquired
              probe.execute('ROLLBACK')
            rescue SQLite3::BusyException
              observed = :busy
            ensure
              probe.close
            end
            fresh.merge('a' => 1)
          end

          expect(observed).to eq(:acquired)
          expect(stored_row('go2', 'DR')).to eq('a' => 1)
        end

        it 'does not stall other threads of this process while the block runs' do
          # The other writer is a thread of this process on its own connection,
          # as when another script writes lich.db3. A wait inside SQLite keeps
          # the GVL, so if the write lock were held here, that thread would hold
          # up the whole process until its busy timeout ran out and then fail.
          writer_result = nil
          @adapter.update_settings('go2', 'DR') do |fresh|
            writer = Thread.new do
              db = SQLite3::Database.new(db_file)
              db.busy_timeout(1000)
              db.execute('INSERT OR REPLACE INTO script_auto_settings (script, scope, hash) VALUES (?, ?, ?)',
                         ['other', 'DR', SQLite3::Blob.new(Marshal.dump({ 'b' => 2 }))])
              writer_result = :stored
            rescue SQLite3::BusyException
              writer_result = :busy
            ensure
              db&.close
            end
            writer.join
            fresh.merge('a' => 1)
          end

          expect(writer_result).to eq(:stored)
          expect(stored_row('other', 'DR')).to eq('b' => 2)
          expect(stored_row('go2', 'DR')).to eq('a' => 1)
        end

        it 'holds no SQLite lock whenever Ruby code runs, so a thread switch cannot leave one held' do
          # A thread can be switched out wherever Ruby code runs. If it held a
          # lock there, a writer that waits inside SQLite (Lich.db keeps the
          # GVL while it waits) would stall the process until its busy timeout.
          # Every C method returning into Ruby is such a point: probe there.
          @adapter.save_settings('go2', { 'mine' => 1 }, 'DR')
          @adapter.update_settings('go2', 'DR') { |fresh| fresh } # connect before tracing
          probe = SQLite3::Database.new(db_file)
          probe.busy_timeout(0)
          me = Thread.current
          held = []
          trace = TracePoint.new(:c_return) do |tp|
            next unless Thread.current.equal?(me)

            begin
              probe.execute('BEGIN EXCLUSIVE')
              probe.execute('ROLLBACK')
            rescue SQLite3::BusyException
              held << "#{tp.defined_class}##{tp.method_id}"
            end
          end

          trace.enable { @adapter.update_settings('go2', 'DR') { |fresh| fresh.merge('new' => 2) } }
          trace.enable { @adapter.update_settings('fresh-row', 'DR') { |fresh| fresh.merge('first' => 1) } }

          expect(held).to be_empty
          expect(stored_row('go2', 'DR')).to eq('mine' => 1, 'new' => 2)
          expect(stored_row('fresh-row', 'DR')).to eq('first' => 1)
        ensure
          probe&.close
        end

        it 'reads the row again and calls the block again when it changed during the block' do
          @adapter.save_settings('go2', { 'mine' => 1 }, 'DR')
          seen = []

          result = @adapter.update_settings('go2', 'DR') do |fresh|
            seen << fresh.dup
            put_row('go2', 'DR', fresh.merge('theirs' => 2)) if seen.size == 1
            fresh.merge('new' => 3)
          end

          expect(seen).to eq([{ 'mine' => 1 }, { 'mine' => 1, 'theirs' => 2 }])
          expect(result).to eq('mine' => 1, 'theirs' => 2, 'new' => 3)
          expect(stored_row('go2', 'DR')).to eq('mine' => 1, 'theirs' => 2, 'new' => 3)
        end

        it 'keeps the other writer\'s row when it creates a row that was missing when read' do
          seen = []

          result = @adapter.update_settings('go2', 'DR') do |fresh|
            seen << fresh.dup
            put_row('go2', 'DR', { 'theirs' => 2 }) if seen.size == 1
            fresh.merge('new' => 3)
          end

          expect(seen).to eq([{}, { 'theirs' => 2 }])
          expect(result).to eq('theirs' => 2, 'new' => 3)
          expect(stored_row('go2', 'DR')).to eq('theirs' => 2, 'new' => 3)
        end

        it 'still stores the row when another writer wrote identical bytes in between' do
          @adapter.save_settings('go2', { 'same' => 1 }, 'DR')
          calls = 0

          result = @adapter.update_settings('go2', 'DR') do |fresh|
            calls += 1
            put_row('go2', 'DR', { 'same' => 1 }) if calls == 1
            fresh.merge('new' => 2)
          end

          expect(calls).to eq(1)
          expect(result).to eq('same' => 1, 'new' => 2)
        end

        it 'gives up once the busy timeout has passed while the row changes every time, and reports it' do
          allow(Lich).to receive(:sqlite_busy_timeout_ms).and_return(200)
          calls = 0
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          result = @adapter.update_settings('go2', 'DR') do |fresh|
            calls += 1
            put_row('go2', 'DR', { 'theirs' => calls })
            fresh.merge('mine' => calls)
          end
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

          expect(result).to be_nil
          expect(elapsed).to be >= 0.2
          expect(elapsed).to be < 2
          expect(calls).to be >= described_class::MIN_UPDATE_ATTEMPTS
          expect(stored_row('go2', 'DR')).to eq('theirs' => calls)
          expect(messages).to include(['error', a_string_including("kept changing, gave up after #{calls} attempts")])
        end

        it 'stops at MIN_UPDATE_ATTEMPTS when slow attempts use up the busy timeout first' do
          allow(Lich).to receive(:sqlite_busy_timeout_ms).and_return(200)
          calls = 0

          result = @adapter.update_settings('go2', 'DR') do |fresh|
            calls += 1
            sleep 0.08
            put_row('go2', 'DR', { 'theirs' => calls })
            fresh.merge('mine' => calls)
          end

          expect(result).to be_nil
          expect(calls).to eq(described_class::MIN_UPDATE_ATTEMPTS)
          expect(stored_row('go2', 'DR')).to eq('theirs' => calls)
          expect(messages).to include(['error', a_string_including("gave up after #{calls} attempts")])
        end

        it 'keeps trying past 20 attempts while within the busy timeout' do
          allow(Lich).to receive(:sqlite_busy_timeout_ms).and_return(60_000)
          calls = 0

          result = @adapter.update_settings('go2', 'DR') do |fresh|
            calls += 1
            put_row('go2', 'DR', fresh.merge('theirs' => calls)) if calls <= 30
            fresh.merge('mine' => calls)
          end

          expect(calls).to eq(31)
          expect(result).to eq('theirs' => 30, 'mine' => 31)
          expect(stored_row('go2', 'DR')).to eq('theirs' => 30, 'mine' => 31)
          expect(messages).to be_empty
        end

        it 'still tries MIN_UPDATE_ATTEMPTS times when the busy timeout is zero' do
          allow(Lich).to receive(:sqlite_busy_timeout_ms).and_return(0)
          calls = 0

          result = @adapter.update_settings('go2', 'DR') do |fresh|
            calls += 1
            put_row('go2', 'DR', { 'theirs' => calls })
            fresh.merge('mine' => calls)
          end

          expect(result).to be_nil
          expect(calls).to eq(described_class::MIN_UPDATE_ATTEMPTS)
          expect(messages).to include(['error', a_string_including('gave up after 3 attempts')])
        end
      end

      it 'reports a lock it cannot get within the busy timeout and stores nothing' do
        db = @adapter.instance_variable_get(:@db)
        db.run('PRAGMA busy_timeout = 100')
        @adapter.save_settings('go2', { 'keep' => 1 }, 'DR')
        blocker = SQLite3::Database.new(db_file)
        blocker.execute('BEGIN IMMEDIATE')

        result = @adapter.update_settings('go2', 'DR') { |fresh| fresh.merge('a' => 1) }
        blocker.execute('ROLLBACK')

        expect(result).to be_nil
        expect(stored_row('go2', 'DR')).to eq('keep' => 1)
        expect(messages).to include(['error', a_string_including('Database error while saving settings')])
      ensure
        blocker&.close
      end

      it 'reports a Sequel error that is not a database error (a full connection pool) and returns nil' do
        allow(@adapter.instance_variable_get(:@db)).to receive(:synchronize).and_raise(Sequel::PoolTimeout, 'timeout: 5.0')
        yielded = false

        expect(@adapter.update_settings('go2', 'DR') { |fresh| yielded = true; fresh }).to be_nil
        expect(yielded).to be(false)
        expect(messages).to include(['error', a_string_including('Database error while saving settings')])
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
    let(:messages) { [] }

    before do
      captured = messages
      allow(Lich).to receive(:log)
      stub_const('Lich::Messaging', Module.new { define_singleton_method(:msg) { |kind, text| captured << [kind, text] } })
    end

    it 'still refuses a non-Hash and returns false' do
      @adapter = described_class.new(tmp_dir, :script_auto_settings)

      expect(@adapter.save_settings('go2', [1], 'DR')).to be(false)
    end

    # update_settings reports these as database errors; save_settings must too.
    it 'reports a Sequel error that is not a database error (a full connection pool) as a database error' do
      @adapter = described_class.new(tmp_dir, :script_auto_settings)
      allow(@adapter.instance_variable_get(:@db)).to receive(:synchronize).and_raise(Sequel::PoolTimeout, 'timeout: 5.0')

      expect(@adapter.save_settings('go2', { 'a' => 1 }, 'DR')).to be(false)
      expect(messages).to eq([['error', '--- Database error while saving settings ---']])
    end

    it 'reports a database error (the upsert fails) as a database error' do
      # The adapter's own table has no (script, scope) key, so the upsert fails.
      @adapter = described_class.new(tmp_dir, :script_auto_settings)

      expect(@adapter.save_settings('go2', { 'a' => 1 }, 'DR')).to be(false)
      expect(messages).to eq([['error', '--- Database error while saving settings ---']])
    end

    it 'still reports any other error as unexpected and returns false' do
      @adapter = described_class.new(tmp_dir, :script_auto_settings)
      allow(@adapter.instance_variable_get(:@db)).to receive(:synchronize).and_raise(IOError, 'boom')

      expect(@adapter.save_settings('go2', { 'a' => 1 }, 'DR')).to be(false)
      expect(messages).to eq([['error', '--- Unexpected error while saving settings ---']])
    end
  end
end
