# frozen_string_literal: true

require_relative 'tree_builder'

module Lich
  module WebUI
    # Core page definition and monotonic render source.
    class Page
      Render = Data.define(:page_id, :generation, :tree, :bindings, :submissions, :facilities) do
        def to_h
          {
            page_id: page_id, generation: generation, tree: tree.to_h,
            facilities: facilities,
          }
        end
      end

      attr_reader :owner, :id, :title, :lifecycle_bindings

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
      end

      def generation
        @mutex.synchronize { @generation }
      end

      def last_render
        @mutex.synchronize { @last_render }
      end

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
      def refresh_definition(title:, props:, on:)
        raise ArgumentError, 'title must be a String' unless title.is_a?(String)

        @mutex.synchronize do
          @title = title.dup.freeze
          @root_props = props.dup
          @lifecycle_bindings = validate_lifecycle_bindings(on)
        end
        self
      end

      def bind_runtime(runtime)
        @mutex.synchronize do
          if @runtime && !@runtime.equal?(runtime)
            raise Error.new('page is already bound to another runtime', owner: owner_label, page_id: id)
          end

          @runtime = runtime
        end
        self
      end

      def get(cid, property = :value, viewer: nil)
        bound_runtime.read(self, cid, property, viewer: viewer)
      end

      def set(cid, property, value, viewer: nil)
        bound_runtime.write(self, cid, property, value, viewer: viewer)
      end

      def presentation_support
        bound_runtime.presentation_support(self)
      end

      def degradations
        bound_runtime.degradations(self)
      end

      def fetch_shared_value(cid, property, fallback)
        @mutex.synchronize { @shared_values.fetch([cid.to_s, property.to_sym], fallback) }
      end

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
        return owner.webui_owner_id if owner.respond_to?(:webui_owner_id)
        return owner.name if owner.respond_to?(:name) && owner.name

        "#{owner.class}:#{owner.object_id}"
      end
    end
  end
end
