# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        module PositionType
          TOP = :top
          BOTTOM = :bottom
          LEFT = :left
          RIGHT = :right
        end

        # Arbitrary same-owner widgets in a button-anchored browser panel.
        # Visibility is local to the viewer; this never creates an OS window.
        class Popover < Widget
          attr_reader :relative_to, :position

          # Creates an unparented panel with an optional same-owner MenuButton anchor.
          # @param relative_to [MenuButton, nil] only the anchored button may claim this panel
          # @raise [UnsupportedOperation] for a foreign, destroyed or unsupported anchor
          def initialize(relative_to = nil)
            super()
            session.refuse(self, :new) unless relative_to.nil? ||
                                              (relative_to.is_a?(MenuButton) && relative_to.session.equal?(session) && !relative_to.destroyed?)
            @relative_to = relative_to
            @position = :bottom
          end

          # Retains panel placement and updates an owning menu button when attached.
          # @param value [Symbol] :top, :bottom, :left or :right
          # @return [Popover] self
          # @raise [UnsupportedOperation] for invalid placement, teardown or foreign ownership
          def set_position(value)
            session.style_operation(self, :set_position) do
              session.refuse(self, :set_position) if destroyed? || !%i[top bottom left right].include?(value)
              parent.send(:write, :menu_position, value) if parent.is_a?(MenuButton)
              @position = value
            end
            self
          end
          alias position= set_position

          # Adds one same-owner content widget through the shared parenting checks.
          # @return [Popover] self
          # @raise [UnsupportedOperation] when adding a second distinct child
          def add(child)
            session.refuse(self, :add) unless children.empty? || children.include?(child)
            super
          end

          protected

          # @return [Symbol] inline contents rather than another native window
          def component_type = :stack
          # @return [Hash] zero-gap contents inside the owning button's panel
          def component_props = super.merge(gap: 0)
        end

        class MenuButton < Widget
          attr_reader :popover

          # Creates a palette trigger; content is supplied before materialization.
          def initialize
            super
            @props[:label] = 'Palette'
          end

          # Keep the icon in the normal ownership tree, before the panel contents.
          # @param image [Image] live, unparented icon from this script session
          # @return [MenuButton] self
          # @raise [UnsupportedOperation] for replacement, late attachment or foreign ownership
          def set_image(image)
            session.style_operation(self, :set_image) do
              session.refuse(self, :set_image) if destroyed? || @handle || !image.is_a?(Image) ||
                                                  !image.session.equal?(session) || image.destroyed? || image.parent || @image
              insert_child(image, 0)
              @image = image
            end
            self
          end

          # Accepts the supported always-visible icon policy without changing ownership.
          # @param value [true] other visibility policies are unsupported
          # @return [MenuButton] self
          def set_always_show_image(value)
            session.refuse(self, :set_always_show_image) unless value == true
            self
          end

          # Claims one panel before publication, preserving its requested placement.
          # @param value [Popover] live unparented panel with a matching or omitted anchor
          # @return [MenuButton] self
          # @raise [UnsupportedOperation] for replacement, late attachment or foreign ownership
          def set_popover(value)
            session.style_operation(self, :set_popover) do
              valid = value.is_a?(Popover) && value.session.equal?(session) && !value.destroyed? &&
                      !value.parent && (value.relative_to.nil? || value.relative_to.equal?(self))
              session.refuse(self, :set_popover) if destroyed? || @handle || @popover || !valid
              add(value)
              @popover = value
              write(:menu_position, value.position)
            end
            self
          end
          alias popover= set_popover

          protected

          # @return [Symbol] shared menu-capable renderer container
          def component_type = :group
          # @return [Hash] popover presentation and whether the first child is an icon
          def component_props = super.merge(menu: :popover, menu_icon: !!@image)
        end

        # Bounded viewport coordinates from one authenticated pointer callback.
        PointerEvent = Data.define(:x, :y, :button, :time, :state, :click_count, :released) do
          def initialize(x:, y:, button:, time:, state:, click_count: 1, released: false)
            super
          end

          def event_type = released ? :button_release : click_count == 2 ? :button2_press : :button_press
        end

        # Literal menu labels. Mnemonic-bearing labels require keyboard support
        # beyond this adapter; they are refused rather than silently stripped.
        module MenuLabel
          # Label replacements preserve the constructor's explicit mnemonic policy.
          # @return [Widget] self
          def set_label(value) = write(:label, menu_label(value, @use_underline))
          alias label= set_label

          private

          # Validates literal labels and retains the constructor's mnemonic policy.
          # @return [String] unchanged label, never stripped or interpreted as markup
          # @raise [UnsupportedOperation] for invalid input or requested mnemonic syntax
          def menu_label(label, underline)
            session.refuse(self, :label) unless label.is_a?(String) && [true, false].include?(underline)
            session.refuse(self, :mnemonic) if underline && label.include?('_')
            @use_underline = underline
            label
          end
        end

        class MenuItem < Widget
          include MenuLabel
          attr_reader :submenu

          # Creates a literal action or, before publication, a submenu trigger.
          # @param text [String] legacy positional label
          # @param use_underline [Boolean] mnemonic flag; labels containing '_' refuse when true
          # @param label [String] keyword label overriding text
          def initialize(text = '', use_underline = false, label: text)
            super()
            @props[:label] = menu_label(label, use_underline)
          end

          # @return [String] literal action or submenu label
          def label = read(:label)

          # Replaces submenu contents while retaining the published trigger's identity.
          # @param menu [Menu] unparented menu from the same Script session
          # @return [MenuItem] self
          # @raise [UnsupportedOperation] for an owned/foreign menu or a published terminal action
          def set_submenu(menu)
            session.style_operation(self, :set_submenu) do
              valid = !destroyed? && menu.is_a?(Menu) && menu.session.equal?(session) && !menu.destroyed? &&
                      !menu.parent && (!menu.instance_variable_get(:@handle) || menu.instance_variable_get(:@embedded)) && (!@handle || @submenu_trigger)
              session.refuse(self, :set_submenu) unless valid
              previous = @submenu
              menu.send(:embed!)
              if @handle
                session.port.replace_child(@handle, previous&.materialize, menu.materialize)
              end
              if previous
                @children.delete(previous)
                previous.send(:parent=, nil)
              end
              @children << menu
              menu.send(:parent=, self)
              @submenu = menu
              @submenu_trigger = true
              session.refresh_label_styles
            end
            self
          end
          alias submenu= set_submenu

          # Executes explicit script activation through the ordered local handlers.
          # @return [MenuItem] self
          # @raise [UnsupportedOperation] for submenu triggers, which open in the browser
          def activate
            session.refuse(self, :activate) if @submenu_trigger
            emit_handlers(:activate)
            self
          end

          protected

          # Destruction of a submenu retires its owner reference without changing
          # the already rendered trigger's component type.
          def forget_child(child)
            @submenu = nil if @submenu.equal?(child)
            super
          end

          # @return [Symbol] submenu container or terminal action
          def component_type = @submenu_trigger ? :group : :button
          # @return [Hash] shared submenu presentation only when this item owns a menu
          def component_props = @submenu_trigger ? super.merge(menu: :submenu) : super
          # @return [Hash] submenu opening has no script activation callback
          def signal_map = @submenu_trigger ? {} : { 'activate' => :activate }
        end

        class SeparatorMenuItem < Widget
          protected

          # @return [Symbol] noninteractive separator in the shared renderer
          def component_type = :divider
        end

        # Check and radio menu items reuse existing viewer-local input state and
        # terminal activation, including complete form submission before callbacks.
        class CheckMenuItem < ToggleButton
          include MenuLabel

          # Creates an initially unchecked menu choice with the literal-label policy.
          # @param text [String] legacy positional label
          # @param use_underline [Boolean] whether mnemonic syntax was requested
          # @param label [String] keyword label overriding text
          def initialize(text = '', use_underline = false, label: text)
            super(label)
            @props[:label] = menu_label(label, use_underline)
          end

          # Toggles first, delivering changed notifications before activation handlers.
          # @return [CheckMenuItem] self
          def activate
            set_active(!active?)
            emit_handlers(:activate)
            self
          end

          protected

          # @return [Hash] existing toggle state with menu presentation
          def component_props = super.merge(appearance: :menu)
          # @return [Hash] state notification and terminal activation are distinct events
          def signal_map = { 'toggled' => :change, 'activate' => :activate }
        end

        class RadioMenuItem < RadioButton
          include MenuLabel

          # Accepts an initial label or an existing group member and label.
          # @param member [RadioButton, String, nil] same-session group member or first label
          # @param label [String, Boolean, nil] label, or mnemonic flag in label-first form
          # @param use_underline [Boolean] whether mnemonic syntax was requested
          def initialize(member = nil, label = nil, use_underline = false)
            if member.is_a?(String)
              use_underline = label unless label.nil?
              label = member
              member = nil
            end
            super(member: member, label: label || '')
            @props[:label] = menu_label(@props[:label], use_underline)
          end

          # Selects exclusively before activation; an already selected item still activates.
          # @return [RadioMenuItem] self
          def activate
            set_active(true)
            emit_handlers(:activate)
            self
          end

          protected

          # @return [Hash] existing radio-group identity and state with menu presentation
          def component_props = super.merge(appearance: :menu)
          # @return [Hash] group transitions precede the terminal activation callback
          def signal_map = { 'toggled' => :change, 'activate' => :activate }
        end

        # Immutable key notification with the same script-readable masks as scroll events.
        KeyEvent = Data.define(:keyval, :state) do
          # Retains the key code and normalizes modifiers without nesting existing wrappers.
          # @param keyval [Integer] validated shared key code
          # @param state [Integer, ModifierState] modifier bitmask or existing wrapper
          def initialize(keyval:, state:)
            super(keyval: keyval, state: state.is_a?(ModifierState) ? state : ModifierState.new(state))
          end
        end

        # Script-readable modifiers retain ordinary integer mask comparisons.
        class ModifierState < Numeric
          def initialize(value)
            super()
            @value = value
          end

          def control_mask? = (@value & 4) != 0
          def shift_mask? = (@value & 1) != 0
          def ==(other) = @value == other
          def to_i = @value
          def &(other) = @value & other
        end

        class ScrollEvent
          attr_reader :state, :x, :y
          attr_accessor :direction

          def initialize(payload)
            @state = ModifierState.new(payload[:state])
            @dx, @dy = payload.values_at(:delta_x, :delta_y)
            @x, @y = payload.values_at(:x, :y)
            @direction = if @dx.abs > @dy.abs
                           @dx.negative? ? :left : :right
                         else
                           @dy.negative? ? :up : :down
                         end
            @original_direction = @direction
          end

          def put
            Gtk.session.refuse(self, :put) unless %i[up down left right].include?(@direction)
            @replayed = true
          end

          def replayed? = @replayed == true

          def deltas
            return [@dx, @dy] if @direction == @original_direction

            magnitude = [@dx.abs, @dy.abs].max
            { up: [0, -magnitude], down: [0, magnitude], left: [-magnitude, 0], right: [magnitude, 0] }.fetch(@direction)
          end
        end

        # Popups are page children with viewer-scoped open state, never OS windows.
        # Submenus remain in the same owner tree for destruction and input commits.
        class Menu < Widget
          # Creates a closed popup; assigning it as a submenu switches to embedded content.
          def initialize
            super
            @embedded = false
            @props[:open] = false
          end

          # Inserts only supported menu entries and preserves caller order.
          # @param item [MenuItem, SeparatorMenuItem, CheckMenuItem, RadioMenuItem] entry
          # @return [Menu] self
          def add(item)
            session.refuse(self, :add) unless [MenuItem, SeparatorMenuItem, CheckMenuItem, RadioMenuItem].any? { |type| item.is_a?(type) }
            super
          end
          alias append add

          # @return [Menu] self after inserting the entry before all existing entries
          def prepend(item) = insert(item, 0)

          # Inserts or reorders a supported entry at a bounded zero-based position.
          # @param item [Widget] supported same-session menu entry
          # @param position [Integer] zero through the current child count
          # @return [Menu] self
          def insert(item, position)
            session.refuse(self, :insert) unless position.is_a?(Integer) && position.between?(0, children.length)
            add(item)
            reorder_child(item, position)
          end

          # Opens only from the matching pointer callback, in that viewer's window.
          # @param parent_shell [nil] detached popup only
          # @param parent_item [nil] detached popup only
          # @param button [Integer] active pointer button
          # @param time [Integer] active pointer time
          # @return [Menu] self
          # @raise [UnsupportedOperation] outside the matching pointer callback
          def popup(parent_shell, parent_item, button, time)
            context = session.pointer_context
            valid = context && parent_shell.nil? && parent_item.nil? && context.last.button == button && context.last.time == time
            session.refuse(self, :popup) unless valid
            popup_at_pointer(context.last)
          end

          # Attaches a popup to the originating window and opens it for one viewer.
          # @param event [PointerEvent, nil] exact event from the callback, or its implicit event
          # @return [Menu] self
          # @raise [UnsupportedOperation] for embedded, foreign-window or nonpointer use
          def popup_at_pointer(event = nil)
            context = session.pointer_context
            session.refuse(self, :popup_at_pointer) unless context && !@embedded && (event.nil? || context.last.equal?(event))
            widget, pointer = context
            root = widget.toplevel
            session.refuse(self, :popup_at_pointer) unless root.is_a?(Window) && (!parent || parent.equal?(root))
            root.add(self) unless parent
            root.children.grep(Menu).each { |menu| menu.popdown unless menu.equal?(self) }
            was_visible = visible?
            show_all
            emit_handlers(:show) if was_visible && !destroyed?
            write(:popup_position, [pointer.x, pointer.y])
            write(:open, true)
          end

          # @return [Menu] self after closing only the active viewer's popup
          def popdown = write(:open, false)
          # @return [Boolean] popup state for the current viewer or retained default
          def open? = read(:open)

          protected

          # Selects inline submenu contents before materialization fixes the core type.
          # @raise [UnsupportedOperation] if the menu has already been materialized
          def embed!
            session.refuse(self, :submenu) if @handle && !@embedded
            @embedded = true
          end

          # @return [Symbol] inline contents or a viewer-scoped popup container
          def component_type = @embedded ? :stack : :group
          # @return [Symbol, nil] only standalone popups own open state
          def input_property = @embedded ? nil : :open

          # Removes popup-only fields from submenu contents before core validation.
          # @return [Hash] presentation properties for the chosen menu form
          def component_props
            @embedded ? super.except(:open, :popup_position).merge(gap: 0) : super.merge(menu: :context)
          end

          # Maps legacy popup dismissal names to the single core dismissal event.
          # @return [Hash] embedded contents do not own dismissal signals
          def signal_map
            @embedded ? {} : { 'deactivate' => :dismiss, 'selection-done' => :dismiss, 'hide' => :dismiss }
          end
        end
      end

      module Gdk
        module EventMask
          BUTTON_PRESS_MASK = 1 << 8
          BUTTON_RELEASE_MASK = 1 << 9
          SCROLL_MASK = 1 << 21
          ENTER_NOTIFY_MASK = 1 << 12
          LEAVE_NOTIFY_MASK = 1 << 13
        end
        BUTTON_PRESS_MASK = EventMask::BUTTON_PRESS_MASK
        BUTTON_RELEASE_MASK = EventMask::BUTTON_RELEASE_MASK
        BUTTON_PRIMARY = 1
        BUTTON_MIDDLE = 2
        BUTTON_SECONDARY = 3
        module EventType
          BUTTON_PRESS = :button_press
          BUTTON2_PRESS = :button2_press
          BUTTON_RELEASE = :button_release
        end

        module ScrollDirection
          UP = :up
          DOWN = :down
          LEFT = :left
          RIGHT = :right
        end
        EventScroll = ScrollDirection
        module Window
          SHIFT_MASK = 1
          CONTROL_MASK = 4
        end

        module Keyval
          KEY_Escape = 0xff1b
          ('0'..'9').chain('a'..'z', 'A'..'Z').each { |key| const_set("KEY_#{key}", key.ord) }
        end

        module WindowState
          ICONIFIED = 1 << 1
        end

        # Legacy constant spelling; this does not expose native GDK event objects.
        module Event
          BUTTON_PRESS_MASK = EventMask::BUTTON_PRESS_MASK
          BUTTON_RELEASE_MASK = EventMask::BUTTON_RELEASE_MASK
          BUTTON2_PRESS = :button2_press
          Type = EventType
        end
      end
    end
  end
end
