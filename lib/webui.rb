# frozen_string_literal: true

require_relative 'webui/contract'
require_relative 'webui/adapter'
require_relative 'webui/browser_launcher'
require_relative 'webui/window_presentation'
require_relative 'webui/presented_window'
require_relative 'webui/dispatcher'
require_relative 'webui/errors'
require_relative 'webui/page'
require_relative 'webui/future'
require_relative 'webui/modal_coordinator'
require_relative 'webui/options'
require_relative 'webui/protocol'
require_relative 'webui/registry'
require_relative 'webui/runtime'
require_relative 'webui/server'
require_relative 'webui/service'
require_relative 'webui/sensitive_value'
require_relative 'webui/validator'
require_relative 'webui/viewer_store'
require_relative 'webui/websocket'

module Lich
  # Process-wide entry point to the browser-rendered UI.
  #
  # Holds the single {Registry} and {Service} for the process, created lazily
  # under {INITIALIZATION_MUTEX}, and offers the small surface that core code,
  # scripts, and the GTK shim call: register a page, start the loopback
  # server, open a browser on a page, refresh, raise a modal, and tear an
  # owner's pages down. Everything else lives in the classes under `webui/`.
  module WebUI
    # Guards lazy creation of the registry and service.
    INITIALIZATION_MUTEX = Mutex.new

    class << self
      # @!attribute [w] registry
      #   @return [Registry] replaces the process registry (test seam)
      # @!attribute [w] service
      #   @return [Service] replaces the process service (test seam)
      attr_writer :registry, :service

      # The process-wide page registry, created on first use.
      #
      # @return [Registry] the registry
      def registry
        INITIALIZATION_MUTEX.synchronize { @registry ||= Registry.new }
      end

      # Registers a new page and binds it to the process runtime.
      #
      # @param owner [Object] the script or core object that owns the page
      # @param id [String] page identifier matching the contract identifier syntax
      # @param title [String] window title
      # @param props [Hash{Symbol => Object}] root page properties
      # @param on [Hash{Symbol => #call}] page lifecycle callbacks keyed by event name
      # @yield the render block, evaluated against a {TreeBuilder} on every render
      # @return [Page] the registered, runtime-bound page
      # @raise [DuplicatePageError] when the owner already has a page with this id
      def page(owner:, id:, title:, props: {}, on: {}, &render_block)
        page = registry.register(Page.new(owner: owner, id: id, title: title, props: props, on: on, &render_block))
        page.bind_runtime(service.runtime)
      end

      # The process-wide service, created on first use with the port from {Options}.
      #
      # @return [Service] the service
      def service
        INITIALIZATION_MUTEX.synchronize do
          @registry ||= Registry.new
          @service ||= Service.new(registry: @registry, port: Options.port, logger: logger)
        end
      end

      # Where the service, runtime and dispatcher write: the Lich log. The
      # service used to be built without a logger, so everything they
      # recorded -- a handler that raised, a refused write, a timed-out
      # socket -- went to a proc that did nothing.
      #
      # @return [Proc] receives `(level, message)`
      def logger
        @logger ||= lambda do |level, message|
          Lich.log("#{level}: webui: #{message}") if defined?(Lich) && Lich.respond_to?(:log)
        end
      end

      # Starts the loopback server.
      #
      # @return [Service] the started service
      def start
        service.start
      end

      # Applies command-line WebUI settings; see Options.
      #
      # @param settings [Hash{Symbol => Object}] `port:` and `open_browser:`, as {Options.configure} takes them
      # @return [Module] {Options}
      def configure(**settings)
        Options.configure(**settings)
      end

      # Whether Lich should open a browser itself. When false the caller
      # surfaces the launch URL for the player to open where their display is.
      #
      # @return [Boolean] true unless `--webui-no-browser` (or equivalent) was given
      def open_browser?
        Options.open_browser?
      end

      # A single-use authenticated URL that opens the launcher, or one page.
      #
      # @param page [Page, nil] the page to land on, or nil for the launcher
      # @return [String] the URL
      # @raise [Error] when the server is not running
      def launch_url(page: nil)
        service.launch_url(page: page)
      end

      # Opens a browser window on +page+. With a +presentation+ (a callable
      # answering `always_on_top`/`opacity`/`borderless`), the OS window is
      # found and dressed accordingly and a PresentedWindow is returned,
      # whose `apply` re-reads the wishes; without one, true or false.
      #
      # @param page [Page, nil] the page to open, or nil for the launcher
      # @param presentation [#call, nil] answers the current window wishes as a Hash
      # @param geometry [Hash{Symbol => Object}, nil] `width:`, `height:` and optional `position:` for the window
      # @param title [String, nil] the page's window title, used to find the OS window
      # @return [PresentedWindow, Boolean] the window when a presentation was given, otherwise whether a
      #   browser was opened; nil when a presentation was given but no browser could be opened
      def open(page: nil, presentation: nil, geometry: nil, title: nil)
        url = launch_url(page: page)
        return BrowserLauncher.open(url, geometry: geometry) unless presentation

        PresentedWindow.open(url, presentation: presentation, geometry: geometry, title: title)
      end

      # Re-renders a page and delivers the result to every attached viewer.
      #
      # @param page [Page] the page to re-render
      # @return [void]
      def refresh(page)
        service.refresh(page)
      end

      # Cancels an owner's modals, revokes its file roots, and closes its pages.
      #
      # @param owner [Object] the script or core object being torn down
      # @return [void]
      def terminate_owner(owner)
        service.terminate_owner(owner)
      end

      # Raises a modal dialog; see {ModalCoordinator#open}.
      #
      # @param options [Hash{Symbol => Object}] the dialog options {ModalCoordinator#open} takes
      # @yield optional body content, evaluated against the dialog's {TreeBuilder}
      # @return [Future] resolves with the button pressed or the reason it closed
      def modal(**options, &content)
        service.modal(**options, &content)
      end

      # Stops the service and starts over with an empty registry.
      #
      # @return [void]
      def reset!
        service = INITIALIZATION_MUTEX.synchronize do
          current = @service
          @service = nil
          @registry = Registry.new
          current
        end
        service&.stop
      end
    end
  end
end
