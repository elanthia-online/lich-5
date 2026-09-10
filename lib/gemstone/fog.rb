# frozen_string_literal: true

# Fog: the ways home. Spirit Guide (130), Symbol of Return (Voln), Traveler's
# Song (1020), Sigil of Escape (Sunfist) and Familiar Gate (930) each take a
# character out of the field to a known room. Getting home is a thing any
# script may need, not a hunting rule, so it belongs in core: this is
# bigshot's fog_return routine on the spell and society readers, with the
# answer confirmed on the room changing rather than assumed.
#
#   Lich::Gemstone::Fog.available                        # => [:spirit_guide, :symbol_of_return]
#   Lich::Gemstone::Fog.return(:spirit_guide)            # => true when the room changed
#   Lich::Gemstone::Fog.return(2, rift: true, resting_room: 4)   # bigshot's numbering
#
# Policy stays with the caller: which method a profile picks, whether to fog at
# all, and any custom command list are the script's. What each method is, what
# it costs, how it is sent and how it is confirmed are here.
module Lich
  module Gemstone
    module Fog
      # The Rift's exit: a fog that lands here needs a second cast to go on
      # (bigshot fog_return_spirit, fog_return_voln).
      RIFT_ROOM = 2635

      # Seconds to wait for the room to change after a send. A fog resolves
      # in one server pulse; a Traveler's Song walk takes longer.
      CONFIRM_TIMEOUT = 8

      METHODS = %i[spirit_guide symbol_of_return travelers_song sigil_of_escape familiar_gate].freeze

      # bigshot's fog_return setting (1-5; 6 is the profile's own commands)
      NUMBERS = { 1 => :spirit_guide, 2 => :symbol_of_return, 3 => :travelers_song, 4 => :sigil_of_escape, 5 => :familiar_gate }.freeze

      SPELLS = { spirit_guide: 130, travelers_song: 1020, familiar_gate: 930 }.freeze

      # @param method [Symbol, Integer, String] a METHODS name or bigshot's number
      # @return [Symbol, nil]
      def self.normalize(method)
        return NUMBERS[method] if method.is_a?(Integer)
        return NUMBERS[method.to_i] if method.to_s =~ /\A\d+\z/

        sym = method.to_s.downcase.to_sym
        METHODS.include?(sym) ? sym : nil
      end

      # Does this character have the method at all.
      def self.known?(method)
        case normalize(method)
        when :spirit_guide, :travelers_song, :familiar_gate then spell_known?(SPELLS[normalize(method)])
        when :symbol_of_return then voln&.known?('return') || false
        when :sigil_of_escape then sunfist&.known?('escape') || false
        else false
        end
      end

      # Known and affordable right now.
      def self.available?(method)
        case normalize(method)
        when :spirit_guide, :travelers_song, :familiar_gate
          num = SPELLS[normalize(method)]
          spell_known?(num) && Spell[num].affordable?
        when :symbol_of_return then voln&.available?('return') || false
        when :sigil_of_escape then sunfist&.available?('escape') || false
        else false
        end
      end

      # @return [Array<Symbol>] every method the character can use right now
      def self.available
        METHODS.select { |m| available?(m) }
      end

      # Go home by +method+. Waits out roundtime first, pulses mana when the
      # spell is known but unaffordable, and answers whether the room changed.
      #
      # Spirit Guide and Symbol of Return fall back to each other when the
      # first does not move us, and cast a second time when the first cast
      # lands in the Rift and the destination is elsewhere - bigshot's rules,
      # kept.
      #
      # @param method [Symbol, Integer, String]
      # @param rift [Boolean] the destination is reached through the Rift
      # @param resting_room [Integer, nil] with +rift+, the room the fog is for
      # @return [Boolean] whether the room changed
      def self.return(method, rift: false, resting_room: nil)
        method = normalize(method)
        return false if method.nil?

        start = here
        sleep 0.5
        waitcastrt?
        waitrt?
        case method
        when :spirit_guide then spirit_guide(rift: rift, resting_room: resting_room)
        when :symbol_of_return then symbol_of_return(rift: rift, resting_room: resting_room)
        when :travelers_song then travelers_song
        when :sigil_of_escape then sigil_of_escape
        when :familiar_gate then familiar_gate
        end
        moved_from?(start)
      end

      # --- the five ------------------------------------------------------------

      # @api private
      def self.spirit_guide(rift: false, resting_room: nil, from_voln: false)
        start = here
        pulse_mana(130)
        if available?(:spirit_guide)
          cast_and_settle(130)
          second_cast_from_rift(rift, resting_room, start) do
            # the first cast may have spent the mana the second needs (bigshot pulses again here)
            pulse_mana(130)
            cast_and_settle(130) if available?(:spirit_guide)
          end
        end
        return true if moved_from?(start)

        # 130 did not move us: Symbol of Return, once (fog_return_spirit)
        symbol_of_return(rift: rift, resting_room: resting_room, from_spirit: true) if !from_voln && known?(:symbol_of_return)
        moved_from?(start)
      end

      # @api private
      def self.symbol_of_return(rift: false, resting_room: nil, from_spirit: false)
        start = here
        if known?(:symbol_of_return)
          fput 'symbol of return'
          wait_for_move(start)
          second_cast_from_rift(rift, resting_room, start) do
            rift_mark = here
            fput 'symbol of return'
            wait_for_move(rift_mark)
          end
        end
        return true if moved_from?(start)

        # the symbol did not move us: Spirit Guide, once (fog_return_voln)
        spirit_guide(rift: rift, resting_room: resting_room, from_voln: true) if !from_spirit && known?(:spirit_guide)
        moved_from?(start)
      end

      # @api private
      def self.travelers_song
        pulse_mana(1020)
        cast_and_settle(1020) if available?(:travelers_song)
      end

      # @api private
      def self.sigil_of_escape
        return unless available?(:sigil_of_escape)

        fput 'sigil of escape'
        sleep 0.5
        waitcastrt?
        waitrt?
      end

      # @api private
      def self.familiar_gate
        pulse_mana(930)
        return unless available?(:familiar_gate)

        Spell[930].cast
        fput 'go portal'
        sleep 0.5
        waitcastrt?
        waitrt?
      end

      # --- helpers ---------------------------------------------------------------

      # @api private
      def self.cast_and_settle(num)
        start = here
        Spell[num].cast
        sleep 0.5
        waitcastrt?
        wait_for_move(start)
      end

      # A fog into the Rift with the destination elsewhere is cast again
      # from 2635 (bigshot: @FOG_RIFT && @RESTING_ROOM_ID != 2635).
      # @api private
      def self.second_cast_from_rift(rift, resting_room, start)
        return unless rift && resting_room.to_i != RIFT_ROOM
        return unless moved_from?(start) && room_id == RIFT_ROOM

        yield
      end

      # MANA PULSE before a known spell we cannot afford (bigshot mana_pulse).
      # @api private
      def self.pulse_mana(num)
        return unless spell_known?(num) && !Spell[num].affordable?

        dothistimeout 'mana pulse', 2, /An invigorating rush of mana pulses through you|You are too mentally fatigued|You're already at full mana|Your mana control skills are not yet advanced/i
        sleep 0.2
      end

      # @api private
      def self.wait_for_move(start)
        deadline = Time.now + CONFIRM_TIMEOUT
        sleep 0.25 until moved_from?(start) || Time.now > deadline
        moved_from?(start)
      end

      # Where we are, as the server reports it: the server room id, which
      # is set for an unmapped room too (Room.current is nil there, and a
      # map id would compare nil to nil and call a real move a failure),
      # with the room counter alongside for the rare stream that carries
      # no id.
      # @api private
      def self.here = { id: XMLData.room_id.to_s, count: XMLData.room_count }

      # A move is a different server room id. The counter alone is not
      # evidence: it steps on every room refresh, moved or not, so it is
      # consulted only when an id is missing on either side.
      # @api private
      def self.moved_from?(start)
        now = here
        return now[:id] != start[:id] unless now[:id].empty? || start[:id].empty?

        now[:count] != start[:count]
      end

      # The map id, for the Rift check only.
      # @api private
      def self.room_id = Room.current&.id

      # @api private
      def self.spell_known?(num)
        spell = Spell[num]
        !spell.nil? && spell.known?
      end

      # @api private
      def self.voln
        Societies::OrderOfVoln if defined?(Societies::OrderOfVoln)
      end

      # @api private
      def self.sunfist
        Societies::GuardiansOfSunfist if defined?(Societies::GuardiansOfSunfist)
      end
    end
  end
end
