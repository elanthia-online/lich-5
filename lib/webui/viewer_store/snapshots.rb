# frozen_string_literal: true

module Lich
  module WebUI
    class ViewerStore
      # Copies one coherent render and its nonsensitive viewer values for queued work.
      # The snapshot is not attached or resumable and cannot receive browser events.
      # @param attachment [Attachment] viewer whose delivered state is captured
      # @param for_delivery [Boolean] record read-only values from this wire snapshot;
      #   lifecycle snapshots must not change what the browser is allowed to submit
      # @return [Snapshot] independent values with an immutable render definition
      def snapshot(attachment, for_delivery: false)
        @mutex.synchronize do
          raise Error, 'viewer has no delivered render' unless attachment.render

          if for_delivery
            attachment.delivered_read_only.clear
            attachment.render.tree.each do |component|
              next unless %i[text_input textarea].include?(component.type) && component.props[:read_only] && !component.props[:sensitive]

              attachment.delivered_read_only[component.cid] = attachment.values.fetch([component.cid, :value], component.props[:value])
            end
          end
          Snapshot.new(attachment.page, attachment.viewer_id, attachment.render, attachment.values.dup, attachment.input_requests.dup)
        end
      end

      # Captures the sole retained viewer when an owned OS window exits without pagehide.
      # Multiple viewers are deliberately not guessed; expired viewers are excluded.
      # @param page [Page] page whose native host exited
      # @param retire [Boolean] retire the exited viewer after copying its closing state
      # @return [Snapshot, nil] last delivered state, when unambiguous
      def closing_snapshot(page, retire: false)
        @mutex.synchronize do
          expire_locked!
          candidates = @by_resume.values.select { |attachment| attachment.page.equal?(page) && attachment.render }
          if candidates.one?
            attachment = candidates.first
            snapshot = Snapshot.new(page, attachment.viewer_id, attachment.render, attachment.values.dup, attachment.input_requests.dup)
            destroy_locked!(attachment) if retire
            snapshot
          end
        end
      end

      # Overlays viewer-local values onto the delivered tree for wire serialization.
      # @param attachment [Attachment, Snapshot] delivered viewer or captured closing/delivery state
      # @return [Hash] viewer-specific component tree
      # @raise [Error] before a render has been delivered
      def serialize(attachment)
        @mutex.synchronize do
          render = attachment.render
          raise Error, 'viewer has no delivered render' unless render

          serialize_component(render.tree, attachment.values)
        end
      end

      private

      # Overlays viewer properties and row expansion while excluding secret/ephemeral fields.
      # @param component [Component] validated delivered component
      # @param values [Hash] this viewer's property overrides under the store monitor
      # @return [Hash] recursively serialized control
      # @api private
      def serialize_component(component, values)
        props = component.props.each_with_object({}) do |(name, value), result|
          definition = Contract.schema(component.type)[:properties][name]
          next if definition && %i[sensitive_write_only ephemeral_client].include?(definition[:scope])
          next if name == :value && ValueHelpers.sensitive_value?(component)

          result[name] = definition && definition[:scope] == :viewer ? values.fetch([component.cid, name], value) : value
        end
        # Optional viewer properties (for example a naturally sized split's
        # position) may first exist after interaction, with no source default.
        Contract.schema(component.type)[:properties].each do |name, definition|
          next if component.props.key?(name) || definition[:scope] != :viewer
          next if name == :value && ValueHelpers.sensitive_value?(component)

          props[name] = values[[component.cid, name]] if values.key?([component.cid, name])
        end
        if component.type == :table
          props[:rows] = props[:rows].map do |row|
            expanded = values.key?([component.cid, :expanded]) ? values[[component.cid, :expanded]].include?(row[:key]) : row[:expanded]
            row.merge(expanded: expanded)
          end
        end
        result = { type: component.type.to_s, cid: component.cid, props: props, children: component.children.map { |child| serialize_component(child, values) } }
        result[:slot] = component.slot if component.slot
        result[:placement] = component.placement unless component.placement.empty?
        result
      end
    end
  end
end
