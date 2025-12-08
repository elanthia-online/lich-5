module Lich
  module DragonRealms
    module DRCS
      module_function

      def summon_weapon(moon = nil, element = nil, ingot = nil, skill = nil)
        if DRStats.moon_mage?
          DRCMM.hold_moon_weapon?
        elsif DRStats.warrior_mage?
          get_ingot(ingot, true)
          case DRC.bput("summon weapon #{element} #{skill}", 'You lack the elemental charge', 'you draw out')
          when 'You lack the elemental charge'
            summon_admittance
            summon_weapon(moon, element, nil, skill)
          end
          stow_ingot(ingot)
        else
          echo "Unable to summon weapons as a #{DRStats.guild}"
        end
        pause 1
        waitrt?
        DRC.fix_standing
      end

      def get_ingot(ingot, swap)
        return unless ingot

        DRC.bput("get my #{ingot} ingot", 'You get')
        DRC.bput('swap', 'You move') if swap
      end

      def stow_ingot(ingot)
        return unless ingot

        DRC.bput("stow my #{ingot} ingot", 'You put')
      end

      def break_summoned_weapon(item)
        return if item.nil?

        DRC.bput("break my #{item}", 'Focusing your will', 'disrupting its matrix', "You can't break", "Break what")
      end

      def shape_summoned_weapon(skill, ingot = nil)
        weapon_to_summon = identify_summoned_weapon
        if DRStats.moon_mage?
          skill_to_shape = { 'Staves' => 'blunt', 'Twohanded Edged' => 'huge', 'Large Edged' => 'heavy', 'Small Edged' => 'normal' }
          shape = skill_to_shape[skill]
          if DRCMM.hold_moon_weapon?
            DRC.bput("shape #{weapon_to_summon} to #{shape}", 'you adjust the magic that defines its shape', 'already has', 'You fumble around')
          end
        elsif DRStats.warrior_mage?
          shape_failures = ['You lack the elemental charge', 'You reach out', 'You fumble around', "You don't know how to manipulate your weapon in that way"]
          get_ingot(ingot, false)
          case DRC.bput("shape my #{weapon_to_summon} to #{skill}", shape_failures << 'What type of weapon were you trying')
          when 'You lack the elemental charge'
            summon_admittance
            shape_summoned_weapon(skill, nil)
          when 'What type of weapon were you trying'
            # currently custom adjectives from https://elanthipedia.play.net/Books_of_Binding tomes
            # aren't recognized for shaping summoned elemental weapons, and the error message itself is misleading
            # thankfully breaking, turning, pulling, pushing work fine with custom adj
            case DRC.bput("shape my #{weapon_to_summon.split(' ').last} to #{skill}", shape_failures)
            when 'You lack the elemental charge'
              summon_admittance
              shape_summoned_weapon(skill, nil)
            end
          end
          stow_ingot(ingot)
        else
          echo "Unable to shape weapons as a #{DRStats.guild}"
        end
        pause 1
        waitrt?
      end

      # Returns what kind of summoned weapon you're holding.
      # Will be the <adj> <noun> like 'red-hot moonblade' or 'electric sword.
      def identify_summoned_weapon(settings = nil)
        if DRStats.moon_mage?
          return DRC.right_hand if DRCMM.is_moon_weapon?(DRC.right_hand)
          return DRC.left_hand  if DRCMM.is_moon_weapon?(DRC.left_hand)
        elsif DRStats.warrior_mage?
          # match = DRC.bput("#{command} #{abbrev} #{mana}", get_data('spells').prep_messages)
          weapon_regex = /^You tap (?:a|an|some)(?:[\w\s\-]+)((#{settings&.summoned_weapons_adjective}|stone|fiery|icy|electric) [\w\s\-]+) that you are holding.$/
          # For a two-worded weapon like 'short sword' the only way to know
          # which element it was summoned with is by tapping it. That's the only
          # way we can infer if it's a summoned sword or a regular one.
          # However, the <adj> <noun> of the item we return must be what's in
          # their hands, not what the regex matches in the tap.
          return DRC.right_hand if DRCI.tap(DRC.right_hand) =~ weapon_regex
          return DRC.left_hand if DRCI.tap(DRC.left_hand) =~ weapon_regex
        else
          echo "Unable to summon weapons as a #{DRStats.guild}"
        end
      end

      def turn_summoned_weapon
        case DRC.bput("turn my #{GameObj.right_hand.noun}", 'You lack the elemental charge', 'You reach out')
        when 'You lack the elemental charge'
          summon_admittance
          turn_summoned_weapon
        end
        pause 1
        waitrt?
      end

      def push_summoned_weapon
        case DRC.bput("push my #{GameObj.right_hand.noun}", 'You lack the elemental charge', 'Closing your eyes', 'That\'s as')
        when 'You lack the elemental charge'
          summon_admittance
          push_summoned_weapon
        end
        pause 1
        waitrt?
      end

      def pull_summoned_weapon
        case DRC.bput("pull my #{GameObj.right_hand.noun}", 'You lack the elemental charge', 'Closing your eyes', 'That\'s as')
        when 'You lack the elemental charge'
          summon_admittance
          pull_summoned_weapon
        end
        pause 1
        waitrt?
      end

      def summon_admittance
        case DRC.bput('summon admittance', 'You align yourself to it', 'further increasing your proximity', 'Going any further while in this plane would be fatal', 'Summon allows Warrior Mages to draw', 'You are a bit too distracted')
        when 'You are a bit too distracted'
          DRC.retreat
          summon_admittance
        end
        pause 1
        waitrt?
        DRC.fix_standing
      end
    end
  end
end
