# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        class Entry < Widget
          # Legacy base-color requests share the explicit themed-background omission.
          # @param state [Symbol] normal state only
          # @param colour [Gdk::Color] bounded legacy color value
          # @return [Entry] self
          def modify_base(state, colour)
            session.style_operation(self, :modify_base) do
              session.refuse(self, :modify_base) if destroyed? || !colour.is_a?(Gdk::Color)
              override_background_color(state, colour.to_rgba)
            end
          end

          # Explicit initialization notification uses the ordinary synchronous
          # callback path, without changing text or fabricating a browser event.
          # @param name [String, Symbol] only changed
          # @return [nil] the GTK void-signal result
          def signal_emit(name)
            session.style_operation(self, :signal_emit) do
              session.refuse(self, :signal_emit) if destroyed? || !["changed", :changed].include?(name)
              emit_handlers(:change, signal: 'changed')
            end
            nil
          end

          # Creates an empty editable entry using the shared read-only property.
          def initialize
            super
            @props[:value] = ''
            @editable = true
          end

          # Reads current callback input or retained committed/default entry text.
          # @return [String]
          def text = read(:value)

          # GTK emits changed for an actual programmatic text change as well as
          # typing, including read-only entries. Notify through the same handler
          # path after the validated write; equal writes must not recurse.
          # @param value [Object] literal text converted with String before publication
          # @return [Entry] self
          def set_text(value)
            text = String(value)
            text = text[0, @props[:max_length]] if @props[:max_length]
            session.synchronize do
              previous = read(:value)
              write(:value, text)
              emit_handlers(:change) unless previous == text
            end
            self
          end
          alias text= set_text

          # GTK truncates existing and programmatically assigned text to its
          # declared character limit. Configure before publication; live limit
          # changes would need an atomic limit/value update for every viewer.
          # Zero retains the core's existing 8192-character safety boundary.
          # @param value [Integer] 0..8192; zero means no smaller script limit
          # @return [Entry] self
          def set_max_length(value)
            session.refuse(self, :max_length=) unless !@handle && value.is_a?(Integer) && value.between?(0, 8192)
            @props[:max_length] = value.zero? ? 8192 : value
            self.text = read(:value)
            self
          end
          alias max_length= set_max_length

          # Sets literal placeholder text for the shared input control.
          # @param value [Object] literal text converted with String before publication
          # @return [Entry] self
          def placeholder_text=(value)
            write(:placeholder, String(value))
          end
          alias set_placeholder_text placeholder_text=

          # Uses the same typed character minimum as native WebUI forms, not a pixel guess.
          # @param count [Integer] 1..1024; reset requests remain unsupported
          # @return [Entry] self
          def set_width_chars(count)
            session.refuse(self, :set_width_chars) unless count.is_a?(Integer) && count.between?(1, 1024)
            write(:min_width_chars, count)
          end

          alias width_chars= set_width_chars

          # Caps the entry's natural character width through the existing core
          # metric. This is presentation sizing, not a limit on entered text.
          # @param count [Integer] 1..1024; reset requests remain unsupported
          # @return [Entry] self
          def set_max_width_chars(count)
            session.refuse(self, :set_max_width_chars) unless count.is_a?(Integer) && count.between?(1, 1024)
            write(:max_width_chars, count)
          end
          alias max_width_chars= set_max_width_chars

          # Maps a unit-interval fraction to start/center/end text alignment.
          # @param value [Numeric] finite numeric presentation request within the supported range
          # @return [void] result is not part of the supported script contract
          # @raise [UnsupportedOperation] for out-of-range values
          def xalign=(value)
            session.refuse(self, :xalign=) unless value.is_a?(Numeric) && value.real? && value.finite? && value.between?(0, 1)
            write(:align, value.zero? ? :start : (value == 1 ? :end : :center))
          end
          alias set_alignment xalign=

          # Updates server-owned read-only behavior without replacing the input
          # or its viewer draft. The core rejects subsequent read-only edits.
          # @param value [Boolean] explicit boolean preference for this operation
          # @return [void] result is not part of the supported script contract
          # @raise [UnsupportedOperation] for invalid values, ownership or lifetime
          def editable=(value)
            session.style_operation(self, :editable=) do
              session.refuse(self, :editable=) if destroyed? || ![true, false].include?(value)
              write(:read_only, !value)
              @editable = value
            end
          end
          alias set_editable editable=

          # Controls the entry's visible border without affecting editability or focus.
          # @param value [Boolean] whether to draw the standard entry frame
          # @return [Entry] self
          def set_has_frame(value) = write(:has_frame, value)
          alias has_frame= set_has_frame

          protected

          # Selects the shared component type for this compatibility object.
          # @return [Symbol] shared component type
          # @api private
          def component_type = :text_input
          # Identifies the viewer input retained by this widget.
          # @return [Symbol, nil] input property, or nil for non-input widgets
          # @api private
          def input_property = :value
          # Maps supported GTK signal spellings to shared component events.
          # @return [Hash{String => Symbol}] accepted GTK signals and shared events
          # @api private
          def signal_map = { 'changed' => :change, 'activate' => :submit, 'focus-in-event' => :focus, 'focus-out-event' => :blur }

          # Combines shadow properties with the current shared presentation.
          # @return [Hash] shared presentation properties
          # @api private
          def component_props
            super.merge(change_mode: :input, read_only: !@editable)
          end
        end
      end
    end
  end
end
