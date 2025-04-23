## breakout for Feat released with PSM3
## updated for Ruby 3.2.1 and new Infomon module

module Lich
  module Gemstone
    module Feat
      def self.feat_lookups
        [{ long_name: 'absorb_magic',              short_name: 'absorbmagic',        cost:  0 },
         { long_name: 'chain_armor_proficiency',   short_name: 'chainarmor',         cost:  0 },
         { long_name: 'combat_mastery',            short_name: 'combatmastery',      cost:  0 },
         { long_name: 'covert_art_escape_artist',  short_name: 'escapeartist',       cost:  0 },
         { long_name: 'covert_art_keen_eye',       short_name: 'keeneye',            cost:  0 },
         { long_name: 'covert_art_poisoncraft',    short_name: 'poisoncraft',        cost:  0 },
         { long_name: 'covert_art_sidestep',       short_name: 'sidestep',           cost: 10 },
         { long_name: 'covert_art_swift_recovery', short_name: 'swiftrecovery',      cost:  0 },
         { long_name: 'covert_art_throw_poison',   short_name: 'throwpoison',        cost: 15 },
         { long_name: 'covert_arts',               short_name: 'covert',             cost:  0 },
         { long_name: 'critical_counter',          short_name: 'criticalcounter',    cost:  0 },
         { long_name: 'dispel_magic',              short_name: 'dispelmagic',        cost: 30 },
         { long_name: 'dragonscale_skin',          short_name: 'dragonscaleskin',    cost:  0 },
         { long_name: 'guard',                     short_name: 'guard',              cost:  0 },
         { long_name: 'kroderine_soul',            short_name: 'kroderinesoul',      cost:  0 },
         { long_name: 'light_armor_proficiency',   short_name: 'lightarmor',         cost:  0 },
         { long_name: 'martial_arts_mastery',      short_name: 'martialarts',        cost:  0 },
         { long_name: 'martial_mastery',           short_name: 'martialmastery',     cost:  0 },
         { long_name: 'mental_acuity',             short_name: 'mentalacuity',       cost:  0 },
         { long_name: 'mystic_strike',             short_name: 'mysticstrike',       cost: 10 },
         { long_name: 'mystic_tattoo',             short_name: 'tattoo',             cost:  0 },
         { long_name: 'perfect_self',              short_name: 'perfectself',        cost:  0 },
         { long_name: 'plate_armor_proficiency',   short_name: 'platearmor',         cost:  0 },
         { long_name: 'protect',                   short_name: 'protect',            cost:  0 },
         { long_name: 'scale_armor_proficiency',   short_name: 'scalearmor',         cost:  0 },
         { long_name: 'shadow_dance',              short_name: 'shadowdance',        cost: 30 },
         { long_name: 'silent_strike',             short_name: 'silentstrike',       cost: 20 },
         { long_name: 'vanish',                    short_name: 'vanish',             cost: 30 },
         { long_name: 'weapon_bonding',            short_name: 'weaponbonding',      cost:  0 },
         { long_name: 'weighting',                 short_name: 'wps',                cost:  0 },
         { long_name: 'padding',                   short_name: 'wps',                cost:  0 }]
      end

      @@feats = {
        "absorb_magic"              => {
          :cost  => 0,
          :regex => Regexp.union(/You open yourself to the ravenous void at the core of your being, allowing it to surface\.  Muted veins of metallic grey ripple just beneath your skin\./,
                                 /You strain, but the void within remains stubbornly out of reach\.  You need more time\./),
          :usage => "absorbmagic"
        },
        "chain_armor_proficiency"   => {
          :cost  => 0,
          :regex => /Chain Armor Proficiency is passive and cannot be activated\./,
          :usage => nil
        },
        "combat_mastery"            => {
          :cost  => 0,
          :regex => /Combat Mastery is passive and cannot be activated\./,
          :usage => nil
        },
        "covert_art_escape_artist"  => {
          :cost  => 15, # cost is actually 0 if "recent evasion" is present
          :regex => Regexp.union(/You roll your shoulders and subtly test the flexion of your joints, staying limber for ready escapes\./,
                                 /You were unable to find any targets that meet Covert Art\: Escape Artist\'s reaction requirements./),
          :usage => "escapeartist"
        },
        "covert_art_keen_eye"       => {
          :cost  => 0,
          :regex => /Covert Art\: Keen Eye is always active as long as you stay up to date on training\./,
          :usage => nil
        },
        "covert_art_poisoncraft"    => {
          :cost  => 0,
          :regex => /USAGE\: FEAT POISONCRAFT \{options\} \[args\]/, #  USAGE: FEAT POISONCRAFT {options} [args]
          :usage => nil # usage set to NIL as not currently supported due to complexity
        },
        "covert_art_sidestep"       => {
          :cost  => 10,
          :regex => /You tread lightly and keep your head on a swivel, prepared to sidestep any loose salvos that might stray your way\./,
          :usage => "sidestep"
        },
        "covert_art_swift_recovery" => {
          :cost  => 0,
          :regex => /Covert Art\: Swift Recovery is always active as long as you stay up to date on training\./,
          :usage => nil
        },
        "covert_art_throw_poison"   => {
          :cost  => 15,
          :regex => Regexp.union(/What did the .+ ever do to you\?/,
                                 /You pop the cork on .+ and, with a nimble flick of the wrist, fling a portion of its contents in a wide arc\!/,
                                 /Covert Art\: Throw Poison what\?/),
          :usage => "throwpoison"
        },
        "covert_arts"               => {
          :cost  => 0,
          :regex => /USAGE\: FEAT COVERT \{options\} \[args\]/, #  USAGE: FEAT COVERT {options} [args]
          :usage => nil # usage not supported at this time, complicated and used to train others in the skills
        },
        "critical_counter"          => {
          :cost  => 0,
          :regex => /Critical Counter is passive and cannot be activated\./,
          :usage => nil
        },
        "dispel_magic"              => {
          :cost  => 30,
          :regex => Regexp.union(/You reach for the emptiness within, but there are no spells afflicting you to dispel\./,
                                 /You reach for the emptiness within\.  A single, hollow note reverberates through your core, resonating outward and scouring away the energies that cling to you\./),
          :usage => "dispelmagic"
        },
        "dragonscale_skin"          => {
          :cost  => 0,
          :regex => /The Dragonscale Skin\s{1,2}feat is always active once you have learned it\./, # Note: Game has a typo with two spaces after the name of the feat, modified regex to match 1 or 2 spaces so this doesn't break if the typo gets fixed.
          :usage => nil
        },
        "guard"                     => {
          :cost  => 0,
          :regex => Regexp.union(/Guard what\?/, # "any variation of "feat guard" or bad target
                                 /You move over to .+ and prepare to guard [a-z]+ from attack\./, # "Guard <target>"
                                 /You stop guarding .+, move over to .+, and prepare to guard [a-z]+ from attack\./, # "Guard <target2>" while already guarding <target1>
                                 /You stop protecting .+, move over to .+, and prepare to guard [a-z]+ from attack\./, # "Guard <target2>" while protecting <target1>
                                 /You stop protecting .+ and prepare to guard [a-z]+ instead\./, # "Guard <target>" while protecting <target>
                                 /You are already guarding .+\./), # "Guard <target>" while already doing so
          :usage => "guard"
        },
        "kroderine_soul"            => {
          :cost  => 0,
          :regex => /Kroderine Soul is passive and always active as long as you do not learn any spells\.  You have access to two new abilities\:/,
          :usage => nil
        },
        "light_armor_proficiency"   => {
          :cost  => 0,
          :regex => /Light Armor Proficiency is passive and cannot be activated\./,
          :usage => nil
        },
        "martial_arts_mastery"      => {
          :cost  => 0,
          :regex => /Martial Arts Mastery is passive and cannot be activated\./,
          :usage => nil
        },
        "martial_mastery"           => {
          :cost  => 0,
          :regex => /Martial Mastery is passive and cannot be activated\./,
          :usage => nil
        },
        "mental_acuity"             => {
          :cost  => 0,
          :regex => /The Mental Acuity\s{1,2}feat is always active once you have learned it\./, # Note: Game has a typo with two spaces after the name of the feat, modified regex to match 1 or 2 spaces so this doesn't break if the typo gets fixed.
          :usage => nil
        },
        "mystic_strike"             => {
          :cost  => 10,
          :regex => /You prepare yourself to deliver a Mystic Strike with your next attack\./,
          :usage => "mysticstrike"
        },
        "mystic_tattoo"             => {
          :cost  => 0,
          :regex => /Usage\:/,
          :usage => nil # usage not supported at this time, complicated and used for a service
        },
        "perfect_self"              => {
          :cost  => 0,
          :regex => /The Perfect Self feat is always active once you have learned it\.  It provides a constant enhancive bonus to all your stats\./,
          :usage => nil
        },
        "plate_armor_proficiency"   => {
          :cost  => 0,
          :regex => /Plate Armor Proficiency is passive and cannot be activated\./,
          :usage => nil
        },
        "protect"                   => {
          :cost  => 0,
          :regex => Regexp.union(/Protect what\?/, #  any variation of "feat protect" or bad target:
                                 /You move over to .+ and prepare to protect [a-z]+ from attack\./, #  "protect <target>"
                                 /You stop protecting .+, move over to .+, and prepare to protect [a-z]+ from attack\./, #  "protect <target2>" while already protecting <target1>
                                 /You stop guarding .+, move over to .+, and prepare to protect [a-z]+ from attack\./, #  "protect <target2>" while guarding <target1>
                                 /You stop guarding .+ and prepare to protect [a-z]+ instead\./, #  "protect <target>" while already guarding <target>
                                 /You are already protecting .+\./), #  "protect <target>" while already protecting <target>
          :usage => "protect"
        },
        "scale_armor_proficiency"   => {
          :cost  => 0,
          :regex => /Scale Armor Proficiency is passive and cannot be activated\./,
          :usage => nil
        },
        "shadow_dance"              => {
          :cost  => 30,
          :regex => /You focus your mind and body on the shadows\./,
          :usage => nil
        },
        "silent_strike"             => {
          :cost  => 20,
          :regex => Regexp.union(/Silent Strike can not be used with fire as the attack type\./,
                                 /You quickly leap from hiding to attack\!/),
          :usage => "silentstrike"
        },
        "vanish"                    => {
          :cost  => 30,
          :regex => /With subtlety and speed, you aim to clandestinely vanish into the shadows\./,
          :usage => "vanish"
        },
        "weapon_bonding"            => {
          :cost  => 0,
          :regex => /USAGE\:/,
          :usage => nil # not currently supported due to complexity
        },
        "weighting"                 => {
          :cost  => 0,
          :regex => /USAGE\: FEAT WPS \{options\} \[args\]/, # USAGE: FEAT WPS {options} [args]
          :usage => nil # not currently supported due to complexity
        },
        "padding"                   => {
          :cost  => 0,
          :regex => /USAGE\: FEAT WPS \{options\} \[args\]/, # USAGE: FEAT WPS {options} [args]
          :usage => nil # not currently supported due to complexity
        },
      }

      def Feat.[](name)
        return PSMS.assess(name, 'Feat')
      end

      def Feat.known?(name)
        Feat[name] > 0
      end

      def Feat.affordable?(name)
        return PSMS.assess(name, 'Feat', true)
      end

      def Feat.available?(name)
        Feat.known?(name) and Feat.affordable?(name) and !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
      end

      def Feat.use(name, target = "", results_of_interest: nil)
        return unless Feat.available?(name)
        usage = @@feats.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)[:usage]
        return if usage.nil?

        results_regex = Regexp.union(
          PSMS::FAILURES_REGEXES,
          @@feats.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)[:regex],
          /^#{name} what\?$/i
        )

        if results_of_interest.is_a?(Regexp)
          results_regex = Regexp.union(results_regex, results_of_interest)
        end

        usage_cmd = (['guard', 'protect'].include?(usage) ? "#{usage}" : "feat #{usage}")
        if target.class == GameObj
          usage_cmd += " ##{target.id}"
        elsif target.class == Integer
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
        @@feats.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)[:regex]
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
