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
  module WebUI
    INITIALIZATION_MUTEX = Mutex.new

    class << self
      attr_writer :registry, :service

      def registry
        INITIALIZATION_MUTEX.synchronize { @registry ||= Registry.new }
      end

      def page(owner:, id:, title:, props: {}, on: {}, &render_block)
        page = registry.register(Page.new(owner: owner, id: id, title: title, props: props, on: on, &render_block))
        page.bind_runtime(service.runtime)
      end

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

      def start
        service.start
      end

      # Applies command-line WebUI settings; see Options.
      def configure(**settings)
        Options.configure(**settings)
      end

      # Whether Lich should open a browser itself. When false the caller
      # surfaces the launch URL for the player to open where their display is.
      def open_browser?
        Options.open_browser?
      end

      def launch_url(page: nil)
        service.launch_url(page: page)
      end

      # Opens a browser window on +page+. With a +presentation+ (a callable
      # answering `always_on_top`/`opacity`/`borderless`), the OS window is
      # found and dressed accordingly and a PresentedWindow is returned,
      # whose `apply` re-reads the wishes; without one, true or false.
      def open(page: nil, presentation: nil, geometry: nil, title: nil)
        url = launch_url(page: page)
        return BrowserLauncher.open(url, geometry: geometry) unless presentation

        PresentedWindow.open(url, presentation: presentation, geometry: geometry, title: title)
      end

      def refresh(page)
        service.refresh(page)
      end

      def terminate_owner(owner)
        service.terminate_owner(owner)
      end

      def modal(**options, &content)
        service.modal(**options, &content)
      end

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
