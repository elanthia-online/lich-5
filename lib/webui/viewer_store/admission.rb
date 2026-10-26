# frozen_string_literal: true

module Lich
  module WebUI
    class ViewerStore
      # Serializes event validation and queue admission with delivery/detachment.
      # The yielded runtime work may enqueue callbacks, but never runs script code.
      # Only unchanged transfer/release authority can outlive a paint generation;
      # compressed epochs are retained per viewer, never a render history.
      # @param attachment [Attachment] exact viewer/page association
      # @param message [Hash] validated event envelope with generation and optional request
      # @return [Object] runtime admission result, or :queued for a duplicate request
      # @yieldparam admission [Admission, ReleaseAdmission] captured gesture authority
      # @raise [Protocol::Refusal] for obsolete generations or a departed viewer
      def admit_event(attachment, message)
        @mutex.synchronize do
          unless live_attachment?(attachment)
            raise Protocol::Refusal.new(:attachment, 'viewer is no longer attached')
          end
          widget_drop = message[:event].to_s == 'widget_drop'
          return admit_release(attachment, message) { |admission| yield admission } if %w[pointer_release pointer_motion].include?(message[:event].to_s)

          generation = message[:generation]
          current = attachment.delivered_generation
          compatible = widget_drop && attachment.widget_generation && generation.is_a?(Integer) &&
                       generation.between?(attachment.widget_generation, current) &&
                       @clock.call - attachment.widget_started_at < WIDGET_ADMISSION_WINDOW &&
                       attachment.render.submissions.fetch(message[:cid], []).empty?
          unless generation == current || compatible
            raise Protocol::Refusal.new(:stale_generation, 'stale generation')
          end
          request = message[:request] if widget_drop && message[:request].is_a?(Integer)
          return :queued if request && attachment.widget_request && request <= attachment.widget_request

          admission = Admission.new(widget_drop ? attachment.render : nil, attachment.widget_revision, @clock.call)
          result = yield admission
          attachment.widget_request = request if request && result == :queued
          result
        end
      end

      # Checks queued transfers without holding the store lock during script code.
      # The captured callback/render retain admission-time identity; later state
      # changes retire queued work instead of selecting a replacement source.
      # @param attachment [Attachment] exact viewer/page association
      # @param admission [Admission] captured widget revision and admission time
      # @return [Boolean]
      def widget_admission_current?(attachment, admission)
        @mutex.synchronize do
          live_attachment?(attachment) && attachment.widget_revision == admission.widget_revision &&
            @clock.call - admission.accepted_at < WIDGET_ADMISSION_WINDOW
        end
      end

      # Rechecks the exact release surface epoch before queued user code runs.
      # @param attachment [Attachment] original admitting viewer
      # @param admission [ReleaseAdmission] captured surface epoch and queue time
      # @return [Boolean] whether the queued callback still has live authority
      def release_admission_current?(attachment, admission)
        @mutex.synchronize do
          live_attachment?(attachment) && attachment.release_epochs[admission.cid].equal?(admission.epoch) &&
            @clock.call - admission.accepted_at < RELEASE_ADMISSION_WINDOW
        end
      end

      private

      # Checks connection identity as well as transient-disconnect state.
      # Caller holds the store monitor; no resume token alone authorizes events.
      # @param attachment [Attachment] candidate live viewer
      # @return [Boolean] whether this exact attachment remains routed
      # @api private
      def live_attachment?(attachment)
        @by_connection[[attachment.connection_id, attachment.address]].equal?(attachment) && !attachment.expires_at
      end

      # Clears transfer/release epochs on disconnect or permanent destruction.
      # @param attachment [Attachment] viewer whose queued authority is retired
      # @return [Integer] advanced transfer revision
      # @api private
      def retire_widget_admission!(attachment)
        attachment.release_epochs.clear
        attachment.release_request = nil
        attachment.widget_signature = attachment.widget_generation = attachment.widget_started_at = attachment.widget_request = nil
        attachment.widget_revision += 1
      end

      # Admits only unchanged release surfaces, never submitted forms or arbitrary
      # stale event families. Request high-water marks prevent duplicate callbacks
      # across surface replacement and time-window renewal.
      # @param attachment [Attachment] live viewer protected by the store monitor
      # @param message [Hash] correlated release envelope, still subject to validation
      # @return [Object] validation/enqueue result, or :queued for a duplicate
      # @yieldparam admission [ReleaseAdmission] coherent callback render and epoch
      # @raise [Protocol::Refusal] for a generation outside the surface epoch
      # @api private
      def admit_release(attachment, message)
        epoch = attachment.release_epochs[message[:cid]]
        generation = message[:generation]
        current = attachment.delivered_generation
        compatible = epoch && generation.is_a?(Integer) && generation.between?(epoch.generation, current) &&
                     @clock.call - epoch.started_at < RELEASE_ADMISSION_WINDOW &&
                     attachment.render.submissions.fetch(message[:cid], []).empty?
        unless generation == current || compatible
          raise Protocol::Refusal.new(:stale_generation, 'stale generation')
        end
        request = message[:request] if message[:request].is_a?(Integer)
        return :queued if request && attachment.release_request && request <= attachment.release_request

        admission = ReleaseAdmission.new(attachment.render, epoch, message[:cid], @clock.call)
        result = yield admission
        attachment.release_request = request if request && result == :queued
        result
      end
    end
  end
end
