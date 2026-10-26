# frozen_string_literal: true

module Lich
  module WebUI
    class Adapter
      # Replaces a tabs page/header collection atomically, preserving retained handles.
      # Viewer selections are reconciled by stable header key on delivery.
      # One adapter monitor guards validation, ownership, selection remapping and
      # publication scheduling. Removed pages remain reusable; tab actions remain.
      # If mutation or scheduling raises before return, properties, child
      # ownership/slots and pending viewer selections are restored before re-raising.
      # @param parent [Handle] tabs container owned by this adapter
      # @param children [Array<Handle>] unique tab pages in their new display order
      # @param names [Array<String>] one caption per tab page
      # @param headers [Array<Hash>] contracted header metadata with stable keys
      # @return [nil]
      def layout_tabs(parent, children:, names:, headers:)
        @mutex.synchronize do
          tabs = node!(parent)
          raise attributed_error('tabs required', parent) unless tabs.type == :tabs
          unless children.is_a?(Array) && names.is_a?(Array) && children.uniq.length == children.length && children.length == names.length
            raise attributed_error('one unique child per tab required', parent)
          end
          props = @validator.validate_component!(
            :tabs, tabs.props.merge(names: names, headers: headers, selected: 0),
            owner: owner_label, page_id: adapter_page_id, cid: handle_label(parent)
          )
          headers = props.fetch(:headers)
          candidates = children.map do |handle|
            child = node!(handle)
            raise attributed_error('foreign or cyclic tab child', handle) if (child.parent && child.parent != parent) || root_for(tabs).equal?(child)
            child
          end
          actions = tabs.children.select { |handle| node!(handle).placement.key?(:tab_action) }
          raise attributed_error('action cannot also be a tab page', parent) if candidates.any? { |child| child.placement.key?(:tab_action) }
          raise attributed_error('component has too many children', parent) if children.length + actions.length > Contract::BOUNDS[:children]
          old_headers = tabs.props[:headers]
          remap = proc do |index|
            Contract.remap_tab_index(old_headers, headers, index, names.length)
          end
          props = props.merge(selected: remap.call(tabs.props[:selected] || 0)).freeze
          pending = tabs.viewer_values.select { |(_viewer, name), _value| name == :selected }
          before_props, before_children = tabs.props, tabs.children.dup
          involved = (tabs.children + children).uniq.to_h { |handle| [handle, [node!(handle).parent, node!(handle).slot]] }
          begin
            (tabs.children - children - actions).each { |handle| node!(handle).parent = node!(handle).slot = nil }
            tabs.props, tabs.children = props, children + actions
            candidates.each { |child| child.parent = parent }
            assign_child_slots!(tabs)
            pending.each { |key, index| tabs.viewer_values[key] = remap.call(index) }
            dirty!(root_for(tabs))
          rescue StandardError
            tabs.props, tabs.children = before_props, before_children
            pending.each { |key, index| tabs.viewer_values[key] = index }
            involved.each { |handle, (owner, slot)| node!(handle).parent, node!(handle).slot = owner, slot }
            raise
          end
        end
        nil
      end

      # Atomically replaces the two auxiliary tab-strip roles without touching pages or selection.
      # Removed actions remain reusable; refused publication restores every ownership edge.
      # @param parent [Handle] tabs container
      # @param actions [Hash{Symbol => Handle}] optional :start and :end action widgets
      # @return [nil]
      def layout_tab_actions(parent, actions:)
        @mutex.synchronize do
          tabs = node!(parent)
          valid = tabs.type == :tabs && actions.is_a?(Hash) && (actions.keys - %i[start end]).empty? && actions.values.uniq.length == actions.length
          raise attributed_error('unique start/end tab actions required', parent) unless valid

          previous = tabs.children.select { |handle| node!(handle).placement.key?(:tab_action) }
          pages = tabs.children - previous
          raise attributed_error('component has too many children', parent) if pages.length + actions.length > Contract::BOUNDS[:children]
          actions.each_value do |handle|
            child = node!(handle)
            valid = child.type != :page && (!child.parent || previous.include?(handle)) && !root_for(tabs).equal?(child)
            raise attributed_error('action must be unparented or already owned by these tabs', handle) unless valid
          end
          involved = (previous + actions.values).uniq.to_h do |handle|
            child = node!(handle)
            [handle, [child.parent, child.slot, child.placement]]
          end
          before = tabs.children
          begin
            previous.each do |handle|
              child = node!(handle)
              child.parent = child.slot = nil
              child.placement = child.placement.except(:tab_action).freeze
            end
            tabs.children = pages + actions.values
            actions.each do |side, handle|
              child = node!(handle)
              child.parent, child.slot = parent, nil
              child.placement = child.placement.merge(tab_action: side.to_s).freeze
              validate_placement!(tabs, child, handle)
            end
            dirty!(root_for(tabs))
          rescue StandardError
            tabs.children = before
            involved.each { |handle, state| node!(handle).parent, node!(handle).slot, node!(handle).placement = state }
            raise
          end
        end
        nil
      end

      # Atomically changes a grid's bounded geometry and placements without
      # replacing handles, bindings or viewer-owned input. Unparented children
      # may be prepared for a subsequent attach; foreign parents are refused.
      # @param parent [Handle] grid container
      # @param columns [Integer] positive shared-contract column count
      # @param placements [Hash{Handle => Hash}] replacement child placements
      # @param expand_columns [Array<Integer>] expanding tracks in the new geometry
      # @return [nil]
      def layout_grid(parent, columns:, placements:, expand_columns: [])
        @mutex.synchronize do
          grid = node!(parent)
          raise attributed_error('grid required', parent) unless grid.type == :grid
          raise attributed_error('placement map required', parent) unless placements.is_a?(Hash) && placements.size <= Contract::BOUNDS[:children]
          proposed = grid.dup
          proposed.props = @validator.validate_component!(
            :grid, grid.props.merge(cols: columns, expand_columns: expand_columns),
            owner: owner_label, page_id: adapter_page_id, cid: handle_label(parent)
          )
          replacements = placements.to_h do |handle, placement|
            child = node!(handle)
            raise attributed_error('foreign grid child', handle) if child.parent && child.parent != parent
            raise attributed_error('placement must be a Hash', handle) unless placement.is_a?(Hash)
            candidate = child.dup
            candidate.placement = symbolize(placement).freeze
            validate_placement!(proposed, candidate, handle)
            [handle, candidate.placement]
          end
          grid.children.each do |handle|
            validate_placement!(proposed, node!(handle), handle) unless replacements.key?(handle)
          end
          grid.props = proposed.props
          replacements.each { |handle, placement| node!(handle).placement = placement }
          dirty!(root_for(grid))
        end
        nil
      end

      # Updates only an attached overlay child's pointer hit testing. Rejection
      # or publication failure preserves its previous placement and identity.
      # @param parent [Handle] overlay container
      # @param child [Handle] attached layer
      # @param value [Boolean] pointer pass-through flag
      # @return [nil]
      def set_overlay_pass_through(parent, child, value)
        @mutex.synchronize do
          parent_node = node!(parent)
          child_node = node!(child)
          unless parent_node.type == :overlay && child_node.parent.equal?(parent)
            raise attributed_error('expected an attached overlay child', child, :pass_through)
          end
          previous = child_node.placement
          candidate = child_node.dup
          candidate.placement = previous.merge(pass_through: value).freeze
          validate_placement!(parent_node, candidate, child)
          return nil if previous == candidate.placement

          child_node.placement = candidate.placement
          begin
            dirty!(root_for(parent_node))
          rescue StandardError
            child_node.placement = previous
            raise
          end
        end
        nil
      end
    end
  end
end
