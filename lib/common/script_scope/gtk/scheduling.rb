# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      # Script-local scheduling only; never loads native GLib or replaces Ruby Timeout.
      module GLib
        # Keeps unimplemented calls and constants on the attributed refusal path.
        module Boundary
          # @raise [Gtk::UnsupportedOperation] for unimplemented GLib operations
          def method_missing(name, *, **, &) = Gtk.session.refuse(self, name)
          # @raise [Gtk::UnsupportedOperation] for unimplemented GLib constants
          def const_missing(name) = Gtk.session.refuse(self, name)
        end
        extend Boundary

        # Owner-bound constructor for scripts that allocate a loop before building UI.
        # The core dispatcher owns execution; nested GLib loops remain unsupported.
        class MainLoop
          # Captures the existing script session without creating a native loop.
          def initialize
            @session = Gtk.session
            @session.style_operation(self, :new) { nil }
          end

          # @raise [Gtk::UnsupportedOperation] nested dispatch is unsupported
          def run
            @session.style_operation(self, :run) { @session.refuse(self, :run) }
          end

          # @raise [Gtk::UnsupportedOperation] no native loop exists to stop
          def quit
            @session.style_operation(self, :quit) { @session.refuse(self, :quit) }
          end
        end

        module Timeout
          extend Boundary

          # @param interval [Integer] milliseconds, including deferred zero
          # @return [Integer] owner-bound source ID; truthy callback results repeat
          def self.add(interval, &block)
            Gtk.session.schedule(self, :add, interval, &block)
          end

          # @param interval [Integer] seconds converted to bounded milliseconds
          # @return [Integer] owner-bound source ID
          def self.add_seconds(interval, &block)
            Gtk.session.refuse(self, :add_seconds) unless interval.is_a?(Integer)
            Gtk.session.schedule(self, :add_seconds, interval * 1000, &block)
          end
        end

        module Idle
          extend Boundary

          # Defers onto the owner queue with the core's 1ms fairness floor.
          # @return [Integer] cancellable source ID, never an inline callback result
          def self.add(&block)
            Gtk.session.schedule(self, :add, 0, &block)
          end
        end

        module Source
          extend Boundary

          # @param id [Integer] ID returned by this owner's scheduling call
          # @return [Boolean] false when already removed or finished
          def self.remove(id)
            Gtk.session.remove_source(self, id)
          end
        end
      end
    end
  end
end
