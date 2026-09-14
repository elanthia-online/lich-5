# frozen_string_literal: true

require 'tempfile'
require 'json'
require 'fileutils'
require 'fiddle'
require 'fiddle/import'
require 'open3'
require 'os'
require 'monitor'
require 'set' # rubocop:disable Lint/RedundantRequireStatement -- needed when this file is loaded directly on Ruby < 3.2
require_relative '../util/deep_freeze'

# Define the ABI predicate before the top-level Win32 binding guard that uses it;
# the main Frontend implementation continues in the module reopening below.
module Lich
  module Common
    module Frontend
      PLATFORM_KEYS = %i[darwin linux windows unsupported].freeze
      CAPABILITY_VOCABULARY = %i[xml gsl streams mono room_window sentinel].freeze
      BUILT_IN_DEFINITION_FILES = [
        %w[stormfront wrayth],
        %w[profanity profanity],
        %w[genie genie],
        %w[frostbite frostbite],
        %w[suks suks],
        %w[wizard wizard],
        %w[avalon avalon],
        %w[saga saga]
      ].freeze
      BUILT_IN_FRONTEND_IDS = BUILT_IN_DEFINITION_FILES.map(&:first).freeze

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
      @registry_monitor = Monitor.new

      # Serializes registry reads and writes. Monitor is intentionally
      # reentrant because public catalog methods call one another.
      #
      # @param block [Proc] registry operation
      # @yield registry operation
      # @return [Object] block result
      # @api private
      def self.registry_synchronize(&block)
        @registry_monitor.synchronize(&block)
      end
      private_class_method :registry_synchronize

      # Registers a frontend with its capabilities and metadata.
      # @param name [Symbol, String] The name of the frontend (e.g., :wrayth)
      # @param capabilities [Array<Symbol>] A list of capabilities (e.g., [:xml, :streams])
      # @param metadata [Hash] Additional data (e.g., { client_string: "..." })
      # @return [void]
      def self.register(name, capabilities: [], metadata: {})
        registry_synchronize do
          key = name.to_s.downcase
          raise ArgumentError, 'frontend name must not be empty' if key.empty?

          aliases = Array(metadata[:aliases]).map { |alias_name| alias_name.to_s.downcase }
          settings_owned = Array(@user_frontend_ids)
          if settings_owned.include?(key) || aliases.any? { |alias_name| settings_owned.include?(alias_name) }
            raise ArgumentError, "frontend identifier is managed by user settings: #{key}"
          end

          entry = (@registry[key] ||= { capabilities: Set.new, metadata: {} })
          entry[:capabilities].merge(capabilities.map(&:to_sym))
          entry[:metadata].merge!(deep_copy(metadata))
          aliases.each { |alias_name| @aliases[alias_name] = key }
          @definitions.delete(key)
          nil
        end
      end

      # Returns the capabilities users may declare for custom frontends.
      # Runtime-only implementation details are deliberately excluded.
      # @return [Array<Symbol>]
      def self.capability_vocabulary
        CAPABILITY_VOCABULARY
      end

      # Returns the stable identifiers owned by Lich's built-in catalog.
      # User configuration may override only explicitly supported launch fields;
      # it cannot replace built-in identity, protocol capabilities, or defaults.
      # @return [Array<String>]
      def self.built_in_frontends
        BUILT_IN_FRONTEND_IDS
      end

      # Returns whether an identifier is available for a settings-owned custom
      # frontend. An identifier already owned by the current settings document
      # remains available so reloads can replace it without colliding with
      # themselves. Registry entries and aliases owned elsewhere are reserved.
      #
      # @param frontend_name [String, Symbol]
      # @return [Boolean]
      def self.user_definition_id_available?(frontend_name)
        registry_synchronize do
          key = frontend_name.to_s.downcase
          next false if key.empty?
          next true if Array(@user_frontend_ids).include?(key)

          !@registry.key?(key) && !@aliases.key?(key)
        end
      end

      # Replaces the complete process-local user configuration in one operation.
      # Built-ins are restored from their sealed defaults before launch-only
      # overrides are applied, and custom definitions from an earlier load are
      # removed before the new set is registered.
      #
      # FrontendSettings owns validation and persistence. This method is the
      # narrow application seam that keeps catalog reloads deterministic.
      #
      # @param built_in_overrides [Hash<String, Hash>]
      # @param custom_definitions [Hash<String, Hash>]
      # @return [void]
      def self.replace_user_configuration!(built_in_overrides:, custom_definitions:)
        registry_synchronize do
          raise 'built-in frontend catalog has not been sealed' unless @built_in_registry

          snapshot = {
            registry: deep_copy(@registry),
            aliases: deep_copy(@aliases),
            definitions: @definitions.dup,
            user_frontend_ids: Array(@user_frontend_ids).dup
          }

          begin
            replace_user_configuration_unlocked!(
              built_in_overrides: built_in_overrides,
              custom_definitions: custom_definitions
            )
          rescue StandardError
            @registry = snapshot[:registry]
            @aliases = snapshot[:aliases]
            @definitions = snapshot[:definitions]
            @user_frontend_ids = snapshot[:user_frontend_ids]
            raise
          end
        end
      end

      # Applies validated user configuration while the registry monitor is held.
      # The public wrapper snapshots state first so an invalid replacement rolls
      # back completely.
      #
      # @param built_in_overrides [Hash<String, Hash>]
      # @param custom_definitions [Hash<String, Hash>]
      # @return [void]
      # @api private
      def self.replace_user_configuration_unlocked!(built_in_overrides:, custom_definitions:)
        collisions = custom_definitions.keys.reject { |frontend_id| user_definition_id_available?(frontend_id) }
        unless collisions.empty?
          raise ArgumentError, "custom frontend identifier is already registered: #{collisions.join(', ')}"
        end

        previous_user_frontend_ids = Array(@user_frontend_ids)
        previous_user_frontend_ids.each { |frontend_id| @registry.delete(frontend_id) }
        @user_frontend_ids = []

        BUILT_IN_FRONTEND_IDS.each do |frontend_id|
          @registry[frontend_id] = deep_copy(@built_in_registry.fetch(frontend_id))
        end
        @aliases.delete_if do |_alias_name, target|
          previous_user_frontend_ids.include?(target) || BUILT_IN_FRONTEND_IDS.include?(target)
        end
        @aliases.merge!(deep_copy(@built_in_aliases))

        built_in_overrides.each do |frontend_id, override|
          metadata = @registry.fetch(frontend_id)[:metadata]
          metadata[:configured_executable] = override[:executable] if override[:executable]
          metadata[:additional_arguments] = deep_copy(override[:arguments]) if override[:arguments]
        end

        custom_definitions.each do |frontend_id, custom|
          raise ArgumentError, "cannot replace built-in frontend: #{frontend_id}" if BUILT_IN_FRONTEND_IDS.include?(frontend_id)

          register(
            frontend_id,
            capabilities: custom.fetch(:capabilities),
            metadata: {
              display_name: custom.fetch(:label),
              gui_selectable: true,
              gui_platforms: %i[darwin windows linux],
              launcher_adapter: :custom,
              launch_command: custom.fetch(:command),
              launch_directory: custom[:directory],
              additional_arguments: deep_copy(custom.fetch(:arguments))
            }.compact
          )
          @user_frontend_ids << frontend_id
        end

        @definitions.clear
        nil
      end
      private_class_method :replace_user_configuration_unlocked!

      # Captures immutable built-in defaults after all built-ins are registered.
      # @return [void]
      def self.seal_built_in_catalog!
        registry_synchronize do
          @built_in_registry = BUILT_IN_FRONTEND_IDS.each_with_object({}) do |frontend_id, result|
            result[frontend_id] = deep_copy(@registry.fetch(frontend_id))
          end
          @built_in_aliases = @aliases.select do |_alias_name, frontend_id|
            BUILT_IN_FRONTEND_IDS.include?(frontend_id)
          end
          Lich::Util.deep_freeze(@built_in_registry)
          Lich::Util.deep_freeze(@built_in_aliases)
          @user_frontend_ids = []
          nil
        end
      end

      # Returns the stable catalog identifier for a frontend or alias.
      # Unknown values are normalized but are not registered.
      #
      # @param frontend_name [String, Symbol]
      # @return [String]
      def self.canonical_name(frontend_name)
        registry_synchronize do
          key = frontend_name.to_s.downcase
          @aliases.fetch(key, key)
        end
      end

      # Checks if a frontend has a specific capability.
      # @param frontend_name [String] The name of the frontend to check
      # @param capability [Symbol] The capability to check for
      # @return [Boolean]
      def self.has_capability?(frontend_name, capability)
        return false if frontend_name.nil?

        registry_synchronize do
          entry = @registry[canonical_name(frontend_name)]
          entry ? entry[:capabilities].include?(capability.to_sym) : false
        end
      end

      # Retrieves a metadata value for a given frontend.
      # @param frontend_name [String] The name of the frontend
      # @param key [Symbol] The metadata key to retrieve
      # @return [Object, nil]
      def self.metadata_for(frontend_name, key)
        return nil if frontend_name.nil?

        definition_for(frontend_name).dig(:metadata, key)
      rescue ArgumentError
        nil
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
        registry_synchronize do
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
      end

      # Returns immutable catalog definitions, optionally restricted to those
      # intended for the graphical launcher.
      #
      # @param gui_selectable [Boolean, nil]
      # @return [Array<Hash>]
      def self.definitions(gui_selectable: nil)
        registry_synchronize do
          definitions = @registry.keys.map { |name| definition_for(name) }
          next definitions if gui_selectable.nil?

          definitions.select do |definition|
            definition.dig(:metadata, :gui_selectable) == gui_selectable
          end
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
        registry_synchronize { @registry.keys + @aliases.keys }
      end

      # Returns all frontends that have a specific capability.
      # @param capability [Symbol] The capability to filter by
      # @return [Array<String>]
      def self.frontends_with_capability(capability)
        registry_synchronize do
          canonical = @registry.select { |_name, data| data[:capabilities].include?(capability.to_sym) }.keys
          aliases = @aliases.filter_map do |alias_name, name|
            alias_name if canonical.include?(name)
          end
          canonical + aliases
        end
      end

      # --- Default Frontend Registrations ------------------------

      # Loads the trusted, shipped frontend catalog. Each file is a Ruby Hash in
      # the same vocabulary consumed by #register; mutable user settings remain
      # in FrontendSettings rather than becoming executable Ruby.
      #
      # The manifest is explicit because registry order is user-visible in the
      # GTK selector and retained by the legacy capability constants below.
      # @return [void]
      # @api private
      def self.load_built_in_catalog!
        definitions = BUILT_IN_DEFINITION_FILES.map do |expected_id, file_name|
          path = File.join(__dir__, 'frontend', "#{file_name}.rb")
          definition = module_eval(File.read(path, encoding: 'UTF-8'), path, 1)
          validate_built_in_definition!(definition, expected_id, path)
          {
            id: definition.fetch(:id),
            capabilities: definition.fetch(:capabilities, []).map(&:to_sym),
            metadata: deep_copy(definition.fetch(:metadata, {}))
          }
        end

        validate_built_in_aliases!(definitions)
        definitions.each do |definition|
          register(
            definition.fetch(:id),
            capabilities: definition.fetch(:capabilities, []),
            metadata: definition.fetch(:metadata, {})
          )
        end
        nil
      end
      private_class_method :load_built_in_catalog!

      # Validates the small authoring contract for a shipped definition before
      # any entry is registered, preventing a malformed file from exposing a
      # partial built-in catalog.
      # @api private
      def self.validate_built_in_definition!(definition, expected_id, path)
        raise TypeError, "frontend definition must return a Hash: #{path}" unless definition.is_a?(Hash)

        unknown_keys = definition.keys - %i[id capabilities metadata]
        raise ArgumentError, "unknown frontend definition keys in #{path}: #{unknown_keys.join(', ')}" unless unknown_keys.empty?

        actual_id = definition[:id].to_s.downcase
        raise ArgumentError, "frontend definition id must be #{expected_id}: #{path}" unless actual_id == expected_id
        capabilities = definition.fetch(:capabilities, [])
        raise TypeError, "frontend capabilities must be an Array: #{path}" unless capabilities.is_a?(Array)

        invalid_capabilities = capabilities.reject { |capability| capability.respond_to?(:to_sym) }
        unless invalid_capabilities.empty?
          raise TypeError, "frontend capabilities must be symbols or strings: #{path}"
        end

        unknown_capabilities = capabilities.map(&:to_sym) - CAPABILITY_VOCABULARY
        unless unknown_capabilities.empty?
          raise ArgumentError, "unknown frontend capabilities in #{path}: #{unknown_capabilities.join(', ')}"
        end

        raise TypeError, "frontend metadata must be a Hash: #{path}" unless definition.fetch(:metadata, {}).is_a?(Hash)

        definition
      end
      private_class_method :validate_built_in_definition!

      # Rejects ambiguous aliases before registration can overwrite one based on
      # file order. Canonical built-in identifiers are reserved as aliases too.
      # @api private
      def self.validate_built_in_aliases!(definitions)
        owners = BUILT_IN_FRONTEND_IDS.to_h { |frontend_id| [frontend_id, frontend_id] }
        definitions.each do |definition|
          frontend_id = definition.fetch(:id).to_s.downcase
          Array(definition.dig(:metadata, :aliases)).each do |alias_name|
            alias_id = alias_name.to_s.downcase
            raise ArgumentError, "frontend alias must not be empty: #{frontend_id}" if alias_id.empty?
            if owners.key?(alias_id)
              raise ArgumentError, "duplicate frontend identifier or alias: #{alias_id}"
            end

            owners[alias_id] = frontend_id
          end
        end
        nil
      end
      private_class_method :validate_built_in_aliases!

      load_built_in_catalog!

      seal_built_in_catalog!

      SAGA_LICH_LAUNCH_ENVIRONMENT = definition_for(:saga)
                                     .dig(:metadata, :launch_plans, :linux, :environment)

      # --- Client String -----------------------------------------
      # Default client string (Wrayth identity) sent during handshake
      CLIENT_STRING = "/FE:WRAYTH /VERSION:1.0.1.28 /P:WIN_UNKNOWN /XML"

      # --- Backward-Compatible Constants -------------------------
      # These frozen arrays preserve the built-in capability membership exposed
      # by older Lich versions. They intentionally remain stable when user-defined
      # frontends are loaded. Runtime callers that need current custom frontend
      # membership must use frontends_with_capability or supports_*? instead.
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

      # Set PID from a detachable frontend such as Profanity or Saga.
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
