# frozen_string_literal: true

require_relative 'component'
require_relative 'validator'

module Lich
  module WebUI
    # Declarative render builder. Variable collections are explicit so keyed identity is enforceable.
    class TreeBuilder
      Draft = Struct.new(:type, :cid, :props, :children, :slot, :placement, keyword_init: true)
      FOCUSABLE_TYPES = %i[
        button toggle checkbox radio radio_option text_input password_input textarea number_input slider select
        table dialog composite
      ].freeze

      attr_reader :bindings, :submissions, :facilities

      # Sets the page palette from render-time state (for example a launcher
      # preference toggle). The ordinary page schema validates the value.
      # @param value [Symbol, String] light or dark
      # @return [Symbol, String] supplied palette
      def theme(value)
        @root.props[:theme] = value
      end

      # Composes a setup notice and action without owning Save/Close behavior.
      # Pass a SettingsForm layout's save callable to retain its submission scope.
      # @param notice [String] caller's exact notice text
      # @param action [#call] renders the action with this builder and keywords
      # @param label [String] caller's action label
      # @param notice_props [Hash] text properties, including margins and wrapping
      # @param action_props [Hash] action properties, including margins and sizing
      # @param columns_props [Hash] overrides for the existing columns control
      # @return [Draft] footer columns
      def setup_footer(notice:, action:, label: 'Close', notice_props: {}, action_props: {}, **columns_props)
        columns(**{ count: 2, compact: true, weights: [5, 1], gap: 0 }.merge(columns_props)) do
          text(**{ font_style: :italic, content: notice, slot: '0' }.merge(notice_props))
          action.call(self, **{ label: label, slot: '1', align: :end }.merge(action_props))
        end
      end

      # Starts one render with a page root and fresh identity, binding, and submission indexes.
      # @param owner [Object] server-owned identity used for diagnostics
      # @param page_id [String] owner-local page identifier
      # @param title [String] root title
      # @param root_props [Hash] additional root properties
      # @param validator [Validator] shared contract validator
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

      # Adds a validated control under the current parent and evaluates its children.
      # Stable keys are mandatory inside variable collections; positional IDs serve fixed layouts.
      # @param type [Symbol, String] contract component type
      # @param key [String, nil] stable author identity within the parent
      # @param slot [Symbol, String, nil] parent-defined child slot
      # @param placement [Hash] parent-specific layout hints
      # @param on [Hash] supported event names mapped to callbacks
      # @param submit [Array<Draft>, nil] inputs captured by a terminal action
      # @param props [Hash] component properties
      # @yield [draft] child composition evaluated in this builder
      # @return [Draft] reference usable in submissions
      # @raise [IdentityError] for missing collection keys or duplicate identity
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

      (Contract::TYPES - [:page]).each do |type|
        define_method(type) do |**props, &block|
          component(type, **props, &block)
        end
      end

      # Plain text can exceed a single wire field (for example, repository
      # comments). Keep the authored string intact while sending bounded
      # fragments through the existing text-component contract.
      def text(content:, **props)
        if content.is_a?(String) && !props.key?(:fragments)
          bounded = Contract.fragment_text(content, bound: :body_text)
          if bounded.is_a?(Array)
            props[:fragments] = bounded
            content = ''
          end
        end
        component(:text, content: content, **props)
      end

      # Builds variable children while requiring explicit keys and enforcing cardinality.
      # @param items [Enumerable] caller-owned items; order is retained
      # @yield [item, index] composition for each item
      # @return [nil]
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

      # Validates and records a page facility such as presentation or accelerators.
      # @return [nil]
      def facility(name, value)
        key = normalize_name(name)
        @facilities[key] = @validator.validate_facility!(
          key, value, owner: owner_label, page_id: @page_id, cid: @root.cid
        )
        nil
      end

      # Bind an action after its fields have been rendered. This permits buttons
      # above or beside their inputs while retaining the same checked, explicit
      # submission scope as the component's submit: keyword.
      # @param terminal [Draft] terminal action created by this builder
      # @param inputs [Array<Draft, String>] input drafts or component IDs to snapshot
      # @return [nil]
      # @raise [ArgumentError] if the action does not belong to this builder
      # @example Bind an action to an input rendered after it
      #   action = builder.button(key: 'load', label: 'Load')
      #   name = builder.text_input(key: 'name', value: '')
      #   builder.submit(action, [name])
      def submit(terminal, inputs)
        unless terminal.respond_to?(:cid) && @cids[terminal.cid].equal?(terminal)
          raise ArgumentError, 'submission terminal must belong to this builder'
        end

        register_submission!(terminal, inputs)
        nil
      end

      Contract::FACILITIES.each_key do |name|
        define_method(name) { |value| facility(name, value) }
      end

      # Validates cross-component relationships, then freezes the draft as a render tree.
      # Checks child placement, submissions, accelerators, and focus before publication.
      # @return [Component] immutable page root
      def build
        root_props = @validator.validate_component!(
          :page, @root.props, owner: owner_label, page_id: @page_id, cid: @root.cid
        )
        @root.props = root_props
        validate_children!(@root, depth: 1)
        validate_submissions!
        validate_accelerators!
        validate_focus!
        selected_groups = @cids.values.select { |draft| draft.type == :radio_option && draft.props[:checked] }.group_by { |draft| draft.props[:group] }
        if selected_groups.any? { |_group, members| members.length > 1 }
          raise SchemaViolationError.new('radio group has multiple selected options', owner: owner_label, page_id: @page_id, field: :checked)
        end
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
          if draft.props[:sensitive] == true && event_key == :change
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
        if @facilities[:focus_revision] && !target
          raise SchemaViolationError.new('focus revision requires a focus target', owner: owner_label, page_id: @page_id, field: :focus_revision)
        end
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
        if draft.type == :grid && draft.props[:cells] && draft.children.length > draft.props[:cells]
          child_violation!(draft, 'grid children exceed declared cells')
        end
        validate_child_placements!(draft)
        draft.children.each { |child| validate_children!(child, depth: depth + 1) }
      end

      def validate_named_children!(draft, rule)
        if rule[:types] && draft.children.any? { |child| !rule[:types].include?(child.type) }
          child_violation!(draft, 'child type is not permitted')
        end
        slots = Contract.child_slots(rule, draft.props)
        children = draft.children
        if draft.type == :tabs
          actions, children = children.partition { |child| child.placement.key?(:tab_action) }
          sides = actions.map { |child| child.placement[:tab_action].to_s }
          child_violation!(draft, 'tab actions must be unique and have no page slot') if sides.uniq.length != sides.length || actions.any?(&:slot)
        end
        actual = children.map { |child| child.slot&.to_s }
        child_violation!(draft, 'named children require a slot') if actual.any?(&:nil?)
        child_violation!(draft, 'child slot is unknown') unless (actual - slots).empty?
        child_violation!(draft, 'child slots must be unique') unless actual.uniq.length == actual.length
      end

      def validate_child_placements!(draft)
        if draft.type == :grid && draft.props[:row_sizing].to_s == 'spread'
          unless draft.children.all? { |child| child.placement.key?(:row) }
            child_violation!(draft, 'spread grid sizing requires an explicit row for every child')
          end
        end
        definitions = Contract.schema(draft.type)[:child_properties] || {}
        draft.children.each do |child|
          unknown = child.placement.keys - definitions.keys
          child_violation!(draft, "unknown child placement #{unknown.first}") unless unknown.empty?
          child.placement.each do |name, value|
            definition = definitions.fetch(name)
            shape = Contract.child_placement_shape(definition.fetch(:shape), draft.props)
            @validator.validate_placement!(
              name, shape, value, owner: owner_label, page_id: @page_id, cid: child.cid
            )
          end
          case Contract.child_placement_condition(draft.type, draft.props, child.placement)
          when :grid_row_overflow
            child_violation!(draft, 'child placement exceeds grid rows')
          when :unpositioned_coordinates
            child_violation!(draft, 'coordinates require a positioned overlay')
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
        Diagnostics.owner_label(@owner)
      end
    end
  end
end
