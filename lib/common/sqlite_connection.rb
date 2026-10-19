# frozen_string_literal: true

# SQLite connection helpers for lich.db3. Loaded by lib/lich.rb before sqlite3
# and sequel are required, so nothing here touches SQLite3 or Sequel at load
# time.

require 'monitor'

module Lich
  DEFAULT_SQLITE_BUSY_TIMEOUT_MS = 5000 unless const_defined?(:DEFAULT_SQLITE_BUSY_TIMEOUT_MS)

  def Lich.sqlite_busy_timeout_ms
    DEFAULT_SQLITE_BUSY_TIMEOUT_MS
  end

  # For a single SQLite3::Database that several threads share (Lich.db and
  # the session summary connection). It gets the same Ruby busy handler as the
  # pooled connections, and every sqlite3 call on it and on its statements
  # runs under one Monitor (see SQLiteBusyWait::SerializedDatabase), so a
  # second thread waits in Ruby instead of on SQLite's connection mutex while
  # the first sleeps in the handler. The C busy timeout set first stays in
  # force if the connection has no busy_handler API.
  def Lich.configure_sqlite_connection(db)
    db.busy_timeout(sqlite_busy_timeout_ms) if db.respond_to?(:busy_timeout)
    SQLiteBusyWait.install(db, sqlite_busy_timeout_ms.to_i, shared: true)
  end

  def Lich.open_sqlite_db(path)
    configure_sqlite_connection(SQLite3::Database.new(path))
  end

  # How many busy timeouts a thread waits for a free pooled connection before
  # Sequel raises Sequel::PoolTimeout; see Lich.sqlite_pool_timeout_s.
  SQLITE_POOL_TIMEOUT_BUSY_TIMEOUTS = 3 unless const_defined?(:SQLITE_POOL_TIMEOUT_BUSY_TIMEOUTS)

  # Seconds a thread waits for a free connection from the lich.db3 Sequel pool.
  #
  # Threads holding pooled connections wait for the lock side by side, each
  # for up to the busy timeout, and keep their connections meanwhile. With
  # Sequel's default pool timeout (5 s, the same as the busy timeout) a thread
  # queued behind them timed out on the pool at about the moment they gave up
  # or got the lock, and failed with Sequel::PoolTimeout without ever having
  # waited for the lock itself. A connection holder usually keeps its
  # connection waiting for locks for at most two busy timeouts in one
  # transaction (BEGIN IMMEDIATE or its first write, and COMMIT); a third
  # leaves room for holders that start waiting after the queued thread does. A queued thread then usually gets a connection once
  # those holders finish, and its own full busy timeout after that. Sequel's
  # pool is not strictly first come, first served: a thread that releases a
  # connection and asks again at once can take it back before a queued thread
  # wakes. A queued thread can still time out behind callers that keep coming
  # back, and queued writes do not necessarily land in the order they queued.
  #
  # A caller that defers interrupts around a database call
  # (Thread.handle_interrupt(Object => :never)) and is killed while queued
  # holds the kill back for up to this long plus one busy timeout for each
  # statement that then waits for a lock: the pool wait does not end on an
  # interrupt, and each statement that follows starts with the kill pending,
  # so it waits out its lock wait (see SQLiteBusyWait.wait_uninterrupted).
  # That is 20 s with the defaults for a single statement, and 25 s for a
  # transaction, which usually waits twice (its first write and COMMIT).
  def Lich.sqlite_pool_timeout_s
    SQLITE_POOL_TIMEOUT_BUSY_TIMEOUTS * sqlite_busy_timeout_ms.to_i / 1000.0
  end

  # Opens lich.db3 through Sequel. Sequel's pool hands each thread its own
  # connection, and every connection it creates gets a busy handler that waits
  # with Ruby's sleep (see SQLiteBusyWait). `timeout:` is the C busy timeout
  # Sequel sets first; it stays in force if the Ruby handler can't be installed.
  # `pool_timeout:` is Lich.sqlite_pool_timeout_s.
  def Lich.open_sequel_sqlite(path)
    timeout_ms = sqlite_busy_timeout_ms.to_i
    db = Sequel.sqlite(
      path,
      timeout: timeout_ms,
      pool_timeout: sqlite_pool_timeout_s,
      after_connect: ->(conn) { SQLiteBusyWait.install(conn, timeout_ms) }
    )
    db.extend(SQLiteBusyWait::Transactions)
  end

  # Lock waits that let the rest of the process keep running.
  #
  # sqlite3's busy_timeout waits inside C with the GVL held. If the lock holder
  # is another thread of this process that still has Ruby code to run before it
  # commits, it can't run, and the waiter fails when the timeout expires. A
  # waiting thread also freezes every other thread (game I/O included) while
  # another process holds the lock. Every connection Lich opens to lich.db3
  # (the Sequel pool, Lich.db, the session summary connection) gets the Ruby
  # handler: a thread spinning in C with the GVL held while another thread of
  # this process sleeps in the Ruby handler holding the lock it waits for
  # would stall both for the full timeout.
  #
  # A busy handler written in Ruby sleeps between retries, which releases the
  # GVL. SQLite calls it from inside the C call that is waiting for the lock,
  # though, so a Thread#kill, Thread#raise or Timeout delivered during that
  # sleep would unwind through SQLite's C frames and leave the connection's
  # mutex locked; the next thread to use that connection would then block
  # forever with the GVL held. On these connections every sqlite3 entry point
  # that can wait for a lock therefore defers interrupts until SQLite returns:
  #
  # - SQLite3::Statement#initialize (sqlite3_prepare) and #step (sqlite3_step),
  #   which carry #execute, #query, #prepare, #execute_batch, #transaction and
  #   everything Sequel sends;
  # - Database#exec_batch (sqlite3_exec), which carries #execute_batch2.
  #
  # An interrupt that arrives during a lock wait ends the wait: the handler
  # gives up at its next poll (within about 1 ms), SQLite returns SQLITE_BUSY,
  # and the interrupt is delivered as the call returns, in place of the
  # BusyException. The interrupted statement does not run. Letting the wait go
  # on until the lock freed would deliver the interrupt after the write had
  # landed: a Timeout around the write reports a failure for a write that
  # happened, a second interrupt can arrive meanwhile and land outside the
  # scope it was meant for (a Timeout::ExitException after its Timeout block
  # has returned), and a killed script's write can land after the writes its
  # cleanup makes once the kill returns. With the C busy timeout none of this
  # could happen, because nothing else ran until the wait ended.
  #
  # Two exceptions keep waiting until the lock frees or the busy timeout
  # expires, and deliver the interrupt afterwards:
  #
  # - a call that starts with an interrupt already pending, which means the
  #   caller deferred it with Thread.handle_interrupt to finish its writes
  #   first (see SQLiteBusyWait.wait_uninterrupted);
  # - ROLLBACK (see SQLiteBusyWait::Transactions).
  #
  # A caller that defers interrupts itself and is interrupted during the
  # wait gets the BusyException; the interrupt stays deferred, as it asked.
  # SQLite3::Backup#step is not covered; nothing in Lich backs up into or out
  # of lich.db3.
  #
  # While one thread sleeps in the handler, SQLite holds that connection's
  # mutex and other threads run, garbage collection included. GC finalizes an
  # unclosed SQLite3::Statement with sqlite3_finalize, which needs the same
  # mutex and waits for it with the GVL held: the sleeping thread can never
  # wake and the process freezes. So every open statement on these
  # connections is kept referenced by its connection until it is closed (see
  # SQLiteBusyWait::Statement); GC never finalizes one while it is open. A
  # statement nobody closes is freed with its connection.
  #
  # A connection that several threads share has one more hazard: a second
  # thread calling into it while the first sleeps in the handler blocks on
  # the same connection mutex with the GVL held. Shared connections are
  # therefore serialized; see SQLiteBusyWait::SerializedDatabase.
  #
  # Deferring interrupts moves where a Thread#kill lands inside
  # Sequel::Database#transaction to the end of BEGIN or COMMIT; see
  # SQLiteBusyWait::Transactions.
  module SQLiteBusyWait
    POLL_INTERVAL_S = 0.001 unless const_defined?(:POLL_INTERVAL_S)

    # sqlite3 C methods that a serialized connection or statement calls
    # without its Monitor: they don't take SQLite's connection mutex
    # (interrupt is meant to be called from another thread while a statement
    # runs), or they only run while the connection is opened or discarded
    # after a fork, before any other thread can see it. Statement#prepare runs
    # under SerializedDatabase's Monitor from Statement#initialize.
    UNSERIALIZED_DATABASE_METHODS = %i[closed? complete? interrupt open16 open_v2 discard].freeze unless const_defined?(:UNSERIALIZED_DATABASE_METHODS)
    UNSERIALIZED_STATEMENT_METHODS = %i[closed? prepare].freeze unless const_defined?(:UNSERIALIZED_STATEMENT_METHODS)

    # Extended onto each connection that has the Ruby busy handler; marks it
    # for SQLiteBusyWait::Statement and wraps the Database methods that call
    # SQLite directly.
    module Connection
      def self.extended(conn)
        conn.instance_variable_set(:@lich_open_statements, {}.compare_by_identity)
      end

      private

      # Called by SQLiteBusyWait::Statement only.
      def hold_open_statement(stmt)
        @lich_open_statements[stmt] = true
      end

      def release_open_statement(stmt)
        @lich_open_statements.delete(stmt)
      end

      # sqlite3's private C method behind #execute_batch2. It runs
      # sqlite3_exec, which calls the busy handler without going through
      # SQLite3::Statement. On sqlite3 versions without it nothing calls this.
      def exec_batch(*args)
        SQLiteBusyWait.wait_uninterrupted { super }
      end
    end

    # Extended (after Connection) onto a connection that several threads
    # share. Every sqlite3 C method on the connection, and on each statement
    # prepared on it (SerializedStatement), runs under one re-entrant Monitor,
    # so only one thread at a time is inside SQLite on this connection. A
    # thread that finds another one waiting for a lock waits for the Monitor,
    # which releases the GVL, instead of blocking on SQLite's connection mutex
    # with the GVL held. Ruby-level methods such as #execute or #transaction
    # are not wrapped as a whole: as before, statements from different threads
    # can interleave between calls.
    #
    # The wrappers are defined by SQLiteBusyWait.prepare_sqlite3 from the
    # sqlite3 gem that is loaded, so a C method added by a later gem version
    # is serialized too.
    module SerializedDatabase
      def self.extended(conn)
        conn.instance_variable_set(:@lich_monitor, Monitor.new)
      end
    end

    # Extended onto each statement prepared on a SerializedDatabase; shares
    # that connection's Monitor.
    module SerializedStatement
    end

    # Prepended to SQLite3::Statement. Only statements on marked connections
    # change behaviour.
    module Statement
      def initialize(db, *args)
        unless db.is_a?(Connection)
          super
          return
        end

        monitor = db.instance_variable_get(:@lich_monitor) if db.is_a?(SerializedDatabase)
        if monitor
          monitor.synchronize { prepare_on_connection(db, monitor) { super } }
        else
          prepare_on_connection(db, nil) { super }
        end
      end

      def step
        return super unless @connection.is_a?(Connection)

        SQLiteBusyWait.wait_uninterrupted { super }
      end

      def close
        super
      ensure
        @connection.__send__(:release_open_statement, self) if @connection.is_a?(Connection)
      end

      private

      # Runs the block (sqlite3's own initialize, which prepares) with
      # interrupts deferred and registers the new statement with `db`.
      def prepare_on_connection(db, monitor)
        prepared = false
        returned = false
        begin
          SQLiteBusyWait.wait_uninterrupted do
            yield
            # sqlite3 returns no statement for SQL that is only a comment or
            # whitespace; it is closed at birth and nobody will close it.
            unless closed?
              db.__send__(:hold_open_statement, self)
              if monitor
                @lich_monitor = monitor
                extend(SerializedStatement)
              end
            end
            prepared = true
          end
          returned = true
        ensure
          # An interrupt deferred during a lock wait in prepare is delivered as
          # the block exits. The caller never gets this statement, so nothing
          # else would close it.
          close if prepared && !returned && !closed?
        end
      end
    end

    # Extended onto the Sequel::Database that Lich.open_sequel_sqlite returns.
    #
    # With interrupts deferred, a Thread#kill that arrives while BEGIN or
    # COMMIT waits for the lock ends the wait, and is delivered the moment
    # that statement returns, in place of its BusyException. Thread#kill skips
    # Sequel's rescue clauses and runs only its ensure, so Sequel's own
    # recovery for a failed BEGIN or COMMIT would not run:
    #
    # - a COMMIT that gave up would leave the transaction open on the pooled
    #   connection, holding the write lock until the process exits;
    # - after a BEGIN that gave up, Sequel's ensure rolls back a transaction
    #   that never started. SQLite raises "cannot rollback - no transaction is
    #   active", and an exception raised in an ensure replaces the kill: the
    #   thread keeps running, and its later transactions are rolled back.
    #
    # Two interrupts can be queued before the waiting thread runs again. The
    # first is delivered when the statement returns and Sequel rolls back; the
    # second is delivered as the next interrupt mask ends, which without
    # protection is the one around ROLLBACK's prepare, so ROLLBACK never runs
    # and the write transaction stays open. ROLLBACK therefore runs with
    # interrupts deferred too, and a lock wait inside it does not give up
    # because those interrupts are pending.
    module Transactions
      private

      # Rolls back a failed COMMIT before any deferred interrupt is delivered,
      # as Sequel does when the COMMIT raises.
      def commit_transaction(conn, opts = Sequel::OPTS)
        Thread.handle_interrupt(Object => :never) do
          super
        rescue Exception => e # rubocop:disable Lint/RescueException -- re-raised below
          begin
            rollback_transaction(conn, opts)
          rescue Exception # rubocop:disable Lint/RescueException -- keep the COMMIT error, as Sequel does
            nil
          end
          raise e
        end
      end

      # ROLLBACK with no transaction open can only raise; skip it. Otherwise
      # run it whole before delivering a deferred interrupt, without giving
      # up a lock wait because an interrupt is pending: an abandoned ROLLBACK
      # would leave the write transaction open on the pooled connection.
      def rollback_transaction(conn, opts = Sequel::OPTS)
        Thread.handle_interrupt(Object => :never) do
          next if conn.respond_to?(:transaction_active?) && !conn.transaction_active?

          SQLiteBusyWait.keep_waiting_through_interrupts { super }
        end
      end
    end

    SETUP_LOCK = Mutex.new unless const_defined?(:SETUP_LOCK)

    # Thread variable: while set, the busy handler keeps waiting even though
    # an interrupt is pending.
    KEEP_WAITING_KEY = :lich_sqlite_keep_waiting unless const_defined?(:KEEP_WAITING_KEY)

    # Runs one sqlite3 call that may wait for a lock with interrupts
    # deferred. An interrupt already pending here was deferred by the caller
    # (otherwise it would have been delivered before this call), so the
    # caller wants its writes finished first: the busy handler keeps waiting
    # for this call. Otherwise an interrupt that arrives during the wait makes
    # the handler give up.
    def self.wait_uninterrupted
      Thread.handle_interrupt(Object => :never) do
        next yield unless Thread.pending_interrupt?

        keep_waiting_through_interrupts { yield }
      end
    end

    # Runs the block with the busy handler waiting through pending
    # interrupts. Callers defer interrupts around it, so the thread variable
    # is always restored.
    def self.keep_waiting_through_interrupts
      thread = Thread.current
      outer = thread.thread_variable_get(KEEP_WAITING_KEY)
      thread.thread_variable_set(KEEP_WAITING_KEY, true)
      begin
        yield
      ensure
        thread.thread_variable_set(KEEP_WAITING_KEY, outer)
      end
    end

    # Installs the busy handler on a raw SQLite3::Database and returns it.
    # `shared: true` is for a connection that several threads use at once; it
    # is serialized (SerializedDatabase). Connections without the
    # busy_handler API keep their C busy timeout.
    def self.install(conn, timeout_ms, shared: false)
      return conn unless conn.respond_to?(:busy_handler)

      prepare_sqlite3
      timeout_s = timeout_ms / 1000.0
      deadline = nil
      conn.busy_handler do |count|
        next false if give_up_for_interrupt?

        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        deadline = now + timeout_s if count.zero? || deadline.nil?
        next false if now > deadline

        unless count.zero?
          sleep(POLL_INTERVAL_S)
          # An interrupt that arrived during the sleep woke it. Check again
          # before SQLite retries: the retry runs in C with the GVL held, so
          # once this check passes no other thread can interrupt before it,
          # and a write that lands was never interrupted.
          next false if give_up_for_interrupt?
        end
        true
      end
      conn.extend(Connection)
      conn.extend(SerializedDatabase) if shared
      conn
    end

    # True when the busy handler should give up the current lock wait: an
    # interrupt is pending for the waiting thread (the handler runs on it), it
    # will be delivered as soon as the call returns, and nothing asked to keep
    # waiting (see wait_uninterrupted).
    def self.give_up_for_interrupt?
      Thread.pending_interrupt? && !Thread.current.thread_variable_get(KEEP_WAITING_KEY)
    end

    # Prepends Statement to SQLite3::Statement and defines the Monitor
    # wrappers for every C method of SQLite3::Database and SQLite3::Statement
    # not listed as unserialized. Runs once.
    def self.prepare_sqlite3
      SETUP_LOCK.synchronize do
        return if @sqlite3_prepared

        serialize_c_methods(SerializedDatabase, ::SQLite3::Database, UNSERIALIZED_DATABASE_METHODS)
        serialize_c_methods(SerializedStatement, ::SQLite3::Statement, UNSERIALIZED_STATEMENT_METHODS)
        ::SQLite3::Statement.prepend(Statement) unless ::SQLite3::Statement <= Statement
        @sqlite3_prepared = true
      end
    end

    # The C methods (no Ruby source) that `klass` itself defines.
    def self.c_methods(klass)
      (klass.public_instance_methods(false) + klass.protected_instance_methods(false) +
        klass.private_instance_methods(false)).select do |name|
        meth = klass.instance_method(name)
        # Skip past anything prepended to klass.
        meth = meth.super_method while meth && meth.owner != klass
        meth && meth.source_location.nil?
      end
    end

    def self.serialize_c_methods(mod, klass, skip)
      (c_methods(klass) - skip).each do |name|
        mod.define_method(name) do |*args, &block|
          @lich_monitor.synchronize { super(*args, &block) }
        end
        if klass.private_method_defined?(name)
          mod.send(:private, name)
        elsif klass.protected_method_defined?(name)
          mod.send(:protected, name)
        end
      end
    end
    private_class_method :c_methods, :serialize_c_methods
  end
end
