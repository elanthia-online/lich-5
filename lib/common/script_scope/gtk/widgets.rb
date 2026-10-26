# frozen_string_literal: true

require 'cgi'
require 'rexml/document'
require 'uri'
require 'weakref'
require_relative 'label_markup'

module Lich
  module Common
    module ScriptScope
      module Gtk
        # Marker for supported legacy containers. Iteration exposes a snapshot
        # of actual children; sensitivity is inherited through the shared component tree.
        module Container
          # Iterates a child snapshot through the ordinary container protocol.
          # @param block [Proc] GTK callback invoked with the signal arguments
          # @return [Enumerator, Array<Widget>] enumerator without a block, otherwise the child snapshot
          def each(&block) = children.each(&block)
        end

        CrossingEvent = Data.define(:event_type)

        # Shadow objects preserve synchronous reads and GTK mutator chaining.
        # Only materialized widgets own opaque port handles. Destruction removes
        # the browser surface while leaving Ruby metadata readable, as MyFletch
        # reads and normalizes its entries after destroying the setup window.
        class Widget
          SIGNAL_ID_MUTEX = Mutex.new
          private_constant :SIGNAL_ID_MUTEX

          # IDs are unique across widgets; a foreign widget's ID cannot remove
          # a coincidentally numbered local connection. They never cross the wire.
          # @return [Integer] unique disconnectable connection identity
          # @api private
          def self.next_signal_id
            SIGNAL_ID_MUTEX.synchronize { @signal_sequence = (@signal_sequence || 0) + 1 }
          end
          private_class_method :next_signal_id

          attr_reader :session, :parent
          attr_writer :placement

          # Creates script-owned shadow state without allocating a browser control.
          def initialize
            @session = Gtk.session
            @props = {}
            @children = []
            @signals = {}
            @signal_connections = {}
            @committed = {}
            @handle = nil
            @destroyed = false
          end

          # Refuses unsupported widget operations with source attribution.
          # @param name [String, Symbol] supported GTK operation, property or signal spelling
          # @return [void] result is not part of the supported script contract
          # @raise [UnsupportedOperation] always
          def method_missing(name, *, **, &)
            session.refuse(self, name)
          end

          # GTK returns a collection snapshot. A source may remove each child
          # while iterating that snapshot without skipping alternating entries.
          # @return [Array<Widget>] independent child collection snapshot
          def children = @children.dup

          # Retains GTK's widget name as script metadata, distinct from Builder
          # identity. Names never become DOM IDs, classes or CSS selectors.
          # @return [String] explicit name or the GTK class name
          def name = @widget_name || "Gtk#{self.class.name.to_s.split('::').last}"

          # Retains a bounded widget name and refreshes matching label styles.
          # @param value [String] bounded literal name, at most 512 characters
          # @return [Widget] self
          def set_name(value)
            session.refuse(self, :name=) unless value.is_a?(String) && value.length <= 512
            @widget_name = value.dup.freeze
            session.refresh_label_styles
            self
          end
          alias name= set_name

          # Uses the existing show/hide lifecycle for the property spelling.
          # @param value [Boolean] requested visibility
          # @return [void] result is not part of the supported script contract
          def visible=(value)
            session.refuse(self, :visible=) unless [true, false].include?(value)
            value ? show : hide
          end

          # Detaches a child from this widget while retaining its shadow state and handle.
          # @param child [Widget] same-session child governed by this container
          # @return [Widget] self
          # @raise [UnsupportedOperation] unless this widget is its parent
          def remove(child)
            session.refuse(self, :remove) if @tab_owner
            session.refuse(self, :remove) unless child.parent.equal?(self)
            session.port.detach(@handle, child.materialize) if @handle
            @children.delete(child)
            child.parent = nil
            session.refresh_label_styles
            refresh_layout!
            self
          end

          # Does not advertise unsupported native widget methods through reflection.
          # @param args [Array<Object>] legacy arguments forwarded to the inherited operation
          # @return [Boolean]
          # @api private
          # @!visibility private
          def respond_to_missing?(*args)
            super
          end

          # Applies bounded generic-family typography to text and ordinary controls.
          # @param font [Pango::FontDescription] parsed family/size plus normal/bold weight
          # @return [Widget] self
          # @raise [UnsupportedOperation] for widgets without a text-style contract
          def override_font(font)
            valid = font.is_a?(Pango::FontDescription) && %i[text button text_input].include?(component_type)
            session.refuse(self, :override_font) unless valid
            font.properties.each { |property, value| write(property, value) }
            write(:emphasis, font.weight == :bold ? :strong : :normal)
          end

          # Legacy spelling dispatches through each control's typography mapping.
          # @param font [Pango::FontDescription] bounded generic-family typography
          # @return [Widget] self
          def modify_font(font) = override_font(font)

          # Returns the widget-local decoration facade without exposing DOM styling.
          # @return [StyleContext]
          def style_context
            session.style_operation(self, :style_context) do
              session.refuse(self, :style_context) if destroyed?
              @style_context ||= StyleContext.new(self)
            end
          end

          # Changes subtree alpha without hiding, disabling or reallocating it.
          # @param value [Numeric] finite opacity in 0..1
          # @return [Widget] self
          def set_opacity(value)
            session.style_operation(self, :opacity=) do
              valid = (value.is_a?(Integer) || value.is_a?(Float) && value.finite?) && value.between?(0, 1)
              session.refuse(self, :opacity=) unless valid && !destroyed? && %i[stack button text].include?(component_type)
              write(:opacity, value)
            end
            self
          end
          alias opacity= set_opacity

          # Reads authored subtree opacity without querying browser state.
          # @return [Numeric] retained alpha, defaulting to fully opaque
          def opacity = @props.fetch(:opacity, 1.0)

          # Appends a same-session child through the shared single-parent/cycle checks.
          # @param child [Widget] same-session child governed by this container
          # @return [Widget] self
          def add(child)
            insert_child(child, @children.length)
          end

          # GTK moves a negative or past-end position to the final child. This
          # also preserves Glade packing positions with omitted placeholder slots.
          # @param child [Widget] same-session child governed by this container
          # @param index [Integer] GTK child or page position; negative values use the operation default
          # @return [Widget] self
          def reorder_child(child, index)
            session.refuse(self, :reorder_child) unless child.parent.equal?(self) && index.is_a?(Integer)
            session.synchronize do
              @children.delete(child)
              index = @children.length if index.negative? || index > @children.length
              @children.insert(index, child)
              if @handle
                session.port.detach(@handle, child.materialize)
                session.port.attach(@handle, child.materialize, index)
              end
              refresh_layout!
            end
            self
          end

          # Validates ownership and placement before attaching one child.
          # @param child [Widget] same-session child governed by this container
          # @param index [Integer] GTK child or page position; negative values use the operation default
          # @param placement [Hash, nil] validated shared child placement, when required
          # @return [Widget] self
          # @api private
          def insert_child(child, index, placement: nil)
            session.refuse(self, :add) unless child.is_a?(Widget)
            session.refuse(self, :add) unless child.session.equal?(session)
            ancestor = self
            while ancestor
              session.refuse(self, :add) if ancestor.equal?(child)
              ancestor = ancestor.parent
            end
            # A widget has one parent and one rendered identity. betazzherb
            # packs the same row twice; retain it once and report the source
            # defect rather than duplicating inputs in the submission scope.
            if child.parent.equal?(self)
              session.source_warning(self, :add, 'child already packed; duplicate ignored')
              return self
            end
            session.refuse(self, :add) if child.parent
            if @handle
              if placement
                session.port.attach(@handle, child.materialize, index, placement: placement)
              else
                session.port.attach(@handle, child.materialize, index)
              end
            end
            child.parent = self
            @children.insert(index, child)
            session.refresh_label_styles
            refresh_layout!
            self
          end
          private :insert_child
        end
      end
    end
  end
end

# Keep the legacy entry path and definition order; boot loads later class extensions.
require_relative 'widgets/signals'
require_relative 'widgets/presentation'
require_relative 'widgets/lifecycle'
require_relative 'widgets/port'
require_relative 'widgets/window'
require_relative 'widgets/containers'
require_relative 'widgets/notebook'
require_relative 'widgets/labels'
require_relative 'widgets/entry'
require_relative 'widgets/buttons'
