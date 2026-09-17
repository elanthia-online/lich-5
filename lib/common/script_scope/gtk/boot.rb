# frozen_string_literal: true

# Entry point for the GTK compatibility shim. Loaded by ScriptScope.activate!
# through the plugin glob; nothing in core names this directory.
#
# The shim's vocabulary is the declared surface the supported-script list
# uses (docs/webui-rebuild-plan.md, "The shim's admission rule"). Images,
# Cairo, GdkPixbuf, Gtk::Layout and the menu classes are deliberately not
# here: the scripts that drew or popped menus are rewritten natively, and a
# script that names one of those classes gets the stubbed-widget notice and
# a ledger entry through Gtk.const_missing, which is the honest answer.
require_relative 'session'
require_relative 'degradation'
require_relative 'widgets'
require_relative 'glib'

module Lich
  module Common
    module ScriptScope
      module Gtk
        # OWN_DEFINITIONS keeps const_missing from stubbing a class a later
        # slice file defines, but the list is hand-maintained and the cost
        # of forgetting a name was silent: the real class was shadowed by an
        # empty box for the rest of the process. Checked once every slice
        # has loaded, a forgotten name is a load error that names itself.
        #
        # The list is declared inside `class << self`, so it lives on the
        # singleton class; a bare OWN_DEFINITIONS here would go through
        # const_missing and come back as a symbol.
        def self.verify_own_definitions!(names = singleton_class::OWN_DEFINITIONS)
          names.each do |name|
            raise LoadError, "Gtk::#{name} is in OWN_DEFINITIONS but is not defined after boot" unless const_defined?(name, false)

            value = const_get(name, false)
            next unless value.respond_to?(:webui_stub?)

            raise LoadError, "Gtk::#{name} is in OWN_DEFINITIONS but resolved to a stub after boot; " \
                             'the file that defines it was not loaded'
          end
          nil
        end
      end
    end
  end
end

Lich::Common::ScriptScope::Gtk.verify_own_definitions!
