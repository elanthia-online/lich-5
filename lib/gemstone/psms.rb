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

require_relative('./psms/technique.rb')
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
        seek_psm = self.find_name(name, type) || invalid_technique!(name, type)
        if costcheck
          category = Object.const_get("Lich::Gemstone::#{type}")
          cost_affordable?(category.respond_to?(:cost) ? category.cost(name) : seek_psm[:cost], forcert_count: forcert_count)
        else
          Infomon.get("#{type.downcase}.#{seek_psm[:short_name]}")
        end
      end

      # Logs and raises for a technique name that is not in its category, which
      # stops (kills) the offending script.
      #
      # @param name [String] the normalized technique name
      # @param type [String] the category ("CMan", "Shield", ...)
      # @raise [ArgumentError] always
      def self.invalid_technique!(name, type)
        Lich.log("error: PSMS request: invalid #{type} skill #{name}\n\t")
        raise ArgumentError, "Aborting script - The referenced #{type} skill #{name} is invalid.\r\nCheck your PSM category (Armor, CMan, Feat, Shield, Warcry, Weapon) and your spelling of #{name}.", (caller.find { |call| call =~ /^#{Script.current.name}/ })
      end

      # Whether current stamina (or other resource) covers a cost, with the
      # FORCERT surcharge of 25% plus 10% per FORCERT when any are used.
      #
      # @param cost [Hash] e.g. { stamina: 20 }, keyed by XMLData resource
      # @param forcert_count [Integer] FORCERTs used, including this one
      # @return [Boolean]
      def self.cost_affordable?(cost, forcert_count: 0)
        return false unless forcert_count <= max_forcert_count

        cost.all? do |cost_type, cost_amount|
          cost_amount = (cost_amount + (cost_amount * ((25 + (10.0 * forcert_count)) / 100))).truncate if forcert_count > 0
          cost_amount < XMLData.public_send(cost_type)
        end
      end

      # Determines if a given PSM skill is available for use (not in cooldown, and not overexerted).
      #
      # @param name [String] The name of the PSM skill to check.
      # @param ignore_cooldown [Boolean] Skip the cooldown check (default: false)
      # @return [Boolean] True if the skill is available (not in cooldown or overexerted), false otherwise.
      #
      # @example Check if a combat maneuver is available
      #   PSMS.available?("bull_rush")
      #   # => true (if not in cooldown or overexerted)
      def self.available?(name, ignore_cooldown = false)
        return false if effect_active?(Effects::Debuffs, 'Overexerted')
        return false if !ignore_cooldown && effect_active?(Effects::Cooldowns, name)
        return true
      end

      # Whether an unexpired effect is listed in an Effects registry. A String
      # matches regardless of case, spacing, underscores, colons and apostrophes
      # ("seanettes_shout" matches "Seanette's Shout"); a Regexp matches any entry.
      #
      # @param registry [Effects::Registry] Effects::Buffs, Effects::Cooldowns, ...
      # @param effect [String, Symbol, Regexp] the effect name or pattern
      # @return [Boolean]
      def self.effect_active?(registry, effect)
        now = Time.now.to_f
        wanted = effect.is_a?(Regexp) ? effect : name_normal(effect)
        registry.to_h.any? do |key, expiry|
          next false unless expiry.to_f > now

          wanted.is_a?(Regexp) ? wanted.match?(key.to_s) : name_normal(key) == wanted
        end
      end

      # Whether a technique target names a single creature or character, as
      # opposed to none (the character, or the room) or ALL.
      #
      # @param target [String, Integer, GameObj, nil]
      # @return [Boolean]
      def self.single_target?(target)
        return true if target.is_a?(GameObj) || target.is_a?(Integer)

        !target.to_s.strip.empty? && !target.to_s.strip.casecmp?('all')
      end

      # Whether MSTRIKE can be used right now: enough Multi Opponent Combat
      # training (5 ranks open, 30 focused), not overexerted, and enough stamina
      # for its cost while it is in recovery.
      #
      # @param focused [Boolean] a focused (single target) strike, else open
      # @return [Boolean]
      def self.mstrike_available?(focused: false)
        return false if Skills.multi_opponent_combat < (focused ? 30 : 5)
        return false if effect_active?(Effects::Debuffs, 'Overexerted')

        cost_affordable?({ stamina: QStrike.mstrike_cost(focused: focused) })
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
      #   - 0-9 ranks:     0 forcert rounds
      #   - 10-34 ranks:   1 forcert round
      #   - 35-74 ranks:   2 forcert rounds
      #   - 75-124 ranks:  3 forcert rounds
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
        /^You can't reach .+!$/,
        / attempting to .+ would be a rather awkward proposition\.$/,
      )

      # The command a technique is sent with, as each category's +use+ sends
      # it: the verb, the technique's usage word, an optional target, and
      # FORCERT. Exposed so a script that sends and confirms on its own
      # terms (an engine with its own roundtime and timeout discipline)
      # still gets the exact command +use+ would send.
      #
      # @param verb [String, nil] "cman", "shield", ... or nil for a bare command (FEAT GUARD)
      # @param usage [String] the technique's usage word
      # @param target [String, Integer, GameObj] a GameObj or id is sent as #id; a String as given
      # @param forcert_count [Integer] more than 0 appends FORCERT
      # @return [String]
      #
      # @example
      #   PSMS.command("cman", "bullrush", GameObj.targets.first)  # => "cman bullrush #12345"
      def self.command(verb, usage, target = "", forcert_count: 0)
        cmd = verb.nil? || verb.to_s.empty? ? usage.to_s : "#{verb} #{usage}"
        if target.is_a?(GameObj)
          cmd += " ##{target.id}"
        elsif target.is_a?(Integer)
          cmd += " ##{target}"
        elsif target.to_s != ""
          cmd += " #{target}"
        end
        cmd += " forcert" if forcert_count > 0
        cmd
      end

      # Every line that answers a technique command: the shared failures, the
      # "X what?" and cooldown refusals for this technique, its own result
      # messaging, and any extra patterns. This is the regex each category's
      # +use+ waits on, so a caller confirming the command itself matches the
      # same lines +use+ would.
      #
      # @param name [String] the technique name as the caller gave it
      # @param patterns [Array<Regexp, nil>] the technique's result regex and friends; nils are skipped
      # @param results_of_interest [Regexp, nil] extra lines the caller wants to see
      # @return [Regexp]
      def self.results_regex(name, *patterns, results_of_interest: nil)
        parts = [FAILURES_REGEXES, WAIT_REGEX, /^#{name} what\?$/i, /^#{name} is still in cooldown\./i]
        parts.concat(patterns.compact)
        parts << results_of_interest if results_of_interest.is_a?(Regexp)
        Regexp.union(*parts)
      end

      # The roundtime line most techniques answer with.
      ROUNDTIME_REGEX = /^Roundtime: [0-9]+ sec\.$/

      # The refusal for a command sent while still in roundtime.
      WAIT_REGEX = /^(?:\.\.\.w|W)ait \d+ sec(?:onds?)?\.$/

      # Sends a technique command and waits for its answer, sending it again
      # after a "...wait" (roundtime the client had not seen yet) or once the
      # character recovers from "You don't seem to be able to move to do that."
      #
      # @param usage_cmd [String] the command, e.g. from {PSMS.command}
      # @param results_regex [Regexp] the lines that answer it, e.g. from {PSMS.results_regex}
      # @param timeout [Numeric] seconds to wait for each answer
      # @param attempts [Integer] the most times to send the command
      # @return [String, false] the answering line, or false on timeout
      def self.dispatch(usage_cmd, results_regex, timeout: 5, attempts: 3)
        usage_result = false
        attempts.times do
          usage_result = dothistimeout(usage_cmd, timeout, results_regex)
          if usage_result == "You don't seem to be able to move to do that."
            100.times { break if clear.any? { |line| line =~ /^You regain control of your senses!$/ }; sleep 0.1 }
          elsif usage_result.is_a?(String) && WAIT_REGEX.match?(usage_result)
            waitrt?
            waitcastrt?
          else
            break
          end
        end
        usage_result
      end
    end
  end
end
