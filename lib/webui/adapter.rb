# frozen_string_literal: true

require 'securerandom'
require 'monitor'
require 'weakref'
require_relative 'weak_identity_map'
require_relative 'contract'
require_relative 'errors'
require_relative 'page'
require_relative 'validator'
require_relative 'value_helpers'

module Lich
  module WebUI
    # Imperative, versioned port used by the bounded script compatibility shim.
    class Adapter
      OPERATIONS = %i[create get set attach detach bind unbind destroy modal schema present].freeze

      # Explicit reset token for optional shared properties. Never enters a render:
      # set removes the property and revalidates defaults and dependent layout.
      UNSET = Object.new.freeze

      # Requests host geometry through the shared service using this adapter's owner/viewer.
      # @param target [Symbol] :active, :primary, or :point
      # @param point [Array<Integer>, nil] signed desktop point for :point
      # @return [Hash] bounded geometry and explicit measurement/fallback provenance
      def monitor_geometry(target: :active, point: nil)
        viewer = ValueHelpers.viewer_id(@viewer)
        @service.monitor_geometry(owner: @owner, viewer: viewer, target: target, point: point)
      end

      # Opaque token retaining its payload while the discovery indexes stay weak.
      class Handle
        # The retained public token owns its payload even through a weak index.
        # @return [void]
        # @api private
        def initialize
          @state = []
        end

        # Replaces the token-owned payload during creation or retirement.
        # @param node [Node, nil] live payload, or nil when destroyed
        # @return [void]
        # @api private
        def retain(node)
          @state[0] = node
        end
        private :retain

        # Keeps diagnostic output opaque instead of exposing adapter internals.
        # @return [String] opaque token description
        # @api private
        def inspect = '#<Lich::WebUI::Adapter::Handle opaque>'
        alias to_s inspect
      end
      private_constant :Handle

      Node = Struct.new(:type, :props, :placement, :children, :parent, :slot, :bindings, :page, :cid, :published, :handle,
                        :callbacks, :viewer_values, :focus, :present_requested,
                        keyword_init: true)
      private_constant :Node

      # Creates an owner-bound imperative facade over the shared component contract.
      # Handles use object identity; equal-looking windows remain independent.
      # @param owner [Object] lifecycle identity for every created page
      # @param service [Service] host used for publication and cleanup
      # @param viewer [String, #viewer_id, nil] explicit identity or callback viewer resolver
      # @param validator [Validator] shared property validator
      # @param on_publish [#call, nil] host opener called on first publication or explicit presentation
      # @return [Adapter] newly initialized owner-bound port
      def initialize(owner:, service:, viewer: nil, validator: Validator.new, on_publish: nil)
        @owner = owner
        @service = service
        @viewer = viewer
        @validator = validator
        @on_publish = on_publish
        @nodes = WeakIdentityMap.new
        @destroyed = WeakIdentityMap.new
        @bindings = {}
        @binding_operations = 0
        @focus_sequence = 0
        @dirty_roots = {}.compare_by_identity
        @mutex = Monitor.new
      end

      # Validates a component and allocates an opaque handle without opening a window.
      # Page roots are marked dirty for later publication; placement is stored separately.
      # @param type [Symbol, String] supported component type
      # @param props [Hash] properties and optional placement hints
      # @return [Handle] identity-bound reference
      def create(type, props)
        normalized = Contract.normalize_type(type)
        schema(normalized)
        raise ArgumentError, 'props must be a Hash' unless props.is_a?(Hash)

        handle = Handle.new.freeze
        props = symbolize(props)
        placement = props.delete(:placement) || {}
        raise ArgumentError, 'placement must be a Hash' unless placement.is_a?(Hash)

        validated = @validator.validate_component!(
          normalized, props, owner: owner_label, page_id: adapter_page_id,
          cid: handle_label(handle)
        )
        node = Node.new(
          type: normalized, props: validated, placement: symbolize(placement).freeze, children: [], parent: nil, slot: nil,
          bindings: {}, callbacks: {}, viewer_values: {}, page: nil, handle: handle
        )
        @mutex.synchronize do
          handle.send(:retain, node)
          @nodes[handle] = node
          dirty!(node) if normalized == :page
        end
        handle
      rescue UnknownTypeError, SchemaViolationError => error
        raise attributed(error, handle)
      end

      # Destroys a handle subtree and closes its published page when destroying a root.
      # Unlike the shim's idempotent widget wrapper, repeated adapter destruction is refused.
      # @param handle [Handle] subtree root to retire
      # @return [nil]
      def destroy(handle)
        @mutex.synchronize do
          raise attributed_error('handle is already destroyed', handle) if @destroyed.key?(handle)

          node = node!(handle)
          root = root_for(node)
          if node.parent
            parent = node!(node.parent)
            parent.children.delete(handle)
            dirty!(root_for(parent))
          end
          destroy_node!(handle)
          @dirty_roots.delete(root) if root.equal?(node)
          close_page(root.page) if root.equal?(node) && root.page
        end
        nil
      end

      # Flushes pending roots, then opens an owner-scoped asynchronous modal.
      # @param props [Hash] modal options; ID is generated when absent
      # @return [Future] completion
      def modal(props)
        raise ArgumentError, 'props must be a Hash' unless props.is_a?(Hash)

        flush!
        options = symbolize(props)
        id = options.delete(:id) || "adapter-modal-#{SecureRandom.hex(8)}"
        @service.modal(owner: @owner, id: id, **options)
      rescue StandardError => error
        raise attributed(error, nil, :modal)
      end

      # Returns the shared schema with adapter-owner attribution on unknown types.
      # @param type [Symbol, String] supported contract type
      # @return [Hash] frozen type schema
      def schema(type)
        Contract.schema(type)
      rescue UnknownTypeError => error
        raise attributed(error)
      end

      private

      # Resolves an exact live handle and distinguishes destruction from foreign identity.
      # @param handle [Object] candidate opaque token
      # @return [Node] retained payload
      # @api private
      def node!(handle)
        return @nodes.fetch(handle) if @nodes.key?(handle)
        raise attributed_error('handle is already destroyed', handle) if @destroyed.key?(handle)

        raise attributed_error('unknown handle', handle)
      end

      # Recursively retires handles, bindings, and local values while remembering destruction.
      # Requires the adapter monitor; page closure is handled by the caller.
      # @param handle [Handle] owned subtree root to retire
      # @return [void]
      # @api private
      def destroy_node!(handle)
        node = @nodes.delete(handle)
        node.focus = nil
        node.children.each { |child| destroy_node!(child) }
        node.bindings.each_value { |binding_id| @bindings.delete(binding_id) }
        node.viewer_values.clear
        node.callbacks.clear
        node.bindings.clear
        node.children.clear
        handle.send(:retain, nil)
        @destroyed[handle] = true
      end

      # Follows retained parent handles to the current tree root.
      # @param node [Node] live node in the adapter tree
      # @return [Node] topmost ancestor
      # @api private
      def root_for(node)
        current = node
        current = node!(current.parent) while current.parent
        current
      end

      # Resolves a live node by its retained handle and exact identity, never Struct equality.
      # @param node [Node] candidate payload to resolve by exact identity
      # @return [Handle, nil] nil after retirement
      # @api private
      def handle_for(node)
        handle = node.handle
        handle if @nodes[handle].equal?(node)
      end

      # Derives diagnostic or registered page identity from the retained root handle.
      # @param root [Node, nil] page root, or nil for unrendered diagnostics
      # @return [String] adapter-local page identifier
      # @api private
      def adapter_page_id(root = nil)
        suffix = root ? handle_for(root).object_id.to_s(36) : 'unrendered'
        "adapter-#{suffix}"
      end

      # Formats an opaque diagnostic identity without exposing payload state.
      # @param handle [Handle, nil] component token or nil for the adapter
      # @return [String] opaque diagnostic label
      # @api private
      def handle_label(handle)
        handle ? "opaque-#{handle.object_id.to_s(36)}" : 'adapter'
      end

      # Reads the shared diagnostic label without changing lifecycle ownership.
      # @return [Object] owner ID, name or fallback label
      # @api private
      def owner_label
        Diagnostics.owner_label(@owner)
      end

      # Preserves attributed errors and adds adapter context to unscoped failures.
      # @param error [Exception] original failure
      # @param handle [Handle, nil] optional component token
      # @param field [Object, nil] optional failing property or operation
      # @return [Error] original attributed error or contextual replacement
      # @api private
      def attributed(error, handle = nil, field = nil)
        return error if error.is_a?(Error) && error.owner

        error_class = error.is_a?(Error) ? error.class : Error
        error_class.new(
          error.message, owner: owner_label, page_id: adapter_page_id,
          cid: handle && handle_label(handle), field: field
        )
      end

      # Builds an adapter failure carrying owner, page and optional component context.
      # @param message [String] failure description
      # @param handle [Handle, nil] optional component token
      # @param field [Object, nil] optional failing property or operation
      # @return [Error] contextual adapter error
      # @api private
      def attributed_error(message, handle = nil, field = nil)
        Error.new(
          message, owner: owner_label, page_id: adapter_page_id,
          cid: handle && handle_label(handle), field: field
        )
      end

      # Normalizes contract field names while retaining their supplied values.
      # @param hash [Hash] authored property or layout fields
      # @return [Hash{Symbol => Object}] normalized field map
      # @api private
      def symbolize(hash)
        hash.to_h { |key, value| [normalize_name(key), value] }
      end

      # Accepts symbol names or identifier-shaped strings and refuses other names.
      # @param value [Symbol, String] candidate contract name
      # @return [Symbol] normalized contract name
      # @api private
      def normalize_name(value)
        return value if value.is_a?(Symbol)
        return value.to_sym if value.is_a?(String) && value.match?(Contract::IDENTIFIER)

        raise ArgumentError, "invalid contract name #{value.inspect}"
      end
    end
  end
end

require_relative 'adapter/properties'
require_relative 'adapter/tree_mutation'
require_relative 'adapter/layout'
require_relative 'adapter/bindings'
require_relative 'adapter/render_tree'
require_relative 'adapter/publication'
