# frozen_string_literal: true

require_relative 'file_service'
require_relative 'modal_coordinator'
require_relative 'registry'
require_relative 'runtime'
require_relative 'server'

module Lich
  module WebUI
    # Composes the contract registry, runtime, file boundary, and loopback server.
    #
    # One Service is the whole WebUI for a process: it wires the parts
    # together at construction and forwards the handful of operations
    # {Lich::WebUI} exposes to whichever part owns them.
    class Service
      # Directory the built-in client assets are served from.
      ASSETS_DIR = File.expand_path('assets', __dir__).freeze

      # @!attribute [r] registry
      #   @return [Registry] the page registry
      # @!attribute [r] runtime
      #   @return [Runtime] the render and event runtime
      # @!attribute [r] file_service
      #   @return [FileService] the owner-attributed file roots
      # @!attribute [r] server
      #   @return [Server] the loopback HTTP and WebSocket server
      # @!attribute [r] modals
      #   @return [ModalCoordinator] the modal dialog coordinator
      attr_reader :registry, :runtime, :file_service, :server, :modals

      # Builds every part and wires them together; nothing listens until {#start}.
      #
      # @param registry [Registry] the page registry to serve
      # @param application_roots [Array<String>] directories files may always be served from
      # @param user_allowlist [Array<String>] extra directories the player permits
      # @param host [String] the address to bind; loopback by design
      # @param port [Integer] the port to bind; 0 asks the OS for a free one
      # @param logger [#call, nil] receives `(level, message)`; silent when nil
      # @return [Service] the service
      def initialize(registry: Registry.new, application_roots: [ASSETS_DIR], user_allowlist: [],
                     host: '127.0.0.1', port: 0, logger: nil)
        @registry = registry
        @logger = logger || proc { |_level, _message| }
        @file_service = FileService.new(
          application_roots: application_roots, user_allowlist: user_allowlist, logger: @logger
        )
        @runtime = Runtime.new(registry: registry, file_service: file_service, logger: @logger)
        @server = Server.new(
          assets_dir: ASSETS_DIR, pages_provider: -> { registry.descriptors },
          message_handler: ->(connection, message) { runtime.handle(connection, message) },
          disconnect_handler: ->(connection) { runtime.disconnect(connection) },
          file_service: file_service, host: host, port: port, logger: @logger
        )
        @modals = ModalCoordinator.new(
          registry: registry, runtime: runtime, viewers_present: -> { server.connection_count.positive? },
          pages_changed: -> { server.broadcast(type: 'pages', pages: registry.descriptors) }, logger: @logger
        )
      end

      # Starts the server listening.
      #
      # @return [Service] self
      def start
        server.start
        self
      end

      # Stops the server and shuts the runtime's callback threads down.
      #
      # @return [Service] self
      def stop
        server.stop
        runtime.shutdown
        self
      end

      # A single-use authenticated URL for the launcher or one page.
      #
      # @param page [Page, nil] the page to land on, or nil for the launcher
      # @param lifetime [Integer, nil] seconds the URL stays valid; nil for the server's default
      # @return [String] the URL
      # @raise [Error] when the server is not running or the page is not registered
      def launch_url(page: nil, lifetime: nil)
        target = page ? "/?page=#{registry.address_for(page)}" : '/'
        lifetime ? server.launch_url(to: target, lifetime: lifetime) : server.launch_url(to: target)
      end

      # Re-renders a page for every attached viewer.
      #
      # @param page [Page] the page to re-render
      # @return [void]
      def refresh(page)
        runtime.refresh(page)
      end

      # Cancels an owner's modals, revokes its file roots, and closes its pages.
      #
      # @param owner [Object] the script or core object being torn down
      # @return [void]
      def terminate_owner(owner)
        modals.terminate_owner(owner)
        file_service.revoke_owner(owner)
        runtime.terminate_owner(owner)
      end

      # Raises a modal dialog; see {ModalCoordinator#open}.
      #
      # @param options [Hash{Symbol => Object}] the dialog options {ModalCoordinator#open} takes
      # @yield optional body content, evaluated against the dialog's {TreeBuilder}
      # @return [Future] resolves with the button pressed or the reason it closed
      def modal(**options, &content)
        modals.open(**options, &content)
      end

      # Registers a directory an owner may serve image files from; see {FileService#register}.
      #
      # @param alias_name [String, Symbol] the URL alias
      # @param directory [String] the directory to serve
      # @param owner [Object] the registering owner
      # @param script_root [String, nil] the owner's own directory, permitted in addition to the allowlists
      # @return [String] the URL prefix files under the alias are served at
      def register_files(alias_name, directory, owner:, script_root: nil)
        file_service.register(alias_name, directory, owner: owner, script_root: script_root)
      end
    end
  end
end
