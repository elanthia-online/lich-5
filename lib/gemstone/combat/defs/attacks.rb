# frozen_string_literal: true

require_relative 'pattern_gate'

module Lich
  module Gemstone
    module Combat
      module Definitions
        module Attacks
          AttackDef = Struct.new(:name, :patterns)

          # Spell attack defs (SPELL_ATTACKS, WIKI_SPELL_ATTACKS,
          # THIRD_PERSON_SPELL_ATTACKS) live in defs/spells.rb. Loaded
          # mid-module because spells.rb shares AttackDef (defined above);
          # match order is set solely by the ALL_ATTACKS concatenation below,
          # not by this require's position.
          require_relative 'spells'

          # Ordered BEFORE the generic swing defs: these lines end in
          # "and connect(s)!" (or aim at "your <item>") and the plain
          # "swings ... at ...!" patterns would swallow them with the tail
          # folded into the target capture.
          PRIORITY_ATTACKS = [
            AttackDef.new(:sunder_shield, [/You swing your .+? at (?<target>.+?)'s#{MK_POST} .+? and connect!/].freeze),
            AttackDef.new(:disarm_weapon, [
              /Choosing your opening, you attempt to disarm (?<target>.+?)'s#{MK_POST} (?<weapon>.+?) with your .+? and connects?!/,
              /(?<attacker>.+?) swings (?<weapon>.+?) at your .+? and connects!/
            ].freeze),
            AttackDef.new(:tackle, [/You hurl yourself at (?<target>.+?) and connect!/].freeze)
          ].freeze

          # Core attack patterns - most common combat actions
          BASIC_ATTACKS = [
            AttackDef.new(:attack, [
              /You(?<aimed> take aim and)? swing .+? at (?<target>[^!]+)!/,
              /You(?<aimed> take aim and)? (?:punch|jab|kick|grapple) with (?<weapon>.+?) at (?<target>[^!]+)!/
            ].freeze),
            AttackDef.new(:fire, [/You(?<aimed> take aim and)? fire .+? at (?<target>[^!]+)!/].freeze),
            AttackDef.new(:hurl, [/You(?<aimed> take aim and)? throw (?<weapon>.+?) at (?<target>[^!]+)!/].freeze),
            AttackDef.new(:grapple, [/You(?<aimed> make a precise)? attempt to grapple (?<target>[^!]+)!/].freeze),
            AttackDef.new(:jab, [/You(?<aimed> make a precise)? attempt to jab (?<target>[^!]+)!/].freeze),
            AttackDef.new(:kick, [/You(?<aimed> make a precise)? attempt to kick (?<target>[^!]+)!/].freeze),
            AttackDef.new(:punch, [/You(?<aimed> make a precise)? attempt to punch (?<target>[^!]+)!/].freeze),
            AttackDef.new(:wand, [/You wave your .+ at (?<target>[^\.]+)\./].freeze)
          ].freeze

          # Weapon techniques - melee and ranged maneuvers alike (the ranged
          # defs were observed live on the forge test-server runs)
          WEAPON_ATTACKS = [
            AttackDef.new(:cripple, [
              # the sidle connect line ("You sidle in close and drag the
              # blade...") sits between the SMR and the damage - a hit line,
              # NEVER a def (it double-opened the event once markup-tolerant)
              /You reverse your grip on your .+? and dart toward (?<target>.+?) at an angle!/
            ].freeze),
            AttackDef.new(:flurry, [
              /Flowing with deadly grace, you smoothly reverse the direction of your blades? and slash again!/,
              # flurry is an assault attack: any setup except two-handed
              # (one weapon, dual wield, or weapon+shield), so the weapon
              # phrase and strike verb vary with the loadout
              /With fluid motion, you guide your .+?, \w+ing toward (?<target>.+?) at the apex of (?:their|its) deadly arc!/
            ].freeze),
            AttackDef.new(:pummel, [/With deliberate brutality, you bring your .+? around to pummel (?<target>[^!]+)!/].freeze),
            # Pulverize (THB AoE): untargeted opener; per-target attribution
            # is UNRELIABLE (weapon_pulverize.txt) - the "strikes true, but X
            # shrugs off" pre-roll line only prints vs undead with an
            # unblessed weapon, crit lines only sometimes name the target,
            # and a clean-miss roll can be fully anonymous. Combat-dropdown
            # order != hit order, and mirror image repeats the same target,
            # so positional inference is also out. Bind targets only from
            # explicit naming lines; leave anonymous rolls unattributed.
            # TODO: revisit with more logs (blessed weapon, living targets).
            # 2p (ours) and 3p (a nearby player's - the opener names them, so
            # the whole actor-less AoE swing chain that follows is theirs, not
            # ours; foreign_caster keeps it off our ledger - real-feed,
            # GSIV-Nisugi 2026-09-06: Heavenscent's pulverize dumped ~825 swing
            # damage into our rollup via the open web event).
            AttackDef.new(:pulverize, [
              /You wheel your .+? overhead before slamming it around in a wide arc to pulverize your foes!/,
              # attacker uses the file's .+? convention (matches names with
              # apostrophes/hyphens etc.); the "wheels ... overhead ... pulverize
              # ... foes" tail bounds it. The old [A-Z][a-z]+ dropped any name
              # outside a single plain-cased word, silently failing to arm the
              # foreign latch this def exists to feed.
              /(?<attacker>.+?) wheels (?:his|her|its) .+? overhead before slamming it around in a wide arc to pulverize (?:his|her|its) foes!/
            ].freeze),
            AttackDef.new(:dizzying_swing, [/You heft your .+? and, looping it once to build momentum, lash out in a strike at (?<target>.+?)'s#{MK_POST} head!/].freeze),
            AttackDef.new(:guardant_thrust, [/You lunge at (?<target>.+?), guiding your .+? with both hands in a powerful thrust!/].freeze),
            AttackDef.new(:cyclone, [
              /You whirl on (?<target>[^!]+)!/,
              /You redirect your .+? toward (?<target>[^!]+)!/,
              /Pivoting sharply, you lunge at (?<target>[^!]+)!/
            ].freeze),
            # Clash (multi-opponent brawl): untargeted opener, per-target
            # engagement lines. The lunge form is comma-fenced so guardant
            # thrust's "You lunge at X, guiding..." never files here.
            AttackDef.new(:clash, [
              /Steeling yourself for a brawl, you plunge into the fray!/,
              /You lunge at (?<target>[^!,]+)!/,
              /You launch yourself at (?<target>[^!,]+)!/,
              /You charge toward (?<target>[^!,]+)!/
            ].freeze),
            # Fury (UAC/brawling): its own opener; the "Relentless in your
            # assault" line that rides along in fury logs stays filed under
            # :relentless_assault (a separate PSM whose passive fires there)
            AttackDef.new(:fury, [/With a percussive snap, you shake out your arms in quick succession and bear down on (?<target>.+?) in a fury!/].freeze),
            AttackDef.new(:twinhammer, [/You raise your hands high, lace them together and bring them crashing down towards (?<target>[^!]+)!/].freeze),
            AttackDef.new(:wblade, [
              /You turn, blade spinning in your hand toward (?<target>[^!]+)!/,
              /You angle your blade at (?<target>.+?) in a crosswise slash!/,
              /In a fluid whirl, you sweep your blade at (?<target>[^!]+)!/,
              /Your blade licks out at (?<target>.+?) in a blurred arc!/,
              # AoE opener, dual-wield form (real-feed capture,
              # logs/examples/whirling_blade.txt) - no target on the line;
              # per-strike rolls and linked crit lines bind targets
              /With a broad flourish, you weave your .+? into a whirling display of coordination and menace!/
            ].freeze),
            AttackDef.new(:barrage, [/Nocking another arrow to your bowstring, you swiftly draw back and loose again!/].freeze),
            # suppressing hail: non-damaging AoE, per-target SMR + root follow
            AttackDef.new(:pindown, [/Without bothering to aim, you loose a chaotic hail of arrows to pin down your foes!/].freeze),
            # Volley (multi-round AoE): the bow-raise line is the SEQUENCE
            # prefix, not an attack - see Sequences :volley. It prints once
            # per volley while the hail-shadow line that opens the sequence
            # prints once per ROUND (logs/examples/weapon_volley.txt: 4 bow
            # lines, 16 shadow lines). These per-arrow lines are the real
            # attack defs - each one names the target it struck.
            AttackDef.new(:volley, [
              /An arrow finds its mark!  (?<target>.+?) is hit!/,
              /An arrow pierces (?<target>[^!]+)!/,
              /An arrow skewers (?<target>[^!]+)!/,
              /(?<target>.+?) is struck by a falling arrow!/,
              /(?<target>.+?) is transfixed by an arrow's descent!/
            ].freeze)
          ].freeze

          # Combat maneuvers (cmans, PSMs, techniques) - both persons where
          # the wiki documents them. Sources: docs/COMBAT_DEFS_WIKI_CATALOG.md
          MANEUVER_ATTACKS = [
            AttackDef.new(:haymaker, [
              /You clench your (?:right|left) fist and bring your arm back for a roundhouse punch aimed at (?<target>[^!]+)!/,
              /(?<attacker>.+?) clenches #{MK_PRE}(?:his|her|its)#{MK_POST} (?:right|left) fist and brings #{MK_PRE}(?:his|her|its)#{MK_POST} arm back for a roundhouse punch aimed at (?<target>[^!]+)!/
            ].freeze),
            AttackDef.new(:headbutt, [
              /You charge towards (?<target>.+?) and attempt to headbutt #{MK_PRE}(?:him|her|it)#{MK_POST}!/,
              /(?<attacker>.+?) charges towards you and attempts a headbutt!/
            ].freeze),
            AttackDef.new(:bull_rush, [
              /You rush towards (?<target>.+?) and connect with a shoulder check!/,
              /(?<attacker>.+?) rushes towards (?<target>.+?) and connects with a shoulder check!/
            ].freeze),
            AttackDef.new(:cutthroat, [
              /You spring from hiding and attempt to grasp (?<target>.+?) by the chin while slitting #{MK_PRE}(?:his|her|its)#{MK_POST} throat with your .+?!/,
              /You spring from hiding and attempt to cut (?<target>.+?)'s#{MK_POST} throat!/,
              /(?<attacker>.+?) springs upon (?<target>you|.+?) from behind and attempts to slit #{MK_PRE}(?:your|his|her|its)#{MK_POST} throat(?: with #{MK_PRE}(?:his|her|its)#{MK_POST} .+?)?!/
            ].freeze),
            AttackDef.new(:bearhug, [/(?<attacker>.+?) charges towards (?<target>you|.+?) and attempts to grasp #{MK_PRE}(?:you|him|her|it)#{MK_POST} in a ferocious bearhug!/].freeze),
            AttackDef.new(:charge, [
              /(?<attacker>.+?) rushes forward at (?<target>you|.+?) with #{MK_PRE}(?:his|her|its)#{MK_POST} .+? and attempts a charge!/,
              # 2p (logs/examples/weapon_charge.txt). The graded connect line
              # ("You lunge forward with an expert charge!") sits between the
              # SMR and the damage - a hit line, NEVER a def (double-open)
              /You rush forward at (?<target>.+?) with your .+? and attempt a charge!/
            ].freeze),
            AttackDef.new(:garrote, [
              /You fling your .+? around (?<target>.+?)'s#{MK_POST} neck and snap it taut\./,
              /(?<attacker>.+?) (?:jumps on your back and )?flings a (?<weapon>.+?) around your neck and snaps it taut\./
            ].freeze),
            AttackDef.new(:groin_kick, [
              # the short "kicks at" form is the ATTEMPT (opens the roll);
              # "and connects!" is the success line
              /(?<attacker>.+?) kicks at (?<target>your|.+?'s)#{MK_POST} groin!/,
              # 2p (logs/examples/cman_groin_kick.txt)
              /You attempt to deliver a kick to (?<target>.+?'s)#{MK_POST} groin!/,
              /(?<attacker>.+?) kicks #{MK_PRE}(?:his|her|its)#{MK_POST} leg at (?<target>your|.+?'s)#{MK_POST} groin and connects!/
            ].freeze),
            AttackDef.new(:dirtkick, [/You manage to kick a large clump of dust at (?<target>[^!]+)!/].freeze),
            # Feint: the SMR roll PRECEDES this line - the result line is the
            # only carrier of the target (logs/examples/cman_feint.txt)
            AttackDef.new(:feint, [
              /You feint (?:high|low|to the (?:left|right))\.\s+(?<target>.+?) buys the ruse/,
              /You feint (?:high|low|to the (?:left|right)), but (?<target>.+?) (?:isn't|is not) fooled/
            ].freeze),
            # Spell Thieve (cman sthieve): the ward-probe form with no attack
            # is a prefix - no roll follows it, so no def
            AttackDef.new(:spell_thieve, [/You hang back for a moment and concentrate on the magical wards surrounding (?<target>[^,]+), before sneaking in an attack/].freeze),
            # 2p leg sweep (logs/examples/cman_sweep.txt); 3p lives in
            # THIRD_PERSON_ATTACKS with the cartwheel wording
            AttackDef.new(:leg_sweep, [/You crouch and sweep a leg at (?<target>[^!]+)!/].freeze),
            AttackDef.new(:silent_strike, [/You quickly leap from hiding to deliver your attack!/].freeze),
            # 2p ambush re-emerge: printed per strike taken from hiding after
            # a shroud restealth, with the target arriving on the following
            # resisted/evade/roll lines (logs/examples/weapon_pulverize.txt).
            # "You leap from hiding to attack!" is NOT here: cman_garrote.txt
            # proves it a PREFIX - its SMR belongs to the maneuver line after.
            AttackDef.new(:ambush, [/You step from hiding and attack!/].freeze),
            # Thrash: the rush line is the ASSAULT opener (defs/assaults.rb);
            # this per-hit line between the rolls is the def
            # (logs/examples/weapon_thrash.txt)
            AttackDef.new(:thrash, [
              /You bring your .+? around in a tight arc to batter (?<target>.+?) into submission!/
            ].freeze),
            AttackDef.new(:smite, [/You level your .+? at (?<target>.+?) and call down the excoriating power of .+? to smite #{MK_PRE}(?:him|her|it)#{MK_POST}!/].freeze),
            AttackDef.new(:flurry_of_blows, [/You quickly pivot and follow up with a jab against (?<target>[^!]+)!/].freeze),
            AttackDef.new(:executioners_stance, [/Barely breaking your momentum, you continue on to attack (?<target>[^!]+)!/].freeze),
            AttackDef.new(:whirling_dervish, [/You deftly switch your ongoing (?:attack|assault) towards (?<target>[^!]+)!/].freeze),
            AttackDef.new(:subdual_strike, [/(?<attacker>.+?) springs from the shadows and strikes at you!/].freeze),
            AttackDef.new(:trip, [
              /With a fluid whirl, (?<attacker>.+?) plants (?<weapon>.+?) firmly into the ground near you and jerks the weapon sharply sideways\./,
              # 2p (logs/examples/cman_trip.txt); SMR between this and result
              /With a fluid whirl, you plant (?<weapon>.+?) firmly into the ground near (?<target>.+?) and jerk the weapon sharply sideways\./
            ].freeze),
            # 2p shield maneuvers (3p bash/charge/throw live in THIRD_PERSON_ATTACKS)
            AttackDef.new(:shield_bash, [/You lunge forward at (?<target>.+?) with your (?<weapon>.+?) and attempt a shield bash!/].freeze),
            AttackDef.new(:shield_pin, [/You attempt to expose a vulnerability with a diversionary shield bash on (?<target>[^!]+)!/].freeze),
            AttackDef.new(:shield_push, [/You raise your (?<weapon>.+?) before you and attempt to push (?<target>.+?) away!/].freeze),
            AttackDef.new(:shield_strike, [/You launch a quick bash with your (?<weapon>.+?) at (?<target>[^!]+)!/].freeze),
            AttackDef.new(:shield_charge, [/You raise your (?<weapon>.+?) before you and charge headlong towards (?<target>[^!]+)!/].freeze),
            # Assassinate (rogue): the uncoil line opens the event; the SMR
            # roll follows it directly, then the "carve into" hit line
            AttackDef.new(:eviscerate, [/You uncoil from the shadows, your (?<weapon>.+?) poised to eviscerate (?<target>[^!]+)!/].freeze),
            # Coup de Grace - messaging varies by weapon type; this is the
            # THW form, catalogue other weapon variants as they're observed
            AttackDef.new(:coup_de_grace, [/You lunge towards (?<target>.+?), intending to finish #{MK_PRE}(?:him|her|it)#{MK_POST} off!/].freeze),
            # "dark wings" equipment proc (SMR attack); name pending
            AttackDef.new(:shadow_barb, [/Your umbrous wings twitch sharply, launching a barbed shard of shadow that hisses through the air toward (?<target>[^!]+)!/].freeze),
            # Whirlwind (THW AoE, single round - not a sequence). Known to
            # have ~4 message variants; two catalogued so far plus the
            # per-target strike line, all under one name.
            AttackDef.new(:whirlwind, [
              /Twisting and spinning among your foes, you lash out again and again with the force of a reaping whirlwind!/,
              /You turn and sweep your (?<weapon>.+?) at (?<target>[^!]+)!/,
              /(?<target>.+?) is struck in your flurry of sweeping strikes!/
            ].freeze),
            # rogue KO-strike: SMR follows directly, then the paralyzed status
            AttackDef.new(:subdue, [/You spring from hiding and aim a blow at (?<target>.+?)'s#{MK_POST} head!/].freeze),
            # shield-strike PSM follow-up (its own SMR precedes; round-5)
            AttackDef.new(:relentless_assault, [
              /Relentless in your assault, you unleash a frenzy of violence upon (?<target>[^!]+)!/,
              /You assault (?<target>.+?) with an unrelenting fury!/
            ].freeze),
            # bard sonic disruption: the renewal verses are untargeted; this
            # per-target line sits between the CS/TD roll and the damage
            # (same shape as the volley per-arrow defs)
            AttackDef.new(:sonic_disruption, [/(?<target>.+?) reels under the force of the sonic vibrations!/].freeze),
            AttackDef.new(:hamstring, [/You lunge forward and try to hamstring (?<target>.+?) with your .+?!/].freeze),
            # Tremors: rollless AoE; per-target balance-loss + weakened follow
            AttackDef.new(:tremors, [
              /As (?:you|(?<attacker>.+?)) stomps? #{MK_PRE}(?:your|his|her|its)#{MK_POST} foot sharply, the (?:ground|floor) shakes wildly!/,
              # mastodon variant (round-5 corpus)
              /(?<attacker>.+?) slams a gigantic foot down, sending tremors rippling outward/
            ].freeze)
          ].freeze

          # Third-person attack initiations: other players and creatures.
          # Catalogued from 2026-08-20 Duskruin arena spectator logs. The
          # same grammar covers both attacker classes - in the live stream
          # player attackers are <a exist> links (negative ids) and creature
          # attackers are pushBold-wrapped links, so the attacker capture
          # uses .+? to span the markup. These enable group-member
          # attribution and creature AS/DS collection (the roll line that
          # follows attaches to the event these lines open).
          # NOTE: 3p spell initiations (:creature_spell, :cast, :channel,
          # :wand, :bolt) live in defs/spells.rb (THIRD_PERSON_SPELL_ATTACKS),
          # spliced into ALL_ATTACKS just before this group.
          THIRD_PERSON_ATTACKS = [
            AttackDef.new(:attack, [
              # known flavor tails ("in a murderous arc") trimmed from the
              # target capture; post-capture normalization is the general
              # answer if more tails appear
              /(?<attacker>.+?) swings (?<weapon>.+?) at (?<target>.+?)(?: in a murderous arc)?!/,
              # UAC strike WITH a weapon = weapon attack, same rule as 2p
              /(?<attacker>.+?) (?:punches|jabs|kicks|grapples) with (?<weapon>.+?) at (?<target>[^!]+)!/,
              # dance-macabre chain swings (round-5: only the last plain
              # swing of a chain matched before these)
              /(?<attacker>.+?) charges, swinging (?<weapon>.+?) at (?<target>[^!]+)!/,
              /(?<attacker>.+?) whirls into a deadly form, swinging (?<weapon>.+?) at (?<target>[^!]+)!/,
              /With an .+? flourish of #{MK_PRE}(?:his|her|its)#{MK_POST} (?<weapon>.+?), (?<attacker>.+?) (?:charges forward, trying to skewer|lashes out at) (?<target>[^!]+)!/
            ].freeze),
            AttackDef.new(:thrust, [/(?<attacker>.+?) thrusts with (?<weapon>.+?) at (?<target>[^!]+)!/].freeze),
            # generic verb parallel to "thrusts with" (creature mstrike
            # swings, e.g. dance macabre, use it too)
            AttackDef.new(:slash, [/(?<attacker>.+?) slashes with (?<weapon>.+?) at (?<target>.+?)(?: in a murderous arc)?!/].freeze),
            AttackDef.new(:fire, [/(?<attacker>.+?) fires (?<weapon>.+?) at (?<target>.+?)(?: but the shot flies wide of the target)?!/].freeze),
            # ".+?" not "[^!]+" for target: the cman form appends " and
            # connects!" which a greedy class would swallow into the target
            AttackDef.new(:tackle, [/(?<attacker>.+?) hurls #{MK_PRE}(?:himself|herself|itself)#{MK_POST} at (?<target>.+?)(?: and connects)?!/].freeze),
            # Maneuver-style strike opener (round-14 sweep: 40/40 resolve
            # in the very next line, usually the target's evanescent
            # shield absorb or an outmaneuver outcome, then the swing
            # continues on that target). Broad creature spread. Target
            # may be "you" (inbound) or a named player (foreign_target).
            AttackDef.new(:positioning_strike, [
              /(?<attacker>.+?) positions #{MK_PRE}(?:himself|herself|itself)#{MK_POST} to attack (?<target>you|\w+)[.!]/
            ].freeze),
            # UAC - "attempts to" (3p) vs the 2p "attempt to" above. The
            # weapon-form ("punches with a katar at") lives under :attack:
            # a UAC strike WITH a weapon resolves as a weapon attack.
            AttackDef.new(:uac, [
              /(?<attacker>.+?) attempts to (?<strike>punch|jab|kick|grapple) (?<target>[^!]+)!/
            ].freeze),
            # creature natural weapons and maneuvers
            AttackDef.new(:natural, [
              /(?<attacker>.+?) claws at (?<target>[^!]+)!/,
              /(?<attacker>.+?) snaps at (?<target>.+?) with its (?<weapon>[^!]+)!/,
              /(?<attacker>.+?) pounds at (?<target>.+?) with #{MK_PRE}(?:his|her|its)#{MK_POST} .*?fists?!/,
              /(?<attacker>.+?) tries to bite (?<target>[^!]+)!/,
              /(?<attacker>.+?) tries to ensnare (?<target>[^!]+)!/,
              /(?<attacker>.+?) charges at (?<target>[^!]+)!/,
              /(?<attacker>.+?) crouches and sweeps a leg at (?<target>[^!]+)!/,
              # generic verb cores (round-5; the hyper-bespoke forms go to
              # the orphan-fallback catalog instead)
              /(?<attacker>.+?) flails with #{MK_PRE}(?:his|her|its)#{MK_POST} .+? at (?<target>[^!]+)!/,
              /(?<attacker>.+?) thrusts down at (?<target>.+?) with #{MK_PRE}(?:his|her|its)#{MK_POST} .+?!/,
              /(?<attacker>.+?) barrels into a merciless charge at (?<target>[^!]+)!/,
              /(?<attacker>.+?) attempts to crush (?<target>.+?) with a vicious stomp!/,
              /(?<attacker>.+?) tries to strangle (?<target>.+?) with/,
              # Inbound forms mined from orphaned AS/DS rolls - each of these
              # left its roll, damage and crits with no event to attach to
              # (1-3% of all AS-roll chunks; see mining_results/inbound_attacks.txt).
              # Keyed on the ACTION, not the creature: "points a clawed finger"
              # arrives under five psionicist adjectives but is one shape.
              /(?<attacker>.+?) rakes at (?<target>.+?) with #{MK_PRE}(?:his|her|its)#{MK_POST} .+?!/,
              /(?<attacker>.+?) pecks viciously at (?<target>.+?) with #{MK_PRE}(?:his|her|its)#{MK_POST} .+?!/,
              /(?<attacker>.+?) lunges at (?<target>.+?), maw slathering as #{MK_PRE}(?:he|she|it)#{MK_POST} tries to take/,
              /(?<attacker>.+?) bounds forward and slashes at (?<target>.+?) with /,
              /(?<attacker>.+?) slices at (?<target>.+?) with an elongated talon!/,
              /(?<attacker>.+?) undulates forward and tries to close #{MK_PRE}(?:his|her|its)#{MK_POST} vast jaws on (?<target>[^!]+)!/,
              /(?<attacker>.+?) tries to stomp on (?<target>[^!]+)!/,
              /(?<attacker>.+?) lowers one shoulder and barrels toward (?<target>[^!]+)!/,
              /Misshapen arms erupt from (?<attacker>.+?) to flail at (?<target>[^!]+)!/,
              /(?<attacker>.+?) whirls on (?<target>[^!]+)!/,
              # Round-7 inbound forms, verified against logs/examples XML.
              # Each left its AS roll, damage and crits unbound.
              /(?<attacker>.+?) slashes relentlessly at (?<target>.+?) with /,
              /(?<attacker>.+?) raises #{MK_PRE}(?:his|her|its)#{MK_POST} fists overhead and flails violently at (?<target>[^!]+)!/,
              /(?<attacker>.+?) opens its stony jaws and tries to savage (?<target>.+?) with /,
              /(?<attacker>.+?) rears up onto its ossified hind legs and kicks at (?<target>.+?) with /,
              # Mounted charge: the rider clause comes FIRST and carries its
              # own link to the mount, so the attacker capture must start at
              # the comma - otherwise "Urged on by the knight riding it"
              # becomes the attacker and the real one is lost.
              /Urged on by .+?, (?<attacker>.+?) gallops into a deadly charge at (?<target>[^!]+)!/,
              # Ward-probe opener (CS/TD follows). "sneaking in an attack on
              # the magical wards" is the creature form of spell_thieve.
              /(?<attacker>.+?) hangs back for a moment and concentrates intently on (?<target>[^,]+), before sneaking in an attack/,
              /(?<attacker>.+?) lifts a slender hand and points unerringly at (?<target>[^!]+)!/
            ].freeze),
            # ambush - "waylay" IS its own attack line (it names a target).
            # The bare "leaps from hiding" form is NOT here: it is a
            # MODIFIER, see AMBUSH_PREFIXES below.
            AttackDef.new(:ambush, [
              /(?<attacker>.+?) steps out of hiding to waylay (?<target>[^!]+)!/,
              # cannibal grapple/lunge forms (round-5)
              /(?<attacker>.+?) leaps from the shadows and (?:throws #{MK_PRE}(?:his|her|its)#{MK_POST} .+? around|hurtles at) (?<target>[^,!]+)/
            ].freeze),
            # PSM maneuvers, third person
            AttackDef.new(:hamstring, [/(?<attacker>.+?) lunges forward and tries to hamstring (?<target>.+?) with #{MK_PRE}(?:his|her|its)#{MK_POST} .+?!/].freeze),
            AttackDef.new(:shield_bash, [
              /(?<attacker>.+?) lunges forward at (?<target>.+?) with #{MK_PRE}(?:his|her|its)#{MK_POST} .+? and attempts a shield bash!/,
              /(?<attacker>.+?) launches a quick bash with (?<weapon>.+?) at (?<target>[^!]+)!/,
              /(?<attacker>.+?) dips #{MK_PRE}(?:his|her|its)#{MK_POST} shoulder and rushes towards (?<target>[^!]+)!/
            ].freeze),
            AttackDef.new(:shield_charge, [
              /(?<attacker>.+?) raises #{MK_PRE}(?:his|her|its)#{MK_POST} (?<weapon>.+?) and charges headlong towards (?<target>[^!]+)!/,
              /(?<attacker>.+?) charges forward at (?<target>.+?) with #{MK_PRE}(?:his|her|its)#{MK_POST} (?<weapon>.+?) and attempts a shield charge!/
            ].freeze),
            AttackDef.new(:shield_throw, [/(?<attacker>.+?) snaps #{MK_PRE}(?:his|her|its)#{MK_POST} arm forward, hurling (?<weapon>.+?) at (?<target>.+?) with all #{MK_PRE}(?:his|her|its)#{MK_POST} might!/].freeze),
            AttackDef.new(:swiftkick, [/(?<attacker>.+?) spins around behind (?<target>[^,]+), attempting a swiftkick!/].freeze),
            AttackDef.new(:leg_sweep, [/(?<attacker>.+?) upends #{MK_PRE}(?:himself|herself)#{MK_POST} into a cartwheel and then, twisting #{MK_PRE}(?:his|her)#{MK_POST} lateral momentum into a spin, drops low and lashes out with one leg at (?<target>[^!]+)!/].freeze),
            AttackDef.new(:smite, [/(?<attacker>.+?) levels #{MK_PRE}(?:his|her)#{MK_POST} .+? at (?<target>.+?) and calls down excoriating power to smite/].freeze),
            AttackDef.new(:thrash, [/(?<attacker>.+?) rushes (?<target>.+?), raising #{MK_PRE}(?:his|her)#{MK_POST} .+? high to deliver a sound thrashing!/].freeze),
            # collateral pin when a mount goes down (rollless; damage follows)
            AttackDef.new(:mount_collapse, [/(?<target>.+?) (?:is|are) pinned beneath (?<mount>.+?) as #{MK_PRE}(?:it|he|she)#{MK_POST} falls!/].freeze)
          ].freeze

          # 2p shield throw: each flash/ricochet line opens its own SMR +
          # damage, one event per bounce target. Ricochet pattern MUST come
          # first or the plain flash pattern swallows it. The wind-up line
          # ("You snap your arm forward, hurling...") is a PREFIX - no def.
          SHIELD_ATTACKS = [
            AttackDef.new(:shield_throw, [
              /Your (?<weapon>.+?) ricochets off .+? and flashes toward (?<target>[^!]+)!/,
              /Your (?<weapon>.+?) flashes toward (?<target>[^!]+)!/
            ].freeze)
          ].freeze

          # Companion/pet attacks
          COMPANION_ATTACKS = [
            AttackDef.new(:companion, [
              /(?<companion>.+?) pounces on (?<target>[^,]+), knocking the .+? painfully to the ground!/,
              %r{The (?<companion>.+?) takes the opportunity to slash .+? claws at (?:<pushBold/>)?the (?<target>.+?) \w+!},
              /(?<companion>.+?) charges forward and slashes .+? claws at (?<target>.+?) faster than .+? can react!/,
              /(?<companion>.+?) charges forward and bites down on (?<target>.+?) faster than .+? can react!/,
              /(?<companion>.+?) rushes forward, sinking #{MK_PRE}(?:his|her|its)#{MK_POST} teeth into (?<target>.+?) neck!/,
              /(?<companion>.+?) rushes forward, slashing viciously at the back of (?<target>.+?) (?:right|left) leg with #{MK_PRE}(?:his|her|its)#{MK_POST} teeth and claws!/
            ].freeze)
          ].freeze

          # Environmental / self-inflicted damage. No attacker, no target
          # capture: the parser classifies every name in SELF_INFLICTED as
          # inbound (damage to US), so the "... N points of damage!" line that
          # follows lands on our taken ledger instead of orphaning or, worse,
          # attaching to whatever creature event was open (real-feed
          # 2026-09-07: 18 cold ticks and 10 thorn recoils per hunt, damage
          # taken recorded as 0).
          ENVIRONMENTAL_ATTACKS = [
            # Ojandhaart weather: the wind/sleet announce is flavor, the tick
            # line names the effect and precedes the damage
            AttackDef.new(:frigid_wind, [
              /The burn of the cold tears precious warmth from your flesh\./,
              /A shiver rattles your knees as the crystalline cold settles deep into your bones\./,
              /Your limbs tingle as warmth flees them in the frigid air\./,
              /Bitter cold leaches warmth from your skin\./,
              # a nearby player taking the same tick (foreign_target - the
              # capture is a bare name, never a creature link)
              /(?<target>.+?) shivers as the cold settles into #{MK_PRE}(?:his|her|its)#{MK_POST} flesh\./
            ].freeze),
            # Thorn-grown bow recoil: sheathing it rips the embedded thorns
            # out of the wielder's hand (owner: "my weapon hurts me when I
            # put it away")
            AttackDef.new(:thorn_recoil, [
              /As (?:a|an|your) .+? leaves your (?:left|right) hand, the thorns embedded in your skin painfully rip away/
            ].freeze)
          ].freeze

          # Def names whose lines describe damage to US with no attacker: the
          # parser reports them inbound without needing a "you" capture.
          SELF_INFLICTED = %i[frigid_wind thorn_recoil].freeze

          # The tracker's chunk gate only forwards chunks holding a bolded
          # creature link; an environmental tick names no creature, so its
          # chunk was discarded before the parser ever saw it (real-feed
          # 2026-09-07: zero frigid_wind rows against 10 log ticks). This
          # union lets the gate pass such chunks.
          SELF_INFLICTED_PATTERN = Regexp.union(ENVIRONMENTAL_ATTACKS.flat_map(&:patterns)).freeze

          def self.self_inflicted_line?(line)
            SELF_INFLICTED_PATTERN.match?(line)
          end

          # AMBUSH PREFIXES - modifiers, not attacks.
          #
          # Attacking from hiding is still just an attack; the hiding line
          # only marks that it carries the ambush bonuses (DS pushdown plus
          # crit weighting - or, for waylay, damage weighting instead). The
          # real attack line follows and carries the target and the roll:
          #
          #     Butch leaps from hiding to strike!      <- prefix, no target
          #     Butch attempts to punch <creature>!     <- the actual attack
          #       UAF: 681 vs UDF: 575 ... = 130        <- its roll
          #
          # Archive evidence (11k+ logs): the follower is always an attack
          # or UAC maneuver (swings/claws/thrusts/attempts to jab|punch|kick)
          # - or, when the ambush is wholly negated, an OUTCOME with no
          # attack line at all ("The thorny barrier ... blocks the attack!",
          # "You outmaneuver the attack!"). Never a non-combat action.
          #
          # Treated as a def these opened a second, fact-less event per
          # ambush (35,549 occurrences). Treated as a prefix they set
          # `ambush: true` on the attack that follows, so the attack keeps
          # its own name (:attack, :uac...) and gains the modifier - and a
          # negated ambush still records as a missed attack via its outcome.
          AMBUSH_PREFIXES = [
            # 2p. cman_garrote.txt proved these prefixes: the SMR that
            # follows belongs to the maneuver line, not to this.
            /\AYou leap from hiding to (?:attack|strike)!/,
            /\AYou quickly leap from hiding to deliver your attack!/,
            /\AYou step from hiding and attack!/,
            # 3p, same grammar with an attacker
            /\A(?<attacker>.+?) leaps from hiding to (?:attack|strike)!/
          ].freeze

          AMBUSH_GATE, AMBUSH_ALWAYS_SCAN = PatternGate.build(AMBUSH_PREFIXES)

          # True when the line is an ambush prefix; returns the attacker
          # capture when the 3p form carries one.
          def self.ambush_prefix(line)
            return nil if PatternGate.rejects?(AMBUSH_GATE, AMBUSH_ALWAYS_SCAN, line)

            AMBUSH_PREFIXES.each do |pattern|
              next unless (m = pattern.match(line))

              return { attacker: m.names.include?('attacker') ? m[:attacker] : nil }
            end
            nil
          end

          # REDIRECT PREFIXES - modifiers, not attacks and not outcomes.
          #
          # A guardian creature (gigas shield-maiden) steps between us and
          # the creature we struck at, and the attack RESOLVES IN FULL
          # against the guardian instead. The line names the guardian and
          # the intended victim (by noun) and is followed by the real attack
          # line, which now names the guardian as its target:
          #
          #     Gritting her teeth ..., a brawny gigas shield-maiden raises
          #       her targe and throws herself between you and the mastodon
          #       to intercept your attack!                <- prefix
          #     You fire a faewood arrow at a brawny gigas shield-maiden!
          #       AS: ... = +328                            <- the real attack
          #
          # Corpus (130 lines, 2026-09-07): the follower is ALWAYS an attack
          # line (aimed/ambush/thrown/UAC/echo shot). So this is not an
          # :intercept outcome - nothing was nullified, and treating it as
          # one would either file it on the PREVIOUS attack (the one still
          # open) or fabricate a phantom :unknown event when no attack is
          # open (the ambush-prefix + kick cases). Instead it arms a pending
          # marker the next attack claims as `redirect: { interceptor:,
          # intended: }`, so per-creature hit stats know the guardian's DS
          # was rolled against, not the intended victim's.
          REDIRECT_PREFIXES = [
            /\A(?:Gritting (?:her|his|its) teeth with determination, )?(?<interceptor>.+?) raises (?:her|his|its) \S+ and throws (?:herself|himself|itself) between you and the (?<intended>[^!]+?) to intercept your attack!/
          ].freeze

          REDIRECT_GATE, REDIRECT_ALWAYS_SCAN = PatternGate.build(REDIRECT_PREFIXES)

          # True when the line announces a guardian intercepting the attack
          # that follows; returns the interceptor (raw, links intact) and the
          # intended victim's noun.
          def self.redirect_prefix(line)
            return nil if PatternGate.rejects?(REDIRECT_GATE, REDIRECT_ALWAYS_SCAN, line)

            REDIRECT_PREFIXES.each do |pattern|
              next unless (m = pattern.match(line))

              return { interceptor: m[:interceptor], intended: m[:intended] }
            end
            nil
          end

          # All attack definitions combined
          # Ordering is load-bearing: PRIORITY defs pre-empt the generic
          # swing patterns; second-person defs come before third-person so
          # "You swing" never falls through; the generic 2p bolt sits last
          # inside WIKI_SPELL_ATTACKS so named bolts keep their names.
          ALL_ATTACKS = (PRIORITY_ATTACKS + BASIC_ATTACKS + SPELL_ATTACKS + WIKI_SPELL_ATTACKS +
                        MANEUVER_ATTACKS + WEAPON_ATTACKS +
                        SHIELD_ATTACKS + COMPANION_ATTACKS + ENVIRONMENTAL_ATTACKS +
                        THIRD_PERSON_SPELL_ATTACKS + THIRD_PERSON_ATTACKS).freeze

          # Create lookup table for fast pattern matching
          ATTACK_LOOKUP = ALL_ATTACKS.flat_map do |attack_def|
            attack_def.patterns.compact.map { |pattern| [pattern, attack_def.name] }
          end.freeze

          # Compiled regex for fast detection. NOTE: costs ~0.5ms per
          # non-matching line (unanchored `.+?` alternatives); kept for
          # compatibility but the literal gate below is what the parser uses.
          ATTACK_DETECTOR = Regexp.union(ATTACK_LOOKUP.map(&:first)).freeze

          # Literal-substring gate (~7us/line): a line can only match an
          # attack pattern if it contains that pattern's longest literal.
          ATTACK_GATE, ATTACK_ALWAYS_SCAN = PatternGate.build(ATTACK_LOOKUP.map(&:first))

          # True when the line cannot match any attack pattern
          def self.rejects?(line)
            PatternGate.rejects?(ATTACK_GATE, ATTACK_ALWAYS_SCAN, line)
          end
        end
      end
    end
  end
end
