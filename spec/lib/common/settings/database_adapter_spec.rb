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
    @adapter&.instance_variable_get(:@version_db)&.close
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
          expect(calls).to be > described_class::MIN_UPDATE_ATTEMPTS
          expect(stored_row('go2', 'DR')).to eq('theirs' => calls)
          expect(messages).to include(['error', a_string_including("kept changing, gave up after #{calls} attempts")])
        end

        it 'keeps trying past 20 attempts while within the busy timeout' do
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

  describe '#data_version' do
    let(:db_file) { File.join(tmp_dir, 'lich.db3') }

    before do
      # The production table, as Lich.init_db creates it before Settings loads.
      other_connection { |db| db.execute('CREATE TABLE script_auto_settings (script TEXT NOT NULL, scope TEXT, hash BLOB, PRIMARY KEY(script, scope));') }
      @adapter = described_class.new(tmp_dir, :script_auto_settings)
    end

    # Another Lich process: its own connection to the same file.
    def other_connection
      db = SQLite3::Database.new(db_file)
      yield db
    ensure
      db&.close
    end

    def commit_elsewhere(hash = { 'k' => rand })
      other_connection do |db|
        db.execute('INSERT OR REPLACE INTO script_auto_settings (script, scope, hash) VALUES (?, ?, ?)',
                   ['go2', 'DR', SQLite3::Blob.new(Marshal.dump(hash))])
      end
    end

    it 'returns an Integer that stays the same while nothing is committed' do
      first = @adapter.data_version

      expect(first).to be_a(Integer)
      expect(Array.new(5) { @adapter.data_version }).to all(eq(first))
      @adapter.get_settings('go2', 'DR') # a read is not a commit
      expect(@adapter.data_version).to eq(first)
    end

    it 'changes when another connection commits' do
      before = @adapter.data_version

      commit_elsewhere

      expect(@adapter.data_version).not_to eq(before)
    end

    it 'changes when this adapter itself saves, through any of its connections' do
      before = @adapter.data_version
      @adapter.save_settings('go2', { 'a' => 1 }, 'DR')
      after_save = @adapter.data_version
      Thread.new { @adapter.update_settings('go2', 'DR') { |row| row.merge('b' => 2) } }.join

      expect(after_save).not_to eq(before)
      expect(@adapter.data_version).not_to eq(after_save)
    end

    it 'does not change for a transaction another connection rolled back' do
      before = @adapter.data_version
      other_connection do |db|
        db.execute('BEGIN IMMEDIATE')
        db.execute("INSERT INTO script_auto_settings (script, scope, hash) VALUES ('go2', 'DR', x'00')")
        expect(@adapter.data_version).to eq(before) # still uncommitted
        db.execute('ROLLBACK')
      end

      expect(@adapter.data_version).to eq(before)
    end

    it 'returns nil at once, without waiting for the busy timeout, while another connection holds the exclusive lock' do
      before = @adapter.data_version
      other_connection do |db|
        db.execute('BEGIN EXCLUSIVE')
        db.execute("INSERT INTO script_auto_settings (script, scope, hash) VALUES ('go2', 'DR', x'00')")
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        expect(@adapter.data_version).to be_nil
        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1.0
        db.execute('COMMIT')
      end

      expect(@adapter.data_version).to be_a(Integer).and(satisfy { |v| v != before })
    end

    it 'holds no lock once it returns, so another connection can take the exclusive lock at once' do
      @adapter.data_version

      other_connection do |db|
        db.busy_timeout(0)
        expect { db.execute('BEGIN EXCLUSIVE') }.not_to raise_error
        db.execute('ROLLBACK')
      end
    end

    it 'answers every thread when called from several threads at once' do
      results = Queue.new
      threads = Array.new(8) { Thread.new { 50.times { results << @adapter.data_version } } }
      committer = Thread.new { 10.times { commit_elsewhere } }
      (threads + [committer]).each(&:join)

      values = Array.new(results.size) { results.pop }
      expect(values.size).to eq(400)
      expect(values).to all(be_a(Integer).or(be_nil))
      expect(values.compact).not_to be_empty
    end

    context 'when the database cannot be opened for the check' do
      before do
        allow(Lich).to receive(:log)
        @adapter.data_version # opens the version connection
        @adapter.send(:close_version_connection, @adapter.instance_variable_get(:@version_db))
        allow(SQLite3::Database).to receive(:new).and_call_original
        allow(SQLite3::Database).to receive(:new).with(db_file).and_raise(SQLite3::CantOpenException, 'unable to open database file')
      end

      it 'returns nil and logs the problem once, however often it is asked' do
        expect(Array.new(3) { @adapter.data_version }).to eq([nil, nil, nil])
        expect(Lich).to have_received(:log).with(a_string_including('cannot tell whether settings changed', 'SQLite3::CantOpenException')).once
      end

      it 'recovers once the database can be opened again' do
        expect(@adapter.data_version).to be_nil
        allow(SQLite3::Database).to receive(:new).with(db_file).and_call_original

        expect(@adapter.data_version).to be_a(Integer)
      end
    end

    it 'reopens its connection after a failed check instead of reusing a broken one' do
      allow(Lich).to receive(:log)
      @adapter.data_version
      broken = @adapter.instance_variable_get(:@version_db)
      allow(broken).to receive(:execute_batch2).and_raise(SQLite3::IOException, 'disk I/O error')

      expect(@adapter.data_version).to be_nil
      expect(broken).to be_closed
      expect(@adapter.data_version).to be_a(Integer)
      expect(@adapter.instance_variable_get(:@version_db)).not_to equal(broken)
    end

    it 'never repeats or goes back to a value it returned before its connection was reopened' do
      allow(Lich).to receive(:log)
      @adapter.data_version # opens the version connection
      3.times { commit_elsewhere }
      before_reopen = @adapter.data_version
      broken = @adapter.instance_variable_get(:@version_db)
      allow(broken).to receive(:execute_batch2).and_raise(SQLite3::IOException, 'disk I/O error')
      expect(@adapter.data_version).to be_nil

      after_reopen = @adapter.data_version
      unchanged = @adapter.data_version
      commit_elsewhere
      later = @adapter.data_version

      expect(after_reopen).to be > before_reopen
      expect(unchanged).to eq(after_reopen)
      expect(later).to be > after_reopen
    end

    it 'sets the new offset before another thread can see a reopened connection' do
      allow(Lich).to receive(:log)
      @adapter.data_version # opens the version connection
      old_db = @adapter.instance_variable_get(:@version_db)
      old_base = @adapter.instance_variable_get(:@version_base)
      allow(old_db).to receive(:execute_batch2).and_raise(SQLite3::IOException, 'disk I/O error')
      expect(@adapter.data_version).to be_nil # closes it

      # Another thread could run, or this one be interrupted, between any two
      # lines. Record the offset it would read at every line at which the new
      # connection is already visible.
      seen = []
      adapter_file = @adapter.method(:data_version).source_location.first
      trace = TracePoint.new(:line) do |tp|
        next unless tp.path == adapter_file

        db = @adapter.instance_variable_get(:@version_db)
        seen << @adapter.instance_variable_get(:@version_base) if db && !db.equal?(old_db)
      end
      trace.enable { expect(@adapter.data_version).to be_a(Integer) }

      expect(seen).not_to be_empty
      expect(seen).to all(be > old_base)
    end

    it 'answers a thread that asks now and then while another thread asks in a tight loop' do
      @adapter.data_version
      stop = false
      looper = Thread.new { @adapter.data_version until stop }
      latencies = []
      occasional = Thread.new do
        10.times do
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          @adapter.data_version
          latencies << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
          sleep 0.01
        end
      end
      occasional.join(5)
      stop = true
      looper.join
      occasional.join

      expect(latencies.size).to eq(10)
      expect(latencies.max).to be < 0.5
    end

    it 'takes no Ruby lock to answer once its connection is open, so it never waits behind another thread' do
      first = @adapter.data_version
      locked = Queue.new
      release = Queue.new
      holder = Thread.new do
        @adapter.instance_variable_get(:@version_mutex).synchronize do
          locked << true
          release.pop
        end
      end
      locked.pop

      answer = nil
      asker = Thread.new { answer = @adapter.data_version }
      finished = asker.join(2)
      release << true
      holder.join
      asker.join

      expect(finished).to eq(asker)
      expect(answer).to eq(first)
    end

    describe 'closing the version connection' do
      before { @adapter.data_version } # opens the version connection

      it 'needs to be told which connection to close' do
        current = @adapter.instance_variable_get(:@version_db)

        expect { @adapter.send(:close_version_connection) }.to raise_error(ArgumentError)
        expect(current).not_to be_closed
        expect(@adapter.instance_variable_get(:@version_db)).to equal(current)
      end

      it 'closes the connection it is given while that is still the current one' do
        current = @adapter.instance_variable_get(:@version_db)

        expect(@adapter.send(:close_version_connection, current)).to be(true)
        expect(current).to be_closed
        expect(@adapter.instance_variable_get(:@version_db)).to be_nil
      end

      it 'leaves the current connection open when given one that was already replaced' do
        old = @adapter.instance_variable_get(:@version_db)
        @adapter.send(:close_version_connection, old)
        @adapter.data_version # opens a new one
        current = @adapter.instance_variable_get(:@version_db)

        expect(@adapter.send(:close_version_connection, old)).to be(false)
        expect(current).not_to be_closed
        expect(@adapter.instance_variable_get(:@version_db)).to equal(current)
        expect(@adapter.data_version).to be_a(Integer)
      end

      it 'counts a connection that failed to open (nil) as current only while none is open' do
        current = @adapter.instance_variable_get(:@version_db)

        expect(@adapter.send(:close_version_connection, nil)).to be(false)
        expect(current).not_to be_closed
        @adapter.send(:close_version_connection, current)
        expect(@adapter.send(:close_version_connection, nil)).to be(true)
      end
    end

    context 'when another thread replaces the connection during a check' do
      before do
        allow(Lich).to receive(:log)
        @adapter.data_version # opens the version connection
        3.times { commit_elsewhere }
        @old = @adapter.instance_variable_get(:@version_db)
      end

      # What another thread does when its own check fails: close the
      # connection, then open a new one with its next check.
      def replace_connection_from_another_thread
        value = nil
        Thread.new do
          @adapter.send(:close_version_connection, @old)
          value = @adapter.data_version
        end.join(2)
        value
      end

      it 'discards the value read on the replaced connection' do
        replaced_value = nil
        allow(@old).to receive(:execute_batch2).and_wrap_original do |original, *args|
          result = original.call(*args)
          replaced_value = replace_connection_from_another_thread
          result
        end

        expect(@adapter.data_version).to be_nil
        expect(replaced_value).to be_a(Integer)
        expect(@adapter.data_version).to eq(replaced_value)
        commit_elsewhere
        expect(@adapter.data_version).to be > replaced_value
      end

      it 'leaves the new connection open, and logs nothing, when the read fails on the replaced one' do
        replaced_value = nil
        allow(@old).to receive(:execute_batch2) do
          replaced_value = replace_connection_from_another_thread
          raise SQLite3::MisuseException, 'cannot use a closed database'
        end

        expect(@adapter.data_version).to be_nil
        current = @adapter.instance_variable_get(:@version_db)
        expect(current).not_to equal(@old)
        expect(current).not_to be_closed
        expect(@adapter.data_version).to eq(replaced_value)
        expect(Lich).not_to have_received(:log)
      end
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
