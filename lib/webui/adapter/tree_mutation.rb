# frozen_string_literal: true

module Lich
  module WebUI
    class Adapter
      # Repositions an existing child atomically under its parent's placement contract.
      # @param parent_handle [Handle] current parent
      # @param child_handle [Handle] attached child
      # @param placement [Hash] replacement parent-relative layout
      # @return [nil]
      # @raise [Error] without changing placement on invalid input or parentage
      def place(parent_handle, child_handle, placement)
        @mutex.synchronize do
          parent, child = node!(parent_handle), node!(child_handle)
          raise attributed_error('placement requires an attached child', child_handle, :placement) unless child.parent.equal?(parent_handle)
          raise ArgumentError, 'placement must be a Hash' unless placement.is_a?(Hash)

          candidate = child.dup
          candidate.placement = symbolize(placement).freeze
          validate_placement!(parent, candidate, child_handle)
          if parent.type == :tabs && candidate.placement[:tab_action]&.to_s != child.placement[:tab_action]&.to_s
            raise attributed_error('change tab action roles through layout_tab_actions', child_handle, :placement)
          end
          child.placement = candidate.placement
          dirty!(root_for(parent))
        end
        nil
      end

      # Inserts an unparented child after checking cycles, capacity, and placement.
      # Publication failure restores membership and named slots before re-raising;
      # handles, bindings and viewer values remain available for a later retry.
      # @param parent [Handle] owning container
      # @param child [Handle] child to attach
      # @param index [Integer, nil] insertion position; nil appends
      # @param placement [Hash, nil] replacement layout, or nil to keep the existing placement
      # @return [nil]
      def attach(parent, child, index = nil, placement: nil)
        @mutex.synchronize do
          parent_node = node!(parent)
          child_node = node!(child)
          raise attributed_error('child already has a parent', child) if child_node.parent
          raise attributed_error('component accepts no children', parent) if Contract.schema(parent_node.type)[:children] == :none
          raise attributed_error('component hierarchy cannot contain a cycle', child) if root_for(parent_node).equal?(child_node)

          position = index.nil? ? parent_node.children.length : Integer(index)
          unless position.between?(0, parent_node.children.length)
            raise attributed_error('child index is out of range', parent, :index)
          end
          child_rule = Contract.schema(parent_node.type)[:children]
          if child_rule.is_a?(Hash) && child_rule[:types] && !child_rule[:types].include?(child_node.type)
            raise attributed_error('child type is not permitted', child)
          end
          previous = child_node.placement
          candidate = child_node.dup
          unless placement.nil? || placement.is_a?(Hash)
            raise attributed_error('placement must be a Hash', child, :placement)
          end
          candidate.placement = symbolize(placement).freeze if placement
          validate_placement!(parent_node, candidate, child)
          raise attributed_error('tab actions cannot be pages', child) if parent_node.type == :tabs && candidate.placement.key?(:tab_action) && candidate.type == :page
          validate_child_capacity!(parent, parent_node, candidate)
          parent_node.children.insert(position, child)
          child_node.placement = candidate.placement
          child_node.parent = parent
          begin
            assign_child_slots!(parent_node)
            dirty!(root_for(parent_node))
          rescue StandardError
            parent_node.children.delete(child)
            child_node.parent = nil
            child_node.placement = previous
            child_node.slot = nil
            assign_child_slots!(parent_node)
            raise
          end
        end
        nil
      rescue ArgumentError, TypeError
        raise attributed_error('child index is out of range', parent, :index)
      end

      # Replaces one ordinary container child without publishing an intermediate tree.
      # Invalid ownership/cycles or refused publication preserve the previous tree.
      # @param parent_handle [Handle] ordinary container accepting many children
      # @param previous_handle [Handle, nil] actual child to replace, or nil to append
      # @param replacement_handle [Handle] unparented same-adapter replacement
      # @return [nil]
      # @raise [Error] for invalid replacement or refused publication admission
      def replace_child(parent_handle, previous_handle, replacement_handle)
        @mutex.synchronize do
          parent, replacement = node!(parent_handle), node!(replacement_handle)
          previous = node!(previous_handle) if previous_handle
          valid = Contract.schema(parent.type)[:children] == :many && !replacement.parent &&
                  (!previous || previous.parent.equal?(parent_handle))
          ancestor = parent
          while ancestor
            valid &&= !ancestor.equal?(replacement)
            ancestor = ancestor.parent && node!(ancestor.parent)
          end
          raise attributed_error('replacement requires an unparented child and its actual previous sibling', parent_handle) unless valid

          validate_placement!(parent, replacement, replacement_handle)
          expected = parent.children.length + (previous ? 0 : 1)
          raise attributed_error('component has too many children', parent_handle) if expected > Contract::BOUNDS[:children]
          index = previous ? parent.children.index(previous_handle) : parent.children.length
          before_children = parent.children.dup
          begin
            parent.children.delete(previous_handle) if previous
            previous.parent = nil if previous
            parent.children.insert(index, replacement_handle)
            replacement.parent = parent_handle
            dirty!(root_for(parent))
          rescue StandardError
            parent.children.replace(before_children)
            previous.parent = parent_handle if previous
            replacement.parent = nil
            raise
          end
        end
        nil
      end

      # Unparents a child without destroying its handle or descendants.
      # The former root is marked dirty for the next flush.
      # @param parent [Handle] current container
      # @param child [Handle] child to unparent and retain
      # @return [nil]
      def detach(parent, child)
        @mutex.synchronize do
          parent_node = node!(parent)
          child_node = node!(child)
          index = parent_node.children.index(child)
          raise attributed_error('component is not a child of parent', child) unless index

          if parent_node.type == :tabs && child_node.placement.key?(:tab_action)
            actions = parent_node.children.reject { |handle| handle.equal?(child) }.filter_map do |handle|
              side = node!(handle).placement[:tab_action]
              [side.to_sym, handle] if side
            end.to_h
            return layout_tab_actions(parent, actions: actions)
          end
          parent_node.children.delete_at(index)
          child_node.parent = nil
          child_node.slot = nil
          child_node.placement = child_node.placement.except(:pass_through).freeze if parent_node.type == :overlay
          child_node.placement = child_node.placement.except(:tab_action).freeze if parent_node.type == :tabs
          assign_child_slots!(parent_node)
          dirty!(root_for(parent_node))
        end
        nil
      end

      private

      # Child layout belongs to its parent schema. Validate before attaching so
      # an invalid span cannot corrupt the tree or fail later in a render job.
      # @param parent [Node] owning container with validated properties
      # @param child [Node] candidate child and placement
      # @param handle [Handle] child identity for errors
      # @return [void]
      # @api private
      def validate_placement!(parent, child, handle)
        definitions = Contract.schema(parent.type)[:child_properties] || {}
        child.placement.each do |name, value|
          definition = definitions[name] || raise(attributed_error('unknown child placement', handle, name))
          shape = Contract.child_placement_shape(definition.fetch(:shape), parent.props)
          @validator.validate_placement!(name, shape, value, owner: owner_label,
                                        page_id: adapter_page_id, cid: handle_label(handle))
        end
        if parent.type == :grid && child.placement.fetch(:column, 1) + child.placement.fetch(:span, 1) - 1 > parent.props[:cols]
          raise attributed_error('child placement exceeds grid columns', handle, :span)
        end
        case Contract.child_placement_condition(parent.type, parent.props, child.placement)
        when :grid_row_overflow
          raise attributed_error('child placement exceeds grid rows', handle, :row_span)
        when :unpositioned_coordinates
          raise attributed_error('coordinates require a positioned overlay', handle, :placement)
        end
      end

      # Updates named child slots without assigning tab-strip actions a page slot.
      # @param parent [Node] container with its current validated properties and children
      # @return [void]
      # @api private
      def assign_child_slots!(parent)
        rule = Contract.schema(parent.type)[:children]
        slots = Contract.child_slots(rule, parent.props)
        index = 0
        parent.children.each do |child_handle|
          child = node!(child_handle)
          if parent.type == :tabs && child.placement.key?(:tab_action)
            child.slot = nil
            next
          end
          # Dynamic numbering remains positional even before a reduced capacity
          # is rejected at publication; declared slot membership is a separate check.
          child.slot = rule.is_a?(Hash) && rule[:kind] == :named_dynamic ? index.to_s : slots[index]
          index += 1
        end
      end

      # Refuses attachments beyond the parent contract or an occupied tab action role.
      # @param handle [Handle] parent identity for errors
      # @param node [Node] current parent
      # @param candidate [Node] proposed child
      # @return [void]
      # @api private
      def validate_child_capacity!(handle, node, candidate)
        rule = Contract.schema(node.type)[:children]
        return unless rule.is_a?(Hash)

        if node.type == :tabs
          raise attributed_error('component has too many children', handle) if node.children.length >= Contract::BOUNDS[:children]
          children = node.children.map { |child| node!(child) }
          if candidate.placement.key?(:tab_action)
            side = candidate.placement[:tab_action].to_s
            raise attributed_error('tab action position occupied', handle) if children.any? { |child| child.placement[:tab_action]&.to_s == side }
            return
          end
          return if children.count { |child| !child.placement.key?(:tab_action) } < node.props[:names].length
          raise attributed_error('component has too many children', handle)
        end
        expected = Contract.child_slots(rule, node.props).length
        raise attributed_error('component has too many children', handle) if node.children.length >= expected
      end

      # Identifies containers whose contract declares named child slots.
      # @param node [Node] candidate parent
      # @return [Boolean] whether its child rule is a named declaration
      # @api private
      def named_children?(node)
        Contract.schema(node.type)[:children].is_a?(Hash)
      end
    end
  end
end
