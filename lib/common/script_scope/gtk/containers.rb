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

        # Gtk::ProgressBar -> `progress`. spellson draws one per active spell.
        class ProgressBar < Widget
          def initialize(*_args, **_options)
            super()
            @fraction = 0.0
            @text = nil
            @show_text = false
            @pulsing = false
          end

          attr_reader :fraction, :text

          def fraction=(value)
            @fraction = value.to_f.clamp(0.0, 1.0)
            @pulsing = false
            changed!
          end
          alias set_fraction fraction=

          def text=(value)
            @text = value&.to_s
            changed!
          end
          alias set_text text=

          def show_text=(value)
            @show_text = value ? true : false
            changed!
          end
          alias set_show_text show_text=

          # GTK's pulse bounces a block with no known fraction; the contract
          # spells that `indeterminate`. The first fraction= ends it.
          def pulse
            @pulsing = true
            changed!
            self
          end

          def node_type
            :progress
          end

          def node_props
            props = { value: @fraction }
            props[:label] = @text if @text && !@text.empty? && (@show_text || !@text.empty?)
            props[:indeterminate] = true if @pulsing
            props
          end
        end

        # Gtk::ListBox -> a `stack` of rows; each Gtk::ListBoxRow -> a `group`
        # with a blank legend, so rows stay visibly delimited. There is no
        # list type in the contract, and the plan proposes one only if a
        # script needs selection -- creaturebar's does not act on it.
        class ListBox < Container
          def initialize(*_args)
            super()
            @selection_mode = :single
            @selected = nil
          end

          def selection_mode=(mode)
            @selection_mode = mode
          end
          alias set_selection_mode selection_mode=

          def insert(row, position = -1)
            add(row)
            reorder(row, position) unless position.negative?
            self
          end

          def select_row(row)
            @selected = row
            self
          end

          def selected_row
            @selected
          end

          def unselect_all
            @selected = nil
            self
          end

          def get_row_at_index(index)
            @children[index.to_i]
          end
          alias row_at_index get_row_at_index

          def node_type
            :stack
          end

          def node_props
            { gap: 0 }
          end

          private

          def reorder(row, position)
            @children.delete(row)
            @children.insert(position.to_i.clamp(0, @children.length), row)
            changed!
          end
        end

        class ListBoxRow < Container
          def initialize(*_args)
            super()
            @activatable = true
            @selectable = true
          end

          def activatable=(value)
            @activatable = value ? true : false
          end
          alias set_activatable activatable=

          def selectable=(value)
            @selectable = value ? true : false
          end
          alias set_selectable selectable=

          def index
            parent.respond_to?(:children) ? parent.children.index(self).to_i : -1
          end
          alias get_index index

          def node_type
            :group
          end

          def node_props
            { label: ' ' }
          end
        end

        # Gtk::Paned -> `split`. Two named slots, first and second, along an
        # orientation; the divider's position is the viewer's to drag.
        #
        # GTK positions the divider in pixels and the contract in percent.
        # With no real size to divide by, a script's pixel position is taken
        # against the window's default extent on that axis, which is what the
        # script sized the window for.
        class Paned < Container
          SLOTS = %w[first second].freeze

          def initialize(orientation = :horizontal, **_options)
            super()
            @orientation = orientation.to_s.start_with?('v') ? :vertical : :horizontal
            @position = nil
            @slotted = {}.compare_by_identity
          end

          attr_reader :orientation

          def add1(child)
            place(child, 'first')
          end

          def add2(child)
            place(child, 'second')
          end

          def pack1(child, _resize = false, _shrink = true)
            add1(child)
          end

          def pack2(child, _resize = true, _shrink = true)
            add2(child)
          end

          # A bare add fills the first free slot, as GTK does.
          def add(child)
            place(child, @slotted.value?('first') ? 'second' : 'first')
          end

          def child1
            @slotted.key('first')
          end

          def child2
            @slotted.key('second')
          end

          def remove(child)
            @slotted.delete(child)
            super
          end

          def position=(pixels)
            @position = pixels.to_i
            changed!
            @session.viewer_write(window_root, self, :position, position_percent) if @handle && position_percent
          end
          alias set_position position=

          def position
            @position || 0
          end

          def node_type
            :split
          end

          def node_props
            props = { orientation: @orientation.to_s }
            percent = position_percent
            props[:position] = percent if percent
            props
          end

          # Ordered first, second, so slots are assigned in contract order.
          def render_children
            super.sort_by { |child| SLOTS.index(@slotted[child]) || SLOTS.length }
          end

          def event_for(signal)
            :move if signal == :notify_position
          end

          def always_bound_events
            [:move]
          end

          protected

          def apply_event(event, context)
            return unless event == :move

            percent = payload_value(context, :position)
            return if percent.nil?

            extent = axis_extent
            @position = extent ? (extent * percent.to_f / 100).round : @position
          end

          private

          def place(child, slot)
            existing = @slotted.key(slot)
            super_remove(existing) if existing && !existing.equal?(child)
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

        class HPaned < Paned
          def initialize(**options)
            super(:horizontal, **options)
          end
        end

        class VPaned < Paned
          def initialize(**options)
            super(:vertical, **options)
          end
        end

        # Gtk::Overlay -> `overlay`. The first child is the base, laid out in
        # flow; each add_overlay child is stacked on top of it in order. The
        # contract's per-child `z` is not used: document order is stacking
        # order, which is exactly what GTK does when no z is set.
        class Overlay < Container
          def add_overlay(child)
            add(child)
          end

          def reorder_overlay(child, index)
            return self unless @children.delete(child)

            @children.insert(index.to_i.clamp(0, @children.length), child)
            changed!
            self
          end

          def set_overlay_pass_through(*_args)
            self
          end

          def node_type
            :overlay
          end

          def node_props
            {}
          end
        end
      end
    end
  end
end
