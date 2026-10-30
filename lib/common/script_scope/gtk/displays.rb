# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # Use the contracted split primitive: the first child's natural width
        # establishes the initial divider, and the viewer owns later dragging.
        class Paned < Box
          # Creates the supported horizontal split using the common layout contract.
          # @raise [UnsupportedOperation] for other orientations
          def initialize(orientation)
            super(orientation)
            session.refuse(self, :new) unless orientation == :horizontal
          end

          # Adds the first split child only while the split is empty.
          # @return [Paned] self
          def add1(child)
            session.refuse(self, :add1) unless children.empty?
            add(child)
          end

          # Adds the second split child only after the first exists.
          # @return [Paned] self
          def add2(child)
            session.refuse(self, :add2) unless children.length == 1
            add(child)
          end

          # Uses the existing draggable split; native allocation hints are omitted.
          # @param resize [Boolean] native resize hint, reported as browser-owned
          # @param shrink [Boolean] native shrink hint, reported as browser-owned
          def pack1(child, resize = false, shrink = true)
            pack_pane(child, resize, shrink, :add1)
          end

          # Packs the second pane with the same bounded split policy.
          def pack2(child, resize = true, shrink = true)
            pack_pane(child, resize, shrink, :add2)
          end

          # Initial pixels use the existing first-resizing/second-fixed split.
          # A live reset would overwrite a viewer's drag and remains unsupported.
          def set_position(value)
            valid = !@handle && value.is_a?(Integer) && value.between?(0, 65_536)
            valid &&= @pane_resize == { add1: true, add2: false }
            session.refuse(self, :position=) unless valid
            @props.merge!(position_pixels: value, resize_side: :first)
            self
          end
          alias position= set_position

          private

          def pack_pane(child, resize, shrink, operation)
            session.synchronize do
              session.refuse(self, :pack) unless [resize, shrink].all? { |value| [true, false].include?(value) }
              public_send(operation, child)
              (@pane_resize ||= {})[operation] = resize
              session.degrade(:split_packing, 'native resize and shrink hints follow browser split layout; the divider remains user-controlled')
            end
            self
          end

          protected

          def component_type = :split
          def component_props = super.except(:cols, :gap).merge(orientation: :horizontal)
          def builtin_events = [:move]
        end

        class Overlay < Widget
          # Records overlay children separately from the underlying content.
          def initialize
            super
            @overlays = {}.compare_by_identity
          end

          # Adds a same-owner layer; pointer events reach this layer by default.
          # @return [Overlay] self
          def add_overlay(child)
            session.synchronize do
              session.refuse(self, :add_overlay) if destroyed? || child.is_a?(Widget) && child.destroyed?
              session.refuse(self, :add_overlay) if children.include?(child) && !@overlays.key?(child)
              add(child)
              @overlays[child] = false unless @overlays.key?(child)
            end
            self
          end

          # Changes hit testing without replacing the child, its input or bindings.
          # @param child [Widget] a live layer added with add_overlay
          # @param value [Boolean] whether pointer events pass through the layer
          # @return [Overlay] self
          def set_overlay_pass_through(child, value)
            session.synchronize do
              validate_overlay(child, :set_overlay_pass_through)
              session.refuse(self, :set_overlay_pass_through) unless [true, false].include?(value)
              session.port.set_overlay_pass_through(@handle, child.materialize, value) if @handle
              @overlays[child] = value
            end
            self
          end

          # @return [Boolean] the layer's requested pointer pass-through state
          def get_overlay_pass_through(child)
            session.synchronize do
              validate_overlay(child, :get_overlay_pass_through)
              @overlays.fetch(child)
            end
          end

          # Applies pending layer flags before the enclosing page can publish.
          # @return [Lich::WebUI::Adapter::Handle]
          def materialize
            session.synchronize do
              handle = super
              @overlays.each { |child, value| session.port.set_overlay_pass_through(handle, child.materialize, value) }
              handle
            end
          end

          # Detachment releases relationship state so reparenting starts normally.
          def remove(child)
            session.synchronize do
              super
              @overlays.delete(child)
            end
            self
          end

          # Reordering briefly detaches a handle; retain this layer's hit testing.
          # @return [Overlay] self
          def reorder_child(child, index)
            session.synchronize do
              super
              if @handle && @overlays.key?(child)
                session.port.set_overlay_pass_through(@handle, child.materialize, @overlays.fetch(child))
              end
            end
            self
          end

          # Owner/window destruction releases all layer metadata.
          def mark_destroyed
            super
            @overlays.clear
          end

          protected

          # Child destruction also retires its overlay relationship.
          def forget_child(child)
            @overlays.delete(child)
            super
          end

          def component_type = :overlay

          private

          # Refuses stale, foreign and ordinary content children.
          def validate_overlay(child, operation)
            valid = !destroyed? && @overlays.key?(child) && !child.destroyed? && child.parent.equal?(self)
            session.refuse(self, operation) unless valid
          end
        end

        class ProgressBar < Widget
          # Initializes a progress control at an empty fraction.
          def initialize
            super
            @props[:value] = 0.0
          end

          # A GTK width request is a minimum; the trough fills its overlay cell.
          # @param value [Integer] minimum width in pixels
          # @return [ProgressBar] self
          def set_width_request(value)
            write(:min_width, Integer(value))
          end
          alias width_request= set_width_request

          # Bounds the displayed fraction without changing the script's arithmetic.
          # NaN has no representable WebUI fraction; retain the last display value
          # and report that degradation once rather than aborting the whole update.
          # @param value [Numeric] requested fraction; infinities saturate at an end
          # @return [ProgressBar] this progress bar
          # @raise [UnsupportedOperation] when the value is not a real number
          def set_fraction(value)
            session.refuse(self, :set_fraction) unless value.is_a?(Numeric) && value.real?
            fraction = value.to_f
            if fraction.nan?
              session.degrade(:progress_fraction_nan, 'undefined fraction; retaining the last displayed value')
              return self
            end

            session.synchronize do
              write(:value, fraction.clamp(0.0, 1.0))
              refresh_progress_text if show_text? && @text.nil?
            end
            self
          end
          alias fraction= set_fraction

          # @return [Float] retained bounded fraction
          def fraction = read(:value)

          # Hides only the bar's own text; independent overlay labels remain visible.
          # @param value [Boolean] whether to display authored text or a percentage
          # @return [ProgressBar] self
          def set_show_text(value)
            session.refuse(self, :show_text=) unless [true, false].include?(value)
            session.synchronize do
              publish_progress_text(value, @text)
              @show_text = value
            end
            self
          end
          alias show_text= set_show_text

          # @return [Boolean] false until explicitly enabled
          def show_text? = @show_text == true

          # Retains bounded plain text even while hidden; nil selects percentage text.
          # @param value [String, nil] literal progress text
          # @return [ProgressBar] self
          def set_text(value)
            valid = value.nil? || (value.is_a?(String) && value.length <= Lich::WebUI::Contract::BOUNDS[:short_text])
            session.refuse(self, :text=) unless valid
            session.synchronize do
              text = value&.dup&.freeze
              publish_progress_text(show_text?, text)
              @text = text
            end
            self
          end
          alias text= set_text

          # @return [String, nil] authored text, independent of its visibility
          def text = @text

          protected

          # Fraction changes update the default percentage through the same handle.
          def refresh_progress_text
            publish_progress_text(show_text?, @text)
          end

          # Uses the existing optional label, removing it entirely when hidden.
          def publish_progress_text(visible, text)
            if visible
              write(:label, text || "#{(fraction * 100).round}%")
            else
              session.port.set(@handle, :label, Lich::WebUI::Adapter::UNSET) if @handle && !destroyed?
              @props.delete(:label)
            end
          end

          # Style effects overlay authored values; provider removal never loses a
          # preexisting request. A later explicit write wins until styling clears.
          def component_props
            super.merge(@progress_style || {}).merge(@style_overrides || {})
          end

          def write(property, value)
            session.synchronize do
              super
              (@style_overrides ||= {})[property] = value if @progress_style&.key?(property)
            end
            self
          end

          # Publishes typed effects through the existing handle. Clearing an
          # absent authored property uses the adapter's explicit reset token.
          # @api private
          def apply_progress_style(style)
            session.synchronize do
              overrides = style.empty? ? {} : (@style_overrides || {})
              before = component_props
              after = @props.merge(style).merge(overrides)
              if @handle && !@destroyed
                %i[fill_color height].each do |property|
                  next if before[property] == after[property]
                  value = after.fetch(property, Lich::WebUI::Adapter::UNSET)
                  session.with_widget(self) { session.port.set(@handle, property, value) }
                end
              end
              @progress_style = style
              @style_overrides = overrides
            end
          end

          def component_type = :progress
        end
      end
    end
  end
end
