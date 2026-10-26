# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # A viewport adds no second scroll surface; its parent owns scrolling.
        class Viewport < Widget
          include Container

          # Creates a zero-gap wrapper without a second scroll surface or native adjustments.
          # @param horizontal [nil] native horizontal adjustments are unsupported
          # @param vertical [nil] native vertical adjustments are unsupported
          # @raise [UnsupportedOperation] when either adjustment argument is supplied
          def initialize(horizontal = nil, vertical = nil)
            super()
            session.refuse(self, :new) unless horizontal.nil? && vertical.nil?
            @props[:gap] = 0
          end

          protected

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :stack
        end

        # Adjustment reads report the last real viewer measurements. They do
        # not invent screen geometry or poll the browser synchronously.
        class ScrollAdjustment < Adjustment
          # Creates a viewer-measurement cache for one scroll container.
          # @param scroll [ScrolledWindow] scroll container whose viewer geometry is cached
          # @param axis [Symbol] :horizontal or :vertical allocation axis
          def initialize(scroll, axis = :vertical)
            super()
            @scroll = scroll
            @axis = axis
            @measurements = {}
          end

          # Caches bounded viewer measurements and signals changed extents, not mere movement.
          # @param viewer [String] viewer attachment identity
          # @param payload [Hash] bounded viewer measurements for one axis
          # @return [void]
          def observe(viewer, payload)
            old = @measurements[viewer]
            # Geometry is disposable cache, not durable form input. Bound it
            # even when a long-running display sees many fresh attachments.
            @measurements.shift if !@measurements.key?(viewer) && @measurements.length >= 64
            @measurements[viewer] = payload.dup
            @changed&.call(self) if !old || old.values_at(:upper, :page_size) != payload.values_at(:upper, :page_size)
          end

          # Registers the supported changed notification for scroll extent updates.
          # @param name [String, Symbol] supported GTK operation, property or signal spelling
          # @param block [Proc] GTK callback invoked with the signal arguments
          # @return [Proc] retained callback
          # @raise [UnsupportedOperation] for other signals
          def signal_connect(name, &block)
            @scroll.session.refuse(self, "signal:#{name}") unless name.to_s.tr('-', '_') == 'changed'
            @changed = block
          end

          # Reads the last measured content extent for the attributed viewer.
          # @return [Numeric] zero before measurement
          def upper = measurement.fetch(:upper, 0)
          # Reads the last measured viewport extent for the attributed viewer.
          # @return [Numeric] zero before measurement
          def page_size = measurement.fetch(:page_size, 0)
          # Reads this axis's cached scroll position for the attributed viewer.
          # @return [Numeric] zero before measurement
          def value = measurement.fetch(:position, 0)

          # Requests a finite, rounded position and updates the local measurement cache.
          # @param position [Numeric, String] finite requested position, converted with Float
          # @return [void] result is not part of the supported script contract
          # @raise [UnsupportedOperation] for positions outside the transport bounds
          def value=(position)
            number = Float(position)
            @scroll.session.refuse(self, :value=) unless number.finite?
            target = number.round
            @scroll.session.refuse(self, :value=) unless target.between?(-65_536, 65_536)
            target = [target, 0].max
            @scroll.request_position(@axis, target)
            measurement[:position] = target
          end
          alias set_value value=

          private

          # Returns the cached scroll geometry for the attributed viewer.
          # @return [Hash] current viewer geometry cache
          # @api private
          def measurement
            viewer = @scroll.session.with_widget(@scroll) { @scroll.session.viewer_id }
            @measurements[viewer] ||= {}
          end
        end

        # Single-child visibility container; slide timing remains browser-owned.
        class Revealer < Box
          # Creates an initially collapsed single-child disclosure container.
          def initialize
            super(:vertical, 0)
            @reveal_child, @shown = false, false
          end

          # Enforces a single child before using ordinary Box ownership.
          # @param child [Widget] same-session child governed by this container
          # @return [Revealer] self
          def add(child)
            session.refuse(self, :add) unless children.empty?
            super
          end

          # Retains reveal state while respecting explicit widget visibility.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [Revealer] self
          def set_reveal_child(value)
            session.style_operation(self, :set_reveal_child) do
              session.refuse(self, :set_reveal_child) if destroyed? || ![true, false].include?(value)
              @reveal_child = value
              write(:hidden, !@shown)
            end
            self
          end
          alias reveal_child= set_reveal_child
          # Reads the retained disclosure state.
          def reveal_child? = @reveal_child

          # Validates the supported disclosure transition and reports omitted animation.
          # @param value [Symbol] supported GTK presentation or behavior token
          # @return [Revealer] self
          def set_transition_type(value)
            session.style_operation(self, :set_transition_type) do
              session.refuse(self, :set_transition_type) if destroyed? || !%i[none slide_down].include?(value)
              session.degrade(:reveal_animation, 'reveal state is immediate; native slide animation is omitted')
            end
            self
          end

          # Validates the animation hint while retaining immediate reveal behavior.
          # @param value [Integer] bounded layout or model integer request
          # @return [Revealer] self
          def set_transition_duration(value)
            session.style_operation(self, :set_transition_duration) do
              session.refuse(self, :set_transition_duration) if destroyed? || !value.is_a?(Integer) || !value.between?(0, 10_000)
              session.degrade(:reveal_animation, 'reveal state is immediate; native slide animation is omitted')
            end
            self
          end

          protected

          # Combines explicit visibility with reveal state before delegating the write.
          # @param property [Symbol] shared shadow or port property name
          # @param value [Object] property value accepted by the shared control contract
          # @return [void] result is not part of the supported script contract
          # @api private
          def write(property, value)
            if property == :hidden
              @shown = !value
              value ||= !@reveal_child
            end
            super
          end
        end

        class ScrolledWindow < Widget
          include Container

          attr_reader :vadjustment, :hadjustment

          # Browser viewport measurements supply the scroller's content allocation.
          # @return [Window::Allocation] measured viewport size or its containing window allocation
          def allocation
            width, height = @hadjustment.page_size, @vadjustment.page_size
            if width.zero? && height.zero? && parent.is_a?(Window)
              return parent.allocation
            end
            Window::Allocation.new(width, height)
          end

          # A shared sequence makes repeated same-position requests observable on either axis.
          # @param axis [Symbol] :horizontal or :vertical allocation axis
          # @param target [Integer] validated nonnegative pixel position
          # @return [void] result is not part of the supported script contract
          def request_position(axis, target)
            unless session.with_widget(self) { session.viewer_id }
              initial = (@props[:initial_scroll] || { x: 0, y: 0 }).merge(axis == :horizontal ? { x: target } : { y: target })
              write(:initial_scroll, initial)
              return
            end
            write(axis == :horizontal ? :scroll_position_x : :scroll_position, target)
            @scroll_revision = (@scroll_revision || 0) + 1
            write(axis == :horizontal ? :scroll_revision_x : :scroll_revision, @scroll_revision)
          end

          # Explicit compatibility policy: accept :in but omit its inset decoration.
          # :none is already represented by the browser scroll container. Other shadow
          # types are refused; this is not an arbitrary style-dropping mechanism.
          # @param value [Symbol] :none or :in
          # @return [void]
          def shadow_type=(value)
            session.refuse(self, :shadow_type=) unless %i[none in].include?(value)
            session.degrade(:scroll_shadow, 'shadow-type=in accepted; inset decoration omitted; browser theme applies') if value == :in
          end
          alias set_shadow_type shadow_type=

          # Creates a browser-owned scroller; native adjustment objects are unsupported.
          # @param horizontal [nil] optional legacy horizontal adjustment argument
          # @param vertical [nil] optional legacy vertical adjustment argument
          def initialize(horizontal = nil, vertical = nil)
            super()
            session.refuse(self, :new) unless horizontal.nil? && vertical.nil?
            @vadjustment = ScrollAdjustment.new(self)
            @hadjustment = ScrollAdjustment.new(self, :horizontal)
          end

          # Retains the GTK preference; browser/host chrome owns scrollbar presentation.
          # @param value [Boolean] requested overlay scrollbar preference
          # @return [ScrolledWindow] self
          # @raise [UnsupportedOperation] for invalid values, ownership or retired widgets
          def set_overlay_scrolling(value)
            session.style_operation(self, :set_overlay_scrolling) do
              session.refuse(self, :set_overlay_scrolling) if destroyed? || ![true, false].include?(value)
              @overlay_scrolling = value
              session.degrade(:overlay_scrolling, 'overlay scrollbar preference retained; browser and host determine scrollbar presentation')
            end
            self
          end
          alias overlay_scrolling= set_overlay_scrolling

          # Reads the retained overlay preference with the GTK default.
          # @return [Boolean] retained preference, GTK default true before assignment
          def overlay_scrolling?
            session.style_operation(self, :overlay_scrolling) do
              session.refuse(self, :overlay_scrolling) if destroyed?
              @overlay_scrolling.nil? ? true : @overlay_scrolling
            end
          end
          alias overlay_scrolling overlay_scrolling?

          # Requests a minimum viewport height independently of an explicit height request.
          # GTK's -1 reset becomes an unconstrained zero browser minimum.
          # @param value [Integer] minimum viewport height, -1..65536
          # @return [ScrolledWindow] self
          def set_min_content_height(value)
            set_min_content(:height, value)
          end
          alias min_content_height= set_min_content_height

          # Reads the authored minimum viewport height, including the unset sentinel.
          # @return [Integer] requested floor, or -1 before assignment
          def min_content_height
            session.style_operation(self, :min_content_height) { @min_content_height || -1 }
          end

          # Minimum viewport width uses the same bounded floor/reset as height.
          # @param value [Integer] minimum viewport width, -1..65536
          # @return [ScrolledWindow] self
          def set_min_content_width(value)
            set_min_content(:width, value)
          end
          alias min_content_width= set_min_content_width

          # Reads the authored minimum viewport width, including the unset sentinel.
          # @return [Integer] requested floor, or -1 before assignment
          def min_content_width
            session.style_operation(self, :min_content_width) { @min_content_width || -1 }
          end

          # Reads the retained horizontal overflow policy.
          # @return [Symbol] horizontal policy; :automatic by default
          def hscrollbar_policy = (@scrollbar_policy || %i[automatic automatic]).first
          # Reads the retained vertical overflow policy.
          # @return [Symbol] vertical policy; :automatic by default
          def vscrollbar_policy = (@scrollbar_policy || %i[automatic automatic]).last
          # Updates horizontal overflow while preserving the vertical policy.
          # @param value [Symbol] horizontal overflow policy
          # @return [ScrolledWindow] self
          def set_hscrollbar_policy(value) = session.style_operation(self, :set_hscrollbar_policy) { set_policy(value, vscrollbar_policy) }
          # Updates vertical overflow while preserving the horizontal policy.
          # @param value [Symbol] vertical overflow policy
          # @return [ScrolledWindow] self
          def set_vscrollbar_policy(value) = session.style_operation(self, :set_vscrollbar_policy) { set_policy(hscrollbar_policy, value) }
          alias hscrollbar_policy= set_hscrollbar_policy
          alias vscrollbar_policy= set_vscrollbar_policy

          # Accepts known GTK policy tokens while reporting browser-owned overflow behavior.
          # @param horizontal [Symbol] horizontal scrollbar policy
          # @param vertical [Symbol] vertical scrollbar policy
          # @return [ScrolledWindow] self
          # @raise [UnsupportedOperation] for unknown policies
          def set_policy(horizontal, vertical)
            horizontal, vertical = [horizontal, vertical].map do |value|
              { AUTOMATIC: :automatic, ALWAYS: :always, NEVER: :never }.fetch(value, value)
            end
            session.refuse(self, :set_policy) unless [horizontal, vertical].all? { |value| %i[automatic always never].include?(value) }
            session.refuse(self, :set_policy) if destroyed?
            @scrollbar_policy = [horizontal, vertical].freeze
            session.degrade(:scrollbar_policy, 'browser provides scrollbars when content overflows')
            self
          end

          # Wraps one non-scrollable child in the existing viewport projection.
          # Existing viewports are attached directly. Failed attachment leaves the
          # caller's child alive and unparented, retaining its handle and inputs.
          # @param child [Widget] unparented, live widget belonging to this script
          # @return [ScrolledWindow] self
          # @raise [UnsupportedOperation] for invalid ownership, lifecycle or nesting
          def add_with_viewport(child)
            session.style_operation(self, :add_with_viewport) do
              valid = !destroyed? && @children.empty? && child.is_a?(Widget) &&
                      child.session.equal?(session) && !child.destroyed? && child.parent.nil?
              session.refuse(self, :add_with_viewport) unless valid
              ancestor = self
              while ancestor
                session.refuse(self, :add_with_viewport) if ancestor.equal?(child)
                ancestor = ancestor.parent
              end
              next add(child) if child.is_a?(Viewport)

              viewport = Viewport.new
              begin
                viewport.add(child)
                add(viewport)
              rescue StandardError
                viewport.remove(child) if child.parent.equal?(viewport)
                viewport.destroy
                raise
              end
            end
          end

          # A viewport requests allocation for scrolling rather than expanding
          # its host to the full content size. Explicit expansion flags still win.
          # @param axis [Symbol] :horizontal or :vertical allocation axis
          # @return [Boolean] allocation demand along the requested axis
          # @api private
          def expands?(axis)
            return super unless @children.first.is_a?(Viewport) || @children.first.is_a?(Layout)

            explicit = axis == :horizontal ? @hexpand : @vexpand
            explicit.nil? ? true : explicit
          end

          protected

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :scroll
          # Lists component events needed independently of script connections.
          # @return [Array<Symbol>] required shared event names
          # @api private
          def builtin_events = [:scrolled]

          # Projects container allocation and child alignment into shared layout properties.
          # @return [Hash] shared layout properties
          # @api private
          def layout_props
            allocated = parent.is_a?(Window) || (parent.is_a?(Box) && parent.vertical?)
            { fill: !!(allocated && (@children.first.is_a?(Viewport) || @children.first.is_a?(Layout)) && expands?(:vertical)) }
          end

          # Binds shared notifications to this compatibility object callback path.
          # @param event [Symbol] shared component event family
          # @return [String] shared event binding identity
          # @api private
          def bind_event(event)
            return super unless event == :scrolled

            session.port.bind(@handle, :scrolled, proc do |context|
              session.callback(context, widget: self) do
                @vadjustment.observe(context.viewer_id, context.payload.slice(:position, :upper, :page_size))
                @hadjustment.observe(context.viewer_id, context.payload.slice(:position_x, :upper_x, :page_size_x).transform_keys { |key| key.to_s.delete_suffix('_x').to_sym }) if context.payload.key?(:position_x)
              end
            end)
          end

          private

          # Applies one scroller minimum while retaining the caller's operation name.
          # Publish the browser floor before retaining GTK's request, including -1.
          # @param axis [Symbol] :height or :width from the public wrappers
          # @param value [Integer] requested minimum, -1..65536
          # @return [ScrolledWindow] self
          # @raise [UnsupportedOperation] for invalid values or a retired widget
          # @api private
          def set_min_content(axis, value)
            operation = :"set_min_content_#{axis}"
            session.style_operation(self, operation) do
              valid = value.is_a?(Integer) && value.between?(-1, Lich::WebUI::Contract::BOUNDS[:geometry].end)
              session.refuse(self, operation) if destroyed? || !valid
              write(:"min_#{axis}", [value, 0].max)
              instance_variable_set(:"@min_content_#{axis}", value)
            end
            self
          end
        end
      end
    end
  end
end
