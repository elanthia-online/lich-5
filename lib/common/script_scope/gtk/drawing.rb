# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # A closed, owner-bound rectangle recorder. It is valid for one draw only.
        class RectangleDrawing < ModelObject
          # Starts an owner-bound recorder with an empty path and opaque black fill.
          # @return [RectangleDrawing] context valid only during the current draw
          def initialize
            super
            @active, @commands, @paths, @layers = true, 0, [], []
            @color, @line_width = { r: 0, g: 0, b: 0, a: 1.0 }, 2
          end

          # Sets the opaque source color without accepting CSS or native resources.
          # @param red [Numeric] finite channel in 0..1
          # @param green [Numeric] finite channel in 0..1
          # @param blue [Numeric] finite channel in 0..1
          # @return [RectangleDrawing] self
          def set_source_rgb(red, green, blue)
            operation(:set_source_rgb) do
              values = [red, green, blue]
              session.refuse(self, :set_source_rgb) unless values.all? { |value| finite?(value) && value.between?(0, 1) }
              @color = %i[r g b].zip(values.map { |value| (value * 255).round }).to_h.merge(a: 1.0)
            end
          end

          # Appends a bounded rectangle path, consumed by the next fill or stroke.
          # @param x [Numeric] finite horizontal origin in -65536..65536
          # @param y [Numeric] finite vertical origin in -65536..65536
          # @param width [Numeric] finite nonnegative extent, at most 65536
          # @param height [Numeric] finite nonnegative extent, at most 65536
          # @return [RectangleDrawing] self
          def rectangle(x, y, width, height)
            operation(:rectangle) do
              valid = [x, y, width, height].all? { |value| finite?(value) && value.abs <= 65_536 }
              session.refuse(self, :rectangle) unless valid && width >= 0 && height >= 0
              @paths << { x: x, y: y, w: width, h: height }
            end
          end

          # Sets the stroke width for subsequent recorded paths.
          # @param value [Numeric] finite width in 1..16
          # @return [RectangleDrawing] self
          def set_line_width(value)
            operation(:set_line_width) do
              session.refuse(self, :set_line_width) unless finite?(value) && value.between?(1, 16)
              @line_width = value
            end
          end

          # @return [RectangleDrawing] self after filling and consuming all paths
          def fill = paint(:fill)
          # @return [RectangleDrawing] self after stroking and consuming all paths
          def stroke = paint(:stroke)

          # Retires the borrowed context even when an original handler raises.
          def close
            @active = false
            @layers
          end
          private :close

          private

          # @return [Boolean] whether geometry can be serialized as a finite number
          def finite?(value) = value.is_a?(Integer) || (value.is_a?(Float) && value.finite?)

          # Enforces owner, lifetime and the 512-command bound before recording.
          # @param name [Symbol] operation used in refusal attribution
          # @yield bounded recorder mutation
          # @return [RectangleDrawing] self
          def operation(name)
            session.style_operation(self, name) do
              @commands += 1
              session.refuse(self, name) unless @active && @commands <= 512
              yield
            end
            self
          end

          # Converts pending paths to typed layers, enforcing the 512-layer bound.
          # @param mode [Symbol] :fill or :stroke
          # @return [RectangleDrawing] self
          def paint(mode)
            operation(mode) do
              session.refuse(self, mode) if @layers.size + @paths.size > 512
              @layers.concat(@paths.map { |path| path.merge(kind: :rectangle, mode: mode, color: @color.dup, line_width: @line_width) })
              @paths.clear
            end
          end
        end

        # Requested-size rectangle surface; arbitrary Cairo operations remain refused.
        class DrawingArea < Widget
          # Creates a clipped rectangle surface with a one-pixel requested size.
          def initialize
            super
            @props.merge!(width: 1, height: 1, layers: [], clip_layers: true)
          end

          # Updates requested dimensions and redraws an already published surface.
          # @param width [Integer] -1, or requested width in 1..65536
          # @param height [Integer] -1, or requested height in 1..65536
          # @return [DrawingArea] self
          def set_size_request(width, height)
            session.style_operation(self, :set_size_request) do
              valid = [width, height].all? { |value| value.is_a?(Integer) && (value == -1 || value.between?(1, 65_536)) }
              session.refuse(self, :set_size_request) if destroyed? || !valid
              super
              queue_draw if @handle
            end
            self
          end

          # @return [Integer] bounded requested width used by the draw callback
          def allocated_width = drawing_dimension(:width)
          # @return [Integer] bounded requested height used by the draw callback
          def allocated_height = drawing_dimension(:height)

          # Retains ordinary handler IDs and disconnection/destruction behavior.
          def signal_connect(name, &handler)
            return super unless name.to_s == 'draw'
            session.style_operation(self, :signal_connect) do
              session.refuse(self, :signal_connect) if destroyed? || !handler
              id = Widget.send(:next_signal_id)
              callback = proc { |*args| handler.call(*args) if @signal_connections.key?(id) }
              (@signals[:draw] ||= []) << ['draw', callback]
              @signal_connections[id] = [:draw, callback]
              id
            end
          end

          # @param id [Integer] live connection ID returned by signal_connect
          # @return [DrawingArea] self after retiring exactly that handler
          def signal_handler_disconnect(id) = disconnect_signal_handler(id)

          # Rebuilds the complete layer list before replacing the published frame.
          def queue_draw
            session.style_operation(self, :queue_draw) do
              session.refuse(self, :queue_draw) if destroyed? || @drawing
              layers = drawing_layers
              write(:layers, layers)
            end
            self
          end

          protected

          def component_type = :composite
          def component_props = super.merge(layers: drawing_layers)
          def bind_event(event) = event == :draw ? nil : super

          private

          def drawing_dimension(axis)
            session.style_operation(self, axis) do
              value = @props.fetch(axis)
              session.refuse(self, axis) if destroyed? || !value.is_a?(Integer) || !value.between?(1, 65_536)
              session.degrade(:drawing_allocation, 'drawing allocation follows requested dimensions; browser layout owns final placement')
              value
            end
          end

          # Runs script draw handlers once with an always-retired borrowed context.
          # Publication occurs only after all callbacks and recorder cleanup finish.
          # @return [Array<Hash>] typed layers for one complete frame
          def drawing_layers
            session.refuse(self, :draw) if destroyed? || @drawing
            allocated_width
            allocated_height
            context = RectangleDrawing.new
            begin
              @drawing = true
              @signals.fetch(:draw, []).dup.each { |_name, handler| handler.call(self, context) }
            ensure
              @drawing = false
              layers = context.send(:close)
            end
            layers
          end
        end
      end
    end
  end
end
