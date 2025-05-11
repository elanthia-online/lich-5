## breakout for Feat released with PSM3
## updated for Ruby 3.2.1 and new Infomon module

module Lich
  module Gemstone
    module Feat
      @@feats = {
        "absorb_magic"              => {
          "short_name" => "absorbmagic",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => Regexp.union(/You open yourself to the ravenous void at the core of your being, allowing it to surface\.  Muted veins of metallic grey ripple just beneath your skin\./,
                                       /You strain, but the void within remains stubbornly out of reach\.  You need more time\./),
          "usage"      => "absorbmagic"
        },
        "chain_armor_proficiency"   => {
          "short_name" => "chainarmor",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /Chain Armor Proficiency is passive and cannot be activated\./,
          "usage"      => nil
        },
        "combat_mastery"            => {
          "short_name" => "combatmastery",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /Combat Mastery is passive and cannot be activated\./,
          "usage"      => nil
        },
        "covert_art_escape_artist"  => {
          "short_name" => "escapeartist",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => Regexp.union(/You roll your shoulders and subtly test the flexion of your joints, staying limber for ready escapes\./,
                                       /You were unable to find any targets that meet Covert Art\: Escape Artist's reaction requirements\./),
          "usage"      => "escapeartist"
        },
        "covert_art_keen_eye"       => {
          "short_name" => "keeneye",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /Covert Art\: Keen Eye is always active as long as you stay up to date on training\./,
          "usage"      => nil
        },
        "covert_art_poisoncraft"    => {
          "short_name" => "poisoncraft",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /USAGE\: FEAT POISONCRAFT \{options\} \[args\]/,
          "usage"      => nil
        },
        "covert_art_sidestep"       => {
          "short_name" => "sidestep",
          "type"       => nil,
          "cost"       => 10,
          "regex"      => /You tread lightly and keep your head on a swivel, prepared to sidestep any loose salvos that might stray your way\./,
          "usage"      => "sidestep"
        },
        "covert_art_swift_recovery" => {
          "short_name" => "swiftrecovery",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /Covert Art\: Swift Recovery is always active as long as you stay up to date on training\./,
          "usage"      => nil
        },
        "covert_art_throw_poison"   => {
          "short_name" => "throwpoison",
          "type"       => nil,
          "cost"       => 15,
          "regex"      => Regexp.union(/What did the .+ ever do to you\?/,
                                       /You pop the cork on .+ and, with a nimble flick of the wrist, fling a portion of its contents in a wide arc\!/,
                                       /Covert Art\: Throw Poison what\?/),
          "usage"      => "throwpoison"
        },
        "covert_arts"               => {
          "short_name" => "covert",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /USAGE\: FEAT COVERT \{options\} \[args\]/,
          "usage"      => nil
        },
        "critical_counter"          => {
          "short_name" => "criticalcounter",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /Critical Counter is passive and cannot be activated\./,
          "usage"      => nil
        },
        "dispel_magic"              => {
          "short_name" => "dispelmagic",
          "type"       => nil,
          "cost"       => 30,
          "regex"      => Regexp.union(/You reach for the emptiness within, but there are no spells afflicting you to dispel\./,
                                       /You reach for the emptiness within\.  A single, hollow note reverberates through your core, resonating outward and scouring away the energies that cling to you\./),
          "usage"      => "dispelmagic"
        },
        "dragonscale_skin"          => {
          "short_name" => "dragonscaleskin",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /The Dragonscale Skin\s{1,2}feat is always active once you have learned it\./,
          "usage"      => nil
        },
        "guard"                     => {
          "short_name" => "guard",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => Regexp.union(/Guard what\?/,
                                       /You move over to .+ and prepare to guard [a-z]+ from attack\./,
                                       /You stop guarding .+, move over to .+, and prepare to guard [a-z]+ from attack\./,
                                       /You stop protecting .+, move over to .+, and prepare to guard [a-z]+ from attack\./,
                                       /You stop protecting .+ and prepare to guard [a-z]+ instead\./,
                                       /You are already guarding .+\./),
          "usage"      => "guard"
        },
        "kroderine_soul"            => {
          "short_name" => "kroderinesoul",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /Kroderine Soul is passive and always active as long as you do not learn any spells\.  You have access to two new abilities\:/,
          "usage"      => nil
        },
        "light_armor_proficiency"   => {
          "short_name" => "lightarmor",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /Light Armor Proficiency is passive and cannot be activated\./,
          "usage"      => nil
        },
        "martial_arts_mastery"      => {
          "short_name" => "martialarts",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /Martial Arts Mastery is passive and cannot be activated\./,
          "usage"      => nil
        },
        "martial_mastery"           => {
          "short_name" => "martialmastery",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /Martial Mastery is passive and cannot be activated\./,
          "usage"      => nil
        },
        "mental_acuity"             => {
          "short_name" => "mentalacuity",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /The Mental Acuity\s{1,2}feat is always active once you have learned it\./,
          "usage"      => nil
        },
        "mystic_strike"             => {
          "short_name" => "mysticstrike",
          "type"       => nil,
          "cost"       => 10,
          "regex"      => /You prepare yourself to deliver a Mystic Strike with your next attack\./,
          "usage"      => "mysticstrike"
        },
        "mystic_tattoo"             => {
          "short_name" => "tattoo",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /Usage\:/,
          "usage"      => nil
        },
        "perfect_self"              => {
          "short_name" => "perfectself",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /The Perfect Self feat is always active once you have learned it\.  It provides a constant enhancive bonus to all your stats\./,
          "usage"      => nil
        },
        "plate_armor_proficiency"   => {
          "short_name" => "platearmor",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /Plate Armor Proficiency is passive and cannot be activated\./,
          "usage"      => nil
        },
        "protect"                   => {
          "short_name" => "protect",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => Regexp.union(/Protect what\?/,
                                       /You move over to .+ and prepare to protect [a-z]+ from attack\./,
                                       /You stop protecting .+, move over to .+, and prepare to protect [a-z]+ from attack\./,
                                       /You stop guarding .+, move over to .+, and prepare to protect [a-z]+ from attack\./,
                                       /You stop guarding .+ and prepare to protect [a-z]+ instead\./,
                                       /You are already protecting .+\./),
          "usage"      => "protect"
        },
        "scale_armor_proficiency"   => {
          "short_name" => "scalearmor",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /Scale Armor Proficiency is passive and cannot be activated\./,
          "usage"      => nil
        },
        "shadow_dance"              => {
          "short_name" => "shadowdance",
          "type"       => nil,
          "cost"       => 30,
          "regex"      => /You focus your mind and body on the shadows\./,
          "usage"      => nil
        },
        "silent_strike"             => {
          "short_name" => "silentstrike",
          "type"       => nil,
          "cost"       => 20,
          "regex"      => Regexp.union(/Silent Strike can not be used with fire as the attack type\./,
                                       /You quickly leap from hiding to attack\!/),
          "usage"      => "silentstrike"
        },
        "vanish"                    => {
          "short_name" => "vanish",
          "type"       => nil,
          "cost"       => 30,
          "regex"      => /With subtlety and speed, you aim to clandestinely vanish into the shadows\./,
          "usage"      => "vanish"
        },
        "weapon_bonding"            => {
          "short_name" => "weaponbonding",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /USAGE\:/,
          "usage"      => nil
        },
        "weighting"                 => {
          "short_name" => "wps",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /USAGE\: FEAT WPS \{options\} \[args\]/,
          "usage"      => nil
        },
        "padding"                   => {
          "short_name" => "wps",
          "type"       => nil,
          "cost"       => 0,
          "regex"      => /USAGE\: FEAT WPS \{options\} \[args\]/,
          "usage"      => nil
        }
      }

      def self.feat_lookups
        @@feats.map do |long_name, psm|
          {
            long_name: long_name,
            short_name: psm[:short_name],
            cost: psm[:cost]
          }
        end
      end

      def Feat.[](name)
        return PSMS.assess(name, 'Feat')
      end

      def Feat.known?(name, min_rank: 1)
        min_rank = 1 unless min_rank >= 1 # in case a 0 or below is passed
        Feat[name] >= min_rank
      end

      def Feat.affordable?(name)
        return PSMS.assess(name, 'Feat', true)
      end

      def Feat.available?(name, min_rank: 1)
        Feat.known?(name, min_rank: min_rank) and Feat.affordable?(name) and !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
      end

      def Feat.use(name, target = "", results_of_interest: nil)
        return unless Feat.available?(name)
        name_normalized = PSMS.name_normal(name)
        technique = @@feats.fetch(name_normalized)
        usage = technique[:usage]
        return if usage.nil?

        in_cooldown_regex = /^#{name} is still in cooldown\./i

        results_regex = Regexp.union(
          PSMS::FAILURES_REGEXES,
          /^#{name} what\?$/i,
          in_cooldown_regex,
          technique[:regex],
          /^Roundtime: [0-9]+ sec\.$/,
        )

        if results_of_interest.is_a?(Regexp)
          results_regex = Regexp.union(results_regex, results_of_interest)
        end

        usage_cmd = (['guard', 'protect'].include?(usage) ? "#{usage}" : "feat #{usage}")
        if target.is_a?(GameObj)
          usage_cmd += " ##{target.id}"
        elsif target.is_a?(Integer)
          usage_cmd += " ##{target}"
        elsif target != ""
          usage_cmd += " #{target}"
        end
        waitrt?
        waitcastrt?
        usage_result = dothistimeout usage_cmd, 5, results_regex
        if usage_result == "You don't seem to be able to move to do that."
          100.times { break if clear.any? { |line| line =~ /^You regain control of your senses!$/ }; sleep 0.1 }
          usage_result = dothistimeout usage_cmd, 5, results_regex
        end
        usage_result
      end

      def Feat.regexp(name)
        @@feats.fetch(PSMS.name_normal(name))[:regex]
      end

      Feat.feat_lookups.each { |feat|
        self.define_singleton_method(feat[:short_name]) do
          Feat[feat[:short_name]]
        end

        self.define_singleton_method(feat[:long_name]) do
          Feat[feat[:short_name]]
        end
      }
    end
  end
end
