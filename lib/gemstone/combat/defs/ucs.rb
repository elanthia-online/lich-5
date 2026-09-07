# frozen_string_literal: true

#
# UCS (Unarmed Combat System) tracking definitions
# Patterns for position tiers, tierup vulnerabilities, and smite status
#

module Lich
  module Gemstone
    module Combat
      module Definitions
        module UCS
          # Pattern for position updates - use .+ not .*
          # Example: "You have good positioning against a kobold."
          POSITION_PATTERN = /^You have (decent|good|excellent) positioning against.+<a exist="([0-9]+)"/i.freeze

          # Inbound mirror of POSITION_PATTERN: the creature's tier
          # against US, printed as the second line of its UCS attack
          # block (round-14 sweep: 40/40 sandwiched between the
          # "attempts to jab you!" initiation and the UAF/UDF roll;
          # only "decent" attested but the vocabulary is shared).
          # Example: "The triton brawler has decent positioning against you."
          POSITION_INBOUND_PATTERN = /<a exist="([0-9]+)"[^>]*>[^<]+<\/a>(?:<popBold\/>)? has (decent|good|excellent) positioning against you\./i.freeze

          # Pattern for tierup vulnerability
          # Example: "Strike leaves foe vulnerable to a followup jab attack!"
          TIERUP_PATTERN = /Strike leaves foe vulnerable to a followup (jab|grapple|punch|kick) attack!/i.freeze

          # Pattern for smite applied (crimson mist)
          # Use .+ not .*
          SMITE_APPLIED_PATTERN = /^ *A crimson mist suddenly surrounds .+<a exist="([0-9]+)"/i.freeze

          # Pattern for smite held in corporeal plane
          SMITE_HELD_PATTERN = /The crimson mist surrounding .+<a exist="([0-9]+)".+held in the corporeal plane/i.freeze

          # Pattern for smite removed
          SMITE_REMOVED_PATTERN = /^ *The crimson mist surrounding .+<a exist="([0-9]+)".+returns to an ethereal state/i.freeze

          # Positioning tier words -> ordinal, so the recorder can persist
          # positioning as a number (its value column is numeric) and
          # queries can compare outbound vs inbound tiers directly.
          POSITION_TIERS = { 'decent' => 1, 'good' => 2, 'excellent' => 3 }.freeze

          # Literal substrings required by the patterns below - used as a cheap
          # gate so non-UCS lines skip all five regexes.
          RELEVANT_SUBSTRINGS = ['positioning against', 'vulnerable to a followup', 'crimson mist'].freeze

          class << self
            # Quick check whether a line could contain a UCS event
            def relevant?(line)
              RELEVANT_SUBSTRINGS.any? { |s| line.include?(s) }
            end

            # Parse UCS-related events from a line
            # Returns: { type: :position|:position_inbound|:tierup|:smite_on|:smite_off, target_id: id, value: ... }
            # Position types also carry tier: 1..3 (see POSITION_TIERS).
            def parse(line)
              return nil unless relevant?(line)

              # Position update
              if (match = POSITION_PATTERN.match(line))
                position = match[1]
                target_id = match[2].to_i
                return {
                  type: :position,
                  target_id: target_id,
                  value: position,
                  tier: POSITION_TIERS[position.downcase]
                }
              end

              # Creature's position against us (per-swing attack
              # metadata, not persistent state - it prints inside the
              # inbound UCS attack block)
              if (match = POSITION_INBOUND_PATTERN.match(line))
                position = match[2]
                return {
                  type: :position_inbound,
                  target_id: match[1].to_i,
                  value: position,
                  tier: POSITION_TIERS[position.downcase]
                }
              end

              # Tierup vulnerability
              if (match = TIERUP_PATTERN.match(line))
                attack_type = match[1]
                return {
                  type: :tierup,
                  value: attack_type
                  # Note: target_id comes from most recent target in combat context
                }
              end

              # Smite applied or held
              if (match = SMITE_APPLIED_PATTERN.match(line))
                target_id = match[1].to_i
                return {
                  type: :smite_on,
                  target_id: target_id
                }
              end

              if (match = SMITE_HELD_PATTERN.match(line))
                target_id = match[1].to_i
                return {
                  type: :smite_on,
                  target_id: target_id
                }
              end

              # Smite removed
              if (match = SMITE_REMOVED_PATTERN.match(line))
                target_id = match[1].to_i
                return {
                  type: :smite_off,
                  target_id: target_id
                }
              end

              nil
            end
          end
        end
      end
    end
  end
end
