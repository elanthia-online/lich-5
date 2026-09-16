# frozen_string_literal: true

# Mana: the MANA PULSE verb (Mana Control), sent and confirmed once.
#
# bigshot, ebounty and eherbs each carry a copy of the same "pulse if I can't
# afford this spell" sequence with the same four result lines. This is that
# sequence.
#
#   Mana.pulse            # pulse now, return the game's answer
#   Mana.pulse(130)       # pulse only if 130 is known and not currently affordable
#   Mana.pulse(Spell[130])
module Lich
  module Gemstone
    module Mana
      PULSE_RESULT = Regexp.union(
        /^An invigorating rush of mana pulses through you/i,
        /^You are too mentally fatigued to attempt this ability/i,
        /^You're already at full mana\./i,
        /^Your mana control skills are not yet advanced/i,
      ).freeze

      PULSED = /^An invigorating rush of mana pulses through you/i.freeze

      # Send MANA PULSE, optionally only when it would help cast a given spell.
      #
      # @param spell [Integer, Spell, nil] when given, pulse only if the spell is
      #   known and not affordable right now
      # @param timeout [Numeric]
      # @return [Boolean] true when mana was gained, false when the game refused,
      #   nothing confirmed, or the spell did not need it
      def self.pulse(spell = nil, timeout: 2)
        unless spell.nil?
          spell = Spell[spell] unless spell.is_a?(Spell)
          return false if spell.nil? || !spell.known? || spell.affordable?
        end
        waitrt?
        result = dothistimeout('mana pulse', timeout, PULSE_RESULT)
        sleep 0.2
        result.to_s =~ PULSED ? true : false
      end
    end
  end
end
