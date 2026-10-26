# frozen_string_literal: true

module Lich
  module WebUI
    class Runtime
      # Retains resumable attachments and rechecks modals after active viewers leave.
      # Enqueues every detach before notifying each owner identity once.
      # @param connection [Object] disconnected transport with a viewer_id
      # @return [void]
      def disconnect(connection)
        @connections_mutex.synchronize { @connections.delete(connection.viewer_id) }
        owners = {}.compare_by_identity
        @viewers.transient_disconnect(connection.viewer_id).each do |attachment|
          attachment.page.forget_monitors(attachment.viewer_id)
          enqueue_lifecycle(attachment, :detach)
          owners[attachment.page.owner] = true
        end
        owners.each_key { |owner| @viewers_changed&.call(owner) }
      end

      # A different script's open window cannot present this owner's modal.
      # Transiently disconnected attachments are retained for resume, not counted.
      # @param owner [Object] server-owned lifecycle identity
      # @return [Boolean]
      def viewers_present?(owner)
        @registry.pages_for(owner).any? { |page| !@viewers.attachments_for(page).empty? }
      end

      private

      # Resolves a registered page and creates/resumes its viewer attachment before delivery.
      # @param connection [Object] authenticated viewer transport
      # @param message [Hash] validated protocol envelope
      # @return [Symbol] :attached after render delivery and lifecycle enqueue
      # @api private
      def attach(connection, message)
        @connections_mutex.synchronize { @connections[connection.viewer_id] = connection }
        page = fetch_page(message[:page])
        page.bind_runtime(self)
        attachment = @viewers.attach(
          connection_id: connection.viewer_id, address: message[:page], page: page,
          resume_token: message[:resume]
        )
        render = validated_render(page)
        @viewers.deliver(attachment, render)
        send_render(connection, attachment)
        enqueue_lifecycle(attachment, :attach)
        :attached
      end

      # Removes an explicit viewer attachment regardless of render generation.
      # Close targets attachment lifetime, so an in-flight render must not discard
      # it. Component events still require the delivered generation to match.
      # Rechecks the owner's modal policies after removal.
      # @param connection [Object] authenticated transport
      # @param message [Hash] validated detach envelope
      # @return [Symbol] :detached after removal
      # @api private
      def detach(connection, message)
        attachment = fetch_attachment(connection, message[:page])
        jobs = []
        if message[:geometry]
          # Final window measurements and close travel together, so a pending
          # meter render cannot invalidate the last size just as Chrome exits.
          payload = @validator.validate_event!(:page, :configure, message[:geometry], props: attachment.render.tree.props,
                                               owner: owner_label(attachment.page.owner), page_id: attachment.page.id,
                                               cid: attachment.render.tree.cid)
          attachment.page.observe_window_geometry(payload)
          jobs << lifecycle_job(attachment, :configure, payload)
        end
        # A close handler can unregister the page immediately on its worker.
        # Capture all contexts before dispatch can clear the attachment render.
        jobs << lifecycle_job(attachment, :close, reason: :user)
        jobs << lifecycle_job(attachment, :detach)
        jobs.compact.each(&:call)
        @viewers.close(connection_id: connection.viewer_id, address: message[:page])
        attachment.page.forget_monitors(attachment.viewer_id)
        @viewers_changed&.call(attachment.page.owner)
        :detached
      end

      # Resolves an opaque page address with a page-gone refusal on retirement.
      # @param address [String] opaque registered page address
      # @return [Page]
      # @api private
      def fetch_page(address)
        @registry.fetch_address(address)
      rescue Error
        raise Protocol::Refusal.new(:page_gone, 'page is no longer registered', page_id: address)
      end

      # Requires both a registered page and its current connection-specific attachment.
      # @param connection [Object] authenticated viewer transport
      # @param address [String] opaque registered page address
      # @return [ViewerStore::Attachment]
      # @raise [Protocol::Refusal] with page_gone or viewer_gone attribution
      # @api private
      def fetch_attachment(connection, address)
        fetch_page(address)
        @viewers.fetch(connection_id: connection.viewer_id, address: address)
      rescue Protocol::Refusal
        raise
      rescue Error
        raise Protocol::Refusal.new(:viewer_gone, 'viewer is no longer attached', page_id: address)
      end
    end
  end
end
