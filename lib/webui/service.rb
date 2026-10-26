# frozen_string_literal: true

require_relative 'file_service'
require_relative 'browser_window'
require_relative 'modal_coordinator'
require_relative 'registry'
require_relative 'runtime'
require_relative 'server'
require_relative 'window_geometry_store'
require_relative 'monitor_geometry'

module Lich
  module WebUI
    # Composes the contract registry, runtime, file boundary, and loopback server.
    class Service
      ASSETS_DIR = File.expand_path('assets', __dir__).freeze

      attr_reader :registry, :runtime, :file_service, :server, :modals

      # Resolves an owner's viewer measurement, or local discovery before attachment.
      # Explicit viewers never fall back to another viewer or the server's desktop.
      # @return [Hash] rectangle with source/fallback, or an unavailable result
      def monitor_geometry(owner:, viewer: nil, target: :active, point: nil)
        snapshot = if viewer
                     registry.pages_for(owner).filter_map { |page| page.monitor_snapshot(viewer) }.first
                   else
                     MonitorGeometry.new.snapshot
                   end
        MonitorGeometry.select(snapshot, target: target, point: point)
      end

      # Builds an inactive host with shared page, file, modal and window ownership.
      # @param registry [Registry] pages served by this host
      # @param application_roots [Array<String>] allowed application asset roots
      # @param user_allowlist [Array<String>] additional permitted file roots
      # @param host [String] loopback bind address
      # @param port [Integer] listener port; zero requests an available port
      # @param logger [#call, nil] diagnostic sink accepting level and message
      # @param browser_open [#call, nil] window opener; nil uses BrowserLauncher
      # @param browser_terminate [#call] terminator accepting a signal and owned PID
      # @param geometry_store [WindowGeometryStore, nil] optional window persistence
      def initialize(registry: Registry.new, application_roots: [ASSETS_DIR], user_allowlist: [],
                     host: '127.0.0.1', port: 0, logger: nil, browser_open: nil, browser_terminate: Process.method(:kill), geometry_store: nil)
        @registry = registry
        @stopped = false
        @windows = {}.compare_by_identity
        @windows_mutex = Mutex.new
        @browser_open = browser_open
        @browser_terminate = browser_terminate
        @geometry_store = geometry_store
        @logger = logger || proc { |level, message| Lich.log("#{level}: #{message}") if Lich.respond_to?(:log) }
        @file_service = FileService.new(
          application_roots: application_roots, user_allowlist: user_allowlist, logger: @logger
        )
        @runtime = Runtime.new(
          registry: registry, file_service: file_service, logger: @logger,
          on_page_closed: method(:close_window), window_host: method(:window_host),
          viewers_changed: ->(owner) { @modals.viewers_changed(owner) }
        )
        @server = Server.new(
          assets_dir: ASSETS_DIR, pages_provider: -> { registry.descriptors },
          message_handler: ->(connection, message) { runtime.handle(connection, message) },
          disconnect_handler: ->(connection) { runtime.disconnect(connection) },
          file_service: file_service, host: host, port: port, logger: @logger
        )
        @modals = ModalCoordinator.new(
          registry: registry, runtime: runtime, viewers_present: ->(owner) { runtime.viewers_present?(owner) },
          pages_changed: -> { server.broadcast(type: 'pages', pages: registry.descriptors) }, logger: @logger
        )
      end

      # Starts the loopback server; a stopped service requires a new instance.
      # @return [Service] self
      # @raise [Error] once shutdown has begun
      def start
        raise Error, 'stopped services cannot be restarted; create a fresh service' if @stopped

        server.start
        self
      end

      # Stops the listener and callbacks while attempting every owned window.
      # Failed closes remain tracked; repeated calls retry them without spawning.
      # @return [Service] this stopped host
      def stop
        registry.stop
        pages = @windows_mutex.synchronize do
          @stopped = true
          @windows.keys.dup
        end
        begin
          modals.shutdown
        ensure
          pages.each { |page| close_window(page) }
          begin
            server.stop
          ensure
            runtime.shutdown
          end
        end
        self
      end

      # Reports whether this service has entered terminal shutdown.
      # @return [Boolean]
      def stopped? = @stopped

      # Failed terminations and in-flight spawns remain owned for later cleanup.
      # @return [Boolean] whether this host still owns any active or closing window
      def pending_windows?
        @windows_mutex.synchronize { !@windows.empty? }
      end

      # Issues a short-lived authentication URL targeting a page or the page selector.
      # @param page [Page, nil] registered target; nil opens the selector
      # @return [String] URL containing a single-use launch credential
      def launch_url(page: nil)
        target = page ? "/?page=#{registry.address_for(page)}" : '/'
        server.launch_url(to: target)
      end

      # Window ownership belongs to the host, for native and compatibility pages.
      # Reserve before spawning so repeated opens and concurrent shutdown agree.
      # @param page [Page, nil] registered page, or the service-owned page selector
      # @param geometry [Hash, nil] explicit bounds overriding stored or default bounds
      # @return [Boolean] opener result, or true for an already-owned window
      # @raise [Error] if the host is stopped or the page is unregistered
      def open(page, geometry: nil)
        # Explicit caller geometry and script configure handlers retain their
        # existing settings authority. Otherwise saved user geometry precedes
        # a page's default size (for example a setup form's first-run size).
        props = page&.last_render&.tree&.props
        geometry ||= @geometry_store&.read(page) if page && !page.lifecycle_bindings.key?(:configure)
        if geometry.nil? && props && props[:size]
          geometry = { width: props[:size][0], height: props[:size][1], position: props[:position] }
        end
        page.restore_window_geometry(geometry) if page && geometry
        url = launch_url(page: page)
        window = @windows_mutex.synchronize do
          raise Error, 'service is stopped' if @stopped
          registry.ensure_active!(page.owner) if page
          return true if @windows.key?(page)
          if page
            registry.address_for(page)
            runtime.watch_window(page)
          end

          @windows[page] = BrowserWindow.new(
            opener: @browser_open, terminate: @browser_terminate,
            on_close: -> { browser_closed(page) }
          )
        end
        window.present(page.last_render) if page&.last_render
        # Spawn and monitor setup must survive the requesting script's exit.
        result = HostThread.start { window.open(url, geometry: geometry) }.value
        close_window(page) if !result || window.closed?
        result
      rescue StandardError
        close_window(page) if window
        raise
      end

      # Saves geometry and releases ownership only after termination succeeds.
      # Startup and termination failures leave the window tracked for retry.
      # @param page [Page, nil] exact page identity, or the service-owned selector
      # @return [void]
      def close_window(page)
        save_geometry(page) if page
        window = @windows_mutex.synchronize { @windows[page] }
        return unless window

        return false unless window.close
        @windows_mutex.synchronize { @windows.delete(page) if @windows[page].equal?(window) }
      rescue StandardError => error
        @logger.call(:warning, "WebUI window termination failed: #{error.class}; retained for retry")
      end

      # Finds the native presentation controller through its owning page window.
      # @param page [Page] exact page identity, never a title or sibling modal
      # @return [BrowserWindow, nil] the page's owned desktop window
      def window_host(page)
        @windows_mutex.synchronize { @windows[page] }
      end

      # Releases an exited window and reports page closure when one was selected.
      # @param page [Page, nil] exact page identity, or the service-owned selector
      # @return [void]
      def browser_closed(page)
        save_geometry(page) if page
        window = @windows_mutex.synchronize { @windows.delete(page) }
        runtime.browser_closed(page) if window && page
      end

      # Renders and delivers a registered page to its current attachments.
      # @param page [Page] registered page to render and publish
      # @return [Integer] evaluated generation
      # @see Runtime#refresh
      def refresh(page)
        runtime.refresh(page)
      end

      # Repaints existing windows after the persisted preference changes.
      # Explicit page themes still win; unrendered pages pick up the preference
      # on their first render. This does not open windows or start the listener.
      # @return [void]
      def refresh_theme
        registry.pages.each { |page| refresh(page) if page.last_render }
      end

      # Refuses new owner work before canceling modals, routes and runtime resources.
      # Every cleanup stage runs even if an earlier stage raises.
      # @param owner [Object] terminating script or core owner identity
      # @return [Array<Page>] pages removed by the runtime
      def terminate_owner(owner)
        registry.terminate_owner(owner)
        begin
          modals.terminate_owner(owner)
        ensure
          begin
            file_service.revoke_owner(owner)
          ensure
            pages = runtime.terminate_owner(owner)
          end
        end
        pages
      end

      # Opens an asynchronous modal using this service's owner/viewer lifecycle.
      # @return [Future] modal completion
      # @see ModalCoordinator#open
      def modal(**options, &content)
        modals.open(**options, &content)
      end

      # Registers an owner-bound image alias within approved filesystem roots.
      # @see FileService#register
      def register_files(alias_name, directory, owner:, script_root: nil)
        file_service.register(alias_name, directory, owner: owner, script_root: script_root)
      end

      # Saves only host-managed geometry, matching the restoration rule in #open.
      # Pages with configure handlers own their geometry policy; saving their
      # ephemeral IDs creates files the host never reads. Persistence failures
      # are reported through the host logger.
      # @param page [Page] window whose final bounds may be persisted
      # @return [Object, nil] store result, or nil for script-managed geometry
      def save_geometry(page)
        return if page.lifecycle_bindings.key?(:configure)

        @geometry_store&.save(page)
      rescue StandardError => error
        @logger.call(:warning, "WebUI geometry save failed: #{error.class}")
      end
    end
  end
end
