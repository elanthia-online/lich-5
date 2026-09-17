# frozen_string_literal: true

require_relative 'widgets'

module Lich
  module Common
    module ScriptScope
      module Gtk
        # ------------------------------------------------------------------
        # Notebook -> tabs. Pages are children in tab order; tab labels are
        # widgets in GTK and become the contract's `names`.
        # ------------------------------------------------------------------
        class Notebook < Container
          def initialize
            super
            @tab_labels = {}.compare_by_identity
            @page = 0
          end

          def append_page(child, tab_label = nil)
            add(child)
            set_tab_label(child, tab_label) if tab_label
            @children.length - 1
          end

          def prepend_page(child, tab_label = nil)
            child.detach_from_parent if child.parent
            child.attach_to(self)
            @children.unshift(child)
            set_tab_label(child, tab_label) if tab_label
            changed!
            0
          end

          def insert_page(child, tab_label, position)
            child.detach_from_parent if child.parent
            child.attach_to(self)
            @children.insert(position.to_i.clamp(0, @children.length), child)
            set_tab_label(child, tab_label) if tab_label
            changed!
            position
          end

          def remove_page(index)
            child = @children[index.to_i]
            remove(child) if child
            self
          end

          def remove(child)
            @tab_labels.delete(child)
            super
          end

          def set_tab_label(child, label)
            @tab_labels[child] = label
            changed!
            self
          end

          def set_tab_label_text(child, text)
            set_tab_label(child, text.to_s)
          end

          def get_tab_label(child)
            @tab_labels[child]
          end

          def get_tab_label_text(child)
            tab_text(child)
          end

          def n_pages
            @children.length
          end

          def get_nth_page(index)
            @children[index.to_i]
          end

          def page_num(child)
            @children.index(child) || -1
          end

          def page
            @page
          end
          alias current_page page

          def page=(index)
            @page = index.to_i.clamp(0, [@children.length - 1, 0].max)
            viewer_push(:selected, @page)
          end
          def_setter :set_page, :page=
          def_setter :set_current_page, :page=
          alias current_page= page=

          def next_page
            self.page = @page + 1
          end

          def prev_page
            self.page = @page - 1
          end

          def show_tabs=(_value); end
          def_setter :set_show_tabs, :show_tabs=

          def tab_pos=(_value); end
          def_setter :set_tab_pos, :tab_pos=

          def scrollable=(_value); end
          def_setter :set_scrollable, :scrollable=

          def event_for(signal)
            :select if signal == :switch_page
          end

          def always_bound_events
            [:select]
          end

          def node_type
            :tabs
          end

          def node_props
            names = render_children.map { |child| tab_text(child) }
            names = [' '] if names.empty?
            seen = Hash.new(0)
            names = names.map do |name|
              seen[name] += 1
              seen[name] > 1 ? "#{name} (#{seen[name]})" : name
            end
            { names: names, vertical: false, selected: @page.clamp(0, names.length - 1) }
          end

          protected

          def apply_event(event, context)
            return unless event == :select

            index = payload_value(context, :index)
            @page = index.to_i unless index.nil?
          end

          def receive_event(event, context)
            apply_event(event, context)
            page_widget = @children[@page]
            @handlers.each_key do |signal|
              emit(signal, page_widget, @page) if event_for(signal) == event
            end
          end

          private

          def tab_text(child)
            label = @tab_labels[child]
            text = label.respond_to?(:text) ? label.text.to_s : label.to_s
            text = "Page #{@children.index(child).to_i + 1}" if text.strip.empty?
            text
          end
        end

        # ------------------------------------------------------------------
        # Expander -> expander
        # ------------------------------------------------------------------
        class Expander < Container
          def initialize(label = nil)
            super()
            @label = label.to_s
            @expanded = false
          end

          def label
            @label
          end

          def label=(value)
            @label = value.to_s
            changed!
          end
          def_setter :set_label, :label=

          def set_label_widget(widget)
            @label = widget.text.to_s if widget.respond_to?(:text)
            changed!
            self
          end

          def expanded?
            @expanded
          end

          def expanded=(value)
            @expanded = value ? true : false
            viewer_push(:open, @expanded)
          end
          def_setter :set_expanded, :expanded=

          def event_for(signal)
            :toggle if %i[activate notify_expanded].include?(signal)
          end

          def always_bound_events
            [:toggle]
          end

          def node_type
            :expander
          end

          def node_props
            { label: @label.empty? ? ' ' : @label, open: @expanded }
          end

          protected

          def apply_event(event, context)
            return unless event == :toggle

            open = payload_value(context, :open)
            @expanded = open ? true : false unless open.nil?
          end
        end

        # ------------------------------------------------------------------
        # SpinButton -> number_input. GTK makes SpinButton an Entry; scripts
        # use instance_of? to tell them apart, so the hierarchy is kept.
        # ------------------------------------------------------------------
        class SpinButton < Entry
          attr_reader :adjustment

          def initialize(*args, **_options)
            super()
            @digits = 0
            if args.first.is_a?(Adjustment)
              self.adjustment = args.first
              @digits = args[2].to_i if args[2]
            else
              min, max, step = args
              self.adjustment = Adjustment.new(min.to_f, min.to_f, (max || 100).to_f, (step || 1).to_f, 10.0, 0.0)
            end
          end

          def adjustment=(adjustment)
            @adjustment = adjustment
            adjustment.watch(self)
            changed!
          end
          def_setter :set_adjustment, :adjustment=

          def value
            @adjustment.value
          end

          def value=(number)
            @adjustment.value = number.to_f.clamp(@adjustment.lower, @adjustment.upper)
          end
          def_setter :set_value, :value=

          # Called by the adjustment for every write, including a script
          # writing `spin.adjustment.value = x` directly.
          def adjustment_moved
            viewer_push(:value, contract_value)
          end

          def value_as_int
            value.round
          end

          def set_range(min, max)
            @adjustment.lower = min.to_f
            @adjustment.upper = max.to_f
            self
          end

          def set_increments(step, page)
            @adjustment.step_increment = step.to_f
            @adjustment.page_increment = page.to_f
            self
          end

          def digits=(value)
            @digits = value.to_i
            changed!
          end
          def_setter :set_digits, :digits=

          def text
            @digits.zero? ? value.round.to_s : format("%.#{@digits}f", value)
          end

          def text=(value)
            self.value = value.to_f
          end

          def apply_builder_property(name, value)
            return (self.value = Gtk.builder_value(value)) && self if name.to_s == 'text' || name.to_s == 'value'

            super
          end

          def event_for(signal)
            case signal
            when :value_changed, :changed then :change
            when :activate then :submit
            when :focus_in_event then :focus
            when :focus_out_event then :blur
            end
          end

          def node_type
            :number_input
          end

          def node_props
            step = @adjustment.step_increment
            step = 1 if step <= 0
            min = @adjustment.lower
            max = [@adjustment.upper, min].max
            props = {
              value: contract_number(value.clamp(min, max)), min: contract_number(min),
              max: contract_number(max), step: contract_number(step),
            }
            props[:disabled] = true unless @sensitive && editable?
            props
          end

          protected

          def apply_event(event, context)
            return unless event == :change

            number = payload_value(context)
            @adjustment.value = number.to_f.clamp(@adjustment.lower, @adjustment.upper) unless number.nil?
          end

          private

          def contract_value
            contract_number(value)
          end

          def contract_number(number)
            @digits.zero? && number == number.round ? number.round : number.to_f
          end
        end

        # ------------------------------------------------------------------
        # ComboBox / ComboBoxText -> select. A has-entry combo keeps a real
        # Entry child (scripts address it by builder id) whose text mirrors
        # the selection; free text that matches no option becomes one.
        # ------------------------------------------------------------------
        class ComboBox < Widget
          def size_request_axes
            [:width]
          end

          attr_reader :child

          def initialize(*_args, **options)
            super()
            @options = [] # [[id, label]]
            @active_id = nil
            @next_id = 0
            @child = nil
            self.has_entry = options[:entry] || options[:has_entry] || false
          end

          def has_entry=(value)
            return if @child && value

            @child = value ? Entry.new.tap { |entry| entry.attach_to(self) } : nil
          end
          def_setter :set_has_entry, :has_entry=

          def has_entry?
            !@child.nil?
          end

          def entry_child=(entry)
            @child = entry
            entry.attach_to(self)
          end

          def append_text(text)
            append(next_id, text)
          end

          def append(id, text)
            @options << [id.to_s, text.to_s]
            changed!
            self
          end

          def prepend_text(text)
            @options.unshift([next_id, text.to_s])
            changed!
            self
          end

          def insert_text(position, text)
            @options.insert(position.to_i.clamp(0, @options.length), [next_id, text.to_s])
            changed!
            self
          end

          def remove(position)
            removed = @options.delete_at(position.to_i)
            if removed && removed.first == @active_id
              clear_mirrored_entry
              @active_id = nil
            end
            changed!
            self
          end

          def remove_all
            clear_mirrored_entry
            @options.clear
            @active_id = nil
            changed!
            self
          end

          def active
            index = @options.index { |(id, _label)| id == @active_id }
            index || -1
          end

          def active=(index)
            entry = @options[index.to_i] if index.to_i >= 0
            @active_id = entry&.first
            @child&.instance_variable_set(:@text, entry ? entry.last.dup : +'')
            # Pushed only when the id names a real option -- the same guard
            # node_props applies -- because the validator refuses any select
            # value not among the options, and viewer_write answers a refusal
            # by forgetting the viewer. A stale id would have dropped them.
            #
            # A cleared selection (active = -1) therefore cannot be pushed:
            # neither "" nor nil is a legal select value, and the runtime has
            # no way to remove a viewer's override. The shared props already
            # omit value on clear; only a viewer who had picked something
            # keeps seeing it. Lifting that needs a contract change (a "no
            # selection" value on select), not a shim line.
            changed!
            if @active_id && @options.any? { |(candidate, _label)| candidate == @active_id }
              viewer_push(:value, @active_id)
            end
          end
          def_setter :set_active, :active=

          def active_id
            @active_id
          end

          def active_id=(id)
            self.active = @options.index { |(candidate, _label)| candidate == id.to_s } || -1
          end
          def_setter :set_active_id, :active_id=

          def active_text
            typed = @child&.text
            return typed if typed && !typed.empty? && (@active_id.nil? || option_label(@active_id) != typed)

            option_label(@active_id)
          end

          def active_iter
            @active_id && Struct.new(:id, :text).new(@active_id, option_label(@active_id))
          end

          def entry_text_column=(_value); end
          def_setter :set_entry_text_column, :entry_text_column=

          def id_column=(_value); end

          def apply_builder_property(name, value)
            case name.to_s
            when 'active' then self.active = Gtk.builder_value(value)
            when 'active-id', 'active_id' then self.active_id = value
            else return super
            end
            self
          end

          def event_for(signal)
            :change if signal == :changed
          end

          def always_bound_events
            [:change]
          end

          def node_type
            :select
          end

          def node_props
            options = @options.map { |(id, label)| { value: id, label: label.empty? ? ' ' : label } }
            typed = @child&.text.to_s
            props = { options: options }
            props[:value] = @active_id if @active_id && options.any? { |option| option[:value] == @active_id }
            if !typed.empty? && (@active_id.nil? || option_label(@active_id) != typed)
              match = options.find { |option| option[:label] == typed }
              unless match
                match = { value: "typed:#{typed}", label: typed }
                options << match
              end
              props[:value] = match[:value]
            end
            props[:disabled] = true unless @sensitive
            props
          end

          protected

          def apply_event(event, context)
            return unless event == :change

            value = payload_value(context)
            return if value.nil?

            if value.to_s.start_with?('typed:')
              @child&.instance_variable_set(:@text, value.to_s.delete_prefix('typed:'))
              @active_id = nil
            else
              @active_id = value.to_s
              @child&.instance_variable_set(:@text, option_label(@active_id).dup)
            end
          end

          private

          def option_label(id)
            entry = @options.find { |(candidate, _label)| candidate == id }
            entry ? entry.last : ''
          end

          # The entry child shows the selection; when that selection goes away
          # the mirrored text goes with it. Text the viewer typed stays.
          def clear_mirrored_entry
            return unless @child && @active_id && @child.text == option_label(@active_id)

            @child.instance_variable_set(:@text, +'')
          end

          def next_id
            (@next_id += 1).to_s
          end
        end

        class ComboBoxText < ComboBox
        end

        # ------------------------------------------------------------------
        # TextView + TextBuffer -> textarea
        # ------------------------------------------------------------------
        class TextIter
          attr_reader :offset

          def initialize(offset)
            @offset = offset
          end
        end

        class TextBuffer
          extend Setters
          attr_reader :text

          def initialize(_table = nil)
            @text = +''
            @views = []
            @handlers = Hash.new { |hash, signal| hash[signal] = [] }
          end

          def watch(view)
            @views << view unless @views.include?(view)
          end

          def text=(value)
            @text = value.to_s.dup
            notify
          end
          def_setter :set_text, :text=

          def insert(iter, string, *_tags)
            offset = iter.respond_to?(:offset) ? iter.offset : @text.length
            @text.insert(offset.clamp(0, @text.length), string.to_s)
            notify
            self
          end

          def insert_at_cursor(string)
            insert(end_iter, string)
          end

          def delete(from, to)
            start = from.respond_to?(:offset) ? from.offset : 0
            stop = to.respond_to?(:offset) ? to.offset : @text.length
            @text.slice!(start, stop - start)
            notify
            self
          end

          def start_iter
            TextIter.new(0)
          end

          def end_iter
            TextIter.new(@text.length)
          end

          def get_iter_at_offset(offset)
            TextIter.new(offset.to_i.clamp(0, @text.length))
          end

          def get_iter_at_line(line)
            offset = @text.lines.first(line.to_i).sum(&:length)
            TextIter.new(offset)
          end

          def get_text(from = nil, to = nil, _include_hidden = false)
            return @text.dup unless from || to

            start = from.respond_to?(:offset) ? from.offset : 0
            stop = to.respond_to?(:offset) ? to.offset : @text.length
            @text[start...stop].to_s
          end

          def char_count
            @text.length
          end

          def line_count
            [@text.count("\n") + 1, 1].max
          end

          def create_tag(name = nil, **_properties)
            Gtk.log_unsupported('Gtk::TextBuffer', 'create_tag', note: 'rich text ranges are not rendered yet')
            name
          end

          def apply_tag(*_args)
            self
          end

          def create_mark(*_args)
            end_iter
          end

          def signal_connect(signal, &block)
            @handlers[Gtk.normalize_signal(signal)] << block if block
            @handlers.length
          end

          def changed_by_viewer!(value)
            @text = value.to_s.dup
            @handlers[:changed].each { |handler| Widget.call_handler(handler, [self]) }
          end

          private

          def notify
            @handlers[:changed].each { |handler| Widget.call_handler(handler, [self]) }
            @views.each(&:buffer_changed!)
          end
        end

        class TextView < Widget
          attr_reader :buffer

          def size_request_axes
            %i[width height]
          end

          def initialize(buffer = nil)
            super()
            self.buffer = buffer || TextBuffer.new
            @editable = true
            @rows = 5
          end

          def buffer=(buffer)
            @buffer = buffer
            buffer.watch(self)
            changed!
          end
          def_setter :set_buffer, :buffer=

          def editable=(value)
            @editable = value ? true : false
            changed!
          end
          def_setter :set_editable, :editable=

          def editable?
            @editable
          end

          def cursor_visible=(_value); end
          def_setter :set_cursor_visible, :cursor_visible=

          def set_size_request(width, height)
            @rows = [(height.to_i / 20), 2].max if height.to_i.positive?
            super
          end

          def scroll_to_mark(*_args)
            self
          end

          def scroll_to_iter(*_args)
            self
          end

          def buffer_changed!
            viewer_push(:value, @buffer.text)
          end

          def event_for(signal)
            case signal
            when :focus_in_event then :focus
            when :focus_out_event then :blur
            end
          end

          def always_bound_events
            [:change]
          end

          def node_type
            :textarea
          end

          def node_props
            props = { value: @buffer.text.dup, rows: @rows.clamp(1, 64) }
            props[:disabled] = true unless @sensitive && @editable
            props
          end

          protected

          def apply_event(event, context)
            return unless event == :change

            value = payload_value(context)
            @buffer.changed_by_viewer!(value) unless value.nil?
          end
        end

        # ------------------------------------------------------------------
        # TreeView family -> table
        # ------------------------------------------------------------------
        class TreePath
          attr_reader :indices

          def initialize(spec = '0')
            @indices = spec.is_a?(Array) ? spec.map(&:to_i) : spec.to_s.split(':').map(&:to_i)
          end

          def to_s
            @indices.join(':')
          end
          alias to_str to_s

          def ==(other)
            other.respond_to?(:indices) ? indices == other.indices : to_s == other.to_s
          end
        end

        # A row handle. Scripts index it with the model column number.
        class TreeIter
          attr_reader :model, :key, :values
          attr_accessor :parent_key

          def initialize(model, key, values, parent_key = nil)
            @model = model
            @key = key
            @values = values
            @parent_key = parent_key
          end

          def [](column)
            @values[column.to_i]
          end

          def []=(column, value)
            @values[column.to_i] = @model.coerce(column.to_i, value)
            @model.row_changed!
          end

          def set_value(column, value)
            self[column] = value
          end
          alias set_values_at []=

          def get_value(column)
            self[column]
          end

          def path
            TreePath.new(@model.path_indices(self))
          end

          # GTK advances the iter to the next row and leaves the model
          # alone. This used to copy the next row's key AND its values into
          # self -- and the model handed out its own row objects, so self WAS
          # a row: the copy overwrote that row's data with its successor's.
          # Walking ["alpha","beta","gamma"] left ["beta","beta","gamma"].
          #
          # It also never terminated: @rows.index(self) compares by key, so
          # once the key had been rewritten the iter matched the row it had
          # just advanced to and iter_after returned that same successor
          # forever. jinx.lic walks a store exactly this way, twice.
          #
          # The model now hands out copies (see #dup_row), so moving this
          # iter moves only this iter; and @values is the successor's own
          # array, so writing through the advanced iter still reaches the
          # model, as writing through any other iter does.
          def next!
            following = @model.iter_after(self)
            return false unless following

            @key = following.key
            @parent_key = following.parent_key
            @values = following.values
            true
          end

          def ==(other)
            other.is_a?(TreeIter) && other.model.equal?(@model) && other.key == @key
          end
          alias eql? ==

          def hash
            [@model.object_id, @key].hash
          end
        end

        class ListStore
          attr_reader :column_types
          attr_accessor :builder_name

          def initialize(*types)
            @column_types = types.map { |type| normalize_type(type) }
            @rows = [] # TreeIter, in display order
            @views = []
            @next_key = 0
            @sort_column = nil
          end

          def watch(view)
            @views << view unless @views.include?(view)
          end

          def n_columns
            @column_types.length
          end

          def get_column_type(index)
            @column_types[index.to_i]
          end

          def append(parent = nil)
            iter = TreeIter.new(self, next_key, Array.new(n_columns) { |i| coerce(i, nil) }, parent&.key)
            @rows << iter
            row_changed!
            dup_row(iter)
          end

          def prepend(parent = nil)
            iter = TreeIter.new(self, next_key, Array.new(n_columns) { |i| coerce(i, nil) }, parent&.key)
            @rows.unshift(iter)
            row_changed!
            dup_row(iter)
          end

          def insert(position, parent = nil)
            iter = TreeIter.new(self, next_key, Array.new(n_columns) { |i| coerce(i, nil) }, parent&.key)
            @rows.insert(position.to_i.clamp(0, @rows.length), iter)
            row_changed!
            dup_row(iter)
          end

          def remove(iter)
            removed = @rows.delete(iter)
            @rows.delete_if { |row| row.parent_key == iter.key } if removed
            row_changed!
            !removed.nil?
          end

          def clear
            @rows.clear
            row_changed!
            self
          end

          def each
            return enum_for(:each) unless block_given?

            @rows.dup.each { |iter| yield self, iter.path, dup_row(iter) }
          end

          # A copy, like every iter the model hands out: #next! advances by
          # rewriting the iter's key, so handing back the row itself let a
          # walk rewrite the model.
          def iter_first
            dup_row(@rows.first)
          end

          def get_iter(path)
            indices = path.respond_to?(:indices) ? path.indices : TreePath.new(path).indices
            top_level = @rows.select { |row| row.parent_key.nil? }
            iter = top_level[indices.first.to_i]
            indices.drop(1).each do |index|
              break unless iter

              iter = @rows.select { |row| row.parent_key == iter.key }[index]
            end
            dup_row(iter)
          end

          def iter_after(iter)
            index = @rows.index { |row| row.key == iter.key }
            return nil unless index

            dup_row(@rows[index + 1])
          end

          # A copy that names the same row. #next! advances an iter by
          # rewriting its key, and the model hands out its own row objects,
          # so without a copy the caller's iter IS a row and advancing it
          # rewrote that row. Lookups are all by key, which the copy keeps,
          # and @values is the row's own array, so writing through the copy
          # still reaches the model.
          def dup_row(row)
            return nil unless row

            TreeIter.new(self, row.key, row.values, row.parent_key)
          end

          def path_indices(iter)
            siblings = @rows.select { |row| row.parent_key == iter.parent_key }
            [siblings.index(iter) || 0]
          end

          def rows
            @rows.dup
          end

          def size
            @rows.length
          end
          alias length size

          def empty?
            @rows.empty?
          end

          def set_sort_column_id(column, _order = nil)
            @sort_column = column.to_i
            self
          end

          def set_sort_func(*_args)
            self
          end

          def set_default_sort_func(*_args)
            self
          end

          def coerce(column, value)
            type = @column_types[column]
            if type == Integer then value.to_i
            elsif type == Float then value.to_f
            elsif type == TrueClass then value ? true : false
            else value.nil? ? '' : value.to_s
            end
          end

          def row_changed!
            @views.each(&:model_changed!)
          end

          def apply_builder_property(_name, _value)
            self
          end

          private

          def next_key
            "r#{@next_key += 1}"
          end

          def normalize_type(type)
            case type.to_s
            when 'gchararray', 'String', 'string' then String
            when 'gint', 'guint', 'glong', 'Integer', 'int' then Integer
            when 'gfloat', 'gdouble', 'Float', 'float' then Float
            when 'gboolean', 'TrueClass', 'boolean' then TrueClass
            else String
            end
          end
        end

        # A tree, not a flat list that happens to record a parent.
        #
        # This was a bare subclass, so every hierarchy operation answered as
        # though the rows were siblings: a grandchild's path was "0" rather
        # than "0:0:0", advancing an iter walked the backing array into its
        # own descendants instead of to the next sibling, and removing a row
        # deleted its children but left grandchildren pointing at a parent
        # that no longer existed. Checked against gtk3 3.24.52, which answers
        # "0:0:0", advances root to the next TOP-LEVEL row, and takes the
        # whole subtree on remove.
        class TreeStore < ListStore
          # Every ancestor index, outermost first, which is what a TreePath
          # spells with colons.
          def path_indices(iter)
            indices = []
            current = iter
            while current
              siblings = @rows.select { |row| row.parent_key == current.parent_key }
              indices.unshift(siblings.index { |row| row.key == current.key } || 0)
              current = current.parent_key && @rows.find { |row| row.key == current.parent_key }
            end
            indices
          end

          # The next row at the SAME level under the same parent. The flat
          # implementation returned the following row in the backing array,
          # which for a row with children is its own first child.
          def iter_after(iter)
            siblings = @rows.select { |row| row.parent_key == iter.parent_key }
            index = siblings.index { |row| row.key == iter.key }
            return nil unless index

            dup_row(siblings[index + 1])
          end

          # Depth-first, so a subtree goes with the row that owns it rather
          # than leaving orphans behind.
          def remove(iter)
            row = @rows.find { |candidate| candidate.key == iter.key }
            return false unless row

            descendants_of(row.key).each { |key| @rows.delete_if { |candidate| candidate.key == key } }
            @rows.delete(row)
            row_changed!
            true
          end

          # How many children a row has, which GTK exposes and a script that
          # walks a tree asks for.
          def iter_n_children(iter = nil)
            parent_key = iter&.key
            @rows.count { |row| row.parent_key == parent_key }
          end

          def iter_has_child?(iter)
            iter_n_children(iter).positive?
          end

          def iter_children(iter = nil)
            dup_row(@rows.find { |row| row.parent_key == iter&.key })
          end

          def iter_parent(iter)
            return nil unless iter.parent_key

            dup_row(@rows.find { |row| row.key == iter.parent_key })
          end

          private

          # Every key beneath +key+, at any depth.
          def descendants_of(key)
            direct = @rows.select { |row| row.parent_key == key }.map(&:key)
            direct.flat_map { |child| [child] + descendants_of(child) }
          end
        end

        class CellRenderer
          attr_accessor :builder_name

          def initialize
            @handlers = Hash.new { |hash, signal| hash[signal] = [] }
          end

          def signal_connect(signal, &block)
            @handlers[Gtk.normalize_signal(signal)] << block if block
            @handlers.length
          end

          def emit(signal, *args)
            @handlers[Gtk.normalize_signal(signal)].each { |handler| Widget.call_handler(handler, [self, *args]) }
          end

          def apply_builder_property(name, value)
            setter = "#{name.to_s.tr('-', '_')}="
            public_send(setter, Gtk.builder_value(value)) if respond_to?(setter, false) && !respond_to?(:method_missing)
            self
          end

          def method_missing(name, *_args, &_block)
            return super if Widget::PROTOCOL_METHODS.include?(name)

            Gtk.log_unsupported(self.class.name.split('::').last, name)
            name.end_with?('=') || name.start_with?('set_') ? self : nil
          end

          def respond_to_missing?(name, include_private = false)
            return super if Widget::PROTOCOL_METHODS.include?(name)

            true
          end
        end

        class CellRendererText < CellRenderer
          extend Setters
          attr_reader :editable

          def initialize
            super
            @editable = false
          end

          def editable=(value)
            @editable = value ? true : false
          end
          def_setter :set_editable, :editable=

          def editor
            @editable ? { type: 'text' } : nil
          end
        end

        class CellRendererToggle < CellRenderer
          def initialize
            super
            @activatable = true
          end

          def activatable=(value)
            @activatable = value ? true : false
          end

          def editor
            @activatable ? { type: 'checkbox' } : nil
          end
        end

        class CellRendererCombo < CellRendererText
        end

        class TreeViewColumn
          extend Setters
          attr_reader :title, :renderer, :attributes
          attr_accessor :builder_name, :sort_column_id

          def initialize(title = nil, renderer = nil, attributes = {})
            @title = title.to_s
            @renderer = renderer
            @attributes = attributes.to_h { |name, column| [name.to_s, column.to_i] }
            @sort_column_id = nil
            @expand = false
            @visible = true
          end

          def title=(value)
            @title = value.to_s
          end
          def_setter :set_title, :title=

          def pack_start(renderer, _expand = true)
            @renderer ||= renderer
            self
          end
          alias pack_end pack_start

          def add_attribute(_renderer, name, column)
            @attributes[name.to_s] = column.to_i
            self
          end

          def set_attributes(_renderer, attributes)
            attributes.each { |name, column| @attributes[name.to_s] = column.to_i }
            self
          end

          def set_sort_column_id(column)
            @sort_column_id = column.to_i
            self
          end

          def expand=(value)
            @expand = value ? true : false
          end
          def_setter :set_expand, :expand=

          def resizable=(_value); end
          def_setter :set_resizable, :resizable=

          def visible=(value)
            @visible = value ? true : false
          end

          def visible?
            @visible
          end

          def fixed_width=(_value); end
          def_setter :set_fixed_width, :fixed_width=

          def sizing=(_value); end
          def_setter :set_sizing, :sizing=

          def set_cell_data_func(*_args)
            Gtk.log_unsupported('Gtk::TreeViewColumn', 'set_cell_data_func', note: 'cell data functions are ignored')
            self
          end

          # Model column that feeds the cell's visible text (or toggle).
          def value_column
            @attributes['text'] || @attributes['active'] || @attributes['markup'] || 0
          end

          def apply_builder_property(name, value)
            setter = "#{name.to_s.tr('-', '_')}="
            public_send(setter, Gtk.builder_value(value)) if respond_to?(setter)
            self
          end
        end

        class TreeSelection
          extend Setters
          attr_reader :mode

          def initialize(view)
            @view = view
            @mode = :single
            @handlers = []
          end

          def mode=(value)
            @mode = value.to_s.downcase.to_sym
            @view.changed!
          end
          def_setter :set_mode, :mode=

          def selected
            @view.selected_iters.first
          end

          def selected_rows
            @view.selected_iters.map(&:path)
          end

          def selected_each
            @view.selected_iters.each { |iter| yield @view.model, iter.path, iter }
          end

          def select_iter(iter)
            @view.select_keys([iter.key])
          end

          def select_path(path)
            iter = @view.model&.get_iter(path)
            select_iter(iter) if iter
          end

          def unselect_all
            @view.select_keys([])
          end

          def select_all
            @view.select_keys(@view.model ? @view.model.rows.map(&:key) : [])
          end

          def iter_is_selected?(iter)
            @view.selected_keys.include?(iter.key)
          end

          def count_selected_rows
            @view.selected_keys.length
          end

          def signal_connect(_signal, &block)
            @handlers << block if block
            @handlers.length
          end

          def changed!
            @handlers.each { |handler| Widget.call_handler(handler, [self]) }
          end

          def apply_builder_property(name, value)
            self.mode = value if name.to_s == 'mode'
            self
          end
        end

        class TreeView < Widget
          attr_reader :model, :selection

          def size_request_axes
            %i[width height]
          end

          def initialize(model = nil)
            super()
            @columns = []
            @selected_keys = []
            @selection = TreeSelection.new(self)
            @headers_visible = true
            self.model = model if model
          end

          def model=(model)
            @model = model
            model&.watch(self)
            @selected_keys = []
            changed!
          end
          def_setter :set_model, :model=

          def append_column(column)
            @columns << column
            changed!
            @columns.length
          end

          def insert_column(column, position)
            @columns.insert(position.to_i.clamp(0, @columns.length), column)
            changed!
            @columns.length
          end

          def remove_column(column)
            @columns.delete(column)
            changed!
            @columns.length
          end

          def columns
            @columns.dup
          end

          def get_column(index)
            @columns[index.to_i]
          end

          def headers_visible=(value)
            @headers_visible = value ? true : false
            changed!
          end
          def_setter :set_headers_visible, :headers_visible=

          def enable_search=(_value); end
          def_setter :set_enable_search, :enable_search=

          def search_column=(_value); end
          def_setter :set_search_column, :search_column=

          def reorderable=(_value); end
          def_setter :set_reorderable, :reorderable=

          def rules_hint=(_value); end
          def_setter :set_rules_hint, :rules_hint=

          def set_cursor(path, _column = nil, _start_editing = false)
            iter = @model&.get_iter(path)
            select_keys([iter.key]) if iter
            self
          end

          def expand_all
            self
          end

          def collapse_all
            self
          end

          def expand_row(*_args)
            self
          end

          def columns_autosize
            self
          end

          def model_changed!
            @selected_keys &= @model.rows.map(&:key) if @model
            changed!
          end

          def selected_keys
            @selected_keys.dup
          end

          # Copies, for the same reason iter_first/get_iter/append do: #next!
          # advances an iter by rewriting its key, so handing a script the
          # model's own row object let a walk from `selection.selected` rewrite
          # the model. Walking [alpha, beta, gamma] from the selected first row
          # repeated `beta` forever and left the store as [beta, beta, gamma].
          # dup_row shares the row's values array, so writing through the copy
          # still reaches the model.
          # A cursor over the named row, never the model's own object. Writes
          # through it still land, because the copy shares the values array.
          def find_row_copy(row_key)
            row = @model&.rows&.find { |candidate| candidate.key == row_key }
            row && @model.send(:dup_row, row)
          end

          def selected_iters
            return [] unless @model

            @model.rows.select { |iter| @selected_keys.include?(iter.key) }
                       .map { |iter| @model.send(:dup_row, iter) }
          end

          def select_keys(keys)
            @selected_keys = keys.uniq
            viewer_push(:selected, @selected_keys.dup)
            @selection.changed!
          end

          def apply_builder_property(name, value)
            return super unless name.to_s == 'model'

            self.model = value if value.is_a?(ListStore)
            self
          end

          def event_for(signal)
            :row_activate if signal == :row_activated
          end

          def always_bound_events
            events = []
            events << :selection_change unless @selection.mode == :none
            events << :cell_edit if @columns.any? { |column| column.renderer&.editor }
            events
          end

          def node_type
            :table
          end

          def node_props
            columns = @columns.select(&:visible?).each_with_index.map do |column, index|
              spec = { key: "c#{index}", label: column.title.empty? ? ' ' : column.title }
              editor = column.renderer&.editor
              spec[:editor] = editor if editor
              spec
            end
            columns = [{ key: 'c0', label: ' ' }] if columns.empty?
            rows = (@model ? @model.rows : []).map do |iter|
              cells = @columns.select(&:visible?).each_with_index.to_h do |column, index|
                ["c#{index}", cell_value(iter[column.value_column])]
              end
              cells = { 'c0' => cell_value(iter[0]) } if @columns.select(&:visible?).empty?
              row = { key: iter.key, cells: cells }
              row[:parent] = iter.parent_key if iter.parent_key
              row
            end
            mode = case @selection.mode
                   when :none then 'none'
                   when :multiple then 'multi'
                   else 'single'
                   end
            props = { columns: columns, rows: rows, selection: mode }
            # A tree view used as a plain list names its columns for the
            # model and hides the header row; the label is internal.
            props[:headers] = false unless @headers_visible
            props[:selected] = @selected_keys.dup unless mode == 'none' || @selected_keys.empty?
            props[:disabled] = true unless @sensitive
            props
          end

          protected

          def apply_event(event, context)
            case event
            when :selection_change
              rows = payload_value(context, :rows)
              @selected_keys = Array(rows).map(&:to_s) unless rows.nil?
              @selection.changed!
            when :cell_edit
              row_key = payload_value(context, :row).to_s
              column_key = payload_value(context, :column).to_s
              value = payload_value(context)
              index = column_key.delete_prefix('c').to_i
              column = @columns.select(&:visible?)[index]
              iter = find_row_copy(row_key)
              if column && iter
                iter[column.value_column] = value
                column.renderer&.emit(:edited, iter.path.to_s, value)
                column.renderer&.emit(:toggled, iter.path.to_s)
              end
            end
          end

          def receive_event(event, context)
            apply_event(event, context)
            if event == :row_activate
              row_key = payload_value(context, :row).to_s
              iter = find_row_copy(row_key)
              emit(:row_activated, iter&.path, @columns.first) if iter
            else
              @handlers.each_key do |signal|
                emit(signal, Event.new) if event_for(signal) == event
              end
            end
          end

          private

          def cell_value(value)
            case value
            when nil then ''
            when String, Numeric, true, false then value
            else value.to_s
            end
          end
        end
      end
    end
  end
end
