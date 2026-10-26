# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gdk
        # Legacy module helpers share the owner-bound primary screen projection.
        # @return [Integer] measured width or the existing nominal fallback
        def self.screen_width = Screen.default.width

        # @return [Integer] measured height or the existing nominal fallback
        def self.screen_height = Screen.default.height

        # Shared ownership/refusal boundary for bounded display and cursor values.
        module DisplayValue
          attr_reader :session

          # @raise [Gtk::UnsupportedOperation] for every unimplemented native operation
          def method_missing(name, *, **, &)
            session.refuse(self, name)
          end

          private

          # Preserves owner identity and refuses reuse after script teardown.
          def owned(operation, &block) = session.style_operation(self, operation, &block)

          # Retains provenance in diagnostics while returning compatible dimension hints.
          def rectangle(target:, point: nil)
            result = session.port.monitor_geometry(target: target, point: point)
            if result[:source] == 'unavailable'
              session.degrade(:screen_geometry, 'monitor unavailable; nominal 1024x768 sizing hint; host owns placement', receiver: self)
              result = { x: 0, y: 0, width: 1024, height: 768 }
            elsif result[:fallback]
              session.degrade(:monitor_selection, 'requested monitor unavailable; available host screen used', receiver: self)
            end
            Rectangle.new(session, result)
          end
        end

        # Read-only geometry with no native rectangle or mutable display state.
        class Rectangle
          include DisplayValue

          # @param session [Gtk::Session] owner boundary
          # @param values [Hash] validated geometry or explicit nominal sizing fallback
          def initialize(session, values)
            @session, @values = session, values.slice(:x, :y, :width, :height).freeze
          end

          %i[x y width height].each do |name|
            define_method(name) { owned(name) { @values.fetch(name) } }
          end
        end

        # One bounded primary-monitor projection; no device/pointer APIs.
        class Monitor
          include DisplayValue

          # @param session [Gtk::Session] owning script
          def initialize(session) = @session = session
          # @return [Rectangle] measured primary screen, or documented best effort
          def geometry = owned(:geometry) { rectangle(target: :primary) }
        end

        # Process-local monitor selection tokens, scoped to one Screen instance.
        class Screen
          include DisplayValue

          # @return [Integer] primary display width, with the declared nominal fallback
          def width = owned(:width) { rectangle(target: :primary).width }

          # @return [Integer] primary display height, with the declared nominal fallback
          def height = owned(:height) { rectangle(target: :primary).height }

          # Returns a stable bounded token for this requested point, never an OS handle.
          # @return [Integer] token accepted only by this screen's geometry lookup
          def get_monitor_at_point(x, y)
            owned(:get_monitor_at_point) do
              session.refuse(self, :get_monitor_at_point) unless [x, y].all? { |n| n.is_a?(Integer) && n.between?(-65_536, 65_536) }
              @monitor_points ||= {}
              point = [x, y].freeze
              next @monitor_points.key(point) if @monitor_points.value?(point)

              session.refuse(self, :get_monitor_at_point) if @monitor_points.size >= 32
              token = @monitor_points.size
              @monitor_points[token] = point
              token
            end
          end

          # @return [Rectangle] selected host monitor or explicit fallback
          def get_monitor_geometry(token)
            owned(:get_monitor_geometry) do
              point = @monitor_points&.[](token)
              session.refuse(self, :get_monitor_geometry) unless point && token.is_a?(Integer)
              rectangle(target: :point, point: point)
            end
          end
        end

        # Script-owned display facade. Screen instances persist for the observed call chain.
        class Display
          include DisplayValue

          # @return [Display] one facade per live script session
          def self.default
            current = Gtk.session
            current.style_operation(self, :default) do
              current.instance_variable_get(:@display_facade) || current.instance_variable_set(:@display_facade, new(current))
            end
          end

          # @param session [Gtk::Session] owner boundary
          def initialize(session)
            @session = session
            @screen = Screen.new
            @monitor = Monitor.new(session)
          end

          # @return [Screen] same owner-bound screen token
          def default_screen = owned(:default_screen) { @screen }
          # @return [Monitor] primary selection facade
          def primary_monitor = owned(:primary_monitor) { @monitor }

          # Opaque tokens select this session's browser pointer, never a native device.
          def default_seat = owned(:default_seat) { @seat ||= PointerSeat.new(session) }
        end

        class PointerSeat
          include DisplayValue
          def initialize(session) = @session = session
          def pointer = owned(:pointer) { @pointer ||= PointerDevice.new(session) }
        end

        class PointerDevice
          include DisplayValue
          def initialize(session) = @session = session
        end

        module CursorType
          HAND2 = :hand2
          # @raise [Gtk::UnsupportedOperation] for unimplemented native cursor types
          def self.const_missing(name) = Gtk.session.refuse(self, name)
        end

        # Immutable presentation hint; never creates or changes a native global cursor.
        class Cursor
          include DisplayValue
          attr_reader :name

          # @param name [String, Symbol] supported name, or a default-cursor fallback
          # @param display [Display, nil] same-owner display when provided
          def initialize(name, display: nil)
            @session = Gtk.session
            owned(:new) do
              session.refuse(self, :new) unless (name.is_a?(String) || name.is_a?(Symbol)) && name.to_s.length <= 128
              session.refuse(self, :new) if display && (!display.is_a?(Display) || !display.session.equal?(session))
              @name = name.to_s == 'hand2' ? 'pointer' : name.to_s
              unless %w[default pointer cell copy].include?(@name)
                session.degrade(:cursor_hint, 'unsupported named cursor uses browser default', receiver: self)
                @name = 'default'
              end
              @name = @name.dup.freeze
            end
          end

          # @return [Cursor] named presentation hint for the supplied display
          def self.new_from_name(display, name) = new(name, display: display)
        end

        # Cursor and measured-pointer facade; it never exposes a Gdk native window.
        class CursorWindow
          include DisplayValue

          # @param widget [Gtk::Widget] widget whose presentation receives cursor hints
          def initialize(widget)
            @widget, @session = widget, widget.session
          end

          # @param cursor [Cursor, nil] same-owner hint; nil restores inherited/default styling
          # @return [Cursor, nil] supplied hint
          def set_cursor(cursor)
            owned(:set_cursor) do
              session.refuse(self, :set_cursor) if @widget.destroyed? || (cursor && (!cursor.is_a?(Cursor) || !cursor.session.equal?(session)))
              if cursor
                @widget.send(:write, :cursor_hint, cursor.name)
              else
                @widget.send(:reset_cursor_hint)
              end
              cursor
            end
          end
          alias cursor= set_cursor

          def get_device_position(device)
            owned(:get_device_position) do
              surface = @widget.instance_variable_get(:@pointer_surface)
              valid = !@widget.destroyed? && device.is_a?(PointerDevice) && device.session.equal?(session) && surface && !surface.destroyed?
              session.refuse(self, :get_device_position) unless valid
              position = surface.pointer_position
              [self, position.fetch(:x), position.fetch(:y), position.fetch(:state)]
            end
          end
        end

        # Class-level native/device APIs remain explicit refusals as well.
        module DisplayClassBoundary
          # @raise [Gtk::UnsupportedOperation] for unsupported native constructors/helpers
          def method_missing(name, *, **, &) = Gtk.session.refuse(self, name)
          # @raise [Gtk::UnsupportedOperation] for unsupported native constants
          def const_missing(name) = Gtk.session.refuse(self, name)
        end
        [Display, Screen, Monitor, Rectangle, Cursor, CursorWindow].each { |type| type.extend(DisplayClassBoundary) }
      end

      module Gtk
        class Window
          # Returns an owner-bound dimension facade, without creating a native display handle.
          # @return [Gdk::Screen] screen whose dimensions follow shared monitor discovery
          def screen
            session.style_operation(self, :screen) do
              session.refuse(self, :screen) if destroyed?
              @screen ||= Gdk::Screen.new
            end
          end

          # @return [Array<Integer>] live dimensions or requested dimensions before publication
          def size
            dimensions = allocation
            [dimensions.width, dimensions.height]
          end
        end

        class Widget
          # Returns only cursor presentation capability, not native handles or pointer queries.
          # @return [Gdk::CursorWindow] same-widget facade
          def window
            session.style_operation(self, :window) do
              session.refuse(self, :window) if destroyed?
              @cursor_window ||= Gdk::CursorWindow.new(self)
            end
          end

          protected

          # Removes the optional hint while retaining the control's identity and input state.
          # @return [void]
          def reset_cursor_hint
            session.port.set(@handle, :cursor_hint, Lich::WebUI::Adapter::UNSET) if @handle
            @props.delete(:cursor_hint)
          end
        end
      end
    end
  end
end
