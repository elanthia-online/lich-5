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

      # Seconds to wait for the room to change after a send. A fog resolves in
      # one server pulse, so 8 is generous for the four that fog; a Traveler's
      # Song is a walk to the destination and gets its own, longer budget.
      CONFIRM_TIMEOUT = 8
      TRAVELERS_SONG_TIMEOUT = 60

      # Real room UIDs are small integers. Above this the id is xmlparser's
      # MD5 stand-in for a room that arrived with no UID (xmlparser.rb, the
      # <compass> branch), which is not unique across same-text rooms.
      MAX_ROOM_UID = 1_000_000_000

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
        name = normalize(method)
        case name
        when :spirit_guide, :travelers_song, :familiar_gate then spell_known?(SPELLS[name])
        when :symbol_of_return then voln&.known?('return') || false
        when :sigil_of_escape then sunfist&.known?('escape') || false
        else false
        end
      end

      # Known and affordable right now.
      def self.available?(method)
        name = normalize(method)
        case name
        when :spirit_guide, :travelers_song, :familiar_gate
          num = SPELLS[name]
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
        cast_and_settle(1020, timeout: TRAVELERS_SONG_TIMEOUT) if available?(:travelers_song)
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
      def self.cast_and_settle(num, timeout: CONFIRM_TIMEOUT)
        start = here
        Spell[num].cast
        sleep 0.5
        waitcastrt?
        wait_for_move(start, timeout: timeout)
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
      def self.wait_for_move(start, timeout: CONFIRM_TIMEOUT)
        deadline = Time.now + timeout
        sleep 0.25 until moved_from?(start) || Time.now > deadline
        moved_from?(start)
      end

      # Where we are, as the server reports it. XMLData.room_id is set for an
      # unmapped room too - Room.current is nil there, and a map id would
      # compare nil to nil and call a real move a failure - so it is the
      # primary mark. It is never absent (xmlparser defaults it to 0 and every
      # write goes through to_i), but it is not always unique: a room with no
      # UID gets an MD5 of its title, description and exits, so two unmapped
      # rooms whose text reads the same share an id. The room counter, which
      # steps once per room stream, breaks that tie.
      # @api private
      def self.here = { id: XMLData.room_id.to_s, count: XMLData.room_count.to_i }

      # A move is a different server room id. When the id is unchanged it may
      # still be a move between two same-text unmapped rooms, so the counter
      # decides: an MD5 id means the room has no UID, and a counter that has
      # stepped there is a new room stream rather than a refresh of this one.
      # A real UID is unique, so an unchanged one is never a move.
      # @api private
      def self.moved_from?(start)
        now = here
        return true if now[:id] != start[:id]
        return false unless uidless?(now[:id])

        now[:count] > start[:count]
      end

      # A server room id that is not a real room UID: xmlparser substitutes an
      # MD5 of the room text, far above any UID, when <nav> carries none.
      # @api private
      def self.uidless?(id)
        id.to_i > MAX_ROOM_UID
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
