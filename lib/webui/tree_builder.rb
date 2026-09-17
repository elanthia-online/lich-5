# frozen_string_literal: true

require_relative 'component'
require_relative 'validator'

module Lich
  module WebUI
    # Declarative render builder. Variable collections are explicit so keyed identity is enforceable.
    #
    # A page's render block runs against one of these. Each contract type is
    # a method (`button(...)`, `text_input(...)`), each facility too
    # (`focus(...)`, `accelerators(...)`); nesting a block nests components.
    # {#build} validates the whole drafted tree and materializes it into
    # frozen {Component}s.
    class TreeBuilder
      # A component under construction, before validation of its children.
      Draft = Struct.new(:type, :cid, :props, :children, :slot, :placement, keyword_init: true)
      # The component types the `focus` facility may name.
      FOCUSABLE_TYPES = %i[
        button toggle checkbox radio text_input password_input textarea number_input slider select chips
        table dialog composite
      ].freeze

      # @!attribute [r] bindings
      #   @return [Hash{Array(String, Symbol) => #call}] event callbacks keyed by `[cid, event]`
      # @!attribute [r] submissions
      #   @return [Hash{String => Array<String>}] input cids each terminal submits, keyed by terminal cid
      # @!attribute [r] facilities
      #   @return [Hash{Symbol => Object}] validated page facilities
      attr_reader :bindings, :submissions, :facilities

      # Starts a tree with an empty page root.
      #
      # @param owner [Object] the page's owner, for error attribution
      # @param page_id [String] the page id
      # @param title [String] the page title
      # @param root_props [Hash{Symbol => Object}] other root page properties
      # @param validator [Validator] validates components, facilities and placements
      # @return [TreeBuilder]
      def initialize(owner:, page_id:, title:, root_props: {}, validator: Validator.new)
        @owner = owner
        @page_id = page_id
        @validator = validator
        @root = Draft.new(
          type: :page, cid: "page:#{page_id}", props: root_props.merge(title: title),
          children: [], placement: {}
        )
        @stack = [@root]
        @cids = { @root.cid => @root }
        @variable_parents = {}.compare_by_identity
        @bindings = {}
        @submissions = {}
        @facilities = {}
      end

      # Adds a component under the current parent; the typed methods forward here.
      #
      # @param type [Symbol, String] the contract component type
      # @param key [String, Symbol, Integer, nil] the author key; required inside a {#collection}
      # @param slot [String, Symbol, Integer, nil] the named slot this child fills in its parent
      # @param placement [Hash{Symbol, String => Object}] parent-defined placement properties
      # @param on [Hash{Symbol, String => #call}] event callbacks keyed by event name
      # @param submit [Array, Object, nil] the input components (or cids) this terminal submits
      # @param props [Hash{Symbol => Object}] the component's properties
      # @yield nested inside the new component; child calls attach to it
      # @return [Draft] the drafted component
      # @raise [UnknownTypeError] when the type is not in the contract
      # @raise [IdentityError] when the identity collides or a key is missing inside a collection
      # @raise [UnknownEventError] when +on+ names an event the type does not emit, or binds a
      #   value-bearing change on a sensitive input
      # @raise [SchemaViolationError] when the props fail validation or +submit+ is given on a
      #   non-terminal component
      # @raise [ArgumentError] when +on+ is not a Hash, a callback is not callable, or +slot+ or
      #   +placement+ has the wrong type
      def component(type, key: nil, slot: nil, placement: {}, on: {}, submit: nil, **props, &block)
        normalized_type = Contract.normalize_type(type)
        Contract.schema(normalized_type)
        parent = @stack.last
        require_collection_key!(parent, normalized_type, key)
        props = props.merge(key: key) unless key.nil?
        position = parent.children.length
        segment = key || position
        cid = "#{parent.cid}/#{normalized_type}:#{segment}"
        if @cids.key?(cid)
          raise IdentityError.new(
            "duplicate component identity for #{normalized_type}:#{segment}",
            owner: owner_label, page_id: @page_id, cid: cid
          )
        end

        validated_props = @validator.validate_component!(
          normalized_type, props, owner: owner_label, page_id: @page_id, cid: cid
        )
        draft = Draft.new(
          type: normalized_type, cid: cid, props: validated_props, children: [],
          slot: normalize_slot(slot), placement: normalize_placement(placement)
        )
        parent.children << draft
        @cids[cid] = draft
        register_bindings!(draft, on)
        register_submission!(draft, submit) if submit

        if block
          @stack << draft
          instance_exec(draft, &block)
          @stack.pop
        end
        draft
      ensure
        @stack.pop if block && @stack.last.equal?(draft)
      end

      # @!macro [attach] typed_component
      #   @!method $1(**props, &block)
      #     Adds a `$1` component; see {#component}.
      #     @param props [Hash{Symbol => Object}] the component's properties and the `key:`, `slot:`,
      #       `placement:`, `on:` and `submit:` options {#component} takes
      #     @return [Draft] the drafted component
      (Contract::TYPES - [:page]).each do |type|
        define_method(type) do |**props, &block|
          component(type, **props, &block)
        end
      end

      # Marks the children added inside the block as a variable collection, so each needs a key.
      #
      # @param items [#each] the items to iterate
      # @yield [item, index] once per item, inside the current parent
      # @yieldparam item [Object] the item
      # @yieldparam index [Integer] its position
      # @return [nil]
      # @raise [ArgumentError] when no block is given or +items+ is not enumerable
      # @raise [SchemaViolationError] when the collection exceeds the children bound
      def collection(items)
        raise ArgumentError, 'collection requires a block' unless block_given?
        raise ArgumentError, 'collection items must be enumerable' unless items.respond_to?(:each)

        parent = @stack.last
        count = 0
        items.each_with_index do |item, index|
          count += 1
          if count > Contract::BOUNDS[:children]
            raise SchemaViolationError.new(
              "collection exceeds #{Contract::BOUNDS[:children]} children",
              owner: owner_label, page_id: @page_id, cid: parent.cid, field: :children
            )
          end
          @variable_parents[parent] = @variable_parents.fetch(parent, 0) + 1
          yield item, index
        ensure
          depth = @variable_parents.fetch(parent, 1) - 1
          depth.zero? ? @variable_parents.delete(parent) : @variable_parents[parent] = depth
        end
        nil
      end

      # Sets a page facility; the named facility methods forward here.
      #
      # @param name [Symbol, String] the facility name
      # @param value [Object] its value, as the contract defines it
      # @return [nil]
      # @raise [ArgumentError] when the name is not an identifier
      # @raise [SchemaViolationError] when the value fails validation
      def facility(name, value)
        key = normalize_name(name)
        @facilities[key] = @validator.validate_facility!(
          key, value, owner: owner_label, page_id: @page_id, cid: @root.cid
        )
        nil
      end

      # @!macro [attach] named_facility
      #   @!method $1(value)
      #     Sets the `$1` facility; see {#facility}.
      #     @param value [Object] the facility value
      #     @return [nil]
      Contract::FACILITIES.each_key do |name|
        define_method(name) { |value| facility(name, value) }
      end

      # Validates the whole tree and materializes it.
      #
      # @return [Component] the frozen root component
      # @raise [SchemaViolationError] when the root props, a child rule, a bound, a submission scope, an
      #   accelerator, or the focus target is invalid
      def build
        root_props = @validator.validate_component!(
          :page, @root.props, owner: owner_label, page_id: @page_id, cid: @root.cid
        )
        @root.props = root_props
        validate_children!(@root, depth: 1)
        validate_submissions!
        validate_accelerators!
        validate_focus!
        materialize(@root)
      end

      private

      def require_collection_key!(parent, type, key)
        return unless @variable_parents[parent] && key.nil?

        raise IdentityError.new(
          "author key required for variable collection component #{type}",
          owner: owner_label, page_id: @page_id, cid: parent.cid, field: :key
        )
      end

      def register_bindings!(draft, on)
        raise ArgumentError, 'on must be a Hash' unless on.is_a?(Hash)

        allowed = Contract.schema(draft.type).fetch(:events)
        on.each do |event_name, callable|
          event_key = normalize_name(event_name)
          unless allowed.key?(event_key)
            raise UnknownEventError.new(
              "unknown event #{event_name.inspect} for #{draft.type}",
              owner: owner_label, page_id: @page_id, cid: draft.cid, field: event_name
            )
          end
          # 2.18: a password's change carries no payload, so binding it
          # discloses nothing; a sensitive text_input's change would.
          if draft.props[:sensitive] == true && event_key == :change && allowed.fetch(event_key)[:payload]
            raise UnknownEventError.new(
              'sensitive components cannot bind value-bearing change events',
              owner: owner_label, page_id: @page_id, cid: draft.cid, field: event_name
            )
          end
          raise ArgumentError, "callback for #{event_name} must respond to call" unless callable.respond_to?(:call)

          @bindings[[draft.cid, event_key]] = callable
        end
      end

      def register_submission!(draft, submit)
        events = Contract.schema(draft.type).fetch(:events)
        unless events.key?(:submit) || events.key?(:activate) || events.key?(:response)
          raise SchemaViolationError.new(
            'submission scope requires a terminal component',
            owner: owner_label, page_id: @page_id, cid: draft.cid, field: :submit
          )
        end
        values = Array(submit)
        @submissions[draft.cid] = values.map { |value| value.respond_to?(:cid) ? value.cid : value.to_s }.freeze
      end

      def validate_submissions!
        @submissions.each do |terminal_cid, input_cids|
          input_cids.each do |input_cid|
            input = @cids[input_cid]
            unless input && Contract.schema(input.type)[:value]
              raise SchemaViolationError.new(
                "submission names unknown or non-input cid #{input_cid}",
                owner: owner_label, page_id: @page_id, cid: terminal_cid, field: :submit
              )
            end
          end
        end
      end

      def validate_accelerators!
        Array(@facilities[:accelerators]).each do |accelerator|
          target = accelerator[:target]
          event = accelerator[:event].to_sym
          unless @bindings.key?([target, event])
            raise SchemaViolationError.new(
              'accelerator target/event is not server-registered',
              owner: owner_label, page_id: @page_id, cid: target, field: :accelerators
            )
          end
        end
      end

      def validate_focus!
        target = @facilities[:focus]
        return unless target

        component = @cids[target]
        return if component && FOCUSABLE_TYPES.include?(component.type)

        raise SchemaViolationError.new(
          'focus target is unknown or non-focusable',
          owner: owner_label, page_id: @page_id, cid: target, field: :focus
        )
      end

      def validate_children!(draft, depth:)
        if depth > Contract::BOUNDS[:tree_depth]
          raise SchemaViolationError.new(
            "tree depth exceeds #{Contract::BOUNDS[:tree_depth]}",
            owner: owner_label, page_id: @page_id, cid: draft.cid, field: :children
          )
        end
        if draft.children.length > Contract::BOUNDS[:children]
          raise SchemaViolationError.new(
            "children exceed #{Contract::BOUNDS[:children]}",
            owner: owner_label, page_id: @page_id, cid: draft.cid, field: :children
          )
        end

        child_rule = Contract.schema(draft.type).fetch(:children)
        case child_rule
        when :none
          child_violation!(draft, 'component accepts no children') unless draft.children.empty?
        when :many
          nil
        when Hash
          validate_named_children!(draft, child_rule)
        end
        child_violation!(draft, 'page cannot be nested') if draft.children.any? { |child| child.type == :page }
        validate_menu_children!(draft)
        if draft.type == :grid && draft.props[:cells] && draft.children.length > draft.props[:cells]
          child_violation!(draft, 'grid children exceed declared cells')
        end
        validate_child_placements!(draft)
        draft.children.each { |child| validate_children!(child, depth: depth + 1) }
      end

      # A menu holds items; an item holds at most one submenu.
      # @api private
      def validate_menu_children!(draft)
        case draft.type
        when :menu
          child_violation!(draft, 'menu children must be menu_item') if draft.children.any? { |child| child.type != :menu_item }
        when :menu_item
          child_violation!(draft, 'menu_item children must be menu') if draft.children.any? { |child| child.type != :menu }
          child_violation!(draft, 'menu_item holds at most one submenu') if draft.children.length > 1
        end
      end

      def validate_named_children!(draft, rule)
        slots = case rule.fetch(:kind)
                when :named then rule.fetch(:slots)
                when :named_dynamic then Array.new(draft.props.fetch(rule.fetch(:count_property))) { |index| index.to_s }
                when :named_from_property then draft.props.fetch(rule.fetch(:property)).map(&:to_s)
                else []
                end
        actual = draft.children.map { |child| child.slot&.to_s }
        child_violation!(draft, 'named children require a slot') if actual.any?(&:nil?)
        child_violation!(draft, 'child slot is unknown') unless (actual - slots).empty?
        child_violation!(draft, 'child slots must be unique') unless actual.uniq.length == actual.length
      end

      def validate_child_placements!(draft)
        definitions = Contract.schema(draft.type)[:child_properties] || {}
        draft.children.each do |child|
          unknown = child.placement.keys - definitions.keys
          child_violation!(draft, "unknown child placement #{unknown.first}") unless unknown.empty?
          child.placement.each do |name, value|
            definition = definitions.fetch(name)
            shape = definition.fetch(:shape)
            shape = shape.merge(max: draft.props.fetch(shape[:max_property])) if shape[:max_property]
            @validator.validate_placement!(
              name, shape, value, owner: owner_label, page_id: @page_id, cid: child.cid
            )
          end
        end
      end

      def child_violation!(draft, message)
        raise SchemaViolationError.new(
          message, owner: owner_label, page_id: @page_id, cid: draft.cid, field: :children
        )
      end

      def materialize(draft)
        Component.new(
          type: draft.type, cid: draft.cid, props: draft.props,
          children: draft.children.map { |child| materialize(child) },
          slot: draft.slot, placement: draft.placement
        )
      end

      def normalize_slot(slot)
        return nil if slot.nil?
        return slot.to_s if slot.is_a?(String) || slot.is_a?(Symbol) || slot.is_a?(Integer)

        raise ArgumentError, 'slot must be a String, Symbol, or Integer'
      end

      def normalize_placement(placement)
        raise ArgumentError, 'placement must be a Hash' unless placement.is_a?(Hash)
        placement.to_h { |key, value| [normalize_name(key), value] }
      end

      def normalize_name(name)
        return name if name.is_a?(Symbol)
        return name.to_sym if name.is_a?(String) && name.match?(Contract::IDENTIFIER)

        raise ArgumentError, "invalid name #{name.inspect}"
      end

      def owner_label
        return @owner.webui_owner_id if @owner.respond_to?(:webui_owner_id)
        return @owner.name if @owner.respond_to?(:name) && @owner.name

        "#{@owner.class}:#{@owner.object_id}"
      end
    end
  end
end
