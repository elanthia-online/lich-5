# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # Natural-sized children at bounded pixel coordinates, with no native GTK window.
        class Fixed < Widget
          include Container

          # Creates an empty positioned overlay with natural child sizes.
          def initialize
            super
            @props[:positioned] = true
          end

          # Adds a same-owner child at integer coordinates; failed attachment restores its placement.
          # @param child [Widget] same-session child governed by this container
          # @param x [Integer] bounded horizontal coordinate
          # @param y [Integer] bounded vertical coordinate
          # @return [Fixed] self
          def put(child, x, y)
            session.synchronize do
              valid = !destroyed? && child.is_a?(Widget) && child.session.equal?(session) && !child.destroyed? && child.parent.nil?
              session.refuse(self, :put) unless valid
              placement = position(x, y)
              previous = child.instance_variable_get(:@placement)
              child.placement = placement
              begin
                insert_child(child, @children.length, placement: placement)
              rescue StandardError
                child.placement = previous
                raise
              end
            end
            self
          end

          # GTK's generic add places an unpositioned child at the origin.
          # @param child [Widget] same-session child governed by this container
          # @return [Fixed] self
          def add(child) = put(child, 0, 0)

          # Moves only an existing child, preserving placement on refusal.
          # @param child [Widget] same-session child governed by this container
          # @param x [Integer] bounded horizontal coordinate
          # @param y [Integer] bounded vertical coordinate
          # @return [Fixed] self
          def move(child, x, y)
            session.synchronize do
              session.refuse(self, :move) unless !destroyed? && child.is_a?(Widget) && !child.destroyed? && child.parent.equal?(self)
              placement = position(x, y)
              session.port.place(@handle, child.materialize, placement) if @handle
              child.placement = placement
            end
            self
          end

          # Keeps attachment validation, adapter detachment and shadow removal atomic with moves.
          # @param child [Widget] same-session child governed by this container
          # @return [Fixed] self
          def remove(child)
            session.synchronize { super }
          end

          protected

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :overlay

          private

          # Validates coordinates before preparing a positioned child placement.
          # @param x [Integer] bounded horizontal coordinate
          # @param y [Integer] bounded vertical coordinate
          # @return [Hash{Symbol => Integer}] bounded x/y placement
          # @api private
          def position(x, y)
            session.refuse(self, :position) unless [x, y].all? { |value| value.is_a?(Integer) && Lich::WebUI::Contract::BOUNDS[:geometry].cover?(value) }
            { x: x, y: y }
          end
        end

        # Bounded Layout positioning reuses Fixed; the canvas clips offscreen children.
        # Virtual dimensions reuse the bounded overlay extent.
        class Layout < Fixed
          # Creates a clipped pointer-tracking canvas with browser-owned scrolling.
          # @param hadjustment [nil] only browser-owned scrolling is supported
          # @param vadjustment [nil] only browser-owned scrolling is supported
          # @raise [UnsupportedOperation] for native scroll adjustments
          def initialize(hadjustment = nil, vadjustment = nil)
            super()
            session.refuse(self, :new) unless hadjustment.nil? && vadjustment.nil?
            @props[:clip_children] = true
            @props[:pointer_tracking] = true
          end

          # Updates bounded virtual canvas dimensions under the session lock.
          # @param width [Numeric] finite virtual width, 0..65536
          # @param height [Numeric] finite virtual height, 0..65536
          # @return [Layout] self
          def set_size(width, height)
            session.synchronize do
              session.refuse(self, :set_size) unless [width, height].all? { |value| value.is_a?(Numeric) && value.finite? && value.between?(0, 65_536) }
              write(:width, width.round)
              write(:height, height.round)
            end
            self
          end

          # Reads the retained virtual canvas width.
          # @return [Numeric] authored virtual width, or zero
          def width = read(:width) || 0
          # Reads the retained virtual canvas height.
          # @return [Numeric] authored virtual height, or zero
          def height = read(:height) || 0

          # Queued polling keeps the drag's originating viewer until release.
          # @return [String, nil] originating viewer while an interaction remains active
          def pointer_viewer = @pointer_press && @pointer_viewer

          # Reads the current attachment's bounded window coordinates, never OS state.
          # @return [Hash] last attributed bounded pointer coordinates
          def pointer_position
            viewer = session.with_widget(self) { session.viewer_id }
            session.refuse(self, :pointer_position) unless viewer == @pointer_viewer
            @last_pointer = session.with_widget(self) { session.port.get(@handle, :pointer_position) } || @last_pointer
            session.refuse(self, :pointer_position) unless @last_pointer && !destroyed?
            @last_pointer
          rescue Lich::WebUI::Error
            raise unless @pointer_cancelled && @last_pointer
            @last_pointer
          end

          # Detach cancels the script's drag loop using its original release handlers.
          # @param viewer [String] viewer attachment identity
          # @return [void] result is not part of the supported script contract
          def cancel_pointer(viewer)
            return unless @pointer_viewer == viewer && @pointer_press
            @pointer_cancelled = true
            event = @pointer_press
            @pointer_press = nil
            @signals.fetch(:pointer_release, []).dup.each { |_name, handler| handler.call(self, PointerEvent.new(**event.to_h.merge(released: true))) }
          end

          protected

          # Lists component events needed independently of script connections.
          # @return [Array<Symbol>] required shared event names
          # @api private
          def builtin_events = [:pointer_motion]

          # Retains canvas drag state before invoking the admitted pointer handlers.
          # @param event [Symbol] :pointer_press or :pointer_release
          # @param pointer [PointerEvent] immutable script-facing pointer event
          # @param context [Lich::WebUI::Runtime::EventContext] originating viewer/payload
          # @return [PointerEvent, nil] active press, or nil after release
          # @api private
          def observe_pointer(event, pointer, context)
            session.refuse(self, :pointer_press) if pointer_viewer && pointer_viewer != context.viewer_id
            toplevel.send(:track_pointer_surface, self)
            @last_pointer = context.payload.slice(:x, :y, :state)
            @pointer_viewer = context.viewer_id
            @pointer_cancelled = false
            @pointer_press = event == :pointer_press ? pointer : nil
          end

          private

          # GTK integer coordinates accept finite numeric script calculations.
          # @param x [Numeric] finite horizontal coordinate within the canvas bound
          # @param y [Numeric] finite vertical coordinate within the canvas bound
          # @return [Hash{Symbol => Integer}] bounded x/y placement
          # @api private
          def position(x, y)
            session.refuse(self, :position) unless [x, y].all? { |value| value.is_a?(Numeric) && value.finite? && value.between?(-65_536, 65_536) }
            super(x.to_i, y.to_i)
          end
        end

        # A single-child pointer surface uses the existing owner/viewer event bridge.
        class EventBox < Widget
          include Container

          # Creates a zero-gap single-child pointer surface.
          def initialize
            super
            @props.merge!(orientation: :vertical, gap: 0)
          end

          # Preserves GtkBin's single-child rule rather than silently stacking content.
          # @param child [Widget] same-session child governed by this container
          # @return [EventBox] self
          def add(child)
            session.synchronize do
              session.refuse(self, :add) unless @children.empty?
              super
            end
          end

          protected

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :stack

          # Projects container allocation and child alignment into shared layout properties.
          # @return [Hash] shared layout properties
          # @api private
          def layout_props
            alignment = @children.first&.instance_variable_get(:@props)&.fetch(:vertical_align, nil)
            return {} unless alignment || @published_layout&.key?(:content_align)
            { content_align: alignment || :stretch }
          end
        end
      end
    end
  end
end
