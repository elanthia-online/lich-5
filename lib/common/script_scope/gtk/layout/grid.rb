# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # The plain table in vars/alias contains widgets, not a TreeView model.
        # Cell positions become validated grid placements without extra handles.
        class Table < Widget
          include Container

          attr_reader :n_rows

          # Creates a widget grid using the shared natural/equal track policy.
          # @param rows [Integer] initial row count, clamped to at least one
          # @param columns [Integer] initial column count, bounded by the grid contract
          # @param homogeneous [Boolean] legacy equal-sizing request
          def initialize(rows, columns, homogeneous = false)
            super()
            @n_rows = [Integer(rows), 1].max
            @columns = [Integer(columns), 1].max
            @props.merge!(cols: @columns, gap: 0, homogeneous: homogeneous)
            session.refuse(self, :new) unless @n_rows.positive? && @columns.between?(1, 24)
            session.degrade(:homogeneous_rows, 'equal columns are retained; row heights follow browser layout') if homogeneous
          end

          # Grows the shadow row count while refusing shrink requests.
          # @param value [Integer] new row count, at least the current count
          # @return [Integer] retained row count
          def n_rows=(value)
            count = Integer(value)
            session.refuse(self, :n_rows=) if count < @n_rows
            @n_rows = count
          end

          # Updates shadow row count and the shared grid's column count.
          # @param rows [Integer] requested row count
          # @param columns [Integer] requested column count
          # @return [Table] self
          def resize(rows, columns)
            @n_rows = [Integer(rows), 1].max
            @columns = [Integer(columns), 1].max
            write(:cols, @columns)
          end

          # Maps legacy row spacing to the shared row-gap property.
          # @param value [Integer] bounded layout or model integer request
          # @return [Table] self
          def row_spacings=(value)
            write(:row_gap, Integer(value))
          end

          # Maps legacy column spacing to the shared column-gap property.
          # @param value [Integer] bounded layout or model integer request
          # @return [Table] self
          def column_spacings=(value)
            write(:column_gap, Integer(value))
          end

          # Converts opposing zero-based cell edges to one-based grid placement and padding.
          # The grid grows to contain the child; unsupported attach flags/coordinates are refused.
          # @param child [Widget] same-session child governed by this container
          # @param left [Integer] left edge or inset in this container coordinate system
          # @param right [Integer] right edge or inset in this container coordinate system
          # @param top [Integer] top edge or inset in this container coordinate system
          # @param bottom [Integer] bottom edge or inset in this container coordinate system
          # @param xoptions [Integer, Symbol] supported horizontal attach flags
          # @param yoptions [Integer, Symbol] supported vertical attach flags
          # @param xpadding [Integer] horizontal cell inset
          # @param ypadding [Integer] vertical cell inset
          # @return [Table] self
          def attach(child, left, right, top, bottom, xoptions = 5, yoptions = 5, xpadding = 0, ypadding = 0)
            valid = [left, right, top, bottom].all? { |value| value.is_a?(Integer) }
            valid &&= left >= 0 && right > left && right <= 24 && top >= 0 && bottom > top &&
                      bottom <= Lich::WebUI::Contract::BOUNDS[:children]
            session.refuse(self, :attach) unless valid
            session.refuse(self, :attach) unless [xoptions, yoptions].all? { |value| %i[fill expand shrink].include?(value) || (value.is_a?(Integer) && value.between?(0, 7)) }
            if right > @columns
              @columns = right
              write(:cols, @columns)
            end
            child.placement = { column: left + 1, row: top + 1, span: right - left, row_span: bottom - top }
            child.send(:write, :margin, { left: xpadding, right: xpadding, top: ypadding, bottom: ypadding })
            @n_rows = [@n_rows, bottom].max
            add(child)
          end

          # Legacy convenience spelling uses the same default expansion and padding.
          # @param child [Widget] same-session child governed by this container
          # @param left [Integer] left edge or inset in this container coordinate system
          # @param right [Integer] right edge or inset in this container coordinate system
          # @param top [Integer] top edge or inset in this container coordinate system
          # @param bottom [Integer] bottom edge or inset in this container coordinate system
          # @return [Table] self
          def attach_defaults(child, left, right, top, bottom)
            session.refuse(self, :attach_defaults) if is_a?(Grid)
            attach(child, left, right, top, bottom)
          end

          protected

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :grid

          # A spanning expanding child can request surplus width in each covered track.
          # This reuses the native grid policy without imposing equal-sized columns.
          # @return [Hash] shared layout properties
          # @api private
          def layout_props
            columns = @children.select { |child| child.expands?(:horizontal) }.flat_map do |child|
              placement = child.instance_variable_get(:@placement) || {}
              first = placement.fetch(:column, 1)
              (first...(first + placement.fetch(:span, 1))).to_a
            end
            { expand_columns: columns.uniq.sort }
          end
        end

        # Nonselecting flow layout uses the existing grid ownership and bounds.
        # The browser reduces the requested column maximum to fit available width.
        class FlowBox < Table
          # Creates a nonselecting flow with a seven-column maximum and natural cell sizes.
          def initialize
            super(1, 7, false)
            @props[:flow] = true
          end

          # Accepts only :none; selectable flow children are outside this adapter.
          # @param value [Symbol] :none
          # @return [void] result is not part of the supported script contract
          # @raise [UnsupportedOperation] for other modes or a destroyed flow
          def selection_mode=(value)
            session.style_operation(self, :selection_mode=) do
              session.refuse(self, :selection_mode=) if destroyed? || value != :none
              @selection_mode = value
            end
          end

          alias set_selection_mode selection_mode=

          # Combatical requests the natural one-child minimum; larger minima require new layout semantics.
          # @param value [Integer] supported minimum of one child per line
          # @return [FlowBox] self
          def set_min_children_per_line(value)
            session.style_operation(self, :set_min_children_per_line) do
              session.refuse(self, :set_min_children_per_line) if destroyed? || value != 1
            end
            self
          end

          # Reads the flow container selection policy.
          # @return [Symbol] :none, including before any explicit assignment
          def selection_mode = @selection_mode || :none

          # Reads the authored maximum number of flow columns.
          # @return [Integer] authored column maximum; the browser may fit fewer columns
          def max_children_per_line = read(:cols)

          # Updates both the published column maximum and shadow table dimensions.
          # @param value [Integer] maximum columns, from 1 through 24
          # @return [void] result is not part of the supported script contract
          # @raise [UnsupportedOperation] for an invalid maximum or a destroyed flow
          def max_children_per_line=(value)
            session.style_operation(self, :max_children_per_line=) do
              session.refuse(self, :max_children_per_line=) if destroyed? || !value.is_a?(Integer) || !value.between?(1, 24)
              write(:cols, value)
              @columns = value
            end
          end
          alias set_max_children_per_line max_children_per_line=

          # Applies equal-width columns and equal-height rows together.
          # @param value [Boolean] whether flow cells share equal dimensions
          # @return [void] result is not part of the supported script contract
          # @raise [UnsupportedOperation] for nonboolean input or a destroyed flow
          def homogeneous=(value)
            session.style_operation(self, :homogeneous=) do
              session.refuse(self, :homogeneous=) if destroyed? || ![true, false].include?(value)
              write(:homogeneous, value)
              write(:equal_rows, value)
            end
          end

          # Sets the vertical gap without changing the horizontal gap.
          # @param value [Integer] CSS pixels, from 0 through 64
          # @return [void] result is not part of the supported script contract
          def row_spacing=(value)
            flow_spacing(:row_gap, value)
          end

          # Sets the horizontal gap used when fitting columns to available width.
          # @param value [Integer] CSS pixels, from 0 through 64
          # @return [void] result is not part of the supported script contract
          def column_spacing=(value)
            flow_spacing(:column_gap, value)
          end
          alias set_row_spacing row_spacing=
          alias set_column_spacing column_spacing=

          # Explicit cell placement and selection are outside nonselecting flow layout.
          # @return [void] always refuses this unsupported mutation
          # @raise [UnsupportedOperation] explicit table coordinates are unsupported
          def attach(*) = session.refuse(self, :attach)
          # Refuses fixed dimensions that bypass the flow column policy.
          # @return [void] always refuses this unsupported mutation
          # @raise [UnsupportedOperation] use max_children_per_line instead of fixed dimensions
          def resize(*) = session.refuse(self, :resize)

          private

          # Validates an owned spacing update before writing shared renderer properties.
          # @param property [Symbol] shared shadow or port property name
          # @param value [Integer] bounded layout or model integer request
          # @return [void] result is not part of the supported script contract
          # @raise [UnsupportedOperation] outside the supported 0..64 pixel range
          # @api private
          def flow_spacing(property, value)
            session.style_operation(self, property) do
              session.refuse(self, property) if destroyed? || !value.is_a?(Integer) || !value.between?(0, 64)
              write(property, value)
            end
          end
        end

        # sellunder uses Grid coordinates expressed as origin plus extent,
        # whereas Table receives opposing cell edges. Share validated placement.
        class Grid < Table
          # Creates the origin-plus-extent grid variant with one initial cell.
          def initialize
            super(1, 1)
            @grid_origins = {}.compare_by_identity
          end

          alias row_spacing= row_spacings=
          alias column_spacing= column_spacings=
          alias set_row_spacing row_spacings=
          alias set_column_spacing column_spacings=

          # Finds the first attached child covering an original signed GTK cell.
          # @param column [Integer] model column or grid coordinate for this operation
          # @param row [Integer] signed GTK grid row
          # @return [Widget, nil] covering child, or nil for an empty cell
          # @raise [UnsupportedOperation] for invalid coordinates or a retired grid
          def get_child_at(column, row)
            session.synchronize do
              valid = [column, row].all? { |value| value.is_a?(Integer) && value.abs <= 65_536 }
              session.refuse(self, :get_child_at) if destroyed? || !valid
              @grid_origins.find do |_child, (left, top, width, height)|
                column >= left && column < left + width && row >= top && row < top + height
              end&.first
            end
          end

          # Maps the GTK equal-column request to the existing shared grid policy.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [void] result is not part of the supported script contract
          # @raise [UnsupportedOperation] for nonboolean values
          def column_homogeneous=(value)
            session.refuse(self, :column_homogeneous=) unless [true, false].include?(value)
            write(:homogeneous, value)
          end

          alias set_column_homogeneous column_homogeneous=

          # Equal row tracks are independent of equal columns and surplus-space
          # spreading. Content spanning rows contributes to their shared minimum.
          # @param value [Boolean] whether all occupied rows have equal height
          # @return [void] result is not part of the supported script contract
          def row_homogeneous=(value)
            session.refuse(self, :row_homogeneous=) unless [true, false].include?(value)
            write(:equal_rows, value)
          end
          alias set_row_homogeneous row_homogeneous=

          # Retains signed GTK origins and maps them into positive shared grid
          # coordinates. The translation is uniform, preserving gaps and spans.
          # @param child [Widget] same-session child governed by this container
          # @param left [Integer] left edge or inset in this container coordinate system
          # @param top [Integer] top edge or inset in this container coordinate system
          # @param width [Integer] requested width in bounded layout units
          # @param height [Integer] requested height in bounded layout units
          # @return [Grid] self
          def attach(child, left, top, width, height)
            session.synchronize do
              valid = [left, top, width, height].all? { |value| value.is_a?(Integer) }
              valid &&= width.positive? && height.positive? && left.abs <= 65_536 && top.abs <= 65_536
              session.refuse(self, :attach) unless valid && !destroyed? && child.is_a?(Widget) &&
                                                   child.session.equal?(session) && !child.destroyed? && !child.parent
              ancestor = self
              while ancestor
                session.refuse(self, :attach) if ancestor.equal?(child)
                ancestor = ancestor.parent
              end
              proposed = @grid_origins.merge(child => [left, top, width, height])
              previous = { origins: @grid_origins, columns: @columns, rows: @n_rows,
                           placements: (@children + [child]).to_h { |widget| [widget, widget.instance_variable_get(:@placement)] } }
              apply_grid_origins(proposed)
              @grid_origins = proposed
              begin
                add(child)
              rescue StandardError
                restore_attachment(child, previous)
                raise
              end
            end
            self
          end

          # Rebase remaining placements after detaching while keeping handles live.
          # @param child [Widget] same-session child governed by this container
          # @return [Grid] self
          def remove(child)
            session.synchronize do
              super
              @grid_origins.delete(child)
              apply_grid_origins(@grid_origins)
            end
            self
          end

          protected

          # Removes a retired child from the owning collection and refreshes layout.
          # @param child [Widget] same-session child governed by this container
          # @return [void] result is not part of the supported script contract
          # @api private
          def forget_child(child)
            @grid_origins.delete(child)
            super
            apply_grid_origins(@grid_origins) unless destroyed?
          end

          private

          # Restore both representations, including an already inserted child and
          # detached controls whose old placement exceeds this grid's old width.
          # @param child [Widget] same-session child governed by this container
          # @param previous [Hash] captured origins, dimensions and placements for rollback
          # @return [void] result is not part of the supported script contract
          # @api private
          def restore_attachment(child, previous)
            if child.parent.equal?(self)
              session.port.detach(@handle, child.materialize) if @handle
              @children.delete(child)
              child.parent = nil
            end
            @grid_origins = previous[:origins]
            previous[:placements].each { |widget, placement| widget.placement = placement }
            @columns, @n_rows = previous.values_at(:columns, :rows)
            @props[:cols] = @columns
            if @handle
              placements = previous[:placements].filter_map do |widget, placement|
                handle = widget.instance_variable_get(:@handle)
                [handle, placement || {}] if handle
              end.to_h
              child_handle = child.instance_variable_get(:@handle)
              child_placement = placements.delete(child_handle)
              expanding = layout_props.fetch(:expand_columns)
              session.port.layout_grid(@handle, columns: @columns, placements: placements, expand_columns: expanding)
              if child_handle
                # Separate the rejected child so a full grid's rollback stays
                # within the adapter's placement-map capacity.
                columns = [@columns, child_placement.fetch(:column, 1) + child_placement.fetch(:span, 1) - 1].max
                session.port.layout_grid(@handle, columns: columns, placements: { child_handle => child_placement }, expand_columns: expanding)
                session.port.layout_grid(@handle, columns: @columns, placements: {}, expand_columns: expanding) if columns != @columns
              end
            end
            session.refresh_label_styles
            refresh_layout!
          end

          # Rebases signed cell origins and publishes validated grid placements.
          # @param origins [Hash{Widget => Array<Integer>}] children and signed left/top/width/height cell origins
          # @return [void] result is not part of the supported script contract
          # @api private
          def apply_grid_origins(origins)
            left = [0, *origins.values.map(&:first)].min
            top = [0, *origins.values.map { |origin| origin[1] }].min
            placements = origins.to_h do |child, (x, y, width, height)|
              [child, { column: x - left + 1, row: y - top + 1, span: width, row_span: height }]
            end
            columns = [1, *placements.values.map { |p| p[:column] + p[:span] - 1 }].max
            rows = [1, *placements.values.map { |p| p[:row] + p[:row_span] - 1 }].max
            valid = columns <= 24 && rows <= Lich::WebUI::Contract::BOUNDS[:children]
            session.refuse(self, :attach) unless valid
            expanding = placements.flat_map do |child, p|
              child.expands?(:horizontal) ? (p[:column]...(p[:column] + p[:span])).to_a : []
            end.uniq.sort
            if @handle
              handles = placements.to_h { |child, p| [child.materialize, p] }
              session.port.layout_grid(@handle, columns: columns, placements: handles, expand_columns: expanding)
            end
            placements.each { |child, p| child.placement = p }
            @columns, @n_rows = columns, rows
            @props[:cols] = columns
            refresh_layout!
          end
        end
      end
    end
  end
end
