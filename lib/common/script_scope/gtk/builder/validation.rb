# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        class Builder
          private

          # Reports all unmapped properties in one preflight, before allocating objects.
          # This is not an exhaustive behavior audit: constructor/value failures are
          # subsequently reported at their actual failing phase.
          # @return [void] result is not part of the supported script contract
          # @api private
          def check_properties
            issues = []
            @elements.each do |element|
              klass = CLASSES.fetch(element.attributes['class'])
              allowed = CONSTRUCTOR_PROPERTIES.fetch(element.attributes['class'], [])
              allowed += COMMON.keys if klass <= Widget
              PROPERTIES.each { |type, entries| allowed += entries.keys if klass <= type }
              properties(element).each_key do |name|
                next if allowed.include?(name)
                issues << issue(element, name, 'unsupported property; requires an explicit mapping')
              end
            end
            return if issues.empty?
            first = issues.first
            fail_at(@elements.find { |element| (element.attributes['id'] || '(anonymous)') == first[:object] && element.attributes['class'] == first[:xml_class] },
                    first[:property], "#{first[:reason]} (#{issues.length} unmapped declarations)", issues: issues)
          end

          # Rejects unsupported XML syntax instead of silently ignoring unvisited nodes.
          # @param element [REXML::Element] XML declaration providing source attribution
          # @param depth [Integer] current bounded XML nesting depth
          # @return [void] result is not part of the supported script contract
          # @api private
          def check_elements(element, depth = 0)
            fail_at(element, 'nesting', 'XML depth limit exceeded') if depth > MAX_DEPTH
            shape = ELEMENTS[element.name]
            fail_at(element, element.name, 'unsupported XML element') unless shape
            element.attributes.each_attribute do |attribute|
              fail_at(element, attribute.name, 'unsupported XML attribute') unless shape.last.include?(attribute.name)
            end
            if element.name == 'requires'
              valid = element.attributes['lib'] == 'gtk+' && element.attributes['version'].to_s.match?(/\A3\.(?:[0-9]|1[0-9]|2[0-4])\z/)
              fail_at(element, 'requires', 'only GTK 3 through 3.24 is supported') unless valid
            end
            element.elements.each do |child|
              fail_at(child, child.name, "not supported inside #{element.name}") unless shape.first.include?(child.name)
              check_elements(child, depth + 1)
            end
            if element.name == 'object'
              %w[columns data items attributes].each do |name|
                fail_at(element, name, 'duplicate section') if element.elements.to_a(name).length > 1
              end
            elsif element.name == 'child'
              %w[packing attributes].each do |name|
                fail_at(element, name, 'duplicate section') if element.elements.to_a(name).length > 1
              end
            end
            if !%w[property col item attribute].include?(element.name) && element.texts.any? { |text| !text.value.strip.empty? }
              fail_at(element, 'text', 'unexpected text outside a value element')
            end
          end

          # Preserves all text characters; only explicitly numeric/boolean properties coerce.
          # @param value [String] unconverted XML property text
          # @param kind [Symbol] conversion token from the property catalog
          # @param element [REXML::Element] XML declaration providing source attribution
          # @param name [String] XML property name used for conversion and diagnostics
          # @return [String, Numeric, Boolean, Symbol] value converted by its declared mapping
          # @api private
          def convert(value, kind, element, name)
            @location = [element, name]
            case kind
            when :text then value
            when :symbol then value.strip.tr('-', '_').to_sym
            when :integer then Integer(value, 10)
            when :number
              number = Float(value)
              fail_at(element, name, 'number must be finite') unless number.finite?
              number
            when :boolean
              case value.strip.downcase
              when 'true', 'yes', '1' then true
              when 'false', 'no', '0' then false
              else fail_at(element, name, 'expected boolean')
              end
            end
          rescue ArgumentError
            fail_at(element, name, "expected #{kind}")
          end

          # Collects XML property text while refusing duplicate declarations.
          # @param element [REXML::Element] XML declaration providing source attribution
          # @return [Hash{String => String}] property names and unconverted XML text
          # @api private
          def properties(element)
            element.elements.to_a('property').each_with_object({}) do |property, result|
              name = property.attributes['name'].to_s.tr('_', '-')
              fail_at(element, name, 'empty or duplicate property') if name.empty? || result.key?(name)
              result[name] = property.texts.map(&:value).join
            end
          end
        end
      end
    end
  end
end
