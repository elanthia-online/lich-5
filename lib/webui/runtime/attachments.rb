# frozen_string_literal: true

module Lich
  module WebUI
    class Runtime
      # Retains resumable attachments and rechecks modals after active viewers leave.
      # Enqueues every detach before notifying each owner identity once, then
      # schedules one recheck at the resume deadline so expiry is delivered even
      # when no later request arrives (B2).
      # A refused detach enqueue (queue overflow or a terminated owner) does not
      # skip the other attachments, the expiry recheck or the owner notifications;
      # every step is attempted and the first refusal is re-raised afterwards.
      # @param connection [Object] disconnected transport with a viewer_id
      # @return [void]
      # @raise [Error] the first refused detach enqueue, after all steps ran
      def disconnect(connection)
        @connections_mutex.synchronize { @connections.delete(connection.viewer_id) }
        owners = {}.compare_by_identity
        disconnected = @viewers.transient_disconnect(connection.viewer_id)
        retain_resumable(disconnected)
        failure = nil
        disconnected.each do |attachment|
          attachment.page.forget_monitors(attachment.viewer_id)
          owners[attachment.page.owner] = true
          begin
            enqueue_lifecycle(attachment, :detach)
          rescue Error => error
            failure ||= error
          end
        end
        schedule_viewer_expiry(owners.keys)
        owners.each_key { |owner| @viewers_changed&.call(owner) }
        raise failure if failure
      end

      # A different script's open window cannot present this owner's modal.
      # Active and resumable (transiently disconnected, unexpired) viewers both
      # count; modal no-viewer policy applies only when neither remains (B2).
      # The store decides expiry; this only remembers which viewers to recheck.
      # @param owner [Object] server-owned lifecycle identity
      # @return [Boolean]
      def viewers_present?(owner)
        @registry.pages_for(owner).any? do |page|
          !@viewers.attachments_for(page).empty? || resumable_viewers?(page)
        end
      end

      private

      # Resolves a registered page and creates/resumes its viewer attachment before delivery.
      # The render is validated before any viewer or connection bookkeeping, so a
      # render failure leaves an earlier resumable attachment untouched. A failed
      # delivery retires a new attachment, re-suspends a resumed one (it keeps its
      # values, resume token and original deadline), and removes any connection
      # mapping this attach added, so a retry is never refused as already attached.
      # Store bookkeeping the failed deliver advanced (render, generation, widget
      # and release epochs, read-only evidence) needs no undo: events require live
      # routing, and the next resume delivers and re-records them for its render.
      # @param connection [Object] authenticated viewer transport
      # @param message [Hash] validated protocol envelope
      # @return [Symbol] :attached after render delivery and lifecycle enqueue
      # @api private
      def attach(connection, message)
        page = fetch_page(message[:page])
        page.bind_runtime(self)
        render = validated_render(page)
        added = @connections_mutex.synchronize do
          next false if @connections.key?(connection.viewer_id)

          @connections[connection.viewer_id] = connection
          true
        end
        attachment = nil
        begin
          attachment = @viewers.attach(
            connection_id: connection.viewer_id, address: message[:page], page: page,
            resume_token: message[:resume]
          )
          @viewers.deliver(attachment, render)
          send_render(connection, attachment)
        rescue StandardError
          if attachment&.resume_state == :resumed && @viewers.resuspend(attachment)
            retain_resumable([attachment])
          elsif attachment
            @viewers.close(connection_id: connection.viewer_id, address: message[:page])
          end
          if added
            @connections_mutex.synchronize do
              @connections.delete(connection.viewer_id) if @connections[connection.viewer_id].equal?(connection)
            end
          end
          raise
        end
        enqueue_lifecycle(attachment, :attach)
        :attached
      end

      # Removes one viewer attachment regardless of render generation.
      # Close targets attachment lifetime, so an in-flight render must not discard
      # it. Component events still require the delivered generation to match.
      # Viewer detach never closes the page: managed-window closure belongs to the
      # owned process path (browser_closed), so another viewer keeps its page (B2).
      # The attachment is retired even when a lifecycle enqueue is refused (queue
      # overflow or a terminated owner); every job is attempted, the first refusal
      # is re-raised, and no window-close claim is consumed here.
      # Retiring discards the viewer's drafts: the detach handler receives them,
      # but a later managed-window close of the page (browser_closed) no longer
      # has this viewer, so its close handlers see source values, not the drafts.
      # Rechecks the owner's modal policies after removal.
      # @param connection [Object] authenticated transport
      # @param message [Hash] validated detach envelope
      # @return [Symbol] :detached after removal
      # @api private
      def detach(connection, message)
        attachment = fetch_attachment(connection, message[:page])
        begin
          jobs = []
          if message[:geometry]
            # Final window measurements and detach travel together, so a pending
            # meter render cannot invalidate the last size just as Chrome exits.
            payload = @validator.validate_event!(:page, :configure, message[:geometry], props: attachment.render.tree.props,
                                                 owner: owner_label(attachment.page.owner), page_id: attachment.page.id,
                                                 cid: attachment.render.tree.cid)
            attachment.page.observe_window_geometry(payload)
            jobs << lifecycle_job(attachment, :configure, payload)
          end
          # Capture all contexts before removal clears the attachment render.
          jobs << lifecycle_job(attachment, :detach)
          failure = nil
          jobs.compact.each do |job|
            job.call
          rescue Error => error
            failure ||= error
          end
          raise failure if failure
        ensure
          @viewers.close(connection_id: connection.viewer_id, address: message[:page])
          attachment.page.forget_monitors(attachment.viewer_id)
          @viewers_changed&.call(attachment.page.owner)
        end
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

      # Remembers suspended attachments for the modal viewer-presence check.
      # A re-suspended viewer is added again because a concurrent presence check
      # may have pruned it while its resume was live.
      # @param attachments [Array<ViewerStore::Attachment>] disconnected or re-suspended viewers
      # @return [void]
      # @api private
      def retain_resumable(attachments)
        @resumable_mutex.synchronize do
          attachments.each do |attachment|
            retained = (@resumable[attachment.page] ||= [])
            retained << attachment unless retained.any? { |candidate| candidate.equal?(attachment) }
          end
        end
      end

      # Reports whether a transiently disconnected viewer of this page is still
      # resumable. Call after ViewerStore#attachments_for, which applies the
      # store's expiry; a destroyed attachment has no render and a resumed one
      # has no deadline (it is active again).
      # @param page [Page] exact page instance
      # @return [Boolean]
      # @api private
      def resumable_viewers?(page)
        @resumable_mutex.synchronize do
          retained = @resumable[page]
          next false unless retained

          retained.select! { |attachment| attachment.expires_at && attachment.render }
          @resumable.delete(page) if retained.empty?
          !retained.empty?
        end
      end

      # Queues one owner recheck at the resume deadline on a single host worker.
      # Deadlines share one window length, so the queue stays in deadline order.
      # @param owners [Array<Object>] owners whose viewers became resumable
      # @return [void]
      # @api private
      def schedule_viewer_expiry(owners)
        return if owners.empty?

        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + ViewerStore::RECONNECT_WINDOW
        @resumable_mutex.synchronize do
          next if @expiry_stopped

          owners.each { |owner| @expiry_queue << [deadline, owner] }
          @expiry_thread ||= HostThread.start { viewer_expiry_loop }
          @expiry_condition.signal
        end
      end

      # Delivers each scheduled resume deadline as an owner viewer recheck.
      # @return [void]
      # @api private
      def viewer_expiry_loop
        loop do
          owner = @resumable_mutex.synchronize do
            loop do
              return if @expiry_stopped

              if @expiry_queue.empty?
                @expiry_condition.wait(@resumable_mutex)
              else
                remaining = @expiry_queue.first[0] - Process.clock_gettime(Process::CLOCK_MONOTONIC)
                break @expiry_queue.shift[1] unless remaining.positive?

                @expiry_condition.wait(@resumable_mutex, remaining)
              end
            end
          end
          begin
            @viewers_changed&.call(owner)
          rescue StandardError => error
            log(:warning, "WebUI viewer expiry check failed error=#{error.class}")
          end
        end
      end

      # Stops the expiry worker with a bounded wait; pending rechecks are dropped.
      # @return [void]
      # @api private
      def stop_viewer_expiry
        thread = @resumable_mutex.synchronize do
          @expiry_stopped = true
          @expiry_queue.clear
          @expiry_condition.broadcast
          @expiry_thread
        end
        thread&.join(1) unless thread.equal?(Thread.current)
      end
    end
  end
end
