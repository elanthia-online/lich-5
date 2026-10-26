# frozen_string_literal: true

require 'os'
require 'fiddle/import'
require_relative 'host_thread'
require_relative 'errors'

module Lich
  module WebUI
    # Applies Win32 presentation to an owned Chromium app window. The API and
    # pointer-width corrections follow EO #1648; our isolated browser profiles
    # permit strict PID ownership, without the title fallback repaired in #1657.
    module WindowPresentation
      HWND_TOPMOST = -1
      HWND_NOTOPMOST = -2
      SWP_FLAGS = 0x0001 | 0x0002 | 0x0010 # NOSIZE, NOMOVE, NOACTIVATE
      GWL_EXSTYLE = -20
      WS_EX_LAYERED = 0x00080000
      SUPPORT = { always_on_top: true, opacity: true, hidden: true }.freeze
      ABI = Fiddle::Function.const_defined?(:STDCALL) ? Fiddle::Function::STDCALL : Fiddle::Function::DEFAULT

      class << self
        # Loads system bindings only on Windows; no compiler or helper binary.
        # @return [Module, nil] user32/kernel32 bindings, absent when unavailable
        def bindings
          return unless OS.windows?
          return @bindings if defined?(@bindings)

          @bindings = Module.new do
            extend Fiddle::Importer
            dlload 'user32.dll', 'kernel32.dll'
            convention = ABI == Fiddle::Function::DEFAULT ? :cdecl : :stdcall
            [
              'int EnumWindows(void*, void*)', 'int IsWindow(void*)',
              'int ShowWindow(void*, int)', 'int IsWindowVisible(void*)', 'void* GetWindow(void*, unsigned int)',
              'int GetWindowThreadProcessId(void*, void*)', 'int GetClassNameW(void*, void*, int)',
              'int SetWindowPos(void*, void*, int, int, int, int, unsigned int)',
              'long GetWindowLongW(void*, int)', 'long SetWindowLongW(void*, int, long)',
              'int SetLayeredWindowAttributes(void*, unsigned long, unsigned char, unsigned long)',
              'void SetLastError(unsigned long)', 'unsigned long GetLastError()',
            ].each { |signature| extern(signature, convention) }
          end
        rescue Fiddle::DLError => error
          warn_failure(error)
          @bindings = nil
        end

        # Checks binding availability without starting window discovery.
        # @return [Boolean] whether the native Windows bindings loaded
        def available? = !bindings.nil?

        # Advertises native capabilities only when their system bindings loaded.
        # @return [Hash{Symbol => Boolean}] supported real-window properties
        def support = available? ? SUPPORT : {}

        # Reports the error class without exposing page contents or launch credentials.
        # @param error [Exception] failure; do not log window contents or URLs
        # @return [void]
        def warn_failure(error)
          Lich.log("warning: WebUI window presentation failed: #{error.class}") if Lich.respond_to?(:log)
        end
      end

      # One controller per BrowserWindow. Discovery is bounded; later changes
      # arrive with validated renders. Closing prevents late discovery/apply.
      class Controller
        # Prepares a controller that remains inactive until an owned PID arrives.
        # @param win32 [Module] native bindings or a test implementation
        # @param thread_factory [#call] host-owned discovery worker factory
        # @param sleeper [#call] delay between discovery attempts
        # @param clock [#call] monotonic time source
        def initialize(win32: WindowPresentation.bindings, thread_factory: HostThread.method(:start),
                       sleeper: Kernel.method(:sleep), clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
          @win32, @thread_factory, @sleeper, @clock = win32, thread_factory, sleeper, clock
          @mutex = Mutex.new
          @closed = false
          @desired = { always_on_top: false, opacity: 1.0, hidden: false }
          @generation = 0
        end

        # Starts bounded discovery; ambiguous matches never receive native writes.
        # @param pid [Integer] process spawned for this isolated browser profile
        # @return [void]
        def start(pid)
          @mutex.synchronize { return if @closed; @pid = pid }
          @thread_factory.call do
            # Construct the closure on the thread that calls EnumWindows.
            finder = window_finder(pid)
            deadline = @clock.call + 15.0
            loop do
              finished = @mutex.synchronize do
                break true if @closed

                @hwnd = finder.call
                apply if @hwnd
                !!@hwnd
              end
              break if finished
              if @clock.call >= deadline
                raise Error, 'owned browser window was not found unambiguously'
              end

              @sleeper.call(0.1)
            end
          rescue StandardError => error
            WindowPresentation.warn_failure(error)
          end
          nil
        end

        # Accepts the same validated presentation record for native and shim
        # pages. A delayed older render must not overwrite a newer request.
        # @param render [Page::Render] validated page render
        # @return [void]
        def update(render)
          @mutex.synchronize do
            return if @closed || render.generation < @generation

            @generation = render.generation
            props = (render.tree.props[:presentation] || {}).merge(render.facilities[:presentation] || {})
            @desired = { always_on_top: props.fetch(:always_on_top, false), opacity: props.fetch(:opacity, 1.0),
                         hidden: props.fetch(:hidden, false) }
            apply if @hwnd
          end
        rescue StandardError => error
          WindowPresentation.warn_failure(error)
        end

        # Prevents later native writes before the owning process is terminated.
        # @return [void]
        def close
          @mutex.synchronize { @closed = true; @hwnd = nil }
        end

        private

        # Builds a reusable enumerator whose callback lives on its invoking thread.
        # @param pid [Integer] process that must own the matching window
        # @api private
        # @return [Proc] enumerator refusing absent or ambiguous owned windows
        def window_finder(pid)
          matches = []
          callback = Fiddle::Closure::BlockCaller.new(Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], ABI) do |hwnd, _|
            matches << Fiddle::Pointer.new(hwnd.to_i) if owned?(hwnd, pid)
            1
          end
          lambda do
            matches.clear
            check(@win32.EnumWindows(callback, Fiddle::Pointer.new(0)))
            matches.one? ? matches.first : nil
          end
        end

        # Rejects stale, hidden, child-owned or unrelated application handles.
        # Releases the UTF-16 class-name buffer on success, rejection or exception.
        # @param hwnd [Fiddle::Pointer, Integer] candidate native window handle
        # @param pid [Integer] retained browser process identity
        # @param visible [Boolean] require visibility during discovery only
        # @api private
        # @return [Boolean] unowned top-level Chromium window for pid
        def owned?(hwnd, pid, visible: true)
          return false if @win32.IsWindow(hwnd).zero? || (visible && @win32.IsWindowVisible(hwnd).zero?)
          return false unless @win32.GetWindow(hwnd, 4).to_i.zero? # GW_OWNER

          owner = [0].pack('L') # DWORD is 32 bits even on Win64.
          @win32.GetWindowThreadProcessId(hwnd, owner)
          return false unless owner.unpack1('L') == pid

          Fiddle::Pointer.malloc(512, Fiddle::RUBY_FREE) do |buffer|
            length = @win32.GetClassNameW(hwnd, buffer, 255)
            length.positive? && buffer[0, length * 2].force_encoding('UTF-16LE').encode('UTF-8') == 'Chrome_WidgetWin_1'
          end
        end

        # Applies changed topmost, alpha and visibility without taking focus.
        # The controller mutex must be held. Unchanged requests need no native
        # work; changed requests recheck PID ownership before any native write.
        # @api private
        # @return [void]
        def apply
          return if @applied == @desired
          return unless owned?(@hwnd, @pid, visible: false)

          # HWND_TOPMOST is a pointer-sized -1, not a Windows 32-bit long.
          target = Fiddle::Pointer.new(@desired[:always_on_top] ? HWND_TOPMOST : HWND_NOTOPMOST)
          check(@win32.SetWindowPos(@hwnd, target, 0, 0, 0, 0, SWP_FLAGS))
          @win32.SetLastError(0)
          style = @win32.GetWindowLongW(@hwnd, GWL_EXSTYLE)
          check(@win32.GetLastError.zero? ? 1 : 0) if style.zero?
          style &= 0xFFFF_FFFF
          if (style & WS_EX_LAYERED).zero?
            @win32.SetLastError(0)
            previous = @win32.SetWindowLongW(@hwnd, GWL_EXSTYLE, style | WS_EX_LAYERED)
            check(@win32.GetLastError.zero? ? 1 : 0) if previous.zero?
          end
          alpha = (@desired[:opacity] * 255).round.clamp(1, 255)
          check(@win32.SetLayeredWindowAttributes(@hwnd, 0, alpha, 2)) # LWA_ALPHA
          if @desired[:hidden] != (@applied || {})[:hidden] && (@desired[:hidden] || @applied&.fetch(:hidden))
            # ShowWindow returns previous visibility, not success. Retain this
            # owned handle while hidden so a later render can reveal it again.
            @win32.ShowWindow(@hwnd, @desired[:hidden] ? 0 : 4) # SW_HIDE / SW_SHOWNOACTIVATE
          end
          @applied = @desired
        end

        # Converts a failed Win32 BOOL into a diagnostic instead of reporting success.
        # @api private
        # @param result [Integer] Win32 BOOL result
        # @raise [Error] on native failure, never report a successful no-op
        # @return [void]
        def check(result)
          raise Error, 'Win32 window presentation call failed' if result.zero?
        end
      end
    end
  end
end
