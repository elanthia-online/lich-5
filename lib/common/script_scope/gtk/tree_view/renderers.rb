# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # Literal scalar cell presentation. Editing proposes a value; only script callbacks
        # may commit it to the model. Cell-data functions project literal text and color.
        class CellRendererText < ModelObject
          attr_reader :editable, :align, :background_color

          # Creates an uneditable renderer with no dependent columns or handlers.
          def initialize
            super
            @editable, @handlers, @columns = false, [], []
          end

          # Enables edit proposals and updates already attached column definitions.
          # Callers ignore the method result; Ruby assignment expressions still
          # evaluate to their right-hand value.
          # @param value [Boolean] whether the browser may propose an edit
          # @return [void]
          def editable=(value)
            session.refuse(self, :editable=) if @projecting_cell
            session.refuse(self, :editable=) unless value == true || value == false
            @editable = value
            @columns.each(&:changed!)
          end
          alias set_editable editable=
          # Reports whether this renderer accepts text edit proposals.
          def editable? = editable

          # Literal cell fill is a typed color, never a CSS string or selector.
          # Nil clears the fill so the table theme is visible again.
          # @param value [String] bounded literal text for this presentation property
          # @return [void] result is not part of the supported script contract
          def background=(value)
            session.refuse(self, :background=) if @projecting_cell
            session.style_operation(self, :background=) do
              valid = value.is_a?(String) && value.valid_encoding? && value.encoding.ascii_compatible? && value.length <= 64
              color = Color.parse(value) if valid
              session.refuse(self, :background=) unless value.nil? || color
              @background_color = color
              @columns.each(&:changed!)
            end
          end
          alias set_background background=

          # Maps cell alignment fractions to the existing column alignment tokens.
          # @param value [Numeric] 0..1; intermediate fractions use center
          # @return [void] result is not part of the supported script contract
          def xalign=(value)
            session.refuse(self, :xalign=) if @projecting_cell
            session.refuse(self, :xalign=) unless value.is_a?(Numeric) && value.between?(0, 1)
            @align = value.zero? ? :start : (value == 1 ? :end : :center)
            @columns.each(&:changed!)
          end

          # Registers only the signal supported by this compatibility object.
          # @param name [String, Symbol] only edited (or toggled for toggle renderers)
          # @param handler [Proc] callback invoked with this object and its signal arguments
          # @yieldparam renderer [CellRendererText] emitting object
          # @yieldparam path [String] current model path
          # @yieldparam text [String] proposed text; omitted for toggled
          # @return [Integer] connection count
          def signal_connect(name, &handler)
            session.refuse(self, :signal_connect) unless name.to_s == signal_name && handler
            @handlers << handler
            @handlers.length
          end

          # Routes a named property through the same bounded setters as direct calls.
          # @param name [String, Symbol] supported property name
          # @param value [Object] property value
          # @return [Object] setter result
          def set_property(name, value)
            setter = "#{name.to_s.tr('-', '_')}="
            session.refuse(self, name) unless respond_to?(setter)
            public_send(setter, value)
          end

          # Retains a same-owner dependent column for subsequent configuration updates.
          # @param column [TreeViewColumn] owning presentation column
          # @return [void]
          # @api private
          def watch(column)
            session.refuse(self, :watch) unless column.session.equal?(session)
            @columns << column unless @columns.include?(column)
          end

          # Removes a dependent column from subsequent configuration notifications.
          # @param column [TreeViewColumn] dependent column observing renderer configuration
          # @return [void] result is not part of the supported script contract
          def unwatch(column) = @columns.delete(column)

          # Literal display text is independent of the model's identity/sort value.
          # @param value [Object] literal text converted with String before publication
          # @return [void] result is not part of the supported script contract
          def text=(value)
            session.refuse(self, :text=) unless value.is_a?(String) && value.valid_encoding? && value.length <= Lich::WebUI::Contract::BOUNDS[:body_text]
            @cell_text = value.dup.freeze
            @columns.each(&:changed!) unless @projecting_cell
          end

          # Reads the current literal cell-data projection.
          # @return [String, nil] current literal cell text
          def text = @cell_text

          # Retains a typed cell foreground and refreshes dependent columns.
          # @param value [Gdk::RGBA, nil] typed foreground; nil restores theme color
          # @return [void] result is not part of the supported script contract
          def foreground_rgba=(value)
            session.refuse(self, :foreground_rgba=) unless value.nil? || value.is_a?(Gdk::RGBA)
            @cell_foreground = value&.to_h
            @cell_foreground_set = !value.nil?
            @columns.each(&:changed!) unless @projecting_cell
          end

          # Clearing the flag restores the theme without discarding the chosen color.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [void] result is not part of the supported script contract
          def foreground_set=(value)
            session.refuse(self, :foreground_set=) unless [true, false].include?(value)
            @cell_foreground_set = value
            @columns.each(&:changed!) unless @projecting_cell
          end

          # A renderer is reused across rows. Restore its defaults even if a
          # source callback fails, so later rows/columns cannot inherit that row.
          # @param value [Object] literal scalar value for this row projection
          # @return [Array(Object, Hash), Array(Object, nil)] literal value and optional typed foreground
          # @api private
          def project_cell(value)
            session.refuse(self, :cell_data_recursion) if @projecting_cell
            saved = [@cell_text, @cell_foreground, @cell_foreground_set, @projecting_cell]
            @cell_text, @projecting_cell = value, true
            yield if block_given?
            [@cell_text, @cell_foreground_set == false ? nil : @cell_foreground]
          ensure
            @cell_text, @cell_foreground, @cell_foreground_set, @projecting_cell = saved if saved
          end

          # Projects the renderer into the shared table editor declaration.
          # @return [Hash, nil] shared editor schema or nil when disabled
          def editor = editable ? { type: 'text' } : nil
          # Names the GTK model attribute supplying this renderer value.
          # @return [String] model attribute spelling
          def value_attribute = 'text'
          # Names the GTK proposal signal emitted by this renderer.
          # @return [String] GTK proposal signal spelling
          def signal_name = 'edited'

          # Dispatches the renderer signal without changing the model first.
          # @param path [String] current model path, resolved from the stable event row
          # @param value [Object] proposed scalar
          # @return [void]
          # @api private
          def emit_edit(path, value)
            @handlers.dup.each { |handler| handler.call(self, path, value.to_s) }
          end
        end

        # A boolean cell whose toggled signal carries a path and never pre-mutates its row.
        class CellRendererToggle < CellRendererText
          # Creates an activatable boolean cell renderer.
          def initialize
            super
            @editable = true
          end

          alias activatable= editable=
          alias set_activatable editable=
          # Reports whether this compatibility object admits activation.
          def activatable? = editable
          # Names the GTK model attribute supplying this renderer value.
          # @return [String] model attribute spelling
          def value_attribute = 'active'
          # Names the GTK proposal signal emitted by this renderer.
          # @return [String] GTK proposal signal spelling
          def signal_name = 'toggled'
          # Projects the renderer into the shared table editor declaration.
          # @return [Hash, nil] shared editor schema or nil when disabled
          def editor = { type: 'checkbox', disabled: !editable }

          # Dispatches the renderer signal without changing the model first.
          # @param path [String] current model path
          # @param _value [Boolean] proposal; the script owns the actual toggle
          # @return [void]
          # @api private
          def emit_edit(path, _value)
            @handlers.dup.each { |handler| handler.call(self, path) }
          end
        end

        # A closed text-choice editor backed by a same-owner flat store.
        class CellRendererCombo < CellRendererText
          attr_reader :model, :text_column

          # Creates an unbound closed-choice renderer with its first text column.
          def initialize
            super
            @model, @text_column = nil, 0
            @changed_handlers = []
          end

          # Choice changes carry an actual iterator, while edited keeps literal text.
          # @param name [String, Symbol] supported GTK operation, property or signal spelling
          # @param handler [Proc] callback invoked with this object and its signal arguments
          # @return [Integer] connection count
          def signal_connect(name, &handler)
            return super unless name.to_s == 'changed'

            session.refuse(self, :signal_connect) unless handler
            @changed_handlers << handler
            model_changed!
            @handlers.length + @changed_handlers.length
          end

          # Dispatches choice and text proposals while the selected row remains live.
          # @param path [TreePath, String, Array<Integer>] current model path
          # @param value [String] stable choice identity or proposed literal cell text
          # @return [void] result is not part of the supported script contract
          def emit_edit(path, value)
            return super if @changed_handlers.empty?

            choice_model = model
            choice = choice_model&.find_key(value)
            return unless choice

            text = choice[text_column].to_s
            @changed_handlers.dup.each do |handler|
              break unless model.equal?(choice_model) && choice_model.iter_is_valid?(choice)
              handler.call(self, path, choice)
            end
            super(path, text)
          end

          # Rebinds the same-owner model and detaches the previous observer.
          # @param model [ListStore] flat same-owner choice model
          # @return [void] model changes notify dependent columns
          def model=(model)
            session.refuse(self, :model=) unless model.instance_of?(ListStore) && model.session.equal?(session)
            @model&.unwatch(self)
            @model = model
            model.watch(self) unless @columns.empty?
            model_changed!
          end
          alias set_model model=

          # Chooses the String column supplying choice labels.
          # @param column [Integer] string column used as the edited text
          # @return [void] text-column changes notify dependent columns
          def text_column=(column)
            session.refuse(self, :text_column=) unless column.is_a?(Integer) && column >= 0
            @text_column = column
            model_changed!
          end
          alias set_text_column text_column=

          # Freeform cell-combo entries need a separate editor contract.
          # @param value [Boolean] only false is supported
          # @return [void] accepts only the closed-choice mode
          def has_entry=(value)
            session.refuse(self, :has_entry=) unless value == false
          end

          # Retains a same-owner dependent column for subsequent configuration updates.
          # @param column [TreeViewColumn] dependent column observing renderer configuration
          # @return [void] result is not part of the supported script contract
          def watch(column)
            super
            @model&.watch(self)
          end

          # Releases a dependent column and any unused choice-model observer.
          # @param column [TreeViewColumn] dependent column observing renderer configuration
          # @return [void] result is not part of the supported script contract
          def unwatch(column)
            super
            @model&.unwatch(self) if @columns.empty?
          end

          # Refreshes dependent columns after a choice-model update.
          # @return [void] result is not part of the supported script contract
          def model_changed! = @columns.each(&:changed!)

          # Validates choice changes before the backing model publishes to any observer.
          # @return [void]
          # @api private
          def model_will_change!
            @columns.each { |column| column.view&.model_will_change! }
          end

          # Serializes labels as text values, deduplicating identical text choices only.
          # @return [Hash, nil] shared closed-choice editor
          # @api private
          def editor
            return nil unless editable
            session.refuse(self, :model) unless model && model.get_column_type(text_column) == String
            # Unset string cells display as blank choices, while the model keeps
            # nil for script callbacks just as it does for ordinary table cells.
            unless @changed_handlers.empty?
              choices = model.rows.map { |iter| { value: iter.key, label: iter[text_column].to_s } }
              session.refuse(self, :options) if choices.length > Lich::WebUI::Contract::BOUNDS[:collection]
              return { type: 'select', options: choices, option_labels: true }
            end
            values = model.rows.map { |iter| iter[text_column].to_s }.uniq
            session.refuse(self, :options) if values.length > Lich::WebUI::Contract::BOUNDS[:collection]
            { type: 'select', options: values.map { |text| { value: text, label: text } } }
          end
        end
      end
    end
  end
end
