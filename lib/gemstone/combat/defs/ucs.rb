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

          class << self
            # Parse UCS-related events from a line
            # Returns: { type: :position|:tierup|:smite_on|:smite_off, target_id: id, value: ... }
            def parse(line)
              # Position update
              if (match = POSITION_PATTERN.match(line))
                position = match[1]
                target_id = match[2].to_i
                return {
                  type: :position,
                  target_id: target_id,
                  value: position
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
