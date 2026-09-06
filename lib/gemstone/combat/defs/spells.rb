# frozen_string_literal: true

require_relative 'pattern_gate'

module Lich
  module Gemstone
    module Combat
      module Definitions
        # Spell attack definitions - reopens Attacks with the spell-initiation
        # def groups. Loaded from attacks.rb (mid-module require, after
        # AttackDef is defined); the constants here are spliced into
        # ALL_ATTACKS there, so ordering notes below refer to that final
        # concatenation.
        module Attacks
          # Spell-based attacks
          SPELL_ATTACKS = [
            AttackDef.new(:balefire, [/You hurl a ball of greenish-black flame at (?<target>[^!]+)!/].freeze),
            # 302 Bane, living-target version (the undead version has
            # different messaging - not yet catalogued)
            AttackDef.new(:bane, [/A sickly, violet haze encompasses (?<target>.+?)\./].freeze),
            AttackDef.new(:blood_burst, [/Blood sprays from (?<target>.+?) neck in a crimson arc!/].freeze),
            AttackDef.new(:cold_snap, [/An airy mist rolls into the area, carrying a harsh chill with it./].freeze),
            AttackDef.new(:ethereal_censer, [/(?<target>.+?) becomes enveloped in the incense smoke!/].freeze),
            AttackDef.new(:divine_wrath, [
              /A shadowy figure briefly materializes behind (?<target>[^,]+), and a silent scream courses over .+? visage./,
              /Within the reddish haze, the man brings his forging-hammer sharply down upon the anvil, producing a loud clang\./
            ].freeze),
            AttackDef.new(:earthen_fury, [
              /Fiery debris explodes from the ground beneath (?<target>[^!]+)!/,
              /Craggy debris explodes from the ground beneath (?<target>[^!]+)!/,
              /The earth cracks beneath (?<target>[^,]+), releasing a column of frigid air!/,
              /Icy stalagmites burst from the ground beneath (?<target>[^!]+)!/
            ].freeze),
            # Sphere descriptors are multi-word ("icy blue", "snapping and
            # crackling"), hence .+? rather than \w+ (round-12 generic table:
            # icy blue 3,497x/14, snapping and crackling 3,315x/15,
            # crimson 3,312x/12). The ", but is unaffected" fused form is
            # deliberately NOT matched here - it settles through the
            # :unaffected outcome's named-target fallback instead.
            AttackDef.new(:ewave, [/(?:An?|Some) (?<target>.+?) is buffeted by the (?:.+? ethereal (?:waves|sphere)|formless black (?:waves|sphere))(?: and is knocked to the ground)?\./].freeze),
            AttackDef.new(:natures_fury, [/The surroundings advance upon (?<target>.+?) with relentless fury!/].freeze),
            # 711 Pain result line - names the spell the bare-gesture cast
            # wrapper cannot (exchange evidence 2026-09-03: sits between
            # "Warding failed!" and its damage; 17.9k lines / 50+ creatures)
            AttackDef.new(:pain, [/(?<target>.+?) twists in great pain!/].freeze),
            AttackDef.new(:searing_light, [/The radiant burst of light engulfs (?<target>[^!]+)!/].freeze),
            AttackDef.new(:spikethorn, [/Dozens of long thorns suddenly grow out from the ground underneath (?<target>[^!]+)!/].freeze),
            AttackDef.new(:stone_fist, [/The (?:ground|floor) beneath (?<target>you|.+?) rumbles, then erupts in a shower of rubble that coalesces in to an? (?:enormous|large),? ?.*?hand(?: with .+? fingers)? in mid-air\./].freeze),
            AttackDef.new(:sunburst, [/The dazzling solar blaze flashes before (?<target>[^!]+)!/].freeze),
            AttackDef.new(:tangleweed, [
              /The (?<weed>.+?) lashes out violently at (?<target>[^,]+), dragging .+? to the (?:ground|floor)!/,
              /The (?<weed>.+?) lashes out at (?<target>[^,]+), wraps itself around .+? body and entangles .+? on the ground\./
            ].freeze),
            AttackDef.new(:tonis_bolt, [/You unleash a bolt of churning air at (?<target>[^!]+)!/].freeze),
            AttackDef.new(:unbalance, [/Bands of spectral mist ripple and surge beneath (?<target>[^!]+)!/].freeze),
            AttackDef.new(:web, [/Cloudy wisps swirl about (?<target>.+?)\./].freeze),
          ].freeze

          # Spell initiations catalogued from the wiki Messaging sections
          # (docs/COMBAT_DEFS_WIKI_CATALOG.md). Ordered AFTER SPELL_ATTACKS
          # so per-spell defs above (balefire, tonis_bolt) keep their names;
          # the generic 2p bolt def is LAST in this group for the same reason.
          WIKI_SPELL_ATTACKS = [
            AttackDef.new(:astral_spear, [/You project a thin spear of nacreous light at (?<target>[^!]+)!/].freeze),
            # 1106 Bone Shatter; the same "concentrate intently" wording is
            # used by energy runestave channels
            AttackDef.new(:bone_shatter, [
              /You concentrate intently on (?<target>[^,]+), and a pulse of .+? energy ripples toward #{MK_PRE}(?:it|him|her)#{MK_POST}!/,
              # 3p: a creature casts it at us (gigas skald, round-5 corpus)
              /(?<attacker>.+?) concentrates intently on (?<target>you|[^,]+), and a pulse of .+? energy ripples toward #{MK_PRE}(?:you|it|him|her)#{MK_POST}!/
            ].freeze),
            AttackDef.new(:curse, [
              /A thread of .+? magic issues forth from your hand toward (?<target>[^.]+)\./,
              /Holding (?<target>.+?) in your gaze, you utter a foul curse upon #{MK_PRE}(?:him|her|it)#{MK_POST}\./
            ].freeze),
            # 317 Divine Fury. Whole line - it began mid-sentence at "you
            # release ...". ground/floor varies by room.
            AttackDef.new(:divine_fury, [/Particles of dust and soot rise from the (?:ground|floor) at your feet as you release a pulsating, platinum ripple of energy toward (?<target>[^!]+)!/].freeze),
            # 717 Evil Eye cast line (per-target per-round; round-5)
            AttackDef.new(:evil_eye, [/You turn to stare at (?<target>[^.]+)\./].freeze),
            # Excalibur-style weapon spell surge: opens its own CS/TD (the
            # patron-aura flavor rides between); the actual swing opens
            # separately after. The fizzle form is a prefix - no def.
            AttackDef.new(:weapon_cast, [/As you attempt to strike with your (?<weapon>.+?), it sends a surge of power through you that quickly leaps out at (?:the )?(?<target>[^!]+)!/].freeze),
            AttackDef.new(:elemental_strike, [/A vortex of elemental energy suddenly strikes (?<target>[^!]+)!/].freeze),
            AttackDef.new(:fervent_reproach, [/With a quick flick of your wrists, the orbs dance through the air toward (?<target>[^!]+)!/].freeze),
            AttackDef.new(:force_projection, [/A translucent force moves outward from you and toward (?<target>[^.]+)\./].freeze),
            # 1630 Judgment. The summon is deity-specific and so is its strike
            # line - 35 catalogued forms (wiki Judgment_(1630) messaging).
            # Written whole rather than as an "ethereal .+?, striking X!"
            # fragment: four of them name no ethereal object at all (the
            # shadows, the claws, the silver arm, the two-headed serpent), so
            # the fragment MISSED those while matching any unrelated line
            # that happened to contain both words.
            AttackDef.new(:judgment, [
              /A chain of lightning erupts from the tip of the ethereal trident, striking (?<target>[^!]+)!/,
              /A strum of crimson notes float out from the strings of the ethereal lute, striking (?<target>[^!]+)!/,
              /A shockwave of golden energy ripples out from the head of the ethereal forging hammer, striking (?<target>[^!]+)!/,
              /A swarm of translucent bees spiral from the petals of the ethereal blossom, striking (?<target>[^!]+)!/,
              /A veil of grey vapor spews forth from the interior of the ethereal crystal ball, striking (?<target>[^!]+)!/,
              /A flare of silver energy blasts from the fist of the silver arm, striking (?<target>[^!]+)!/,
              /A blast of white energy bursts from the tip of the ethereal sceptre, striking (?<target>[^!]+)!/,
              /A flurry of golden snowflake-shaped motes unwind from the chain of the ethereal keys, striking (?<target>[^!]+)!/,
              /An arc of multihued light leaps from the parchment of the ethereal scroll, striking (?<target>[^!]+)!/,
              /A cloud of flame-hued petals drifts from the edge of the heart-shaped chakram, striking (?<target>[^!]+)!/,
              /A ray of brilliant sunlight gleams from the edge of the ethereal chakram, striking (?<target>[^!]+)!/,
              /A plume of silver starlit flames stream from the edge of (?:your|the) ethereal sword, striking (?<target>[^!]+)!/,
              /A volley of black shards gleam from the tip of the claws, striking (?<target>[^!]+)!/,
              /A curl of black flames unravel from the tip of the ethereal sceptre, striking (?<target>[^!]+)!/,
              /A flurry of parchment flies out from the inside of the ethereal tome, striking (?<target>[^!]+)!/,
              /A length of a green tentacle bursts out from the tendrils of mist, striking (?<target>[^!]+)!/,
              /A cloud of noxious black-green gas emits from the center of the ethereal pentacle, striking (?<target>[^!]+)!/,
              /A flurry of sanguine slivers fly from the edge of the ethereal whip, striking (?<target>[^!]+)!/,
              /A black jackal-shaped visage leaps from the shadows, striking (?<target>[^!]+)!/,
              /A barrage of purple essence flings from the surface of the ethereal shield, striking (?<target>[^!]+)!/,
              /A barrage of viridian essence sprays from the blade of the ethereal falarica, striking (?<target>[^!]+)!/,
              /A blast of multihued plasma flares out from the center of the ethereal sphere, striking (?<target>[^!]+)!/,
              /A chain of blazing fire whips out from the surface of the ethereal shield, striking (?<target>[^!]+)!/,
              /A gust of shimmering air blows from the edge of the ethereal feathered armband, striking (?<target>[^!]+)!/,
              /A number of green vines lash out from the center of the ethereal lily-shaped talisman, striking (?<target>[^!]+)!/,
              /A shaft of dark essence blazes from the center of the ethereal hourglass, striking (?<target>[^!]+)!/,
              /A simple beam of white energy flares out from the tip of the ethereal stiletto, striking (?<target>[^!]+)!/,
              /A spiral of multi-hued essence streams out from the edge of the ethereal boomerang, striking (?<target>[^!]+)!/,
              /A streak of ivory energy flares out from the blade of the ethereal dagger, striking (?<target>[^!]+)!/,
              /A succession of crimson energy is emitted from the two-headed serpent, striking (?<target>[^!]+)!/,
              /A surge of white fire blazes from the center of the ethereal shield, striking (?<target>[^!]+)!/,
              /A sweep of silver essence slashes out from the blade of the ethereal scythe, striking (?<target>[^!]+)!/,
              /A torrent of incarnadine essence streams out from the blade of the ethereal scimitar, striking (?<target>[^!]+)!/,
              /A trill of delicate, yellow notes drifts out from the end of the ethereal flute, striking (?<target>[^!]+)!/,
              /A wave of grey vibrations washes out from the inside of the ethereal conch shell, striking (?<target>[^!]+)!/,
              /An arc of silver-grey tendrils spiral out from the blade of the ethereal sickle, striking (?<target>[^!]+)!/
            ].freeze),
            AttackDef.new(:kais_smite, [/You attempt to smite (?<target>[^!]+)!/].freeze),
            # 708 Limb Disruption. Full line, with the leading article and the
            # possessive: a bare "<x> right leg explodes!" fragment also
            # matched OUR OWN limb ("Your right leg explodes!") and opened an
            # attack event against us.
            AttackDef.new(:limb_disruption, [/The (?<target>.+?)'s#{MK_POST} (?:right|left) (?:leg|arm|hand|eye) explodes!/].freeze),
            AttackDef.new(:moonbeam, [/You level a nebulous beam of shadowy luminescence at (?<target>[^!]+)!/].freeze),
            AttackDef.new(:pestilence, [
              /You exhale a virulent green mist toward (?<target>[^,]+), instantly infecting/,
              # 3p: a group member casts it. Without this the per-target
              # damage that follows had no event and was dropped - or worse,
              # was claimed by whatever event happened to still be open
              # (real-feed replay, GSIV-Nisugi 2026-01-01: Zoleta's 18 and 25
              # landed on the creature we were fighting).
              /(?<attacker>.+?) exhales a virulent green mist toward (?<target>[^,]+), instantly infecting/,
              # Per-round TICK forms. Pestilence keeps damaging its victim for
              # rounds after the cast, and each tick line carries BOTH its own
              # damage and the target - but with no def they had no event, so
              # the tick damage was dropped outright while the swing that
              # followed in the same chunk persisted normally (real-feed
              # replay: 59 and 44 lost against a tattooed gigas berserker).
              # Wiki Pestilence_(716) messaging plus the mist form from live
              # logs, which the wiki does not list.
              /(?<target>.+?) howls in pain as virulent green mist passes through #{MK_PRE}(?:his|her|its)#{MK_POST} form causing \d+ points of damage!/,
              /Boils rupture all over (?<target>.+?) causing \d+ points of damage!/,
              /Pustules break out all over (?<target>.+?) causing \d+ points of damage!/,
              /Pus-filled sores erupt on (?<target>.+?) causing \d+ points of damage!/,
              /(?<target>.+?) wails as painful boils form and erupt causing \d+ points of damage!/,
              /(?<target>.+?)'s#{MK_POST} skin hardens into a black rot and begins to crumble causing \d+ points of damage!/,
              /(?<target>.+?)'s#{MK_POST} skin necrotizes and falls away as an indiscernible mass causing \d+ points of damage!/,
              /(?<target>.+?) begins hemorrhaging from multiple orifices causing \d+ points of damage!/,
              /The sickly green miasma around (?<target>.+?) flares causing \d+ points of damage!/
            ].freeze),
            # 302 Smite, undead counterpart of the :bane living-target haze
            AttackDef.new(:smite_undead, [/A scintillating, blue-white aura encompasses (?<target>[^.]+)\./].freeze),
            AttackDef.new(:song_of_rage, [/A dull keening quickly crescendos into a singular shrill note focused directly at (?<target>[^.]+)\./].freeze),
            AttackDef.new(:stunning_shout, [/(?<target>.+?) is struck violently by the tightly focused sonic energy of your cacophonous shout!/].freeze),
            # shared cast line of targeted bard attack songs (1008, 1016...)
            AttackDef.new(:spellsong, [/You weave another verse into your harmony, directing the sound of your voice at (?<target>[^.]+)\./].freeze),
            AttackDef.new(:sunburst, [/A sudden burst of bright light emanates from your hand toward (?<target>[^!]+)!/].freeze),
            AttackDef.new(:templars_verdict, [/A column of violet flame envelops (?<target>.+?) in its searing embrace!/].freeze),
            AttackDef.new(:thought_lash, [/A crackling whip of energy lashes out at (?:the )?(?<target>[^!]+)!/].freeze),
            AttackDef.new(:web_bolt, [/You shoot strands of webbing at (?<target>[^!]+)!/].freeze),
            AttackDef.new(:wither, [/A nebulous haze shimmers into view around (?<target>[^,.]+)/].freeze),
            # generic 2p cast - "You gesture at X." opens warding spells the
            # same way the 3p "gestures at" does (logs/examples/moonbeam.txt,
            # wild_entropy.txt); second-to-LAST so specific spells name
            # themselves first
            AttackDef.new(:cast, [/You gesture at (?<target>[^.!]+)[.!]/].freeze),
            # generic 2p bolt - the standard initiation for the whole bolt
            # family (901/904/906/910/1707/1709/1710...); LAST so specific
            # bolt spells above name themselves first
            AttackDef.new(:bolt, [
              /You hurl (?:a|an|some) (?<bolt>.+?) at (?<target>[^!]+)!/,
              /You unleash a compact swirling vortex at (?<target>[^!]+)!/
            ].freeze)
          ].freeze

          # Third-person spell initiations: other players and creatures.
          # Split out of THIRD_PERSON_ATTACKS (attacks.rb) so all spell
          # grammar lives in this file; spliced into ALL_ATTACKS at the tail
          # alongside it (2p defs always come first).
          THIRD_PERSON_SPELL_ATTACKS = [
            # Creature spell initiations aimed at us, mined from orphaned
            # CS/TD rolls. Like the :natural additions these key on the
            # ACTION - one "points a clawed finger" pattern covers every
            # psionicist adjective the corpus contains.
            AttackDef.new(:creature_spell, [
              /(?<attacker>.+?) points a clawed finger toward (?<target>[^!]+)!/,
              /(?<attacker>.+?) points a single golden nail toward (?<target>[^!]+)!/,
              /(?<attacker>.+?) turns to look at (?<target>.+?), the empty pits where/,
              /(?<attacker>.+?) glares malevolently at (?<target>[^.!]+)[.!]/,
              /(?<attacker>.+?) flicks #{MK_PRE}(?:his|her|its)#{MK_POST} bulging eyes toward (?<target>[^!]+)!/,
              /(?<attacker>.+?) focuses a lambent beam of divine energy at (?<target>[^!]+)!/,
              /(?<attacker>.+?) levitates a sizeable stone at (?<target>[^!]+)!/,
              /(?<attacker>.+?) projects a thin spear of nacreous light at (?<target>[^!]+)!/,
              /A sudden burst of bright light emanates from (?<attacker>.+?) toward (?<target>[^!]+)!/,
              /(?<attacker>.+?) sends dripping tendrils of rust-colored ectoplasm (?:toward|at) (?<target>[^!]+)!/,
              /(?<attacker>.+?) artfully plays #{MK_PRE}(?:his|her|its)#{MK_POST} .+?, sending .+? toward (?<target>[^!]+)!/
            ].freeze),
            # warding/bolt cast initiations (the spell itself names no verb);
            # the creature telegraph and rapid-cast forms open their own
            # CS/TD rolls just like "gestures at"
            AttackDef.new(:cast, [
              # bang terminator is the inbound form ("gestures at you!",
              # full-corpus sweep 2026-09-03: 839x across 21 creatures)
              /(?<attacker>.+?) gestures at (?<target>[^.!]+)[.!]/,
              # untargeted AoE cast (round-6: 8.4k "Nisugi gestures.");
              # per-target events unfold under it via the switch logic.
              # Collides with the bare GESTURE emote, but that event never
              # gains a target id, so event_savable? drops it silently
              /^(?<attacker>.+?) gestures\.\s*$/,
              /(?<attacker>.+?) brings a hand forward, pointing at (?<target>[^!]+)!/,
              /(?<attacker>.+?) makes a complex gesture at (?<target>[^.]+)\./,
              # generic creature warding grammar (round-5: ~5,600 + ~1,700
              # orphaned CS/TD rolls; the tendril/finger lead-ins that
              # precede the warp line are prefixes)
              /The force of (?<attacker>.+?)'s#{MK_POST} power warps the air as it surges toward (?<target>[^!]+)!/,
              /(?<attacker>.+?) points an? .+? finger at (?<target>[^!]+)!/,
              /(?<attacker>.+?) directs the force of #{MK_PRE}(?:his|her|its)#{MK_POST} voice at (?<target>[^!]+)!/
            ].freeze),
            AttackDef.new(:channel, [/(?<attacker>.+?) channels at (?<target>[^.]+)\./].freeze),
            # creature wand flourish - the erupt tail rides the same line
            AttackDef.new(:wand, [/(?<attacker>.+?) flourishes (?<weapon>.+?) at (?<target>[^.]+)\.\s+A .+? erupts toward/].freeze),
            # "hurls a/an <bolt>" - bolt spells from players AND creatures;
            # the reflexive form ("hurls himself") is the tackle maneuver
            AttackDef.new(:bolt, [
              /(?<attacker>.+?) hurls (?:a|an|some) (?<bolt>.+?) at (?<target>[^!]+)!/,
              /(?<attacker>.+?) throws (?:a|an) (?<bolt>.+?) at (?<target>[^!]+)!/,
              # haste-repeat rounds emit the vortex with no cast line; when a
              # cast line IS present it opened the event with the same target,
              # so the re-open is benign
              /(?<attacker>.+?) unleashes a compact swirling vortex at (?<target>[^!]+)!/
            ].freeze)
          ].freeze
        end
      end
    end
  end
end
