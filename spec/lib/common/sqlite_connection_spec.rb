# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'
require 'sqlite3'
require 'sequel'

require_relative '../../support/lich_sqlite'

# Lock waits on Lich's Sequel connections to lich.db3. A thread waiting for
# another connection's write lock must not stop the rest of the process: the
# lock holder may be a thread of this same process that needs to run Ruby code
# before it can commit.
RSpec.describe 'Lich.open_sequel_sqlite lock waits' do
  let(:tmp_dir) { Dir.mktmpdir('lich-sqlite-busy-spec') }
  let(:path) { File.join(tmp_dir, 'lich.db3') }

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # Opens the database the way core settings storage does and creates a table.
  def open_db
    db = Lich.open_sequel_sqlite(path)
    db.create_table?(:rows) { Integer :n }
    @dbs << db
    db
  end

  # A plain sqlite3 connection that takes the write lock and holds it until
  # the caller commits.
  def hold_write_lock
    holder = SQLite3::Database.new(path)
    @raw << holder
    holder.execute('BEGIN IMMEDIATE')
    holder.execute('INSERT INTO rows (n) VALUES (0)')
    holder
  end

  # Runs a write on its own thread and records how it ended and when.
  def writer(db, value)
    Thread.new do
      started = monotonic
      begin
        db[:rows].insert(n: value)
        [:ok, monotonic - started]
      rescue Sequel::DatabaseError => e
        [e.class, monotonic - started]
      end
    end
  end

  # Counts how often a thread that only sleeps gets to run for `seconds`.
  def ticks_during(seconds)
    ticks = 0
    deadline = monotonic + seconds
    while monotonic < deadline
      sleep 0.01
      ticks += 1
    end
    ticks
  end

  before do
    @dbs = []
    @raw = []
  end

  after do
    @raw.each { |c| c.close unless c.closed? }
    @dbs.each(&:disconnect)
    FileUtils.remove_entry(tmp_dir) if Dir.exist?(tmp_dir)
  end

  it 'lets a second writer commit once a same-process transaction holding the write lock commits' do
    db = open_db
    locked = Queue.new
    holder = Thread.new do
      db.transaction(mode: :immediate) do
        db[:rows].insert(n: 1)
        locked << true
        # Pure Ruby work with the write lock held, as a read-modify-write does.
        busy_until = monotonic + 0.5
        x = 0
        x += 1 while monotonic < busy_until
      end
      monotonic
    end
    locked.pop
    result, waited = writer(db, 2).value
    committed_at = holder.value

    expect(result).to eq(:ok)
    expect(waited).to be < 3.0
    expect(committed_at).to be < monotonic
    expect(db[:rows].select_order_map(:n)).to eq([1, 2])
  end

  it 'keeps other threads running while a writer waits for the lock' do
    db = open_db
    holder = hold_write_lock
    waiting = writer(db, 1)
    sleep 0.05
    ticks = ticks_during(0.5)
    still_waiting = waiting.alive?
    holder.execute('COMMIT')

    expect(ticks).to be >= 20
    expect(still_waiting).to be(true)
    expect(waiting.value.first).to eq(:ok)
    expect(db[:rows].select_order_map(:n)).to eq([0, 1])
  end

  it 'waits on every pooled connection, not only the first one' do
    db = open_db
    holder = hold_write_lock
    waiting = (1..3).map { |n| writer(db, n) }
    sleep 0.3
    holder.execute('COMMIT')

    expect(waiting.map { |t| t.value.first }).to eq(%i[ok ok ok])
    expect(db[:rows].select_order_map(:n)).to eq([0, 1, 2, 3])
  end

  it 'gives up with a database error once the lock has been held for the busy timeout' do
    allow(Lich).to receive(:sqlite_busy_timeout_ms).and_return(200)
    db = open_db
    holder = hold_write_lock
    result, waited = writer(db, 1).value
    holder.execute('COMMIT')

    expect(result).to eq(Sequel::DatabaseError)
    expect(waited).to be >= 0.2
    expect(waited).to be < 2.0
    expect(db[:rows].select_order_map(:n)).to eq([0])
  end

  it 'waits again for the full busy timeout on a later lock wait on the same connection' do
    allow(Lich).to receive(:sqlite_busy_timeout_ms).and_return(300)
    db = open_db
    go = Queue.new
    results = Queue.new
    # One thread holds one pooled connection across both waits.
    worker = Thread.new do
      db.synchronize do |conn|
        2.times do |i|
          go.pop
          begin
            conn.execute('INSERT INTO rows (n) VALUES (?)', [i + 1])
            results << :ok
          rescue SQLite3::BusyException
            results << :busy
          end
        end
      end
    end
    outcomes = 2.times.map do
      holder = hold_write_lock
      go << true
      sleep 0.1
      holder.execute('COMMIT')
      outcome = results.pop
      # Start the next wait after the first one's deadline has passed.
      sleep 0.4
      outcome
    end
    worker.join

    expect(outcomes).to eq(%i[ok ok])
    expect(db[:rows].select_order_map(:n)).to eq([0, 0, 1, 2])
  end

  it 'finishes a write before delivering an interrupt the caller had already deferred' do
    db = open_db
    holder = hold_write_lock
    ready = Queue.new
    caller_thread = Thread.new do
      Thread.current.report_on_exception = false
      Thread.handle_interrupt(RuntimeError => :never) do
        ready << true
        sleep 0.01 until Thread.pending_interrupt?
        db[:rows].insert(n: 1)
      end
    end
    ready.pop
    caller_thread.raise(RuntimeError, 'deferred by caller')
    sleep 0.3
    holder.execute('COMMIT')

    expect { caller_thread.join(5) }.to raise_error(RuntimeError, 'deferred by caller')
    expect(db[:rows].select_order_map(:n)).to eq([0, 1])
  end

  describe 'which statements defer interrupts' do
    # Records the interrupt masks this thread sets while the block runs.
    def masks_set_during
      masks = []
      me = Thread.current
      allow(Thread).to receive(:handle_interrupt).and_wrap_original do |original, *args, &block|
        masks << args.first if Thread.current.equal?(me)
        original.call(*args, &block)
      end
      result = yield
      [result, masks]
    end

    it 'defers interrupts while preparing and stepping statements on a pooled connection' do
      db = open_db
      db.synchronize do |conn|
        count, masks = masks_set_during { conn.get_first_value('SELECT count(*) FROM rows') }

        expect(count).to eq(0)
        # One for Statement.new (prepare), at least one for #step.
        expect(masks.size).to be >= 2
        expect(masks).to all(eq(Object => :never))
      end
    end

    it 'defers interrupts while execute_batch2 runs on a pooled connection' do
      db = open_db
      db.synchronize do |conn|
        rows, masks = masks_set_during { conn.execute_batch2('SELECT count(*) AS c FROM rows') }

        expect(rows).to eq([['0']])
        expect(masks).to eq([{ Object => :never }])
      end
    end

    it 'leaves execute_batch2 on other sqlite3 connections alone' do
      open_db
      plain = SQLite3::Database.new(path)
      @raw << plain
      rows, masks = masks_set_during { plain.execute_batch2('SELECT count(*) AS c FROM rows') }

      expect(rows).to eq([['0']])
      expect(masks).to be_empty
    end

    it 'leaves statements on other sqlite3 connections alone' do
      open_db
      plain = SQLite3::Database.new(path)
      @raw << plain
      expect(SQLite3::Statement.ancestors).to include(Lich::SQLiteBusyWait::Statement)
      count, masks = masks_set_during { plain.get_first_value('SELECT count(*) FROM rows') }

      expect(count).to eq(0)
      expect(masks).to be_empty
    end

    it 'leaves a plain connection alone even after it has been given its own busy handler' do
      open_db
      plain = SQLite3::Database.new(path)
      @raw << plain
      plain.busy_handler { |_count| true }
      expect(SQLite3::Statement.ancestors).to include(Lich::SQLiteBusyWait::Statement)
      _, masks = masks_set_during do
        plain.prepare('SELECT count(*) FROM rows') { |stmt| stmt.execute.to_a }
      end

      expect(masks).to be_empty
    end
  end

  it 'keeps an unclosed statement on a pooled connection from being freed until it is closed' do
    db = open_db
    refs = ObjectSpace::WeakMap.new
    db.synchronize do |conn|
      # Dropped without close, as a statement whose caller was interrupted is.
      2.times { |i| refs[i] = conn.prepare('SELECT n FROM rows') }
      closed = conn.prepare('SELECT n FROM rows')
      closed.close
      refs[:closed] = closed
    end
    GC.start(full_mark: true, immediate_sweep: true)

    expect(refs.key?(0) && refs.key?(1)).to be(true)
    expect([refs[0], refs[1]]).to all(satisfy { |st| !st.closed? })
    db.synchronize do |conn|
      expect(conn.instance_variable_get(:@lich_open_statements).keys).to contain_exactly(refs[0], refs[1])
    end
  end

  it 'does not hold a statement on a plain sqlite3 connection open after it is dropped' do
    open_db
    plain = SQLite3::Database.new(path)
    @raw << plain
    plain.prepare('SELECT n FROM rows').close

    expect(plain.instance_variable_defined?(:@lich_open_statements)).to be(false)
  end

  it 'rolls back and raises when COMMIT times out waiting for readers' do
    allow(Lich).to receive(:sqlite_busy_timeout_ms).and_return(200)
    db = open_db
    reader = SQLite3::Database.new(path)
    @raw << reader
    reader.execute('BEGIN')
    reader.execute('SELECT count(*) FROM rows') # holds a read lock until COMMIT
    error = nil
    begin
      db.transaction { db[:rows].insert(n: 1) }
    rescue Sequel::DatabaseError => e
      error = e
    end
    reader.execute('COMMIT')

    expect(error&.message).to match(/locked/)
    expect(db.synchronize(&:transaction_active?)).to be(false)
    expect(db[:rows].select_order_map(:n)).to eq([])
  end

  it 'falls back to the C busy timeout when the connection has no busy handler API' do
    plain = SQLite3::Database.new(path)
    @raw << plain
    plain.busy_timeout(1234)
    plain.singleton_class.send(:undef_method, :busy_handler)

    expect(Lich::SQLiteBusyWait.install(plain, 5000)).to be(plain)
    expect(plain).not_to be_a(Lich::SQLiteBusyWait::Connection)
    expect(plain.get_first_value('PRAGMA busy_timeout')).to eq(1234)
  end

  it 'still sets the busy timeout on new connections when the Ruby busy handler is unavailable' do
    allow(Lich::SQLiteBusyWait).to receive(:install) { |conn, _timeout_ms| conn }
    db = open_db
    timeouts = db.synchronize { |conn| conn.get_first_value('PRAGMA busy_timeout') }

    expect(timeouts).to eq(Lich.sqlite_busy_timeout_ms)
  end

  # A Ruby busy handler runs inside sqlite3_step. Thread#kill, Thread#raise or
  # Timeout delivered while it sleeps would unwind through SQLite and leave the
  # connection locked, so the next thread to use it would block forever with
  # the GVL held. Run in a child process so a regression hangs only the child.
  # The holder commits 0.2 s after the interrupt, well inside the 5 s timeout.
  describe 'interrupting a thread that is waiting for the lock' do
    let(:harness) do
      <<~'RUBY'
        require 'sqlite3'
        require 'sequel'
        require 'timeout'
        module Lich; end
        require ARGV[0]
        path, how = ARGV[1], ARGV[2]
        db = Lich.open_sequel_sqlite(path)
        db.create_table?(:rows) { Integer :n }
        holder = SQLite3::Database.new(path)
        if how == 'kill_in_prepare'
          # A new connection has no schema loaded, so preparing its first
          # statement needs a read lock, which an EXCLUSIVE lock blocks.
          db.disconnect
          holder.execute('BEGIN EXCLUSIVE')
        else
          holder.execute('BEGIN IMMEDIATE')
        end
        holder.execute('INSERT INTO rows (n) VALUES (0)')
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        waiter = Thread.new do
          Thread.current.report_on_exception = false
          case how
          when 'timeout' then Timeout.timeout(0.2) { db[:rows].insert(n: 1) }
          when 'kill_in_prepare' then db[:rows].count
          # sqlite3_exec waits for the lock without going through
          # SQLite3::Statement.
          when 'kill_in_batch2'
            db.synchronize { |conn| conn.execute_batch2('INSERT INTO rows (n) VALUES (1)') }
          else db[:rows].insert(n: 1)
          end
        end
        sleep 0.2
        case how
        when 'kill', 'kill_in_prepare', 'kill_in_batch2' then waiter.kill
        when 'raise' then waiter.raise(RuntimeError, 'interrupted')
        end
        sleep 0.2
        holder.execute('COMMIT')
        outcome = begin
          waiter.join(5) ? 'joined' : 'stuck'
        rescue Exception => e
          e.class.name
        end
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        # Use every pooled connection, including the interrupted one.
        writers = (2..5).map { |n| Thread.new { db[:rows].insert(n: n) } }
        writers.each(&:join)
        puts outcome, (elapsed < 1.5), db[:rows].select_order_map(:n).inspect
      RUBY
    end

    def run_harness(how)
      lib = File.expand_path('../../../lib/common/sqlite_connection.rb', __dir__)
      stdout = +''
      stderr = +''
      status = nil
      Open3.popen3(RbConfig.ruby, '-e', harness, lib, path, how) do |_in, out, err, wait|
        unless wait.join(20)
          Process.kill(:KILL, wait.pid)
          wait.join
        end
        stdout = out.read
        stderr = err.read
        status = wait.value
      end
      expect(status.success?).to be(true), "child hung or failed: #{stderr}"
      stdout.lines.map(&:strip)
    end

    { 'kill' => 'joined', 'raise' => 'RuntimeError', 'timeout' => 'Timeout::Error',
      'kill_in_batch2' => 'joined' }.each do |how, expected_outcome|
      it "delivers #{how} after the lock wait and leaves the connection usable" do
        lines = run_harness(how)

        expect(lines[0]).to eq(expected_outcome)
        expect(lines[1]).to eq('true')
        # The interrupted write finishes once the lock frees; the interrupt
        # is delivered after it.
        expect(lines[2]).to eq('[0, 1, 2, 3, 4, 5]')
      end
    end

    it 'delivers kill after a lock wait inside statement preparation and leaves the connection usable' do
      lines = run_harness('kill_in_prepare')

      expect(lines).to eq(['joined', 'true', '[0, 2, 3, 4, 5]'])
    end
  end

  # Child-process cases for what an interrupted or sleeping lock wait leaves
  # behind. Each child prints one line per check.
  describe 'after a lock wait' do
    let(:harness) do
      <<~'RUBY'
        require 'sqlite3'
        require 'sequel'
        module Lich; end
        require ARGV[0]
        path, how = ARGV[1], ARGV[2]
        Lich.define_singleton_method(:sqlite_busy_timeout_ms) { 300 } if how.start_with?('kill_in_')
        $stdout.sync = true
        db = Lich.open_sequel_sqlite(path)
        db.create_table?(:rows) { Integer :n }
        holder = SQLite3::Database.new(path)
        mono = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        # No GC first: freeing a leaked statement here would hide the leak.
        open_statements = -> { ObjectSpace.each_object(SQLite3::Statement).count { |st| !st.closed? } }
        case how
        when 'gc_unclosed', 'gc_after_kill_in_prepare'
          if how == 'gc_after_kill_in_prepare'
            # The kill arrives while a new connection waits inside prepare,
            # and is delivered once prepare succeeds.
            db.disconnect
            holder.execute('BEGIN EXCLUSIVE')
            k = Thread.new { db[:rows].count }
            sleep 0.2
            k.kill
            sleep 0.2
            holder.execute('COMMIT')
            k.join
            puts open_statements.call
          end
          holder.execute('BEGIN EXCLUSIVE')
          writer = Thread.new do
            db.synchronize do |conn|
              # Statements dropped without close on the connection that waits.
              20.times { conn.prepare('SELECT n FROM rows') } if how == 'gc_unclosed'
              conn.execute('INSERT INTO rows (n) VALUES (1)')
            end
          end
          sleep 0.3
          started = mono.call
          GC.start(full_mark: true, immediate_sweep: true)
          puts(mono.call - started < 1.0)
          holder.execute('COMMIT')
          writer.join
        when 'kill_in_begin', 'kill_in_commit'
          if how == 'kill_in_begin'
            holder.execute('BEGIN EXCLUSIVE')
          else
            holder.execute('BEGIN')
            holder.execute('SELECT count(*) FROM rows') # a read lock blocks COMMIT
          end
          rescued = Queue.new
          k = Thread.new do
            Thread.current.report_on_exception = false
            begin
              db.transaction(mode: :immediate) { db[:rows].insert(n: 1) }
            rescue StandardError => e
              rescued << e.class.name
            end
            sleep 1.5
            db.transaction { db[:rows].insert(n: 2) }
          end
          sleep 0.1
          k.kill
          dead = k.join(1)
          holder.execute('COMMIT')
          puts(dead ? 'dead' : "alive #{k.status}")
          puts(rescued.empty? ? 'not rescued' : rescued.pop)
          puts db.synchronize(&:transaction_active?)
          other = SQLite3::Database.new(path)
          other.busy_timeout = 1000
          other.execute('INSERT INTO rows (n) VALUES (3)')
          sleep 1.6
        end
        puts db[:rows].select_order_map(:n).inspect
      RUBY
    end

    def run_harness(how)
      lib = File.expand_path('../../../lib/common/sqlite_connection.rb', __dir__)
      stdout = +''
      stderr = +''
      status = nil
      Open3.popen3(RbConfig.ruby, '-e', harness, lib, path, how) do |_in, out, err, wait|
        unless wait.join(20)
          Process.kill(:KILL, wait.pid)
          wait.join
        end
        stdout = out.read
        stderr = err.read
        status = wait.value
      end
      expect(status.success?).to be(true), "child hung or failed: #{stderr}"
      stdout.lines.map(&:strip)
    end

    # GC frees an unclosed statement with sqlite3_finalize, which waits with
    # the GVL held for the connection mutex that the sleeping waiter holds.
    it 'lets GC run while a pooled connection with unclosed statements waits for the lock' do
      expect(run_harness('gc_unclosed')).to eq(['true', '[1]'])
    end

    it 'closes a statement whose preparation was cut short by a kill, and GC then runs during a lock wait' do
      expect(run_harness('gc_after_kill_in_prepare')).to eq(['0', 'true', '[1]'])
    end

    it 'lets a thread killed while BEGIN IMMEDIATE waits for the lock die' do
      expect(run_harness('kill_in_begin')).to eq(['dead', 'not rescued', 'false', '[3]'])
    end

    it 'rolls back and releases the lock when a thread is killed while COMMIT waits for readers' do
      expect(run_harness('kill_in_commit')).to eq(['dead', 'not rescued', 'false', '[3]'])
    end
  end
end
