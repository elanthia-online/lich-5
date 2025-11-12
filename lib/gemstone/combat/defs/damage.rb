# frozen_string_literal: true

#
# Damage Pattern Definitions
# Various damage patterns from attacks, spells, flares, and environmental effects
#

module Lich
  module Gemstone
    module Combat
      module Definitions
        module Damage
          # Core damage patterns - most common
          BASIC_DAMAGE = [
            /\.\.\. and hit for (?<damage>\d+) points? of damage!/,
            /\.\.\. (?<damage>\d+) points? of damage!/,
            /\.\.\. hits for (?<damage>\d+) points? of damage!/
          ].freeze

          # Spell damage patterns
          SPELL_DAMAGE = [
            /Consumed by the hallowed flames, (?<target>.+?) is ravaged for (?<damage>\d+) points? of damage!/,
            /Wisps of black smoke swirl around (?<target>.+?) and it bursts into flame causing (?<damage>\d+) points? of damage!/
          ].freeze

          # Environmental/cyclone damage patterns
          ENVIRONMENTAL_DAMAGE = [
            /The whirlwind quickly swirls around (?<target>.+?), causing (?<damage>\d+) points? of damage!/,
            /The flickering flames quickly swirl around (?<target>.+?), causing (?<damage>\d+) points? of damage!/,
            /The shifting stones quickly orbit (?<target>.+?), causing (?<damage>\d+) points? of damage!/
          ].freeze

          # All damage patterns combined
          ALL_DAMAGE = (BASIC_DAMAGE + SPELL_DAMAGE + ENVIRONMENTAL_DAMAGE).freeze

          # Compiled regex for fast detection
          DAMAGE_DETECTOR = Regexp.union(ALL_DAMAGE).freeze

          # Parse damage from line
          def self.parse(line)
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
