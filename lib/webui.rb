# frozen_string_literal: true

require_relative 'webui/contract'
require_relative 'webui/adapter'
require_relative 'webui/browser_launcher'
require_relative 'webui/dispatcher'
require_relative 'webui/errors'
require_relative 'webui/page'
require_relative 'webui/future'
require_relative 'webui/image_size'
require_relative 'webui/settings_form'
require_relative 'webui/list_settings_form'
require_relative 'webui/modal_coordinator'
require_relative 'webui/protocol'
require_relative 'webui/registry'
require_relative 'webui/runtime'
require_relative 'webui/server'
require_relative 'webui/service'
require_relative 'webui/sensitive_value'
require_relative 'webui/validator'
require_relative 'webui/viewer_store'
require_relative 'webui/websocket'
require_relative 'common/script_death'

module Lich
  module WebUI
    INITIALIZATION_MUTEX = Mutex.new

    class << self
      attr_writer :registry, :service

      # Returns the current page registry without starting a listener.
      # @return [Registry] lazily initialized registry
      def registry
        INITIALIZATION_MUTEX.synchronize { @registry ||= Registry.new }
      end

      # Registers a page with the active host. Does not render or open it.
      # Resolving the host first ensures pages created after shutdown belong
      # to the replacement registry and runtime.
      #
      # @param owner [Object] lifetime identity for cleanup, not a browser value
      # @param id [String] contract identifier unique within the owner
      # @param title [String] window title
      # @param props [Hash] page component properties
      # @param on [Hash{Symbol => Proc}] lifecycle callbacks
      # @yieldparam builder [TreeBuilder] context for declaring the component tree
      # @return [Page] registered page bound to the host runtime
      # @raise [DuplicatePageError] if the owner already registered this id
      # @example Register and display a native page
      #   page = Lich::WebUI.page(owner: self, id: 'status', title: 'Status') do
      #     text(key: 'message', content: 'Ready')
      #   end
      #   Lich::WebUI.refresh(page)
      #   Lich::WebUI.start
      #   Lich::WebUI.open(page: page)
      def page(owner:, id:, title:, props: {}, on: {}, &render_block)
        host = service
        page = host.registry.register(Page.new(owner: owner, id: id, title: title, props: props, on: on, &render_block))
        page.bind_runtime(host.runtime)
      end

      # Returns the shared host, replacing a stopped host and its registry.
      # This constructs the service but does not start its listener.
      # @return [Service] usable host for new pages
      def service
        INITIALIZATION_MUTEX.synchronize do
          if @service&.stopped?
            (@retired_services ||= []) << @service if @service.pending_windows?
            @service = nil
            @registry = Registry.new
          end
          @registry ||= Registry.new
          @service ||= Service.new(registry: @registry, geometry_store: window_geometry_store,
                                   application_roots: application_asset_roots)
        end
      end

      # Host configuration approves data assets, independently of any script's
      # requested image path. Legacy scripts may still use LICH_DIR/data even
      # when --data-dir relocates DATA_DIR. Missing optional roots are not created.
      # FileService retains canonical containment and owner-scoped image routes.
      def application_asset_roots
        candidates = [Service::ASSETS_DIR]
        candidates << DATA_DIR if defined?(DATA_DIR)
        candidates << File.join(LICH_DIR, 'data') if defined?(LICH_DIR)
        candidates.filter_map do |path|
          File.realpath(path) if File.directory?(path)
        rescue SystemCallError
          nil
        end.uniq
      end

      # Builds geometry persistence scoped to the current game and character.
      # @return [WindowGeometryStore, nil] store, or nil without DATA_DIR
      def window_geometry_store
        return unless defined?(DATA_DIR)

        WindowGeometryStore.new(directory: File.join(DATA_DIR, 'webui-window-geometry'), context: proc {
          [defined?(XMLData) ? XMLData.game : nil, defined?(Char) ? Char.name : nil]
        })
      end

      # Hosting is core-owned: compatibility consumers obtain an opaque port
      # without managing servers, transport, page registries or browser windows.
      # Opening follows the first valid render or an explicit adapter presentation.
      # The service reuses live owned windows and can reopen a retained page.
      #
      # @param owner [Object] lifetime identity for adapter pages
      # @param viewer [String, nil] attachment id for viewer-local operations
      # @return [Adapter] adapter with core publication and window callbacks
      def adapter(owner:, viewer: nil)
        host = service
        Adapter.new(owner: owner, service: host, viewer: viewer, on_publish: proc do |page|
          host.start
          host.server.broadcast(type: 'pages', pages: host.registry.descriptors)
          host.open(page)
        end)
      end

      # Captures an owner's asynchronous callback queue on the current host.
      # Calling the returned proc with a block submits ordered, non-coalesced work;
      # it never waits for that block or starts a browser. Retaining the host here
      # prevents a stale queue from creating a replacement service after shutdown.
      # @param owner [Object] lifecycle identity shared with pages and callbacks
      # @return [Proc] block-accepting handle returning :queued on admission
      # @raise [Error] on submission after shutdown, owner termination or overflow
      def callback_queue(owner:)
        host = service
        proc { |&work| host.runtime.dispatch(owner: owner, &work) }
      end

      # Captures bounded schedule/cancel operations on the current host and owner.
      # Callbacks run on the same dispatcher as UI events; truthy results repeat.
      # @param owner [Object] callback lifecycle identity
      # @return [Scheduler::Handle] retained capability; never recreates a stopped host
      def callback_scheduler(owner:)
        service.runtime.scheduler.for_owner(owner)
      end

      # Starts the shared loopback listener; repeated calls reuse it.
      # @return [Service] running host
      def start
        service.start
      end

      # Issues a single-use launch URL for a running host. Do not log the URL.
      # @param page [Page, nil] registered page, or the page selector
      # @return [String] loopback URL containing a short-lived authentication token
      # @raise [Error] if the host is stopped or the page is unregistered
      def launch_url(page: nil)
        service.launch_url(page: page)
      end

      # Opens a browser app window after the caller renders and starts the host.
      # Pages and the page selector have host-owned windows; repeated opens reuse them.
      #
      # @param page [Page, nil] registered page, or the page selector
      # @param geometry [Hash, nil] width, height and optional position; when nil,
      #   page windows use persisted geometry or their declared size
      # @return [Boolean] whether opening succeeded or the page was already open
      def open(page: nil, geometry: nil)
        service.open(page, geometry: geometry)
      end

      # Runs the page render block and delivers to its connected viewers.
      # @param page [Page] page to render
      # @return [Integer] generated revision, which may be superseded concurrently
      def refresh(page)
        service.refresh(page)
      end

      # Native consumers close their own page through the core host. Delivery,
      # viewer disposal and address removal remain runtime responsibilities.
      #
      # @param page [Page] page to unregister and close
      # @return [Page, nil] closed page, or nil if already absent
      def close(page)
        service.runtime.close_page(page)
      end

      # Cancels modal work, revokes file routes and closes pages for one owner.
      # @param owner [Object] identity used during registration
      # @return [Array<Page>] pages removed from the registry
      def terminate_owner(owner)
        service.terminate_owner(owner)
      end

      # Requests a modal and returns immediately. Await its future only outside
      # WebUI event callbacks; callbacks must not block the owner dispatcher.
      #
      # @param options [Hash] keywords accepted by ModalCoordinator#open, including
      #   owner, id, title, buttons and the required no_viewer policy
      # @param content [Proc, nil] optional dialog content builder
      # @return [Future] completion carrying the chosen button or cancellation reason
      # @see ModalCoordinator#open
      def modal(**options, &content)
        service.modal(**options, &content)
      end

      # Stops the current host and replaces the registry, discarding all pages.
      # Intended for full-host teardown, not closing an individual script's UI.
      # Hosts with pending window cleanup remain retained for a subsequent retry;
      # calling this method never constructs a replacement service.
      # @return [Service, nil] stopped service, or nil if none existed
      def reset!
        current = nil
        services = INITIALIZATION_MUTEX.synchronize do
          current = @service
          @service = nil
          @registry = Registry.new
          @retired_services ||= []
          @retired_services << current if current && !@retired_services.include?(current)
          @retired_services.dup
        end
        services.each do |host|
          begin
            host.stop
          rescue StandardError => error
            Lich.log("warning: WebUI shutdown failed: #{error.class}") if Lich.respond_to?(:log)
          ensure
            INITIALIZATION_MUTEX.synchronize do
              @retired_services.delete(host) unless host.pending_windows?
            end
          end
        end
        current
      end
    end

    # This applies to native script pages as well as imperative consumers.
    # Do not initialize a host merely because a non-UI script has ended.
    Common::ScriptDeath.on_death do |owner|
      current = INITIALIZATION_MUTEX.synchronize { @service }
      current&.terminate_owner(owner) unless current&.stopped?
    end
  end
end
