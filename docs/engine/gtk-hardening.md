# GTK compatibility lifecycle

The native GTK runtime described by the former version of this page has been
retired from ordinary execution. `lib/common/gtk.rb`, the shared GTK main
loop, GLib callback-retention wrappers, and `shutdown_gtk!` are not current APIs.
Their historical implementation remains in Git history; do not use those
instructions to configure or extend WebUI.

The current [script-local shim](../../lib/common/script_scope/gtk/boot.rb) is a
bounded migration bridge into WebUI. Core and native WebUI consumers do not load
GTK. The [author guide](../webui-integration.md) describes supported methods,
refusals, declared presentation omissions, and the shared owner lifecycle.

- `Gtk.main` and `Gtk.main_quit` report that native-loop control is omitted;
  neither starts nor stops a GTK loop or the shared WebUI dispatcher.
- `Gtk.queue` uses the existing owner dispatcher. Nested submissions join its
  tail; callbacks must not wait for later callbacks on that same dispatcher.
- Calls require an owning script/session. A detached thread does not acquire
  ownership merely because it calls a GTK-named method.
- Script termination retires that owner's windows and callbacks. Cleanup queued
  from the owner's `before_dying` handler runs inline on its cleanup thread.
- An unhandled queued `BuilderError` closes the owner's UI and requests the
  existing asynchronous script-stop path. It must not leave a partially wired
  setup window operating. A direct Builder failure rescued by the script retains
  transactional load behavior.

There is no native GTK fallback, arbitrary GLib timer compatibility, or global
`Gtk` constant. The shim does not suppress missing widgets or repair script
business logic. Actual script operations and native window behavior require beta
acceptance; passing a bounded fixture does not establish complete script support.
