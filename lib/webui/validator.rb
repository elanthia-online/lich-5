# frozen_string_literal: true

require_relative 'contract'

module Lich
  module WebUI
    # Validates component properties, event payloads, facilities, and cross-field invariants.
    class Validator
      Context = Data.define(:owner, :page_id, :cid)

      # Validates property names/shapes/defaults and type-specific relationships.
      # @param type [Symbol, String] contracted component type
      # @param props [Hash] authored properties, before normalization and defaults
      # @param owner [Object] diagnostic owner identity
      # @param page_id [String] diagnostic page identity
      # @param cid [String] diagnostic component identity
      # @return [Hash] normalized, frozen properties
      # @raise [Error] for unknown types/properties or invalid values
      def validate_component!(type, props, owner:, page_id:, cid:)
        normalized_type = Contract.normalize_type(type)
        schema = Contract.schema(normalized_type)
        context = Context.new(owner, page_id, cid)
        normalized = validate_properties(schema.fetch(:properties), props, context)
        validate_component_invariants!(normalized_type, normalized, context)
        normalized.freeze
      end

      # Validates a supported event payload against the current control properties.
      # This checks dynamic limits and choices as well as the static payload shape.
      # @param type [Symbol, String] contracted component type
      # @param event_name [Symbol, String] supported event name
      # @param payload [Hash, nil] submitted event fields, or nil for a payload-free event
      # @param props [Hash] current validated control properties
      # @param owner [Object] diagnostic owner identity
      # @param page_id [String] diagnostic page identity
      # @param cid [String] diagnostic component identity
      # @return [Hash] validated payload
      # @raise [UnknownEventError] for an unsupported event
      # @raise [SchemaViolationError] for invalid payloads
      def validate_event!(type, event_name, payload, props:, owner:, page_id:, cid:)
        normalized_type = Contract.normalize_type(type)
        schema = Contract.schema(normalized_type)
        event_key = normalize_name(event_name)
        event_schema = schema.fetch(:events)[event_key]
        context = Context.new(owner, page_id, cid)
        unless event_schema
          raise UnknownEventError.new(
            "unknown event #{event_name.inspect} for #{normalized_type}",
            **error_context(context, event_name)
          )
        end

        shape = event_schema.fetch(:payload)
        validated = if shape.nil?
                      unless payload.nil? || payload == {}
                        violation!('event accepts no payload', context, event_name)
                      end
                      {}
                    else
                      validate_shape(shape, payload, context, event_name.to_s)
                    end
        validate_event_invariants!(normalized_type, event_key, validated, props, context)
        validated
      end

      # Validates a supported page facility with owner/page diagnostic attribution.
      # @param name [Symbol, String] contracted facility name
      # @param value [Object] authored facility value
      # @param owner [Object] diagnostic owner identity
      # @param page_id [String] diagnostic page identity
      # @param cid [String, nil] optional diagnostic component identity
      # @return [Object] normalized facility value
      # @raise [UnknownPropertyError] for an unsupported facility
      def validate_facility!(name, value, owner:, page_id:, cid: nil)
        key = normalize_name(name)
        facility = Contract::FACILITIES[key]
        context = Context.new(owner, page_id, cid)
        unless facility
          raise UnknownPropertyError.new("unknown page facility #{name.inspect}", **error_context(context, name))
        end

        validate_shape(facility.fetch(:shape), value, context, name.to_s)
      end

      # Validates a submitted input against both its shape and current choices/range.
      # @param type [Symbol, String] contracted input component type
      # @param value [Object] submitted input value
      # @param props [Hash] current validated control properties
      # @param owner [Object] diagnostic owner identity
      # @param page_id [String] diagnostic page identity
      # @param cid [String] diagnostic component identity
      # @return [Object] normalized input
      # @raise [SchemaViolationError] for non-input components or invalid values
      def validate_input_value!(type, value, props:, owner:, page_id:, cid:)
        normalized_type = Contract.normalize_type(type)
        schema = Contract.schema(normalized_type)
        shape = schema[:value]
        context = Context.new(owner, page_id, cid)
        violation!('component carries no input value', context, :value) unless shape

        validated = validate_shape(shape, value, context, 'value')
        validate_dynamic_input_value!(normalized_type, validated, props, context)
        validated
      end

      # Checks a parent-provided placement shape using a placement-qualified error field.
      # @param name [Symbol, String] placement field name
      # @param shape [Hash] parent-provided contract shape definition
      # @param value [Object] authored placement value
      # @param owner [Object] diagnostic owner identity
      # @param page_id [String] diagnostic page identity
      # @param cid [String] diagnostic component identity
      # @return [Object] normalized placement value
      def validate_placement!(name, shape, value, owner:, page_id:, cid:)
        validate_shape(shape, value, Context.new(owner, page_id, cid), "placement.#{name}")
      end

      # Revalidates the complete property set before accepting one changed property.
      # Cross-property invariants cannot be bypassed by a single-field update.
      # @param type [Symbol, String] contracted component type
      # @param name [Symbol, String] property being changed
      # @param value [Object] proposed property value
      # @param props [Hash] current properties to merge with the proposed value
      # @param owner [Object] diagnostic owner identity
      # @param page_id [String] diagnostic page identity
      # @param cid [String] diagnostic component identity
      # @return [Object] normalized requested value
      # @raise [UnknownPropertyError] for an unsupported property
      def validate_property!(type, name, value, props:, owner:, page_id:, cid:)
        normalized_type = Contract.normalize_type(type)
        key = normalize_name(name)
        definitions = Contract.schema(normalized_type).fetch(:properties)
        unless definitions.key?(key)
          raise UnknownPropertyError.new(
            "unknown property #{name.inspect}", owner: owner, page_id: page_id, cid: cid, field: name
          )
        end

        validate_component!(
          normalized_type, props.merge(key => value), owner: owner, page_id: page_id, cid: cid
        ).fetch(key)
      end

      private

      def validate_properties(definitions, props, context)
        violation!('properties must be a Hash', context, :properties) unless props.is_a?(Hash)

        normalized_input = normalize_hash_keys(props, context)
        unknown = normalized_input.keys - definitions.keys
        unless unknown.empty?
          field = unknown.first
          raise UnknownPropertyError.new("unknown property #{field.inspect}", **error_context(context, field))
        end

        definitions.each_with_object({}) do |(name, definition), result|
          if normalized_input.key?(name)
            result[name] = validate_shape(definition.fetch(:shape), normalized_input.fetch(name), context, name.to_s)
          elsif definition.fetch(:required)
            violation!("missing required property #{name}", context, name)
          elsif definition.key?(:default)
            result[name] = deep_dup(definition.fetch(:default))
          end
          if definition[:forced] && result.key?(name) && result[name] != definition[:forced]
            violation!("#{name} must be #{definition[:forced]}", context, name)
          end
        end
      end

      def validate_shape(shape, value, context, path)
        case shape.fetch(:kind)
        when :string
          validate_string(shape, value, context, path)
        when :integer
          validate_integer(shape, value, context, path)
        when :number
          validate_number(shape, value, context, path)
        when :boolean
          violation!('must be true or false', context, path) unless value == true || value == false
          value
        when :enum
          validate_enum(shape, value, context, path)
        when :array
          validate_array(shape, value, context, path)
        when :record
          validate_record(shape, value, context, path)
        when :union
          validate_union(shape, value, context, path)
        when :editor
          validate_editor(value, context, path)
        when :cell_map
          validate_cell_map(value, context, path)
        when :editor_value
          validate_editor_scalar(value, context, path)
        else
          violation!("unknown schema shape #{shape[:kind].inspect}", context, path)
        end
      end

      def validate_string(shape, value, context, path)
        violation!('must be a String', context, path) unless value.is_a?(String)

        max = Contract::BOUNDS[shape[:bound]]
        violation!("exceeds #{max} characters", context, path) if max && value.length > max
        if shape[:pattern] && !value.match?(shape[:pattern])
          violation!('has invalid identifier syntax', context, path)
        end
        value.dup.freeze
      end

      def validate_integer(shape, value, context, path)
        violation!('must be an Integer', context, path) unless value.is_a?(Integer)
        validate_range(shape, value, context, path)
        value
      end

      def validate_number(shape, value, context, path)
        violation!('must be numeric', context, path) unless value.is_a?(Numeric)
        violation!('must be finite', context, path) unless value.finite?
        validate_range(shape, value, context, path)
        value
      end

      def validate_range(shape, value, context, path)
        violation!("must be >= #{shape[:min]}", context, path) if shape.key?(:min) && value < shape[:min]
        violation!("must be <= #{shape[:max]}", context, path) if shape.key?(:max) && value > shape[:max]
      end

      def validate_enum(shape, value, context, path)
        normalized = value.is_a?(Symbol) ? value.to_s : value
        unless normalized.is_a?(String) && shape.fetch(:values).include?(normalized)
          violation!("must be one of #{shape.fetch(:values).join(', ')}", context, path)
        end
        normalized.freeze
      end

      def validate_array(shape, value, context, path)
        violation!('must be an Array', context, path) unless value.is_a?(Array)
        violation!("must contain at least #{shape[:min]} items", context, path) if value.length < shape[:min]
        if shape[:max] && value.length > shape[:max]
          violation!("must contain at most #{shape[:max]} items", context, path)
        end
        value.each_with_index.map do |item, index|
          validate_shape(shape.fetch(:items), item, context, "#{path}[#{index}]")
        end.freeze
      end

      def validate_record(shape, value, context, path)
        violation!('must be a Hash', context, path) unless value.is_a?(Hash)

        fields = shape.fetch(:fields)
        normalized = normalize_hash_keys(value, context)
        unknown = normalized.keys - fields.keys
        if !shape.fetch(:allow_extra) && !unknown.empty?
          violation!("contains unknown field #{unknown.first}", context, "#{path}.#{unknown.first}")
        end
        fields.each_with_object({}) do |(name, definition), result|
          child_path = "#{path}.#{name}"
          if normalized.key?(name)
            result[name] = validate_shape(definition.fetch(:shape), normalized.fetch(name), context, child_path)
          elsif definition.fetch(:required)
            violation!("missing required field #{name}", context, child_path)
          elsif definition.key?(:default)
            result[name] = deep_dup(definition.fetch(:default))
          end
        end.freeze
      end

      def validate_union(shape, value, context, path)
        failures = shape.fetch(:variants).filter_map do |variant|
          begin
            return validate_shape(variant, value, context, path)
          rescue SchemaViolationError => error
            error.message
          end
        end
        violation!("matches no permitted shape: #{failures.join(' | ')}", context, path)
      end

      def validate_component_invariants!(type, props, context)
        validate_sensitive!(type, props, context)
        if props[:width_groups] && props[:width_groups].uniq.size != props[:width_groups].size
          violation!('width_groups must be unique', context, :width_groups)
        end
        case type
        when :text then validate_text!(props, context)
        when :columns then validate_columns!(props, context)
        when :grid then validate_grid!(props, context)
        when :tabs then validate_tabs!(props, context)
        when :progress then validate_progress!(props, context)
        when :radio then validate_options!(props, :selected, context)
        when :select then validate_options!(props, :value, context)
        when :number_input, :slider then validate_numeric_input!(props, context, fixed: type == :number_input)
        when :log then validate_log!(props, context)
        when :table then validate_table!(props, context)
        when :dialog then validate_dialog!(props, context)
        when :composite then validate_composite!(props, context)
        end
      end

      def validate_text!(props, context)
        fragments = props[:fragments]
        return unless fragments&.any? { |part| part.is_a?(Hash) }

        length = fragments.sum { |part| part.is_a?(Hash) ? part[:content].length : part.length }
        violation!('styled text exceeds display text bound', context, :fragments) if length > Contract::BOUNDS[:display_text]
        violation!('middle ellipsis requires plain text', context, :ellipsize) if props[:ellipsize] == 'middle'
      end

      def validate_sensitive!(type, props, context)
        if type == :password_input && props[:sensitive] != true
          violation!('password_input sensitive must be true', context, :sensitive)
        end
      end

      def validate_columns!(props, context)
        return unless props[:weights]
        return if props[:weights].length == props[:count]

        violation!('weights length must equal count', context, :weights)
      end

      def validate_grid!(props, context)
        if props[:equal_rows] && props[:row_sizing] == 'spread'
          violation!('equal rows cannot also spread unequal natural row heights', context, :row_sizing)
        end
        columns = props[:expand_columns] || []
        return if columns.uniq == columns && columns.all? { |column| column <= props[:cols] }

        violation!('expanded columns must be unique declared grid columns', context, :expand_columns)
      end

      def validate_tabs!(props, context)
        if props[:headers]
          keys = props[:headers].map { |header| header[:key] }
          unless keys.length == props[:names].length && keys.uniq.length == keys.length && props[:names].uniq.length == props[:names].length
            violation!('tab headers must uniquely identify each named page', context, :headers)
          end
        end
        return unless props.key?(:selected)
        return if props[:names].empty? && props[:selected].zero?
        return if props[:selected] < props[:names].length

        violation!('selected tab index is out of range', context, :selected)
      end

      def validate_progress!(props, context)
        return if props[:indeterminate] || props.key?(:value)

        violation!('value is required unless progress is indeterminate', context, :value)
      end

      def validate_options!(props, selected_key, context)
        validate_unique_options!(props[:options], context, :options)
        if props.key?(:empty_value) && props[:options].none? { |option| option[:value] == props[:empty_value] }
          violation!('empty value must name an option', context, :empty_value)
        end
        if props[:free_text_prefix]
          violation!('free text prefix requires an editable select', context, :free_text_prefix) unless props[:editable]
          if props[:free_text_prefix].empty? || props[:options].any? { |option| option[:value].start_with?(props[:free_text_prefix]) }
            violation!('free text prefix must be nonempty and disjoint from option IDs', context, :free_text_prefix)
          end
        end
        return if selected_key == :value && props[:editable]
        return unless props.key?(selected_key)
        return if props[:options].any? { |option| option[:value] == props[selected_key] }

        violation!("#{selected_key} is not present in options", context, selected_key)
      end

      def validate_unique_options!(options, context, path)
        return unless options
        values = options.map { |option| option[:value] }
        violation!('option values must be unique', context, path) unless values.uniq.length == values.length
      end

      def validate_numeric_input!(props, context, fixed: false)
        ordered = fixed ? props[:min] <= props[:max] : props[:min] < props[:max]
        violation!(fixed ? 'min must not exceed max' : 'min must be less than max', context, :min) unless ordered
        violation!('step must be positive', context, :step) unless props[:step].positive?
        unless props[:value].between?(props[:min], props[:max])
          violation!('value must be within min and max', context, :value)
        end
        if props[:snap_to_step] == false && !props[:stepper_buttons]
          violation!('free numeric stepping requires stepper_buttons', context, :snap_to_step)
        end
        if (props.key?(:acceleration) || props.key?(:page_step)) && props[:snap_to_step] != false
          violation!('acceleration and page_step require free numeric stepping', context, :acceleration)
        end
      end

      def validate_log!(props, context)
        return if props[:lines].length <= props[:max_lines]

        violation!('lines exceed declared max_lines retention', context, :lines)
      end

      def validate_dialog!(props, context)
        ids = props[:buttons].map { |button| button[:id] }
        violation!('dialog button ids must be unique', context, :buttons) unless ids.uniq.length == ids.length
        if props[:cancel_button] && !ids.include?(props[:cancel_button])
          violation!('cancel_button must name a dialog button', context, :cancel_button)
        end
        if props[:default_button] && !ids.include?(props[:default_button])
          violation!('default_button must name a dialog button', context, :default_button)
        end
        if props[:no_viewer] == 'default' && !props[:default_button]
          violation!('default_button is required for no_viewer=default', context, :default_button)
        end
      end

      def validate_composite!(props, context)
        regions = props[:layers].select { |layer| layer[:kind] == 'region' }
        region_keys = regions.map { |region| region[:key] }
        violation!('region keys must be unique', context, :layers) unless region_keys.uniq.length == region_keys.length
        if props[:scroll_to] && !region_keys.include?(props[:scroll_to])
          violation!('scroll_to must name a declared region', context, :scroll_to)
        end
      end

      def validate_event_invariants!(type, event_name, payload, props, context)
        normalized_props = props.transform_keys { |key| normalize_name(key) }
        if %i[pointer_press pointer_release].include?(event_name) && !normalized_props[:pointer_events]
          violation!('pointer events are not enabled', context, event_name)
        end
        if event_name == :dismiss && normalized_props[:menu] != 'context'
          violation!('only context menus can be dismissed', context, event_name)
        end
        case [type, event_name]
        when [:scroll, :scrolled]
          if payload[:upper] && payload[:page_size] && payload[:upper] < payload[:page_size]
            violation!('scroll extent must cover its viewport', context, event_name)
          end
        when [:tabs, :select]
          violation!('selected tab index is out of range', context, event_name) if payload[:index] >= normalized_props[:names].length
          header = normalized_props[:headers]&.[](payload[:index])
          if header ? payload[:tab] != header[:key] || header[:disabled] || header[:hidden] : payload.key?(:tab)
            violation!('tab identity does not match selection', context, event_name)
          end
        when [:tabs, :tab_pointer]
          header = normalized_props.fetch(:headers, []).find { |item| item[:key] == payload[:tab] }
          violation!('tab pointer target is absent or disabled', context, event_name) unless header && header[:pointer_events] && !header[:disabled] && !header[:hidden] && !normalized_props[:disabled]
        when [:table, :row_activate], [:table, :row_toggle], [:table, :cursor_change]
          row_keys = normalized_props[:rows].map { |row| (row[:key] || row['key']).to_s }
          violation!('event row does not exist', context, event_name) unless row_keys.include?(payload[:row])
          columns = normalized_props[:columns].map { |column| (column[:key] || column['key']).to_s }
          violation!('event column does not exist', context, event_name) if payload[:column] && !columns.include?(payload[:column])
        when [:table, :selection_change]
          validate_table_selection_event!(payload, normalized_props, context, event_name)
        when [:table, :cell_edit]
          validate_cell_edit_event!(payload, normalized_props, context, event_name)
        when [:table, :column_activate]
          column = normalized_props[:columns].find { |candidate| candidate[:key] == payload[:column] }
          violation!('column is not activatable', context, event_name) unless column && column[:activatable]
        when [:table, :sort_change]
          validate_sort_event!(payload, normalized_props, context, event_name)
        when [:composite, :region_activate]
          validate_region_event!(payload, normalized_props, context, event_name)
        when [:composite, :surface_activate]
          violation!('surface events are not enabled', context, event_name) unless normalized_props[:surface_events]
        when [:dialog, :response]
          ids = normalized_props[:buttons].map { |button| (button[:id] || button['id']).to_s }
          violation!('response button does not exist', context, event_name) unless ids.include?(payload[:button])
        end
        validate_input_event!(type, event_name, payload, normalized_props, context)
      end

      def validate_input_event!(type, event_name, payload, props, context)
        return unless event_name == :change || (%i[text_input textarea].include?(type) && event_name == :blur)
        violation!('sensitive components cannot emit change', context, event_name) if props[:sensitive] == true

        value = payload[:value]
        case type
        when :radio_option
          violation!('radio changes select an option', context, event_name) unless value == true
        when :radio, :select
          return if type == :select && props[:editable]
          options = props[:options].map { |option| (option[:value] || option['value']).to_s }
          violation!('event value is not present in options', context, event_name) unless options.include?(value)
        when :text_input
          violation!('text is read-only', context, event_name) if props[:read_only]
          max = input_text_limit(type, props)
          violation!("event value exceeds #{max} characters", context, event_name) if value.length > max
        when :textarea
          violation!('text is read-only', context, event_name) if props[:read_only]
          max = input_text_limit(type, props)
          violation!("event value exceeds #{max} characters", context, event_name) if value.length > max
        when :number_input, :slider
          unless value.between?(props[:min], props[:max])
            violation!('event value must be within min and max', context, event_name)
          end
        end
      end

      def validate_dynamic_input_value!(type, value, props, context)
        normalized_props = props.transform_keys { |key| normalize_name(key) }
        case type
        when :radio, :select
          return if type == :select && normalized_props[:editable]
          # A select without an initial value may remain unselected on submit.
          # This does not grant arbitrary choices or change-event values.
          return if type == :select && !normalized_props.key?(:value) && value.empty?

          options = normalized_props[:options].map { |option| (option[:value] || option['value']).to_s }
          violation!('value is not present in options', context, :value) unless options.include?(value)
        when :text_input
          max = input_text_limit(type, normalized_props)
          violation!("value exceeds #{max} characters", context, :value) if value.length > max
        when :textarea
          max = input_text_limit(type, normalized_props)
          violation!("value exceeds #{max} characters", context, :value) if value.length > max
        when :number_input, :slider
          unless value.between?(normalized_props[:min], normalized_props[:max])
            violation!('value must be within min and max', context, :value)
          end
        end
      end

      # Reads the shared text bound; callers retain event/submission admission and errors.
      # @param type [Symbol] text_input or textarea
      # @param props [Hash] properties with normalized names
      # @return [Integer] explicit limit or the component family's contract bound
      def input_text_limit(type, props)
        props[:max_length] || Contract::BOUNDS[type == :text_input ? :input_text : :multiline_text]
      end

      def validate_region_event!(payload, props, context, event_name)
        layer = props[:layers].find do |candidate|
          kind = candidate[:kind] || candidate['kind']
          key = candidate[:key] || candidate['key']
          kind.to_s == 'region' && key.to_s == payload[:region]
        end
        violation!('region does not exist or is not activatable', context, event_name) unless layer && (layer[:activates] || layer['activates'])
      end

      def normalize_hash_keys(hash, context)
        hash.each_with_object({}) do |(key, value), normalized|
          name = normalize_name(key)
          violation!('field names must be String or Symbol', context, key) unless name
          violation!("duplicate field #{name}", context, name) if normalized.key?(name)
          normalized[name] = value
        end
      end

      def normalize_name(name)
        return name if name.is_a?(Symbol)
        return name.to_sym if name.is_a?(String) && name.match?(Contract::IDENTIFIER)

        nil
      end

      def violation!(message, context, field)
        raise SchemaViolationError.new(message, **error_context(context, field))
      end

      def error_context(context, field)
        { owner: context.owner, page_id: context.page_id, cid: context.cid, field: field }
      end

      def deep_dup(value)
        Contract.deep_dup(value)
      end
    end
  end
end

require_relative 'validator/table'
