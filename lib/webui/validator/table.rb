# frozen_string_literal: true

module Lich
  module WebUI
    class Validator
      private

      def validate_editor(value, context, path)
        return nil if value.nil?
        violation!('must be a Hash or nil', context, path) unless value.is_a?(Hash)

        normalized = normalize_hash_keys(value, context)
        editor_type = normalized[:type]&.to_s
        fields = Contract.table_editor_fields(editor_type)
        violation!('has unknown editor type', context, "#{path}.type") unless fields
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

      def validate_table!(props, context)
        columns = props[:columns]
        rows = props[:rows]
        column_keys = columns.map { |column| column[:key] }
        row_keys = rows.map { |row| row[:key] }
        violation!('column keys must be unique', context, :columns) unless column_keys.uniq.length == column_keys.length
        if props[:search_column] && !column_keys.include?(props[:search_column])
          violation!('search column must name a displayed column', context, :search_column)
        end
        violation!('row keys must be unique', context, :rows) unless row_keys.uniq.length == row_keys.length

        columns.each_with_index do |column, index|
          validate_editor(column[:editor], context, "columns[#{index}].editor")
        end
        rows.each_with_index do |row, index|
          if row[:parent] && !row_keys.include?(row[:parent])
            violation!('parent must name a row in the same table', context, "rows[#{index}].parent")
          end
          unknown_cells = row[:cells].keys - column_keys
          foreground_columns = (row[:cell_foregrounds] || []).map { |entry| entry[:column] }
          unless (foreground_columns - column_keys).empty? && foreground_columns.uniq.size == foreground_columns.size
            violation!('cell_foregrounds must name unique displayed columns', context, "rows[#{index}].cell_foregrounds")
          end
          disabled_cells = row[:cell_disabled] || []
          unless (disabled_cells - column_keys).empty? && disabled_cells.uniq.size == disabled_cells.size
            violation!('cell_disabled must name unique displayed columns', context, "rows[#{index}].cell_disabled")
          end
          disabled_backgrounds = row[:background_disabled] || []
          unless (disabled_backgrounds - column_keys).empty? && disabled_backgrounds.uniq.size == disabled_backgrounds.size
            violation!('background_disabled must name unique displayed columns', context, "rows[#{index}].background_disabled")
          end
          unless unknown_cells.empty?
            violation!("cell names unknown column #{unknown_cells.first}", context, "rows[#{index}].cells")
          end
          unknown_sort_cells = (row[:sort_cells] || {}).keys - column_keys
          unless unknown_sort_cells.empty?
            violation!("sort cell names unknown column #{unknown_sort_cells.first}", context, "rows[#{index}].sort_cells")
          end
        end
        validate_table_cycles!(rows, context)

        selected = props[:selected] || []
        violation!('selected rows must exist', context, :selected) unless (selected - row_keys).empty?
        violation!('selected is invalid when selection is none', context, :selected) if props[:selection] == 'none' && !selected.empty?
        violation!('single selection accepts at most one row', context, :selected) if %w[single browse].include?(props[:selection]) && selected.length > 1
        violation!('expanded rows must exist', context, :expanded) unless ((props[:expanded] || []) - row_keys).empty?
        cursor = props[:cursor] || {}
        violation!('cursor row must exist', context, :cursor) if cursor[:row] && !row_keys.include?(cursor[:row])
        if cursor[:column] && (!cursor[:row] || !column_keys.include?(cursor[:column]))
          violation!('cursor column must exist and accompany a row', context, :cursor)
        end
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

      def validate_table_selection_event!(payload, props, context, event_name)
        keys = props[:rows].map { |row| (row[:key] || row['key']).to_s }
        violation!('selection contains unknown row', context, event_name) unless (payload[:rows] - keys).empty?
        violation!('selection is disabled', context, event_name) if props.fetch(:selection, 'none').to_s == 'none'
        if %w[single browse].include?(props.fetch(:selection, 'none').to_s) && payload[:rows].length > 1
          violation!('single selection accepts one row', context, event_name)
        end
      end

      def validate_cell_edit_event!(payload, props, context, event_name)
        row_keys = props[:rows].map { |row| (row[:key] || row['key']).to_s }
        violation!('edit row does not exist', context, event_name) unless row_keys.include?(payload[:row])
        column = props[:columns].find { |candidate| (candidate[:key] || candidate['key']).to_s == payload[:column] }
        violation!('edit column does not exist', context, event_name) unless column
        row = props[:rows].find { |candidate| candidate[:key] == payload[:row] }
        violation!('cell is disabled', context, event_name) if (row[:cell_disabled] || []).include?(payload[:column])
        editor = column[:editor] || column['editor']
        violation!('column is read-only', context, event_name) unless editor
        violation!('column editor is disabled', context, event_name) if editor[:disabled] || editor['disabled']
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
    end
  end
end
