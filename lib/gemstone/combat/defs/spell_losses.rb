# frozen_string_literal: true

#
# Spell-Loss Pattern Definitions
#
# Third-person wear-off lines of ordinary spell-circle spells, keyed by
# spell number - NOT creature statuses, and deliberately not new status
# vocabulary. These are the "dispel buff-strip family" from the
# 2026-09-04 multi-chunk sweep: ~90% ride directly behind dispel/
# sigil_dispel flares (creatures shedding their self-buff stacks), the
# rest are natural expiry, including on player characters in view.
#
# Conversion discipline (owner ruling 2026-09-04): a line is only added
# here once it is pinned to a specific spell. Identification methods:
#   - effect-list.xml first-person start/end wording (suggestive only -
#     the 404 misattribution of "focused look" shows wording alone lies)
#   - cross-log timestamp pairing: the third-person line in a sibling
#     character's log at the same second as the first-person wear-off in
#     the subject's own log (how 1109 was proven)
# Unpinned wear-offs ("elemental aura wavers", "hazy film coats") stay
# residue by design.
#

require_relative 'pattern_gate'

module Lich
  module Gemstone
    module Combat
      module Definitions
        module SpellLosses
          SpellLossDef = Struct.new(:spell, :spell_name, :patterns)

          SPELL_LOSSES = [
            # wiki-pinned 2026-09-04 (owner directive: wiki first, log
            # pairing for what the wiki can't settle). 107's page carries
            # the motes first-person verbatim; the glow-leaves form falls
            # out of the Dispel flare page's worked example (two spells
            # stripped, 107 + 120, and "both the very powerful look and
            # white light come from 120" - the remaining line is 107's).
            SpellLossDef.new(107, 'Spirit Warding II',
                             [
                               /Deep blue motes swirl away from (?<target>.+?) and fade\./,
                               /The deep blue glow leaves (?<target>[^.]+)\./
                             ].freeze),
            SpellLossDef.new(120, 'Lesser Shroud',
                             [
                               /The very powerful look leaves (?<target>[^.]+)\./,
                               /The white light leaves (?<target>[^.]+)\./
                             ].freeze),
            # proven by pairing 2026-02-02 12:16:24: sibling logs show
            # "Nisugi loses his focused look." as Nisugi's own log prints
            # 1109's end message "Your mind's keen focus fades away."
            SpellLossDef.new(1109, 'Empathic Focus',
                             [/(?<target>.+?) loses #{MK_PRE}(?:his|her|its)#{MK_POST} focused look\./].freeze),
            SpellLossDef.new(1119, 'Strength of Will',
                             [/(?<target>.+?) loses an aura of resolve\./].freeze),
            # onset observed in the wild: "gets an intense expression."
            SpellLossDef.new(1130, 'Intensity',
                             [/(?<target>.+?) loses an intense expression\./].freeze),
            # effect-list pins (2026-09-04 round 2): first-person end
            # messages verbatim ("You no longer bristle with energy.",
            # "You become solid again." - 911 only, no standalone Blur
            # entry exists; 1605's end names the same warmth+spiritual
            # force around the arms the third person describes)
            SpellLossDef.new(513, 'Elemental Focus',
                             [/(?<target>.+?) no longer bristles with energy\./].freeze),
            SpellLossDef.new(911, 'Mass Blur',
                             [/(?<target>.+?) becomes solid again\./].freeze),
            SpellLossDef.new(1605, 'Arm of the Arkati',
                             [/(?<target>.+?)'s#{MK_POST} movements no longer appear to be influenced by a divine power as the spiritual force fades from around #{MK_PRE}(?:his|her|its)#{MK_POST} arms\./].freeze),
            # owner-pinned via the 319 wiki page (collapse wear-off
            # verbatim; the same page carries the intercept "flares to
            # life" wording outcomes.rb claims)
            SpellLossDef.new(319, 'Soul Ward',
                             [/The air about (?<target>.+?) shimmers momentarily before the evanescent shield surrounding #{MK_PRE}(?:him|her|it|you)#{MK_POST} collapses\./].freeze),
            # wiki-pinned: first-person wear-offs verbatim on the 1209/1214
            # pages ("The scales covering your hands turn brittle...",
            # "The thick plates of bone around your forearms...")
            SpellLossDef.new(1209, 'Dragonclaw',
                             [/The scales covering (?<target>.+?)'s#{MK_POST} hands turn brittle and flake away\./].freeze),
            SpellLossDef.new(1214, 'Brace',
                             [/The thick plates of bone around (?<target>.+?)'s#{MK_POST} forearms begin to crack, then shatter into a fine white dust\./].freeze),
            # owner-pinned. The line color varies by caster (observed:
            # dark, blue, pale blue, ether blue, purple, jade green,
            # umber, snow white) - wildcarded, anchored on the invariant
            # sentence frame
            SpellLossDef.new(1208, 'Mindward',
                             [/A series of [\w ]+ lines suddenly appears on (?<target>.+?)'s#{MK_POST} face, quickly racing towards the center of #{MK_PRE}(?:his|her|its)#{MK_POST} forehead before detaching and dissipating in the air\./].freeze),
            SpellLossDef.new(1204, 'Foresight',
                             [/(?<target>.+?) takes a deep breath, blinking a couple of times before resuming a calm expression\./].freeze),

            # The game's GENERIC third-person wear-off - the fallback
            # wording for any spell without bespoke end messaging
            # (owner ruling 2026-09-05: "a spell coming off, not sure
            # which one" - and there is no which: 26+/15+ creature
            # spread, fires in quiet RP contexts with no cascade, no
            # effect-list phrase). spell: nil is deliberate - "some
            # spell left this target"; the cause attribution still
            # applies. This is the one permitted exception to the
            # pin-before-convert rule, because the wording itself is
            # the game's unspecified-spell marker.
            SpellLossDef.new(nil, 'unknown',
                             [
                               /(?<target>.+?) appears somehow different\./,
                               /(?<target>.+?) seems slightly different\./
                             ].freeze)
          ].freeze

          LOOKUP = SPELL_LOSSES.flat_map do |loss_def|
            loss_def.patterns.map { |pattern| [pattern, loss_def] }
          end.freeze

          GATE, ALWAYS_SCAN = PatternGate.build(LOOKUP.map(&:first))

          # Parse a spell wear-off line. Returns { spell:, spell_name:,
          # target: <raw capture> } or nil.
          def self.parse(line)
            return nil if PatternGate.rejects?(GATE, ALWAYS_SCAN, line)

            LOOKUP.each do |pattern, loss_def|
              if (match = pattern.match(line))
                return {
                  spell: loss_def.spell,
                  spell_name: loss_def.spell_name,
                  target: match[:target]
                }
              end
            end
            nil
          end
        end
      end
    end
  end
end
