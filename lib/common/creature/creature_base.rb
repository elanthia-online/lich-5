# frozen_string_literal: true

# =============================================================================
# common/creature/creature_base.rb
#
# Game-agnostic core of Lich's runtime creature model, shared by the GemStone
# and DragonRealms `Creature` implementations. Mirrors the structure of
# common/map/map_base.rb: a single {Lich::Common::CreatureBase} mixin whose
# `self.included` hook wires the shared {CreatureBase::ClassMethods} (id-keyed
# registry, room roster and target queries) and {CreatureBase::InstanceMethods}
# (transient status / classification tracking) into the including class.
#
# Both games receive the same structured, id-keyed creature feed:
#
#   <crtrStatus exist="..." hostile="1" .../>
#
# a full snapshot of a creature's transient combat status and classification
# flags. The flag vocabulary is identical across the two games (see
# {CRTR_STATUS_FLAGS} and {CRTR_CLASSIFICATION_FLAGS}), so status/flag
# reconciliation, the registry, the room roster and target filtering all live
# here and are mixed into each game's concrete `CreatureInstance`.
#
# Game-specific concerns stay out of this file:
#   * GemStone: bestiary templates, UCS (Unarmed Combat System) tracking,
#     HP/injury modelling and GemStone `valid_target?` exclusions
#     (lib/gemstone/creature.rb).
#   * DragonRealms: `assess`-stream name/position backfill and the DragonRealms
#     `valid_target?` rule (lib/dragonrealms/creature.rb).
#
# Usage (see lib/gemstone/creature.rb for a worked example):
#
#   class CreatureInstance
#     include Lich::Common::CreatureBase   # adds instance + class methods
#     def initialize(id, noun, name)
#       @id = id.to_i; @noun = noun; @name = name
#       initialize_status_tracking
#       # ...game-specific ivars...
#     end
#     def valid_target? = !crtr_flag?(:dead) # each game supplies its own rule
#   end
# =============================================================================

module Lich
  module Common
    # Shared creature behaviour mixed into each game's `CreatureInstance`.
    #
    # Include this into a concrete creature-instance class. The `included` hook
    # extends the class with {ClassMethods} (registry/roster/target queries) and
    # includes {InstanceMethods} (status/flag tracking). The class must define a
    # `new(id, noun, name)` constructor, call {InstanceMethods#initialize_status_tracking}
    # from its own `initialize`, and expose a `valid_target?` predicate (used by
    # {ClassMethods#targets}) plus a `created_at` reader (used by
    # {ClassMethods#cleanup_old}).
    module CreatureBase
      # Wires the shared behaviour into the including class, matching the
      # MapBase convention.
      #
      # @param base [Class] the including creature-instance class.
      # @return [void]
      def self.included(base)
        base.extend(ClassMethods)
        base.include(InstanceMethods)
      end

      # Status-effect lifetimes, in seconds, used for automatic cleanup.
      #
      # A `nil` value means the status has a reliable server-sent removal
      # message and therefore must not be auto-expired on a timer.
      #
      # @return [Hash{String=>Integer, nil}]
      STATUS_DURATIONS = {
        'breeze'       => 6,   # 6 seconds roundtime
        'bind'         => 10,  # 10 seconds typical
        'web'          => 8,   # 8 seconds typical
        'entangle'     => 10,  # 10 seconds typical
        'hypnotism'    => 12,  # 12 seconds typical
        'calm'         => 15,  # 15 seconds typical
        'mass_calm'    => 15,  # 15 seconds typical
        'sleep'        => 8,   # 8 seconds typical (can wake early)
        # Crit-derived states. 'roundtime' is set with an explicit duration by
        # the combat processor (critical tables report it in seconds); these
        # defaults apply when a source supplies no duration of its own.
        'roundtime'    => 5,
        'dazed'        => 10,
        # Statuses with reliable removal messages - no duration needed.
        'stunned'      => nil,
        # Reachable from many sources (Silence 210, silencing flares, UCS
        # crits / Slow 506, ensorcell) with no single reliable duration, so
        # they are message-cleared rather than timer-expired.
        'silenced'     => nil,
        'slowed'       => nil,
        'crippled'     => nil,
        'limb_favored' => nil,
        'amputated'    => nil,
        'immobilized'  => nil,
        'prone'        => nil,
        'blind'        => nil,
        'sunburst'     => nil,
        'webbed'       => nil,
        'poisoned'     => nil,
        'hidden'       => nil
      }.freeze

      # Maps `<crtrStatus>` transient XML flags to canonical status names.
      #
      # The XML feed and the message parser use slightly different terms for the
      # same state (e.g. "immobile" versus "immobilized"). Keeping this mapping
      # explicit lets XML- and message-based detection reconcile into the same
      # status entries.
      #
      # @return [Hash{String=>String}]
      CRTR_STATUS_FLAGS = {
        'immobile'    => 'immobilized',
        'webbed'      => 'webbed',
        'sleeping'    => 'sleeping',
        'disoriented' => 'disoriented',
        'stunned'     => 'stunned',
        'rooted'      => 'rooted',
        'calmed'      => 'calm',
        'kneeling'    => 'kneeling',
        'prone'       => 'prone',
        'sitting'     => 'sitting',
        'flying'      => 'flying',
        'hovering'    => 'hovering',
        'hidden'      => 'hidden'
      }.freeze

      # Maps `<crtrStatus>` classification XML flags to predicate keys.
      #
      # These are relationship or classification facts rather than transient
      # combat statuses, so they are stored separately and read via
      # {InstanceMethods#crtr_flag?}.
      #
      # @return [Hash{String=>Symbol}]
      CRTR_CLASSIFICATION_FLAGS = {
        'hostile'       => :hostile,
        'disengaged'    => :disengaged,
        'dead'          => :dead,
        'sympathetic'   => :sympathetic,
        'ascended'      => :ascended,
        'inferior'      => :inferior,
        'AscensionBoss' => :ascension_boss,
        'MiniBoss'      => :mini_boss,
        'challenging'   => :challenging,
        'rider'         => :rider,
        'mount'         => :mount
      }.freeze

      # All known `<crtrStatus>` attributes keyed by XML name, for debug
      # snapshots.
      #
      # @return [Hash{String=>String, Symbol}]
      ALL_CRTR_FLAGS = CRTR_STATUS_FLAGS.merge(CRTR_CLASSIFICATION_FLAGS).freeze

      # Every filter name {ClassMethods#targets} and {ClassMethods#in_room} can
      # match: the canonical status vocabulary (both the `<crtrStatus>` status
      # spellings and the timer-based message statuses in {STATUS_DURATIONS})
      # plus the classification keys. A filter outside this set is "unknown" and,
      # per the query contract, matches no candidates - even when negated with a
      # `not_` prefix.
      #
      # @return [Array<String>]
      KNOWN_FLAG_NAMES = (
        CRTR_STATUS_FLAGS.values +
        STATUS_DURATIONS.keys +
        CRTR_CLASSIFICATION_FLAGS.values.map(&:to_s)
      ).uniq.freeze

      # Class-level behaviour: the id-keyed instance registry, the current-room
      # roster and the target/room queries shared by both games' `Creature`
      # facades.
      #
      # State lives in per-class instance variables (`@instances`,
      # `@current_room_ids`, ...), so each extending class keeps an independent
      # registry - GemStone and DragonRealms never share a roster even though
      # they share this code.
      module ClassMethods
        # Registers or looks up a creature instance, marking it present in the
        # current room.
        #
        # Room-marking happens on every call, new instance or not, because the
        # feed event that triggers registration (a bolded room-object name, or a
        # `<crtrStatus>` tag) is exactly the signal that the creature is present.
        #
        # @param name [String, nil] display name; may be nil when the feed
        #   supplies an id before a name (DragonRealms `<crtrStatus>`).
        # @param id [Integer, String] server creature id.
        # @param noun [String, nil] noun from room XML, when available.
        # @return [Object, nil] the registered instance, or nil when
        #   auto-registration is disabled or the registry is full.
        def register(name, id, noun = nil)
          # Record room presence first: the feed event that triggers this call
          # (a bolded room-object name or a <crtrStatus> tag) is itself proof the
          # creature is in the room, and that stays true even when
          # auto-registration is disabled and no instance will be created. Mark
          # before the guard so a known creature's room presence is still tracked
          # while auto-registration is off.
          entered_room = mark_in_room(id)
          return nil unless auto_register?

          existing = instances[id.to_i]
          if existing
            respond "--- #{name} (#{id}): in room" if entered_room && $creature_debug
            return existing
          end

          if full?
            # Progressively more aggressive: 120 minutes, then 15-minute steps.
            [7200, 6300, 5400, 4500, 3600, 2700, 1800, 900].each do |age_threshold|
              removed = cleanup_old(age_threshold)
              respond "--- Auto-cleanup: removed #{removed} old creatures (threshold: #{age_threshold}s)" if removed > 0 && $creature_debug
              break unless full?
            end
            return nil if full? # Still full after every cleanup attempt.
          end

          instance = new(id, noun, name)
          instances[id.to_i] = instance
          respond "--- #{name} (#{id}): registered" if $creature_debug
          instance
        end

        # Marks an id present in the current-room roster.
        #
        # @param id [Integer, String] server creature id.
        # @return [Boolean] true when the id was newly added.
        def mark_in_room(id)
          id = id.to_i
          return false if room_roster.include?(id)

          room_roster << id
          true
        end

        # Empties the current-room roster (the persistent registry is untouched).
        #
        # Called from the XML parser's nav and room-object refresh hooks; the
        # roster is then rebuilt from fresh room XML.
        #
        # @return [void]
        def clear_room
          count = room_roster.size
          @current_room_ids = []
          respond "--- room: roster cleared (#{count} creature#{'s' unless count == 1})" if $creature_debug && count > 0
        end

        # Returns the creature ids currently present in the room.
        #
        # Hands back a copy, not the live roster. The internal roster is mutated
        # in place by {#mark_in_room} / {#clear_room}, so a caller that mutated
        # the returned array - the GemStone facade relied on this defensive copy
        # before the extraction - would otherwise corrupt shared targeting state.
        #
        # @return [Array<Integer>]
        def current_room_ids
          room_roster.dup
        end

        # Looks up a registered instance by id.
        #
        # @param id [Integer, String] server creature id.
        # @return [Object, nil]
        def [](id)
          instances[id.to_i]
        end

        # @return [Array<Object>] every registered instance.
        def all
          instances.values
        end

        # Clears all instances and the room roster (session reset).
        #
        # @return [void]
        def clear
          instances.clear
          clear_room
        end

        # Removes instances older than the given age.
        #
        # @param max_age_seconds [Integer] age cutoff in seconds.
        # @return [Integer] number of instances removed.
        def cleanup_old(max_age_seconds = 600)
          cutoff = Time.now - max_age_seconds
          removed = instances.select { |_id, instance| instance.created_at < cutoff }.size
          instances.reject! { |_id, instance| instance.created_at < cutoff }
          removed
        end

        # Configures registry limits.
        #
        # Every call resets omitted options to their defaults - max_size to 1000
        # and auto_register to true - so calling this with no arguments restores
        # all defaults. Facade callers (e.g. `Creature.configure(**options)`)
        # should pass every option they mean to keep.
        #
        # @param max_size [Integer] maximum number of retained instances.
        # @param auto_register [Boolean] whether {#register} creates instances.
        # @return [void]
        def configure(max_size: 1000, auto_register: true)
          @max_size = max_size
          @auto_register = auto_register
        end

        # @return [Boolean] whether auto-registration is enabled (default true).
        def auto_register?
          @auto_register = true if @auto_register.nil?
          @auto_register
        end

        # @return [Integer] configured maximum registry size (default 1000).
        def max_size
          @max_size ||= 1000
        end

        # @return [Integer] current number of retained instances.
        def size
          instances.size
        end

        # @return [Boolean] whether the registry is at capacity.
        def full?
          size >= max_size
        end

        # Returns attackable hostile creatures currently in the room.
        #
        # Room membership comes from the creature roster (fed by XML room-object
        # and `<crtrStatus>` events), not from any client last-selected-target
        # control, which can go stale after movement or death. `valid_target?`
        # (supplied by the game class) removes decoys/dead appendages and
        # `crtr_flag?(:hostile)` supplies structured hostility.
        #
        # @param filters [Array<String, Symbol>] optional ANDed status/classification filters.
        # @return [Array<Object>]
        def targets(*filters)
          candidates = room_roster
                       .filter_map { |id| self[id] }
                       .select { |c| c.valid_target? && c.crtr_flag?(:hostile) }
          apply_filters(candidates, filters)
        end

        # Returns all tracked creatures currently in the room.
        #
        # Unlike {#targets} this requires neither hostility nor target validity,
        # so it also serves dead creatures, looting and wound inspection.
        # Filters are ANDed and may name a status, a classification flag, or a
        # `not_` negation such as `:not_prone`; unknown filters match nothing.
        #
        # @param filters [Array<String, Symbol>] optional ANDed status/classification filters.
        # @return [Array<Object>]
        def in_room(*filters)
          candidates = room_roster.filter_map { |id| self[id] }
          apply_filters(candidates, filters)
        end

        # Toggles live echo of status, flag, and registration changes.
        #
        # @param level [Boolean, Symbol] false disables debug output; true or
        #   `:changes` reports changes only; `:all` reports every `<crtrStatus>`
        #   flag; `:active` reports only active `<crtrStatus>` flags.
        # @return [Boolean, Symbol] the configured debug value.
        def debug_on(level = :changes)
          $creature_debug = level
        end

        private

        # Applies status/classification filters to a candidate list.
        #
        # @param candidates [Array<Object>] initial creature list.
        # @param filters [Array<String, Symbol>] filter names, optionally prefixed with `not_`.
        # @return [Array<Object>]
        def apply_filters(candidates, filters)
          filters.each do |filter|
            negate = filter.to_s.start_with?('not_')
            key = negate ? filter.to_s.delete_prefix('not_') : filter.to_s

            # Unknown filters match nothing, per the documented contract. Without
            # this guard a negated unknown filter (e.g. a typo like :not_prnoe)
            # inverts "matches nothing" into "matches everything", silently
            # widening a query instead of narrowing it. Filters are ANDed, so an
            # unknown one collapses the whole result to empty.
            return [] unless known_flag?(key)

            candidates = candidates.select { |c| c.flag_active?(key) != negate }
          end
          candidates
        end

        # Whether a filter name (with any `not_` prefix already removed) is part
        # of the recognized filter vocabulary. See {CreatureBase::KNOWN_FLAG_NAMES}.
        #
        # @param key [String, Symbol] filter name without its `not_` prefix.
        # @return [Boolean]
        def known_flag?(key)
          KNOWN_FLAG_NAMES.include?(key.to_s)
        end

        # The backing store of id => instance.
        #
        # @return [Hash{Integer=>Object}]
        def instances
          @instances ||= {}
        end

        # The live current-room roster. Mutated in place by {#mark_in_room} and
        # replaced wholesale by {#clear_room}; {#current_room_ids} hands callers a
        # copy so this array never escapes to be mutated from outside.
        #
        # @return [Array<Integer>]
        def room_roster
          @current_room_ids ||= []
        end
      end

      # Per-instance transient status and classification tracking driven by the
      # `<crtrStatus>` feed. The host class must call
      # {#initialize_status_tracking} from its own `initialize` and expose
      # `@name`/`@id` (used only for debug headers).
      module InstanceMethods
        # Initializes the tracking ivars. Call from the host class `initialize`.
        #
        # @return [void]
        def initialize_status_tracking
          @status = []
          @status_timestamps = {}
          @crtr_flags = {}
        end

        # Adds a status to the creature.
        #
        # Normalizes to String so callers can pass symbols from message-based
        # status parsing or strings from `<crtrStatus>`; both sources then land
        # in the same status entries and match {#has_status?}.
        #
        # @param status [String, Symbol] canonical status name.
        # @param duration [Integer, nil] optional expiration duration in seconds;
        #   falls back to {STATUS_DURATIONS} when omitted.
        # @return [void]
        def add_status(status, duration = nil)
          # Canonicalize case at the boundary, not per producer: the crit
          # tables report position as "PRONE"/"KNEELING"/"SITTING" while
          # messaging and <crtrStatus> use lowercase, and @status membership
          # is exact - an uppercase add could never be removed or matched.
          status = status.to_s.downcase
          if @status.include?(status)
            # Re-adding with an explicit duration extends the lock: without
            # this, a 3s roundtime followed by an overlapping 20s one kept
            # the 3s expiry and reported the creature free ~19s early.
            # Never shorten - the longest known source wins.
            if duration
              expires = Time.now + duration
              current = @status_timestamps[status]
              @status_timestamps[status] = expires if current.nil? || expires > current
            end
            return
          end

          @status << status

          duration ||= STATUS_DURATIONS[status]
          if duration
            @status_timestamps[status] = Time.now + duration
            debug_log("+status: #{status} (expires in #{duration}s)")
          else
            debug_log("+status: #{status} (no auto-expiry)")
          end
        end

        # Removes a status from the creature.
        #
        # @param status [String, Symbol] canonical status name.
        # @return [void]
        def remove_status(status)
          status = status.to_s.downcase
          @status.delete(status)
          @status_timestamps.delete(status)
          # A stun removal (message or <crtrStatus> snapshot) is authoritative
          # and retires any crit-table duration estimate with it, however much
          # time that estimate had left. GemStone-only hook.
          clear_stun_estimate if status == 'stunned' && respond_to?(:clear_stun_estimate)
          debug_log("-status: #{status}")
        end

        # Drops any timed statuses whose expiry has passed.
        #
        # @return [void]
        def cleanup_expired_statuses
          return unless @status_timestamps && !@status_timestamps.empty?

          now = Time.now
          @status_timestamps.select { |_status, expires_at| expires_at <= now }.keys.each do |expired_status|
            @status.delete(expired_status)
            @status_timestamps.delete(expired_status)
            debug_log("~status: #{expired_status} (auto-expired)")
          end
        end

        # Checks whether a specific status is active (after expiring stale ones).
        #
        # @param status [String, Symbol] canonical status name.
        # @return [Boolean]
        def has_status?(status)
          cleanup_expired_statuses
          @status.include?(status.to_s.downcase)
        end

        # Returns a copy of the currently-active statuses (after expiry).
        #
        # @return [Array<String>]
        def statuses
          cleanup_expired_statuses
          @status.dup
        end

        # Reconciles status and classification from a `<crtrStatus>` tag.
        #
        # The tag is a full snapshot of what is currently active, not a delta. A
        # missing flag, or a flag set to "0", means inactive even if it was
        # active a moment ago, so absent known flags are cleared rather than
        # ignored.
        #
        # @param attrs [Hash{String=>String}] XML attributes excluding `exist`.
        # @return [void]
        def sync_crtr_status(attrs)
          # Scoped to CRTR_STATUS_FLAGS on purpose: @status has two writers,
          # this feed and the combat parser reading messaging. The feed is a
          # full snapshot only of the states it reports, so it owns removal
          # for exactly those - and must not touch the rest. blind,
          # poisoned, natures_decay and the other message-only effects never
          # appear in the tag; reconciling them here would clear them on the
          # next one and make them impossible to model.
          CRTR_STATUS_FLAGS.each do |xml_name, status|
            if attrs[xml_name] == '1'
              add_status(status)
            elsif @status.include?(status)
              remove_status(status)
            end
          end

          CRTR_CLASSIFICATION_FLAGS.each do |xml_name, key|
            new_value = (attrs[xml_name] == '1')
            debug_log("~flag: #{key}=#{new_value}") if debug_level == :changes && @crtr_flags[key] != new_value
            @crtr_flags[key] = new_value
          end

          report_crtr_snapshot(attrs) if %i[all active].include?(debug_level)
        end

        # Checks a classification flag captured from `<crtrStatus>`.
        #
        # Unlike template tri-state facts, live XML flags are always-sent
        # booleans, so an unknown or unseen flag is false, not nil.
        #
        # @param key [String, Symbol] classification key, e.g. `:hostile`.
        # @return [Boolean]
        def crtr_flag?(key)
          @crtr_flags[key.to_sym] || false
        end

        # Whether any `<crtrStatus>` classification has been seen for this
        # creature yet.
        #
        # Callers filtering on a flag need to tell "the feed said this is not
        # hostile" apart from "the feed has not told us anything" - an absent
        # flag is unknown, not false. A ridden mount, for instance, carries a
        # bold creature link but never a `<crtrStatus>` of its own.
        #
        # @return [Boolean]
        def crtr_flags?
          !@crtr_flags.empty?
        end

        # Checks whether a status or classification flag is active.
        #
        # The two vocabularies are intentionally disjoint, so callers can filter
        # on any known flag name without caring which bucket stores it.
        #
        # @param key [String, Symbol] status or classification key.
        # @return [Boolean]
        def flag_active?(key)
          has_status?(key) || crtr_flag?(key)
        end

        private

        # Normalizes the configured creature debug level.
        #
        # @return [Symbol, false, nil] debug level; `true` normalizes to `:changes`.
        def debug_level
          $creature_debug == true ? :changes : $creature_debug
        end

        # Builds the prefix used for creature debug messages.
        #
        # @return [String]
        def debug_header
          "--- #{@name} (#{@id}):"
        end

        # Emits a creature debug message when creature debugging is enabled.
        #
        # @param message [String] message body.
        # @return [void]
        def debug_log(message)
          respond "#{debug_header} #{message}" if $creature_debug
        end

        # Emits a debug snapshot for a `<crtrStatus>` tag.
        #
        # `:all` reports every known flag; `:active` reports only true flags. The
        # snapshot reads straight from the tag attributes so it reflects exactly
        # what the feed sent, independent of how the mutation logic applies it.
        #
        # @param attrs [Hash{String=>String}] XML attributes excluding `exist`.
        # @return [void]
        def report_crtr_snapshot(attrs)
          flags = ALL_CRTR_FLAGS.map { |xml_name, key| [key, attrs[xml_name] == '1'] }
          flags = flags.select { |_, active| active } if debug_level == :active
          debug_log("crtrStatus: #{flags.map { |key, active| "#{key}=#{active}" }.join(', ')}")
        end
      end
    end
  end
end
