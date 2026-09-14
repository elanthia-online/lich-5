# frozen_string_literal: true

#
# Damage Pattern Definitions
# Various damage patterns from attacks, spells, flares, and environmental effects
#

require_relative 'pattern_gate'

module Lich
  module Gemstone
    module Combat
      module Definitions
        module Damage
          # Core damage patterns - most common
          BASIC_DAMAGE = [
            # "and hit for" is second person (your attacks); "and hits for"
            # is third person (other players' casts and companions) - both
            # are live, and missing the latter undercounted every group
            # member's initial hit while still counting their followups.
            # \s* not a literal space: several abilities emit "...N points"
            # with no space after the ellipsis (Bearhug, Empathic Assault)
            /\.\.\.\s*and hits? for (?<damage>\d+) points? of damage!/,
            /\.\.\.\s*(?<damage>\d+) points? of damage!/,
            /\.\.\.\s*hits for (?<damage>\d+) points? of damage!/,
            /\.\.\.\s*and receives (?<damage>\d+) points? of damage!/,
            /\.\.\.\s*and causes? (?<damage>\d+) points? of damage!/,
            # mid-cycle DoT ticks end in "..." not "!" (Fervent Reproach 312)
            /\.\.\.\s*(?<damage>\d+) points? of damage \.\.\./,
            /pulses for an additional (?<damage>\d+) points? of damage/,
            # Searing Light (135) per-target burn - "The bright light sears
            # the ant for 10 damage!" precedes the main damage line
            /sears .+? for (?<damage>\d+) damage!/,
            /dissipating with a final discharge of (?<damage>\d+) points? of damage!/,
            # roll-based maneuvers: "...6 damage!" - no "points of" at all
            /\.\.\.\s*(?<damage>\d+) damage!/,
            # indirect/AoE hits (third person; high volume in group logs)
            /(?<target>.+?) is hit for (?<damage>\d+) points? of damage!/,
            /(?<target>.+?) is smashed for (?<damage>\d+) points? of damage!/,
            # lingering/bleed ticks - note: no "points of", plain "damage!"
            /(?<target>.+?) suffers an additional (?<damage>\d+) damage!/
          ].freeze

          # Spell damage patterns
          SPELL_DAMAGE = [
            /Consumed by the hallowed flames, (?<target>.+?) is ravaged for (?<damage>\d+) points? of damage!/,
            /Wisps of black smoke swirl around (?<target>.+?) and it bursts into flame causing (?<damage>\d+) points? of damage!/,
            /Sound waves disrupt for (?<damage>\d+) damage!/,
            /(?<target>.+?) is cloaked in a blinding platinum light and assailed for (?<damage>\d+) points? of damage!/,
            /Ripples of cold white flame flare up around (?<target>.+?) and blister .+? for (?<damage>\d+) points? of damage!/,
            /Cloudy tendrils writhe throughout (?<target>.+?) form, ravaging .+? for (?<damage>\d+) points? of damage!/,
            # 702 Mana Disruption grades its lead word by endroll; only
            # "Massive" is captured in local logs (overkill casters), so
            # anchor on the invariant phrase and take any grade word
            /\w+ internal disruption for (?<damage>\d+) points? of damage!/,
            /(?<target>.+?) is struck by a burning projectile, taking (?<damage>\d+) points? of damage!/,
            /Blazing light, hot and blistering, coalesces around (?<target>.+?) for (?<damage>\d+) points? of damage!/,
            # Stone Fist (514) hand actions - inline damage, no "..." prefix
            /The stone hand throws (?<target>.+?) and .+? goes flying through the air, then hits the ground with a loud thud\.\s+(?<damage>\d+) points? of damage!/,
            /The stone hand lets (?<target>.+?) go free for a moment, then quickly moves to slap #{MK_PRE}(?:him|her|it)#{MK_POST}\.\s*(?<damage>\d+) points? of damage!/,
            /The stone hand closes its grasp around (?<target>.+?) and squeezes\.\s*(?<damage>\d+) points? of damage!/,
            /The stone hand raises (?<target>.+?) into the air and brings #{MK_PRE}(?:him|her|it)#{MK_POST} down, pounding #{MK_PRE}(?:him|her|it)#{MK_POST} into the (?:floor|ground)\.\s*(?<damage>\d+) points? of damage!/,
            # elemental storm ticks (710 Energy Maelstrom / Immolation storms)
            /The (?:rocks|hailstones|hail|winds|bolts|heat) (?:pummels?|burns?|electrif(?:y|ies)|assaults?) (?<target>.+?) for (?<damage>\d+) points? of damage!/
          ].freeze

          # Environmental/cyclone damage patterns.
          #
          # Generalized over the element: Chromatic Circle (502) alone has
          # five observed variants (crackling lightning ARCS, whirlwind
          # SWIRLS, shifting stones ORBIT, flickering flames swirl, ice
          # shards orbit), all sharing the "causing N points of damage"
          # tail. The old per-element list missed "arcs" entirely, so every
          # lightning 502 kill undercounted by the arc damage - and that
          # total is the LOWER bound for max_hp, so brackets came out low.
          ENVIRONMENTAL_DAMAGE = [
            /quickly (?:arcs?|swirls?|orbits?) around (?<target>[^,]+), causing (?<damage>\d+) points? of damage!/,
            /quickly (?:arcs?|swirls?|orbits?) (?<target>[^,]+), causing (?<damage>\d+) points? of damage!/
          ].freeze

          # Broad fallbacks, ordered LAST so the specific patterns above win
          # their better target captures first. These close whole families
          # (deity Condemn variants, Pestilence DoT wordings, "for N damage"
          # spells, maneuver "N hits!") without a def per flavor line.
          FALLBACK_DAMAGE = [
            /(?<target>.+?) for (?<damage>\d+) points? of damage[.!]/,
            /causing (?<damage>\d+) points? of damage!/,
            /inflicting (?<damage>\d+) points? of damage(?: in their wake)?!/,
            /(?<target>.+?) for (?<damage>\d+) damage!/,
            / (?<damage>\d+) hits!/
          ].freeze

          # All damage patterns combined
          ALL_DAMAGE = (BASIC_DAMAGE + SPELL_DAMAGE + ENVIRONMENTAL_DAMAGE + FALLBACK_DAMAGE).freeze

          # Compiled regex for fast detection
          DAMAGE_DETECTOR = Regexp.union(ALL_DAMAGE).freeze

          # Parse damage from line
          def self.parse(line)
            # Fast rejection: every damage pattern contains "damage" except
            # the maneuver "N hits!" form. The substring check skips the
            # regex scan on the ~95% of lines that can't match; the union
            # detector rejects near-misses cheaply.
            return nil unless line.include?('damage') || line.include?(' hits!')
            return nil unless DAMAGE_DETECTOR.match?(line)

            ALL_DAMAGE.each do |pattern|
              if (match = pattern.match(line))
                result = { damage: match[:damage].to_i }
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
