# frozen_string_literal: true

#
# Status Effect Pattern Definitions
# Combat status effects like stun, prone, blind, etc.
#

require_relative 'pattern_gate'

module Lich
  module Gemstone
    module Combat
      module Definitions
        module Statuses
          StatusDef = Struct.new(:name, :add_patterns, :remove_patterns)

          # Core status effects with both add and remove patterns
          STATUS_EFFECTS = [
            StatusDef.new(:blind,
                          [
                            /You blinded (?<target>[^!]+)!/,
                            /You are blinded!/,
                            /Your eyes suddenly cloud over\.  A moment later you realize you cannot see at all\./,
                            /Suddenly, a silver mist swirls about you\.  Golden arcs streak across your vision/,
                            /(?<target>.+?) is blinded!/,
                            # re-blind confirmation (round-11/12 generic
                            # table: 7,232 lines across 272 creatures);
                            # add_status is idempotent so re-adding is safe
                            /(?<target>.+?) is already blinded\./
                          ].freeze,
                          [
                            /(?<target>.+?) vision clears\./,
                            /(?<target>.+?) steadies #{MK_PRE}(?:himself|herself|itself)#{MK_POST} as #{MK_PRE}(?:he|she|it)#{MK_POST} recovers from #{MK_PRE}(?:his|her|its)#{MK_POST} blindness\./
                          ].freeze),

            StatusDef.new(:immobilized,
                          [
                            /(?<target>.+?) form is entangled in an unseen force that restricts .+? movement\./,
                            /(?<target>.+?) shakes in utter terror!/,
                            /An unseen force entangles you, restricting your movement!/,
                            # 619 Moonbeam hold onset - pairs with the
                            # "lunar light encircling ... fades away" remove
                            # below (full-corpus sweep 2026-09-03: ~85k lines
                            # across up to 26 creatures per moon variant;
                            # only observed moons listed)
                            /(?<target>.+?) is caught fast, the light of (?:Liabo|Lornon|Tilaok|the moon) arresting #{MK_PRE}(?:his|her|its)#{MK_POST} movements\./,
                            /You are pinned in place, unable to move\./,
                            /(?<target>.+?) is rooted in place!/,
                            # ambient still-immobilized tick (round-13
                            # sweep: fires under the Moonbeam hold and the
                            # untagged "odd paralysis"/lassitude effects,
                            # never webs; the grits-teeth analog for this
                            # status). Idempotent re-add.
                            /(?<target>.+?) struggles as #{MK_PRE}(?:he|she|it)#{MK_POST} tries to move\./
                          ].freeze,
                          [
                            /(?<target>.+?) movements no longer appear hampered as the lunar light encircling .+? fades away\./,
                            /The restricting force enveloping (?<target>.+?) fades away\./,
                          ].freeze),

            StatusDef.new(:prone,
                          [
                            /It is knocked to the ground!/,
                            /(?<target>.+?) is knocked to the ground!/,
                            /(?<target>.+?) falls to the ground!/,
                            # 501 landing on a STANDING target: the sleep
                            # def registers sleeping off the same line;
                            # the fall itself is also a knockdown (the
                            # goes-limp variant is the already-prone form
                            # and deliberately absent here).
                            /(?<target>.+?) slumps to the ground unconscious\./,
                            # second person - the victim is us
                            /You are knocked to the ground!/,
                            /You lose your footing and fall to the ground!/,
                            /Your feet are suddenly swept from under you!/,
                            /You fall flat on the floor\./,
                            /You fall to the ground!/,
                            /(?<target>.+?) loses #{MK_PRE}(?:his|her|its)#{MK_POST} balance and falls to the ground\./,
                            # crit-free injury knockdowns (add_status is
                            # idempotent, so overlap with critranks is safe)
                            /(?<target>.+?) falls to the ground grasping #{MK_PRE}(?:his|her|its)#{MK_POST} mangled (?:right|left) (?:leg|arm)!/,
                            /(?<target>.+?) falls to #{MK_PRE}(?:his|her|its)#{MK_POST} knees in pain!/,
                            # "falls over" family: tremors stomp, wind AoE,
                            # sonic-onslaught proc, burning smother roll
                            /(?<target>.+?) loses #{MK_PRE}(?:his|her|its)#{MK_POST} balance and falls over\./,
                            /The wind knocks (?<target>.+?) off balance and #{MK_PRE}(?:he|she|it)#{MK_POST} falls over!/,
                            /Reeling from the sonic onslaught, (?<target>.+?) staggers and falls over, writh(?:ing|es)/,
                            /(?<target>.+?) falls to the ground and rolls, trying to smother the flames/,
                            # round-5 period-form
                            /(?<target>.+?) wobbles painfully and #{MK_PRE}(?:he|she|it)#{MK_POST} falls to the ground\./,
                            # spine-crush knockdown flavor; often the ONLY
                            # knockdown line printed (exchange evidence
                            # 2026-09-03, 1.9k lines / 50+ creatures). The
                            # "unconscious"/"in a deep slumber" tails file
                            # as :sleeping, not here.
                            /(?<target>.+?) slumps to the ground\./
                          ].freeze,
                          [
                            /(?<target>.+?) stands back up\./,
                            /(?<target>.+?) gets back to .+? feet\./,
                            /(?<target>.+?) rises to .+? feet\./,
                            /(?<target>.+?) stands up\./,
                            # round-5
                            /(?<target>.+?) leaps (?:back )?up from the ground/,
                            /(?<target>.+?) rises back into a standing position/,
                            # round-11/12 generic table: 7,715 lines across
                            # 45 creatures; the bare "stands up." pattern
                            # above requires the period right after "up"
                            /(?<target>.+?) stands up with a grunt\./
                          ].freeze),

            # round-5: Judgment and knockdown-to-knees results (~200 + every
            # Judgment blob). The lookbehind keeps the subdue result line
            # ("is dazed and is driven to its knees!") filing as :paralyzed.
            StatusDef.new(:kneeling,
                          [
                            /(?<target>.+?)(?<! dazed and)(?<! paralyzed and) is (?:knocked|driven) to #{MK_PRE}(?:his|her|its)#{MK_POST} knees!/,
                            /You crash to the ground, falling to your knees!/
                          ].freeze,
                          [].freeze),

            StatusDef.new(:sitting,
                          [/(?<target>.+?) is knocked into a sitting position!/].freeze,
                          # standing back up clears sitting - same remove
                          # messagings as prone
                          [
                            /(?<target>.+?) stands back up\./,
                            /(?<target>.+?) gets back to .+? feet\./,
                            /(?<target>.+?) rises to .+? feet\./,
                            /(?<target>.+?) stands up\./
                          ].freeze),

            StatusDef.new(:stunned,
                          [
                            /The (?<target>.+?) is stunned!/,
                            /(?<target>.+?) is badly stunned!/,
                            # pronoun confirmations - period (assess/look) and
                            # bang (combat) forms both live
                            /^\s*(?<target>#{MK_PRE}(?:He|She|It))#{MK_POST} is stunned[.!]/,
                            # second person - the victim is us
                            /You are stunned(?: for (?<rounds>\d+) rounds?)?!/,
                            /^You are still stunned\./,
                            # ambient still-stunned indicators (multi-chunk
                            # sweep 2026-09-04: failed recovery tick and the
                            # between-rounds idle sway; both fire alone in
                            # their own chunk, never with a crit, with the
                            # stun add 1-3 chunks earlier). Idempotent
                            # re-adds, same treatment as "is already blinded"
                            /(?<target>.+?) grits #{MK_PRE}(?:his|her|its)#{MK_POST} teeth, but is unable to recover #{MK_PRE}(?:his|her|its)#{MK_POST} wits\./,
                            /(?<target>.+?) staggers slightly, swaying about in a daze\./,
                            # crtrStatus-proven (2026-09-04): stunned="1"
                            # in the last repaint before the line 20/20,
                            # still stunned at the next repaint 16/20 -
                            # a failed break or idle tick, identical for
                            # our purposes. Berserker-only in corpus but
                            # the wording is generic.
                            /(?<target>.+?) looks sluggishly about with dazed eyes\./
                          ].freeze,
                          [
                            # "the stun" (no "effect") is the live third-person
                            # wording; flavor prefixes vary by creature
                            /(?<target>.+?) shakes off the stun(?: effect)?[.!]/,
                            /(?<target>.+?) twitches fiercely, shaking off the stun!/,
                            /(?<target>.+?) throws .+? head back and howls, shaking off the stun!/,
                            /(?<target>.+?) regains .+? composure\./,
                            /(?<target>.+?) is no longer stunned\./,
                            /You are no longer stunned\./,
                            /with a sudden surge of strength, you throw off your stunned state!/,
                            /(?<target>.+?) shudders violently before visibly recovering from #{MK_PRE}(?:his|her|its)#{MK_POST} stunned state\./,
                            # round-5
                            /(?<target>.+?) throws off #{MK_PRE}(?:his|her|its)#{MK_POST} dazed state/,
                            # unparsed variant of the shakes-off family
                            # (sweep 2026-09-04: 15/36 windows show the stun
                            # add on the same creature 1-3 chunks earlier;
                            # trailing clause is creature flavor, anchor on
                            # the shared core only)
                            /(?<target>.+?) shakes free from #{MK_PRE}(?:his|her|its)#{MK_POST} stunned state/,
                            /Rivulets of swirling incarnadine energy envelop (?<target>.+?) scarred flesh, allowing #{MK_PRE}(?:him|her|it)#{MK_POST} to move freely once more\./
                          ].freeze),

            # Dispel landing - a spell stripped from the target (round-6:
            # 44k; follows the dispel/sigil_dispel flare + its SMR)
            StatusDef.new(:dispelled,
                          [
                            /A white glow rushes away from (?<target>[^.]+)\./,
                            # dispel-flare landing confirmation (exchange
                            # evidence 2026-09-03: directly follows dispel/
                            # sigil_dispel flares in all captured exchanges;
                            # 13.4k lines / 50+ creatures)
                            /(?<target>.+?) blinks and looks around in confusion for a moment\./
                          ].freeze,
                          [].freeze),

            # Weapon knocked from the grip (round-6: 32k+ across spear/
            # targe/handaxe). Indent-anchored crit-tail form - unindented
            # period lines are room item-drop flavor, not this
            StatusDef.new(:disarmed,
                          [/^#{MK_POST}\s+The (?<target>.+?)'s#{MK_POST} (?<weapon>.+?) falls to the ground\./].freeze,
                          [].freeze),

            StatusDef.new(:sunburst,
                          [/(?<target>.+?) reels and stumbles under the intense flare!/].freeze,
                          [/(?<target>.+?) blinks a few times, regaining a sense of balance\./].freeze),

            StatusDef.new(:webbed,
                          [
                            /(?<target>.+?) becomes ensnared in thick strands of webbing!/,
                            /You become ensnared in thick strands of webbing!/,
                            /(?<target>.+?) is firmly webbed in place\./
                          ].freeze,
                          [
                            /(?<target>.+?) breaks free of the webs\./,
                            /(?<target>.+?) struggles free of the webs\./,
                            /(?<target>.+?) tears through the webbing\./,
                            /The webs dissolve from around (?<target>.+?)\./
                          ].freeze),

            StatusDef.new(:sleeping,
                          [
                            /(?<target>.+?) falls into a deep slumber\./,
                            /(?<target>.+?) falls asleep\./,
                            # Lullabye full-sleep wording (also implies prone)
                            /(?<target>.+?) falls to the ground in a deep slumber\./,
                            /(?<target>.+?)'s#{MK_POST} eyes roll up into its head as it slumps to the ground\./,
                            # 501 Sleep landing (forge test server, 2026-08-28):
                            # both wordings read as deaths before this - the
                            # death-lore grammar guards on \bunconscious\b, and
                            # these are the lines that guard exists for.
                            /(?<target>.+?) slumps to the ground unconscious\./,
                            /(?<target>.+?) goes limp as #{MK_PRE}(?:he|she|it)#{MK_POST} falls unconscious[.!]/
                          ].freeze,
                          [
                            /(?<target>.+?) wakes up\./,
                            /(?<target>.+?) awakens\./,
                            /(?<target>.+?) opens .+? eyes\./,
                            # 2p-attacker form of the :unconscious remove
                            # below (round-11/12 generic table: 4,836 lines
                            # across 124 creatures)
                            /(?<target>.+?) is awakened by your attack!/
                          ].freeze),

            StatusDef.new(:poisoned,
                          [
                            /(?<target>.+?) appears to be suffering from a poison\./,
                            /You feel a fierce poison coursing through your veins!/,
                            /A virulent poison courses through your veins!/,
                            /You feel poison coursing through your veins\./,
                            /Bilious poison seeps into (?<target>.+?) flesh, sending #{MK_PRE}(?:him|her|it)#{MK_POST} into paroxysms of agony!/
                          ].freeze,
                          [
                            /(?<target>.+?) looks much better\./,
                            /(?<target>.+?) recovers from the poison\./,
                            /(?<target>.+?) collects #{MK_PRE}(?:himself|herself|itself)#{MK_POST} as the poison afflicting #{MK_PRE}(?:him|her|it)#{MK_POST} finally runs its course\./
                          ].freeze),

            StatusDef.new(:roundtime,
                          [/(?<target>.+?) struggles momentarily with the gale\./].freeze,
                          [].freeze),

            StatusDef.new(:sounds,
                          [/(?<target>.+?) seems to be distracted by something\./].freeze,
                          [].freeze),

            StatusDef.new(:calm,
                          [/A calm washes over (?<target>.+?)\./].freeze,
                          [
                            /The calmed look leaves (?<target>.+?)\./,
                            /(?<target>.+?) is enraged by your attack\!/
                          ].freeze),

            StatusDef.new(:natures_decay,
                          [
                            /An earthy, sweet aroma clings to (?<target>.+?) in a murky haze, accompanied by soot brown specks of leaf mold\./,
                            /An earthy, sweet aroma wafts from (?<target>.+?) in a murky haze\./,
                            /The earthy, sweet aroma clinging to (?<target>.+?) grows more pervasive\./
                          ].freeze,
                          [/The earthy, sweet aroma surrounding (?<target>.+?) dwindles as the murky haze disperses./].freeze),

            StatusDef.new(:tangleweed,
                          [/You notice .+? scrape into (?<target>.+?) skin. .+? suddenly looks very weak!/].freeze,
                          [/(?<target>.+?) appears to recover some strength\./].freeze),

            # --- catalogued from 2026-08-20 arena spectator logs ---
            StatusDef.new(:unconscious,
                          [
                            /(?<target>.+?) goes limp as #{MK_PRE}(?:he|she|it)#{MK_POST} is rendered unconscious!/,
                            /You go limp as you are rendered unconscious!/,
                            /(?<target>.+?) slumps to the ground in an unconscious heap\./
                          ].freeze,
                          [
                            /(?<target>.+?) is awakened by (?<attacker>.+?)'s#{MK_POST} attack!/,
                            # full-corpus sweep 2026-09-03: 1,256 lines
                            # across 50+ creatures
                            /(?<target>.+?) slowly comes back to consciousness\./
                          ].freeze),

            StatusDef.new(:slowed,
                          [
                            /(?<target>.+?) movements slow to a crawl!/,
                            /(?<target>.+?) suddenly slows all movements\./
                          ].freeze,
                          [].freeze),

            # Blessed 2026-09-04: the crit-echo theory held only for UCS
            # exchanges. The multi-chunk sweep found three no-crit sources
            # (noxious brume SMR, Powersink, cold wyrm flyover - the last
            # hits players too), so this line DOES carry information no
            # other line carries. Add-only; when it trails a dizzies crit
            # the critranks :dazed flag re-adds harmlessly.
            StatusDef.new(:dazed,
                          [/(?<target>.+?) appears dazed and unsure\./].freeze,
                          [].freeze),

            # KO-class disable from the rogue subdue strike; "dazed and is
            # driven to its knees" is the same maneuver's lighter result
            StatusDef.new(:paralyzed,
                          [/(?<target>.+?) is (?:paralyzed|dazed)(?: and is driven to #{MK_PRE}(?:his|her|its)#{MK_POST} knees)?!/].freeze,
                          [].freeze),

            StatusDef.new(:terrified,
                          [
                            /Your limbs lock and you quiver with fright!/,
                            /You shake with terror!/,
                            /You are immobilized with sheer terror!/,
                            /(?<target>.+?) freezes in place, quivering with fright!/,
                            /(?<target>.+?) freezes in place, shaking with terror!/,
                            /(?<target>.+?) shakes with terror!/,
                            /(?<target>.+?) freezes in utter terror!/,
                            /(?<target>.+?) is frozen with fear!/,
                            # Evil Eye result (round-5)
                            /(?<target>.+?) is frightened into utter immobility!/
                          ].freeze,
                          [/You regain control of your senses!/].freeze),

            StatusDef.new(:silenced,
                          [/(?<target>.+?) chokes, momentarily unable to speak!/].freeze,
                          [].freeze),

            StatusDef.new(:weakened,
                          # standalone strength-drain line (the tangleweed def
                          # above requires the "You notice ... scrape" prefix)
                          [
                            /(?<target>.+?) suddenly looks very weak!/,
                            /(?<target>.+?) appears weak and feeble, #{MK_PRE}(?:his|her|its)#{MK_POST} movements sluggish\./
                          ].freeze,
                          [/(?<target>.+?) appears to recover some strength\./].freeze),

            # 1625 Templar's Verdict defense-debuff rider: printed right
            # after the violet-flame damage in every captured exchange
            # (2026-09-03; 7.2k lines / 50+ creatures). Add-only - no
            # expiry line observed yet.
            StatusDef.new(:vulnerable,
                          [/(?<target>.+?)'s#{MK_POST} defenses are diminished in the wake of the flames\./].freeze,
                          [].freeze),

            # Immolation-class burn: onset and per-round ticks observed in
            # the 2026-09-03 exchanges (bursts-into-flame carries its own
            # inline damage; continue-to-burn is the round tick); the
            # shakes-off line is the expiry, printed even as death cleanup.
            # add_status is idempotent so the tick re-add is safe.
            StatusDef.new(:burning,
                          [
                            /Wisps of black smoke swirl around (?<target>.+?) and #{MK_PRE}(?:he|she|it)#{MK_POST} bursts into flame/,
                            /The flames around (?<target>.+?) continue to burn!/
                          ].freeze,
                          [
                            # 4.8k lines / 50+ creatures
                            /(?<target>.+?) shakes off the effects of the flames\./
                          ].freeze),

            # DS vulnerability (502 whirlwind et al.). The onset wording
            # varies by damage type but keeps the "off balance and exposed"
            # core; the recovery is the shared "regains balance" line
            # (6.8k lines / 40+ creatures). Crit-driven unbalance onsets
            # ("stumbles forward, off balance.") stay with critranks, same
            # split as :dazed. Remove fires as a no-op when the onset was
            # a crit or an uncaptured variant.
            StatusDef.new(:off_balance,
                          [
                            /leaves? (?<target>.+?) off balance and exposed to/,
                            # short-form rider without the "exposed" suffix
                            # (sweep 2026-09-04: "The whirlwind leaves the
                            # mastodon off balance.")
                            /leaves? (?<target>.+?) off balance\./
                          ].freeze,
                          [/(?<target>.+?) regains #{MK_PRE}(?:his|her|its)#{MK_POST} balance\./].freeze),

            # Temporary physical-damage immunity gained in response to
            # damage of that type (owner exchange 2026-09-05: Bone
            # Shatter damage -> this line -> "unharmed by the impact!"
            # on every subsequent impact hit). Stimulus vocabulary is
            # tiny: vibrations (27.6k, ->impact) and piercing (12,
            # ->puncture). Add-only - no expiry line observed. The
            # elemental unharmed-by-X lines are NOT this: those are
            # innate (gorefrost golem vs cold), with no onset at all.
            StatusDef.new(:hardened,
                          [/In response to the \w+, (?<target>.+?)'s#{MK_POST} skin seems to discolor and harden, lending the .+? unnatural durability!/].freeze,
                          [].freeze),

            # Remove-only, like :dispelled/:disarmed: creatures enter hiding
            # through per-creature flavor lines (creature messaging, not
            # grammar), but the un-hide transitions are shared wording
            # (round-11/12 candidate list: "is revealed from hiding."
            # 2,533x/2, "is forced out of hiding!" 416x/5). Removing a
            # status that was never added is a harmless no-op.
            StatusDef.new(:hidden,
                          [].freeze,
                          [
                            /(?<target>.+?) is revealed from hiding\./,
                            # both terminators live (sweep: period 2,200x/8,
                            # bang 416x/5)
                            /(?<target>.+?) is forced out of hiding[.!]/
                          ].freeze)
          ].freeze

          # Create lookup tables for fast pattern matching
          ADD_LOOKUP = STATUS_EFFECTS.flat_map do |status_def|
            status_def.add_patterns.compact.map { |pattern| [pattern, status_def.name, :add] }
          end.freeze

          REMOVE_LOOKUP = STATUS_EFFECTS.flat_map do |status_def|
            status_def.remove_patterns.compact.map { |pattern| [pattern, status_def.name, :remove] }
          end.freeze

          ALL_LOOKUP = (ADD_LOOKUP + REMOVE_LOOKUP).freeze

          # Compiled regex for fast detection. NOTE: costs ~1ms per
          # non-matching line (unanchored `.+?` alternatives); kept for
          # compatibility but the literal gate below is what parse uses.
          STATUS_DETECTOR = Regexp.union(ALL_LOOKUP.map(&:first)).freeze

          # Literal-substring gate (~7us/line, measured on session logs)
          STATUS_GATE, STATUS_ALWAYS_SCAN = PatternGate.build(ALL_LOOKUP.map(&:first))

          # Parse status effect from line
          def self.parse(line)
            # Fast rejection: a line can only match a status pattern if it
            # contains that pattern's literal fragment.
            return nil if PatternGate.rejects?(STATUS_GATE, STATUS_ALWAYS_SCAN, line)

            ALL_LOOKUP.each do |pattern, name, action|
              if (match = pattern.match(line))
                result = {
                  status: name,
                  action: action # :add or :remove
                }
                result[:target] = match[:target] if match.names.include?('target') && match[:target]
                return result
              end
            end
            nil
          end
        end
      end
    end
  end
end

# Disir shaking moonbeam/immobilize
# A shining winged disir's wings unfurl in a rainbow of color that brightens toward blinding white.  The forces restraining her fall away in shreds of crackling mana.
