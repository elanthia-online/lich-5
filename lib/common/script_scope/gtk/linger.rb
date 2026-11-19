# frozen_string_literal: true

require_relative '../../script_body_completion'

module Lich
  module Common
    module ScriptScope
      module Gtk
        # Seconds a finished script waits for admitted UI work that has not
        # started. Queued UI work that never runs (a dropped dispatch) must not
        # keep a finished script alive indefinitely. A scheduled source is
        # counted from the time it is due, not from when the body ended.
        UI_LINGER_PENDING_LIMIT = 30
        # Seconds a finished body waits for a live worker thread to queue UI.
        UI_LINGER_WORKER_GRACE = 1.0
        # Source text that marks a script as a user of this compatibility layer.
        UI_LINGER_SOURCE = /\b(?:Gtk|GLib)(?:::|\.)/

        # Queue-then-exit: a legacy GTK script that queues its window and ends
        # still shows that window, because GTK runs the queued work after the
        # script is gone. When a script body ends successfully with
        # compatibility UI work not yet started, keep the owner running until
        # that work has run and the windows it shows are closed; ;kill still
        # ends it at once. A body that ends with nothing pending stops as
        # before, so scripts that close their own windows in exit handlers are
        # unaffected. A body that failed never waits: its name and callbacks
        # are released at once.
        # @param owner [Script] owner whose body has just finished
        # @return [void]
        # @api private
        def self.await_ui_linger(owner)
          return unless owner.running? && !owner.stopping? && owner.exit_error.nil?
          return unless ui_left_behind?(owner)

          waiting_since = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          loop do
            break if !owner.running? || owner.stopping?

            now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            if visible_windows?(owner)
              waiting_since = now
            elsif busy_ui?(owner)
              # Pending or still running (a window mid-show is not visible yet).
              # A source accepted for a later time is not stalled before then.
              break if now - [waiting_since, pending_ui_due(owner)].compact.max > UI_LINGER_PENDING_LIMIT
            else
              break
            end
            sleep 0.1
          end
        rescue StandardError => error
          Lich.log "UI linger check failed for #{owner.name}: #{error.class}"
        end
        private_class_method :await_ui_linger

        # Decides whether a finished body left UI work behind. A worker thread
        # started just before the body ended may not have queued its UI yet
        # (Thread.new { Gtk.queue { ... } }; exit). Only scripts that use this
        # compatibility layer and queued no UI of their own before the body
        # ended wait for it. Work admitted after the body ended counts even if
        # it has already run by the time this check looks.
        # @param owner [Script] owner whose body has just finished
        # @return [Boolean] whether admitted UI work is pending or arrived late
        # @api private
        def self.ui_left_behind?(owner)
          admitted_at_end = ui_admissions(owner)
          queued_after_end = -> { ui_admissions(owner) > admitted_at_end }
          workers = -> { owner.thread_group.list.any? { |thread| !thread.equal?(Thread.current) && thread.alive? } }
          if admitted_at_end.zero? && workers.call && legacy_ui_source?(owner)
            grace = Process.clock_gettime(Process::CLOCK_MONOTONIC) + UI_LINGER_WORKER_GRACE
            until pending_ui?(owner) || queued_after_end.call || Process.clock_gettime(Process::CLOCK_MONOTONIC) > grace
              break unless workers.call

              sleep 0.05
            end
          end
          pending_ui?(owner) || queued_after_end.call
        end
        private_class_method :ui_left_behind?

        # Whether the script's loaded source names the legacy GTK or GLib API.
        # Reads the text the script was started from, so every supported file
        # encoding gives the same answer.
        # @param owner [Script] owner whose body has just finished
        # @return [Boolean] whether any label of the script names Gtk or GLib
        # @api private
        def self.legacy_ui_source?(owner)
          labels = owner.respond_to?(:labels) ? owner.labels : nil
          labels.is_a?(Hash) && labels.each_value.any? { |text| text.to_s.match?(UI_LINGER_SOURCE) }
        end
        private_class_method :legacy_ui_source?

        # With presentation disabled this layer is concealed from scripts, so
        # no finished script waits on it.
        unless Lich::WebUI.presentation_disabled?
          Lich::Common::ScriptBodyCompletion.on_complete { |owner| __send__(:await_ui_linger, owner) }
        end
      end
    end
  end
end
