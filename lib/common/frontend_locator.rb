# frozen_string_literal: true

require 'rexml/document'
require 'open3'
require 'shellwords'

module Lich
  module Common
    # Resolves installed frontend executables from the shared Frontend catalog.
    # It has no GTK dependency and is safe for GUI, CLI, and --no-gtk startup.
    class FrontendLocator
      Resolution = Struct.new(:frontend_id, :executable_path, :source, keyword_init: true) do
        def initialize(**attributes)
          super
          freeze
        end
      end

      class << self
        # Resolves a known frontend to a launchable executable.
        #
        # @param frontend_id [String, Symbol] registered frontend identifier
        # @param override [String, nil] explicit executable path for this call
        # @param refresh [Boolean] bypass the process-local discovery cache
        # @return [Resolution, nil] nil when the frontend is not installed
        # @raise [ArgumentError] for blank/unknown identifiers or invalid overrides
        def resolve(frontend_id, override: nil, refresh: false)
          default.resolve(frontend_id, override: override, refresh: refresh)
        end

        # Returns resolutions for installed catalog entries.
        #
        # @param gui_selectable [Boolean, nil] catalog presentation filter
        # @param refresh [Boolean] clear cached results before discovery
        # @return [Array<Resolution>]
        def available(gui_selectable: nil, refresh: false)
          default.available(gui_selectable: gui_selectable, refresh: refresh)
        end

        # Returns whether a frontend is both installed and supported by the
        # graphical launcher on this platform.
        #
        # @param frontend_id [String, Symbol] registered frontend identifier
        # @param refresh [Boolean] bypass the process-local discovery cache
        # @return [Boolean]
        def selectable?(frontend_id, refresh: false)
          default.selectable?(frontend_id, refresh: refresh)
        end

        # Returns whether a frontend has a native launcher on this platform and
        # its required executable is installed. Unlike selectable?, this does
        # not apply graphical presentation metadata.
        #
        # @param frontend_id [String, Symbol] registered frontend identifier
        # @param refresh [Boolean] bypass the process-local discovery cache
        # @return [Boolean]
        def launchable?(frontend_id, refresh: false)
          default.launchable?(frontend_id, refresh: refresh)
        end

        # Clears process-local discovery results. No settings are persisted.
        # @return [void]
        def refresh!
          default.refresh!
        end

        # Backward-compatible directory result used by Lich.seek.
        # @param frontend_id [String, Symbol]
        # @return [String, nil]
        def compatibility_location(frontend_id)
          resolution = resolve(frontend_id)
          resolution && File.dirname(resolution.executable_path)
        rescue ArgumentError
          nil
        end

        private

        def default
          @default ||= new
        end
      end

      # @param platform_key [Symbol] canonical host classification
      # @param environment [Hash] environment used for path expansion/PATH
      # @param logger [#call, nil] receives handled discovery warning strings
      # @param application_roots [Array<String>] macOS application directories
      # @param wine [Module, nil] injected Wine integration provider
      # @param spotlight [#call, nil] macOS bundle-id search returning bundle
      #   paths; nil uses mdfind
      def initialize(
        platform_key: Frontend.platform_key,
        environment: ENV,
        logger: nil,
        application_roots: ['/Applications', '~/Applications'],
        wine: (defined?(Wine) ? Wine : nil),
        spotlight: nil
      )
        @platform_key = Frontend.validate_platform_key!(platform_key)
        @environment = environment
        @logger = logger || method(:default_log)
        @application_roots = application_roots
        @wine = wine
        @spotlight = spotlight || method(:spotlight_search)
        @cache = {}
        # Always acquire the cache mutex before the application-index mutex
        # when both are needed. resolve(refresh: true) relies on this order.
        @cache_mutex = Mutex.new
        @application_index = nil
        @application_index_mutex = Mutex.new
      end

      # Resolves a known frontend to a launchable executable.
      #
      # @param frontend_id [String, Symbol] registered frontend identifier
      # @param override [String, nil] explicit executable path for this call
      # @param refresh [Boolean] bypass the process-local discovery cache
      # @return [Resolution, nil] nil when the frontend is not installed
      # @raise [ArgumentError] for blank or unknown identifiers and invalid overrides
      def resolve(frontend_id, override: nil, refresh: false)
        definition = Frontend.definition_for(frontend_id)
        return resolve_override(definition, override) unless override.nil?

        configured = definition.dig(:metadata, :configured_executable)
        if configured
          configured_resolution = resolve_configured(definition, configured)
          return configured_resolution if configured_resolution
        end

        @cache_mutex.synchronize do
          if refresh
            @cache.delete(definition[:id])
            @application_index_mutex.synchronize { @application_index = nil }
          end
          return @cache[definition[:id]] if @cache.key?(definition[:id])
        end

        discovered = discover(definition)
        @cache_mutex.synchronize { @cache[definition[:id]] = discovered }
      end

      def available(gui_selectable: nil, refresh: false)
        refresh! if refresh
        definitions = Frontend.definitions(gui_selectable: gui_selectable)
        definitions = definitions.select { |definition| gui_platform_supported?(definition) } if gui_selectable
        definitions.filter_map do |definition|
          resolve(definition[:id])
        end
      end

      def selectable?(frontend_id, refresh: false)
        definition = Frontend.definition_for(frontend_id)
        return false unless definition.dig(:metadata, :gui_selectable)
        return false unless gui_platform_supported?(definition)

        !resolve(definition[:id], refresh: refresh).nil?
      end

      def launchable?(frontend_id, refresh: false)
        definition = Frontend.definition_for(frontend_id)
        return false unless native_launcher_supported?(definition)
        return true if definition.dig(:metadata, :launcher_adapter) == :embedded

        !resolve(definition[:id], refresh: refresh).nil?
      end

      def refresh!
        @cache_mutex.synchronize { @cache.clear }
        @application_index_mutex.synchronize { @application_index = nil }
        nil
      end

      private

      def discover(definition)
        candidates = registry_candidates(definition).map { |path| [path, :registry] }
        candidates.concat(application_candidates(definition).map { |path| [path, :application] })
        candidates.concat(appimage_candidates(definition))
        candidates.concat(conventional_candidates(definition).map { |path| [path, :conventional] })
        candidates.concat(path_candidates(definition).map { |path| [path, :path] })

        candidates.each do |path, source|
          next unless executable?(path, definition)

          resolved = resolution(definition, path, source)
          return resolved if resolved
        end
        nil
      end

      # Resolves and validates an explicitly configured executable path.
      #
      # @param definition [Hash] immutable frontend definition
      # @param override [String] executable path
      # @param source [Symbol] resolution source marker
      # @return [Resolution] validated executable resolution
      # @raise [ArgumentError] when the path is not executable for the frontend
      # @api private
      def resolve_override(definition, override, source: :override)
        path = expand_path(override)
        unless executable?(path, definition)
          raise ArgumentError, "frontend override is not executable: #{override}"
        end

        resolution(definition, path, source) ||
          raise(ArgumentError, "frontend override is not executable: #{override}")
      end

      # Resolves a persisted executable override, logging invalid paths.
      #
      # @param definition [Hash] immutable frontend definition
      # @param configured [String] persisted executable path
      # @return [Resolution, nil] configured resolution when valid
      # @api private
      def resolve_configured(definition, configured)
        resolve_override(definition, configured, source: :configured)
      rescue ArgumentError => error
        log_discovery_error(configured, error)
        nil
      end

      def conventional_candidates(definition)
        paths = definition.dig(:metadata, :discovery, :paths, platform_key) || []
        paths.filter_map { |path| expand_path(path) }
      end

      # Finds catalog-defined executables inside installed macOS application
      # bundles. Bundle directory names are intentionally irrelevant: users may
      # retain versioned, renamed, or side-by-side copies of an application.
      def application_candidates(definition)
        return [] unless platform_key == :darwin

        executables = definition.dig(:metadata, :discovery, :executables) || []
        bundle_ids = definition.dig(:metadata, :discovery, :mac_bundle_ids) || []
        return [] if bundle_ids.empty?

        bundles = bundle_ids.flat_map { |bundle_id| application_index.fetch(bundle_id, []) }.uniq
        bundles = bundle_ids.flat_map { |bundle_id| spotlight_bundles(bundle_id) }.uniq if bundles.empty?
        bundles.product(executables).map do |bundle, executable|
          File.join(bundle, 'Contents', 'MacOS', executable)
        end
      end

      SPOTLIGHT_TIMEOUT = 2
      # Copies Spotlight also indexes that must not become the launch target:
      # a mounted dmg, the Trash, or a Gatekeeper-translocated read-only copy.
      SPOTLIGHT_EXCLUDED = %r{\A/Volumes/|/\.Trash/|/AppTranslocation/}
      private_constant :SPOTLIGHT_TIMEOUT, :SPOTLIGHT_EXCLUDED

      # Finds application bundles outside the scanned application roots via
      # Spotlight. Each hit is re-checked against its Info.plist bundle id.
      #
      # @param bundle_id [String] CFBundleIdentifier to search for
      # @return [Array<String>] matching bundle paths; empty when Spotlight
      #   is disabled, slow, or unavailable
      # @api private
      def spotlight_bundles(bundle_id)
        return [] unless bundle_id.match?(/\A[A-Za-z0-9.-]+\z/)

        Array(@spotlight.call(bundle_id)).filter_map do |path|
          path = path.to_s.strip
          next unless path.end_with?('.app') && absolute_path?(path)
          next if path.match?(SPOTLIGHT_EXCLUDED)

          path if mac_bundle_id(path) == bundle_id
        end
      rescue SystemCallError, IOError => e
        log_discovery_error("Spotlight #{bundle_id}", e)
        []
      end

      # Runs mdfind for a bundle id with a hard timeout; Spotlight can stall
      # while indexing and discovery runs while the GUI builds its list.
      def spotlight_search(bundle_id)
        query = "kMDItemCFBundleIdentifier == '#{bundle_id}'"
        Open3.popen3('/usr/bin/mdfind', query) do |stdin, stdout, stderr, wait|
          stdin.close
          stderr.close
          reader = Thread.new { stdout.read }
          unless wait.join(SPOTLIGHT_TIMEOUT)
            begin
              Process.kill('KILL', wait.pid)
            rescue SystemCallError
              nil
            end
            reader.kill
            return []
          end
          wait.value.success? ? reader.value.to_s.lines(chomp: true) : []
        end
      rescue SystemCallError
        []
      end

      # Finds a Linux AppImage. Releases ship only a versioned AppImage
      # (Saga-0.10.8-x86_64.AppImage) that the user places anywhere and that
      # electron-updater renames to the new version when it updates. Desktop
      # entries written by AppImage integrators (AppImageLauncher, Gear Lever)
      # point at custom locations; their directories are then searched by the
      # catalog name patterns so a renamed post-update file is still found.
      #
      # @param definition [Hash] immutable frontend definition
      # @return [Array<Array(String, Symbol)>] candidate paths and sources
      # @api private
      def appimage_candidates(definition)
        return [] unless platform_key == :linux

        appimage = definition.dig(:metadata, :discovery, :appimage)
        return [] unless appimage

        entries = desktop_entry_appimages(appimage[:startup_wm_class])
        directories = entries.map { |path| File.dirname(path) }
        directories.concat((appimage[:directories] || []).filter_map { |path| expand_path(path) })
        globbed = directories.uniq.flat_map do |directory|
          appimages_in(directory, appimage[:names] || [])
        end
        entries.map { |path| [path, :desktop_entry] } + globbed.uniq.map { |path| [path, :appimage] }
      end

      # @return [Array<String>] AppImage paths named by matching desktop entries
      def desktop_entry_appimages(startup_wm_class)
        return [] if startup_wm_class.to_s.empty?

        data_home = environment_value('XDG_DATA_HOME')
        data_home = File.join(environment_value('HOME').to_s, '.local', 'share') if data_home.to_s.empty?
        return [] unless absolute_path?(data_home)

        applications = File.join(data_home, 'applications')
        Dir.glob('*.desktop', base: applications).sort.filter_map do |name|
          file = File.join(applications, name)
          desktop_entry_appimage(file, startup_wm_class)
        end
      rescue SystemCallError => e
        log_discovery_error('desktop entries', e)
        []
      end

      def desktop_entry_appimage(file, startup_wm_class)
        fields = {}
        section = nil
        File.foreach(file, encoding: 'UTF-8') do |line|
          line = line.strip
          if line.start_with?('[')
            section = line
          elsif section == '[Desktop Entry]' && (match = line.match(/\A(StartupWMClass|Exec)\s*=\s*(.*)\z/))
            fields[match[1]] ||= match[2]
          end
        end
        return nil unless fields['StartupWMClass'] == startup_wm_class

        command = Shellwords.split(fields['Exec'].to_s).first.to_s
        command if command.start_with?('/') && File.extname(command).casecmp?('.AppImage')
      rescue SystemCallError, ArgumentError, EncodingError => e
        log_discovery_error(file, e)
        nil
      end

      # Globs catalog AppImage names (case-sensitive) in a directory, newest
      # release first: highest embedded version, then most recent mtime.
      def appimages_in(directory, names)
        paths = names.flat_map do |name|
          Dir.glob(name, base: directory).map { |file| File.join(directory, file) }
        end
        # Dir.glob returns dangling symlinks (e.g. a stable Saga.AppImage link
        # whose versioned target an update renamed); File.mtime would raise on
        # them and drop the whole directory. executable? requires a file anyway.
        paths = paths.uniq.select { |path| File.file?(path) }
        paths.sort_by { |path| [appimage_version(path), File.mtime(path)] }.reverse
      rescue SystemCallError => e
        log_discovery_error(directory, e)
        []
      end

      def appimage_version(path)
        Gem::Version.new(File.basename(path)[/\d+(?:\.\d+)+/] || '0')
      end

      def application_index
        @application_index_mutex.synchronize do
          @application_index ||= scan_application_bundles
        end
      end

      def scan_application_bundles
        index = @application_roots.each_with_object({}) do |root, result|
          Dir.glob(File.join(expand_path(root), '*.app')).each do |bundle|
            bundle_id = mac_bundle_id(bundle)
            (result[bundle_id] ||= []) << bundle if bundle_id
          end
        rescue SystemCallError => e
          log_discovery_error(root, e)
        end
        index.each_value(&:freeze)
        index.freeze
      end

      def path_candidates(definition)
        return [] if definition.dig(:metadata, :discovery, :path_lookup) == false

        path_entries = @environment.fetch('PATH', '').split(File::PATH_SEPARATOR)
                                   .reject(&:empty?)
                                   .select { |directory| absolute_path?(directory) }
        executables = definition.dig(:metadata, :discovery, :executables) || []
        path_entries.product(executables).map do |directory, executable|
          File.expand_path(executable, directory)
        end
      end

      # Registry hives a catalog registry entry may name.
      REGISTRY_HIVES = {
        local_machine: :HKEY_LOCAL_MACHINE,
        current_user: :HKEY_CURRENT_USER
      }.freeze
      # Win32 KEY_WOW64_64KEY access flag. win32/registry does not define it.
      # It selects the 64-bit view from a 32-bit Ruby; it is a no-op otherwise.
      KEY_WOW64_64KEY = 0x0100
      private_constant :REGISTRY_HIVES, :KEY_WOW64_64KEY

      def registry_candidates(definition)
        entries = registry_entries(definition)
        return [] if entries.empty?

        directories = if windows?
                        windows_registry_directories(entries)
                      elsif wine_managed?(definition)
                        wine_registry_directories(entries)
                      else
                        []
                      end
        executables = definition.dig(:metadata, :discovery, :executables) || []
        directories.product(executables).map { |directory, executable| File.join(directory, executable) }
      end

      # Normalizes catalog registry entries. A String entry is an
      # HKEY_LOCAL_MACHINE key whose 'Directory' value holds the install
      # directory; a Hash entry may name another hive, value, and view.
      #
      # @param definition [Hash] immutable frontend definition
      # @return [Array<Hash>] entries with :hive, :key, :value, and :view
      # @api private
      def registry_entries(definition)
        entries = definition.dig(:metadata, :discovery, :registry_keys) || []
        entries.map do |entry|
          if entry.is_a?(String)
            { hive: :local_machine, key: entry, value: 'Directory', view: nil }
          else
            {
              hive: entry.fetch(:hive, :local_machine),
              key: entry.fetch(:key),
              value: entry.fetch(:value, 'Directory'),
              view: entry[:view]
            }
          end
        end
      end

      def windows_registry_directories(entries)
        require 'win32/registry'
        entries.filter_map do |entry|
          hive = Win32::Registry.const_get(REGISTRY_HIVES.fetch(entry[:hive]))
          access = Win32::Registry::KEY_READ
          access |= KEY_WOW64_64KEY if entry[:view] == 64
          directory = hive.open(entry[:key], access) do |registry|
            registry[entry[:value]]
          end
          directory unless directory.to_s.strip.empty?
        rescue Win32::Registry::Error
          nil
        rescue SystemCallError => e
          log_discovery_error(entry[:key], e)
          nil
        end
      rescue LoadError => e
        log_discovery_error('Windows registry', e)
        []
      end

      # Wine registry discovery only serves frontends Lich launches through
      # Wine. Others (e.g. Saga) have native non-Windows builds, so a Windows
      # copy inside a Wine prefix must not become their launch target.
      def wine_registry_directories(entries)
        entries.filter_map do |entry|
          next unless entry[:hive] == :local_machine

          value = @wine.registry_gets("HKEY_LOCAL_MACHINE\\#{entry[:key]}\\#{entry[:value]}")
          wine_path(value) if value
        rescue SystemCallError => e
          log_discovery_error(entry[:key], e)
          nil
        end
      end

      def wine_path(path)
        path.to_s.tr('\\', '/').sub(/\AC:/i, "#{@wine.const_get(:PREFIX)}/drive_c")
      end

      def platform_key
        @platform_key
      end

      def gui_platform_supported?(definition)
        platforms = definition.dig(:metadata, :gui_platforms)
        platforms.nil? || platforms.include?(platform_key)
      end

      def native_launcher_supported?(definition)
        adapter = definition.dig(:metadata, :launcher_adapter)
        case adapter
        when :environment
          !definition.dig(:metadata, :launch_plans, platform_key).nil?
        when :avalon
          platform_key == :darwin
        when :simutronics
          windows? || !@wine.nil?
        when :embedded
          true
        else
          false
        end
      end

      def windows?
        platform_key == :windows
      end

      def expand_path(path)
        unresolved_variable = false
        value = path.to_s.gsub(/%([^%]+)%/) do
          environment_value(Regexp.last_match(1)) || begin
            unresolved_variable = true
            Regexp.last_match(0)
          end
        end
        return nil if unresolved_variable

        File.expand_path(value)
      end

      def absolute_path?(path)
        return true if path.match?(/\A[A-Za-z]:[\\\/]/)

        path.start_with?('/')
      end

      def environment_value(name)
        pair = @environment.find { |key, _value| key.casecmp?(name) }
        pair && pair.last
      end

      def mac_bundle_id(bundle)
        plist = File.join(bundle, 'Contents', 'Info.plist')
        document = REXML::Document.new(File.read(plist))
        key = document.elements.to_a('plist/dict/key').find do |element|
          element.text == 'CFBundleIdentifier'
        end
        key&.next_element&.text
      rescue REXML::ParseException
        bundle_id_from_plutil(plist)
      rescue SystemCallError
        nil
      end

      def bundle_id_from_plutil(plist)
        output, _error, status = Open3.capture3(
          '/usr/bin/plutil', '-extract', 'CFBundleIdentifier', 'raw', '--', plist
        )
        status.success? ? output.strip : nil
      rescue SystemCallError
        nil
      end

      def executable?(path, definition)
        return false if path.to_s.empty? || !File.file?(path)

        wine_managed_executable?(path, definition) || File.executable?(path)
      rescue SystemCallError => e
        log_discovery_error(path, e)
        false
      end

      def wine_managed_executable?(path, definition)
        platform_key == :linux &&
          wine_managed?(definition) &&
          File.extname(path).casecmp?('.exe')
      end

      def wine_managed?(definition)
        !@wine.nil? && definition.dig(:metadata, :launcher_adapter) == :simutronics
      end

      def resolution(definition, path, source)
        Resolution.new(
          frontend_id: definition[:id],
          executable_path: File.realpath(path),
          source: source
        )
      rescue SystemCallError => e
        log_discovery_error(path, e)
        nil
      end

      def log_discovery_error(subject, error)
        @logger.call("frontend discovery failed for #{subject}: #{error.message}")
      end

      def default_log(message)
        Lich.log("warning: #{message}") if Lich.respond_to?(:log)
      end
    end
  end
end
