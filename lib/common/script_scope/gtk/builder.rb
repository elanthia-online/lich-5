# frozen_string_literal: true

require 'rexml/document'
require_relative 'widgets_data'

module Lich
  module Common
    module ScriptScope
      module Gtk
        # Gtk::Builder: builds a shim widget tree from GtkBuilder XML (the
        # Glade files nine scripts embed as strings). Scripts subclass it,
        # call add_from_string, look objects up by id, iterate `objects`,
        # and wire XML-declared signals with connect_signals.
        #
        # The parser targets what those files use - see the census in
        # docs/webui-gtk-shim-plan.md - and logs anything else once.
        class Builder
          CLASSES = {
            'GtkWindow' => :Window, 'GtkDialog' => :Dialog,
            'GtkBox' => :Box, 'GtkHBox' => :HBox, 'GtkVBox' => :VBox,
            'GtkGrid' => :Grid, 'GtkTable' => :Table, 'GtkFrame' => :Frame,
            'GtkScrolledWindow' => :ScrolledWindow, 'GtkViewport' => :Viewport,
            'GtkNotebook' => :Notebook, 'GtkExpander' => :Expander, 'GtkEventBox' => :EventBox,
            'GtkLabel' => :Label, 'GtkEntry' => :Entry, 'GtkSearchEntry' => :SearchEntry,
            'GtkButton' => :Button, 'GtkToggleButton' => :ToggleButton,
            'GtkCheckButton' => :CheckButton, 'GtkRadioButton' => :RadioButton,
            'GtkSpinButton' => :SpinButton, 'GtkComboBoxText' => :ComboBoxText, 'GtkComboBox' => :ComboBox,
            'GtkTextView' => :TextView, 'GtkTextBuffer' => :TextBuffer,
            'GtkSeparator' => :Separator, 'GtkHSeparator' => :HSeparator, 'GtkVSeparator' => :VSeparator,
            'GtkTreeView' => :TreeView, 'GtkTreeViewColumn' => :TreeViewColumn,
            'GtkTreeSelection' => :TreeSelection, 'GtkListStore' => :ListStore, 'GtkTreeStore' => :TreeStore,
            'GtkCellRendererText' => :CellRendererText, 'GtkCellRendererToggle' => :CellRendererToggle,
            'GtkCellRendererCombo' => :CellRendererCombo, 'GtkAdjustment' => :Adjustment,
          }.freeze

          # Properties that reference another object by id.
          REFERENCE_PROPERTIES = %w[adjustment model buffer].freeze

          attr_reader :objects

          def initialize
            @objects = []
            @by_id = {}
            @signals = [] # [object, signal_name, handler_name]
            @pending_references = [] # [object, property, id]
          end

          def add_from_string(xml)
            document = REXML::Document.new(xml.to_s)
            interface = document.root
            raise ArgumentError, 'GtkBuilder XML must have an <interface> root' unless interface && interface.name == 'interface'

            interface.elements.each('object') { |element| build_object(element, nil, nil, nil) }
            resolve_references!
            self
          end

          def add_from_file(path)
            add_from_string(File.read(path))
          end

          def get_object(id)
            @by_id[id.to_s]
          end
          alias [] get_object

          # Wires every <signal> in the XML. With a block, yields the handler
          # name and expects a callable back (the scripts use
          # `method(handler)`); without one, looks the method up on self.
          # Handler arity is honored the way ruby-gnome does it.
          def connect_signals
            @signals.each do |(object, signal, handler_name)|
              callable = block_given? ? yield(handler_name) : method(handler_name)
              next unless callable.respond_to?(:call)

              object.signal_connect(signal) { |*args| Widget.call_handler(callable, args) }
            end
            self
          end

          def connect_signals_full(&block)
            connect_signals(&block)
          end

          private

          def build_object(element, parent, child_type, packing)
            gtk_class = element.attributes['class']
            klass_name = CLASSES[gtk_class]
            unless klass_name
              Gtk.log_unsupported('Gtk::Builder', "class #{gtk_class}")
              return nil
            end

            id = element.attributes['id']
            properties = element.elements.to_a('property').to_h { |p| [p.attributes['name'], p.text.to_s] }
            object = construct(klass_name, gtk_class, properties, element)
            return nil unless object

            register(object, id)
            apply_properties(object, properties, klass_name)
            element.elements.each('signal') do |signal|
              @signals << [object, signal.attributes['name'], signal.attributes['handler']]
            end
            build_children(object, element)
            attach_child(parent, object, child_type, packing, element) if parent
            object
          end

          def construct(klass_name, gtk_class, properties, element)
            klass = Gtk.const_get(klass_name)
            case klass_name
            when :Box
              klass.new(properties['orientation'] || 'horizontal', properties.fetch('spacing', 0).to_i)
            when :ListStore, :TreeStore
              types = element.elements.to_a('columns/column').map { |column| column.attributes['type'] }
              klass.new(*types)
            when :Adjustment
              klass.new(
                properties.fetch('value', 0).to_f, properties.fetch('lower', 0).to_f,
                properties.fetch('upper', 100).to_f, properties.fetch('step-increment', 1).to_f,
                properties.fetch('page-increment', 10).to_f, properties.fetch('page-size', 0).to_f
              )
            when :SpinButton
              klass.new(Adjustment.new(0.0, 0.0, 100.0, 1.0, 10.0, 0.0))
            when :TreeSelection
              nil # configured through the owning TreeView
            when :TreeViewColumn
              klass.new(properties['title'])
            when :Label
              klass.new(properties['label'])
            when :Frame, :Expander
              klass.new(properties['label'])
            when :Button, :ToggleButton, :CheckButton, :RadioButton
              klass.new(label: properties['label'].to_s)
            when :ComboBoxText, :ComboBox
              klass.new(entry: Gtk.builder_value(properties.fetch('has-entry', 'False')))
            when :Separator
              klass.new(properties['orientation'] || 'horizontal')
            when :Window
              klass.new(properties['title'])
            else
              klass.new
            end
          rescue StandardError => error
            Gtk.log_unsupported('Gtk::Builder', "construct #{gtk_class}", note: error.message)
            nil
          end

          HANDLED_AT_CONSTRUCTION = {
            Box: %w[orientation spacing], ListStore: %w[], TreeStore: %w[],
            Adjustment: %w[value lower upper step-increment page-increment page-size],
            TreeViewColumn: %w[title], Label: %w[label], Frame: %w[label], Expander: %w[label],
            Button: %w[label], ToggleButton: %w[label], CheckButton: %w[label], RadioButton: %w[label],
            ComboBoxText: %w[has-entry], ComboBox: %w[has-entry], Separator: %w[orientation], Window: %w[title],
          }.freeze

          # Properties whose meaning depends on children built later (a
          # combo's active index needs its <items> first).
          DEFERRED_PROPERTIES = { ComboBox => %w[active active-id] }.freeze

          def apply_properties(object, properties, klass_name)
            handled = HANDLED_AT_CONSTRUCTION.fetch(klass_name, [])
            deferred = DEFERRED_PROPERTIES.find { |klass, _names| object.is_a?(klass) }&.last || []
            default_size = {}
            properties.each do |name, value|
              next if handled.include?(name)

              if REFERENCE_PROPERTIES.include?(name)
                @pending_references << [object, name, value]
              elsif deferred.include?(name)
                (@deferred ||= []) << [object, name, value]
              elsif %w[default-width default-height].include?(name) && object.is_a?(Window)
                default_size[name] = value.to_i
              elsif name == 'visible'
                object.visible = Gtk.builder_value(value) if object.respond_to?(:visible=)
              else
                object.apply_builder_property(name, value) if object.respond_to?(:apply_builder_property)
              end
            end
            return if default_size.empty?

            object.set_default_size(default_size.fetch('default-width', -1), default_size.fetch('default-height', -1))
          end

          def apply_deferred_properties(object)
            return unless @deferred

            mine, @deferred = @deferred.partition { |(target, _name, _value)| target.equal?(object) }
            mine.each { |(target, name, value)| target.apply_builder_property(name, value) }
          end

          def build_children(object, element)
            previous_page = nil
            element.elements.each('child') do |child|
              child_type = child.attributes['type']
              internal = child.attributes['internal-child']
              child_object_element = child.elements['object']
              next unless child_object_element

              packing_element = child.elements['packing']
              packing = packing_element ? packing_element.elements.to_a('property').to_h { |p| [p.attributes['name'], p.text.to_s] } : {}
              if internal == 'selection' && object.is_a?(TreeView)
                props = child_object_element.elements.to_a('property').to_h { |p| [p.attributes['name'], p.text.to_s] }
                object.selection.mode = props['mode'] if props['mode']
                register(object.selection, child_object_element.attributes['id'])
                next
              end
              if internal == 'entry' && object.is_a?(ComboBox)
                entry = build_object(child_object_element, nil, nil, nil)
                object.entry_child = entry if entry
                next
              end
              if child_type == 'tab' && object.is_a?(Notebook)
                label = build_object(child_object_element, nil, nil, nil)
                object.set_tab_label(previous_page, label) if previous_page && label
                next
              end
              built = build_object(child_object_element, object, child_type, packing)
              previous_page = built if object.is_a?(Notebook) && child_type.nil? && built
            end
            build_items(object, element) if object.is_a?(ComboBox)
            build_column_attributes(object, element) if object.is_a?(TreeViewColumn)
            apply_deferred_properties(object)
          end

          def build_items(combo, element)
            element.elements.each('items/item') do |item|
              id = item.attributes['id']
              text = item.text.to_s
              id ? combo.append(id, text) : combo.append_text(text)
            end
          end

          def build_column_attributes(column, element)
            element.elements.each('child/attributes/attribute') do |attribute|
              column.add_attribute(nil, attribute.attributes['name'], attribute.text.to_i)
            end
          end

          def attach_child(parent, child, child_type, packing, _element)
            case parent
            when Frame
              child_type == 'label' ? parent.set_label_widget(child) : parent.add(child)
            when Expander
              child_type == 'label' ? parent.set_label_widget(child) : parent.add(child)
            when Grid
              parent.attach(
                child, packing.fetch('left-attach', 0).to_i, packing.fetch('top-attach', 0).to_i,
                packing.fetch('width', 1).to_i, packing.fetch('height', 1).to_i
              )
            when Table
              left = packing.fetch('left-attach', 0).to_i
              top = packing.fetch('top-attach', 0).to_i
              parent.attach(child, left, packing.fetch('right-attach', left + 1).to_i, top, packing.fetch('bottom-attach', top + 1).to_i)
            when Box
              options = {
                expand: Gtk.builder_value(packing.fetch('expand', 'False')),
                fill: Gtk.builder_value(packing.fetch('fill', 'True')),
                padding: packing.fetch('padding', 0).to_i,
              }
              packing['pack-type'] == 'end' ? parent.pack_end(child, **options) : parent.pack_start(child, **options)
              position = packing['position']
              parent.reorder_child(child, position.to_i) if position && !parent.children.empty?
            when Notebook
              parent.append_page(child)
            when TreeView
              parent.append_column(child) if child.is_a?(TreeViewColumn)
            when TreeViewColumn
              parent.pack_start(child) if child.is_a?(CellRenderer)
            when Container
              parent.add(child)
            else
              Gtk.log_unsupported('Gtk::Builder', "child of #{parent.class.name.split('::').last}")
            end
          end

          def register(object, id)
            @objects << object
            return unless id && !id.empty?

            object.builder_name = id if object.respond_to?(:builder_name=)
            @by_id[id] = object
          end

          def resolve_references!
            @pending_references.each do |(object, property, id)|
              target = @by_id[id]
              next Gtk.log_unsupported('Gtk::Builder', "reference #{property}=#{id}", note: 'unknown id') unless target

              setter = "#{property}="
              object.public_send(setter, target) if object.respond_to?(setter)
            end
            @pending_references.clear
          end
        end
      end
    end
  end
end
