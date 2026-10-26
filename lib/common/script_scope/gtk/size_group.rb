# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        module SizeGroupMode
          HORIZONTAL = :horizontal

          # @raise [UnsupportedOperation] for unimplemented native sizing modes
          def self.const_missing(name) = Gtk.session.refuse(self, name)
        end

        # Horizontal requisitions share page-local browser measurements, not guessed text widths.
        # Membership is owner-bound, limited to eight groups per widget and 1024 live members.
        class SizeGroup
          attr_reader :session, :key

          # @param mode [Symbol] only :horizontal is implemented
          def initialize(mode)
            @session = Gtk.session
            session.refuse(self, :new) unless mode == :horizontal
            session.style_operation(self, :new) do
              sequence = session.instance_variable_get(:@size_group_sequence).to_i + 1
              session.refuse(self, :new) if sequence > 512
              session.instance_variable_set(:@size_group_sequence, sequence)
              @key = "sizegroup-#{sequence}".freeze
              @widgets = []
            end
          end

          # Adds one live same-owner member; repeats preserve existing identity and membership.
          # @return [SizeGroup] self
          def add_widget(widget)
            session.style_operation(self, :add_widget) do
              valid = widget.is_a?(Widget) && !widget.is_a?(Window) && widget.session.equal?(session) && !widget.destroyed?
              session.refuse(self, :add_widget) unless valid
              next if @widgets.include?(widget)
              @widgets.reject!(&:destroyed?)
              session.refuse(self, :add_widget) if @widgets.size >= 1024
              validate_roots(widget)
              widget.send(:attach_width_group, self)
              @widgets << widget
            end
            self
          end

          # Removes only this group's contribution without changing authored widget dimensions.
          # @return [SizeGroup] self
          def remove_widget(widget)
            session.style_operation(self, :remove_widget) do
              session.refuse(self, :remove_widget) unless widget.is_a?(Widget) && widget.session.equal?(session)
              if @widgets.include?(widget)
                widget.send(:detach_width_group, self)
                @widgets.delete(widget)
              end
            end
            self
          end

          # @return [Array<Widget>] independent snapshot of surviving members
          def widgets
            session.style_operation(self, :widgets) { @widgets.reject(&:destroyed?) }
          end
          alias get_widgets widgets

          # Page-local sizing cannot coordinate separate native windows or owners.
          # @api private
          def validate_projection(widget)
            session.style_operation(self, :add_widget) { validate_roots(widget) }
          end

          # @raise [UnsupportedOperation] for unsupported native group APIs
          def method_missing(name, *, **, &) = session.refuse(self, name)

          private

          # Refuses membership spanning multiple windows before publishing group identity.
          # @raise [UnsupportedOperation] when live members belong to distinct windows
          def validate_roots(widget)
            roots = (@widgets + [widget]).reject(&:destroyed?).map(&:toplevel).grep(Window).uniq
            session.refuse(self, :add_widget) if roots.size > 1
          end
        end

        # Shadow membership reaches every component type, including controls with custom props.
        module WidthGroupWidget
          # Validates group projection before delegating to the widget's materializer.
          # @return [Lich::WebUI::Adapter::Handle] existing or newly created control handle
          def materialize
            @width_groups&.each { |group| group.validate_projection(self) }
            super
          end

          protected

          # Publishes the new group list before accepting shadow membership.
          # @param group [SizeGroup] validated same-session sizing group
          # @raise [UnsupportedOperation] when this widget would exceed eight groups
          def attach_width_group(group)
            groups = (@width_groups || []) + [group]
            session.refuse(self, :size_group) if groups.size > 8
            write(:width_groups, groups.map(&:key))
            @width_groups = groups
          end

          # Removes one group's measurement contribution while retaining other memberships.
          # @param group [SizeGroup] group being removed
          def detach_width_group(group)
            groups = (@width_groups || []) - [group]
            write(:width_groups, groups.map(&:key))
            @width_groups = groups
          end
        end
        Widget.prepend(WidthGroupWidget)
      end
    end
  end
end
