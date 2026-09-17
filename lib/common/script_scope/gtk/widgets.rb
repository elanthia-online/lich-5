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
      # widgets. Anything a script calls that is not implemented logs once
      # and degrades; that machinery (the ledger, const_missing, the
      # stubbed-widget notice) is in degradation.rb, and GLib's sources in
      # glib.rb. Images, layouts, drawing areas and menus are deliberately
      # not here: see boot.rb.
      module Gtk
        # Version constants of the GTK release the shim emulates, as ruby-gnome's
        # Gtk::Version exposes them.
        module Version
          MAJOR = 3
          MINOR = 24
          MICRO = 0
          STRING = '3.24.0'
        end

        # Gtk::AttachOptions bit flags for Table#attach's xoptions/yoptions.
        module AttachOptions
          EXPAND = 1
          SHRINK = 2
          FILL = 4
        end
        EXPAND = AttachOptions::EXPAND
        SHRINK = AttachOptions::SHRINK
        FILL = AttachOptions::FILL

        # Gtk::ResponseType: the integer responses dialogs answer with.
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

        # Gtk::PolicyType for ScrolledWindow#set_policy. Symbols rather than
        # GTK's integers; the shim only ever compares them by name.
        module PolicyType
          ALWAYS = :always
          AUTOMATIC = :automatic
          NEVER = :never
          EXTERNAL = :external
        end

        # Gtk::WindowType. Accepted by Window.new and otherwise ignored.
        module WindowType
          TOPLEVEL = :toplevel
          POPUP = :popup
        end

        # Gtk::Align for halign/valign. Mapped to the contract's alignment
        # through {ALIGN_TO_CONTRACT}.
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

        # Gtk::SortType for sortable models and tree view columns.
        module SortType
          ASCENDING = :ascending
          DESCENDING = :descending
        end

        # Gtk::WrapMode for text views. Accepted; the browser wraps as it likes.
        module WrapMode
          NONE = :none
          CHAR = :char
          WORD = :word
          WORD_CHAR = :word_char
        end

        # Gtk::PositionType for tab and scale placement.
        module PositionType
          LEFT = :left
          RIGHT = :right
          TOP = :top
          BOTTOM = :bottom
        end

        # Gtk::SelectionMode for tree selections.
        module SelectionMode
          NONE = :none
          SINGLE = :single
          BROWSE = :browse
          MULTIPLE = :multiple
        end

        # Gtk::Orientation for boxes, separators and panes.
        module Orientation
          HORIZONTAL = :horizontal
          VERTICAL = :vertical
        end

        # The only fields GTK event structs expose that these scripts read.
        # Modifier keys held during a pointer event, with the Gdk predicates
        # scripts test.
        ModifierState = Struct.new(:ctrl, :shift, :alt) do
          # Whether Control was held, as Gdk::ModifierType#control_mask? reports.
          #
          # @return [Boolean] true when the ctrl modifier was down
          def control_mask?
            ctrl
          end

          # Whether Shift was held, as Gdk::ModifierType#shift_mask? reports.
          #
          # @return [Boolean] true when the shift modifier was down
          def shift_mask?
            shift
          end

          # Whether Alt was held, as Gdk::ModifierType#mod1_mask? reports.
          #
          # @return [Boolean] true when the alt modifier was down
          def mod1_mask?
            alt
          end
        end

        # Contract pointer button names mapped to GTK's button numbers.
        POINTER_BUTTONS = { 'primary' => 1, 'middle' => 2, 'secondary' => 3 }.freeze

        # The Gdk::Event stand-in handed to signal handlers: the fields scripts
        # read from Gdk::EventButton and Gdk::EventKey, flattened into one
        # struct. Also exposed as Gdk::Event.
        Event = Struct.new(:type, :button, :state, :keyval, :x, :y, :direction, :time) do
          # Builds a button event from a contract pointer payload.
          #
          # @param kind [Symbol] :button_press or :button_release
          # @param payload [Hash] the contract's press/release payload (button, x, y, modifiers)
          # @return [Event] the Gdk-shaped event, timestamped from the monotonic clock
          def self.pointer(kind, payload)
            modifiers = Array(payload[:modifiers] || payload['modifiers']).map(&:to_s)
            state = ModifierState.new(modifiers.include?('ctrl'), modifiers.include?('shift'), modifiers.include?('alt'))
            new(kind, POINTER_BUTTONS.fetch((payload[:button] || payload['button']).to_s, 1), state, nil,
                (payload[:x] || payload['x']).to_f, (payload[:y] || payload['y']).to_f, nil,
                Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond))
          end

          # The event's type, under the name Gdk::Event uses for it.
          #
          # @return [Symbol, nil] :button_press, :button_release, :key_press, :delete, or nil
          def event_type
            type
          end
        end

        # Widgets that receive pointer gestures: button-press-event and
        # button-release-event with a Gdk-shaped event argument. Prepended to
        # widget classes so it runs before their own event mapping.
        module PointerSurface
          # Maps the pointer signals to the contract's press and release events.
          #
          # @param signal [Symbol] a normalized GTK signal name
          # @return [Symbol, nil] :press, :release, or whatever the widget maps otherwise
          def event_for(signal)
            case signal
            when :button_press_event then :press
            when :button_release_event then :release
            else super
            end
          end

          # Turns a contract press or release into a Gdk event and runs the handlers.
          #
          # @param event [Symbol] the contract event that arrived
          # @param context [Lich::WebUI::Runtime::EventContext] the event's context (payload, viewer)
          # @return [void]
          def receive_event(event, context)
            return super unless %i[press release].include?(event)

            payload = context.payload || {}
            gdk = Event.pointer(event == :press ? :button_press : :button_release, payload)
            @handlers.each_key do |signal|
              emit(signal, gdk) if event_for(signal) == event
            end
          end
        end

        # Gtk::Align symbols mapped to the contract's `align` values.
        ALIGN_TO_CONTRACT = {
          start: 'start', center: 'center', end: 'end', fill: 'stretch', baseline: 'start',
        }.freeze

        @key_counter = 0
        @key_mutex = Mutex.new

        class << self
          # Mints the next process-unique widget key ("w1", "w2", ...).
          #
          # @return [String] a key no other widget in this process has
          def next_key
            @key_mutex.synchronize { "w#{@key_counter += 1}" }
          end

          # Schedules +block+ on the calling script's emulated GTK thread.
          #
          # @yield the work to run on the session thread
          # @return [nil]
          def queue(&block)
            Session.current.enqueue(&block)
            nil
          end

          # Gtk.main: a no-op logged once, because the session owns the main loop.
          #
          # @return [nil]
          def main(*)
            log_unsupported('Gtk', 'main', note: 'the shim owns the main loop')
            nil
          end

          # Gtk.main_quit: a no-op, since there is no script-owned loop to quit.
          #
          # @return [nil]
          def main_quit(*)
            nil
          end

          # Gtk.main_level: always 0, as there is never a recursive script loop.
          #
          # @return [Integer] 0
          def main_level
            0
          end

          # Gtk.events_pending?: always false; events are dispatched by the session.
          #
          # @return [Boolean] false
          def events_pending?
            false
          end

          # Gtk.main_iteration_do: a no-op that reports no quit request.
          #
          # @return [Boolean] false
          def main_iteration_do(*)
            false
          end

          # Canonical form of a signal name: "button-press-event" and
          # :button_press_event both become :button_press_event.
          #
          # @param name [String, Symbol] a GTK signal name in either spelling
          # @return [Symbol] the underscored symbol
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
          #
          # @param name [String, Symbol, nil] the GTK keyval name the browser sent
          # @return [Symbol, nil] the Gdk::Keyval-shaped symbol, or nil for a blank name
          def keyval_for(name)
            return nil if name.nil? || name.to_s.empty?

            "key_#{name}".downcase.to_sym
          end

          # Coerces a GtkBuilder property string to the value a setter wants.
          #
          # @param value [#to_s] the raw <property> text
          # @return [Boolean, Integer, Float, String] the coerced value; unrecognized text stays a String
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
          # Extends +base+ with {ClassMethods} so it can declare setters.
          #
          # @param base [Class] the class that extended Setters
          # @return [void]
          def self.extended(base)
            base.extend(ClassMethods)
          end

          # The `def_setter` macro, added to every class that extends {Setters}.
          module ClassMethods
            # Defines +name+ as a wrapper around the writer +writer+ that
            # returns self, the way ruby-gnome's own set_* do.
            #
            # @param name [Symbol] the set_* method to define
            # @param writer [Symbol] the existing foo= writer it delegates to
            # @return [Symbol] the name of the defined method
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
        # Stand-in for Gtk::Widget, the root of every shim widget. Unlike GTK a
        # widget here is shadow state plus a mapping onto one contract node
        # ({#node_type}, {#node_props}); nothing is drawn until the session
        # materializes it. Unknown setters degrade to self (see
        # {#method_missing}); everything else is a NoMethodError, as in Ruby.
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

          # @!attribute [r] key
          #   @return [String] the process-unique key carried as the node's `key` prop
          # @!attribute [r] parent
          #   @return [Container, nil] the container this widget is attached to
          # @!attribute [r] handle
          #   @return [Lich::WebUI::Adapter::Handle, nil] the adapter node, once materialized
          # @!attribute [r] session
          #   @return [Session] the script session that owns this widget
          # @!attribute [r] halign
          #   @return [Symbol, nil] the Gtk::Align symbol set through halign=, if any
          # @!attribute [r] valign
          #   @return [Symbol, nil] the Gtk::Align symbol set through valign=, if any
          # @!attribute [r] placement
          #   @return [Hash{Symbol => Object}, nil] placement in the parent's node (span, grow, pad)
          attr_reader :key, :parent, :handle, :session, :halign, :valign, :placement
          # @!attribute packing
          #   @return [Hash{Symbol => Object}, nil] the Box packing (expand, fill, padding) recorded by pack_*
          # @!attribute builder_name
          #   @return [String, nil] the id a GtkBuilder file gave this widget
          attr_accessor :packing, :builder_name

          # Creates a widget owned by the current session, visible and sensitive.
          #
          # @return [Widget] a new instance
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

          # The contract node type this widget renders as.
          #
          # @return [Symbol] a contract component type such as :text or :button
          # @raise [NotImplementedError] on the base class; every concrete widget overrides it
          def node_type
            raise NotImplementedError
          end

          # The type-specific props of this widget's node, merged over {#common_props}.
          #
          # @return [Hash{Symbol => Object}] props for the contract node
          def node_props
            {}
          end

          # Contract event a GTK signal maps to for this widget, or nil.
          #
          # @param _signal [Symbol] a normalized GTK signal name
          # @return [Symbol, nil] the contract event, or nil when the signal has no mapping
          def event_for(_signal)
            nil
          end

          # Events bound whether or not the script connected a handler, so
          # the shadow state tracks the viewer (scripts read `entry.text`
          # later without ever connecting `changed`).
          #
          # @return [Array<Symbol>] contract events to bind unconditionally
          def always_bound_events
            []
          end

          # --- GTK surface ---------------------------------------------------

          # Connects a handler block to a GTK signal, as Gtk::Widget#signal_connect does.
          #
          # @param signal [String, Symbol] the signal name in either GTK spelling
          # @param _args [Array] ignored; GTK's detail and flags arguments
          # @yield the handler, called with GTK's (widget, event, ...) arguments trimmed to its arity
          # @return [Integer] a handler id for {#signal_handler_disconnect}
          # @raise [ArgumentError] when no block is given
          def signal_connect(signal, *_args, &block)
            raise ArgumentError, 'signal handler block required' unless block

            name = Gtk.normalize_signal(signal)
            @handlers[name] << block
            id = (@handler_id_seq += 1)
            @handler_ids[id] = [name, block]
            id
          end
          alias signal_connect_after signal_connect

          # Removes a handler by the id {#signal_connect} returned.
          #
          # @param id [Integer] the handler id
          # @return [nil]
          def signal_handler_disconnect(id)
            name, block = @handler_ids.delete(id)
            @handlers[name].delete(block) if name
            nil
          end

          # Gtk::Widget#signal_emit: runs the handlers connected to +signal+.
          #
          # @param signal [String, Symbol] the signal name
          # @param args [Array] arguments passed after the widget
          # @return [Object, nil] the last handler's return value, or nil with no handlers
          def signal_emit(signal, *args)
            emit(signal, *args)
          end

          # Runs the handlers for +signal+ with GTK's (widget, event) shape,
          # trimming arguments to what each handler accepts.
          #
          # @param signal [String, Symbol] the signal name
          # @param args [Array] arguments passed after the widget
          # @return [Object, nil] the last handler's return value, or nil with no handlers
          def emit(signal, *args)
            name = Gtk.normalize_signal(signal)
            result = nil
            @handlers[name].dup.each do |handler|
              result = Gtk::Widget.call_handler(handler, [self, *args])
            end
            result
          end

          # Calls +handler+ with as many of +args+ as its arity accepts.
          #
          # @param handler [Proc] the connected block
          # @param args [Array] the full (widget, event, ...) argument list
          # @return [Object] whatever the handler returns
          def self.call_handler(handler, args)
            arity = handler.arity
            if arity.negative?
              handler.call(*args)
            else
              handler.call(*args.first(arity))
            end
          end

          # Whether any handler is connected to +signal+.
          #
          # @param signal [String, Symbol] the signal name
          # @return [Boolean] true when at least one handler is connected
          def handlers?(signal)
            !@handlers[Gtk.normalize_signal(signal)].empty?
          end

          # Sets sensitivity; an insensitive widget renders disabled.
          #
          # @param value [Object] truthy for sensitive
          # @return [void]
          def sensitive=(value)
            @sensitive = value ? true : false
            changed!
          end
          def_setter :set_sensitive, :sensitive=

          # Whether the widget is sensitive.
          #
          # @return [Boolean] true unless sensitivity was turned off
          def sensitive?
            @sensitive
          end

          # Sets visibility; a hidden widget is dropped from its parent's node.
          #
          # @param value [Object] truthy for visible
          # @return [void]
          def visible=(value)
            @visible = value ? true : false
            changed!
          end
          def_setter :set_visible, :visible=

          # Whether the widget is visible. Unlike GTK, widgets start visible.
          #
          # @return [Boolean] true unless hidden
          def visible?
            @visible
          end

          # Makes the widget visible.
          #
          # @return [self]
          def show
            self.visible = true
            self
          end

          # Makes the widget visible; containers override to recurse.
          #
          # @return [self]
          def show_all
            show
          end

          # Hides the widget.
          #
          # @return [self]
          def hide
            self.visible = false
            self
          end

          # Sets the tooltip; it is truncated to the contract's short-text bound at render.
          #
          # @param text [#to_s, nil] the tooltip, or nil to clear it
          # @return [void]
          def tooltip_text=(text)
            @tooltip = text&.to_s
            changed!
          end
          def_setter :set_tooltip_text, :tooltip_text=

          # The tooltip as set, untruncated.
          #
          # @return [String, nil] the tooltip text
          def tooltip_text
            @tooltip
          end

          # Gtk::Widget#has_tooltip=: accepted and ignored.
          #
          # @param _value [Object] ignored
          # @return [void]
          def has_tooltip=(_value); end

          # Which of a size request's axes reach the contract node.
          #
          # @return [Array<Symbol>] a subset of [:width, :height]; empty on the base class
          def size_request_axes
            []
          end

          # Records a minimum size. Non-positive values (GTK's -1) clear that axis.
          #
          # @param width [Integer] the requested width in pixels, or -1 for none
          # @param height [Integer] the requested height in pixels, or -1 for none
          # @return [self]
          def set_size_request(width, height)
            @width_request = width.to_i.positive? ? width.to_i : nil
            @height_request = height.to_i.positive? ? height.to_i : nil
            changed!
            self
          end

          # Sets the width request, keeping the height request.
          #
          # @param width [Integer] the requested width in pixels, or -1 for none
          # @return [void]
          def width_request=(width)
            set_size_request(width, @height_request || -1)
          end
          def_setter :set_width_request, :width_request=

          # Sets the height request, keeping the width request.
          #
          # @param height [Integer] the requested height in pixels, or -1 for none
          # @return [void]
          def height_request=(height)
            set_size_request(@width_request || -1, height)
          end
          def_setter :set_height_request, :height_request=

          # Sets the horizontal alignment; see {Align} and {ALIGN_TO_CONTRACT}.
          #
          # @param value [Symbol, String] a Gtk::Align value in any case
          # @return [void]
          def halign=(value)
            @halign = value.to_s.downcase.to_sym
            changed!
          end
          def_setter :set_halign, :halign=

          # Sets the vertical alignment. Recorded for scripts that read it back;
          # the contract's `align` carries only the horizontal axis.
          #
          # @param value [Symbol, String] a Gtk::Align value in any case
          # @return [void]
          def valign=(value)
            @valign = value.to_s.downcase.to_sym
            changed!
          end
          def_setter :set_valign, :valign=

          # @!method margin_top=(value)
          #   Sets one margin edge in pixels. Also margin_right=, margin_bottom=, margin_left=,
          #   with set_margin_* setters returning self, and margin_start=/margin_end= as
          #   aliases of the left and right edges.
          #   @param value [#to_i] the margin in pixels
          #   @return [void]
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

          # Sets all four margins at once.
          #
          # @param value [#to_i] the margin in pixels
          # @return [void]
          def margin=(value)
            @margins = { top: value.to_i, right: value.to_i, bottom: value.to_i, left: value.to_i }
            changed!
          end

          # Gtk::Misc#set_padding(xpad, ypad): pads both sides of each axis.
          # Distinct from Alignment#set_padding, which names four edges.
          # Labels in nine scripts space wrapped text this way; without it
          # the padding was recorded nowhere and the blocks ran together.
          #
          # @param xpad [#to_i] pixels added to the left and right margins
          # @param ypad [#to_i] pixels added to the top and bottom margins
          # @return [self]
          def set_padding(xpad, ypad)
            @margins[:left] = @margins[:right] = xpad.to_i
            @margins[:top] = @margins[:bottom] = ypad.to_i
            changed!
            self
          end

          # Sets whether the widget claims free horizontal space in its parent.
          #
          # Grid reads hexpand? at render rather than at attach, precisely
          # because a script may set it afterwards -- so without changed! the
          # widget never became dirty and the column kept its old weight until
          # something else happened to trigger a re-render.
          #
          # @param value [Object] truthy to expand
          # @return [void]
          def hexpand=(value)
            @hexpand = value ? true : false
            changed!
          end
          def_setter :set_hexpand, :hexpand=

          # Records vertical expansion; nothing consumes it yet (see {#vexpand?}).
          #
          # @param value [Object] truthy to expand
          # @return [void]
          def vexpand=(value)
            @vexpand = value ? true : false
            changed!
          end
          def_setter :set_vexpand, :vexpand=

          # Whether the widget claims free horizontal space.
          #
          # @return [Boolean] true when hexpand was set
          def hexpand?
            @hexpand
          end

          # `@vexpand` was set and never read by anything. The contract has no
          # vertical counterpart to a column's `grow`, so nothing consumes it
          # yet; the reader at least makes the recorded value observable
          # rather than silently dead.
          #
          # @return [Boolean] true when vexpand was set
          def vexpand?
            @vexpand
          end

          # Gtk::Misc#xalign=: accepted and ignored on the base widget; Label overrides it.
          #
          # @param _value [Object] ignored
          # @return [void]
          def xalign=(_value); end
          def_setter :set_xalign, :xalign=

          # Gtk::Widget#add_events: a no-op.
          #
          # Event masks are implicit here: a widget with a handler is bound.
          #
          # @param _masks [Array] ignored Gdk event masks
          # @return [self]
          def add_events(*_masks)
            self
          end
          alias set_events add_events
          alias events= add_events

          # Gtk::Container#set_border_width: accepted and ignored.
          #
          # @param _width [Object] ignored
          # @return [self]
          def set_border_width(_width)
            self
          end
          alias border_width= set_border_width

          # Gtk::Widget#set_can_focus: accepted and ignored.
          #
          # Focusability is the browser's to decide. Already ignored as a
          # builder property; scripts set it directly too.
          #
          # @param _value [Object] ignored
          # @return [self]
          def set_can_focus(_value)
            self
          end
          alias can_focus= set_can_focus

          # Whether the widget can take focus: always true here.
          #
          # @return [Boolean] true
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

          # The widget's allocation: its size request, or its window's default size.
          #
          # With no size request and no window to inherit from it answers
          # 640x480, and says so through the ledger (D5): the number is a
          # guess, and a script that centres on it deserves a log line.
          #
          # @return [Allocation] a rectangle at the origin with the best-known size
          def allocation
            root = window_root
            width = @width_request || root&.default_width
            height = @height_request || root&.default_height
            if width.nil? || height.nil?
              Gtk.log_unsupported(short_class_name, 'allocation',
                                  note: 'no size request and no window to inherit from; answering 640x480')
            end
            Allocation.new(0, 0, width || 640, height || 480)
          end
          alias get_allocation allocation

          # Sets the widget's CSS-style name.
          #
          # @param value [#to_s] the name
          # @return [void]
          def name=(value)
            @name = value.to_s
          end
          def_setter :set_name, :name=

          # The widget's name, if one was set.
          #
          # @return [String, nil] the name
          def name
            @name
          end

          # Gtk::Widget#grab_focus: a no-op, since focus belongs to the browser.
          #
          # @return [self]
          def grab_focus
            self
          end

          # Removes the widget from its parent, emits destroy, and requests a commit.
          #
          # @return [nil]
          def destroy
            # Only Window set this; every other widget answered destroyed?
            # false forever, and scripts guard cleanup on it at ~50 sites.
            @destroyed = true
            @parent&.remove(self)
            emit(:destroy)
            @session.request_commit unless @session.on_session_thread?
            nil
          end

          # Whether {#destroy} has been called.
          #
          # @return [Boolean] true once destroyed
          def destroyed?
            @destroyed == true
          end

          # The root of this widget's parent chain, which need not be a Window.
          #
          # @return [Widget] the topmost ancestor, or self when unparented
          def toplevel
            node = self
            node = node.parent while node.parent
            node
          end

          # The Window this widget sits in, if it is in one.
          #
          # @return [Window, nil] the enclosing window
          def window_root
            root = toplevel
            root.is_a?(Window) ? root : nil
          end

          # GObject#set_property, routed through {#apply_builder_property}.
          #
          # @param name [String, Symbol] the property name in either spelling
          # @param value [Object] the value; strings are coerced as builder values
          # @return [self]
          def set_property(name, value)
            apply_builder_property(name, value)
          end

          # Applies one GtkBuilder <property> to this widget. Subclasses
          # override for names that mean different things per class (label,
          # active, text) and fall back here.
          #
          # @param name [String, Symbol] the property name; underscores and dashes are equivalent
          # @param value [Object] the property text, coerced through {Gtk.builder_value}
          # @return [self]
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

          # Degrades an unimplemented method: logs it once and answers self for
          # setter shapes, nil for anything else. Names in {PROTOCOL_METHODS}
          # raise NoMethodError as they would on any object.
          #
          # @param name [Symbol] the missing method
          # @param args [Array] its arguments, ignored
          # @return [self, nil] self for set_* and *= names, otherwise nil
          # @raise [NoMethodError] for Ruby's conversion and comparison protocol methods
          def method_missing(name, *args, &block)
            return super if PROTOCOL_METHODS.include?(name)

            Gtk.log_unsupported(short_class_name, name)
            return self if name.end_with?('=') || name.start_with?('set_')

            nil
          end

          # Honest about what method_missing will do (D4): only a setter
          # shape (set_* or *=) is answered, because only those degrade to
          # something a script can use -- the widget itself. Every other
          # name falls through to Ruby's own answer, so a script that probes
          # for a capability is told no rather than yes-and-then-silence.
          #
          # @param name [Symbol] the method name being probed
          # @param include_private [Boolean] whether private methods count
          # @return [Boolean] true only for setter shapes and methods Ruby already answers
          def respond_to_missing?(name, include_private = false)
            return super if PROTOCOL_METHODS.include?(name)

            name.end_with?('=') || name.start_with?('set_') || super
          end

          # --- materialization ------------------------------------------------

          # Records +parent+ as this widget's container. Called by Container#add.
          #
          # @param parent [Container] the new parent
          # @return [void]
          def attach_to(parent)
            @parent = parent
          end

          # Forgets the parent. Called by Container#remove.
          #
          # @return [void]
          def detach_from_parent
            @parent = nil
          end

          # Placement in the parent's contract node (grid span etc.).
          #
          # @param hash [Hash{Symbol => Object}, nil] placement props; empty or nil clears it
          # @return [void]
          def placement=(hash)
            @placement = hash && !hash.empty? ? hash : nil
          end

          # Marks the widget dirty and, from off the session thread, requests a commit.
          #
          # @return [void]
          def changed!
            @dirty = true
            window = window_root
            return unless window&.handle && @session.on_session_thread? == false

            # Off-thread mutation (a script thread poking a widget): render
            # after the batch this joins (D3), not once per write.
            @session.request_commit
          end

          # A viewer-scoped property (checked, value, open, selected) has a
          # per-viewer copy that shadows the shared prop, so re-rendering
          # alone changes nothing the browser shows: the viewer's own copy
          # wins. The write has to be pushed to every attached viewer as
          # well. That pairing was hand-copied at ten sites and forgotten at
          # five -- radio buttons, radio menu items, Menu#popdown, Adjustment
          # and ComboBox -- each a separate user-visible bug with one cause.
          # One method, so it cannot be half-copied again.
          #
          # @param name [Symbol] the viewer-scoped prop name
          # @param value [Object] the new value
          # @return [Object] +value+
          def viewer_push(name, value)
            changed!
            @session.viewer_write(window_root, self, name, value) if @handle
            value
          end

          # The props every widget contributes: key, hidden, tooltip, size, align, margin.
          #
          # @return [Hash{Symbol => Object}] props merged under {#node_props} at render
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
            align = ALIGN_TO_CONTRACT[@halign] if @halign
            # The child's own halign wins; failing that, how its box packed it.
            align ||= @parent.packed_align(self) if @parent.is_a?(Box)
            props[:align] = align if align
            margin = contract_margin
            props[:margin] = margin if margin
            props
          end

          # GTK sets one edge at a time, so collapsing the four to their max
          # put a one-sided indent on all four sides -- bigshot has 518
          # one-sided margins and came out spread across the window. Sends a
          # plain integer when every side agrees, which is most widgets.
          #
          # @return [Integer, Hash{Symbol => Integer}, nil] one margin, the non-zero edges, or nil for none
          def contract_margin
            sides = @margins.transform_values do |value|
              clamped = value.to_i.clamp(0, 512)
              Gtk.log_clamped(short_class_name, 'margin', value.to_i, clamped) if value.to_i > 512
              clamped
            end
            return nil if sides.values.all?(&:zero?)
            return sides.values.first if sides.values.uniq.size == 1

            sides.reject { |_side, value| value.zero? }
          end

          # Creates or updates this widget's adapter node. Returns the handle.
          #
          # @param adapter [Lich::WebUI::Adapter] the session's adapter
          # @return [Lich::WebUI::Adapter::Handle] the node's handle
          # @raise [Lich::WebUI::Error] when the adapter refuses the node's props
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
            sync_submission!(adapter)
            @dirty = false
            @handle
          end

          # Forgets the adapter node and everything synced to it, so the next
          # commit creates the node afresh. Does not destroy the node itself.
          #
          # @return [void]
          def release_handle!
            @handle = nil
            @synced_props = nil
            @synced_placement = nil
            @synced_type = nil
            @synced_submission = nil
            @bound_events = {}
            # A new handle needs its presentation reader registered again.
            @presentation_registered = false
            @synced_presentation = nil
          end

          # Drops this widget's node so the next commit builds it again with
          # the type it now reports. The parent re-attaches it in place,
          # because it is still in the parent's child list.
          #
          # @param adapter [Lich::WebUI::Adapter] the session's adapter
          # @return [void]
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

          # Sends the placement to the adapter when it has changed since the last sync.
          #
          # @param adapter [Lich::WebUI::Adapter] the session's adapter
          # @return [void]
          def sync_placement!(adapter)
            return unless @handle
            return if @placement == @synced_placement

            adapter.set_placement(@handle, @placement || {})
            @synced_placement = @placement
          end

          # The inputs whose values this widget's event must carry. Most
          # widgets submit nothing; a terminal that reads a password back
          # declares the entries it reads.
          #
          # @return [Array<Widget>] the input widgets whose values this widget's event carries
          def submission_scope
            []
          end

          # Sends the submission scope's handles to the adapter when they have changed.
          #
          # @param adapter [Lich::WebUI::Adapter] the session's adapter
          # @return [void]
          def sync_submission!(adapter)
            return unless @handle
            return unless adapter.respond_to?(:set_submission)

            scope = submission_scope.filter_map(&:handle)
            return if scope == @synced_submission

            adapter.set_submission(@handle, scope)
            @synced_submission = scope
          end

          # The class name as the ledger reports it, e.g. "Gtk::Entry".
          #
          # @return [String] the last two namespace segments
          def short_class_name
            self.class.name.split('::').last(2).join('::')
          end

          protected

          # Contract event arrived (on the session thread): update shadow state
          # then run the GTK handlers for every signal mapped to it.
          #
          # @param event [Symbol] the contract event
          # @param context [Lich::WebUI::Runtime::EventContext, CarriedEvent] the event's context
          # @return [void]
          def receive_event(event, context)
            apply_event(event, context)
            @handlers.each_key do |signal|
              emit(signal, Event.new) if event_for(signal) == event
            end
          end

          # Updates shadow state from a contract event. No-op on the base class.
          #
          # @param _event [Symbol] the contract event
          # @param _context [Lich::WebUI::Runtime::EventContext, CarriedEvent] the event's context
          # @return [void]
          def apply_event(_event, _context); end

          # Reads one field of the event payload, under a symbol or string key.
          #
          # @param context [Lich::WebUI::Runtime::EventContext, CarriedEvent] the event's context
          # @param name [Symbol] the payload field
          # @return [Object, nil] the field's value, or nil without a payload
          def payload_value(context, name = :value)
            payload = context.payload
            return nil unless payload

            payload.key?(name) ? payload[name] : payload[name.to_s]
          end

          # This widget's value out of the event's submission scope. A password
          # has no other channel: the contract makes its value sensitive and
          # write-only, so it never arrives as a property or an event payload.
          # The scope is keyed by cid, and a widget knows itself by its key.
          #
          # @param context [Lich::WebUI::Runtime::EventContext, CarriedEvent] the event's context
          # @return [String, nil] this widget's submitted value, if the event carried one
          def submitted_value(context)
            return nil unless context.respond_to?(:submitted)

            submitted = context.submitted
            return nil unless submitted

            cid = rendered_cid
            cid && submitted[cid]
          end

          # The cid the tree builder minted for this widget in the last render.
          # Derived the same way Session#viewer_write finds it: every widget
          # carries a `key` prop that is unique and fixed for its lifetime.
          #
          # @return [String, nil] the cid, or nil before the window's first render
          def rendered_cid
            window = window_root
            return nil unless window&.handle

            page = @session.adapter.page_for(window.handle)
            render = page&.last_render
            return nil unless render

            render.tree.each.find { |candidate| candidate.props[:key] == key }&.cid
          end

          private

          # Drops any common prop the contract does not allow on this type.
          # @api private
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
        # Stand-in for Gtk::Container: an ordered child list that materializes
        # into the node's children, attaching, detaching and destroying adapter
        # nodes to match. Hidden children are kept but not attached.
        class Container < Widget
          # Creates an empty container.
          #
          # @return [Container] a new instance
          def initialize
            super
            @children = []
            @synced_children = []
            # Handle last attached per child, so a child that rebuilds its
            # node is re-attached rather than silently orphaned.
            @synced_handles = {}.compare_by_identity
          end

          # The children in render order.
          #
          # @return [Array<Widget>] a copy of the ordered child list
          def children
            ordered_children.dup
          end

          # Iterates the children in render order.
          #
          # @yieldparam child [Widget] each child
          # @return [Array<Widget>] the ordered children
          def each(&block)
            ordered_children.each(&block)
          end

          # Adds a child, removing it from any previous parent first.
          #
          # @param child [Widget] the widget to add
          # @return [self]
          def add(child)
            child.detach_from_parent if child.parent
            child.attach_to(self)
            @children << child
            changed!
            self
          end

          # Removes a child. A widget that is not a child is ignored.
          #
          # @param child [Widget] the widget to remove
          # @return [self]
          def remove(child)
            return self unless @children.delete(child)

            child.detach_from_parent
            changed!
            self
          end

          # Removes every child.
          #
          # @return [Array<Widget>] the children that were removed
          def remove_all
            @children.dup.each { |child| remove(child) }
          end

          # Shows this container and, recursively, every child.
          #
          # @return [self]
          def show_all
            show
            @children.each(&:show_all)
            self
          end

          # The children in the order the node should hold them. Subclasses
          # override to honour pack_end or cell positions.
          #
          # @return [Array<Widget>] the ordered children (not a copy)
          def ordered_children
            @children
          end

          # Children the contract node should hold, in order. Grids override
          # to interleave fillers; hidden children are dropped.
          #
          # @return [Array<Widget>] the visible children to attach
          def render_children
            ordered_children.select(&:visible?)
          end

          # Materializes this node and its children, attaching and detaching
          # child nodes to match {#render_children}.
          #
          # @param adapter [Lich::WebUI::Adapter] the session's adapter
          # @return [Lich::WebUI::Adapter::Handle] this node's handle
          def materialize!(adapter)
            handle = super
            (@synced_children - ordered_children - filler_children).each do |gone|
              # Forgotten here as well as destroyed: the identity map held
              # every child ever attached, so a long-lived window that
              # replaced its rows kept each removed widget, and everything
              # it reached, for the life of the container.
              @synced_handles.delete(gone)
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

          # Placeholder widgets this container renders that are not children.
          #
          # @return [Array<Widget>] empty except for grids
          def filler_children
            []
          end

          # A child that rebuilt its node is no longer attached to ours, so
          # forget it and let the next commit attach the replacement.
          #
          # @param child [Widget] the child whose node was rebuilt
          # @return [void]
          def forget_child_handle(child)
            @synced_handles.delete(child)
            changed!
          end

          # Releases this node's handle and every child's.
          #
          # @return [void]
          def release_handle!
            super
            @synced_children = []
            @children.each(&:release_handle!)
          end
        end

        # Stand-in for Gtk::Box. A vertical box renders as a contract stack and
        # a horizontal one as columns, whose weights come from the children's
        # packing and hexpand. Homogeneous packing is accepted and ignored.
        class Box < Container
          # @!attribute [r] orientation
          #   @return [Symbol] :horizontal or :vertical
          # @!attribute [r] spacing
          #   @return [Integer] the gap between children in pixels
          attr_reader :orientation, :spacing

          # Creates a box.
          #
          # @param orientation [Symbol, String] :horizontal or :vertical; anything not starting with "h" is vertical
          # @param spacing [#to_i] the gap between children in pixels
          # @return [Box] a new instance
          def initialize(orientation = :vertical, spacing = 0)
            super()
            @orientation = orientation.to_s.start_with?('h') ? :horizontal : :vertical
            @spacing = spacing.to_i
            @end_children = []
          end

          # Packs a child at the start, in GTK's positional or keyword spelling.
          #
          # @param child [Widget] the widget to pack
          # @param positional [Array] GTK 2's (expand, fill, padding), booleans or 0/1 integers
          # @param options [Hash{Symbol => Object}] :expand, :fill and :padding keywords
          # @return [self]
          def pack_start(child, *positional, **options)
            child.packing = packing_from(positional, options)
            add(child)
          end

          # Packs a child at the end; end-packed children render after the
          # start-packed ones, in reverse packing order as in GTK.
          #
          # @param child [Widget] the widget to pack
          # @param positional [Array] GTK 2's (expand, fill, padding), booleans or 0/1 integers
          # @param options [Hash{Symbol => Object}] :expand, :fill and :padding keywords
          # @return [self]
          def pack_end(child, *positional, **options)
            child.packing = packing_from(positional, options)
            add(child)
            @end_children << child
            self
          end

          # Removes a child from the box and from the end-packed set.
          #
          # @param child [Widget] the widget to remove
          # @return [self]
          def remove(child)
            @end_children.delete(child)
            super
          end

          # Moves a child to +position+ in the packing order.
          #
          # @param child [Widget] a child of this box
          # @param position [#to_i] the new index, clamped to the child count
          # @return [self]
          def reorder_child(child, position)
            return self unless @children.delete(child)

            @children.insert(position.to_i.clamp(0, @children.length), child)
            changed!
            self
          end

          # Gtk::Box#homogeneous=: accepted and ignored.
          #
          # @param _value [Object] ignored
          # @return [void]
          def homogeneous=(_value); end
          def_setter :set_homogeneous, :homogeneous=

          # Sets the gap between children.
          #
          # @param value [#to_i] the spacing in pixels
          # @return [void]
          def spacing=(value)
            @spacing = value.to_i
            changed!
          end
          def_setter :set_spacing, :spacing=

          # Changes the orientation, which changes the node type at the next render.
          #
          # @param value [Symbol, String] :horizontal or :vertical
          # @return [void]
          def orientation=(value)
            @orientation = value.to_s.start_with?('h') ? :horizontal : :vertical
            changed!
          end

          # Start-packed children in order, then end-packed children reversed.
          #
          # @return [Array<Widget>] the children in render order
          def ordered_children
            starts = @children.reject { |child| @end_children.include?(child) }
            starts + @end_children.reverse.select { |child| @children.include?(child) }
          end

          # :stack for a vertical box, :columns for a horizontal one.
          #
          # @return [Symbol] the node type
          def node_type
            @orientation == :vertical ? :stack : :columns
          end

          # The common props, plus an end alignment for a horizontal box whose
          # children are all packed end.
          #
          # @return [Hash{Symbol => Object}] props for the node
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
          #
          # @return [Array<Widget>] the visible children, with their placement set
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

          # The stack's gap, or the columns' count, gap and weights.
          #
          # @return [Hash{Symbol => Object}] props for the node
          def node_props
            if @orientation == :vertical
              { gap: [@spacing, 64].min }
            else
              children = render_children
              count = children.length.clamp(1, 12)
              Gtk.log_clamped(short_class_name, 'children', children.length, count) if children.length > 12
              props = { count: count, gap: [@spacing, 64].min }
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

          # GTK's expand: true, fill: false gives the child the room but keeps
          # it its natural size, centred in it. packing[:fill] was computed
          # and never read, so it rendered exactly like fill: true. The
          # contract has one `align`, and on a columns row it is
          # justify-self -- the box axis -- so a child packed that way is
          # centred in its column. (It is align-self too, so the child also
          # sits mid-row rather than on the baseline; there is no way to say
          # one without the other.) In a vertical stack `align` is the cross
          # axis, so expand-without-fill cannot be said there and the child
          # fills its grown row as before.
          #
          # @param child [Widget] a child of this box
          # @return [String, nil] 'center' for a child packed expand-without-fill in a horizontal box
          def packed_align(child)
            return nil unless @orientation == :horizontal

            packing = child.packing
            return nil unless packing && packing[:expand] && !packing[:fill]

            'center'
          end

          private

          # Where the free space falls when nothing expands: before the first
          # pack_end child. nil when the box is all starts or all ends, since
          # then GTK has no split to honor and the children simply sit at
          # their edge.
          # @api private
          def trailing_gap_index(children)
            return nil if @end_children.empty?

            first_end = children.index { |child| @end_children.include?(child) }
            return nil if first_end.nil? || first_end.zero? || first_end > 11

            first_end
          end

          # A box whose children are *all* packed end has no column to widen
          # -- the free space falls before the first of them, outside any
          # child. The contract says that with alignment on the box itself.
          # @api private
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
          # @api private
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

        # Stand-in for the deprecated Gtk::HBox: a horizontal {Box}.
        class HBox < Box
          # Creates a horizontal box.
          #
          # @param _homogeneous [Object] ignored
          # @param spacing [#to_i] the gap between children in pixels
          # @return [HBox] a new instance
          def initialize(_homogeneous = false, spacing = 0)
            super(:horizontal, spacing)
          end
        end

        # Stand-in for the deprecated Gtk::VBox: a vertical {Box}.
        class VBox < Box
          # Creates a vertical box.
          #
          # @param _homogeneous [Object] ignored
          # @param spacing [#to_i] the gap between children in pixels
          # @return [VBox] a new instance
          def initialize(_homogeneous = false, spacing = 0)
            super(:vertical, spacing)
          end
        end

        # Placeholder for an empty grid cell so flow order reproduces an
        # attach layout that has holes. Has no GTK counterpart.
        class Filler < Widget
          # A filler is a text node.
          #
          # @return [Symbol] :text
          def node_type
            :text
          end

          # A single space, so the cell has content.
          #
          # @return [Hash{Symbol => Object}] props for the node
          def node_props
            { content: ' ' }
          end

          # Only the key; a filler has no visibility, size or margin of its own.
          #
          # @return [Hash{Symbol => Object}] props for the node
          def common_props
            { key: @key }
          end
        end

        # Shared by Gtk::Table and Gtk::Grid: children carry a cell rectangle
        # and render into a flow-ordered contract grid, row by row, with
        # fillers for holes and span placement for wide cells.
        module GridLayout
          # Each child's cell rectangle as [left, top, width, height], by identity.
          #
          # @return [Hash{Widget => Array<Integer>}] the cell map
          def cells
            @cells ||= {}.compare_by_identity
          end

          # The {Filler} placed in each empty cell, keyed by [column, row].
          #
          # @return [Hash{Array<Integer> => Filler}] the fillers made so far
          def fillers
            @fillers ||= {}
          end

          # The number of columns the grid renders with.
          #
          # @return [Integer] the column count
          # @raise [NotImplementedError] unless the including class defines it
          def column_count
            raise NotImplementedError
          end

          # Columns a child asked to expand into, by left edge. GTK's default
          # is not to expand, so a table with no EXPAND anywhere keeps every
          # column at natural width.
          #
          # @return [Hash{Integer => Boolean}] true under each expanding column's index
          def expanding_columns
            @expanding_columns ||= {}
          end

          # Per-column share of the leftover width. nil when nothing expands,
          # so the contract prop stays absent and the client keeps `auto`.
          #
          # @return [Array<Integer>, nil] a 1 or 0 per column, or nil when no column expands
          def column_weights
            cols = column_count
            expanding = expanding_columns.keys.select { |column| column < cols }
            return nil if expanding.empty?

            Array.new(cols) { |column| expanding.include?(column) ? 1 : 0 }
          end

          # The children in row-major cell order.
          #
          # @return [Array<Widget>] the children sorted by (top, left)
          def ordered_children
            @children.sort_by { |child| cells.fetch(child, [0, 0, 1, 1]).first(2).reverse }
          end

          # Only the fillers the current layout still places. filler_for
          # memoizes by cell and this returned every one ever made, so the
          # gone-child sweep in Container#materialize! never saw a stale
          # filler: a table that shrank, or a cell a child later covered,
          # kept an adapter node forever. Pruned here rather than in
          # render_children because the sweep runs first and works from this
          # list.
          #
          # @return [Array<Filler>] the fillers the current layout still places
          def filler_children
            live = render_children.select { |child| child.is_a?(Filler) }
            fillers.keep_if { |_cell, filler| live.include?(filler) }
            fillers.values
          end

          # The children and fillers in flow order, row by row, with span
          # placement set on each child. Rows whose children are all hidden
          # collapse, as they do in GTK.
          #
          # @return [Array<Widget>] the widgets to attach, in order
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

        # Stand-in for Gtk::Table (GTK 2 API, still used): attach(child, left,
        # right, top, bottom). Renders as a contract grid with the declared
        # column count (at most 24); rows grow with the content.
        class Table < Container
          include GridLayout

          # @!attribute [r] n_rows
          #   @return [Integer] the declared row count (informational; rows follow the content)
          # @!attribute [r] n_columns
          #   @return [Integer] the declared column count
          attr_reader :n_rows, :n_columns

          # Creates a table.
          #
          # @param rows [#to_i] the row count, at least 1
          # @param columns [#to_i] the column count, at least 1
          # @param _homogeneous [Object] ignored
          # @return [Table] a new instance
          def initialize(rows = 1, columns = 1, _homogeneous = false)
            super()
            @n_rows = [rows.to_i, 1].max
            @n_columns = [columns.to_i, 1].max
          end

          # Sets the declared row count. Does not re-render; rows follow the content.
          #
          # @param value [#to_i] the row count, at least 1
          # @return [void]
          def n_rows=(value)
            @n_rows = [value.to_i, 1].max
          end
          alias resize_rows n_rows=

          # Sets the column count.
          #
          # @param value [#to_i] the column count, at least 1
          # @return [void]
          def n_columns=(value)
            @n_columns = [value.to_i, 1].max
            changed!
          end

          # Gtk::Table#resize: sets both counts.
          #
          # @param rows [#to_i] the row count
          # @param columns [#to_i] the column count
          # @return [void]
          def resize(rows, columns)
            self.n_rows = rows
            self.n_columns = columns
          end

          # yoptions is dropped on purpose: contract grid rows are content-
          # sized, so there is no vertical free space for EXPAND to claim and
          # nothing for FILL to stretch into. The paddings are dropped because
          # the contract has no per-cell padding, and unlike yoptions a
          # non-zero one changes the layout visibly, so it goes in the ledger.
          #
          # @param child [Widget] the widget to attach
          # @param left [#to_i] the left column edge
          # @param right [#to_i] the right column edge (exclusive)
          # @param top [#to_i] the top row edge
          # @param bottom [#to_i] the bottom row edge (exclusive)
          # @param xoptions [Integer, nil] {AttachOptions} bits; EXPAND marks the column as expanding
          # @param _yoptions [Integer, nil] ignored
          # @param xpadding [#to_i] ignored, logged when non-zero
          # @param ypadding [#to_i] ignored, logged when non-zero
          # @return [self]
          def attach(child, left, right, top, bottom, xoptions = nil, _yoptions = nil, xpadding = 0, ypadding = 0)
            cells[child] = [left.to_i, top.to_i, [right.to_i - left.to_i, 1].max, [bottom.to_i - top.to_i, 1].max]
            # Gtk::EXPAND in the x options is the only place a Table says
            # which column should take the free width -- the label column
            # beside an entry says nothing and must stay natural.
            expanding_columns[left.to_i] = true if expand?(xoptions)
            if xpadding.to_i.positive? || ypadding.to_i.positive?
              Gtk.log_unsupported(short_class_name, 'attach', note: 'xpadding/ypadding are ignored')
            end
            add(child)
          end

          # Whether an attach options value carries the EXPAND bit.
          #
          # @param options [Integer, Object] the xoptions argument
          # @return [Boolean] true only for an Integer with EXPAND set
          def expand?(options)
            options.is_a?(Integer) && (options & AttachOptions::EXPAND).positive?
          end

          # Gtk::Table#attach_defaults: attach with GTK's default options.
          #
          # @param child [Widget] the widget to attach
          # @param left [#to_i] the left column edge
          # @param right [#to_i] the right column edge (exclusive)
          # @param top [#to_i] the top row edge
          # @param bottom [#to_i] the bottom row edge (exclusive)
          # @return [self]
          def attach_defaults(child, left, right, top, bottom)
            attach(child, left, right, top, bottom)
          end

          # Removes a child and forgets its cell.
          #
          # @param child [Widget] the widget to remove
          # @return [self]
          def remove(child)
            cells.delete(child)
            super
          end

          # The declared column count, clamped to the contract's 24 and logged when over.
          #
          # @return [Integer] the columns to render
          def column_count
            clamped = @n_columns.clamp(1, 24)
            Gtk.log_clamped(short_class_name, 'columns', @n_columns, clamped) if @n_columns > 24
            clamped
          end

          # A table is a grid node.
          #
          # @return [Symbol] :grid
          def node_type
            :grid
          end

          # The column count, a fixed gap of 4, and the weights when any column expands.
          #
          # @return [Hash{Symbol => Object}] props for the node
          def node_props
            props = { cols: column_count, gap: 4 }
            weights = column_weights
            props[:weights] = weights if weights
            props
          end
        end

        # Stand-in for Gtk::Grid: attach(child, left, top, width, height).
        # Renders as a contract grid whose column count is derived from the
        # widest cell (at most 24) and whose single gap is the larger of the
        # row and column spacing.
        class Grid < Container
          include GridLayout

          # Creates a grid with 4px spacing on both axes.
          #
          # @return [Grid] a new instance
          def initialize
            super
            @row_spacing = 4
            @column_spacing = 4
          end

          # Attaches a child at a cell with a span.
          #
          # @param child [Widget] the widget to attach
          # @param left [#to_i] the column
          # @param top [#to_i] the row
          # @param width [#to_i] the column span, at least 1
          # @param height [#to_i] the row span, at least 1
          # @return [self]
          def attach(child, left, top, width = 1, height = 1)
            cells[child] = [left.to_i, top.to_i, [width.to_i, 1].max, [height.to_i, 1].max]
            add(child)
          end

          # Gtk::Grid has no attach options; a child asks for the free width
          # with hexpand, and it can be set after attaching, so this is read
          # at render rather than recorded at attach.
          #
          # @return [Hash{Integer => Boolean}] true under the left column of each hexpand child
          def expanding_columns
            @children.each_with_object({}) do |child, result|
              next unless child.respond_to?(:hexpand?) && child.hexpand?

              result[cells.fetch(child, [0, 0, 1, 1]).first] = true
            end
          end

          # Attaches a child beside a sibling. Unlike GTK, the new cell is not
          # offset by the sibling's span, only by one cell in the given direction.
          #
          # @param child [Widget] the widget to attach
          # @param sibling [Widget] an attached child to place it next to
          # @param side [Symbol, String] :right, :bottom, :left, or anything else for top
          # @param width [#to_i] the column span
          # @param height [#to_i] the row span
          # @return [self]
          def attach_next_to(child, sibling, side, width = 1, height = 1)
            left, top, = cells.fetch(sibling, [0, 0, 1, 1])
            case side.to_s
            when 'right' then attach(child, left + 1, top, width, height)
            when 'bottom' then attach(child, left, top + 1, width, height)
            when 'left' then attach(child, [left - 1, 0].max, top, width, height)
            else attach(child, left, [top - 1, 0].max, width, height)
            end
          end

          # Adds a child without a cell: it goes in column 0 of the next free row.
          #
          # @param child [Widget] the widget to add
          # @return [self]
          def add(child)
            cells[child] ||= [0, next_free_row, 1, 1]
            super
          end

          # Removes a child and forgets its cell.
          #
          # @param child [Widget] the widget to remove
          # @return [self]
          def remove(child)
            cells.delete(child)
            super
          end

          # Sets the spacing between rows.
          #
          # @param value [#to_i] the spacing in pixels
          # @return [void]
          def row_spacing=(value)
            @row_spacing = value.to_i
            changed!
          end
          def_setter :set_row_spacing, :row_spacing=

          # Sets the spacing between columns.
          #
          # @param value [#to_i] the spacing in pixels
          # @return [void]
          def column_spacing=(value)
            @column_spacing = value.to_i
            changed!
          end
          def_setter :set_column_spacing, :column_spacing=

          # The rightmost cell edge, clamped to the contract's 24 and logged when over.
          #
          # @return [Integer] the columns to render, at least 1
          def column_count
            cols = @children.map { |child| rect = cells.fetch(child, [0, 0, 1, 1]); rect[0] + rect[2] }.max || 1
            clamped = cols.clamp(1, 24)
            Gtk.log_clamped(short_class_name, 'columns', cols, clamped) if cols > 24
            clamped
          end

          # A grid is a grid node.
          #
          # @return [Symbol] :grid
          def node_type
            :grid
          end

          # The column count, the larger spacing as the gap, and the weights when any column expands.
          #
          # @return [Hash{Symbol => Object}] props for the node
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

        # Stand-in for Gtk::ScrolledWindow, rendered as a contract scroll node.
        # Its two {Adjustment}s are fed by the viewer's `scrolled` event, so
        # a script's scroll arithmetic sees real extents once one arrives.
        # Unlike GTK the scrollbar policy is one switch for both axes, and a
        # script's own adjustments passed to the constructor are ignored.
        class ScrolledWindow < Container
          # Creates a scrolled window with fresh adjustments.
          #
          # @param _hadjustment [Object] ignored
          # @param _vadjustment [Object] ignored
          # @return [ScrolledWindow] a new instance
          def initialize(_hadjustment = nil, _vadjustment = nil)
            super()
            @vadjustment = Adjustment.new
            @hadjustment = Adjustment.new
            @vadjustment.watch(self)
            @hadjustment.watch(self)
          end

          # @!attribute [r] vadjustment
          #   @return [Adjustment] the vertical scroll adjustment
          # @!attribute [r] hadjustment
          #   @return [Adjustment] the horizontal scroll adjustment
          attr_reader :vadjustment, :hadjustment

          # The viewer is the only side that knows the scroll extent, so the
          # `scrolled` event feeds `upper` and `page_size` back into the
          # adjustment. Scripts read those to compute a target (`upper -
          # page_size` is the scroll-to-bottom idiom in vars, alias and
          # localchat) and the arithmetic is nonsense against the defaults.
          #
          # @return [Array<Symbol>] [:scrolled]
          def always_bound_events
            [:scrolled]
          end

          # Feeds a `scrolled` report into both adjustments and replays a
          # pending centre request on the first real extent; every other
          # event goes to the base handling.
          #
          # @param event [Symbol] the contract event
          # @param context [Lich::WebUI::Runtime::EventContext, CarriedEvent] the event's context
          # @return [void]
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
            # Spent either way: replayed just now, or cancelled by a viewer
            # who has scrolled somewhere of their own.
            @centre_request = nil
            super
          end

          # Whether the viewer has ever reported how big this pane really is.
          #
          # @return [Boolean] true after the first `scrolled` event with a page size
          def viewport_known?
            @viewport_known ? true : false
          end

          # Re-centre on whatever the script was aiming at, now that the pane's
          # real size is known. The script computed `target = point -
          # viewport / 2` against allocation, which until now answered with the
          # window's default size; recovering the point it meant and redoing
          # the arithmetic puts the map where it always intended to be.
          #
          # @return [void]
          def replay_centre_request
            return unless @centre_request

            x, y = @centre_request
            centre_viewport_on(x, y)
          end

          # The point a script centred on, recovered from the offset it asked
          # for and the viewport size it believed in at the time.
          #
          # @param guessed_width [Integer] the viewport width allocation answered with
          # @param guessed_height [Integer] the viewport height allocation answered with
          # @return [void]
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

          # Scrolls so that (x, y) sits in the middle of the reported viewport,
          # clamped to the content. An axis given as nil, or one whose page
          # size is unknown, is left alone.
          #
          # @param x [Numeric, nil] the content x to centre on
          # @param y [Numeric, nil] the content y to centre on
          # @return [void]
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
          #
          # @param horizontal [Symbol, String] a {PolicyType} value for the horizontal bar
          # @param vertical [Symbol, String] a {PolicyType} value for the vertical bar
          # @return [self]
          def set_policy(horizontal, vertical)
            @scrollbars_hidden = [horizontal, vertical].all? { |policy| policy.to_s.downcase == 'never' }
            changed!
            self
          end

          # Whether both axes were set to NEVER.
          #
          # @return [Boolean] true when the script asked for no scrollbars
          def scrollbars_hidden?
            @scrollbars_hidden ? true : false
          end

          # Gtk::ScrolledWindow#add_with_viewport: the same as add here.
          #
          # @param child [Widget] the widget to scroll
          # @return [self]
          def add_with_viewport(child)
            add(child)
          end

          # Gtk::ScrolledWindow#set_shadow_type: accepted and ignored.
          #
          # @param _type [Object] ignored
          # @return [self]
          def set_shadow_type(_type)
            self
          end
          alias shadow_type= set_shadow_type

          # Records the minimum content height. Nothing renders it yet.
          #
          # @param value [#to_i] the height in pixels
          # @return [self]
          def set_min_content_height(value)
            @min_height = value.to_i
            self
          end
          alias min_content_height= set_min_content_height

          # A scrolled window is a scroll node.
          #
          # @return [Symbol] :scroll
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
          #
          # @return [Allocation] the reported viewport size, per axis, else the base answer
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

          # Only the height, and only for a nested scroller; one filling its window is sized by the page.
          #
          # @return [Array<Symbol>] [] or [:height]
          def size_request_axes
            parent.is_a?(Window) ? [] : [:height]
          end

          # A max height for a nested scroller, and the requested scroll position if any.
          #
          # @return [Hash{Symbol => Object}] props for the node
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
          #
          # @return [void]
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
          # @api private
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

        # Stand-in for Gtk::Viewport: a plain stack, since the browser scrolls
        # whatever a scroll node holds.
        class Viewport < Container
          # Creates a viewport; the adjustments are ignored.
          #
          # @param _hadjustment [Object] ignored
          # @param _vadjustment [Object] ignored
          # @return [Viewport] a new instance
          def initialize(_hadjustment = nil, _vadjustment = nil)
            super()
          end

          # A viewport is a stack node.
          #
          # @return [Symbol] :stack
          def node_type
            :stack
          end

          # No gap.
          #
          # @return [Hash{Symbol => Object}] props for the node
          def node_props
            { gap: 0 }
          end
        end

        # Gtk::Alignment (deprecated in GTK 3, still the most-used container
        # in these scripts at ~400 call sites): one child, positioned by
        # xalign/yalign unless the matching scale is 1.0, which means fill.
        # Renders as a stack; only the horizontal alignment and the padding
        # reach the contract.
        class Alignment < Container
          # Creates an alignment.
          #
          # @param xalign [#to_f] horizontal position of the child, 0.0 (left) to 1.0 (right)
          # @param yalign [#to_f] vertical position, recorded but not rendered
          # @param xscale [#to_f] how much of the free width the child takes; 1.0 means fill
          # @param yscale [#to_f] vertical scale, recorded but not rendered
          # @return [Alignment] a new instance
          def initialize(xalign = 0.0, yalign = 0.0, xscale = 0.0, yscale = 0.0)
            super()
            @xalign = xalign.to_f
            @yalign = yalign.to_f
            @xscale = xscale.to_f
            @yscale = yscale.to_f
            @padding = { top: 0, bottom: 0, left: 0, right: 0 }
          end

          # Gtk::Alignment#set: changes the alignment and, optionally, the scales.
          #
          # @param xalign [#to_f] horizontal position, 0.0 to 1.0
          # @param yalign [#to_f] vertical position, 0.0 to 1.0
          # @param xscale [#to_f] horizontal scale; defaults to the current one
          # @param yscale [#to_f] vertical scale; defaults to the current one
          # @return [self]
          def set_alignment(xalign, yalign, xscale = @xscale, yscale = @yscale)
            @xalign = xalign.to_f
            @yalign = yalign.to_f
            @xscale = xscale.to_f
            @yscale = yscale.to_f
            changed!
            self
          end

          # Gtk::Alignment#set_padding: four edges, rendered as the node's margin.
          #
          # @param top [#to_i] top padding in pixels
          # @param bottom [#to_i] bottom padding in pixels
          # @param left [#to_i] left padding in pixels
          # @param right [#to_i] right padding in pixels
          # @return [self]
          def set_padding(top, bottom, left, right)
            @padding = {
              top: top.to_i, bottom: bottom.to_i, left: left.to_i, right: right.to_i,
            }
            changed!
            self
          end

          # An alignment is a stack node.
          #
          # @return [Symbol] :stack
          def node_type
            :stack
          end

          # The common props plus the horizontal alignment (unless filling or
          # overridden by halign) and the padding as a margin.
          #
          # @return [Hash{Symbol => Object}] props for the node
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

          # No gap.
          #
          # @return [Hash{Symbol => Object}] props for the node
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

        # Stand-in for Gtk::Frame, rendered as a contract group. A label widget
        # contributes its text only; the widget itself is not rendered.
        class Frame < Container
          # Creates a frame.
          #
          # @param label [#to_s, nil] the frame's label
          # @return [Frame] a new instance
          def initialize(label = nil)
            super()
            @label = label.to_s
            @label_widget = nil
          end

          # The frame's label text.
          #
          # @return [String] the label, possibly empty
          def label
            @label
          end

          # Sets the label text.
          #
          # @param value [#to_s] the label
          # @return [void]
          def label=(value)
            @label = value.to_s
            changed!
          end
          def_setter :set_label, :label=

          # Uses a widget as the label; its text (if it has any) becomes the group label.
          #
          # @param widget [Widget] the label widget
          # @return [self]
          def set_label_widget(widget)
            @label_widget = widget
            @label = widget.respond_to?(:text) ? widget.text.to_s : @label
            changed!
            self
          end
          alias label_widget= set_label_widget

          # The label widget, if one was set.
          #
          # @return [Widget, nil] the label widget
          def label_widget
            @label_widget
          end

          # Gtk::Frame#set_label_align: accepted and ignored.
          #
          # @param _args [Array] ignored
          # @return [self]
          def set_label_align(*_args)
            self
          end

          # A frame is a group node.
          #
          # @return [Symbol] :group
          def node_type
            :group
          end

          # The label, read live from the label widget when there is one.
          #
          # @return [Hash{Symbol => Object}] props for the node
          def node_props
            text = @label_widget.respond_to?(:text) ? @label_widget.text.to_s : @label
            { label: text.empty? ? ' ' : text }
          end
        end

        # Stand-in for Gtk::EventBox: a stack that receives pointer gestures
        # through {PointerSurface}.
        class EventBox < Container
          prepend PointerSurface

          # An event box is a stack node.
          #
          # @return [Symbol] :stack
          def node_type
            :stack
          end

          # No gap.
          #
          # @return [Hash{Symbol => Object}] props for the node
          def node_props
            { gap: 0 }
          end
        end

        # Scroll adjustments and SpinButton ranges: real state, so scripts
        # that read or animate them see sane numbers. Owners re-render when
        # the range changes. Stand-in for Gtk::Adjustment; not a widget.
        class Adjustment
          extend Setters
          # How close to `upper - page_size` a written value may be to count as the extent.
          EXTENT_EPSILON = 0.5

          # @!attribute [r] value
          #   @return [Float] the current value
          # @!attribute [r] lower
          #   @return [Float] the range's lower bound
          # @!attribute [r] upper
          #   @return [Float] the range's upper bound
          # @!attribute [r] page_size
          #   @return [Float] the visible page size
          # @!attribute [r] step_increment
          #   @return [Float] the step increment
          # @!attribute [r] page_increment
          #   @return [Float] the page increment
          attr_reader :value, :lower, :upper, :page_size, :step_increment, :page_increment
          # @!attribute builder_name
          #   @return [String, nil] the id a GtkBuilder file gave this adjustment
          attr_accessor :builder_name

          # The defaults are load-bearing, not decorative. Until the viewer
          # reports an extent, upper 100.0 and page_size 0.0 are what
          # #at_extent? compares a script's write against: `value = upper -
          # page_size` computed against them lands exactly on 100, which is
          # how the shim tells "the script means the bottom" from a pixel
          # offset it worked out for itself. Change them and scroll-to-end in
          # every log window silently becomes a scroll to a random pixel.
          #
          # @param value [#to_f] the initial value
          # @param lower [#to_f] the lower bound
          # @param upper [#to_f] the upper bound
          # @param step [#to_f] the step increment
          # @param page_inc [#to_f] the page increment
          # @param page_size [#to_f] the page size
          # @return [Adjustment] a new instance
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

          # Registers a widget to notify when the adjustment changes. An owner
          # with `adjustment_moved` gets that; otherwise `changed!`.
          #
          # @param owner [Widget] the widget that renders this adjustment
          # @return [void]
          def watch(owner)
            @owners << owner unless @owners.include?(owner)
          end

          # Whether the script has written a value we have not yet rendered.
          # nil means it never did, so the scroll node stays silent rather
          # than pinning the viewer to the top on every commit.
          #
          # @return [Float, nil] the last value the script wrote, until the viewer reports
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
          #
          # @return [Boolean] true when the requested value sits on `upper - page_size`
          def at_extent?
            return false unless @requested_value
            # Past the extent is a pixel the script computed against a bigger
            # canvas than we know about, not a request for the end.
            return false if @requested_value > (@upper - @page_size) + EXTENT_EPSILON

            @requested_value >= (@upper - @page_size) - EXTENT_EPSILON
          end

          # The viewer reporting where it actually is, and how big the content
          # turned out to be. This is the only source of a true extent.
          #
          # @param value [Numeric, nil] the viewer's current position; clears the requested value
          # @param upper [Numeric, nil] the content extent
          # @param page_size [Numeric, nil] the viewport size
          # @return [self]
          def note_viewport(value: nil, upper: nil, page_size: nil)
            @upper = upper.to_f if upper
            @page_size = page_size.to_f if page_size
            if value
              @value = value.to_f
              @requested_value = nil
            end
            self
          end

          # @!method lower=(number)
          #   Sets one bound of the range and notifies the owners. Also upper=,
          #   page_size=, step_increment= and page_increment=, each with a set_*
          #   alias (which, being a plain alias, returns the argument).
          #   @param number [#to_f] the new value
          #   @return [void]
          %i[lower upper page_size step_increment page_increment].each do |attribute|
            define_method(:"#{attribute}=") do |number|
              instance_variable_set(:"@#{attribute}", number.to_f)
              notify_owners
            end
            alias_method :"set_#{attribute}", :"#{attribute}="
          end

          # Recorded as a request, not just shadow state: a ScrolledWindow
          # turns it into a scroll_position prop on the next commit.
          #
          # @param number [#to_f] the new value
          # @return [void]
          def value=(number)
            @value = number.to_f
            @requested_value = @value
            notify_owners
          end
          def_setter :set_value, :value=

          # Gtk::Adjustment#configure: sets every field at once and notifies the owners.
          #
          # @param value [#to_f] the value, recorded as a request
          # @param lower [#to_f] the lower bound
          # @param upper [#to_f] the upper bound
          # @param step [#to_f] the step increment
          # @param page_inc [#to_f] the page increment
          # @param page_size [#to_f] the page size
          # @return [void]
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

          # Records a handler. Adjustment signals are never emitted here; the
          # block is kept so the call does not raise.
          #
          # @param _signal [String, Symbol] ignored
          # @yield never called
          # @return [Integer] the handler count, standing in for a handler id
          def signal_connect(_signal, &block)
            @handlers << block if block
            @handlers.length
          end

          # Applies a GtkBuilder <property> through the matching writer, if there is one.
          #
          # @param name [String, Symbol] the property name
          # @param value [Object] the property text, coerced through {Gtk.builder_value}
          # @return [self]
          def apply_builder_property(name, value)
            setter = "#{name.to_s.tr('-', '_')}="
            public_send(setter, Gtk.builder_value(value)) if respond_to?(setter)
            self
          end

          private

          # An owner whose value is viewer-scoped (SpinButton) has to push it,
          # not just re-render: `spin.adjustment.value = x` bypassed the
          # owner's own setter and the viewer kept the old number.
          # @api private
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
        # Stand-in for Gtk::Window: a contract page. Showing it opens a browser
        # window through the session; its signals (destroy, delete-event,
        # key-press-event) are page lifecycle rather than component events.
        # Position, icon and modality are accepted and ignored; keep-above,
        # decoration and opacity go to the viewer's `presentation` facility.
        class Window < Container
          TOPLEVEL = WindowType::TOPLEVEL
          POPUP = WindowType::POPUP

          # @!attribute [r] title
          #   @return [String] the window title, possibly empty
          # @!attribute [r] default_width
          #   @return [Integer, nil] the default width set by the script
          # @!attribute [r] default_height
          #   @return [Integer, nil] the default height set by the script
          attr_reader :title, :default_width, :default_height

          # Creates a window and registers it with the session.
          #
          # @param arg [String, Symbol, nil] the title, or a {WindowType} that is ignored
          # @param _rest [Array] ignored
          # @return [Window] a new instance
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

          # Sets the window title.
          #
          # @param value [#to_s] the title
          # @return [void]
          def title=(value)
            @title = value.to_s
            changed!
          end
          def_setter :set_title, :title=

          # Hands each input in a submission scope the value the viewer typed
          # into it. The scope hangs off the terminal that submitted -- a
          # button, or a dialog's response -- so the inputs themselves never
          # see the event, and a script that reads `entry.text` from that
          # terminal's handler would otherwise read a stale value.
          #
          # @param carried [Hash{String => String}, nil] submitted values by cid
          # @return [void]
          def distribute_submitted(carried)
            return if carried.nil? || carried.empty?

            each_submittable do |widget|
              cid = widget.send(:rendered_cid)
              next unless cid

              value = carried[cid]
              widget.accept_submitted(value) unless value.nil?
            end
          end

          # Walks the widget tree. respond_to? is honest since D4, so the
          # capability test is the ordinary one.
          #
          # @param node [Widget] the subtree root; the window itself by default
          # @yieldparam widget [Widget] each widget that responds to accept_submitted
          # @return [void]
          def each_submittable(node = self, &block)
            yield node if node.respond_to?(:accept_submitted)
            return unless node.respond_to?(:children)

            # A Bin reports its single child through #children, but a widget
            # that has none at all reports nil rather than an empty list.
            Array(node.children).each { |child| each_submittable(child, &block) }
          end

          # Sets the size the browser window opens at. Non-positive values clear that axis.
          #
          # @param width [#to_i] the width in pixels, or -1 for the content's
          # @param height [#to_i] the height in pixels, or -1 for the content's
          # @return [self]
          def set_default_size(width, height)
            @default_width = width.to_i.positive? ? width.to_i : nil
            @default_height = height.to_i.positive? ? height.to_i : nil
            changed!
            self
          end

          # Sets the default width, keeping the height.
          #
          # @param width [#to_i] the width in pixels
          # @return [void]
          def default_width=(width)
            set_default_size(width, @default_height || -1)
          end

          # Sets the default height, keeping the width.
          #
          # @param height [#to_i] the height in pixels
          # @return [void]
          def default_height=(height)
            set_default_size(@default_width || -1, height)
          end

          # Gtk::Window#resize: the same as set_default_size here.
          #
          # @param width [#to_i] the width in pixels
          # @param height [#to_i] the height in pixels
          # @return [self]
          def resize(width, height)
            set_default_size(width, height)
          end

          # A window's size request is Widget's: a minimum, not a size, since
          # GTK grows a window past it to fit the content. It used to stand
          # in for a default size when the script gave none, which would have
          # made bigshot's 450x25 request the window's size once the client
          # honoured geometry; the client's content measurement is what
          # GTK's natural size is.

          # Gtk::Window#set_icon: accepted and ignored.
          #
          # @param _icon [Object] ignored
          # @return [self]
          def set_icon(_icon)
            self
          end
          alias icon= set_icon

          # Gtk::Window#set_window_position: accepted and ignored.
          #
          # @param _position [Object] ignored
          # @return [self]
          def set_window_position(_position)
            self
          end
          alias window_position= set_window_position

          # Asks for the window to stay above others.
          #
          # The four presentation properties. Kept as shadow state because
          # scripts read them back -- creaturebar persists `decorated?` to
          # its config file -- and declared to the viewer through the
          # `presentation` facility, which refuses what a browser cannot do
          # and records the refusal as a degradation.
          #
          # @param value [Object] truthy to keep above
          # @return [self]
          def set_keep_above(value)
            @keep_above = value ? true : false
            changed!
            self
          end
          alias keep_above= set_keep_above

          # Whether keep-above was requested.
          #
          # @return [Boolean] true after set_keep_above(true)
          def keep_above?
            @keep_above ? true : false
          end

          # Records resizability. Shadow state only; a browser window cannot refuse a resize.
          #
          # @param value [Object] truthy for resizable
          # @return [self]
          def set_resizable(value)
            @resizable = value ? true : false
            changed!
            self
          end
          alias resizable= set_resizable

          # Whether the window is resizable; true until set otherwise.
          #
          # @return [Boolean] the recorded value
          def resizable?
            @resizable.nil? ? true : @resizable
          end
          alias resizable resizable?

          # Sets whether the window has decorations; false asks the viewer for a borderless window.
          #
          # @param value [Object] truthy for decorated
          # @return [self]
          def set_decorated(value)
            @decorated = value ? true : false
            changed!
            self
          end
          alias decorated= set_decorated

          # Whether the window is decorated; true until set otherwise.
          #
          # @return [Boolean] the recorded value
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
          #
          # @param value [#to_f] the opacity, clamped to 0.0..1.0
          # @return [self]
          def set_opacity(value)
            @opacity = value.to_f.clamp(0.0, 1.0)
            changed!
            self
          end
          alias opacity= set_opacity

          # The recorded opacity; 1.0 until set.
          #
          # @return [Float] the opacity
          def opacity
            @opacity.nil? ? 1.0 : @opacity
          end

          # Materializes the page and keeps its facilities (presentation,
          # geometry) current beside the tree.
          #
          # Handles are opaque, so the adapter cannot find this widget from
          # its node; the window hands over a reader instead, once.
          #
          # @param adapter [Lich::WebUI::Adapter] the session's adapter
          # @return [Lich::WebUI::Adapter::Handle] the page's handle
          def materialize!(adapter)
            handle = super
            if handle && !@presentation_registered && adapter.respond_to?(:presentation_source)
              window = self
              adapter.presentation_source(handle) { window.page_facilities }
              @presentation_registered = true
            end
            # Facilities live beside the tree, not in a prop, so the base
            # materialize sees nothing to update when only opacity moved.
            if handle && @synced_presentation != page_facilities
              @synced_presentation = page_facilities
              adapter.refresh_facilities(handle) if adapter.respond_to?(:refresh_facilities)
              # keep_above and opacity belong to the OS window, which the page
              # cannot reach; the session carries them there if this host can.
              @session.apply_window_presentation(self)
            end
            handle
          end

          # Every facility this window declares on its page, by name; nil
          # values are not declared.
          #
          # @return [Hash{Symbol => Hash}] the declared facilities
          def page_facilities
            { presentation: presentation, geometry: geometry_facility }.compact
          end

          # The `geometry` facility: the window size a script asked for with
          # set_default_size, which the client makes the browser window's
          # size on the page's first render (--window-size is ignored once
          # Chrome is running). A size request is a minimum, not a size, so
          # it is left to the client's content measurement. An axis the
          # script did not set is 0: "the content's".
          #
          # @return [Hash{Symbol => Integer}, nil] width and height, or nil when neither was set
          def geometry_facility
            return nil unless @default_width || @default_height

            { width: @default_width || 0, height: @default_height || 0 }
          end

          # What the `presentation` facility should say, or nil when the
          # script never asked for anything.
          #
          # @return [Hash{Symbol => Object}, nil] always_on_top, borderless, opacity, scrollbars as set
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
          #
          # @return [Boolean] true when there are scrollers and all hide their bars
          def scrollbars_hidden?
            scrollers = []
            collect_scrollers(self, scrollers)
            !scrollers.empty? && scrollers.all?(&:scrollbars_hidden?)
          end

          # Tested by class: the question is what the widget IS, since only a
          # ScrolledWindow has bars to hide.
          # @api private
          def collect_scrollers(widget, found)
            found << widget if widget.is_a?(ScrolledWindow)
            return unless widget.is_a?(Container)

            widget.children.each { |child| collect_scrollers(child, found) }
          end
          private :collect_scrollers

          # Gtk::Window#modal=: accepted and ignored.
          #
          # @param _value [Object] ignored
          # @return [void]
          def modal=(_value); end
          def_setter :set_modal, :modal=

          # Gtk::Window#move: accepted and ignored; the browser places its windows.
          #
          # @param _x [Object] ignored
          # @param _y [Object] ignored
          # @return [self]
          def move(_x, _y)
            self
          end

          # Gtk::Window#position: always the origin.
          #
          # @return [Array<Integer>] [0, 0]
          def position
            [0, 0]
          end

          # The default size, or 640x480 when none was set.
          #
          # @return [Allocation] a rectangle at the origin
          def allocation
            Allocation.new(0, 0, @default_width || 640, @default_height || 480)
          end

          # Gtk::Window#size: the default size, or 640x480 when none was set.
          #
          # @return [Array<Integer>] [width, height]
          def size
            [@default_width || 640, @default_height || 480]
          end

          # Shows the window. Children are not recursed into: they start visible.
          #
          # @return [self]
          def show_all
            show
          end

          # Shows the window: opens it through the session the first time, and
          # requests a commit on later calls.
          #
          # @return [self]
          def show
            super
            if @shown
              @session.request_commit
            else
              @shown = true
              @session.enqueue { @session.show_window(self) }
            end
            self
          end

          # Gtk::Window#present: the same as show here.
          #
          # @return [self]
          def present
            show
          end

          # Emits destroy and closes the window through the session.
          #
          # @return [nil]
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
          #
          # @return [Object, nil] the last delete-event handler's result, or nil when nothing ran
          def viewer_closed
            return if @delete_emitted || @destroyed

            @delete_emitted = true
            emit(:delete_event, Event.new(:delete))
          end

          # Whether the session has bound this window's lifecycle signals to its page.
          #
          # @return [Boolean] true once bound
          def lifecycle_bound?
            @lifecycle_bound
          end

          # Marks the lifecycle signals as bound. Called by the session.
          #
          # @return [void]
          def lifecycle_bound!
            @lifecycle_bound = true
          end

          # The browser window, which opens at the size GTK would have used:
          # the default, or the size request when that is larger.
          #
          # @return [Hash{Symbol => Integer}, nil] width and height, or nil unless both are known
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
          #
          # @return [nil] always
          def event_for(*)
            nil
          end

          # True once a script has connected key-press-event. Read at bind time
          # (session) and at render (node_props) so the prop and the binding
          # go together -- the validator refuses a `key` event on a page that
          # did not ask for it, exactly as a composite opts into surface_events.
          #
          # @return [Boolean] true when a key-press-event handler is connected
          def key_wanted?
            @handlers.key?(:key_press_event)
          end

          # A browser keydown arrived on the page root. Rebuild the Gdk-shaped
          # event a GTK key handler expects and emit key-press-event to the
          # script's own handlers, trimmed to each block's arity.
          #
          # @param context [Lich::WebUI::Runtime::EventContext] the key event's context
          # @return [Object, nil] the last handler's result, or nil with no handlers
          def receive_key(context)
            payload = context.payload || {}
            keyval = Gtk.keyval_for(payload[:keyval] || payload['keyval'])
            modifiers = Array(payload[:modifiers] || payload['modifiers']).map(&:to_s)
            state = ModifierState.new(modifiers.include?('ctrl'), modifiers.include?('shift'), modifiers.include?('alt'))
            gdk = Event.new(:key_press, nil, state, keyval, nil, nil, nil,
                            Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond))
            emit(:key_press_event, gdk)
          end

          # A window is a page node.
          #
          # @return [Symbol] :page
          def node_type
            :page
          end

          # The title (defaulting to "Lich"), bare page flag, size, and key-event opt-in.
          #
          # @return [Hash{Symbol => Object}] props for the page
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

          # Only the key: a page has no hidden, size, align or margin props.
          #
          # @return [Hash{Symbol => Object}] props for the page
          def common_props
            { key: @key }
          end
        end

        # Stock button labels. Without this, const_missing turned `Stock` into
        # an empty widget class and `Gtk::Stock::OK` raised NameError -- which
        # is where map's room-list dialog died. Stand-in for Gtk::Stock; the
        # values are plain label strings rather than stock ids.
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
          # Creates a dialog with an empty content area and action row.
          #
          # @param title [#to_s, nil] the window title
          # @param parent [Object, nil] ignored
          # @param flags [Object, nil] ignored
          # @param buttons [Array<Array(String, Object)>, nil] (label, response) pairs to add
          # @param _options [Hash] ignored
          # @return [Dialog] a new instance
          def initialize(title: nil, parent: nil, flags: nil, buttons: nil, **_options)
            # to_s: a nil title would reach the page as a nil prop. Lich's
            # NilClass patch answers nil.empty? with nil, so node_props' own
            # guard would let it through and the page fail validation.
            super(title.to_s)
            @content = VBox.new
            @actions = HBox.new
            @runs = [] # one Future per thread parked in #run (D15)
            @runs_mutex = Mutex.new
            Container.instance_method(:add).bind_call(self, @content)
            Container.instance_method(:add).bind_call(self, @actions)
            Array(buttons).each { |(label, response)| add_button(label, response) }
          end
          # rubocop:enable Lint/UnusedMethodArgument

          # The vertical box scripts put their content in.
          #
          # @return [VBox] the content area
          def content_area
            @content
          end
          alias child content_area
          alias vbox content_area

          # The horizontal box holding the response buttons.
          #
          # @return [HBox] the action area
          def action_area
            @actions
          end

          # A script's `dialog.add(widget)` means the content area, not a
          # third top-level child beside the buttons.
          #
          # @param child [Widget] the widget to add to the content area
          # @return [self]
          def add(child)
            @content.add(child)
            self
          end

          # Adds a response button to the action area.
          #
          # @param label [#to_s] the button label
          # @param response [Object] the value {#run} returns when it is pressed
          # @return [Button] the new button
          def add_button(label, response)
            button = Button.new(label.to_s)
            dialog = self
            button.signal_connect(:clicked) { dialog.respond(response) }
            @actions.add(button)
            changed!
            button
          end

          # Adds an existing widget to the action area, responding when it is clicked.
          #
          # @param widget [Widget] the widget; connected to clicked if it can be
          # @param response [Object] the value {#run} returns when it is clicked
          # @return [self]
          def add_action_widget(widget, response)
            dialog = self
            widget.signal_connect(:clicked) { dialog.respond(response) } if widget.respond_to?(:signal_connect)
            @actions.add(widget)
            self
          end

          # Gtk::Dialog#set_default_response: accepted and ignored.
          #
          # @param _response [Object] ignored
          # @return [self]
          def set_default_response(_response)
            self
          end
          alias default_response= set_default_response

          # Answers every run parked on this dialog. run promises to return
          # the very object given to add_button, and false and nil are legal
          # ones: `add_button('No', false)` is how a yes/no dialog is
          # spelled. A Future's result carries the answer as its button and
          # a cancellation as its reason, so false and nil survive and only
          # a reason means nobody answered.
          #
          # @param response [Object] the response, exactly as given to add_button
          # @return [self]
          def respond(response)
            each_run { |future| future.resolve(button: response) }
            emit(:response, response)
            self
          end
          alias response respond

          # Blocks until answered, cancelled, or destroyed. Each run waits on
          # its own Future (D15) -- the same thing a MessageDialog waits on,
          # tracked by the session so shutdown cancels both through one
          # path -- so a run answered twice leaves nothing for the next run
          # to pop, and two threads waiting on one dialog are both released.
          #
          # @return [Object] the response object passed to add_button, or
          #   {ResponseType::DELETE_EVENT} when closed, destroyed or shut down
          def run
            show unless @shown
            future = @session.await_answer
            @runs_mutex.synchronize { @runs << future }
            if @session.on_session_thread?
              @session.commit
              @session.pump(0.05) until future.resolved? || destroyed?
            else
              @session.request_commit
              future.await
            end
            answer_from(future)
          ensure
            @runs_mutex.synchronize { @runs.delete(future) } if future
          end

          # Releases every parked run with DELETE_EVENT, then destroys the window.
          #
          # @return [nil]
          def destroy
            cancel_runs(:destroyed)
            super
          end

          # The viewer closing the window is the ordinary way a dialog goes
          # away, and since D1 it is the only viewer-side way: nothing
          # watches the browser process any more, so a closed window arrives
          # through the page's detach/close lifecycle and lands here. Without
          # this, `run` waited on a queue nobody would ever push to: a plain
          # confirmation dialog with no :delete_event handler hung the
          # script forever. The base class emits :delete_event; the waiters
          # have to be let go too.
          #
          # @return [void]
          def viewer_closed
            return if @delete_emitted || destroyed?

            super
            cancel_runs(:closed)
          end

          private

          def each_run(&block)
            @runs_mutex.synchronize { @runs.dup }.each(&block)
          end

          # Releases every thread parked in #run with DELETE_EVENT. The
          # session's own shutdown reaches the same Futures through
          # Session#cancel_pending_answers; this is the dialog-side path.
          # @api private
          def cancel_runs(reason)
            @destroyed = true
            each_run { |future| future.cancel(reason: reason) }
          end

          # The run's answer, or DELETE_EVENT when it was cancelled -- by the
          # viewer, by destroy, or by the session shutting down, which also
          # makes the dialog report itself destroyed. An unresolved Future
          # here means the pump loop ended on destroyed?.
          # @api private
          def answer_from(future)
            result = future.await(timeout: 0)
            return ResponseType::DELETE_EVENT if result.nil?

            if result.reason
              @destroyed = true if result.reason == :terminated
              return ResponseType::DELETE_EVENT
            end
            result.button
          end
        end

        # ------------------------------------------------------------------
        # Simple leaf widgets
        # ------------------------------------------------------------------
        # Stand-in for Gtk::Label, rendered as a contract text node. Pango
        # markup is passed through when the validator accepts it and
        # otherwise stripped to plain text; links become their target text.
        class Label < Widget
          prepend PointerSurface

          # Matches a Pango <a href> link, capturing the target and the inner text.
          LINK = %r{<a\s[^>]*href="([^"]*)"[^>]*>(.*?)</a>}m
          @markup_cache = {}
          @markup_cache_mutex = Mutex.new

          class << self
            # Validates a Pango markup string once and remembers the verdict;
            # labels re-render often and the validator parses XML.
            #
            # @param markup [String] the markup to validate
            # @return [Boolean] true when the contract accepts it
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

          # Creates a label.
          #
          # @param text [#to_s, nil] the label text
          # @param _mnemonic [Object] ignored
          # @return [Label] a new instance
          def initialize(text = nil, _mnemonic = false)
            super()
            @text = text.to_s
            @raw = @text
            @markup = false
            @markup_source = nil
            @wrap = false
          end

          # The plain text, with any markup stripped.
          #
          # @return [String] the text
          def text
            @text
          end

          # Sets plain text, turning markup off.
          #
          # @param value [#to_s] the text
          # @return [void]
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
          #
          # @param markup [#to_s] the Pango markup
          # @return [self]
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

          # Turns markup on for text already set; turning it off is a no-op.
          #
          # @param value [Object] truthy to parse the current text as markup
          # @return [void]
          def use_markup=(value)
            set_markup(@raw) if value && !@markup
          end
          def_setter :set_use_markup, :use_markup=

          # Whether the text was set as markup.
          #
          # @return [Boolean] true after set_markup or use_markup = true
          def use_markup?
            @markup
          end

          # GTK's xalign places the text inside the cell the label was given.
          #
          # @param value [#to_f] 0.0 (start) to 1.0 (end); the middle half is centred
          # @return [void]
          def xalign=(value)
            value = value.to_f
            @xalign = if value <= 0.25 then :start
                      elsif value >= 0.75 then :end
                      else :center
                      end
            changed!
          end
          def_setter :set_xalign, :xalign=

          # Gtk::Misc#set_alignment: sets xalign; yalign is ignored.
          #
          # @param xalign [#to_f] 0.0 to 1.0
          # @param _yalign [Object] ignored
          # @return [self]
          def set_alignment(xalign, _yalign = nil)
            self.xalign = xalign
            self
          end

          # The common props, plus the xalign as `align` unless halign was set.
          #
          # @return [Hash{Symbol => Object}] props for the node
          def common_props
            props = super
            props[:align] = @xalign.to_s if @xalign && !@halign
            props
          end

          # Sets whether the text wraps.
          #
          # @param value [Object] truthy to wrap
          # @return [self]
          def set_wrap(value)
            @wrap = value ? true : false
            changed!
            self
          end
          alias wrap= set_wrap
          alias set_line_wrap set_wrap
          alias line_wrap= set_wrap

          # Whether the text wraps.
          #
          # @return [Boolean] true when wrapping
          def wrap?
            @wrap
          end

          # Gtk::Label#width_chars=: accepted and ignored.
          #
          # A label's width-chars is a wrap hint; text wraps naturally here.
          #
          # @param _chars [Object] ignored
          # @return [void]
          def width_chars=(_chars); end
          def_setter :set_width_chars, :width_chars=
          alias max_width_chars= width_chars=
          def_setter :set_max_width_chars, :width_chars=

          # Gtk::Label#set_selectable: accepted and ignored.
          #
          # @param _value [Object] ignored
          # @return [self]
          def set_selectable(_value)
            self
          end
          alias selectable= set_selectable

          # Applies a builder property; "label" sets the text.
          #
          # @param name [String, Symbol] the property name
          # @param value [Object] the property value
          # @return [self]
          def apply_builder_property(name, value)
            return (self.text = value) && self if name.to_s == 'label'

            super
          end

          # A label is a text node.
          #
          # @return [Symbol] :text
          def node_type
            :text
          end

          # The content, wrap flag, allowed markup, and subtle emphasis when insensitive.
          #
          # @return [Hash{Symbol => Object}] props for the node
          def node_props
            props = { content: @text.empty? ? ' ' : @text, wrap: @wrap }
            props[:markup] = @markup_source if @markup_source && self.class.markup_allowed?(@markup_source)
            props[:emphasis] = 'subtle' unless @sensitive
            props
          end
        end

        # Stand-in for Gtk::Separator, rendered as a contract divider. The
        # orientation is recorded but the divider is always horizontal.
        class Separator < Widget
          # Creates a separator.
          #
          # @param orientation [Symbol] :horizontal or :vertical
          # @return [Separator] a new instance
          def initialize(orientation = :horizontal)
            super()
            @orientation = orientation
          end

          # Records the orientation.
          #
          # @param value [Symbol, String] anything starting with "v" is vertical
          # @return [void]
          def orientation=(value)
            @orientation = value.to_s.start_with?('v') ? :vertical : :horizontal
          end

          # A separator is a divider node.
          #
          # @return [Symbol] :divider
          def node_type
            :divider
          end
        end

        # Stand-in for the deprecated Gtk::HSeparator.
        class HSeparator < Separator
          # Creates a horizontal separator.
          #
          # @return [HSeparator] a new instance
          def initialize
            super(:horizontal)
          end
        end

        # Stand-in for the deprecated Gtk::VSeparator.
        class VSeparator < Separator
          # Creates a vertical separator.
          #
          # @return [VSeparator] a new instance
          def initialize
            super(:vertical)
          end
        end

        # Stand-in for Gtk::Entry, rendered as a text_input, or as a
        # password_input once visibility is turned off. A password's value is
        # never echoed to the viewer and reaches the script only through a
        # submission scope (a button click or dialog response).
        class Entry < Widget
          # Creates an empty, editable entry.
          #
          # @param _args [Array] ignored
          # @return [Entry] a new instance
          def initialize(*_args)
            super()
            @text = +''
            @editable = true
            @placeholder = nil
            @max_length = nil
          end

          # The current text, as last typed or set.
          #
          # @return [String] a copy of the text
          def text
            @text.dup
          end

          # Sets the text. A visible entry pushes it to every viewer; a
          # password entry can only tell the browser to clear its field.
          #
          # @param value [#to_s] the new text
          # @return [void]
          def text=(value)
            previous = @text
            @text = value.to_s.dup
            # A password's value is write-only by contract, so there is no
            # property to push: the runtime refuses the write and the browser
            # keeps showing what was typed. Scripts use this to wipe a rejected
            # password (`password_entry.text = ""`), and the viewer's own field
            # is cleared by the runtime's clear_sensitive after the submit that
            # delivered it. Zero the old plaintext rather than leaving it on the
            # heap for the GC to release whenever it gets round to it.
            if visibility?
              viewer_push(:value, @text)
            else
              # The browser cannot be told the new value, only to drop the old
              # one -- which is what a script clearing a rejected password
              # wants, and closer to right than stale text for any other.
              @session.viewer_clear_sensitive(window_root, self) if @handle
              previous.replace("\0" * previous.bytesize) unless previous.equal?(@text) || previous.frozen?
              changed!
            end
          end
          def_setter :set_text, :text=

          # Sets whether the viewer can type into the entry.
          #
          # @param value [Object] truthy for editable
          # @return [void]
          def editable=(value)
            @editable = value ? true : false
            changed!
          end
          def_setter :set_editable, :editable=

          # Only the width request reaches the node.
          #
          # @return [Array<Symbol>] [:width]
          def size_request_axes
            [:width]
          end

          # Approximates GTK's character-width sizing in pixels.
          #
          # @param chars [#to_i] the width in characters; non-positive values are ignored
          # @return [void]
          def width_chars=(chars)
            set_size_request((chars.to_i * 8) + 24, @height_request || -1) if chars.to_i.positive?
          end
          def_setter :set_width_chars, :width_chars=

          # Whether the entry is editable.
          #
          # @return [Boolean] true unless editability was turned off
          def editable?
            @editable
          end

          # Sets the placeholder shown when the entry is empty.
          #
          # @param value [#to_s, nil] the placeholder, or nil to clear it
          # @return [void]
          def placeholder_text=(value)
            @placeholder = value&.to_s
            changed!
          end
          def_setter :set_placeholder_text, :placeholder_text=

          # Sets the maximum length; non-positive values (GTK's 0) mean no limit.
          #
          # @param value [#to_i] the limit in characters
          # @return [void]
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
          #
          # @param value [Object] falsy to make this a password entry
          # @return [void]
          def visibility=(value)
            visible = value ? true : false
            return if @visibility == visible

            @visibility = visible
            changed!
          end
          def_setter :set_visibility, :visibility=

          # Whether typed text is shown; false means a password entry.
          #
          # @return [Boolean] true unless visibility was turned off
          def visibility?
            @visibility != false
          end

          # A value this entry submitted as part of another widget's scope.
          # Only the shadow state moves: pushing it back to the viewer is what
          # the contract forbids for a password, and for a plain entry the
          # browser already shows what was typed.
          #
          # @param value [#to_s] the submitted value
          # @return [void]
          def accept_submitted(value)
            @text = value.to_s.dup
          end

          # Gtk::Entry#set_alignment: accepted and ignored.
          #
          # @param _value [Object] ignored
          # @return [self]
          def set_alignment(_value)
            self
          end

          # Maps changed, activate, focus-in-event and focus-out-event to the
          # contract's change, submit, focus and blur.
          #
          # @param signal [Symbol] a normalized GTK signal name
          # @return [Symbol, nil] the contract event, or nil for any other signal
          def event_for(signal)
            mapped = case signal
                     when :changed then :change
                     when :activate then :submit
                     when :focus_in_event then :focus
                     when :focus_out_event then :blur
                     end
            # A password's `changed` fires too (contract 2.18): the event
            # carries no value, so the handler sees the entry's text as it
            # was -- empty until a submit delivers it -- and knows only that
            # the viewer typed. A handler that needs the current contents
            # (a live strength meter) cannot have them from here; that is a
            # limit of never echoing a password, not of this mapping, and
            # the shim used to suppress the event outright, which lost the
            # notification as well (review 2026-09-17, R13).
            mapped
          end

          # `change` is always bound so the shadow text tracks the viewer.
          #
          # @return [Array<Symbol>] [:change]
          def always_bound_events
            [:change]
          end

          # :text_input, or :password_input when visibility is off.
          #
          # @return [Symbol] the node type
          def node_type
            visibility? ? :text_input : :password_input
          end

          # The value (visible entries only), disabled flag, placeholder and max length.
          #
          # @return [Hash{Symbol => Object}] props for the node
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
          #
          # @param event [Symbol] the contract event
          # @param context [Lich::WebUI::Runtime::EventContext, CarriedEvent] the event's context
          # @return [void]
          def apply_event(event, context)
            return unless %i[change submit].include?(event)

            # A password's value travels only in the submission scope. The
            # contract gives password_input's submit no payload, so reading one
            # here could only ever pick up something fabricated -- a plain
            # entry's `change` is the one that carries a value that way.
            value = submitted_value(context)
            value = payload_value(context) if value.nil? && visibility?
            @text = value.to_s.dup unless value.nil?
          end
        end

        # Stand-in for Gtk::SearchEntry: an {Entry} flagged as a search field.
        class SearchEntry < Entry
          # The entry's props plus the search flag.
          #
          # @return [Hash{Symbol => Object}] props for the node
          def node_props
            super.merge(search: true)
          end
        end

        # Stand-in for Gtk::Button, rendered as a contract button. Its click
        # carries the window's password entries as a submission scope, since
        # that is the only way a password reaches the script. Images and
        # relief are accepted and ignored.
        class Button < Widget
          # Creates a button.
          #
          # @param label [String, nil] the label; a non-String (a stock id) gives an empty label
          # @param options [Hash{Symbol => Object}] :label overrides the positional label
          # @return [Button] a new instance
          def initialize(label = nil, **options)
            super()
            @label = if options.key?(:label) then options[:label].to_s
                     elsif label.is_a?(String) then label
                     else ''
                     end
          end

          # The button label.
          #
          # @return [String] the label, possibly empty
          def label
            @label
          end

          # Sets the button label.
          #
          # @param value [#to_s] the label
          # @return [void]
          def label=(value)
            @label = value.to_s
            changed!
          end
          def_setter :set_label, :label=

          # Gtk::Button#clicked: runs the clicked handlers as if the viewer had pressed it.
          #
          # @return [Object, nil] the last handler's result, or nil with no handlers
          def clicked
            emit(:clicked)
          end

          # A button is how a password actually leaves the browser. The login
          # GUI's Connect button reads `pass_entry.text`, and a dialog's OK
          # button is what makes `run` return before the script reads three
          # entries -- in GTK the value is simply already in the widget, so
          # nothing declares anything. Here the value is sensitive and travels
          # only in a submission scope, so the button claims the password
          # entries sharing its window. Only passwords: a plain entry keeps its
          # own value current from `change`, and naming it here would have the
          # runtime blank it in the browser on every click.
          #
          # @return [Array<Entry>] the password entries in this button's window
          def submission_scope
            window = window_root
            return [] unless window

            scope = []
            window.each_submittable do |widget|
              scope << widget if widget.class.method_defined?(:visibility?) && !widget.visibility?
            end
            scope
          end

          # Gtk::Button#set_image: accepted and ignored.
          #
          # @param _image [Object] ignored
          # @return [self]
          def set_image(_image)
            self
          end
          alias image= set_image

          # Gtk::Button#set_relief: accepted and ignored.
          #
          # @param _relief [Object] ignored
          # @return [self]
          def set_relief(_relief)
            self
          end
          alias relief= set_relief

          # Maps clicked to the contract's activate.
          #
          # @param signal [Symbol] a normalized GTK signal name
          # @return [Symbol, nil] :activate for :clicked, otherwise nil
          def event_for(signal)
            :activate if signal == :clicked
          end

          # A button is a button node.
          #
          # @return [Symbol] :button
          def node_type
            :button
          end

          # The label and the disabled flag.
          #
          # @return [Hash{Symbol => Object}] props for the node
          def node_props
            props = { label: @label.empty? ? ' ' : @label }
            props[:disabled] = true unless @sensitive
            props
          end
        end

        # GTK hierarchy: CheckButton < ToggleButton < Button. Scripts test
        # `is_a?(Gtk::ToggleButton)` to find anything checkable. Stand-in for
        # Gtk::ToggleButton, rendered as a contract toggle whose `checked`
        # state is viewer-scoped and therefore pushed on every write.
        class ToggleButton < Button
          # Creates an inactive toggle button.
          #
          # @param label [String, nil] the label
          # @param options [Hash{Symbol => Object}] :label overrides the positional label
          # @return [ToggleButton] a new instance
          def initialize(label = nil, **options)
            super
            @active = false
          end

          # Whether the button is active (checked).
          #
          # @return [Boolean] the active state
          def active?
            @active
          end

          # Sets the active state and pushes it to every viewer.
          #
          # @param value [Object] truthy for active
          # @return [void]
          def active=(value)
            @active = value ? true : false
            viewer_push(:checked, @active)
          end
          def_setter :set_active, :active=

          # Applies a builder property; "active" sets the active state.
          #
          # @param name [String, Symbol] the property name
          # @param value [Object] the property value
          # @return [self]
          def apply_builder_property(name, value)
            return (self.active = Gtk.builder_value(value)) && self if name.to_s == 'active'

            super
          end

          # Maps toggled and clicked to the contract's change.
          #
          # @param signal [Symbol] a normalized GTK signal name
          # @return [Symbol, nil] :change for :toggled or :clicked, otherwise nil
          def event_for(signal)
            :change if %i[toggled clicked].include?(signal)
          end

          # `change` is always bound so the shadow state tracks the viewer.
          #
          # @return [Array<Symbol>] [:change]
          def always_bound_events
            [:change]
          end

          # A toggle button is a toggle node.
          #
          # @return [Symbol] :toggle
          def node_type
            :toggle
          end

          # The label, checked state and disabled flag.
          #
          # @return [Hash{Symbol => Object}] props for the node
          def node_props
            props = { label: @label.empty? ? ' ' : @label, checked: @active }
            props[:disabled] = true unless @sensitive
            props
          end

          protected

          # Takes the active state from a change event's payload.
          #
          # @param event [Symbol] the contract event
          # @param context [Lich::WebUI::Runtime::EventContext, CarriedEvent] the event's context
          # @return [void]
          def apply_event(event, context)
            return unless event == :change

            value = payload_value(context)
            @active = value ? true : false unless value.nil?
          end
        end

        # Stand-in for Gtk::CheckButton: a {ToggleButton} rendered as a checkbox.
        class CheckButton < ToggleButton
          # A check button is a checkbox node.
          #
          # @return [Symbol] :checkbox
          def node_type
            :checkbox
          end
        end

        # Radio groups are rendered as independent checkboxes for now; the
        # group is kept so `group`/`active?` behave, and the shim enforces
        # exclusivity itself. Stand-in for Gtk::RadioButton, in every
        # constructor spelling ruby-gnome accepts.
        class RadioButton < CheckButton
          # Creates a radio button, joining a group when one is given.
          #
          # @param group_or_label [RadioButton, Array<RadioButton>, String, nil] a group leader, a
          #   group array, or the label
          # @param label [String, nil] the label when the first argument is a group
          # @param options [Hash{Symbol => Object}] :label, and :member naming a group leader
          # @return [RadioButton] a new instance
          def initialize(group_or_label = nil, label = nil, **options)
            text = options[:label] || (label.is_a?(String) ? label : (group_or_label.is_a?(String) ? group_or_label : nil))
            super(text, **{})
            @group = []
            leader = options[:member] || (group_or_label.is_a?(RadioButton) ? group_or_label : nil)
            leader = group_or_label.first if group_or_label.is_a?(Array) && group_or_label.first.is_a?(RadioButton)
            join_group(leader) if leader
            Gtk.log_unsupported('Gtk::RadioButton', 'exclusive rendering', note: 'rendered as checkboxes')
          end

          # The radio group this button belongs to.
          #
          # @return [Array<RadioButton>] the members, or [self] when ungrouped
          def group
            @group.empty? ? [self] : @group
          end

          # Joins +leader+'s group, sharing one member list across the group.
          #
          # @param leader [RadioButton] any member of the group to join
          # @return [self]
          def join_group(leader)
            @group = leader.group
            @group << self unless @group.include?(self)
            @group.each { |member| member.instance_variable_set(:@group, @group) }
            self
          end
          alias set_group join_group

          # Sets the active state; activating deactivates every other member.
          #
          # @param value [Object] truthy for active
          # @return [void]
          def active=(value)
            super
            group.each { |member| member.send(:deactivate_quietly) if !member.equal?(self) && value }
          end

          protected

          # The deselected sibling's `checked` is viewer-scoped, so a plain
          # changed! left the viewer's copy checked: two radios lit at once.
          #
          # @return [Boolean] false, the pushed value
          def deactivate_quietly
            @active = false
            viewer_push(:checked, false)
          end
        end

        # ------------------------------------------------------------------
        # Modal dialogs. Not widgets in the tree: a run maps to a contract
        # modal and blocks the session thread until the viewer answers.
        # ------------------------------------------------------------------
        # Stand-in for Gtk::MessageDialog. Not a {Widget}: it has no node and
        # no parent, and `run` shows a contract modal instead of a page. Icons
        # and signal handlers are accepted and ignored.
        class MessageDialog
          extend Setters
          # The button rows Gtk::MessageDialog::ButtonsType names, as (id, label) pairs.
          BUTTON_SETS = {
            none: [],
            ok: [[:ok, 'OK']],
            close: [[:close, 'Close']],
            cancel: [[:cancel, 'Cancel']],
            yes_no: [[:yes, 'Yes'], [:no, 'No']],
            ok_cancel: [[:ok, 'OK'], [:cancel, 'Cancel']],
          }.freeze

          # Modal button ids mapped to the {ResponseType} `run` returns.
          RESPONSES = {
            ok: ResponseType::OK, close: ResponseType::CLOSE, cancel: ResponseType::CANCEL,
            yes: ResponseType::YES, no: ResponseType::NO,
          }.freeze

          # @!attribute title
          #   @return [String] the modal's title; defaults to the capitalized type
          attr_accessor :title

          # Creates a message dialog from ruby-gnome's positional or keyword arguments.
          #
          # @param positional [Array] GTK 2 style arguments; the first String is the message and
          #   the first {BUTTON_SETS} key the button set
          # @param options [Hash{Symbol => Object}] :message, :buttons (a {BUTTON_SETS} key),
          #   :type (:info, :warning, :question, :error); :parent and :flags are ignored
          # @return [MessageDialog] a new instance
          def initialize(*positional, **options)
            @session = Session.current
            @message = options[:message] || positional.find { |value| value.is_a?(String) } || ''
            buttons = options[:buttons] || positional.find { |value| value.is_a?(Symbol) && BUTTON_SETS.key?(value) } || :ok
            @buttons = BUTTON_SETS.fetch(buttons.to_sym, BUTTON_SETS[:ok])
            @type = options[:type] || :info
            @title = @type.to_s.capitalize
            @secondary = nil
          end

          # Sets the title.
          #
          # @param value [#to_s] the title
          # @return [self]
          def set_title(value)
            @title = value.to_s
            self
          end

          # Gtk::Window#set_icon: accepted and ignored.
          #
          # @param _icon [Object] ignored
          # @return [self]
          def set_icon(_icon)
            self
          end
          alias icon= set_icon

          # Sets the secondary text, shown under the message.
          #
          # @param value [#to_s] the secondary text
          # @return [void]
          def secondary_text=(value)
            @secondary = value.to_s
          end
          def_setter :set_secondary_text, :secondary_text=

          # Sets the message from markup, with the tags stripped.
          #
          # @param value [#to_s] the Pango markup
          # @return [self]
          def set_markup(value)
            @message = value.to_s.gsub(/<[^>]+>/, '')
            self
          end

          # Adds a button. Only responses named in {RESPONSES} map back to a
          # ResponseType from `run`; any other answers {ResponseType::NONE}.
          #
          # @param label [#to_s] the button label
          # @param response [#to_s] the response id, e.g. :ok or Gtk::Stock::CANCEL
          # @return [self]
          def add_button(label, response)
            @buttons += [[response.to_s.downcase.to_sym, label.to_s]]
            self
          end

          # Shows the modal and blocks until the viewer answers or the session
          # cancels it. Cancel and No render as default buttons, the rest primary.
          #
          # @return [Integer] the {ResponseType} for the pressed button, NONE for an
          #   unknown one, or DELETE_EVENT when dismissed or when the modal failed
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

          # Gtk::Widget#destroy: nothing to destroy; the modal is gone once answered.
          #
          # @return [nil]
          def destroy
            nil
          end

          # Gtk::Widget#show_all: a no-op; `run` is what shows the modal.
          #
          # @return [self]
          def show_all
            self
          end

          # Accepts and ignores a handler; a modal has no signals.
          #
          # @param _args [Array] ignored
          # @return [Integer] 0
          def signal_connect(*_args, &_block)
            0
          end
        end
      end

      # Sibling namespaces scripts touch alongside Gtk: the slice of Gdk that
      # scripts read (screen geometry, events, colours), with a degrading
      # const_missing for the rest.
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
        #
        # @param name [Symbol] the missing constant
        # @return [Module, Symbol] a degrading module for a class-like name, else the downcased symbol
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
        # Stand-in for Gdk::Screen; `Screen.default` answers a {Size}, which
        # also plays the monitor.
        class Screen
          # Answers both the width/height that seven scripts read straight off
          # `Screen.default` and the monitor rectangle map.lic asks for.
          Size = Struct.new(:width, :height) do
            # The monitor under a point: always monitor 0.
            #
            # @param _x [Object] ignored
            # @param _y [Object] ignored
            # @return [Integer] 0
            def get_monitor_at_point(_x = nil, _y = nil)
              0
            end
            alias_method :monitor_at_point, :get_monitor_at_point

            # The monitor's rectangle: the whole screen.
            #
            # @param _monitor [Object] ignored
            # @return [Rectangle] the screen rectangle at the origin
            def get_monitor_geometry(_monitor = 0)
              Rectangle.new(0, 0, width, height)
            end
            alias_method :monitor_geometry, :get_monitor_geometry

            # The monitor count: always one.
            #
            # @return [Integer] 1
            def n_monitors
              1
            end

            # The monitor's work area: the same as its geometry.
            #
            # @param _monitor [Object] ignored
            # @return [Rectangle] the screen rectangle at the origin
            def get_monitor_workarea(_monitor = 0)
              get_monitor_geometry
            end

            # The display this screen belongs to.
            #
            # @return [Display] the default display
            def display
              Display.default
            end
          end

          # The one screen, 1280x800.
          #
          # @return [Size] the shared default screen
          def self.default
            @default ||= Size.new(1280, 800)
          end
        end

        # Stand-in for Gdk::Rectangle.
        Rectangle = Struct.new(:x, :y, :width, :height)

        # Gdk::Display.default.default_screen, which map.lic walks to reach
        # the monitor geometry. Stand-in for Gdk::Display with one screen
        # and one monitor.
        class Display
          # The one display.
          #
          # @return [Display] the shared default display
          def self.default
            @default ||= new
          end

          # The default screen.
          #
          # @return [Screen::Size] the default screen
          def default_screen
            Screen.default
          end
          alias screen default_screen

          # The monitor count: always one.
          #
          # @return [Integer] 1
          def n_monitors
            1
          end

          # A monitor by index: always the default screen, which plays the monitor.
          #
          # @param _index [Object] ignored
          # @return [Screen::Size] the default screen
          def get_monitor(_index = 0)
            Screen.default
          end

          # The primary monitor: the default screen.
          #
          # @return [Screen::Size] the default screen
          def primary_monitor
            Screen.default
          end

          # The display name.
          #
          # @return [String] "webui"
          def name
            'webui'
          end

          # Gdk::Display#flush: a no-op.
          #
          # @return [void]
          def flush; end

          # Gdk::Display#sync: a no-op.
          #
          # @return [void]
          def sync; end
        end

        # Stand-in for Gdk::RGBA. Components are stored as given; parsing a
        # colour string is not implemented and answers black.
        class RGBA
          # @!attribute [r] red
          #   @return [Numeric] the red component
          # @!attribute [r] green
          #   @return [Numeric] the green component
          # @!attribute [r] blue
          #   @return [Numeric] the blue component
          # @!attribute [r] alpha
          #   @return [Numeric] the alpha component
          attr_reader :red, :green, :blue, :alpha

          # Creates a colour.
          #
          # @param red [Numeric] 0.0 to 1.0
          # @param green [Numeric] 0.0 to 1.0
          # @param blue [Numeric] 0.0 to 1.0
          # @param alpha [Numeric] 0.0 to 1.0
          # @return [RGBA] a new instance
          def initialize(red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0)
            @red = red
            @green = green
            @blue = blue
            @alpha = alpha
          end

          # Gdk::RGBA.parse: ignores the spec and answers opaque black.
          #
          # @param _spec [Object] ignored
          # @return [RGBA] a default colour
          def self.parse(_spec)
            new
          end
        end

        # Stand-in for the GTK 2 Gdk::Color: an empty object scripts can pass around.
        class Color
          # Gdk::Color.parse: ignores the spec.
          #
          # @param _spec [Object] ignored
          # @return [Color] a new instance
          def self.parse(_spec)
            new
          end
        end

        # Gdk::Event is the same struct as Gtk::Event.
        Event = Gtk::Event
      end
    end
  end
end
