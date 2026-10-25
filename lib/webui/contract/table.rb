# frozen_string_literal: true

module Lich
  module WebUI
    module Contract
      module_function

      TABLE_COLUMN = record(
        key: property(IDENT, required: true), label: property(SHORT, required: true),
        align: property(enum(:start, :center, :end), default: 'start'), width: property(GEOMETRY),
        min_width: property(integer(min: 0, max: 65_536)), tooltip: property(string(:body_text)),
        activatable: property(BOOL, default: false),
        sortable: property(BOOL, default: false), resizable: property(BOOL, default: false), expand: property(BOOL, default: false),
        editor: property(scalar(:editor), default: nil),
        background: property(RGBA),
        color_preview: property(record(width: property(integer(min: 1, max: 128), required: true),
                                       height: property(integer(min: 1, max: 128), required: true)))
      ).freeze
      TABLE_ROW = record(
        key: property(IDENT, required: true), parent: property(IDENT),
        expanded: property(BOOL, default: false, scope: :viewer),
        cells: property(scalar(:cell_map), required: true),
        # Preserve numeric ordering when the visible cells include formatting.
        sort_cells: property(scalar(:cell_map)),
        background_disabled: property(array(IDENT, max: BOUNDS[:table_columns])),
        cell_disabled: property(array(IDENT, max: BOUNDS[:table_columns])),
        cell_foregrounds: property(array(record(column: property(IDENT, required: true),
                                                color: property(RGBA, required: true)), max: BOUNDS[:table_columns]))
      ).freeze

      TABLE_PROPERTIES = {
        headers: property(BOOL),
        # Stable row IDs separate viewer interaction from positional model paths.
        expanded: property(array(IDENT, max: BOUNDS[:table_rows]), scope: :viewer),
        cursor: property(record(row: property(IDENT), column: property(IDENT)), scope: :viewer),
        scrollable: property(BOOL, default: true),
        # Single-line cells retain their natural width and scroll horizontally.
        # Omission preserves existing wrapping tables, including shim consumers.
        wrap: property(BOOL),
        row_height: property(integer(min: 1, max: BOUNDS[:geometry].end)),
        border_width: property(integer(min: 0, max: 8)),
        grid_lines: property(enum(:none, :horizontal, :vertical, :both)),
        sort_mode: property(enum(:natural, :lexical, :model), default: 'natural'),
        columns: property(array(TABLE_COLUMN, min: 1, max: BOUNDS[:table_columns]), required: true),
        rows: property(array(TABLE_ROW, max: BOUNDS[:table_rows]), required: true),
        selection: property(enum(:none, :single, :browse, :multi), default: 'none'),
        selection_background: property(RGBA),
        selected: property(array(IDENT, max: BOUNDS[:table_rows]), scope: :viewer),
        sortable: property(BOOL, default: false),
        sort: property(record(
                         column: property(IDENT, required: true), direction: property(enum(:asc, :desc), required: true)
                       ), scope: :viewer),
        max_height: property(GEOMETRY),
        transfer_group: property(IDENT),
        search_column: property(IDENT),
        activation: property(enum(:single, :double), default: 'double'),
      }.freeze

      TABLE_EVENTS = {
        column_activate: event(record(column: property(IDENT, required: true))),
        row_drop: event(record(source: property(CID, required: true), row: property(IDENT, required: true)), terminal: true),
        row_activate: event(record(row: property(IDENT, required: true), column: property(IDENT)), terminal: true),
        # Cursor and selection changes are already visible in the client. An
        # automatic refresh would invalidate the following activation (including
        # its one stale-generation retry). Callback-authored edits still refresh.
        cursor_change: event(record(row: property(IDENT, required: true), column: property(IDENT))),
        selection_change: event(record(rows: property(array(IDENT, max: BOUNDS[:table_rows]), required: true))),
        cell_edit: event(record(
                           row: property(IDENT, required: true), column: property(IDENT, required: true),
                           value: property(scalar(:editor_value), required: true)
                         )),
        row_toggle: event(record(
                            row: property(IDENT, required: true), expanded: property(BOOL, required: true)
                          ), structural: true),
        sort_change: event(record(
                             column: property(IDENT, required: true), direction: property(enum(:asc, :desc), required: true)
                           )),
      }.freeze

      # Supplies fresh table-editor field declarations to Validator.
      # Admission, normalization, errors, and cross-field checks stay on Validator.
      # @api private
      # @param editor_type [String, nil] normalized editor type
      # @return [Hash, nil] fields, or nil for an unsupported editor
      def table_editor_fields(editor_type)
        case editor_type
        when 'text'
          {
            type: property(enum(:text), required: true),
            max_length: property(integer(min: 1, max: 8192)),
          }
        when 'number'
          {
            type: property(enum(:number), required: true),
            min: property(ANY_NUMBER, required: true),
            max: property(ANY_NUMBER, required: true),
            step: property(ANY_NUMBER, default: 1),
          }
        when 'checkbox'
          { type: property(enum(:checkbox), required: true), disabled: property(BOOL, default: false) }
        when 'select'
          {
            type: property(enum(:select), required: true),
            options: property(OPTIONS, required: true),
            option_labels: property(BOOL, default: false),
          }
        else
          nil
        end
      end
    end
  end
end
