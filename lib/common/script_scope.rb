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
      # helpers only on its singleton, so a script helper can never shadow a
      # method its superclass defines.
      module Nesting
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
      # helpers are reached only after the whole superclass chain has had its
      # say, so they can neither shadow an inherited method nor pre-empt the
      # shim's degrade-and-log +method_missing+.
      module InheritedHelpers
        def method_missing(name, *args, &block)
          return ScriptScope.public_send(name, *args, &block) if ScriptScope.respond_to?(name)

          super
        end

        def respond_to_missing?(name, include_private = false)
          ScriptScope.respond_to?(name) || super
        end
      end

      singleton_class.include(Nesting)

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
      # @return [Binding]
      def self.script_binding
        Proc.new {}.binding
      end
    end
  end
end
