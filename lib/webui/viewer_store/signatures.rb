# frozen_string_literal: true

module Lich
  module WebUI
    class ViewerStore
      private

      # One epoch per currently bound release surface; removed surfaces retain no
      # history. Equal paints keep authority for at most 30 seconds. The caller
      # holds the same monitor used for delivery and event validation.
      # @param attachment [Attachment] viewer receiving the render
      # @param render [Page::Render] newest coherent component tree and bindings
      # @param now [Numeric] monotonic delivery time
      # @return [Hash] current release signatures, keyed by component identity
      # @api private
      def update_release_epochs(attachment, render, now)
        signatures = release_signatures(render)
        attachment.release_epochs.keep_if { |cid, _epoch| signatures.key?(cid) }
        signatures.each do |cid, signature|
          epoch = attachment.release_epochs[cid]
          if !epoch || epoch.signature != signature
            attachment.release_epochs[cid] = ReleaseEpoch.new(signature, render.generation, now)
          elsif now - epoch.started_at >= RELEASE_ADMISSION_WINDOW
            epoch.generation = render.generation
            epoch.started_at = now
          end
        end
      end

      # Captures target subtrees and ancestor layout/state, excluding unrelated
      # sibling text paints. Shared immutable projections keep storage linear in
      # the tree plus the ancestry of each bound release surface.
      # @param render [Page::Render] validated tree and binding authority
      # @return [Hash] per-surface projections without viewer input snapshots
      # @api private
      def release_signatures(render)
        return {} unless render.bindings.any? { |(_cid, event), _callback| event == :pointer_release }

        bindings = render.bindings.each_with_object({}) do |((cid, event), callback), grouped|
          (grouped[cid] ||= {})[event] = callback
        end
        signatures = {}
        project = lambda do |node, ancestors|
          boundary = [node.cid, node.type, node.props, node.slot, node.placement, node.children.map(&:cid)]
          children = node.children.map { |child| project.call(child, ancestors + [boundary]) }
          subtree = [boundary, bindings[node.cid], render.submissions[node.cid], children]
          if bindings[node.cid]&.key?(:pointer_release)
            # A tracking canvas releases its own drag, not a child hit target.
            # Marker paints and scrolling may change during that drag; ownership,
            # visibility and the exact callbacks still delimit release authority.
            signatures[node.cid] = if node.type == :overlay && node.props[:pointer_tracking]
                                     [node.cid, bindings[node.cid], render.submissions[node.cid],
                                      (ancestors + [boundary]).map { |item| [item[0], item[1], item[2].slice(:hidden, :disabled, :pointer_tracking, :pointer_events), item[3]] }]
                                   else
                                     [subtree, ancestors, render.facilities]
                                   end
          end
          subtree
        end
        project.call(render.tree, [])
        signatures
      end

      # Transfer descendants retain all authored properties/bindings, so geometry
      # or meaning changes invalidate old measured insertion intent. Ancestors
      # retain their state and child order; unrelated sibling text paints do not.
      # Shared immutable property references keep the retained projection bounded
      # by the already validated component tree; no viewer input values are copied.
      # @param render [Page::Render] validated tree and transfer bindings
      # @return [Array, nil] transfer projection, or nil without transfer surfaces
      # @api private
      def widget_signature(render)
        bindings = render.bindings.each_with_object({}) do |((cid, event), callback), grouped|
          (grouped[cid] ||= {})[event] = callback
        end
        project = lambda do |node, inside|
          transfer = inside || node.props[:drag_source] || node.props[:drag_destination]
          children = node.children.filter_map { |child| project.call(child, transfer) }
          next if !transfer && children.empty?

          [node.cid, node.type, node.props, node.slot, node.placement, node.children.map(&:cid),
           transfer ? bindings[node.cid] : nil, render.submissions[node.cid], children]
        end
        tree = project.call(render.tree, false)
        [tree, render.facilities] if tree
      end
    end
  end
end
