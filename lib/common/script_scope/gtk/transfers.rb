# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        module TargetFlags
          SAME_APP = :same_app
        end

        # A bounded same-application text transfer descriptor, not a native target.
        class TargetEntry < ModelObject
          attr_reader :target, :flags, :info

          def initialize(target, flags, info)
            super()
            session.refuse(self, :new) unless %w[STRING text/plain].include?(target) && flags == TargetFlags::SAME_APP && info == 0
            @target, @flags, @info = target, flags, info
          end
        end

        # Data never comes from an arbitrary browser payload: the source callback
        # produces it from a validated live source in the same viewer/page.
        class SelectionData < ModelObject
          attr_reader :text

          def set(type, text)
            session.style_operation(self, :set) do
              valid = type == Gdk::Selection::TYPE_STRING && text.is_a?(String) && text.valid_encoding? &&
                      text.encoding.ascii_compatible? && text.length <= Lich::WebUI::Contract::BOUNDS[:input_text]
              session.refuse(self, :set) unless valid
              @text = text.dup.freeze
            end
          end

          # Legacy callbacks write literal text through the same bounded data channel.
          def text=(text)
            set(Gdk::Selection::TYPE_STRING, text)
          end
          alias set_text text=
        end

        # Script callbacks own model changes. Completion acknowledges their result;
        # it never performs a second deletion or automatic model transfer.
        class DragContext < ModelObject
          ACTION_MOVE = :move
          def finish(success:, delete:, time:)
            session.refuse(self, :finish) unless [true, false].include?(success) && delete == false && time == Gdk::CURRENT_TIME
          end
        end

        # Legacy module spelling delegates to the same owner-bound TreeView protocol.
        module Drag
          TARGET_SAME_APP = TargetFlags::SAME_APP
          DEST_DEFAULT_ALL = :all

          # Delegates legacy module syntax to the owned TreeView source validator.
          # @param widget [TreeView] source view
          # @return [Object] result of TreeView#drag_source_set
          # @raise [UnsupportedOperation] for an unsupported source widget or protocol
          def self.source_set(widget, mask, targets, action)
            Gtk.session.refuse(self, :source_set) unless widget.is_a?(TreeView)
            widget.drag_source_set(mask, targets, action)
          end

          # Delegates legacy module syntax to the owned TreeView destination validator.
          # @param widget [TreeView] destination view
          # @return [Object] result of TreeView#drag_dest_set
          # @raise [UnsupportedOperation] for an unsupported destination widget or protocol
          def self.dest_set(widget, defaults, targets, action)
            Gtk.session.refuse(self, :dest_set) unless widget.is_a?(TreeView)
            widget.drag_dest_set(defaults, targets, action)
          end
        end

        module DestDefaults
          MOTION = 1
          HIGHLIGHT = 2
        end

        # Accepted widget drops run as one owner callback, so redraws cannot leave
        # script drag locks set. Cancelled/browser-external drags invoke no script.
        module WidgetTransfers
          TransferAllocation = Data.define(:y, :height)
          SIGNALS = %w[drag_begin drag_end drag_motion drag_leave drag_drop drag_data_get drag_data_received].freeze

          # Registers a same-session text MOVE source before publication.
          def drag_source_set(mask, targets, action)
            session.style_operation(self, :drag_source_set) do
              validate_widget_transfer!(targets, action)
              session.refuse(self, :drag_source_set) unless mask == Gdk::ModifierType::BUTTON1_MASK
              @props[:drag_source] ||= "widget-drag-#{Widget.send(:next_signal_id)}"
            end
            self
          end

          # Registers the measured motion/highlight destination spelling.
          def drag_dest_set(defaults, targets, action)
            session.style_operation(self, :drag_dest_set) do
              validate_widget_transfer!(targets, action)
              session.refuse(self, :drag_dest_set) unless [DestDefaults::MOTION, DestDefaults::MOTION | DestDefaults::HIGHLIGHT].include?(defaults)
              @props[:drag_destination] = true
            end
            self
          end

          # Stores transfer handlers in the ordinary disconnectable signal store.
          def signal_connect(name, &handler)
            signal = name.to_s.tr('-', '_')
            return super unless SIGNALS.include?(signal)

            session.style_operation(self, :signal_connect) do
              source_signal = %w[drag_begin drag_end drag_data_get].include?(signal)
              enabled = source_signal ? @props[:drag_source] : @props[:drag_destination]
              session.refuse(self, :signal_connect) unless !destroyed? && enabled && handler
              id = Widget.send(:next_signal_id)
              callback = proc { |*args| handler.call(*args) if @signal_connections.key?(id) }
              (@signals[:widget_drop] ||= []) << [signal, callback]
              @signal_connections[id] = [:widget_drop, callback]
              @transfer_revision = (@transfer_revision || 0) + 1
              write(:drag_source, "widget-drag-#{id}") if source_signal
              bind_event(:widget_drop) if @handle && @props[:drag_destination]
              id
            end
          end

          # Source handlers are shadow callbacks, not standalone core bindings.
          # Rotate their published identity and rebind destinations on retirement.
          def disconnect_signal_handler(id)
            session.style_operation(self, :signal_handler_disconnect) do
              transfer = @signal_connections[id]&.first == :widget_drop
              result = super
              if transfer
                @transfer_revision = (@transfer_revision || 0) + 1
                write(:drag_source, "widget-drag-#{Widget.send(:next_signal_id)}") if @props[:drag_source]
                bind_event(:widget_drop) if @handle && @props[:drag_destination]
              end
              result
            end
          end
          private :disconnect_signal_handler

          # Geometry is viewer measurement data scoped to the accepted callback.
          def allocation
            return @transfer_allocation if @transfer_allocation
            super
          end

          protected

          def bind_event(event)
            return super unless event == :widget_drop
            return unless @props[:drag_destination]

            revision = @transfer_revision
            session.port.bind(@handle, event, proc do |event_context|
              session.callback(event_context, terminal: true, widget: self) do
                session.refuse(self, :widget_drop) unless @transfer_revision == revision
                dispatch_widget_drop(event_context)
              end
            end)
          end

          private

          def validate_widget_transfer!(targets, action)
            valid = targets.is_a?(Array) && targets.length == 1 && targets.first.instance_of?(TargetEntry) &&
                    targets.first.session.equal?(session) && action == Gdk::DragAction::MOVE &&
                    session.port.schema(component_type)[:events].key?(:widget_drop) && !destroyed? && !@handle
            session.refuse(self, :widget_drag) unless valid
            session.degrade(:widget_drag_callbacks, 'same-page widget begin/motion/data-get/drop/data-received/leave/end callbacks run together on accepted drop; cancelled drags invoke no callbacks')
          end

          # Recheck queued work against live shadow ancestors before callbacks.
          def widget_transfer_live?
            widget = self
            while widget
              return false if widget.destroyed? || !widget.sensitive? || widget.instance_variable_get(:@props)[:hidden] == true
              widget = widget.parent
            end
            true
          end

          def emit_widget_drag(signal, *args)
            @signals.fetch(:widget_drop, []).dup.each do |name, callback|
              callback.call(self, *args) if name == signal
            end
          end

          def dispatch_widget_drop(event)
            payload = event.payload
            admitted = event.render || event.page.last_render
            component = admitted.tree.each.find { |node| node.cid == payload[:source] }
            key = component&.props&.fetch(:drag_source, nil)
            pending = [toplevel]
            source = nil
            until pending.empty?
              widget = pending.pop
              source = widget if key && widget.instance_variable_get(:@props)[:drag_source] == key
              pending.concat(widget.children)
            end
            session.refuse(self, :widget_drop) unless source && source.send(:widget_transfer_live?) && widget_transfer_live?
            current = event.page.last_render.tree.each.find { |node| node.cid == event.component.cid }
            session.refuse(self, :widget_drop) unless current && current.children.map(&:cid) == payload[:allocations].map { |item| item[:cid] }
            children = self.children
            session.refuse(self, :widget_drop) unless children.length == payload[:allocations].length
            context = DragContext.new
            children.zip(payload[:allocations]).each do |child, item|
              child.instance_variable_set(:@transfer_allocation, TransferAllocation.new(item[:y], item[:height]))
            end
            begin
              source.send(:emit_widget_drag, 'drag_begin', context)
              emit_widget_drag('drag_motion', context, payload[:x], payload[:y], Gdk::CURRENT_TIME)
              # Gather bounded source data before a manual drop can mutate the tree.
              # Scripts own both manual and data-driven moves; the shim never moves.
              if widget_transfer_live? && source.send(:widget_transfer_live?)
                data = SelectionData.new
                source.send(:emit_widget_drag, 'drag_data_get', context, data, 0, Gdk::CURRENT_TIME)
                if widget_transfer_live? && source.send(:widget_transfer_live?)
                  emit_widget_drag('drag_drop', context, payload[:x], payload[:y], Gdk::CURRENT_TIME)
                  if !data.text.nil? && widget_transfer_live? && source.send(:widget_transfer_live?)
                    emit_widget_drag('drag_data_received', context, payload[:x], payload[:y], data, 0, Gdk::CURRENT_TIME)
                  end
                end
              end
            ensure
              begin
                emit_widget_drag('drag_leave', context, Gdk::CURRENT_TIME) unless destroyed?
              ensure
                begin
                  source.send(:emit_widget_drag, 'drag_end', context)
                ensure
                  children.each { |child| child.remove_instance_variable(:@transfer_allocation) if child.instance_variable_defined?(:@transfer_allocation) }
                end
              end
            end
          end
        end

        Widget.prepend(WidgetTransfers)

        class TreeView
          # Only primary-button, same-app text MOVE transfers are admitted.
          def drag_source_set(mask, targets, action)
            session.style_operation(self, :drag_source_set) do
              session.refuse(self, :drag_source_set) if destroyed?
              normalized = mask == :button1_mask ? Gdk::ModifierType::BUTTON1_MASK : mask
              enable_model_drag_source(normalized, legacy_transfer_targets(targets), action)
            end
          end

          # Enables legacy same-application text MOVE drops before materialization.
          # @param defaults [Symbol] :all
          # @param targets [Array<Array>] one STRING or text/plain target with SAME_APP and info 0
          # @param action [Symbol] :move
          # @raise [UnsupportedOperation] for invalid protocol, selection mode or widget lifecycle
          def drag_dest_set(defaults, targets, action)
            session.style_operation(self, :drag_dest_set) do
              session.refuse(self, :drag_dest_set) unless !destroyed? && defaults == :all
              enable_model_drag_dest(legacy_transfer_targets(targets), action)
            end
          end

          # Accepts only the measured primary-button, same-app String MOVE protocol.
          def enable_model_drag_source(mask, targets, action)
            session.refuse(self, :enable_model_drag_source) unless mask == Gdk::ModifierType::BUTTON1_MASK
            configure_transfer(targets, action)
            @drag_source = true
            self
          end

          def enable_model_drag_dest(targets, action)
            configure_transfer(targets, action)
            @drag_destination = true
            self
          end

          # Drag callbacks are paired on a validated drop, never on cancelled drags.
          # No arbitrary formats, desktop/file drops, or cross-window transfers.
          def signal_connect(name, &handler)
            signal = name.to_s.tr('-', '_')
            return super unless %w[drag_data_get drag_data_received].include?(signal)
            session.refuse(self, signal) unless handler && (signal == 'drag_data_get' ? @drag_source : @drag_destination)
            (@drag_handlers ||= Hash.new { |hash, key| hash[key] = [] })[signal] << handler
            @drag_handlers.values.sum(&:length)
          end

          protected

          def dispatch_row_drop(context)
            payload = context.payload
            session.refuse(self, :row_drop) unless @drag_destination
            published_source = context.page.last_render.tree.each.find { |component| component.cid == payload[:source] }
            pending = [toplevel]
            source = nil
            until pending.empty?
              widget = pending.pop
              source = widget if widget.is_a?(TreeView) && widget.send(:transfer_source?, published_source)
              pending.concat(widget.children)
            end
            valid = source.is_a?(TreeView) && source.instance_variable_get(:@drag_source) && source.model&.find_key(payload[:row])
            session.refuse(self, :row_drop) unless valid
            source.select_keys([payload[:row]])
            data, context = SelectionData.new, DragContext.new
            source.send(:emit_drag, 'drag_data_get', context, data, 0, Gdk::CURRENT_TIME)
            return if data.text.nil?
            emit_drag('drag_data_received', context, 0, 0, data, 0, Gdk::CURRENT_TIME)
          end

          def emit_drag(signal, *args)
            (@drag_handlers || {}).fetch(signal, []).dup.each { |handler| handler.call(self, *args) }
          end

          private

          # Normalizes the single supported legacy tuple to the shared STRING target.
          # @param targets [Array<Array>] one text target restricted to this application
          # @return [Array<TargetEntry>] validated same-session target
          # @raise [UnsupportedOperation] for unsupported names, flags or info values
          def legacy_transfer_targets(targets)
            valid = targets.is_a?(Array) && targets.size == 1 && targets.first.is_a?(Array) &&
                    targets.first.size == 3 && %w[text/plain STRING].include?(targets.first[0]) &&
                    targets.first[1] == TargetFlags::SAME_APP && targets.first[2] == 0
            session.refuse(self, :drag_targets) unless valid
            [TargetEntry.new('STRING', TargetFlags::SAME_APP, 0)]
          end

          # Column identities are generated by each shim column and cannot be shared
          # between views. Match those published identities, never an adapter CID format.
          def transfer_source?(component)
            @drag_source && @handle && component&.type == :table && !visible_columns.empty? &&
              visible_columns.map(&:key) == component.props[:columns].map { |column| column[:key] }
          end

          def configure_transfer(targets, action)
            valid = targets.is_a?(Array) && targets.length == 1 && targets.first.instance_of?(TargetEntry)
            valid &&= targets.first.session.equal?(session) && action == Gdk::DragAction::MOVE
            session.refuse(self, :model_drag) unless valid && !@handle && selection.mode == :single
            session.degrade(:drag_callbacks, 'same-page text row callbacks run together on accepted drop; cancelled drags do not invoke data-get')
            @props[:transfer_group] = 'gtk-string-move'
          end
        end
      end

      module Gdk
        CURRENT_TIME = 0
        DragContext = Gtk::DragContext

        module Window
          BUTTON1_MASK = :button1
        end

        module ModifierType
          BUTTON1_MASK = :button1
        end

        module DragAction
          MOVE = :move
        end

        module Selection
          TYPE_STRING = :string
        end
      end
    end
  end
end
