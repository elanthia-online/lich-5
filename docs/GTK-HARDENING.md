# GTK Hardening

Lich owns the shared GTK main loop. Scripts may create, show, update, and
destroy windows, but script-level `Gtk.main` and `Gtk.main_quit` calls can
destabilize every GTK script in the process.

Core hardening in [gtk.rb](/Users/doug/dev/test/lich-5/lib/common/gtk.rb):

- Redundant `Gtk.main` calls are ignored once the GTK loop is already running.
- Script-context `Gtk.main_quit` calls are ignored.
- Core shutdown paths use `Gtk.lich_main_quit` as an explicit escape hatch.
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
