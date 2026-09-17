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

      # @return [Boolean] whether a constant defined in this scope now belongs
      #   to a script rather than to a plugin loaded by {.activate!}
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
        #
        # @param name [Symbol] the constant just defined
        # @return [void]
        def const_added(name)
          return super unless ScriptScope.adopt_nested_constants?

          value = const_get(name)
          return super unless value.is_a?(Module)

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
      # runs before Gtk::Widget's degrade-and-log one, and a helper whose name
      # matches an unimplemented GTK call is reached rather than degraded.
      # That is the right order -- the script wrote both -- and it is pinned
      # in spec/lib/common/script_scope_spec.rb.
      module InheritedHelpers
        # Forwards a call the superclass chain does not answer to the script's top-level helpers.
        #
        # @param name [Symbol] the method the script called
        # @param args [Array<Object>] its arguments
        # @return [Object] whatever the helper returns, or +super+'s result when no helper matches
        # @raise [NoMethodError] from +super+ when neither the ancestors nor ScriptScope answer
        def method_missing(name, *args, &block)
          return ScriptScope.public_send(name, *args, &block) if ScriptScope.respond_to?(name)

          super
        end

        # @param name [Symbol] the method being asked about
        # @param include_private [Boolean] whether private methods count
        # @return [Boolean] true when a script helper of that name exists, else +super+'s answer
        def respond_to_missing?(name, include_private = false)
          ScriptScope.respond_to?(name) || super
        end
      end

      singleton_class.include(Nesting)

      # Glob that finds every plugin's entry file under lib/common/script_scope/<name>/boot.rb.
      PLUGIN_GLOB = File.join(__dir__, 'script_scope', '*', 'boot.rb').freeze

      @active = false
      @activation_mutex = Mutex.new

      # Loads every plugin and routes trusted scripts through this scope.
      # Idempotent. Scripts already running keep the binding they started with.
      #
      # @return [Boolean] true once active
      def self.activate!
        @activation_mutex.synchronize do
          return true if @active

          Dir[PLUGIN_GLOB].sort.each { |boot| require boot }
          @adopt_nested_constants = true
          @active = true
        end
      end

      # @return [Boolean] whether new trusted scripts get a ScriptScope binding
      def self.active?
        @active
      end

      # A fresh binding whose constant lookup starts in this module. Created by
      # a method call so every script gets its own local-variable table.
      #
      # @return [Binding] a new binding whose self is this module
      def self.script_binding
        Proc.new {}.binding
      end
    end
  end
end
