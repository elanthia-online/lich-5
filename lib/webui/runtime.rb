# frozen_string_literal: true

require_relative 'dispatcher'
require_relative 'scheduler'
require_relative 'protocol'
require_relative 'submission'
require_relative 'viewer_store'
require_relative 'native_host'
require_relative 'window_presentation'
require_relative 'value_helpers'
require_relative 'runtime/render_coordinator'

module Lich
  module WebUI
    # Server-routed page attachment, viewer state, submission, and callback runtime.
    class Runtime
      attr_reader :scheduler

      LIFECYCLE_SNAPSHOT_KEY = :lich_webui_lifecycle_snapshot
      EventContext = Data.define(:viewer_id, :page, :component, :event, :payload, :submission, :render) do
        # The optional immutable admission render pins callback source identity.
        # @param viewer_id [String, nil] originating viewer identity
        # @param page [Page] event's owning page
        # @param component [Component, nil] admitted control or page root
        # @param event [Symbol] admitted event name
        # @param payload [Hash] validated event payload
        # @param submission [Submission, nil] disposable terminal snapshot
        # @param render [Page::Render, nil] immutable admission render
        # @return [EventContext] captured callback context
        def initialize(viewer_id:, page:, component:, event:, payload:, submission:, render: nil)
          super
        end
      end
      PRESENTATION_SUPPORT = {
        always_on_top: false, borderless: false, hidden: false, minimized: false, minimized_revision: false, opacity: true, scrollbars: true,
      }.freeze

      # Connects page delivery and callback dispatch to optional host services.
      # @param registry [Registry] server-owned page registry
      # @param dispatcher [Dispatcher, nil] callback queue; nil creates a dispatcher
      # @param viewers [ViewerStore] viewer-local state and resume index
      # @param validator [Validator] component and event validator
      # @param file_service [FileService, nil] image-route resolver
      # @param logger [#call, nil] diagnostic sink accepting level and message
      # @param on_page_closed [#call, nil] callback releasing a page's owned window
      # @param window_host [#call, nil] lookup from a Page to its BrowserWindow
      # @param viewers_changed [#call, nil] notification after an owner's viewer loss
      # @return [Runtime]
      def initialize(registry:, dispatcher: nil, viewers: ViewerStore.new,
                     validator: Validator.new, file_service: nil, logger: nil, on_page_closed: nil, window_host: nil, viewers_changed: nil)
        @registry = registry
        @on_page_closed = on_page_closed
        @window_host = window_host
        @viewers_changed = viewers_changed
        @window_close_mutex = Mutex.new
        @window_closes = ObjectSpace::WeakMap.new
        @viewers = viewers
        @validator = validator
        @file_service = file_service
        @logger = logger || proc { |_level, _message| }
        @dispatcher = dispatcher || Dispatcher.new(logger: @logger)
        @scheduler = Scheduler.new(dispatcher: @dispatcher, admission: @registry.method(:ensure_active!), logger: @logger)
        @connections = {}
        @connections_mutex = Mutex.new
        @render_coordinator = RenderCoordinator.new(on_error: lambda do |owner, error|
          log(:error, "WebUI refresh failed owner=#{owner_label(owner)} error=#{error.class}")
        end)
        @degradation_mutex = Mutex.new
        @degradations = {}.compare_by_identity
      end

      # Submits non-page work to the same ordered worker as this owner's UI events.
      # It is never coalesced. Owner termination cancels pending work, and the
      # existing dispatcher bounds apply to these submissions as one logical source.
      # @param owner [Object] lifecycle identity used by the caller's pages
      # @param work [Proc] work queued on the owner dispatcher
      # @return [Symbol] :queued when admitted, not the block's eventual result
      # @yield work to execute asynchronously; must not await this dispatcher
      # @raise [Error] if the host/owner has stopped or the queue is full
      # @raise [ArgumentError] if the owner or work block is missing
      def dispatch(owner:, &work)
        @registry.ensure_active!(owner)
        @dispatcher.enqueue(owner: owner, page_id: nil, viewer_id: nil, cid: nil,
                            event: :callback, coalescable: false, &work)
      end

      # Combines browser facilities with presentation available on the current OS.
      # Opacity support may be content-only; per-window metadata identifies native alpha.
      # @param _page [Page, nil] reserved for page-specific host selection
      # @return [Hash{Symbol => Boolean}] supported presentation properties
      def presentation_support(_page = nil)
        support = NativeHost.platform ? PRESENTATION_SUPPORT.merge(always_on_top: true, borderless: true, hidden: true, minimized: true, minimized_revision: true) : PRESENTATION_SUPPORT
        support.merge(WindowPresentation.support).freeze
      end

      # Snapshots recorded presentation limitations without exposing mutable internal records.
      # @param page [Page] exact owner-scoped page
      # @return [Array<Hash>] copied notices for the page
      def degradations(page)
        @degradation_mutex.synchronize { Array(@degradations[page]).map(&:dup).freeze }
      end

      # Routes an already-parsed attach, detach, or event message.
      # Refusals expose a generic wire message; stale-generation refusals precede a new tree.
      # @param connection [Object] authenticated transport
      # @param message [Hash] message accepted by Protocol.parse_client_message
      # @return [Object] dispatch result, or :refused for a handled protocol/contract error
      def handle(connection, message)
        case message[:type]
        when 'attach' then attach(connection, message)
        when 'detach' then detach(connection, message)
        when 'event' then event(connection, message)
        end
      rescue Protocol::Refusal => error
        log(:warning, "WebUI event refusal=#{error.reason}")
        connection.send_text(
          Protocol.refusal(reason: error.reason, message: 'Message refused', page: message[:page], cid: message[:cid],
                           event: message[:event], request: message[:request])
        )
        # Refusal must precede the replacement tree so the browser can associate
        # a correlated retry with the exact rejected intent.
        send_render(connection, fetch_attachment(connection, message[:page])) if error.reason == :stale_generation
        :refused
      rescue Error => error
        log(:warning, "WebUI event refusal=#{error.class}")
        connection.send_text(
          Protocol.refusal(reason: :contract, message: 'Message refused', page: message[:page], cid: message[:cid],
                           event: message[:event], request: message[:request])
        )
        :refused
      end

      # Closes admission before waiting for previously accepted work and releasing pages.
      # @param owner [Object] terminating owner identity
      # @return [Array<Page>] removed pages
      def terminate_owner(owner)
        @registry.terminate_owner(owner)
        @scheduler.cancel_owner(owner, terminal: true)
        cancel_renders(owner)
        pages = @registry.pages_for(owner)
        @dispatcher.shutdown_owner(owner)
        @registry.unregister_owner(owner)
        pages.each do |page|
          @on_page_closed&.call(page)
          @viewers.attachments_for(page).each do |attachment|
            connection = @connections_mutex.synchronize { @connections[attachment.connection_id] }
            connection&.send_text(Protocol.page_closed(address: attachment.address, reason: :owner))
          end
          @viewers.destroy_page(page)
        end
        @degradation_mutex.synchronize { pages.each { |page| @degradations.delete(page) } }
        pages
      end

      # Refuses registration before draining the host's dispatcher and render workers.
      # @return [void]
      def shutdown
        @registry.stop
        @scheduler.shutdown
        @dispatcher.shutdown
        cancel_renders
      end

      # Internal core render scheduling, shared by native page updates and the
      # imperative adapter. A key has at most one worker, with changes coalesced
      # until its next render. Explicit adapter presentation shares this queue.
      # The short adapter delay batches construction without blocking its caller.
      # @param key [Object] render source identified by object identity
      # @param owner [Object] server-owned lifecycle identity
      # @param delay [Numeric] coalescing delay in seconds
      # @param render [Proc] render work retained for the scheduling record
      # @return [nil]
      # @api private
      def schedule_render(key, owner:, delay: 0.01, &render)
        @render_coordinator.schedule_render(key, owner: owner, delay: delay, &render)
      end

      private

      # Reads diagnostic identity without changing lifecycle ownership.
      # @param owner [Object] server-owned lifecycle identity
      # @return [Object]
      # @api private
      def owner_label(owner)
        Diagnostics.owner_label(owner)
      end

      # Join already admitted renders before unregistering pages. Otherwise an
      # adapter could publish a page immediately after its owner was removed.
      # @param owner [Object, nil] exact owner, or nil to cancel all render workers
      # @return [Array<Thread>]
      # @api private
      def cancel_renders(owner = nil)
        @render_coordinator.cancel_renders(owner)
      end

      # Delivers diagnostics while isolating sink failures from runtime control flow.
      # @param level [Symbol] diagnostic severity
      # @param message [String] diagnostic text
      # @return [Object, nil]
      # @api private
      def log(level, message)
        Diagnostics.log(@logger, level, message)
      end
    end
  end
end

require_relative 'runtime/attachments'
require_relative 'runtime/events'
require_relative 'runtime/submissions'
require_relative 'runtime/rendering'
require_relative 'runtime/properties'
require_relative 'runtime/lifecycle'
