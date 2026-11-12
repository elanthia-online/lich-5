# frozen_string_literal: true

module Lich
  module Main
    # Runs the default native WebUI launcher for startup and turns its outcome
    # into launch data, an ordinary cancellation, or a fatal startup failure.
    module WebUIStartup
      module_function

      # Prepares native hosting before either graphical login or script startup.
      # Disabled presentation and an explicit browser perform no native build.
      # Failures end startup before any window or script can consume an
      # unavailable helper.
      # @return [void]
      # @raise [SystemExit] status 1 when a required helper could not be built
      def prepare
        return unless Lich::WebUI.presentation_enabled?

        browser, = Lich::WebUI::BrowserLauncher.browser_override(nil, ENV)
        return unless Lich::WebUI::BrowserLauncher.native_host(nil, browser)

        Lich::WebUI::NativeHost.prepare!
      rescue Lich::WebUI::Error => error
        report_fatal(error.message)
        raise SystemExit.new(1)
      end

      # Starts the launcher and waits for a selection. A launcher failure (a host
      # that could not start, or one that exited before any viewer connected) is
      # reported and ends startup with exit status 1; a user closing a connected
      # launcher window is an ordinary cancellation. When the wait ends normally,
      # fails or is killed, the launcher's bounded and idempotent exit cleanup runs
      # before startup continues or exits. A real signal exit is not covered by
      # this ensure: it is handled by the launcher's at_exit hook (see
      # WebUILauncher.close_launchers_at_exit), which must stay.
      # @param launcher [Lich::Common::WebUILauncher] launcher that has not started
      # @return [Array<String>, nil] launch data, or nil when the user cancelled
      # @raise [SystemExit] status 1 when the launcher failed
      def await(launcher)
        launch_data = nil
        start_error = nil
        begin
          launch_data = launcher.start.await_launch
        rescue StandardError => error
          start_error = error
        ensure
          launcher.close_at_exit
        end
        return launch_data if launch_data

        failure = launcher.failure
        failure ||= "WebUI launcher failed to start: #{start_error.class}" if start_error
        return nil unless failure

        report_fatal(failure)
        raise SystemExit.new(1)
      end

      # Writes the fatal reason to the debug log and, when stderr was redirected
      # to that log, to the terminal stream as well. With no terminal attached (a
      # desktop launch), Lich.msgbox_alert shows it off Windows. On Windows,
      # launcher failures use the launcher's own message box notification.
      # @param message [String] authored, secret-free failure message
      # @return [void]
      def report_fatal(message)
        Lich.log "error: #{message}"
        Lich.msgbox_alert(message: message, icon: :error) if Lich.respond_to?(:msgbox_alert)
        return if $stderr.equal?(STDERR)

        begin
          STDERR.puts "error: #{message}"
          STDERR.flush
        rescue IOError, SystemCallError
          # A closed terminal must not mask the logged failure or the exit status.
          nil
        end
      end
    end
  end
end
