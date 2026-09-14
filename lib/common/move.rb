# frozen_string_literal: true

module Lich
  module Common
    # Support for the top-level +move+ primitive (lib/global_defs.rb): the
    # retry budgets that keep its "fix the obstacle and re-send" branches
    # from looping forever, and a record of why the last move failed that
    # callers can act on without re-parsing game text.
    #
    # move's return value is unchanged and still tri-state: true (moved),
    # false (the exit is wrong - callers may drop it from the map), nil
    # (blocked for now - keep the exit). What is new is {last_failure}: after
    # a false or nil return it names the direction sent, the game line that
    # ended the attempt, and a small +cause+ symbol chosen from {CAUSES} so a
    # supervising script can switch on it instead of matching text:
    #
    #   :injured     too wounded to do it (agony, too injured to climb, a
    #                stand that keeps failing with limb wounds)
    #   :encumbered  a stand that keeps failing while overburdened
    #   :engaged     in combat and cannot leave
    #   :position    not standing and could not get up
    #   :hidden      must be visible to go that way
    #   :hands       needs empty hands
    #   :closed      a door or gate that would not open
    #   :map         the game does not know this exit from here (bad wayto,
    #                or the character is not where the map thinks)
    #   :denied      an NPC or rule refused entry (guards, tickets, guild)
    #   :climb       the climb kept failing (skill roll; not a wound)
    #   :swim        the swim kept failing
    #   :roundtime   still waiting on roundtime when we gave up
    #   :unknown     none of the above - read +line+
    #
    # When Lich::Common::Events is present the same record is emitted as
    # 'move.failed', payload the frozen Failure, so a supervisor can hear it.
    module Move
      Failure = Struct.new(:dir, :line, :cause, :attempts, keyword_init: true)

      # A remedy that should work first time (stand, unhide, empty hands,
      # retreat, open, stow) is retried this many times before move gives
      # up. Past this, the remedy is not working and no number of repeats
      # will change that.
      MAX_REMEDIES = 3

      # A skill roll (climb, swim) legitimately fails several times before
      # succeeding, so it gets a much longer leash. Past this it is either
      # an unpassable exit for this character or the character is stuck.
      MAX_ROLLS = 20

      # Ordered: the first pattern to match a line wins, so the specific
      # causes sit above the broad "You can't" ones. Every pattern is text
      # move itself already matches, or a line captured in play; nothing is
      # invented here.
      CAUSES = [
        [:injured,    /far too much agony|too injured to be doing/i],
        [:encumbered, /overburdened/i],
        [:engaged,    /engaged|retreat out of combat|while in combat|next to impossible while in combat/i],
        [:hidden,     /remain hidden or invisible|can't be seen|without being seen|no one can see you|can't see you/i],
        [:hands,      /hands were empty|hands full|both hands (?:free|might help)|empty hands/i],
        [:position,   /stand(?:ing)? ?(?:up )?first|must be standing|while (?:sitting|lying down)|from that position|already sitting|should stand up|standing up might help|get up first/i],
        [:closed,     /(?:appears|seems) to be closed|squeeze between the stone doors/i],
        [:denied,     /may not pass|unseen force prevents|aren't allowed to enter|only performers|see your ticket|registered groups|reputation precedes|"Abandoned\."|leave promptly|open to invitees|unable to follow you|check in/i],
        [:map,        /can't go there|can't (?:go|swim) in that direction|could not find what you were referring|what were you referring|where are you trying to go|plan to do that here|can't go to|become impassable|too far away|too far above/i],
        [:roundtime,  /^\.{3}wait \d|^wait \d/i]
      ].freeze

      @last_failure = nil
      @mutex = Mutex.new

      class << self
        # The most recent failed move, or nil after a successful one.
        # @return [Failure, nil]
        def last_failure
          @mutex.synchronize { @last_failure }
        end

        # @param line [String, nil]
        # @return [Symbol] one of the CAUSES keys, or :unknown
        def classify(line)
          return :unknown if line.nil?

          CAUSES.each { |cause, pattern| return cause if line =~ pattern }
          :unknown
        end

        # Why did a stand keep failing? "You struggle, but fail to stand" is
        # the same text for a heavy pack and for leg wounds, so look at the
        # character rather than the line. Falls back to :position.
        # @return [Symbol]
        def stand_failure_cause
          if defined?(XMLData) && XMLData.respond_to?(:encumbrance_text) && XMLData.encumbrance_text.to_s =~ /overburdened/i
            :encumbered
          elsif defined?(Lich::Gemstone::Wounds) && Lich::Gemstone::Wounds.respond_to?(:limbs) && limb_wounds? && Lich::Gemstone::Wounds.limbs.to_i > 0
            :injured
          else
            :position
          end
        rescue StandardError
          :position
        end

        # Record (and announce) a failed move. Called by move on every false
        # or nil return; +cause+ defaults to classifying the line.
        #
        # @param dir [String] the direction as last sent
        # @param line [String, nil] the game line that ended the attempt
        # @param cause [Symbol, nil]
        # @param attempts [Integer] how many times the direction was sent
        # @return [Failure] the frozen record
        def record_failure(dir, line, cause: nil, attempts: 1)
          failure = Failure.new(dir: dir.to_s.dup, line: line&.to_s&.dup, cause: (cause || classify(line)), attempts: attempts).freeze
          @mutex.synchronize { @last_failure = failure }
          if defined?(Lich::Common::Events)
            begin
              Lich::Common::Events.emit('move.failed', failure)
            rescue StandardError => e
              Lich.log("move: Events.emit failed: #{e.class}: #{e.message}") if defined?(Lich) && Lich.respond_to?(:log)
            end
          end
          failure
        end

        # Forget the last failure (move calls this on success).
        # @return [void]
        def clear_failure
          @mutex.synchronize { @last_failure = nil }
        end

        private

        # Wounds.limbs reads XMLData.injuries; only ask when that hash is there.
        def limb_wounds?
          defined?(XMLData) && XMLData.respond_to?(:injuries) && XMLData.injuries.is_a?(Hash) && !XMLData.injuries.empty?
        end
      end
    end
  end
end
