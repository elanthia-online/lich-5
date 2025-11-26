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
      # Combat tracking system
      #
      # Main interface for the combat tracking system. Integrates with Lich's
      # downstream hooks to process game output and track combat events.
      #
      # Features:
      # - Damage tracking and HP estimation
      # - Wound/injury tracking by body part
      # - Status effect tracking with auto-expiration
      # - UCS (Unarmed Combat System) support
      # - Async processing for performance
      # - Automatic creature registry cleanup
      #
      # @example Enable tracking
      #   Combat::Tracker.enable!
      #   Combat::Tracker.configure(track_wounds: true, track_statuses: true)
      #
      # @example Get statistics
      #   stats = Combat::Tracker.stats
      #   puts "Active threads: #{stats[:active]}"
      #
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

          # Check if combat tracking is enabled
          #
          # Lazily initializes on first check if not already initialized.
          #
          # @return [Boolean] true if tracking is active
          def enabled?
            initialize! unless @initialized
            @enabled && @settings[:enabled]
          end

          # Enable combat tracking
          #
          # Initializes the processor, loads settings, and adds downstream hook.
          # Persists enabled state to DB.
          #
          # @return [void]
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

          # Disable combat tracking
          #
          # Shuts down the processor, removes hooks, and persists disabled state.
          #
          # @return [void]
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

          # Check if debug mode is enabled
          #
          # @return [Boolean] true if debug logging is active
          def debug?
            @settings[:debug] || $combat_debug
          end

          # Enable debug logging
          #
          # @return [void]
          def enable_debug!
            configure(debug: true, enabled: true)
            respond "[Combat] Debug mode enabled"
          end

          # Disable debug logging
          #
          # @return [void]
          def disable_debug!
            configure(debug: false)
            respond "[Combat] Debug mode disabled"
          end

          # Set fallback HP value for creatures without templates
          #
          # @param hp_value [Integer] Default max HP value
          # @return [void]
          def set_fallback_hp(hp_value)
            configure(fallback_max_hp: hp_value.to_i)
            respond "[Combat] Fallback max HP set to #{hp_value}"
          end

          def fallback_hp
            initialize! unless @initialized
            @settings[:fallback_max_hp]
          end

          # Process a chunk of game lines
          #
          # Filters for combat-relevant lines and processes them.
          # Triggers periodic cleanup of old creature instances.
          #
          # @param chunk [Array<String>] Game lines to process
          # @return [void]
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

          # Check if line contains combat-relevant content
          #
          # Quick filter to avoid processing non-combat lines.
          #
          # @param line [String] Game line to check
          # @return [Boolean] true if line may contain combat events
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

          # Update tracker settings
          #
          # Merges new settings with existing ones and persists to Lich settings.
          # Reinitializes processor if thread count changes.
          #
          # @param new_settings [Hash] Settings to update
          # @option new_settings [Boolean] :enabled Enable/disable tracking
          # @option new_settings [Boolean] :track_damage Track damage
          # @option new_settings [Boolean] :track_wounds Track wounds/injuries
          # @option new_settings [Boolean] :track_statuses Track status effects
          # @option new_settings [Boolean] :track_ucs Track UCS data
          # @option new_settings [Integer] :max_threads Thread pool size
          # @option new_settings [Boolean] :debug Enable debug logging
          # @return [void]
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

          # Get processing statistics
          #
          # @return [Hash] Stats including :enabled, :buffer_size, :settings, :active, :total
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
            removed = Creature.cleanup_old(max_age)

            if removed && removed > 0
              respond "[Combat] Cleaned up #{removed} old creature instances (age > #{max_age}s)" if debug?
            end
          rescue => e
            respond "[Combat] Error during creature cleanup: #{e.message}" if debug?
          end

          def load_settings
            # Load from DB_Store with per-character scope
            scope = "#{XMLData.game}:#{XMLData.name}"
            stored_settings = Lich::Common::DB_Store.read(scope, 'lich_combat_tracker')
            @settings = DEFAULT_SETTINGS.merge(stored_settings)
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

          # Initialize tracker from saved settings
          #
          # Reads settings from DB and auto-enables if previously enabled.
          # Called lazily on first access when XMLData is available.
          #
          # @return [void]
          def initialize!
            return if @initialized

            # Wait until XMLData is ready (avoid wrong scope)
            sleep 0.1 until !XMLData.game.nil? && !XMLData.game.empty? && !XMLData.name.nil? && !XMLData.name.empty?

            @initialized = true
            load_settings

            # Auto-enable if settings indicate it was previously enabled
            if @settings[:enabled]
              @enabled = true
              initialize_processor
              add_downstream_hook
              respond "[Combat] Auto-enabled combat tracking from saved settings" if debug?
            end
          end
        end

        # Trigger initialization check in a background thread
        Thread.new { initialize! }
      end
    end
  end
end
