# frozen_string_literal: true

module Lich
  module Common
    # The script-facing `Creature` module both games expose over their creature
    # registry, composed like {CreatureBase} (and lib/common/map): the shared
    # surface lives here, and each game's `module Creature` extends it, names its
    # registry class with `instance_class`, and adds or overrides only what
    # differs for that game.
    #
    # @example
    #   module Creature
    #     extend Lich::Common::CreatureFacade
    #     def self.instance_class = CreatureInstance
    #   end
    module CreatureFacade
      # Toggles live echo of status, flag, and registration changes.
      #
      # @param level [Boolean, Symbol] false disables debug output; true or
      #   `:changes` reports changes only; `:all` reports every `<crtrStatus>`
      #   flag; `:active` reports only active `<crtrStatus>` flags.
      # @return [Boolean, Symbol] the configured debug value.
      def debug_on(level = :changes)
        $creature_debug = level
      end

      # Lookup creature instance by id.
      #
      # @param id [Integer, String] server creature id.
      # @return [Object, nil] the game's creature instance
      def [](id)
        instance_class[id]
      end

      # Returns attackable hostile creatures currently in the room, including
      # once-hostile creatures now `sympathetic` (Sympathy 1120). Pass
      # `:not_sympathetic` to exclude those.
      #
      # @param filters [Array<String, Symbol>] optional ANDed status/classification filters.
      # @return [Array]
      def targets(*filters)
        instance_class.targets(*filters)
      end

      # Returns all tracked creatures currently in the room.
      #
      # @param filters [Array<String, Symbol>] optional ANDed status/classification filters.
      # @return [Array]
      def in_room(*filters)
        instance_class.in_room(*filters)
      end

      # Empties the current room roster.
      #
      # @return [void]
      def clear_room
        instance_class.clear_room
      end

      # Registers a creature.
      #
      # @param name [String, nil] display name (may be nil for an id-first feed).
      # @param id [Integer, String] server creature id.
      # @param noun [String, nil] noun, when available.
      # @return [Object, nil] the registered instance, or nil when
      #   auto-registration is disabled or the registry is full.
      def register(name, id, noun = nil)
        instance_class.register(name, id, noun)
      end

      # Configures the registry.
      #
      # @return [void]
      def configure(**options)
        instance_class.configure(**options)
      end

      # @return [Hash] registry statistics.
      def stats
        {
          instances: instance_class.size,
          max_size: instance_class.max_size,
          auto_register: instance_class.auto_register?,
          cleanup_max_age: instance_class.cleanup_max_age
        }
      end

      # Clears every instance and the room roster.
      #
      # @return [void]
      def clear
        instance_class.clear
      end

      # Removes creatures unseen for longer than the given age (in seconds).
      #
      # Positional to match {CreatureBase} `cleanup_old`; a keyword-only
      # signature would raise ArgumentError against the positional base method.
      # The registry also sweeps itself on a wall-clock throttle from
      # `register`; this is for scripts that want an immediate sweep.
      #
      # @param max_age_seconds [Integer] age cutoff in seconds; defaults to
      #   the configured cleanup_max_age.
      # @return [Integer] number of instances removed.
      def cleanup_old(max_age_seconds = instance_class.cleanup_max_age)
        instance_class.cleanup_old(max_age_seconds)
      end

      # @return [Array] every registered instance.
      def all
        instance_class.all
      end
    end
  end
end
