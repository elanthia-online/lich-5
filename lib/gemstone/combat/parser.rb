# frozen_string_literal: true

#
# Combat Parser - Core parsing methods for combat events
# Performance-optimized with lazy loading and selective pattern matching
#

require_relative 'defs/assaults'
require_relative 'defs/attacks'
require_relative 'defs/damage'
require_relative 'defs/flares'
require_relative 'defs/outcomes'
require_relative 'defs/sequences'
require_relative 'defs/spell_losses'
require_relative 'defs/statuses'
require_relative 'defs/ucs'

module Lich
  module Gemstone
    module Combat
      module Parser
        # Target link pattern - extract creatures/players from XML
        TARGET_LINK_PATTERN = /<a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>/i.freeze
        # A link whose closing tag lies beyond the captured text (see
        # extract_attacker_from_match)
        OPEN_LINK_TAIL_PATTERN = /<a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)\z/i.freeze

        # Bold tag pattern - creatures are wrapped in bold tags
        # Non-greedy match to avoid spanning multiple creatures
        # Allow zero or more characters before <a> tag (e.g., "a creature" or just "creature")
        BOLD_WRAPPER_PATTERN = /<pushBold\/>([^<]*<a exist="[^"]+"[^>]+>[^<]+<\/a>)<popBold\/>/i.freeze

        # NOTE ON SCALE: each def family gates itself with a small literal
        # union (PatternGate). A single combined prefilter union was tried
        # and measured SLOWER (58us vs 35us/line on real logs) - Ruby's
        # regex engine scans large alternations linearly, so one big union
        # costs more than several small ones. When def counts grow into the
        # hundreds-per-family, the proven fix is a first-word bucket index
        # (see CritRanks - 2,389 patterns, indexed by first literal word),
        # not a bigger union.

        class << self
          # Parse attack initiation
          def parse_attack(line)
            # One table read per call: lookup and gate from the same build
            # even if the defs are hot-reloaded mid-chunk.
            table = Definitions::Attacks.table
            return nil if table.rejects?(line)

            table.lookup.each do |pattern, name|
              if (match = pattern.match(line))
                # An inbound attack (creature -> us) names US as its target.
                # Its only creature link is the ATTACKER, so the line-scan
                # fallback below would install the attacker as its own
                # target and apply its damage/crits to itself. Resolve the
                # target as us and stop - never fall through.
                # Environmental / self-inflicted defs (ATTACKERLESS) are
                # damage to us by construction - no attacker, no "you"
                # capture - unless this particular pattern named someone
                # else (a nearby player taking the same tick). They name
                # their source for the ledger: 'environment' (weather) or
                # 'self' (our own gear), so reports can tell them apart.
                attackerless = Definitions::Attacks::ATTACKERLESS.include?(name) &&
                               !(match.names.include?('target') && match[:target])
                if self_target?(match) || attackerless || Definitions::Attacks::ROOM_TARGETED.include?(name)
                  attacker = extract_attacker_from_match(match)
                  if attackerless
                    attacker ||= { name: Definitions::Attacks::ENVIRONMENTAL.include?(name) ? 'environment' : 'self' }
                  end
                  return {
                    name: name,
                    target: {},
                    inbound: true,
                    attacker: attacker,
                    damaging: true
                  }
                end

                # The fallback is only safe when the def has NO target
                # capture: then the sole creature link on the line really is
                # the target. When a def DID capture a target but it failed
                # to resolve to a creature link, scanning the line would find
                # some other creature (typically the attacker) - so don't.
                attacker = extract_attacker_from_match(match)
                target_info = if match.names.include?('target')
                                extract_target_from_match(match)
                              else
                                extract_target_from_line(line)
                              end
                # Nothing can attack itself. An untargeted def (an AoE like
                # the mastodon's tremors) has no target capture, so the
                # line-scan above returns the only link present - the
                # attacker. Drop it: the event is genuinely untargeted, and
                # the per-target lines that follow bind the real victims.
                target_info = nil if target_info && attacker &&
                                     attacker[:id] && target_info[:id] == attacker[:id]
                result = {
                  name: name,
                  target: target_info || {},
                  damaging: true
                }
                # The def NAMED a target but it is not a creature link - a
                # player ("striking Sugiin!"), or a name we cannot resolve.
                # The event is therefore bound to someone who is not a
                # creature, and must never later adopt one: the caster's own
                # bolded props (a summoned ethereal sphere) and room echoes
                # would otherwise fill the empty slot through the
                # target-switcher and take that third party's damage with
                # them (real-feed replay, GSIV-Monstr 2025-09-30).
                if target_info.nil? && match.names.include?('target') &&
                   !match[:target].to_s.strip.empty?
                  result[:foreign_target] = true
                end
                # Third-person defs capture the attacker (a player link with
                # a negative exist id, or a pushBold-wrapped creature link)
                result[:attacker] = attacker if attacker
                # A NEARBY PLAYER's attack on a creature we can see. When a
                # 3p attack names its actor but that actor is not us and not
                # a creature - a player link (negative id) or a bare name
                # from mid-sentence prose (the paladin weapon_infusion proc
                # names "Heavenscent", not a link) - the whole event belongs
                # to that player. Marked foreign_caster so the processor
                # emits it for observers but never lands its damage on our
                # ledger, the attacker-side mirror of foreign_target
                # (real-feed, GSIV-Nisugi 2026-09-06). Attacks a CREATURE
                # makes on us are :inbound and handled above; those keep
                # their creature-id attacker and are not foreign_caster.
                if attacker && !result[:inbound] &&
                   (attacker[:id].to_i < 0 || (attacker[:id].nil? && attacker[:name]))
                  result[:foreign_caster] = true
                end
                result[:weapon] = strip_links(match[:weapon]) if match.names.include?('weapon') && match[:weapon]
                # Aimed shots ("You take aim and fire...", "You make a precise
                # attempt to jab...") roll differently from unaimed ones. The
                # defs have captured this all along; it was never surfaced.
                result[:aimed] = true if match.names.include?('aimed') && match[:aimed]
                return result
              end
            end
            nil
          end

          # A target capture that refers to US rather than a creature.
          # Anchored at the start of the capture: real forms observed in
          # session logs are "you", "your <bodypart>" and tails like
          # "you with its tusk" - but NOT a creature whose name merely
          # contains the word ("a youngling"), hence the \b and the anchor.
          SELF_TARGET_PATTERN = /\A(?:you|your)\b/i.freeze

          # Some inbound defs name us in the pattern LITERAL rather than in a
          # target capture ("<attacker> springs from the shadows and strikes
          # at you!", "... plants <weapon> ... near you"). They have an
          # attacker capture and no target capture, so without this they too
          # fall through to the line-scan and self-attribute. A def that
          # captures an attacker and addresses "you"/"your" in its own source
          # is aimed at us by construction.
          SELF_IN_PATTERN = /\b(?:at|towards?|upon|around|near|on)\s+your?\b/i.freeze

          def self_target?(match)
            if match.names.include?('target')
              text = match[:target]
              return false if text.nil?

              return SELF_TARGET_PATTERN.match?(strip_links(text).strip)
            end

            # No target capture: inbound only if the def both identifies an
            # attacker and addresses us literally.
            match.names.include?('attacker') &&
              SELF_IN_PATTERN.match?(match.regexp.source)
          end

          # True when this line is an attack aimed at US. Used by the
          # processor to keep the attacker's own link out of the
          # target-switcher (see the inbound_line note there).
          def inbound_attack?(line)
            table = Definitions::Attacks.table
            return false if table.rejects?(line)

            table.lookup.each do |pattern, name|
              if (match = pattern.match(line))
                return self_target?(match) || Definitions::Attacks::ROOM_TARGETED.include?(name)
              end
            end
            false
          end

          # Attacker from a third-person def's (?<attacker>...) capture.
          # Unlike targets, player attackers have NEGATIVE exist ids, so no
          # id sign check; plain text (pre-stripped logs) falls back to name.
          def extract_attacker_from_match(match)
            return nil unless match.names.include?('attacker')

            text = match[:attacker]
            return nil if text.nil? || text.strip.empty?

            # The LAST link: a flavor prefix can carry the attacker's own
            # pronoun link first ("Froth bubbling on <his> lips, <a tattooed
            # gigas berserker> swings..." - hunt log 2026-09-07 recorded the
            # attacker as "his").
            links = text.to_enum(:scan, TARGET_LINK_PATTERN).map { Regexp.last_match }
            # A possessive INSIDE the link ("<a>flayed gigas disciple's</a>
            # power warps the air") leaves the capture ending mid-link: the
            # def's 's sits inside the <a>. Take the unterminated link too.
            links << Regexp.last_match if links.empty? && OPEN_LINK_TAIL_PATTERN.match(text)
            if (link = links.last)
              { id: link[:id].to_i, noun: link[:noun], name: link_name(link) }
            else
              { name: strip_links(text).strip }
            end
          end

          # Drop XML link/bold markup from a captured fragment
          def strip_links(text)
            text.gsub(/<[^>]+>/, '')
          end

          # A creature's display name from its link. The game sometimes puts
          # the possessive INSIDE the link ("<a>grim gigas skald's</a> mastery
          # of music"), which registered a second creature named "grim gigas
          # skald's" (hunt log 2026-09-07). Same id, same creature: strip it.
          # A hidden adjective leaves a doubled space ("halfling  cannibal"),
          # squeezed for the same reason.
          def link_name(link)
            link[:name].sub(/'s\z/, '').squeeze(' ').strip
          end

          # Parse damage amounts using damage definitions
          def parse_damage(line)
            result = Definitions::Damage.parse(line)
            result ? result[:damage] : nil
          end

          # Parse a flare announce line (weapon scripts, enchants, GEFs,
          # flourishes). Returns name/damaging/aoe/spawns plus the flaring
          # weapon's { id:, name: } when the line links it.
          def parse_flare(line)
            Definitions::Flares.parse(line)
          end

          # Why a swing produced nothing: :evade, :block, :parry, :warded,
          # :miss, :fumble, :hindrance, :confused
          def parse_outcome(line)
            Definitions::Outcomes.parse(line)
          end

          # Roll lines: AS/DS, CS/TD, UAF/UDF, SMR - returns the full
          # breakdown { type:, as:, ds:, avd:, roll:, result: ... }
          def parse_resolution(line)
            Definitions::Resolutions.parse(line)
          end

          # Multi-TARGET action brackets (mstrike, volley, spawned casts)
          def parse_sequence_start(line)
            Definitions::Sequences.parse_start(line)
          end

          def parse_sequence_end(line)
            Definitions::Sequences.parse_end(line)
          end

          # Single-target multi-round assault brackets (flurry, barrage,
          # pummel, guardant thrusts, thrash) - see defs/assaults.rb
          def parse_assault_start(line)
            Definitions::Assaults.parse_start(line)
          end

          def parse_assault_end(line)
            Definitions::Assaults.parse_end(line)
          end

          # The weapon a swing line names, in plain text (swing lines do
          # not link the weapon):  "You swing a kelyn-edged slim short
          # sword at <pushBold/>..." - used to claim pre-flares by weapon.
          # The weapon itself may be linked ("You swing a perfect <a ...>mithril
          # mace</a> at ..."), so anchor tags are dropped before matching and
          # the capture ends at the " at " that precedes the target (linked or
          # plain) rather than at a literal "<".
          SWING_WEAPON_PATTERN = /You(?: take aim and)? (?:swing|fire) (?:an? |your |some )?(?<weapon>[^<]+?) at (?=<|\S)/.freeze

          def parse_swing_weapon(line)
            SWING_WEAPON_PATTERN.match(line.gsub(%r{</?a\b[^>]*>}, ''))&.[](:weapon)
          end

          # Parse status effects (optional - performance setting)
          def parse_status(line)
            return nil unless Tracker.settings[:track_statuses]

            # Return the full result including action field
            Definitions::Statuses.parse(line)
          end

          # Third-person spell wear-off lines pinned to a spell number
          # (defs/spell_losses.rb). Unlike statuses these apply to players
          # in view as well as creatures, so the subject resolves through
          # ANY link (negative player ids included), falling back to the
          # stripped capture text for plain logs.
          def parse_spell_loss(line)
            return nil unless Tracker.settings[:track_statuses]

            result = Definitions::SpellLosses.parse(line)
            return nil unless result

            if (link = TARGET_LINK_PATTERN.match(result[:target].to_s))
              result[:id]   = link[:id].to_i
              result[:name] = link[:name]
            else
              result[:id]   = nil
              result[:name] = strip_links(result[:target].to_s).strip
            end
            result
          end

          # Parse UCS events (position, tierup, smite)
          def parse_ucs(line)
            return nil unless Tracker.settings[:track_ucs]

            Definitions::UCS.parse(line)
          end

          # Extract creature target (must be wrapped in bold tags)
          def extract_creature_target(line)
            # Cheap gate: the wrapper pattern can't match without the bold tag,
            # and the substring check avoids two regexes on most lines
            return nil unless line.include?('<pushBold/>')

            # Check if line contains a bolded link
            bold_match = BOLD_WRAPPER_PATTERN.match(line)
            return nil unless bold_match

            # Extract the link from within the bold tags
            link_text = bold_match[1]
            link_match = TARGET_LINK_PATTERN.match(link_text)
            return nil unless link_match

            id = link_match[:id].to_i
            return nil if id <= 0 # Skip invalid IDs

            {
              id: id,
              noun: link_match[:noun],
              name: link_name(link_match)
            }
          end

          # Try to extract target from regex match first, then from line
          def extract_target_from_match(match)
            return nil unless match.names.include?('target')
            target_text = match[:target]
            return nil if target_text.nil? || target_text.strip.empty?

            # Look for creature in target text. A possessive capture ends at
            # the apostrophe INSIDE the link text ("<a ...>human robber" + "'s"
            # outside), so the closing tag falls beyond the capture and
            # TARGET_LINK_PATTERN cannot match - bleed/trickle ticks were
            # resolving to no target and recording as foreign (Rysk logs
            # 2026-09-11: 10 bleed ticks on named creatures, all unattributed).
            # Fall back to the open-tail form, as the attacker path does.
            if (target_match = TARGET_LINK_PATTERN.match(target_text) ||
                               OPEN_LINK_TAIL_PATTERN.match(target_text))
              id = target_match[:id].to_i
              return nil if id < 0

              return {
                id: id,
                noun: target_match[:noun],
                name: link_name(target_match)
              }
            end

            nil
          end

          def extract_target_from_line(line)
            # ONLY accept bolded creatures as targets
            # Non-bolded links are equipment, objects, or other non-combatants
            extract_creature_target(line)
          end
        end
      end
    end
  end
end
