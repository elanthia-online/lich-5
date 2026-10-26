# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        class Widget
          # Creates descendants before the root can publish, then binds supported events once.
          # @return [Lich::WebUI::Adapter::Handle] cached opaque control handle
          def materialize
            session.flush_models!
            return @handle if @handle

            # Build descendants before the page starts scheduling delivery. A
            # long script constructor must not publish a half-built window.
            descendants = owned_children
            child_handles = descendants.map(&:materialize)
            @handle = session.port.create(component_type, component_props.merge(placement: @placement || {}))
            @published_layout = layout_props
            descendants.zip(child_handles).each do |child, handle|
              placement = child_placement(child)
              if placement
                session.port.attach(@handle, handle, placement: placement)
              else
                session.port.attach(@handle, handle)
              end
            end
            optional = %i[key_press key_release blur] + (is_a?(RadioButton) ? [:activate] : [])
            (builtin_events + signal_map.values + @signals.keys).uniq.reject { |event| %i[show map realize].include?(event) || (optional.include?(event) && !@signals.key?(event)) }.each { |event| bind_event(event) }
            @handle
          end

          # Reports shadow lifecycle state without querying a retired adapter handle.
          # @return [Boolean]
          def destroyed? = @destroyed
          # Reports explicitly shown shadow state for a widget not yet destroyed.
          # @return [Boolean]
          def visible? = !@destroyed && @props[:hidden] == false

          # Walks shadow parents to the owning root.
          # @return [Widget] top-level ancestor or self
          def toplevel
            parent ? parent.toplevel : self
          end

          # Retains a child modal so parent destruction can cancel it.
          # @param dialog [Widget] same-session auxiliary dialog
          # @return [void]
          def own_dialog(dialog)
            (@dialogs ||= []) << dialog
          end

          # Releases a completed/destroyed modal from parent cleanup.
          # @param dialog [Widget] same-session auxiliary dialog
          # @return [void]
          def forget_dialog(dialog)
            @dialogs&.delete(dialog)
          end

          # Clears the shared hidden property.
          # @return [Widget] self
          def show
            changed = !visible?
            write(:hidden, false)
            emit_handlers(:show) if changed && !destroyed?
            self
          end

          # Opts out of recursive show_all; explicit show/hide still work.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [void] result is not part of the supported script contract
          def no_show_all=(value)
            session.refuse(self, :no_show_all=) unless [true, false].include?(value)
            write(:hidden, true) if value && !visible? && !is_a?(Window)
            @no_show_all = value
          end
          alias set_no_show_all no_show_all=
          # Reads the explicit exclusion from recursive show operations.
          def no_show_all? = @no_show_all == true

          # Hides widget content without discarding its input or destroying its owner.
          # @return [Widget] self
          def hide
            write(:hidden, true)
          end

          # Shows this widget and every shadow descendant.
          # @return [Widget] self
          def show_all
            return self if no_show_all?

            show
            owned_children.each(&:show_all)
            self
          end

          # Removes the widget once and runs each destroy handler independently.
          # @return [Widget] self, including repeated destruction
          def destroy
            session.synchronize do
              return self if @destroyed

              # Keep handle retirement and provider detachment atomic with reloads.
              @dialogs&.dup&.each { |dialog| session.cleanup(dialog) { dialog.destroy } }
              @tab_owner&.send(:retire_header, self)
              session.port.destroy(@handle) if @handle
              @parent&.send(:forget_child, self)
              @parent = nil
              mark_destroyed
              session.forget(self)
              self
            end
          end

          # Marks the shadow subtree retired while preserving script-readable metadata.
          # @return [void]
          def mark_destroyed
            return if @destroyed

            @destroyed = true
            @style_context&.send(:close)
            owned_children.dup.each(&:mark_destroyed)
            begin
              @emitting_destroy = true
              @destroy_handlers&.dup&.each { |handler| session.cleanup(self) { handler.call(self) } }
            ensure
              @emitting_destroy = false
              @signal_connections.clear
              @signals.clear
              @destroy_handlers&.clear
            end
          end

          # Drafts stay in the core viewer store. Only a terminal action copies
          # current input into script-owned shadow state for synchronous reads
          # after the dialog closes; disconnect never leaves draft copies here.
          # @return [void] result is not part of the supported script contract
          def commit_inputs
            property = input_property
            if property && @handle && !@destroyed
              @committed[property] = session.with_widget(self) { session.port.get(@handle, property) }
            end
            owned_children.each(&:commit_inputs)
          end
        end
      end
    end
  end
end
