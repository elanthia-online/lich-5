# frozen_string_literal: true

module Lich
  module WebUI
    class Adapter
      private

      # Snapshots the mutable adapter tree before constructing its declarative render.
      # Terminal actions receive the snapshot's complete input scope.
      # @param builder [TreeBuilder] current declarative render
      # @param node [Node] owned page root
      # @return [void]
      # @api private
      def render_children(builder, node)
        snapshot = @mutex.synchronize { snapshot_children(node) }
        scope = input_cids(snapshot, "page:#{adapter_page_id(node)}")
        render_snapshot(builder, snapshot, scope)
        @mutex.synchronize do
          reference, revision = node.focus
          handle = weak_value(reference)
          target = @nodes[handle]
          if target && target.cid && root_for(target).equal?(node)
            builder.focus(target.cid)
            builder.focus_revision(revision)
          end
        end
      end

      # Captures properties, bindings, slots, placement and descendants under the adapter monitor.
      # @param node [Node] parent whose descendants are captured under the monitor
      # @return [Array] render snapshot tuples
      # @api private
      def snapshot_children(node)
        node.children.map do |handle|
          child = @nodes.fetch(handle)
          bindings = child.bindings.to_h { |event, id| [event, child.callbacks.fetch(id).last] }
          [child, child.props.merge(key: handle_label(handle)), child.slot, bindings, snapshot_children(child), child.placement]
        end
      end

      # An imperative page is a legacy form. Each terminal control declares the
      # page's input scope server-side, so Save captures current DOM values even
      # when a change/blur event has not arrived. Values remain viewer-local.
      # @param snapshot [Array<Array>] captured descendant tuples
      # @param parent_cid [String] declarative identity of their parent
      # @return [Array<String>] depth-first input identities for terminal submissions
      # @api private
      def input_cids(snapshot, parent_cid)
        snapshot.flat_map do |child, props, _slot, _bindings, children|
          cid = "#{parent_cid}/#{child.type}:#{props.fetch(:key)}"
          own = Contract.schema(child.type)[:value] ? [cid] : []
          own + input_cids(children, cid)
        end
      end

      # Builds snapshot controls and retains generated CIDs for subsequent scoped reads/writes.
      # @param builder [TreeBuilder] current declarative parent
      # @param snapshot [Array<Array>] captured descendants
      # @param scope [Array<String>] complete terminal-action input scope
      # @return [void]
      # @api private
      def render_snapshot(builder, snapshot, scope)
        adapter = self
        snapshot.each do |child, props, slot, bindings, children, placement|
          terminal = (Contract.schema(child.type)[:events].keys & %i[activate submit response]).any?
          draft = builder.component(child.type, slot: slot, placement: placement, on: bindings, submit: terminal ? scope : nil, **props) do
            adapter.send(:render_snapshot, self, children, scope)
          end
          @mutex.synchronize { child.cid = draft.cid }
        end
      end
    end
  end
end
