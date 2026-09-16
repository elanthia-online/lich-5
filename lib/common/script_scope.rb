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
    module ScriptScope
      extend self

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
