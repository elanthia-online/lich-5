# frozen_string_literal: true

# SQLite connection helpers for lich.db3. Loaded by lib/lich.rb before sqlite3
# and sequel are required, so nothing here touches SQLite3 or Sequel at load
# time.
module Lich
  DEFAULT_SQLITE_BUSY_TIMEOUT_MS = 5000 unless const_defined?(:DEFAULT_SQLITE_BUSY_TIMEOUT_MS)

  def Lich.sqlite_busy_timeout_ms
    DEFAULT_SQLITE_BUSY_TIMEOUT_MS
  end

  # For a single SQLite3::Database that several threads share (Lich.db). This
  # keeps sqlite3's C busy timeout: a Ruby busy handler would release the GVL
  # while it waits, and another thread entering the same connection would then
  # block on SQLite's connection mutex with the GVL held, deadlocking both.
  def Lich.configure_sqlite_connection(db)
    db.busy_timeout(sqlite_busy_timeout_ms) if db.respond_to?(:busy_timeout)
    db
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
    Sequel.sqlite(
      path,
      timeout: timeout_ms,
      after_connect: ->(conn) { SQLiteBusyWait.install(conn, timeout_ms) }
    )
  end

  # Lock waits that let the rest of the process keep running.
  #
  # sqlite3's busy_timeout waits inside C with the GVL held. If the lock holder
  # is another thread of this process that still has Ruby code to run before it
  # commits, it can't run, and the waiter fails when the timeout expires. A
  # waiting thread also freezes every other thread (game I/O included) while
  # another process holds the lock.
  #
  # A busy handler written in Ruby sleeps between retries, which releases the
  # GVL. SQLite calls it from inside sqlite3_prepare and sqlite3_step, though,
  # so a Thread#kill, Thread#raise or Timeout delivered during that sleep would
  # unwind through SQLite's C frames and leave the connection's mutex locked;
  # the next thread to use that pooled connection would then block forever with
  # the GVL held. Statements on these connections therefore defer interrupts
  # until SQLite returns. An interrupt that arrives during a lock wait is
  # delivered once the statement finishes or the busy timeout expires, as it
  # was with the C busy timeout.
  module SQLiteBusyWait
    POLL_INTERVAL_S = 0.001

    # Marks a connection that has the Ruby busy handler.
    module Connection; end

    # Prepended to SQLite3::Statement. Only statements on marked connections
    # change behaviour.
    module Statement
      def initialize(db, *args)
        if db.is_a?(Connection)
          Thread.handle_interrupt(Object => :never) { super }
        else
          super
        end
      end

      def step
        return super unless @connection.is_a?(Connection)

        Thread.handle_interrupt(Object => :never) { super }
      end
    end

    # Installs the busy handler on a raw SQLite3::Database and returns it.
    # Connections without the busy_handler API keep their C busy timeout.
    def self.install(conn, timeout_ms)
      return conn unless conn.respond_to?(:busy_handler)

      ::SQLite3::Statement.prepend(Statement) unless ::SQLite3::Statement <= Statement
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
    end
  end
end
