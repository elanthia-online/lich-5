# frozen_string_literal: true

require_relative 'session'

module Lich
  module Common
    module ScriptScope
      # How the shim says no. Every Gtk API a script reaches that the shim
      # does not implement lands here: an unknown method degrades and is
      # counted, an unknown widget class becomes an empty box and the
      # script is told, a value the contract cannot carry is clamped and
      # reported. The per-script ledger built from these is what the
      # supported-script list is written from, and it is summarised once
      # at session shutdown.
      module Gtk
        @unsupported = {}
        @dropped = {}

        class << self
          # A widget the contract refused. Unlike an unsupported method, this
          # costs a cell, so it is never deduplicated and it names the key so
          # the widget can be found in the rendered tree.
          def log_render_failure(child, error)
            label = child.respond_to?(:key) ? child.key : nil
            # Deduplicated per widget, not per class: every dropped cell is
            # reported once, but a commit loop does not flood the log.
            key = "#{child.short_class_name}##{label}"
            return if @dropped[key]

            @dropped[key] = true
            message = "webui-gtk-shim: dropped #{child.short_class_name}" + "#{" key=#{label}" if label} from its parent: #{error.message}"
            script = Session.current_script&.name
            message += " script=#{script}" if script
            Lich.log("warning: #{message}") if defined?(Lich) && Lich.respond_to?(:log)
          end

          # A value the contract cannot carry, reported once per class and
          # property. The shim's stated principle is to say what it cannot
          # honour rather than drop it quietly; a horizontal box past twelve
          # children, a grid past twenty-four columns and a margin past 512px
          # all silently lost the excess, which turns a script bug into a
          # rendering mystery. Deduped like the others so a commit loop does
          # not flood the log.
          def log_clamped(klass, property, requested, applied)
            script, first = record_unsupported("#{klass}.#{property}", "#{requested} exceeds what the contract carries; using #{applied}")
            return unless first

            message = "webui-gtk-shim: #{klass} #{property} #{requested} exceeds what the contract carries; " + "using #{applied}"
            message += " script=#{script}" if script
            Lich.log("warning: #{message}") if defined?(Lich) && Lich.respond_to?(:log)
          end

          def log_unsupported(klass, method, note: nil)
            key = "#{klass}##{method}"
            script, first = record_unsupported(key, note)
            return unless first

            message = "webui-gtk-shim: unsupported #{key}#{" (#{note})" if note}#{" script=#{script}" if script}"
            Lich.log("warning: #{message}") if defined?(Lich) && Lich.respond_to?(:log)
          end

          # The ledger of what scripts asked for and did not get, per script.
          # Deduplicated per script and API, not per API alone: a warning
          # logged once for the whole process said nothing about the second
          # script to hit the same gap, and "no warnings on the next run" was
          # taken for support. Every hit is counted, so a supported-script
          # manifest can be written from what actually happened rather than
          # from what loaded without error.
          #
          # @return [Hash{String => Hash{String => Hash}}] script name (or
          #   "(core)") => "Klass#method" => { count:, note: }
          def unsupported_report
            @unsupported.transform_values { |entries| entries.transform_values(&:dup) }
          end

          # One line per script that hit something, for the log at shutdown.
          def unsupported_summary(script)
            entries = @unsupported[script.to_s]
            return nil if entries.nil? || entries.empty?

            listed = entries.map { |api, entry| "#{api} (#{entry[:count]})" }.join(', ')
            "webui-gtk-shim: script=#{script} unsupported: #{listed}"
          end

          def reset_unsupported!
            @unsupported = {}
          end

          # Drops one script's entries. The ledger is keyed by script name
          # and lives for the process, so without this a script run, exited
          # and run again never got its first-hit notice the second time --
          # once per class per process, when the notice is meant per run.
          # A session calls this at shutdown, after it has logged the
          # summary line built from these entries.
          def forget_unsupported(script)
            @unsupported.delete(script.to_s)
            nil
          end

          # @return [Array(String, Boolean)] the script name and whether this
          #   is the first time that script hit this API
          def record_unsupported(key, note)
            script = Session.current_script&.name
            entries = (@unsupported[script.to_s] ||= {})
            entry = entries[key]
            if entry
              entry[:count] += 1
              [script, false]
            else
              entries[key] = { count: 1, note: note }
              [script, true]
            end
          end
          private :record_unsupported

          # A widget class the shim does not implement yet. It renders as an
          # empty box and accepts every call, so a script that builds one
          # loses that part of its window instead of dying at load. Scripts
          # reach these through Gtk.const_missing, never by name here.
          def unimplemented_widget(name)
            klass = Class.new(Container) do
              # GTK constructors take arguments and a stub's did not, so a
              # script building one got ArgumentError rather than the empty
              # box this is meant to degrade to -- Gtk::TargetEntry.new(target,
              # flags, info) killed ewaggle's whole window. Accept anything and
              # keep it, since a value object like TargetEntry is read back.
              def initialize(*args, **options)
                super()
                @stub_args = args
                @stub_options = options
              end

              attr_reader :stub_args, :stub_options

              def node_type
                :stack
              end

              def node_props
                { gap: 0 }
              end

              # Absolute-positioning containers (Layout, Fixed) take the
              # coordinates and ignore them; the child still renders.
              def put(child, _x = nil, _y = nil)
                add(child)
              end

              def move(_child, _x = nil, _y = nil)
                self
              end

              def set_size(_width = nil, _height = nil)
                self
              end
            end
            klass.define_singleton_method(:name) { "Gtk::#{name}" }
            # Marks this as generated. const_missing const_sets what it
            # returns, so a file loaded later that defines the real class
            # would reopen this stub rather than replace it; the marker lets
            # that file tell the two apart and discard the stub.
            klass.define_singleton_method(:webui_stub?) { true }
            klass
          end

          # Constants scripts reference that the shim has no implementation
          # for. A widget class degrades to an empty container; anything else
          # (an enum member, a flag) becomes the symbol it was named, since
          # scripts only ever pass those back into methods the shim ignores.
          # Either way the script keeps running and the gap is logged once.
          #
          # The two are not equally harmless, and used to log identically.
          # A missing enum member costs nothing: it is handed straight back
          # to a method the shim ignores. A missing *widget class* costs the
          # script everything it was going to put in that widget -- map's
          # Gtk::Image is the map, and it renders as an empty box with one
          # `warning:` line in a debug file, indistinguishable from the
          # harmless kind. A stubbed widget now says so where the player
          # will see it.
          # Names this shim defines in files loaded after this one. Stubbing
          # any of them would be silently permanent -- const_missing
          # const_sets its answer, so the stub shadows the real class for the
          # rest of the process and renders an empty box. Raising instead
          # says plainly that boot.rb has not finished, rather than papering
          # over it with something that looks like it works.
          #
          # Gtk::Image, Gtk::Layout, Gtk::DrawingArea and the Menu family are
          # deliberately absent: they are not shimmed (the scripts that used
          # them are rewritten natively), so a script naming one gets the
          # stubbed-widget notice and a ledger entry, not a shadowed class.
          OWN_DEFINITIONS = %i[].freeze

          def const_missing(name)
            if OWN_DEFINITIONS.include?(name)
              raise NameError, "Gtk::#{name} is defined by the shim but not loaded yet; " \
                               'require common/script_scope/gtk/boot before using it'
            end

            # A CamelCase name is *usually* a widget class, but not always: a
            # flags or enum namespace looks identical and is only ever read
            # through, never instantiated. Stubbing one as a widget class made
            # `Gtk::TargetFlags::SAME_APP` raise NameError -- a class has no
            # fallback for its own missing constants -- which killed ewaggle
            # at GUI construction, taking with it the row-activated handler it
            # registers a few lines later. Those degrade to a module whose
            # members answer as symbols, exactly as Gdk's fallback does.
            widget = class_name?(name) && !namespace_name?(name)
            value = if widget
                      unimplemented_widget(name)
                    elsif class_name?(name)
                      enum_namespace(name)
                    else
                      name.to_s.downcase.to_sym
                    end
            if widget
              report_stubbed_widget(name)
            else
              log_unsupported('Gtk', name, note: 'constant is not implemented')
            end
            const_set(name, value)
          end

          # A class name rather than an enum member. CamelCase is the usual
          # tell, but GTK also ships acronym-led names -- UIManager,
          # IMContext, RGBA -- and requiring a lowercase second letter sent
          # every one of them to the enum-member fallback, where they became
          # a bare symbol: `Gtk::UIManager.new` then raised NoMethodError on
          # Symbol, which is the uncaught crash this whole path exists to
          # prevent. An enum MEMBER is the thing being distinguished, and
          # those are SCREAMING_SNAKE_CASE, so the test is "not all caps".
          def class_name?(name)
            text = name.to_s
            text.match?(/\A[A-Z]/) && !text.match?(/\A[A-Z0-9_]+\z/)
          end

          # Names that read as a namespace of constants rather than a widget:
          # flags, enums and the target/selection vocabulary drag-and-drop is
          # described with. A script only ever reads a member out of one and
          # hands it back to a method the shim ignores.
          #
          # The list is empirical, not derived from GTK's naming: it was built
          # from what the 230-script corpus actually reaches (TargetFlags and
          # SAME_APP from ewaggle's drag-and-drop, and the like) and is meant
          # to be extended as scripts reach new names. The cost of a wrong
          # guess is asymmetric: a real widget class whose name happens to end
          # in one of these words would degrade to an inert module rather than
          # an empty box, so its constructor answers a symbol and the script
          # loses that part of its window more quietly than a stub would.
          NAMESPACE_SUFFIXES = /(?:Flags|Type|Types|Mode|Modes|Action|Actions|Mask|State|Direction|Priority|Options|Defaults|Style|Policy|Position|Order|Level|Role|Hint|Format|Class|Kind|Target)\z/

          def namespace_name?(name)
            name.to_s.match?(NAMESPACE_SUFFIXES)
          end

          # A stand-in for a constant namespace: any member answers as the
          # symbol it was named, the way Gdk's fallback does, so `A::B` never
          # raises and the value is inert wherever the script passes it.
          def enum_namespace(name)
            namespace = Module.new do
              def self.const_missing(member)
                member.to_s.downcase.to_sym
              end
            end
            namespace.define_singleton_method(:name) { "Gtk::#{name}" }
            namespace.define_singleton_method(:webui_stub?) { true }
            namespace
          end

          # Told once per widget class per session, to the script's own
          # output as well as the log: an empty box on screen is otherwise
          # indistinguishable from a layout bug.
          def report_stubbed_widget(name)
            script, first = record_unsupported("Gtk::#{name}", 'not implemented; renders as an empty box')
            return unless first

            detail = "webui-gtk-shim: Gtk::#{name} is not implemented; " \
                     'anything placed in it renders as an empty box'
            detail += " script=#{script}" if script
            Lich.log("warning: #{detail}") if defined?(Lich) && Lich.respond_to?(:log)
            # The guard tested `defined?(::Lich::Messaging)` and then called
            # Kernel#respond, so with Messaging loaded but respond absent the
            # call raised into the rescue below and the script was never told --
            # the one thing this method exists to do. Test the method that is
            # actually about to be called.
            return unless Kernel.respond_to?(:respond, true)

            Kernel.send(:respond, "[#{script || 'gtk'}: Gtk::#{name} is not supported yet -- " \
                                  'that part of the window will be blank]')
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
