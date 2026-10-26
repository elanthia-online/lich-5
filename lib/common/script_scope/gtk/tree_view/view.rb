# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # A typed table projection of a script-owned model, with independent viewer state.
        class TreeView < Widget
          attr_reader :model, :selection

          # Creates a typed table with independent selection, expansion and cursor state.
          # @param model [ListStore, TreeStore, nil] same-session model
          def initialize(model = nil)
            super()
            @columns = []
            @selection = TreeSelection.new(self)
            @props.merge!(selection: 'single', selected: [], expanded: [], cursor: {}, headers: true, sort_mode: 'model')
            self.model = model if model
          end

          # Selected-row color uses the core's typed table property, including live writes.
          # Other states retain Widget's existing compatibility behavior.
          # @param state [Symbol] supported GTK state token
          # @param colour [Gdk::RGBA] typed bounded legacy color
          # @return [void] result is not part of the supported script contract
          def override_background_color(state, colour)
            return super unless state == :selected

            session.style_operation(self, :override_background_color) do
              session.refuse(self, :override_background_color) if destroyed? || !colour.is_a?(Gdk::RGBA)
              write(:selection_background, colour.to_h)
            end
          end

          # Returns a snapshot of attached columns without exposing their collection.
          # @return [Array<TreeViewColumn>] independent attached-column snapshot
          def columns = @columns.dup
          alias get_selection selection

          # Rebinds this view while leaving the previous model and other views intact.
          # @param model [ListStore, TreeStore, nil] replacement or nil to clear
          # @return [void] rebinding reconciles retained rows and refreshes presentation
          def model=(model)
            valid = model.nil? || (model.is_a?(ListStore) && model.session.equal?(session))
            session.refuse(self, :model=) unless valid
            session.synchronize do
              validate_columns(model)
              @model&.unwatch(self)
              @model = model
              model&.watch(self) unless destroyed?
              model_changed!
            end
          end
          alias set_model model=

          # Attaches a column during construction, before a live schema exists.
          # @param column [TreeViewColumn] same-owner column, before materialization
          # @return [Integer] number of columns
          def append_column(column)
            check_column_structure!
            session.refuse(self, :append_column) unless column.is_a?(TreeViewColumn) && column.session.equal?(session)
            column.attach(self)
            @columns << column
            @columns.length
          end

          # Controls header visibility independently of captions and model columns.
          # @param value [Boolean] explicit header visibility
          # @return [TreeView] self
          def headers_visible=(value)
            session.refuse(self, :headers_visible=) unless [true, false].include?(value)
            write(:headers, value)
          end
          alias set_headers_visible headers_visible=
          # Reads the retained table header visibility.
          def headers_visible? = read(:headers)

          # Selects a displayed String model column for viewer-local incremental search.
          # @param column [Integer] model column, or -1 to disable
          # @return [Integer] accepted model index
          def search_column=(column)
            session.refuse(self, :search_column=) unless column.is_a?(Integer) && column >= -1
            check_column_structure!
            @search_column = column
          end

          # Disables incremental keyboard search; explicit search entries remain independent.
          # @param value [Boolean] only false; enabling needs an explicit search column
          # @return [void] result is not part of the supported script contract
          def enable_search=(value)
            session.refuse(self, :enable_search=) unless value == false
            check_column_structure!
            @search_disabled = true
          end

          # Uses the shared table activation policy while retaining keyboard Enter.
          # @param value [Boolean] activate on a single click instead of a double click
          # @return [void] result is not part of the supported script contract
          def activate_on_single_click=(value)
            session.refuse(self, :activate_on_single_click=) unless [true, false].include?(value)
            write(:activation, value ? :single : :double)
          end

          # GTK's fixed-row measurement optimization is omitted; browser layout measures rows.
          # @param value [Boolean] requested measurement optimization
          # @return [void]
          def fixed_height_mode=(value)
            session.refuse(self, :fixed_height_mode=) unless [true, false].include?(value)
            session.degrade(:fixed_height_mode, 'GTK row measurement optimization omitted; browser measures row heights') if value
          end

          # Maps a bounded grid-line policy to the shared table presentation.
          # @param value [Symbol] :none, :horizontal, :vertical or :both
          # @return [TreeView] self
          def enable_grid_lines=(value)
            session.refuse(self, :enable_grid_lines=) unless %i[none horizontal vertical both].include?(value)
            write(:grid_lines, value)
          end
          alias set_enable_grid_lines enable_grid_lines=

          # Resolves the current viewer cursor back to a model path and column.
          # @return [Array(TreePath, TreeViewColumn), Array(nil, nil)] viewer cursor
          def cursor
            state = view_state(:cursor)
            iter = model&.find_key(state[:row])
            [iter&.path, @columns.find { |column| column.key == state[:column] }]
          end

          # Selects and focuses a row/cell. Starting an editor programmatically is unsupported.
          # @param path [TreePath, String, Array<Integer>] model path
          # @param column [TreeViewColumn, nil] optional visible column
          # @param start_editing [Boolean] must be false
          # @return [TreeView] self
          def set_cursor(path, column = nil, start_editing = false)
            iter = model&.get_iter(path)
            valid = iter && start_editing == false && (column.nil? || visible_columns.include?(column))
            session.refuse(self, :set_cursor) unless valid
            state = { row: iter.key }
            state[:column] = column.key if column
            write(:cursor, state)
            select_keys([iter.key]) unless selection.mode == :none
            self
          end

          # Requests expansion of every current parent row.
          # @return [void] result is not part of the supported script contract
          def expand_all = write(:expanded, parent_keys)
          # Clears expanded parent identities for the attributed viewer.
          # @return [void] result is not part of the supported script contract
          def collapse_all = write(:expanded, [])
          # Resolves the current row identity before reading viewer expansion.
          # @param path [TreePath, String, Array<Integer>] current model path
          def row_expanded?(path) = view_state(:expanded).include?(model&.get_iter(path)&.key)

          # Expands a parent and optionally all of its descendant parents.
          # @param path [TreePath, String, Array<Integer>] parent row
          # @param open_all [Boolean] also expand all descendant parents
          # @return [Boolean] false for a leaf/missing row
          def expand_row(path, open_all = false)
            session.refuse(self, :expand_row) unless [true, false].include?(open_all)
            iter = model&.get_iter(path)
            return false unless iter && parent_keys.include?(iter.key)
            keys = [iter.key]
            if open_all
              prefix = iter.path.indices
              keys |= model.rows.select { |row| row.path.indices.first(prefix.length) == prefix }.map(&:key) & parent_keys
            end
            write(:expanded, view_state(:expanded) | keys)
            true
          end

          # Collapses a parent while retaining descendant expansion choices.
          # @param path [TreePath, String, Array<Integer>] row to collapse
          # @return [Boolean] whether an expanded row was collapsed
          def collapse_row(path)
            iter = model&.get_iter(path)
            return false unless iter && row_expanded?(path)
            write(:expanded, view_state(:expanded) - [iter.key])
            true
          end

          # Detaches nonvisual observers during both direct and ancestor destruction.
          # @return [void]
          def mark_destroyed
            model&.unwatch(self)
            @columns.each(&:release)
            super
          end

          # Retains selection, expansion and cursor before terminal callbacks/closure.
          # @return [void]
          def commit_inputs
            if @handle && !destroyed?
              %i[selected expanded cursor].each do |property|
                @committed[property] = session.with_widget(self) { session.port.get(@handle, property) }
              end
            end
            super
          end

          # Resolves surviving selected identities in current model order.
          # @return [Array<TreeIter>] current viewer's surviving selected rows
          # @api private
          def selected_iters
            keys = (view_state(:selected) || []).to_h { |key| [key, true] }
            model ? model.rows.select { |iter| keys[iter.key] } : []
          end

          # Updates the target viewer's selection and emits changed only when it changes.
          # @param keys [Array<String>] same-model identities
          # @return [TreeView] self
          # @api private
          def select_keys(keys)
            session.refuse(self, :selection) if selection.mode == :none && !keys.empty?
            return self if selection.mode == :browse && keys.empty? && model && !model.empty?
            previous = view_state(:selected)
            keys = selection.filter_keys(previous, keys)
            write(:selected, keys)
            selection.changed! unless previous == keys
            self
          end

          # Reconciles selection before publishing a different selection policy.
          # @param mode [Symbol] validated GTK selection mode
          # @return [void]
          # @api private
          def selection_mode_changed(mode)
            keys = view_state(:selected)
            keys = [] if mode == :none
            keys = keys.first(1) unless mode == :multiple
            keys = model.rows.first(1).map(&:key) if mode == :browse && keys.empty? && model
            write(:selected, [])
            write(:selection, mode == :multiple ? 'multi' : mode.to_s)
            write(:selected, keys)
          end

          # Reprojects only shared data; live viewer state is reconciled by row identity in core.
          # @return [void]
          # @api private
          def model_changed!
            return if destroyed?
            rows = if @handle
                     @validated_rows && @validated_model.equal?(model) && @validated_revision == model&.revision ? @validated_rows : row_definitions
                   end
            # Before materialization only retained identities need reconciliation;
            # no renderer reads cell values just to populate an unseen model.
            survives = ->(key) { model&.find_key(key) }
            %i[selected expanded].each do |property|
              @props[property] = @props[property].select(&survives)
              @committed[property] = @committed[property].select(&survives) if @committed.key?(property)
            end
            @props[:cursor] = {} unless survives.call(@props[:cursor][:row])
            if @committed[:cursor] && !survives.call(@committed[:cursor][:row])
              @committed[:cursor] = {}
            end
            if @props[:selection] == 'browse' && @props[:selected].empty?
              @props[:selected] = [model&.iter_first&.key].compact
            end
            write(:rows, rows) if @handle
          ensure
            @validated_rows = @validated_model = @validated_revision = nil
          end

          # Checks a candidate model snapshot without changing this view or its live adapter.
          # @return [void]
          # @api private
          def model_will_change!
            props = @handle ? component_props : unmaterialized_model_props
            keys = props[:rows].map { |row| row[:key] }
            props[:selected] = props[:selected] & keys
            props[:expanded] = props[:expanded] & keys
            props[:cursor] = {} unless keys.include?(props[:cursor][:row])
            Lich::WebUI::Validator.new.validate_component!(:table, props, owner: 'shim', page_id: nil, cid: nil)
            if @handle
              @validated_rows, @validated_model, @validated_revision = props[:rows], model, model&.revision
            end
          end

          # Validates renderer configuration before updating live column definitions.
          # @return [void]
          # @api private
          def columns_changed!
            @validated_rows = @validated_model = @validated_revision = nil
            validate_columns(model)
            if @handle
              write(:columns, column_definitions)
              write(:sortable, visible_columns.any?(&:sort_column_id))
              write(:rows, row_definitions)
            end
          end

          # Structural column edits are bounded to construction; no partial live schema is published.
          # @return [void]
          # @api private
          def check_column_structure!
            session.refuse(self, :column_structure) if @handle
          end

          protected

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :table
          # Maps supported GTK signal spellings to shared component events.
          # @return [Hash{String => Symbol}] accepted GTK signals and shared events
          # @api private
          def signal_map = { 'row_activated' => :row_activate, 'row_expanded' => :row_toggle, 'row_collapsed' => :row_toggle, 'cursor_changed' => :cursor_change }
          # Lists component events needed independently of script connections.
          # @return [Array<Symbol>] required shared event names
          # @api private
          def builtin_events = %i[selection_change cell_edit sort_change column_activate] + (@drag_destination ? [:row_drop] : [])

          # Combines shadow properties with the current shared presentation.
          # @return [Hash] shared presentation properties
          # @api private
          def component_props
            validate_columns(model)
            @props.merge(columns: column_definitions, rows: row_definitions, sortable: visible_columns.any?(&:sort_column_id)).merge(search_props)
          end

          # Search is deliberately bounded to a visible plain-text column.
          # @return [Hash] optional shared search-column declaration
          # @api private
          def search_props
            return {} if @search_disabled || @search_column.nil? || @search_column == -1
            # Numeric text renderers already project their display text; prefix
            # search uses that same representation, without changing model types.
            column = visible_columns.find { |item| item.value_column == @search_column }
            session.refuse(self, :search_column) unless column && [String, Integer, Float].include?(model&.get_column_type(@search_column))
            { search_column: column.key }
          end

          # Events resolve current paths from stable IDs; removed rows cannot target their replacements.
          # @param event [Symbol] validated shared event
          # @return [String] binding ID
          # @api private
          def bind_event(event)
            return super if event == :pointer_press
            callback = proc do |context|
              session.callback(context, terminal: %i[row_activate row_drop].include?(event), widget: self) do
                payload = context.payload
                iter = model&.find_key(payload[:row])
                case event
                when :column_activate
                  column = visible_columns.find { |candidate| candidate.key == payload[:column] }
                  column.emit_clicked if column&.activatable?
                when :row_drop then dispatch_row_drop(context)
                when :selection_change then selection.changed!
                when :cell_edit
                  column = visible_columns.find { |candidate| candidate.key == payload[:column] }
                  column.renderer.emit_edit(iter.path.to_s, payload[:value]) if iter && column && column.sensitive_for?(iter)
                when :sort_change
                  column = visible_columns.find { |candidate| candidate.key == payload[:column] }
                  model.set_sort_column_id(column.sort_column_id, payload[:direction] == 'asc' ? :ascending : :descending) if model && column&.sortable?
                when :row_activate
                  column = visible_columns.find { |candidate| candidate.key == payload[:column] }
                  emit_row(event, 'row_activated', iter.path, column) if iter
                when :row_toggle
                  emit_row(event, payload[:expanded] ? 'row_expanded' : 'row_collapsed', iter, iter.path) if iter
                when :cursor_change then emit_row(event, 'cursor_changed') if iter
                end
              end
            ensure
              # The callback must finish committing or rolling back before a
              # no-op/failing editor is repainted from authoritative model data.
              session.synchronize { model_changed! } if event == :cell_edit
            end
            if event == :selection_change
              view = self
              callback.define_singleton_method(:prepare_selection) do |context|
                view.session.callback(context, widget: view) do
                  { rows: view.selection.filter_keys(view.send(:view_state, :selected), context.payload[:rows]) }
                end
              end
            end
            session.port.bind(@handle, event, callback)
          end

          private

          # Model insertion/setters already enforce row count, depth, identities and
          # scalar types. An unseen view needs only column/editor validation and the
          # rows referenced by retained state. Empty cell maps avoid reading every
          # cell; omitted parents rely on the model's checked tree invariant.
          # Full projection validation still runs when the view is materialized.
          # @return [Hash] candidate schema and retained row identities
          # @api private
          def unmaterialized_model_props
            validate_columns(model)
            keys = (@props[:selected] + @props[:expanded] + [@props[:cursor][:row]]).compact.uniq
            rows = keys.filter_map { |key| { key: key, cells: {} } if model&.find_key(key) }
            @props.merge(columns: column_definitions, rows: rows, sortable: visible_columns.any?(&:sort_column_id))
          end

          # Selects the columns included in shared table presentation.
          # @return [Array<TreeViewColumn>] columns included in presentation
          # @api private
          def visible_columns = @columns.select(&:visible?)
          # Builds the visible shared columns, including the empty-table placeholder.
          # @return [Array<Hash>] shared column records
          # @api private
          def column_definitions = visible_columns.empty? ? [{ key: 'empty', label: '' }] : visible_columns.map(&:definition)
          # Collects stable identities for current parent rows.
          # @return [Array<String>] identities of current parent rows
          # @api private
          def parent_keys = model ? model.rows.select { |iter| model.iter_has_child?(iter) }.map(&:key) : []

          # Uses live viewer state only inside callbacks, and retained/default state afterward.
          # @param property [Symbol] selected, expanded or cursor
          # @return [Array, Hash] scoped table state
          # @api private
          def view_state(property)
            session.flush_models!
            if @handle && !destroyed? && session.in_callback?
              session.with_widget(self) { session.port.get(@handle, property) } || @props[property]
            else
              @committed.fetch(property, @props[property])
            end
          end

          # Checks model-column mappings before exposing a table projection.
          # @param candidate [ListStore, nil] candidate backing model
          # @return [void]
          # @api private
          def validate_columns(candidate)
            return unless candidate
            visible_columns.each do |column|
              type = candidate.get_column_type(column.value_column)
              session.refuse(self, :cell_type) if column.renderer.is_a?(CellRendererToggle) && type != TrueClass
              candidate.get_column_type(column.sort_column_id) if column.sort_column_id
              column.validate_background_binding(candidate)
              column.validate_sensitive_binding(candidate)
            end
          end

          # Serializes scalar cells and stable parent identities, never Ruby model objects.
          # @return [Array<Hash>] shared rows in model order
          # @api private
          def row_definitions
            return [] unless model
            model.rows.map do |iter|
              foregrounds = []
              cells = visible_columns.to_h do |column|
                value, foreground = column.project_cell(model, iter)
                foregrounds << { column: column.key, color: foreground } if foreground
                [column.key, value.nil? ? '' : value]
              end
              row = { key: iter.key, cells: cells }
              row[:cell_foregrounds] = foregrounds unless foregrounds.empty?
              disabled_cells = visible_columns.reject { |column| column.sensitive_for?(iter) }.map(&:key)
              row[:cell_disabled] = disabled_cells unless disabled_cells.empty?
              disabled = visible_columns.reject { |column| column.background_enabled?(iter) }.map(&:key)
              row[:background_disabled] = disabled unless disabled.empty?
              parent = model.iter_parent(iter)
              row[:parent] = parent.key if parent
              row
            end
          end

          # Keeps expanded/collapsed handlers distinct although they share one wire event.
          # @param event [Symbol] contracted event
          # @param signal [String] normalized GTK signal
          # @param args [Array<Object>] resolved GTK arguments
          # @return [void]
          # @api private
          def emit_row(event, signal, *args)
            @signals.fetch(event, []).dup.each { |name, handler| handler.call(self, *args) if name == signal }
          end
        end
      end
    end
  end
end
