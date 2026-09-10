# frozen_string_literal: true

# Stance: read and set the character's combat stance.
#
# Lich has always been able to read stance (Char.stance, Char.percent_stance)
# but every script that needs to set one carries its own copy of the same
# send-and-confirm sequence. Spell#cast had one, bigshot has one, ebounty,
# eloot and ecleanse each have one. This module is that sequence, once.
#
#   Stance.change('defensive')            # send, wait for the game to confirm
#   Stance.change(:off)                   # prefixes and symbols are fine
#   Stance.change(80)                     # perfect stance when Stance Perfection is known,
#                                         # otherwise the band it falls in (guarded)
#   Stance.change('guarded', wait: false) # fire and forget through fput
#   Stance.change('offensive', force: true) # send even if already offensive
#   Stance.safest                         # 'guarded' during cast roundtime, else 'defensive'
#
# change returns true when the character is in the requested stance (or already
# was), false when the game refused (cast roundtime, unable to change, dead) or
# no confirmation arrived within the timeout. An unrecognised stance raises
# ArgumentError; that is a caller bug, not a game state.
module Lich
  module Gemstone
    module Stance
      NAMES = %w[offensive advance forward neutral guarded defensive].freeze

      # Percent-of-defense band each named stance occupies. The game reports
      # stance_value as a 0..100 number; checkstance has always used these
      # ranges to decide which name a value belongs to.
      BANDS = {
        'offensive' => (0..0),
        'advance'   => (1..20),
        'forward'   => (21..40),
        'neutral'   => (41..60),
        'guarded'   => (61..80),
        'defensive' => (81..100),
      }.freeze

      # Every line the game can answer a stance change with. Shared with
      # Spell#cast, which used to carry its own copy.
      CONFIRM = Regexp.union(
        /^You (?:are now in|move into) an? \w+ stance/,
        /^You fall back into an? \w+ stance/,
        /^You are unable to change your stance\./,
        /^Cast Roundtime in effect/,
      ).freeze

      REFUSED = /^You are unable to change your stance\.|^Cast Roundtime in effect/.freeze

      DEFAULT_TIMEOUT = 3

      # @return [String] current stance name as the game reports it
      def self.current
        Char.stance
      end

      # @return [Integer] current stance as a 0..100 percentage
      def self.value
        Char.percent_stance
      end

      # @return [Boolean] whether Stance Perfection (cman stance N) is trained
      def self.perfection?
        return false unless defined?(Lich::Gemstone::CMan)
        Lich::Gemstone::CMan.known?('stance_perfection')
      rescue StandardError
        false
      end

      # The stance to fall back to when the caller just wants to be safe:
      # defensive, unless a cast roundtime is running, in which case the game
      # will not allow defensive and guarded is the best available.
      #
      # @return [String]
      def self.safest
        checkcastrt > 0 ? 'guarded' : 'defensive'
      end

      # Resolve anything a script might hand us into [name, percent].
      #
      # @param target [String, Symbol, Integer] a stance name, a prefix
      #   (off/adv/for/neu/gua/def), or a multiple of ten from 0 to 100
      # @return [Array(String, Integer|nil)] the band name and, for numeric
      #   targets, the exact percent requested
      # @raise [ArgumentError] when target is not a stance
      def self.normalize(target)
        case target
        when Integer
          normalize_percent(target)
        when Symbol
          normalize(target.to_s)
        when String
          stripped = target.strip.downcase
          return normalize_percent(stripped.to_i) if stripped =~ /\A\d+\z/
          name = NAMES.find { |n| n.start_with?(stripped[0, 3]) } if stripped.length >= 3
          raise ArgumentError, "Stance: unknown stance #{target.inspect}" if name.nil?
          [name, nil]
        else
          raise ArgumentError, "Stance: unknown stance #{target.inspect}"
        end
      end

      # @return [Boolean] whether the character is already in the target stance
      def self.at?(target)
        name, percent = normalize(target)
        return value == percent unless percent.nil?
        current.to_s.downcase == name
      end

      # Change stance and, by default, wait for the game to confirm.
      #
      # @param target [String, Symbol, Integer] see normalize
      # @param wait [Boolean] wait for CONFIRM (true) or fire through fput (false)
      # @param force [Boolean] send even when already in the target stance
      # @param timeout [Numeric] seconds to wait for confirmation
      # @return [Boolean] true when in the requested stance, false when the game
      #   refused, no confirmation arrived, or the character is dead
      def self.change(target, wait: true, force: false, timeout: DEFAULT_TIMEOUT)
        name, percent = normalize(target)
        return false if Status.dead?
        return true if !force && at?(target)

        command = if percent && perfection?
                    "cman stance #{percent}"
                  else
                    "stance #{name}"
                  end

        unless wait
          fput command
          return true
        end

        waitrt?
        result = dothistimeout(command, timeout, CONFIRM)
        return false if result.nil?
        return false if result =~ REFUSED
        true
      end

      # @param percent [Integer]
      # @return [Array(String, Integer)]
      def self.normalize_percent(percent)
        unless percent.is_a?(Integer) && percent.between?(0, 100) && (percent % 10).zero?
          raise ArgumentError, "Stance: percent must be a multiple of ten from 0 to 100, got #{percent.inspect}"
        end
        name = BANDS.find { |_n, range| range.cover?(percent) }.first
        [name, percent]
      end
      private_class_method :normalize_percent
    end
  end
end
