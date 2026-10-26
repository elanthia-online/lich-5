# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # A client-area title row composed from existing shared controls. It does
        # not replace native OS chrome or introduce another window lifecycle.
        class HeaderBar < Box
          # Builds action regions, a fallback title and an initially hidden Close
          # control. Closing is dispatched through the owning Window's lifecycle.
          def initialize
            super(:horizontal, 6)
            @start = Box.new(:horizontal, 6)
            @middle = Box.new(:vertical, 0)
            @end = Box.new(:horizontal, 6)
            @title_label = Label.new('')
            @middle.add(@title_label)
            @close_button = Button.new('Close')
            @close_button.set_tooltip_text('Close window')
            @close_button.signal_connect('clicked') do
              window = parent
              window.close if window.is_a?(Window) && window.titlebar.equal?(self)
            end
            [@start, @middle, @end, @close_button].each do |child|
              pack(child, [], expand: child.equal?(@middle), fill: child.equal?(@middle), padding: 0, ending: false)
            end
            set_show_close_button(false)
          end

          # Header actions retain their own callbacks and window attribution.
          # @param child [Widget] unparented action from this script session
          # @return [HeaderBar] self
          def pack_start(child)
            @start.pack_start(child, expand: false, fill: false)
            self
          end
          alias add pack_start

          # Packs an action in the trailing region, preserving Box end ordering.
          # @param child [Widget] unparented action from this script session
          # @return [HeaderBar] self
          def pack_end(child)
            @end.pack_end(child, expand: false, fill: false)
            self
          end

          # Sets the fallback title, including while a custom title is displayed.
          # @param value [String] literal title text
          # @return [HeaderBar] self
          def set_title(value)
            @title_label.text = value
            self
          end
          alias title= set_title

          # Reads the fallback title independently of the current custom widget.
          # @return [String] stored fallback title text
          def title = @title_label.text

          # Returns the custom title only while it remains attached to this header.
          # @return [Widget, nil] active custom title, or nil for the fallback title
          def custom_title
            @custom_title if @custom_title&.parent.equal?(@middle)
          end

          # Script-owned actions can be detached and reused without exposing slots.
          # @param child [Widget] current custom title or packed action
          # @return [HeaderBar] self
          # @raise [UnsupportedOperation] if the child is not owned by a title/action region
          def remove(child)
            if child.equal?(custom_title) && child
              set_custom_title(nil)
            elsif child.is_a?(Widget) && [@start, @end].include?(child.parent)
              child.parent.remove(child)
            else
              session.refuse(self, :remove)
            end
            self
          end

          # Replacement detaches the old title without destroying a script-held widget.
          # @param child [Widget, nil] unparented same-session title; nil restores the fallback
          # @return [HeaderBar] self
          # @raise [UnsupportedOperation] for invalid ownership, lifetime or hierarchy
          def set_custom_title(child)
            session.synchronize do
              session.refuse(self, :set_custom_title) if destroyed?
              session.refuse(self, :set_custom_title) unless child.nil? || child.is_a?(Widget)
              return self if @middle.children.include?(child || @title_label)

              if child
                valid = child.is_a?(Widget) && child.session.equal?(session) && !child.destroyed? && !child.parent
                session.refuse(self, :set_custom_title) unless valid && !toplevel.equal?(child)
              end
              current = @middle.children.first
              @middle.add(child || @title_label)
              @middle.remove(current) if current
              @custom_title = child
            end
            self
          end
          alias custom_title= set_custom_title

          # A visible Close action uses Window#close, including delete-event vetoes.
          # @param value [Boolean] whether the Close control should be visible
          # @return [HeaderBar] self
          # @raise [UnsupportedOperation] unless value is true or false
          def set_show_close_button(value)
            session.refuse(self, :set_show_close_button) unless value == true || value == false
            @show_close_button = value
            value ? @close_button.show : @close_button.hide
            self
          end
          alias show_close_button= set_show_close_button

          # Reports the requested Close visibility, retained across show_all calls.
          # @return [Boolean] whether the Close control is enabled for display
          def show_close_button? = @show_close_button

          # Shows the title/actions while honoring the stored Close visibility flag.
          # @return [HeaderBar] self
          def show_all
            super
            @close_button.hide unless @show_close_button
            self
          end
        end
      end
    end
  end
end
