# frozen_string_literal: true

module Lich
  module Common
    # Lexical scope for script code that must see something different from
    # what core sees.
    #
    # A script evaluated through {.script_binding} resolves bare constants
    # through this module first, then Lich::Common, Lich, and Object - so a
    # plugin under lib/common/script_scope/<name>/ can define a constant here
    # that shadows a top-level one for scripts only. Core never resolves
    # constants through ScriptScope and never references its plugins; the
    # plugins are loaded by glob so no core file names one.
    #
    # Methods a script defines with a bare +def+ land on this module. +extend
    # self+ makes them callable from the binding's self (this module), which
    # is the same visibility trick TRUSTED_SCRIPT_BINDING relies on through
    # Lich::Common being included into Object.
    #
    # A script's own modules and classes reach those methods through
    # {Nesting}. Without it a bare +def+ would be visible only at the
    # script's top level, where an ordinary Lich script -- whose +def+ lands
    # on Object -- can call it from anywhere.
    module ScriptScope
      extend self

      @adopt_nested_constants = false
      @core_aliases = {}
      @legacy_constants = {}
      @legacy_helpers = {}
      @legacy_notices = {}
      @plugin_names = []
      @plugin_modules = []

      # Compatibility exports contain only script declarations, never plugins.
      # Retirement: migrate supported legacy consumers, verify zero bridge uses
      # in the agreed corpus, then obtain owner approval before removing this bridge.
      module LegacyConstants; end

      # Existing Object/Core methods take precedence over legacy script helpers.
      # Binding the method to the original receiver preserves helpers such as
      # Numeric#percent_of without including ScriptScope into Object or core classes.
      module LegacyHelpers
        # Forwards a missing public script helper with the original receiver.
        # @param name [Symbol] requested helper name
        # @param args [Array<Object>] positional arguments
        # @param kwargs [Hash] keyword arguments
        # @param block [Proc, nil] block forwarded to the helper
        # @return [Object] helper result or the next missing-method handler result
        # @raise [NoMethodError] when no handler answers the call
        def method_missing(name, *args, **kwargs, &block)
          return super unless ScriptScope.legacy_helper?(name)

          ScriptScope.legacy_notice(:helper, name)
          ScriptScope.instance_method(name).bind_call(self, *args, **kwargs, &block)
        end

        # Advertises eligible public helpers while preserving ancestor lookup.
        # @param name [Symbol] requested method name
        # @param include_private [Boolean] forwarded to the ancestor handler
        # @return [Boolean] whether a helper or ancestor handler answers
        def respond_to_missing?(name, include_private = false)
          ScriptScope.legacy_helper?(name) || super
        end
      end

      # Late core definitions must be visible before a script reopens them.
      module CoreConstants
        # Refreshes core aliases after a constant is added while scope is active.
        # @param name [Symbol] newly defined core constant
        # @return [void]
        def const_added(name)
          super
          ScriptScope.sync_core_constants! if ScriptScope.active?
        end
      end

      # Registers declarations made after plugin boot for legacy lookup.
      # @param name [Symbol] newly defined instance method
      # @return [void]
      def self.method_added(name)
        @legacy_helpers[name] = true if @adopt_nested_constants
        super
      end

      # Checks that a registered legacy helper remains public and directly defined.
      # @param name [Symbol] requested helper name
      # @return [Boolean] whether the helper can be forwarded
      def self.legacy_helper?(name)
        @legacy_helpers.key?(name) && public_instance_methods(false).include?(name)
      end

      # Emits one migration notice per kind/name, without script values.
      # Logging failures do not interrupt script execution.
      # @param kind [Symbol] export category, such as :helper or :constant
      # @param name [Symbol] exported name
      # @return [void]
      def self.legacy_notice(kind, name)
        key = [kind, name]
        return if @legacy_notices[key]

        @legacy_notices[key] = true
        source = caller_locations.find { |location| location.path.end_with?('.lic') }
        location = source ? "#{File.basename(source.path)}:#{source.lineno}" : 'script scope'
        Lich.log("warning: legacy script #{kind}=#{name} source=#{location}; migrate to ScriptScope lookup") if Lich.respond_to?(:log)
      rescue StandardError
        nil
      end

      # Aliases are refreshed without changing the core objects' ancestors.
      # Never overwrite a plugin or a script-owned constant.
      # @return [void]
      def self.sync_core_constants!
        public_names = Lich::Common.constants(false) - [:ScriptScope]
        @core_aliases.keys.each do |name|
          next if public_names.include?(name) && Lich::Common.const_get(name, false).equal?(@core_aliases[name])

          remove_const(name) if const_defined?(name, false) && const_get(name, false).equal?(@core_aliases[name])
          @core_aliases.delete(name)
        end
        public_names.each do |name|
          next if const_defined?(name, false) || Lich::Common.autoload?(name)

          value = Lich::Common.const_get(name, false)
          @core_aliases[name] = value
          const_set(name, value)
        end
      end

      # Export actual aliases so Ruby's defined? and const_defined? agree with
      # absolute lookup. Missing-method/constant hooks alone cannot do that.
      # Clears stale exports before excluding core, plugin and existing Object names.
      # @param name [Symbol] script constant name
      # @param value [Object] current constant value
      # @return [void]
      def self.export_legacy_constant(name, value)
        if @legacy_constants.delete(name)
          LegacyConstants.send(:remove_const, name)
        end
        return if @core_aliases.key?(name) || @plugin_names.include?(name)
        if value.is_a?(Module)
          module_name = Module.instance_method(:name).bind_call(value).to_s
          return if @plugin_modules.any? { |plugin| value.equal?(plugin) || module_name.start_with?("#{plugin.name}::") }
        end
        return if Object.const_defined?(name)

        LegacyConstants.const_set(name, value)
        @legacy_constants[name] = true
        legacy_notice(:constant, name)
      end

      # Keeps explicit removal and subsequent redefinition from leaving stale exports.
      # @param name [Symbol, String] constant to remove from script scope
      # @return [Object] removed constant value
      # @raise [NameError] when the constant is not defined directly on this scope
      def self.remove_const(name)
        value = super
        if @legacy_constants.delete(name.to_sym)
          LegacyConstants.send(:remove_const, name)
        end
        value
      end
      private_class_method :remove_const

      # Reports whether script-owned nested classes/modules receive scoped helpers.
      # @return [Boolean] whether new constants belong to scripts rather than plugins loaded by {.activate!}
      def self.adopt_nested_constants?
        @adopt_nested_constants
      end

      # Gives every module and class a script defines inside ScriptScope the
      # same view of the script's top-level methods that it would have under
      # Object, and installs itself on each one so nesting keeps working at
      # any depth.
      #
      # Only constants defined after {.activate!} are touched: the plugins
      # loaded there (the GTK shim's own widget classes) must keep the
      # ancestry they were written with. For the same reason a script class
      # that inherits behaviour -- one subclassing a shim widget -- gains the
      # helpers through {InheritedHelpers}' method_missing rather than by
      # including this module, so a script helper can never shadow a method
      # its superclass defines.
      module Nesting
        # Wires a newly defined nested module or class into ScriptScope.
        #
        # Runs for every constant defined on a module that extends {Nesting}; anything defined
        # before {.activate!} (or that is not a Module) is passed straight to +super+.
        # Top-level script declarations also update eligible legacy constant exports.
        # Only a definition named inside this namespace is adopted; aliases to
        # existing core/script classes keep their original ancestry.
        #
        # @param name [Symbol] the constant just defined
        # @return [void]
        def const_added(name)
          return super unless ScriptScope.adopt_nested_constants?

          value = const_get(name)
          ScriptScope.export_legacy_constant(name, value) if equal?(ScriptScope)
          return super unless value.is_a?(Module)
          # A constant alias is not a class/module definition. Adopting an alias
          # such as MyCmp = ::Comparable would change unrelated core ancestors.
          module_name = Module.instance_method(:name)
          return super unless module_name.bind_call(value) == "#{module_name.bind_call(self)}::#{name}"

          value.singleton_class.include(Nesting)
          if !value.is_a?(Class) || value.superclass == Object
            value.include(ScriptScope)
          else
            value.include(InheritedHelpers)
          end
          value.extend(ScriptScope)
          super
        end
      end

      # For a script class that subclasses something real -- a shim widget --
      # helpers are reached through method_missing, so every real method in
      # the superclass chain wins over a same-named helper. What they do
      # pre-empt is the superclass's own +method_missing+: +include+ places
      # this module directly above the script's class, so this method_missing
      # runs before a widget's unsupported-operation handler; a helper whose name
      # matches an unimplemented call is reached rather than rejected.
      # That is the right order -- the script wrote both -- and it is pinned
      # in spec/lib/common/script_scope_redux_spec.rb. Only helpers declared on
      # ScriptScope are forwarded, never its inherited Module/Object API.
      module InheritedHelpers
        # Forwards a call the superclass chain does not answer to the script's top-level helpers.
        #
        # @param name [Symbol] the method the script called
        # @param args [Array<Object>] its arguments
        # @return [Object] whatever the helper returns, or +super+'s result when no helper matches
        # @raise [NoMethodError] from +super+ when neither the ancestors nor ScriptScope answer
        def method_missing(name, *args, &block)
          return ScriptScope.public_send(name, *args, &block) if ScriptScope.public_instance_methods(false).include?(name)

          super
        end

        # Advertises declared public helpers without exposing Module's own API.
        # @param name [Symbol] the method being asked about
        # @param include_private [Boolean] whether private methods count
        # @return [Boolean] true when a script helper of that name exists, else +super+'s answer
        def respond_to_missing?(name, include_private = false)
          ScriptScope.public_instance_methods(false).include?(name) || super
        end
      end

      singleton_class.include(Nesting)

      # Glob that finds every plugin's entry file under lib/common/script_scope/<name>/boot.rb.
      PLUGIN_GLOB = File.join(__dir__, 'script_scope', '*', 'boot.rb').freeze

      @active = false
      @activation_mutex = Mutex.new

      # Loads every plugin and routes trusted scripts through this scope.
      # Idempotent. Scripts already running keep the binding they started with.
      # Captures plugin exclusions, synchronizes core aliases and installs the
      # legacy lookup hooks before accepting script-owned declarations.
      #
      # @return [Boolean] true once active
      def self.activate!
        @activation_mutex.synchronize do
          return true if @active

          @legacy_helpers = public_instance_methods(false).to_h { |name| [name, true] }
          Dir[PLUGIN_GLOB].sort.each { |boot| require boot }
          @plugin_names = constants(false) - @core_aliases.keys
          @plugin_modules = @plugin_names.filter_map { |name| value = const_get(name, false); value if value.is_a?(Module) }
          sync_core_constants!
          Object.include(LegacyConstants)
          Object.prepend(LegacyHelpers)
          Lich::Common.singleton_class.prepend(CoreConstants)
          @adopt_nested_constants = true
          @active = true
        end
      end

      # Reports whether script-scope activation has occurred.
      # @return [Boolean] whether new trusted scripts get a ScriptScope binding
      def self.active?
        @active
      end

      # A fresh binding whose constant lookup starts in this module. Created by
      # a method call so every script gets its own local-variable table.
      # Synchronizes core aliases before exposing the binding.
      #
      # @return [Binding] a new binding whose self is this module
      def self.script_binding
        sync_core_constants!
        Proc.new {}.binding
      end

      # Label-based scripts keep instance methods on their own receiver while
      # resolving extension constants through the same lexical boundary.
      class Sandbox
        include ScriptScope

        # Creates fresh locals on this receiver within the shared lexical script scope.
        # Despite the historical class name, this binding is not a security sandbox.
        # @return [Binding]
        def script_binding
          Proc.new {}.binding
        end
      end

      # Creates a fresh receiver/binding for label-based scripts, retaining scoped constants.
      # Synchronizes core aliases before constructing the receiver.
      # This preserves evaluation semantics; it does not restrict arbitrary Ruby execution.
      # @return [Binding]
      def self.untrusted_binding
        sync_core_constants!
        Sandbox.new.script_binding
      end
    end
  end
end
