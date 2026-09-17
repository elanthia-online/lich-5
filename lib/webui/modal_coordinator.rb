# frozen_string_literal: true

require_relative 'future'
require_relative 'page'

module Lich
  module WebUI
    # Owns modal registration and the response/timeout/termination race.
    #
    # A modal is a throwaway {Page} holding one dialog component. The
    # coordinator registers it, arms the ways it can end -- a button, the
    # viewer closing it, every viewer leaving, a timeout, the owner being
    # torn down -- and resolves the {Future} exactly once, whichever wins,
    # then unregisters the page.
    class ModalCoordinator
      # A modal that has been raised and not yet answered.
      #
      # @!attribute [r] owner
      #   @return [Object] the script or core object that raised it
      # @!attribute [r] page
      #   @return [Page] the page holding the dialog
      # @!attribute [r] future
      #   @return [Future] the completion
      # @!attribute [r] timer
      #   @return [Thread, nil] the timeout thread, when a timeout was given
      Pending = Data.define(:owner, :page, :future, :timer)
      # How long a modal whose only viewer's socket dropped waits for that
      # viewer to come back before the answer is "dismissed". A viewer that
      # closed the window says so explicitly and is not made to wait.
      DISMISS_GRACE = 5.0

      # Builds a coordinator.
      #
      # @param registry [Registry] where modal pages are registered
      # @param runtime [Runtime] binds and closes the modal pages
      # @param viewers_present [#call] answers whether any browser is connected
      # @param pages_changed [#call] called after a modal page is added or removed
      # @param logger [#call, nil] receives `(level, message)`; silent when nil
      # @param dismiss_grace [Numeric] seconds to wait for a dropped viewer, {DISMISS_GRACE} by default
      # @return [ModalCoordinator] the coordinator
      def initialize(registry:, runtime:, viewers_present:, pages_changed:, logger: nil, dismiss_grace: DISMISS_GRACE)
        @registry = registry
        @runtime = runtime
        @viewers_present = viewers_present
        @pages_changed = pages_changed
        @logger = logger || proc { |_level, _message| }
        @dismiss_grace = dismiss_grace
        @pending = {}.compare_by_identity
        @dismissals = {}.compare_by_identity
        # Viewers attached to each modal's page, counted from the page's own
        # attach and detach lifecycle events; a modal is dismissed only when
        # the count has been zero for the whole grace.
        @attached = Hash.new(0).compare_by_identity
        @mutex = Mutex.new
      end

      # Raises a modal dialog and returns its completion.
      #
      # With no viewer connected the future resolves at once according to
      # +no_viewer+ (`'default'` answers with +default_button+; `'wait'` keeps
      # the dialog up for the next viewer; anything else resolves with
      # `:no_viewer`), and no page is registered unless waiting.
      #
      # @param owner [Object] the script or core object raising the dialog
      # @param id [String] the page id for the dialog
      # @param title [String] the dialog title
      # @param buttons [Array] the dialog's buttons, as the `dialog` schema takes them
      # @param no_viewer [String, Symbol] what to do with nobody connected: `'default'`, `'wait'`, or other
      # @param body [String, nil] the dialog's message
      # @param default_button [String, nil] the button answered when nobody can press one
      # @param timeout [Numeric, nil] seconds before the future resolves with `:timeout`
      # @param credential [Boolean] whether the dialog collects a secret; such a dialog may not wait
      # @yield optional body content, evaluated against the dialog's {TreeBuilder}
      # @return [Future] resolves with the button pressed, or a reason: `:timeout`, `:dismissed`,
      #   `:no_viewer`, `:terminated`, `:error`
      # @raise [ArgumentError] when a credential dialog asks to wait for a viewer
      # @raise [SchemaViolationError] when the dialog properties fail validation
      def open(owner:, id:, title:, buttons:, no_viewer:, body: nil, default_button: nil,
               timeout: nil, credential: false, &content)
        raise ArgumentError, 'credential modals cannot wait for a viewer' if credential && no_viewer.to_s == 'wait'

        props = {
          title: title, body: body, buttons: buttons, no_viewer: no_viewer,
          default_button: default_button, timeout: timeout,
        }.compact
        props = Validator.new.validate_component!(
          :dialog, props, owner: owner_label(owner), page_id: id, cid: "page:#{id}/dialog:modal"
        )
        future = Future.new
        unless @viewers_present.call
          return resolve_absent_viewer(future, props) unless props[:no_viewer] == 'wait'
        end

        page = nil
        # A dialog nobody will answer must not wait for its timeout (review
        # 2026-09-17, R6: an hour, for a MessageDialog whose window was
        # closed). The viewer closing the window is an explicit close and
        # dismisses at once; a dropped socket is a detach and gets the
        # grace, cancelled by the viewer coming back.
        page = Page.new(owner: owner, id: id, title: title, on: {
          close: ->(_event) { future.resolve(reason: :dismissed) },
          detach: ->(_event) { viewer_left(future) },
          attach: ->(_event) { viewer_arrived(future) },
        }) do
          dialog(
            key: 'modal', **props,
            on: { response: ->(event) { future.resolve(button: event.payload[:button]) } }
          ) do
            instance_exec(self, &content) if content
          end
        end
        page.modal = true
        @registry.register(page)
        registered = page
        page.bind_runtime(@runtime)
        timer = timeout && Thread.new do
          sleep(timeout)
          future.resolve(reason: :timeout)
        end
        @mutex.synchronize { @pending[future] = Pending.new(owner, page, future, timer) }
        future.then { |result| complete(future, result) }
        @pages_changed.call
        future
      rescue StandardError
        future&.cancel(reason: :error)
        # Cancelling only reaches the page through future.then, which is
        # armed last. A failure between register and then would otherwise
        # leave the page registered with nothing that will ever close it.
        forget_registered(registered)
        raise
      end

      # Cancels every pending modal an owner raised.
      #
      # @param owner [Object] the owner being torn down
      # @return [Integer] how many modals were cancelled
      def terminate_owner(owner)
        futures = @mutex.synchronize do
          @pending.values.select { |pending| pending.owner.equal?(owner) }.map(&:future)
        end
        futures.each { |future| future.cancel(reason: :terminated) }
        futures.length
      end

      # How many modals are up and unanswered.
      #
      # @return [Integer]
      def pending_count
        @mutex.synchronize { @pending.length }
      end

      private

      # Resolves a modal nobody is connected to see, per its no_viewer policy.
      # @api private
      def resolve_absent_viewer(future, props)
        if props[:no_viewer] == 'default'
          future.resolve(button: props[:default_button], reason: :no_viewer)
        else
          future.resolve(reason: :no_viewer)
        end
        future
      end

      # Drops a page that was registered before open failed.
      # @api private
      def forget_registered(page)
        return unless page

        @mutex.synchronize { @pending.delete_if { |_future, pending| pending.page.equal?(page) } }
        @registry.unregister(page.owner, page.id)
      rescue StandardError => error
        @logger.call(:warning, "WebUI modal unregister failed=#{error.class}")
      end

      # A viewer attached to the modal's page; a pending dismissal is cancelled.
      # @api private
      def viewer_arrived(future)
        @mutex.synchronize do
          @attached[future] += 1
          @dismissals.delete(future)
        end
        nil
      end

      # A viewer's socket dropped (or it detached). When that was the last
      # one, the future resolves as dismissed once the grace passes with
      # nobody back; a viewer arriving in the meantime cancels it.
      # @api private
      def viewer_left(future)
        token = Object.new
        last = @mutex.synchronize do
          @attached[future] = [@attached[future] - 1, 0].max
          next false unless @attached[future].zero? && @pending.key?(future)

          @dismissals[future] = token
          true
        end
        return unless last

        Thread.new do
          sleep(@dismiss_grace)
          current = @mutex.synchronize { @dismissals[future].equal?(token) && @dismissals.delete(future) }
          future.resolve(reason: :dismissed) if current
        end
        nil
      end

      # The future resolved: stop the timer, close the page, and tell the launcher.
      # @api private
      def complete(future, result)
        pending = @mutex.synchronize do
          @dismissals.delete(future)
          @attached.delete(future)
          @pending.delete(future)
        end
        return unless pending

        pending.timer&.kill unless pending.timer.equal?(Thread.current)
        reason = result.reason || :response
        @runtime.close_page(pending.page, reason: reason)
        @pages_changed.call
      rescue StandardError => error
        @logger.call(:warning, "WebUI modal cleanup failed=#{error.class}")
      end

      def owner_label(owner)
        return owner.webui_owner_id if owner.respond_to?(:webui_owner_id)
        return owner.name if owner.respond_to?(:name) && owner.name

        "#{owner.class}:#{owner.object_id}"
      end
    end
  end
end
