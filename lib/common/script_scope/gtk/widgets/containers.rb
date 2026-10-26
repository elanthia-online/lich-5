# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        class Box < Widget
          include Container

          # Reports whether Box uses vertical packing.
          # @api private
          def vertical? = @orientation == :vertical

          # Creates a horizontal grid or vertical stack with the requested spacing.
          # Numeric orientation 0/1 is accepted for the measured GTK enum usage.
          # @param orientation [Symbol, Integer] horizontal/vertical token or supported numeric enum
          # @param spacing [Integer] gap between children
          def initialize(orientation = :horizontal, spacing = 0)
            super()
            # sloot uses GTK's numeric vertical enum in its Save button box.
            orientation = { 0 => :horizontal, 1 => :vertical, Horizontal: :horizontal, Vertical: :vertical }.fetch(orientation, orientation)
            session.refuse(self, :new) unless %i[horizontal vertical].include?(orientation)
            @orientation = orientation
            @end_children = []
            @packing = {}.compare_by_identity
            @props[:gap] = Integer(spacing)
          end

          # Forget packing metadata when a live child is detached for reuse.
          # @param child [Widget] same-session child governed by this container
          # @return [Box] self
          def remove(child)
            super
            @packing.delete(child)
            self
          end

          # Inserts before end-packed children while retaining accepted positional packing arguments.
          # @param child [Widget] same-session child governed by this container
          # @param packing [Array<Object>] legacy positional expand, fill and padding arguments
          # @param expand [Boolean] whether the child requests surplus allocation
          # @param fill [Boolean] whether the child fills its allocation
          # @param padding [Integer] child inset in bounded layout units
          # @return [Box] self
          def pack_start(child, *packing, expand: true, fill: true, padding: 0)
            pack(child, packing, expand: expand, fill: fill, padding: padding, ending: false)
          end

          # Legacy GTK defaults expand and fill the child with no extra padding.
          # @param child [Widget] unparented child owned by this script
          # @return [Box] self
          def pack_start_defaults(child) = pack_start(child, expand: true, fill: true, padding: 0)

          # GTK packs each new end child before the previous end children.
          # hands_and_room depends on this to show right, left, then room.
          # @param child [Widget] same-session child governed by this container
          # @param packing [Array<Object>] legacy positional expand, fill and padding arguments
          # @param expand [Boolean] whether the child requests surplus allocation
          # @param fill [Boolean] whether the child fills its allocation
          # @param padding [Integer] child inset in bounded layout units
          # @return [Box] self
          def pack_end(child, *packing, expand: true, fill: true, padding: 0)
            pack(child, packing, expand: expand, fill: fill, padding: padding, ending: true)
          end

          protected

          # Removes a retired child from the owning collection and refreshes layout.
          # @param child [Widget] same-session child governed by this container
          # @return [void] result is not part of the supported script contract
          # @api private
          def forget_child(child)
            @packing.delete(child)
            super
          end

          # Applies legacy packing arguments while retaining one parent and stable child order.
          # @param child [Widget] same-session child governed by this container
          # @param packing [Array<Object>] legacy positional expand, fill and padding arguments
          # @param expand [Boolean] whether the child requests surplus allocation
          # @param fill [Boolean] whether the child fills its allocation
          # @param padding [Integer] child inset in bounded layout units
          # @param ending [Boolean] whether to retain the child in the end-packed group
          # @return [Box] self
          # @api private
          def pack(child, packing, expand:, fill:, padding:, ending:)
            session.refuse(self, :pack_start) if packing.length > 3
            expand = packing[0] if packing.length >= 1
            fill = packing[1] if packing.length >= 2
            padding = packing[2] if packing.length >= 3
            session.style_operation(self, :pack_start) do
              session.refuse(self, :pack_start) if destroyed? || !child.is_a?(Widget) || child.destroyed? || !child.session.equal?(session)
              ancestor = child.parent
              if ancestor && !ancestor.equal?(self)
                ancestor = ancestor.parent until ancestor.nil? || ancestor.equal?(self)
                if ancestor.equal?(self)
                  session.source_warning(self, :pack_start, 'child already contained through another parent; redundant packing ignored')
                  return self
                end
              end
              child.set_border_width(padding) if padding.positive?
              # Horizontal grouping and fixed requested widths carry the measured
              # packing intent; browser layout owns excess-space distribution.
              session.degrade(:packing, 'excess space follows browser layout') if expand != fill
              @end_children.select! { |widget| widget.parent.equal?(self) }
              previous_cols = [@children.length, 1].max
              growing = @handle && @orientation == :horizontal && !@children.include?(child)
              session.port.set(@handle, :cols, @children.length + 1) if growing
              begin
                insert_child(child, @children.length - @end_children.length)
              rescue StandardError
                session.port.set(@handle, :cols, previous_cols) if growing
                raise
              end
              @end_children << child if ending && !@end_children.include?(child)
              @packing[child] = { expand: expand, fill: fill }
              refresh_layout!
            end
            self
          end

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = vertical? && !@homogeneous ? :stack : :grid

          # Natural tracks keep long captions from spilling into equal-width peers.
          # Expanded children share surplus width; their own alignment still applies.
          # @return [Hash] shared layout properties
          # @api private
          def layout_props
            return {} unless %i[stack grid].include?(component_type)
            if vertical?
              return { cols: 1, equal_rows: true } if @homogeneous

              allocated = parent.is_a?(Window) || (parent.is_a?(Box) && parent.vertical?)
              { fill: !!(allocated && expands?(:vertical)) }
            else
              expanding = @children.each_index.select do |index|
                child = @children[index]
                child.expands?(:horizontal) || @packing.dig(child, :expand) == true
              end.map { |index| index + 1 }
              { cols: [@children.length, 1].max, homogeneous: @homogeneous == true, expand_columns: expanding }
            end
          end
        end

        # Measured horizontal action rows use natural tracks aligned to the end.
        # Other GTK ButtonBox layouts remain explicit unsupported operations.
        class ButtonBox < Box
          # Creates the supported horizontal action row aligned to the end.
          # @param orientation [Symbol, Integer] horizontal/vertical token or supported numeric enum
          def initialize(orientation = :horizontal)
            super(orientation)
            session.refuse(self, :new) if vertical?
            @props[:align] = :end
          end

          # Reads the retained action-row alignment.
          # @return [Symbol] retained action alignment
          def layout = read(:align)

          # Applies the supported end-aligned action-row layout.
          # @param value [Symbol] the measured :end layout
          # @return [ButtonBox] self
          def set_layout(value)
            session.refuse(self, :layout=) unless value == :end
            write(:align, value)
          end
          alias layout= set_layout

          # Reads the authored gap between action buttons.
          # @return [Integer] authored gap
          def spacing = read(:gap)

          # Updates the bounded action-row gap.
          # @param value [Integer] inter-button gap in pixels, 0..64
          # @return [ButtonBox] self
          def set_spacing(value)
            session.refuse(self, :spacing=) unless value.is_a?(Integer) && value.between?(0, 64)
            write(:gap, value)
          end
          alias spacing= set_spacing

          # Use Box's live grid growth before admitting another button.
          # @param child [Widget] same-session child governed by this container
          # @return [ButtonBox] self
          def add(child)
            pack_start(child, expand: false, fill: false)
          end

          protected

          # Projects container allocation and child alignment into shared layout properties.
          # @return [Hash] shared layout properties
          # @api private
          def layout_props = super.merge(expand_columns: [])
        end

        # Legacy horizontal constructor using the existing Box packing contract.
        class HBox < Box
          # Creates a horizontal group with optional equal-width tracks.
          # @param homogeneous [Boolean] whether children share equal widths
          # @param spacing [Integer] gap between children in shared layout units
          # @raise [UnsupportedOperation] when homogeneous is not boolean
          def initialize(homogeneous = false, spacing = 0)
            super(:horizontal, spacing)
            session.refuse(self, :new) unless [true, false].include?(homogeneous)
            @homogeneous = homogeneous
          end
        end

        # Legacy vertical constructor using the existing Box packing contract.
        class VBox < Box
          # Creates a vertical group with optional equal-height grid rows.
          # @param homogeneous [Boolean] whether children share equal heights
          # @param spacing [Integer] gap between children in shared layout units
          # @raise [UnsupportedOperation] when homogeneous is not boolean
          def initialize(homogeneous = false, spacing = 0)
            super(:vertical, spacing)
            session.refuse(self, :new) unless [true, false].include?(homogeneous)
            @homogeneous = homogeneous
          end
        end

        class Alignment < Widget
          include Container

          # Matches GTK's finite-value clamping before projecting horizontal alignment.
          # Vertical fractions/scaling remain layout hints, not a full GTK allocator.
          # @param xalign [Numeric] finite horizontal alignment fraction, clamped to 0..1
          # @param yalign [Numeric] finite vertical alignment fraction, clamped to 0..1
          # @param xscale [Numeric] finite horizontal scaling hint
          # @param yscale [Numeric] finite vertical scaling hint
          # @raise [UnsupportedOperation] for non-real or nonfinite numeric inputs
          def initialize(xalign, yalign, xscale, yscale)
            super()
            values = [xalign, yalign, xscale, yscale]
            session.refuse(self, :new) unless values.all? { |value| value.is_a?(Numeric) && value.real? && value.finite? }
            xalign = values.map { |value| value.clamp(0, 1) }.first
            @props[:align] = xalign == 1 ? :end : (xalign.zero? ? :start : :center)
          end

          # Maps each padding edge to its corresponding shared margin.
          # @param top [Integer] top padding in bounded layout units
          # @param bottom [Integer] bottom padding in bounded layout units
          # @param left [Integer] left padding in bounded layout units
          # @param right [Integer] right padding in bounded layout units
          # @return [Alignment] self
          def set_padding(top, bottom, left, right)
            write(:margin, { top: top, bottom: bottom, left: left, right: right })
          end

          protected

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :stack
        end

        class Frame < Widget
          include Container

          # A frame's requested width is a minimum; it must still contain its
          # child's natural requisition instead of clipping the grid decoration.
          # @param value [Integer] bounded layout or model integer request
          # @return [Frame] self
          def set_width_request(value)
            write(:min_width, Integer(value))
          end
          alias width_request= set_width_request

          # Height requests likewise set a floor, allowing the child's natural
          # height to grow the frame instead of centering overflow above it.
          # @param value [Integer] bounded layout or model integer request
          # @return [Frame] self
          def set_height_request(value)
            write(:min_height, Integer(value))
          end
          alias height_request= set_height_request

          # GTK creates no label widget when the constructor label is absent.
          # @param label [String, nil] frame label; an empty string creates a blank label
          def initialize(label = nil)
            super()
            set_label(label) unless label.nil?
          end

          # Reads retained literal caption text.
          # @return [String, nil] caption, preserving absent and explicitly empty labels
          def label = read(:label)

          # Changes only the shared group caption, preserving children and their identities.
          # @param value [String] literal caption, at most 512 characters
          # @return [Frame] self
          def set_label(value)
            validate_caption!(value)
            write(:label, value)
            @frame_label ||= Label.new(value)
            @frame_label.caption_owner = self
            @frame_label.text = value unless @frame_label.text == value
            self
          end
          alias label= set_label

          # Returns the currently owned frame caption widget.
          # @return [Label, nil] owned caption, retired when replaced or destroyed
          def label_widget = @frame_label

          # Retires the owned caption when a containing window retires this frame.
          # @return [void]
          def mark_destroyed
            super
            @frame_label&.mark_destroyed
          end

          # Adopts a same-session unparented label and retires the prior caption.
          # Publishes before cleanup so rejected writes preserve ownership and
          # destroy callbacks observe the replacement without later overwrites.
          # @param label [Label] live, unowned replacement with bounded literal text
          # @return [Frame] self
          # @raise [UnsupportedOperation] for invalid labels or a destroyed frame
          def set_label_widget(label)
            session.style_operation(self, :set_label_widget) do
              valid = label.is_a?(Label) && label.session.equal?(session) && !label.destroyed? && label.parent.nil? &&
                      !label.tab_owner && !label.caption_owner
              session.refuse(self, :set_label_widget) unless valid && !destroyed?
              text = label.text
              validate_caption!(text)
              write(:label, text)
              previous = @frame_label
              previous.caption_owner = nil if previous
              @frame_label = label
              label.caption_owner = self
              previous&.destroy
            end
            self
          end

          # Releases the current caption and its style context exactly once.
          # @return [Frame] self
          def destroy
            super
            @frame_label&.destroy
            self
          end

          # The shared frame already places its caption at the left edge.
          # @param value [Numeric] only zero is supported
          # @return [void]
          def label_xalign=(value)
            session.refuse(self, :label_xalign=) unless value.is_a?(Numeric) && value.zero?
          end

          # Restores the themed frame border for :in; native inset bevels are omitted.
          # @param value [Symbol] :none, :in or :etched_in
          # @return [Frame] self
          def set_shadow_type(value)
            session.refuse(self, :shadow_type=) unless %i[none in etched_in].include?(value)
            write(:border_width, value == :none ? 0 : 1)
            session.degrade(:frame_shadow, 'native inset/etched bevel uses the themed frame border; bevel decoration omitted') unless value == :none
            self
          end
          alias shadow_type= set_shadow_type

          protected

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :group

          # Synchronizes owned caption text, reporting only omitted markup styling.
          # @param label [Label] caption whose content or fragments changed
          # @return [Object] write result, or nil for a retired/unchanged caption
          # @api private
          def refresh_caption(label)
            refresh_owned_caption(label, @frame_label,
                                  operation: :frame_caption_style,
                                  message: 'frame caption keeps literal label text; caption typography follows browser theme')
          end

          # Applies the shared caption bound before any ownership or port change.
          # @param value [String] proposed literal heading
          # @return [void]
          # @raise [UnsupportedOperation] for malformed or oversized headings
          # @api private
          def validate_caption!(value)
            valid = value.is_a?(String) && value.valid_encoding? && value.encoding.ascii_compatible? &&
                    value.length <= Lich::WebUI::Contract::BOUNDS[:short_text]
            session.refuse(self, :label=) unless valid
          end

          # A frame aligns its child's natural height within its own allocation.
          # Explicit :start resets an earlier center/end request after live edits.
          # @return [Hash] shared layout properties
          # @api private
          def layout_props
            alignment = @children.first&.instance_variable_get(:@props)&.fetch(:vertical_align, nil)
            return {} unless alignment || @published_layout&.key?(:content_align)

            { content_align: alignment && alignment != :stretch ? alignment : :start }
          end
        end
      end
    end
  end
end
