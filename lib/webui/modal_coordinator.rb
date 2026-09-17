# frozen_string_literal: true

require_relative 'future'
require_relative 'page'

module Lich
  module WebUI
    # Owns modal registration and the response/timeout/termination race.
    class ModalCoordinator
      Pending = Data.define(:owner, :page, :future, :timer)
      # How long a modal whose only viewer's socket dropped waits for that
      # viewer to come back before the answer is "dismissed". A viewer that
      # closed the window says so explicitly and is not made to wait.
      DISMISS_GRACE = 5.0

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

      def terminate_owner(owner)
        futures = @mutex.synchronize do
          @pending.values.select { |pending| pending.owner.equal?(owner) }.map(&:future)
        end
        futures.each { |future| future.cancel(reason: :terminated) }
        futures.length
      end

      def pending_count
        @mutex.synchronize { @pending.length }
      end

      private

      def resolve_absent_viewer(future, props)
        if props[:no_viewer] == 'default'
          future.resolve(button: props[:default_button], reason: :no_viewer)
        else
          future.resolve(reason: :no_viewer)
        end
        future
      end

      def forget_registered(page)
        return unless page

        @mutex.synchronize { @pending.delete_if { |_future, pending| pending.page.equal?(page) } }
        @registry.unregister(page.owner, page.id)
      rescue StandardError => error
        @logger.call(:warning, "WebUI modal unregister failed=#{error.class}")
      end

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
