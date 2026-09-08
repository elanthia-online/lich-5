# frozen_string_literal: true

require_relative 'pattern_gate'

module Lich
  module Gemstone
    module Combat
      module Definitions
        # Classifies attack-outcome lines - the line that says how a swing,
        # bolt, or maneuver resolved (miss, hit, evade, block, parry, warded,
        # intercepted, resisted, ...). One outcome type per line; an attack
        # event may accumulate several outcomes (multi-strike attacks).
        module Outcomes
          # One outcome category and the game lines that signal it.
          #
          # @!attribute type
          #   @return [Symbol] outcome category (:miss, :hit, :evade, ...)
          # @!attribute patterns
          #   @return [Array<Regexp>] lines that signal this outcome; may
          #     carry named captures (target, attacker, weapon, armor)
          OutcomeDef = Struct.new(:type, :patterns)

          # All outcome definitions, in match-priority order (parse is
          # first-match-wins, so more specific categories precede the
          # broad :evade/:block pools).
          #
          # @return [Array<OutcomeDef>]
          OUTCOME_DEFS = [
            OutcomeDef.new(:miss, [
              /A clean miss./,
              /A close miss./,
              /Nowhere close./,
              /(?<attacker>.+?)'s#{MK_POST} swing goes wide./,
              /The (?:arrow|bolt) streaks off into the distance./,
              /Though (?<target>.+?) is caught unaware, you manage to completely miss your strike./,
              /You make a grab for (?<target>.+?) but miss, leaving yourself open./,
              /You stumble slightly as you leap from hiding, revealing yourself in the process./,
              /You move towards (?<target>.+?) to finish your kill, but .+? thwarts your attempt./,
              /The shadowy barb strikes harmlessly at the ground near (?<target>[^.]+)./,
              /A falling arrow flashes past (?<target>.+?) and shatters against the (?:ground|floor)./,
              /An incoming arrow just misses (?<target>[^!]+)./,
              /An arrow falls to the (?:ground|floor), narrowly missing (?<target>[^!]+)./,
              /(?<target>.+?) moves at the last moment to avoid an incoming arrow./,
              /The spray of arrows leaves (?<target>.+?) unscathed and undeterred./,
              /The .+? vine#{MK_POST} (?:lashes out at|grabs at) (?<target>.+?),? (?:but is unable to grasp|unable to find a purchase)/,
              /Your strike misses its mark./,
              /(?<attacker>.+?) whacks your legs to no effect./,
              /You whack (?<target>.+?'s)#{MK_POST} legs futilely./,
              /You end up missing entirely, leaving you slightl?y off balance./,
              /(?<target>.+?) avoids your bash./,
              /(?<target>.+?) is unaffected by your futile bash./,
              /Your (?<weapon>.+?) flies wide, narrowly missing (?<target>[^!]+)./,
              /The net flies past you and collapses into a useless heap./,
              /(?<attacker>.+?) stumbles behind you like a top out of control./,
              /The enormous hand attempts to grab you, but you manage to avoid it at the last moment./
            ].freeze),
            OutcomeDef.new(:hit, [
              /(?:A|Good) hit!/,
              # Nature's Fury per-target hit lines (round-13 sweep: 52/52
              # follow the natures_fury initiation + Warding failed! in
              # the same chunk, damage always follows). The adjective is
              # terrain flavor (hard/snowy/cold/hot/mist-covered...).
              # Outcome, not attack def - the "surroundings advance"
              # initiation already owns the event; these just confirm
              # the strike landed.
              /(?<target>.+?) is struck by a sharp piece of \S+(?: \S+)? debris!/,
              /One of the large, pointed slivers of \S+(?: \S+)? debris hits (?<target>[^!]+)!/,
              # 1106 Bone Shatter result rider (owner evidence 2026-09-05:
              # sits between "Warding failed!" and the "battered for N"
              # damage; severity grades by endroll - mild/moderate/severe
              # observed). Initiation + damage were already claimed;
              # this closes the 6.2k-line rider family.
              /(?<target>.+?) shudders with \w+ convulsions as pearlescent ripples envelop #{MK_PRE}(?:his|her|its|your)#{MK_POST} body\./
            ].freeze),
            OutcomeDef.new(:warded, [/Warded off!/].freeze),
            OutcomeDef.new(:ward_failed, [/Warding failed!/].freeze),
            # INTERCEPTS - the attack is nullified BEFORE it resolves, by a
            # barrier/shield/ward standing between attacker and defender.
            # Categorically NOT :block or :evade: nothing was blocked or
            # dodged, and no defensive skill was exercised - it is as if the
            # attack never happened. Kept separate so hit-rate and
            # block-rate statistics stay honest (an intercept must not count
            # against a creature's evasion or a character's block rate).
            #
            # Ordered BEFORE :evade/:block so these claim their lines first
            # (parse is first-match-wins).
            OutcomeDef.new(:intercept, [
              # 250 Thorn Barrier / thorny barrier
              /The thorny barrier surrounding (?<target>.+?) blocks your .+?!/,
              /The thorny barrier surrounding you blocks the attack from (?<attacker>[^!]+)!/,
              /The thorny barrier surrounding (?<target>.+?) blocks the attack from .+?!/,
              # 319 Soul Ward (owner-corrected 2026-09-04; the 319 wiki
              # page carries this wording verbatim - 430 is Elemental
              # Barrier and was a misattribution)
              /The evanescent shield shrouding (?<target>.+?) flares to life and absorbs the (?:oncoming blow|essence of the spell, dissipating it harmlessly)\./,
              /The evanescent shield shrouding you flares to life and absorbs the (?:oncoming blow|essence of the spell, dissipating it harmlessly)\./,
              # 606 Bark Skin
              /The layer of bark on you hardens and absorbs the attack!/,
              /The layer of bark on (?<target>.+?) hardens and absorbs the attack!/,
              # stone barrier
              /A heavy barrier of stone momentarily forms around (?<target>.+?) and blocks the attack!/,
              # full spell-deflect barrier - replaces the roll line entirely
              /A complex pattern of .+? energy flashes briefly into existence between .+? and (?<target>.+?), deflecting the assault entirely\./,
              /(?<attacker>.+?)'s#{MK_POST} spell is deflected by your barrier in a flash of \w+ light!/,
              %r{Your spell is deflected by (?:<pushBold/>)?the (?<target>.+?)'s#{MK_POST} barrier in a flash of \w+ light!},
              # mirror image - the image takes the hit, not the character
              /A mirror image of (?:you|.+?) shimmers into view, gaining substance just long enough to intercept the attack!/,
            ].freeze),
            OutcomeDef.new(:evade, [
              /By amazing chance, (?<target>.+?) evades the .+?!/,
              /Lying flat on .+? back, (?<target>.+?) leans to one side and dodges the .+?!/,
              /Nearly insensible, (?<target>.+?) desperately evades the .+?!/,
              /Rolling hurriedly, (?<target>.+?) blocks the .+? with .+?!/,
              /Stupefied, (?<target>.+?) evades the .+? by blind luck!/,
              /Unable to focus clearly, (?<target>.+?) blindly evades the .+?!/,
              /(?<target>.+?) barely dodges the .+?!/,
              /(?<target>.+?) dodges just in the nick of time!/,
              /(?<target>.+?) dodges out of the way!/,
              /(?<target>.+?) evades the .+? by a hair!/,
              /(?<target>.+?) evades the .+? by inches!/,
              /(?<target>.+?) evades the .+? with ease!/,
              /(?<target>.+?) flails on the ground but manages to barely dodge the .+?!/,
              /(?<target>.+?) gracefully avoids the .+?!/,
              /(?<target>.+?) moves at the last moment to evade the .+?!/,
              /(?<target>.+?) rolls to one side and evades the .+?!/,
              /(?<target>.+?) skillfully dodges the .+?!/,
              /(?<target>.+?) stumbles dazedly, somehow managing to evade the .+?!/,
              /(?<target>.+?) outmaneuvers the attack and completely avoids it!/,
              /You outmaneuver the attack and completely avoid it!/,
              /(?<target>.+?) dodges an incoming arrow!/,
              /Sensing your attack coming, (?<target>.+?) leaps to safety as you move to attack (?:him|her|it), leaving you out of position!/,
              /Unable to focus clearly, you blindly evade the attack!/,
              /You barely dodge the attack!/,
              /Unfortunately, your aim is off and your attack goes wide!/,
              /You evade the (?:attack|missile|bolt) by inches!/,
              /You evade the (?:attack|missile|bolt) by a hair!/,
              /You evade the (?:attack|missile|bolt) with ease!/,
              /You evade the attack with incredible finesse!/,
              /You dodge just in the nick of time!/,
              /You dodge out of the way!/,
              /By amazing chance, you evade the .+?!/,
              /You move at the last moment to evade the .+?!/,
              /You gracefully avoid the .+?!/,
              /You skillfully dodge the .+?!/,
              /With blinding speed, (?:you|(?<target>.+?)) dodges? the .+?!/,
              /You move slightly, letting the attack pass harmlessly by!/,
              /You move quickly avoiding the magic!/,
              /You manage to jump out of the way!/,
              /Staggering like a punch-drunk brawler, you dodge the .+?!/,
              /Sensing an impending attack, you manage to roll hard to the side/,
              /Stupefied, you evade the .+? by blind luck!/,
              /You manage to dodge (?<attacker>.+?)'s#{MK_POST} blow!/,
              /(?<attacker>.+?) attempts to bearhug (?<target>.+?), but .+? to evade #{MK_PRE}(?:his|her|its)#{MK_POST} grasp!/,
              /You dodge the .+? with barely a hair's breadth to spare!/,
              /You manage to dodge .+?(?:, and it passes harmlessly by| in the nick of time)!/,
              /You dodge the .+? by a hair!/,
              /Bobbing and weaving, you dodge the .+?!/,
              /(?<target>.+?) deftly avoids the stroke\./,
              # 1712 Ethereal Censer per-target dodge - pairs with the
              # :ethereal_censer "becomes enveloped" initiation (round-11/12
              # coverage channel: 13,713 lines across 12 creatures)
              /(?<target>.+?) avoids the incense smoke!/
            ].freeze),
            OutcomeDef.new(:block, [
              /Amazingly, (?<target>.+?) manages to block the .+? with .+?!/,
              /At the last moment, (?<target>.+?) blocks the .+? with .+?!/,
              /Fumbling aimlessly, (?<target>.+?) manages to deflect the .+? with .+?!/,
              /In the nick of time, (?<target>.+?) interposes .+? between .+? and the .+?!/,
              /Lying flat on .+? back, (?<target>.+?) barely deflects the .+? with .+?!/,
              /Nearly insensible, (?<target>.+?) desperately blocks the .+? with .+?!/,
              /Nearly insensible, (?<target>.+?) wildly blocks the .+? with .+?!/,
              /Reeling and staggering, (?<target>.+?) barely blocks the .+? with .+?!/,
              /Stupefied, (?<target>.+?) blocks the .+? by blind luck!/,
              /You harmlessly deflect the charge!/,
              /Unable to focus clearly, (?<target>.+?) blindly blocks the .+?!/,
              /With extreme effort, (?<target>.+?) blocks the .+? with .+?!/,
              /With no room to spare, (?<target>.+?) blocks the .+? with .+?!/,
              /(?<target>.+?) awkwardly scrambles along the ground to avoid the .+?!/,
              /(?<target>.+?) awkwardly scrambles to the right and blocks the .+?!/,
              /(?<target>.+?) barely manages to block the .+? with .+?!/,
              /(?<target>.+?) easily blocks the .+? with .+?!/,
              /(?<target>.+?) flails on the ground but manages to block the .+? with .+?!/,
              /(?<target>.+?) interposes .+? between .+? and the .+?!/,
              /(?<target>.+?) manages to block the .+? with .+?!/,
              /(?<target>.+?) rolls to one side and deflects the .+? with .+?!/,
              /(?<target>.+?) skillfully blocks the .+? with .+?!/,
              /(?<target>.+?) skillfully interposes .+? between .+? and the .+?!/,
              /(?<target>.+?) stumbles dazedly, but (?:manages to )?blocks? the .+? with .+?!/,
              /(?<target>.+?) deflects your (?<weapon>.+?) with #{MK_PRE}(?:his|her|its)#{MK_POST} .+?!/,
              /(?<target>.+?) stumbles dazedly, somehow managing to block the .+? with .+?!/,
              /(?<target>.+?) tumbles to the side and deflects the .+? with .+?!/,
              /(?<target>.+?) harmlessly deflects the charge!/,
              /You gauge the attack and expertly deflect it with your .+?!/,
              /At the last moment, you block the missile with your .+?!/,
              /In the nick of time, you interpose your .+? between yourself and the (?:missile|blow)!/,
              /Though dazed, you easily deflect the .+? with your .+?!/,
              /Although completely oblivious, you instinctively block the .+? with your .+?!/,
              /You skillfully block the missile with your .+?!/,
              /(?:With no room to spare|With blinding speed|With extreme effort|Amazingly), you(?: manage to)? block the .+? with your .+?!/,
              /At the last moment, you block the (?:attack|missile|bolt|blow) with your .+?!/,
              /You (?:easily|skillfully) block the (?:attack|missile|bolt|blow) with your .+?!/,
              /You barely manage to block the .+? with your .+?!/,
              /With incredible finesse, you deflect the .+? with your .+?!/,
              /You block the (?:attack|missile|bolt|blow) with your .+?!/,
              /You manage to deflect (?<attacker>.+?)'s#{MK_POST} blow in the nick of time!/
              # (spell-deflect-by-barrier lines live in :intercept, which wins
              # first-match; keeping copies here would be dead and would also
              # contradict :intercept's design note that these are NOT :block)
            ].freeze),
            OutcomeDef.new(:parry, [
              /Amazingly, (?<target>.+?) manages to parry the .+? with .+?!/,
              /At the last moment, (?<target>.+?) parries the .+? with .+?!/,
              /Using the bone plates surrounding .+? forearms, (?<target>.+?) parries your .+?!/,
              /With extreme effort, (?<target>.+?) beats back the .+? with .+?!/,
              /With no room to spare, (?<target>.+?) manages to parry the .+? with .+?!/,
              /(?<target>.+?) barely manages to fend off the .+? with .+?!/,
              /(?<target>.+?) flails on the ground but manages to parry the .+? with .+?!/,
              /(?<target>.+?) rolls to one side and parries the .+? with .+?!/,
              /With no room to spare, you manage to parry the blow with your .+?!/,
              /Using the bone plates surrounding your forearms, you parry the attack!/,
              /(?<target>.+?) manages to fend off (?:your|(?<attacker>.+?)'s#{MK_POST}) attack!/,
              /At the last moment, you parry the .+? with your .+?!/,
              /Amazingly, you manage to parry the .+? with your .+?!/,
              /You barely manage to fend off the .+? with your .+?!/,
              /With extreme effort, you beat back the .+? with your .+?!/,
              /You gauge the attack and expertly parry it with your .+?!/
            ].freeze),
            OutcomeDef.new(:resisted, [
              /(?<target>.+?) shrugs off some of the damage!/,
              /(?<target>.+?)'s#{MK_POST} exterior hardens for a moment and softens the attack!/,
              /(?<target>.+?) aura absorbs some of the damage!/,
              /(?<target>.+?) manages to block some of the (?:elemental )?damage with #{MK_PRE}(?:his|her|its)#{MK_POST} .+?!/,
              /(?<armor>.+?) partially deflects the onslaught of the \w+ attack\./,
              /Your body resists the \w+ damage and lessens the severity of the attack!/
            ].freeze),
            # Immunity: the spell simply has no effect - no CS/TD roll is
            # printed at all (e.g. 501 Sleep vs a troll wraith, forge
            # capture), so this line is the ONLY thing that settles the
            # cast event. Distinct from :warded (a roll happened and failed).
            OutcomeDef.new(:unaffected, [
              /(?<target>.+?) does not seem to be affected\./,
              # AoE sweep no-effect lines (round-12 tracker candidates).
              # The fused "buffeted ..., but is unaffected" form MUST sit
              # before the bare form: the lazy target capture of the bare
              # pattern would otherwise swallow "... waves, but" into the
              # target text.
              #   "A giant warg is buffeted by the formless black waves,
              #    but is unaffected."  (~2.0k lines, ewave/sphere family)
              /(?<target>.+?) is buffeted by the .+?, but is unaffected\./,
              #   "A tattooed gigas berserker is unaffected."  (~2.2k lines)
              /(?<target>.+?) is unaffected\./,
              # Elemental no-effect on immune creatures - per-target line of
              # our elemental AoEs/flares (round-11/12 status candidate list:
              # plasma 5,983x/4, electricity 5,571x/5, cold 4,479x/7,
              # heat 1,094x/4, impact 34,531x/4 from the 2026-09-03
              # full-corpus sweep; only observed elements listed). Owner
              # note 2026-09-04: many of these are likely TEMPORARY
              # immunities a creature gains after taking damage of that
              # type, not permanent traits - so consumers should treat
              # the outcome as per-attack fact, not a creature attribute.
              /(?<target>.+?) is unharmed by the (?:plasma|electricity|cold|heat|impact)!/,
              # holy-luminescence AoE no-effect (full-corpus sweep 2026-09-03:
              # 1,239 lines across 50+ creatures)
              /(?<target>.+?) endures the luminescence and is unscathed!/,
              # magic-avoid special defense (triton brawler): follows the
              # gesture with NO roll printed, so like the troll-wraith
              # immunity above it is the ONLY line that settles the cast
              # (exchange evidence 2026-09-03; 21.7k lines)
              /(?<target>.+?)'s#{MK_POST} face goes blank for a moment before returning to normal, as #{MK_PRE}(?:he|she|it)#{MK_POST} successfully avoids the effects of the magical attack!/
            ].freeze),
            # Attacking a corpse: the attack never happens - no roll,
            # no roundtime, no attack def (owner ruling 2026-09-05).
            # Pure information for the player; claimed so 2k lines
            # across 22 creatures stop reading as unmatched.
            OutcomeDef.new(:already_dead, [/(?<target>.+?) is quite dead already\./].freeze),
            OutcomeDef.new(:fumble, [/d100 == 1 FUMBLE!/].freeze),
            OutcomeDef.new(:hindrance, [/\[Spell Hindrance for (?<armor>.+?) is (?<hindrance_amount>\d+)% with current Armor Use skill, d100= (?<roll>\d+)\]/].freeze),
            OutcomeDef.new(:confused, [/Something confusing enters your mind at the worst possible moment, and the distraction disrupts your .+?!/].freeze)
          ].freeze

          # PARKED - flavor lines that accompany a failed warding attempt.
          # Believed redundant: the result is already established by the
          # "Warded off!" line / CS-vs-TD resolution, so matching these would
          # only double-record the outcome. Kept here in case any of them
          # turns out to be the ONLY line a given spell prints on failure,
          # in which case it should be promoted back into :warded.
          #   /A dull grey beam snakes out toward you, but dissipates upon impact\./
          #   /The web turns away harmlessly from (?<target>[^.]+)\./
          #   /The wisps dissipate harmlessly into the air\./
          #   /Your attack whistles right through (?<target>[^.]+)\./
          #   /(?<target>.+?) wavers as your attack passes right through #{MK_PRE}(?:it|him|her)#{MK_POST}!/
          #   /Your heart leaps for an instant, but you control the urge to run\./
          #   /(?<attacker>.+?) attempts to jab (?<weapon>.+?) into your .+?, but it doesn't faze you\./
          #   /(?<target>.+?) remains resolute in the face of the tremendous sound!/

          # Flattened [pattern, type] pairs in definition order, used for
          # first-match-wins scanning.
          #
          # @return [Array<Array(Regexp, Symbol)>]
          OUTCOME_LOOKUP = OUTCOME_DEFS.flat_map { |d| d.patterns.map { |rx| [rx, d.type] } }.freeze

          # Cheap literal pre-filter over all outcome patterns; ALWAYS_SCAN
          # holds the few patterns the gate cannot cover.
          GATE, ALWAYS_SCAN = PatternGate.build(OUTCOME_LOOKUP.map(&:first))

          # Classifies a single game line as an attack outcome.
          #
          # @param line [String] one line of game text (tags included)
          # @return [Symbol, nil] outcome type (:miss, :hit, :evade, ...),
          #   or nil when the line is not an outcome line
          def self.parse(line)
            return nil unless GATE.match?(line) || ALWAYS_SCAN.any? { |rx| rx.match?(line) }

            OUTCOME_LOOKUP.each { |rx, type| return type if rx.match?(line) }
            nil
          end
        end

        # Parses combat resolution (roll) lines - the numeric line that
        # decides an attack (AS/DS, CS/TD, UAF/UDF, SMR/SSR, and friends) -
        # into a typed hash of its components.
        module Resolutions
          # One roll grammar and the line format(s) that carry it.
          #
          # @!attribute type
          #   @return [Symbol] roll family (:as_ds, :cs_td, :smr, ...)
          # @!attribute patterns
          #   @return [Array<Regexp>] roll-line formats; every named capture
          #     becomes a key in the parsed hash
          ResolutionDef = Struct.new(:type, :patterns)

          # All resolution definitions, in match-priority order.
          #
          # @return [Array<ResolutionDef>]
          RESOLUTION_DEFS = [
            ResolutionDef.new(:as_ds, [
              # optional "+ N +" term = True Strike bonus; the die is not
              # always d100 there either (d80, d40 at higher tiers)
              /AS: (?<as>[+\-\d]+) vs DS: (?<ds>[+\-\d]+) with AvD: (?<avd>[+\-\d]+) \+ (?:(?<bonus>\d+) \+ )?d\d+ roll: (?<roll>[+\-\d]+) = (?<result>[+\-\d]+)/
            ].freeze),
            ResolutionDef.new(:cs_td, [
              /CS: (?<cs>[+\-\d]+) - TD: (?<td>[+\-\d]+) \+ CvA: (?<cva>[+\-\d]+) \+ d\d+: (?<roll>[+\-\d]+) \+ Bonus: (?<bonus>[+\-\d]+) == (?<result>[+\-\d]+)/,
              # trailing "- N" modifier (Torment 718, Untrammel 209, Vertigo 1219)
              /CS: (?<cs>[+\-\d]+) - TD: (?<td>[+\-\d]+) \+ CvA: (?<cva>[+\-\d]+) \+ d\d+: (?<roll>[+\-\d]+)(?: - (?<penalty>[+\-\d]+))? == (?<result>[+\-\d]+)/
            ].freeze),
            ResolutionDef.new(:uaf_udf, [
              /UAF: (?<uaf>\d+) vs UDF: (?<udf>\d+) = (?<total>[.\d]+) \* MM: (?<mm>\d+) \+ d\d+: (?<roll>\d+) = (?<result>\d+)/
            ].freeze),
            ResolutionDef.new(:smr, [
              # Penalty term and negative results are both live (Rysk logs)
              /\[SMR result: (?<result>-?\d+) \(Open d100: (?<roll>[+\-\d]+)(?:, Bonus: (?<bonus>[+\-\d]+))?(?:, Penalt(?:y|ies): (?<penalty>[+\-\d]+))?\)\]/
            ].freeze),
            # Standard Save Roll - follows intimidation/terrorize checks
            ResolutionDef.new(:ssr, [
              /\[SSR result: (?<result>-?\d+) \(Open d100: (?<roll>[+\-\d]+)\)\]/
            ].freeze),
            # Imbed/crystal activation roll - sits between a wand wave and
            # its spell cast ("1d100: 30 + Modifiers: 375 == 405"); gives
            # the otherwise fact-less :wand event its roll (round-6, from
            # the fury/divine_fury real-feed capture)
            ResolutionDef.new(:activation, [
              /1d100: (?<roll>[+\-\d]+) \+ Modifiers: (?<mods>[+\-\d]+) == (?<result>[+\-\d]+)/
            ].freeze),
            # Legacy maneuver roll (lowercase "open", no SMR prefix). Most
            # cmans were converted to SMR but the old format is kept as a
            # fallback - it costs one gate literal and catches stragglers.
            ResolutionDef.new(:maneuver_roll, [
              /\[Roll result: (?<result>-?\d+) \(open d100: (?<roll>-?\d+)\)(?:,? (?:Bonus: (?<bonus>-?\d+)|Penalt(?:y|ies): (?<penalty>-?\d+)))?\]/
            ].freeze),
            # Fear resolution (Sheer fear) - its own roll grammar entirely
            ResolutionDef.new(:fear, [
              /FS: (?<fs>[+\-\d]+) - FD: (?<fd>[+\-\d]+) \+ FvP: (?<fvp>[+\-\d]+) \+ d100\(L\): (?<roll>[+\-\d]+) = (?<result>[+\-\d]+)/
            ].freeze)
          ].freeze

          # Flattened [pattern, type] pairs in definition order.
          #
          # @return [Array<Array(Regexp, Symbol)>]
          RESOLUTION_LOOKUP = RESOLUTION_DEFS.flat_map { |d| d.patterns.map { |rx| [rx, d.type] } }.freeze

          # Cheap literal pre-filter over all resolution patterns; ALWAYS_SCAN
          # holds the few patterns the gate cannot cover.
          GATE, ALWAYS_SCAN = PatternGate.build(RESOLUTION_LOOKUP.map(&:first))

          # Parses a single roll line into its numeric components.
          #
          # @param line [String] one line of game text
          # @return [Hash, nil] { type: :as_ds, as: 739, ds: 376, ..., result: 469 }
          #   with every named capture converted to Integer (total, which can
          #   be fractional in UCS, converts to Float when it contains a dot),
          #   or nil when the line is not a resolution line
          def self.parse(line)
            return nil unless GATE.match?(line) || ALWAYS_SCAN.any? { |rx| rx.match?(line) }

            RESOLUTION_LOOKUP.each do |rx, type|
              next unless (match = rx.match(line))

              result = { type: type }
              match.names.each do |cap|
                next unless match[cap]

                result[cap.to_sym] = match[cap].include?('.') ? match[cap].to_f : match[cap].to_i
              end
              return result
            end
            nil
          end
        end
      end
    end
  end
end
