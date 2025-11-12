# frozen_string_literal: true

#
# Combat Tracker - Main interface for combat event processing
# Integrates with Lich's game processing to track damage, wounds, and status effects
#

require_relative 'parser'
require_relative 'processor'
require_relative 'async_processor'

module Lich
  module Gemstone
    module Combat
      module Tracker
        @enabled = false
        @settings = {}
        @async_processor = nil
        @buffer = []

        # Default settings for combat tracking
        DEFAULT_SETTINGS = {
          enabled: true,            # Enable by default for testing
          track_damage: true,
          track_wounds: true,
          track_statuses: true,     # Enable for testing
          max_threads: 2,           # Keep threading for performance
          debug: false,             # Enable debug for testing
          buffer_size: 200,         # Increase for large combat chunks
          fallback_max_hp: 350      # Default max HP when template unavailable
        }.freeze

        class << self
          attr_reader :settings, :buffer

          def enabled?
            @enabled && @settings[:enabled]
          end

          def enable!
            return if @enabled

            @enabled = true
            load_settings
            @settings[:enabled] = true # Force enabled in settings
            save_settings # Persist enabled state
            initialize_processor
            add_downstream_hook

            puts "[Combat] Combat tracking enabled" if debug?
          end

          def disable!
            return unless @enabled

            @enabled = false
            @settings[:enabled] = false
            save_settings # Persist disabled state
            remove_downstream_hook
            shutdown_processor

            puts "[Combat] Combat tracking disabled" if debug?
          end

          def debug?
            @settings[:debug] || $combat_debug
          end

          def enable_debug!
            configure(debug: true, enabled: true)
            puts "[Combat] Debug mode enabled"
          end

          def disable_debug!
            configure(debug: false)
            puts "[Combat] Debug mode disabled"
          end

          def set_fallback_hp(hp_value)
            configure(fallback_max_hp: hp_value.to_i)
            puts "[Combat] Fallback max HP set to #{hp_value}"
          end

          def fallback_hp
            @settings[:fallback_max_hp]
          end

          # Process a chunk of game lines
          def process(chunk)
            return unless enabled?
            return if chunk.empty?

            # Quick filter - only process if combat-related content present
            return unless chunk.any? { |line| combat_relevant?(line) }

            if @settings[:max_threads] > 1
              @async_processor.process_async(chunk)
            else
              Processor.process(chunk)
            end
          end

          # Check if line contains combat-relevant content
          def combat_relevant?(line)
            line.include?('swing') ||
              line.include?('thrust') ||
              line.include?('cast') ||
              line.include?('gesture') ||
              line.include?('points of damage') ||
              line.include?('**') || # Flares
              line.include?('<pushBold/>') || # Creatures
              line.include?('AS:') || # Attack rolls
              line.match?(/\b(?:hit|miss|parr|block|dodge)\b/i)
          end

          # Update settings
          def configure(new_settings = {})
            @settings.merge!(new_settings)

            # Save to Lich settings system for persistence
            save_settings

            # Reinitialize processor if thread count changed
            if new_settings.key?(:max_threads)
              shutdown_processor
              initialize_processor
            end

            puts "[Combat] Settings updated: #{@settings}" if debug?
          end

          # Get processing stats
          def stats
            return { enabled: false } unless enabled?

            base_stats = {
              enabled: true,
              buffer_size: @buffer.size,
              settings: @settings
            }

            if @async_processor
              base_stats.merge(@async_processor.stats)
            else
              base_stats.merge(active: 0, total: 0)
            end
          end

          private

          def load_settings
            # Load from Lich settings system
            game_settings = Settings['combat'] || {}
            @settings = DEFAULT_SETTINGS.merge(game_settings)
          end

          def save_settings
            # Save current settings to Lich settings system
            Settings['combat'] = @settings
          end

          def initialize_processor
            return unless @settings[:max_threads] > 1
            @async_processor = AsyncProcessor.new(@settings[:max_threads])
          end

          def shutdown_processor
            return unless @async_processor
            @async_processor.shutdown
            @async_processor = nil
          end

          def add_downstream_hook
            @hook_id = 'Combat::Tracker::downstream'

            segment_buffer = proc do |server_string|
              @buffer << server_string

              # Process on prompt (natural break in game flow)
              if server_string.include?('<prompt time=')
                chunk = @buffer.slice!(0, @buffer.size)

                # Check if THIS chunk contains creatures (no persistent state)
                if chunk.any? { |line| line.match?(/<pushBold\/>.+?<a exist="[^"]+"[^>]*>.+?<\/a><popBold\/>/) }
                  process(chunk) unless chunk.empty?
                  puts "[Combat] Processed chunk with creatures (#{chunk.size} lines)" if debug?
                else
                  puts "[Combat] Discarded non-combat chunk (#{chunk.size} lines)" if debug?
                end
              end

              # Prevent buffer overflow
              if @buffer.size > @settings[:buffer_size]
                @buffer.shift(@buffer.size - @settings[:buffer_size])
              end

              server_string
            end

            DownstreamHook.add(@hook_id, segment_buffer)
          end

          def remove_downstream_hook
            DownstreamHook.remove(@hook_id) if @hook_id
            @hook_id = nil
          end
        end
      end
    end
  end
end

# Auto-enable combat tracking
# Enable if previously enabled OR if no settings exist (use defaults)
combat_settings = Settings['combat'] || {}
should_enable = combat_settings.fetch('enabled', true) # Default to enabled

if should_enable
  Lich::Gemstone::Combat::Tracker.enable!
  puts "[Combat] Auto-enabled combat tracking"
end
