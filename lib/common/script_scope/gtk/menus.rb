# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # ------------------------------------------------------------------
        # Menus (contract 2.7): Gtk::Menu popups and menu bars, and the item
        # classes scripts build them from. A popup menu is not in any window
        # until it is shown; `popup` attaches it to the window that received
        # the last pointer event, which is where GTK would have shown it.
        # ------------------------------------------------------------------
        class MenuItem < Container
          def initialize(label = nil, _use_underline = true, **options)
            super()
            label = options[:label] if options.key?(:label)
            @label = mnemonic_free(label)
            @submenu = nil
          end

          attr_reader :submenu

          def label
            @label
          end

          def label=(value)
            @label = mnemonic_free(value)
            changed!
          end
          def_setter :set_label, :label=

          def submenu=(menu)
            remove(@submenu) if @submenu
            @submenu = menu
            add(menu) if menu
            changed!
          end
          def_setter :set_submenu, :submenu=

          # GTK lets a script put a Label (or anything) inside an item; the
          # contract item carries only a label, so that is what is kept.
          def add(child)
            case child
            when Menu then super
            when Label then self.label = child.text
            else Gtk.log_unsupported(short_class_name, "add #{child.short_class_name}")
            end
            self
          end

          def activate
            emit(:activate)
            self
          end

          def kind
            'normal'
          end

          def event_for(signal)
            signal == :activate ? :activate : nil
          end

          def node_type
            :menu_item
          end

          def node_props
            props = { kind: kind }
            props[:label] = @label.empty? ? ' ' : @label unless kind == 'separator'
            props[:disabled] = true unless @sensitive
            props
          end

          def apply_builder_property(name, value)
            return (self.label = value) && self if name.to_s == 'label'

            super
          end

          private

          def mnemonic_free(label)
            label.to_s.gsub(/_(\S)/, '\1')
          end
        end

        class ImageMenuItem < MenuItem
        end

        class SeparatorMenuItem < MenuItem
          def initialize(*)
            super()
          end

          def kind
            'separator'
          end
        end

        class CheckMenuItem < MenuItem
          def initialize(label = nil, _use_underline = true, **options)
            super
            @active = options[:active] ? true : false
          end

          def active?
            @active
          end
          alias active active?

          def active=(value)
            value = value ? true : false
            return if value == @active

            @active = value
            viewer_push(:active, @active)
            emit(:toggled)
          end
          def_setter :set_active, :active=

          def toggled
            self.active = !@active
            self
          end

          def kind
            'check'
          end

          def event_for(signal)
            case signal
            when :toggled then :change
            when :activate then :activate
            end
          end

          def always_bound_events
            [:change]
          end

          def node_props
            super.merge(active: @active)
          end

          def apply_builder_property(name, value)
            return (self.active = Gtk.builder_value(value)) && self if name.to_s == 'active'

            super
          end

          protected

          # The viewer toggled it: update the shadow, then the handlers run
          # (`toggled` maps to this event, `activate` follows separately).
          def apply_event(event, context)
            return unless event == :change

            value = payload_value(context)
            @active = value ? true : false unless value.nil?
          end
        end

        # Radio items share a leader; `new(group, label)` where group is any
        # member (GTK also accepts the leader's group list, which is the same
        # here), `new(label)`, or `new(label: ...)`.
        class RadioMenuItem < CheckMenuItem
          def initialize(group = nil, label = nil, **options)
            if group.is_a?(String) || group.is_a?(Symbol)
              label = group
              group = nil
            end
            group = group.first if group.is_a?(Array)
            super(label, **options)
            @leader = group.is_a?(RadioMenuItem) ? group.leader : self
            @members = [] if @leader.equal?(self)
            @leader.members << self
            # GTK activates the first item of a group.
            @active = true if @leader.equal?(self) && !options.key?(:active)
          end

          attr_reader :leader

          def members
            @leader.equal?(self) ? @members : @leader.members
          end

          def group
            @leader
          end

          def active=(value)
            value = value ? true : false
            return if value == @active

            if value
              members.each { |member| member.send(:deactivate!) unless member.equal?(self) }
            end
            super
          end
          def_setter :set_active, :active=

          def kind
            'radio'
          end

          def node_props
            super.merge(group: @leader.key)
          end

          protected

          def apply_event(event, context)
            return unless event == :change

            value = payload_value(context)
            return if value.nil?

            @active = value ? true : false
            members.each { |member| member.send(:deactivate!) unless member.equal?(self) } if @active
          end

          def deactivate!
            return unless @active

            @active = false
            viewer_push(:active, false)
            emit(:toggled)
          end
        end

        class Menu < Container
          def initialize(*)
            super()
            @open = false
          end

          def append(item)
            add(item)
          end

          def prepend(item)
            add(item)
            @children.delete(item)
            @children.unshift(item)
            changed!
            self
          end

          def insert(item, position)
            add(item)
            @children.delete(item)
            @children.insert(position.to_i.clamp(0, @children.length), item)
            changed!
            self
          end

          def add(child)
            unless child.is_a?(MenuItem)
              Gtk.log_unsupported(short_class_name, "add #{child.short_class_name}")
              return self
            end
            super
          end

          def attach_to_widget(_widget, *_rest)
            self
          end

          def detach
            self
          end

          def accel_group=(_group); end
          def_setter :set_accel_group, :accel_group=

          # The 3.x forms: popup(parent_shell, parent_item, button, time),
          # popup_at_pointer(event), popup_at_widget(widget, ...).
          def popup(*_args)
            open!
          end

          def popup_at_pointer(_event = nil)
            open!
          end

          def popup_at_widget(*_args)
            open!
          end

          def popdown
            return self unless @open

            # `open` is viewer-scoped: with only changed!, the script could
            # raise a menu but never take it down.
            @open = false
            viewer_push(:open, false)
            self
          end

          def open?
            @open
          end

          def bar?
            false
          end

          def event_for(signal)
            case signal
            when :deactivate, :hide, :selection_done then :close
            end
          end

          def always_bound_events
            bar? ? [] : [:close]
          end

          def node_type
            :menu
          end

          def node_props
            { bar: bar?, open: @open && !bar? }
          end

          protected

          def apply_event(event, _context)
            @open = false if event == :close
          end

          private

          def open!
            return self if @open

            unless window_root
              window = @session.popup_window
              unless window
                Gtk.log_unsupported(short_class_name, 'popup', note: 'no window to show the menu in')
                return self
              end
              window.attach_popup(self)
            end
            @open = true
            changed!
            viewer_push(:open, true)
            self
          end
        end

        class MenuBar < Menu
          def bar?
            true
          end
        end

        # Accelerators are keyboard shortcuts on menu items; nothing to do
        # until the contract carries them for menus.
        class AccelGroup
          def connect(*_args, &_block)
            self
          end
        end
      end
    end
  end
end
