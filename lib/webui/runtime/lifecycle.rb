# frozen_string_literal: true

module Lich
  module WebUI
    class Runtime
      # An owned app process exiting is a real window close. A WebSocket loss
      # remains a reconnectable detach and must never terminate the script.
      # @param page [Page] exact owner-scoped page
      # @return [void]
      def watch_window(page)
        @window_close_mutex.synchronize { @window_closes[page] = false }
      end

      # Dispatches an OS close with the last retained viewer state when unambiguous.
      # @param page [Page] page whose owned process exited
      # @return [Object, nil] dispatch result, or nil when already closed
      def browser_closed(page)
        @registry.address_for(page)
        callback = page.lifecycle_bindings[:close]
        return unless callback && claim_window_close(page)

        snapshot = @viewers.closing_snapshot(page, retire: true)
        component = snapshot&.render&.tree || page.last_render&.tree
        context = EventContext.new(snapshot&.viewer_id, page, component, :close, { reason: :user }.freeze, nil)
        begin
          dispatch_lifecycle(context, callback, snapshot)
        ensure
          if snapshot
            page.forget_monitors(snapshot.viewer_id)
            @viewers_changed&.call(page.owner)
          end
        end
      rescue Error
        nil # Owner termination already removed the page or its dispatcher.
      end

      # Removes a page and its attachments, then reevaluates owner modal availability.
      # @param page [Page] page to remove
      # @param reason [Symbol] reason sent to attached viewers
      # @return [Page, nil] removed page, or nil if already absent
      def close_page(page, reason: :owner)
        address = @registry.address_for(page)
        @registry.unregister(page.owner, page.id)
        @on_page_closed&.call(page)
        @viewers.attachments_for(page).each do |attachment|
          connection = @connections_mutex.synchronize { @connections[attachment.connection_id] }
          connection&.send_text(Protocol.page_closed(address: address, reason: reason))
        end
        @viewers.destroy_page(page)
        @degradation_mutex.synchronize { @degradations.delete(page) }
        @viewers_changed&.call(page.owner)
        page
      rescue Error
        nil
      end

      private

      # pagehide and the process monitor can both observe one user close.
      # Unmanaged browser viewers retain their existing per-viewer semantics.
      # @param page [Page] exact owner-scoped page
      # @return [Boolean]
      # @api private
      def claim_window_close(page)
        @window_close_mutex.synchronize do
          return true unless @window_closes.key?(page)
          return false if @window_closes[page]

          @window_closes[page] = true
        end
      end

      # Admits the captured lifecycle job when that event has a callback.
      # @param attachment [ViewerStore::Attachment] exact admitted viewer/page association
      # @param event [Symbol] page lifecycle event
      # @param payload [Hash] validated event fields
      # @return [Symbol, nil]
      # @api private
      def enqueue_lifecycle(attachment, event, payload = {})
        lifecycle_job(attachment, event, payload)&.call
      end

      # Captures readable viewer state before close removes its live attachment.
      # @param attachment [ViewerStore::Attachment] originating viewer
      # @param event [Symbol] lifecycle event
      # @param payload [Hash] validated event details
      # @return [Proc, nil] enqueue operation, or nil when no callback is bound
      # @api private
      def lifecycle_job(attachment, event, payload = {})
        callback = attachment.page.lifecycle_bindings[event]
        return unless callback
        return if event == :close && !claim_window_close(attachment.page)

        snapshot = @viewers.snapshot(attachment) if %i[close detach configure].include?(event)
        component = (snapshot&.render || attachment.render).tree
        context = EventContext.new(
          attachment.viewer_id, attachment.page, component, event, payload.freeze, nil
        )
        proc { dispatch_lifecycle(context, callback, snapshot) }
      end

      # Owns closing-state disposal even when callback work is refused or canceled.
      # @param context [EventContext] captured lifecycle event
      # @param callback [#call] bound page callback
      # @param snapshot [ViewerStore::Snapshot, nil] temporary closing viewer state
      # @return [Symbol] dispatcher admission result
      # @api private
      def dispatch_lifecycle(context, callback, snapshot)
        @dispatcher.enqueue(
          owner: context.page.owner, page_id: context.page.id,
          viewer_id: context.viewer_id, cid: context.component&.cid, event: context.event, coalescable: false,
          cleanup: -> { snapshot&.values&.clear }
        ) do
          previous = Thread.current.thread_variable_get(LIFECYCLE_SNAPSHOT_KEY)
          Thread.current.thread_variable_set(LIFECYCLE_SNAPSHOT_KEY, [self, snapshot])
          begin
            callback.call(context)
          ensure
            Thread.current.thread_variable_set(LIFECYCLE_SNAPSHOT_KEY, previous)
          end
        end
      end
    end
  end
end
