# frozen_string_literal: true

require_relative 'browser_launcher'
require_relative 'window_presentation'

module Lich
  module WebUI
    # A browser window opened for a page, with the OS-window presentation
    # the page asked for -- keep-above and opacity -- kept applied to it.
    #
    # A page cannot reach its own window: the `presentation` facility is
    # recorded and degraded by the runtime, and the client honours only what
    # a document can (opacity as a fade of the page, at best). The shim
    # applies the real thing through the Win32 handle of the browser it
    # spawned; a script rendering its own page had no way to, so its
    # keep-above and opacity did nothing. This is that path, for anyone.
    #
    # +presentation+ is a callable answering the current wishes as a Hash
    # (`always_on_top`, `opacity`, `borderless`), read whenever the window is
    # found and whenever `apply` is called, so a script re-applies after a
    # setting changes by calling `apply` and nothing else.
    class PresentedWindow
      # Opens the browser and returns the window, or nil when no browser
      # could be opened (the launch URL still works in any browser).
      # +title+ is the page's window title, or a prefix of it: with a shared
      # browser profile the spawned process hands the page to the Chrome
      # already running and exits, so its pid owns no window, and the title
      # is the only thing that names the window from outside.
      def self.open(url, presentation:, geometry: nil, title: nil, opener: BrowserLauncher.method(:open))
        window = new(presentation, title: title)
        opened = opener.call(url, geometry: geometry, on_start: ->(pid) { window.started(pid) })
        opened ? window : nil
      end

      def initialize(presentation, title: nil)
        raise ArgumentError, 'presentation must respond to call' unless presentation.respond_to?(:call)

        @presentation = presentation
        @title = title
        @mutex = Mutex.new
        @pid = nil
        @hwnd = nil
      end

      # The browser process is running; find its window in the background
      # and dress it: by pid first, and when the pid owns no window, by the
      # page's title. Where the platform has no window presentation, or
      # neither finds it, nothing is applied and `presented?` stays false.
      def started(pid)
        @mutex.synchronize { @pid = pid }
        return unless WindowPresentation.available?

        WindowPresentation.discover(pid, title: @title) { |hwnd| adopt(pid, hwnd) }
        nil
      end

      def presented?
        @mutex.synchronize { !@hwnd.nil? }
      end

      # Re-reads the presentation and applies it. A no-op until the window
      # has been found, and after it has gone.
      def apply
        hwnd = @mutex.synchronize { @hwnd }
        return false unless hwnd

        requested = @presentation.call || {}
        WindowPresentation.apply(
          hwnd,
          always_on_top: requested[:always_on_top] ? true : false,
          opacity: requested[:opacity] || 1.0,
          borderless: requested[:borderless] ? true : false
        )
      end

      private

      def adopt(pid, hwnd)
        return unless hwnd
        # The process may have been replaced while the search ran; a stale
        # handle would dress up somebody else's window.
        return unless @mutex.synchronize { @pid == pid && (@hwnd = hwnd) }

        apply
      end
    end
  end
end
