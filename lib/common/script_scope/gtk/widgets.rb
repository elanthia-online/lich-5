# frozen_string_literal: true

require_relative 'session'

module Lich
  module Common
    module ScriptScope
      # Ruby implementation of the slice of the ruby-gnome GTK 3 API that
      # scripts use, rendered through the WebUI contract. Scripts evaluated in
      # ScriptScope resolve `Gtk` here instead of the real gem.
      #
      # Slice one covers what vars.lic and alias.lic need: Window, Box,
      # Table, Label, Entry, Button, CheckButton, ScrolledWindow, Viewport,
      # MessageDialog, Gtk.queue, the AttachOptions/ResponseType constants,
      # Gdk::Screen, and GLib timers. Anything else logs once and degrades.
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

        # The only field GTK event structs expose that these scripts read.
        Event = Struct.new(:type, :button, :state, :keyval, :x, :y, :direction, :time)

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
        end

        def self.normalize_signal(name)
          name.to_s.tr('-', '_').to_sym
        end

        # ------------------------------------------------------------------
        # Base widget: identity, visibility, sensitivity, signals, and the
        # bookkeeping that materializes it into an adapter node.
        # ------------------------------------------------------------------
        class Widget
          attr_reader :key, :parent, :handle, :session
          attr_accessor :packing

          def initialize
            @key = Gtk.next_key
            @session = Session.current
            @handlers = Hash.new { |hash, signal| hash[signal] = [] }
            @handler_ids = {}
            @handle = nil
            @synced_props = nil
            @bound_events = {}
            @parent = nil
            @visible = true
            @sensitive = true
            @tooltip = nil
            @width_request = nil
            @height_request = nil
            @packing = nil
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

          # Runs the handlers for +signal+ with GTK's (widget, event) shape.
          def emit(signal, *args)
            name = Gtk.normalize_signal(signal)
            result = nil
            @handlers[name].dup.each do |handler|
              result = handler.arity.zero? ? handler.call : handler.call(self, *args)
            end
            result
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
            setter = "#{name.to_s.tr('-', '_')}="
            respond_to?(setter) ? public_send(setter, value) : Gtk.log_unsupported(self.class.name, "set_property(#{name})")
          end

          def method_missing(name, *_args, &_block)
            Gtk.log_unsupported(self.class.name.split('::').last(2).join('::'), name)
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
            props[:width] = @width_request if @width_request
            props[:height] = @height_request if @height_request
            props
          end

          # Creates or updates this widget's adapter node. Returns the handle.
          def materialize!(adapter)
            props = common_props.merge(node_props)
            if @handle.nil?
              @handle = adapter.create(node_type, props)
              @synced_props = props
            elsif props != @synced_props
              (props.keys | @synced_props.keys).each do |name|
                next if props[name] == @synced_props[name]

                adapter.set(@handle, name, props.fetch(name, default_for(name)))
              end
              @synced_props = props
            end
            sync_bindings!(adapter)
            @dirty = false
            @handle
          end

          def release_handle!
            @handle = nil
            @synced_props = nil
            @bound_events = {}
          end

          private

          def default_for(name)
            case name
            when :hidden, :disabled then false
            when :tooltip then ''
            else nil
            end
          end

          def sync_bindings!(adapter)
            window = window_root
            return unless window

            @handlers.each_key do |signal|
              event = event_for(signal)
              next unless event
              next if @bound_events[event]

              widget = self
              @bound_events[event] = adapter.bind(@handle, event, @session.dispatch_proc(window) { |context|
                widget.receive_event(event, context)
              })
            end
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

          def materialize!(adapter)
            handle = super
            desired = ordered_children.select(&:visible?)
            (@synced_children - ordered_children).each do |gone|
              next unless gone.handle

              begin
                adapter.destroy(gone.handle)
              rescue Lich::WebUI::Error
                nil
              end
              gone.release_handle!
            end
            @synced_children &= ordered_children
            unless desired == @synced_children
              @synced_children.each do |child|
                adapter.detach(handle, child.handle) if child.handle
              rescue Lich::WebUI::Error
                nil
              end
              @synced_children = []
            end
            desired.each_with_index do |child, index|
              child_handle = child.materialize!(adapter)
              next if @synced_children[index].equal?(child)

              adapter.attach(handle, child_handle, index)
            end
            @synced_children = desired
            # keep hidden children's own state current without attaching them
            (ordered_children - desired).each { |child| child.materialize!(adapter) if child.handle }
            handle
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

          def homogeneous=(_value); end
          alias set_homogeneous homogeneous=
          def spacing=(value)
            @spacing = value.to_i
            changed!
          end
          alias set_spacing spacing=

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
              count = ordered_children.count(&:visible?)
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

        # Gtk::Table: children carry an attach rectangle; they render into a
        # contract grid in row-major order.
        class Table < Container
          attr_reader :n_rows, :n_columns

          def initialize(rows = 1, columns = 1, _homogeneous = false)
            super()
            @n_rows = [rows.to_i, 1].max
            @n_columns = [columns.to_i, 1].max
            @cells = {}.compare_by_identity
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
            @cells[child] = [top.to_i, left.to_i, bottom.to_i, right.to_i]
            add(child)
          end

          def attach_defaults(child, left, right, top, bottom)
            attach(child, left, right, top, bottom)
          end

          def remove(child)
            @cells.delete(child)
            super
          end

          def ordered_children
            @children.sort_by { |child| @cells.fetch(child, [0, 0]).first(2) }
          end

          def node_type
            :grid
          end

          def node_props
            { cols: @n_columns.clamp(1, 24), gap: 4 }
          end
        end

        class Grid < Container
          def initialize
            super
            @cells = {}.compare_by_identity
            @columns = 1
          end

          def attach(child, left, top, width = 1, height = 1)
            @cells[child] = [top.to_i, left.to_i, width.to_i, height.to_i]
            @columns = [@columns, left.to_i + width.to_i].max
            add(child)
          end

          def remove(child)
            @cells.delete(child)
            super
          end

          def row_spacing=(_value); end
          alias set_row_spacing row_spacing=
          def column_spacing=(_value); end
          alias set_column_spacing column_spacing=

          def ordered_children
            @children.sort_by { |child| @cells.fetch(child, [0, 0]).first(2) }
          end

          def node_type
            :grid
          end

          def node_props
            { cols: @columns.clamp(1, 24), gap: 4 }
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

          def node_type
            :scroll
          end

          def node_props
            window = window_root
            height = window&.default_height
            height ? { max_height: [height - 48, 120].max } : {}
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

        class Frame < Container
          def initialize(label = nil)
            super()
            @label = label.to_s
          end

          def label=(value)
            @label = value.to_s
            changed!
          end
          alias set_label label=

          def set_label_widget(widget)
            @label = widget.respond_to?(:text) ? widget.text.to_s : @label
            changed!
            self
          end

          def node_type
            :group
          end

          def node_props
            { label: @label.empty? ? ' ' : @label }
          end
        end

        # Scroll adjustments: enough state for scripts that read or animate
        # them; writes do not move the browser yet.
        class Adjustment
          attr_accessor :value, :lower, :upper, :page_size, :step_increment, :page_increment

          def initialize(value = 0.0, lower = 0.0, upper = 1000.0, step = 10.0, page_inc = 100.0, page_size = 100.0)
            @value = value.to_f
            @lower = lower.to_f
            @upper = upper.to_f
            @step_increment = step.to_f
            @page_increment = page_inc.to_f
            @page_size = page_size.to_f
          end

          def signal_connect(*_args, &_block)
            0
          end

          def configure(*_args); end
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

          def resize(width, height)
            set_default_size(width, height)
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
        # Leaf widgets
        # ------------------------------------------------------------------
        class Label < Widget
          def initialize(text = nil, _mnemonic = false)
            super()
            @text = text.to_s
            @markup = false
          end

          def text
            @text
          end

          def text=(value)
            @text = value.to_s
            @markup = false
            changed!
          end
          alias set_text text=
          alias label= text=
          alias set_label text=
          alias label text

          def set_markup(markup)
            @text = markup.to_s.gsub(/<[^>]+>/, '').gsub('&amp;', '&').gsub('&lt;', '<').gsub('&gt;', '>')
            @markup = true
            changed!
            self
          end
          alias markup= set_markup

          def use_markup=(_value); end

          def set_alignment(*_args)
            self
          end

          def set_wrap(_value)
            self
          end
          alias wrap= set_wrap
          alias set_line_wrap set_wrap

          def set_selectable(_value)
            self
          end
          alias selectable= set_selectable

          def node_type
            :text
          end

          def node_props
            props = { content: @text.empty? ? ' ' : @text }
            props[:emphasis] = 'subtle' unless @sensitive
            props
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
          def width_chars=(_value); end
          alias set_width_chars width_chars=
          def activates_default=(_value); end
          alias set_activates_default activates_default=
          def set_alignment(_value)
            self
          end

          def grab_focus
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

            value = context.payload && (context.payload[:value] || context.payload['value'])
            @text = value.to_s.dup unless value.nil?
            @synced_props = @synced_props.merge(value: @text.dup) if @synced_props
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

        class CheckButton < Widget
          def initialize(label = nil, **options)
            super()
            @label = options.fetch(:label, label.is_a?(String) ? label : '').to_s
            @active = false
          end

          def label
            @label
          end

          def label=(value)
            @label = value.to_s
            changed!
          end
          alias set_label label=

          def active?
            @active
          end

          def active=(value)
            @active = value ? true : false
            changed!
            @session.viewer_write(window_root, self, :checked, @active) if @handle
          end
          alias set_active active=

          def event_for(signal)
            :change if %i[toggled clicked].include?(signal)
          end

          def node_type
            :checkbox
          end

          def node_props
            props = { label: @label.empty? ? ' ' : @label, checked: @active }
            props[:disabled] = true unless @sensitive
            props
          end

          protected

          def apply_event(event, context)
            return unless event == :change

            value = context.payload && (context.payload.key?(:value) ? context.payload[:value] : context.payload['value'])
            @active = value ? true : false unless value.nil?
            @synced_props = @synced_props.merge(checked: @active) if @synced_props
          end
        end

        class ToggleButton < CheckButton
          def node_type
            :toggle
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
