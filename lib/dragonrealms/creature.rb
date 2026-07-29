# frozen_string_literal: true

# =============================================================================
# dragonrealms/creature.rb
#
# DragonRealms runtime creature tracking, built on the shared
# {Lich::Common::CreatureBase} mixin (see lib/common/creature/creature_base.rb).
#
# DragonRealms delivers creature information across three streams, unlike
# GemStone's single structured room-object tag:
#
#   * `<crtrStatus exist="..." hostile="1" immobile="1"/>` - an id-keyed, full
#     snapshot of combat status and classification flags. Emitted automatically
#     with room refreshes, but *name-less* and batched after the room-objs
#     component closes.
#   * room-objs bold text (`<pushBold/>a jeol moradu<popBold/>`) - names only,
#     with no `exist` id (consumed separately by DRRoom; not used here).
#   * the `assess` combat stream (`<d cmd='look #NNN'>A jeol moradu</d>
#     (1: ...) is behind you at melee range`) - the only feed that ties an
#     `exist` id to a name, plus assess number, relation and range.
#
# So {CreatureInstance}s are created id-first from `<crtrStatus>` (flags, no
# name) and have their name/position/range backfilled from `assess` via
# {CreatureInstance#feed_assess}. The XML parser drives both paths (see
# lib/common/xmlparser.rb).
#
# This layer is additive: it does not touch DRRoom or the name-string roster the
# existing DragonRealms scripts rely on.
# =============================================================================

require_relative '../common/creature/creature_base'
require_relative 'drinfomon/drvariables' # DR_BALANCE_VALUES (assess balance parsing)

module Lich
  module DragonRealms
    # A single DragonRealms creature, keyed by its server `exist` id.
    #
    # Shares its registry, room roster and `<crtrStatus>` flag handling with
    # GemStone through {Lich::Common::CreatureBase}; the DragonRealms-specific
    # layer adds the `assess`-stream backfill (name, assess number, relation,
    # range) and a DragonRealms `valid_target?` rule.
    class CreatureInstance
      include Lich::Common::CreatureBase

      # @return [Integer] server creature id.
      attr_reader :id
      # @return [String, nil] attack noun (the trailing word of the name),
      #   derived whenever a name is set; nil until then.
      attr_reader :noun
      # @return [String, nil] display name; nil until a room-objs backfill or an
      #   `assess` tie-in supplies one.
      attr_accessor :name
      # @return [Time] when this instance was first registered.
      attr_reader :created_at
      # @return [Integer, nil] the `assess` list number (1-based), if seen.
      attr_reader :assess_number
      # @return [String, nil] the `assess` relation phrase, e.g. "behind you".
      attr_reader :relation
      # @return [String, nil] the `assess` parenthetical status, e.g.
      #   "cursed and solidly balanced".
      attr_reader :assess_status
      # @return [Symbol, nil] `assess` range bucket: `:melee`, `:pole` or `:missile`.
      attr_reader :range
      # @return [String, nil] id of the creature/PC this one is engaging, from `assess`.
      attr_reader :target_id
      # @return [String, nil] name of the creature/PC this one is engaging, from
      #   `assess` (e.g. "you", "Holdigor", "a plague spawn").
      attr_reader :target
      # @return [Integer, nil] the engaged target's `assess` list number, if any.
      attr_reader :target_number
      # @return [String, nil] balance descriptor parsed from the `assess`
      #   parenthetical, one of DR_BALANCE_VALUES (e.g. "solidly", "off"). nil
      #   until an assess with a balance phrase arrives. See #off_balance?.
      attr_reader :balance
      # @return [Array<String>] afflictions parsed from the `assess` parenthetical
      #   that crtrStatus does NOT carry (e.g. ["cursed"]); [] when none/unseen.
      #   crtrStatus states (prone/sleeping/stunned/...) live in crtr_flag?, not here.
      attr_reader :conditions
      # @return [Time, nil] when assess enrichment last landed for this id; nil
      #   until first assess. See #enriched?. Assess fields (range/balance/
      #   conditions/relation/target) are "pull" snapshots and can go stale -
      #   poll assess before relying on one.
      attr_reader :enriched_at

      # @param id [Integer, String] server creature id.
      # @param noun [String, nil] noun, when available.
      # @param name [String, nil] display name, when already known.
      def initialize(id, noun, name)
        @id = id.to_i
        @noun = noun
        @name = name
        @created_at = Time.now
        @assess_number = nil
        @relation = nil
        @assess_status = nil
        @range = nil
        @target_id = nil
        @target = nil
        @target_number = nil
        @balance = nil
        @conditions = []
        @enriched_at = nil
        # The assess stream is the authoritative id<->name tie; once it names a
        # creature, the room-objs backfill must not overwrite it (see
        # #apply_room_name). Room-objs may still supply a name first, before any
        # assess has run.
        @name_from_assess = false
        initialize_status_tracking
      end

      # Backfills name and positional data from a parsed `assess` entry.
      #
      # `<crtrStatus>` registers a creature id-first with no name, so this is how
      # DragonRealms learns which name/relation/range belongs to that id. The
      # `assess` feed capitalizes the subject ("A jeol moradu"); the name is
      # downcased to match the room-objs vocabulary DragonRealms scripts expect.
      #
      # @param entry [Hash] an entry from `XMLData.parse_assess_line`, with keys
      #   `:name`, `:number`, `:status`, `:relation`, `:range`, `:target_id`.
      # @return [void]
      def feed_assess(entry)
        if entry[:name]
          @name = entry[:name].to_s.downcase
          @noun = derive_noun(@name)
          # Authoritative from here on: subsequent room-objs backfills no-op.
          @name_from_assess = true
        end
        @assess_number = entry[:number]
        @assess_status = entry[:status]
        @balance, @conditions = parse_assess_status(entry[:status])
        @relation = entry[:relation]
        @range = entry[:range]
        @target_id = entry[:target_id]
        @target = entry[:target]
        @target_number = entry[:target_number]
        @enriched_at = Time.now
      end

      # Applies a name learned from the room-objs stream, and derives the attack
      # noun from it.
      #
      # Two producers call this, both via the XML parser: the stream-order
      # backfill that pairs the Nth bold room-objs name with the Nth
      # `<crtrStatus>` id, and (future-proofing) a GemStone-style
      # `<a exist noun>` room-objs tag if DragonRealms ever emits one. The
      # `assess` stream is the authoritative id<->name tie, so once #feed_assess
      # has named the creature this is a no-op. A nil name (e.g. an out-of-range
      # positional lookup, the count-guard) is ignored, leaving any existing name
      # intact.
      #
      # @param name [String, nil] display name from the room-objs stream.
      # @return [void]
      def apply_room_name(name)
        return if name.nil? || @name_from_assess

        @name = name
        @noun = derive_noun(name)
      end

      # Whether this creature should be considered attackable.
      #
      # DragonRealms has no UCS or appendage decoys to exclude, so the rule is
      # simply "not confirmed dead by `<crtrStatus>`".
      #
      # @return [Boolean]
      def valid_target?
        !crtr_flag?(:dead)
      end

      # Whether any `assess` enrichment (range/balance/conditions/relation/target)
      # has landed for this id. These are "pull" snapshots -- poll assess before
      # relying on them, and see #enriched_at for staleness.
      #
      # @return [Boolean]
      def enriched?
        !@enriched_at.nil?
      end

      # Whether the creature is below "solidly balanced" per the last `assess`
      # (a softer target). False when balance is unknown.
      #
      # @return [Boolean]
      def off_balance?
        return false unless @balance

        idx = DR_BALANCE_VALUES.index(@balance)
        !idx.nil? && idx < DR_BALANCE_VALUES.index('solidly')
      end

      # Whether a given assess affliction is present (e.g. "cursed", "poisoned").
      #
      # @param name [String, Symbol]
      # @return [Boolean]
      def condition?(name)
        @conditions.include?(name.to_s)
      end

      # Convenience for the one affliction confirmed so far; use #condition? for
      # others until they are confirmed and given their own predicate.
      #
      # @return [Boolean]
      def cursed?
        condition?('cursed')
      end

      # Matches a DR_BALANCE_VALUES descriptor followed by "balance(d)" in an
      # assess parenthetical, e.g. "solidly balanced", "off balance". Built lazily
      # so DR_BALANCE_VALUES (loaded with drvariables) is present by first use;
      # union order (longest multi-word values first in the array) resolves
      # "somewhat off" ahead of "off".
      #
      # @return [Regexp]
      def self.balance_pattern
        @balance_pattern ||= /\b(#{Regexp.union(DR_BALANCE_VALUES)})\s+balanced?\b/i
      end

      private

      # Splits an `assess` parenthetical status into [balance, conditions].
      # Balance is the DR_BALANCE_VALUES descriptor before "balance(d)"; the rest
      # (afflictions joined by "and") becomes the conditions list.
      #
      # crtrStatus flag words that also appear in the parenthetical (e.g.
      # "immobile") are dropped from conditions: they are tracked fresh via
      # crtr_flag?/has_status? (a "push" source), whereas assess is a staleable
      # "pull" snapshot, so keeping them here would duplicate and could disagree.
      # Only assess-only afflictions (cursed, poisoned, ...) remain.
      #
      # @param status [String, nil] e.g. "immobile and slightly off balance".
      # @return [Array(String, Array<String>)] [balance_or_nil, conditions].
      def parse_assess_status(status)
        return [nil, []] if status.nil? || status.strip.empty?

        pattern = self.class.balance_pattern
        balance = status[pattern, 1]
        remainder = balance ? status.sub(pattern, '') : status
        conditions = remainder.split(/\s+and\s+|,/)
                              .map(&:strip)
                              .reject { |w| w.empty? || w == 'and' }
                              .reject { |w| Lich::Common::CreatureBase::ALL_CRTR_FLAGS.key?(w) }
        [balance, conditions]
      end

      # Extracts the attack noun (trailing word) from a display name, matching
      # DragonRealms' end-anchored creature-name convention (see
      # DRDefsPattern::CREATURE_NAME) so `noun` is a drop-in for `attack <noun>`
      # -- e.g. "a jeol moradu" -> "moradu".
      #
      # @param name [String, nil]
      # @return [String, nil]
      def derive_noun(name)
        name && name[/[A-Za-z'-]+$/]
      end
    end

    # Public Creature API for DragonRealms runtime creature tracking.
    #
    # Mirrors `Lich::Gemstone::Creature`: registry/roster/query operations
    # delegate to {CreatureInstance} (which carries the shared
    # {Lich::Common::CreatureBase} class methods), plus the two DragonRealms feed
    # entry points {sync} and {feed_assess} used by the XML parser.
    module Creature
      # Toggles live echo of status, flag, and registration changes.
      #
      # @param level [Boolean, Symbol] false disables debug output; true or
      #   `:changes` reports changes only; `:all` reports every `<crtrStatus>`
      #   flag; `:active` reports only active `<crtrStatus>` flags.
      # @return [Boolean, Symbol] the configured debug value.
      def self.debug_on(level = :changes)
        $creature_debug = level
      end

      # Applies a `<crtrStatus>` snapshot, registering the creature id-first if
      # it has not been seen yet.
      #
      # This is the automatic, name-less DragonRealms feed: it produces an
      # id-keyed hostile roster with flags before any `assess` has run.
      #
      # The optional `name` is the stream-order backfill: the XML parser pairs the
      # Nth bold room-objs name with the Nth `<crtrStatus>` in the batch and passes
      # it here, so creatures are named every refresh without waiting for `assess`.
      # It is applied via {CreatureInstance#apply_room_name} (assess still wins;
      # a nil name is ignored), and works whether the id is new or already known.
      #
      # @param id [Integer, String] server creature id (the tag's `exist`).
      # @param flags [Hash{String=>String}] tag attributes excluding `exist`.
      # @param name [String, nil] stream-order room-objs name for this id, if any.
      # @return [CreatureInstance, nil] the synced instance, or nil if disabled/full.
      def self.sync(id, flags, name = nil)
        instance = CreatureInstance.register(name, id)
        return nil unless instance

        instance.apply_room_name(name)
        instance.sync_crtr_status(flags)
        instance
      end

      # Backfills a creature from a parsed `assess` entry, registering it if the
      # id has not been seen yet.
      #
      # @param entry [Hash] a creature entry from `XMLData.parse_assess_line`.
      # @return [CreatureInstance, nil] the updated instance, or nil if disabled/full.
      def self.feed_assess(entry)
        id = entry[:id]
        return nil unless id

        instance = CreatureInstance.register(entry[:name], id)
        return nil unless instance

        instance.feed_assess(entry)
        instance
      end

      # Lookup creature instance by id.
      #
      # @param id [Integer, String] server creature id.
      # @return [CreatureInstance, nil]
      def self.[](id)
        CreatureInstance[id]
      end

      # Returns attackable hostile creatures currently in the room.
      #
      # @param filters [Array<String, Symbol>] optional ANDed status/classification filters.
      # @return [Array<CreatureInstance>]
      def self.targets(*filters)
        CreatureInstance.targets(*filters)
      end

      # Returns all tracked creatures currently in the room.
      #
      # @param filters [Array<String, Symbol>] optional ANDed status/classification filters.
      # @return [Array<CreatureInstance>]
      def self.in_room(*filters)
        CreatureInstance.in_room(*filters)
      end

      # Empties the current room roster.
      #
      # @return [void]
      def self.clear_room
        CreatureInstance.clear_room
      end

      # Registers a creature.
      #
      # @param name [String, nil] display name (may be nil for an id-first feed).
      # @param id [Integer, String] server creature id.
      # @param noun [String, nil] noun, when available.
      # @return [CreatureInstance, nil]
      def self.register(name, id, noun = nil)
        CreatureInstance.register(name, id, noun)
      end

      # Configures the registry.
      #
      # @return [void]
      def self.configure(**options)
        CreatureInstance.configure(**options)
      end

      # @return [Hash] registry statistics.
      def self.stats
        {
          instances: CreatureInstance.size,
          max_size: CreatureInstance.max_size,
          auto_register: CreatureInstance.auto_register?
        }
      end

      # Clears every instance and the room roster.
      #
      # @return [void]
      def self.clear
        CreatureInstance.clear
      end

      # Removes creatures older than the given age (in seconds).
      #
      # Positional to match {CreatureInstance#cleanup_old} (supplied by
      # {Lich::Common::CreatureBase}); a keyword-only signature would raise
      # ArgumentError against the positional base method.
      #
      # @param max_age_seconds [Integer] age cutoff in seconds.
      # @return [Integer] number of instances removed.
      def self.cleanup_old(max_age_seconds = 600)
        CreatureInstance.cleanup_old(max_age_seconds)
      end

      # @return [Array<CreatureInstance>] every registered instance.
      def self.all
        CreatureInstance.all
      end
    end
  end
end
