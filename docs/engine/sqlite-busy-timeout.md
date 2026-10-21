# SQLite Busy Timeout

Lich configures SQLite connections opened through the core database helpers with
a 5000 ms busy timeout.

The timeout is connection-local SQLite behavior. It is applied when Lich opens a
connection; it is not persisted in `lich.db3` and does not affect independently
opened SQLite handles.

Covered core open paths:

- `Lich.db`
- `Lich.open_sqlite_db(path)`
- `Lich.open_sequel_sqlite(path)`
- Settings' `lich.db3` Sequel adapter
- Session summary adapter fallback connections

Deliberate exception:

- The Settings adapter's `data_version` connection (`DatabaseAdapter#data_version`)
  uses a busy timeout of 0. It only reads `PRAGMA data_version` to tell whether
  another connection has committed since a cached row was read. SQLite's busy
  wait keeps Ruby's GVL, so waiting there would stall every thread of the
  process while another process holds the lock. With a timeout of 0 the read
  fails at once, and Settings keeps using its cached row until the version can
  be read again.
