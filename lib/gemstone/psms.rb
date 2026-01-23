# Provides a unified interface for interacting with Player System Manager (PSM) skills
# in GemStone IV, such as Combat Maneuvers, Shield Specializations, Feats, Warcries,
# Weapon Techniques, and Armor Specializations.
#
# This module acts as a central registry and utility for:
# - Normalizing skill names for lookup.
# - Querying and validating available PSM skills by type.
# - Determining stamina costs and eligibility for use.
# - Evaluating the character's ability to perform forced roundtime actions.
# - Detecting common PSM failure responses using pattern matching.
#
# Each PSM category (e.g., `CMan`, `Shield`, `Feat`) is defined in its own file and loaded as a submodule.
#
# @example Check if a skill can be used with current stamina
#   PSMS.assess("bullrush", "CMan", true)
#
# @example Normalize a skill name for consistent lookup
#   PSMS.name_normal("Smash")
#
# @see Lich::Gemstone::CMan
# @see Lich::Gemstone::Shield
# @see Lich::Gemstone::Feat
# @see Lich::Gemstone::Weapon
# @see Lich::Gemstone::Armor
# @see Lich::Gemstone::Warcry
# @see Lich::Gemstone::Ascension

require "ostruct"

require_relative('./psms/armor.rb')
require_relative('./psms/cman.rb')
require_relative('./psms/feat.rb')
require_relative('./psms/shield.rb')
require_relative('./psms/weapon.rb')
require_relative('./psms/warcry.rb')
require_relative('./psms/ascension.rb')
require_relative('./psms/qstrike.rb')

module Lich
  module Gemstone
    module PSMS
      # Normalizes a name for internal lookup consistency.
      #
      # Converts the input string to a standardized format (e.g., downcased, underscored)
      # using `Lich::Util.normalize_name`.
      #
      # @param name [String] The name to normalize.
      # @return [String] The normalized name.
      #
      # @example
      #   PSMS.name_normal("Some Name")
      #   # => "some_name"
      def self.name_normal(name)
        Lich::Util.normalize_name(name)
      end

      # Finds a Player System Manager (PSM) skill by name within the specified category.
      #
      # This method searches for a PSM skill (such as a combat maneuver, armor skill, feat, etc.)
      # by matching the normalized `long_name` or `short_name` within the specified type's lookup table.
      #
      # @param name [String] The name of the PSM to find (normalized beforehand).
      # @param type [String] The category of the PSM (e.g., "Armor", "CMan", "Feat", "Shield", "Warcry", "Weapon").
      # @return [Hash, nil] A hash representing the PSM's attributes if found, or nil if not found.
      #
      # @example
      #   PSMS.find_name("feint", "CMan")
      #   # => { long_name: "combat_feint", short_name: "feint", cost: 10 }
      def self.find_name(name, type)
        name = self.name_normal(name)
        Object.const_get("Lich::Gemstone::#{type}").method("#{type.downcase}_lookups").call
              .find { |h| h[:long_name].eql?(name) || h[:short_name].eql?(name) }
      end

      # Assess the validity or cost of a given PSM (Player System Manager) skill.
      #
      # This method checks if a named PSM skill exists in a given category (`type`), and either:
      #   - Verifies if the character has enough stamina to use it (when `costcheck` is true),
      #   - Or retrieves the rank of the skill from Infomon (when `costcheck` is false).
      #
      # If the skill cannot be found, it logs an error and raises an exception to halt execution.
      #
      # @param name [String] The name of the PSM skill to assess.
      # @param type [String] The category of the PSM skill (e.g., "Armor", "CMan", "Feat", "Shield", "Warcry", "Weapon").
      # @param costcheck [Boolean] If true, check whether the character has enough stamina to use the skill.
      # @param forcert_count [Integer] Optional. Number of forced RT applications, affecting stamina cost calculation (default: 0).
      #
      # @return [Boolean, Object] Returns a boolean if `costcheck` is true (indicating stamina sufficiency),
      # or the Infomon rank of the skill otherwise.
      #
      # @raise [StandardError] If the skill name is invalid or not found in the given category.
      #
      # @example Check if a combat maneuver can be used with current stamina
      #   assess("feint", "CMan", true)
      #
      # @example Get the Infomon rank of a shield technique
      #   assess("bulwark", "Shield")
      #
      # @example Check if a feat can be used with current stamina, considering forced RT applications
      #   assess("shield bash", "Feat", true, forcert_count: 2)
      def self.assess(name, type, costcheck = false, forcert_count: 0)
        return false unless forcert_count <= max_forcert_count
        name = self.name_normal(name)
        seek_psm = self.find_name(name, type)
        # this logs then raises an exception to stop (kill) the offending script
        if seek_psm.nil?
          Lich.log("error: PSMS request: #{$!}\n\t")
          raise ArgumentError, "Aborting script - The referenced #{type} skill #{name} is invalid.\r\nCheck your PSM category (Armor, CMan, Feat, Shield, Warcry, Weapon) and your spelling of #{name}.", (caller.find { |call| call =~ /^#{Script.current.name}/ })
        end
        # otherwise process request
        case costcheck
        when true
          base_cost = seek_psm[:cost]
          base_cost.each do |cost_type, cost_amount|
            if forcert_count > 0
              return false unless (cost_amount + (cost_amount * ((25 + (10.0 * forcert_count)) / 100))).truncate < XMLData.public_send(cost_type)
            else
              return false unless cost_amount < XMLData.public_send(cost_type)
            end
          end
          return true
        else
          Infomon.get("#{type.downcase}.#{seek_psm[:short_name]}")
        end
      end

      # Determines if a given PSM skill is available for use (not in cooldown, and not overexerted).
      #
      # This method checks if the skill is not listed in the cooldowns or debuffs (specifically "Overexerted").
      # It uses the `Lich::Util.normalize_lookup` method to check for the skill's presence in these lists.
      #
      # @param name [String] The name of the PSM skill to check.
      # @return [Boolean] True if the skill is available (not in cooldown or overexerted), false otherwise.
      #
      # @example Check if a combat maneuver is available
      #   PSMS.available?("bullrush")
      #   # => true (if not in cooldown or overexerted)
      #
      # @example Check if a shield technique is available
      #   PSMS.available?("bulwark")
      #   # => false (if in cooldown or overexerted)
      def self.available?(name, ignore_cooldown = false)
        return false if Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
        return false if Lich::Util.normalize_lookup('Cooldowns', name) unless ignore_cooldown
        return true
      end

      # Determines whether the character is eligible to perform the given number of forced roundtime (forcert) rounds.
      #
      # This method checks if the character's Multi-Opponent Combat (MOC) training allows at least
      # the specified number of forcert rounds, based on the result of {PSMS.max_forcert_count}.
      #
      # @param times [Integer] The number of forcert rounds to check eligibility for.
      # @return [Boolean] True if the character can perform at least the given number of forcert rounds, false otherwise.
      #
      # @example Check if the character can perform 2 forcert rounds
      #   PSMS.can_forcert?(2)
      #   # => true  (if MOC ranks are 35 or higher)
      def self.can_forcert?(times)
        max_forcert_count >= times
      end

      # Determines the maximum number of forced roundtime (forcert) activations
      # allowed based on the character's Multi-Opponent Combat (MOC) training.
      #
      # The number of forcert rounds scales with ranks in MOC as follows:
      #   - 0–9 ranks:     0 forcert rounds
      #   - 10–34 ranks:   1 forcert round
      #   - 35–74 ranks:   2 forcert rounds
      #   - 75–124 ranks:  3 forcert rounds
      #   - 125+ ranks:    4 forcert rounds
      #
      # @return [Integer] The maximum number of forcert rounds the character can perform.
      #
      # @example
      #   PSMS.max_forcert_count
      #   # => 3  (for a character with 100 MOC ranks)
      def self.max_forcert_count
        case Skills.multi_opponent_combat
        when 0..9
          0
        when 10..34
          1
        when 35..74
          2
        when 75..124
          3
        else # 125+
          4
        end
      end

      # A compiled regular expression used to match common failure messages across all PSM (Player System Manager) actions.
      #
      # This constant combines several game-generated failure messages into a single `Regexp` using `Regexp.union`,
      # allowing centralized pattern matching for detecting failed actions.
      #
      # Useful for interpreting command results and handling expected failure states in scripting logic.  Note that
      # in most cases, the match on a failure message here is not considered an error, but rather that the command
      # succeeded, but the action itself failed for some reason.
      #
      # @return [Regexp] A union of common failure message patterns.
      #
      # @example
      #   if PSMS::FAILURES_REGEXES.match?(response)
      #     respond "Action failed: #{response}"
      #   end
      FAILURES_REGEXES = Regexp.union(
        /^And give yourself away!  Never!$/,
        /^You are unable to do that right now\.$/,
        /^You don't seem to be able to move to do that\.$/,
        /^Provoking a GameMaster is not such a good idea\.$/,
        /^You do not currently have a target\.$/,
        /^Your mind clouds with confusion and you glance around uncertainly\.$/,
        /^But your hands are full\!$/,
        /^You are still stunned\.$/,
        /^You lack the momentum to attempt another skill\.$/,
      )
    end
  end
end
