# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'
require 'timeout'
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

  # Waits until `thread` sleeps: in these examples, in the busy handler.
  def wait_until_sleeping(thread)
    deadline = monotonic + 5
    sleep 0.01 until thread.status == 'sleep' || monotonic > deadline
    expect(thread.status).to eq('sleep')
    sleep 0.05
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

  # Runs the block on a thread while another thread holds the connection's
  # Monitor for 0.3 s, and returns how long the block took.
  def time_while_monitor_held(conn)
    monitor = conn.instance_variable_get(:@lich_monitor)
    expect(monitor).to be_a(Monitor)
    held = Queue.new
    blocker = Thread.new do
      monitor.synchronize do
        held << true
        sleep 0.3
      end
    end
    expect(held.pop(timeout: 5)).to be(true)
    started = monotonic
    yield
    elapsed = monotonic - started
    blocker.join
    elapsed
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

  it 'gives up a write when an interrupt the caller defers arrives during the lock wait, and keeps it deferred' do
    db = open_db
    holder = hold_write_lock
    outcome = Queue.new
    caller_thread = Thread.new do
      Thread.current.report_on_exception = false
      Thread.handle_interrupt(RuntimeError => :never) do
        started = monotonic
        begin
          db[:rows].insert(n: 1)
          outcome << [:ok, monotonic - started, Thread.pending_interrupt?]
        rescue Sequel::DatabaseError => e
          outcome << [e.class, monotonic - started, Thread.pending_interrupt?]
        end
      end
    end
    wait_until_sleeping(caller_thread)
    caller_thread.raise(RuntimeError, 'deferred by caller')
    result = outcome.pop(timeout: 2)
    holder.execute('COMMIT')

    expect(result).not_to be_nil, 'the write kept waiting for the lock'
    expect(result[0]).to eq(Sequel::DatabaseError)
    expect(result[1]).to be < 2.0
    expect(result[2]).to be(true)
    expect { caller_thread.join(5) }.to raise_error(RuntimeError, 'deferred by caller')
    expect(db[:rows].select_order_map(:n)).to eq([0])
  end

  # Two interrupts in one lock wait. If the wait went on until the lock freed,
  # the inner Timeout's interrupt would be delivered after the outer one had
  # unwound its block, as a bare Timeout::ExitException that `rescue => e`
  # and `rescue Timeout::Error` do not catch.
  it 'ends the lock wait on the first of two Timeouts, so the other cannot escape its block later' do
    db = open_db
    holder = hold_write_lock
    log = Queue.new
    worker = Thread.new do
      Thread.current.report_on_exception = false
      begin
        begin
          Timeout.timeout(0.2) { Timeout.timeout(0.4) { db[:rows].insert(n: 1) } }
          log << :returned
        rescue StandardError => e
          log << e.class
        end
        sleep 0.5 # the caller's code after its rescue
        log << :carried_on
      rescue Exception => e # rubocop:disable Lint/RescueException -- what escapes is the point
        log << e.class
      end
    end
    sleep 0.8
    holder.execute('COMMIT')
    worker.join(5)

    expect(Array.new(2) { log.pop(timeout: 2) }).to eq([Timeout::Error, :carried_on])
    expect(db[:rows].select_order_map(:n)).to eq([0])
  end

  it 'ends a Lich.open_sqlite_db lock wait on Thread#raise, so a Timeout around the write cannot escape later' do
    open_db
    shared = Lich.open_sqlite_db(path)
    @raw << shared
    holder = hold_write_lock
    log = Queue.new
    worker = Thread.new do
      Thread.current.report_on_exception = false
      begin
        begin
          Timeout.timeout(0.4) { shared.execute('INSERT INTO rows (n) VALUES (1)') }
          log << :returned
        rescue StandardError => e
          log << e.message
        end
        sleep 0.5
        log << :carried_on
      rescue Exception => e # rubocop:disable Lint/RescueException -- what escapes is the point
        log << e.class
      end
    end
    wait_until_sleeping(worker)
    worker.raise(RuntimeError, 'raised during the wait')
    sleep 0.6
    holder.execute('COMMIT')
    worker.join(5)

    expect(Array.new(2) { log.pop(timeout: 2) }).to eq(['raised during the wait', :carried_on])
    expect(shared.execute('SELECT n FROM rows ORDER BY n').flatten).to eq([0])
  end

  # Script cleanup kills a script's threads and runs its cleanup procs without
  # joining them. The killed thread's write must not land after the cleanup's.
  it 'abandons a killed thread\'s write before the kill returns, so later writes are not overwritten' do
    db = open_db
    holder = hold_write_lock
    victim = writer(db, 1)
    wait_until_sleeping(victim)
    victim.kill
    dead = victim.join(1)
    cleanup = writer(db, 2)
    sleep 0.05
    holder.execute('COMMIT')

    expect(dead).to be(victim)
    expect(cleanup.value.first).to eq(:ok)
    expect(db[:rows].select_order_map(:n)).to eq([0, 2])
  end

  it 'keeps waiting through an interrupt inside keep_waiting_through_interrupts, and restores the flag' do
    db = open_db
    holder = hold_write_lock
    worker = Thread.new do
      Thread.current.report_on_exception = false
      Thread.handle_interrupt(Object => :never) do
        Lich::SQLiteBusyWait.keep_waiting_through_interrupts { db[:rows].insert(n: 1) }
      end
    end
    wait_until_sleeping(worker)
    worker.raise(RuntimeError, 'after the write')
    sleep 0.2
    still_waiting = worker.alive?
    holder.execute('COMMIT')

    expect { worker.join(5) }.to raise_error(RuntimeError, 'after the write')
    expect(still_waiting).to be(true)
    expect(db[:rows].select_order_map(:n)).to eq([0, 1])
    expect(worker.thread_variable_get(Lich::SQLiteBusyWait::KEEP_WAITING_KEY)).to be_nil
  end

  it 'restores the keep-waiting flag when the block raises' do
    outer = Thread.new do
      Thread.current.thread_variable_set(Lich::SQLiteBusyWait::KEEP_WAITING_KEY, :outer)
      begin
        Lich::SQLiteBusyWait.keep_waiting_through_interrupts { raise ArgumentError }
      rescue ArgumentError
        nil
      end
      Thread.current.thread_variable_get(Lich::SQLiteBusyWait::KEEP_WAITING_KEY)
    end

    expect(outer.value).to eq(:outer)
  end

  # ROLLBACK must run whole; an abandoned ROLLBACK would leave the write
  # transaction open on the pooled connection.
  it 'runs ROLLBACK with interrupts deferred and the busy handler waiting through them' do
    db = open_db
    seen = []
    allow(Lich::SQLiteBusyWait).to receive(:keep_waiting_through_interrupts).and_wrap_original do |original, &block|
      seen << db.synchronize(&:transaction_active?)
      original.call(&block)
    end
    db.transaction do
      db[:rows].insert(n: 1)
      raise Sequel::Rollback
    end

    expect(seen).to eq([true])
    expect(db.synchronize(&:transaction_active?)).to be(false)
    expect(db[:rows].select_order_map(:n)).to eq([])
  end

  describe 'which statements defer interrupts' do
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
  # The holder commits 0.2 s after the interrupt, well inside the 5 s timeout;
  # the interrupt must have ended the wait by then.
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
        ended_while_locked = !waiter.alive?
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
        puts outcome, ended_while_locked, (elapsed < 1.5), db[:rows].select_order_map(:n).inspect
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
      it "ends the lock wait on #{how}, abandons the write and leaves the connection usable" do
        lines = run_harness(how)

        expect(lines[0]).to eq(expected_outcome)
        # The interrupt ended the wait while the lock was still held, and the
        # interrupted write never ran, even after the lock freed.
        expect(lines[1]).to eq('true')
        expect(lines[2]).to eq('true')
        expect(lines[3]).to eq('[0, 2, 3, 4, 5]')
      end
    end

    it 'ends a lock wait inside statement preparation on kill and leaves the connection usable' do
      lines = run_harness('kill_in_prepare')

      expect(lines).to eq(['joined', 'true', 'true', '[0, 2, 3, 4, 5]'])
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
        when 'raise_kill_in_begin', 'raise_raise_in_begin', 'raise_kill_in_insert'
          # Two interrupts arrive during one lock wait: in BEGIN IMMEDIATE, or
          # in the first INSERT of a deferred transaction.
          holder.execute('BEGIN IMMEDIATE')
          k = Thread.new do
            Thread.current.report_on_exception = false
            mode = how.end_with?('_in_insert') ? :deferred : :immediate
            db.transaction(mode: mode) { db[:rows].insert(n: 1) }
          end
          sleep 0.1
          # Back to back, so both are queued before the waiting thread runs
          # again: the first one ends the wait.
          k.raise(RuntimeError, 'first')
          how.start_with?('raise_kill') ? k.kill : k.raise(RuntimeError, 'second')
          sleep 0.1
          holder.execute('COMMIT')
          outcome = begin
            k.join(2) ? 'ended' : 'stuck'
          rescue Exception => e
            e.message
          end
          puts outcome
          other = SQLite3::Database.new(path)
          other.busy_timeout = 1000
          puts(begin
            other.execute('INSERT INTO rows (n) VALUES (3)')
            'other process can write'
          rescue SQLite3::BusyException
            'locked'
          end)
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

    # The second interrupt is delivered as the next interrupt mask ends; that
    # must not be one inside ROLLBACK, before ROLLBACK runs.
    it 'rolls back when a thread waiting in BEGIN IMMEDIATE gets Thread#raise and then Thread#kill' do
      expect(run_harness('raise_kill_in_begin')).to eq(['ended', 'other process can write', '[3]'])
    end

    it 'rolls back when a thread waiting in BEGIN IMMEDIATE gets Thread#raise twice' do
      expect(run_harness('raise_raise_in_begin')).to eq(['first', 'other process can write', '[3]'])
    end

    it 'rolls back when a thread waiting in the first write of a transaction gets Thread#raise and then Thread#kill' do
      expect(run_harness('raise_kill_in_insert')).to eq(['ended', 'other process can write', '[3]'])
    end
  end

  # Pooled connections wait for the lock side by side and keep their
  # connections meanwhile; Sequel's pool holds 4. Threads beyond that queue on
  # the pool.
  describe 'more writers than pooled connections' do
    # Starts `count` writers at once and returns [outcome, seconds] for each,
    # where outcome is :ok or the class of the Sequel::Error raised.
    def concurrent_writers(db, count)
      start = Queue.new
      threads = (1..count).map do |n|
        Thread.new do
          start.pop
          started = monotonic
          begin
            db[:rows].insert(n: n)
            [:ok, monotonic - started]
          rescue Sequel::Error => e
            [e.class, monotonic - started]
          end
        end
      end
      count.times { start << true }
      threads
    end

    it 'waits for a free connection for three busy timeouts' do
      expect(open_db.opts[:pool_timeout]).to eq(15.0)
      allow(Lich).to receive(:sqlite_busy_timeout_ms).and_return(300)
      expect(open_db.opts[:pool_timeout]).to eq(0.9)
    end

    it 'gives a writer queued behind four waiting connections its own lock wait instead of a pool timeout' do
      db = open_db
      holder = hold_write_lock
      threads = concurrent_writers(db, 10)
      # Past the 5 s busy timeout: the four writers holding connections give up
      # and hand them to queued writers, which must still be waiting for them.
      sleep 5.6
      holder.execute('COMMIT')
      outcomes = threads.map { |t| t.value.first }

      expect(outcomes).not_to include(Sequel::PoolTimeout)
      expect(outcomes - [:ok]).to all(eq(Sequel::DatabaseError))
      expect(outcomes.count(:ok)).to be >= 6
      expect(db[:rows].count).to eq(1 + outcomes.count(:ok))
    end

    # Boundary: a lock held past every waiter's budget. Each writer fails, and
    # one still queued on the pool fails with Sequel::PoolTimeout, but only
    # after waiting the pool timeout.
    it 'raises Sequel::PoolTimeout only after a queued writer has waited the pool timeout' do
      allow(Lich).to receive(:sqlite_busy_timeout_ms).and_return(200)
      db = open_db
      holder = hold_write_lock
      threads = concurrent_writers(db, 24)
      results = threads.map(&:value)
      holder.execute('COMMIT')
      pool_timeouts = results.select { |outcome, _| outcome == Sequel::PoolTimeout }
      busy = results.select { |outcome, _| outcome == Sequel::DatabaseError }

      expect(results.map(&:first)).to all(eq(Sequel::PoolTimeout).or(eq(Sequel::DatabaseError)))
      expect(pool_timeouts).not_to be_empty
      expect(pool_timeouts.map(&:last)).to all(be >= 0.6)
      expect(busy.map(&:last)).to all(be >= 0.2)
      expect(db[:rows].select_order_map(:n)).to eq([0])
    end

    # A caller that defers interrupts around a write (Thread.handle_interrupt)
    # and is killed while it is queued on the pool holds the kill back for the
    # pool wait plus, once it has a connection, one lock wait: the kill is
    # pending when that call starts, so the call waits out its busy timeout.
    describe 'a kill sent to a writer queued with interrupts deferred' do
      # Takes all four pooled connections until `gate` gets four values.
      def take_every_connection(db, gate)
        holders = Array.new(4) { Thread.new { db.synchronize { gate.pop } } }
        holders.each { |t| wait_until_sleeping(t) }
        holders
      end

      # Starts a write inside Thread.handle_interrupt(Object => :never), kills
      # it once it is queued on the pool, and returns [thread, start time].
      def kill_masked_writer(db)
        started = monotonic
        victim = Thread.new do
          Thread.handle_interrupt(Object => :never) { db[:rows].insert(n: 1) }
          :survived
        end
        wait_until_sleeping(victim)
        victim.kill
        [victim, started]
      end

      it 'dies without writing when the pool wait ends with Sequel::PoolTimeout' do
        allow(Lich).to receive(:sqlite_busy_timeout_ms).and_return(200)
        db = open_db
        gate = Queue.new
        holders = take_every_connection(db, gate)
        victim, started = kill_masked_writer(db)
        result = victim.value
        dead_after = monotonic - started
        4.times { gate << true }
        holders.each(&:join)

        expect(result).to be_nil
        expect(dead_after).to be >= 0.6
        expect(dead_after).to be < 0.6 + 0.4
        expect(db[:rows].count).to eq(0)
      end

      it 'dies without writing after a full lock wait when a connection frees up while another process holds the lock' do
        allow(Lich).to receive(:sqlite_busy_timeout_ms).and_return(200)
        db = open_db
        holder = hold_write_lock
        gate = Queue.new
        holders = take_every_connection(db, gate)
        victim, started = kill_masked_writer(db)
        sleep 0.3
        4.times { gate << true }
        holders.each(&:join)
        result = victim.value
        dead_after = monotonic - started
        holder.execute('COMMIT')

        expect(result).to be_nil
        expect(dead_after).to be >= 0.3 + 0.2
        expect(dead_after).to be < 0.6 + 0.2 + 0.4
        expect(db[:rows].select_order_map(:n)).to eq([0])
      end
    end
  end

  it 'does not track a statement that is closed at birth (comment-only SQL)' do
    db = open_db
    20.times { db.run('UPDATE rows SET n = n; -- trailing comment') }
    shared = Lich.open_sqlite_db(path)
    @raw << shared
    20.times { shared.execute_batch('UPDATE rows SET n = n; -- trailing comment') }

    db.synchronize { |conn| expect(conn.instance_variable_get(:@lich_open_statements)).to be_empty }
    expect(shared.instance_variable_get(:@lich_open_statements)).to be_empty
  end

  # Lich.db and the session summary connection: one SQLite3::Database that
  # several threads use.
  describe 'a connection from Lich.open_sqlite_db' do
    def c_methods(klass)
      (klass.public_instance_methods(false) + klass.private_instance_methods(false)).select do |name|
        meth = klass.instance_method(name)
        meth = meth.super_method while meth && meth.owner != klass
        meth && meth.source_location.nil?
      end
    end

    it 'gets the Ruby busy handler and a Monitor around every sqlite3 C method on it and its statements' do
      open_db
      shared = Lich.open_sqlite_db(path)
      @raw << shared
      stmt = shared.prepare('SELECT n FROM rows WHERE n = ?')

      expect(shared).to be_a(Lich::SQLiteBusyWait::Connection)
      expect(shared.get_first_value('PRAGMA busy_timeout')).to eq(0)
      expect(stmt).to be_a(Lich::SQLiteBusyWait::SerializedStatement)
      wrapped_db = Lich::SQLiteBusyWait::SerializedDatabase.instance_methods(false) +
                   Lich::SQLiteBusyWait::SerializedDatabase.private_instance_methods(false)
      wrapped_stmt = Lich::SQLiteBusyWait::SerializedStatement.instance_methods(false) +
                     Lich::SQLiteBusyWait::SerializedStatement.private_instance_methods(false)
      expect(wrapped_db).to match_array(c_methods(SQLite3::Database) - Lich::SQLiteBusyWait::UNSERIALIZED_DATABASE_METHODS)
      expect(wrapped_stmt).to match_array(c_methods(SQLite3::Statement) - Lich::SQLiteBusyWait::UNSERIALIZED_STATEMENT_METHODS)
      # Private sqlite3 methods stay private.
      expect(shared.respond_to?(:exec_batch)).to be(false)
      expect(stmt.respond_to?(:stats_as_hash)).to be(false)
      stmt.close
    end

    it 'makes other threads wait for the Monitor before entering SQLite on the connection or its statements' do
      open_db
      shared = Lich.open_sqlite_db(path)
      @raw << shared
      stmt = shared.prepare('SELECT n FROM rows WHERE n = ?')
      waits = {
        changes: time_while_monitor_held(shared) { shared.changes },
        prepare: time_while_monitor_held(shared) { shared.prepare('SELECT 1').close },
        bind_param: time_while_monitor_held(shared) { stmt.bind_param(1, 1) },
        step: time_while_monitor_held(shared) { stmt.step },
        reset: time_while_monitor_held(shared) { stmt.reset! },
        execute_batch2: time_while_monitor_held(shared) { shared.execute_batch2('SELECT 1') }
      }
      free = {
        interrupt: time_while_monitor_held(shared) { shared.interrupt },
        closed: time_while_monitor_held(shared) { shared.closed? }
      }
      stmt.close

      expect(waits.values).to all(be >= 0.2)
      expect(free.values).to all(be < 0.2)
    end

    it 'leaves plain connections and their statements unserialized' do
      open_db
      Lich.open_sqlite_db(path).tap { |c| @raw << c }
      plain = SQLite3::Database.new(path)
      @raw << plain
      stmt = plain.prepare('SELECT n FROM rows')

      expect(plain).not_to be_a(Lich::SQLiteBusyWait::SerializedDatabase)
      expect(stmt).not_to be_a(Lich::SQLiteBusyWait::SerializedStatement)
      stmt.close
    end

    # A pooled connection waits at COMMIT, in the Ruby handler, for another
    # connection's read lock to go. A thread that reads through the shared
    # connection meanwhile waits for the pooled writer's pending lock. With the
    # C busy timeout it would spin with the GVL held, and nothing else could
    # run until it gave up.
    it 'lets a pooled writer waiting at COMMIT and a reader on it both finish once the read lock goes' do
      allow(Lich).to receive(:sqlite_busy_timeout_ms).and_return(1500)
      db = open_db
      shared = Lich.open_sqlite_db(path)
      @raw << shared
      reader_conn = SQLite3::Database.new(path)
      @raw << reader_conn
      reader_conn.execute('BEGIN')
      reader_conn.execute('SELECT count(*) FROM rows') # read lock until COMMIT
      started = monotonic
      pooled = writer(db, 1)
      sleep 0.2
      shared_reader = Thread.new do
        [shared.get_first_value('SELECT count(*) FROM rows'), monotonic - started]
      rescue SQLite3::BusyException => e
        [e.class, monotonic - started]
      end
      sleep 0.2
      reader_conn.execute('COMMIT')
      committed_at = monotonic - started

      expect(committed_at).to be < 0.8
      expect(pooled.value.first).to eq(:ok)
      expect(shared_reader.value.first).to eq(1)
      expect(shared_reader.value.last).to be < 1.2
    end
  end

  # Two threads on one shared connection, one waiting for the lock. Without
  # the Monitor the second thread blocks on SQLite's connection mutex with
  # the GVL held and the process hangs, so these run in a child process.
  describe 'two threads on a connection from Lich.open_sqlite_db' do
    let(:harness) do
      <<~'RUBY'
        require 'sqlite3'
        module Lich; end
        require ARGV[0]
        path, how = ARGV[1], ARGV[2]
        Lich.define_singleton_method(:sqlite_busy_timeout_ms) { 1500 }
        mono = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        setup = SQLite3::Database.new(path)
        setup.execute('CREATE TABLE rows (n INTEGER)')
        setup.close
        shared = Lich.open_sqlite_db(path)
        holder = SQLite3::Database.new(path)
        holder.execute('BEGIN IMMEDIATE')
        holder.execute('INSERT INTO rows (n) VALUES (0)')
        started = mono.call
        waiter = Thread.new do
          Thread.current.report_on_exception = false
          shared.execute('INSERT INTO rows (n) VALUES (1)')
          :ok
        end
        sleep 0.1
        other = Thread.new do
          shared.get_first_value('SELECT count(*) FROM rows')
        rescue SQLite3::BusyException => e
          e.class.name
        end
        ticks = 0
        deadline = mono.call + 0.3
        while mono.call < deadline
          sleep 0.01
          ticks += 1
        end
        waiter.kill if how == 'kill'
        # Commit at once: the killed thread must not retry its write even if
        # the lock is free by the time it runs again.
        holder.execute('COMMIT')
        waited = begin
          waiter.value.to_s
        rescue Exception => e
          e.class.name
        end
        puts ticks >= 10, waiter.status.inspect, waited, other.value.inspect, mono.call - started < 1.2
        shared.execute('INSERT INTO rows (n) VALUES (2)')
        puts shared.execute('SELECT n FROM rows ORDER BY n').flatten.inspect
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

    it 'lets the second thread run once the first one\'s lock wait ends, and other threads keep running' do
      # The reader may run before or after the write lands.
      lines = run_harness('wait')

      expect(lines.values_at(0, 1, 2, 4, 5)).to eq(['true', 'false', 'ok', 'true', '[0, 1, 2]'])
      expect(%w[1 2]).to include(lines[3])
    end

    it 'ends the waiting thread\'s lock wait on kill, abandons its write and leaves the connection usable' do
      # The reader may run before or after the holder commits.
      lines = run_harness('kill')

      expect(lines.values_at(0, 1, 4, 5)).to eq(['true', 'false', 'true', '[0, 2]'])
      expect(%w[0 1]).to include(lines[3])
    end
  end

  # sqlite3_backup_step waits for locks through the busy handler of the
  # connection at either end of the backup.
  describe 'SQLite3::Backup with a lich.db3 connection at one end' do
    let(:copy_path) { File.join(tmp_dir, 'copy.db3') }

    # Child process, so a regression that hangs can't hang the suite.
    # Another connection holds an EXCLUSIVE lock on lich.db3 while a thread
    # backs up from Lich.open_sqlite_db's connection ('src_*') or from a plain
    # database into a pooled connection ('dst_*'). In 'src_*' a second thread
    # reads through the shared connection during the wait.
    let(:harness) do
      <<~'RUBY'
        require 'sqlite3'
        require 'sequel'
        module Lich; end
        require ARGV[0]
        path, copy, how = ARGV[1], ARGV[2], ARGV[3]
        Lich.define_singleton_method(:sqlite_busy_timeout_ms) { 1500 }
        mono = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        to_lich = how.start_with?('dst_')
        setup = SQLite3::Database.new(path)
        setup.execute('CREATE TABLE rows (n INTEGER)')
        setup.execute('INSERT INTO rows (n) VALUES (1)')
        setup.close
        plain = SQLite3::Database.new(copy)
        if to_lich
          plain.execute('CREATE TABLE rows (n INTEGER)')
          plain.execute('INSERT INTO rows (n) VALUES (7)')
          pooled = Lich.open_sequel_sqlite(path)
          pooled.synchronize { |conn| conn.get_first_value('SELECT 1') }
        else
          shared = Lich.open_sqlite_db(path)
          shared.get_first_value('SELECT 1')
        end
        backup = lambda do
          run = lambda do |dst, src|
            b = SQLite3::Backup.new(dst, 'main', src, 'main')
            begin
              b.step(-1)
            ensure
              b.finish
            end
          end
          to_lich ? pooled.synchronize { |conn| run.call(conn, plain) } : run.call(plain, shared)
        end
        holder = SQLite3::Database.new(path)
        holder.execute('BEGIN EXCLUSIVE')
        waiter = Thread.new do
          Thread.current.report_on_exception = false
          backup.call
        rescue RuntimeError => e
          "rescued #{e.message}"
        end
        sleep 0.1
        reader = Thread.new { shared.get_first_value('SELECT count(*) FROM rows') } unless to_lich
        ticks = 0
        deadline = mono.call + 0.3
        while mono.call < deadline
          sleep 0.01
          ticks += 1
        end
        if how.end_with?('_kill')
          waiter.kill
        elsif how.end_with?('_raise')
          waiter.raise(RuntimeError, 'stop')
        end
        # An interrupted backup has to end while the lock is still held.
        ended = how.end_with?('_wait') ? waiter.alive? : waiter.join(1).nil?
        holder.execute('COMMIT')
        result = begin
          waiter.value.inspect
        rescue Exception => e
          e.class.name
        end
        puts ticks >= 10, ended, result, reader ? reader.value.inspect : 'none'
        # Every connection involved still works.
        puts backup.call
        puts SQLite3::Database.new(to_lich ? path : copy).get_first_value('SELECT group_concat(n) FROM rows')
      RUBY
    end

    def run_harness(how)
      lib = File.expand_path('../../../lib/common/sqlite_connection.rb', __dir__)
      stdout = +''
      stderr = +''
      status = nil
      Open3.popen3(RbConfig.ruby, '-e', harness, lib, path, copy_path, how) do |_in, out, err, wait|
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

    let(:done) { SQLite3::Constants::ErrorCode::DONE.to_s }

    it 'keeps other threads running while it waits, and a thread using the shared connection waits for it' do
      lines = run_harness('src_wait')

      # ticks, still waiting before the commit, backup result, read, second backup, copy
      expect(lines).to eq(['true', 'true', done, '1', done, '1'])
    end

    it 'ends the wait on Thread#kill and leaves the shared connection usable' do
      lines = run_harness('src_kill')

      expect(lines).to eq(['true', 'false', 'nil', '1', done, '1'])
    end

    it 'ends the wait on Thread#raise and leaves the shared connection usable' do
      lines = run_harness('src_raise')

      expect(lines).to eq(['true', 'false', '"rescued stop"', '1', done, '1'])
    end

    it 'ends a wait on a pooled destination on Thread#kill and leaves the pooled connection usable' do
      lines = run_harness('dst_kill')

      expect(lines).to eq(['true', 'false', 'nil', 'none', done, '7'])
    end

    def plain_source
      src = SQLite3::Database.new(copy_path)
      @raw << src
      src.execute('CREATE TABLE IF NOT EXISTS rows (n INTEGER)')
      src
    end

    it 'defers interrupts in #step when lich.db3 is either end, and not between plain connections' do
      open_db
      shared = Lich.open_sqlite_db(path)
      @raw << shared
      plain = plain_source
      other = SQLite3::Database.new(':memory:')
      @raw << other

      _, from_lich = masks_set_during { SQLite3::Backup.new(other, 'main', shared, 'main').tap { |b| b.step(-1) }.finish }
      pooled = Lich.open_sequel_sqlite(File.join(tmp_dir, 'pooled.db3'))
      @dbs << pooled
      _, to_lich = pooled.synchronize do |conn|
        masks_set_during { SQLite3::Backup.new(conn, 'main', plain, 'main').tap { |b| b.step(-1) }.finish }
      end
      _, plain_only = masks_set_during { SQLite3::Backup.new(other, 'main', plain, 'main').tap { |b| b.step(-1) }.finish }

      expect(SQLite3::Backup.ancestors).to include(Lich::SQLiteBusyWait::Backup)
      expect(from_lich).to eq([{ Object => :never }])
      expect(to_lich).to eq([{ Object => :never }])
      expect(plain_only).to be_empty
    end

    it 'gives up and returns BUSY once the lock has been held for the busy timeout' do
      allow(Lich).to receive(:sqlite_busy_timeout_ms).and_return(200)
      open_db
      shared = Lich.open_sqlite_db(path)
      @raw << shared
      holder = SQLite3::Database.new(path)
      @raw << holder
      holder.execute('BEGIN EXCLUSIVE')
      backup = SQLite3::Backup.new(SQLite3::Database.new(':memory:').tap { |c| @raw << c }, 'main', shared, 'main')
      started = monotonic
      result = backup.step(-1)
      waited = monotonic - started
      backup.finish
      holder.execute('COMMIT')

      expect(result).to eq(SQLite3::Constants::ErrorCode::BUSY)
      expect(waited).to be >= 0.2
      expect(waited).to be < 2.0
    end

    it 'makes #initialize, #step and #finish wait for the shared connection\'s Monitor, but not #remaining or #pagecount' do
      open_db
      shared = Lich.open_sqlite_db(path)
      @raw << shared
      dst = SQLite3::Database.new(':memory:')
      @raw << dst
      backup = nil
      waits = { initialize: time_while_monitor_held(shared) { backup = SQLite3::Backup.new(dst, 'main', shared, 'main') } }
      waits[:step] = time_while_monitor_held(shared) { backup.step(1) }
      free = {
        remaining: time_while_monitor_held(shared) { backup.remaining },
        pagecount: time_while_monitor_held(shared) { backup.pagecount }
      }
      waits[:finish] = time_while_monitor_held(shared) { backup.finish }

      expect(waits.values).to all(be >= 0.2)
      expect(free.values).to all(be < 0.2)
    end

    # SQLite requires that no other thread use a backup's destination
    # between sqlite3_backup_init and sqlite3_backup_finish; doing so has
    # corrupted the destination and crashed the process. A shared connection
    # is there for other threads to use, so it is refused as a destination.
    it 'refuses a shared connection as the destination before SQLite sees it, and leaves it usable' do
      open_db
      shared = Lich.open_sqlite_db(path)
      other_shared = Lich.open_sqlite_db(copy_path)
      @raw << shared << other_shared
      shared.execute('CREATE TABLE mine (n INTEGER)')
      shared.execute('INSERT INTO mine (n) VALUES (1)')
      plain = plain_source
      plain.execute('INSERT INTO rows (n) VALUES (7)')

      expect { SQLite3::Backup.new(shared, 'main', plain, 'main') }.to raise_error(ArgumentError, /destination/)
      expect { SQLite3::Backup.new(shared, 'main', other_shared, 'main') }.to raise_error(ArgumentError, /destination/)
      # A write from another thread, which corrupted a destination mid-backup.
      expect(Thread.new { shared.execute('INSERT INTO mine (n) VALUES (2)') }.join(5)).to be_a(Thread)
      expect(shared.execute('SELECT n FROM mine ORDER BY n').flatten).to eq([1, 2])
      expect(shared.get_first_value("SELECT count(*) FROM sqlite_master WHERE name = 'rows'")).to eq(1)
    end

    it 'waits for the shared source\'s Monitor when backing up into a pooled connection' do
      open_db
      shared = Lich.open_sqlite_db(copy_path)
      @raw << shared
      shared.execute('CREATE TABLE IF NOT EXISTS copied (n INTEGER)')
      shared.execute('INSERT INTO copied (n) VALUES (3)')
      pooled = Lich.open_sequel_sqlite(path)
      @dbs << pooled

      result = pooled.synchronize do |conn|
        waited = time_while_monitor_held(shared) do
          backup = SQLite3::Backup.new(conn, 'main', shared, 'main')
          begin
            backup.step(-1)
          ensure
            backup.finish
          end
        end
        [waited, conn.get_first_value('SELECT group_concat(n) FROM copied')]
      end

      expect(result[0]).to be >= 0.2
      expect(result[1]).to eq('3')
    end
  end
end
