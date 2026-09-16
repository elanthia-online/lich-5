# frozen_string_literal: true

# Entry point for the GTK compatibility shim. Loaded by ScriptScope.activate!
# through the plugin glob; nothing in core names this directory.
require_relative 'session'
require_relative 'widgets'
require_relative 'widgets_data'
require_relative 'builder'
require_relative 'menus'
require_relative 'images'
require_relative 'containers'

# A pixbuf cannot say which file it was built from, so the shim records that
# as it is built. Without this every Gtk::Image has a pixbuf and no source,
# and renders with an empty src -- which is a blank window, not an error.
# Safe when the gem is absent: it reports and returns false.
Lich::Common::ScriptScope::Gtk.install_pixbuf_tracking!
