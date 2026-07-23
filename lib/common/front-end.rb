# frozen_string_literal: true

require 'tempfile'
require 'json'
require 'fileutils'
require 'fiddle'
require 'fiddle/import'
require 'open3'
require 'os'
require_relative '../util/deep_freeze'

# Define the ABI predicate before the top-level Win32 binding guard that uses it;
# the main Frontend implementation continues in the module reopening below.
module Lich
  module Common
    module Frontend
      PLATFORM_KEYS = %i[darwin linux windows unsupported].freeze

      # Native user32 bindings require a Windows MRI ABI, not merely a Windows host.
      # @return [Boolean]
      def self.native_windows_runtime?
        OS.host_os.to_s.match?(/mingw|mswin/i)
      end
    end
  end
end

# Windows API modules for frontend PID detection and window focus.
# Keep this narrower than Frontend.windows_platform?: these direct Fiddle
# bindings are supported by native mingw/mswin Ruby, not every Windows-like
# compatibility runtime recognized for executable discovery.
if Lich::Common::Frontend.native_windows_runtime?
  unless defined?(::Win32Enum)
    module ::Win32Enum
      extend Fiddle::Importer
      dlload 'user32.dll'
      extern 'int EnumWindows(void*, long)'
      extern 'int IsWindowVisible(void*)'
      extern 'int GetWindowThreadProcessId(void*, void*)'
    end
  end

  unless defined?(::WinAPI)
    module ::WinAPI
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
      ORIGIN_SENTINEL = "\x1f"

      def self.deep_copy(value)
        case value
        when Hash
          value.each_with_object({}) { |(key, item), copy| copy[key] = deep_copy(item) }
        when Array
          value.map { |item| deep_copy(item) }
        else
          value.dup
        end
      end
      private_class_method :deep_copy

      # --- Frontend Registry -------------------------------------
      # Each registered frontend has:
      #   - capabilities: Set of symbols (e.g., :xml, :streams, :mono)
      #   - metadata: Hash of additional data (e.g., client_string)
      #
      # This registry-based approach allows adding new frontends via
      # configuration without modifying the controller code.
      @registry = {}
      @aliases = {}
      @definitions = {}

      # Registers a frontend with its capabilities and metadata.
      # @param name [Symbol, String] The name of the frontend (e.g., :wrayth)
      # @param capabilities [Array<Symbol>] A list of capabilities (e.g., [:xml, :streams])
      # @param metadata [Hash] Additional data (e.g., { client_string: "..." })
      def self.register(name, capabilities: [], metadata: {})
        key = name.to_s.downcase
        raise ArgumentError, 'frontend name must not be empty' if key.empty?

        entry = (@registry[key] ||= { capabilities: Set.new, metadata: {} })
        entry[:capabilities].merge(capabilities.map(&:to_sym))
        entry[:metadata].merge!(deep_copy(metadata))
        Array(metadata[:aliases]).each { |alias_name| @aliases[alias_name.to_s.downcase] = key }
        @definitions.delete(key)
      end

      # Returns the stable catalog identifier for a frontend or alias.
      # Unknown values are normalized but are not registered.
      #
      # @param frontend_name [String, Symbol]
      # @return [String]
      def self.canonical_name(frontend_name)
        key = frontend_name.to_s.downcase
        @aliases.fetch(key, key)
      end

      # Checks if a frontend has a specific capability.
      # @param frontend_name [String] The name of the frontend to check
      # @param capability [Symbol] The capability to check for
      # @return [Boolean]
      def self.has_capability?(frontend_name, capability)
        return false if frontend_name.nil?

        entry = @registry[canonical_name(frontend_name)]
        entry ? entry[:capabilities].include?(capability.to_sym) : false
      end

      # Retrieves a metadata value for a given frontend.
      # @param frontend_name [String] The name of the frontend
      # @param key [Symbol] The metadata key to retrieve
      # @return [Object, nil]
      def self.metadata_for(frontend_name, key)
        return nil if frontend_name.nil?

        entry = @registry[canonical_name(frontend_name)]
        entry && entry[:metadata][key]
      end

      # Returns an immutable catalog definition for a registered frontend.
      #
      # Accepted inputs are a non-empty String or Symbol naming an existing
      # registry entry. Invalid or unknown identifiers raise ArgumentError.
      # This method performs no discovery and persists nothing.
      #
      # @param frontend_name [String, Symbol]
      # @return [Hash]
      # @raise [ArgumentError] if frontend_name is blank or unregistered
      def self.definition_for(frontend_name)
        key = canonical_name(frontend_name)
        raise ArgumentError, 'frontend name must not be empty' if key.empty?
        raise ArgumentError, "unknown frontend: #{frontend_name}" unless @registry.key?(key)

        @definitions[key] ||= Lich::Util.deep_freeze(
          {
            id: key,
            capabilities: @registry.fetch(key)[:capabilities].to_a,
            metadata: deep_copy(@registry.fetch(key)[:metadata])
          }
        )
      end

      # Returns immutable catalog definitions, optionally restricted to those
      # intended for the graphical launcher.
      #
      # @param gui_selectable [Boolean, nil]
      # @return [Array<Hash>]
      def self.definitions(gui_selectable: nil)
        definitions = @registry.keys.map { |name| definition_for(name) }
        return definitions if gui_selectable.nil?

        definitions.select do |definition|
          definition.dig(:metadata, :gui_selectable) == gui_selectable
        end
      end

      # Returns the canonical platform key used by frontend discovery and
      # launch-plan metadata.
      #
      # @return [Symbol] :darwin, :windows, :linux, or :unsupported
      def self.platform_key
        return :darwin if OS.mac?
        return :linux if OS.linux?
        return :windows if OS.windows?

        :unsupported
      end

      # Validates a canonical platform key used by discovery and launch plans.
      #
      # @param key [Symbol]
      # @return [Symbol]
      # @raise [ArgumentError] when key is not canonical
      def self.validate_platform_key!(key)
        return key if PLATFORM_KEYS.include?(key)

        raise ArgumentError, "invalid platform key: #{key.inspect}"
      end

      # Returns whether the current host is classified as Windows.
      #
      # @return [Boolean]
      def self.windows_platform?
        platform_key == :windows
      end

      # Returns the catalog display name, with a stable fallback for legacy
      # saved entries that predate the catalog.
      #
      # @param frontend_name [String, Symbol]
      # @return [String]
      def self.display_name(frontend_name)
        definition_for(frontend_name).dig(:metadata, :display_name) || frontend_name.to_s.capitalize
      rescue ArgumentError
        frontend_name.to_s.capitalize
      end

      # Returns every recognized frontend name: canonical catalog identifiers
      # followed by their accepted aliases.
      # @return [Array<String>]
      def self.registered_frontends
        @registry.keys + @aliases.keys
      end

      # Returns all frontends that have a specific capability.
      # @param capability [Symbol] The capability to filter by
      # @return [Array<String>]
      def self.frontends_with_capability(capability)
        canonical = @registry.select { |_name, data| data[:capabilities].include?(capability.to_sym) }.keys
        aliases = @aliases.filter_map do |alias_name, name|
          alias_name if canonical.include?(name)
        end
        canonical + aliases
      end

      # --- Default Frontend Registrations ------------------------

      register(:stormfront,
               capabilities: %i[xml streams mono room_window],
               metadata: {
                 display_name: 'Wrayth',
                 aliases: %w[wrayth],
                 gui_selectable: true,
                 launcher_adapter: :simutronics,
                 discovery: {
                   executables: %w[Wrayth.exe StormFront.exe],
                   registry_keys: [
                     'SOFTWARE\\Simutronics\\STORM32',
                     'SOFTWARE\\WOW6432Node\\Simutronics\\STORM32'
                   ]
                 }
               })

      register(:profanity,
               capabilities: %i[xml streams])

      register(:genie,
               capabilities: %i[xml mono])

      register(:frostbite,
               capabilities: %i[xml])

      # SUKS has no client socket, so frontend protocol capabilities do not apply.
      register(:suks,
               metadata: {
                 launcher_adapter: :embedded
               })

      register(:wizard,
               capabilities: %i[gsl],
               metadata: {
                 display_name: 'Wizard',
                 gui_selectable: true,
                 launcher_adapter: :simutronics,
                 discovery: {
                   executables: %w[Wizard.exe],
                   registry_keys: [
                     'SOFTWARE\\Simutronics\\WIZ32',
                     'SOFTWARE\\WOW6432Node\\Simutronics\\WIZ32'
                   ]
                 }
               })

      register(:avalon,
               capabilities: %i[gsl],
               metadata: {
                 display_name: 'Avalon',
                 gui_selectable: true,
                 launcher_adapter: :avalon,
                 native_launch_only: true,
                 discovery: {
                   executables: %w[Avalon avalon],
                   mac_bundle_ids: %w[Avalon SimutronicsAvalon],
                   path_lookup: false
                 }
               })

      SAGA_TEMPORARY_LAUNCH_ENVIRONMENT = {
        'SAGA_LICH_MODE' => '1',
        'SAGA_LICH_HOST' => '%host%',
        'SAGA_LICH_PORT' => '%port%',
        'SAGA_LICH_KEY'  => '%key%'
      }.freeze

      register(:saga,
               capabilities: %i[xml streams mono room_window sentinel],
               metadata: {
                 display_name: 'Saga',
                 gui_selectable: true,
                 gui_platforms: %i[darwin windows linux],
                 launcher_adapter: :environment,
                 launcher_status: :temporary_pending_cli_login,
                 launch_notice: 'Temporary Saga launch bridge pending Saga CLI login support',
                 native_launch_only: true,
                 # Temporary cold-start bridges pending Saga's external CLI
                 # login capability. Saga currently forwards only the mode flag
                 # to an existing process, not this connection payload.
                 launch_plans: {
                   darwin: {
                     command: '/usr/bin/open',
                     arguments: %w[-n -b com.auchand.saga],
                     environment: SAGA_TEMPORARY_LAUNCH_ENVIRONMENT
                   },
                   windows: {
                     command: :resolved_executable,
                     arguments: [],
                     environment: SAGA_TEMPORARY_LAUNCH_ENVIRONMENT
                   },
                   linux: {
                     command: :resolved_executable,
                     arguments: [],
                     environment: SAGA_TEMPORARY_LAUNCH_ENVIRONMENT
                   }
                 },
                 discovery: {
                   executables: %w[Saga Saga.exe saga],
                   mac_bundle_ids: %w[com.auchand.saga],
                   # Do not search PATH: `saga` also names the unrelated SAGA GIS
                   # executable. Saga's Linux AppImage location is user-selected;
                   # /opt is one known convention pending desktop/AppImage discovery.
                   path_lookup: false,
                   paths: {
                     windows: [
                       '%LOCALAPPDATA%/Programs/Saga/Saga.exe',
                       '%LOCALAPPDATA%/Programs/saga/Saga.exe',
                       '%PROGRAMFILES%/Saga/Saga.exe',
                       '%PROGRAMFILES(X86)%/Saga/Saga.exe'
                     ],
                     linux: [
                       '/opt/Saga/saga'
                     ]
                   }
                 }
               })

      # --- Client String -----------------------------------------
      # Default client string (Wrayth identity) sent during handshake
      CLIENT_STRING = "/FE:WRAYTH /VERSION:1.0.1.28 /P:WIN_UNKNOWN /XML"

      # --- Backward-Compatible Constants -------------------------
      # These arrays are derived from the registry for backward compatibility.
      # External code may still reference these constants directly.
      XML_FRONTENDS      = frontends_with_capability(:xml).freeze
      GSL_FRONTENDS      = frontends_with_capability(:gsl).freeze
      STREAM_FRONTENDS   = frontends_with_capability(:streams).freeze
      MONO_FRONTENDS     = frontends_with_capability(:mono).freeze
      SENTINEL_FRONTENDS = frontends_with_capability(:sentinel).freeze

      # --- Predicate Methods -------------------------------------
      # These now delegate to has_capability? for consistency.

      def self.supports_xml?(fe = $frontend)
        has_capability?(fe, :xml)
      end

      def self.supports_gsl?(fe = $frontend)
        has_capability?(fe, :gsl)
      end

      def self.supports_streams?(fe = $frontend)
        has_capability?(fe, :streams)
      end

      def self.supports_mono?(fe = $frontend)
        has_capability?(fe, :mono)
      end

      def self.supports_room_window?(fe = $frontend)
        has_capability?(fe, :room_window)
      end

      def self.supports_sentinel?(fe = $frontend)
        has_capability?(fe, :sentinel)
      end

      # Build the <playerID> re-emit tag for a detachable client (e.g. Saga).
      #
      # Lich consumes the game's one-time <playerID> during its own login
      # handshake, before a detachable client attaches, so the client never
      # sees it. XMLData.player_id stores the id verbatim, so re-emitting
      # reproduces exactly what a Direct login delivers.
      #
      # Returns the tag string only when player_id is a bare numeric id (the
      # form the game sends). Returns nil otherwise, so callers skip emitting
      # an empty or malformed tag before login has populated the id.
      def self.player_id_tag(player_id)
        id = player_id.to_s
        return nil unless id =~ /\A\d+\z/

        "<playerID id='#{id}'/>"
      end

      # Accessor for the current frontend identity ($frontend global)
      def self.client
        $frontend
      end

      # Setter for the current frontend identity
      def self.client=(value)
        $frontend = value
      end

      # Send version string, ready signals, and setup commands to the game server.
      # Used during login handshake for wizard/avalon/frostbite frontends.
      def self.send_handshake(version_string)
        $_CLIENTBUFFER_.push(version_string.dup)
        Game._puts(version_string)
        2.times do
          sleep 0.3
          $_CLIENTBUFFER_.push("#{$cmd_prefix}\r\n")
          Game._puts($cmd_prefix)
        end
        ["#{$cmd_prefix}_injury 2",
         "#{$cmd_prefix}_flag Display Inventory Boxes 1",
         "#{$cmd_prefix}_flag Display Dialog Boxes 0"].each do |cmd|
          $_CLIENTBUFFER_.push(cmd)
          Game._puts(cmd)
        end
      end

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
        @pid_mutex.synchronize { @frontend_pid }
      end

      # Set the frontend PID
      # @param value [Integer] The PID to store
      # @return [Integer] The stored PID
      def self.pid=(value)
        value = value.to_i
        @pid_mutex.synchronize { @frontend_pid = value }
      end

      # Initialize PID from parent process (for Warlock)
      # @return [Integer, nil] The resolved frontend PID
      def self.init_from_parent(parent_pid)
        Lich.log "=== Frontend.init_from_parent called ==="
        Lich.log "Parent process PID: #{parent_pid}"

        # Let's see what process this actually is on Windows
        if windows_platform?
          begin
            require 'win32ole'
            wmi = WIN32OLE.connect('winmgmts://')
            rows = wmi.ExecQuery("SELECT Name, ProcessId FROM Win32_Process WHERE ProcessId=#{parent_pid}")
            row = rows.each.first rescue nil
            if row
              Lich.log "Parent process name: #{row.Name}"
            end
          rescue StandardError, LoadError => e
            Lich.log "Could not get parent process name: #{e.message}"
          end
        end

        resolved_pid = resolve_pid(parent_pid)
        Lich.log "resolve_pid(#{parent_pid}) returned: #{resolved_pid}"

        self.pid = resolved_pid
        Lich.log "Frontend PID set to: #{self.pid}"

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
        key = platform_key
        key == :darwin ? :macos : key
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
        Lich.log "=== resolve_windows_pid starting with PID: #{pid} ==="

        ensure_windows_modules
        require 'win32ole' rescue (return pid)

        begin
          wmi = WIN32OLE.connect('winmgmts://')
          p = pid

          16.times do
            # Get process name for debugging
            rows = wmi.ExecQuery("SELECT Name FROM Win32_Process WHERE ProcessId=#{p}")
            row = rows.each.first rescue nil
            process_name = row ? row.Name : "unknown"
            Lich.log "  Process name: #{process_name}"

            # Check if this process owns any visible window
            found = false
            cb = Fiddle::Closure::BlockCaller.new(
              Fiddle::TYPE_INT,
              [Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG]
            ) do |hwnd, _|
              next 1 if ::Win32Enum.IsWindowVisible(hwnd).zero?
              buf = [0].pack('L')
              ::Win32Enum.GetWindowThreadProcessId(hwnd, buf)
              if buf.unpack1('L') == p
                found = true
                Lich.log "  Found visible window for PID #{p}"
                0  # stop enumeration
              else
                1  # continue enumeration
              end
            end
            ::Win32Enum.EnumWindows(cb, 0)

            if found
              Lich.log "  Stopping at PID #{p} (#{process_name}) - has visible window"
              return p
            end

            # Walk up to parent process
            parent = windows_parent_pid(wmi, p)

            break if parent.nil? || parent.zero? || parent == p
            p = parent
          end
        rescue => e
          Lich.log "ERROR in resolve_windows_pid: #{e}"
        end

        Lich.log "Fallback: returning original PID #{pid}"
        pid
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
          next 1 if ::WinAPI.IsWindowVisible(hwnd).zero?

          pid_tmp = [0].pack('L')
          ::WinAPI.GetWindowThreadProcessId(hwnd, pid_tmp)
          win_pid = pid_tmp.unpack1('L')

          if win_pid == pid
            hwnd_buf[0, Fiddle::SIZEOF_VOIDP] = [hwnd].pack('L!')
            0  # stop enumeration
          else
            1  # continue enumeration
          end
        end

        ::WinAPI.EnumWindows(enum_cb, 0)
        hwnd = hwnd_buf[0, Fiddle::SIZEOF_VOIDP].unpack1('L!')

        if hwnd != 0
          ::WinAPI.SetForegroundWindow(hwnd)
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
        return false unless native_windows_runtime?

        defined?(::Win32Enum) && defined?(::WinAPI)
      end
    end
  end
end

# Top-level alias so all consumers can use bare `Frontend`
Frontend = Lich::Common::Frontend unless defined?(Frontend)
