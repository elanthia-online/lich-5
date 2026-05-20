# frozen_string_literal: true

module Lich
  module Main
    # Coordinates orderly session teardown after the game server closes the
    # TCP connection and Game.thread exits.
    #
    # Phases execute in a fixed order chosen so that external tooling sees
    # the session as gone immediately, before the potentially slow script-kill
    # window begins:
    #
    #   1. Unregister sessions (ActiveSessions + SessionLifecycle)
    #   2. Kill client reader threads
    #   3. Stop user scripts (with timeout)
    #   4. Flush in-memory state to disk
    #   5. Close game, client, and database connections
    #   6. (caller-supplied reconnect hook)
    #   7. Signal UI exit and terminate process
    #
    # Every phase rescues StandardError so that a failure in one phase never
    # prevents the remaining cleanup from running.  The ensure block in
    # main.rb calls the lifecycle stops a second time as a safety net for
    # abnormal exits; both modules are idempotent.
    module Shutdown
      # Maximum seconds to wait for all scripts to finish their +before_dying+
      # hooks and remove themselves from +Script.running+/+Script.hidden+.
      #
      # @return [Float]
      SCRIPT_KILL_TIMEOUT_SECONDS = 20.0

      # Executes the full teardown sequence.
      #
      # @param client_thread [Thread, nil] the frontend client reader thread
      # @param detachable_client_thread [Thread, nil] the detachable client
      #   listener thread
      # @param reconnect_if_wanted [#call] proc that may exec a new Lich
      #   process when +--reconnect+ is active
      # @return [void] does not return (calls +exit+)
      def self.run(client_thread:, detachable_client_thread:, reconnect_if_wanted:)
        unregister_sessions
        kill_threads(client_thread, detachable_client_thread)
        stop_scripts
        save_state
        close_connections
        begin
          reconnect_if_wanted.call
        rescue StandardError => e
          Lich.log "warning: reconnect hook failed during shutdown: #{e.class}: #{e.message}"
        end
        quit_ui
      end

      # Removes the current process from both session tracking services.
      #
      # Called first so that external tooling (CLI queries, launcher conflict
      # checks) sees the session as gone before the slow script-kill phase.
      # Safe to call even when the lifecycle modules are not loaded.
      #
      # @return [void]
      def self.unregister_sessions
        Lich.log 'info: unregistering session...'
        begin
          Lich::InternalAPI::ActiveSessions::Lifecycle.stop if defined?(Lich::InternalAPI::ActiveSessions::Lifecycle)
        rescue StandardError => e
          Lich.log "warning: ActiveSessions lifecycle stop failed during shutdown: #{e.class}: #{e.message}"
        end
        begin
          Lich::Common::SessionLifecycle.stop if defined?(Lich::Common::SessionLifecycle)
        rescue StandardError => e
          Lich.log "warning: SessionLifecycle stop failed during shutdown: #{e.class}: #{e.message}"
        end
      end

      # Terminates the client and detachable-client reader threads.
      #
      # @param client_thread [Thread, nil]
      # @param detachable_client_thread [Thread, nil]
      # @return [void]
      def self.kill_threads(client_thread, detachable_client_thread)
        client_thread&.kill
        detachable_client_thread&.kill
      rescue StandardError
        nil
      end
      private_class_method :kill_threads

      # Signals all running and hidden scripts to die, then polls until they
      # have removed themselves from the running list or the timeout expires.
      #
      # Each +Script#kill+ spawns a background thread that executes
      # +before_dying+ hooks, removes the script from +@@running+, and runs
      # +GC.start+.  The poll loop waits for those threads to finish.
      #
      # @return [void]
      def self.stop_scripts
        Lich.log 'info: stopping scripts...'
        Script.running.each { |script| script.kill }
        Script.hidden.each { |script| script.kill }
        (SCRIPT_KILL_TIMEOUT_SECONDS / 0.1).to_i.times do
          break if Script.running.empty? && Script.hidden.empty?

          sleep 0.1
        end
      rescue StandardError => e
        Lich.log "warning: stop_scripts failed during shutdown: #{e.class}: #{e.message}"
      end
      private_class_method :stop_scripts

      # Flushes in-memory session state that requires an explicit write.
      #
      # Only +Vars.save+ is needed here.  +Settings+ and +CharSettings+
      # auto-persist to SQLite on every +[]=+ call, making explicit saves
      # redundant.
      #
      # @return [void]
      def self.save_state
        Lich.log 'info: saving state...'
        Vars.save
      rescue StandardError => e
        Lich.log "warning: Vars.save failed during shutdown: #{e.class}: #{e.message}"
      end
      private_class_method :save_state

      # Closes the game server socket, frontend client socket, and SQLite
      # database connection.
      #
      # All three close operations are synchronous and return immediately.
      # Each is individually rescued so that a failure in one does not
      # prevent the others from closing.
      #
      # @return [void]
      def self.close_connections
        Lich.log 'info: closing connections...'
        Game.close rescue nil
        $_CLIENT_&.close rescue nil
        Lich.db&.close rescue nil
      end
      private_class_method :close_connections

      # Signals the GTK main loop to quit (when running in GUI mode) and
      # terminates the process.
      #
      # @return [void] does not return
      def self.quit_ui
        Lich.log 'info: exiting...'
        Gtk.queue { Gtk.main_quit } if defined?(Gtk)
        exit
      end
      private_class_method :quit_ui
    end
  end
end
