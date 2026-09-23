# The root module for Lich scripting.
module Lich
  # GemStone IV-specific extensions for Lich.
  module Gemstone
    # Provides access to Feats learned by a character in GemStone IV.
    #
    # This module supports checking feat knowledge, availability, and cost (including FORCERT use),
    # as well as triggering their usage. Each feat is described in a metadata hash which includes:
    # - long and short names
    # - cost
    # - expected in-game output (regex)
    # - optional usage string for execution
    #
    # Dynamic accessor methods are created for each feat's long and short name.
    module Feat
      # A registry of all known feats and their properties.
      #
      # @return [Hash<String, Hash>] A mapping of feat names to metadata including:
      #   - `:short_name` [String]
      #   - `:type` [String, nil]
      #   - `:cost` [Integer]
      #   - `:regex` [Regexp] for expected output
      #   - `:usage` [String, nil] command usage
      @@feats = {
        "absorb_magic"              => {
          :short_name => "absorbmagic",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => Regexp.union(/You open yourself to the ravenous void at the core of your being, allowing it to surface\.  Muted veins of metallic grey ripple just beneath your skin\./,
                                      /You strain, but the void within remains stubbornly out of reach\.  You need more time\./),
          :usage      => "absorbmagic"
        },
        "chain_armor_proficiency"   => {
          :short_name => "chainarmor",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Chain Armor Proficiency is passive and cannot be activated\./,
          :usage      => nil
        },
        "chastise"                  => {
          :short_name => "chastise",
          :type       => :attack,
          :cost       => { stamina: 10 },
          :regex      => /as you lunge at .+? in a quick and vicious strike!$/,
          :usage      => "chastise"
        },
        "combat_mastery"            => {
          :short_name => "combatmastery",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Combat Mastery is passive and cannot be activated\./,
          :usage      => nil
        },
        "covert_art_escape_artist"  => {
          :short_name => "escapeartist",
          :type       => :reaction,
          :cost       => { stamina: 0 },
          :regex      => Regexp.union(/You roll your shoulders and subtly test the flexion of your joints, staying limber for ready escapes\./,
                                      /You were unable to find any targets that meet Covert Art\: Escape Artist's reaction requirements\./),
          :usage      => "escapeartist"
        },
        "covert_art_keen_eye"       => {
          :short_name => "keeneye",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Covert Art\: Keen Eye is always active as long as you stay up to date on training\./,
          :usage      => nil
        },
        "covert_art_poisoncraft"    => {
          :short_name => "poisoncraft",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /USAGE\: FEAT POISONCRAFT \{options\} \[args\]/,
          :usage      => nil
        },
        "covert_art_sidestep"       => {
          :short_name => "sidestep",
          :type       => :buff,
          :cost       => { stamina: 10 },
          :regex      => /You tread lightly and keep your head on a swivel, prepared to sidestep any loose salvos that might stray your way\./,
          :usage      => "sidestep"
        },
        "covert_art_swift_recovery" => {
          :short_name => "swiftrecovery",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Covert Art\: Swift Recovery is always active as long as you stay up to date on training\./,
          :usage      => nil
        },
        "covert_art_throw_poison"   => {
          :short_name => "throwpoison",
          :type       => :attack,
          :cost       => { stamina: 15 },
          :regex      => Regexp.union(/What did the .+ ever do to you\?/,
                                      /You pop the cork on .+ and, with a nimble flick of the wrist, fling a portion of its contents in a wide arc\!/,
                                      /Covert Art\: Throw Poison what\?/),
          :usage      => "throwpoison"
        },
        "covert_arts"               => {
          :short_name => "covert",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /USAGE\: FEAT COVERT \{options\} \[args\]/,
          :usage      => nil
        },
        "critical_counter"          => {
          :short_name => "criticalcounter",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Critical Counter is passive and cannot be activated\./,
          :usage      => nil
        },
        "dispel_magic"              => {
          :short_name => "dispelmagic",
          :type       => :buff,
          :cost       => { stamina: 30 },
          :regex      => Regexp.union(/You reach for the emptiness within, but there are no spells afflicting you to dispel\./,
                                      /You reach for the emptiness within\.  A single, hollow note reverberates through your core, resonating outward and scouring away the energies that cling to you\./),
          :usage      => "dispelmagic"
        },
        "dragonscale_skin"          => {
          :short_name => "dragonscaleskin",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /The Dragonscale Skin\s{1,2}feat is always active once you have learned it\./,
          :usage      => nil
        },
        "excoriate"                 => {
          :short_name => "excoriate",
          :type       => :attack,
          :cost       => { mana: 10 },
          :regex      => /You level your .+? at .+? and call down the excoriating power of .+? to smite (?:him|her|it)!/,
          :usage      => "excoriate"
        },
        "guard"                     => {
          :short_name => "guard",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => Regexp.union(/Guard what\?/,
                                      /You move over to .+ and prepare to guard [a-z]+ from attack\./,
                                      /You stop guarding .+, move over to .+, and prepare to guard [a-z]+ from attack\./,
                                      /You stop protecting .+, move over to .+, and prepare to guard [a-z]+ from attack\./,
                                      /You stop protecting .+ and prepare to guard [a-z]+ instead\./,
                                      /You are already guarding .+\./),
          :usage      => "guard"
        },
        "kroderine_soul"            => {
          :short_name => "kroderinesoul",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Kroderine Soul is passive and always active as long as you do not learn any spells\.  You have access to two new abilities\:/,
          :usage      => nil
        },
        "light_armor_proficiency"   => {
          :short_name => "lightarmor",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Light Armor Proficiency is passive and cannot be activated\./,
          :usage      => nil
        },
        "martial_arts_mastery"      => {
          :short_name => "martialarts",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Martial Arts Mastery is passive and cannot be activated\./,
          :usage      => nil
        },
        "martial_mastery"           => {
          :short_name => "martialmastery",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Martial Mastery is passive and cannot be activated\./,
          :usage      => nil
        },
        "mental_acuity"             => {
          :short_name => "mentalacuity",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /The Mental Acuity\s{1,2}feat is always active once you have learned it\./,
          :usage      => nil
        },
        "mystic_strike"             => {
          :short_name => "mysticstrike",
          :type       => :buff,
          :cost       => { stamina: 10 },
          :regex      => /You prepare yourself to deliver a Mystic Strike with your next attack\./,
          :usage      => "mysticstrike"
        },
        "mystic_tattoo"             => {
          :short_name => "tattoo",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Usage\:/,
          :usage      => nil
        },
        "perfect_self"              => {
          :short_name => "perfectself",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /The Perfect Self feat is always active once you have learned it\.  It provides a constant enhancive bonus to all your stats\./,
          :usage      => nil
        },
        "plate_armor_proficiency"   => {
          :short_name => "platearmor",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Plate Armor Proficiency is passive and cannot be activated\./,
          :usage      => nil
        },
        "protect"                   => {
          :short_name => "protect",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => Regexp.union(/Protect what\?/,
                                      /You move over to .+ and prepare to protect [a-z]+ from attack\./,
                                      /You stop protecting .+, move over to .+, and prepare to protect [a-z]+ from attack\./,
                                      /You stop guarding .+, move over to .+, and prepare to protect [a-z]+ from attack\./,
                                      /You stop guarding .+ and prepare to protect [a-z]+ instead\./,
                                      /You are already protecting .+\./),
          :usage      => "protect"
        },
        "scale_armor_proficiency"   => {
          :short_name => "scalearmor",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Scale Armor Proficiency is passive and cannot be activated\./,
          :usage      => nil
        },
        "shadow_dance"              => {
          :short_name => "shadowdance",
          :type       => :buff,
          :cost       => { stamina: 30 },
          :regex      => /You focus your mind and body on the shadows\./,
          :usage      => nil
        },
        "silent_strike"             => {
          :short_name => "silentstrike",
          :type       => :attack,
          :cost       => { stamina: 20 },
          :regex      => Regexp.union(/Silent Strike can not be used with fire as the attack type\./,
                                      /You quickly leap from hiding to (?:deliver your )?attack\!/),
          :usage      => "silentstrike"
        },
        "vanish"                    => {
          :short_name => "vanish",
          :type       => :buff,
          :cost       => { stamina: 30 },
          :regex      => /With subtlety and speed, you aim to clandestinely vanish into the shadows\./,
          :usage      => "vanish"
        },
        "weapon_bonding"            => {
          :short_name => "weaponbonding",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /USAGE\:/,
          :usage      => nil
        },
        "weighting"                 => {
          :short_name => "wps",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /USAGE\: FEAT WPS \{options\} \[args\]/,
          :usage      => nil
        },
        "padding"                   => {
          :short_name => "wps",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /USAGE\: FEAT WPS \{options\} \[args\]/,
          :usage      => nil
        }
      }

      extend PSMS::Technique
      techniques @@feats, type: "Feat", verb: "feat"

      # Feats sent as their own verb rather than FEAT <usage>.
      BARE_COMMANDS = ['guard', 'protect'].freeze

      # @api private
      # GUARD and PROTECT are sent bare; every other feat as FEAT <usage>.
      def Feat.verb_for(usage)
        BARE_COMMANDS.include?(usage) ? nil : "feat"
      end
    end
  end
end
