# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        class Window < Widget
          include Container

          # Reads the attachment associated with an active pointer interaction.
          # @return [String, nil] viewer associated with a tracked pointer surface
          # @api private
          def pointer_viewer = @pointer_surface&.pointer_viewer

          attr_reader :titlebar

          TOPLEVEL = :toplevel
          Allocation = Data.define(:width, :height)

          # Creates a compact window inheriting the application's GTK preference.
          # @param kind [Symbol, String] :toplevel, legacy :TOPLEVEL, or the window title
          def initialize(kind = :toplevel)
            super()
            kind = :toplevel if kind == :TOPLEVEL
            session.refuse(self, :new) unless kind == :toplevel || kind.is_a?(String)
            @props[:title] = kind.is_a?(String) ? kind : ''
            @props.merge!(bare: true, density: :compact)
            session.register(self)
          end

          # Requests focus for a live same-owner descendant through the core facility.
          # Before show, the request is retained until the page and its inputs exist.
          # @param widget [Widget] same-session widget whose ownership is changing
          # @return [Window] self
          # @raise [UnsupportedOperation] for foreign, detached or retired targets
          def set_focus(widget)
            valid = !destroyed? && widget.is_a?(Widget) && widget.session.equal?(session) && !widget.destroyed?
            valid &&= Lich::WebUI::TreeBuilder::FOCUSABLE_TYPES.include?(widget.send(:component_type))
            ancestor = widget if valid
            ancestor = ancestor.parent while ancestor && !ancestor.equal?(self)
            session.refuse(self, :set_focus) unless valid && ancestor.equal?(self)
            session.synchronize do
              if @handle
                session.port.focus(@handle, widget.materialize)
              else
                @initial_focus = widget
              end
            end
            self
          end

          # Updates the requested page/window title through the adapter.
          # @param value [Object] literal title converted with String
          # @return [Window] self
          def title=(value)
            write(:title, String(value))
          end
          alias set_title title=

          # Reads the current shadow window title.
          # @return [String]
          def title = read(:title)

          # Retains a non-owning same-script parent hint; native stacking is host-controlled.
          # This is not containment, modality or destroy-with-parent ownership.
          # @param parent [Window, nil] live logical parent; nil clears the association
          # @return [Window] self
          def set_transient_for(parent)
            session.style_operation(self, :transient_for=) do
              session.refuse(self, :transient_for=) if destroyed?
              if parent
                valid = parent.is_a?(Window) && parent.session.equal?(session) && !parent.destroyed?
                ancestor = parent if valid
                while ancestor
                  valid &&= !ancestor.equal?(self)
                  break unless valid
                  ancestor = ancestor.transient_for
                end
                session.refuse(self, :transient_for=) unless valid
              end
              @transient_parent = parent && WeakRef.new(parent)
              session.degrade(:window_transient_parent, 'logical parent retained; native parent-child stacking is host-controlled') if parent
            end
            self
          end
          alias transient_for= set_transient_for

          # Reads the live weak parent reference without retaining its window.
          # @return [Window, nil] live logical parent, never an ownership edge
          def transient_for
            session.style_operation(self, :transient_for) do
              target = @transient_parent&.__getobj__
              target if !destroyed? && target && !target.destroyed?
            rescue WeakRef::RefError
              @transient_parent = nil
            end
          end
          alias get_transient_for transient_for

          # A HeaderBar is a separate first child; the normal content stays intact.
          # Live replacement preserves both the page handle and detached titlebar.
          # @param bar [HeaderBar, nil] same-session titlebar, or nil to remove it
          # @return [Window] self
          def set_titlebar(bar)
            session.synchronize do
              session.refuse(self, :set_titlebar) if destroyed?
              session.refuse(self, :set_titlebar) unless bar.nil? || bar.is_a?(HeaderBar)
              return self if bar.equal?(@titlebar)

              if bar
                valid = bar.is_a?(HeaderBar) && bar.session.equal?(session) && !bar.destroyed? && !bar.parent
                session.refuse(self, :set_titlebar) unless valid && !toplevel.equal?(bar)
                insert_child(bar, 0)
              end
              remove(@titlebar) if @titlebar
              @titlebar = bar
            end
            self
          end
          alias titlebar= set_titlebar

          # Releases titlebar ownership before detaching the requested child.
          # @param child [Widget] same-session child governed by this container
          # @return [Window] self
          def remove(child)
            super
            @titlebar = nil if child.equal?(@titlebar)
            self
          end

          # Programmatic and header closes follow the existing owner dispatcher.
          # A true delete-event result vetoes destruction; destroyed windows are inert.
          # @return [Window] self; closure is dispatched through the owner queue
          def close
            return self if destroyed?

            session.queue { destroy unless destroyed? || emit_handlers(:close) == true }
            self
          end

          # Requests integer window dimensions through the shared page size property.
          # @param width [Integer] requested width in bounded layout units
          # @param height [Integer] requested height in bounded layout units
          # @return [Window] self
          def resize(width, height)
            write(:size, [Integer(width), Integer(height)])
          end
          alias set_default_size resize

          # GTK window requisitions are minimum client sizes, not fixed HTML widths.
          # Both positive minima supply an initial size when no explicit resize exists;
          # a single minimum leaves the other axis under host/user control.
          # @param value [Integer] bounded layout or model integer request
          # @return [Window] self
          def set_width_request(value)
            write(:min_width, Integer(value))
            refresh_layout!
            self
          end
          alias width_request= set_width_request

          # Applies a content height floor while allowing natural growth.
          # @param value [Integer] bounded layout or model integer request
          # @return [Window] self
          def set_height_request(value)
            write(:min_height, Integer(value))
            refresh_layout!
            self
          end
          alias height_request= set_height_request

          # sloot restores its saved dimensions with independent setters.
          # @param value [Integer] authored default content width
          # @return [Window] self
          def default_width=(value)
            resize(value, (@props[:size] || [0, 0])[1])
          end

          # Updates the requested height while preserving the current requested width.
          # @param value [Integer] authored default content height
          # @return [Window] self
          def default_height=(value)
            resize((@props[:size] || [0, 0])[0], value)
          end

          # Materializes the window while reporting that raising/focus is host-controlled.
          # @return [Window] self
          def present
            show_all
            session.degrade(:present, 'raising an existing window is controlled by the browser host')
            self
          end

          # Retains bounded placement intent without overriding saved or host geometry.
          # Parent centering needs a live logical parent; exact native placement is not promised.
          # @param value [Symbol] :center or :center_on_parent
          # @return [Window] self
          def set_window_position(value)
            session.style_operation(self, :set_window_position) do
              valid = %i[center center_on_parent].include?(value) && !destroyed?
              valid &&= !transient_for.nil? if value == :center_on_parent
              session.refuse(self, :set_window_position) unless valid
              @window_position = value
              if value == :center_on_parent
                session.degrade(:window_parent_position, 'parent-relative centering is host-controlled; saved geometry and host placement take precedence')
              else
                session.degrade(:window_position, 'initial placement is controlled by the browser host')
              end
            end
            self
          end

          # Reads the retained host placement preference.
          # @return [Symbol, nil] requested hint, not observed native coordinates
          def window_position = @window_position
          alias get_window_position window_position

          alias set_position set_window_position

          # Requests integer desktop coordinates through the page position property.
          # @param x [Integer] bounded horizontal coordinate
          # @param y [Integer] bounded vertical coordinate
          # @return [Window] self
          def move(x, y)
            write(:position, [Integer(x), Integer(y)])
          end

          # Reads live geometry, or the final observed position after destruction.
          # @return [Array<Integer>] x/y coordinates, defaulting to zero before observation
          def position
            return (@observed_geometry&.fetch(:position) || [0, 0]).dup if destroyed?

            (@handle ? session.port.get(@handle, :position) : read(:position)) || [0, 0]
          end

          # Reads live or retained content dimensions without reviving a destroyed handle.
          # @return [Allocation] width/height pair
          def allocation
            size = if destroyed?
                     @observed_geometry&.values_at(:width, :height)
                   else
                     @handle ? session.port.get(@handle, :size) : read(:size)
                   end
            size ||= @observed_geometry&.values_at(:width, :height) || @props[:size] || [0, 0]
            Allocation.new(*size)
          end

          # Keep geometry available to original destroy/exit handlers after
          # the adapter has retired the window handle.
          # @return [Window] self
          def destroy
            session.synchronize do
              unless destroyed?
                dimensions = allocation
                @observed_geometry = { width: dimensions.width, height: dimensions.height, position: position }
              end
              super
            end
          end

          # Validates the legacy flag and reports that window resizing is host-controlled.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [void] result is not part of the supported script contract
          # @raise [UnsupportedOperation] for nonboolean values
          def resizable=(value)
            session.refuse(self, :resizable=) unless value == true || value == false
            session.degrade(:resizable, 'window resizing is controlled by the browser host')
          end
          alias set_resizable resizable=

          # Utility classification does not change focus, ownership or native window lifetime.
          # @param value [Symbol] supported utility-window hint
          # @return [Window] self
          def set_type_hint(value)
            session.refuse(self, :set_type_hint) unless value == Gdk::WindowTypeHint::UTILITY
            session.degrade(:window_type_hint, 'utility window classification is controlled by the browser host')
            self
          end
          alias type_hint= set_type_hint

          # Reports the host-owned window-icon limitation without loading native image objects.
          # @param _icon [Object] ignored native icon descriptor
          # @return [Window] self
          def set_icon(_icon)
            session.degrade(:window_icon, 'browser window icons are host-controlled')
            self
          end
          alias icon= set_icon

          # Browser setup windows remain independently interactive. Retain the GTK
          # hint, but report that blocking peer windows is not implemented here;
          # this does not alter owner isolation or impose a window-count limit.
          # @param value [Boolean] requested GTK modality
          # @return [void] result is not part of the supported script contract
          def modal=(value)
            session.refuse(self, :modal=) unless [true, false].include?(value)
            @modal = value
            session.degrade(:window_modal, 'GTK window modality is ignored; setup windows remain independently interactive') if value
          end
          alias set_modal modal=

          # Reads the retained modal hint without imposing browser modality.
          # @return [Boolean] retained request, not a claim of host enforcement
          def modal? = @modal == true

          # Requests native topmost behavior through the shared presentation contract.
          # Unsupported hosts retain the request and report their normal degradation.
          # @param value [Boolean] whether to keep this window above ordinary windows
          # @return [void]
          def keep_above=(value)
            session.refuse(self, :keep_above=) unless value == true || value == false
            write(:presentation, (@props[:presentation] || {}).merge(always_on_top: value))
          end
          alias set_keep_above keep_above=

          # Requests native chrome using the existing bounded presentation contract.
          # Browser-only hosts retain the request with their normal host limitation.
          # @param value [Boolean] whether to retain window decorations
          # @return [Window] self
          def set_decorated(value)
            session.refuse(self, :decorated=) unless [true, false].include?(value)
            session.synchronize do
              write(:presentation, (@props[:presentation] || {}).merge(borderless: !value))
            end
          end
          alias decorated= set_decorated

          # Reads the retained window decoration preference.
          # @return [Boolean] requested decoration state; true by default
          def decorated? = !read(:presentation)&.fetch(:borderless, false)

          # Window borders belong to its content, not the page schema.
          # @param value [Integer] bounded layout or model integer request
          # @return [Window] self
          def set_border_width(value)
            @content_margin = Integer(value)
            self
          end
          alias border_width= set_border_width

          # Applies content margins and materializes this page for the shared publication path.
          # @return [Window] self
          def show_all
            return self if no_show_all?

            @children.each { |child| child.set_border_width(@content_margin) unless child.equal?(@titlebar) } if @content_margin
            @children.each(&:show_all)
            show
          end

          # Publishes the window through its existing owner lifecycle.
          # @return [Window] self
          def show
            session.synchronize do
              session.refuse(self, :show) if destroyed?
              write(:presentation, @props[:presentation].merge(hidden: false)) if @props.dig(:presentation, :hidden)
              materialize
              session.port.present(@handle)
              if @initial_focus
                target, @initial_focus = @initial_focus, nil
                unless target.destroyed?
                  ancestor = target
                  ancestor = ancestor.parent while ancestor && !ancestor.equal?(self)
                  set_focus(target) if ancestor.equal?(self)
                end
              end
              first = !@realized
              changed = !@shown
              @realized = true
              @shown = true
              emit_handlers(:realize) if first
              emit_handlers(:show) if changed && !destroyed?
              emit_handlers(:map) if changed && !destroyed? && visible?
            end
            self
          end

          # Hides the owned host window without retiring the page or its inputs.
          # Browser hosts hide page content and report the chrome limitation.
          # @return [Window] self
          def hide
            session.synchronize do
              session.refuse(self, :hide) if destroyed?
              write(:presentation, (@props[:presentation] || {}).merge(hidden: true))
              @shown = false
            end
            self
          end

          # Requests real native minimization without retiring the page.
          # @return [Window] self
          def iconify
            request_minimized(true)
          end

          # Restores the owned native window through its presentation channel.
          # @return [Window] self
          def deiconify
            request_minimized(false)
          end

          # A new request can repeat a value after the user changed the actual native state.
          # @param value [Boolean] requested host minimization state
          # @return [Window] self
          # @api private
          def request_minimized(value)
            session.synchronize do
              revision = (@minimize_revision || 0) + 1
              session.refuse(self, :iconify) if revision > 2_147_483_647
              write(:presentation, (@props[:presentation] || {}).merge(minimized: value, minimized_revision: revision))
              @minimize_revision = revision
            end
            self
          end
          private :request_minimized

          # Reports shadow visibility without allocating a browser surface.
          # @return [Boolean] whether this window has been published and remains live
          def visible? = !destroyed? && @shown == true

          # Removes a standard window signal, including destroy, without retiring
          # its core geometry/close observers. Other facade signal families retain
          # their existing capability boundaries.
          # @param id [Integer] connection identity returned by this widget
          # @return [Window] self
          def signal_handler_disconnect(id) = disconnect_signal_handler(id)

          protected

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :page

          # Retains the Layout supplying this window's active drag/viewer attribution.
          # @param surface [Layout] materialized canvas belonging to this window
          # @return [Layout] retained surface
          # @api private
          def track_pointer_surface(surface)
            @pointer_surface = surface
          end

          # Clears a retired titlebar reference before ordinary child cleanup.
          # @param child [Widget] same-session child governed by this container
          # @return [void] result is not part of the supported script contract
          # @api private
          def forget_child(child)
            @titlebar = nil if child.equal?(@titlebar)
            super
          end

          # Projects container allocation and child alignment into shared layout properties.
          # @return [Hash] shared layout properties
          # @api private
          def layout_props
            props = { viewport: expands?(:vertical) }
            if !@props.key?(:size) && @props.fetch(:min_width, 0).positive? && @props.fetch(:min_height, 0).positive?
              props[:size] = [@props[:min_width], @props[:min_height]]
            end
            props
          end

          # Maps supported GTK signal spellings to shared component events.
          # @return [Hash{String => Symbol}] accepted GTK signals and shared events
          # @api private
          def signal_map = { 'delete_event' => :close, 'configure_event' => :configure, 'window_state_event' => :window_state, 'size_allocate' => :configure,
                             'key_press_event' => :key_press, 'key_release_event' => :key_release }

          # Lists component events needed independently of script connections.
          # @return [Array<Symbol>] required shared event names
          # @api private
          def builtin_events = %i[close configure window_state detach]

          # Preserve the latest validated browser measurements for the original
          # script's allocation/position reads, including its exit cleanup.
          # @param event [Symbol] shared component event family
          # @return [String] shared event binding identity
          # @api private
          def bind_event(event)
            if event == :detach
              return session.port.bind(@handle, event, proc do |context|
                session.callback(context, widget: self) { @pointer_surface&.cancel_pointer(context.viewer_id) }
              end)
            end
            if event == :window_state
              return session.port.bind(@handle, event, proc do |context|
                session.callback(context, widget: self) do
                  minimized = context.payload.fetch(:minimized)
                  previous = @observed_minimized || false
                  @observed_minimized = minimized
                  next if previous == minimized

                  state = WindowStateEvent.new(new_window_state: minimized ? Gdk::WindowState::ICONIFIED : 0,
                                               changed_mask: Gdk::WindowState::ICONIFIED)
                  dispatch_live_handlers(:window_state, state)
                end
              end)
            end
            return super unless event == :configure

            session.port.bind(@handle, :configure, proc do |context|
              session.callback(context, widget: self) do
                previous = @observed_geometry
                @observed_geometry = context.payload.merge(position: context.payload.fetch(:position).dup.freeze).freeze
                geometry = @observed_geometry.values_at(:width, :height, :position)
                next if previous && previous.values_at(:width, :height, :position) == geometry

                event = ConfigureEvent.new(width: geometry[0], height: geometry[1], x: geometry[2][0], y: geometry[2][1])
                @signals.fetch(:configure, []).dup.each do |name, handler|
                  break if destroyed?
                  next if name == 'size_allocate' && previous && previous.values_at(:width, :height) == geometry.first(2)

                  argument = name == 'size_allocate' ? Allocation.new(*geometry.first(2)) : event
                  break if handler.call(self, argument) == true && name != 'size_allocate'
                end
              end
            end)
          end
        end

        # Immutable notification data from the existing validated viewer geometry.
        ConfigureEvent = Data.define(:width, :height, :x, :y)
        WindowStateEvent = Data.define(:new_window_state, :changed_mask)
      end
    end
  end
end
