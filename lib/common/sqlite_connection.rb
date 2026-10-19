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

  # Opens lich.db3 through Sequel. Sequel's pool hands each thread its own
  # connection, and every connection it creates gets a busy handler that waits
  # with Ruby's sleep (see SQLiteBusyWait). `timeout:` is the C busy timeout
  # Sequel sets first; it stays in force if the Ruby handler can't be installed.
  def Lich.open_sequel_sqlite(path)
    timeout_ms = sqlite_busy_timeout_ms.to_i
    db = Sequel.sqlite(
      path,
      timeout: timeout_ms,
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
  # An interrupt that arrives during a lock wait is delivered once that call
  # finishes or the busy timeout expires, as it was with the C busy timeout.
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
        Thread.handle_interrupt(Object => :never) { super }
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

        Thread.handle_interrupt(Object => :never) { super }
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
          Thread.handle_interrupt(Object => :never) do
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
    # COMMIT waits for the lock is delivered the moment that statement
    # returns. Thread#kill skips Sequel's rescue clauses and runs only its
    # ensure, so Sequel's own recovery for a failed BEGIN or COMMIT would not
    # run:
    #
    # - a COMMIT that timed out would leave the transaction open on the pooled
    #   connection, holding the write lock until the process exits;
    # - after a BEGIN that timed out, Sequel's ensure rolls back a transaction
    #   that never started. SQLite raises "cannot rollback - no transaction is
    #   active", and an exception raised in an ensure replaces the kill: the
    #   thread keeps running, and its later transactions are rolled back.
    #
    # Two interrupts that arrive during one lock wait are both deferred. The
    # first is delivered when the statement returns and Sequel rolls back; the
    # second is delivered as the next interrupt mask ends, which without
    # protection is the one around ROLLBACK's prepare, so ROLLBACK never runs
    # and the write transaction stays open. ROLLBACK therefore runs with
    # interrupts deferred too.
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
      # run it whole before delivering a deferred interrupt.
      def rollback_transaction(conn, opts = Sequel::OPTS)
        Thread.handle_interrupt(Object => :never) do
          next if conn.respond_to?(:transaction_active?) && !conn.transaction_active?

          super
        end
      end
    end

    SETUP_LOCK = Mutex.new unless const_defined?(:SETUP_LOCK)

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
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        deadline = now + timeout_s if count.zero? || deadline.nil?
        next false if now > deadline

        sleep(POLL_INTERVAL_S) unless count.zero?
        true
      end
      conn.extend(Connection)
      conn.extend(SerializedDatabase) if shared
      conn
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
