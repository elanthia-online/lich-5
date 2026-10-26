# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        class Widget
          protected

          attr_writer :parent

          # Auxiliary owned widgets participate in lifetime/render traversal without becoming public children.
          # @return [Array<Widget>] descendants included in traversal
          # @api private
          def owned_children = @children
          # Ordinary widgets attach children without auxiliary placement metadata.
          # @param _child [Widget] child ignored by this unsupported or default operation
          # @return [Hash, nil] auxiliary placement, or nil for ordinary children
          # @api private
          def child_placement(_child) = nil

          # Releases a child reference and refreshes ancestor layout.
          # @param child [Widget] same-session child governed by this container
          # @return [void] result is not part of the supported script contract
          # @api private
          def forget_child(child)
            @children.delete(child)
            refresh_layout!
          end

          # Do not mistake a vertical flex container's horizontal cross axis for
          # vertical allocation. Only natural-height start alignment is supported
          # there; single-child scrollers own a separate grid allocation.
          # @return [Hash] shared presentation properties
          # @api private
          def component_props
            validate_vertical_parent(@props[:vertical_align]) if @props.key?(:vertical_align) && parent
            @props.merge(layout_props)
          end

          # Refuses vertical placement unsupported by the containing layout.
          # @param alignment [Symbol] shared vertical allocation token
          # @return [void] result is not part of the supported script contract
          # @api private
          def validate_vertical_parent(alignment)
            supported = parent.is_a?(Table) || parent.is_a?(Frame) || parent.is_a?(EventBox) || parent.is_a?(Overlay) ||
                        (parent.is_a?(ScrolledWindow) && parent.children.length == 1) ||
                        (parent.is_a?(Box) && (!parent.vertical? || (alignment == :start && !expands?(:vertical))))
            session.refuse(self, :valign_parent) unless supported
          end

          # Supplies an empty layout extension point for concrete containers.
          # @return [Hash] shared layout properties
          # @api private
          def layout_props = {}
          # Supplies an empty signal map for concrete widgets to extend.
          # @return [Hash{String => Symbol}] accepted GTK signals and shared events
          # @api private
          def signal_map = {}
          # Declares that an ordinary container has no viewer input value.
          # @return [Symbol, nil] input property, or nil for non-input widgets
          # @api private
          def input_property = nil
          # Declares no mandatory events for an ordinary widget.
          # @return [Array<Symbol>] required shared event names
          # @api private
          def builtin_events = []

          # Internal metadata queries never read viewer-local state or publish widgets.
          # @return [Boolean] whether this widget is explicitly hidden
          # @api private
          def hidden? = @props[:hidden] == true

          # Reports whether this widget declared a pointer event surface.
          # @return [Boolean] whether this widget authored a pointer surface
          # @api private
          def pointer_events? = @props[:pointer_events] == true

          # Reports whether this shadow widget already owns a port handle.
          # @return [Boolean] whether an opaque port handle has already been allocated
          # @api private
          def materialized? = !@handle.nil?

          # Reads the Notebook responsible for this header widget.
          # @return [Notebook, nil] current header owner, independently of parentage
          # @api private
          def tab_owner = @tab_owner

          # Claims/releases header notification ownership after caller-side validation.
          # @param owner [Notebook, nil] new owner, or nil to release the existing claim
          # @return [Object, nil] assigned owner or released reference
          # @api private
          def tab_owner=(owner)
            if owner.nil?
              remove_instance_variable(:@tab_owner) if instance_variable_defined?(:@tab_owner)
            else
              @tab_owner = owner
            end
          end

          # Reads the container responsible for this caption widget.
          # @return [Frame, Expander, nil] current caption notification owner
          # @api private
          def caption_owner = @frame_caption_owner

          # Claims/releases caption notification ownership after caller-side validation.
          # @param owner [Frame, Expander, nil] new owner, or nil to release a claimed caption
          # @return [Object] assigned owner or released reference
          # @api private
          def caption_owner=(owner)
            owner.nil? ? remove_instance_variable(:@frame_caption_owner) : @frame_caption_owner = owner
          end

          # Publishes only this widget's changed layout, retaining the last successful map.
          # The caller owns traversal and synchronization; rejected writes leave the map intact.
          # @return [Hash, nil] published layout map, or nil for an unallocated/retired widget
          # @api private
          def publish_layout!
            return unless @handle && !destroyed?

            props = layout_props
            previous = @published_layout || {}
            props.each { |key, value| session.port.set(@handle, key, value) unless previous[key] == value }
            @published_layout = props
          end

          # A specialized pointer surface may retain its own event state before dispatch.
          # @param _event [Symbol] :pointer_press or :pointer_release
          # @param _pointer [PointerEvent] immutable script-facing event
          # @param _context [Lich::WebUI::Runtime::EventContext] originating viewer/payload
          # @return [nil] ordinary widgets retain no drag bookkeeping
          # @api private
          def observe_pointer(_event, _pointer, _context); end

          # Invokes a connection-order pointer snapshot, stopping only on literal true.
          # Connection wrappers retain their own disconnection/destruction guards.
          # @param event [Symbol] pointer signal family
          # @param pointer [PointerEvent] script-facing pointer event
          # @return [Array, nil] snapshot on completion, or nil when a handler stops dispatch
          # @api private
          def dispatch_pointer_handlers(event, pointer)
            @signals.fetch(event, []).dup.each do |_name, handler|
              break if handler.call(self, pointer) == true
            end
          end

          # Invokes key, crossing and window-state snapshots while the widget remains live.
          # @param event [Symbol] one of the three notification families
          # @param argument [KeyEvent, CrossingEvent, WindowStateEvent] script-facing notification
          # @return [Array, nil] snapshot on completion, or nil after destruction/handled true
          # @api private
          def dispatch_live_handlers(event, argument)
            @signals.fetch(event, []).dup.each { |_name, handler| break if destroyed? || handler.call(self, argument) == true }
          end

          # Refreshes one class-owned caption without adopting or retiring labels.
          # @param label [Label] caption reporting a text/fragment change
          # @param owned_label [Label, nil] the caller's current caption
          # @param operation [Symbol] class-specific degradation key
          # @param message [String] class-specific omitted-style notice
          # @return [Object, nil] write result, or nil for a retired/unowned/unchanged caption
          # @api private
          def refresh_owned_caption(label, owned_label, operation:, message:)
            return if destroyed? || !owned_label.equal?(label)
            session.degrade(operation, message) if label.send(:caption_fragments?)
            write(:label, label.text) unless @props[:label] == label.text
          end

          # Reads current viewer input only inside a live callback; otherwise uses committed/default shadow state.
          # @param property [Symbol] shared shadow or port property name
          # @return [Object] synchronous script-visible value
          # @api private
          def read(property)
            session.synchronize do
              session.flush_models!
              if property == input_property && @handle && !@destroyed && session.in_callback?
                session.with_widget(self) { session.port.get(@handle, property) }
              else
                @committed.fetch(property, @props[property])
              end
            end
          end

          # Validates a live adapter write before updating script-visible shadow state.
          # After destruction, retained metadata can still be updated without touching the retired handle.
          # @param property [Symbol] shared shadow or port property name
          # @param value [Object] property value accepted by the shared control contract
          # @return [Widget] self
          # @api private
          def write(property, value)
            session.synchronize do
              session.flush_models!
              @tab_owner&.send(:header_will_change, self, property, value)
              # A rejected port write must leave synchronous script reads at
              # their last valid value, including after window destruction.
              session.with_widget(self) { session.port.set(@handle, port_property(property), value) } if @handle && !@destroyed
              if property == input_property && @committed.key?(property)
                @committed[property] = value
              else
                @props[property] = value
              end
              @tab_owner&.send(:refresh_headers)
              @frame_caption_owner&.send(:refresh_caption, self) if %i[content fragments].include?(property)
              parent.send(:refresh_headers) if property == :hidden && parent.is_a?(Notebook)
            end
            self
          end

          # Maps a shadow property to its shared port spelling.
          # @param property [Symbol] shared shadow or port property name
          # @return [Symbol] shared port property name
          # @api private
          def port_property(property) = property

          # Calls handlers in connection order; a true close result vetoes default destruction.
          # @param event [Symbol] shared component event family
          # @param signal [String, nil] optional GTK signal spelling used to filter handlers
          # @return [Object, nil] last handler result, or the first close veto
          # @api private
          def emit_handlers(event, signal: nil)
            result = nil
            ordered_handlers(event).each do |name, handler|
              next if signal && name != signal

              result = handler.call(self)
              break if event == :close && result == true
            end
            result
          end

          # Partitions a connection snapshot so ordinary listeners precede after-listeners.
          # @param event [Symbol] shared component event family
          # @return [Array<Array>] ordinary listeners followed by after-listeners
          # @api private
          def ordered_handlers(event)
            ordinary, after = @signals.fetch(event, []).partition { |_name, handler| !handler.instance_variable_get(:@gtk_after) }
            ordinary + after
          end

          # Commits terminal input before invoking legacy save/close handlers.
          # @param event [Symbol] shared-control event mapped to a GTK signal
          # @return [String] adapter binding identifier
          # @api private
          def bind_event(event)
            widget = self
            release_handlers = @signals.fetch(event, []).dup if event == :pointer_release
            session.port.bind(@handle, event, proc do |context|
              session.callback(context, terminal: !context.viewer_id.nil? && %i[activate submit close].include?(event), widget: widget) do
                # A shadow handler change can precede its next published tree.
                # Never retarget an admitted release to replacement handlers.
                session.refuse(self, :pointer_release) if release_handlers && release_handlers != @signals.fetch(event, [])
                result = if event == :scroll
                           scroll = ScrollEvent.new(context.payload)
                           stopped = @signals.fetch(event, []).dup.any? { |_name, handler| handler.call(widget, scroll) == true }
                           unless destroyed? || (stopped && !scroll.replayed?)
                             delta = scroll.deltas
                             previous = session.with_widget(self) { session.port.get(@handle, :scroll_request) } || { x: 0, y: 0 }
                             write(:scroll_request, { x: previous[:x] + delta[0], y: previous[:y] + delta[1] })
                           end
                         elsif %i[key_press key_release].include?(event)
                           key = KeyEvent.new(**context.payload)
                           dispatch_live_handlers(event, key)
                         elsif %i[pointer_enter pointer_leave].include?(event)
                           crossing = CrossingEvent.new(event == :pointer_enter ? :enter_notify : :leave_notify)
                           dispatch_live_handlers(event, crossing)
                         elsif %i[pointer_press pointer_release].include?(event)
                           pointer = PointerEvent.new(**context.payload, released: event == :pointer_release)
                           observe_pointer(event, pointer, context)
                           session.with_pointer(widget, pointer) do
                             dispatch_pointer_handlers(event, pointer)
                           end
                         else
                           widget.send(:emit_handlers, event)
                         end
                widget.destroy if event == :close && result != true
              end
            end)
          end
        end
      end
    end
  end
end
