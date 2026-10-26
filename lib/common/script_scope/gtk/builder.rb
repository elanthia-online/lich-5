# frozen_string_literal: true

require 'rexml/document'

module Lich
  module Common
    module ScriptScope
      module Gtk
        # Stable XML identity for Builder objects; it is unrelated to CSS widget names.
        module BuilderIdentity
          # @return [String, nil] declared ID, generated anonymous ID, or nil outside Builder
          attr_reader :builder_name
        end

        [Widget, ModelObject, Adjustment, TextBuffer].each { |type| type.include(BuilderIdentity) }

        # A refused document reports the XML location in addition to script attribution.
        class BuilderError < UnsupportedOperation
          # @return [Array<Hash>] detected XML blockers, excluding property text values
          attr_reader :issues

          # Retains immutable XML blockers alongside the attributed refusal message.
          # @param message [String] attributed refusal message
          # @param issues [Array<Hash>] value-free XML blockers retained immutably
          def initialize(message, issues: [])
            super(message)
            @issues = issues.map(&:freeze).freeze
          end

          # Bounded structural context for Gtk.queue logging; never includes XML values.
          # @return [String] first blocker and total detected declaration count
          def diagnostic
            first = issues.first || {}
            fields = %i[object xml_class property reason].map do |key|
              "#{key}=#{first[key].to_s.gsub(/[^a-zA-Z0-9_.:\- =;()]/, '?')[0, 160]}"
            end
            "#{fields.join(' ')} blockers=#{issues.length}"
          end
        end

        # Bounded GtkBuilder translation into existing script-owned shim objects.
        # Each load constructs an isolated graph. No handlers or windows are exposed
        # until references, properties, child placement and component schemas validate.
        class Builder < ModelObject
          MAX_BYTES = 1_048_576
          MAX_OBJECTS = 2048
          MAX_DEPTH = 64
          # Ordered class/property/XML declarations used by every Builder phase.
          require_relative 'builder/catalog'

          # Creates a Builder owned by the current script, including subclass instances.
          def initialize
            super
            @objects, @by_id, @signals = [], {}, []
          end

          # Returns a document-order snapshot without exposing the Builder collection.
          # @return [Array<Object>] document-order snapshot, including anonymous objects
          def objects = @objects.dup

          # Resolves a declared XML identity or refuses the missing lookup.
          # @param id [String, Symbol] XML identifier
          # @return [Object] the original object for a declared identifier
          # @raise [BuilderError] undeclared identifier; unlike GTK, lookup never returns nil
          def get_object(id)
            # Refuse at lookup so Lich's NilClass extension cannot silently swallow
            # a subsequent widget operation. Optional lookups must inspect objects.
            session.synchronize do
              @by_id.fetch(id.to_s) do
                fail_at(nil, 'get_object', 'undeclared object identifier; update the script to native WebUI', object_id: id.to_s)
              end
            end
          end
          alias [] get_object

          # Parses bounded local XML without evaluating Ruby or resolving external entities.
          # Failed additions preserve previously loaded IDs and detach all new observers.
          # @param xml [String] complete interface document
          # @return [Builder] self
          # @raise [BuilderError] unsupported or invalid XML, with object/property context
          def add_from_string(xml)
            session.synchronize do
              @location = nil
              fail_at(nil, 'document', 'expected bounded XML text') unless xml.is_a?(String) && xml.bytesize <= MAX_BYTES
              fail_at(nil, 'document', 'DTD and entity declarations are unsupported') if xml.match?(/<!\s*(?:DOCTYPE|ENTITY)\b/i)
              document = REXML::Document.new(xml)
              fail_at(nil, 'document', 'root must be interface') unless document.root&.name == 'interface'
              check_elements(document.root)
              @elements = REXML::XPath.match(document, '//object')
              fail_at(nil, 'objects', 'object limit exceeded') if @objects.length + @elements.length > MAX_OBJECTS
              @pending_ids, @built, @building, @created, @pending_signals, @visible_windows = {}, {}, {}, [], [], []
              @object_elements = {}.compare_by_identity
              @positions = @elements.each_with_index.to_h
              @elements.each do |element|
                fail_at(element, 'class', 'unsupported class') unless CLASSES.key?(element.attributes['class'])
                id = element.attributes['id']
                next unless id
                fail_at(element, 'id', 'empty or duplicate identifier') if id.empty? || @by_id.key?(id) || @pending_ids.key?(id)
                @pending_ids[id] = element
              end
              check_properties
              @elements.each { |element| build(element) }
              @elements.each { |element| load_model(element) }
              @elements.each { |element| bind_model(element) }
              @elements.reverse_each { |element| compose(element) }
              @elements.each { |element| finish(element) }
              @created.each { |object| validate_object(object) }
              @visible_windows.each(&:show)
              @objects.concat(@elements.map { |element| @built.fetch(element) })
              @pending_ids.each { |id, element| @by_id[id] = @built.fetch(element) }
              @signals.concat(@pending_signals)
              self
            rescue BuilderError
              discard_pending
              raise
            rescue REXML::ParseException
              discard_pending
              fail_at(nil, 'document', 'malformed XML')
            rescue StandardError => error
              discard_pending
              detail = error.is_a?(UnsupportedOperation) ? error.message[/operation=([^ ]+)/, 1] : error.class.name.split('::').last
              detail += " field=#{error.field}" if error.is_a?(Lich::WebUI::Error) && error.field
              fail_at(@location&.first, @location&.last || 'document', "rejected by shim: #{detail}")
            ensure
              @elements = @pending_ids = @built = @building = @created = @pending_signals = @visible_windows = nil
              @positions = @object_elements = nil
            end
          end

          # Reads a local file using the same bounded, transactional parser.
          # @param path [String] local XML filename
          # @return [Builder] self
          def add_from_file(path)
            fail_at(nil, 'file', 'expected local filename') unless path.is_a?(String) && !path.include?("\0")
            xml = File.open(path, 'rb') { |file| file.read(MAX_BYTES + 1) }
            add_from_string(xml)
          rescue SystemCallError, IOError
            fail_at(nil, 'file', 'cannot read local XML file')
          end

          # Resolves every handler before connecting any; repeated calls connect only new signals.
          # Fixed-arity methods receive the supported prefix of emitted GTK arguments.
          # Handler return values (including close vetoes) and exceptions are preserved.
          # @yieldparam name [String] declared handler name
          # @yieldreturn [Method, Proc] callback; without a block, resolve on this Builder
          # @return [Builder] self
          def connect_signals
            session.synchronize do
              connections = @signals.map do |object, name, handler, element|
                callable = block_given? ? yield(handler) : method(handler)
                fail_at(element, "signal:#{name}", 'handler must be a Method or Proc') unless callable.is_a?(Method) || callable.is_a?(Proc)
                [object, name, callable]
              rescue NameError
                fail_at(element, "signal:#{name}", "missing handler #{handler}")
              end
              connections.each do |object, name, callable|
                object.signal_connect(name) do |*args|
                  callable.arity >= 0 ? callable.call(*args.take(callable.arity)) : callable.call(*args)
                end
              end
              @signals.clear
              self
            end
          end

          private

          # Keep translation phases on this receiver; each family declares private helpers.
          require_relative 'builder/validation'
          require_relative 'builder/construction'
          require_relative 'builder/composition'
          require_relative 'builder/models_and_signals'

          # No script handlers have been connected on rejected graphs, so teardown cannot
          # invoke user code. Every widget is visited, including unattached label objects.
          # @return [void] result is not part of the supported script contract
          # @api private
          def discard_pending
            @created&.reverse_each do |object|
              session.cleanup(object) { object.destroy } if object.is_a?(Widget) && !object.is_a?(ComboEntry)
              object.release if object.is_a?(TreeViewColumn)
            end
          end

          # Builds value-free diagnostic context from the nearest XML object.
          # @param element [REXML::Element, nil] XML location, or nil for a document-level refusal
          # @param operation [String] XML property or phase being refused
          # @param reason [String] value-free explanation of the refusal
          # @return [Hash] value-free XML location and refusal reason
          # @api private
          def issue(element, operation, reason)
            node = element
            node = node.parent while node.is_a?(REXML::Element) && node.name != 'object'
            { object: node.is_a?(REXML::Element) ? node.attributes['id'] || '(anonymous)' : '(document)',
              xml_class: node.is_a?(REXML::Element) ? node.attributes['class'] : nil, property: operation, reason: reason }
          end

          # Raises a Builder refusal with script and XML declaration attribution.
          # @param element [REXML::Element, nil] XML location, or nil for a document-level refusal
          # @param operation [String] XML property or phase being refused
          # @param reason [String] value-free explanation of the refusal
          # @param issues [Array<Hash>, nil] collected value-free XML blockers
          # @param object_id [String, nil] explicit XML identity for a lookup refusal
          # @return [void] always raises BuilderError
          # @api private
          def fail_at(element, operation, reason, issues: nil, object_id: nil)
            detail = issue(element, operation, reason)
            detail[:object] = object_id if object_id
            begin
              session.refuse(self, :Builder)
            rescue UnsupportedOperation => error
              message = "#{error.message} object=#{detail[:object]} xml_class=#{detail[:xml_class]} property=#{operation} reason=#{reason}"
              raise BuilderError.new(message, issues: issues || [detail])
            end
          end
        end
      end
    end
  end
end
