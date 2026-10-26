# frozen_string_literal: true

require_relative 'future'
require_relative 'page'

module Lich
  module WebUI
    # Owns modal registration and the response/timeout/termination race.
    class ModalCoordinator
      Pending = Data.define(:owner, :page, :future, :timer, :props)

      # Connects modal completion to registry ownership and viewer availability.
      # @param registry [Registry] page registration/admission service
      # @param runtime [Runtime] render and callback runtime
      # @param viewers_present [#call] owner-scoped viewer availability query
      # @param pages_changed [#call] notification after modal registration changes
      # @param logger [#call, nil] isolated diagnostic sink
      def initialize(registry:, runtime:, viewers_present:, pages_changed:, logger: nil)
        @registry = registry
        @runtime = runtime
        @viewers_present = viewers_present
        @pages_changed = pages_changed
        @logger = logger || proc { |_level, _message| }
        @pending = {}.compare_by_identity
        @mutex = Mutex.new
      end

      # Registers a nonblocking modal while its owner is live, with explicit viewer policy.
      # @param owner [Object] lifetime identity shared with the presenting pages
      # @param id [String] modal page ID unique within the owner
      # @param title [String] dialog title
      # @param buttons [Array<Hash>] permitted responses
      # @param no_viewer [Symbol, String] abort, default or wait when no active viewer exists
      # @param body [String, nil] optional dialog text
      # @param default_button [String, nil] response selected by the default policy
      # @param timeout [Numeric, nil] explicit deadline in seconds; nil adds no deadline
      # @param credential [Boolean] refuses wait policy for credential prompts
      # @param props [Hash] dialog property overrides
      # @param page_props [Hash] containing page properties
      # @param on_response [#call, nil] custom handler receiving event and completion
      # @param content [Proc, nil] builder for additional dialog controls
      # @return [Future] response or cancellation completion
      # @raise [Error] if the owner terminated or the host stopped
      # @raise [ArgumentError] if a credential modal requests wait policy
      def open(owner:, id:, title:, buttons:, no_viewer:, body: nil, default_button: nil,
               timeout: nil, credential: false, props: {}, page_props: {}, on_response: nil, &content)
        timer = nil
        registered = false
        @registry.ensure_active!(owner)
        raise ArgumentError, 'credential modals cannot wait for a viewer' if credential && no_viewer.to_s == 'wait'

        props = props.merge(
          title: title, body: body, buttons: buttons, no_viewer: no_viewer,
          default_button: default_button, timeout: timeout,
        ).compact
        props = Validator.new.validate_component!(
          :dialog, props, owner: owner_label(owner), page_id: id, cid: "page:#{id}/dialog:modal"
        )
        page_props = Validator.new.validate_component!(
          :page, page_props.merge(title: title), owner: owner_label(owner), page_id: id, cid: "page:#{id}"
        )
        future = Future.new(logger: @logger)
        unless @viewers_present.call(owner)
          return resolve_absent_viewer(future, props) unless props[:no_viewer] == 'wait'
        end

        # Custom native forms use the same terminal submission validation as
        # buttons. A response handler may retain the modal while a warning is
        # pending, but must resolve/cancel its completion without blocking.
        response = proc do |event|
          if on_response
            on_response.call(event, future)
          else
            future.resolve(button: event.payload[:button])
          end
        rescue StandardError
          future.cancel(reason: :error)
          raise
        end
        page = nil
        page = Page.new(owner: owner, id: id, title: title, props: page_props,
                        on: { close: proc { future.cancel(reason: :cancelled) } }) do
          dialog(
            key: 'modal', **props,
            on: { response: response }
          ) do |dialog|
            if content
              # Existing one-argument modal blocks keep their calling convention.
              on_response ? instance_exec(self, dialog, &content) : instance_exec(self, &content)
            end
          end
        end
        # Admission and pending tracking must be indivisible with respect to
        # terminate_owner/shutdown; user callbacks run only after releasing this lock.
        @mutex.synchronize do
          @registry.register(page, modal: true)
          registered = true
          page.bind_runtime(@runtime)
          timer = timeout && Thread.new do
            sleep(timeout)
            future.resolve(reason: :timeout)
          end
          @pending[future] = Pending.new(owner, page, future, timer, props)
        end
        future.then { |result| complete(future, result) }
        cleanup_installed = true
        @pages_changed.call
        viewers_changed(owner)
        future
      rescue StandardError
        future&.cancel(reason: :error)
        unless cleanup_installed
          timer&.kill
          @runtime.close_page(page, reason: :error) if registered
        end
        raise
      end

      # Prevents late admission and resolves every pending modal for one owner.
      # @param owner [Object] terminating lifetime identity
      # @return [Integer] number of completions considered
      def terminate_owner(owner)
        @registry.terminate_owner(owner)
        futures = @mutex.synchronize do
          @pending.values.select { |pending| pending.owner.equal?(owner) }.map(&:future)
        end
        futures.each { |future| future.cancel(reason: :terminated) }
        futures.length
      end

      # Cancels pending completions after globally closing registration.
      # @return [void]
      def shutdown
        @registry.stop
        futures = @mutex.synchronize { @pending.keys }
        futures.each { |future| future.cancel(reason: :terminated) }
      end

      # Reapplies each modal's policy when its owner has no active viewers.
      # Disconnected attachments remain resumable, but do not count as active.
      # A failed availability check is logged and leaves registered modals live;
      # it must not turn a post-registration notification into a setup failure.
      # @param owner [Object] owner whose viewer availability changed
      # @return [void]
      def viewers_changed(owner)
        return if @viewers_present.call(owner)

        pending = @mutex.synchronize { @pending.values.select { |item| item.owner.equal?(owner) } }
        pending.each do |item|
          resolve_absent_viewer(item.future, item.props) unless item.props[:no_viewer] == 'wait'
        end
      rescue StandardError => error
        begin
          @logger.call(:warning, "WebUI modal viewer check failed: #{error.class}")
        rescue StandardError
          nil # Diagnostic failure must not cancel an otherwise usable modal.
        end
      end

      # Counts unresolved modals under the coordinator lock.
      # @return [Integer]
      def pending_count
        @mutex.synchronize { @pending.length }
      end

      private

      # Completes an unavailable modal using its declared default or cancellation policy.
      # @return [Future] supplied completion
      def resolve_absent_viewer(future, props)
        if props[:no_viewer] == 'default'
          future.resolve(button: props[:default_button], reason: :no_viewer)
        else
          future.resolve(reason: :no_viewer)
        end
        future
      end

      # Retires a resolved modal, stops its timer, and announces page removal.
      # Repeated completion after retirement is ignored.
      # @return [void]
      def complete(future, result)
        pending = @mutex.synchronize { @pending.delete(future) }
        return unless pending

        pending.timer&.kill unless pending.timer.equal?(Thread.current)
        reason = result.reason || :response
        @runtime.close_page(pending.page, reason: reason)
        @pages_changed.call
      rescue StandardError => error
        @logger.call(:warning, "WebUI modal cleanup failed=#{error.class}")
      end

      def owner_label(owner)
        Diagnostics.owner_label(owner)
      end
    end
  end
end
