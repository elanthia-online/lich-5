# frozen_string_literal: true

require_relative 'contract'

module Lich
  module WebUI
    # Validates component properties, event payloads, facilities, and cross-field invariants.
    class Validator
      Context = Data.define(:owner, :page_id, :cid)

      def validate_component!(type, props, owner:, page_id:, cid:)
        normalized_type = Contract.normalize_type(type)
        schema = Contract.schema(normalized_type)
        context = Context.new(owner, page_id, cid)
        normalized = validate_properties(schema.fetch(:properties), props, context)
        validate_component_invariants!(normalized_type, normalized, context)
        normalized.freeze
      end

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

      def validate_facility!(name, value, owner:, page_id:, cid: nil)
        key = normalize_name(name)
        facility = Contract::FACILITIES[key]
        context = Context.new(owner, page_id, cid)
        unless facility
          raise UnknownPropertyError.new("unknown page facility #{name.inspect}", **error_context(context, name))
        end

        validate_shape(facility.fetch(:shape), value, context, name.to_s)
      end

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

      def validate_placement!(name, shape, value, owner:, page_id:, cid:)
        validate_shape(shape, value, Context.new(owner, page_id, cid), "placement.#{name}")
      end

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

      def validate_editor(value, context, path)
        return nil if value.nil?
        violation!('must be a Hash or nil', context, path) unless value.is_a?(Hash)

        normalized = normalize_hash_keys(value, context)
        editor_type = normalized[:type]&.to_s
        fields = case editor_type
                 when 'text'
                   {
                     type: Contract.property(Contract.enum(:text), required: true),
                     max_length: Contract.property(Contract.integer(min: 1, max: 8192)),
                   }
                 when 'number'
                   {
                     type: Contract.property(Contract.enum(:number), required: true),
                     min: Contract.property(Contract::ANY_NUMBER, required: true),
                     max: Contract.property(Contract::ANY_NUMBER, required: true),
                     step: Contract.property(Contract::ANY_NUMBER, default: 1),
                   }
                 when 'checkbox'
                   { type: Contract.property(Contract.enum(:checkbox), required: true) }
                 when 'select'
                   {
                     type: Contract.property(Contract.enum(:select), required: true),
                     options: Contract.property(Contract::OPTIONS, required: true),
                   }
                 else
                   violation!('has unknown editor type', context, "#{path}.type")
                 end
        result = validate_record(Contract.record(fields), normalized, context, path)
        if editor_type == 'number' && result[:min] >= result[:max]
          violation!('editor min must be less than max', context, path)
        end
        validate_unique_options!(result[:options], context, path) if editor_type == 'select'
        result
      end

      def validate_cell_map(value, context, path)
        violation!('must be a Hash', context, path) unless value.is_a?(Hash)

        value.each_with_object({}) do |(key, cell), result|
          key_string = key.to_s
          violation!('has invalid column key', context, "#{path}.#{key}") unless key_string.match?(Contract::IDENTIFIER)
          result[key_string.freeze] = validate_editor_scalar(cell, context, "#{path}.#{key}")
        end.freeze
      end

      def validate_editor_scalar(value, context, path)
        valid = value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false
        violation!('must be a string, finite number, or boolean', context, path) unless valid
        violation!('must be finite', context, path) if value.is_a?(Numeric) && !value.finite?
        value.is_a?(String) ? value.dup.freeze : value
      end

      def validate_component_invariants!(type, props, context)
        validate_sensitive!(type, props, context)
        case type
        when :columns then validate_columns!(props, context)
        when :tabs then validate_tabs!(props, context)
        when :progress then validate_progress!(props, context)
        when :radio then validate_options!(props, :selected, context)
        when :select then validate_options!(props, :value, context)
        when :number_input, :slider then validate_numeric_input!(props, context)
        when :log then validate_log!(props, context)
        when :table then validate_table!(props, context)
        when :dialog then validate_dialog!(props, context)
        when :composite then validate_composite!(props, context)
        end
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

      def validate_tabs!(props, context)
        return unless props.key?(:selected)
        return if props[:selected] < props[:names].length

        violation!('selected tab index is out of range', context, :selected)
      end

      def validate_progress!(props, context)
        return if props[:indeterminate] || props.key?(:value)

        violation!('value is required unless progress is indeterminate', context, :value)
      end

      def validate_options!(props, selected_key, context)
        validate_unique_options!(props[:options], context, :options)
        return unless props.key?(selected_key)
        return if props[:options].any? { |option| option[:value] == props[selected_key] }

        violation!("#{selected_key} is not present in options", context, selected_key)
      end

      def validate_unique_options!(options, context, path)
        return unless options
        values = options.map { |option| option[:value] }
        violation!('option values must be unique', context, path) unless values.uniq.length == values.length
      end

      def validate_numeric_input!(props, context)
        violation!('min must be less than max', context, :min) unless props[:min] < props[:max]
        violation!('step must be positive', context, :step) unless props[:step].positive?
        unless props[:value].between?(props[:min], props[:max])
          violation!('value must be within min and max', context, :value)
        end
      end

      def validate_log!(props, context)
        return if props[:lines].length <= props[:max_lines]

        violation!('lines exceed declared max_lines retention', context, :lines)
      end

      def validate_table!(props, context)
        columns = props[:columns]
        rows = props[:rows]
        column_keys = columns.map { |column| column[:key] }
        row_keys = rows.map { |row| row[:key] }
        violation!('column keys must be unique', context, :columns) unless column_keys.uniq.length == column_keys.length
        violation!('row keys must be unique', context, :rows) unless row_keys.uniq.length == row_keys.length

        columns.each_with_index do |column, index|
          validate_editor(column[:editor], context, "columns[#{index}].editor")
        end
        rows.each_with_index do |row, index|
          if row[:parent] && !row_keys.include?(row[:parent])
            violation!('parent must name a row in the same table', context, "rows[#{index}].parent")
          end
          unknown_cells = row[:cells].keys - column_keys
          unless unknown_cells.empty?
            violation!("cell names unknown column #{unknown_cells.first}", context, "rows[#{index}].cells")
          end
        end
        validate_table_cycles!(rows, context)

        selected = props[:selected] || []
        violation!('selected rows must exist', context, :selected) unless (selected - row_keys).empty?
        violation!('selected is invalid when selection is none', context, :selected) if props[:selection] == 'none' && !selected.empty?
        violation!('single selection accepts at most one row', context, :selected) if props[:selection] == 'single' && selected.length > 1
        if props[:sort]
          column = columns.find { |candidate| candidate[:key] == props[:sort][:column] }
          violation!('sort column does not exist', context, :sort) unless column
          violation!('sort column is not sortable', context, :sort) unless props[:sortable] && column[:sortable]
        end
      end

      def validate_table_cycles!(rows, context)
        parents = rows.to_h { |row| [row[:key], row[:parent]] }
        parents.each_key do |key|
          seen = []
          current = key
          while current
            violation!('table parent cycle detected', context, :rows) if seen.include?(current)
            seen << current
            violation!('table depth exceeds global bound', context, :rows) if seen.length > Contract::BOUNDS[:tree_depth]
            current = parents[current]
          end
        end
      end

      def validate_dialog!(props, context)
        ids = props[:buttons].map { |button| button[:id] }
        violation!('dialog button ids must be unique', context, :buttons) unless ids.uniq.length == ids.length
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
        case [type, event_name]
        when [:tabs, :select]
          violation!('selected tab index is out of range', context, event_name) if payload[:index] >= normalized_props[:names].length
        when [:table, :row_activate], [:table, :row_toggle]
          row_keys = normalized_props[:rows].map { |row| (row[:key] || row['key']).to_s }
          violation!('event row does not exist', context, event_name) unless row_keys.include?(payload[:row])
        when [:table, :selection_change]
          validate_table_selection_event!(payload, normalized_props, context, event_name)
        when [:table, :cell_edit]
          validate_cell_edit_event!(payload, normalized_props, context, event_name)
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
        return unless event_name == :change
        violation!('sensitive components cannot emit change', context, event_name) if props[:sensitive] == true

        value = payload[:value]
        case type
        when :radio, :select
          options = props[:options].map { |option| (option[:value] || option['value']).to_s }
          violation!('event value is not present in options', context, event_name) unless options.include?(value)
        when :text_input
          max = props[:max_length] || Contract::BOUNDS[:input_text]
          violation!("event value exceeds #{max} characters", context, event_name) if value.length > max
        when :textarea
          max = props[:max_length] || Contract::BOUNDS[:multiline_text]
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
          options = normalized_props[:options].map { |option| (option[:value] || option['value']).to_s }
          violation!('value is not present in options', context, :value) unless options.include?(value)
        when :text_input
          max = normalized_props[:max_length] || Contract::BOUNDS[:input_text]
          violation!("value exceeds #{max} characters", context, :value) if value.length > max
        when :textarea
          max = normalized_props[:max_length] || Contract::BOUNDS[:multiline_text]
          violation!("value exceeds #{max} characters", context, :value) if value.length > max
        when :number_input, :slider
          unless value.between?(normalized_props[:min], normalized_props[:max])
            violation!('value must be within min and max', context, :value)
          end
        end
      end

      def validate_table_selection_event!(payload, props, context, event_name)
        keys = props[:rows].map { |row| (row[:key] || row['key']).to_s }
        violation!('selection contains unknown row', context, event_name) unless (payload[:rows] - keys).empty?
        violation!('selection is disabled', context, event_name) if props.fetch(:selection, 'none').to_s == 'none'
        if props.fetch(:selection, 'none').to_s == 'single' && payload[:rows].length > 1
          violation!('single selection accepts one row', context, event_name)
        end
      end

      def validate_cell_edit_event!(payload, props, context, event_name)
        row_keys = props[:rows].map { |row| (row[:key] || row['key']).to_s }
        violation!('edit row does not exist', context, event_name) unless row_keys.include?(payload[:row])
        column = props[:columns].find { |candidate| (candidate[:key] || candidate['key']).to_s == payload[:column] }
        violation!('edit column does not exist', context, event_name) unless column
        editor = column[:editor] || column['editor']
        violation!('column is read-only', context, event_name) unless editor
        validate_editor_value_against!(payload[:value], editor, context, event_name)
      end

      def validate_editor_value_against!(value, editor, context, path)
        normalized = editor.transform_keys { |key| normalize_name(key) }
        case normalized[:type].to_s
        when 'text'
          violation!('edited value must be text', context, path) unless value.is_a?(String)
          max = normalized[:max_length] || 8192
          violation!("edited text exceeds #{max} characters", context, path) if value.length > max
        when 'number'
          violation!('edited value must be numeric', context, path) unless value.is_a?(Numeric) && value.finite?
          unless value.between?(normalized[:min], normalized[:max])
            violation!('edited number is out of range', context, path)
          end
        when 'checkbox'
          violation!('edited value must be boolean', context, path) unless value == true || value == false
        when 'select'
          values = normalized[:options].map { |option| (option[:value] || option['value']).to_s }
          violation!('edited value is not a select option', context, path) unless values.include?(value)
        end
      end

      def validate_sort_event!(payload, props, context, event_name)
        violation!('table is not sortable', context, event_name) unless props[:sortable]
        column = props[:columns].find { |candidate| (candidate[:key] || candidate['key']).to_s == payload[:column] }
        violation!('sort column does not exist', context, event_name) unless column
        violation!('sort column is not sortable', context, event_name) unless column[:sortable] || column['sortable']
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
        case value
        when Hash then value.to_h { |key, child| [key, deep_dup(child)] }
        when Array then value.map { |child| deep_dup(child) }
        else value
        end
      end
    end
  end
end
