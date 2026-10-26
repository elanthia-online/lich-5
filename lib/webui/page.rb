# frozen_string_literal: true

require_relative 'tree_builder'
require_relative 'theme'
require_relative 'monitor_geometry'

module Lich
  module WebUI
    # Core page definition and monotonic render source.
    class Page
      Render = Data.define(:page_id, :generation, :tree, :bindings, :submissions, :facilities) do
        # Serializes a render snapshot before per-viewer state is overlaid.
        # @return [Hash] generation, tree, facilities, and owner-local page ID
        def to_h
          {
            page_id: page_id, generation: generation, tree: tree.to_h,
            facilities: facilities,
          }
        end
      end

      attr_reader :owner, :id, :title, :lifecycle_bindings

      # Stores only validated, bounded per-viewer monitor hints, separate from window state.
      # @return [void]
      def observe_monitors(viewer, snapshot)
        @mutex.synchronize do
          @monitor_snapshots ||= {}
          @monitor_snapshots.shift if !@monitor_snapshots.key?(viewer) && @monitor_snapshots.size >= 64
          @monitor_snapshots[viewer] = MonitorGeometry.normalize(snapshot)
        end
      end

      # @return [Hash, nil] immutable snapshot for this viewer only
      def monitor_snapshot(viewer)
        @mutex.synchronize { @monitor_snapshots&.[](viewer) }
      end

      # Retires a viewer's disposable monitor hints on detach.
      # @return [void]
      def forget_monitors(viewer)
        @mutex.synchronize { @monitor_snapshots&.delete(viewer) }
      end

      # Defines an owner-scoped page without rendering, registering, or opening it.
      # @param owner [Object] server-side lifecycle identity
      # @param id [String] contract identifier unique within that owner
      # @param title [String] window title
      # @param props [Hash] root component properties
      # @param validator [Validator] contract validator
      # @param on [Hash] lifecycle event callbacks
      # @yield render DSL evaluated for each refresh
      # @raise [ArgumentError] for missing owner/block or invalid ID/title
      def initialize(owner:, id:, title:, props: {}, validator: Validator.new, on: {}, &render_block)
        raise ArgumentError, 'owner is required' if owner.nil?
        unless id.is_a?(String) && id.match?(Contract::IDENTIFIER)
          raise ArgumentError, 'id must match the contract identifier syntax'
        end
        raise ArgumentError, 'title must be a String' unless title.is_a?(String)
        raise ArgumentError, 'render block is required' unless render_block

        @owner = owner
        @id = id.dup.freeze
        @title = title.dup.freeze
        @root_props = props.dup
        @validator = validator
        @lifecycle_bindings = validate_lifecycle_bindings(on)
        @render_block = render_block
        @generation = 0
        @mutex = Mutex.new
        @render_mutex = Mutex.new
        @last_render = nil
        @runtime = nil
        @shared_values = {}
        @window_geometry = nil
      end

      # Reads the allocated render generation under the page lock. Allocation
      # precedes author rendering and validation, so failed renders advance it too.
      # @return [Integer] zero before the first render attempt
      def generation
        @mutex.synchronize { @generation }
      end

      # Reads the latest successful render without evaluating the render block.
      # @return [Render, nil] nil until a render succeeds; failures retain the prior result
      def last_render
        @mutex.synchronize { @last_render }
      end

      # Host measurements survive page removal so a script's exit cleanup can
      # read the final content size and desktop position without a live viewer.
      def window_geometry
        @mutex.synchronize { @window_geometry&.dup }
      end

      # Retains validated viewer geometry, copying and freezing desktop coordinates.
      # @param value [Hash] width, height, and position from a configure event
      # @return [void]
      def observe_window_geometry(value)
        @mutex.synchronize { @window_geometry = value.except(:monitors).merge(position: value.fetch(:position).dup.freeze).freeze }
      end

      # Stages host-restored geometry for subsequent rendering.
      # @param value [Hash, nil] saved geometry, or nil to clear the host override
      # @return [void]
      def restore_window_geometry(value)
        @mutex.synchronize { @host_geometry = value&.dup }
      end

      # Builds a fresh tree with the application theme unless explicitly styled.
      # Viewer drafts and authored color/font overrides retain their own scope.
      # @return [Render] validated tree, callbacks and submission scopes
      def render
        @render_mutex.synchronize do
          generation, root_props, shared_values = @mutex.synchronize do
            @generation += 1
            props = { theme: Theme.current }.merge(@root_props)
            if @host_geometry
              props[:size] = @host_geometry.values_at(:width, :height)
              props[:position] = @host_geometry[:position] if @host_geometry[:position]
            end
            [@generation, props, @shared_values.dup]
          end
          builder = TreeBuilder.new(
            owner: owner, page_id: id, title: title, root_props: root_props, validator: @validator
          )
          builder.instance_exec(builder, &@render_block)
          tree = apply_shared_values(builder.build, shared_values)
          if tree.each.count > Contract::BOUNDS[:components]
            raise SchemaViolationError.new(
              "page exceeds #{Contract::BOUNDS[:components]} components",
              owner: owner_label, page_id: id, cid: tree.cid, field: :children
            )
          end
          # Lifecycle callbacks previously never reached the browser bindings.
          # Geometry and native state are browser reports; close/attach/detach stay under
          # the runtime's lifecycle delivery and close-once guard.
          bindings = builder.bindings.merge(
            [tree.cid, :configure] => lifecycle_bindings.fetch(:configure, proc {})
          )
          browser_events = Contract::PAGE_LIFECYCLE_EVENTS.keys - %i[configure close attach detach]
          # Preserve the existing binding order: window-state reports precede input.
          browser_events.partition { |event| event == :window_state }.flatten.each do |event|
            bindings[[tree.cid, event]] = lifecycle_bindings[event] if lifecycle_bindings.key?(event)
          end
          render = Render.new(
            id, generation, tree, bindings.freeze,
            builder.submissions.freeze, builder.facilities.freeze
          )
          @mutex.synchronize { @last_render = render }
          render
        end
      end

      # Updates adapter-owned page metadata without exposing renderer state through a handle.
      def refresh_definition(title:, props:, on:)
        raise ArgumentError, 'title must be a String' unless title.is_a?(String)

        @mutex.synchronize do
          @title = title.dup.freeze
          @root_props = props.dup
          @lifecycle_bindings = validate_lifecycle_bindings(on)
        end
        self
      end

      # Binds a page once; repeated binding to that same runtime is safe.
      # @param runtime [Runtime] host runtime responsible for this page's state and events
      # @return [Page] self
      # @raise [Error] if a different runtime already owns the page
      def bind_runtime(runtime)
        @mutex.synchronize do
          if @runtime && !@runtime.equal?(runtime)
            raise Error.new('page is already bound to another runtime', owner: owner_label, page_id: id)
          end

          @runtime = runtime
        end
        self
      end

      # Reads a property using the runtime's shared/viewer ownership rules.
      # @param cid [String] component ID from the current render
      # @param property [Symbol] contract property name
      # @param viewer [String, nil] explicit viewer ID, or current callback context
      # @return [Object] current value
      # @raise [SensitiveReadError] for a write-only sensitive property
      # @see Runtime#read
      # @example Read one attached viewer's draft outside a callback
      #   page.get(input.cid, :value, viewer: viewer_id)
      def get(cid, property = :value, viewer: nil)
        bound_runtime.read(self, cid, property, viewer: viewer)
      end

      # Validates a property write and schedules a refresh through the bound runtime.
      # @param cid [String] component ID from the current render
      # @param property [Symbol] contract property name
      # @param value [Object] proposed value
      # @param viewer [String, nil] explicit viewer ID, or current callback context
      # @return [nil]
      # @see Runtime#write
      def set(cid, property, value, viewer: nil)
        bound_runtime.write(self, cid, property, value, viewer: viewer)
      end

      # Reports host presentation capabilities, which may differ by platform.
      # @return [Hash{Symbol => Boolean}] supported requests
      def presentation_support
        bound_runtime.presentation_support(self)
      end

      # Snapshots presentation degradations recorded by the runtime.
      # @return [Array<Hash>] copied notices
      def degradations
        bound_runtime.degradations(self)
      end

      # Reads a server-owned override, falling back to the rendered property.
      # @return [Object] override or fallback
      # @api private
      def fetch_shared_value(cid, property, fallback)
        @mutex.synchronize { @shared_values.fetch([cid.to_s, property.to_sym], fallback) }
      end

      # Stores a server-owned override; the runtime performs validation and refresh.
      # @return [Object] stored value
      # @api private
      def write_shared_value(cid, property, value)
        @mutex.synchronize { @shared_values[[cid.to_s, property.to_sym]] = value }
      end

      private

      def validate_lifecycle_bindings(bindings)
        raise ArgumentError, 'on must be a Hash' unless bindings.is_a?(Hash)

        bindings.each_with_object({}) do |(name, callback), result|
          event = name.to_sym
          unless Contract::PAGE_LIFECYCLE_EVENTS.key?(event)
            raise UnknownEventError.new(
              "unknown page lifecycle event #{name.inspect}", owner: owner_label, page_id: id, field: name
            )
          end
          raise ArgumentError, "callback for #{name} must respond to call" unless callback.respond_to?(:call)

          result[event] = callback
        end.freeze
      end

      def bound_runtime
        @mutex.synchronize { @runtime } || raise(Error.new('page is not bound to a runtime', owner: owner_label, page_id: id))
      end

      def apply_shared_values(component, shared_values)
        overrides = shared_values.each_with_object({}) do |((cid, property), value), result|
          (result[cid] ||= {})[property] = value
        end
        apply_component_values(component, overrides)
      end

      def apply_component_values(component, overrides)
        props = component.props.merge(overrides.fetch(component.cid, {}))
        validated = @validator.validate_component!(
          component.type, props, owner: owner_label, page_id: id, cid: component.cid
        )
        Component.new(
          type: component.type, cid: component.cid, props: validated,
          children: component.children.map { |child| apply_component_values(child, overrides) },
          slot: component.slot, placement: component.placement
        )
      end

      def owner_label
        Diagnostics.owner_label(owner)
      end
    end
  end
end
