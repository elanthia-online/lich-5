# frozen_string_literal: true

require_relative 'watchable'

module Lich
  module Common
    module PostLoad
      extend Lich::Common::Watchable

      @@complete = false
      @@game_loaded = false
      @callbacks = {}
      @mutex = Mutex.new

      # Register a named callback to run after game-specific load completes.
      # Callbacks run in registration order. Duplicate names replace prior entry.
      #
      #   PostLoad.register("my_feature") { do_something }
      #
      def self.register(name, &block)
        raise ArgumentError, "PostLoad.register requires a block" unless block_given?

        @mutex.synchronize do
          @callbacks[name.to_s] = block
        end
      end

      # Called by game-specific modules to signal their startup is done.
      # GS: called at end of Infomon.watch! thread
      # DR: called from DRInfomon.startup_completed!
      def self.game_loaded!
        @@game_loaded = true
      end

      def self.game_loaded?
        @@game_loaded
      end

      def self.complete?
        @@complete
      end

      def self.watch!
        @thread ||= Thread.new do
          begin
            # Phase 1: Wait for base readiness (same as other watchers)
            sleep 0.1 until GameBase::Game.autostarted? &&
                           XMLData.name && !XMLData.name.empty?

            # Phase 2: Wait for game-specific init to signal completion
            sleep 0.1 until @@game_loaded

            # Phase 3: Run registered callbacks
            run_callbacks
          rescue StandardError => e
            respond "--- Lich: error in PostLoad thread: #{e.message}"
            respond e.backtrace.first(5).join("\n") if e.backtrace
          end
        end
      end

      def self.run_callbacks
        snapshot = @mutex.synchronize { @callbacks.dup }
        snapshot.each do |name, callback|
          begin
            callback.call
          rescue StandardError => e
            respond "--- Lich: error in PostLoad callback '#{name}': #{e.message}"
            respond e.backtrace.first(5).join("\n") if e.backtrace
          end
        end
        @@complete = true
      end

      private_class_method :run_callbacks
    end
  end
end
