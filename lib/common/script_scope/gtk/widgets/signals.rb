# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        class Widget
          # Maps accepted legacy signals to core events; destroy handlers accumulate separately.
          # @param name [String, Symbol] supported GTK operation, property or signal spelling
          # @param block [Proc] GTK callback invoked with the signal arguments
          # @return [Integer] stable connection ID, shared across this widget's signal families
          # @raise [UnsupportedOperation] for an unmapped signal
          def signal_connect(name, &block)
            raise ArgumentError, 'signal handler is required' unless block

            session.style_operation(self, :signal_connect) do
              session.refuse(self, :signal_connect) if destroyed?
              name = name.to_s.tr('-', '_')
              event = if %w[destroy show map realize].include?(name)
                        session.refuse(self, "signal:#{name}") if %w[map realize].include?(name) && !is_a?(Window)
                        name.to_sym
                      elsif %w[scroll_event enter_notify_event leave_notify_event].include?(name)
                        mapped = { 'scroll_event' => :scroll, 'enter_notify_event' => :pointer_enter, 'leave_notify_event' => :pointer_leave }.fetch(name)
                        session.refuse(self, "signal:#{name}") unless session.port.schema(component_type)[:events].key?(mapped)
                        mapped
                      elsif %w[button_press_event button_release_event].include?(name)
                        pointer_event = name == 'button_press_event' ? :pointer_press : :pointer_release
                        session.refuse(self, "signal:#{name}") unless session.port.schema(component_type)[:events].key?(pointer_event)
                        write(:pointer_events, true)
                        pointer_event
                      else
                        signal_map.transform_keys { |key| key.tr('-', '_') }[name] || session.refuse(self, "signal:#{name}")
                      end
              id = Widget.send(:next_signal_id)
              # The guard also suppresses a disconnected handler already present
              # in an emission snapshot, without disturbing other listeners.
              handler = proc { |*args| block.call(*args) if @signal_connections.key?(id) }
              if event == :destroy
                (@destroy_handlers ||= []) << handler
              else
                (@signals[event] ||= []) << [name, handler]
                bind_event(event) if @handle && !%i[show map realize].include?(event)
              end
              @signal_connections[id] = [event, handler]
              id
            end
          end

          # The supported after-signals observe selected tabs or an unhandled close.
          # Normal listeners run first regardless of connection order.
          # @param name [String, Symbol] supported GTK operation, property or signal spelling
          # @param block [Proc] GTK callback invoked with the signal arguments
          # @return [Integer] disconnectable connection ID
          def signal_connect_after(name, &block)
            session.style_operation(self, :signal_connect_after) do
              normalized = name.to_s.tr('-', '_')
              valid = (is_a?(Notebook) && normalized == 'switch_page') || (is_a?(Window) && normalized == 'delete_event')
              session.refuse(self, :signal_connect_after) unless valid
              id = signal_connect(name, &block)
              @signal_connections.fetch(id).last.instance_variable_set(:@gtk_after, true)
              id
            end
          end

          # Removes exactly one local connection, retaining the internal lifecycle
          # binding (including geometry observation). Unknown/reused IDs refuse.
          # @param id [Integer] connection identity returned by this widget
          # @return [Widget] self
          # @api private
          def disconnect_signal_handler(id)
            session.style_operation(self, :signal_handler_disconnect) do
              connection = @signal_connections[id] if id.is_a?(Integer)
              session.refuse(self, :signal_handler_disconnect) if (destroyed? && !@emitting_destroy) || !connection
              event, handler = @signal_connections.delete(id)
              if event == :destroy
                @destroy_handlers.delete(handler)
              else
                @signals.fetch(event).delete_if { |_name, callback| callback.equal?(handler) }
                bind_event(event) if event == :pointer_release && @handle
              end
            end
            self
          end
          private :disconnect_signal_handler

          # Accepts positive combined press, release, scroll, enter and leave masks
          # only when every requested event exists in this component's schema.
          # Press/release requests also enable the pointer_events property.
          # Unsupported bits, zero and ineligible component events are refused.
          # @param mask [Integer, Symbol] supported mask bits, or :scroll_mask,
          #   :button_press_mask or :button_release_mask
          # @return [Widget] self
          def add_events(mask)
            masks = { Gdk::EventMask::BUTTON_PRESS_MASK => :pointer_press, Gdk::EventMask::BUTTON_RELEASE_MASK => :pointer_release, Gdk::EventMask::SCROLL_MASK => :scroll,
                      Gdk::EventMask::ENTER_NOTIFY_MASK => :pointer_enter, Gdk::EventMask::LEAVE_NOTIFY_MASK => :pointer_leave }
            mask = { scroll_mask: Gdk::EventMask::SCROLL_MASK, button_press_mask: Gdk::EventMask::BUTTON_PRESS_MASK,
                     button_release_mask: Gdk::EventMask::BUTTON_RELEASE_MASK }.fetch(mask, mask)
            supported = masks.keys.reduce(0, :|)
            session.refuse(self, :add_events) unless mask.is_a?(Integer) && mask.positive? && (mask & ~supported).zero?
            events = masks.filter_map { |bit, event| event unless (mask & bit).zero? }
            session.refuse(self, :add_events) unless events.all? { |event| session.port.schema(component_type)[:events].key?(event) }
            write(:pointer_events, true) if events.any? { |event| %i[pointer_press pointer_release].include?(event) }
            self
          end
        end
      end
    end
  end
end
