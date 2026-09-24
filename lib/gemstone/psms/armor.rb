# The root namespace for Lich scripting extensions.
module Lich
  # Namespace for Gemstone IV-specific modules and helpers.
  module Gemstone
    # Provides logic for detecting, checking, and using PSM3 armor techniques in GemStone IV.
    #
    # This module defines a registry of available armor-related abilities and wraps common queries
    # like whether a technique is known, affordable, or currently usable. It also provides the
    # `use` method to execute the appropriate command in-game, handling roundtime and feedback matching.
    #
    # Techniques are stored in a constant hash, and dynamic methods are defined for both long and short
    # names of each technique.
    #
    # Example:
    #   if Armor.available?("armor_blessing")
    #     Armor.use("armor_blessing")
    #   end
    module Armor
      # Mapping of armor technique identifiers to their associated data, including:
      # - short name
      # - usage command
      # - regex to match expected in-game output
      # - cost to use
      # - type of technique (buff, passive, etc.)
      #
      # @return [Hash<String, Hash>] A lookup table of armor techniques
      @@armor_techniques = {
        "armor_blessing"      => {
          :short_name => "blessing",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => /As \w+ prays? over \w+(?:'s)? [\w\s]+, you sense that (?:the Arkati's|a) blessing will be granted against magical attacks\./i,
          :usage      => "blessing"
        },
        "armor_reinforcement" => {
          :short_name => "reinforcement",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, reinforcing weak spots\./i,
          :usage      => "reinforcement"
        },
        "armor_spike_mastery" => {
          :short_name => "spikemastery",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Armor Spike Mastery is passive and always active once learned\./i,
          :usage      => "spikemastery"
        },
        "armor_support"       => {
          :short_name => "support",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, improving its ability to support the weight of \w+ gear\./i,
          :usage      => "support"
        },
        "armored_casting"     => {
          :short_name => "casting",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, making it easier for \w+ to recover from failed spell casting\./i,
          :usage      => "casting"
        },
        "armored_evasion"     => {
          :short_name => "evasion",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, improving its comfort and maneuverability\./i,
          :usage      => "evasion"
        },
        "armored_fluidity"    => {
          :short_name => "fluidity",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, making it easier for \w+ to cast spells\./i,
          :usage      => "fluidity"
        },
        "armored_stealth"     => {
          :short_name => "stealth",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => /\w+ adjusts? \w+(?:'s)? [\w\s]+ to cushion \w+ movements\./i,
          :usage      => "stealth"
        },
        "crush_protection"    => {
          :short_name => "crush",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => Regexp.union(
            /You adjust \w+(?:'s)? [\w\s]+ with your (?:cloth|leather|scale|chain|plate|accessory) armor fittings, rearranging and reinforcing the armor to better protect against crushing damage\./i,
            /You must specify an armor slot\./,
            /You don't seem to have the necessary armor fittings in hand\./
          ),
          :usage      => "crush"
        },
        "puncture_protection" => {
          :short_name => "puncture",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => Regexp.union(
            /You adjust \w+(?:'s)? [\w\s]+ with your (?:cloth|leather|scale|chain|plate|accessory) armor fittings, rearranging and reinforcing the armor to better protect against puncturing damage\./i,
            /You must specify an armor slot\./,
            /You don't seem to have the necessary armor fittings in hand\./
          ),
          :usage      => "puncture"
        },
        "slash_protection"    => {
          :short_name => "slash",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => Regexp.union(
            /You adjust \w+(?:'s)? [\w\s]+ with your (?:cloth|leather|scale|chain|plate|accessory) armor fittings, rearranging and reinforcing the armor to better protect against slashing damage\./i,
            /You must specify an armor slot\./,
            /You don't seem to have the necessary armor fittings in hand\./
          ),
          :usage      => "slash"
        }
      }

      extend PSMS::Technique
      techniques @@armor_techniques, type: "Armor", verb: "armor"

      # The refusal when the target wears no armor to work with.
      NOT_WEARING_ARMOR = /^\w+ [a-z]+ not wearing any armor that you can work with\.$/

      # The lines {Armor.use} waits on, including the no-armor refusal.
      #
      # @see PSMS::Technique#results_regex
      def Armor.results_regex(name, results_of_interest: nil)
        super(name, results_of_interest: Regexp.union(*[NOT_WEARING_ARMOR, results_of_interest].grep(Regexp)))
      end
    end
  end
end
