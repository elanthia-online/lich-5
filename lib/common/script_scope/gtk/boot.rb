# frozen_string_literal: true

# Entry point for the GTK compatibility shim. Loaded by ScriptScope.activate!
# through the plugin glob; nothing in core names this directory.
require_relative 'session'
require_relative 'widgets'
require_relative 'widgets_data'
require_relative 'builder'
require_relative 'menus'
require_relative 'images'
