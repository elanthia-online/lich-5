# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # Rich rows reuse ordinary stacks; only nonselecting lists are supported.
        class ListBox < Box
          # Creates a vertical list whose child controls own their interactions.
          def initialize
            super(:vertical, 0)
          end

          # @return [Symbol] the supported nonselecting mode
          def selection_mode = :none

          # @param value [Symbol] only :none; native row selection is unsupported
          def selection_mode=(value)
            session.refuse(self, :selection_mode=) unless value == :none && !destroyed?
          end
          alias set_selection_mode selection_mode=

          protected

          # All inherited packing paths enforce explicit row identity too.
          # @param child [ListBoxRow] live same-owner row
          # @return [ListBox] self
          def insert_child(child, index, placement: nil)
            session.refuse(self, :add) unless child.is_a?(ListBoxRow) && !child.destroyed? && !destroyed?
            super
          end
        end

        # One content child, with independent embedded controls and no row actions.
        class ListBoxRow < Widget
          include Container

          # @return [Boolean] rows do not activate or select through this facade
          def activatable? = false
          alias activatable activatable?
          alias selectable? activatable?
          alias selectable activatable?

          %i[activatable selectable].each do |property|
            define_method("#{property}=") do |value|
              session.refuse(self, "#{property}=") unless value == false && !destroyed?
            end
            alias_method "set_#{property}", "#{property}="
          end

          # @param child [Widget] sole content child, or the existing child again
          # @return [ListBoxRow] self
          def add(child)
            session.refuse(self, :add) if destroyed? || child.is_a?(Widget) && child.destroyed?
            session.refuse(self, :add) unless children.empty? || children.include?(child)
            super
          end

          protected

          def component_type = :stack
        end
      end
    end
  end
end
