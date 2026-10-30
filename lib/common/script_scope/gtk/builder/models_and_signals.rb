# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        class Builder
          private

          # Applies values that require completed children/models, then records signals.
          # @param element [REXML::Element] XML declaration providing source attribution
          # @return [void] result is not part of the supported script contract
          # @api private
          def finish(element)
            object = @built.fetch(element)
            props = properties(element)
            if object.is_a?(ComboBox)
              element.elements.each('items/item') do |item|
                text = item.texts.map(&:value).join
                item.attributes['id'] ? object.append(item.attributes['id'], text) : object.append_text(text)
              end
              %w[entry-text-column active].each do |name|
                next unless props.key?(name)
                method, kind = PROPERTIES[ComboBox].fetch(name)
                object.public_send(method, convert(props[name], kind, element, name))
              end
            elsif element.elements['items']
              fail_at(element, 'items', 'items require a combo')
            end
            element.elements.each('attributes/attribute') do |attribute|
              @location = [element, 'attributes']
              fail_at(element, 'attributes', 'text attributes require a Label') unless object.is_a?(Label)
              name, value = [attribute.attributes['name'], attribute.attributes['value']]
              case name
              when 'style'
                fail_at(element, 'attributes', 'unsupported text attribute') unless %w[normal italic].include?(value)
                object.send(:write, :font_style, value)
              when 'foreground'
                # Pango's 16-bit RGB literals become bounded numeric channels;
                # source attributes are never passed through as arbitrary CSS.
                color = Color.parse(value)
                fail_at(element, 'attributes', 'unsupported foreground color') unless color
                object.send(:write, :foreground, color)
              else fail_at(element, 'attributes', 'unsupported text attribute')
              end
            end
            element.elements.each('signal') { |signal| prepare_signal(object, element, signal) }
          end

          # Store data exists before a forward-referencing combo applies its active index.
          # @param element [REXML::Element] XML declaration providing source attribution
          # @return [void] result is not part of the supported script contract
          # @api private
          def load_model(element)
            object = @built.fetch(element)
            @location = [element, 'model data']
            if object.is_a?(ListStore)
              element.elements.each('data/row') { |row| populate(object, row) }
            elsif element.elements['data'] || element.elements['columns']
              fail_at(element, 'model data', 'columns/data require a store')
            end
          end

          # Loads typed model rows recursively while preserving parentage and XML order.
          # @param model [ListStore, TreeStore] same-session backing model
          # @param element [REXML::Element] XML declaration providing source attribution
          # @param parent [Object] container owning the child declaration
          # @return [void] result is not part of the supported script contract
          # @api private
          def populate(model, element, parent = nil)
            row = model.is_a?(TreeStore) ? model.append(parent) : model.append
            seen = []
            element.elements.each('col') do |column|
              index = convert(column.attributes['id'].to_s, :integer, element, 'column id')
              fail_at(element, 'column id', 'duplicate cell') if seen.include?(index)
              seen << index
              kind = { String => :text, Integer => :integer, Float => :number, TrueClass => :boolean }.fetch(model.get_column_type(index))
              row[index] = convert(column.texts.map(&:value).join, kind, element, 'cell')
            end
            element.elements.each('row') do |child|
              fail_at(element, 'row', 'nested rows require TreeStore') unless model.is_a?(TreeStore)
              populate(model, child, row)
            end
          end

          # Validates a declared handler and retains it without connecting user callbacks.
          # @param object [Object] constructed shim object to configure or validate
          # @param element [REXML::Element] XML declaration providing source attribution
          # @param signal [String, nil] optional GTK signal spelling used to filter handlers
          # @return [void] result is not part of the supported script contract
          # @api private
          def prepare_signal(object, element, signal)
            name = signal.attributes['name'].to_s.tr('-', '_')
            handler = signal.attributes['handler'].to_s
            %w[after swapped].each do |flag|
              fail_at(element, "signal:#{name}", "#{flag}=true is unsupported") if convert(signal.attributes[flag] || 'false', :boolean, element, flag)
            end
            supported = if object.is_a?(ComboEntry) then ['changed']
                        elsif object.is_a?(Widget)
                          object.send(:signal_map).keys.map { |key| key.tr('-', '_') } + ['destroy']
                        elsif object.is_a?(Adjustment) then %w[changed value_changed]
                        elsif object.is_a?(TreeSelection) then ['changed']
                        elsif object.is_a?(CellRendererCombo) then %w[edited changed]
                        elsif object.is_a?(CellRendererText) then [object.signal_name]
                        else []
                        end
            fail_at(element, "signal:#{name}", 'unsupported signal or invalid handler name') unless supported.include?(name) && handler.match?(/\A[a-zA-Z_]\w*[!?]?\z/)
            @pending_signals << [object, name, handler, element]
          end

          # Validates a completed widget projection before the document can publish.
          # @param object [Object] constructed shim object to configure or validate
          # @return [void] result is not part of the supported script contract
          # @api private
          def validate_object(object)
            return unless object.is_a?(Widget) && !object.is_a?(ComboEntry)
            element = @object_elements.fetch(object)
            @location = [element, 'component properties']
            Lich::WebUI::Validator.new.validate_component!(object.send(:component_type), object.send(:component_props), owner: 'shim', page_id: nil, cid: nil)
          end
        end
      end
    end
  end
end
