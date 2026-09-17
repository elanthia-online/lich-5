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
    #
    # Where a native page is declared by a render block, the adapter lets a caller build
    # the same tree one operation at a time: {#create} a node and receive an opaque
    # handle, {#set} its properties, {#attach} it under a parent, {#bind} callbacks, and
    # {#destroy} it. Every operation validates against the {Contract} through the
    # {Validator}, marks the affected page root dirty, and the private `flush!` turns the
    # dirty roots into {Page} renders through the service. A subclass (the GTK shim)
    # extends what a render carries through the traversal hooks without walking the tree
    # itself.
    class Adapter
      # @return [Array<Symbol>] the operations the port exposes
      OPERATIONS = %i[create get set attach detach bind unbind destroy modal schema].freeze

      # An opaque token naming one node. It carries nothing a caller can read.
      class Handle
        # @return [String] a fixed description that reveals nothing about the node
        def inspect = '#<Lich::WebUI::Adapter::Handle opaque>'
        alias to_s inspect
      end
      private_constant :Handle

      # The adapter's own record of a node: its type, validated props, child handles, parent
      # handle, named slot, event to binding id, and the Page once the root has rendered.
      Node = Struct.new(:type, :props, :children, :parent, :slot, :bindings, :page, keyword_init: true)
      private_constant :Node

      # Creates an adapter for one owner over the WebUI service.
      #
      # @param owner [Object] the script or object the pages are registered under
      # @param service [Service] provides the registry, the runtime, refresh and modals
      # @param viewer [String, nil] the viewer whose viewer-scoped values {#get} and {#set} address;
      #   nil leaves viewer-scoped access refused
      # @param validator [Validator] checks every property write
      # @return [Adapter] the new adapter
      def initialize(owner:, service:, viewer: nil, validator: Validator.new)
        @owner = owner
        @service = service
        @viewer = viewer
        @validator = validator
        @nodes = {}.compare_by_identity
        # handle_for was Hash#key, which scans values -- and a Node is a
        # Struct, so each candidate is a memberwise == that recurses into
        # props and children. flush! calls it twice per dirty root, on every
        # commit, and the shim commits on every property write. Measured at
        # 401 nodes: 0.162ms a call against 0.00005ms through this map.
        @handles_by_node = {}.compare_by_identity
        @destroyed = {}.compare_by_identity
        @bindings = {}
        @viewer_values = {}
        @dirty_roots = {}.compare_by_identity
        @mutex = Monitor.new
      end

      # Creates a detached node of a contract type and returns its handle.
      #
      # A `page` node is marked dirty at once so it renders on the next flush.
      #
      # @param type [Symbol, String] the component type
      # @param props [Hash{Symbol, String => Object}] the node's initial properties
      # @return [Handle] the opaque handle naming the node
      # @raise [ArgumentError] when props is not a Hash or a key is not a contract name
      # @raise [UnknownTypeError] when the type is not a contract type
      # @raise [SchemaViolationError] when the properties fail validation
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
          @handles_by_node[node] = handle
          dirty!(node) if normalized == :page
        end
        handle
      rescue UnknownTypeError, SchemaViolationError => error
        raise attributed(error, handle)
      end

      # Reads a node property from the adapter's server-held state.
      #
      # Viewer-scoped properties come from this adapter's viewer's values, falling back to
      # the node's props. `:value` resolves to the type's value shape when it is not a
      # declared property.
      #
      # @param handle [Handle] the node
      # @param property [Symbol, String] the property name
      # @return [Object] a deep copy of the value
      # @raise [Error] when the handle is unknown or destroyed
      # @raise [UnknownPropertyError] when the type has no such property
      # @raise [SensitiveReadError] when the property is write-only
      # @raise [AmbiguousViewerError] when the property is viewer-scoped and the adapter has no viewer
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

      # Validates and writes one node property, marking the node's root dirty.
      #
      # Viewer-scoped properties are stored per viewer; shared ones re-validate the whole
      # property set with the new value merged in, and re-assign child slots when the
      # type names its children.
      #
      # @param handle [Handle] the node
      # @param property [Symbol, String] the property name
      # @param value [Object] the new value
      # @return [nil]
      # @raise [Error] when the handle is unknown or destroyed
      # @raise [UnknownPropertyError] when the type has no such property
      # @raise [SchemaViolationError] when the property is sensitive or ephemeral, or the value is invalid
      # @raise [AmbiguousViewerError] when the property is viewer-scoped and the adapter has no viewer
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

      # Inserts a child under a parent, at the end or at an index.
      #
      # @param parent [Handle] the node to attach under
      # @param child [Handle] the node to attach; must currently have no parent
      # @param index [Integer, nil] the position among the parent's children; nil appends
      # @return [nil]
      # @raise [Error] when a handle is unknown or destroyed, the child already has a parent, the
      #   parent accepts no children or is already full, the attach would form a cycle, or the
      #   index is out of range
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

      # Removes a child from its parent without destroying it.
      #
      # @param parent [Handle] the node the child is under
      # @param child [Handle] the node to remove
      # @return [nil]
      # @raise [Error] when a handle is unknown or destroyed, or the child is not under the parent
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

      # Binds a callback to one of the node's events, replacing any earlier binding for that event.
      #
      # A page root accepts the lifecycle events ({Contract::PAGE_LIFECYCLE_EVENTS}); every other
      # type accepts the events its schema lists.
      #
      # @param handle [Handle] the node
      # @param event [Symbol, String] the event name
      # @param callable [#call] receives the {Runtime::EventContext} when the event fires
      # @return [String] the binding id, for {#unbind}
      # @raise [ArgumentError] when the callable does not respond to call or the event is not a
      #   contract name
      # @raise [Error] when the handle is unknown or destroyed
      # @raise [UnknownEventError] when the type has no such event
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

      # Removes a binding by id.
      #
      # @param binding_id [String, #to_s] an id returned by {#bind}
      # @return [nil]
      # @raise [Error] when the id is not a live binding
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

      # Destroys a node and its whole subtree, detaching it from its parent first.
      #
      # Destroying a rendered page root closes the page through the runtime. The handle
      # stays known as destroyed, so a later use is refused as such rather than as unknown.
      #
      # @param handle [Handle] the node to destroy
      # @return [nil]
      # @raise [Error] when the handle is unknown or already destroyed
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

      # Opens a modal dialog through the service on the owner's behalf.
      #
      # @param props [Hash{Symbol, String => Object}] the modal's options as the service's `modal`
      #   takes them; an `id` is minted when none is given
      # @return [Object] whatever the service's modal call returns
      # @raise [ArgumentError] when props is not a Hash
      # @raise [Error] any failure from the service, re-raised with adapter attribution
      def modal(props)
        raise ArgumentError, 'props must be a Hash' unless props.is_a?(Hash)

        options = symbolize(props)
        id = options.delete(:id) || "adapter-modal-#{SecureRandom.hex(8)}"
        @service.modal(owner: @owner, id: id, **options)
      rescue StandardError => error
        raise attributed(error, nil, :modal)
      end

      # Looks up a contract type's schema, attributing an unknown type to this adapter.
      #
      # @param type [Symbol, String] the component type
      # @return [Hash{Symbol => Object}] the schema from {Contract.schema}
      # @raise [UnknownTypeError] when the type is not a contract type
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

      # Registers a Page for a page root the first time it is flushed.
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

      # One render pass for a page root. The traversal is the only one: a
      # subclass that carries more than props beside its nodes (the shim's
      # placement, presentation facility and submission scopes) supplies it
      # through the three hooks below rather than walking the tree itself,
      # so the two can never drift (D13).
      def render_children(builder, node)
        @mutex.synchronize do
          declare_facilities(builder, node)
          drafts = {}.compare_by_identity
          render_child_components!(builder, node, drafts)
          render_completed(builder, drafts)
        end
      end

      # Caller holds @mutex (a Monitor, so the recursion may retake it).
      # +drafts+ collects handle => draft across the whole pass, because a
      # scope that names other components by cid can only be installed once
      # every cid has been minted.
      def render_child_components!(builder, node, drafts)
        adapter = self
        node.children.each do |child_handle|
          child = @nodes.fetch(child_handle)
          props = effective_props(child, child_handle)
          bindings = child.bindings.to_h do |event, binding_id|
            [event, @bindings.fetch(binding_id).last]
          end
          drafts[child_handle] =
            builder.component(child.type, slot: child.slot, on: bindings, placement: child_placement(child_handle), **props) do
              adapter.send(:render_child_components!, self, child, drafts)
            end
        end
      end

      # --- traversal hooks --------------------------------------------------
      # Each is called under @mutex during render_children; a subclass
      # overrides what it carries and leaves the walk alone.

      # Facilities the page root declares (presentation, say). Nothing by
      # default.
      def declare_facilities(_builder, _node); end

      # The placement a child renders with (grid span, box padding). None by
      # default.
      def child_placement(_handle)
        {}
      end

      # Runs once every component in the pass has a draft, and so a cid.
      def render_completed(_builder, _drafts); end

      # The node's props with this adapter's viewer's viewer-scoped values overlaid.
      def effective_props(node, handle)
        Contract.schema(node.type)[:properties].each_with_object(node.props.dup) do |(name, definition), result|
          next unless definition[:scope] == :viewer && @viewer

          key = [@viewer, handle, name]
          result[name] = @viewer_values[key] if @viewer_values.key?(key)
        end
      end

      # Event name to callable for a node's bindings.
      def callbacks_for(node)
        node.bindings.to_h { |event, binding_id| [event, @bindings.fetch(binding_id).last] }
      end

      # Validates one property in the context of the node's others and returns its normalised value.
      def validate_property(node, handle, name, value)
        @validator.validate_component!(
          node.type, node.props.merge(name => value), owner: owner_label,
          page_id: adapter_page_id, cid: handle_label(handle)
        ).fetch(name)
      end

      # The normalised name and definition of a property, treating `:value` as the type's value shape.
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

      # Whether the property is write-only: sensitive scope, or the value of a sensitive input.
      def sensitive_property?(node, name, definition)
        definition[:scope] == :sensitive_write_only ||
          (name == :value && (node.type == :password_input || node.props[:sensitive] == true))
      end

      # This adapter's viewer's value for the property, or the node's prop when none was set.
      def viewer_value(node, handle, name)
        viewer = viewer!
        deep_copy(@viewer_values.fetch([viewer, handle, name], node.props[name]))
      end

      # The adapter's viewer, or an AmbiguousViewerError when it was created without one.
      def viewer!
        return @viewer if @viewer

        message = 'viewer-scoped adapter state requires an explicit viewer'
        raise AmbiguousViewerError.new(message, owner: owner_label, page_id: adapter_page_id)
      end

      # Recomputes each child's slot name from its position, for types with named children.
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

      # Refuses an attach to a named-children parent that already has every slot filled.
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

      # Whether the node's type places children in named slots.
      def named_children?(node)
        Contract.schema(node.type)[:children].is_a?(Hash)
      end

      # The node for a handle; an attributed error for a destroyed or unknown one.
      def node!(handle)
        return @nodes.fetch(handle) if @nodes.key?(handle)
        raise attributed_error('handle is already destroyed', handle) if @destroyed.key?(handle)

        raise attributed_error('unknown handle', handle)
      end

      # Forgets a node and its subtree: bindings, viewer values, and the handle map.
      def destroy_node!(handle)
        node = @nodes.delete(handle)
        @handles_by_node.delete(node)
        node.children.each { |child| destroy_node!(child) }
        node.bindings.each_value { |binding_id| @bindings.delete(binding_id) }
        @viewer_values.delete_if { |(_viewer, candidate, _property), _value| candidate.equal?(handle) }
        @destroyed[handle] = true
      end

      # Closes a rendered page through the runtime with reason owner.
      def close_page(page)
        @service.runtime.close_page(page, reason: :owner)
      end

      # The topmost ancestor of a node.
      def root_for(node)
        current = node
        current = node!(current.parent) while current.parent
        current
      end

      # Marks a root as needing a render on the next flush.
      def dirty!(root)
        @dirty_roots[root] = true
      end

      # The handle for a node, or nil once the node is destroyed.
      def handle_for(node)
        @handles_by_node[node]
      end

      # The page id a root renders under, or a placeholder for errors before any root exists.
      def adapter_page_id(root = nil)
        suffix = root ? handle_for(root).object_id.to_s(36) : 'unrendered'
        "adapter-#{suffix}"
      end

      # The cid a handle is attributed by in errors.
      def handle_label(handle)
        handle ? "opaque-#{handle.object_id.to_s(36)}" : 'adapter'
      end

      # A printable name for the owner, for error attribution.
      def owner_label
        return @owner.webui_owner_id if @owner.respond_to?(:webui_owner_id)
        return @owner.name if @owner.respond_to?(:name) && @owner.name

        "#{@owner.class}:#{@owner.object_id}"
      end

      # Re-raises an error as an attributed Error of the same class, unless it is already attributed.
      def attributed(error, handle = nil, field = nil)
        return error if error.is_a?(Error) && error.owner

        error_class = error.is_a?(Error) ? error.class : Error
        error_class.new(
          error.message, owner: owner_label, page_id: adapter_page_id,
          cid: handle && handle_label(handle), field: field
        )
      end

      # A new Error attributed to this adapter, and to a handle and field when given.
      def attributed_error(message, handle = nil, field = nil)
        Error.new(
          message, owner: owner_label, page_id: adapter_page_id,
          cid: handle && handle_label(handle), field: field
        )
      end

      # A copy of the hash with every key normalised to a contract name symbol.
      def symbolize(hash)
        hash.to_h { |key, value| [normalize_name(key), value] }
      end

      # A symbol for a symbol or identifier-shaped string; ArgumentError for anything else.
      def normalize_name(value)
        return value if value.is_a?(Symbol)
        return value.to_sym if value.is_a?(String) && value.match?(Contract::IDENTIFIER)

        raise ArgumentError, "invalid contract name #{value.inspect}"
      end

      # A structural copy: hashes, arrays and strings are duplicated, everything else shared.
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
