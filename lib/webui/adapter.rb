# frozen_string_literal: true

require 'securerandom'
require 'monitor'
require_relative 'contract'
require_relative 'errors'
require_relative 'page'
require_relative 'validator'

module Lich
  module WebUI
    # Imperative, versioned port used by the bounded script compatibility shim.
    class Adapter
      OPERATIONS = %i[create get set attach detach bind unbind destroy modal schema].freeze

      class Handle
        def inspect = '#<Lich::WebUI::Adapter::Handle opaque>'
        alias to_s inspect
      end
      private_constant :Handle

      Node = Struct.new(:type, :props, :children, :parent, :slot, :bindings, :page, keyword_init: true)
      private_constant :Node

      def initialize(owner:, service:, viewer: nil, validator: Validator.new)
        @owner = owner
        @service = service
        @viewer = viewer
        @validator = validator
        @nodes = {}.compare_by_identity
        @destroyed = {}.compare_by_identity
        @bindings = {}
        @viewer_values = {}
        @dirty_roots = {}.compare_by_identity
        @mutex = Monitor.new
      end

      def create(type, props)
        normalized = Contract.normalize_type(type)
        schema(normalized)
        raise ArgumentError, 'props must be a Hash' unless props.is_a?(Hash)

        handle = Handle.new.freeze
        validated = @validator.validate_component!(
          normalized, symbolize(props), owner: owner_label, page_id: adapter_page_id,
          cid: handle_label(handle)
        )
        node = Node.new(
          type: normalized, props: validated, children: [], parent: nil, slot: nil,
          bindings: {}, page: nil
        )
        @mutex.synchronize do
          @nodes[handle] = node
          dirty!(node) if normalized == :page
        end
        handle
      rescue UnknownTypeError, SchemaViolationError => error
        raise attributed(error, handle)
      end

      def get(handle, property)
        @mutex.synchronize do
          node = node!(handle)
          name, definition = property!(node, handle, property)
          if sensitive_property?(node, name, definition)
            raise SensitiveReadError.new(
              'sensitive-write-only property cannot be read', owner: owner_label,
              page_id: adapter_page_id, cid: handle_label(handle), field: name
            )
          end
          return viewer_value(node, handle, name) if definition[:scope] == :viewer

          deep_copy(node.props[name])
        end
      end

      def set(handle, property, value)
        @mutex.synchronize do
          node = node!(handle)
          name, definition = property!(node, handle, property)
          if sensitive_property?(node, name, definition)
            raise SchemaViolationError.new(
              'sensitive-write-only property cannot be set through server-held adapter state',
              owner: owner_label, page_id: adapter_page_id, cid: handle_label(handle), field: name
            )
          end
          if definition[:scope] == :ephemeral_client || definition[:scope] == :sensitive_write_only
            raise SchemaViolationError.new(
              'property cannot be set through server-held adapter state', owner: owner_label,
              page_id: adapter_page_id, cid: handle_label(handle), field: name
            )
          end
          if definition[:scope] == :viewer
            viewer = viewer!
            validated = validate_property(node, handle, name, value)
            @viewer_values[[viewer, handle, name]] = validated
          else
            node.props = @validator.validate_component!(
              node.type, node.props.merge(name => value), owner: owner_label,
              page_id: adapter_page_id, cid: handle_label(handle)
            )
            assign_child_slots!(node) if named_children?(node)
          end
          dirty!(root_for(node))
        end
        nil
      rescue SchemaViolationError => error
        raise attributed(error, handle, property)
      end

      def attach(parent, child, index = nil)
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
          validate_child_capacity!(parent, parent_node)
          parent_node.children.insert(position, child)
          child_node.parent = parent
          assign_child_slots!(parent_node)
          dirty!(root_for(parent_node))
        end
        nil
      rescue ArgumentError, TypeError
        raise attributed_error('child index is out of range', parent, :index)
      end

      def detach(parent, child)
        @mutex.synchronize do
          parent_node = node!(parent)
          child_node = node!(child)
          index = parent_node.children.index(child)
          raise attributed_error('component is not a child of parent', child) unless index

          parent_node.children.delete_at(index)
          child_node.parent = nil
          child_node.slot = nil
          assign_child_slots!(parent_node)
          dirty!(root_for(parent_node))
        end
        nil
      end

      def bind(handle, event, callable)
        raise ArgumentError, 'callback must respond to call' unless callable.respond_to?(:call)

        @mutex.synchronize do
          node = node!(handle)
          name = normalize_name(event)
          allowed_events = if node.type == :page
                             Contract::PAGE_LIFECYCLE_EVENTS
                           else
                             Contract.schema(node.type)[:events]
                           end
          unless allowed_events.key?(name)
            raise UnknownEventError.new(
              'event is not in the component allowlist', owner: owner_label,
              page_id: adapter_page_id, cid: handle_label(handle), field: name
            )
          end
          binding_id = "binding-#{SecureRandom.hex(16)}".freeze
          @bindings[binding_id] = [handle, name, callable]
          node.bindings[name] = binding_id
          dirty!(root_for(node))
          binding_id
        end
      end

      def unbind(binding_id)
        @mutex.synchronize do
          handle, event, = @bindings.delete(binding_id.to_s) || raise(
            attributed_error('unknown binding', nil, binding_id)
          )
          node = node!(handle)
          # Only if this id is still the one the node holds: a later bind for
          # the same event replaces it, and unbinding the old id must not
          # remove its replacement.
          node.bindings.delete(event) if node.bindings[event] == binding_id.to_s
          dirty!(root_for(node))
        end
        nil
      end

      def destroy(handle)
        @mutex.synchronize do
          raise attributed_error('handle is already destroyed', handle) if @destroyed.key?(handle)

          node = node!(handle)
          root = root_for(node)
          if node.parent
            parent = node!(node.parent)
            parent.children.delete(handle)
            # As detach does: named slots are positional, and the gap left by
            # the destroyed child shifted every later sibling.
            assign_child_slots!(parent)
            dirty!(root_for(parent))
          end
          destroy_node!(handle)
          @dirty_roots.delete(root) if root.equal?(node)
          close_page(root.page) if root.equal?(node) && root.page
        end
        nil
      end

      def modal(props)
        raise ArgumentError, 'props must be a Hash' unless props.is_a?(Hash)

        options = symbolize(props)
        id = options.delete(:id) || "adapter-modal-#{SecureRandom.hex(8)}"
        @service.modal(owner: @owner, id: id, **options)
      rescue StandardError => error
        raise attributed(error, nil, :modal)
      end

      def schema(type)
        Contract.schema(type)
      rescue UnknownTypeError => error
        raise attributed(error)
      end

      private

      # Prepares every dirty root under the lock, then refreshes outside it.
      #
      # `@service.refresh` reaches `Page#render`, which takes the page's
      # render mutex and then calls back into `render_children` for the
      # tree -- which takes this mutex. A viewer attaching on the
      # connection thread walks the same path in the other order: it holds
      # the render mutex first and reaches for this one second. Holding
      # both across the refresh is a lock-order inversion between the
      # script thread and the connection thread, and it deadlocks.
      #
      # Everything that reads adapter state stays inside the lock. Only the
      # refresh itself moves out, where re-entering through
      # `render_children` is safe.
      def flush!
        pages = @mutex.synchronize do
          selected = @dirty_roots.keys.filter_map do |candidate|
            root_for(candidate) if handle_for(candidate)
          end.uniq
          @dirty_roots.clear
          selected.filter_map do |root|
            next unless handle_for(root)

            ensure_page!(root)
            root.page.refresh_definition(
              title: root.props.fetch(:title), props: root.props.except(:title), on: callbacks_for(root)
            )
            root.page
          end
        end
        pages.each { |page| @service.refresh(page) }
        nil
      end

      def ensure_page!(root)
        return root.page if root.page
        raise attributed_error('only page roots can be rendered') unless root.type == :page

        adapter = self
        page = Page.new(
          owner: @owner, id: adapter_page_id(root), title: root.props.fetch(:title),
          props: root.props.except(:title), on: callbacks_for(root)
        ) do |builder|
          adapter.send(:render_children, builder, root)
        end
        @service.registry.register(page)
        page.bind_runtime(@service.runtime)
        root.page = page
      end

      def render_children(builder, node)
        @mutex.synchronize do
          adapter = self
          node.children.each do |child_handle|
            child = @nodes.fetch(child_handle)
            props = effective_props(child, child_handle)
            bindings = child.bindings.to_h do |event, binding_id|
              [event, @bindings.fetch(binding_id).last]
            end
            builder.component(child.type, slot: child.slot, on: bindings, **props) do
              adapter.send(:render_children, self, child)
            end
          end
        end
      end

      def effective_props(node, handle)
        Contract.schema(node.type)[:properties].each_with_object(node.props.dup) do |(name, definition), result|
          next unless definition[:scope] == :viewer && @viewer

          key = [@viewer, handle, name]
          result[name] = @viewer_values[key] if @viewer_values.key?(key)
        end
      end

      def callbacks_for(node)
        node.bindings.to_h { |event, binding_id| [event, @bindings.fetch(binding_id).last] }
      end

      def validate_property(node, handle, name, value)
        @validator.validate_component!(
          node.type, node.props.merge(name => value), owner: owner_label,
          page_id: adapter_page_id, cid: handle_label(handle)
        ).fetch(name)
      end

      def property!(node, handle, property)
        name = normalize_name(property)
        component_schema = Contract.schema(node.type)
        definition = component_schema[:properties][name]
        if !definition && name == :value && component_schema[:value]
          definition = { shape: component_schema[:value], scope: component_schema[:value_scope] }
        end
        return [name, definition] if definition

        raise UnknownPropertyError.new(
          'unknown property', owner: owner_label, page_id: adapter_page_id,
          cid: handle_label(handle), field: name
        )
      end

      def sensitive_property?(node, name, definition)
        definition[:scope] == :sensitive_write_only ||
          (name == :value && (node.type == :password_input || node.props[:sensitive] == true))
      end

      def viewer_value(node, handle, name)
        viewer = viewer!
        deep_copy(@viewer_values.fetch([viewer, handle, name], node.props[name]))
      end

      def viewer!
        return @viewer if @viewer

        message = 'viewer-scoped adapter state requires an explicit viewer'
        raise AmbiguousViewerError.new(message, owner: owner_label, page_id: adapter_page_id)
      end

      def assign_child_slots!(parent)
        rule = Contract.schema(parent.type)[:children]
        parent.children.each_with_index do |child_handle, index|
          child = node!(child_handle)
          child.slot = case rule
                       when Hash
                         case rule[:kind]
                         when :named then rule[:slots][index]
                         when :named_dynamic then index.to_s
                         when :named_from_property then parent.props.fetch(rule[:property])[index]&.to_s
                         end
                       end
        end
      end

      def validate_child_capacity!(handle, node)
        rule = Contract.schema(node.type)[:children]
        return unless rule.is_a?(Hash)

        expected = case rule[:kind]
                   when :named then rule[:slots].length
                   when :named_dynamic then node.props.fetch(rule[:count_property])
                   when :named_from_property then node.props.fetch(rule[:property]).length
                   end
        raise attributed_error('component has too many children', handle) if node.children.length >= expected
      end

      def named_children?(node)
        Contract.schema(node.type)[:children].is_a?(Hash)
      end

      def node!(handle)
        return @nodes.fetch(handle) if @nodes.key?(handle)
        raise attributed_error('handle is already destroyed', handle) if @destroyed.key?(handle)

        raise attributed_error('unknown handle', handle)
      end

      def destroy_node!(handle)
        node = @nodes.delete(handle)
        node.children.each { |child| destroy_node!(child) }
        node.bindings.each_value { |binding_id| @bindings.delete(binding_id) }
        @viewer_values.delete_if { |(_viewer, candidate, _property), _value| candidate.equal?(handle) }
        @destroyed[handle] = true
      end

      def close_page(page)
        @service.runtime.close_page(page, reason: :owner)
      end

      def root_for(node)
        current = node
        current = node!(current.parent) while current.parent
        current
      end

      def dirty!(root)
        @dirty_roots[root] = true
      end

      def handle_for(node)
        @nodes.key(node)
      end

      def adapter_page_id(root = nil)
        suffix = root ? handle_for(root).object_id.to_s(36) : 'unrendered'
        "adapter-#{suffix}"
      end

      def handle_label(handle)
        handle ? "opaque-#{handle.object_id.to_s(36)}" : 'adapter'
      end

      def owner_label
        return @owner.webui_owner_id if @owner.respond_to?(:webui_owner_id)
        return @owner.name if @owner.respond_to?(:name) && @owner.name

        "#{@owner.class}:#{@owner.object_id}"
      end

      def attributed(error, handle = nil, field = nil)
        return error if error.is_a?(Error) && error.owner

        error_class = error.is_a?(Error) ? error.class : Error
        error_class.new(
          error.message, owner: owner_label, page_id: adapter_page_id,
          cid: handle && handle_label(handle), field: field
        )
      end

      def attributed_error(message, handle = nil, field = nil)
        Error.new(
          message, owner: owner_label, page_id: adapter_page_id,
          cid: handle && handle_label(handle), field: field
        )
      end

      def symbolize(hash)
        hash.to_h { |key, value| [normalize_name(key), value] }
      end

      def normalize_name(value)
        return value if value.is_a?(Symbol)
        return value.to_sym if value.is_a?(String) && value.match?(Contract::IDENTIFIER)

        raise ArgumentError, "invalid contract name #{value.inspect}"
      end

      def deep_copy(value)
        case value
        when Hash then value.to_h { |key, item| [key, deep_copy(item)] }
        when Array then value.map { |item| deep_copy(item) }
        when String then value.dup
        else value
        end
      end
    end
  end
end
