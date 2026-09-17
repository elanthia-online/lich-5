# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # ------------------------------------------------------------------
        # Slice five's long tail: the containers and one display widget the
        # corpus reaches for a handful of times each. Until now every one of
        # them fell through Gtk.const_missing into an empty box.
        # ------------------------------------------------------------------

        # Stand-in for Gtk::ProgressBar, rendered as the contract's `progress` node.
        #
        # spellson draws one per active spell. The text is only rendered when +show_text+ is on,
        # as in GTK; +pulse+ maps to the contract's `indeterminate` flag.
        class ProgressBar < Widget
          # A bar at fraction 0.0 with no text.
          #
          # @param _args [Array<Object>] ignored; GTK's constructor takes none either
          # @param _options [Hash{Symbol => Object}] ignored
          def initialize(*_args, **_options)
            super()
            @fraction = 0.0
            @text = nil
            @show_text = false
            @pulsing = false
          end

          # @return [Float] the current fraction, 0.0 to 1.0
          attr_reader :fraction
          # @return [String, nil] the bar's text, or nil when none was set
          attr_reader :text

          # Sets the fraction, clamped to 0.0..1.0, and ends any pulse. Also +set_fraction+.
          #
          # @param value [Numeric, #to_f] the new fraction
          # @return [void]
          def fraction=(value)
            @fraction = value.to_f.clamp(0.0, 1.0)
            @pulsing = false
            changed!
          end
          def_setter :set_fraction, :fraction=

          # Sets the bar's text. Also +set_text+.
          #
          # @param value [String, nil] the text; nil clears it
          # @return [void]
          def text=(value)
            @text = value&.to_s
            changed!
          end
          def_setter :set_text, :text=

          # Sets whether the text is rendered. Also +set_show_text+.
          #
          # @param value [Boolean] truthy to show the text
          # @return [void]
          def show_text=(value)
            @show_text = value ? true : false
            changed!
          end
          def_setter :set_show_text, :show_text=

          # Switches the bar to indeterminate.
          #
          # GTK's pulse bounces a block with no known fraction; the contract
          # spells that `indeterminate`. The first fraction= ends it.
          #
          # @return [self]
          def pulse
            @pulsing = true
            changed!
            self
          end

          # @return [Symbol] :progress
          def node_type
            :progress
          end

          # @return [Hash{Symbol => Object}] value, plus label when shown and indeterminate when pulsing
          def node_props
            props = { value: @fraction }
            # `(@show_text || !@text.empty?)` was tautological -- the guard
            # before it already required a non-empty text -- so show_text
            # decided nothing and a bar whose text a script had switched off
            # still showed it. In GTK it is what makes the text render at all.
            # creaturebar's calibrator drives this from a "Text" checkbox.
            props[:label] = @text if @show_text && @text && !@text.empty?
            props[:indeterminate] = true if @pulsing
            props
          end
        end

        # Stand-in for Gtk::ListBox, rendered as a `stack` of rows.
        #
        # Gtk::ListBox -> a `stack` of rows; each Gtk::ListBoxRow -> a `group`
        # with a blank legend, so rows stay visibly delimited. There is no
        # list type in the contract, and the plan proposes one only if a
        # script needs selection -- creaturebar's does not act on it.
        #
        # Selection is therefore local state only: the browser never shows it, and every selection
        # call is logged as unsupported.
        class ListBox < Container
          # An empty list in single-selection mode.
          #
          # @param _args [Array<Object>] ignored
          def initialize(*_args)
            super()
            @selection_mode = :single
            @selected = nil
          end

          # Records the selection mode; it changes nothing rendered. Also +set_selection_mode+.
          #
          # @param mode [Symbol, Object] the GTK selection mode
          # @return [void]
          def selection_mode=(mode)
            @selection_mode = mode
          end
          def_setter :set_selection_mode, :selection_mode=

          # Adds a row at a position.
          #
          # @param row [Gtk::Widget] the row to add, usually a {ListBoxRow}
          # @param position [Integer] the index to insert at; negative appends
          # @return [self]
          def insert(row, position = -1)
            add(row)
            reorder(row, position) unless position.negative?
            self
          end

          # Remembers a row as selected; nothing is shown in the browser.
          #
          # Selection is kept so a script can read back what it set, and
          # said to be unsupported because that is all it is: the contract
          # has no list type, so the browser never shows or changes it.
          #
          # @param row [Gtk::Widget, nil] the row to remember
          # @return [self]
          def select_row(row)
            selection_not_shown('select_row')
            @selected = row
            self
          end

          # The row last passed to {#select_row}; logged as unsupported since the viewer cannot change it.
          #
          # @return [Gtk::Widget, nil] the remembered row, or nil
          def selected_row
            selection_not_shown('selected_row')
            @selected
          end

          # Forgets the remembered selection.
          #
          # @return [self]
          def unselect_all
            selection_not_shown('unselect_all')
            @selected = nil
            self
          end

          # The row at an index. Also +row_at_index+.
          #
          # @param index [Integer, #to_i] the row's position
          # @return [Gtk::Widget, nil] the row, or nil when out of range
          def get_row_at_index(index)
            @children[index.to_i]
          end
          alias row_at_index get_row_at_index

          # @return [Symbol] :stack
          def node_type
            :stack
          end

          # @return [Hash{Symbol => Object}] a zero gap between rows
          def node_props
            { gap: 0 }
          end

          private

          def selection_not_shown(method)
            Gtk.log_unsupported(short_class_name, method, note: 'selection is kept locally and not shown in the browser')
          end

          def reorder(row, position)
            @children.delete(row)
            @children.insert(position.to_i.clamp(0, @children.length), row)
            changed!
          end
        end

        # Stand-in for Gtk::ListBoxRow, rendered as a `group` with a blank legend so rows stay
        # visibly delimited inside a {ListBox}.
        #
        # +activatable+ and +selectable+ are recorded but change nothing rendered.
        class ListBoxRow < Container
          # An empty, activatable, selectable row.
          #
          # @param _args [Array<Object>] ignored
          def initialize(*_args)
            super()
            @activatable = true
            @selectable = true
          end

          # Records whether the row is activatable. Also +set_activatable+.
          #
          # @param value [Boolean] truthy for activatable
          # @return [void]
          def activatable=(value)
            @activatable = value ? true : false
          end
          def_setter :set_activatable, :activatable=

          # Records whether the row is selectable. Also +set_selectable+.
          #
          # @param value [Boolean] truthy for selectable
          # @return [void]
          def selectable=(value)
            @selectable = value ? true : false
          end
          def_setter :set_selectable, :selectable=

          # The row's position among its parent's children. Also +get_index+.
          #
          # Tested on the class: a shim widget answers respond_to? for every
          # name, so respond_to?(:children) guarded nothing.
          #
          # @return [Integer] the index, or -1 when the row has no Container parent
          def index
            parent.is_a?(Container) ? parent.children.index(self).to_i : -1
          end
          alias get_index index

          # @return [Symbol] :group
          def node_type
            :group
          end

          # @return [Hash{Symbol => Object}] a single-space label, so the group draws no legend text
          def node_props
            { label: ' ' }
          end
        end

        # Stand-in for Gtk::Paned, rendered as the contract's `split` node.
        #
        # Gtk::Paned -> `split`. Two named slots, first and second, along an
        # orientation; the divider's position is the viewer's to drag.
        #
        # GTK positions the divider in pixels and the contract in percent.
        # With no real size to divide by, a script's pixel position is taken
        # against the window's default extent on that axis, which is what the
        # script sized the window for.
        #
        # Unlike GTK, adding to an occupied pane replaces the widget there (and logs it) instead
        # of being refused; the +resize+ and +shrink+ arguments of +pack1+/+pack2+ are ignored.
        class Paned < Container
          # The contract's slot names, in the order children are rendered.
          SLOTS = %w[first second].freeze

          # An empty paned along an orientation.
          #
          # @param orientation [Symbol, String] anything starting with "v" is vertical; else horizontal
          # @param _options [Hash{Symbol => Object}] ignored
          def initialize(orientation = :horizontal, **_options)
            super()
            @orientation = orientation.to_s.start_with?('v') ? :vertical : :horizontal
            @position = nil
            @slotted = {}.compare_by_identity
          end

          # @return [Symbol] :horizontal or :vertical
          attr_reader :orientation

          # Places a child in the first pane.
          #
          # @param child [Gtk::Widget] the widget to place
          # @return [self]
          def add1(child)
            place(child, 'first')
          end

          # Places a child in the second pane.
          #
          # @param child [Gtk::Widget] the widget to place
          # @return [self]
          def add2(child)
            place(child, 'second')
          end

          # Same as {#add1}; the packing flags are ignored.
          #
          # @param child [Gtk::Widget] the widget to place
          # @param _resize [Boolean] ignored
          # @param _shrink [Boolean] ignored
          # @return [self]
          def pack1(child, _resize = false, _shrink = true)
            add1(child)
          end

          # Same as {#add2}; the packing flags are ignored.
          #
          # @param child [Gtk::Widget] the widget to place
          # @param _resize [Boolean] ignored
          # @param _shrink [Boolean] ignored
          # @return [self]
          def pack2(child, _resize = true, _shrink = true)
            add2(child)
          end

          # A bare add fills the first free slot, as GTK does.
          #
          # @param child [Gtk::Widget] the widget to place
          # @return [self]
          def add(child)
            place(child, @slotted.value?('first') ? 'second' : 'first')
          end

          # @return [Gtk::Widget, nil] the widget in the first pane, or nil
          def child1
            @slotted.key('first')
          end

          # @return [Gtk::Widget, nil] the widget in the second pane, or nil
          def child2
            @slotted.key('second')
          end

          # Removes a child and frees its slot.
          #
          # @param child [Gtk::Widget] the widget to remove
          # @return [self]
          def remove(child)
            @slotted.delete(child)
            super
          end

          # Sets the divider position in pixels. Also +set_position+.
          #
          # The divider is viewer-scoped: the browser keeps its own copy, so
          # the value is pushed to every viewer as well as re-rendered. With
          # no axis to convert against yet there is nothing to push, only a
          # re-render to schedule.
          #
          # @param pixels [Integer, #to_i] the position along the orientation axis
          # @return [void]
          def position=(pixels)
            @position = pixels.to_i
            percent = position_percent
            percent ? viewer_push(:position, percent) : changed!
          end
          def_setter :set_position, :position=

          # The divider position in pixels, as last set or as converted back from a viewer's drag.
          #
          # @return [Integer] the position, 0 when never set
          def position
            @position || 0
          end

          # @return [Symbol] :split
          def node_type
            :split
          end

          # @return [Hash{Symbol => Object}] the orientation, plus position (percent) when known
          def node_props
            props = { orientation: @orientation.to_s }
            percent = position_percent
            props[:position] = percent if percent
            props
          end

          # The children in slot order, with a filler holding the first pane open when only the
          # second is occupied.
          #
          # Ordered first, second, so slots are assigned in contract order.
          #
          # Sorting alone is not enough: the adapter assigns named slots by
          # INDEX, so a paned holding only add2's child gave that child the
          # `first` slot and the browser's split renderer put it on the wrong
          # side. Hiding or removing the first pane did the same. An absent
          # first pane keeps its place with a blank stand-in, the way Grid
          # holds an empty cell open.
          #
          # @return [Array<Gtk::Widget>] the visible children to render, in slot order
          def render_children
            ordered = super.sort_by { |child| SLOTS.index(@slotted[child]) || SLOTS.length }
            return ordered unless ordered.length == 1 && @slotted[ordered.first] == 'second'

            [first_pane_filler, ordered.first]
          end

          # Maps GTK's +notify::position+ signal to the contract's `move` event.
          #
          # @param signal [Symbol] a normalised GTK signal name
          # @return [Symbol, nil] :move for :notify_position, else nil
          def event_for(signal)
            :move if signal == :notify_position
          end

          # The divider is always tracked, so {#position} reads back a viewer's drag.
          #
          # @return [Array<Symbol>] [:move]
          def always_bound_events
            [:move]
          end

          protected

          # Converts a viewer's `move` (percent) back to pixels against the window's default extent.
          #
          # @param event [Symbol] the contract event
          # @param context [Object] the event context carrying the payload
          # @return [void]
          def apply_event(event, context)
            return unless event == :move

            percent = payload_value(context, :position)
            return if percent.nil?

            extent = axis_extent
            @position = extent ? (extent * percent.to_f / 100).round : @position
          end

          private

          # Holds the `first` slot open so the real child keeps `second`.
          # Memoised: a new widget per render would churn adapter handles.
          def first_pane_filler
            @first_pane_filler ||= Gtk::Filler.new.tap { |filler| filler.attach_to(self) }
          end

          # Declared so materialize! does not treat the stand-in as a child
          # that has gone away and detach it again every commit.
          def filler_children
            @first_pane_filler ? [@first_pane_filler] : []
          end

          def place(child, slot)
            existing = @slotted.key(slot)
            # Already in that slot: nothing to evict and nothing to add.
            # Falling through to Container#add listed the child twice.
            return self if existing.equal?(child)

            if existing
              # GTK refuses a second child in an occupied pane; the shim
              # evicts the first instead, which is survivable but silent --
              # the script's earlier widget simply vanishes.
              Gtk.log_unsupported(
                short_class_name, "add to an occupied #{slot} pane",
                note: 'the widget already there was replaced'
              )
              super_remove(existing)
            end
            @slotted[child] = slot
            Container.instance_method(:add).bind_call(self, child)
            self
          end

          def super_remove(child)
            @slotted.delete(child)
            Container.instance_method(:remove).bind_call(self, child)
          end

          def axis_extent
            window = window_root
            return nil unless window

            @orientation == :horizontal ? window.default_width : window.default_height
          end

          def position_percent
            return nil unless @position

            extent = axis_extent
            return nil unless extent&.positive?

            (@position * 100.0 / extent).round.clamp(0, 100)
          end
        end

        # Stand-in for the deprecated Gtk::HPaned: a horizontal {Paned}.
        class HPaned < Paned
          # @param options [Hash{Symbol => Object}] ignored
          def initialize(**options)
            super(:horizontal, **options)
          end
        end

        # Stand-in for the deprecated Gtk::VPaned: a vertical {Paned}.
        class VPaned < Paned
          # @param options [Hash{Symbol => Object}] ignored
          def initialize(**options)
            super(:vertical, **options)
          end
        end

        # Stand-in for Gtk::Overlay, rendered as the contract's `overlay` node.
        #
        # Gtk::Overlay -> `overlay`. The first child is the base, laid out in
        # flow; each add_overlay child is stacked on top of it in order. The
        # contract's per-child `z` is not used: document order is stacking
        # order, which is exactly what GTK does when no z is set.
        class Overlay < Container
          # Stacks a child on top of the base and any earlier overlays.
          #
          # @param child [Gtk::Widget] the widget to overlay
          # @return [self]
          def add_overlay(child)
            add(child)
          end

          # Moves an overlay child to a new stacking index.
          #
          # @param child [Gtk::Widget] a child already added
          # @param index [Integer, #to_i] the new position, clamped to the children's range
          # @return [self]
          def reorder_overlay(child, index)
            return self unless @children.delete(child)

            @children.insert(index.to_i.clamp(0, @children.length), child)
            changed!
            self
          end

          # Accepted and ignored: the contract has no pass-through flag.
          #
          # @param _args [Array<Object>] ignored
          # @return [self]
          def set_overlay_pass_through(*_args)
            self
          end

          # @return [Symbol] :overlay
          def node_type
            :overlay
          end

          # @return [Hash{Symbol => Object}] empty; the overlay carries no props of its own
          def node_props
            {}
          end
        end
      end
    end
  end
end
