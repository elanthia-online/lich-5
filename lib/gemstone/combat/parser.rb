# frozen_string_literal: true

#
# Combat Parser - Core parsing methods for combat events
# Performance-optimized with lazy loading and selective pattern matching
#

require_relative 'defs/attacks'
require_relative 'defs/damage'
require_relative 'defs/statuses'

module Lich
  module Gemstone
    module Combat
      module Parser
        # Target link pattern - extract creatures/players from XML
        TARGET_LINK_PATTERN = /<a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)<\/a>/i.freeze

        # Bold tag pattern - creatures are wrapped in bold tags
        # Non-greedy match to avoid spanning multiple creatures
        BOLD_WRAPPER_PATTERN = /<pushBold\/>([^<]+<a exist="[^"]+"[^>]+>[^<]+<\/a>)<popBold\/>/i.freeze

        class << self
          # Parse attack initiation
          def parse_attack(line)
            return nil unless attack_detector.match?(line)

            attack_lookup.each do |pattern, name|
              if (match = pattern.match(line))
                target_info = extract_target_from_match(match) || extract_target_from_line(line)
                return {
                  name: name,
                  target: target_info || {},
                  damaging: true
                }
              end
            end
            nil
          end

          # Parse damage amounts using damage definitions
          def parse_damage(line)
            result = Definitions::Damage.parse(line)
            result ? result[:damage] : nil
          end

          # Parse status effects (optional - performance setting)
          def parse_status(line)
            return nil unless Tracker.settings[:track_statuses]

            # Return the full result including action field
            Definitions::Statuses.parse(line)
          end

          # Extract creature target (must be wrapped in bold tags)
          def extract_creature_target(line)
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
              name: link_match[:name]
            }
          end

          # Try to extract target from regex match first, then from line
          def extract_target_from_match(match)
            return nil unless match.names.include?('target')
            target_text = match[:target]
            return nil if target_text.nil? || target_text.strip.empty?

            # Look for creature in target text
            if (target_match = TARGET_LINK_PATTERN.match(target_text))
              id = target_match[:id].to_i
              return nil if id < 0

              return {
                id: id,
                noun: target_match[:noun],
                name: target_match[:name]
              }
            end

            nil
          end

          def extract_target_from_line(line)
            # ONLY accept bolded creatures as targets
            # Non-bolded links are equipment, objects, or other non-combatants
            extract_creature_target(line)
          end

          private

          # Lazy-loaded pattern lookups for performance
          def attack_lookup
            @attack_lookup ||= Definitions::Attacks::ATTACK_LOOKUP
          end

          def attack_detector
            @attack_detector ||= Definitions::Attacks::ATTACK_DETECTOR
          end

          # Clear cached patterns when settings change
          def reset_cache!
            @attack_lookup = nil
            @attack_detector = nil
          end
        end
      end
    end
  end
end
