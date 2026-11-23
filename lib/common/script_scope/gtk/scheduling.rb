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

          # Keeps implicit conversions such as Array() and flatten from reaching the refusal.
          # @api private
          def respond_to_missing?(*args)
            super
          end

          # @raise [Gtk::UnsupportedOperation] for unimplemented GLib constants
          def const_missing(name) = Gtk.session.refuse(self, name)
        end
        extend Boundary

        # Owner-bound loop for scripts that wait on their own UI. The core
        # dispatcher already runs callbacks, so run only blocks the calling
        # thread until quit, or until the script's session ends.
        class MainLoop
          WAIT_SLICE = 0.25

          # Captures the existing script session without creating a native loop.
          def initialize
            @session = Gtk.session
            @session.style_operation(self, :new) { nil }
            @mutex = Mutex.new
            @wake = ConditionVariable.new
            @running = false
          end

          # Blocks until quit or the session closes. A callback cannot wait,
          # since it runs on the dispatcher this loop depends on.
          # @return [nil]
          # @raise [Gtk::UnsupportedOperation] when already running or called from a callback
          def run
            nested = @session.held_by_current_thread?
            @session.style_operation(self, :run) do
              @session.refuse(self, :run) if @running || nested
              @running = true
            end
            begin
              @mutex.synchronize do
                @wake.wait(@mutex, WAIT_SLICE) while @running && !@session.closed?
              end
            ensure
              @running = false
            end
            nil
          end

          # Ends a running loop; with none running it does nothing, as in GTK.
          # Only the script that owns the loop may end it. After the owner's
          # session has closed the loop is already released, so the owner's
          # late quit, for example from a destroy handler, stays harmless.
          # @return [nil]
          # @raise [Gtk::UnsupportedOperation] when another script calls it
          def quit
            @session.refuse(self, :quit) unless @session.owner_call?
            @mutex.synchronize do
              @running = false
              @wake.broadcast
            end
            nil
          end

          # @return [Boolean] whether run is waiting
          def running? = @running
          alias is_running running?
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
