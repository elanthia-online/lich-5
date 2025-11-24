# frozen_string_literal: true

#
# Combat Tracker - Main interface for combat event processing
# Integrates with Lich's game processing to track damage, wounds, and status effects
#

require_relative 'parser'
require_relative 'processor'
require_relative 'async_processor'
require_relative '../../common/db_store'

module Lich
  module Gemstone
    module Combat
      module Tracker
        @enabled = false
        @settings = {}
        @async_processor = nil
        @buffer = []
        @chunks_processed = 0
        @initialized = false

        # Default settings for combat tracking
        DEFAULT_SETTINGS = {
          enabled: false,           # Disabled by default, user must enable
          track_damage: true,
          track_wounds: true,
          track_statuses: true,
          track_ucs: true,          # Track UCS (position, tierup, smite)
          max_threads: 2,           # Keep threading for performance
          debug: false,
          buffer_size: 200,         # Increase for large combat chunks
          fallback_max_hp: 350,     # Default max HP when template unavailable
          cleanup_interval: 100,    # Cleanup creature registry every N chunks
          cleanup_max_age: 600      # Remove creatures older than N seconds (10 minutes)
        }.freeze

        class << self
          attr_reader :settings, :buffer

          def enabled?
            initialize! unless @initialized
            @enabled && @settings[:enabled]
          end

          def enable!
            return if @enabled

            initialize! unless @initialized
            @enabled = true
            @settings[:enabled] = true # Force enabled in settings
            save_settings # Persist enabled state
            initialize_processor
            add_downstream_hook

            respond "[Combat] Combat tracking enabled" if debug?
          end

          def disable!
            return unless @enabled

            initialize! unless @initialized
            @enabled = false
            @settings[:enabled] = false
            save_settings # Persist disabled state
            remove_downstream_hook
            shutdown_processor

            respond "[Combat] Combat tracking disabled" if debug?
          end

          def debug?
            @settings[:debug] || $combat_debug
          end

          def enable_debug!
            configure(debug: true, enabled: true)
            respond "[Combat] Debug mode enabled"
          end

          def disable_debug!
            configure(debug: false)
            respond "[Combat] Debug mode disabled"
          end

          def set_fallback_hp(hp_value)
            configure(fallback_max_hp: hp_value.to_i)
            respond "[Combat] Fallback max HP set to #{hp_value}"
          end

          def fallback_hp
            initialize! unless @initialized
            @settings[:fallback_max_hp]
          end

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

            # Periodic cleanup of old creature instances
            @chunks_processed += 1
            if @chunks_processed >= @settings[:cleanup_interval]
              cleanup_creatures
              @chunks_processed = 0
            end
          end

          def combat_relevant?(line)
            line.include?('swing') ||
              line.include?('thrust') ||
              line.include?('cast') ||
              line.include?('gesture') ||
              line.include?('points of damage') ||
              line.include?('**') || # Flares
              line.include?('<pushBold/>') || # Creatures
              line.include?('AS:') || # Attack rolls
              line.include?('positioning against') || # UCS position
              line.include?('vulnerable to a followup') || # UCS tierup
              line.include?('crimson mist') || # UCS smite
              line.match?(/\b(?:hit|miss|parr|block|dodge)\b/i)
          end

          def configure(new_settings = {})
            initialize! unless @initialized
            @settings.merge!(new_settings)

            # Save to Lich settings system for persistence
            save_settings

            # Reinitialize processor if thread count changed
            if new_settings.key?(:max_threads)
              shutdown_processor
              initialize_processor
            end

            respond "[Combat] Settings updated: #{@settings}" if debug?
          end

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

          def cleanup_creatures
            return unless defined?(Creature)

            max_age = @settings[:cleanup_max_age]
            removed = Creature.cleanup_old(max_age_seconds: max_age)

            if removed && removed > 0
              respond "[Combat] Cleaned up #{removed} old creature instances (age > #{max_age}s)" if debug?
            end
          rescue => e
            respond "[Combat] Error during creature cleanup: #{e.message}" if debug?
          end

          def load_settings
            # Load from DB_Store with per-character scope
            scope = "#{XMLData.game}:#{XMLData.name}"
            respond "[Combat] load_settings: scope='#{scope}'" if debug?
            stored_settings = Lich::Common::DB_Store.read(scope, 'lich_combat_tracker')
            respond "[Combat] load_settings: stored=#{stored_settings.inspect}" if debug?
            @settings = DEFAULT_SETTINGS.merge(stored_settings)
            respond "[Combat] load_settings: @settings[:enabled]=#{@settings[:enabled]}" if debug?
          end

          def save_settings
            # Save current settings to DB_Store with per-character scope
            scope = "#{XMLData.game}:#{XMLData.name}"
            Lich::Common::DB_Store.save(scope, 'lich_combat_tracker', @settings)
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
                  respond "[Combat] Processed chunk with creatures (#{chunk.size} lines)" if debug?
                else
                  respond "[Combat] Discarded non-combat chunk (#{chunk.size} lines)" if debug?
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

          def initialize!
            respond "[Combat] initialize! called, @initialized=#{@initialized}, XMLData.game=#{XMLData.game.inspect}, XMLData.name=#{XMLData.name.inspect}" if debug?
            return if @initialized

            # Don't initialize until XMLData is ready (avoid wrong scope)
            if XMLData.game.nil? || XMLData.game.empty? || XMLData.name.nil? || XMLData.name.empty?
              respond "[Combat] initialize! skipped - XMLData not ready" if debug?
              return
            end

            @initialized = true
            respond "[Combat] initialize! proceeding with initialization" if debug?

            load_settings

            # Auto-enable if settings indicate it was previously enabled
            if @settings[:enabled]
              @enabled = true
              initialize_processor
              add_downstream_hook
              respond "[Combat] Auto-enabled combat tracking from saved settings" if debug?
            else
              respond "[Combat] Staying disabled (settings[:enabled]=false)" if debug?
            end
          end
        end
      end
    end
  end
end
