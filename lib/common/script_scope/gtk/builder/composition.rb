# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        class Builder
          private

          # Parent-specific child roles never fall back to an arbitrary empty container.
          # @param element [REXML::Element] XML declaration providing source attribution
          # @return [void] result is not part of the supported script contract
          # @api private
          def compose(element)
            object = @built.fetch(element)
            @location = [element, 'children']
            children = element.elements.to_a('child')
            pages = []
            children.each do |child|
              objects = child.elements.to_a('object')
              placeholders = child.elements.to_a('placeholder')
              valid = objects.length == 1 && placeholders.empty?
              valid ||= objects.empty? && placeholders.length == 1 && child.attributes.empty? && child.elements.size == 1
              fail_at(element, 'child', 'expected exactly one object or an unadorned placeholder') unless valid
              next if objects.empty?
              target = @built.fetch(objects.first)
              internal, role = child.attributes['internal-child'], child.attributes['type']
              if internal
                valid = internal == 'selection' && object.is_a?(TreeView) && target.equal?(object.selection)
                valid ||= internal == 'entry' && object.is_a?(ComboBox) && target.equal?(object.child)
                fail_at(element, 'internal-child', 'unsupported internal child') unless valid && !role && !child.elements['packing'] && !child.elements['attributes']
                next
              end
              if child.elements['attributes'] && !object.is_a?(TreeViewColumn) && !object.is_a?(ComboBox)
                fail_at(element, 'attributes', 'cell bindings require a renderer parent')
              end
              packing = child.elements['packing'] ? properties(child.elements['packing']) : {}
              if object.is_a?(Notebook)
                fail_at(element, 'packing', 'unsupported notebook packing') unless (packing.keys - %w[tab-fill position reorderable]).empty?
                if packing.key?('reorderable') && convert(packing['reorderable'], :boolean, element, 'reorderable')
                  # A sole page with no tab selector has no observable ordering gesture.
                  # Never use this exception to claim multi-page drag reordering.
                  count = element.get_elements('child').count { |item| !item.attributes['type'] && item.elements['object'] }
                  unless object.instance_variable_get(:@props)[:show_tabs] == false && count == 1
                    fail_at(element, 'reorderable', 'tab reordering requires a hidden single-page notebook')
                  end
                  session.degrade(:notebook_reorder, 'single hidden notebook page has no ordering gesture')
                end
                if packing.key?('position')
                  expected = object.children.length
                  fail_at(element, 'position', 'notebook position must match document order') unless convert(packing['position'], :integer, element, 'position') == expected
                end
                # Tabs do not expand in this bounded surface, so either fill request
                # has the same natural allocation. Expanded tab packing is still refused.
                convert(packing['tab-fill'], :boolean, element, 'tab-fill') if packing.key?('tab-fill')
                if role == 'tab'
                  fail_at(element, 'tab', 'tab requires a preceding page and plain label') unless pages.last && target.is_a?(Label)
                  fail_at(element, 'tab attributes', 'caption styling is not supported') if objects.first.elements['attributes']
                  object.append_page(pages.pop, target)
                else
                  fail_at(element, 'child', 'notebook pages require paired tab labels') unless role.nil? && pages.empty?
                  pages << target
                end
              elsif (object.is_a?(Frame) || object.is_a?(Expander)) && role == 'label'
                fail_at(element, 'label', 'frame label must be plain text') unless target.is_a?(Label)
                fail_at(element, 'packing', 'caption packing is unsupported') unless packing.empty?
                fail_at(element, 'label attributes', 'caption styling is not supported') if objects.first.elements['attributes']
                object.is_a?(Frame) ? object.set_label_widget(target) : object.set_label(target.text)
              else
                fail_at(element, 'child type', 'unsupported child role') if role
                attach(object, target, packing, child)
              end
            end
            fail_at(element, 'tab', 'page is missing a tab label') unless pages.empty?
          end

          # Maps legacy child packing into the appropriate existing container operation.
          # @param parent [Object] container owning the child declaration
          # @param child [Object] constructed child selected by the XML role
          # @param packing [Hash{String => String}] unconverted child packing properties
          # @param element [REXML::Element] XML declaration providing source attribution
          # @return [void] result is not part of the supported script contract
          # @api private
          def attach(parent, child, packing, element)
            @location = [element, 'packing']
            case parent
            when Grid, Table
              allowed = parent.instance_of?(Grid) ? %w[left-attach top-attach width height] : %w[left-attach right-attach top-attach bottom-attach]
              fail_at(element, 'packing', 'unsupported grid placement') unless (packing.keys - allowed).empty?
              values = allowed.map { |name| convert(packing.fetch(name, %w[left-attach top-attach].include?(name) ? '0' : '1'), :integer, element, name) }
              # Legacy attach initializes padding through margin; retain explicit XML margins.
              margin = child.instance_variable_get(:@props)[:margin]
              parent.attach(child, *values)
              child.send(:write, :margin, margin) unless margin.nil?
            when Box
              fail_at(element, 'packing', 'unsupported box placement') unless (packing.keys - %w[expand fill padding pack-type position]).empty?
              ending = packing.fetch('pack-type', 'start')
              fail_at(element, 'pack-type', 'expected start or end') unless %w[start end].include?(ending)
              parent.public_send(ending == 'end' ? :pack_end : :pack_start, child,
                                 expand: convert(packing.fetch('expand', 'true'), :boolean, element, 'expand'),
                                 fill: convert(packing.fetch('fill', 'true'), :boolean, element, 'fill'),
                                 padding: convert(packing.fetch('padding', '0'), :integer, element, 'padding'))
              parent.reorder_child(child, convert(packing['position'], :integer, element, 'position')) if packing.key?('position')
            when TreeView
              fail_at(element, 'child', 'expected a column without packing') unless child.is_a?(TreeViewColumn) && packing.empty?
              parent.append_column(child)
            when TreeViewColumn, ComboBox
              fail_at(element, 'child', 'expected one renderer without packing') unless child.is_a?(CellRendererText) && packing.empty?
              attributes = element.elements.to_a('attributes/attribute')
              fail_at(element, 'attributes', 'only one renderer binding is supported') if attributes.length > 1
              parent.pack_start(child, true)
              attributes.each do |attribute|
                fail_at(element, 'attributes', 'renderer binding uses text, not a value attribute') if attribute.attributes['value']
                parent.add_attribute(child, attribute.attributes['name'], convert(attribute.text.to_s, :integer, element, 'column'))
              end
            when Window, Frame, ScrolledWindow, Viewport, Expander
              fail_at(element, 'packing', 'packing unsupported on this container') unless packing.empty?
              parent.add(child)
            else fail_at(element, 'child', 'object cannot contain this child')
            end
          end
        end
      end
    end
  end
end
