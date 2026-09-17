# frozen_string_literal: true

require_relative 'widgets'

module Lich
  module Common
    module ScriptScope
      module Gtk
        # Stands in for `Gtk::Notebook`: a tabbed container rendered as the contract's `tabs` node.
        # Tab labels may be widgets or strings; only their text reaches the viewer, and duplicate
        # tab names are made unique with a numeric suffix.
        #
        # ------------------------------------------------------------------
        # Notebook -> tabs. Pages are children in tab order; tab labels are
        # widgets in GTK and become the contract's `names`.
        # ------------------------------------------------------------------
        class Notebook < Container
          # Creates an empty notebook with page 0 current.
          #
          # @return [Notebook] a new notebook
          def initialize
            super
            @tab_labels = {}.compare_by_identity
            @page = 0
          end

          # Adds a page at the end.
          #
          # @param child [Widget] the page widget
          # @param tab_label [Widget, String, nil] tab label widget or text
          # @return [Integer] index of the new page
          def append_page(child, tab_label = nil)
            add(child)
            set_tab_label(child, tab_label) if tab_label
            @children.length - 1
          end

          # Adds a page at the front.
          #
          # @param child [Widget] the page widget
          # @param tab_label [Widget, String, nil] tab label widget or text
          # @return [Integer] always 0, the index of the new page
          def prepend_page(child, tab_label = nil)
            child.detach_from_parent if child.parent
            child.attach_to(self)
            @children.unshift(child)
            set_tab_label(child, tab_label) if tab_label
            changed!
            0
          end

          # Adds a page at a position, clamped to the page range.
          #
          # @param child [Widget] the page widget
          # @param tab_label [Widget, String, nil] tab label widget or text
          # @param position [Integer] index to insert at
          # @return [Integer] the position as given
          def insert_page(child, tab_label, position)
            child.detach_from_parent if child.parent
            child.attach_to(self)
            @children.insert(position.to_i.clamp(0, @children.length), child)
            set_tab_label(child, tab_label) if tab_label
            changed!
            position
          end

          # Removes the page at an index; an index with no page is ignored.
          #
          # @param index [Integer] page index
          # @return [self]
          def remove_page(index)
            child = @children[index.to_i]
            remove(child) if child
            self
          end

          # Removes a page and forgets its tab label.
          #
          # @param child [Widget] the page widget
          # @return [self]
          def remove(child)
            @tab_labels.delete(child)
            super
          end

          # Sets the tab label for a page.
          #
          # @param child [Widget] the page widget
          # @param label [Widget, String, nil] tab label widget or text
          # @return [self]
          def set_tab_label(child, label)
            @tab_labels[child] = label
            changed!
            self
          end

          # Sets the tab label for a page from plain text.
          #
          # @param child [Widget] the page widget
          # @param text [String] tab text
          # @return [self]
          def set_tab_label_text(child, text)
            set_tab_label(child, text.to_s)
          end

          # The tab label a page was given.
          #
          # @param child [Widget] the page widget
          # @return [Widget, String, nil] the label, or nil when none was set
          def get_tab_label(child)
            @tab_labels[child]
          end

          # The tab text shown for a page, defaulting to "Page N" when the label is blank.
          #
          # @param child [Widget] the page widget
          # @return [String]
          def get_tab_label_text(child)
            tab_text(child)
          end

          # Number of pages.
          #
          # @return [Integer]
          def n_pages
            @children.length
          end

          # The page widget at an index.
          #
          # @param index [Integer] page index
          # @return [Widget, nil]
          def get_nth_page(index)
            @children[index.to_i]
          end

          # Index of a page widget.
          #
          # @param child [Widget] the page widget
          # @return [Integer] the index, or -1 when it is not a page
          def page_num(child)
            @children.index(child) || -1
          end

          # Index of the current page. Also reachable as `current_page`.
          #
          # @return [Integer]
          def page
            @page
          end
          alias current_page page

          # Selects a page by index, clamped to the page range, and pushes the selection to every viewer.
          # Also reachable as `set_page`, `set_current_page` (both return self) and `current_page=`.
          #
          # @param index [Integer] page index
          # @return [void]
          def page=(index)
            @page = index.to_i.clamp(0, [@children.length - 1, 0].max)
            viewer_push(:selected, @page)
          end
          def_setter :set_page, :page=
          def_setter :set_current_page, :page=
          alias current_page= page=

          # Selects the following page (clamped at the last).
          #
          # @return [void]
          def next_page
            self.page = @page + 1
          end

          # Selects the preceding page (clamped at the first).
          #
          # @return [void]
          def prev_page
            self.page = @page - 1
          end

          # Accepted and ignored: the contract always shows tabs. Also reachable as `set_show_tabs`.
          #
          # @param _value [Object] ignored
          # @return [void]
          def show_tabs=(_value); end
          def_setter :set_show_tabs, :show_tabs=

          # Accepted and ignored: tab position is the viewer's. Also reachable as `set_tab_pos`.
          #
          # @param _value [Object] ignored
          # @return [void]
          def tab_pos=(_value); end
          def_setter :set_tab_pos, :tab_pos=

          # Accepted and ignored: tab scrolling is the viewer's. Also reachable as `set_scrollable`.
          #
          # @param _value [Object] ignored
          # @return [void]
          def scrollable=(_value); end
          def_setter :set_scrollable, :scrollable=

          # Contract event a GTK signal maps to for this widget.
          #
          # @param signal [Symbol] normalized GTK signal name
          # @return [Symbol, nil] :select for `switch_page`, else nil
          def event_for(signal)
            :select if signal == :switch_page
          end

          # Events bound whether or not the script connected a handler.
          #
          # @return [Array<Symbol>] always `[:select]`
          def always_bound_events
            [:select]
          end

          # Contract node type this widget renders as.
          #
          # @return [Symbol]
          def node_type
            :tabs
          end

          # Contract props for this widget's node.
          #
          # @return [Hash{Symbol => Object}] `names`, `vertical` and `selected`
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

          # Updates shadow state from a contract event before any GTK handler runs.
          #
          # @param event [Symbol] the contract event that arrived
          # @param context [Object] the runtime event context (payload reachable through `payload_value`)
          # @return [void]
          def apply_event(event, context)
            return unless event == :select

            index = payload_value(context, :index)
            @page = index.to_i unless index.nil?
          end

          # Applies a contract event, then emits `switch_page` with the new page widget and index.
          #
          # @param event [Symbol] the contract event that arrived
          # @param context [Object] the runtime event context (payload reachable through `payload_value`)
          # @return [void]
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

        # Stands in for `Gtk::Expander`: a collapsible container rendered as the contract's `expander` node.
        # A label widget is reduced to its text.
        #
        # ------------------------------------------------------------------
        # Expander -> expander
        # ------------------------------------------------------------------
        class Expander < Container
          # Creates a collapsed expander.
          #
          # @param label [String, nil] label text
          # @return [Expander] a new expander
          def initialize(label = nil)
            super()
            @label = label.to_s
            @expanded = false
          end

          # The label text.
          #
          # @return [String]
          def label
            @label
          end

          # Sets the label text. Also reachable as `set_label`, which returns self.
          #
          # @param value [String] label text
          # @return [void]
          def label=(value)
            @label = value.to_s
            changed!
          end
          def_setter :set_label, :label=

          # Takes the label text from a widget that has one; other widgets leave the label alone.
          #
          # @param widget [Widget] label widget
          # @return [self]
          def set_label_widget(widget)
            @label = widget.text.to_s if widget.respond_to?(:text)
            changed!
            self
          end

          # Whether the expander is open.
          #
          # @return [Boolean]
          def expanded?
            @expanded
          end

          # Opens or closes the expander and pushes the state to every viewer.
          # Also reachable as `set_expanded`, which returns self.
          #
          # @param value [Boolean] truthy to open
          # @return [void]
          def expanded=(value)
            @expanded = value ? true : false
            viewer_push(:open, @expanded)
          end
          def_setter :set_expanded, :expanded=

          # Contract event a GTK signal maps to for this widget.
          #
          # @param signal [Symbol] normalized GTK signal name
          # @return [Symbol, nil] :toggle for `activate` and `notify_expanded`, else nil
          def event_for(signal)
            :toggle if %i[activate notify_expanded].include?(signal)
          end

          # Events bound whether or not the script connected a handler.
          #
          # @return [Array<Symbol>] always `[:toggle]`
          def always_bound_events
            [:toggle]
          end

          # Contract node type this widget renders as.
          #
          # @return [Symbol]
          def node_type
            :expander
          end

          # Contract props for this widget's node.
          #
          # @return [Hash{Symbol => Object}] `label` and `open`
          def node_props
            { label: @label.empty? ? ' ' : @label, open: @expanded }
          end

          protected

          # Updates shadow state from a contract event before any GTK handler runs.
          #
          # @param event [Symbol] the contract event that arrived
          # @param context [Object] the runtime event context (payload reachable through `payload_value`)
          # @return [void]
          def apply_event(event, context)
            return unless event == :toggle

            open = payload_value(context, :open)
            @expanded = open ? true : false unless open.nil?
          end
        end

        # Stands in for `Gtk::SpinButton`: a numeric entry backed by an {Adjustment}, rendered as the contract's
        # `number_input` node.
        #
        # ------------------------------------------------------------------
        # SpinButton -> number_input. GTK makes SpinButton an Entry; scripts
        # use instance_of? to tell them apart, so the hierarchy is kept.
        # ------------------------------------------------------------------
        class SpinButton < Entry
          # @return [Adjustment] the adjustment holding the value and range
          attr_reader :adjustment

          # Creates a spin button from an adjustment or from a numeric range.
          #
          # @param args [Array] either `(adjustment, climb_rate = nil, digits = nil)` or `(min, max = 100, step = 1)`
          # @param _options [Hash] ignored keyword options
          # @return [SpinButton] a new spin button
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

          # Replaces the adjustment and watches it for writes. Also reachable as `set_adjustment`, which returns self.
          #
          # @param adjustment [Adjustment] the new adjustment
          # @return [void]
          def adjustment=(adjustment)
            @adjustment = adjustment
            adjustment.watch(self)
            changed!
          end
          def_setter :set_adjustment, :adjustment=

          # The current value.
          #
          # @return [Float]
          def value
            @adjustment.value
          end

          # Sets the value, clamped to the adjustment's range. Also reachable as `set_value`, which returns self.
          #
          # @param number [Numeric, #to_f] the new value
          # @return [void]
          def value=(number)
            @adjustment.value = number.to_f.clamp(@adjustment.lower, @adjustment.upper)
          end
          def_setter :set_value, :value=

          # Pushes the adjustment's value to every viewer.
          #
          # Called by the adjustment for every write, including a script
          # writing `spin.adjustment.value = x` directly.
          #
          # @return [void]
          def adjustment_moved
            viewer_push(:value, contract_value)
          end

          # The value rounded to an integer.
          #
          # @return [Integer]
          def value_as_int
            value.round
          end

          # Sets the adjustment's lower and upper bounds.
          #
          # @param min [Numeric] lower bound
          # @param max [Numeric] upper bound
          # @return [self]
          def set_range(min, max)
            @adjustment.lower = min.to_f
            @adjustment.upper = max.to_f
            self
          end

          # Sets the adjustment's step and page increments.
          #
          # @param step [Numeric] step increment
          # @param page [Numeric] page increment
          # @return [self]
          def set_increments(step, page)
            @adjustment.step_increment = step.to_f
            @adjustment.page_increment = page.to_f
            self
          end

          # Sets how many decimal places the text shows. Also reachable as `set_digits`, which returns self.
          #
          # @param value [Integer] decimal places
          # @return [void]
          def digits=(value)
            @digits = value.to_i
            changed!
          end
          def_setter :set_digits, :digits=

          # The value formatted with the configured digits.
          #
          # @return [String]
          def text
            @digits.zero? ? value.round.to_s : format("%.#{@digits}f", value)
          end

          # Sets the value from text.
          #
          # @param value [String, #to_f] numeric text
          # @return [void]
          def text=(value)
            self.value = value.to_f
          end

          # Applies a GtkBuilder property; `text` and `value` set the value, anything else goes to {Entry}.
          #
          # @param name [String, Symbol] property name
          # @param value [String] property value as written in the builder file
          # @return [self]
          def apply_builder_property(name, value)
            return (self.value = Gtk.builder_value(value)) && self if name.to_s == 'text' || name.to_s == 'value'

            super
          end

          # Contract event a GTK signal maps to for this widget.
          #
          # @param signal [Symbol] normalized GTK signal name
          # @return [Symbol, nil] :change, :submit, :focus or :blur; nil for a signal with no mapping
          def event_for(signal)
            case signal
            when :value_changed, :changed then :change
            when :activate then :submit
            when :focus_in_event then :focus
            when :focus_out_event then :blur
            end
          end

          # Contract node type this widget renders as.
          #
          # @return [Symbol]
          def node_type
            :number_input
          end

          # Contract props for this widget's node.
          #
          # @return [Hash{Symbol => Object}] `value`, `min`, `max`, `step` and, when insensitive or not editable,
          #   `disabled`
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

          # Updates shadow state from a contract event before any GTK handler runs.
          #
          # @param event [Symbol] the contract event that arrived
          # @param context [Object] the runtime event context (payload reachable through `payload_value`)
          # @return [void]
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

        # Stands in for `Gtk::ComboBox` (and, through {ComboBoxText}, `Gtk::ComboBoxText`): rendered as the contract's
        # `select` node. Options are `[id, label]` pairs; ids given by the script are kept, generated ones count up.
        #
        # ------------------------------------------------------------------
        # ComboBox / ComboBoxText -> select. A has-entry combo keeps a real
        # Entry child (scripts address it by builder id) whose text mirrors
        # the selection; free text that matches no option becomes one.
        # ------------------------------------------------------------------
        class ComboBox < Widget
          # Size-request axes the contract honours for this widget.
          #
          # @return [Array<Symbol>] `[:width]`
          def size_request_axes
            [:width]
          end

          # @return [Entry, nil] the entry child of a has-entry combo, else nil
          attr_reader :child

          # Creates an empty combo, with an entry child when asked for.
          #
          # @param _args [Array] ignored positional arguments (a model, say)
          # @param options [Hash] keyword options
          # @option options [Boolean] :entry create an entry child
          # @option options [Boolean] :has_entry same as `:entry`
          # @return [ComboBox] a new combo
          def initialize(*_args, **options)
            super()
            @options = [] # [[id, label]]
            @active_id = nil
            @next_id = 0
            @child = nil
            self.has_entry = options[:entry] || options[:has_entry] || false
          end

          # Adds or drops the entry child; an existing child is kept when asked for again.
          # Also reachable as `set_has_entry`, which returns self.
          #
          # @param value [Boolean] truthy to have an entry
          # @return [void]
          def has_entry=(value)
            return if @child && value

            @child = value ? Entry.new.tap { |entry| entry.attach_to(self) } : nil
          end
          def_setter :set_has_entry, :has_entry=

          # Whether the combo has an entry child.
          #
          # @return [Boolean]
          def has_entry?
            !@child.nil?
          end

          # Installs a specific entry (from a builder file) as the child.
          #
          # @param entry [Entry] the entry
          # @return [void]
          def entry_child=(entry)
            @child = entry
            entry.attach_to(self)
          end

          # Appends an option with a generated id.
          #
          # @param text [String] option label
          # @return [self]
          def append_text(text)
            append(next_id, text)
          end

          # Appends an option with an explicit id.
          #
          # @param id [String, #to_s] option id
          # @param text [String] option label
          # @return [self]
          def append(id, text)
            @options << [id.to_s, text.to_s]
            changed!
            self
          end

          # Prepends an option with a generated id.
          #
          # @param text [String] option label
          # @return [self]
          def prepend_text(text)
            @options.unshift([next_id, text.to_s])
            changed!
            self
          end

          # Inserts an option with a generated id at a position, clamped to the option range.
          #
          # @param position [Integer] index to insert at
          # @param text [String] option label
          # @return [self]
          def insert_text(position, text)
            @options.insert(position.to_i.clamp(0, @options.length), [next_id, text.to_s])
            changed!
            self
          end

          # Removes the option at an index, clearing the selection when it was the active one.
          #
          # @param position [Integer] option index
          # @return [self]
          def remove(position)
            removed = @options.delete_at(position.to_i)
            if removed && removed.first == @active_id
              clear_mirrored_entry
              @active_id = nil
            end
            changed!
            self
          end

          # Removes every option and clears the selection.
          #
          # @return [self]
          def remove_all
            clear_mirrored_entry
            @options.clear
            @active_id = nil
            changed!
            self
          end

          # Index of the active option.
          #
          # @return [Integer] the index, or -1 when nothing is selected
          def active
            index = @options.index { |(id, _label)| id == @active_id }
            index || -1
          end

          # Selects an option by index (a negative index clears), mirrors its label into the entry child and
          # pushes the selection to every viewer. Also reachable as `set_active`, which returns self.
          #
          # @param index [Integer] option index
          # @return [void]
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

          # Id of the active option.
          #
          # @return [String, nil]
          def active_id
            @active_id
          end

          # Selects an option by id; an unknown id clears the selection.
          # Also reachable as `set_active_id`, which returns self.
          #
          # @param id [String, #to_s] option id
          # @return [void]
          def active_id=(id)
            self.active = @options.index { |(candidate, _label)| candidate == id.to_s } || -1
          end
          def_setter :set_active_id, :active_id=

          # Text the viewer typed into the entry when it differs from the selection, else the active option's label.
          #
          # @return [String] empty when nothing is selected or typed
          def active_text
            typed = @child&.text
            return typed if typed && !typed.empty? && (@active_id.nil? || option_label(@active_id) != typed)

            option_label(@active_id)
          end

          # A row-like handle for the active option.
          #
          # @return [Struct, nil] a struct with `id` and `text`, or nil when nothing is selected
          def active_iter
            @active_id && Struct.new(:id, :text).new(@active_id, option_label(@active_id))
          end

          # Accepted and ignored: options carry their own label. Also reachable as `set_entry_text_column`.
          #
          # @param _value [Object] ignored
          # @return [void]
          def entry_text_column=(_value); end
          def_setter :set_entry_text_column, :entry_text_column=

          # Accepted and ignored: options carry their own id.
          #
          # @param _value [Object] ignored
          # @return [void]
          def id_column=(_value); end

          # Applies a GtkBuilder property; `active` and `active-id` select, anything else goes to {Widget}.
          #
          # @param name [String, Symbol] property name
          # @param value [String] property value as written in the builder file
          # @return [self]
          def apply_builder_property(name, value)
            case name.to_s
            when 'active' then self.active = Gtk.builder_value(value)
            when 'active-id', 'active_id' then self.active_id = value
            else return super
            end
            self
          end

          # Contract event a GTK signal maps to for this widget.
          #
          # @param signal [Symbol] normalized GTK signal name
          # @return [Symbol, nil] :change for `changed`, else nil
          def event_for(signal)
            :change if signal == :changed
          end

          # Events bound whether or not the script connected a handler.
          #
          # @return [Array<Symbol>] always `[:change]`
          def always_bound_events
            [:change]
          end

          # Contract node type this widget renders as.
          #
          # @return [Symbol]
          def node_type
            :select
          end

          # Contract props for this widget's node.
          #
          # @return [Hash{Symbol => Object}] `options`, `value` when one is selected or typed, and `disabled` when
          #   insensitive
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

          # Updates shadow state from a contract event before any GTK handler runs.
          #
          # @param event [Symbol] the contract event that arrived
          # @param context [Object] the runtime event context (payload reachable through `payload_value`)
          # @return [void]
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

        # Stands in for `Gtk::ComboBoxText`; identical to {ComboBox}, kept as its own class for `instance_of?`.
        class ComboBoxText < ComboBox
        end

        # Stands in for `Gtk::TextIter`: a character offset into a {TextBuffer}.
        #
        # ------------------------------------------------------------------
        # TextView + TextBuffer -> textarea
        # ------------------------------------------------------------------
        class TextIter
          # @return [Integer] character offset into the buffer
          attr_reader :offset

          # Creates an iter at an offset.
          #
          # @param offset [Integer] character offset
          # @return [TextIter] a new iter
          def initialize(offset)
            @offset = offset
          end
        end

        # Stands in for `Gtk::TextTag`.
        #
        # A text tag: a named bundle of properties a script applies to a
        # range of a buffer (armor justifies a page, localchat colours a
        # line). The contract's textarea carries plain text, so a tag is
        # kept as readable state and its application is reported through
        # the ledger once; the text itself is never lost.
        class TextTag
          # @return [String, nil] the tag name
          # @return [Hash{String => Object}] properties keyed by their dashed GTK name
          attr_reader :name, :properties

          # Creates a tag with optional properties.
          #
          # @param name [String, nil] tag name
          # @param properties [Hash{String, Symbol => Object}] initial properties
          # @return [TextTag] a new tag
          def initialize(name = nil, properties = {})
            @name = name&.to_s
            @properties = {}
            properties.each { |key, value| set_property(key, value) }
          end

          # Sets a property; underscores in the name become dashes. Also reachable as `[]=`.
          #
          # @param name [String, Symbol] property name
          # @param value [Object] property value
          # @return [self]
          def set_property(name, value)
            @properties[name.to_s.tr('_', '-')] = value
            self
          end
          alias []= set_property

          # Reads a property by name.
          #
          # @param name [String, Symbol] property name
          # @return [Object, nil]
          def [](name)
            @properties[name.to_s.tr('_', '-')]
          end

          # Tag priority; always 0, since tags are not rendered.
          #
          # @return [Integer]
          def priority = 0

          # Accepted and ignored.
          #
          # @param _value [Integer] ignored
          # @return [nil]
          def priority=(_value)
            nil
          end
        end

        # Stands in for `Gtk::TextTagTable`: the tags a {TextBuffer} knows by name.
        class TextTagTable
          # Creates an empty table.
          #
          # @return [TextTagTable] a new table
          def initialize
            @tags = []
          end

          # Adds a tag unless already present.
          #
          # @param tag [TextTag] the tag
          # @return [true]
          def add(tag)
            @tags << tag unless @tags.include?(tag)
            true
          end

          # Removes a tag.
          #
          # @param tag [TextTag] the tag
          # @return [nil]
          def remove(tag)
            @tags.delete(tag)
            nil
          end

          # Finds a tag by name.
          #
          # @param name [String, Symbol] tag name
          # @return [TextTag, nil]
          def lookup(name)
            @tags.find { |tag| tag.name == name.to_s }
          end

          # Number of tags.
          #
          # @return [Integer]
          def size = @tags.length
          # Iterates the tags.
          #
          # @yieldparam tag [TextTag]
          # @return [Array<TextTag>, Enumerator]
          def each(&block) = @tags.each(&block)
        end

        # Stands in for `Gtk::TextBuffer`: plain text shared by the {TextView}s watching it. Tags and marks are
        # accepted but never rendered; the buffer is not a {Widget}, so unknown methods degrade through the ledger
        # instead of raising.
        class TextBuffer
          extend Setters
          # @return [String] the buffer text
          # @return [TextTagTable] the tag table
          attr_reader :text, :tag_table

          # Creates an empty buffer.
          #
          # @param table [TextTagTable, nil] tag table to use; anything else gets a fresh one
          # @return [TextBuffer] a new buffer
          def initialize(table = nil)
            @text = +''
            @views = []
            @handlers = Hash.new { |hash, signal| hash[signal] = [] }
            @tag_table = table.is_a?(TextTagTable) ? table : TextTagTable.new
          end

          # Registers a view to be told when the text changes.
          #
          # @param view [TextView] the view
          # @return [void]
          def watch(view)
            @views << view unless @views.include?(view)
          end

          # Replaces the whole text. Also reachable as `set_text`, which returns self.
          #
          # @param value [String, #to_s] new text
          # @return [void]
          def text=(value)
            @text = value.to_s.dup
            notify
          end
          def_setter :set_text, :text=

          # Inserts text at an iter (at the end when the iter has no offset).
          #
          # @param iter [TextIter, Object] insertion point
          # @param string [String, #to_s] text to insert
          # @param _tags [Array] ignored tags
          # @return [self]
          def insert(iter, string, *_tags)
            offset = iter.respond_to?(:offset) ? iter.offset : @text.length
            @text.insert(offset.clamp(0, @text.length), string.to_s)
            notify
            self
          end

          # Inserts text at the end, where the cursor is taken to be.
          #
          # @param string [String, #to_s] text to insert
          # @return [self]
          def insert_at_cursor(string)
            insert(end_iter, string)
          end

          # Inserts Pango markup as plain text.
          #
          # Pango markup into a plain-text buffer: the tags are stripped and
          # the entities unescaped, so the words arrive and the styling is
          # reported once (armor's legend is bold headings over monospace).
          #
          # @param iter [TextIter, Object] insertion point
          # @param markup [String] Pango markup
          # @param _length [Integer] ignored
          # @return [self]
          def insert_markup(iter, markup, _length = -1)
            Gtk.log_unsupported('Gtk::TextBuffer', 'insert_markup', note: 'markup styling is not rendered')
            insert(iter, self.class.markup_to_text(markup))
          end

          # Strips tags from Pango markup and unescapes its entities.
          #
          # @param markup [String, #to_s] Pango markup
          # @return [String] plain text
          def self.markup_to_text(markup)
            markup.to_s.gsub(/<[^>]*>/, '')
                  .gsub('&lt;', '<').gsub('&gt;', '>').gsub('&quot;', '"').gsub('&apos;', "'").gsub('&amp;', '&')
          end

          # Accepted and ignored; marks are not kept.
          #
          # @param _mark [Object] ignored
          # @return [nil]
          def delete_mark(_mark) = nil

          # Degrades an unsupported buffer method through the ledger.
          #
          # Everything else a script asks a buffer for degrades the way a
          # widget does: reported once through the ledger, a setter answers
          # self so a chain continues, anything else answers nil. A buffer
          # is not a Widget, so it used to raise NoMethodError and kill the
          # script.
          #
          # @param name [Symbol] method name
          # @param args [Array] ignored arguments
          # @return [self, nil] self for a setter shape (`set_*` or `*=`), else nil
          # @raise [NoMethodError] for Ruby's conversion and comparison protocol (see `Widget::PROTOCOL_METHODS`)
          def method_missing(name, *args, &block)
            return super if Widget::PROTOCOL_METHODS.include?(name)

            Gtk.log_unsupported('Gtk::TextBuffer', name)
            return self if name.end_with?('=') || name.start_with?('set_')

            nil
          end

          # Answers true only for the setter shapes `method_missing` degrades.
          #
          # @param name [Symbol] method name
          # @param include_private [Boolean] passed through to Ruby
          # @return [Boolean]
          def respond_to_missing?(name, include_private = false)
            return super if Widget::PROTOCOL_METHODS.include?(name)

            name.end_with?('=') || name.start_with?('set_') || super
          end

          # Deletes the text between two iters.
          #
          # @param from [TextIter, Object] start (offset 0 when it has no offset)
          # @param to [TextIter, Object] end (the text end when it has no offset)
          # @return [self]
          def delete(from, to)
            start = from.respond_to?(:offset) ? from.offset : 0
            stop = to.respond_to?(:offset) ? to.offset : @text.length
            @text.slice!(start, stop - start)
            notify
            self
          end

          # An iter at offset 0.
          #
          # @return [TextIter]
          def start_iter
            TextIter.new(0)
          end

          # An iter at the end of the text.
          #
          # @return [TextIter]
          def end_iter
            TextIter.new(@text.length)
          end

          # An iter at an offset, clamped to the text.
          #
          # @param offset [Integer] character offset
          # @return [TextIter]
          def get_iter_at_offset(offset)
            TextIter.new(offset.to_i.clamp(0, @text.length))
          end

          # An iter at the start of a line.
          #
          # @param line [Integer] zero-based line number
          # @return [TextIter]
          def get_iter_at_line(line)
            offset = @text.lines.first(line.to_i).sum(&:length)
            TextIter.new(offset)
          end

          # The text between two iters, or all of it.
          #
          # @param from [TextIter, nil] start
          # @param to [TextIter, nil] end
          # @param _include_hidden [Boolean] ignored
          # @return [String]
          def get_text(from = nil, to = nil, _include_hidden = false)
            return @text.dup unless from || to

            start = from.respond_to?(:offset) ? from.offset : 0
            stop = to.respond_to?(:offset) ? to.offset : @text.length
            @text[start...stop].to_s
          end

          # Number of characters.
          #
          # @return [Integer]
          def char_count
            @text.length
          end

          # Number of lines, at least 1.
          #
          # @return [Integer]
          def line_count
            [@text.count("\n") + 1, 1].max
          end

          # Creates a tag and adds it to the tag table.
          #
          # @param name [String, nil] tag name
          # @param properties [Hash] properties as a hash
          # @param keyword_properties [Hash] properties as keywords
          # @return [TextTag]
          def create_tag(name = nil, properties = {}, **keyword_properties)
            tag = TextTag.new(name, (properties.is_a?(Hash) ? properties : {}).merge(keyword_properties))
            @tag_table.add(tag)
            tag
          end

          # Accepts a tag application and reports it once.
          #
          # A tag on a range is kept in the tag table and not rendered: the
          # textarea the buffer becomes carries plain text. Said once per
          # script through the ledger, never by dropping the text.
          #
          # @param _tag [TextTag] ignored
          # @param _from [TextIter, nil] ignored
          # @param _to [TextIter, nil] ignored
          # @return [self]
          def apply_tag(_tag, _from = nil, _to = nil)
            Gtk.log_unsupported('Gtk::TextBuffer', 'apply_tag', note: 'rich text ranges are not rendered')
            self
          end

          # Accepts a tag application by name and reports it once.
          #
          # @param _name [String] ignored
          # @param _from [TextIter, nil] ignored
          # @param _to [TextIter, nil] ignored
          # @return [self]
          def apply_tag_by_name(_name, _from = nil, _to = nil)
            Gtk.log_unsupported('Gtk::TextBuffer', 'apply_tag', note: 'rich text ranges are not rendered')
            self
          end

          # Accepted and ignored.
          #
          # @return [self]
          def remove_tag(_tag, _from = nil, _to = nil) = self
          # Accepted and ignored.
          #
          # @return [self]
          def remove_tag_by_name(_name, _from = nil, _to = nil) = self
          # Accepted and ignored.
          #
          # @return [self]
          def remove_all_tags(_from = nil, _to = nil) = self

          # Inserts text, dropping the tags after reporting them once.
          # Also reachable as `insert_with_tags_by_name`.
          #
          # @param iter [TextIter, Object] insertion point
          # @param string [String, #to_s] text to insert
          # @param _tags [Array] ignored
          # @return [self]
          def insert_with_tags(iter, string, *_tags)
            Gtk.log_unsupported('Gtk::TextBuffer', 'insert_with_tags', note: 'rich text ranges are not rendered')
            insert(iter, string)
          end
          alias insert_with_tags_by_name insert_with_tags

          # Marks are not kept; answers an iter at the end so `scroll_to_mark` chains still run.
          #
          # @param _args [Array] ignored
          # @return [TextIter]
          def create_mark(*_args)
            end_iter
          end

          # Connects a handler to a buffer signal; only `changed` is ever emitted.
          #
          # @param signal [String, Symbol] signal name
          # @yieldparam buffer [TextBuffer] this buffer
          # @return [Integer] number of distinct signals with handlers
          def signal_connect(signal, &block)
            @handlers[Gtk.normalize_signal(signal)] << block if block
            @handlers.length
          end

          # Takes text the viewer edited and runs the `changed` handlers without re-rendering.
          #
          # @param value [String, #to_s] the new text
          # @return [void]
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

        # Stands in for `Gtk::TextView`: renders its {TextBuffer} as the contract's `textarea` node.
        # The row count is derived from the height request.
        class TextView < Widget
          # @return [TextBuffer] the buffer shown
          attr_reader :buffer

          # Size-request axes the contract honours for this widget.
          #
          # @return [Array<Symbol>] `[:width, :height]`
          def size_request_axes
            %i[width height]
          end

          # Creates an editable view, with a fresh buffer when none is given.
          #
          # @param buffer [TextBuffer, nil] the buffer to show
          # @return [TextView] a new view
          def initialize(buffer = nil)
            super()
            self.buffer = buffer || TextBuffer.new
            @editable = true
            @rows = 5
          end

          # Replaces the buffer and watches it. Also reachable as `set_buffer`, which returns self.
          #
          # @param buffer [TextBuffer] the buffer
          # @return [void]
          def buffer=(buffer)
            @buffer = buffer
            buffer.watch(self)
            changed!
          end
          def_setter :set_buffer, :buffer=

          # Sets whether the viewer may edit. Also reachable as `set_editable`, which returns self.
          #
          # @param value [Boolean] truthy to allow edits
          # @return [void]
          def editable=(value)
            @editable = value ? true : false
            changed!
          end
          def_setter :set_editable, :editable=

          # Whether the viewer may edit.
          #
          # @return [Boolean]
          def editable?
            @editable
          end

          # Accepted and ignored: the cursor is the viewer's. Also reachable as `set_cursor_visible`.
          #
          # @param _value [Object] ignored
          # @return [void]
          def cursor_visible=(_value); end
          def_setter :set_cursor_visible, :cursor_visible=

          # Sets the size request; a positive height also sets the textarea's row count (about 20px a row).
          #
          # @param width [Integer] width in pixels, or -1
          # @param height [Integer] height in pixels, or -1
          # @return [self]
          def set_size_request(width, height)
            @rows = [(height.to_i / 20), 2].max if height.to_i.positive?
            super
          end

          # Accepted and ignored; scrolling is the viewer's.
          #
          # @param _args [Array] ignored
          # @return [self]
          def scroll_to_mark(*_args)
            self
          end

          # Accepted and ignored; scrolling is the viewer's.
          #
          # @param _args [Array] ignored
          # @return [self]
          def scroll_to_iter(*_args)
            self
          end

          # Pushes the buffer text to every viewer; called by the buffer on every write.
          #
          # @return [void]
          def buffer_changed!
            viewer_push(:value, @buffer.text)
          end

          # Contract event a GTK signal maps to for this widget.
          #
          # @param signal [Symbol] normalized GTK signal name
          # @return [Symbol, nil] :focus or :blur; nil otherwise
          def event_for(signal)
            case signal
            when :focus_in_event then :focus
            when :focus_out_event then :blur
            end
          end

          # Events bound whether or not the script connected a handler.
          #
          # @return [Array<Symbol>] always `[:change]`
          def always_bound_events
            [:change]
          end

          # Contract node type this widget renders as.
          #
          # @return [Symbol]
          def node_type
            :textarea
          end

          # Contract props for this widget's node.
          #
          # @return [Hash{Symbol => Object}] `value`, `rows` and, when insensitive or not editable, `disabled`
          def node_props
            props = { value: @buffer.text.dup, rows: @rows.clamp(1, 64) }
            props[:disabled] = true unless @sensitive && @editable
            props
          end

          protected

          # Updates shadow state from a contract event before any GTK handler runs.
          #
          # @param event [Symbol] the contract event that arrived
          # @param context [Object] the runtime event context (payload reachable through `payload_value`)
          # @return [void]
          def apply_event(event, context)
            return unless event == :change

            value = payload_value(context)
            @buffer.changed_by_viewer!(value) unless value.nil?
          end
        end

        # Stands in for `Gtk::TreePath`: a colon-separated list of indices, one per tree level.
        #
        # ------------------------------------------------------------------
        # TreeView family -> table
        # ------------------------------------------------------------------
        class TreePath
          # @return [Array<Integer>] one index per level, outermost first
          attr_reader :indices

          # Creates a path from a "0:1:2" string or an index array.
          #
          # @param spec [String, Array<Integer>, #to_s] the path spec
          # @return [TreePath] a new path
          def initialize(spec = '0')
            @indices = spec.is_a?(Array) ? spec.map(&:to_i) : spec.to_s.split(':').map(&:to_i)
          end

          # The colon-separated form. Also reachable as `to_str`.
          #
          # @return [String]
          def to_s
            @indices.join(':')
          end
          alias to_str to_s

          # Compares by indices with another path, or by string form with anything else.
          #
          # @param other [TreePath, Object] the other path
          # @return [Boolean]
          def ==(other)
            other.respond_to?(:indices) ? indices == other.indices : to_s == other.to_s
          end
        end

        # Stands in for `Gtk::TreeIter`.
        #
        # A row handle. Scripts index it with the model column number.
        class TreeIter
          # @return [ListStore] the model the row belongs to
          # @return [String] the row key, unique within the model
          # @return [Array] the cell values, shared with the model's row
          attr_reader :model, :key, :values
          # @return [String, nil] key of the parent row, nil at top level
          attr_accessor :parent_key

          # Creates a row handle.
          #
          # @param model [ListStore] the owning model
          # @param key [String] row key
          # @param values [Array] cell values
          # @param parent_key [String, nil] parent row key
          # @return [TreeIter] a new iter
          def initialize(model, key, values, parent_key = nil)
            @model = model
            @key = key
            @values = values
            @parent_key = parent_key
          end

          # Reads a cell.
          #
          # @param column [Integer] model column
          # @return [Object] the cell value
          def [](column)
            @values[column.to_i]
          end

          # Writes a cell, coerced to the column type, and re-renders the views. Also reachable as `set_values_at`.
          #
          # @param column [Integer] model column
          # @param value [Object] the new value
          # @return [void]
          def []=(column, value)
            @values[column.to_i] = @model.coerce(column.to_i, value)
            @model.row_changed!
          end

          # Writes a cell; same as `[]=`.
          #
          # @param column [Integer] model column
          # @param value [Object] the new value
          # @return [void]
          def set_value(column, value)
            self[column] = value
          end
          alias set_values_at []=

          # Reads a cell; same as `[]`.
          #
          # @param column [Integer] model column
          # @return [Object]
          def get_value(column)
            self[column]
          end

          # The path of this row in its model.
          #
          # @return [TreePath]
          def path
            TreePath.new(@model.path_indices(self))
          end

          # Advances this iter to the next row at the same level.
          #
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
          #
          # @return [Boolean] false when there is no next row, leaving the iter where it was
          def next!
            following = @model.iter_after(self)
            return false unless following

            @key = following.key
            @parent_key = following.parent_key
            @values = following.values
            true
          end

          # Two iters are equal when they name the same row of the same model. Also reachable as `eql?`.
          #
          # @param other [Object] the other iter
          # @return [Boolean]
          def ==(other)
            other.is_a?(TreeIter) && other.model.equal?(@model) && other.key == @key
          end
          alias eql? ==

          # Hash consistent with `==`.
          #
          # @return [Integer]
          def hash
            [@model.object_id, @key].hash
          end
        end

        # Stands in for `Gtk::ListStore`: a flat table of typed columns whose rows are {TreeIter}s. Every iter handed
        # out is a copy that shares the row's values array, so writes through it reach the model.
        class ListStore
          # @return [Array<Class>] one of String, Integer, Float or TrueClass per column
          attr_reader :column_types
          # @return [String, nil] the id a builder file gave this store
          attr_accessor :builder_name

          # Creates an empty store with the given column types.
          #
          # @param types [Array<Class, String, Symbol>] GType names (`gchararray`), Ruby classes or their names;
          #   unknown types become String
          # @return [ListStore] a new store
          def initialize(*types)
            @column_types = types.map { |type| normalize_type(type) }
            @rows = [] # TreeIter, in display order
            @views = []
            @next_key = 0
            @sort_column = nil
          end

          # Registers a view to be told when rows change.
          #
          # @param view [TreeView] the view
          # @return [void]
          def watch(view)
            @views << view unless @views.include?(view)
          end

          # Number of columns.
          #
          # @return [Integer]
          def n_columns
            @column_types.length
          end

          # The type of a column.
          #
          # @param index [Integer] column index
          # @return [Class, nil]
          def get_column_type(index)
            @column_types[index.to_i]
          end

          # Adds a row at the end with each cell at its type's zero value.
          #
          # @param parent [TreeIter, nil] parent row (only meaningful for a {TreeStore})
          # @return [TreeIter] a copy naming the new row
          def append(parent = nil)
            iter = TreeIter.new(self, next_key, Array.new(n_columns) { |i| coerce(i, nil) }, parent&.key)
            @rows << iter
            row_changed!
            dup_row(iter)
          end

          # Adds a row at the front with each cell at its type's zero value.
          #
          # @param parent [TreeIter, nil] parent row (only meaningful for a {TreeStore})
          # @return [TreeIter] a copy naming the new row
          def prepend(parent = nil)
            iter = TreeIter.new(self, next_key, Array.new(n_columns) { |i| coerce(i, nil) }, parent&.key)
            @rows.unshift(iter)
            row_changed!
            dup_row(iter)
          end

          # Adds a row at a position, clamped to the row range.
          #
          # @param position [Integer] index to insert at
          # @param parent [TreeIter, nil] parent row (only meaningful for a {TreeStore})
          # @return [TreeIter] a copy naming the new row
          def insert(position, parent = nil)
            iter = TreeIter.new(self, next_key, Array.new(n_columns) { |i| coerce(i, nil) }, parent&.key)
            @rows.insert(position.to_i.clamp(0, @rows.length), iter)
            row_changed!
            dup_row(iter)
          end

          # Removes a row and its direct children.
          #
          # @param iter [TreeIter] the row
          # @return [Boolean] whether a row was removed
          def remove(iter)
            removed = @rows.delete(iter)
            @rows.delete_if { |row| row.parent_key == iter.key } if removed
            row_changed!
            !removed.nil?
          end

          # Removes every row.
          #
          # @return [self]
          def clear
            @rows.clear
            row_changed!
            self
          end

          # Iterates the rows in display order.
          #
          # @yieldparam model [ListStore] this store
          # @yieldparam path [TreePath] the row's path
          # @yieldparam iter [TreeIter] a copy naming the row
          # @return [Array<TreeIter>, Enumerator] an enumerator when no block is given
          def each
            return enum_for(:each) unless block_given?

            @rows.dup.each { |iter| yield self, iter.path, dup_row(iter) }
          end

          # The first row.
          #
          # A copy, like every iter the model hands out: #next! advances by
          # rewriting the iter's key, so handing back the row itself let a
          # walk rewrite the model.
          #
          # @return [TreeIter, nil] a copy, or nil when the store is empty
          def iter_first
            dup_row(@rows.first)
          end

          # The row at a path.
          #
          # @param path [TreePath, String, Array<Integer>] the path
          # @return [TreeIter, nil] a copy, or nil when nothing is there
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

          # The row following one in the backing array.
          #
          # @param iter [TreeIter] the row
          # @return [TreeIter, nil] a copy, or nil at the end or for an unknown row
          def iter_after(iter)
            index = @rows.index { |row| row.key == iter.key }
            return nil unless index

            dup_row(@rows[index + 1])
          end

          # A fresh iter naming a row.
          #
          # A copy that names the same row. #next! advances an iter by
          # rewriting its key, and the model hands out its own row objects,
          # so without a copy the caller's iter IS a row and advancing it
          # rewrote that row. Lookups are all by key, which the copy keeps,
          # and @values is the row's own array, so writing through the copy
          # still reaches the model.
          #
          # @param row [TreeIter, nil] the model's own row object
          # @return [TreeIter, nil] the copy, or nil for nil
          def dup_row(row)
            return nil unless row

            TreeIter.new(self, row.key, row.values, row.parent_key)
          end

          # Path indices of a row; a list store answers its index among its siblings.
          #
          # @param iter [TreeIter] the row
          # @return [Array<Integer>]
          def path_indices(iter)
            siblings = @rows.select { |row| row.parent_key == iter.parent_key }
            [siblings.index(iter) || 0]
          end

          # The rows in display order.
          #
          # @return [Array<TreeIter>] a copy of the row list (the model's own row objects)
          def rows
            @rows.dup
          end

          # Number of rows. Also reachable as `length`.
          #
          # @return [Integer]
          def size
            @rows.length
          end
          alias length size

          # Whether the store has no rows.
          #
          # @return [Boolean]
          def empty?
            @rows.empty?
          end

          # Records the sort column; rows are not reordered.
          #
          # @param column [Integer] model column
          # @param _order [Object] ignored sort order
          # @return [self]
          def set_sort_column_id(column, _order = nil)
            @sort_column = column.to_i
            self
          end

          # Accepted and ignored; rows are not sorted.
          #
          # @param _args [Array] ignored
          # @return [self]
          def set_sort_func(*_args)
            self
          end

          # Accepted and ignored; rows are not sorted.
          #
          # @param _args [Array] ignored
          # @return [self]
          def set_default_sort_func(*_args)
            self
          end

          # Converts a value to the column's type (nil becomes the type's zero value).
          #
          # @param column [Integer] model column
          # @param value [Object] the value
          # @return [String, Integer, Float, Boolean]
          def coerce(column, value)
            type = @column_types[column]
            if type == Integer then value.to_i
            elsif type == Float then value.to_f
            elsif type == TrueClass then value ? true : false
            else value.nil? ? '' : value.to_s
            end
          end

          # Tells every watching view the rows changed.
          #
          # @return [void]
          def row_changed!
            @views.each(&:model_changed!)
          end

          # Accepts and ignores builder properties; a store has none the shim uses.
          #
          # @param _name [String, Symbol] ignored
          # @param _value [Object] ignored
          # @return [self]
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

        # Stands in for `Gtk::TreeStore`: a {ListStore} whose rows nest through `parent_key`.
        #
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
          # Path indices of a row in the tree.
          #
          # Every ancestor index, outermost first, which is what a TreePath
          # spells with colons.
          #
          # @param iter [TreeIter] the row
          # @return [Array<Integer>]
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

          # The next sibling of a row.
          #
          # The next row at the SAME level under the same parent. The flat
          # implementation returned the following row in the backing array,
          # which for a row with children is its own first child.
          #
          # @param iter [TreeIter] the row
          # @return [TreeIter, nil] a copy, or nil for the last sibling or an unknown row
          def iter_after(iter)
            siblings = @rows.select { |row| row.parent_key == iter.parent_key }
            index = siblings.index { |row| row.key == iter.key }
            return nil unless index

            dup_row(siblings[index + 1])
          end

          # Removes a row and its whole subtree.
          #
          # Depth-first, so a subtree goes with the row that owns it rather
          # than leaving orphans behind.
          #
          # @param iter [TreeIter] the row
          # @return [Boolean] whether a row was removed
          def remove(iter)
            row = @rows.find { |candidate| candidate.key == iter.key }
            return false unless row

            descendants_of(row.key).each { |key| @rows.delete_if { |candidate| candidate.key == key } }
            @rows.delete(row)
            row_changed!
            true
          end

          # Number of direct children of a row, or of top-level rows.
          #
          # How many children a row has, which GTK exposes and a script that
          # walks a tree asks for.
          #
          # @param iter [TreeIter, nil] the row, or nil for the root
          # @return [Integer]
          def iter_n_children(iter = nil)
            parent_key = iter&.key
            @rows.count { |row| row.parent_key == parent_key }
          end

          # Whether a row has children.
          #
          # @param iter [TreeIter] the row
          # @return [Boolean]
          def iter_has_child?(iter)
            iter_n_children(iter).positive?
          end

          # The first child of a row, or the first top-level row.
          #
          # @param iter [TreeIter, nil] the row, or nil for the root
          # @return [TreeIter, nil] a copy, or nil when there is none
          def iter_children(iter = nil)
            dup_row(@rows.find { |row| row.parent_key == iter&.key })
          end

          # The parent of a row.
          #
          # @param iter [TreeIter] the row
          # @return [TreeIter, nil] a copy, or nil at top level
          def iter_parent(iter)
            return nil unless iter.parent_key

            dup_row(@rows.find { |row| row.key == iter.parent_key })
          end

          # Keys of every row beneath one.
          #
          # The keys of every row beneath +iter+, at any depth.
          #
          # @param iter [TreeIter] the row
          # @return [Array<String>] depth-first
          def iter_descendant_keys(iter)
            descendants_of(iter.key)
          end

          private

          # Every key beneath +key+, at any depth.
          def descendants_of(key)
            direct = @rows.select { |row| row.parent_key == key }.map(&:key)
            direct.flat_map { |child| [child] + descendants_of(child) }
          end
        end

        # Stands in for `Gtk::CellRenderer`: holds the signal handlers a column's cell emits to (`edited`, `toggled`)
        # and degrades every other method through the ledger.
        class CellRenderer
          # @return [String, nil] the id a builder file gave this renderer
          attr_accessor :builder_name

          # Creates a renderer with no handlers.
          #
          # @return [CellRenderer] a new renderer
          def initialize
            @handlers = Hash.new { |hash, signal| hash[signal] = [] }
          end

          # Connects a handler to a renderer signal.
          #
          # @param signal [String, Symbol] signal name
          # @yieldparam renderer [CellRenderer] this renderer
          # @yieldparam args [Array] the signal's arguments
          # @return [Integer] number of distinct signals with handlers
          def signal_connect(signal, &block)
            @handlers[Gtk.normalize_signal(signal)] << block if block
            @handlers.length
          end

          # Runs the handlers connected to a signal.
          #
          # @param signal [String, Symbol] signal name
          # @param args [Array] handler arguments after the renderer
          # @return [void]
          def emit(signal, *args)
            @handlers[Gtk.normalize_signal(signal)].each { |handler| Widget.call_handler(handler, [self, *args]) }
          end

          # Applies a GtkBuilder property through a setter this renderer defines.
          #
          # Only a setter the renderer actually defines is applied. This
          # used to test `!respond_to?(:method_missing)`, which is false for
          # every renderer since they all define it, so no Glade property
          # ever reached a renderer: an `editable` column stayed read-only
          # (review 2026-09-17, R11).
          #
          # @param name [String, Symbol] property name
          # @param value [String] property value as written in the builder file
          # @return [self]
          def apply_builder_property(name, value)
            setter = "#{name.to_s.tr('-', '_')}="
            public_send(setter, Gtk.builder_value(value)) if self.class.public_method_defined?(setter)
            self
          end

          # Degrades an unsupported renderer method through the ledger.
          #
          # @param name [Symbol] method name
          # @param _args [Array] ignored
          # @return [self, nil] self for a setter shape (`set_*` or `*=`), else nil
          # @raise [NoMethodError] for Ruby's conversion and comparison protocol (see `Widget::PROTOCOL_METHODS`)
          def method_missing(name, *_args, &_block)
            return super if Widget::PROTOCOL_METHODS.include?(name)

            Gtk.log_unsupported(self.class.name.split('::').last, name)
            name.end_with?('=') || name.start_with?('set_') ? self : nil
          end

          # Claims every method except Ruby's conversion and comparison protocol.
          #
          # @param name [Symbol] method name
          # @param include_private [Boolean] passed through to Ruby
          # @return [Boolean]
          def respond_to_missing?(name, include_private = false)
            return super if Widget::PROTOCOL_METHODS.include?(name)

            true
          end
        end

        # Stands in for `Gtk::CellRendererText`: an editable one gives its column a text editor.
        class CellRendererText < CellRenderer
          extend Setters
          # @return [Boolean] whether the viewer may edit the cell
          attr_reader :editable

          # Creates a read-only text renderer.
          #
          # @return [CellRendererText] a new renderer
          def initialize
            super
            @editable = false
          end

          # Sets whether the cell may be edited. Also reachable as `set_editable`, which returns self.
          #
          # @param value [Boolean] truthy to allow edits
          # @return [void]
          def editable=(value)
            @editable = value ? true : false
          end
          def_setter :set_editable, :editable=

          # The contract editor spec for this cell.
          #
          # @return [Hash{Symbol => String}, nil] `{ type: 'text' }` when editable, else nil
          def editor
            @editable ? { type: 'text' } : nil
          end
        end

        # Stands in for `Gtk::CellRendererToggle`: an activatable one gives its column a checkbox editor.
        class CellRendererToggle < CellRenderer
          # Creates an activatable toggle renderer.
          #
          # @return [CellRendererToggle] a new renderer
          def initialize
            super
            @activatable = true
          end

          # Sets whether the viewer may toggle the cell.
          #
          # @param value [Boolean] truthy to allow toggling
          # @return [void]
          def activatable=(value)
            @activatable = value ? true : false
          end

          # The contract editor spec for this cell.
          #
          # @return [Hash{Symbol => String}, nil] `{ type: 'checkbox' }` when activatable, else nil
          def editor
            @activatable ? { type: 'checkbox' } : nil
          end
        end

        # Stands in for `Gtk::CellRendererCombo`; behaves as a {CellRendererText}.
        class CellRendererCombo < CellRendererText
        end

        # Stands in for `Gtk::TreeViewColumn`: a title, one renderer and the attribute map that names the model
        # column feeding the cell.
        class TreeViewColumn
          extend Setters
          # @return [String] the header text
          # @return [CellRenderer, nil] the first renderer packed
          # @return [Hash{String => Integer}] renderer attribute name => model column
          attr_reader :title, :renderer, :attributes
          # @return [String, nil] the id a builder file gave this column
          # @return [Integer, nil] the model column this column sorts by
          attr_accessor :builder_name, :sort_column_id

          # Creates a visible column.
          #
          # @param title [String, nil] header text
          # @param renderer [CellRenderer, nil] the cell renderer
          # @param attributes [Hash{String, Symbol => Integer}] attribute name => model column
          # @return [TreeViewColumn] a new column
          def initialize(title = nil, renderer = nil, attributes = {})
            @title = title.to_s
            @renderer = renderer
            @attributes = attributes.to_h { |name, column| [name.to_s, column.to_i] }
            @sort_column_id = nil
            @expand = false
            @visible = true
          end

          # Sets the header text. Also reachable as `set_title`, which returns self.
          #
          # @param value [String, #to_s] header text
          # @return [void]
          def title=(value)
            @title = value.to_s
          end
          def_setter :set_title, :title=

          # Installs the renderer unless one is already packed. Also reachable as `pack_end`.
          #
          # @param renderer [CellRenderer] the renderer
          # @param _expand [Boolean] ignored
          # @return [self]
          def pack_start(renderer, _expand = true)
            @renderer ||= renderer
            self
          end
          alias pack_end pack_start

          # Maps a renderer attribute to a model column.
          #
          # @param _renderer [CellRenderer] ignored; the column has one renderer
          # @param name [String, Symbol] attribute name (`text`, `active`, `markup`)
          # @param column [Integer] model column
          # @return [self]
          def add_attribute(_renderer, name, column)
            @attributes[name.to_s] = column.to_i
            self
          end

          # Maps several renderer attributes to model columns.
          #
          # @param _renderer [CellRenderer] ignored; the column has one renderer
          # @param attributes [Hash{String, Symbol => Integer}] attribute name => model column
          # @return [self]
          def set_attributes(_renderer, attributes)
            attributes.each { |name, column| @attributes[name.to_s] = column.to_i }
            self
          end

          # Records the sort column.
          #
          # @param column [Integer] model column
          # @return [self]
          def set_sort_column_id(column)
            @sort_column_id = column.to_i
            self
          end

          # Records whether the column expands. Also reachable as `set_expand`, which returns self.
          #
          # @param value [Boolean] truthy to expand
          # @return [void]
          def expand=(value)
            @expand = value ? true : false
          end
          def_setter :set_expand, :expand=

          # Accepted and ignored: column widths are the viewer's. Also reachable as `set_resizable`.
          #
          # @param _value [Object] ignored
          # @return [void]
          def resizable=(_value); end
          def_setter :set_resizable, :resizable=

          # Shows or hides the column.
          #
          # @param value [Boolean] truthy to show
          # @return [void]
          def visible=(value)
            @visible = value ? true : false
          end

          # Whether the column is shown.
          #
          # @return [Boolean]
          def visible?
            @visible
          end

          # Accepted and ignored: column widths are the viewer's. Also reachable as `set_fixed_width`.
          #
          # @param _value [Object] ignored
          # @return [void]
          def fixed_width=(_value); end
          def_setter :set_fixed_width, :fixed_width=

          # Accepted and ignored: column sizing is the viewer's. Also reachable as `set_sizing`.
          #
          # @param _value [Object] ignored
          # @return [void]
          def sizing=(_value); end
          def_setter :set_sizing, :sizing=

          # Accepts a cell data function and reports it once; cells show the model value.
          #
          # @param _args [Array] ignored
          # @return [self]
          def set_cell_data_func(*_args)
            Gtk.log_unsupported('Gtk::TreeViewColumn', 'set_cell_data_func', note: 'cell data functions are ignored')
            self
          end

          # The model column shown in the cell.
          #
          # Model column that feeds the cell's visible text (or toggle).
          #
          # @return [Integer] `text`, `active` or `markup`, else column 0
          def value_column
            @attributes['text'] || @attributes['active'] || @attributes['markup'] || 0
          end

          # Applies a GtkBuilder property through a setter this column answers to.
          #
          # @param name [String, Symbol] property name
          # @param value [String] property value as written in the builder file
          # @return [self]
          def apply_builder_property(name, value)
            setter = "#{name.to_s.tr('-', '_')}="
            public_send(setter, Gtk.builder_value(value)) if respond_to?(setter)
            self
          end
        end

        # Stands in for `Gtk::TreeSelection`: a view of its {TreeView}'s selected keys.
        class TreeSelection
          extend Setters
          # @return [Symbol] `:single`, `:multiple`, `:browse` or `:none`
          attr_reader :mode

          # Creates a single-selection for a view.
          #
          # @param view [TreeView] the owning view
          # @return [TreeSelection] a new selection
          def initialize(view)
            @view = view
            @mode = :single
            @handlers = []
          end

          # Sets the selection mode. Also reachable as `set_mode`, which returns self.
          #
          # @param value [Symbol, String, #to_s] mode name, case-insensitive
          # @return [void]
          def mode=(value)
            @mode = value.to_s.downcase.to_sym
            @view.changed!
          end
          def_setter :set_mode, :mode=

          # The first selected row.
          #
          # @return [TreeIter, nil] a copy, or nil when nothing is selected
          def selected
            @view.selected_iters.first
          end

          # Paths of the selected rows.
          #
          # @return [Array<TreePath>]
          def selected_rows
            @view.selected_iters.map(&:path)
          end

          # Iterates the selected rows.
          #
          # @yieldparam model [ListStore, nil] the view's model
          # @yieldparam path [TreePath] the row's path
          # @yieldparam iter [TreeIter] a copy naming the row
          # @return [Array<TreeIter>]
          def selected_each
            @view.selected_iters.each { |iter| yield @view.model, iter.path, iter }
          end

          # Selects one row, replacing the selection.
          #
          # @param iter [TreeIter] the row
          # @return [void]
          def select_iter(iter)
            @view.select_keys([iter.key])
          end

          # Selects the row at a path; a path with no row is ignored.
          #
          # @param path [TreePath, String, Array<Integer>] the path
          # @return [void]
          def select_path(path)
            iter = @view.model&.get_iter(path)
            select_iter(iter) if iter
          end

          # Clears the selection.
          #
          # @return [void]
          def unselect_all
            @view.select_keys([])
          end

          # Selects every row.
          #
          # @return [void]
          def select_all
            @view.select_keys(@view.model ? @view.model.rows.map(&:key) : [])
          end

          # Whether a row is selected.
          #
          # @param iter [TreeIter] the row
          # @return [Boolean]
          def iter_is_selected?(iter)
            @view.selected_keys.include?(iter.key)
          end

          # Number of selected rows.
          #
          # @return [Integer]
          def count_selected_rows
            @view.selected_keys.length
          end

          # Connects a handler; every signal is treated as `changed`.
          #
          # @param _signal [String, Symbol] ignored signal name
          # @yieldparam selection [TreeSelection] this selection
          # @return [Integer] number of handlers
          def signal_connect(_signal, &block)
            @handlers << block if block
            @handlers.length
          end

          # Runs the handlers; called by the view whenever the selected keys change.
          #
          # @return [void]
          def changed!
            @handlers.each { |handler| Widget.call_handler(handler, [self]) }
          end

          # Applies a GtkBuilder property; only `mode` is understood.
          #
          # @param name [String, Symbol] property name
          # @param value [String] property value
          # @return [self]
          def apply_builder_property(name, value)
            self.mode = value if name.to_s == 'mode'
            self
          end
        end

        # Stands in for `Gtk::TreeView`: renders a {ListStore} or {TreeStore} through its columns as the contract's
        # `table` node. Selection and expansion are kept as row keys; every iter handed to a script is a copy.
        class TreeView < Widget
          # @return [ListStore, nil] the model shown
          # @return [TreeSelection] the selection
          attr_reader :model, :selection

          # Size-request axes the contract honours for this widget.
          #
          # @return [Array<Symbol>] `[:width, :height]`
          def size_request_axes
            %i[width height]
          end

          # Creates a view with visible headers and no columns.
          #
          # @param model [ListStore, nil] the model to show
          # @return [TreeView] a new view
          def initialize(model = nil)
            super()
            @columns = []
            @selected_keys = []
            @expanded_keys = []
            @selection = TreeSelection.new(self)
            @headers_visible = true
            self.model = model if model
          end

          # Replaces the model, watches it and forgets the selection and expansion.
          # Also reachable as `set_model`, which returns self.
          #
          # @param model [ListStore, nil] the model
          # @return [void]
          def model=(model)
            @model = model
            model&.watch(self)
            @selected_keys = []
            @expanded_keys = []
            changed!
          end
          def_setter :set_model, :model=

          # Adds a column at the end.
          #
          # @param column [TreeViewColumn] the column
          # @return [Integer] number of columns
          def append_column(column)
            @columns << column
            changed!
            @columns.length
          end

          # Adds a column at a position, clamped to the column range.
          #
          # @param column [TreeViewColumn] the column
          # @param position [Integer] index to insert at
          # @return [Integer] number of columns
          def insert_column(column, position)
            @columns.insert(position.to_i.clamp(0, @columns.length), column)
            changed!
            @columns.length
          end

          # Removes a column.
          #
          # @param column [TreeViewColumn] the column
          # @return [Integer] number of columns
          def remove_column(column)
            @columns.delete(column)
            changed!
            @columns.length
          end

          # The columns in order.
          #
          # @return [Array<TreeViewColumn>] a copy
          def columns
            @columns.dup
          end

          # The column at an index.
          #
          # @param index [Integer] column index
          # @return [TreeViewColumn, nil]
          def get_column(index)
            @columns[index.to_i]
          end

          # Shows or hides the header row. Also reachable as `set_headers_visible`, which returns self.
          #
          # @param value [Boolean] truthy to show headers
          # @return [void]
          def headers_visible=(value)
            @headers_visible = value ? true : false
            changed!
          end
          def_setter :set_headers_visible, :headers_visible=

          # Accepted and ignored: searching is the viewer's. Also reachable as `set_enable_search`.
          #
          # @param _value [Object] ignored
          # @return [void]
          def enable_search=(_value); end
          def_setter :set_enable_search, :enable_search=

          # Accepted and ignored: searching is the viewer's. Also reachable as `set_search_column`.
          #
          # @param _value [Object] ignored
          # @return [void]
          def search_column=(_value); end
          def_setter :set_search_column, :search_column=

          # Accepted and ignored: drag reordering is not offered. Also reachable as `set_reorderable`.
          #
          # @param _value [Object] ignored
          # @return [void]
          def reorderable=(_value); end
          def_setter :set_reorderable, :reorderable=

          # Accepted and ignored: row striping is the viewer's. Also reachable as `set_rules_hint`.
          #
          # @param _value [Object] ignored
          # @return [void]
          def rules_hint=(_value); end
          def_setter :set_rules_hint, :rules_hint=

          # Selects the row at a path; a path with no row is ignored.
          #
          # @param path [TreePath, String, Array<Integer>] the path
          # @param _column [TreeViewColumn, nil] ignored
          # @param _start_editing [Boolean] ignored
          # @return [self]
          def set_cursor(path, _column = nil, _start_editing = false)
            iter = @model&.get_iter(path)
            select_keys([iter.key]) if iter
            self
          end

          # Opens every row that has children.
          #
          # ---- expansion (review 2026-09-17 (b), F4) ----------------------
          # Which rows are open is the viewer's own state: the runtime keeps
          # it per viewer as row_toggle reports it, and the shim binds that
          # event for a tree store so the report is taken rather than dropped
          # as unbound -- a branch the player opened used to fold again on
          # the next render. The shim keeps its own copy for the script's
          # queries, and the script's own expand and collapse are pushed to
          # every viewer, as any viewer-scoped write is.
          #
          # @return [self]
          def expand_all
            parent_keys.each { |key| set_row_expanded(key, true) }
            self
          end

          # Closes every open row.
          #
          # @return [self]
          def collapse_all
            @expanded_keys.dup.each { |key| set_row_expanded(key, false) }
            self
          end

          # Opens the row at a path, and optionally every parent row beneath it.
          #
          # @param path [TreePath, String, Array<Integer>] the path
          # @param open_all [Boolean] also open the descendants
          # @return [Boolean] false when there is no such row or it has no children
          def expand_row(path, open_all = false)
            iter = @model&.get_iter(path)
            return false unless iter && parent_keys.include?(iter.key)

            keys = [iter.key]
            keys += @model.iter_descendant_keys(iter) & parent_keys if open_all
            keys.each { |key| set_row_expanded(key, true) }
            true
          end

          # Closes the row at a path.
          #
          # @param path [TreePath, String, Array<Integer>] the path
          # @return [Boolean] false when there is no such row or it was not open
          def collapse_row(path)
            iter = @model&.get_iter(path)
            return false unless iter && @expanded_keys.include?(iter.key)

            set_row_expanded(iter.key, false)
            true
          end

          # Whether the row at a path is open.
          #
          # @param path [TreePath, String, Array<Integer>] the path
          # @return [Boolean]
          def row_expanded?(path)
            iter = @model&.get_iter(path)
            iter ? @expanded_keys.include?(iter.key) : false
          end

          # Keys of the rows that have children.
          #
          # Rows with a child: the only ones that can open.
          #
          # @return [Array<String>]
          def parent_keys
            return [] unless @model

            @model.rows.map(&:parent_key).compact.uniq
          end

          # Whether the model is a {TreeStore}.
          #
          # @return [Boolean]
          def hierarchical?
            @model.is_a?(TreeStore)
          end

          # Accepted and ignored; column widths are the viewer's.
          #
          # @return [self]
          def columns_autosize
            self
          end

          # Drops selected and expanded keys the model no longer has and re-renders; called by the model.
          #
          # @return [void]
          def model_changed!
            if @model
              keys = @model.rows.map(&:key)
              @selected_keys &= keys
              @expanded_keys &= keys
            end
            changed!
          end

          # Keys of the selected rows.
          #
          # @return [Array<String>] a copy
          def selected_keys
            @selected_keys.dup
          end

          # Opens or closes a row by key and pushes the state to every viewer.
          #
          # @param key [String] row key
          # @param open [Boolean] truthy to open
          # @return [void]
          def set_row_expanded(key, open)
            if open
              @expanded_keys |= [key]
            else
              @expanded_keys.delete(key)
            end
            viewer_push(:"expanded:#{key}", open ? true : false)
          end

          # A copy of the model row with a key.
          #
          # Copies, for the same reason iter_first/get_iter/append do: #next!
          # advances an iter by rewriting its key, so handing a script the
          # model's own row object let a walk from `selection.selected` rewrite
          # the model. Walking [alpha, beta, gamma] from the selected first row
          # repeated `beta` forever and left the store as [beta, beta, gamma].
          # dup_row shares the row's values array, so writing through the copy
          # still reaches the model.
          # A cursor over the named row, never the model's own object. Writes
          # through it still land, because the copy shares the values array.
          #
          # @param row_key [String] row key
          # @return [TreeIter, nil] the copy, or nil for an unknown key or no model
          def find_row_copy(row_key)
            row = @model&.rows&.find { |candidate| candidate.key == row_key }
            row && @model.send(:dup_row, row)
          end

          # Copies of the selected rows, in model order.
          #
          # @return [Array<TreeIter>]
          def selected_iters
            return [] unless @model

            @model.rows.select { |iter| @selected_keys.include?(iter.key) }
                       .map { |iter| @model.send(:dup_row, iter) }
          end

          # Replaces the selection, pushes it to every viewer and runs the selection's handlers.
          #
          # @param keys [Array<String>] row keys
          # @return [void]
          def select_keys(keys)
            @selected_keys = keys.uniq
            viewer_push(:selected, @selected_keys.dup)
            @selection.changed!
          end

          # Applies a GtkBuilder property; `model` takes a store, anything else goes to {Widget}.
          #
          # @param name [String, Symbol] property name
          # @param value [Object] property value; a {ListStore} for `model`
          # @return [self]
          def apply_builder_property(name, value)
            return super unless name.to_s == 'model'

            self.model = value if value.is_a?(ListStore)
            self
          end

          # Contract event a GTK signal maps to for this widget.
          #
          # @param signal [Symbol] normalized GTK signal name
          # @return [Symbol, nil] :row_activate for `row_activated`, else nil
          def event_for(signal)
            :row_activate if signal == :row_activated
          end

          # Events bound whether or not the script connected a handler.
          #
          # @return [Array<Symbol>] :selection_change unless the mode is none, :cell_edit when a column is editable,
          #   :row_toggle for a tree store
          def always_bound_events
            events = []
            events << :selection_change unless @selection.mode == :none
            events << :cell_edit if @columns.any? { |column| column.renderer&.editor }
            events << :row_toggle if hierarchical?
            events
          end

          # Contract node type this widget renders as.
          #
          # @return [Symbol]
          def node_type
            :table
          end

          # Contract props for this widget's node.
          #
          # @return [Hash{Symbol => Object}] `columns`, `rows`, `selection` and, as needed, `headers`, `selected` and
          #   `disabled`
          def node_props
            columns = @columns.select(&:visible?).each_with_index.map do |column, index|
              spec = { key: "c#{index}", label: column.title.empty? ? ' ' : column.title }
              editor = column.renderer&.editor
              spec[:editor] = editor if editor
              spec
            end
            columns = [{ key: 'c0', label: ' ' }] if columns.empty?
            parents = parent_keys
            rows = (@model ? @model.rows : []).map do |iter|
              cells = @columns.select(&:visible?).each_with_index.to_h do |column, index|
                ["c#{index}", cell_value(iter[column.value_column])]
              end
              cells = { 'c0' => cell_value(iter[0]) } if @columns.select(&:visible?).empty?
              row = { key: iter.key, cells: cells }
              row[:parent] = iter.parent_key if iter.parent_key
              row[:expanded] = @expanded_keys.include?(iter.key) if parents.include?(iter.key)
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

          # Updates shadow state from a contract event; a cell edit is handed to the renderer's handlers instead.
          #
          # @param event [Symbol] the contract event that arrived
          # @param context [Object] the runtime event context (payload reachable through `payload_value`)
          # @return [void]
          def apply_event(event, context)
            case event
            when :selection_change
              rows = payload_value(context, :rows)
              @selected_keys = Array(rows).map(&:to_s) unless rows.nil?
              @selection.changed!
            when :row_toggle
              # The viewer already holds the state it reported; this is the
              # shim's copy, so nothing is pushed back.
              key = payload_value(context, :row).to_s
              if payload_value(context, :expanded)
                @expanded_keys |= [key]
              else
                @expanded_keys.delete(key)
              end
            when :cell_edit
              row_key = payload_value(context, :row).to_s
              column_key = payload_value(context, :column).to_s
              value = payload_value(context)
              index = column_key.delete_prefix('c').to_i
              column = @columns.select(&:visible?)[index]
              iter = find_row_copy(row_key)
              # The script owns the model, as under GTK: the renderer's
              # signal tells it what the viewer did and its handler decides
              # what the cell holds. Writing the value first and then
              # emitting both signals meant a conventional toggle handler
              # (`iter[col] = !iter[col]`) inverted the value the shim had
              # just set, putting the checkbox back where it started, and a
              # text handler could not refuse an edit without undoing one
              # (review 2026-09-17, R7). A text renderer's `edited` carries
              # the new text; a toggle's `toggled` carries the path alone.
              if column && iter && (renderer = column.renderer)
                if renderer.is_a?(CellRendererToggle)
                  renderer.emit(:toggled, iter.path.to_s)
                else
                  renderer.emit(:edited, iter.path.to_s, value)
                end
              end
            end
          end

          # Applies a contract event, then emits `row_activated`, `row_expanded`/`row_collapsed` or the mapped signals.
          #
          # @param event [Symbol] the contract event that arrived
          # @param context [Object] the runtime event context (payload reachable through `payload_value`)
          # @return [void]
          def receive_event(event, context)
            apply_event(event, context)
            if event == :row_activate
              row_key = payload_value(context, :row).to_s
              iter = find_row_copy(row_key)
              emit(:row_activated, iter&.path, @columns.first) if iter
            elsif event == :row_toggle
              iter = find_row_copy(payload_value(context, :row).to_s)
              emit(payload_value(context, :expanded) ? :row_expanded : :row_collapsed, iter, iter.path) if iter
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
