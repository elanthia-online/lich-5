# GTK Hardening

Lich owns the shared GTK main loop. Scripts may create, show, update, and
destroy windows, but script-level `Gtk.main` and `Gtk.main_quit` calls can
destabilize every GTK script in the process.

Core hardening in [gtk.rb](../lib/common/gtk.rb):

- Redundant `Gtk.main` calls are ignored once the GTK loop is already running.
- Script-context `Gtk.main_quit` calls are ignored.
- Core shutdown paths use `Gtk.lich_main_quit` as an explicit escape hatch.
- Core shutdown paths should use `Lich::Common.shutdown_gtk!` on the GTK thread
  before process exit so retained widgets are destroyed deterministically.
- Ruby-side references are retained for blocks passed to:
  - `signal_connect`
  - `GLib::Timeout.add`
  - `GLib::Idle.add`

This reduces two common shared-process risks:

- one script starting or stopping the GTK loop for all other scripts
- GTK/GLib callback blocks becoming GC-eligible while native code still holds
  C-side callback state

This hardening is intended to reduce cross-script GTK instability without
requiring mass updates to old or abandoned scripts.

## Current limits

- Signal handler retention is released on widget `destroy`. If a widget never
  reaches `destroy`, its retained handlers can outlive the script that created
  it.
- Timeout and idle retention is cleared when the wrapped callback returns a
  falsy value or raises. Code that cancels GLib sources through other APIs, such
  as `GLib::Source.remove`, is outside this hardening layer today.
- The launcher installs a perpetual idle keepalive on purpose. It returns
  `true` explicitly so the retention layer preserves it as a long-lived callback.
- `Lich::Common.shutdown_gtk!` only tears down widgets known to the retention
  layer. Script-owned widgets that never connect signals or otherwise escape
  core tracking still need responsible script-level lifecycle management.
