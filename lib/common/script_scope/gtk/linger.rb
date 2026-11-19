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

        # Queue-then-exit: a legacy GTK script that queues its window and ends
        # still shows that window, because GTK runs the queued work after the
        # script is gone and nothing closes the window for it. When a script
        # body ends successfully and the script has used this layer, keep the
        # owner running while it still has UI: a shown window, a repeating
        # scheduled source, or admitted work that is pending or running. It
        # makes no difference whether a queued block has not started, is
        # running or has finished when the body ends. A live worker thread
        # gets a short grace after the body ends to queue its UI. ;kill still
        # ends the owner at once. A script that never used this layer, or has
        # no UI left, stops as before. A body that failed never waits: its
        # name and callbacks are released at once.
        #
        # A script that registered exit handlers before its body ended closes
        # its own UI in them, as GTK would run them at this point, so a window
        # or repeating source it already has is left to those handlers and
        # does not keep it running. Only work still pending or running when
        # its body ends (or queued by a worker in the grace) does, because the
        # handlers cannot have accounted for UI that did not exist yet.
        # @param owner [Script] owner whose body has just finished
        # @return [void]
        # @api private
        def self.await_ui_linger(owner)
          return unless owner.running? && !owner.stopping? && owner.exit_error.nil?
          return unless session?(owner)

          keeps_ui = owner.at_exit_procs.empty?
          body_ended = waiting_since = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          loop do
            break if !owner.running? || owner.stopping?

            now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            busy = busy_ui?(owner)
            keeps_ui ||= busy
            if keeps_ui && (visible_windows?(owner) || repeating_sources?(owner))
              waiting_since = now
            elsif busy
              # Pending or still running (a window mid-show is not visible yet).
              # A source accepted for a later time is not stalled before then.
              break if now - [waiting_since, pending_ui_due(owner)].compact.max > UI_LINGER_PENDING_LIMIT
            elsif now - body_ended > UI_LINGER_WORKER_GRACE || !live_workers?(owner)
              break
            end
            sleep 0.05
          end
        rescue StandardError => error
          Lich.log "UI linger check failed for #{owner.name}: #{error.class}"
        end
        private_class_method :await_ui_linger

        # Whether the owner has a live thread other than the one asking. A
        # worker started just before the body ended may not have queued its UI
        # yet (Thread.new { Gtk.queue { ... } }; exit).
        # @param owner [Script] owner whose body has just finished
        # @return [Boolean] whether another thread of the owner is alive
        # @api private
        def self.live_workers?(owner)
          owner.thread_group.list.any? { |thread| !thread.equal?(Thread.current) && thread.alive? }
        end
        private_class_method :live_workers?

        # With presentation disabled this layer is concealed from scripts, so
        # no finished script waits on it.
        unless Lich::WebUI.presentation_disabled?
          Lich::Common::ScriptBodyCompletion.on_complete { |owner| __send__(:await_ui_linger, owner) }
        end
      end
    end
  end
end
