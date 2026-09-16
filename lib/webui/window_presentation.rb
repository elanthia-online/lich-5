# frozen_string_literal: true

require 'fiddle'
require 'fiddle/import'
require_relative '../common/frontend'

# A page cannot raise its own window or make the frame translucent: those are
# window-manager properties, and what shows through a CSS-faded page is the
# browser's own background, not whatever is behind the window. The properties
# a script sets with Gtk::Window#set_keep_above and #set_opacity therefore
# have to reach the real OS window, which on native Windows means user32.
#
# Only native Windows is supported. wmctrl/xdotool and AppleScript were
# considered and rejected: `xdotool windowstate --add ABOVE` is a no-op under
# Wayland and _NET_WM_WINDOW_OPACITY does nothing without a compositor, so
# they would report success while changing nothing -- worse than degrading
# honestly, which is what every other host keeps doing.
module Lich
  module WebUI
    module WindowPresentation
      HWND_TOPMOST   = -1
      HWND_NOTOPMOST = -2
      SWP_NOSIZE     = 0x0001
      SWP_NOMOVE     = 0x0002
      SWP_NOACTIVATE = 0x0010
      GWL_EXSTYLE    = -20
      GWL_STYLE      = -16
      WS_EX_LAYERED  = 0x00080000
      LWA_ALPHA      = 0x0000_0002
      GW_OWNER       = 4
      # Only the title bar is removed. WS_THICKFRAME stays, so a borderless
      # window can still be resized by its edges -- and the script that took
      # the caption away keeps its own way to put it back (map offers the
      # toggle in the right-click menu that opens on the window itself).
      WS_CAPTION       = 0x00C00000
      SWP_FRAMECHANGED = 0x0020
      SWP_NOZORDER     = 0x0004
      # The class Chromium gives a top-level browser window. A process owns
      # several windows, most of them invisible helpers.
      WINDOW_CLASS = 'Chrome_WidgetWin_1'

      # How long to keep looking for the window after the browser is spawned.
      # Measured repeatedly on a warm machine: the window appears in about a
      # quarter of a second. The budget is deliberately far larger, because
      # the thread waiting is idle and a cold start is slower.
      DISCOVERY_TIMEOUT = 15.0
      DISCOVERY_INTERVAL = 0.1

      class << self
        # Test seams, mirroring Session.browser_open. Setting win32 replaces
        # the user32 facade wholesale, so the applier can be driven with no
        # real window anywhere.
        attr_writer :win32, :thread_factory, :sleeper, :available_override

        def win32
          @win32 ||= (defined?(::WinPresentation) ? ::WinPresentation : nil)
        end

        def thread_factory
          @thread_factory ||= ->(&block) { Thread.new(&block) }
        end

        def sleeper
          @sleeper ||= ->(seconds) { sleep(seconds) }
        end

        def reset_seams!
          @win32 = nil
          @thread_factory = nil
          @sleeper = nil
          @available_override = nil
        end

        # The predicate comes first, so nothing Windows-shaped is even named
        # on a host that has none of it.
        def available?
          return @available_override unless @available_override.nil?
          return false unless Lich::Common::Frontend.native_windows_runtime?

          !win32.nil?
        end

        # What this host can actually honour, merged over the contract's own
        # support table. Empty when there is nothing to add, so the existing
        # degradation record stays exactly as it was.
        def support
          return {} unless available?

          { always_on_top: true, opacity: true, borderless: true }
        end

        # The one visible top-level window belonging to +pid+, or nil.
        #
        # Returning nil unless there is exactly one match is deliberate: a
        # browser that reused an existing process owns many windows, and
        # picking the first would make the player's own browser topmost and
        # translucent. The shim always spawns with a private profile
        # directory (Session#open_browser always passes on_exit, which makes
        # BrowserLauncher create one), so the honest case is exactly one.
        def find_window(pid)
          return nil unless available?

          matches = []
          callback = Fiddle::Closure::BlockCaller.new(
            Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG]
          ) do |hwnd, _|
            matches << Fiddle::Pointer.new(hwnd.to_i) if window_matches?(hwnd, pid)
            1
          end
          win32.EnumWindows(callback, 0)
          matches.length == 1 ? matches.first : nil
        rescue StandardError => error
          log("finding the browser window failed: #{error.class}: #{error.message}")
          nil
        end

        # Applies a fully-resolved desired state. Both properties are always
        # named, never "leave alone": a script turning keep-above off is not
        # visible as a value -- Window#presentation omits false and returns
        # nil once nothing is set -- so the caller resolves the absence into
        # an explicit default and this applies it.
        def apply(hwnd, always_on_top:, opacity:, borderless: false)
          return false unless available? && hwnd

          set_always_on_top(hwnd, always_on_top)
          set_opacity(hwnd, opacity)
          set_borderless(hwnd, borderless)
          true
        rescue StandardError => error
          log("applying window presentation failed: #{error.class}: #{error.message}")
          false
        end

        def alive?(hwnd)
          return false unless available? && hwnd

          !win32.IsWindow(hwnd).zero?
        rescue StandardError
          false
        end

        # Looks for the window in the background, then hands it back on the
        # caller's own thread. Never runs on the session thread: the session
        # thread is the one every script handler and timer runs on, and
        # polling there would stall all of them.
        def discover(pid, timeout: DISCOVERY_TIMEOUT, &on_found)
          return nil unless available?

          thread_factory.call do
            deadline = timeout
            hwnd = nil
            while deadline.positive?
              hwnd = find_window(pid)
              break if hwnd

              sleeper.call(DISCOVERY_INTERVAL)
              deadline -= DISCOVERY_INTERVAL
            end
            on_found&.call(hwnd)
          end
        end

        private

        def set_always_on_top(hwnd, wanted)
          # The second argument MUST be declared and passed as a pointer. As a
          # `long` it is four bytes on this LLP64 runtime, so -1 arrives in the
          # 64-bit register as 0x00000000FFFFFFFF -- not HWND_TOPMOST but an
          # invalid handle, and the call then does nothing while returning no
          # error at all. Silent success is the worst possible failure here.
          target = Fiddle::Pointer.new(wanted ? HWND_TOPMOST : HWND_NOTOPMOST)
          win32.SetWindowPos(hwnd, target, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE)
        end

        def set_opacity(hwnd, opacity)
          # Alpha 255 restores an opaque window while leaving the layered bit
          # set, which reverts opacity without a frame change and without
          # touching the z-order bit SetWindowPos owns.
          alpha = ((opacity || 1.0).to_f.clamp(0.0, 1.0) * 255).round.clamp(1, 255)
          style = win32.GetWindowLongW(hwnd, GWL_EXSTYLE) & 0xFFFF_FFFF
          win32.SetWindowLongW(hwnd, GWL_EXSTYLE, style | WS_EX_LAYERED) if (style & WS_EX_LAYERED).zero?
          win32.SetLayeredWindowAttributes(hwnd, 0, alpha, LWA_ALPHA)
        end

        # Strips (or restores) the title bar. Only WS_CAPTION moves:
        # WS_THICKFRAME stays so the window is still resizable by its edges,
        # and WS_SYSMENU stays so alt+space still reaches the system menu.
        # SWP_FRAMECHANGED is required or the frame is not recomputed and the
        # change does not show until something else resizes the window.
        def set_borderless(hwnd, wanted)
          style = win32.GetWindowLongW(hwnd, GWL_STYLE) & 0xFFFF_FFFF
          captioned = !(style & WS_CAPTION).zero?
          return if captioned != wanted

          updated = wanted ? style & ~WS_CAPTION : style | WS_CAPTION
          win32.SetWindowLongW(hwnd, GWL_STYLE, updated)
          win32.SetWindowPos(hwnd, Fiddle::Pointer.new(0), 0, 0, 0, 0,
                             SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER)
        end

        def window_matches?(hwnd, pid)
          return false if win32.IsWindowVisible(hwnd).zero?
          return false unless owning_pid(hwnd) == pid
          # A top-level window, not a menu or a tooltip Chromium also owns.
          return false unless win32.GetWindow(hwnd, GW_OWNER).to_i.zero?

          window_class(hwnd) == WINDOW_CLASS
        end

        def owning_pid(hwnd)
          # A process id really is a 32-bit DWORD, so 'L' is right here even
          # though a handle would not be.
          buffer = [0].pack('L')
          win32.GetWindowThreadProcessId(hwnd, buffer)
          buffer.unpack1('L')
        end

        def window_class(hwnd)
          buffer = Fiddle::Pointer.malloc(512)
          length = win32.GetClassNameW(hwnd, buffer, 255)
          return '' unless length.positive?

          buffer[0, length * 2].force_encoding('UTF-16LE').encode('UTF-8')
        rescue StandardError
          ''
        end

        def log(message)
          return unless defined?(Lich) && Lich.respond_to?(:log)

          Lich.log("warning: webui-window-presentation: #{message}")
        end
      end
    end
  end
end

# The bindings themselves. Defined only on a native Windows runtime, and
# guarded: a dlload or extern that fails raises at definition time, and
# frontend.rb leaves its own unguarded -- which would take the whole file
# down with it. Absent bindings simply mean the feature is unavailable.
if Lich::Common::Frontend.native_windows_runtime? && !defined?(::WinPresentation)
  begin
    module ::WinPresentation
      extend Fiddle::Importer
      dlload 'user32.dll'
      extern 'int EnumWindows(void*, long)'
      extern 'int IsWindowVisible(void*)'
      extern 'int IsWindow(void*)'
      extern 'int GetWindowThreadProcessId(void*, void*)'
      extern 'int GetClassNameW(void*, void*, int)'
      extern 'void* GetWindow(void*, unsigned int)'
      # hWndInsertAfter is void* on purpose; see set_always_on_top.
      extern 'int SetWindowPos(void*, void*, int, int, int, int, unsigned int)'
      extern 'long GetWindowLongW(void*, int)'
      extern 'long SetWindowLongW(void*, int, long)'
      extern 'int SetLayeredWindowAttributes(void*, unsigned long, unsigned char, unsigned long)'
    end
  rescue StandardError => error
    if defined?(Lich) && Lich.respond_to?(:log)
      Lich.log("warning: webui window presentation unavailable: #{error.class}: #{error.message}")
    end
  end
end
