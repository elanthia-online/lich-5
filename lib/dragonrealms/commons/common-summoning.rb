# frozen_string_literal: true

module Lich
  module DragonRealms
    module DRCS
      module_function

      # Shared response for elemental charge depletion
      LACK_CHARGE = 'You lack the elemental charge'.freeze

      SUMMON_WEAPON_RESPONSES = [
        LACK_CHARGE,
        'you draw out'
      ].freeze

      BREAK_WEAPON_RESPONSES = [
        'Focusing your will',
        'disrupting its matrix',
        "You can't break",
        'Break what'
      ].freeze

      # Moon Mage skill-to-shape mapping for moonblades/staves
      MOON_SKILL_TO_SHAPE = {
        'Staves'          => 'blunt',
        'Twohanded Edged' => 'huge',
        'Large Edged'     => 'heavy',
        'Small Edged'     => 'normal'
      }.freeze

      MOON_SHAPE_RESPONSES = [
        'you adjust the magic that defines its shape',
        'already has',
        'You fumble around'
      ].freeze

      WM_SHAPE_FAILURES = [
        LACK_CHARGE,
        'You reach out',
        'You fumble around',
        "You don't know how to manipulate your weapon in that way"
      ].freeze

      TURN_WEAPON_RESPONSES = [LACK_CHARGE, 'You reach out'].freeze
      PUSH_WEAPON_RESPONSES = [LACK_CHARGE, 'Closing your eyes', "That's as"].freeze
      PULL_WEAPON_RESPONSES = [LACK_CHARGE, 'Closing your eyes', "That's as"].freeze

      SUMMON_ADMITTANCE_RESPONSES = [
        'You align yourself to it',
        'further increasing your proximity',
        'Going any further while in this plane would be fatal',
        'Summon allows Warrior Mages to draw',
        'You are a bit too distracted'
      ].freeze

      # Default element adjectives for Warrior Mage summoned weapons
      WM_ELEMENT_ADJECTIVES = %w[stone fiery icy electric].freeze

      def summon_weapon(_moon = nil, element = nil, ingot = nil, skill = nil)
        if DRStats.moon_mage?
          DRCMM.hold_moon_weapon?
        elsif DRStats.warrior_mage?
          return unless get_ingot(ingot, true)

          result = DRC.bput("summon weapon #{element} #{skill}", *SUMMON_WEAPON_RESPONSES)
          if result == LACK_CHARGE
            summon_admittance
            DRC.bput("summon weapon #{element} #{skill}", *SUMMON_WEAPON_RESPONSES)
          end
          stow_ingot(ingot)
        else
          Lich::Messaging.msg("bold", "DRCS: Unable to summon weapons as a #{DRStats.guild}")
        end
        pause 1
        waitrt?
        DRC.fix_standing
      end

      def get_ingot(ingot, swap)
        return true unless ingot

        unless DRCI.get_item?("#{ingot} ingot")
          Lich::Messaging.msg("bold", "DRCS: Could not get #{ingot} ingot")
          return false
        end
        DRC.bput('swap', 'You move') if swap
        true
      end

      def stow_ingot(ingot)
        return true unless ingot

        unless DRCI.put_away_item?("#{ingot} ingot")
          Lich::Messaging.msg("bold", "DRCS: Could not stow #{ingot} ingot")
          return false
        end
        true
      end

      def break_summoned_weapon(item)
        return if item.nil?

        DRC.bput("break my #{item}", *BREAK_WEAPON_RESPONSES)
      end

      def shape_summoned_weapon(skill, ingot = nil, settings = nil)
        summoned_weapon = identify_summoned_weapon(settings)
        if DRStats.moon_mage?
          shape = MOON_SKILL_TO_SHAPE[skill]
          if DRCMM.hold_moon_weapon?
            DRC.bput("shape #{summoned_weapon} to #{shape}", *MOON_SHAPE_RESPONSES)
          end
        elsif DRStats.warrior_mage?
          return unless get_ingot(ingot, false)

          result = DRC.bput("shape my #{summoned_weapon} to #{skill}", *(WM_SHAPE_FAILURES + ['What type of weapon were you trying']))
          case result
          when LACK_CHARGE
            summon_admittance
            DRC.bput("shape my #{summoned_weapon} to #{skill}", *WM_SHAPE_FAILURES)
          when 'What type of weapon were you trying'
            # Custom adjectives from https://elanthipedia.play.net/Books_of_Binding tomes
            # aren't recognized for shaping summoned elemental weapons, and the error message
            # itself is misleading. Breaking, turning, pulling, pushing work fine with custom adj.
            unless summoned_weapon.nil?
              adj = settings&.summoned_weapons_adjective || ''
              retry_result = DRC.bput("shape my #{summoned_weapon.sub(adj, '')} to #{skill}", *WM_SHAPE_FAILURES)
              if retry_result == LACK_CHARGE
                summon_admittance
                DRC.bput("shape my #{summoned_weapon.sub(adj, '')} to #{skill}", *WM_SHAPE_FAILURES)
              end
            end
          end
          stow_ingot(ingot)
        else
          Lich::Messaging.msg("bold", "DRCS: Unable to shape weapons as a #{DRStats.guild}")
        end
        pause 1
        waitrt?
      end

      # Returns what kind of summoned weapon you're holding.
      # Will be the <adj> <noun> like 'red-hot moonblade' or 'electric sword'.
      def identify_summoned_weapon(settings = nil)
        if DRStats.moon_mage?
          return DRC.right_hand if DRCMM.is_moon_weapon?(DRC.right_hand)
          return DRC.left_hand  if DRCMM.is_moon_weapon?(DRC.left_hand)
        elsif DRStats.warrior_mage?
          custom_adjective = settings&.summoned_weapons_adjective ? "#{settings.summoned_weapons_adjective}|" : ''
          adjectives = WM_ELEMENT_ADJECTIVES.join('|')
          weapon_regex = /^You tap (?:a|an|some)(?:[\w\s\-]+)(?:(?:#{custom_adjective}#{adjectives}) [\w\s\-]+) that you are holding\.$/
          # For a two-worded weapon like 'short sword' the only way to know
          # which element it was summoned with is by tapping it. That's the only
          # way we can infer if it's a summoned sword or a regular one.
          # However, the <adj> <noun> of the item we return must be what's in
          # their hands, not what the regex matches in the tap.
          return DRC.right_hand if weapon_regex.match?(DRCI.tap(DRC.right_hand).to_s)
          return DRC.left_hand if weapon_regex.match?(DRCI.tap(DRC.left_hand).to_s)
        else
          Lich::Messaging.msg("bold", "DRCS: Unable to identify summoned weapons as a #{DRStats.guild}")
        end
      end

      def turn_summoned_weapon
        result = DRC.bput("turn my #{DRC.right_hand_noun}", *TURN_WEAPON_RESPONSES)
        if result == LACK_CHARGE
          summon_admittance
          DRC.bput("turn my #{DRC.right_hand_noun}", *TURN_WEAPON_RESPONSES)
        end
        pause 1
        waitrt?
      end

      def push_summoned_weapon
        result = DRC.bput("push my #{DRC.right_hand_noun}", *PUSH_WEAPON_RESPONSES)
        if result == LACK_CHARGE
          summon_admittance
          DRC.bput("push my #{DRC.right_hand_noun}", *PUSH_WEAPON_RESPONSES)
        end
        pause 1
        waitrt?
      end

      def pull_summoned_weapon
        result = DRC.bput("pull my #{DRC.right_hand_noun}", *PULL_WEAPON_RESPONSES)
        if result == LACK_CHARGE
          summon_admittance
          DRC.bput("pull my #{DRC.right_hand_noun}", *PULL_WEAPON_RESPONSES)
        end
        pause 1
        waitrt?
      end

      def summon_admittance
        loop do
          result = DRC.bput('summon admittance', *SUMMON_ADMITTANCE_RESPONSES)
          if result == 'You are a bit too distracted'
            DRC.retreat
            next
          end
          break
        end
        pause 1
        waitrt?
        DRC.fix_standing
      end
    end
  end
end
