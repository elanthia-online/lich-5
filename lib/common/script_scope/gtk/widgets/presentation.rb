# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        class Widget
          # Maps content border spacing to the shared control's margin.
          # @param value [Integer] bounded layout or model integer request
          # @return [Widget] self
          def set_border_width(value)
            write(:margin, Integer(value))
          end
          alias border_width= set_border_width

          # Sets the requested content width through the shared property contract.
          # @param value [Integer] bounded layout or model integer request
          # @return [Widget] self
          def set_width_request(value)
            write(:width, Integer(value))
          end
          alias width_request= set_width_request

          # Sets the requested content height through the shared property contract.
          # @param value [Integer] bounded layout or model integer request
          # @return [Widget] self
          def set_height_request(value)
            write(:height, Integer(value))
          end
          alias height_request= set_height_request

          # Applies requested dimensions, leaving an axis unchanged when its request is -1.
          # @param width [Integer] requested width in bounded layout units
          # @param height [Integer] requested height in bounded layout units
          # @return [Widget] self
          def set_size_request(width, height)
            set_width_request(width) unless width == -1
            set_height_request(height) unless height == -1
            self
          end

          # Supplies literal tooltip text rather than browser markup.
          # @param value [Object] literal text converted with String before publication
          # @return [Widget] self
          def set_tooltip_text(value)
            write(:tooltip, String(value))
          end
          alias tooltip_text= set_tooltip_text

          # Reads retained literal tooltip metadata, including an unset nil value.
          # @return [String, nil] current tooltip text
          def tooltip_text = read(:tooltip)
          alias get_tooltip_text tooltip_text

          # Accepts the measured normal-state token while retaining browser-theme backgrounds.
          # @param state [Symbol] supported GTK state token
          # @param colour [Gdk::RGBA] typed bounded legacy color
          # @return [Widget] self
          # @raise [UnsupportedOperation] for other state/color objects
          def override_background_color(state, colour)
            session.refuse(self, :override_background_color) unless state == :normal && colour.is_a?(Gdk::RGBA)
            session.degrade(:background_colour, 'widget background colours follow browser theme; displayed values are retained')
            self
          end

          # Labels project bounded foreground colors; control captions remain theme-owned.
          # @param state [Symbol] supported GTK state token
          # @param colour [Gdk::RGBA] typed bounded legacy color
          # @return [Widget] self
          # @raise [UnsupportedOperation] for unknown states, colors, widgets or owner/lifetime misuse
          def override_color(state, colour)
            session.style_operation(self, :override_color) do
              session.refuse(self, :override_color) if destroyed? || state != StateFlags::NORMAL || !colour.is_a?(Gdk::RGBA)
              if is_a?(Label) && !@link_markup
                write(:foreground, @label_color || colour.to_h)
                @props[:foreground] = colour.to_h
              elsif is_a?(Button) || is_a?(ToggleButton) || is_a?(Entry)
                session.degrade(:control_foreground, 'control caption colors follow the WebUI theme', receiver: self)
              else
                session.refuse(self, :override_color)
              end
            end
            self
          end

          # Retains explicit expansion; otherwise containers inherit descendant demand.
          # Horizontal grids use existing expanding tracks and vertical stacks use fill.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [Widget] self
          def set_hexpand(value)
            session.refuse(self, :set_hexpand) unless [true, false].include?(value)
            session.synchronize do
              @hexpand = value
              refresh_layout!
            end
            self
          end
          alias hexpand= set_hexpand

          # Requests available height through the same bounded layout propagation.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [Widget] self
          def set_vexpand(value)
            session.refuse(self, :set_vexpand) unless [true, false].include?(value)
            session.synchronize do
              @vexpand = value
              refresh_layout!
            end
            self
          end
          alias vexpand= set_vexpand

          # Combines explicit expansion hints with descendant allocation demand.
          # @param axis [Symbol] :horizontal or :vertical allocation axis
          # @return [Boolean] explicit or descendant expansion along the given axis
          # @api private
          def expands?(axis)
            explicit = axis == :horizontal ? @hexpand : @vexpand
            explicit.nil? ? @children.any? { |child| child.expands?(axis) } : explicit
          end

          # Recompute only layout properties after a structural/expansion change.
          # Existing adapter handles and viewer-local input remain intact.
          # @return [void] result is not part of the supported script contract
          # @api private
          def refresh_layout!
            root = toplevel
            return unless root.send(:materialized?)
            pending = [root]
            until pending.empty?
              widget = pending.pop
              widget.send(:publish_layout!)
              pending.concat(widget.send(:owned_children))
            end
          end

          # Replaces all edges through the existing bounded margin contract.
          # @param value [Integer] margin in pixels, 0..512
          # @return [Widget] self
          def set_margin(value)
            session.refuse(self, :margin=) unless value.is_a?(Integer) && value.between?(0, 512)
            write(:margin, value)
          end
          alias margin= set_margin

          # Updates the left entry of the widget's explicit per-side margin.
          # @param value [Integer] bounded margin in pixels
          # @return [Widget] self
          def set_margin_left(value)
            set_margin_edge(:left, value)
          end
          alias margin_left= set_margin_left

          # Updates the right entry of the widget's explicit per-side margin.
          # @param value [Integer] bounded margin in pixels
          # @return [Widget] self
          def set_margin_right(value)
            set_margin_edge(:right, value)
          end
          alias margin_right= set_margin_right

          # Updates one vertical edge without changing the other explicit margins.
          # @param value [Integer] margin in pixels, validated by the shared contract
          # @return [Widget] self
          def set_margin_top(value)
            set_margin_edge(:top, value)
          end
          alias margin_top= set_margin_top

          # Changes the bottom margin while preserving the other edges.
          # @param value [Integer] bottom margin in pixels
          # @return [Widget] self
          def set_margin_bottom(value)
            set_margin_edge(:bottom, value)
          end
          alias margin_bottom= set_margin_bottom

          # A scalar margin applies to every edge; changing one preserves the other three.
          # Builder and direct GTK calls share this normalization and contract validation.
          # @param side [Symbol] margin edge to replace
          # @param value [Integer] bounded margin in pixels
          # @return [Widget] self
          # @api private
          def set_margin_edge(side, value)
            current = margin_value
            margins = case current
                      when Hash then current
                      when Numeric then %i[top right bottom left].to_h { |key| [key, current] }
                      else {}
                      end
            write(:margin, margins.merge(side => value))
          end
          private :set_margin_edge

          # Internal entry facades override the source without changing edge normalization.
          # @return [Integer, Hash, nil] authored scalar or per-edge margin
          # @api private
          def margin_value = @props[:margin]
          private :margin_value

          # Aligns the widget in its allocated grid cell or enclosing frame.
          # Content alignment (Label#yalign=) is a separate request.
          # @param value [Symbol] :fill, :start, :center or :end
          # @return [void] result is not part of the supported script contract
          def valign=(value)
            session.refuse(self, :valign=) unless %i[fill start center end].include?(value)
            alignment = value == :fill ? :stretch : value
            validate_vertical_parent(alignment) if parent
            write(:vertical_align, alignment)
            refresh_layout!
          end
          alias set_valign valign=

          # Maps GTK horizontal fill onto the existing grid stretch allocation.
          # @param value [Symbol] supported GTK presentation or behavior token
          # @return [Widget] self
          def halign=(value)
            session.refuse(self, :halign=) unless %i[fill start center end].include?(value)
            write(:align, value == :fill ? :stretch : value)
          end
          alias set_halign halign=

          # Accepts only the focus behavior already provided by this concrete control.
          # Composite entries and non-default requests need their own implementation;
          # disabling focus must never be confused with disabling the whole widget.
          # @param value [Boolean] requested ability to own input focus
          # @return [void]
          # @raise [UnsupportedOperation] when no equivalent control behavior exists
          def can_focus=(value)
            kind = self.class.name&.split('::')&.last
            focusable = %w[Button ToggleButton CheckButton RadioButton Entry ComboEntry SearchEntry SpinButton TextView Notebook ScrolledWindow Expander TreeView ComboBoxText ComboBox]
            passive = %w[Window Box HBox VBox Grid Table Frame Viewport Label Separator HSeparator]
            expected = if focusable.include?(kind) then true
                       elsif passive.include?(kind) then false
                       end
            session.refuse(self, :can_focus=) if expected.nil? || value != expected
          end
          alias set_can_focus can_focus=

          alias set_margin_start set_margin_left
          alias set_margin_end set_margin_right
          alias margin_start= set_margin_start
          alias margin_end= set_margin_end

          # Decodes text entities but refuses tags instead of forwarding markup to the browser.
          # @param value [String] bounded markup translated to safe typed presentation
          # @return [void] result is not part of the supported script contract
          # @raise [UnsupportedOperation] when tags are present
          def tooltip_markup=(value)
            session.refuse(self, :tooltip_markup=) if value.match?(/<[^>]*>/)
            write(:tooltip, CGI.unescapeHTML(value))
          end

          # Clears tooltip text when disabled; enabling does not invent tooltip content.
          # @param enabled [Boolean] whether tooltip content remains enabled
          # @return [void] result is not part of the supported script contract
          # @raise [UnsupportedOperation] for nonboolean values
          def has_tooltip=(enabled)
            session.refuse(self, :has_tooltip=) unless enabled == true || enabled == false
            write(:tooltip, '') unless enabled
          end

          # Sensitivity controls interaction through the existing disabled
          # attribute; input values remain available when a field is disabled.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [Widget] self
          def set_sensitive(value)
            session.refuse(self, :set_sensitive) unless [true, false].include?(value)
            @sensitive = value
            if session.port.schema(component_type)[:properties].key?(:disabled)
              write(:disabled, !value)
            else
              session.degrade(:noninteractive_sensitivity, 'noninteractive text uses browser theme; sensitivity remains readable')
              self
            end
          end
          alias sensitive= set_sensitive

          # Reads retained interaction sensitivity, including for noninteractive controls.
          # @return [Boolean] true by default
          def sensitive? = @sensitive != false

          # Reads effective sensitivity without overwriting a child's own setting.
          # @return [Boolean] false when this widget or any ancestor is insensitive
          def is_sensitive? = sensitive? && (!parent || parent.is_sensitive?)
        end
      end
    end
  end
end
