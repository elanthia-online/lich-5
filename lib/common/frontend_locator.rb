# frozen_string_literal: true

require 'rexml/document'
require 'open3'

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
      def initialize(
        platform_key: Frontend.platform_key,
        environment: ENV,
        logger: nil,
        application_roots: ['/Applications', '~/Applications'],
        wine: (defined?(Wine) ? Wine : nil)
      )
        @platform_key = Frontend.validate_platform_key!(platform_key)
        @environment = environment
        @logger = logger || method(:default_log)
        @application_roots = application_roots
        @wine = wine
        @cache = {}
        # Always acquire the cache mutex before the application-index mutex
        # when both are needed. resolve(refresh: true) relies on this order.
        @cache_mutex = Mutex.new
        @application_index = nil
        @application_index_mutex = Mutex.new
      end

      def resolve(frontend_id, override: nil, refresh: false)
        definition = Frontend.definition_for(frontend_id)
        return resolve_override(definition, override) unless override.nil?

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
        candidates.concat(conventional_candidates(definition).map { |path| [path, :conventional] })
        candidates.concat(path_candidates(definition).map { |path| [path, :path] })

        candidates.each do |path, source|
          next unless executable?(path)

          resolved = resolution(definition, path, source)
          return resolved if resolved
        end
        nil
      end

      def resolve_override(definition, override)
        path = expand_path(override)
        unless executable?(path)
          raise ArgumentError, "frontend override is not executable: #{override}"
        end

        resolution(definition, path, :override) ||
          raise(ArgumentError, "frontend override is not executable: #{override}")
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
        bundles.product(executables).map do |bundle, executable|
          File.join(bundle, 'Contents', 'MacOS', executable)
        end
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

      def registry_candidates(definition)
        keys = definition.dig(:metadata, :discovery, :registry_keys) || []
        return [] if keys.empty?

        directories = if windows?
                        windows_registry_directories(keys)
                      elsif @wine
                        wine_registry_directories(keys)
                      else
                        []
                      end
        executables = definition.dig(:metadata, :discovery, :executables) || []
        directories.product(executables).map { |directory, executable| File.join(directory, executable) }
      end

      def windows_registry_directories(keys)
        require 'win32/registry'
        keys.filter_map do |key|
          Win32::Registry::HKEY_LOCAL_MACHINE.open(key, Win32::Registry::KEY_READ) do |registry|
            registry['Directory']
          end
        rescue Win32::Registry::Error
          nil
        rescue SystemCallError => e
          log_discovery_error(key, e)
          nil
        end
      rescue LoadError => e
        log_discovery_error('Windows registry', e)
        []
      end

      def wine_registry_directories(keys)
        keys.filter_map do |key|
          value = @wine.registry_gets("HKEY_LOCAL_MACHINE\\#{key}\\Directory")
          wine_path(value) if value
        rescue SystemCallError => e
          log_discovery_error(key, e)
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

      def executable?(path)
        !path.to_s.empty? && File.file?(path) && File.executable?(path)
      rescue SystemCallError => e
        log_discovery_error(path, e)
        false
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
