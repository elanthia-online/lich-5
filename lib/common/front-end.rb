require 'tempfile'
require 'json'
require 'fileutils'
require 'fiddle'
require 'fiddle/import'
require 'open3'

# Windows API modules for frontend PID detection and window focus
# These need to be defined at the top level
if RUBY_PLATFORM =~ /mingw|mswin/
  unless defined?(Win32Enum)
    module Win32Enum
      extend Fiddle::Importer
      dlload 'user32.dll'
      extern 'int EnumWindows(void*, long)'
      extern 'int IsWindowVisible(void*)'
      extern 'int GetWindowThreadProcessId(void*, void*)'
    end
  end

  unless defined?(WinAPI)
    module WinAPI
      extend Fiddle::Importer
      dlload 'user32.dll'
      extern 'int EnumWindows(void*, long)'
      extern 'int GetWindowThreadProcessId(void*, void*)'
      extern 'int IsWindowVisible(void*)'
      extern 'int SetForegroundWindow(void*)'
    end
  end
end

module Lich
  module Common
    module Frontend
      @session_file = nil
      @tmp_session_dir = File.join Dir.tmpdir, "simutronics", "sessions"
      @frontend_pid = nil
      @pid_mutex = Mutex.new

      # Existing session file methods
      def self.create_session_file(name, host, port, display_session: true)
        return if name.nil?
        FileUtils.mkdir_p @tmp_session_dir
        @session_file = File.join(@tmp_session_dir, "%s.session" % name.downcase.capitalize)
        session_descriptor = { name: name, host: host, port: port }.to_json
        puts "writing session descriptor to %s\n%s" % [@session_file, session_descriptor] if display_session
        File.open(@session_file, "w") do |fd|
          fd << session_descriptor
        end
      end

      def self.session_file_location
        @session_file
      end

      def self.cleanup_session_file
        return if @session_file.nil?
        File.delete(@session_file) if File.exist? @session_file
      end

      # Frontend PID tracking functionality

      # Get the current frontend PID
      # @return [Integer, nil] The PID if set, nil otherwise
      def self.pid
        @pid_mutex.synchronize { @frontend_pid || $frontend_pid }
      end

      # Set the frontend PID
      # @param value [Integer] The PID to store
      # @return [Integer] The stored PID
      def self.pid=(value)
        value = value.to_i
        @pid_mutex.synchronize {
          @frontend_pid = value
          $frontend_pid = value # Maintain backward compatibility
        }
      end

      # Initialize PID from spawn (called from main.rb after spawn)
      # @param spawn_pid [Integer] The PID returned from spawn()
      # @return [Integer, nil] The resolved frontend PID
      def self.init_from_spawn(spawn_pid)
        return nil unless spawn_pid && spawn_pid > 0

        # Resolve to actual window owner
        resolved_pid = resolve_pid(spawn_pid)
        self.pid = resolved_pid

        Lich.log "Frontend PID initialized from spawn: #{resolved_pid}" if defined?(Lich.log)
        resolved_pid
      end

      # Initialize PID from parent process (for Warlock)
      # @return [Integer, nil] The resolved frontend PID
      def self.init_from_parent
        parent_pid = Process.ppid
        resolved_pid = resolve_pid(parent_pid)
        self.pid = resolved_pid

        Lich.log "Frontend PID initialized from parent: #{resolved_pid}" if defined?(Lich.log)
        resolved_pid
      end

      # Set PID from detachable client (for Profanity)
      # @param pid [Integer] The PID sent by the client
      # @return [Integer] The stored PID
      def self.set_from_client(pid)
        self.pid = pid
        Lich.log "Frontend PID set from client: #{pid}" if defined?(Lich.log)
        pid
      end

      # Detect and store the frontend process ID
      # Uses various methods depending on how Lich was launched
      # @return [Integer, nil] The detected PID or nil if detection fails
      def self.detect_pid
        # Return existing PID if already set
        current_pid = self.pid
        return current_pid if current_pid && current_pid > 0

        # Try to detect based on launch method
        # This is a fallback for cases where init wasn't called
        parent_pid = Process.ppid
        resolved_pid = resolve_pid(parent_pid)

        if resolved_pid && resolved_pid > 0
          self.pid = resolved_pid
          Lich.log "Frontend PID detected (fallback): #{resolved_pid}" if defined?(Lich.log)
          resolved_pid
        else
          Lich.log "Failed to detect frontend PID" if defined?(Lich.log)
          nil
        end
      end

      # Refocus the frontend window
      # @return [Boolean] true if successful, false otherwise
      def self.refocus
        pid = self.pid
        return false unless pid && pid > 0

        case detect_platform
        when :windows
          refocus_windows(pid)
        when :macos
          refocus_macos(pid)
        when :linux
          refocus_linux(pid)
        else
          false
        end
      end

      # Create a callback for GTK windows to refocus on click
      # @return [Proc] A proc that can be called to refocus the frontend
      def self.refocus_callback
        proc {
          if defined?(GLib) && GLib.respond_to?(:Idle)
            GLib::Idle.add(50) { self.refocus; false }
          else
            self.refocus
          end
        }
      end

      # Detect the current platform
      # @return [Symbol] :windows, :macos, :linux, or :unsupported
      def self.detect_platform
        case RUBY_PLATFORM
        when /mingw|mswin/ then :windows
        when /darwin/      then :macos
        when /linux/       then :linux
        else                    :unsupported
        end
      end

      # Resolve PID by walking up process tree to find window owner
      # @param pid [Integer] Starting process ID
      # @return [Integer] The resolved PID
      def self.resolve_pid(pid)
        pid = pid.to_i
        return pid if pid <= 0 # Return as-is if invalid

        # Use the FrontendPID resolver logic
        case detect_platform
        when :windows
          resolve_windows_pid(pid)
        when :linux
          resolve_linux_pid(pid)
        else
          # macOS/other: PID usually already owns the window
          pid
        end
      end

      # Windows-specific PID resolution
      def self.resolve_windows_pid(pid)
        # Ensure Win32 modules are loaded
        ensure_windows_modules

        require 'win32ole' rescue (return pid)

        begin
          wmi = WIN32OLE.connect('winmgmts://')
          p = pid

          16.times do
            # Check if this process owns any visible window
            found = false
            cb = Fiddle::Closure::BlockCaller.new(
              Fiddle::TYPE_INT,
              [Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG]
            ) do |hwnd, _|
              next 1 if Win32Enum.IsWindowVisible(hwnd).zero?
              buf = [0].pack('L')
              Win32Enum.GetWindowThreadProcessId(hwnd, buf)
              if buf.unpack1('L') == p
                found = true
                0  # stop enumeration
              else
                1  # continue enumeration
              end
            end
            Win32Enum.EnumWindows(cb, 0)
            return p if found

            # Walk up to parent process
            parent = windows_parent_pid(wmi, p)
            break if parent.nil? || parent.zero? || parent == p
            p = parent
          end
        rescue => e
          Lich.log "Error resolving Windows PID: #{e}" if defined?(Lich.log)
        end

        pid # fallback to original
      end

      # Get parent process ID on Windows
      def self.windows_parent_pid(wmi, pid)
        rows = wmi.ExecQuery("SELECT ParentProcessId FROM Win32_Process WHERE ProcessId=#{pid}")
        row = rows.each.first rescue nil
        row ? row.ParentProcessId.to_i : 0
      end

      # Linux-specific PID resolution
      def self.resolve_linux_pid(pid)
        return pid unless system('which xdotool > /dev/null 2>&1')

        p = pid
        16.times do
          # Check if this process has a window
          return p if system("xdotool search --pid #{p} >/dev/null 2>&1")

          # Walk up to parent process
          begin
            status = File.read("/proc/#{p}/status")
            parent = status[/PPid:\s+(\d+)/, 1].to_i
          rescue
            parent = 0
          end
          return pid if parent.zero? || parent == p
          p = parent
        end

        pid # fallback
      rescue => e
        Lich.log "Error resolving Linux PID: #{e}" if defined?(Lich.log)
        pid
      end

      # Windows refocus implementation
      def self.refocus_windows(pid)
        ensure_windows_modules

        hwnd_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)

        enum_cb = Fiddle::Closure::BlockCaller.new(
          Fiddle::TYPE_INT,
          [Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG]
        ) do |hwnd, _|
          next 1 if WinAPI.IsWindowVisible(hwnd).zero?

          pid_tmp = [0].pack('L')
          WinAPI.GetWindowThreadProcessId(hwnd, pid_tmp)
          win_pid = pid_tmp.unpack1('L')

          if win_pid == pid
            hwnd_buf[0, Fiddle::SIZEOF_VOIDP] = [hwnd].pack('L!')
            0  # stop enumeration
          else
            1  # continue enumeration
          end
        end

        WinAPI.EnumWindows(enum_cb, 0)
        hwnd = hwnd_buf[0, Fiddle::SIZEOF_VOIDP].unpack1('L!')

        if hwnd != 0
          WinAPI.SetForegroundWindow(hwnd)
          true
        else
          Lich.log "Frontend window for PID #{pid} not found" if defined?(Lich.log)
          false
        end
      rescue => e
        Lich.log "Error refocusing Windows: #{e}" if defined?(Lich.log)
        false
      end

      # macOS refocus implementation
      def self.refocus_macos(pid)
        return false unless system('which osascript > /dev/null 2>&1')

        script = %{tell application "System Events" to set frontmost of (first process whose unix id is #{pid}) to true}
        _stdout, stderr, status = Open3.capture3('osascript', '-e', script)

        if status.success?
          true
        else
          Lich.log "Error refocusing macOS: #{stderr}" if defined?(Lich.log)
          false
        end
      rescue => e
        Lich.log "Error refocusing macOS: #{e}" if defined?(Lich.log)
        false
      end

      # Linux refocus implementation
      def self.refocus_linux(pid)
        return false unless system('which xdotool > /dev/null 2>&1')

        _stdout, stderr, status = Open3.capture3('xdotool', 'search', '--pid', pid.to_s, 'windowactivate')

        if status.success?
          true
        else
          Lich.log "Error refocusing Linux: #{stderr}" if defined?(Lich.log)
          false
        end
      rescue => e
        Lich.log "Error refocusing Linux: #{e}" if defined?(Lich.log)
        false
      end

      # Ensure Windows modules are loaded (they're defined at top level)
      def self.ensure_windows_modules
        # Check if modules exist - they should be defined at file load time
        if RUBY_PLATFORM =~ /mingw|mswin/
          return defined?(::Win32Enum) && defined?(::WinAPI)
        end
        false
      end
    end
  end
end

# Maintain backward compatibility for direct access to frontend_pid
def frontend_pid
  Frontend.pid
end
