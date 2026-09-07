# frozen_string_literal: true

#
# Flare Pattern Definitions
# Converted from ctparser/FLARE_DEFS to Lich::Gemstone::Combat namespace
#
# A flare is a proc that rides on an attack: weapon scripts, enchants,
# gloves, GEFs, flourishes. Each def carries:
#   damaging: whether a damage line is expected to follow (buff/utility
#             flares like acuity or tailwind never produce one)
#   aoe:      false when the flare is explicitly single-target even if
#             its parent attack is not
#   spawns:   the flare casts an imbedded spell as a SEPARATE attack
#             (e.g. Blink), so subsequent attack events in the same
#             chunk are its children rather than independent casts
#
# Timing is NOT declared here: whether a flare resolves before its swing
# (pre-flare, e.g. dispel gloves) or after (most flares) is determined
# positionally by the parser - a flare seen with no open attack event is
# held and claimed by the next swing. Position in the log is ground
# truth regardless of the flare's source.
#

require_relative 'pattern_gate'

module Lich
  module Gemstone
    module Combat
      module Definitions
        module Flares
          FlareDef = Struct.new(:name, :patterns, :damaging, :aoe, :spawns)

          FLARE_DEFS = [
            FlareDef.new(:acid, [
              /\*\* Your .+? releases? a spray of acid! \*\*/,
              /\*\* Your .+? releases? a spray of acid at (?<target>.+?)! \*\*/,
              /\*\* (?<attacker>.+?)'s#{MK_POST} .+? releases? a spray of acid(?: at (?<target>.+?))?! \*\*/
            ].freeze, true, true, false),
            FlareDef.new(:acuity, [
              /Your .+? glows intensely with a verdant light!/,
              /(?<attacker>.+?)'s#{MK_POST} .+? glows intensely with a verdant light!/
            ].freeze, false, true, false),
            FlareDef.new(:air, [
              /\*\* Your .+? unleashes a blast of air! \*\*/,
              /\*\* (?<attacker>.+?)'s#{MK_POST} .+? unleashes a blast of air! \*\*/
            ].freeze, true, true, false),
            FlareDef.new(:air_flourish, [/\*\* A fierce whirlwind erupts around .+?, encircling (?<target>.+?) in a suffocating cyclone! \*\*/].freeze, true, true, false),
            FlareDef.new(:arcane_reflex, [/Vital energy infuses you, hastening your arcane reflexes!/].freeze, false, true, false),
            FlareDef.new(:blink, [/Your .+? suddenly lights up with hundreds of tiny blue sparks!/].freeze, true, false, true),
            FlareDef.new(:blessings_flourish, [
              /\*\* A crackling wave arcs across your body, striking (?<target>.+?) with lightning speed!  A spiritual resonance warms your core, lending you renewed strength! \*\*/,
              /\*\* Shimmering arcs of lightning stream from your hands, colliding with (?<target>.+?) in a rapid burst!  A stirring force ignites within you, augmenting your spirit! \*\*/,
              /\*\* Sparkling tendrils of energy weave around your limbs, shocking (?<target>.+?) in a bright flare!  The pulse leaves you feeling spiritually emboldened! \*\*/,
              /\*\* A faint hum courses through you as arcs of electricity coil around your arms, jolting (?<target>.+?) in a vivid burst!  The current resonates with your spirit, boosting your energy! \*\*/,
              /\*\* You feel a tingling surge channel through your arms, blasting (?<target>.+?) with crackling electricity!  A reassuring feeling of mental acuity settles over you! \*\*/,
              /\*\* Jagged sparks dance along your open palms, lashing out at (?<target>.+?) in a crackling surge!  Your resolve feels bolstered as the energy courses through you! \*\*/,
              /\*\* An electrified aura coalesces around you, crackling outward to shock (?<target>[^!]+)!  The charge resonates with your spirit, heightening your prowess! \*\*/,
              /\*\* Threads of charged light spiral around your arms, striking (?<target>.+?) with a pulsing shock!  A resonant force ripples through you, amplifying your spirit! \*\*/,
              /\*\* Sparks of crackling energy race along your fingertips, shocking (?<target>.+?) with a brilliant flash!  A surge of spiritual power rushes through your veins! \*\*/
            ].freeze, true, true, false),
            FlareDef.new(:breeze, [
              /(?<target>.+?) is buffeted by a burst of wind and pushed back!/,
              /(?<target>.+?) is buffeted by a sudden gust of wind!/,
              /A gust of wind shoves (?<target>.+?) back!/
            ].freeze, false, true, false),
            FlareDef.new(:briar, [/Vines of vicious briars whip out from your [^,]+, raking the \w+ with its thorns\.  The \w+ looks slightly ill as the glistening emerald coating from each briar works itself under its skin\./].freeze, true, true, false),
            FlareDef.new(:chameleon_shroud, [/A tenebrous shroud stitches itself into existence around you as you gracefully retreat into the shadows!/].freeze, false, true, false),
            FlareDef.new(:cold, [
              /Your .+? glows intensely with a cold blue light!/,
              /(?<attacker>.+?)'s#{MK_POST} .+? glows intensely with a cold blue light!/
            ].freeze, true, true, false),
            FlareDef.new(:cold_gef, [/\*\* A vortex of razor-sharp ice gusts from .+? and coalesces around (?<target>[^!]+)! \*\*/].freeze, true, true, false),
            # (?:<pushBold\/>)? before "the": the live feed bolds the target
            # as <pushBold/>the <a...>name</a><popBold/>, so a literal
            # " the " glued to the capture never matches in production
            # (replay-harness verified 2026-08-21)
            FlareDef.new(:concussive_blows, [
              %r{\*\* Your blow slams (?:<pushBold/>)?the (?<target>.+?) with concussive force! \*\*},
              %r{\*\* (?<attacker>.+?)'s#{MK_POST} blow slams (?:<pushBold/>)?the (?<target>.+?) with concussive force! \*\*}
            ].freeze, true, true, false),
            FlareDef.new(:disintegration, [
              /\*\* Your .+? releases a shimmering beam of disintegration! \*\*/,
              /\*\* (?<attacker>.+?)'s#{MK_POST} .+? releases a shimmering beam of disintegration! \*\*/
            ].freeze, true, true, false),
            # Sphere-interference cascade ("flux crit"): fires when a
            # dispel strips a spell whose sphere differs from the sphere
            # of a strip moments before - the interaction is what carries
            # the damage/crit that follows (owner mechanics 2026-09-04 +
            # Dispel flare wiki page). The noun names the stripped
            # spell's sphere: elemental aura = elemental, hazy film =
            # spiritual (plasma crit in the wiki example), murky veil =
            # mental (by elimination - disruption crit expected). The
            # no-flux sphere lines ("wavers."/"coats X."/"surrounds X.")
            # stay deliberately unparsed.
            FlareDef.new(:dispel_flux, [
              /The (?:elemental aura|hazy film|murky veil) around (?<target>.+?) fluxes chaotically!/
            ].freeze, true, false, false),
            FlareDef.new(:dispel, [
              # glows? - plural items ("somnis gauntlets glow")
              /\*\* Your .+? glows? brightly for a moment, consuming the magical energies around (?<target>[^!]+)! \*\*/,
              /\*\* (?<attacker>.+?)'s#{MK_POST} .+? glows brightly for a moment, consuming the magical energies around (?<target>[^!]+)! \*\*/
            ].freeze, true, false, false),
            FlareDef.new(:disruption, [
              /\*\* Your .+? releases a quivering wave of disruption! \*\*/,
              /\*\* (?<attacker>.+?)'s#{MK_POST} .+? releases a quivering wave of disruption! \*\*/
            ].freeze, true, true, false),
            FlareDef.new(:earth_flourish, [/\*\* Chunks of earth violently orbit .+?, pelting (?<target>.+?) with heavy debris and stone! \*\*/].freeze, true, true, false),
            FlareDef.new(:earth_gef, [/\*\* A violent explosion of frenetic energy rumbles from .+? and pummels (?<target>[^!]+)! \*\*/].freeze, true, true, false),
            FlareDef.new(:energy, [%r{\*\* A beam of .+? energy emits from the tip of your .+? and collides with (?<target>.+?</a>) .+?! \*\*}].freeze, true, true, false),
            FlareDef.new(:ensorcell, [
              /\*\* Necrotic energy from your .+? overflows into you! \*\*/,
              # third person: the energy is announced from the wielder's item
              /\*\* Necrotic energy from (?<attacker>.+?) flares up momentarily! \*\*/
            ].freeze, false, true, false),
            FlareDef.new(:fire, [
              /\*\* Your .+? flares with a burst of flame! \*\*/,
              /\*\* (?<attacker>.+?)'s#{MK_POST} .+? flares with a burst of flame! \*\*/
            ].freeze, true, true, false),
            FlareDef.new(:fire_flourish, [/\*\* A blazing inferno erupts around .+?, engulfing (?<target>.+?) and scorching everything in its wake! \*\*/].freeze, true, true, false),
            FlareDef.new(:fire_gef, [/\*\* Burning orbs of pure flame burst from .+? and engulf (?<target>[^!]+)! \*\*/].freeze, true, true, false),
            FlareDef.new(:firewheel, [/\*\* Your .+? emits a fist-sized ball of lightning-suffused flames! \*\*/].freeze, true, true, false),
            FlareDef.new(:ghezyte, [
              /\*\* Cords of plasma-veined grey mist seep from your .+? and entangle (?<target>[^,]+), causing .+? to tremble violently! \*\*/,
              # 3p (round-6: 16k)
              /\*\* Cords of plasma-veined grey mist seep from (?<attacker>.+?)'s#{MK_POST} .+? and entangle (?<target>[^,]+), causing .+? to tremble violently! \*\*/
            ].freeze, false, true, false),
            FlareDef.new(:grapple, [
              /\*\* Your .+? releases a twisted tendril of force! \*\*/,
              /\*\* (?<attacker>.+?)'s#{MK_POST} .+? releases a twisted tendril of force! \*\*/
            ].freeze, true, true, false),
            FlareDef.new(:guiding_light, [/\*\* Your .+? sprays with a burst of plasma energy! \*\*/].freeze, true, true, false),
            FlareDef.new(:holy_water, [/\*\* Your .+? sprays forth a shower of pure water! \*\*/].freeze, true, false, false),
            FlareDef.new(:hurl_boulder, [/You hurl a large boulder at (?<target>[^!]+)!/].freeze, true, false, false),
            FlareDef.new(:immolation, [/You bring a hand up to your lips and form a sign with your fingers as you whisper a quiet invocation for Immolation\.\.\./].freeze, true, false, false),
            FlareDef.new(:impact, [%r{\*\* Your .+? release a blast of vibrating energy at (?:<pushBold/>)?the (?<target>[^!]+)! \*\*}].freeze, true, true, false),
            FlareDef.new(:lightning, [
              /\*\* Your .+? emits a searing bolt of lightning! \*\*/,
              /\*\* (?<attacker>.+?)'s#{MK_POST} .+? emits? a searing bolt of lightning! \*\*/
            ].freeze, true, true, false),
            FlareDef.new(:lightning_gef, [/\*\* A vicious torrent of crackling lightning surges from .+? and strikes (?<target>[^!]+)! \*\*/].freeze, true, true, false),
            FlareDef.new(:magma, [%r{\*\* Your .+? expel a glob of molten magma at (?:<pushBold/>)?the (?<target>[^!]+)! \*\*}].freeze, true, true, false),
            # [Yy] - arrives lowercase mid-sentence from armor flares
            FlareDef.new(:mana, [/[Yy]ou feel \d+ mana surge into you!/].freeze, false, true, false),
            FlareDef.new(:natures_decay, [
              /Soot brown specks of leaf mold trail in the wake of (?<target>.+?) movements, distorted by a murky haze\./,
              /The earthy, sweet aroma clinging to (?<target>.+?) grows more pervasive\./,
              # first application (real-feed 2026-09-07; was a typo'd "armoa
              # clings" that never matched, so the first proc on each creature
              # recorded as a status only, never as a flare)
              /An earthy, sweet aroma wafts from (?<target>.+?) in a murky haze\./,
              /An earthy, sweet aroma clings to (?<target>.+?) in a murky haze, accompanied by soot brown specks of leaf mold\./
            ].freeze, false, true, false),
            FlareDef.new(:necromancy_flourish, [/\*\* A sickly green aura radiates from .+? and seeps into (?<target>.+?) wounds! \*\*/].freeze, true, true, false),
            FlareDef.new(:parasite, [/A slender .+? and black tendril lashes out from .+? and slashes (?<target>.+?) .+?!/].freeze, true, true, false),
            FlareDef.new(:physical_prowess, [/The vitality of nature bestows you with a burst of strength!/].freeze, false, true, false),
            FlareDef.new(:plasma, [
              /\*\* Your .+? pulses with a burst of plasma energy! \*\*/,
              /\*\* (?<attacker>.+?)'s#{MK_POST} .+? pulses with a burst of plasma energy! \*\*/
            ].freeze, true, true, false),
            # Glowbark / plasma weapon flare. Three lines, three roles (owner
            # breakdown 2026-09-06):
            #   1. PRIMARY - damages the swing's target, names it.
            #   2. CHAIN TRIGGER - the 25% AoE proc fires; no target, no
            #      damage. It can flush hidden creatures ("... forced out of
            #      hiding!"), so it must NOT be treated as damaging or it
            #      would swallow the next damage line.
            #   3. SECONDARY - one per additional creature the AoE caught;
            #      damages and names each.
            # 580 primaries + 123 chain lines were dropped as unmatched flare
            # text before this (real-feed, GSIV-Nisugi glowbark long bow).
            # The game reworded this flare on 2026-09-06 ("plasma wave" ->
            # phosphorescence) and the old wording no longer prints, so only
            # the current forms are defined, one name per role (owner naming
            # 2026-09-07) so analytics can tell the three lines apart.
            # PRIMARY: names and damages the swing's target
            FlareDef.new(:phosphorescence, [
              /\*\* Countless points of pale phosphorescence awaken across your .+?, rapidly brightening before bursting into brilliant light around (?<target>.+?)! \*\*/,
              /\*\* Countless points of pale phosphorescence awaken across (?<attacker>.+?)'s#{MK_POST} .+?, rapidly brightening before bursting into brilliant light around (?<target>.+?)! \*\*/
            ].freeze, true, true, false),
            # CHAIN TRIGGER: no target, no damage (see note above)
            FlareDef.new(:glowbright, [
              /\*\* Phosphorescent light races through the .+? as its entire surface blossoms with dazzling radiance, flooding the surroundings in ghostly light! \*\*/
            ].freeze, false, true, false),
            # SECONDARY: one bloom per extra creature the chain reached.
            # Its target is NOT the swing's target - the processor must keep
            # the damage on this flare (creature-attributed) rather than
            # switching the whole event onto the bloom's creature.
            FlareDef.new(:spectral_bloom, [
              /\*\* A bloom of spectral light blossoms around (?<target>.+?), engulfing .+? in searing brilliance! \*\*/
            ].freeze, true, true, false),
            FlareDef.new(:psychic_assault, [
              # bare form (no target clause) observed 2,148x in round-5 logs;
              # optional pushBold before "the" or the targeted-live form dies
              %r{\*\* Your .+? unleashes a blast of psychic energy(?: at (?:<pushBold/>)?the (?<target>[^!]+))?! \*\*},
              %r{\*\* (?<attacker>.+?)'s#{MK_POST} .+? unleashes a blast of psychic energy(?: at (?:<pushBold/>)?the (?<target>[^!]+))?! \*\*}
            ].freeze, true, true, false),
            FlareDef.new(:religion_flourish, [/\*\* Divine flames kindle around .+?, leaping forth to engulf (?<target>.+?) in a sacred inferno! \*\*/].freeze, true, true, false),
            FlareDef.new(:rusalkan, [/Succumbing to the force of the tidal wave, (?<target>.+?) is thrown to the ground\./].freeze, false, true, false),
            FlareDef.new(:sigil_dispel, [
              /\*\* Tendrils of .+? lash out from your .+? toward (?<target>.+?) and cage .+? within bands of concentric geometry that constrict as one, shattering upon impact! \*\*/,
              /\*\* Tendrils of .+? lash out from (?<attacker>.+?)'s#{MK_POST} .+? toward (?<target>.+?) and cage .+? within bands of concentric geometry/,
              # armor-trigger form: the bolt from the caster's armor lights
              # the sigils, then the tendrils lash out in the same line
              /\*\* A bolt of energy leaps from (?<attacker>.+?)'s#{MK_POST} .+? and sets the sigils along .+? ablaze\.  Tendrils of .+? lash out at (?<target>.+?) and cage .+? within bands of concentric geometry/
            ].freeze, true, false, false),
            FlareDef.new(:sigil_cast, [
              /\*\* Numerous sigils along your .+? abruptly flare to brilliance!  .+? surges from each, twining into an echo of your last spell\.\.\. \*\*/,
              /\*\* Numerous sigils along (?<attacker>.+?)'s#{MK_POST} .+? abruptly flare to brilliance!  .+? surges from each, twining into an echo of .+? last spell\.\.\. \*\*/,
              /\*\* Spiraling sigils flare to sudden visibility along (?:your|(?<attacker>.+?)'s#{MK_POST}) .+?, pulsing forth an echo of the spell within! \*\*/
            ].freeze, true, false, true),
            FlareDef.new(:slashing_strikes, [
              # anchored on the possessive: the lazy capture used to stop at
              # the first word ("the") instead of the creature. Works on both
              # forms - live target spans its link markup up to the 's
              %r{\*\* Your .+? finds its mark, slicing deep into (?:<pushBold/>)?(?:the )?(?<target>.+?)'s#{MK_POST} (?<location>[^!]+)! \*\*},
              %r{\*\* (?<attacker>.+?)'s#{MK_POST} .+? finds its mark, slicing deep into (?:<pushBold/>)?(?:the )?(?<target>.+?)'s#{MK_POST} (?<location>[^!]+)! \*\*}
            ].freeze, true, true, false),
            FlareDef.new(:somnis, [
              %r{\*\* For a split second, the striations of your .+? expand into a sinuous pearlescent mist that rushes towards (?:<pushBold/>)?the (?<target>[^,]+), enveloping .+? entirely(?: and causing .+? to collapse, fast asleep)?! \*\*},
              # third person - the "causing ... fast asleep" tail is absent
              /\*\* For a split second, the striations of (?<attacker>.+?)'s#{MK_POST} .+? expand into a sinuous pearlescent mist that rushes towards (?<target>[^,]+), enveloping .+? entirely! \*\*/
            ].freeze, false, true, false),
            FlareDef.new(:sprite, [%r{\*\* The .+? sprite on your shoulder sends forth a cylindrical, .+? blast of magic at (?<target>.+?</a>) .+?! \*\*}].freeze, true, true, false),
            FlareDef.new(:steam, [
              /\*\* Your .+? erupts with a plume of steam! \*\*/,
              %r{\*\* Your .+? erupt with a plume of steam at (?:<pushBold/>)?the (?<target>[^!]+)! \*\*}
            ].freeze, true, true, false),
            FlareDef.new(:summoning_flourish, [/\*\* A radiant mist surrounds .+?, unfurling into a whip of plasma that wreathes (?<target>.+?) in its sizzling embrace! \*\*/].freeze, true, true, false),
            FlareDef.new(:tailwind, [
              /A favorable tailwind springs up behind you\./,
              /You shift position, taking advantage of a favorable tailwind\./,
              /The wind turns in your favor\./
            ].freeze, false, true, false),
            FlareDef.new(:telepathy_flourish, [/\*\* Rippling and half-seen, strands of psychic power unravel from .+? to strike at (?<target>.+?)! \*\*/].freeze, true, true, false),
            FlareDef.new(:terror, [
              /\*\* A series of cacophonous caws and screeches fills the air as a murder of crows appears out of nowhere, swarming (?<target>.+?) and pecking .+? relentlessly! \*\*/,
              /\*\* A wave of wicked power surges forth from your .+? and fills (?<target>.+?) with terror, .+? form trembling with unmitigated fear! \*\*/,
              # 3p (round-6: 8.3k)
              /\*\* A wave of wicked power surges forth from (?<attacker>.+?)'s#{MK_POST} .+? and fills (?<target>.+?) with terror, .+? form trembling with unmitigated fear! \*\*/
            ].freeze, false, true, false),
            FlareDef.new(:unbalance, [/\*\* Your .+? unleashes an invisible burst of force! \*\*/].freeze, true, true, false),
            FlareDef.new(:vacuum, [/\*\* As you hit, the (?:edge|outer rim) of your .+? seems to fold inward upon itself drawing everything it touches along with it! \*\*/].freeze, true, true, false),
            FlareDef.new(:valence, [/\*\* A coil of spectral .+? energy bursts out of thin air and strikes (?<target>[^!]+)! \*\*/].freeze, true, true, false),
            FlareDef.new(:wall_of_thorns, [%r{One of the vines surrounding you lashes out at (?:<pushBold/>)?the (?<target>[^,]+), scraping a thorn across .+? body!  .+? flinches slightly.}].freeze, false, true, false),
            FlareDef.new(:water, [/\*\* Your .+? shoot a blast of water! \*\*/].freeze, true, true, false),
            FlareDef.new(:water_flourish, [/\*\* A watery deluge erupts violently around .+?, crushing (?<target>.+?) with relentless force! \*\*/].freeze, true, true, false),

            # --- families first catalogued from the 2026-08-20 arena logs ---
            # shield/armor spike proc (arena logs 3p, wiki 2p - the 2p form
            # is not **-wrapped for shields but is for armor spikes)
            FlareDef.new(:shield_spike, [
              /\*\* A spike on (?<attacker>.+?)'s#{MK_POST} .+? jabs into (?<target>[^!]+)! \*\*/,
              /\*\* A spike on your .+? jabs into (?<target>[^!]+)! \*\*/,
              /A spike on your (?<weapon>.+?) jabs into (?<target>[^!]+)!/
            ].freeze, true, false, false),
            # UAC gloves blood-boil proc (re-tick line is a status, not here)
            FlareDef.new(:boil_blood, [/\*\* A fiery aura spirals from (?<attacker>.+?) hands into (?<target>.+?) body, roiling .+? blood to a boil! \*\*/].freeze, true, false, false),
            # envenomed/poisoned weapon proc
            # target is .*? not .+? - on our own procs the stripped creature
            # link leaves the slot empty and the line must still match
            FlareDef.new(:weapon_poison, [/\*\* (?:Afflicted|Envenomed) by (?<attacker>.+?), (?<target>.*?) reels as the .+? poison does its work! \*\*/].freeze, false, false, false),
            # Thurfel's-style summoned thundercloud strike
            FlareDef.new(:thundercloud, [/Suddenly a lightning bolt explodes from the .+? thundercloud and strikes (?<target>.+?) with a brilliant flash!/].freeze, true, false, false),
            # vulnerability-exposing procs (arena 3p wordings + wiki 2p)
            FlareDef.new(:vulnerability, [
              /The attack exposes (?:a vulnerability in )?(?<target>.+?) defenses!/,
              /Your attack exposes a vulnerability in (?<target>.+?)'s#{MK_POST} defenses!/
            ].freeze, false, false, false),

            # --- catalogued from wiki Messaging sections ---
            FlareDef.new(:sonic_weapon, [
              /\*\* Your sonic .+? unleashes a blast of sonic energy at (?<target>[^!]+)! \*\*/,
              /\*\* With a loud snap, a blast of energy bursts from your sonic .+?! \*\*/
            ].freeze, true, false, false),
            FlareDef.new(:retribution_aura, [/\*\* Your aura unleashes a blast of divine retribution at (?<target>[^!]+)! \*\*/].freeze, true, false, false),
            # releases? throughout: plural subjects ("Your somnis boots
            # release ...", 910x round-5) drop the s
            FlareDef.new(:terror_weapon, [
              /\*\* Your .+? releases? a distorted black shadow! \*\*/,
              /\*\* Your .+? releases? a distorted black shadow at (?:the )?(?<target>[^!]+)! \*\*/,
              /\*\* (?<attacker>.+?)'s#{MK_POST} .+? releases? a distorted black shadow(?: at .+?)?! \*\*/
            ].freeze, false, false, false),
            FlareDef.new(:vethinye, [/\*\* As a resonating song emanates from (?:your|(?<attacker>.+?)'s#{MK_POST}) .+?, it entwines .+? in night blue wisps of ephemera\.  Suddenly, a star-sparked rush of percussive pressure .*?whips out at (?<target>[^!]+)! \*\*/].freeze, true, false, false),
            # targeted form ("... glow at the wendigo!") observed 92x round-5
            FlareDef.new(:xazkruvrixis, [/\*\* Your .+? emits an ominous black-green glow(?: at (?:the )?(?<target>[^!]+))?! \*\*/].freeze, false, false, false),
            FlareDef.new(:forceful_blows, [/\*\* With a mighty swing of your .+?, you deal (?<target>.+?) a forceful blow! \*\*/].freeze, false, false, false),
            FlareDef.new(:critical_hit, [/\*\* Critical hit!  Your .+? strikes (?<target>.+?) a savage blow! \*\*/].freeze, true, false, false),
            # Crusade/Repentance/Sanguine deity radiance (2p; color varies)
            FlareDef.new(:crusade, [/Your (?:.+?|body) surges with power as .+? radiance coalesces around it!/].freeze, true, true, false),
            FlareDef.new(:banshee, [/Your .+? emits a deafening wail as a bright red glow erupts from its surface, surrounding you!/].freeze, false, true, false),
            # incoming ammo/weapon elemental proc - the attacker's flare, us as victim
            FlareDef.new(:incoming_elemental, [/\*\* As (?<attacker>.+?)'s#{MK_POST} (?<weapon>.+?) hits you, it emits a burst of flame! \*\*/].freeze, true, false, false),

            # --- catalogued from Rysk THW/ambush logs (2026-08-20) ---
            # sanctified/blessed weapon; "Consumed by the hallowed flames"
            # damage line that follows is already in SPELL_DAMAGE
            FlareDef.new(:holy_fire, [/\*\* (?:Your|(?<attacker>.+?)'s#{MK_POST}) .+? bursts alight with leaping tongues of holy fire! \*\*/].freeze, true, false, false),
            # possibly custom messaging, but live and high-volume
            FlareDef.new(:shadow_daggers, [/\*\* Striking out of the darkness, unseen daggers stab at (?:the )?(?<target>.+?) from behind! \*\*/].freeze, true, false, false),
            # bloodstone jewelry proc; precedes "suffers an additional N
            # damage!" bleed ticks
            FlareDef.new(:bloodstone, [/\*\* Sanguine brilliance strikes (?:the )?(?<target>.+?) a rupturing blow! \*\*/].freeze, true, false, false),
            # arcarium harvested-essence procs (three tails share the prefix)
            FlareDef.new(:arcarium, [/\*\* Harvested essence stirs within your arcarium, rising to a keening ululation\./].freeze, false, true, false),
            FlareDef.new(:magma_ghosts, [/\*\* Splashing magma everywhere, charred red ghosts rise out of (?<attacker>.+?)'s#{MK_POST} .+? and sail through the air/].freeze, true, false, false),

            # --- blob-verified corpus additions (2026-08-20) ---
            # ethereal spirit-animal weapon procs; the "Riotous misty green
            # energy races along the surface" announce is this flare's PREFIX
            FlareDef.new(:spirit_animal, [/\*\* .+? ethereal (?<animal>[\w -]+?) (?:charges forward|rushes forward|dives down|lumbers forward|scurries forward|circles in the air|glides unsteadily downward)/].freeze, true, true, false),
            # offhand echo of the spirit-animal proc (non-damaging)
            FlareDef.new(:spirit_animal_echo, [/A turbulent cloud of .+? light lashes out from (?:a|an) .+? with an echoing (?:screech|howl|bellow|growl|roar|huff)!/].freeze, false, false, false),
            # defensive variant: fires on OUR evade, resolves via its own SMR;
            # the "angry growl reverberates through your X" line is its PREFIX
            FlareDef.new(:spirit_animal_growl, [/A deafening growl impacts (?<target>.+?) with a gust of displaced air!/].freeze, false, false, false),
            FlareDef.new(:gauntlet_tendrils, [/\*\* Tendrils of energy lash out from your (?<weapon>.+?) and surge towards (?<target>[^!]+)! \*\*/].freeze, true, false, false),
            # weighting proc
            FlareDef.new(:unyielding_force, [/\*\* (?:Your|(?<attacker>.+?)'s#{MK_POST}) (?<weapon>.+?) meets (?<target>.+?) with unyielding force! \*\*/].freeze, true, false, false),
            # sigil-dispel whiff: separate def because :sigil_dispel declares
            # damaging=true and this form must not promise a damage line
            FlareDef.new(:sigil_dispel_failed, [/\*\* Tendrils of .+? lash out from your .+? toward (?<target>.+?) and cage .+? within bands of concentric geometry that constrict as one, but dissipate harmlessly/].freeze, false, false, false),

            # Song of Mirrors echo: the image repeats the swing with its own
            # AS/DS + damage - damaging, so the flare cursor owns that roll
            # and damage instead of leaking them to the next attack
            # (real-feed capture, logs/examples/Barrage.txt)
            FlareDef.new(:mirror_image, [
              /\*\* Fleeting and insubstantial, a mirror image of you shimmers into view at your side, echoing your attack with one of its own! \*\*/,
              # shadow variant (logs/examples/mstrike.txt)
              /\*\* Fleeting and insubstantial, a whisper of shadow coalesces beside you, echoing your attack with one of its own! \*\*/,
              # 3p - another player's mirror echoes THEIR attack (round-6:
              # 33k; shadow sibling inferred from the same transformation)
              /\*\* Fleeting and insubstantial, a mirror image of (?<attacker>.+?) shimmers into view beside #{MK_PRE}(?:him|her)#{MK_POST}, echoing #{MK_PRE}(?:his|her)#{MK_POST} attack with one of its own! \*\*/,
              /\*\* Fleeting and insubstantial, a whisper of shadow coalesces beside (?<attacker>.+?), echoing #{MK_PRE}(?:his|her)#{MK_POST} attack with one of its own! \*\*/
            ].freeze, true, false, false),

            # Hunter's afterimage: the arrow re-forms in hand and the bow
            # fires AGAIN as its own "You fire ..." swing with its own roll
            # and damage. The announce arrives while the shot it rode is
            # still open (after that shot's damage/crit), so it attaches
            # there; the echo swing that follows opens its own event.
            # NOT damaging - the echo's damage belongs to the echo swing, and
            # a damaging flare here would steal the cursor from it. Lineage
            # is deliberately not chained (see processor spawn_root notes).
            # (real-feed 2026-09-07, gigas hunt; 3p form from corpus.)
            FlareDef.new(:hunters_afterimage, [
              /\*\* A radiant afterimage of the .+? appears in your ready hand, coalescing to replace its predecessor! \*\*/,
              /\*\* A radiant afterimage of the .+? appears in (?<attacker>.+?)'s#{MK_POST} ready hand, coalescing to replace its predecessor! \*\*/
            ].freeze, false, false, false),

            # lance/weapon motes proc - rolls its own SMR immediately after
            # (logs/examples/weapon_guardant_thrust.txt); damaging so the
            # flare cursor owns that roll instead of orphaning it
            FlareDef.new(:glittering_motes, [
              /\*\* A winking spray of glittering motes erupts from your .+?, showering (?<target>.+?) in sparkling flecks of clinging radiance! \*\*/,
              /\*\* A winking spray of glittering motes erupts from (?<attacker>.+?)'s#{MK_POST} .+?, showering (?<target>.+?) in sparkling flecks of clinging radiance! \*\*/
            ].freeze, true, false, false),

            # --- round-5 corpus additions (2026-08-21) ---
            # Reckoning: "Divine guidance intensifies your Reckoning!" is
            # its prefix (~3,500)
            FlareDef.new(:reckoning, [/\*\* Falling like a hammer from the sky, a golden light strikes (?:the )?(?<target>.+?) with resounding force! \*\*/].freeze, true, false, false),
            FlareDef.new(:alchemical_fire, [/\*\* A swirl of alchemical fire, .+?, erupts from your (?<weapon>[^!]+)! \*\*/].freeze, true, false, false),
            # 2p armor-trigger sigil bolt: separate name so :sigil_dispel's
            # damaging=true promise isn't inherited - this form runs its own SMR
            FlareDef.new(:sigil_bane, [/\*\* A bolt of energy leaps from your .+? and sets the sigils along your .+? ablaze\.\s+Tendrils of .+? lash out at (?<target>.+?) and cage/].freeze, false, false, false),
            # UAC gauntlet procs (damage follows each); releases? covers the
            # plural-gauntlets bare form per the A2 rule
            FlareDef.new(:spring_rod, [/\*\* Your .+? releases? a small spring-loaded rod! \*\*/].freeze, true, false, false),
            FlareDef.new(:shadow_strike, [/\*\* The shadows surrounding your .+? swirl off and strike! \*\*/].freeze, true, false, false),
            # defensive armor procs (safe from held-flare mis-claim: the
            # pre-flare claim requires a weapon match, and armor names never
            # match the swing weapon)
            FlareDef.new(:filament_corona, [/\*\* Branching filaments of power snap outward from your .+? in a lambent silver corona! \*\*/].freeze, false, false, false),
            FlareDef.new(:shadow_shroud, [/As (?<attacker>.+?) attacks you, a cyclone of shadows emerges? from your .+?\.\s+The shadows swirl around in an attempt to conceal you!/].freeze, false, false, false)
          ].freeze

          # [pattern, name, damaging, aoe, spawns] rows, one per pattern
          FLARE_LOOKUP = FLARE_DEFS.flat_map { |d|
            d.patterns.map { |rx| [rx, d.name, d.damaging, d.aoe, d.spawns] }
          }.freeze

          GATE, ALWAYS_SCAN = PatternGate.build(FLARE_LOOKUP.map(&:first))

          # Flare announce lines name the flaring weapon as a link:
          #   Your <a exist="393573117" noun="sword">slim short sword</a> ...
          # The exist id is the join key for claiming pre-flares by weapon.
          WEAPON_LINK = %r{Your <a exist="(?<id>\d+)" noun="[^"]+">(?<name>[^<]+)</a>}.freeze

          # Parse a flare announce line.
          #
          # @return [Hash, nil] { name:, damaging:, aoe:, spawns:, target:, weapon: }
          #   target is the named capture when the pattern has one (may be nil);
          #   weapon is { id:, name: } when the line links the flaring weapon.
          def self.parse(line)
            return nil unless GATE.match?(line) || ALWAYS_SCAN.any? { |rx| rx.match?(line) }

            FLARE_LOOKUP.each do |pattern, name, damaging, aoe, spawns|
              next unless (match = pattern.match(line))

              result = { name: name, damaging: damaging, aoe: aoe, spawns: spawns }
              result[:target] = match[:target] if match.names.include?('target') && match[:target]
              if (weapon = WEAPON_LINK.match(line))
                result[:weapon] = { id: weapon[:id].to_i, name: weapon[:name] }
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
