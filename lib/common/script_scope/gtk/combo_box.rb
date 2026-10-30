# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # The entry child uses its combo's single shared input, never a second browser control.
        module ComboEntry
          # GTK exposes this child as an actual Entry, including exact .class
          # checks used by Builder scripts. Attach delegation to that Entry;
          # do not spoof reflection or allocate a second browser input.
          # @param combo [ComboBox] owning editable combo
          # @return [Entry] the combo's stable entry child
          def self.new(combo)
            Entry.new.extend(self).tap do |entry|
              entry.instance_variable_set(:@combo, combo)
              entry.instance_variable_set(:@parent, combo)
            end
          end

          def text = @combo.entry_text

          # Assigns literal free text through the owning combo's value contract.
          # @param value [String] literal free text, including blank
          # @return [ComboBox] owning combo
          def text=(value)
            @combo.set_entry_text(value)
          end
          alias set_text text=

          # This Entry shares its owning combo's single input and tooltip.
          def tooltip_text = @combo.tooltip_text
          alias get_tooltip_text tooltip_text

          # Applies the internal entry request to the existing shared input width.
          # @param value [Integer] pixel width, 1..1024; reset requests remain unsupported
          # @return [Entry] self
          def set_width_request(value)
            session.refuse(self, :width_request=) unless value.is_a?(Integer) && value.between?(1, 1024)
            @combo.send(:write, :control_width, value)
            self
          end
          alias width_request= set_width_request

          # The owning select has no character-limit contract. Refuse before
          # Entry's setter changes child state or clears the combo's text.
          # @raise [UnsupportedOperation] internal entry limits are unsupported
          def set_max_length(_value)
            session.refuse(self, :max_length=)
          end
          alias max_length= set_max_length

          # The facade has no separate browser focus target. GTK's request to
          # suppress its focus is omitted; the combo remains keyboard accessible.
          def can_focus=(value)
            session.refuse(self, :can_focus=) unless [true, false].include?(value)
            session.degrade(:combo_entry_focus, 'internal combo entry focus hint is ignored; its single browser input remains keyboard accessible') unless value
          end
          alias set_can_focus can_focus=

          # A noneditable combo entry becomes the existing closed selector,
          # retaining this facade for text reads and option-change notifications.
          # It remains keyboard focusable; it is not a passive Label.
          def editable=(value)
            @combo.set_entry_editable(value)
          end
          alias set_editable editable=

          # Forwards changed notifications from the combo's single shared input.
          # @param name [String, Symbol] changed
          # @yieldparam entry [Entry] this entry
          # @return [Integer] handler count
          def signal_connect(name, &handler)
            session.refuse(self, :signal_connect) unless name.to_s == 'changed'
            super
          end

          # @raise [UnsupportedOperation] this facade cannot be packed independently
          def materialize
            session.refuse(self, :materialize)
          end

          protected

          # Character sizing, placeholder and tooltip belong to the combo's input.
          # Other entry writes still require an explicit shared-control mapping.
          def write(property, value)
            session.refuse(self, property) unless %i[min_width_chars max_width_chars placeholder tooltip margin].include?(property)
            @combo.send(:write, property == :margin ? :control_margin : property, value)
            self
          end

          # Internal entry spacing belongs to the input, independently of combo margins.
          def margin_value = @combo.send(:read, :control_margin)
          private :margin_value
        end

        # A flat model-backed select. Wire IDs name rows, so duplicate labels remain distinct.
        # The permanent blank sentinel represents active=-1 for both new and attached viewers.
        class ComboBox < Widget
          # GTK height requests are minima. Reuse the existing select minimum
          # without imposing a fixed height that could clip its entry or label.
          def set_height_request(value)
            write(:min_height, Integer(value))
          end
          alias height_request= set_height_request

          attr_reader :model, :child, :entry_text_column

          # Removes one local callback through the shared guarded connection registry.
          # @return [ComboBox] self
          def signal_handler_disconnect(id) = disconnect_signal_handler(id)

          # Creates a bounded model-backed combo or its single-input entry facade.
          # @param source [ListStore, Boolean, nil] model, or legacy text-only constructor flag
          # @param entry [Boolean] expose an editable entry child
          # @param has_entry [Boolean] equivalent legacy keyword
          def initialize(source = nil, entry: false, has_entry: false)
            super()
            valid = source.nil? || source == true || source == false || (source.instance_of?(ListStore) && source.session.equal?(session))
            valid &&= [true, false].include?(entry) && [true, false].include?(has_entry)
            session.refuse(self, :new) unless valid
            @entry_text_column, @label_column = 0, 0
            @props.merge!(options: [{ value: 'none', label: '' }], value: 'none', empty_value: 'none', editable: entry || has_entry)
            @props[:free_text_prefix] = 'text:' if @props[:editable]
            @child = ComboEntry.new(self) if @props[:editable]
            self.model = source.instance_of?(ListStore) ? source : ListStore.new(String)
          end

          def has_entry? = !child.nil?

          # Select the shared input presentation before publication. Runtime
          # changes would replace an input and need a separate lifecycle design.
          # @api private
          def set_entry_editable(value)
            session.synchronize do
              session.refuse(self, :entry_editable=) unless has_entry? && !@handle && [true, false].include?(value)
              choice = @props[:value]
              if !value && choice.start_with?('text:')
                # A closed select must retain a real option or the blank sentinel.
                # Resolve text before mutation so refusal never discards script state.
                choice = closed_entry_choice(choice.delete_prefix('text:'))
                session.refuse(self, :entry_editable=) unless choice
              end
              @props[:value] = choice
              @props[:editable] = value
              value ? @props[:free_text_prefix] = 'text:' : @props.delete(:free_text_prefix)
            end
          end

          # Editable combos delegate focus to their existing single input facade;
          # closed selects own focus themselves. No second focus target is created.
          # The facade survives closing, so its existence cannot determine focus.
          def can_focus=(value)
            session.refuse(self, :can_focus=) unless value == false || (value == true && !@props[:editable])
            if !@props[:editable] && value == false
              session.degrade(:combo_focus, 'closed combo focus hints are ignored; its single browser select remains keyboard accessible')
            end
          end
          alias set_can_focus can_focus=

          # Rebinds the options and clears a selection whose row belongs to the old model.
          # @param model [ListStore] same-owner flat store
          # @return [ListStore]
          def model=(model)
            session.refuse(self, :model=) unless model.instance_of?(ListStore) && model.session.equal?(session)
            validate_label_column(model, @label_column) if @handle
            session.synchronize do
              @model&.unwatch(self)
              @model = model
              model.watch(self) unless destroyed?
              model_changed!
            end
          end
          alias set_model model=

          # Maps labels to a validated String column without changing option identities.
          # @param column [Integer] String model column shown in the entry and options
          # @return [Integer]
          def entry_text_column=(column)
            validate_label_column(model, column)
            @entry_text_column = @label_column = column
            model_changed!
          end
          alias set_entry_text_column entry_text_column=

          # Accepts one text renderer; composite option cells remain unsupported.
          # @param renderer [CellRendererText] same-owner plain text renderer
          # @param expand [Boolean] single-renderer allocation flag
          # @return [ComboBox] self
          def pack_start(renderer, expand)
            valid = renderer.instance_of?(CellRendererText) && renderer.session.equal?(session) && [true, false].include?(expand)
            session.refuse(self, :pack_start) unless valid && !@renderer
            @renderer = renderer
            self
          end

          # Accepts the single text binding for the packed plain renderer.
          # @param renderer [CellRendererText] the packed renderer
          # @param name [String, Symbol] text
          # @param column [Integer] model label column
          # @return [Integer]
          def add_attribute(renderer, name, column)
            session.refuse(self, :add_attribute) unless renderer.equal?(@renderer) && name.to_s == 'text'
            self.entry_text_column = column
          end

          # Applies one text mapping through the same label-column validation.
          # @param renderer [CellRendererText] packed renderer
          # @param attributes [Hash] one text mapping
          # @return [Integer]
          def set_attributes(renderer, attributes)
            session.refuse(self, :set_attributes) unless attributes.keys.map(&:to_s) == ['text']
            add_attribute(renderer, :text, attributes.values.first)
          end

          def active_iter = model.find_key(read(:value))
          def active = model.rows.index(active_iter) || -1
          def active_text = has_entry? ? entry_text : active_iter&.[](@label_column)

          # Selects the first matching text row through the normal changed path.
          # This bounded convenience API never appends options or invents free text.
          # @param text [String] existing label in a single-String-column model
          # @return [ComboBox] self
          def set_active_text(text)
            session.refuse(self, :active_text=) unless text.is_a?(String) && text.length <= Lich::WebUI::Contract::BOUNDS[:short_text]
            session.synchronize do
              text_model!
              row = model.rows.find { |candidate| candidate[@label_column] == text }
              session.refuse(self, :active_text=) unless row
              set_choice(row.key)
            end
          end
          alias active_text= set_active_text

          # Named text items retain their script ID separately from stable wire row IDs.
          # @param id [String] unique script identifier, including an empty placeholder ID
          # @param text [String] literal display label
          # @return [ComboBox] self
          def append(id, text)
            text_model!
            session.refuse(self, :append) unless id.is_a?(String) && id.length <= 8192
            text = String(text)
            session.refuse(self, :append) if text.length > Lich::WebUI::Contract::BOUNDS[:short_text]
            session.synchronize do
              @item_ids ||= {}
              session.refuse(self, :append) if @item_ids.any? { |key, value| value == id && model.find_key(key) }
              iter = model.append
              iter[0] = text
              @item_ids[iter.key] = id.dup.freeze
            end
            self
          end

          # @return [String, nil] named active item, or nil for free text/unnamed rows
          def active_id = @item_ids&.[](active_iter&.key)

          # Selects an existing named item; missing IDs leave the selection intact.
          # @param id [String, nil] script ID, or nil to clear
          # @return [Boolean] whether the requested selection was found
          def set_active_id(id)
            return !!(self.active = -1) if id.nil?
            session.refuse(self, :set_active_id) unless id.is_a?(String)
            key = @item_ids&.find { |key, value| value == id && model.find_key(key) }&.first
            return false unless key
            set_choice(key)
            true
          end
          alias active_id= set_active_id

          # Selects by model position; a missing row leaves no active selection, like GTK.
          # @param index [Integer] GTK signed-int model index, or -1 to clear
          # @return [ComboBox] self
          def active=(index)
            session.refuse(self, :active=) unless index.is_a?(Integer) && index.between?(-1, 2_147_483_647)
            row = model.rows[index] unless index == -1
            set_choice(row ? row.key : 'none')
          end
          alias set_active active=

          # Selects an actual same-model row or explicitly clears with nil.
          # @param iter [TreeIter, nil] actual live model row, or nil to clear
          # @return [ComboBox] self
          def active_iter=(iter)
            session.refuse(self, :active_iter=) unless iter.nil? || model.iter_is_valid?(iter)
            set_choice(iter ? iter.key : 'none')
          end
          alias set_active_iter active_iter=

          # Appends a label to a single-String-column model.
          # @param text [String] text for a single-string-column model
          # @return [ComboBox] self
          def append_text(text)
            text_model!
            session.synchronize { model.append[0] = String(text) }
            self
          end

          # Prepends a label without changing existing row identities.
          # @param text [String] label to prepend
          # @return [ComboBox] self
          def prepend_text(text)
            text_model!
            session.synchronize { model.prepend[0] = String(text) }
            self
          end

          # Inserts a label at a model position without using its label as identity.
          # @param index [Integer] insertion position
          # @param text [String] new label
          # @return [ComboBox] self
          def insert_text(index, text)
            text_model!
            session.synchronize { model.insert(index)[0] = String(text) }
            self
          end

          # Removes one model row; viewer reconciliation clears only that retired choice.
          # @param index [Integer] row index to remove
          # @return [ComboBox] self
          def remove(index)
            session.refuse(self, :remove) unless index.is_a?(Integer) && index.between?(0, model.size - 1)
            model.remove(model.rows[index])
            self
          end

          def remove_all
            model.clear
            self
          end

          # Decodes literal entry text or resolves the currently selected label.
          # @return [String] selected label or literal viewer text
          # @api private
          def entry_text
            value = read(:value)
            return '' if value == 'none'
            # A selected row with an unset label is blank entry text, not a
            # free-text value; falling through would expose its internal row ID.
            row = model.find_key(value)
            row ? row[@label_column].to_s : value.delete_prefix('text:')
          end

          # Encodes literal text separately from option IDs and the clearing sentinel.
          # @param text [String] literal text for the entry facade
          # @return [ComboBox] self
          # @api private
          def set_entry_text(text)
            session.refuse(self, :text=) unless has_entry? && text.is_a?(String) && text.length <= Lich::WebUI::Contract::BOUNDS[:input_text] - 5
            if @props[:editable]
              set_choice("text:#{text}")
            else
              choice = closed_entry_choice(text)
              session.refuse(self, :text=) unless choice
              set_choice(choice)
            end
          end

          # Updates labels and identity choices while preserving surviving viewer selections.
          # @return [void]
          # @api private
          def model_changed!
            return if destroyed?
            @item_ids&.delete_if { |key, _id| !model.find_key(key) }
            # Custom models can be installed before pack_start/add_attribute chooses
            # their String column. Materialization still refuses an incomplete mapping.
            return unless model.column_types[@label_column] == String
            options = model_options
            session.refuse(self, :options) if options.length > Lich::WebUI::Contract::BOUNDS[:collection]
            old_keys = @props[:options].map { |option| option[:value] }
            new_keys = options.map { |option| option[:value] }
            %i[value].each do |property|
              value = @props[property]
              @props[property] = 'none' if old_keys.include?(value) && !new_keys.include?(value)
              committed = @committed[property]
              @committed[property] = 'none' if old_keys.include?(committed) && !new_keys.include?(committed)
            end
            write(:options, options)
          end

          # Rejects oversized labels/options before any shared model observer is updated.
          # @return [void]
          # @api private
          def model_will_change!
            return unless @handle || model.column_types[@label_column] == String
            options = model_options
            Lich::WebUI::Validator.new.validate_component!(:select, @props.merge(options: options, value: 'none'), owner: 'shim', page_id: nil, cid: nil)
          end

          # Releases the model observer even when destruction comes from an ancestor.
          # @return [void]
          def mark_destroyed
            model.unwatch(self)
            child&.mark_destroyed
            super
          end

          protected

          def component_type = :select
          def input_property = :value
          def signal_map = { 'changed' => :change }

          # Refuses unfinished label mappings before allocating a visible control.
          # @return [Hash] complete shared select properties
          # @api private
          def component_props
            validate_label_column(model, @label_column)
            super
          end

          def emit_handlers(event, signal: nil)
            super
            child&.send(:emit_handlers, event, signal: signal)
          end

          private

          # Projects the current model independently for preflight and publication.
          # Row IDs preserve duplicate/blank labels; this performs no admission or write.
          # @return [Array<Hash>] fresh options beginning with the no-selection sentinel
          def model_options
            [{ value: 'none', label: '' }] + model.rows.map { |iter| { value: iter.key, label: iter[@label_column].to_s } }
          end

          # Matches the first label in model order, including a real blank label;
          # only unmatched empty text resolves to the no-selection sentinel.
          # @return [String, nil] row ID, empty sentinel or no representable choice
          def closed_entry_choice(text)
            model.rows.find { |iter| iter[@label_column] == text }&.key || ('none' if text.empty?)
          end

          # Validates the live write before notifying combo and entry observers.
          # @param value [String] row ID, clearing sentinel or encoded literal text
          # @return [ComboBox] self
          # @api private
          def set_choice(value)
            previous = read(:value)
            write(:value, value)
            emit_handlers(:change) unless previous == value
            self
          end

          # Prevents text convenience methods from inventing values for extra model columns.
          # @return [void]
          # @api private
          def text_model!
            session.refuse(self, :text_model) unless model.column_types == [String]
          end

          # Requires an actual String column instead of silently stringifying arbitrary data.
          # @param candidate [ListStore] candidate model
          # @param column [Integer] label column
          # @return [void]
          # @api private
          def validate_label_column(candidate, column)
            session.refuse(self, :text_column) unless candidate.get_column_type(column) == String
          end
        end
      end
    end
  end
end
