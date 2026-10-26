# frozen_string_literal: true

require_relative 'browser_launcher'
require_relative 'window_presentation'

module Lich
  module WebUI
    # One isolated browser app process per page. Only its PID may be terminated;
    # closing a page never terminates the shared browser or WebUI server.
    class BrowserWindow
      # Prepares ownership without spawning; callbacks must describe this window only.
      # @param on_close [#call] notification for an unsolicited process exit
      # @param opener [#call, nil] launcher accepting start/exit callbacks
      # @param terminate [#call] process terminator accepting a signal and owned PID
      def initialize(on_close:, opener: nil, terminate: Process.method(:kill))
        @opener = opener || BrowserLauncher.method(:open)
        @terminate = terminate
        @on_close = on_close
        @mutex = Mutex.new
        @closed = false
        @opening = false
        @pid = nil
        @presentation = WindowPresentation::Controller.new if WindowPresentation.available?
      end

      # Forwards validated presentation to the optional Windows controller.
      # @param render [Page::Render] validated presentation from either API
      # @return [void]
      def present(render)
        @presentation&.update(render)
      end

      # Identifies native operations that replace renderer-side presentation.
      # @return [Hash] OS-handled properties the renderer must not apply again
      def presentation_support = @presentation ? WindowPresentation::SUPPORT : {}

      # Opens unless already closed, settling any close requested during spawn
      # only after the opener has returned and installed its process monitor.
      # @param url [String] authenticated page launch URL
      # @param geometry [Hash, nil] initial window bounds
      # @return [Boolean] opener result, or false when closed before startup
      def open(url, geometry: nil)
        @mutex.synchronize do
          return false if @closed

          @opening = true
        end
        begin
          result = @opener.call(url, geometry: geometry, on_start: method(:started), on_exit: method(:exited))
        ensure
          @mutex.synchronize { @opening = false }
        end
        close if !result || closed?
        result
      rescue StandardError
        close
        raise
      end

      # Requests closure; startup must finish installing its process monitor
      # before termination can succeed and the service can release ownership.
      # @return [Boolean] whether startup is settled and no termination retry is needed
      # @raise [SystemCallError] when the owned process could not be terminated
      def close
        @mutex.synchronize do
          @closed = true
          @presentation&.close
          return false if @opening

          terminate_process
          true
        end
      end

      # Reads the owned window's close state under its lifecycle mutex.
      # @return [Boolean] whether closure was requested or the process exited
      def closed?
        @mutex.synchronize { @closed }
      end

      private

      # Retain an arriving PID even after closure is requested. open performs
      # deferred termination after the opener has installed its exit monitor.
      # @param pid [Integer] process returned by the opener
      # @return [void]
      # @api private
      def started(pid)
        @mutex.synchronize do
          @pid = pid
          @presentation&.start(pid) unless @closed
        end
      end

      # Releases ownership and notifies the page once for an unsolicited exit.
      # @return [void]
      # @api private
      def exited
        notify = @mutex.synchronize do
          @pid = nil
          @presentation&.close
          next false if @closed

          @closed = true
          true
        end
        @on_close.call if notify
      end

      # Terminates only the retained PID while the window mutex is held.
      # Missing processes count as closed; other failures retain the PID for retry.
      # @return [void]
      # @raise [SystemCallError] if termination fails for a still-owned process
      # @api private
      def terminate_process
        return unless @pid

        # Windows Ruby rejects TERM for external processes with EINVAL.
        @terminate.call(OS.windows? ? 'KILL' : 'TERM', @pid)
        @pid = nil
      rescue Errno::ESRCH, Errno::ECHILD
        @pid = nil
      end
    end
  end
end
