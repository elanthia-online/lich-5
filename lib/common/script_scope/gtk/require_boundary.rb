# frozen_string_literal: true

module Lich
  module Common
    module ScriptScope
      module Gtk
        # Prevents ordinary Ruby loaders from bringing native GTK into a script
        # process. Installed gems do not widen the bounded compatibility surface.
        # This is a dependency boundary, not a sandbox against arbitrary Ruby.
        module RequireBoundary
          COMPATIBILITY_FEATURES = %w[gtk2 gtk2.rb gtk3 gtk3.rb].freeze
          # Ruby-GNOME uses underscore names for some native extensions even
          # when their Ruby entrypoints use hyphens; guard both before loading.
          NATIVE_FEATURE = %r{
            \A(?:gtk[234]|gdk[234]?|gdk_pixbuf2|glib2|gio2|gi|
            gobject[-_]introspection|cairo(?:[-_]gobject)?|pango|atk)
            (?:\.(?:rb|so|bundle|dll))?(?:/|\z)|\Agtk(?:\.rb)?\z
          }ix

          # Recognizes preloaded compatibility entrypoints or refuses native code.
          # Other dependencies retain normal Ruby loader behavior.
          # @param feature [String, #to_path] requested Ruby feature or path
          # @param operation [Symbol] Ruby loader being used
          # @param location [Thread::Backtrace::Location] caller of the loader
          # @return [Boolean] true only for an already available shim entrypoint
          # @raise [UnsupportedOperation] when a native dependency is requested
          def self.handled?(feature, operation, location)
            path = File.path(feature).tr('\\', '/')
            return false unless native_feature?(path)

            owner = if defined?(Script)
                      Script.respond_to?(:current_without_pause) ? Script.current_without_pause : Script.current
                    end
            return true if owner && operation == :require && COMPATIBILITY_FEATURES.include?(path)

            raise UnsupportedOperation,
                  "script=#{owner&.name || 'none'} operation=#{operation} feature=#{path} source=#{location}: native GTK loading is disabled; use the bounded script shim or native WebUI"
          end

          # Resolve feature roots against Ruby's load paths rather than matching
          # arbitrary ancestor directory names in an installation path.
          # Direct entrypoint filenames remain reserved, including absolute loads.
          # @param path [String] feature or path with forward-slash separators
          # @return [Boolean] whether the request identifies a native GTK dependency
          def self.native_feature?(path)
            absolute = path.start_with?('/') || path.match?(/\A[A-Za-z]:\//)
            return true if !absolute && NATIVE_FEATURE.match?(path.sub(%r{\A(?:\./)+}, ''))
            return true if NATIVE_FEATURE.match?(File.basename(path))

            return false unless absolute

            roots = $LOAD_PATH.dup
            if defined?(Gem) && Gem.respond_to?(:loaded_specs)
              roots.concat(Gem.loaded_specs.values.flat_map(&:full_require_paths))
            end
            roots.any? do |root|
              prefix = File.expand_path(root).tr('\\', '/').sub(%r{/+\z}, '') + '/'
              path.start_with?(prefix) && NATIVE_FEATURE.match?(path.delete_prefix(prefix))
            end
          end

          # Covers bare loaders, explicit Kernel calls and loads in helper files.
          # Keeping this hook inside the plugin leaves core WebUI GTK-independent.
          module Loaders
            # Resolves compatibility aliases without activating native gems.
            # @param feature [String, #to_path] feature to require
            # @return [Boolean] false for the preloaded shim, otherwise Ruby's result
            # @raise [UnsupportedOperation] for native GTK dependencies
            def require(feature)
              return false if RequireBoundary.handled?(feature, :require, caller_locations(1, 1).first)

              super
            end

            # Resolves against the original caller, not this wrapper's directory.
            # @param feature [String, #to_path] caller-relative feature
            # @return [Boolean] Ruby's require result
            # @raise [LoadError] when Ruby cannot infer a caller source path
            # @raise [UnsupportedOperation] for native GTK dependencies
            def require_relative(feature)
              location = caller_locations(1, 1).first
              RequireBoundary.handled?(feature, :require_relative, location)
              source = location.absolute_path || location.path
              raise LoadError, 'cannot infer basepath' if source.start_with?('(') || source == '-e'

              path = File.expand_path(File.path(feature), File.dirname(source))
              RequireBoundary.handled?(path, :require_relative, location)
              super(path)
            end

            # Refuses native dependency files before Ruby can execute their code.
            # @param feature [String, #to_path] file to execute
            # @param wrap [Boolean, Module] Ruby's optional namespace wrapper
            # @return [Boolean] Ruby's load result
            # @raise [UnsupportedOperation] for native GTK dependencies
            def load(feature, wrap = false)
              RequireBoundary.handled?(feature, :load, caller_locations(1, 1).first)
              super
            end
          end

          # Kernel's instance loaders stay private; Kernel.require remains public.
          module PrivateLoaders
            # Concrete methods preserve Ruby's module alias lookup. Changing the
            # visibility of included methods breaks dependencies aliasing require.
            Loaders.instance_methods(false).each do |name|
              define_method(name, Loaders.instance_method(name))
              private name
            end
          end
        end
      end
    end
  end
end

Kernel.prepend(Lich::Common::ScriptScope::Gtk::RequireBoundary::PrivateLoaders)
Kernel.singleton_class.prepend(Lich::Common::ScriptScope::Gtk::RequireBoundary::Loaders)
