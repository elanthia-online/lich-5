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
