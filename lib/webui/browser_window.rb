# frozen_string_literal: true

require_relative 'browser_launcher'
require_relative 'window_presentation'

module Lich
  module WebUI
    # One isolated browser app process per page. Only its PID may be terminated;
    # closing a page never terminates the shared browser or WebUI server.
    class BrowserWindow
      # Seconds close waits for a start in progress on another thread to
      # install its process monitor, so a pending close (including process-exit
      # cleanup) terminates the new process instead of leaving it running.
      START_SETTLE_SECONDS = 2

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
        @opener_thread = nil
        @settled = ConditionVariable.new
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
      # A failed startup closes the window and notifies on_close once, unless
      # closure was already requested, so the owner sees a closed lifecycle
      # instead of waiting on a window that never appeared.
      # @param url [String] authenticated page launch URL
      # @param geometry [Hash, nil] initial window bounds
      # @return [Boolean] opener result, or false when closed before startup
      def open(url, geometry: nil)
        @mutex.synchronize do
          return false if @closed

          @opening = true
          @opener_thread = Thread.current
        end
        begin
          result = @opener.call(url, geometry: geometry, on_start: method(:started), on_exit: method(:exited))
        ensure
          @mutex.synchronize do
            @opening = false
            @opener_thread = nil
            @settled.broadcast
          end
        end
        return startup_failed(nil) unless result

        close if closed?
        result
      rescue StandardError => error
        startup_failed(error)
      end

      # Requests closure; startup must finish installing its process monitor
      # before termination can succeed and the service can release ownership.
      # A start in progress on another thread is awaited for up to
      # START_SETTLE_SECONDS, then its process is terminated here; past that
      # bound the close stays pending and open terminates once the start ends.
      # @return [Boolean] whether startup is settled and no termination retry is needed
      # @raise [SystemCallError] when the owned process could not be terminated
      def close
        @mutex.synchronize do
          @closed = true
          @presentation&.close
          await_start
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

      # Waits under the window mutex for another thread's start to settle.
      # The opener's own thread (a close from inside the opener) never waits.
      # @return [void]
      # @api private
      def await_start
        return if @opener_thread.equal?(Thread.current)

        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + START_SETTLE_SECONDS
        while @opening
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          break unless remaining.positive?

          @settled.wait(@mutex, remaining)
        end
      end

      # Closes after a failed startup and reports the closure exactly once.
      # @param error [StandardError, nil] opener exception to re-raise, if any
      # @return [false] when the opener returned a failure
      # @raise [StandardError] the opener's exception, after cleanup and notice
      # @api private
      def startup_failed(error)
        notify = @mutex.synchronize do
          next false if @closed

          @closed = true
        end
        begin
          close
        ensure
          @on_close.call if notify
        end
        raise error if error

        false
      end

      # Retain an arriving PID even after closure is requested. open, or a close
      # awaiting the start, performs deferred termination after the opener has
      # installed its exit monitor.
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
