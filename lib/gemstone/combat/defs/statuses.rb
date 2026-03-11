# frozen_string_literal: true

#
# Status Effect Pattern Definitions
# Combat status effects like stun, prone, blind, etc.
#

module Lich
  module Gemstone
    module Combat
      module Definitions
        module Statuses
          StatusDef = Struct.new(:name, :add_patterns, :remove_patterns)

          # Core status effects with both add and remove patterns
          STATUS_EFFECTS = [
            StatusDef.new(:blind,
                          [/You blinded (?<target>[^!]+)!/].freeze,
                          [/(?<target>.+?) vision clears\./].freeze),

            StatusDef.new(:immobilized,
                          [
                            /(?<target>.+?) form is entangled in an unseen force that restricts .+? movement\./,
                            /(?<target>.+?) shakes in utter terror!/
                          ].freeze,
                          [
                            /(?<target>.+?) movements no longer appear hampered as the lunar light encircling .+? fades away\./,
                            /The restricting force enveloping (?<target>.+?) fades away\./,
                          ].freeze),

            StatusDef.new(:prone,
                          [
                            /It is knocked to the ground!/,
                            /(?<target>.+?) is knocked to the ground!/,
                            /(?<target>.+?) falls to the ground!/
                          ].freeze,
                          [
                            /(?<target>.+?) stands back up\./,
                            /(?<target>.+?) gets back to .+? feet\./,
                            /(?<target>.+?) rises to .+? feet\./,
                            /(?<target>.+?) stands up\./
                          ].freeze),

            StatusDef.new(:stunned,
                          [/The (?<target>.+?) is stunned!/].freeze,
                          [
                            /(?<target>.+?) shakes off the stun effect\./,
                            /(?<target>.+?) regains .+? composure\./,
                            /(?<target>.+?) is no longer stunned\./
                          ].freeze),

            StatusDef.new(:sunburst,
                          [/(?<target>.+?) reels and stumbles under the intense flare!/].freeze,
                          [/(?<target>.+?) blinks a few times, regaining a sense of balance\./].freeze),

            StatusDef.new(:webbed,
                          [/(?<target>.+?) becomes ensnared in thick strands of webbing!/].freeze,
                          [
                            /(?<target>.+?) breaks free of the webs\./,
                            /(?<target>.+?) struggles free of the webs\./,
                            /(?<target>.+?) tears through the webbing\./,
                            /The webs dissolve from around (?<target>.+?)\./
                          ].freeze),

            StatusDef.new(:sleeping,
                          [
                            /(?<target>.+?) falls into a deep slumber\./,
                            /(?<target>.+?) falls asleep\./
                          ].freeze,
                          [
                            /(?<target>.+?) wakes up\./,
                            /(?<target>.+?) awakens\./,
                            /(?<target>.+?) opens .+? eyes\./
                          ].freeze),

            StatusDef.new(:poisoned,
                          [/(?<target>.+?) appears to be suffering from a poison\./].freeze,
                          [
                            /(?<target>.+?) looks much better\./,
                            /(?<target>.+?) recovers from the poison\./
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
                          [/(?<target>.+?) appears to recover some strength\./].freeze)
          ].freeze

          # Create lookup tables for fast pattern matching
          ADD_LOOKUP = STATUS_EFFECTS.flat_map do |status_def|
            status_def.add_patterns.compact.map { |pattern| [pattern, status_def.name, :add] }
          end.freeze

          REMOVE_LOOKUP = STATUS_EFFECTS.flat_map do |status_def|
            status_def.remove_patterns.compact.map { |pattern| [pattern, status_def.name, :remove] }
          end.freeze

          ALL_LOOKUP = (ADD_LOOKUP + REMOVE_LOOKUP).freeze

          # Compiled regex for fast detection
          STATUS_DETECTOR = Regexp.union(ALL_LOOKUP.map(&:first)).freeze

          # Parse status effect from line
          def self.parse(line)
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
