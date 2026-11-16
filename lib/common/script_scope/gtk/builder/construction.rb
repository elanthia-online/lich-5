# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        class Builder
          private

          # References are load-local: no failed load can bind or mutate an older graph.
          # @param id [String] load-local referenced XML identity
          # @param element [REXML::Element] XML declaration providing source attribution
          # @param name [String] XML property name used for conversion and diagnostics
          # @return [Object] load-local referenced shim object
          # @api private
          def reference(id, element, name)
            target = @pending_ids[id]
            fail_at(element, name, "unresolved load-local reference #{id}") unless target
            build(target)
          end

          # Construction order follows dependencies, while objects preserves XML order.
          # @param element [REXML::Element] XML declaration providing source attribution
          # @return [Object] original object for this XML declaration
          # @api private
          def build(element)
            return @built[element] if @built.key?(element)
            fail_at(element, 'reference', 'cyclic construction dependency') if @building[element]
            @building[element] = true
            @location = [element, 'constructor']
            klass = CLASSES.fetch(element.attributes['class'])
            props = properties(element)
            object = construct(klass, props, element)
            fail_at(element, 'internal-child', 'internal object already declared') if @object_elements.key?(object)
            @created << object
            @object_elements[object] = element
            anonymous = "__anonymous_#{@objects.length + @positions.fetch(element) + 1}"
            anonymous += '_' while @pending_ids.key?(anonymous) || @by_id.key?(anonymous)
            object.instance_variable_set(:@builder_name, element.attributes['id'] || anonymous)
            @built[element] = object
            object.hide if object.is_a?(Widget) && !object.is_a?(Window) && !object.is_a?(ComboEntry)
            props.each { |name, value| apply_property(object, name, value, element) unless name == 'can-focus' }
            # Focus acceptance depends on the completed configuration (e.g. editable),
            # not the order Glade happened to serialize the properties.
            apply_property(object, 'can-focus', props['can-focus'], element) if props.key?('can-focus')
            @building.delete(element)
            object
          end

          # Consumes constructor properties and resolves load-local dependencies.
          # @param klass [Class] admitted shim constructor from the catalog
          # @param props [Hash{String => String}] unconverted properties consumed by the constructor
          # @param element [REXML::Element] XML declaration providing source attribution
          # @return [Object] constructed or reused internal shim object
          # @api private
          def construct(klass, props, element)
            case klass.name.split('::').last
            when 'Box' then klass.new(convert(props.delete('orientation') || 'horizontal', :symbol, element, 'orientation'), convert(props.delete('spacing') || '0', :integer, element, 'spacing'))
            when 'HBox', 'VBox' then klass.new(convert(props.delete('homogeneous') || 'false', :boolean, element, 'homogeneous'), convert(props.delete('spacing') || '0', :integer, element, 'spacing'))
            when 'Table' then klass.new(convert(props.delete('n-rows') || '1', :integer, element, 'n-rows'), convert(props.delete('n-columns') || '1', :integer, element, 'n-columns'))
            when 'Adjustment'
              values = %w[value lower upper step-increment page-increment page-size].map do |name|
                convert(props.delete(name) || '0', :number, element, name)
              end
              klass.new(*values)
            when 'SpinButton'
              adjustment = reference(props.delete('adjustment'), element, 'adjustment')
              klass.new(adjustment, convert(props.delete('climb-rate') || '0', :number, element, 'climb-rate'), convert(props.delete('digits') || '0', :integer, element, 'digits'))
            when 'ListStore', 'TreeStore'
              columns = element.elements.to_a('columns/column').map do |column|
                COLUMN_TYPES[column.attributes['type']] || fail_at(element, 'columns', 'unsupported scalar column type')
              end
              klass.new(*columns)
            when 'Frame' then klass.new(props.delete('label'))
            when 'Expander' then klass.new(props.delete('label') || '')
            when 'Button' then klass.new(label: props.delete('label') || '', use_underline: false)
            when 'ToggleButton', 'CheckButton' then klass.new(label: props.delete('label') || '')
            when 'ComboBox', 'ComboBoxText' then klass.new(entry: convert(props.delete('has-entry') || 'false', :boolean, element, 'has-entry'))
            when 'TextView' then klass.new(props.key?('buffer') ? reference(props.delete('buffer'), element, 'buffer') : nil)
            when 'Separator' then klass.new(convert(props.delete('orientation') || 'horizontal', :symbol, element, 'orientation'))
            when 'TreeSelection'
              child, parent = element.parent, element.parent.parent
              fail_at(element, 'internal-child', 'selection must belong to a TreeView') unless child.attributes['internal-child'] == 'selection' && parent.attributes['class'] == 'GtkTreeView'
              build(parent).selection
            when 'Entry'
              if element.parent.attributes['internal-child'] == 'entry'
                owner = build(element.parent.parent)
                fail_at(element, 'internal-child', 'entry requires an editable combo') unless owner.is_a?(ComboBox) && owner.child
                owner.child
              else
                klass.new
              end
            when 'RadioButton'
              group = props.key?('group') ? reference(props.delete('group'), element, 'group') : nil
              klass.new(group, label: props.delete('label') || '')
            else klass.new
            end
          end

          # Bind populated models before renderer mappings select a non-default column.
          # Construction references (buffers, adjustments and radio groups) resolve earlier.
          # @param element [REXML::Element] XML declaration providing source attribution
          # @return [void] result is not part of the supported script contract
          # @api private
          def bind_model(element)
            props = properties(element)
            return unless props.key?('model')
            @location = [element, 'model']
            @built.fetch(element).model = reference(props['model'], element, 'model')
          end

          # Selects the most specific property mapping and applies its typed conversion.
          # @param object [Object] constructed shim object to configure or validate
          # @param name [String] XML property name used for conversion and diagnostics
          # @param value [String] unconverted XML property text
          # @param element [REXML::Element] XML declaration providing source attribution
          # @return [void] result is not part of the supported script contract
          # @api private
          def apply_property(object, name, value, element)
            return if %w[model active entry-text-column].include?(name) && (object.is_a?(ComboBox) || name == 'model')
            @location = [element, name]
            mapping = PROPERTIES.filter_map { |type, entries| entries[name] if object.is_a?(type) }.last
            mapping ||= COMMON[name] if object.is_a?(Widget)
            fail_at(element, name, 'unsupported property; requires an explicit mapping') unless mapping
            method, kind = mapping
            converted = convert(value, kind, element, name)
            case method
            when :visible
              if object.is_a?(Window)
                @visible_windows << object if converted
              else
                converted ? object.show : object.hide
              end
            else object.public_send(method, converted)
            end
          end
        end
      end
    end
  end
end
