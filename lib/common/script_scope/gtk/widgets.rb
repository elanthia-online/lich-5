# frozen_string_literal: true

require_relative 'session'

module Lich
  module Common
    module ScriptScope
      # Ruby implementation of the slice of the ruby-gnome GTK 3 API that
      # scripts use, rendered through the WebUI contract. Scripts evaluated in
      # ScriptScope resolve `Gtk` here instead of the real gem.
      #
      # This file holds the base widget, containers, windows, and simple leaf
      # widgets. Data widgets (Notebook, SpinButton, ComboBox, TreeView,
      # TextView, Expander) live in widgets_data.rb; Gtk::Builder in
      # builder.rb. Anything a script calls that is not implemented logs once
      # and degrades.
      module Gtk
        module Version
          MAJOR = 3
          MINOR = 24
          MICRO = 0
          STRING = '3.24.0'
        end

        module AttachOptions
          EXPAND = 1
          SHRINK = 2
          FILL = 4
        end
        EXPAND = AttachOptions::EXPAND
        SHRINK = AttachOptions::SHRINK
        FILL = AttachOptions::FILL

        module ResponseType
          NONE = -1
          REJECT = -2
          ACCEPT = -3
          DELETE_EVENT = -4
          OK = -5
          CANCEL = -6
          CLOSE = -7
          YES = -8
          NO = -9
          APPLY = -10
          HELP = -11
        end

        module PolicyType
          ALWAYS = :always
          AUTOMATIC = :automatic
          NEVER = :never
          EXTERNAL = :external
        end

        module WindowType
          TOPLEVEL = :toplevel
          POPUP = :popup
        end

        module Align
          FILL = :fill
          START = :start
          CENTER = :center
          BASELINE = :baseline
          const_set(:END, :end) # END is a Ruby keyword; scripts still write Gtk::Align::END
        end

        # GTK 2 spellings that scripts still carry beside their GTK 3 ones.
        STATE_NORMAL = :normal
        STATE_ACTIVE = :active
        STATE_PRELIGHT = :prelight
        STATE_SELECTED = :selected
        STATE_INSENSITIVE = :insensitive

        module SortType
          ASCENDING = :ascending
          DESCENDING = :descending
        end

        module WrapMode
          NONE = :none
          CHAR = :char
          WORD = :word
          WORD_CHAR = :word_char
        end

        module PositionType
          LEFT = :left
          RIGHT = :right
          TOP = :top
          BOTTOM = :bottom
        end

        module SelectionMode
          NONE = :none
          SINGLE = :single
          BROWSE = :browse
          MULTIPLE = :multiple
        end

        module Orientation
          HORIZONTAL = :horizontal
          VERTICAL = :vertical
        end

        # The only fields GTK event structs expose that these scripts read.
        # Modifier keys held during a pointer event, with the Gdk predicates
        # scripts test.
        ModifierState = Struct.new(:ctrl, :shift, :alt) do
          def control_mask?
            ctrl
          end

          def shift_mask?
            shift
          end

          def mod1_mask?
            alt
          end
        end

        POINTER_BUTTONS = { 'primary' => 1, 'middle' => 2, 'secondary' => 3 }.freeze

        Event = Struct.new(:type, :button, :state, :keyval, :x, :y, :direction, :time) do
          # Builds a button event from a contract pointer payload.
          def self.pointer(kind, payload)
            modifiers = Array(payload[:modifiers] || payload['modifiers']).map(&:to_s)
            state = ModifierState.new(modifiers.include?('ctrl'), modifiers.include?('shift'), modifiers.include?('alt'))
            new(kind, POINTER_BUTTONS.fetch((payload[:button] || payload['button']).to_s, 1), state, nil,
                (payload[:x] || payload['x']).to_f, (payload[:y] || payload['y']).to_f, nil,
                Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond))
          end

          def event_type
            type
          end
        end

        # Widgets that receive pointer gestures: button-press-event and
        # button-release-event with a Gdk-shaped event argument.
        module PointerSurface
          def event_for(signal)
            case signal
            when :button_press_event then :press
            when :button_release_event then :release
            else super
            end
          end

          def receive_event(event, context)
            return super unless %i[press release].include?(event)

            payload = context.payload || {}
            gdk = Event.pointer(event == :press ? :button_press : :button_release, payload)
            @session.note_pointer(window_root)
            @handlers.each_key do |signal|
              emit(signal, gdk) if event_for(signal) == event
            end
          end
        end

        ALIGN_TO_CONTRACT = {
          start: 'start', center: 'center', end: 'end', fill: 'stretch', baseline: 'start',
        }.freeze

        @key_counter = 0
        @key_mutex = Mutex.new
        @unsupported = {}

        class << self
          def next_key
            @key_mutex.synchronize { "w#{@key_counter += 1}" }
          end

          # Schedules +block+ on the calling script's emulated GTK thread.
          def queue(&block)
            Session.current.enqueue(&block)
            nil
          end

          def main(*)
            log_unsupported('Gtk', 'main', note: 'the shim owns the main loop')
            nil
          end

          def main_quit(*)
            nil
          end

          def main_level
            0
          end

          def events_pending?
            false
          end

          def main_iteration_do(*)
            false
          end

          def log_unsupported(klass, method, note: nil)
            key = "#{klass}##{method}"
            return if @unsupported[key]

            @unsupported[key] = true
            script = Session.current_script&.name
            message = "webui-gtk-shim: unsupported #{key}#{" (#{note})" if note}#{" script=#{script}" if script}"
            Lich.log("warning: #{message}") if defined?(Lich) && Lich.respond_to?(:log)
          end

          # A widget class the shim does not implement yet. It renders as an
          # empty box and accepts every call, so a script that builds one
          # loses that part of its window instead of dying at load. Scripts
          # reach these through Gtk.const_missing, never by name here.
          def unimplemented_widget(name)
            klass = Class.new(Container) do
              def node_type
                :stack
              end

              def node_props
                { gap: 0 }
              end

              # Absolute-positioning containers (Layout, Fixed) take the
              # coordinates and ignore them; the child still renders.
              def put(child, _x = nil, _y = nil)
                add(child)
              end

              def move(_child, _x = nil, _y = nil)
                self
              end

              def set_size(_width = nil, _height = nil)
                self
              end
            end
            klass.define_singleton_method(:name) { "Gtk::#{name}" }
            klass
          end

          # Constants scripts reference that the shim has no implementation
          # for. A widget class degrades to an empty container; anything else
          # (an enum member, a flag) becomes the symbol it was named, since
          # scripts only ever pass those back into methods the shim ignores.
          # Either way the script keeps running and the gap is logged once.
          def const_missing(name)
            value = if name.to_s.match?(/\A[A-Z][a-z]/)
                      unimplemented_widget(name)
                    else
                      name.to_s.downcase.to_sym
                    end
            log_unsupported('Gtk', name, note: 'constant is not implemented')
            const_set(name, value)
          end

          def normalize_signal(name)
            name.to_s.tr('-', '_').to_sym
          end

          # Coerces a GtkBuilder property string to the value a setter wants.
          def builder_value(value)
            text = value.to_s
            case text
            when 'True', 'true', 'yes' then true
            when 'False', 'false', 'no' then false
            when /\A-?\d+\z/ then text.to_i
            when /\A-?\d*\.\d+\z/ then text.to_f
            else text
            end
          end
        end

        # ------------------------------------------------------------------
        # Base widget: identity, visibility, sensitivity, alignment, signals,
        # and the bookkeeping that materializes it into an adapter node.
        # ------------------------------------------------------------------
        class Widget
          # Builder properties every widget accepts and the shim has no use
          # for. Silently ignored so Glade files do not spam the log.
          IGNORED_BUILDER_PROPERTIES = %w[
            can-focus receives-default draw-indicator border-width label-xalign
            shadow-type yalign sizing search-column headers-visible
            fixed-height-mode column-homogeneous row-homogeneous max-width-chars
            wrap-mode accepts-tab modal tab-fill numeric digits angle
            use-markup activates-default has-frame can-default
            has-default focus-on-click relief image-position use-underline
            invisible-char primary-icon-activatable secondary-icon-activatable
            primary-icon-sensitive secondary-icon-sensitive resize-mode
            window-position type-hint destroy-with-parent skip-taskbar-hint
            hscrollbar-policy vscrollbar-policy min-content-height
            min-content-width propagate-natural-height propagate-natural-width
            overlay-scrolling show-tabs scrollable enable-popup justify
            single-line-mode ellipsize selectable track-visited-links
            left-padding right-padding top-padding bottom-padding xscale yscale
            xpad ypad homogeneous baseline-position pack-type padding
            always-show-image image icon-name stock enable-grid-lines
            activate-on-single-click primary-icon-name secondary-icon-name
            enable-search search-column reorderable rules-hint expander-column
          ].freeze

          attr_reader :key, :parent, :handle, :session, :halign, :valign, :placement
          attr_accessor :packing, :builder_name

          def initialize
            @key = Gtk.next_key
            @session = Session.current
            @handlers = Hash.new { |hash, signal| hash[signal] = [] }
            @handler_ids = {}
            @handle = nil
            @synced_props = nil
            @synced_placement = nil
            @bound_events = {}
            @parent = nil
            @visible = true
            @sensitive = true
            @tooltip = nil
            @width_request = nil
            @height_request = nil
            @packing = nil
            @placement = nil
            @halign = nil
            @valign = nil
            @margins = { top: 0, right: 0, bottom: 0, left: 0 }
            @hexpand = false
            @vexpand = false
            @builder_name = nil
          end

          # --- contract mapping (subclasses override) -----------------------

          def node_type
            raise NotImplementedError
          end

          def node_props
            {}
          end

          # Contract event a GTK signal maps to for this widget, or nil.
          def event_for(_signal)
            nil
          end

          # Events bound whether or not the script connected a handler, so
          # the shadow state tracks the viewer (scripts read `entry.text`
          # later without ever connecting `changed`).
          def always_bound_events
            []
          end

          # --- GTK surface ---------------------------------------------------

          def signal_connect(signal, *_args, &block)
            raise ArgumentError, 'signal handler block required' unless block

            name = Gtk.normalize_signal(signal)
            @handlers[name] << block
            id = @handler_ids.length + 1
            @handler_ids[id] = [name, block]
            id
          end
          alias signal_connect_after signal_connect

          def signal_handler_disconnect(id)
            name, block = @handler_ids.delete(id)
            @handlers[name].delete(block) if name
            nil
          end

          def signal_emit(signal, *args)
            emit(signal, *args)
          end

          # Runs the handlers for +signal+ with GTK's (widget, event) shape,
          # trimming arguments to what each handler accepts.
          def emit(signal, *args)
            name = Gtk.normalize_signal(signal)
            result = nil
            @handlers[name].dup.each do |handler|
              result = Gtk::Widget.call_handler(handler, [self, *args])
            end
            result
          end

          def self.call_handler(handler, args)
            arity = handler.arity
            if arity.negative?
              handler.call(*args)
            else
              handler.call(*args.first(arity))
            end
          end

          def handlers?(signal)
            !@handlers[Gtk.normalize_signal(signal)].empty?
          end

          def sensitive=(value)
            @sensitive = value ? true : false
            changed!
          end
          alias set_sensitive sensitive=

          def sensitive?
            @sensitive
          end

          def visible=(value)
            @visible = value ? true : false
            changed!
          end
          alias set_visible visible=

          def visible?
            @visible
          end

          def show
            self.visible = true
            self
          end

          def show_all
            show
          end

          def hide
            self.visible = false
            self
          end

          def tooltip_text=(text)
            @tooltip = text&.to_s
            changed!
          end
          alias set_tooltip_text tooltip_text=

          def tooltip_text
            @tooltip
          end

          def has_tooltip=(_value); end

          # Which of a size request's axes reach the contract node.
          def size_request_axes
            []
          end

          def set_size_request(width, height)
            @width_request = width.to_i.positive? ? width.to_i : nil
            @height_request = height.to_i.positive? ? height.to_i : nil
            changed!
            self
          end

          def width_request=(width)
            set_size_request(width, @height_request || -1)
          end

          def height_request=(height)
            set_size_request(@width_request || -1, height)
          end

          def halign=(value)
            @halign = value.to_s.downcase.to_sym
            changed!
          end
          alias set_halign halign=

          def valign=(value)
            @valign = value.to_s.downcase.to_sym
            changed!
          end
          alias set_valign valign=

          %i[top right bottom left].each do |side|
            define_method(:"margin_#{side}=") do |value|
              @margins[side] = value.to_i
              changed!
            end
            alias_method :"set_margin_#{side}", :"margin_#{side}="
          end
          alias margin_start= margin_left=
          alias set_margin_start margin_left=
          alias margin_end= margin_right=
          alias set_margin_end margin_right=

          def margin=(value)
            @margins = { top: value.to_i, right: value.to_i, bottom: value.to_i, left: value.to_i }
            changed!
          end

          def hexpand=(value)
            @hexpand = value ? true : false
          end
          alias set_hexpand hexpand=

          def vexpand=(value)
            @vexpand = value ? true : false
          end
          alias set_vexpand vexpand=

          def hexpand?
            @hexpand
          end

          def xalign=(_value); end
          alias set_xalign xalign=

          # Event masks are implicit here: a widget with a handler is bound.
          def add_events(*_masks)
            self
          end
          alias set_events add_events
          alias events= add_events

          def set_border_width(_width)
            self
          end
          alias border_width= set_border_width

          def name=(value)
            @name = value.to_s
          end
          alias set_name name=

          def name
            @name
          end

          def grab_focus
            self
          end

          def destroy
            @parent&.remove(self)
            emit(:destroy)
            @session.enqueue { @session.commit } unless @session.on_session_thread?
            nil
          end

          def destroyed?
            @destroyed == true
          end

          def toplevel
            node = self
            node = node.parent while node.parent
            node
          end

          def window_root
            root = toplevel
            root.is_a?(Window) ? root : nil
          end

          def set_property(name, value)
            apply_builder_property(name, value)
          end

          # Applies one GtkBuilder <property> to this widget. Subclasses
          # override for names that mean different things per class (label,
          # active, text) and fall back here.
          def apply_builder_property(name, value)
            property = name.to_s.tr('_', '-')
            return self if IGNORED_BUILDER_PROPERTIES.include?(property)

            setter = "#{property.tr('-', '_')}="
            if self.class.method_defined?(setter)
              public_send(setter, Gtk.builder_value(value))
            else
              Gtk.log_unsupported(short_class_name, "builder property #{property}")
            end
            self
          end

          def method_missing(name, *_args, &_block)
            Gtk.log_unsupported(short_class_name, name)
            return self if name.end_with?('=') || name.start_with?('set_')

            nil
          end

          def respond_to_missing?(_name, _include_private = false)
            true
          end

          # --- materialization ------------------------------------------------

          def attach_to(parent)
            @parent = parent
          end

          def detach_from_parent
            @parent = nil
          end

          # Placement in the parent's contract node (grid span etc.).
          def placement=(hash)
            @placement = hash && !hash.empty? ? hash : nil
          end

          def changed!
            @dirty = true
            window = window_root
            return unless window&.handle && @session.on_session_thread? == false

            # Off-thread mutation (a script thread poking a widget): render soon.
            @session.enqueue { @session.commit }
          end

          def common_props
            props = { key: @key }
            props[:hidden] = true unless @visible
            props[:tooltip] = @tooltip if @tooltip && !@tooltip.empty?
            # GTK's size request is a minimum that layout grows past; the
            # contract's width/height are fixed. Only widgets whose natural
            # size really is the request (inputs, views) pass it through;
            # for boxes, tables, frames and labels a fixed size would clip
            # content or stretch rows across dead space.
            props[:width] = @width_request if @width_request && size_request_axes.include?(:width)
            props[:height] = @height_request if @height_request && size_request_axes.include?(:height)
            props[:align] = ALIGN_TO_CONTRACT[@halign] if @halign && ALIGN_TO_CONTRACT[@halign]
            margin = @margins.values.max
            props[:margin] = [margin, 512].min if margin.positive?
            props
          end

          # Creates or updates this widget's adapter node. Returns the handle.
          def materialize!(adapter)
            props = filter_props(common_props.merge(node_props))
            if @handle.nil?
              @handle = adapter.create(node_type, props)
              @synced_props = props
            elsif props != @synced_props
              changes = (props.keys | @synced_props.keys).each_with_object({}) do |name, result|
                result[name] = props[name] unless props[name] == @synced_props[name]
              end
              adapter.update(@handle, changes)
              @synced_props = props
            end
            sync_bindings!(adapter)
            @dirty = false
            @handle
          end

          def release_handle!
            @handle = nil
            @synced_props = nil
            @synced_placement = nil
            @bound_events = {}
          end

          def sync_placement!(adapter)
            return unless @handle
            return if @placement == @synced_placement

            adapter.set_placement(@handle, @placement || {})
            @synced_placement = @placement
          end

          def short_class_name
            self.class.name.split('::').last(2).join('::')
          end

          protected

          # Contract event arrived (on the session thread): update shadow state
          # then run the GTK handlers for every signal mapped to it.
          def receive_event(event, context)
            apply_event(event, context)
            @handlers.each_key do |signal|
              emit(signal, Event.new) if event_for(signal) == event
            end
          end

          def apply_event(_event, _context); end

          def payload_value(context, name = :value)
            payload = context.payload
            return nil unless payload

            payload.key?(name) ? payload[name] : payload[name.to_s]
          end

          private

          # Drops any common prop the contract does not allow on this type.
          def filter_props(props)
            allowed = Lich::WebUI::Contract.schema(node_type)[:properties]
            props.select { |name, _value| allowed.key?(name) }
          end

          def sync_bindings!(adapter)
            window = window_root
            return unless window

            events = @handlers.keys.map { |signal| event_for(signal) } + always_bound_events
            events.compact.uniq.each do |event|
              next if @bound_events[event]

              widget = self
              @bound_events[event] = adapter.bind(@handle, event, @session.dispatch_proc(window) { |context|
                widget.receive_event(event, context)
              })
            end
          end
        end

        # ------------------------------------------------------------------
        # Containers
        # ------------------------------------------------------------------
        class Container < Widget
          def initialize
            super
            @children = []
            @synced_children = []
          end

          def children
            ordered_children.dup
          end

          def each(&block)
            ordered_children.each(&block)
          end

          def add(child)
            child.detach_from_parent if child.parent
            child.attach_to(self)
            @children << child
            changed!
            self
          end

          def remove(child)
            return self unless @children.delete(child)

            child.detach_from_parent
            changed!
            self
          end

          def remove_all
            @children.dup.each { |child| remove(child) }
          end

          def show_all
            show
            @children.each(&:show_all)
            self
          end

          def ordered_children
            @children
          end

          # Children the contract node should hold, in order. Grids override
          # to interleave fillers; hidden children are dropped.
          def render_children
            ordered_children.select(&:visible?)
          end

          def materialize!(adapter)
            handle = super
            (@synced_children - ordered_children - filler_children).each do |gone|
              next unless gone.handle

              begin
                adapter.destroy(gone.handle)
              rescue Lich::WebUI::Error
                nil
              end
              gone.release_handle!
            end
            desired = render_children
            @synced_children &= (ordered_children + filler_children)
            unless desired == @synced_children
              @synced_children.each do |child|
                adapter.detach(handle, child.handle) if child.handle
              rescue Lich::WebUI::Error
                nil
              end
              @synced_children = []
            end
            attached = []
            desired.each do |child|
              begin
                child_handle = child.materialize!(adapter)
              rescue Lich::WebUI::Error => error
                Gtk.log_unsupported(child.short_class_name, 'render', note: error.message)
                next
              end
              adapter.attach(handle, child_handle, attached.length) unless @synced_children.include?(child)
              child.sync_placement!(adapter)
              attached << child
            end
            @synced_children = attached
            # keep hidden children's own state current without attaching them
            (ordered_children - desired).each { |child| child.materialize!(adapter) if child.handle }
            handle
          end

          def filler_children
            []
          end

          def release_handle!
            super
            @synced_children = []
            @children.each(&:release_handle!)
          end
        end

        class Box < Container
          attr_reader :orientation, :spacing

          def initialize(orientation = :vertical, spacing = 0)
            super()
            @orientation = orientation.to_s.start_with?('h') ? :horizontal : :vertical
            @spacing = spacing.to_i
            @end_children = []
          end

          def pack_start(child, *positional, **options)
            child.packing = packing_from(positional, options)
            add(child)
          end

          def pack_end(child, *positional, **options)
            child.packing = packing_from(positional, options)
            add(child)
            @end_children << child
            self
          end

          def remove(child)
            @end_children.delete(child)
            super
          end

          def reorder_child(child, position)
            return self unless @children.delete(child)

            @children.insert(position.to_i.clamp(0, @children.length), child)
            changed!
            self
          end

          def homogeneous=(_value); end
          alias set_homogeneous homogeneous=

          def spacing=(value)
            @spacing = value.to_i
            changed!
          end
          alias set_spacing spacing=

          def orientation=(value)
            @orientation = value.to_s.start_with?('h') ? :horizontal : :vertical
            changed!
          end

          def ordered_children
            starts = @children.reject { |child| @end_children.include?(child) }
            starts + @end_children.reverse.select { |child| @children.include?(child) }
          end

          def node_type
            @orientation == :vertical ? :stack : :columns
          end

          def node_props
            if @orientation == :vertical
              { gap: [@spacing, 64].min }
            else
              count = render_children.length
              { count: count.clamp(1, 12), gap: [@spacing, 64].min }
            end
          end

          private

          def packing_from(positional, options)
            expand, fill, padding = positional
            {
              expand: options.fetch(:expand, expand) ? true : false,
              fill: options.fetch(:fill, fill) ? true : false,
              padding: options.fetch(:padding, padding || 0).to_i,
            }
          end
        end

        class HBox < Box
          def initialize(_homogeneous = false, spacing = 0)
            super(:horizontal, spacing)
          end
        end

        class VBox < Box
          def initialize(_homogeneous = false, spacing = 0)
            super(:vertical, spacing)
          end
        end

        # Placeholder for an empty grid cell so flow order reproduces an
        # attach layout that has holes.
        class Filler < Widget
          def node_type
            :text
          end

          def node_props
            { content: ' ' }
          end

          def common_props
            { key: @key }
          end
        end

        # Shared by Gtk::Table and Gtk::Grid: children carry a cell rectangle
        # and render into a flow-ordered contract grid, row by row, with
        # fillers for holes and span placement for wide cells.
        module GridLayout
          def cells
            @cells ||= {}.compare_by_identity
          end

          def fillers
            @fillers ||= {}
          end

          def column_count
            raise NotImplementedError
          end

          def ordered_children
            @children.sort_by { |child| cells.fetch(child, [0, 0, 1, 1]).first(2).reverse }
          end

          def filler_children
            fillers.values
          end

          def render_children
            cols = column_count
            rects = @children.to_h { |child| [child, normalized_rect(child, cols)] }
            rows = rects.values.map { |(_left, top, _width, height)| top + height }.max || 0
            covered = {}
            output = []
            (0...rows).each do |row|
              row_children = rects.select { |child, (_left, top, _w, _h)| top == row && child.visible? }
              # a row whose children are all hidden collapses, as it does in GTK
              next if row_children.empty? && !covered.values.any? { |(_c, r)| r == row }

              column = 0
              while column < cols
                child, rect = row_children.find { |_c, (left, _t, _w, _h)| left == column }
                if child
                  left, top, width, height = rect
                  output << child
                  child.placement = span_placement(width, height)
                  (top...(top + height)).each do |r|
                    (left...(left + width)).each { |c| covered[[c, r]] = [c, r] unless r == top && c == left }
                  end
                  column += width
                elsif covered.key?([column, row])
                  column += 1
                else
                  output << filler_for(column, row)
                  column += 1
                end
              end
            end
            output
          end

          private

          def normalized_rect(child, cols)
            left, top, width, height = cells.fetch(child, [0, 0, 1, 1])
            width = [[width, 1].max, cols - left].min
            [left.clamp(0, cols - 1), [top, 0].max, [width, 1].max, [height, 1].max]
          end

          def span_placement(width, height)
            placement = {}
            placement[:span] = width if width > 1
            placement[:row_span] = height if height > 1
            placement
          end

          def filler_for(column, row)
            fillers[[column, row]] ||= Filler.new.tap { |filler| filler.attach_to(self) }
          end
        end

        # Gtk::Table (GTK 2 API, still used): attach(child, left, right, top, bottom).
        class Table < Container
          include GridLayout

          attr_reader :n_rows, :n_columns

          def initialize(rows = 1, columns = 1, _homogeneous = false)
            super()
            @n_rows = [rows.to_i, 1].max
            @n_columns = [columns.to_i, 1].max
          end

          def n_rows=(value)
            @n_rows = [value.to_i, 1].max
          end
          alias resize_rows n_rows=

          def n_columns=(value)
            @n_columns = [value.to_i, 1].max
            changed!
          end

          def resize(rows, columns)
            self.n_rows = rows
            self.n_columns = columns
          end

          def attach(child, left, right, top, bottom, _xoptions = nil, _yoptions = nil, _xpadding = 0, _ypadding = 0)
            cells[child] = [left.to_i, top.to_i, [right.to_i - left.to_i, 1].max, [bottom.to_i - top.to_i, 1].max]
            add(child)
          end

          def attach_defaults(child, left, right, top, bottom)
            attach(child, left, right, top, bottom)
          end

          def remove(child)
            cells.delete(child)
            super
          end

          def column_count
            @n_columns.clamp(1, 24)
          end

          def node_type
            :grid
          end

          def node_props
            { cols: column_count, gap: 4 }
          end
        end

        # Gtk::Grid: attach(child, left, top, width, height).
        class Grid < Container
          include GridLayout

          def initialize
            super
            @row_spacing = 4
            @column_spacing = 4
          end

          def attach(child, left, top, width = 1, height = 1)
            cells[child] = [left.to_i, top.to_i, [width.to_i, 1].max, [height.to_i, 1].max]
            add(child)
          end

          def attach_next_to(child, sibling, side, width = 1, height = 1)
            left, top, = cells.fetch(sibling, [0, 0, 1, 1])
            case side.to_s
            when 'right' then attach(child, left + 1, top, width, height)
            when 'bottom' then attach(child, left, top + 1, width, height)
            when 'left' then attach(child, [left - 1, 0].max, top, width, height)
            else attach(child, left, [top - 1, 0].max, width, height)
            end
          end

          def add(child)
            cells[child] ||= [0, next_free_row, 1, 1]
            super
          end

          def remove(child)
            cells.delete(child)
            super
          end

          def row_spacing=(value)
            @row_spacing = value.to_i
            changed!
          end
          alias set_row_spacing row_spacing=

          def column_spacing=(value)
            @column_spacing = value.to_i
            changed!
          end
          alias set_column_spacing column_spacing=

          def column_count
            cols = @children.map { |child| rect = cells.fetch(child, [0, 0, 1, 1]); rect[0] + rect[2] }.max || 1
            cols.clamp(1, 24)
          end

          def node_type
            :grid
          end

          def node_props
            { cols: column_count, gap: [[@row_spacing, @column_spacing].max, 64].min }
          end

          private

          def next_free_row
            @children.map { |child| rect = cells.fetch(child, [0, 0, 1, 1]); rect[1] + rect[3] }.max || 0
          end
        end

        class ScrolledWindow < Container
          def initialize(_hadjustment = nil, _vadjustment = nil)
            super()
            @vadjustment = Adjustment.new
            @hadjustment = Adjustment.new
          end

          attr_reader :vadjustment, :hadjustment

          def set_policy(_horizontal, _vertical)
            self
          end

          def add_with_viewport(child)
            add(child)
          end

          def set_shadow_type(_type)
            self
          end
          alias shadow_type= set_shadow_type

          def set_min_content_height(value)
            @min_height = value.to_i
            self
          end
          alias min_content_height= set_min_content_height

          def node_type
            :scroll
          end

          def size_request_axes
            parent.is_a?(Window) ? [] : [:height]
          end

          def node_props
            window = window_root
            height = window&.default_height
            props = {}
            props[:max_height] = [height - 48, 120].max if height && parent.is_a?(Window)
            props
          end
        end

        class Viewport < Container
          def initialize(_hadjustment = nil, _vadjustment = nil)
            super()
          end

          def node_type
            :stack
          end

          def node_props
            { gap: 0 }
          end
        end

        # Gtk::Alignment (deprecated in GTK 3, still the most-used container
        # in these scripts at ~400 call sites): one child, positioned by
        # xalign/yalign unless the matching scale is 1.0, which means fill.
        class Alignment < Container
          def initialize(xalign = 0.0, yalign = 0.0, xscale = 0.0, yscale = 0.0)
            super()
            @xalign = xalign.to_f
            @yalign = yalign.to_f
            @xscale = xscale.to_f
            @yscale = yscale.to_f
            @padding = { top: 0, bottom: 0, left: 0, right: 0 }
          end

          def set_alignment(xalign, yalign, xscale = @xscale, yscale = @yscale)
            @xalign = xalign.to_f
            @yalign = yalign.to_f
            @xscale = xscale.to_f
            @yscale = yscale.to_f
            changed!
            self
          end

          def set_padding(top, bottom, left, right)
            @padding = {
              top: top.to_i, bottom: bottom.to_i, left: left.to_i, right: right.to_i,
            }
            changed!
            self
          end

          def node_type
            :stack
          end

          def common_props
            props = super
            # A scale of 1.0 fills the cell, so alignment does not apply.
            props[:align] = horizontal_align unless @xscale >= 1.0 || @halign
            margin = @padding.values.max
            props[:margin] = [margin, 512].min if margin.positive?
            props
          end

          def node_props
            { gap: 0 }
          end

          private

          def horizontal_align
            if @xalign <= 0.25 then 'start'
            elsif @xalign >= 0.75 then 'end'
            else 'center'
            end
          end
        end

        class Frame < Container
          def initialize(label = nil)
            super()
            @label = label.to_s
            @label_widget = nil
          end

          def label
            @label
          end

          def label=(value)
            @label = value.to_s
            changed!
          end
          alias set_label label=

          def set_label_widget(widget)
            @label_widget = widget
            @label = widget.respond_to?(:text) ? widget.text.to_s : @label
            changed!
            self
          end
          alias label_widget= set_label_widget

          def label_widget
            @label_widget
          end

          def set_label_align(*_args)
            self
          end

          def node_type
            :group
          end

          def node_props
            text = @label_widget.respond_to?(:text) ? @label_widget.text.to_s : @label
            { label: text.empty? ? ' ' : text }
          end
        end

        class EventBox < Container
          prepend PointerSurface

          def node_type
            :stack
          end

          def node_props
            { gap: 0 }
          end
        end

        # Scroll adjustments and SpinButton ranges: real state, so scripts
        # that read or animate them see sane numbers. Owners re-render when
        # the range changes.
        class Adjustment
          attr_reader :value, :lower, :upper, :page_size, :step_increment, :page_increment
          attr_accessor :builder_name

          def initialize(value = 0.0, lower = 0.0, upper = 100.0, step = 1.0, page_inc = 10.0, page_size = 0.0)
            @value = value.to_f
            @lower = lower.to_f
            @upper = upper.to_f
            @step_increment = step.to_f
            @page_increment = page_inc.to_f
            @page_size = page_size.to_f
            @owners = []
            @handlers = []
          end

          def watch(owner)
            @owners << owner unless @owners.include?(owner)
          end

          %i[value lower upper page_size step_increment page_increment].each do |attribute|
            define_method(:"#{attribute}=") do |number|
              instance_variable_set(:"@#{attribute}", number.to_f)
              notify_owners
            end
            alias_method :"set_#{attribute}", :"#{attribute}="
          end

          def configure(value, lower, upper, step, page_inc, page_size)
            @value = value.to_f
            @lower = lower.to_f
            @upper = upper.to_f
            @step_increment = step.to_f
            @page_increment = page_inc.to_f
            @page_size = page_size.to_f
            notify_owners
          end

          def signal_connect(_signal, &block)
            @handlers << block if block
            @handlers.length
          end

          def apply_builder_property(name, value)
            setter = "#{name.to_s.tr('-', '_')}="
            public_send(setter, Gtk.builder_value(value)) if respond_to?(setter)
            self
          end

          private

          def notify_owners
            @owners.each { |owner| owner.changed! if owner.respond_to?(:changed!) }
          end
        end

        # ------------------------------------------------------------------
        # Windows
        # ------------------------------------------------------------------
        class Window < Container
          TOPLEVEL = WindowType::TOPLEVEL
          POPUP = WindowType::POPUP

          attr_reader :title, :default_width, :default_height

          def initialize(arg = nil, *_rest)
            super()
            @title = arg.is_a?(String) ? arg : ''
            @default_width = nil
            @default_height = nil
            @shown = false
            @delete_emitted = false
            @lifecycle_bound = false
            @session.register_window(self)
          end

          def title=(value)
            @title = value.to_s
            changed!
          end
          alias set_title title=

          def set_default_size(width, height)
            @default_width = width.to_i.positive? ? width.to_i : nil
            @default_height = height.to_i.positive? ? height.to_i : nil
            changed!
            self
          end

          def default_width=(width)
            set_default_size(width, @default_height || -1)
          end

          def default_height=(height)
            set_default_size(@default_width || -1, height)
          end

          def resize(width, height)
            set_default_size(width, height)
          end

          def set_size_request(width, height)
            set_default_size(width, height) if @default_width.nil? && @default_height.nil?
            super
          end

          def set_icon(_icon)
            self
          end
          alias icon= set_icon

          def set_window_position(_position)
            self
          end
          alias window_position= set_window_position

          def set_keep_above(_value)
            self
          end
          alias keep_above= set_keep_above

          def set_resizable(_value)
            self
          end
          alias resizable= set_resizable

          def modal=(_value); end
          alias set_modal modal=

          def move(_x, _y)
            self
          end

          def position
            [0, 0]
          end

          def allocation
            Struct.new(:width, :height, :x, :y).new(@default_width || 640, @default_height || 480, 0, 0)
          end

          def size
            [@default_width || 640, @default_height || 480]
          end

          def show_all
            show
          end

          def show
            super
            if @shown
              @session.enqueue { @session.commit }
            else
              @shown = true
              @session.enqueue { @session.show_window(self) }
            end
            self
          end

          def present
            show
          end

          def destroy
            @destroyed = true
            emit(:destroy)
            @session.enqueue { @session.close_window(self) }
            nil
          end

          # GTK emits delete-event when the window manager asks to close. A
          # handler returning true vetoes the close; the browser is already
          # gone by the time we hear about it, so the veto is honored only in
          # the sense that the widget tree survives for the script to reopen.
          def viewer_closed
            return if @delete_emitted || @destroyed

            @delete_emitted = true
            emit(:delete_event, Event.new(:delete))
          end

          def browser_exited
            viewer_closed
          end

          # Popup menus shown over this window. They render as hidden page
          # children; the client raises them when `open` is set.
          def attach_popup(menu)
            @popups ||= []
            return self if @popups.include?(menu)

            menu.detach_from_parent if menu.parent
            menu.attach_to(self)
            @popups << menu
            changed!
            self
          end

          def render_children
            super + Array(@popups).select(&:visible?)
          end

          # Popups are not ordered children but must survive child syncing
          # (Container#materialize! keeps `ordered_children + filler_children`).
          def filler_children
            Array(@popups)
          end

          def lifecycle_bound?
            @lifecycle_bound
          end

          def lifecycle_bound!
            @lifecycle_bound = true
          end

          def browser_geometry
            return nil unless @default_width && @default_height

            { width: @default_width, height: @default_height }
          end

          # Window signals are lifecycle, not component events; the session
          # binds them on the page itself.
          def event_for(*)
            nil
          end

          def node_type
            :page
          end

          def node_props
            props = { title: @title.empty? ? 'Lich' : @title, bare: true }
            props[:size] = [@default_width, @default_height] if @default_width && @default_height
            props
          end

          def common_props
            { key: @key }
          end
        end

        class Dialog < Window
          def initialize(*_args, **_options)
            super()
          end

          def add_button(_label, _response)
            self
          end

          def run
            Gtk.log_unsupported('Gtk::Dialog', 'run', note: 'custom dialogs are not rendered yet')
            ResponseType::DELETE_EVENT
          end
        end

        # ------------------------------------------------------------------
        # Simple leaf widgets
        # ------------------------------------------------------------------
        class Label < Widget
          prepend PointerSurface

          LINK = %r{<a\s[^>]*href="([^"]*)"[^>]*>(.*?)</a>}m
          @markup_cache = {}
          @markup_cache_mutex = Mutex.new

          class << self
            # Validates a Pango markup string once and remembers the verdict;
            # labels re-render often and the validator parses XML.
            def markup_allowed?(markup)
              @markup_cache_mutex.synchronize do
                return @markup_cache[markup] if @markup_cache.key?(markup)

                @markup_cache.clear if @markup_cache.length > 2048
                @markup_cache[markup] = begin
                  Lich::WebUI::Validator.new.validate_component!(
                    :text, { content: ' ', markup: markup }, owner: 'gtk-shim', page_id: 'label', cid: 'markup'
                  )
                  true
                rescue Lich::WebUI::Error => error
                  Gtk.log_unsupported('Label', 'markup', note: error.message)
                  false
                end
              end
            end
          end

          def initialize(text = nil, _mnemonic = false)
            super()
            @text = text.to_s
            @raw = @text
            @markup = false
            @markup_source = nil
            @wrap = false
          end

          def text
            @text
          end

          def text=(value)
            @text = value.to_s
            @raw = @text
            @markup = false
            @markup_source = nil
            changed!
          end
          alias set_text text=
          alias label= text=
          alias set_label text=
          alias label text

          # Pango markup: the contract carries the subset the validator
          # allows; links become their target until the contract has them.
          def set_markup(markup)
            @raw = markup.to_s
            source = @raw.gsub(LINK) do
              href = Regexp.last_match(1)
              inner = Regexp.last_match(2).gsub(/<[^>]+>/, '')
              inner == href ? href : "#{inner} (#{href})"
            end
            @text = source.gsub(/<[^>]+>/, '').gsub('&amp;', '&').gsub('&lt;', '<').gsub('&gt;', '>').gsub('&quot;', '"')
            @markup = true
            @markup_source = source == @text ? nil : source
            changed!
            self
          end
          alias markup= set_markup

          def use_markup=(value)
            set_markup(@raw) if value && !@markup
          end
          alias set_use_markup use_markup=

          def use_markup?
            @markup
          end

          # GTK's xalign places the text inside the cell the label was given.
          def xalign=(value)
            value = value.to_f
            @xalign = if value <= 0.25 then :start
                      elsif value >= 0.75 then :end
                      else :center
                      end
            changed!
          end
          alias set_xalign xalign=

          def set_alignment(xalign, _yalign = nil)
            self.xalign = xalign
            self
          end

          def common_props
            props = super
            props[:align] = @xalign.to_s if @xalign && !@halign
            props
          end

          def set_wrap(value)
            @wrap = value ? true : false
            changed!
            self
          end
          alias wrap= set_wrap
          alias set_line_wrap set_wrap
          alias line_wrap= set_wrap

          def wrap?
            @wrap
          end

          # A label's width-chars is a wrap hint; text wraps naturally here.
          def width_chars=(_chars); end
          alias set_width_chars width_chars=
          alias max_width_chars= width_chars=
          alias set_max_width_chars width_chars=

          def set_selectable(_value)
            self
          end
          alias selectable= set_selectable

          def apply_builder_property(name, value)
            return (self.text = value) && self if name.to_s == 'label'

            super
          end

          def node_type
            :text
          end

          def node_props
            props = { content: @text.empty? ? ' ' : @text, wrap: @wrap }
            props[:markup] = @markup_source if @markup_source && self.class.markup_allowed?(@markup_source)
            props[:emphasis] = 'subtle' unless @sensitive
            props
          end
        end

        class Separator < Widget
          def initialize(orientation = :horizontal)
            super()
            @orientation = orientation
          end

          def orientation=(value)
            @orientation = value.to_s.start_with?('v') ? :vertical : :horizontal
          end

          def node_type
            :divider
          end
        end

        class HSeparator < Separator
          def initialize
            super(:horizontal)
          end
        end

        class VSeparator < Separator
          def initialize
            super(:vertical)
          end
        end

        class Entry < Widget
          def initialize(*_args)
            super()
            @text = +''
            @editable = true
            @placeholder = nil
            @max_length = nil
          end

          def text
            @text.dup
          end

          def text=(value)
            @text = value.to_s.dup
            changed!
            @session.viewer_write(window_root, self, :value, @text) if @handle
          end
          alias set_text text=

          def editable=(value)
            @editable = value ? true : false
            changed!
          end
          alias set_editable editable=

          def size_request_axes
            [:width]
          end

          # Approximates GTK's character-width sizing in pixels.
          def width_chars=(chars)
            set_size_request((chars.to_i * 8) + 24, @height_request || -1) if chars.to_i.positive?
          end
          alias set_width_chars width_chars=

          def editable?
            @editable
          end

          def placeholder_text=(value)
            @placeholder = value&.to_s
            changed!
          end
          alias set_placeholder_text placeholder_text=

          def max_length=(value)
            @max_length = value.to_i.positive? ? value.to_i : nil
            changed!
          end
          alias set_max_length max_length=

          def visibility=(_value); end
          alias set_visibility visibility=

          def set_alignment(_value)
            self
          end

          def event_for(signal)
            case signal
            when :changed then :change
            when :activate then :submit
            when :focus_in_event then :focus
            when :focus_out_event then :blur
            end
          end

          def always_bound_events
            [:change]
          end

          def node_type
            :text_input
          end

          def node_props
            props = { value: @text.dup }
            props[:disabled] = true unless @sensitive && @editable
            props[:placeholder] = @placeholder if @placeholder && !@placeholder.empty?
            props[:max_length] = @max_length if @max_length
            props
          end

          protected

          def apply_event(event, context)
            return unless event == :change

            value = payload_value(context)
            @text = value.to_s.dup unless value.nil?
          end
        end

        class SearchEntry < Entry
          def node_props
            super.merge(search: true)
          end
        end

        class Button < Widget
          def initialize(label = nil, **options)
            super()
            @label = if options.key?(:label) then options[:label].to_s
                     elsif label.is_a?(String) then label
                     else ''
                     end
          end

          def label
            @label
          end

          def label=(value)
            @label = value.to_s
            changed!
          end
          alias set_label label=

          def clicked
            emit(:clicked)
          end

          def set_image(_image)
            self
          end
          alias image= set_image

          def set_relief(_relief)
            self
          end
          alias relief= set_relief

          def event_for(signal)
            :activate if signal == :clicked
          end

          def node_type
            :button
          end

          def node_props
            props = { label: @label.empty? ? ' ' : @label }
            props[:disabled] = true unless @sensitive
            props
          end
        end

        # GTK hierarchy: CheckButton < ToggleButton < Button. Scripts test
        # `is_a?(Gtk::ToggleButton)` to find anything checkable.
        class ToggleButton < Button
          def initialize(label = nil, **options)
            super
            @active = false
          end

          def active?
            @active
          end

          def active=(value)
            @active = value ? true : false
            changed!
            @session.viewer_write(window_root, self, :checked, @active) if @handle
          end
          alias set_active active=

          def apply_builder_property(name, value)
            return (self.active = Gtk.builder_value(value)) && self if name.to_s == 'active'

            super
          end

          def event_for(signal)
            :change if %i[toggled clicked].include?(signal)
          end

          def always_bound_events
            [:change]
          end

          def node_type
            :toggle
          end

          def node_props
            props = { label: @label.empty? ? ' ' : @label, checked: @active }
            props[:disabled] = true unless @sensitive
            props
          end

          protected

          def apply_event(event, context)
            return unless event == :change

            value = payload_value(context)
            @active = value ? true : false unless value.nil?
          end
        end

        class CheckButton < ToggleButton
          def node_type
            :checkbox
          end
        end

        # Radio groups are rendered as independent checkboxes for now; the
        # group is kept so `group`/`active?` behave, and the shim enforces
        # exclusivity itself.
        class RadioButton < CheckButton
          def initialize(group_or_label = nil, label = nil, **options)
            text = options[:label] || (label.is_a?(String) ? label : (group_or_label.is_a?(String) ? group_or_label : nil))
            super(text, **{})
            @group = []
            leader = options[:member] || (group_or_label.is_a?(RadioButton) ? group_or_label : nil)
            leader = group_or_label.first if group_or_label.is_a?(Array) && group_or_label.first.is_a?(RadioButton)
            join_group(leader) if leader
            Gtk.log_unsupported('Gtk::RadioButton', 'exclusive rendering', note: 'rendered as checkboxes')
          end

          def group
            @group.empty? ? [self] : @group
          end

          def join_group(leader)
            @group = leader.group
            @group << self unless @group.include?(self)
            @group.each { |member| member.instance_variable_set(:@group, @group) }
            self
          end
          alias set_group join_group

          def active=(value)
            super
            group.each { |member| member.send(:deactivate_quietly) if !member.equal?(self) && value }
          end

          protected

          def deactivate_quietly
            @active = false
            changed!
          end
        end

        # ------------------------------------------------------------------
        # Modal dialogs. Not widgets in the tree: a run maps to a contract
        # modal and blocks the session thread until the viewer answers.
        # ------------------------------------------------------------------
        class MessageDialog
          BUTTON_SETS = {
            none: [],
            ok: [[:ok, 'OK']],
            close: [[:close, 'Close']],
            cancel: [[:cancel, 'Cancel']],
            yes_no: [[:yes, 'Yes'], [:no, 'No']],
            ok_cancel: [[:ok, 'OK'], [:cancel, 'Cancel']],
          }.freeze

          RESPONSES = {
            ok: ResponseType::OK, close: ResponseType::CLOSE, cancel: ResponseType::CANCEL,
            yes: ResponseType::YES, no: ResponseType::NO,
          }.freeze

          attr_accessor :title

          def initialize(*positional, **options)
            @session = Session.current
            @message = options[:message] || positional.find { |value| value.is_a?(String) } || ''
            buttons = options[:buttons] || positional.find { |value| value.is_a?(Symbol) && BUTTON_SETS.key?(value) } || :ok
            @buttons = BUTTON_SETS.fetch(buttons.to_sym, BUTTON_SETS[:ok])
            @type = options[:type] || :info
            @title = @type.to_s.capitalize
            @secondary = nil
          end

          def set_title(value)
            @title = value.to_s
            self
          end

          def set_icon(_icon)
            self
          end
          alias icon= set_icon

          def secondary_text=(value)
            @secondary = value.to_s
          end
          alias set_secondary_text secondary_text=

          def set_markup(value)
            @message = value.to_s.gsub(/<[^>]+>/, '')
            self
          end

          def add_button(label, response)
            @buttons += [[response.to_s.downcase.to_sym, label.to_s]]
            self
          end

          def run
            buttons = @buttons.map do |(id, label)|
              { id: id.to_s, label: label, variant: id == :cancel || id == :no ? 'default' : 'primary' }
            end
            buttons = [{ id: 'ok', label: 'OK', variant: 'primary' }] if buttons.empty?
            body = [@message, @secondary].compact.reject(&:empty?).join("\n\n")
            future = @session.modal(title: @title.to_s.empty? ? 'Lich' : @title, body: body.empty? ? nil : body, buttons: buttons)
            result = future.await
            return ResponseType::DELETE_EVENT unless result&.button

            RESPONSES.fetch(result.button.to_sym, ResponseType::NONE)
          rescue Lich::WebUI::Error => error
            Lich.log("warning: webui-gtk-shim: dialog failed: #{error.message}") if defined?(Lich) && Lich.respond_to?(:log)
            ResponseType::DELETE_EVENT
          end

          def destroy
            nil
          end

          def show_all
            self
          end

          def signal_connect(*_args, &_block)
            0
          end
        end
      end

      # Sibling namespaces scripts touch alongside Gtk.
      module Gdk
        class Screen
          Size = Struct.new(:width, :height)

          def self.default
            @default ||= Size.new(1280, 800)
          end
        end

        class RGBA
          attr_reader :red, :green, :blue, :alpha

          def initialize(red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0)
            @red = red
            @green = green
            @blue = blue
            @alpha = alpha
          end

          def self.parse(_spec)
            new
          end
        end

        class Color
          def self.parse(_spec)
            new
          end
        end

        Event = Gtk::Event
      end

      module GLib
        @sources = {}
        @sources_mutex = Mutex.new
        @source_id = 0

        class << self
          def register_source(thread)
            @sources_mutex.synchronize do
              id = (@source_id += 1)
              @sources[id] = thread
              id
            end
          end

          def remove_source(id)
            thread = @sources_mutex.synchronize { @sources.delete(id) }
            thread&.kill
            !thread.nil?
          end
        end

        module Timeout
          # Repeats +block+ every +interval+ ms on the session thread until it
          # returns false, like GLib::Timeout.add.
          def self.add(interval, &block)
            session = Gtk::Session.current
            id = nil
            thread = Thread.new do
              loop do
                sleep(interval.to_f / 1000.0)
                keep = session.sync { block.call }
                break unless keep
              end
            rescue StandardError
              nil
            ensure
              GLib.remove_source(id) if id
            end
            id = GLib.register_source(thread)
          end

          def self.add_seconds(interval, &block)
            add(interval.to_f * 1000, &block)
          end
        end

        module Idle
          # Runs once on the session thread; re-queues itself while +block+
          # returns true. There is no thread to kill, so the source id maps
          # to nil and Source.remove is a no-op for it.
          def self.add(&block)
            session = Gtk::Session.current
            session.enqueue do
              keep = block.call
              GLib::Idle.add(&block) if keep
            end
            GLib.register_source(nil)
          end
        end

        module Source
          def self.remove(id)
            GLib.remove_source(id)
          end
        end
      end
    end
  end
end
