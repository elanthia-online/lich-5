# frozen_string_literal: true

require_relative 'tree_builder'

module Lich
  module WebUI
    # Core page definition and monotonic render source.
    #
    # A page is an owner, an id, a title, and a render block. Each {#render}
    # runs the block against a fresh {TreeBuilder}, validates the result, and
    # stamps it with the next generation, so a viewer and the runtime can tell
    # a stale tree from the current one. Property reads and writes go through
    # the bound {Runtime}, which knows which viewers are attached.
    class Page
      # One rendered generation of a page.
      #
      # @!attribute [r] page_id
      #   @return [String] the page id
      # @!attribute [r] generation
      #   @return [Integer] the render generation, increasing by one per render
      # @!attribute [r] tree
      #   @return [Component] the root component
      # @!attribute [r] bindings
      #   @return [Hash{Array(String, Symbol) => #call}] event callbacks keyed by `[cid, event]`
      # @!attribute [r] submissions
      #   @return [Hash{String => Array<String>}] input cids each terminal submits, keyed by terminal cid
      # @!attribute [r] facilities
      #   @return [Hash{Symbol => Object}] page facilities
      Render = Data.define(:page_id, :generation, :tree, :bindings, :submissions, :facilities) do
        # The wire form of this render, without the server-side bindings and submissions.
        #
        # @return [Hash{Symbol => Object}] `page_id`, `generation`, `tree`, `facilities`
        def to_h
          {
            page_id: page_id, generation: generation, tree: tree.to_h,
            facilities: facilities,
          }
        end
      end

      # @!attribute [r] owner
      #   @return [Object] the script or core object that owns the page
      # @!attribute [r] id
      #   @return [String] the page id, unique per owner
      # @!attribute [r] title
      #   @return [String] the window title
      # @!attribute [r] lifecycle_bindings
      #   @return [Hash{Symbol => #call}] page lifecycle callbacks keyed by event
      attr_reader :owner, :id, :title, :lifecycle_bindings

      # Defines a page; nothing renders until {#render}.
      #
      # @param owner [Object] the script or core object that owns the page
      # @param id [String] page identifier matching the contract identifier syntax
      # @param title [String] window title
      # @param props [Hash{Symbol => Object}] root page properties
      # @param validator [Validator] validates every rendered component
      # @param on [Hash{Symbol, String => #call}] page lifecycle callbacks keyed by event name
      # @yield the render block, evaluated against a {TreeBuilder} on every render
      # @return [Page] the page
      # @raise [ArgumentError] when the owner, id, title, or render block is missing or malformed
      # @raise [UnknownEventError] when +on+ names an event that is not a page lifecycle event
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
        # Set by the modal coordinator. A viewer scoped to one page needs to
        # know that another page is a dialog its own script raised, and the
        # descriptor is broadcast before the page has rendered, so this
        # cannot be read back out of the tree.
        @modal = false
      end

      # Whether this page is a modal dialog rather than a script window.
      #
      # @return [Boolean]
      attr_accessor :modal

      # The generation of the most recent render.
      #
      # @return [Integer] 0 before the first render
      def generation
        @mutex.synchronize { @generation }
      end

      # The most recent render.
      #
      # @return [Render, nil] nil before the first render
      def last_render
        @mutex.synchronize { @last_render }
      end

      # Runs the render block and produces the next generation.
      #
      # @return [Render] the new render
      # @raise [SchemaViolationError] when the tree fails validation or exceeds the component bound
      # @raise [IdentityError] when two components share an identity
      def render
        @render_mutex.synchronize do
          generation, root_props, shared_values = @mutex.synchronize do
            @generation += 1
            [@generation, @root_props.dup, @shared_values.dup]
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
          render = Render.new(
            id, generation, tree, builder.bindings.freeze,
            builder.submissions.freeze, builder.facilities.freeze
          )
          @mutex.synchronize { @last_render = render }
          render
        end
      end

      # Updates adapter-owned page metadata without exposing renderer state through a handle.
      #
      # @param title [String] the new window title
      # @param props [Hash{Symbol => Object}] the new root page properties
      # @param on [Hash{Symbol, String => #call}] the new page lifecycle callbacks
      # @return [Page] self
      # @raise [ArgumentError] when +title+ is not a String or +on+ is malformed
      # @raise [UnknownEventError] when +on+ names an event that is not a page lifecycle event
      def refresh_definition(title:, props:, on:)
        raise ArgumentError, 'title must be a String' unless title.is_a?(String)

        @mutex.synchronize do
          @title = title.dup.freeze
          @root_props = props.dup
          @lifecycle_bindings = validate_lifecycle_bindings(on)
        end
        self
      end

      # Attaches the page to the runtime that will serve it.
      #
      # @param runtime [Runtime] the runtime
      # @return [Page] self
      # @raise [Error] when the page is already bound to a different runtime
      def bind_runtime(runtime)
        @mutex.synchronize do
          if @runtime && !@runtime.equal?(runtime)
            raise Error.new('page is already bound to another runtime', owner: owner_label, page_id: id)
          end

          @runtime = runtime
        end
        self
      end

      # Reads a component property through the runtime.
      #
      # @param cid [String] the component identity
      # @param property [Symbol, String] the property name
      # @param viewer [String, nil] the viewer whose copy to read, for viewer-scoped properties
      # @return [Object] the value
      # @raise [Error] when the page is not bound to a runtime
      # @raise [SensitiveReadError] when the property is write-only
      # @raise [AmbiguousViewerError] when a viewer-scoped read names no viewer and several are attached
      def get(cid, property = :value, viewer: nil)
        bound_runtime.read(self, cid, property, viewer: viewer)
      end

      # Writes a component property through the runtime.
      #
      # @param cid [String] the component identity
      # @param property [Symbol, String] the property name
      # @param value [Object] the new value
      # @param viewer [String, nil] the viewer whose copy to write, for viewer-scoped properties
      # @return [Object] what the runtime's write returns
      # @raise [Error] when the page is not bound to a runtime
      def set(cid, property, value, viewer: nil)
        bound_runtime.write(self, cid, property, value, viewer: viewer)
      end

      # Which presentation properties the host can honour.
      #
      # @return [Hash{Symbol => Boolean}] support per presentation property
      # @raise [Error] when the page is not bound to a runtime
      def presentation_support
        bound_runtime.presentation_support(self)
      end

      # The facilities this page asked for that the host could not honour.
      #
      # @return [Array<Hash>] the recorded degradations
      # @raise [Error] when the page is not bound to a runtime
      def degradations
        bound_runtime.degradations(self)
      end

      # A shared (all-viewer) value written since the last render.
      #
      # @param cid [String, #to_s] the component identity
      # @param property [Symbol, #to_sym] the property name
      # @param fallback [Object] returned when nothing has been written
      # @return [Object] the value or the fallback
      def fetch_shared_value(cid, property, fallback)
        @mutex.synchronize { @shared_values.fetch([cid.to_s, property.to_sym], fallback) }
      end

      # Records a shared (all-viewer) value to overlay on the next render.
      #
      # @param cid [String, #to_s] the component identity
      # @param property [Symbol, #to_sym] the property name
      # @param value [Object] the value
      # @return [Object] the value
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

      # Re-validates the tree with shared values written since the last render merged in.
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
        return owner.webui_owner_id if owner.respond_to?(:webui_owner_id)
        return owner.name if owner.respond_to?(:name) && owner.name

        "#{owner.class}:#{owner.object_id}"
      end
    end
  end
end
