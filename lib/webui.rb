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
    # Seconds each before_owner_terminate hook gets before the dying script's
    # pages are retired without it. Hooks close already-known resources, which
    # takes milliseconds; the bound only limits a join that returns as soon as
    # the hook ends, so it matches Service::OWNER_STOP_TIMEOUT.
    BEFORE_TERMINATE_TIMEOUT = 5

    class << self
      attr_writer :registry, :service

      # Records the process presentation policy. Core startup calls this once it
      # has resolved its launch options (--no-gui and the legacy --no-gtk alias
      # resolve false), before script bindings or any window opens. Compatibility
      # layers only read the policy; they never write it.
      # @param enabled [Boolean, nil] resolved policy; nil restores the
      #   unconfigured state (test fixtures)
      # @return [Boolean, nil] recorded policy
      # @raise [ArgumentError] for any other value
      def configure_presentation(enabled:)
        raise ArgumentError, 'presentation policy must be true, false or nil' unless [true, false, nil].include?(enabled)

        INITIALIZATION_MUTEX.synchronize { @presentation_enabled = enabled }
      end

      # Reads the core presentation policy without side effects: it never starts
      # the service, discovers or opens a browser, or loads compatibility code.
      # The unconfigured state reads false, so nothing presents before startup
      # resolves the policy. An enabled policy does not prove a host exists.
      # @return [Boolean]
      def presentation_enabled?
        INITIALIZATION_MUTEX.synchronize { @presentation_enabled == true }
      end

      # Reports whether startup explicitly disabled presentation (--no-gui or
      # --no-gtk). Unlike {.presentation_enabled?}, the unconfigured state is not
      # a decision, so it reads false here. Same side-effect-free read.
      # @return [Boolean]
      def presentation_disabled?
        INITIALIZATION_MUTEX.synchronize { @presentation_enabled == false }
      end

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
          if presentation_enabled?
            host.start
            host.server.broadcast(type: 'pages', pages: host.registry.descriptors)
            host.open(page)
          else
            # Refused without spawning. Like a failed open, deliver the page's
            # close lifecycle so its owner is not left waiting on a window.
            host.runtime.browser_closed(page)
            false
          end
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
      # @return [Boolean] whether opening succeeded or the page was already open;
      #   false without spawning when the core presentation policy is not enabled
      # @raise [Error] when presentation is enabled and the host is not running,
      #   the page is unregistered, or its owner has terminated
      def open(page: nil, geometry: nil)
        return false unless presentation_enabled?

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

      # Registers a hook that runs when a script dies, before the core retires
      # that script's pages, so a later layer can close resources of its own
      # (for example compatibility windows and their destroy handlers) while
      # the owner is still admitted. ScriptDeath runs handlers in registration
      # order with no priority, so this is the only way to run ahead of the
      # core handler. Hooks run one at a time on a host thread (not the script's
      # cleanup thread), each contained and bounded by BEFORE_TERMINATE_TIMEOUT:
      # a raising, exiting or late hook is logged and never prevents or delays
      # the owner's retirement beyond that bound. A hook registered without an
      # owner runs for every script death, which costs every death a host thread
      # and a wait on its cleanup thread; a hook registered for one owner runs
      # only for that owner's death, once, and other deaths pay nothing.
      #
      # The bound limits the wait, not the hook: a hook still running when it
      # expires is abandoned on its host thread, not stopped, and keeps running
      # while the owner's pages are retired. A hook that can run long (for
      # example closing a session with slow destroy handlers) must therefore
      # tolerate its owner's pages being retired mid-run, and must not assume
      # its work is finished or cancelled when the owner's death completes.
      # An owner-bound registration is refused once the owner's hooks have
      # started: the runner marks the owner under the same lock that guards
      # registration when it snapshots the hooks, so a hook either joins that
      # snapshot or is refused, never silently dropped. The owner's workers can
      # still be unwinding then (for example a killed worker's ensure), so a
      # layer that registers a hook lazily must treat the refusal as "this owner
      # is dying" and create no resource that needs the hook (1836:RC22). A
      # check before registering is not enough: the owner can start between the
      # check and the call.
      # @param owner [Object, nil] script the hook is for, or nil for every script
      # @yieldparam owner [Object] the dying script
      # @return [Proc] the registered hook
      # @raise [ArgumentError] without a block
      # @raise [Error] for an owner whose pre-terminate hooks have started or run
      def before_owner_terminate(owner: nil, &hook)
        raise ArgumentError, 'hook block is required' unless hook

        INITIALIZATION_MUTEX.synchronize do
          if owner
            if @terminate_hooks_state&.key?(owner)
              raise Error.new('owner pre-terminate hooks have started; hook not registered', owner: Diagnostics.owner_label(owner))
            end

            ((@owner_terminate_hooks ||= {}.compare_by_identity)[owner] ||= []) << hook
          else
            (@before_terminate_hooks ||= []) << hook
          end
        end
        hook
      end

      # Whether the pre-terminate hooks for this owner have finished running (or
      # the runner was left by an error). False before the owner's death, while
      # its hooks are still running and for any object that never died; use the
      # refusal from before_owner_terminate, not this, to guard a registration.
      # The record holds no strong reference to the owner.
      # @param owner [Object] script to check, by identity
      # @return [Boolean]
      def owner_terminate_hooks_done?(owner)
        INITIALIZATION_MUTEX.synchronize { @terminate_hooks_state&.[](owner) == :done }
      end

      # Runs the registered pre-terminate hooks for one dying script. The owner
      # is marked started under INITIALIZATION_MUTEX as its hooks are
      # snapshotted, which closes owner-bound registration for it, and marked
      # done once they have run.
      # @param owner [Object] the dying script
      # @return [void]
      # @api private
      def run_before_terminate_hooks(owner)
        hooks = INITIALIZATION_MUTEX.synchronize do
          state = (@terminate_hooks_state ||= WeakIdentityMap.new)
          state[owner] = :started unless state.key?(owner)
          Array(@before_terminate_hooks) + Array(@owner_terminate_hooks&.delete(owner))
        end
        hooks.each do |hook|
          worker = HostThread.start do
            hook.call(owner)
          rescue SystemExit, *Dispatcher::CONTAINED_EXCEPTIONS => error
            Lich.log("error: WebUI pre-terminate hook failed owner=#{Diagnostics.owner_label(owner)} error=#{error.class}") if Lich.respond_to?(:log)
          end
          next unless worker.join(BEFORE_TERMINATE_TIMEOUT).nil?

          if Lich.respond_to?(:log)
            Lich.log("warning: WebUI pre-terminate hook did not finish within #{BEFORE_TERMINATE_TIMEOUT}s " \
                     "owner=#{Diagnostics.owner_label(owner)}; abandoning it (not stopped) and retiring its pages")
          end
        end
      ensure
        INITIALIZATION_MUTEX.synchronize { (@terminate_hooks_state ||= WeakIdentityMap.new)[owner] = :done }
      end
      private :run_before_terminate_hooks

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
    # Later layers' before_owner_terminate hooks run first, so their resources
    # close while the owner is still admitted (1836:RC20).
    Common::ScriptDeath.on_death do |owner|
      run_before_terminate_hooks(owner)
      current = INITIALIZATION_MUTEX.synchronize { @service }
      current&.terminate_owner(owner) unless current&.stopped?
    end
  end
end
