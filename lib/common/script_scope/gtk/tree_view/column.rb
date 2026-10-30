# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # One literal renderer per visible column. Column identities survive model mutations.
        class TreeViewColumn < ModelObject
          attr_reader :renderer, :value_column, :view, :key, :title, :sort_column_id

          # Creates one presentation column with a stable identity and optional renderer.
          # @param title [String] header caption
          # @param renderer [CellRendererText, nil] text/toggle/choice renderer
          # @param attributes [Hash] text or active mapped to a model column
          def initialize(title = '', renderer = nil, attributes = {})
            super()
            @title, @visible, @resizable, @width = String(title), true, false, nil
            @value_column, @sort_column_id = 0, nil
            @key = "c#{SecureRandom.hex(8)}"
            pack_start(renderer, true) if renderer
            set_attributes(renderer, attributes) unless attributes.empty?
          end

          # Attaches the single supported cell renderer to this column.
          # @param renderer [CellRendererText] one same-owner renderer
          # @param expand [Boolean] supported single-renderer allocation flag
          # @return [TreeViewColumn] self
          def pack_start(renderer, expand)
            view&.check_column_structure!
            valid = renderer.is_a?(CellRendererText) && renderer.session.equal?(session) && [true, false].include?(expand)
            session.refuse(self, :pack_start) unless valid && !@renderer
            @renderer = renderer
            renderer.watch(self)
            self
          end

          # Adds supplied mappings while preserving the renderer's other column bindings.
          # @param renderer [CellRendererText] this column's renderer
          # @param attributes [Hash] partial value, background_set and sensitive bindings
          # @return [TreeViewColumn] self
          def set_attributes(renderer, attributes)
            view&.check_column_structure!
            normalized = attributes.transform_keys(&:to_s)
            valid = renderer.equal?(@renderer) && (normalized.keys - [renderer.value_attribute, 'background_set', 'sensitive']).empty?
            column = normalized.fetch(renderer.value_attribute, @value_column)
            session.refuse(self, :set_attributes) unless valid && column.is_a?(Integer) && column >= 0
            background_column = normalized.fetch('background_set', @background_set_column)
            valid_background = background_column.nil? || (background_column.is_a?(Integer) && background_column.between?(0, Lich::WebUI::Contract::BOUNDS[:table_columns] - 1))
            session.refuse(self, :set_attributes) unless valid_background
            sensitive_column = normalized.fetch('sensitive', @sensitive_column)
            valid_sensitive = sensitive_column.nil? || (sensitive_column.is_a?(Integer) && sensitive_column.between?(0, Lich::WebUI::Contract::BOUNDS[:table_columns] - 1))
            session.refuse(self, :set_attributes) unless valid_sensitive
            if view&.model
              type = view.model.get_column_type(column)
              session.refuse(self, :cell_type) if renderer.is_a?(CellRendererToggle) && type != TrueClass
              session.refuse(self, :sensitive) if sensitive_column && view.model.get_column_type(sensitive_column) != TrueClass
            end
            @sensitive_column = sensitive_column
            @value_column = column
            @background_set_column = background_column
            changed!
            self
          end

          # Adds one model-column binding without replacing other attributes.
          # @param renderer [CellRendererText] same-session renderer attached to this column
          # @param name [String, Symbol] supported GTK operation, property or signal spelling
          # @param column [Integer] model column supplying this attribute
          # @return [TreeViewColumn] self
          def add_attribute(renderer, name, column) = set_attributes(renderer, name => column)
          # Reads whether this column participates in table presentation.
          def visible? = @visible

          # Controls column visibility before the view is materialized.
          # @param value [Boolean] visibility; structural changes must precede materialization
          # @return [Boolean]
          def visible=(value)
            session.refuse(self, :visible=) unless [true, false].include?(value)
            view&.check_column_structure!
            @visible = value
          end

          # Only requested columns share spare width; cell-renderer expansion is separate.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [void] result is not part of the supported script contract
          def expand=(value)
            session.refuse(self, :expand=) unless [true, false].include?(value)
            @expand = value
            changed!
          end
          alias set_expand expand=
          # Reports whether the column explicitly requests surplus width.
          def expand? = @expand == true

          # Updates the header caption without changing the column identity.
          # @param value [String] header caption
          # @return [void] caption changes notify the owning view
          def title=(value)
            @title = String(value)
            changed!
          end
          alias set_title title=

          # Enables the shared browser column-width interaction.
          # @param value [Boolean] enable browser column resizing
          # @return [void] resize policy changes notify the owning view
          def resizable=(value)
            session.refuse(self, :resizable=) unless [true, false].include?(value)
            @resizable = value
            changed!
          end
          alias set_resizable resizable=

          # Applies a bounded positive initial column width.
          # @param value [Integer] positive column width
          # @return [void] width changes notify the owning view
          def fixed_width=(value)
            session.refuse(self, :fixed_width=) unless value.is_a?(Integer) && value.between?(1, 65_536)
            @width = value
            changed!
          end
          alias set_fixed_width fixed_width=

          # A minimum is retained independently of authored/viewer widths.
          # @param value [Integer] bounded layout or model integer request
          # @return [void] result is not part of the supported script contract
          def min_width=(value)
            session.refuse(self, :min_width=) unless value.is_a?(Integer) && value.between?(0, 65_536)
            @min_width = value
            changed!
          end
          alias set_min_width min_width=

          # Retains bounded literal tooltip text and refreshes the column definition.
          # @param value [String] bounded literal header tooltip
          # @return [void] result is not part of the supported script contract
          def set_tooltip_text(value)
            session.refuse(self, :tooltip_text=) unless value.is_a?(String) && value.valid_encoding? && value.length <= Lich::WebUI::Contract::BOUNDS[:body_text]
            @tooltip = value.dup.freeze
            changed!
          end
          alias tooltip_text= set_tooltip_text
          # Reads retained literal tooltip text.
          # @return [String, nil] authored literal header tooltip
          def tooltip_text = @tooltip

          # Column clicks run script callbacks; they need not imply built-in sorting.
          # @param name [String, Symbol] supported GTK operation, property or signal spelling
          # @param handler [Proc] callback invoked with this object and its signal arguments
          # @return [Integer] connection count
          def signal_connect(name, &handler)
            session.refuse(self, :signal_connect) unless name.to_s == 'clicked' && handler
            (@click_handlers ||= []) << handler
            changed!
            @click_handlers.length
          end

          # Reports whether this compatibility object admits activation.
          def activatable? = @clickable == true && !Array(@click_handlers).empty?
          # Invokes a snapshot of connected column activation handlers.
          # @return [void] result is not part of the supported script contract
          def emit_clicked = Array(@click_handlers).dup.each { |handler| handler.call(self) }

          # Project the measured text renderer through the existing row snapshot.
          # @param renderer [CellRendererText] same-session renderer attached to this column
          # @param handler [Proc] callback invoked with this object and its signal arguments
          # @return [TreeViewColumn] self
          def set_cell_data_func(renderer, &handler)
            view&.check_column_structure!
            session.refuse(self, :set_cell_data_func) unless [CellRendererText, CellRendererCombo].include?(renderer.class) && renderer.equal?(@renderer) && handler
            @cell_data_func = handler
            changed!
            self
          end

          # Projects one model row through the configured literal cell-data callback.
          # @param model [ListStore, TreeStore] same-session backing model
          # @param iter [TreeIter] live row in the owning view model
          # @return [Array(Object, Hash), Array(Object, nil)] literal value and optional typed foreground
          def project_cell(model, iter)
            value = iter[value_column]
            value = '' if value.nil?
            renderer.project_cell(value) { @cell_data_func&.call(self, renderer, model, iter) }
          end

          # Fixed GTK column measurement uses browser allocation and any explicit width.
          # @param value [Symbol] only :fixed is accepted
          # @return [void]
          def sizing=(value)
            session.refuse(self, :sizing=) unless value == :fixed
            session.degrade(:column_sizing, 'fixed column measurement uses browser layout and explicit column widths')
          end

          # Maps the header gesture to built-in sorting on a model column.
          # @param column [Integer] model column used by built-in scalar sorting
          # @return [void] sort mapping changes notify the owning view
          def sort_column_id=(column)
            session.refuse(self, :sort_column_id=) unless column.is_a?(Integer) && column >= 0
            @sort_column_id = column
            changed!
          end
          alias set_sort_column_id sort_column_id=

          # Controls header interaction: false disables sorting and activation;
          # true permits connected clicked callbacks even without a sort column.
          # Built-in sorting additionally requires sort_column_id.
          # @param value [Boolean] whether the header accepts clicks
          # @return [void] result is not part of the supported script contract
          def clickable=(value)
            session.refuse(self, :clickable=) unless [true, false].include?(value)
            @clickable = value
            changed!
          end

          # Reports whether a model sort column is enabled for header interaction.
          def sortable? = !sort_column_id.nil? && @clickable != false

          # Assigns one owning view; columns cannot be shared between views.
          # @param owner [TreeView] single owning view
          # @return [void]
          # @api private
          def attach(owner)
            session.refuse(self, :attach) unless !view && owner.session.equal?(session)
            @view = owner
          end

          # Detaches this column from its renderer observer list.
          # @return [void] result is not part of the supported script contract
          def release = renderer&.unwatch(self)
          # Refreshes the owning view after a column presentation change.
          # @return [void] result is not part of the supported script contract
          def changed! = view&.columns_changed!

          # Warn on an invalid optional GTK binding while retaining the literal fill.
          # @param model [ListStore, TreeStore] same-session backing model
          # @return [void] result is not part of the supported script contract
          def validate_background_binding(model)
            @background_boolean_model = nil
            return unless @background_set_column

            if model.column_types[@background_set_column] == TrueClass
              @background_boolean_model = model
            elsif @background_warning_for != [model, @background_set_column]
              session.source_warning(self, :background_set, "ignored invalid background_set model column #{@background_set_column}; expected boolean; literal renderer background retained")
              @background_warning_for = [model, @background_set_column]
            end
          end

          # A sensitivity binding must name an actual boolean model column.
          # @param model [ListStore, TreeStore] same-session backing model
          # @return [void] result is not part of the supported script contract
          def validate_sensitive_binding(model)
            session.refuse(self, :sensitive) if @sensitive_column && model.get_column_type(@sensitive_column) != TrueClass
          end

          # Reads a row-specific boolean sensitivity binding when configured.
          # @param iter [TreeIter] live row in the owning view model
          def sensitive_for?(iter) = @sensitive_column.nil? || iter[@sensitive_column] == true

          # Reads a valid boolean background binding or retains the literal fill.
          # @param iter [TreeIter] live row in the owning view model
          def background_enabled?(iter)
            !@background_boolean_model.equal?(iter.model) || iter[@background_set_column] == true
          end

          # Projects the supported renderer properties into the shared table schema.
          # @return [Hash] shared column schema
          # @api private
          def definition
            session.refuse(self, :renderer) unless renderer
            result = { key: key, label: title, resizable: @resizable, sortable: sortable? }
            result[:expand] = @expand unless @expand.nil?
            result[:activatable] = activatable?
            result[:tooltip] = @tooltip if @tooltip
            result[:min_width] = @min_width if @min_width
            result[:align] = renderer.align if renderer.align
            result[:width] = @width if @width
            result[:editor] = renderer.editor if renderer.editor
            result[:background] = renderer.background_color if renderer.background_color
            result
          end
        end
      end
    end
  end
end
