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
      # @return [String, nil] noun, when a feed supplies one (usually nil in DR).
      attr_reader :noun
      # @return [String, nil] display name; nil until an `assess` tie-in arrives.
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
        @name = entry[:name].to_s.downcase if entry[:name]
        @assess_number = entry[:number]
        @assess_status = entry[:status]
        @relation = entry[:relation]
        @range = entry[:range]
        @target_id = entry[:target_id]
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
      # @param id [Integer, String] server creature id (the tag's `exist`).
      # @param flags [Hash{String=>String}] tag attributes excluding `exist`.
      # @return [CreatureInstance, nil] the synced instance, or nil if disabled/full.
      def self.sync(id, flags)
        instance = CreatureInstance.register(nil, id)
        return nil unless instance

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
