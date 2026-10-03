# The root namespace for all Lich scripting components.
module Lich
  # Namespace for GemStone IV-specific modules.
  module Gemstone
    # Provides logic for shield-based PSM techniques in GemStone IV.
    #
    # This module defines metadata for each known shield technique, including passive and active skills,
    # usage commands, costs, and expected success message regexes. It offers methods for checking whether
    # a technique is known, affordable, or currently available, and for attempting to use a technique.
    #
    # Dynamic shortcut methods are also defined for each shield technique using both long and short names.
    module Shield
      # Internal registry of all shield techniques and their metadata.
      #
      # @return [Hash<String, Hash>] Each key is a long name and maps to:
      #   - `:short_name` [String] shorthand reference
      #   - `:type` [String, nil] type of skill (e.g., passive, stance)
      #   - `:cost` [Integer] stamina cost
      #   - `:regex` [Regexp] expected in-game output
      #   - `:usage` [String, nil] usage string if applicable
      @@shield_techniques = {
        "adamantine_bulwark"    => {
          :short_name => "bulwark",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Adamantine Bulwark does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "block_specialization"  => {
          :short_name => "blockspec",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /The Block Specialization combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "block_the_elements"    => {
          :short_name => "blockelements",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Block the Elements does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "deflect_magic"         => {
          :short_name => "deflectmagic",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Deflect Magic does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil
        },
        "deflect_missiles"      => {
          :short_name => "deflectmissiles",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Deflect Missiles does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil
        },
        "deflect_the_elements"  => {
          :short_name => "deflectelements",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Deflect the Elements does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "disarming_presence"    => {
          :short_name => "dpresence",
          :type       => :martial_stance,
          :cost       => { stamina: 20 },
          :regex      => Regexp.union(/You assume the Disarming Presence Stance, adjusting your footing and grip to allow for the proper pivot and thrust technique to disarm attacking foes\./,
                                      /You re\-settle into the Disarming Presence Stance, re-ensuring your footing and grip are properly positioned\./),
          :usage      => "dpresence"
        },
        "guard_mastery"         => {
          :short_name => "gmastery",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Guard Mastery does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "large_shield_focus"    => {
          :short_name => "lfocus",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Large Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "medium_shield_focus"   => {
          :short_name => "mfocus",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Medium Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "phalanx"               => {
          :short_name => "phalanx",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Phalanx does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "prop_up"               => {
          :short_name => "prop",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Prop Up does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil
        },
        "protective_wall"       => {
          :short_name => "pwall",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Protective Wall does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "shield_bash"           => {
          :short_name => "bash",
          :type       => :setup,
          :cost       => { stamina: 9 },
          :regex      => /You lunge forward at .+ with your .+ and attempt a shield bash\!/,
          :usage      => "bash"
        },
        "shield_charge"         => {
          :short_name => "charge",
          :type       => :setup,
          :cost       => { stamina: 14 },
          :regex      => /You charge forward at .+ with your .+ and attempt a shield charge\!/,
          :usage      => "charge"
        },
        "shield_forward"        => {
          :short_name => "forward",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Shield Forward does not need to be activated once you have learned it\.  It will automatically activate upon the use of a shield attack\./,
          :usage      => "forward"
        },
        "shield_mind"           => {
          :short_name => "mind",
          :type       => :buff,
          :cost       => { stamina: 10 },
          :regex      => /You must be wielding an ensorcelled or anti-magical shield to be able to properly shield your mind and soul\./,
          :usage      => "mind"
        },
        "shield_pin"            => {
          :short_name => "pin",
          :type       => :attack,
          :cost       => { stamina: 15 },
          :regex      => /You attempt to expose a vulnerability with a diversionary shield bash on .+\!/,
          :usage      => "pin"
        },
        "shield_push"           => {
          :short_name => "push",
          :type       => :setup,
          :cost       => { stamina: 7 },
          :regex      => /You raise your .+ before you and attempt to push .+ away\!/,
          :usage      => "push"
        },
        "shield_riposte"        => {
          :short_name => "riposte",
          :type       => :martial_stance,
          :cost       => { stamina: 20 },
          :regex      => Regexp.union(/You assume the Shield Riposte Stance, preparing yourself to lash out at a moment's notice\./,
                                      /You re\-settle into the Shield Riposte Stance, preparing yourself to lash out at a moment's notice\./),
          :usage      => "riposte"
        },
        "shield_spike_mastery"  => {
          :short_name => "spikemastery",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Shield Spike Mastery does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "shield_strike"         => {
          :short_name => "strike",
          :type       => :attack,
          :cost       => { stamina: 15 },
          :regex      => /You launch a quick bash with your .+ at .+\!/,
          :usage      => "strike"
        },
        "shield_strike_mastery" => {
          :short_name => "strikemastery",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Shield Strike Mastery does not need to be activated once you have learned it\.  It will automatically apply to all relevant focused multi\-attacks, provided that you maintain the prerequisite ranks of Shield Bash\./,
          :usage      => nil
        },
        "shield_swiftness"      => {
          :short_name => "swiftness",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Shield Swiftness does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a small or medium shield and have at least 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil
        },
        "shield_throw"          => {
          :short_name => "throw",
          :type       => :area_of_effect,
          :cost       => { stamina: 20 },
          :regex      => /You snap your arm forward, hurling your .+ at .+ with all your might\!/,
          :usage      => "throw"
        },
        "shield_trample"        => {
          :short_name => "trample",
          :type       => :area_of_effect,
          :cost       => { stamina: 14 },
          :regex      => /You raise your .+ before you and charge headlong towards .+\!/,
          :usage      => "trample"
        },
        "shielded_brawler"      => {
          :short_name => "brawler",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Shielded Brawler does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil
        },
        "small_shield_focus"    => {
          :short_name => "sfocus",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Small Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "spell_block"           => {
          :short_name => "spellblock",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Spell Block does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil
        },
        "steady_shield"         => {
          :short_name => "steady",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Steady Shield does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks against you, provided that you maintain the prerequisite ranks of Stun Maneuvers\./,
          :usage      => nil
        },
        "steely_resolve"        => {
          :short_name => "resolve",
          :type       => :buff,
          :cost       => { stamina: 30 },
          :regex      => Regexp.union(/You focus your mind in a steely resolve to block all attacks against you\./,
                                      /You are still mentally fatigued from your last invocation of your Steely Resolve\./),
          :usage      => "resolve"
        },
        "tortoise_stance"       => {
          :short_name => "tortoise",
          :type       => :martial_stance,
          :cost       => { stamina: 20 },
          :regex      => Regexp.union(/You assume the Stance of the Tortoise, holding back some of your offensive power in order to maximize your defense\./,
                                      /You re\-settle into the Stance of the Tortoise, holding back your offensive power in order to maximize your defense\./),
          :usage      => "tortoise"
        },
        "tower_shield_focus"    => {
          :short_name => "tfocus",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Tower Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./i,
          :usage      => nil
        }
      }

      extend PSMS::Technique
      techniques @@shield_techniques, type: "Shield", verb: "shield"
      free_under "Glorious Momentum", type: :area_of_effect, affects: :cost
    end
  end
end
