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
        @dropped = {}

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

          # A widget the contract refused. Unlike an unsupported method, this
          # costs a cell, so it is never deduplicated and it names the key so
          # the widget can be found in the rendered tree.
          def log_render_failure(child, error)
            label = child.respond_to?(:key) ? child.key : nil
            # Deduplicated per widget, not per class: every dropped cell is
            # reported once, but a commit loop does not flood the log.
            key = "#{child.short_class_name}##{label}"
            return if @dropped[key]

            @dropped[key] = true
            message = "webui-gtk-shim: dropped #{child.short_class_name}" + "#{" key=#{label}" if label} from its parent: #{error.message}"
            script = Session.current_script&.name
            message += " script=#{script}" if script
            Lich.log("warning: #{message}") if defined?(Lich) && Lich.respond_to?(:log)
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
              # GTK constructors take arguments and a stub's did not, so a
              # script building one got ArgumentError rather than the empty
              # box this is meant to degrade to -- Gtk::TargetEntry.new(target,
              # flags, info) killed ewaggle's whole window. Accept anything and
              # keep it, since a value object like TargetEntry is read back.
              def initialize(*args, **options)
                super()
                @stub_args = args
                @stub_options = options
              end

              attr_reader :stub_args, :stub_options

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
            # Marks this as generated. const_missing const_sets what it
            # returns, so a file loaded later that defines the real class
            # would reopen this stub rather than replace it; the marker lets
            # that file tell the two apart and discard the stub.
            klass.define_singleton_method(:webui_stub?) { true }
            klass
          end

          # Constants scripts reference that the shim has no implementation
          # for. A widget class degrades to an empty container; anything else
          # (an enum member, a flag) becomes the symbol it was named, since
          # scripts only ever pass those back into methods the shim ignores.
          # Either way the script keeps running and the gap is logged once.
          #
          # The two are not equally harmless, and used to log identically.
          # A missing enum member costs nothing: it is handed straight back
          # to a method the shim ignores. A missing *widget class* costs the
          # script everything it was going to put in that widget -- map's
          # Gtk::Image is the map, and it renders as an empty box with one
          # `warning:` line in a debug file, indistinguishable from the
          # harmless kind. A stubbed widget now says so where the player
          # will see it.
          # Names this shim defines in files loaded after this one. Stubbing
          # any of them would be silently permanent -- const_missing
          # const_sets its answer, so the stub shadows the real class for the
          # rest of the process and renders an empty box. Raising instead
          # says plainly that boot.rb has not finished, rather than papering
          # over it with something that looks like it works.
          OWN_DEFINITIONS = %i[
            Image Layout Fixed
            Menu MenuBar MenuItem CheckMenuItem RadioMenuItem
            SeparatorMenuItem ImageMenuItem
            Paned HPaned VPaned Overlay ListBox ListBoxRow ProgressBar
          ].freeze

          def const_missing(name)
            if OWN_DEFINITIONS.include?(name)
              raise NameError, "Gtk::#{name} is defined by the shim but not loaded yet; " \
                               'require common/script_scope/gtk/boot before using it'
            end

            # A CamelCase name is *usually* a widget class, but not always: a
            # flags or enum namespace looks identical and is only ever read
            # through, never instantiated. Stubbing one as a widget class made
            # `Gtk::TargetFlags::SAME_APP` raise NameError -- a class has no
            # fallback for its own missing constants -- which killed ewaggle
            # at GUI construction, taking with it the row-activated handler it
            # registers a few lines later. Those degrade to a module whose
            # members answer as symbols, exactly as Gdk's fallback does.
            widget = class_name?(name) && !namespace_name?(name)
            value = if widget
                      unimplemented_widget(name)
                    elsif class_name?(name)
                      enum_namespace(name)
                    else
                      name.to_s.downcase.to_sym
                    end
            if widget
              report_stubbed_widget(name)
            else
              log_unsupported('Gtk', name, note: 'constant is not implemented')
            end
            const_set(name, value)
          end

          # A class name rather than an enum member. CamelCase is the usual
          # tell, but GTK also ships acronym-led names -- UIManager,
          # IMContext, RGBA -- and requiring a lowercase second letter sent
          # every one of them to the enum-member fallback, where they became
          # a bare symbol: `Gtk::UIManager.new` then raised NoMethodError on
          # Symbol, which is the uncaught crash this whole path exists to
          # prevent. An enum MEMBER is the thing being distinguished, and
          # those are SCREAMING_SNAKE_CASE, so the test is "not all caps".
          def class_name?(name)
            text = name.to_s
            text.match?(/\A[A-Z]/) && !text.match?(/\A[A-Z0-9_]+\z/)
          end

          # Names that read as a namespace of constants rather than a widget:
          # flags, enums and the target/selection vocabulary drag-and-drop is
          # described with. A script only ever reads a member out of one and
          # hands it back to a method the shim ignores.
          NAMESPACE_SUFFIXES = /(?:Flags|Type|Types|Mode|Modes|Action|Actions|Mask|State|Direction|Priority|Options|Defaults|Style|Policy|Position|Order|Level|Role|Hint|Format|Class|Kind|Target)\z/

          def namespace_name?(name)
            name.to_s.match?(NAMESPACE_SUFFIXES)
          end

          # A stand-in for a constant namespace: any member answers as the
          # symbol it was named, the way Gdk's fallback does, so `A::B` never
          # raises and the value is inert wherever the script passes it.
          def enum_namespace(name)
            namespace = Module.new do
              def self.const_missing(member)
                member.to_s.downcase.to_sym
              end
            end
            namespace.define_singleton_method(:name) { "Gtk::#{name}" }
            namespace.define_singleton_method(:webui_stub?) { true }
            namespace
          end

          # Told once per widget class per session, to the script's own
          # output as well as the log: an empty box on screen is otherwise
          # indistinguishable from a layout bug.
          def report_stubbed_widget(name)
            key = "Gtk::#{name}"
            return if @unsupported[key]

            @unsupported[key] = true
            script = Session.current_script&.name
            detail = "webui-gtk-shim: Gtk::#{name} is not implemented; " \
                     'anything placed in it renders as an empty box'
            detail += " script=#{script}" if script
            Lich.log("warning: #{detail}") if defined?(Lich) && Lich.respond_to?(:log)
            return unless defined?(::Lich::Messaging) || Kernel.respond_to?(:respond, true)

            Kernel.send(:respond, "[#{script || 'gtk'}: Gtk::#{name} is not supported yet -- " \
                                  'that part of the window will be blank]')
          rescue StandardError
            nil
          end

          def normalize_signal(name)
            name.to_s.tr('-', '_').to_sym
          end

          # The symbol a script compares a key event against. A script writes
          # `when Gdk::Keyval::KEY_Left`, and that constant resolves through
          # Gdk.const_missing to `"KEY_Left".downcase.to_sym` => :key_left. The
          # browser sends the GTK keyval name ("Left", "s", "S"), so prefixing
          # "key_" and downcasing reproduces the same symbol exactly -- which
          # is why event.keyval == Gdk::Keyval::KEY_Left is true. KEY_s and
          # KEY_S both collapse to :key_s here as they do through const_missing;
          # a script that must tell them apart reads event.state.shift_mask?.
          def keyval_for(name)
            return nil if name.nil? || name.to_s.empty?

            "key_#{name}".downcase.to_sym
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

        # `alias set_foo foo=` looks like it defines GTK's set_foo, and it
        # does everything except return the right thing. Ruby makes every
        # assignment method evaluate to its argument no matter what the body
        # returns, and an alias of one keeps that rule -- so set_text("hi")
        # answered "hi" rather than the widget. ruby-gnome's set_* return the
        # widget, which is what makes `Gtk::Entry.new.set_text(v)` -- the
        # first line of real work in perfume.lic -- hand back an Entry
        # instead of a String. 829 setters across the shim got this wrong.
        #
        # Declaring them through this helper keeps the one-line spelling at
        # the call site and gives back self.
        module Setters
          def self.extended(base)
            base.extend(ClassMethods)
          end

          module ClassMethods
            # Defines +name+ as a wrapper around the writer +writer+ that
            # returns self, the way ruby-gnome's own set_* do.
            def def_setter(name, writer)
              define_method(name) do |*args|
                public_send(writer, *args)
                self
              end
            end
          end
        end

        # ------------------------------------------------------------------
        # Base widget: identity, visibility, sensitivity, alignment, signals,
        # and the bookkeeping that materializes it into an adapter node.
        # ------------------------------------------------------------------
        class Widget
          extend Setters
          # Builder properties every widget accepts and the shim has no use
          # for. Silently ignored so Glade files do not spam the log.
          IGNORED_BUILDER_PROPERTIES = %w[
            can-focus receives-default draw-indicator border-width label-xalign
            shadow-type yalign sizing search-column
            fixed-height-mode column-homogeneous row-homogeneous max-width-chars
            wrap-mode accepts-tab modal tab-fill numeric digits angle
            activates-default has-frame can-default
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
            # Monotonic: deriving the next id from the hash's size reused a
            # live id after any disconnect, so disconnecting the handler you
            # meant killed a later one instead.
            @handler_id_seq = 0
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
            id = (@handler_id_seq += 1)
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
          def_setter :set_sensitive, :sensitive=

          def sensitive?
            @sensitive
          end

          def visible=(value)
            @visible = value ? true : false
            changed!
          end
          def_setter :set_visible, :visible=

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
          def_setter :set_tooltip_text, :tooltip_text=

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
          def_setter :set_width_request, :width_request=

          def height_request=(height)
            set_size_request(@width_request || -1, height)
          end
          def_setter :set_height_request, :height_request=

          def halign=(value)
            @halign = value.to_s.downcase.to_sym
            changed!
          end
          def_setter :set_halign, :halign=

          def valign=(value)
            @valign = value.to_s.downcase.to_sym
            changed!
          end
          def_setter :set_valign, :valign=

          %i[top right bottom left].each do |side|
            define_method(:"margin_#{side}=") do |value|
              @margins[side] = value.to_i
              changed!
            end
            def_setter :"set_margin_#{side}", :"margin_#{side}="
          end
          alias margin_start= margin_left=
          def_setter :set_margin_start, :margin_left=
          alias margin_end= margin_right=
          def_setter :set_margin_end, :margin_right=

          def margin=(value)
            @margins = { top: value.to_i, right: value.to_i, bottom: value.to_i, left: value.to_i }
            changed!
          end

          # Gtk::Misc#set_padding(xpad, ypad): pads both sides of each axis.
          # Distinct from Alignment#set_padding, which names four edges.
          # Labels in nine scripts space wrapped text this way; without it
          # the padding was recorded nowhere and the blocks ran together.
          def set_padding(xpad, ypad)
            @margins[:left] = @margins[:right] = xpad.to_i
            @margins[:top] = @margins[:bottom] = ypad.to_i
            changed!
            self
          end

          # Grid reads hexpand? at render rather than at attach, precisely
          # because a script may set it afterwards -- so without changed! the
          # widget never became dirty and the column kept its old weight until
          # something else happened to trigger a re-render.
          def hexpand=(value)
            @hexpand = value ? true : false
            changed!
          end
          def_setter :set_hexpand, :hexpand=

          def vexpand=(value)
            @vexpand = value ? true : false
            changed!
          end
          def_setter :set_vexpand, :vexpand=

          def hexpand?
            @hexpand
          end

          # @vexpand was set and never read by anything. The contract has no
          # vertical counterpart to a column's `grow`, so nothing consumes it
          # yet; the reader at least makes the recorded value observable
          # rather than silently dead.
          def vexpand?
            @vexpand
          end

          def xalign=(_value); end
          def_setter :set_xalign, :xalign=

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

          # Focusability is the browser's to decide. Already ignored as a
          # builder property; scripts set it directly too.
          def set_can_focus(_value)
            self
          end
          alias can_focus= set_can_focus

          def can_focus?
            true
          end

          # A widget's on-screen rectangle. Only the browser knows the real
          # one, so this answers with the size the widget asked for, falling
          # back to its window's default -- which is what GTK would report
          # before the first allocation anyway.
          #
          # It has to answer with numbers rather than fall through to
          # method_missing: a script reads `allocation.width` and does
          # arithmetic on it, and nil (or a stub) turns that into a
          # TypeError several frames away from the script line that asked.
          Allocation = Struct.new(:x, :y, :width, :height)

          def allocation
            root = window_root
            Allocation.new(
              0, 0,
              @width_request || root&.default_width || 640,
              @height_request || root&.default_height || 480
            )
          end
          alias get_allocation allocation

          def name=(value)
            @name = value.to_s
          end
          def_setter :set_name, :name=

          def name
            @name
          end

          def grab_focus
            self
          end

          def destroy
            # Only Window set this; every other widget answered destroyed?
            # false forever, and scripts guard cleanup on it at ~50 sites.
            @destroyed = true
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

          # Ruby's conversion and comparison protocol. Answering these at all
          # turns a script's own bug into a baffling one: map.lic does
          # arithmetic on a widget it expected to be a number, and a `coerce`
          # that returns nil raises "coerce must return [x, y]" from deep in
          # Integer#+, naming neither the widget nor the method. Letting them
          # raise NoMethodError names the call site instead.
          PROTOCOL_METHODS = %i[
            coerce to_int to_i to_f to_str to_ary to_a to_hash to_h to_sym to_proc
            + - * / % ** <=> < > <= >= =~ each begin end succ
          ].freeze

          def method_missing(name, *args, &block)
            return super if PROTOCOL_METHODS.include?(name)

            Gtk.log_unsupported(short_class_name, name)
            return self if name.end_with?('=') || name.start_with?('set_')

            nil
          end

          def respond_to_missing?(name, include_private = false)
            return super if PROTOCOL_METHODS.include?(name)

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

          # A viewer-scoped property (checked, value, open, selected) has a
          # per-viewer copy that shadows the shared prop, so re-rendering
          # alone changes nothing the browser shows: the viewer's own copy
          # wins. The write has to be pushed to every attached viewer as
          # well. That pairing was hand-copied at ten sites and forgotten at
          # five -- radio buttons, radio menu items, Menu#popdown, Adjustment
          # and ComboBox -- each a separate user-visible bug with one cause.
          # One method, so it cannot be half-copied again.
          def viewer_push(name, value)
            changed!
            @session.viewer_write(window_root, self, name, value) if @handle
            value
          end

          def common_props
            props = { key: @key }
            props[:hidden] = true unless @visible
            # GTK help text can exceed the contract's short-text bound. Keep
            # the widget renderable while preserving its full native tooltip.
            props[:tooltip] = @tooltip[0, Lich::WebUI::Contract::BOUNDS[:short_text]] if @tooltip && !@tooltip.empty?
            # GTK's size request is a minimum that layout grows past; the
            # contract's width/height are fixed. Only widgets whose natural
            # size really is the request (inputs, views) pass it through;
            # for boxes, tables, frames and labels a fixed size would clip
            # content or stretch rows across dead space.
            props[:width] = @width_request if @width_request && size_request_axes.include?(:width)
            props[:height] = @height_request if @height_request && size_request_axes.include?(:height)
            props[:align] = ALIGN_TO_CONTRACT[@halign] if @halign && ALIGN_TO_CONTRACT[@halign]
            margin = contract_margin
            props[:margin] = margin if margin
            props
          end

          # GTK sets one edge at a time, so collapsing the four to their max
          # put a one-sided indent on all four sides -- bigshot has 518
          # one-sided margins and came out spread across the window. Sends a
          # plain integer when every side agrees, which is most widgets.
          def contract_margin
            sides = @margins.transform_values { |value| value.to_i.clamp(0, 512) }
            return nil if sides.values.all?(&:zero?)
            return sides.values.first if sides.values.uniq.size == 1

            sides.reject { |_side, value| value.zero? }
          end

          # Creates or updates this widget's adapter node. Returns the handle.
          def materialize!(adapter)
            props = filter_props(common_props.merge(node_props))
            # A node's type is fixed once created, but a script can change
            # what a widget IS after the fact -- an Entry becomes a password
            # field the moment visibility is turned off, which the login GUI
            # does after building the entry. Rebuild rather than leave a
            # password showing in a text box.
            retype!(adapter) if @handle && @synced_type && @synced_type != node_type
            if @handle.nil?
              @handle = adapter.create(node_type, props)
              @synced_props = props
              @synced_type = node_type
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
            @synced_type = nil
            @bound_events = {}
            # A new handle needs its presentation reader registered again.
            @presentation_registered = false
            @synced_presentation = nil
          end

          # Drops this widget's node so the next commit builds it again with
          # the type it now reports. The parent re-attaches it in place,
          # because it is still in the parent's child list.
          def retype!(adapter)
            handle = @handle
            release_handle!
            @parent.forget_child_handle(self) if @parent.respond_to?(:forget_child_handle)
            begin
              adapter.destroy(handle)
            rescue Lich::WebUI::Error
              nil
            end
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
            # Handle last attached per child, so a child that rebuilds its
            # node is re-attached rather than silently orphaned.
            @synced_handles = {}.compare_by_identity
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
                # A dropped child is not cosmetic in a grid: every later cell
                # shifts into the hole it left, so the whole table comes out
                # transposed. Logged every time rather than once per class,
                # because the second occurrence is the one that explains a
                # layout nobody can account for.
                Gtk.log_render_failure(child, error)
                next
              end
              # Compared after materializing, not before: a child that
              # rebuilt its node -- an Entry becoming a password field --
              # is in @synced_children but its handle is new, and skipping
              # the attach would leave the replacement parentless.
              already = @synced_children.include?(child) && @synced_handles[child].equal?(child_handle)
              adapter.attach(handle, child_handle, attached.length) unless already
              @synced_handles[child] = child_handle
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

          # A child that rebuilt its node is no longer attached to ours, so
          # forget it and let the next commit attach the replacement.
          def forget_child_handle(child)
            @synced_handles.delete(child)
            changed!
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
          def_setter :set_homogeneous, :homogeneous=

          def spacing=(value)
            @spacing = value.to_i
            changed!
          end
          def_setter :set_spacing, :spacing=

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

          def common_props
            props = super
            # vars.lic builds its label cell as a horizontal box with a lone
            # pack_end label, which GTK renders against the right edge. With
            # no second child there is no track to stretch, so the box itself
            # carries the alignment.
            if @orientation == :horizontal && !@halign && all_packed_end?(render_children)
              props[:align] = 'end'
            end
            props
          end

          # Packing reaches the contract two ways: along a vertical box as
          # child placement (grow/pad), and along a horizontal one as the
          # columns weights, which is what that type has instead.
          def render_children
            children = super
            children.each do |child|
              packing = child.packing
              placement = {}
              if packing
                placement[:grow] = 1 if @orientation == :vertical && packing[:expand]
                placement[:pad] = [packing[:padding], 512].min if packing[:padding].positive?
              end
              child.placement = placement if @orientation == :vertical || placement[:pad]
            end
            children
          end

          def node_props
            if @orientation == :vertical
              { gap: [@spacing, 64].min }
            else
              children = render_children
              props = { count: children.length.clamp(1, 12), gap: [@spacing, 64].min }
              # GTK shares leftover width among the children packed to
              # expand; one packed without it keeps its natural width. A
              # weight of 0 is the contract's way of saying natural.
              # hexpand is the other way a child claims the free width, and
              # it is how bigshot pushes its Close button to the right edge:
              # packed non-expanding, but hexpand with halign end.
              weights = children.first(12).map do |child|
                next 1 if child.respond_to?(:hexpand?) && child.hexpand?

                child.packing&.fetch(:expand, true) == false ? 0 : 1
              end
              # With nothing expanding, GTK still has free space to place:
              # pack_start children hug the near edge and pack_end children
              # the far one. Without a stretch between the groups they all
              # clump at the start -- which is why vars.lic's labels, packed
              # end so they sit against their entry, came out left aligned.
              if weights.all?(&:zero?) && (gap_at = trailing_gap_index(children))
                weights = weights.dup
                weights[gap_at] = 1
              end
              props[:weights] = weights if weights.any?(&:zero?)
              props
            end
          end

          private

          # Where the free space falls when nothing expands: before the first
          # pack_end child. nil when the box is all starts or all ends, since
          # then GTK has no split to honor and the children simply sit at
          # their edge.
          def trailing_gap_index(children)
            return nil if @end_children.empty?

            first_end = children.index { |child| @end_children.include?(child) }
            return nil if first_end.nil? || first_end.zero? || first_end > 11

            first_end
          end

          # A box whose children are *all* packed end has no column to widen
          # -- the free space falls before the first of them, outside any
          # child. The contract says that with alignment on the box itself.
          def all_packed_end?(children)
            return false if children.empty?

            children.all? do |child|
              # An expanding child already fills the box; aligning to the end
              # would shrink it to its content instead.
              @end_children.include?(child) && child.packing&.fetch(:expand, true) == false
            end
          end

          # GTK's pack_start(child, expand = true, fill = true, padding = 0),
          # in every spelling scripts use. The positional form is the GTK 2 C
          # API, where the flags are integers: 0 is false there, but truthy in
          # Ruby, so they are read as numbers when given as numbers.
          def packing_from(positional, options)
            expand, fill, padding = positional
            {
              expand: packing_flag(options.fetch(:expand, expand), default: true),
              fill: packing_flag(options.fetch(:fill, fill), default: true),
              padding: options.fetch(:padding, padding || 0).to_i,
            }
          end

          def packing_flag(value, default:)
            case value
            when nil then default
            when Integer then !value.zero?
            else value ? true : false
            end
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

          # Columns a child asked to expand into, by left edge. GTK's default
          # is not to expand, so a table with no EXPAND anywhere keeps every
          # column at natural width.
          def expanding_columns
            @expanding_columns ||= {}
          end

          # Per-column share of the leftover width. nil when nothing expands,
          # so the contract prop stays absent and the client keeps `auto`.
          def column_weights
            cols = column_count
            expanding = expanding_columns.keys.select { |column| column < cols }
            return nil if expanding.empty?

            Array.new(cols) { |column| expanding.include?(column) ? 1 : 0 }
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

          def attach(child, left, right, top, bottom, xoptions = nil, _yoptions = nil, _xpadding = 0, _ypadding = 0)
            cells[child] = [left.to_i, top.to_i, [right.to_i - left.to_i, 1].max, [bottom.to_i - top.to_i, 1].max]
            # Gtk::EXPAND in the x options is the only place a Table says
            # which column should take the free width -- the label column
            # beside an entry says nothing and must stay natural.
            expanding_columns[left.to_i] = true if expand?(xoptions)
            add(child)
          end

          def expand?(options)
            options.is_a?(Integer) && (options & AttachOptions::EXPAND).positive?
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
            props = { cols: column_count, gap: 4 }
            weights = column_weights
            props[:weights] = weights if weights
            props
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

          # Gtk::Grid has no attach options; a child asks for the free width
          # with hexpand, and it can be set after attaching, so this is read
          # at render rather than recorded at attach.
          def expanding_columns
            @children.each_with_object({}) do |child, result|
              next unless child.respond_to?(:hexpand?) && child.hexpand?

              result[cells.fetch(child, [0, 0, 1, 1]).first] = true
            end
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
          def_setter :set_row_spacing, :row_spacing=

          def column_spacing=(value)
            @column_spacing = value.to_i
            changed!
          end
          def_setter :set_column_spacing, :column_spacing=

          def column_count
            cols = @children.map { |child| rect = cells.fetch(child, [0, 0, 1, 1]); rect[0] + rect[2] }.max || 1
            cols.clamp(1, 24)
          end

          def node_type
            :grid
          end

          def node_props
            props = { cols: column_count, gap: [[@row_spacing, @column_spacing].max, 64].min }
            weights = column_weights
            props[:weights] = weights if weights
            props
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
            @vadjustment.watch(self)
            @hadjustment.watch(self)
          end

          attr_reader :vadjustment, :hadjustment

          # The viewer is the only side that knows the scroll extent, so the
          # `scrolled` event feeds `upper` and `page_size` back into the
          # adjustment. Scripts read those to compute a target (`upper -
          # page_size` is the scroll-to-bottom idiom in vars, alias and
          # localchat) and the arithmetic is nonsense against the defaults.
          def always_bound_events
            [:scrolled]
          end

          def receive_event(event, context)
            return super unless event == :scrolled

            payload = context.payload || {}
            fetch = ->(name) { payload[name] || payload[name.to_s] }
            # A script that centred its viewport before the viewer had ever
            # reported one computed against the window's default size, not the
            # real pane, and landed half the difference away -- map opened
            # uncentred and only came right on the first walk. Notice the
            # first real extent and let the script place itself again now that
            # allocation tells the truth.
            # Only the very first report, and only the one the client sends
            # after laying out -- which is still at the origin. Once the viewer
            # has actually scrolled somewhere, their position wins and a
            # pending request is theirs to cancel, not ours to replay.
            first_extent = !@viewport_known && fetch.call(:page_size).to_i.positive? &&
                           fetch.call(:position).to_i.zero? && fetch.call(:position_x).to_i.zero?
            @vadjustment.note_viewport(
              value: fetch.call(:position), upper: fetch.call(:upper),
              page_size: fetch.call(:page_size)
            )
            # 2.13: the horizontal axis. GTK's Adjustment is per-axis, and a
            # script reading hadjustment.value to translate a click was
            # reading a constructor default until the viewer reported one.
            @hadjustment.note_viewport(
              value: fetch.call(:position_x), upper: fetch.call(:upper_x),
              page_size: fetch.call(:page_size_x)
            )
            @viewport_known = true if fetch.call(:page_size).to_i.positive?
            replay_centre_request if first_extent
            @centre_request = nil unless first_extent
            super
          end

          # Whether the viewer has ever reported how big this pane really is.
          def viewport_known?
            @viewport_known ? true : false
          end

          # Re-centre on whatever the script was aiming at, now that the pane's
          # real size is known. The script computed `target = point -
          # viewport / 2` against allocation, which until now answered with the
          # window's default size; recovering the point it meant and redoing
          # the arithmetic puts the map where it always intended to be.
          def replay_centre_request
            return unless @centre_request

            x, y = @centre_request
            @centre_request = nil
            centre_viewport_on(x, y)
          end

          # The point a script centred on, recovered from the offset it asked
          # for and the viewport size it believed in at the time.
          def note_centre_request(guessed_width, guessed_height)
            return if @viewport_known

            x = @hadjustment.requested_value
            y = @vadjustment.requested_value
            # A script clamps its own target to `upper - page_size`, and before
            # the viewer reports, that is the constructor's 100. An offset
            # sitting on that stale extent is not the point the script meant --
            # it is whatever was left after the clamp ate it -- so there is
            # nothing to recover and nothing to replay.
            x = nil if x && @hadjustment.at_extent?
            y = nil if y && @vadjustment.at_extent?
            return unless x || y

            @centre_request = [
              x ? x + (guessed_width / 2) : nil,
              y ? y + (guessed_height / 2) : nil,
            ]
          end

          def centre_viewport_on(x, y)
            width = @hadjustment.page_size
            height = @vadjustment.page_size
            if x && width.positive?
              max = [@hadjustment.upper - width, 0].max
              @hadjustment.value = (x - (width / 2)).clamp(0, max)
            end
            return unless y && height.positive?

            max = [@vadjustment.upper - height, 0].max
            @vadjustment.value = (y - (height / 2)).clamp(0, max)
          end

          # GTK's policy is per-axis, but the contract's `scrollbars` facility
          # is one switch for the page, and a script that hides one axis is
          # hiding the furniture rather than the other axis' bar -- map's "Hide
          # Scrollbars" sets both to NEVER together. Treated as hidden when
          # neither axis wants a bar.
          def set_policy(horizontal, vertical)
            @scrollbars_hidden = [horizontal, vertical].all? { |policy| policy.to_s.downcase == 'never' }
            changed!
            self
          end

          def scrollbars_hidden?
            @scrollbars_hidden ? true : false
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

          # The viewer reports its real extent through the `scrolled` event,
          # and that is the only true viewport size the shim ever sees. A
          # script centring on a point computes `x - viewport_width / 2`, so
          # answering with the window's size instead puts the target off by
          # half the difference -- map opened on a corner of empty canvas
          # with the room 800px away.
          #
          # Falls back to Widget#allocation until the first report.
          def allocation
            reported_width = @hadjustment.page_size.to_i
            reported_height = @vadjustment.page_size.to_i
            return super unless reported_width.positive? || reported_height.positive?

            base = super
            Allocation.new(
              0, 0,
              reported_width.positive? ? reported_width : base.width,
              reported_height.positive? ? reported_height : base.height
            )
          end

          def size_request_axes
            parent.is_a?(Window) ? [] : [:height]
          end

          def node_props
            props = {}
            # A scroller filling its window is sized by the stylesheet, which
            # tracks the viewport ("height: calc(100vh - 12px)" on a bare
            # page's own scroll child). Sending max_height too pinned it to a
            # pixel count taken from the startup default size: the interior
            # never grew when the window was resized, and when the window
            # opened smaller than that number the page scrolled as well as the
            # scroller, which is the second scrollbar. A nested scroller has no
            # such rule and still needs the bound.
            unless parent.is_a?(Window)
              height = window_root&.default_height
              props[:max_height] = [height - 48, 120].max if height
            end
            position = scroll_position
            props[:scroll_position] = position if position
            props
          end

          # scroll_position is viewer-scoped, and a viewer-scoped prop is
          # seeded into the viewer's overlay once and never again: ViewerStore
          # writes it `unless attachment.values.key?(key)`, and from then on
          # serialize_component returns the viewer's stale copy. Re-rendering
          # therefore could not move a scroller a second time -- map centred on
          # the room once and every later walk was silently discarded, which
          # the viewer saw as the map snapping back to the corner.
          #
          # Adjustment#notify_owners calls this when an owner defines it and
          # otherwise only calls changed!, which is exactly the path that died.
          # viewer_push writes through to each attached viewer, overriding the
          # seed, the same way a SpinButton pushes its value.
          def adjustment_moved
            # Before the viewer has reported its size, remember what the script
            # was aiming at: allocation is answering with the window default,
            # so the offset it just computed is off by half the error. The
            # first real extent replays it.
            unless viewport_known?
              base = Widget.instance_method(:allocation).bind_call(self)
              note_centre_request(base.width, base.height)
            end
            position = scroll_position
            return changed! unless position

            viewer_push(:scroll_position, position)
          end

          private

          # A script writing `value = upper - page_size` means "the bottom",
          # not a pixel offset -- it derived the number from an extent only
          # the viewer knows. Pass the intent instead, so the browser scrolls
          # to the real bottom however tall the content turned out to be.
          def scroll_position
            vertical = @vadjustment.requested_value
            horizontal = @hadjustment.requested_value
            return nil unless vertical || horizontal

            position = {}
            position[:bottom] = true if @vadjustment.at_extent?
            position[:y] = clamp_offset(vertical) if vertical && !position[:bottom]
            position[:x] = clamp_offset(horizontal) if horizontal
            # Before the viewer has reported an extent, `upper - page_size` is
            # the constructor's 100. A log window writing exactly that means
            # "the bottom" and is honoured as intent. But a script clamping a
            # much larger target to that stale ceiling lands on it by
            # arithmetic, not by intent, and sending the leftover pixel moves
            # the viewer somewhere nobody asked for -- on map's expanded
            # canvas, into the empty quadrant, which reads as a window with no
            # map in it. Only the horizontal half gives the two apart: a log
            # window never asks for one, so an offset on both axes against a
            # guessed extent is a centring that has been clamped to nothing.
            return nil if !viewport_known? && position[:bottom] && position[:x]

            position.empty? ? nil : position
          end

          def clamp_offset(value)
            [[value.to_i, 0].max, 65_535].min
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
            padding = @padding.transform_values { |value| value.to_i.clamp(0, 512) }
            unless padding.values.all?(&:zero?)
              props[:margin] = if padding.values.uniq.size == 1
                                 padding.values.first
                               else
                                 padding.reject { |_side, value| value.zero? }
                               end
            end
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
          def_setter :set_label, :label=

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
          extend Setters
          EXTENT_EPSILON = 0.5

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
            @requested_value = nil
          end

          def watch(owner)
            @owners << owner unless @owners.include?(owner)
          end

          # Whether the script has written a value we have not yet rendered.
          # nil means it never did, so the scroll node stays silent rather
          # than pinning the viewer to the top on every commit.
          attr_reader :requested_value

          # True when the last written value sat at the bottom of the range,
          # which is how a script spells "scroll to the end". This holds
          # against the constructor defaults too: a script that computes
          # `upper - page_size` before the viewer has reported an extent still
          # means the bottom, and the default-derived pixel value (100) would
          # be a worse answer than the intent.
          # "value = upper - page_size" is how a log window spells "the
          # bottom": the number is derived from the extent, so it means the
          # end of the content however tall that turns out to be. A number the
          # script worked out for itself means the pixel it says, even when it
          # happens to sit past the extent we currently believe in.
          #
          # Telling them apart by magnitude alone is what broke map: against
          # the constructor's 100/0 every offset past 99 looked like "the
          # bottom", so centring on a room at y=900 was rewritten to "scroll
          # to the end" and parked the map at the foot of the canvas. So the
          # test is whether the write actually landed on the extent, which a
          # derived one does exactly and a coincidental one only does when it
          # genuinely is the bottom.
          def at_extent?
            return false unless @requested_value
            # Past the extent is a pixel the script computed against a bigger
            # canvas than we know about, not a request for the end.
            return false if @requested_value > (@upper - @page_size) + EXTENT_EPSILON

            @requested_value >= (@upper - @page_size) - EXTENT_EPSILON
          end

          # The viewer reporting where it actually is, and how big the content
          # turned out to be. This is the only source of a true extent.
          def note_viewport(value: nil, upper: nil, page_size: nil)
            @upper = upper.to_f if upper
            @page_size = page_size.to_f if page_size
            if value
              @value = value.to_f
              @requested_value = nil
            end
            self
          end

          %i[lower upper page_size step_increment page_increment].each do |attribute|
            define_method(:"#{attribute}=") do |number|
              instance_variable_set(:"@#{attribute}", number.to_f)
              notify_owners
            end
            alias_method :"set_#{attribute}", :"#{attribute}="
          end

          # Recorded as a request, not just shadow state: a ScrolledWindow
          # turns it into a scroll_position prop on the next commit.
          def value=(number)
            @value = number.to_f
            @requested_value = @value
            notify_owners
          end
          def_setter :set_value, :value=

          def configure(value, lower, upper, step, page_inc, page_size)
            @value = value.to_f
            @requested_value = @value
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

          # An owner whose value is viewer-scoped (SpinButton) has to push it,
          # not just re-render: `spin.adjustment.value = x` bypassed the
          # owner's own setter and the viewer kept the old number.
          def notify_owners
            @owners.each do |owner|
              if owner.respond_to?(:adjustment_moved)
                owner.adjustment_moved
              elsif owner.respond_to?(:changed!)
                owner.changed!
              end
            end
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
          def_setter :set_title, :title=

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

          # The four presentation properties. Kept as shadow state because
          # scripts read them back -- creaturebar persists `decorated?` to
          # its config file -- and declared to the viewer through the
          # `presentation` facility, which refuses what a browser cannot do
          # and records the refusal as a degradation.
          def set_keep_above(value)
            @keep_above = value ? true : false
            changed!
            self
          end
          alias keep_above= set_keep_above

          def keep_above?
            @keep_above ? true : false
          end

          def set_resizable(value)
            @resizable = value ? true : false
            changed!
            self
          end
          alias resizable= set_resizable

          def resizable?
            @resizable.nil? ? true : @resizable
          end
          alias resizable resizable?

          def set_decorated(value)
            @decorated = value ? true : false
            changed!
            self
          end
          alias decorated= set_decorated

          def decorated?
            @decorated.nil? ? true : @decorated
          end
          alias decorated decorated?

          # GTK takes 0.0 to 1.0; the contract's floor is 0.1, because a
          # browser window at 0 is still there and still takes the clicks.
          # creaturebar spells "hide" as set_opacity(0.0), so that case
          # degrades to the floor and is reported rather than silently
          # rounded -- the honest answer is that the browser cannot vanish
          # a window this way.
          def set_opacity(value)
            @opacity = value.to_f.clamp(0.0, 1.0)
            changed!
            self
          end
          alias opacity= set_opacity

          def opacity
            @opacity.nil? ? 1.0 : @opacity
          end

          # Handles are opaque, so the adapter cannot find this widget from
          # its node; the window hands over a reader instead, once.
          def materialize!(adapter)
            handle = super
            if handle && !@presentation_registered && adapter.respond_to?(:presentation_source)
              window = self
              adapter.presentation_source(handle) { window.presentation }
              @presentation_registered = true
            end
            # Presentation is a facility, not a prop, so the base materialize
            # sees nothing to update when only opacity moved.
            if handle && @synced_presentation != presentation
              @synced_presentation = presentation
              adapter.refresh_facilities(handle) if adapter.respond_to?(:refresh_facilities)
              # keep_above and opacity belong to the OS window, which the page
              # cannot reach; the session carries them there if this host can.
              @session.apply_window_presentation(self)
            end
            handle
          end

          # What the `presentation` facility should say, or nil when the
          # script never asked for anything.
          def presentation
            facility = {}
            facility[:always_on_top] = true if @keep_above
            facility[:borderless] = true if @decorated == false
            facility[:opacity] = @opacity.clamp(0.1, 1.0) if @opacity && @opacity < 1.0
            # `resizable` has no presentation field: a browser tab cannot
            # refuse a resize anyway. Kept as readable shadow state only.
            #
            # `scrollbars` is about the page's own scrollbars, which is
            # exactly what a script means by set_policy(:never, :never) -- it
            # is asking for the furniture to go away, and only the page can do
            # that. Reported as false so the client hides them.
            facility[:scrollbars] = false if scrollbars_hidden?
            facility.empty? ? nil : facility
          end

          # True when every scroller in this window has been told to show no
          # bars. A window whose scrollers disagree keeps them, since the
          # facility is one switch for the whole page.
          def scrollbars_hidden?
            scrollers = []
            collect_scrollers(self, scrollers)
            !scrollers.empty? && scrollers.all?(&:scrollbars_hidden?)
          end

          # respond_to? answers true for everything on a Widget, so the test
          # has to be what the widget IS, not what it claims to answer.
          def collect_scrollers(widget, found)
            found << widget if widget.is_a?(ScrolledWindow)
            return unless widget.is_a?(Container)

            widget.children.each { |child| collect_scrollers(child, found) }
          end
          private :collect_scrollers

          def modal=(_value); end
          def_setter :set_modal, :modal=

          def move(_x, _y)
            self
          end

          def position
            [0, 0]
          end

          def allocation
            Allocation.new(0, 0, @default_width || 640, @default_height || 480)
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

          # The browser window, which opens at the size GTK would have used:
          # the default, or the size request when that is larger.
          def browser_geometry
            width = [@default_width, @width_request].compact.max
            height = [@default_height, @height_request].compact.max
            return nil unless width && height

            { width: width, height: height }
          end

          # Window signals are lifecycle, not component events; the session
          # binds them on the page itself. The exception is key-press-event
          # (2.14): a window that connects it opts into page-level key events,
          # which the session binds beside the other lifecycle signals.
          def event_for(*)
            nil
          end

          # True once a script has connected key-press-event. Read at bind time
          # (session) and at render (node_props) so the prop and the binding
          # go together -- the validator refuses a `key` event on a page that
          # did not ask for it, exactly as a composite opts into surface_events.
          def key_wanted?
            @handlers.key?(:key_press_event)
          end

          # A browser keydown arrived on the page root. Rebuild the Gdk-shaped
          # event a GTK key handler expects and emit key-press-event to the
          # script's own handlers, trimmed to each block's arity.
          def receive_key(context)
            payload = context.payload || {}
            keyval = Gtk.keyval_for(payload[:keyval] || payload['keyval'])
            modifiers = Array(payload[:modifiers] || payload['modifiers']).map(&:to_s)
            state = ModifierState.new(modifiers.include?('ctrl'), modifiers.include?('shift'), modifiers.include?('alt'))
            gdk = Event.new(:key_press, nil, state, keyval, nil, nil, nil,
                            Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond))
            emit(:key_press_event, gdk)
          end

          def node_type
            :page
          end

          def node_props
            props = { title: @title.empty? ? 'Lich' : @title, bare: true }
            # GTK opens a window at its default size but never smaller than
            # its size request, and the two disagree: eloot asks for a
            # default of 800 and a minimum of 900, so it opened clipped.
            width = [@default_width, @width_request].compact.max
            height = [@default_height, @height_request].compact.max
            props[:size] = [width, height] if width && height
            # The prop and the key binding go together: the validator refuses a
            # `key` event unless the page declares it wants them.
            props[:key_events] = true if key_wanted?
            props
          end

          def common_props
            { key: @key }
          end
        end

        # Stock button labels. Without this, const_missing turned `Stock` into
        # an empty widget class and `Gtk::Stock::OK` raised NameError -- which
        # is where map's room-list dialog died.
        module Stock
          OK = 'OK'
          CANCEL = 'Cancel'
          YES = 'Yes'
          NO = 'No'
          CLOSE = 'Close'
          APPLY = 'Apply'
          SAVE = 'Save'
          OPEN = 'Open'
          ADD = 'Add'
          DELETE = 'Delete'
          EDIT = 'Edit'
          REFRESH = 'Refresh'
          QUIT = 'Quit'
          HELP = 'Help'
        end

        # A custom dialog: a window with a content area and a row of response
        # buttons, whose `run` blocks the caller until one is pressed.
        #
        # GTK's gtk_dialog_run is a recursive main loop: it blocks the script
        # while still servicing events, which is how the button it is waiting
        # on can ever be pressed. The shim does the same. When `run` is called
        # on the session thread -- creaturebar calls it from a button handler
        # -- it pumps the session's own queue until a response arrives. Off
        # that thread it simply waits, because the session thread is free.
        #
        # The response returned is the very object the script gave
        # add_button, so creaturebar's `:ok` and map's `Gtk::ResponseType::OK`
        # both compare equal to what they passed in.
        class Dialog < Window
          # rubocop:disable Lint/UnusedMethodArgument -- parent and flags are
          # Gtk::Dialog.new's own keywords. Scripts pass them, and accepting
          # and ignoring them is the degradation; dropping them from the
          # signature would make those calls raise instead.
          def initialize(title: nil, parent: nil, flags: nil, buttons: nil, **_options)
            # to_s: a nil title would reach the page as a nil prop. Lich's
            # NilClass patch answers nil.empty? with nil, so node_props' own
            # guard would let it through and the page fail validation.
            super(title.to_s)
            @content = VBox.new
            @actions = HBox.new
            @responses = Queue.new
            @response = nil
            Container.instance_method(:add).bind_call(self, @content)
            Container.instance_method(:add).bind_call(self, @actions)
            Array(buttons).each { |(label, response)| add_button(label, response) }
          end
          # rubocop:enable Lint/UnusedMethodArgument

          def content_area
            @content
          end
          alias child content_area
          alias vbox content_area

          def action_area
            @actions
          end

          # A script's `dialog.add(widget)` means the content area, not a
          # third top-level child beside the buttons.
          def add(child)
            @content.add(child)
            self
          end

          def add_button(label, response)
            button = Button.new(label.to_s)
            dialog = self
            button.signal_connect(:clicked) { dialog.respond(response) }
            @actions.add(button)
            changed!
            button
          end

          def add_action_widget(widget, response)
            dialog = self
            widget.signal_connect(:clicked) { dialog.respond(response) } if widget.respond_to?(:signal_connect)
            @actions.add(widget)
            self
          end

          def set_default_response(_response)
            self
          end
          alias default_response= set_default_response

          def respond(response)
            @response = response
            @responses << response
            emit(:response, response)
            self
          end
          alias response respond

          def run
            show unless @shown
            @response = nil
            if @session.on_session_thread?
              @session.commit
              @session.pump(0.05) until @response || destroyed?
              @response || ResponseType::DELETE_EVENT
            else
              @session.enqueue { @session.commit }
              @responses.pop
            end
          end

          def destroy
            release_waiters
            super
          end

          # The viewer closing the tab is the ordinary way a dialog goes
          # away, and it arrives here -- not through browser_exited, which
          # only fires when the whole browser dies. Without this, `run`
          # waited on a queue nobody would ever push to: a plain
          # confirmation dialog with no :delete_event handler hung the
          # script forever. The base class emits :delete_event; the waiters
          # have to be let go too.
          def viewer_closed
            return if @delete_emitted || destroyed?

            super
            release_waiters
          end

          def browser_exited
            release_waiters
            super
          end

          private

          # Unblocks every thread parked in #run. A single push only wakes
          # one consumer, so concurrent callers each need their own.
          def release_waiters
            @destroyed = true
            waiting = @responses.num_waiting
            (waiting.positive? ? waiting : 1).times do
              @responses << ResponseType::DELETE_EVENT
            end
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
          def_setter :set_text, :text=
          alias label= text=
          def_setter :set_label, :text=
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
          def_setter :set_use_markup, :use_markup=

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
          def_setter :set_xalign, :xalign=

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
          def_setter :set_width_chars, :width_chars=
          alias max_width_chars= width_chars=
          def_setter :set_max_width_chars, :width_chars=

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
            viewer_push(:value, @text)
          end
          def_setter :set_text, :text=

          def editable=(value)
            @editable = value ? true : false
            changed!
          end
          def_setter :set_editable, :editable=

          def size_request_axes
            [:width]
          end

          # Approximates GTK's character-width sizing in pixels.
          def width_chars=(chars)
            set_size_request((chars.to_i * 8) + 24, @height_request || -1) if chars.to_i.positive?
          end
          def_setter :set_width_chars, :width_chars=

          def editable?
            @editable
          end

          def placeholder_text=(value)
            @placeholder = value&.to_s
            changed!
          end
          def_setter :set_placeholder_text, :placeholder_text=

          def max_length=(value)
            @max_length = value.to_i.positive? ? value.to_i : nil
            changed!
          end
          def_setter :set_max_length, :max_length=

          # GTK has no password widget: an Entry with visibility off is one.
          # This was a no-op, so Lich's own login GUI -- which sets it on
          # eight entries, including the master password -- rendered every
          # one of them as a plain text box that shows what is typed, keeps
          # it in the page's value, and offers it to the browser's form
          # autofill. The contract has password_input, whose `sensitive`
          # flag is forced true, so the value is never echoed back to a
          # viewer or written to a golden.
          def visibility=(value)
            visible = value ? true : false
            return if @visibility == visible

            @visibility = visible
            changed!
          end
          def_setter :set_visibility, :visibility=

          def visibility?
            @visibility != false
          end

          def set_alignment(_value)
            self
          end

          def event_for(signal)
            mapped = case signal
                     when :changed then :change
                     when :activate then :submit
                     when :focus_in_event then :focus
                     when :focus_out_event then :blur
                     end
            # A script's `changed` handler cannot fire on a password field:
            # the contract gives password_input no `change` event, because a
            # value that is never echoed back has nothing to report on every
            # keystroke. Dropping the mapping keeps the binding out of the
            # node rather than having the adapter refuse the whole widget.
            return nil if mapped == :change && !visibility?

            mapped
          end

          # A password_input has only `submit`: the contract gives it no
          # `change` event, because a value that is never echoed back has
          # nothing to report on every keystroke.
          def always_bound_events
            visibility? ? [:change] : []
          end

          def node_type
            visibility? ? :text_input : :password_input
          end

          def node_props
            props = {}
            # A password_input carries no `value` property at all: the
            # contract makes its value sensitive and write-only, so what the
            # viewer types is never echoed back. Sending one is refused, and
            # sending one would be the leak this type exists to prevent.
            props[:value] = @text.dup if visibility?
            props[:disabled] = true unless @sensitive && @editable
            props[:placeholder] = @placeholder if @placeholder && !@placeholder.empty?
            props[:max_length] = @max_length if @max_length
            props
          end

          protected

          # `submit` carries the value too, and for a password field it is
          # the only event that does -- password_input has no `change`, so
          # without this the script's activate handler read an empty string
          # and the typed password was lost on the way in as well as kept
          # off the way out.
          def apply_event(event, context)
            return unless %i[change submit].include?(event)

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
          def_setter :set_label, :label=

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
            viewer_push(:checked, @active)
          end
          def_setter :set_active, :active=

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

          # The deselected sibling's `checked` is viewer-scoped, so a plain
          # changed! left the viewer's copy checked: two radios lit at once.
          def deactivate_quietly
            @active = false
            viewer_push(:checked, false)
          end
        end

        # ------------------------------------------------------------------
        # Modal dialogs. Not widgets in the tree: a run maps to a contract
        # modal and blocks the session thread until the viewer answers.
        # ------------------------------------------------------------------
        class MessageDialog
          extend Setters
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
          def_setter :set_secondary_text, :secondary_text=

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
        # Gdk had no fallback, while Gtk has had one since slice one. A name
        # it does not implement raised NameError instead of degrading, and
        # because map.lic reaches for Gdk::WindowTypeHint::UTILITY in the
        # first call of its constructor, on Linux the whole map window failed
        # to build rather than losing one window-manager hint.
        #
        # Enum members become the symbol they were named, as Gtk's do;
        # scripts only pass them back into methods the shim ignores. A name
        # that looks like a class becomes a module so `A::B` still resolves.
        def self.const_missing(name)
          value = if name.to_s.match?(/\A[A-Z][a-z]/)
                    Module.new do
                      def self.const_missing(member)
                        member.to_s.downcase.to_sym
                      end
                    end
                  else
                    name.to_s.downcase.to_sym
                  end
          Gtk.log_unsupported('Gdk', name, note: 'constant is not implemented')
          const_set(name, value)
        end

        # There is no X display behind the browser, so the shim reports one
        # monitor the size of the default screen. Real geometry arrives with
        # the viewer's `geometry` facility once a window is attached; until
        # then this is the same 1280x800 guess the rest of the shim makes.
        class Screen
          # Answers both the width/height that seven scripts read straight off
          # `Screen.default` and the monitor rectangle map.lic asks for.
          Size = Struct.new(:width, :height) do
            def get_monitor_at_point(_x = nil, _y = nil)
              0
            end
            alias_method :monitor_at_point, :get_monitor_at_point

            def get_monitor_geometry(_monitor = 0)
              Rectangle.new(0, 0, width, height)
            end
            alias_method :monitor_geometry, :get_monitor_geometry

            def n_monitors
              1
            end

            def get_monitor_workarea(_monitor = 0)
              get_monitor_geometry
            end

            def display
              Display.default
            end
          end

          def self.default
            @default ||= Size.new(1280, 800)
          end
        end

        Rectangle = Struct.new(:x, :y, :width, :height)

        # Gdk::Display.default.default_screen, which map.lic walks to reach
        # the monitor geometry.
        class Display
          def self.default
            @default ||= new
          end

          def default_screen
            Screen.default
          end
          alias screen default_screen

          def n_monitors
            1
          end

          def get_monitor(_index = 0)
            Screen.default
          end

          def primary_monitor
            Screen.default
          end

          def name
            'webui'
          end

          def flush; end

          def sync; end
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
          # Runs on the session thread, repeating while +block+ returns true.
          #
          # It used to re-enqueue itself directly and register a fresh source
          # each pass: a block that kept returning true queued the next run
          # with no delay at all, so the session thread spun on it, and every
          # pass leaked another entry in @sources. The id it handed back
          # mapped to nil, so Source.remove could never stop it either.
          #
          # Built on the same shape as Timeout.add, with the shortest wait
          # that still yields the thread: one source, cancellable, no spin.
          IDLE_INTERVAL = 0.01

          def self.add(&block)
            session = Gtk::Session.current
            id = nil
            thread = Thread.new do
              loop do
                sleep(IDLE_INTERVAL)
                break unless session.sync { block.call }
              end
            rescue StandardError
              nil
            ensure
              GLib.remove_source(id) if id
            end
            id = GLib.register_source(thread)
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
