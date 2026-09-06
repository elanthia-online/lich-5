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
      #   respond "Active threads: #{stats[:active]}"
      #
      module Tracker
        @enabled = false
        @settings = {}
        @async_processor = nil
        @buffer = []
        @chunks_processed = 0
        @initialized = false
        # Thread count to restore when debug mode is turned off. Deliberately
        # an ivar rather than a setting: `configure` persists settings to
        # DB_Store, so stashing it there would write max_threads: 0 to disk
        # and leave the character parsing inline forever if debug were never
        # cleanly disabled.
        @pre_debug_threads = nil

        # Default settings for combat tracking
        DEFAULT_SETTINGS = {
          enabled: false,           # Disabled by default, user must enable
          track_damage: true,
          track_wounds: true,
          track_statuses: true,
          track_ucs: true,          # Track UCS (position, tierup, smite)
          emit_attacks: false,      # Emit whole parsed events (:attack blob) for recorder-class subscribers
          max_threads: 2,           # Keep threading for performance
          debug: false,
          buffer_size: 200,         # Increase for large combat chunks
          fallback_max_hp: 350,     # Default max HP when template unavailable
          cleanup_interval: 100,    # Cleanup creature registry every N chunks
          cleanup_max_age: 600      # Remove creatures older than N seconds (10 minutes)
        }.freeze

        class << self
          attr_reader :settings, :buffer

          # Subscribe to parsed combat events (see Combat::Observers for
          # event types, payloads, and the subscriber contract - callbacks
          # may run on worker threads; never send game commands from one).
          #
          # @example
          #   Combat::Tracker.on(:damage) { |type, data| queue << data }
          #   Combat::Tracker.on(:damage, name: 'mybar') { ... } # idempotent
          # @return [Proc] handler; pass to {off} to unsubscribe
          def on(*types, name: nil, &block)
            Observers.on(*types, name: name, &block)
          end

          # Unsubscribe a handler returned by {on}, or by its name:.
          def off(handler_or_name)
            Observers.off(handler_or_name)
          end

          # Check if combat tracking is enabled
          #
          # Lazily initializes on first check if not already initialized.
          #
          # @return [Boolean] true if tracking is active
          def enabled?
            # Before login data is available we can't load per-character
            # settings; report disabled instead of sleeping on the caller's
            # thread (the background init thread completes setup once ready).
            return false unless @initialized || xmldata_ready?

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

          # Debug levels, in the order they were introduced. `true` is kept
          # as an alias for :verbose so settings saved before levels existed
          # still resolve.
          DEBUG_LEVELS = %i[summary verbose].freeze

          # Check if debug mode is enabled, or whether a specific level is.
          #
          # Called bare it returns the active level (truthy), which keeps every
          # existing `if Tracker.debug?` guard working unchanged.
          #
          # @param level [Symbol, nil] :verbose or :summary to test one level
          # @return [Symbol, Boolean, nil] active level, or whether `level` is on
          def debug?(level = nil)
            current = @settings[:debug] || $combat_debug
            current = :verbose if current == true
            return current unless level

            current == level
          end

          # Enable debug logging
          #
          # Forces inline processing (max_threads: 0) for the duration, so
          # debug output appears in true order relative to the game text
          # instead of interleaving from the async worker.
          #
          # @param level [Symbol] :verbose for the line-by-line parse trace,
          #   :summary for one line per persisted event
          # @return [void]
          def enable_debug!(level = :verbose)
            level = :verbose if level == true
            unless DEBUG_LEVELS.include?(level)
              respond "[Combat] Unknown debug level #{level.inspect} (expected #{DEBUG_LEVELS.map(&:inspect).join(' or ')})"
              return
            end

            initialize! unless @initialized
            # Only capture on the first enable - a second call while already
            # in debug would otherwise record the forced 0 as the value to
            # restore, stranding the character inline.
            @pre_debug_threads = @settings[:max_threads] unless debug?
            configure(debug: level, enabled: true, max_threads: 0)
            respond "[Combat] Debug mode enabled (#{level}, inline processing)"
          end

          # Disable debug logging
          #
          # Restores the thread count debug mode took over.
          #
          # @return [void]
          def disable_debug!
            initialize! unless @initialized
            restore = @pre_debug_threads || DEFAULT_SETTINGS[:max_threads]
            @pre_debug_threads = nil
            configure(debug: false, max_threads: restore)
            respond "[Combat] Debug mode disabled (max_threads: #{restore})"
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

            if @async_processor
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

          # Single compiled filter for combat-relevant content. One regex scan
          # replaces ~11 include? calls plus a regex per line; alternation of
          # literals compiles to an efficient multi-substring search.
          COMBAT_RELEVANT_PATTERN = Regexp.union(
            'points of damage',
            ' damage!', # roll-based short form ("... 6 damage!")
            # has no "points of" - chunks holding
            # only these were dropped entirely
            '<pushBold/>',              # Creatures
            '**',                       # Flares
            'AS:',                      # Attack rolls
            'swing', 'thrust', 'cast', 'gesture',
            'positioning against',      # UCS position
            'vulnerable to a followup', # UCS tierup
            'crimson mist'              # UCS smite
          ).freeze

          COMBAT_RESOLUTION_PATTERN = /\b(?:hit|miss|parr|block|dodge)\b/i.freeze

          # Check if line contains combat-relevant content
          #
          # Quick filter to avoid processing non-combat lines.
          #
          # @param line [String] Game line to check
          # @return [Boolean] true if line may contain combat events
          def combat_relevant?(line)
            COMBAT_RELEVANT_PATTERN.match?(line) || COMBAT_RESOLUTION_PATTERN.match?(line)
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
            # max_threads <= 0 means process inline on the hook thread
            # (debugging aid); otherwise use the ordered async worker so
            # parsing never delays the game stream.
            return unless @settings[:max_threads] > 0
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

                # Check if THIS chunk contains creatures (no persistent state).
                # Substring checks are equivalent to the old backtracking regex
                # for gating purposes and far cheaper per line.
                if chunk.any? { |line| line.include?('<pushBold/>') && line.include?('<a exist=') }
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

            DownstreamHook.add(@hook_id, segment_buffer, persist: true) # tracker manages its own removal
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
          # True once XMLData has game and character name (settings scope)
          def xmldata_ready?
            !XMLData.game.nil? && !XMLData.game.empty? && !XMLData.name.nil? && !XMLData.name.empty?
          end

          def initialize!
            return if @initialized

            # Wait until XMLData is ready (avoid wrong scope)
            sleep 0.1 until xmldata_ready?

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
