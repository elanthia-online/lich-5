# frozen_string_literal: true

require_relative 'file_service'
require_relative 'modal_coordinator'
require_relative 'registry'
require_relative 'runtime'
require_relative 'server'

module Lich
  module WebUI
    # Composes the contract registry, runtime, file boundary, and loopback server.
    class Service
      ASSETS_DIR = File.expand_path('assets', __dir__).freeze

      attr_reader :registry, :runtime, :file_service, :server, :modals

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

      def start
        server.start
        self
      end

      def stop
        server.stop
        runtime.shutdown
        self
      end

      def launch_url(page: nil)
        target = page ? "/?page=#{registry.address_for(page)}" : '/'
        server.launch_url(to: target)
      end

      def refresh(page)
        runtime.refresh(page)
      end

      def terminate_owner(owner)
        modals.terminate_owner(owner)
        file_service.revoke_owner(owner)
        runtime.terminate_owner(owner)
      end

      def modal(**options, &content)
        modals.open(**options, &content)
      end

      def register_files(alias_name, directory, owner:, script_root: nil)
        file_service.register(alias_name, directory, owner: owner, script_root: script_root)
      end
    end
  end
end
