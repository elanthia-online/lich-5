# frozen_string_literal: true

# Common item manipulation operations for DragonRealms.
#
# DRCI provides low-level, stateless methods for interacting with items
# in the game world: getting, putting, wearing, removing, counting,
# searching, and querying hand contents.
#
# This module should be "bottom-level" and only depend on common (DRC).
# Any modules that deal with items and something else (e.g., crafting,
# combat) should live in a separate module.
#
# ## Method Categories
#
# - **Retrieval**: {.get_item?}, {.get_item_if_not_held?}, {.get_item_safe?}
# - **Storage**: {.put_away_item?}, {.stow_item?}, {.stow_hands}
# - **Wearing**: {.wear_item?}, {.remove_item?}
# - **Tying**: {.tie_item?}, {.untie_item?}
# - **Queries**: {.in_hands?}, {.in_left_hand?}, {.in_right_hand?}, {.in_hand?}
# - **Existence**: {.exists?}, {.wearing?}, {.inside?}, {.search?}
# - **Counting**: {.count_items}, {.count_item_parts}, {.count_items_in_container}
# - **Containers**: {.open_container?}, {.close_container?}, {.look_in_container}, {.rummage_container}
# - **Trash**: {.dispose_trash}
# - **Transfer**: {.give_item?}, {.accept_item?}
# - **Gem Pouches**: {.fill_gem_pouch_with_container}, {.swap_out_full_gempouch?}
#
# @see DRC Core common module
# @see EquipmentManager Higher-level gear management

module Lich
  module DragonRealms
    module DRCI
      module_function

      # Prepends "my " to an item or container name for ownership qualification.
      #
      # Skips the prefix when the value is nil, already starts with "my ",
      # or uses item ID syntax (starts with "#").
      #
      # @param value [String, nil] item or container noun
      # @return [String, nil] qualified name, or nil if value was nil
      #
      # @example
      #   DRCI.item_ref("sword")       #=> "my sword"
      #   DRCI.item_ref("my sword")    #=> "my sword"
      #   DRCI.item_ref("#12345")       #=> "#12345"
      #   DRCI.item_ref(nil)            #=> nil
      def item_ref(value)
        return value if value.nil? || value =~ /^(my |#)/i

        "my #{value}"
      end

      ## How to add new trash receptacles https://github.com/elanthia-online/dr-scripts/wiki/Adding-new-trash-receptacles
      TRASH_STORAGE = %w[arms barrel basin basket bin birdbath bucket chamberpot gloop hole log puddle statue stump tangle tree turtle urn gelapod].freeze

      DROP_TRASH_SUCCESS_PATTERNS = [
        /^You drop/,
        /^You put/,
        /^You spread .* on the ground/,
        /smashing it to bits/,
        # The next message is when item crumbles when leaves your hand, like a moonblade.
        /^As you open your hand to release the/,
        /^You toss .* at the domesticated gelapod/,
        /^You feed .* a bit warily to the domesticated gelapod/
      ].freeze

      DROP_TRASH_FAILURE_PATTERNS = [
        /^What were you referring to/,
        /^I could not find/,
        /^But you aren't holding that/,
        /^Perhaps you should be holding that first/,
        /^You're kidding, right/,
        /^You can't do that/,
        /No littering/, # A guard steps over to you and says, "No littering in the bank."
        /^Where do you want to put that/,
        /^You really shouldn't be loitering/,
        /^You don't seem to be able to move/,
        # You may get the next message if you've been cursed and unable to let go of items.
        # Find a Cleric to uncurse you.
        /^Oddly, when you attempt to stash it away safely/,
        /^You need something in your right hand/,
        /^You can't put that there/,
        /^The domesticated gelapod glances warily at/, # deeds
        /^You should empty it out, first./ # container with items
      ].freeze

      # Messages that when trying to drop an item you're warned.
      # To continue you must retry the command.
      DROP_TRASH_RETRY_PATTERNS = [
        # You may get the next message if the item would be damaged upon dropping.
        /^If you still wish to drop it/,
        /would damage it/,
        # You may get the next messages when an outdated item is updated upon use.
        # "Something appears different about the <item>, perhaps try doing that again."
        # Example: https://elanthipedia.play.net/Item:Leather_lotion
        /^Something appears different about/,
        /perhaps try doing that again/
      ].freeze

      WORN_TRASHCAN_VERB_PATTERNS = [
        /^You drum your fingers/,
        /^You pull a lever/,
        /^You poke your finger around/
      ].freeze

      GET_ITEM_SUCCESS_PATTERNS = [
        /you draw (?!\w+'s wounds)/i,
        /^You get/,
        /^You pick/,
        /^You pluck/,
        /^You slip/,
        /^You scoop/,
        /^You deftly remove/,
        /^You are already holding/,
        /^You fade in for a moment as you/,
        /^You carefully lift/,
        /^You carefully remove .* from the bundle/,
        /^With a flick of your wrist, you stealthily unsheath/
      ].freeze

      GET_ITEM_FAILURE_PATTERNS = [
        /^A magical force keeps you from grasping/,
        /^You'll need both hands free/,
        /^You need both hands free/,
        /^You need a free hand/,
        /^You can't pick that up with your hand that damaged/,
        /^Your (left|right) hand is too injured/,
        /^You just can't/,
        /^You stop as you realize the .* is not yours/,
        /^You can't reach that from here/, # on a mount like a flying carpet
        /^You don't seem to be able to move/,
        /^You should untie/,
        /^You can't do that/,
        /^Get what/,
        /^I could not/,
        /^What were you/,
        /already in your inventory/, # wearing it
        /needs to be tended to be removed/, # ammo lodged in you
        /push you over the item limit/, # you're at item capacity
        /rapidly decays away/, # item disappears when try to get it
        /cracks and rots away/, # item disappears when try to get it
        /^You should stop practicing your Athletics skill before you do that/
      ].freeze

      WEAR_ITEM_SUCCESS_PATTERNS = [
        /^You put/,
        /^You pull/,
        /^You sling/,
        /^You attach/,
        /^You strap/,
        /^You slide/,
        /^You spin/,
        /^You slip/,
        /^You place/,
        /^You hang/,
        /^You tug/,
        /^You struggle/,
        /^You squeeze/,
        /^You manage/,
        /^You gently place/,
        /^You toss one strap/,
        /^You carefully loop/,
        /^You work your way into/,
        /^You are already wearing/,
        /^Gritting your teeth, you grip/,
        /^You expertly sling the/,
        /put it on/, # weird clerical collar thing, trying to make it a bit generic
        /slide effortlessly onto your/,
        /^You carefully arrange/,
        /^A brisk chill rushes through you as you wear/, # some hiro bearskin gloves interlaced with strips of ice-veined leather
        /^You drape/,
        /You lean over and slip your feet into the boots./, # a pair of weathered barkcloth boots lined in flannel,
        /^You reach down and step into/, # pair of enaada boots clasped by asharsh'dai
        /Gritting your teeth/ # Gritting your teeth, you grip each of your heavy combat boots in turn by the straps, and drive your feet into them for a secure fit.
      ].freeze

      WEAR_ITEM_FAILURE_PATTERNS = [
        /^You can't wear/,
        /^You (need to|should) unload/,
        /close the fan/,
        /^You don't seem to be able to move/,
        /^Wear what/,
        /^I could not/,
        /^What were you/
      ].freeze

      TIE_ITEM_SUCCESS_PATTERNS = [
        /^You .*tie/,
        /^You attach/,
        /has already been tied off/,
        /Tie it off when it's empty\?/
      ].freeze

      TIE_ITEM_FAILURE_PATTERNS = [
        /^There's no more free ties/,
        /^Tie what/,
        /^You are a little too busy/,
        /^You don't seem to be able to move/,
        /^You must be holding/,
        /^Your wounds hinder your ability to do that/,
        /close the fan/,
        /doesn't seem to fit/
      ].freeze

      UNTIE_ITEM_SUCCESS_PATTERNS = [
        /^You remove/,
        /You untie/i
      ].freeze

      UNTIE_ITEM_FAILURE_PATTERNS = [
        /^You don't seem to be able to move/,
        /^You fumble with the ties/,
        /^Untie what/,
        /^What were you referring/
      ].freeze

      REMOVE_ITEM_SUCCESS_PATTERNS = [
        /^Dropping your shoulder/,
        /^The .* slide/,
        /^Without any effort/,
        /^You .* slide/,
        /^You detach/,
        /^You loosen/,
        /^You pull/,
        /^You.*remove/,
        /^You slide/,
        /^You sling/,
        /^You slip/,
        /^You struggle/,
        /^You take/,
        /you tug/i,
        /^You untie/,
        /as you remove/,
        /slide themselves off of your/,
        /you manage to loosen/,
        /you unlace/,
        /^You slam the heels/,
        /^You work your way out/,
        /^With masterful grace, you ready/
      ].freeze

      REMOVE_ITEM_FAILURE_PATTERNS = [
        /^You'll need both hands free/,
        /^You need a free hand/,
        /^You aren't wearing/,
        /^You don't seem to be able to move/,
        /^Remove what/,
        /^I could not/,
        /^Grunting with momentary exertion/, # Grunting with momentary exertion, you grip each of your heavy combat boots in turn by the heel, and pull them off.
        /^What were you/
      ].freeze

      # Success patterns for the SHEATH verb.
      #
      # Matches game output when a weapon is successfully sheathed into
      # a scabbard, sheath, or harness. Also splatted into
      # {PUT_AWAY_ITEM_SUCCESS_PATTERNS} because STOW can trigger
      # sheath responses when the default storage is a sheath.
      #
      # @example Matches
      #   "Sheathing your sword, you put it away."
      #   "You sheath your sword in your scabbard."
      #   "With fluid and stealthy movements you slip the sabre into your harness."
      #
      # @see SHEATH_ITEM_FAILURE_PATTERNS
      SHEATH_ITEM_SUCCESS_PATTERNS = [
        /^Sheathing/,
        /^You sheath/,
        /^You secure your/,
        /^You slip/,
        /^You hang/,
        /^You (easily )?strap/,
        /^With a flick of your wrist,? you stealthily sheath/,
        /^With fluid and stealthy movements you slip/,
        /^The .* slides easily/
      ].freeze

      # Failure patterns for the SHEATH verb.
      #
      # @example Matches
      #   "Sheath your sword where?"
      #   "There's no room for that."
      #
      # @see SHEATH_ITEM_SUCCESS_PATTERNS
      SHEATH_ITEM_FAILURE_PATTERNS = [
        /^Sheath your .* where/,
        /^There's no room/,
        /is too small to hold that/,
        /is too wide to fit/,
        /^Your (left|right) hand is too injured/
      ].freeze

      # Success patterns for putting an item away via PUT or STOW.
      #
      # Includes {SHEATH_ITEM_SUCCESS_PATTERNS} because STOW can trigger
      # sheath responses when the default storage is a sheath/harness.
      #
      # @see PUT_AWAY_ITEM_FAILURE_PATTERNS
      # @see SHEATH_ITEM_SUCCESS_PATTERNS
      PUT_AWAY_ITEM_SUCCESS_PATTERNS = [
        /^You put your .* in/,
        /^You hold out/,
        /^You stuff/,
        /^You tuck/,
        /^You open your pouch and put/,
        /^You guide your/i, # puppy storage
        /^You nudge your/i, # monkey storage
        # The next message is when item crumbles when stowed, like a moonblade.
        /^As you open your hand to release the/,
        # You're a thief and you binned a stolen item.
        /nods toward you as your .* falls into the .* bin/,
        /^You add/,
        /^You rearrange/,
        /^You combine the stacks/,
        /^You secure/,
        # The following are success messages for putting an item in a container OFF your person.
        /^You drop/i,
        /^You set/i,
        /^You put/i,
        /^You carefully fit .* into your bundle/,
        /^You gently set/,
        # Sheath patterns included because STOW can trigger sheath responses.
        *SHEATH_ITEM_SUCCESS_PATTERNS,
        /^You toss .* into/ # You toss the alcohol into the bowl and mix it in thoroughly
      ].freeze

      PUT_AWAY_ITEM_FAILURE_PATTERNS = [
        /^Stow what/,
        /^I can't find your container for stowing things in/,
        /^Please rephrase that command/,
        /^What were you referring to/,
        /^I could not find what you were referring to/,
        /^There isn't any more room in/,
        /^There's no room/,
        /^(The|That).* too heavy to go in there/,
        /^You (need to|should) unload/,
        /^You can't do that/,
        /^You just can't get/,
        /^You can't put items/,
        /^You can only take items out/,
        /^You don't seem to be able to move/,
        /^Perhaps you should be holding that first/,
        /^Containers can't be placed in/,
        /^The .* is not designed to carry anything/,
        /^You can't put that.*there/,
        /^Weirdly, you can't manage .* to fit/,
        /^\[Containers can't be placed in/,
        /even after stuffing it/,
        /is too .* to (fit|hold)/,
        /no matter how you arrange it/,
        /close the fan/,
        /to fit in the/,
        /doesn't seem to want to leave you/, # trying to put a pet in a home within a container
        # You may get the next message if you've been cursed and unable to let go of items.
        # Find a Cleric to uncurse you.
        /Oddly, when you attempt to stash it away safely/,
        /completely full/,
        /That doesn't belong in there!/,
        /exerts a steady force preventing/
      ].freeze

      # Messages that when trying to put away an item you're warned.
      # To continue you must retry the command.
      PUT_AWAY_ITEM_RETRY_PATTERNS = [
        # You may get the next messages when an outdated item is updated upon use.
        # "Something appears different about the <item>, perhaps try doing that again."
        # Example: https://elanthipedia.play.net/Item:Leather_lotion
        /Something appears different about/,
        /perhaps try doing that again/
      ].freeze

      STOW_ITEM_SUCCESS_PATTERNS = [
        *GET_ITEM_SUCCESS_PATTERNS,
        *PUT_AWAY_ITEM_SUCCESS_PATTERNS
      ].freeze

      STOW_ITEM_FAILURE_PATTERNS = [
        *GET_ITEM_FAILURE_PATTERNS,
        *PUT_AWAY_ITEM_FAILURE_PATTERNS
      ].freeze

      STOW_ITEM_RETRY_PATTERNS = [
        *PUT_AWAY_ITEM_RETRY_PATTERNS
      ].freeze

      #########################################
      # WIELD/SHEATH/SWAP/UNLOAD PATTERNS
      #########################################

      # Success patterns for the WIELD verb.
      #
      # Matches game output when a weapon is successfully drawn from
      # a sheath, scabbard, or harness.
      #
      # @example Matches
      #   "You draw your sword from your scabbard."
      #   "You deftly remove a dagger from your thigh sheath."
      #   "With a flick of your wrist, you stealthily unsheath your weapon."
      #
      # @see WIELD_ITEM_FAILURE_PATTERNS
      WIELD_ITEM_SUCCESS_PATTERNS = [
        /you draw (?!\w+'s wounds)/i,
        /^You deftly remove/,
        /^You slip/,
        /^With a flick of your wrist,? you stealthily unsheath/,
        /^With fluid and stealthy movements you draw/,
        /^The .* slides easily out/
      ].freeze

      # Failure patterns for the WIELD verb.
      #
      # @see WIELD_ITEM_SUCCESS_PATTERNS
      WIELD_ITEM_FAILURE_PATTERNS = [
        /^Wield what/,
        /^Your (left|right) hand is too injured/
      ].freeze

      # Success patterns for the SWAP verb (hand swap).
      #
      # Matches game output when items are successfully swapped
      # between left and right hands.
      #
      # @example Matches
      #   "You move a steel sword to your left hand."
      #
      # @see SWAP_HANDS_FAILURE_PATTERNS
      SWAP_HANDS_SUCCESS_PATTERNS = [
        /^You move/
      ].freeze

      # Failure patterns for the SWAP verb (hand swap).
      #
      # @see SWAP_HANDS_SUCCESS_PATTERNS
      SWAP_HANDS_FAILURE_PATTERNS = [
        /^Will alone cannot conquer the paralysis/
      ].freeze

      # Success patterns for the UNLOAD verb.
      #
      # Matches game output when a ranged weapon is successfully unloaded.
      # Includes both visible and hidden unloading messages, as well as
      # the case where ammo falls to the ground (hands full).
      #
      # @example Matches
      #   "You unload the crossbow."
      #   "Your bolt falls from your crossbow to your feet."
      #   "As you release the string, the arrow tumbles to the ground."
      #   "You remain concealed by your surroundings, convinced that your unloading of the crossbow went unobserved."
      #
      # @see UNLOAD_WEAPON_FAILURE_PATTERNS
      UNLOAD_WEAPON_SUCCESS_PATTERNS = [
        /^You unload/,
        /^Your .* fall.*to your feet\.$/,
        /As you release the string/,
        /^You .* unloading/
      ].freeze

      # Failure patterns for the UNLOAD verb.
      #
      # @see UNLOAD_WEAPON_SUCCESS_PATTERNS
      UNLOAD_WEAPON_FAILURE_PATTERNS = [
        /But your .* isn't loaded/,
        /You can't unload such a weapon/,
        /You don't have a ranged weapon to unload/,
        /You must be holding the weapon to do that/
      ].freeze

      RUMMAGE_SUCCESS_PATTERNS = [
        /^You rummage through .* and see (.*)\./,
        /^In the .* you see (.*)\./,
        /there is nothing/i
      ].freeze

      RUMMAGE_FAILURE_PATTERNS = [
        /^You don't seem to be able to move/,
        /^I could not find/,
        /^I don't know what you are referring to/,
        /^What were you referring to/
      ].freeze

      TAP_SUCCESS_PATTERNS = [
        /^You tap\s(?!into).*/, # The `.*` is needed to capture entire phrase. Methods parse it to know if an item is worn, stowed, etc.
        /^You (thump|drum) your finger/, # You tapped an item with fancy verbiage, ohh la la!
        /^As you tap/, # As you tap a large ice-veined leather and flamewood surveyor's case
        /^The orb is delicate/, # You tapped a favor orb
        /^You .* on the shoulder/, # You tapped someone
        /^You suddenly forget what you were doing/ # "tap my tessera" messaging when hands are full
      ].freeze

      TAP_FAILURE_PATTERNS = [
        /^You don't seem to be able to move/,
        /^I could not find/,
        /^I don't know what you are referring to/,
        /^What were you referring to/
      ].freeze

      OPEN_CONTAINER_SUCCESS_PATTERNS = [
        /^You open/,
        /^You slowly open/,
        /^The .* opens/,
        /^You unbutton/,
        /(It's|is) already open/,
        /^You spread your arms, carefully holding your bag well away from your body/
      ].freeze

      OPEN_CONTAINER_FAILURE_PATTERNS = [
        /^Please rephrase that command/,
        /^What were you referring to/,
        /^I could not find what you were referring to/,
        /^You don't want to ruin your spell just for that do you/,
        /^It would be a shame to disturb the silence of this place for that/,
        /^This is probably not the time nor place for that/,
        /^You don't seem to be able to move/,
        /^There is no way to do that/,
        /^You can't do that/,
        /^Open what/
      ].freeze

      CLOSE_CONTAINER_SUCCESS_PATTERNS = [
        /^You close/,
        /^You quickly close/,
        /^You pull/,
        /is already closed/
      ].freeze

      CLOSE_CONTAINER_FAILURE_PATTERNS = [
        /^Please rephrase that command/,
        /^What were you referring to/,
        /^I could not find what you were referring to/,
        /^You don't want to ruin your spell just for that do you/,
        /^It would be a shame to disturb the silence of this place for that/,
        /^This is probably not the time nor place for that/,
        /^You don't seem to be able to move/,
        /^There is no way to do that/,
        /^You can't do that/
      ].freeze

      CONTAINER_IS_CLOSED_PATTERNS = [
        /^But that's closed/,
        /^That is closed/,
        /^While it's closed/
      ].freeze

      LOWER_SUCCESS_PATTERNS = [
        /^You lower/,
        # The next message is when item crumbles when leaves your hand, like a moonblade.
        /^As you open your hand to release the/
      ].freeze

      LOWER_FAILURE_PATTERNS = [
        /^You don't seem to be able to move/,
        /^But you aren't holding anything/,
        /^Please rephrase that command/,
        /^What were you referring to/,
        /^I could not find what you were referring to/
      ].freeze

      LIFT_SUCCESS_PATTERNS = [
        /^You pick up/
      ].freeze

      LIFT_FAILURE_PATTERNS = [
        /^There are no items lying at your feet/,
        /^What did you want to try and lift/,
        /can't quite lift it/,
        /^You are not strong enough to pick that up/
      ].freeze

      GIVE_ITEM_SUCCESS_PATTERNS = [
        /has accepted your offer/,
        /your ticket and are handed back/,
        /Please don't lose this ticket!/,
        /^You hand .* gives you back a repair ticket/,
        /^You hand .* your ticket and are handed back/
      ].freeze

      GIVE_ITEM_FAILURE_PATTERNS = [
        /I don't repair those here/,
        /There isn't a scratch on that/,
        /give me a few more moments/,
        /I will not repair something that isn't broken/,
        /I can't fix those/,
        /has declined the offer/,
        /^Your offer to .* has expired/,
        /^You may only have one outstanding offer at a time/,
        /^What is it you're trying to give/,
        /Lucky for you!  That isn't damaged!/
      ].freeze

      #########################################
      # GEM POUCH FILL PATTERNS
      #########################################

      FILL_POUCH_SUCCESS_PATTERNS = [
        /^You open/,
        /^You fill your/,
        /^There aren't any gems/
      ].freeze

      FILL_POUCH_NEEDS_TIE_PATTERNS = [
        /^You'd better tie it up before putting/,
        /^You'll need to tie it up before/
      ].freeze

      FILL_POUCH_FULL_PATTERN = /is too full to fit/.freeze

      FILL_POUCH_FAILURE_PATTERNS = [
        /^Please rephrase that command/,
        /^What were you referring to/
      ].freeze

      #########################################
      # INVENTORY BELT PATTERNS
      #########################################

      INV_BELT_START_PATTERN = /^All of your items worn attached to the belt:/.freeze
      INV_BELT_END_PATTERN = /^\[Use INVENTORY HELP/.freeze

      #########################################
      # TRASH ITEM
      #########################################

      # Disposes of an item by putting it in a trash receptacle.
      #
      # Tries multiple disposal strategies in order: worn trashcan,
      # room meta-tagged trashcan, room objects matching known trash
      # receptacles, and finally drops the item on the ground.
      #
      # @param item [String] item noun to dispose of
      # @param worn_trashcan [String, nil] worn container for trash (e.g., "shroud")
      # @param worn_trashcan_verb [String, nil] verb to activate the worn trashcan after use
      # @return [Boolean, nil] true if disposed, false if failed, nil if item is nil or not held
      #
      # @example Dispose using room trash bins
      #   DRCI.dispose_trash("rock")
      #
      # @example Dispose into a worn trashcan
      #   DRCI.dispose_trash("rock", "shroud", "tap")
      def dispose_trash(item, worn_trashcan = nil, worn_trashcan_verb = nil)
        return unless item
        return unless DRCI.get_item_if_not_held?(item)

        if worn_trashcan
          case DRC.bput("put #{item_ref(item)} in #{item_ref(worn_trashcan)}", DROP_TRASH_SUCCESS_PATTERNS, DROP_TRASH_FAILURE_PATTERNS, DROP_TRASH_RETRY_PATTERNS, /^Perhaps you should be holding that first/)
          when *DROP_TRASH_SUCCESS_PATTERNS
            if worn_trashcan_verb
              DRC.bput("#{worn_trashcan_verb} #{item_ref(worn_trashcan)}", *WORN_TRASHCAN_VERB_PATTERNS)
              DRC.bput("#{worn_trashcan_verb} #{item_ref(worn_trashcan)}", *WORN_TRASHCAN_VERB_PATTERNS)
            end
            return true
          when *DROP_TRASH_FAILURE_PATTERNS
            # NOOP, try next trashcan option
          when *DROP_TRASH_RETRY_PATTERNS
            return DRCI.dispose_trash(item, worn_trashcan, worn_trashcan_verb)
          when /^Perhaps you should be holding that first/
            return (DRCI.get_item?(item) && DRCI.dispose_trash(item, worn_trashcan, worn_trashcan_verb))
          end
        end

        # Check for meta:trashcan tag on the room to identify a specific trashcan to use.
        metatag_match = Room.current.tags.find { |t| t =~ /meta:trashcan:(?<trashcan>.*)/ }&.match(/meta:trashcan:(?<trashcan>.*)/)
        if metatag_match
          metatag_trashcan = metatag_match[:trashcan]

          # Gelapod needs special handling since you feed it, and it disappears in winter
          metatag_trash_command = nil
          if metatag_trashcan == 'gelapod'
            metatag_trash_command = "feed #{item_ref(item)} to gelapod" if DRRoom.room_objs.include?('gelapod')
          else
            metatag_trash_command = "put #{item_ref(item)} in #{metatag_trashcan}"
          end

          # gelapod is not here - probably winter move on to next attempt to get rid of
          unless metatag_trash_command.nil?
            case DRC.bput(metatag_trash_command, DROP_TRASH_SUCCESS_PATTERNS, DROP_TRASH_FAILURE_PATTERNS, DROP_TRASH_RETRY_PATTERNS, /^Perhaps you should be holding that first/)
            when *DROP_TRASH_SUCCESS_PATTERNS
              return true
            when *DROP_TRASH_FAILURE_PATTERNS
              # NOOP, try next trashcan option
            when *DROP_TRASH_RETRY_PATTERNS
              # If still didn't dispose of trash after retry
              # then don't return yet, will try to drop it later.
              return dispose_trash(item)
            when /^Perhaps you should be holding that first/
              return (DRCI.get_item?(item) && DRCI.dispose_trash(item))
            end
          end
        end

        trashcans = DRRoom.room_objs
                          .reject { |obj| obj =~ /azure \w+ tree/ }
                          .map { |long_name| DRC.get_noun(long_name) }
                          .select { |obj| TRASH_STORAGE.include?(obj) }

        trashcans.each do |trashcan|
          if trashcan == 'gloop'
            trashcan = 'bucket' if DRRoom.room_objs.include?('bucket of viscous gloop')
            trashcan = 'cauldron' if DRRoom.room_objs.include?('small bubbling cauldron of viscous gloop')
          elsif trashcan == 'bucket'
            trashcan = 'sturdy bucket' if DRRoom.room_objs.include?('sturdy bucket')
          elsif trashcan == 'basket'
            trashcan = 'waste basket' if DRRoom.room_objs.include?('waste basket')
          elsif trashcan == 'bin'
            trashcan = 'waste bin' if DRRoom.room_objs.include?('waste bin')
            trashcan = 'small bin' if DRRoom.room_objs.include?('small bin concealed with some nearby brush')
          elsif trashcan == 'arms'
            trashcan = 'statue'
          elsif trashcan == 'birdbath'
            trashcan = 'alabaster birdbath'
          elsif trashcan == 'turtle'
            trashcan = 'stone turtle'
          elsif trashcan == 'tree'
            trashcan = 'hollow' if DRRoom.room_objs.include?('dead tree with a darkened hollow near its base')
          elsif trashcan == 'basin'
            trashcan = 'stone basin' if DRRoom.room_objs.include?('hollow stone basin')
          elsif trashcan == 'tangle'
            trashcan = 'dark gap' if DRRoom.room_objs.include?('tangle of thick roots forming a dark gap')
          elsif XMLData.room_title == '[[A Junk Yard]]'
            trashcan = 'bin'
          elsif trashcan == 'gelapod'
            trash_command = "feed #{item_ref(item)} to gelapod"
          end

          trash_command = "put #{item_ref(item)} in #{trashcan}" unless trashcan == 'gelapod'

          case DRC.bput(trash_command, DROP_TRASH_SUCCESS_PATTERNS, DROP_TRASH_FAILURE_PATTERNS, DROP_TRASH_RETRY_PATTERNS, /^Perhaps you should be holding that first/)
          when *DROP_TRASH_SUCCESS_PATTERNS
            return true
          when *DROP_TRASH_FAILURE_PATTERNS
            # NOOP, try next trashcan option
          when *DROP_TRASH_RETRY_PATTERNS
            # If still didn't dispose of trash after retry
            # then don't return yet, will try to drop it later.
            return true if dispose_trash(item)
          when /^Perhaps you should be holding that first/
            return (DRCI.get_item?(item) && DRCI.dispose_trash(item))
          end
        end

        # No trash bins or not able to put item in a bin, just drop it.
        case DRC.bput("drop #{item_ref(item)}", DROP_TRASH_SUCCESS_PATTERNS, DROP_TRASH_FAILURE_PATTERNS, DROP_TRASH_RETRY_PATTERNS, /^Perhaps you should be holding that first/, /^But you aren't holding that/)
        when *DROP_TRASH_SUCCESS_PATTERNS
          return true
        when *DROP_TRASH_FAILURE_PATTERNS
          Lich::Messaging.msg("bold", "DRCI: Failed to dispose of '#{item}'.")
          return false
        when *DROP_TRASH_RETRY_PATTERNS
          return dispose_trash(item)
        when /^Perhaps you should be holding that first/, /^But you aren't holding that/
          return (DRCI.get_item?(item) && DRCI.dispose_trash(item))
        else
          # failure of match patterns in the bput, but still need to return a value
          Lich::Messaging.msg("bold", "DRCI: Unexpected response when dropping '#{item}'.")
          return false
        end
      end

      #########################################
      # SEARCH FOR ITEM
      #########################################

      # Searches inventory for an item using the INV SEARCH command.
      #
      # @param item [String] item noun to search for
      # @return [Integer, nil] match position if found, nil if not found
      #
      # @example
      #   DRCI.search?("deed")  #=> truthy if found
      def search?(item)
        /(?:An?|Some) .+ is (?:in|being)/ =~ DRC.bput("inv search #{item}", /^You can't seem to find anything/, /(?:An?|Some) .+ is (?:in|being)/)
      end

      # Checks if an item is currently worn by tapping it.
      #
      # @param item [String] item noun to check
      # @return [Integer, nil] truthy match position if wearing, nil otherwise
      def wearing?(item)
        tap(item) =~ /wearing/
      end

      # Checks if an item is inside a container by tapping it.
      #
      # @param item [String] item noun to check
      # @param container [String, nil] container noun to check, or nil for any
      # @return [Integer, nil] truthy match position if inside a container, nil otherwise
      def inside?(item, container = nil)
        tap(item, container) =~ /inside/
      end

      # Checks if an item exists in inventory or a container by tapping it.
      #
      # @param item [String] item noun to check
      # @param container [String, nil] container to check in, or nil for general inventory
      # @return [Boolean] true if the item exists
      #
      # @example
      #   DRCI.exists?("deed")
      #   DRCI.exists?("sword", "backpack")
      def exists?(item, container = nil)
        case tap(item, container)
        when *TAP_SUCCESS_PATTERNS
          true
        else
          false
        end
      end

      # Taps an item and returns the game response string.
      #
      # The tap response indicates whether the item is worn, inside a
      # container, etc. Used by {.wearing?}, {.inside?}, and {.exists?}.
      #
      # @param item [String] item noun to tap
      # @param container [String, nil] container to qualify the tap, or nil for general inventory
      # @return [String, nil] game response text, or nil if item is nil
      def tap(item, container = nil)
        return nil unless item

        from = container
        from = "from #{item_ref(container)}" if container && !(container =~ /^(in|on|under|behind|from) /i)
        DRC.bput("tap #{item_ref(item)} #{from}", *TAP_SUCCESS_PATTERNS, *TAP_FAILURE_PATTERNS)
      end

      # Checks if the item is in either hand.
      #
      # @param item [String, DRC::Item] item noun or Item object
      # @return [Boolean] true if item is in either hand
      #
      # @see .in_hand?
      def in_hands?(item)
        in_hand?(item, 'either')
      end

      # Checks if the item is in the left hand.
      #
      # @param item [String, DRC::Item] item noun or Item object
      # @return [Boolean] true if item is in the left hand
      #
      # @see .in_hand?
      def in_left_hand?(item)
        in_hand?(item, 'left')
      end

      # Checks if the item is in the right hand.
      #
      # @param item [String, DRC::Item] item noun or Item object
      # @return [Boolean] true if item is in the right hand
      #
      # @see .in_hand?
      def in_right_hand?(item)
        in_hand?(item, 'right')
      end

      # Checks if an item is in one or more hands.
      #
      # Accepts a string noun or a {DRC::Item} object. Strings are
      # converted to Item objects for regex matching against hand contents.
      #
      # @param item [String, DRC::Item] item noun or Item object
      # @param which_hand [String] "left", "right", "either", or "both"
      # @return [Boolean] true if item is in the specified hand(s)
      #
      # @example Check either hand
      #   DRCI.in_hand?("sword")
      #
      # @example Check specific hand
      #   DRCI.in_hand?("shield", "left")
      def in_hand?(item, which_hand = 'either')
        return false unless item

        item = DRC::Item.from_text(item) if item.is_a?(String)
        case which_hand.downcase
        when 'left'
          DRC.left_hand =~ item.short_regex
        when 'right'
          DRC.right_hand =~ item.short_regex
        when 'either'
          in_left_hand?(item) || in_right_hand?(item)
        when 'both'
          in_left_hand?(item) && in_right_hand?(item)
        else
          Lich::Messaging.msg("bold", "DRCI: Unknown hand: #{which_hand}. Valid options are: left, right, either, both")
          false
        end
      end

      # Checks if an item exists in a container by LOOKing at it.
      #
      # Unlike {.exists?} which uses TAP, this uses LOOK AT which can
      # find items inside containers that TAP cannot reach.
      #
      # @param item [String] item noun to look for
      # @param container [String] container noun to look in
      # @return [Boolean] true if item is found in the container
      def have_item_by_look?(item, container)
        return false unless item

        item = item.delete_prefix('my ')
        # For item IDs, don't add preposition with 'my' - just use 'in' for the container
        if container&.start_with?('#')
          preposition = 'in' if container && !(container =~ /^(in|on|under|behind|from) /i)
        else
          preposition = 'in my' if container && !(container =~ /^((in|on|under|behind|from) )?my /i)
        end

        case DRC.bput("look at #{item_ref(item)} #{preposition} #{container}", item, /^You see nothing unusual/, /^I could not find/, /^What were you referring to/)
        when /You see nothing unusual/, item
          true
        else
          false
        end
      end

      #########################################
      # COUNT ITEMS
      #########################################

      COUNT_PART_PATTERNS = [
        /and see there (?:is|are) (?<count>.+) left\./,
        /There (?:is|are) (?:only )?(?<count>.+) parts? left/,
        /There's (?:only )?(?<count>.+) parts? left/,
        /The (?:.+) has (?<count>.+) uses remaining./,
        /There are enough left to create (?<count>.+) more/,
        /You count out (?<count>.+) pieces? of material there/,
        /There (?:is|are) (?<count>.+) scrolls? left for use with crafting/
      ].freeze

      # Counts the remaining parts/uses of a stackable item.
      #
      # Iterates through ordinals (first, second, ...) to count across
      # multiple stacks. Falls back to {.count_items} if the item is
      # not stackable.
      #
      # @param item [String] item noun to count
      # @return [Integer] total number of parts across all stacks
      #
      # @example
      #   DRCI.count_item_parts("leather")  #=> 45
      def count_item_parts(item)
        count = 0
        # Item IDs (starting with #) are unique, so we count once without ordinals
        items_to_count = item&.start_with?('#') ? [item] : $ORDINALS.map { |ord| "#{ord} #{item}" }

        items_to_count.each do |item_with_ordinal|
          result = DRC.bput("count #{item_ref(item_with_ordinal)}",
                            'I could not find what you were referring to.',
                            'tell you much of anything.',
                            *COUNT_PART_PATTERNS)
          if result == 'I could not find what you were referring to.'
            break
          elsif result == 'tell you much of anything.'
            Lich::Messaging.msg("bold", "DRCI: count_item_parts called on non-stackable item: #{item}")
            count = count_items(item)
            break
          else
            # Try to match against our count patterns
            match = COUNT_PART_PATTERNS.lazy.filter_map { |pat| result.match(pat) }.first
            if match
              countval = match[:count].tr('-', ' ')
              if countval.match?(/\A\d+\z/)
                count += Integer(countval)
              else
                count += DRC.text2num(countval)
              end
            end
          end
          waitrt?
        end
        count
      end

      # Counts matching items in the container inferred by tapping the item.
      #
      # Taps the item to determine which container it is in, then
      # delegates to {.count_items_in_container}.
      #
      # @param item [String] item noun to count
      # @return [Integer] number of matching items in the inferred container
      #
      # @see .count_items_in_container
      def count_items(item)
        tap_result = tap(item)
        match = tap_result&.match(/inside your (?<container>.*)/)
        return 0 unless match

        count_items_in_container(item, match[:container])
      end

      # Counts matching items in a specific container via RUMMAGE.
      #
      # @param item [String] item noun to count
      # @param container [String] container noun to rummage
      # @return [Integer] number of matching items found
      #
      # @see .count_items
      def count_items_in_container(item, container)
        contents = DRC.bput("rummage /C #{item.split.last} in #{item_ref(container)}", /^You rummage .*/, /That would accomplish nothing/)
        # This regexp avoids counting the quoted item name in the message, as
        # well as avoiding finding the item as a substring of other items.
        contents.scan(/ #{item}\W/).size
      end

      # Counts how many more lockpicks a lockpick stacker can hold.
      #
      # Uses APPRAISE QUICK to determine remaining capacity.
      #
      # @param container [String] lockpick ring/stacker noun
      # @return [Integer] number of additional lockpicks that can fit
      #
      # @see https://elanthipedia.play.net/Lockpick_rings
      def count_lockpick_container(container)
        count = DRC.bput("appraise #{item_ref(container)} quick", /it appears to be full/, /it might hold an additional \d+/, /\d+ lockpicks would probably fit/).scan(/\d+/).first.to_i
        waitrt?
        count
      end

      # Lists boxes in a container via RUMMAGE /B.
      #
      # @param container [String] container noun to rummage
      # @return [Array<String>] list of box descriptions
      def get_box_list_in_container(container)
        DRC.rummage('B', container)
      end

      # Lists scrolls in a container via RUMMAGE /SC.
      #
      # @param container [String] container noun to rummage
      # @return [Array<String>] list of scroll descriptions
      def get_scroll_list_in_container(container)
        DRC.rummage('SC', container)
      end

      # Counts items in a Necromancer material stacker via STUDY.
      #
      # @param necro_stacker [String] stacker noun
      # @return [Integer] number of items currently held
      def count_necro_stacker(necro_stacker)
        DRC.bput("study #{item_ref(necro_stacker)}", /currently holds \d+ items/).scan(/\d+/).first.to_i
      end

      # Counts all lockpick boxes across configured containers.
      #
      # Checks the picking_box_source, picking_box_sources, blacklist, and
      # too_hard containers from settings.
      #
      # @param settings [OpenStruct] user settings from get_settings
      # @return [Integer] total number of boxes across all containers
      def count_all_boxes(settings)
        current_box_count = 0

        [
          settings.picking_box_source,
          settings.pick['picking_box_sources'],
          settings.pick['blacklist_container'],
          settings.pick['too_hard_container']
        ].flatten.uniq.reject { |container|
          container.to_s.empty?
        }.each { |container|
          current_box_count += get_box_list_in_container(container).size
        }

        current_box_count
      end

      #########################################
      # STOW ITEM
      #########################################

      # Stows whatever is held in both hands.
      #
      # Skips empty hands. Returns true only if both hands are empty
      # or successfully stowed.
      #
      # @return [Boolean] true if both hands are now empty
      #
      # @see .stow_hand
      def stow_hands
        (!DRC.left_hand || stow_hand('left')) &&
          (!DRC.right_hand || stow_hand('right'))
      end

      BRAID_TOO_LONG_PATTERN = /The braided (?<braid_name>.+) is too long/.freeze

      # Stows whatever is in the specified hand.
      #
      # Handles braids that are too long by disposing them as trash.
      #
      # @param hand [String] "right" or "left"
      # @return [Boolean] true if the hand is now empty
      # @api private
      def stow_hand(hand)
        result = DRC.bput("stow #{hand}", BRAID_TOO_LONG_PATTERN, CONTAINER_IS_CLOSED_PATTERNS, STOW_ITEM_SUCCESS_PATTERNS, STOW_ITEM_FAILURE_PATTERNS, STOW_ITEM_RETRY_PATTERNS)
        braid_match = result&.match(BRAID_TOO_LONG_PATTERN)
        if braid_match
          dispose_trash(DRC.get_noun(braid_match[:braid_name]))
        elsif STOW_ITEM_RETRY_PATTERNS.any? { |pat| pat.match?(result) }
          stow_hand(hand)
        elsif STOW_ITEM_SUCCESS_PATTERNS.any? { |pat| pat.match?(result) }
          true
        else
          false
        end
      end

      #########################################
      # GET ITEM
      #########################################

      # Gets an item only if not already held in either hand.
      #
      # Avoids getting a duplicate when you already have the item.
      # Returns true if the item is already in hand or was successfully
      # retrieved.
      #
      # @param item [String] item noun to get
      # @param container [String, nil] container to get from, or nil for default
      # @return [Boolean] true if item is now in hand
      #
      # @example
      #   DRCI.get_item_if_not_held?("almanac")
      #   DRCI.get_item_if_not_held?("sword", "backpack")
      #
      # @see .get_item?
      def get_item_if_not_held?(item, container = nil)
        return false unless item
        return true if in_hands?(item)

        return get_item(item, container)
      end

      # Gets an item, optionally from a specific container.
      #
      # Predicate-named convenience wrapper for {.get_item}.
      #
      # @param item [String] item noun to get
      # @param container [String, Array<String>, nil] container noun, array of containers to try, or nil
      # @return [Boolean] true if item was retrieved successfully
      #
      # @example Get from default storage
      #   DRCI.get_item?("sword")
      #
      # @example Get from specific container
      #   DRCI.get_item?("bandages", "backpack")
      #
      # @see .put_away_item? Inverse operation
      def get_item?(item, container = nil)
        get_item(item, container)
      end

      # Gets an item, optionally from a specific container.
      #
      # Accepts a single container or an array of containers to try in order.
      # Delegates to {.get_item_safe} with "my " prefix qualification.
      #
      # @param item [String] item noun to get
      # @param container [String, Array<String>, nil] container(s) to try, or nil for default
      # @return [Boolean] true if item was retrieved successfully
      # @api private
      def get_item(item, container = nil)
        if container.is_a?(Array)
          container.each do |c|
            return true if get_item_safe(item, c)
          end
          return false
        end
        get_item_safe(item, container)
      end

      # Gets an item with "my " prefix on item and container names.
      #
      # @param item [String] item noun to get
      # @param container [String, nil] container noun, or nil for default
      # @return [Boolean] true if item was retrieved successfully
      # @api private
      def get_item_safe?(item, container = nil)
        item = item_ref(item)
        container = item_ref(container) if container && !(container =~ /^(in|on|under|behind|from) /i)
        get_item_unsafe(item, container)
      end

      def get_item_safe(item, container = nil)
        get_item_safe?(item, container)
      end

      # Gets an item without "my " prefix qualification.
      #
      # Issues the GET command and checks for success/failure responses.
      # Falls back to eddy portal retrieval if container is a portal.
      #
      # @param item [String] item name (unqualified)
      # @param container [String, nil] container name (unqualified), or nil
      # @return [Boolean] true if item was retrieved successfully
      # @api private
      def get_item_unsafe(item, container = nil)
        from = container
        from = "from #{container}" if container && !(container =~ /^(in|on|under|behind|from) /i)
        case DRC.bput("get #{item} #{from}", GET_ITEM_SUCCESS_PATTERNS, GET_ITEM_FAILURE_PATTERNS)
        when *GET_ITEM_SUCCESS_PATTERNS
          return true
        else
          if container =~ /\bportal\b/i
            return get_item_from_eddy_portal?(item, container)
          else
            return false
          end
        end
      end

      # Gets an item from an eddy portal after forcing a content refresh.
      #
      # Workaround for a game change where you must LOOK in the portal
      # before its contents are available for retrieval.
      #
      # @param item [String] item name to get
      # @param container [String] portal container reference
      # @return [Boolean] true if item was retrieved successfully
      #
      # @see http://forums.play.net/forums/DragonRealms/Discussions%20with%20DragonRealms%20Staff%20and%20Players/Game%20Master%20and%20Official%20Announcements/view/1899
      # @api private
      def get_item_from_eddy_portal?(item, container)
        # Ensure the eddy is open then look in it to force the contents to be loaded.
        return false unless DRCI.open_container?('my eddy') && DRCI.look_in_container('portal in my eddy')

        from = container
        from = "from #{container}" if container && !(container =~ /^(in|on|under|behind|from) /i)
        case DRC.bput("get #{item} #{from}", GET_ITEM_SUCCESS_PATTERNS, GET_ITEM_FAILURE_PATTERNS)
        when *GET_ITEM_SUCCESS_PATTERNS
          return true
        else
          return false
        end
      end

      #########################################
      # TIE/UNTIE ITEM
      #########################################

      # Ties an item, optionally to a specific container.
      #
      # @param item [String] item noun to tie
      # @param container [String, nil] container to tie to, or nil for default
      # @return [Boolean] true if item was tied successfully
      #
      # @example Tie to belt
      #   DRCI.tie_item?("pouch", "belt")
      #
      # @see .untie_item? Inverse operation
      def tie_item?(item, container = nil)
        place = container ? "to #{item_ref(container)}" : nil
        case DRC.bput("tie #{item_ref(item)} #{place}", TIE_ITEM_SUCCESS_PATTERNS, TIE_ITEM_FAILURE_PATTERNS)
        when *TIE_ITEM_SUCCESS_PATTERNS
          true
        else
          false
        end
      end

      # Unties an item, optionally from a specific container.
      #
      # @param item [String] item noun to untie
      # @param container [String, nil] container to untie from, or nil for default
      # @return [Boolean] true if item was untied successfully
      #
      # @see .tie_item? Inverse operation
      def untie_item?(item, container = nil)
        place = container ? "from #{item_ref(container)}" : nil
        case DRC.bput("untie #{item_ref(item)} #{place}", UNTIE_ITEM_SUCCESS_PATTERNS, UNTIE_ITEM_FAILURE_PATTERNS)
        when *UNTIE_ITEM_SUCCESS_PATTERNS
          true
        else
          false
        end
      end

      #########################################
      # WEAR ITEM
      #########################################

      # Wears an item from your hands.
      #
      # Issues the WEAR command with "my " prefix qualification.
      #
      # @param item [String] item noun to wear
      # @return [Boolean] true if item was worn successfully
      #
      # @example
      #   DRCI.wear_item?("cloak")
      #
      # @see .remove_item? Inverse operation
      def wear_item?(item)
        wear_item_safe?(item)
      end

      # Wears an item with "my " prefix qualification.
      #
      # @param item [String] item noun to wear
      # @return [Boolean] true if item was worn successfully
      # @api private
      def wear_item_safe?(item)
        wear_item_unsafe?(item_ref(item))
      end

      # Wears an item without "my " prefix qualification.
      #
      # @param item [String] item name (unqualified)
      # @return [Boolean] true if item was worn successfully
      # @api private
      def wear_item_unsafe?(item)
        case DRC.bput("wear #{item}", WEAR_ITEM_SUCCESS_PATTERNS, WEAR_ITEM_FAILURE_PATTERNS)
        when *WEAR_ITEM_SUCCESS_PATTERNS
          return true
        else
          return false
        end
      end

      #########################################
      # REMOVE ITEM
      #########################################

      # Removes a worn item into your hands.
      #
      # Issues the REMOVE command with "my " prefix qualification.
      #
      # @param item [String] item noun to remove
      # @return [Boolean] true if item was removed successfully
      #
      # @example
      #   DRCI.remove_item?("cloak")
      #
      # @see .wear_item? Inverse operation
      def remove_item?(item)
        remove_item_safe?(item)
      end

      # Removes a worn item with "my " prefix qualification.
      #
      # @param item [String] item noun to remove
      # @return [Boolean] true if item was removed successfully
      # @api private
      def remove_item_safe?(item)
        remove_item_unsafe?(item_ref(item))
      end

      # Removes a worn item without "my " prefix qualification.
      #
      # @param item [String] item name (unqualified)
      # @return [Boolean] true if item was removed successfully
      # @api private
      def remove_item_unsafe?(item)
        case DRC.bput("remove #{item}", REMOVE_ITEM_SUCCESS_PATTERNS, REMOVE_ITEM_FAILURE_PATTERNS)
        when *REMOVE_ITEM_SUCCESS_PATTERNS
          return true
        else
          return false
        end
      end

      #########################################
      # STOW ITEM
      #########################################

      # Stows an item into its default container (per STORE HELP settings).
      #
      # Issues the STOW command with "my " prefix qualification.
      # Retries automatically on retry-pattern responses.
      #
      # @param item [String] item noun to stow
      # @return [Boolean] true if item was stowed successfully
      #
      # @example
      #   DRCI.stow_item?("sword")
      #
      # @see .put_away_item? For stowing into a specific container
      def stow_item?(item)
        stow_item_safe?(item)
      end

      # Stows an item with "my " prefix qualification.
      #
      # @param item [String] item noun to stow
      # @return [Boolean] true if item was stowed successfully
      # @api private
      def stow_item_safe?(item)
        stow_item_unsafe?(item_ref(item))
      end

      # Stows an item without "my " prefix qualification.
      #
      # @param item [String] item name (unqualified)
      # @return [Boolean] true if item was stowed successfully
      #
      # @note Without "my " prefix, may attempt to stow an item on the ground
      #   rather than one in your inventory.
      # @api private
      def stow_item_unsafe?(item)
        case DRC.bput("stow #{item}", CONTAINER_IS_CLOSED_PATTERNS, STOW_ITEM_SUCCESS_PATTERNS, STOW_ITEM_FAILURE_PATTERNS, STOW_ITEM_RETRY_PATTERNS)
        when *STOW_ITEM_RETRY_PATTERNS
          return stow_item_unsafe?(item)
        when *STOW_ITEM_SUCCESS_PATTERNS
          return true
        else
          return false
        end
      end

      #########################################
      # LOWER ITEM
      #########################################

      # Lowers a held item to the ground (feet slot).
      #
      # Determines which hand holds the item, then issues LOWER GROUND.
      #
      # @param item [String] item noun to lower
      # @return [Boolean] true if item was lowered successfully, false if not held or failed
      #
      # @example
      #   DRCI.lower_item?("sword")
      def lower_item?(item)
        return false unless in_hands?(item)

        item_regex = /\b#{item}\b/
        hand = (DRC.left_hand =~ item_regex) ? 'left' : 'right'
        case DRC.bput("lower ground #{hand}", *LOWER_SUCCESS_PATTERNS, *LOWER_FAILURE_PATTERNS)
        when *LOWER_SUCCESS_PATTERNS
          true
        else
          false
        end
      end

      # Lifts an item from the ground, optionally stowing it afterward.
      #
      # @param item [String, nil] item noun to lift (uses last word only)
      # @param stow [String, Boolean, nil] if a String, puts item in that container;
      #   if true, stows to default container; if nil/false, just lifts
      # @return [Boolean] true if lifted (and optionally stowed) successfully
      #
      # @example Lift only
      #   DRCI.lift?("sword")
      #
      # @example Lift and stow to default
      #   DRCI.lift?("sword", true)
      #
      # @example Lift and put in specific container
      #   DRCI.lift?("sword", "backpack")
      def lift?(item = nil, stow = nil)
        return false unless item

        item = item.split.last # Necessary until adjectives are implemented for lift
        case DRC.bput("lift #{item}", LIFT_SUCCESS_PATTERNS, LIFT_FAILURE_PATTERNS)
        when *LIFT_SUCCESS_PATTERNS
          if stow.is_a?(String)
            put_away_item?(item, stow)
          elsif stow
            stow_item?(item)
          else
            true
          end
        else
          false
        end
      end

      #########################################
      # CHECK CONTAINER CONTENTS
      #########################################

      # Checks if a container is empty by looking inside it.
      #
      # @param container [String] container noun to check
      # @return [Boolean, nil] true if empty, false if not empty,
      #   nil if unable to determine (e.g., cannot open or look in container)
      def container_is_empty?(container)
        look_in_container(container)&.empty?
      end

      # Returns a list of item descriptions from the `INVENTORY <type|slot>` verb output.
      #
      # @param type [String] inventory type: armor, weapon, fluff, container,
      #   combat, or any slot from INVENTORY SLOTS LIST
      # @return [Array<String>] item descriptions with articles stripped
      #
      # @example
      #   DRCI.get_inventory_by_type('combat')
      #   #=> ["steel plate helm", "dark leather jerkin with reinforced seams"]
      #
      # @see EquipmentManager#get_combat_items
      def get_inventory_by_type(type = 'combat')
        start_pattern = /^All of your |^You aren't wearing anything like that|^Both of your hands are empty/
        end_pattern = /^\[Use INVENTORY HELP/

        snapshot = Lich::Util.issue_command(
          "inventory #{type}",
          start_pattern,
          end_pattern,
          timeout: 5,
          usexml: false,
          include_end: false
        )

        if snapshot.nil? || snapshot.empty?
          Lich::Messaging.msg("bold", "DRCI: No inventory data for type '#{type}'. Valid options: ARMOR, WEAPON, FLUFF, CONTAINER, COMBAT, or any slot from INVENTORY SLOTS LIST.")
          return []
        end

        items_at_feet = snapshot.any? { |line| line.strip.start_with?('Lying at your feet') }

        snapshot
          .map(&:strip)
          .reject { |line| start_pattern.match?(line) || line.empty? }
          .take_while { |line| !items_at_feet || !line.start_with?('Lying at your feet') }
          .map { |item| item.gsub(/^(a|an|some)\s+/, '').gsub(/\s+\(closed\)/, '') }
      end

      # Lists items in a container using RUMMAGE or LOOK.
      #
      # RUMMAGE returns full tap descriptions (e.g., "grey ice skates with black laces").
      # LOOK returns short names (e.g., "grey ice skates"), which is easier to parse.
      #
      # @param container [String] container noun to inspect
      # @param verb [String] "rummage" or "look"
      # @return [Array<String>, nil] list of item descriptions, or nil on failure
      #
      # @example
      #   DRCI.get_item_list("backpack", "look")
      #
      # @see .rummage_container
      # @see .look_in_container
      def get_item_list(container, verb = 'rummage')
        case verb
        when /^(r|rummage)$/i
          rummage_container(container)
        when /^(l|look)$/i
          look_in_container(container)
        end
      end

      # Lists items in a container via RUMMAGE.
      #
      # Returns full tap descriptions. Automatically opens closed containers
      # before rummaging.
      #
      # @param container [String] container noun to rummage
      # @return [Array<String>, nil] list of item descriptions, or nil if cannot access container
      def rummage_container(container)
        container = item_ref(container)
        contents = DRC.bput("rummage #{container}", CONTAINER_IS_CLOSED_PATTERNS, RUMMAGE_SUCCESS_PATTERNS, RUMMAGE_FAILURE_PATTERNS)
        case contents
        when *RUMMAGE_FAILURE_PATTERNS
          Lich::Messaging.msg("bold", "DRCI: Unable to rummage in '#{container}'.")
          return nil
        when *CONTAINER_IS_CLOSED_PATTERNS
          unless open_container?(container)
            Lich::Messaging.msg("bold", "DRCI: Unable to open '#{container}' for rummaging.")
            return nil
          end

          rummage_container(container)
        else
          contents
            .match(/You rummage through .* and see (?:a|an|some) (?<items>.*)\./)[:items] # Get string of just the comma separated item list
            .sub(/ and (?=a|an|some)/, ", ") # replace " and " for the last item into " , "
            .split(/, (?:a|an|some) /) # Split at a, an, or some, but only when it follows a comma
        end
      end

      # Lists items in a container via LOOK IN.
      #
      # Returns short item names. Automatically opens closed containers
      # before looking.
      #
      # @param container [String] container noun to look in
      # @return [Array<String>, nil] list of item descriptions, or nil if cannot access container
      def look_in_container(container)
        container = item_ref(container)
        contents = DRC.bput("look in #{container}", CONTAINER_IS_CLOSED_PATTERNS, RUMMAGE_SUCCESS_PATTERNS, RUMMAGE_FAILURE_PATTERNS)
        case contents
        when *RUMMAGE_FAILURE_PATTERNS
          Lich::Messaging.msg("bold", "DRCI: Unable to look in '#{container}'.")
          return nil
        when *CONTAINER_IS_CLOSED_PATTERNS
          unless open_container?(container)
            Lich::Messaging.msg("bold", "DRCI: Unable to open '#{container}' to look inside.")
            return nil
          end

          look_in_container(container)
        else
          contents
            .match(/In the .* you see (?:some|an|a) (?<items>.*)\./)[:items]
            .split(/(?:,|and) (?:some|an|a)/)
            .map(&:strip)
        end
      end

      #########################################
      # PUT AWAY ITEM
      #########################################

      # Puts away a held item, optionally into a specific container.
      #
      # If no container is specified, uses the default stow location.
      # Accepts an array of containers to try in order (useful when
      # some may be full).
      #
      # @param item [String] item noun to put away
      # @param container [String, Array<String>, nil] container noun, array of containers, or nil
      # @return [Boolean] true if item was put away successfully
      #
      # @example Stow to default location
      #   DRCI.put_away_item?("sword")
      #
      # @example Put in specific container
      #   DRCI.put_away_item?("sword", "backpack")
      #
      # @example Try multiple containers
      #   DRCI.put_away_item?("gem", ["pouch", "sack", "backpack"])
      #
      # @see .get_item? Inverse operation
      def put_away_item?(item, container = nil)
        if container.is_a?(Array)
          container.each do |c|
            return true if put_away_item_safe?(item, c)
          end
          return false
        end
        put_away_item_safe?(item, container)
      end

      # Puts away an item with "my " prefix on item and container names.
      #
      # @param item [String] item noun to put away
      # @param container [String, nil] container noun, or nil for default
      # @return [Boolean] true if item was put away successfully
      # @api private
      def put_away_item_safe?(item, container = nil)
        put_away_item_unsafe?(item_ref(item), item_ref(container))
      end

      # Puts away an item without "my " prefix qualification.
      #
      # Supports custom prepositions (e.g., "on", "under") and retries
      # on closed containers or retry-pattern responses.
      #
      # @param item [String] item name (unqualified)
      # @param container [String, nil] container name (unqualified), or nil for default stow
      # @param preposition [String] container preposition ("in", "on", "under", etc.)
      # @return [Boolean] true if item was put away successfully
      # @api private
      def put_away_item_unsafe?(item, container = nil, preposition = "in")
        command = "put #{item} #{preposition} #{container}" if container
        command = "stow #{item}" unless container
        result = DRC.bput(command, CONTAINER_IS_CLOSED_PATTERNS, PUT_AWAY_ITEM_SUCCESS_PATTERNS, PUT_AWAY_ITEM_FAILURE_PATTERNS, PUT_AWAY_ITEM_RETRY_PATTERNS)
        case result
        when *CONTAINER_IS_CLOSED_PATTERNS
          return false unless container && open_container?(container)

          return put_away_item_unsafe?(item, container)
        when *PUT_AWAY_ITEM_RETRY_PATTERNS
          return put_away_item_unsafe?(item, container)
        when *PUT_AWAY_ITEM_SUCCESS_PATTERNS
          return true
        when *PUT_AWAY_ITEM_FAILURE_PATTERNS
          return false
        else
          return false
        end
      end

      #########################################
      # OPEN/CLOSE CONTAINERS
      #########################################

      # Opens a container.
      #
      # @param container [String] container noun to open
      # @return [Boolean] true if container was opened (or already open)
      #
      # @see .close_container?
      def open_container?(container)
        case DRC.bput("open #{container}", OPEN_CONTAINER_SUCCESS_PATTERNS, OPEN_CONTAINER_FAILURE_PATTERNS)
        when *OPEN_CONTAINER_SUCCESS_PATTERNS
          return true
        end
        return false
      end

      # Closes a container.
      #
      # @param container [String] container noun to close
      # @return [Boolean] true if container was closed (or already closed)
      #
      # @see .open_container?
      def close_container?(container)
        case DRC.bput("close #{container}", CLOSE_CONTAINER_SUCCESS_PATTERNS, CLOSE_CONTAINER_FAILURE_PATTERNS)
        when *CLOSE_CONTAINER_SUCCESS_PATTERNS
          return true
        end
        return false
      end

      #########################################
      # GIVE/ACCEPT ITEM
      #########################################

      # Gives a held item to a target (player or NPC).
      #
      # Handles retry prompts, expired offers, and hand-swap scenarios.
      # Uses a 35-second timeout to allow the target time to accept.
      #
      # @param target [String] player name or NPC noun to give to
      # @param item [String, nil] item noun, or nil to give whatever is held
      # @return [Boolean, nil] true if accepted, false if declined/failed, nil on edge cases
      #
      # @example Give to NPC for repair
      #   DRCI.give_item?("Ragge", "sword")
      #
      # @see .accept_item?
      def give_item?(target, item = nil)
        command = item ? "give #{item_ref(item)} to #{target}" : "give #{target}"
        case DRC.bput(command, { 'timeout' => 35 }, /GIVE it again/, /give it to me again/, /^You don't need to specify the object/, /already has an outstanding offer/, GIVE_ITEM_SUCCESS_PATTERNS, GIVE_ITEM_FAILURE_PATTERNS)
        when *GIVE_ITEM_SUCCESS_PATTERNS
          true
        when *GIVE_ITEM_FAILURE_PATTERNS
          false
        when /give it to me again/
          give_item?(target, item)
        when /already has an outstanding offer/
          pause 5
          give_item?(target, item)
        when /GIVE it again/
          waitrt
          give_item?(target, item)
        when /You don't need to specify the object/
          if DRC.right_hand&.include?(item)
            give_item?(target)
          elsif DRC.left_hand&.include?(item)
            case DRC.bput('swap', *SWAP_HANDS_SUCCESS_PATTERNS, *SWAP_HANDS_FAILURE_PATTERNS)
            when *SWAP_HANDS_SUCCESS_PATTERNS
              give_item?(target)
            else
              false
            end
          end
        end
      end

      ACCEPT_SUCCESS_PATTERN = /You accept (?<name>\w+)'s offer and are now holding/.freeze

      # Accepts a pending item offer from another player.
      #
      # @return [String, false] name of the person whose offer was accepted,
      #   or false if no offer pending or hands full
      #
      # @see .give_item?
      def accept_item?
        result = DRC.bput("accept", ACCEPT_SUCCESS_PATTERN, "You have no offers", "Both of your hands are full", "would push you over your item limit")
        match = result&.match(ACCEPT_SUCCESS_PATTERN)
        match ? match[:name] : false
      end

      #########################################
      # GEM POUCH HANDLING ROUTINES
      #########################################

      # Checks if a gem pouch is already attached to the belt.
      #
      # Uses INV BELT to inspect belt contents and matches against
      # the pouch adjective and noun.
      #
      # @param gem_pouch_adjective [String] pouch adjective (e.g., "black")
      # @param gem_pouch_noun [String] pouch noun (e.g., "pouch")
      # @return [Boolean] true if a matching pouch is found on the belt
      # @api private
      def check_belt_for_pouch?(gem_pouch_adjective, gem_pouch_noun)
        belt_contents = Lich::Util.issue_command(
          "inv belt",
          INV_BELT_START_PATTERN,
          INV_BELT_END_PATTERN,
          timeout: 3,
          silent: true,
          quiet: true,
          usexml: false,
          include_end: false
        )

        return false if belt_contents.nil? || belt_contents.empty?

        pouch_pattern = /#{gem_pouch_adjective}.*gem.*#{gem_pouch_noun}/i
        belt_contents.any? { |line| line.match?(pouch_pattern) }
      end

      # Ties a gem pouch.
      #
      # @param gem_pouch_adjective [String] pouch adjective (e.g., "black")
      # @param gem_pouch_noun [String] pouch noun (e.g., "pouch")
      # @return [Boolean] true if tied successfully or already tied
      # @api private
      def tie_gem_pouch?(gem_pouch_adjective, gem_pouch_noun)
        tie_item?("#{gem_pouch_adjective} #{gem_pouch_noun}")
      end

      # @deprecated Use {.tie_gem_pouch?} instead for boolean return value.
      def tie_gem_pouch(gem_pouch_adjective, gem_pouch_noun)
        unless tie_gem_pouch?(gem_pouch_adjective, gem_pouch_noun)
          Lich::Messaging.msg("bold", "DRCI: Failed to tie #{gem_pouch_adjective} #{gem_pouch_noun}.")
        end
      end

      # Removes the current gem pouch and stows it in a container.
      #
      # @param gem_pouch_adjective [String] pouch adjective (e.g., "black")
      # @param gem_pouch_noun [String] pouch noun (e.g., "pouch")
      # @param full_pouch_container [String, nil] container for the full pouch, or nil for default
      # @return [Boolean] true if removed and stowed successfully
      # @api private
      def remove_and_stow_pouch?(gem_pouch_adjective, gem_pouch_noun, full_pouch_container = nil)
        pouch = "#{gem_pouch_adjective} #{gem_pouch_noun}"
        unless remove_item?(pouch)
          Lich::Messaging.msg("bold", "DRCI: Unable to remove existing pouch.")
          return false
        end
        put_away_item?(pouch, full_pouch_container) || stow_item?(pouch)
      end

      # Swaps a full gem pouch for a spare one.
      #
      # Removes and stows the current pouch, then checks the belt for
      # an existing spare before getting one from the spare container.
      #
      # @param gem_pouch_adjective [String] pouch adjective (e.g., "black")
      # @param gem_pouch_noun [String] pouch noun (e.g., "pouch")
      # @param full_pouch_container [String, nil] container for the full pouch
      # @param spare_gem_pouch_container [String, nil] container holding spare pouches
      # @param should_tie_gem_pouches [Boolean] whether to tie the new pouch
      # @return [Boolean] true if swap completed successfully
      def swap_out_full_gempouch?(gem_pouch_adjective, gem_pouch_noun, full_pouch_container = nil, spare_gem_pouch_container = nil, should_tie_gem_pouches = false)
        unless DRC.left_hand.nil? || DRC.right_hand.nil?
          Lich::Messaging.msg("bold", "DRCI: No free hand. Not swapping pouches now.")
          return false
        end

        unless remove_and_stow_pouch?(gem_pouch_adjective, gem_pouch_noun, full_pouch_container)
          Lich::Messaging.msg("bold", "DRCI: Remove and stow pouch routine failed.")
          return false
        end

        pouch = "#{gem_pouch_adjective} #{gem_pouch_noun}"

        # Check if there's already another pouch on the belt before getting from spare container
        if check_belt_for_pouch?(gem_pouch_adjective, gem_pouch_noun)
          Lich::Messaging.msg("plain", "DRCI: Found existing #{pouch} on belt, using that.")
          unless untie_item?(pouch)
            Lich::Messaging.msg("bold", "DRCI: Could not untie existing pouch on belt.")
            return false
          end
        elsif !get_item?(pouch, spare_gem_pouch_container)
          Lich::Messaging.msg("bold", "DRCI: No spare pouch found in #{spare_gem_pouch_container || 'default container'}.")
          return false
        end

        unless wear_item?(pouch)
          Lich::Messaging.msg("bold", "DRCI: Could not wear new pouch.")
          return false
        end

        if should_tie_gem_pouches && !tie_gem_pouch?(gem_pouch_adjective, gem_pouch_noun)
          Lich::Messaging.msg("bold", "DRCI: Could not tie new pouch.")
          # Not a fatal error - pouch is worn, just not tied
        end

        true
      end

      # Fills a gem pouch from a source container.
      #
      # Handles full pouches by swapping them out for spares via
      # {.swap_out_full_gempouch?}. Handles untied pouches by tying
      # them when requested.
      #
      # @param gem_pouch_adjective [String] pouch adjective (e.g., "black")
      # @param gem_pouch_noun [String] pouch noun (e.g., "pouch")
      # @param source_container [String] container holding gems to transfer
      # @param full_pouch_container [String, nil] container for full pouches
      # @param spare_gem_pouch_container [String, nil] container holding spare pouches
      # @param should_tie_gem_pouches [Boolean] whether to tie pouches after filling
      # @return [void]
      #
      # @example
      #   DRCI.fill_gem_pouch_with_container("black", "pouch", "lootbag",
      #     "backpack", "trunk", true)
      def fill_gem_pouch_with_container(gem_pouch_adjective, gem_pouch_noun, source_container, full_pouch_container = nil, spare_gem_pouch_container = nil, should_tie_gem_pouches = false)
        Flags.add("pouch-full", FILL_POUCH_FULL_PATTERN)
        begin
          pouch = "#{gem_pouch_adjective} #{gem_pouch_noun}"
          result = DRC.bput(
            "fill #{item_ref(pouch)} with #{item_ref(source_container)}",
            *FILL_POUCH_SUCCESS_PATTERNS,
            FILL_POUCH_FULL_PATTERN,
            *FILL_POUCH_NEEDS_TIE_PATTERNS,
            *FILL_POUCH_FAILURE_PATTERNS
          )

          case result
          when *FILL_POUCH_FAILURE_PATTERNS
            Lich::Messaging.msg("bold", "DRCI: Fill failed - #{result}")
            return
          when *FILL_POUCH_NEEDS_TIE_PATTERNS
            # Pouch needs to be tied before more gems can be added
            if should_tie_gem_pouches
              # Tie the pouch and retry
              tie_gem_pouch?(gem_pouch_adjective, gem_pouch_noun)
              return fill_gem_pouch_with_container(gem_pouch_adjective, gem_pouch_noun, source_container, full_pouch_container, spare_gem_pouch_container, should_tie_gem_pouches)
            else
              # Treat as full - swap out the pouch
              unless swap_out_full_gempouch?(gem_pouch_adjective, gem_pouch_noun, full_pouch_container, spare_gem_pouch_container, should_tie_gem_pouches)
                Lich::Messaging.msg("bold", "DRCI: Could not swap gem pouches.")
                return
              end
              return fill_gem_pouch_with_container(gem_pouch_adjective, gem_pouch_noun, source_container, full_pouch_container, spare_gem_pouch_container, should_tie_gem_pouches)
            end
          when FILL_POUCH_FULL_PATTERN
            # Pouch is full, swap it out
            unless swap_out_full_gempouch?(gem_pouch_adjective, gem_pouch_noun, full_pouch_container, spare_gem_pouch_container, should_tie_gem_pouches)
              Lich::Messaging.msg("bold", "DRCI: Could not swap gem pouches.")
              return
            end
            return fill_gem_pouch_with_container(gem_pouch_adjective, gem_pouch_noun, source_container, full_pouch_container, spare_gem_pouch_container, should_tie_gem_pouches)
          end

          # Check flag for mid-fill full pouch (when pouch fills up during the fill operation)
          if Flags["pouch-full"]
            Flags.reset("pouch-full")
            unless swap_out_full_gempouch?(gem_pouch_adjective, gem_pouch_noun, full_pouch_container, spare_gem_pouch_container, should_tie_gem_pouches)
              Lich::Messaging.msg("bold", "DRCI: Could not swap gem pouches.")
              return
            end
            return fill_gem_pouch_with_container(gem_pouch_adjective, gem_pouch_noun, source_container, full_pouch_container, spare_gem_pouch_container, should_tie_gem_pouches)
          end

          # Optionally tie the pouch after successful fill
          tie_gem_pouch?(gem_pouch_adjective, gem_pouch_noun) if should_tie_gem_pouches
        ensure
          Flags.delete("pouch-full")
        end
      end
    end
  end
end
