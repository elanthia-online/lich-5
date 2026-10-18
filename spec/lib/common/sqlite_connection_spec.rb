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
          else db[:rows].insert(n: 1)
          end
        end
        sleep 0.2
        case how
        when 'kill', 'kill_in_prepare' then waiter.kill
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

    { 'kill' => 'joined', 'raise' => 'RuntimeError', 'timeout' => 'Timeout::Error' }.each do |how, expected_outcome|
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
end
