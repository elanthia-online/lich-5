# This module should be 'bottom-level' and only depend on common.
# Any modules that deal with items and <something> should be somewhere else

module Lich
  module DragonRealms
    module DRCI
      module_function

      ## How to add new trash receptacles https://github.com/elanthia-online/dr-scripts/wiki/Adding-new-trash-receptacles
      TRASH_STORAGE = %w[arms barrel basin basket bin birdbath bucket chamberpot gloop hole log puddle statue stump tangle tree turtle urn gelapod]

      DROP_TRASH_SUCCESS_PATTERNS = [
        /^You drop/,
        /^You put/,
        /^You spread .* on the ground/,
        /smashing it to bits/,
        # The next message is when item crumbles when leaves your hand, like a moonblade.
        /^As you open your hand to release the/,
        /^You toss .* at the domesticated gelapod/,
        /^You feed .* a bit warily to the domesticated gelapod/
      ]

      DROP_TRASH_FAILURE_PATTERNS = [
        /^What were you referring to/,
        /^I could not find/,
        /^But you aren't holding that/,
        /^You're kidding, right/,
        /^You can't do that/,
        /^No littering/,
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
      ]

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
      ]

      WORN_TRASHCAN_VERB_PATTERNS = [
        /^You drum your fingers/,
        /^You pull a lever/,
        /^You poke your finger around/
      ]

      GET_ITEM_SUCCESS_PATTERNS = [
        /you draw (?!\w+'s wounds)/i,
        /^You get/,
        /^You pick/,
        /^You pluck/,
        /^You slip/,
        /^You deftly remove/,
        /^You are already holding/,
        /^You fade in for a moment as you/,
        /^You carefully lift/,
        /^You carefully remove .* from the bundle/
      ]

      GET_ITEM_FAILURE_PATTERNS = [
        /^You need a free hand/,
        /^You can't pick that up with your hand that damaged/,
        /^Your (left|right) hand is too injured/,
        /^You just can't/,
        /^You stop as you realize the .* is not yours/,
        /^You can't reach that from here/, # on a mount like a flying carpet
        /^You don't seem to be able to move/,
        /^You should untie/,
        /^Get what/,
        /^I could not/,
        /^What were you/,
        /already in your inventory/, # wearing it
        /needs to be tended to be removed/, # ammo lodged in you
        /push you over the item limit/, # you're at item capacity
        /rapidly decays away/, # item disappears when try to get it
        /cracks and rots away/, # item disappears when try to get it
        /^You should stop practicing your Athletics skill before you do that/
      ]

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
        /put it on/, # weird clerical collar thing, trying to make it a bit generic
        /slide effortlessly onto your/,
        /^You carefully arrange/,
        /^A brisk chill rushes through you as you wear/, # some hiro bearskin gloves interlaced with strips of ice-veined leather
        /^You drape/,
        /You lean over and slip your feet into the boots./, # a pair of weathered barkcloth boots lined in flannel,
        /^You reach down and step into/ # pair of enaada boots clasped by asharsh'dai
      ]

      WEAR_ITEM_FAILURE_PATTERNS = [
        /^You can't wear/,
        /^You (need to|should) unload/,
        /close the fan/,
        /^You don't seem to be able to move/,
        /^Wear what/,
        /^I could not/,
        /^What were you/
      ]

      TIE_ITEM_SUCCESS_PATTERNS = [
        /^You .* tie/,
        /^You attach/,
        /^You untie/
      ]

      TIE_ITEM_FAILURE_PATTERNS = [
        /^You don't seem to be able to move/,
        /^There's no more free ties/,
        /^You must be holding/,
        /doesn't seem to fit/,
        /^You are a little too busy/,
        /^Your wounds hinder your ability to do that/,
        /^Tie what/
      ]

      UNTIE_ITEM_SUCCESS_PATTERNS = [
        /^You remove/,
        /You untie/i
      ]

      UNTIE_ITEM_FAILURE_PATTERNS = [
        /^You don't seem to be able to move/,
        /^You fumble with the ties/,
        /^Untie what/,
        /^What were you referring/
      ]

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
        /^You slam the heels/
      ]

      REMOVE_ITEM_FAILURE_PATTERNS = [
        /^You need a free hand/,
        /^You aren't wearing/,
        /^You don't seem to be able to move/,
        /^Remove what/,
        /^I could not/,
        /^What were you/
      ]

      PUT_AWAY_ITEM_SUCCESS_PATTERNS = [
        /^You put your .* in/,
        /^You hold out/,
        /^You tuck/,
        /^You open your pouch and put/,
        /^You guide your/i, # puppy storage
        /^You hang/, # frog belt
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
        /You put/i,
        /^You carefully fit .* into your bundle/,
        /^You slip/,
        /^You easily strap/,
        /^You gently set/,
        /^You toss .* into/ # You toss the alcohol into the bowl and mix it in thoroughly
      ]

      PUT_AWAY_ITEM_FAILURE_PATTERNS = [
        /^Stow what/,
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
        /even after stuffing it/,
        /is too .* to (fit|hold)/,
        /no matter how you arrange it/,
        /close the fan/,
        /to fit in the/,
        # You may get the next message if you've been cursed and unable to let go of items.
        # Find a Cleric to uncurse you.
        /Oddly, when you attempt to stash it away safely/,
        /completely full/,
        /That doesn't belong in there!/,
        /exerts a steady force preventing/
      ]

      # Messages that when trying to put away an item you're warned.
      # To continue you must retry the command.
      PUT_AWAY_ITEM_RETRY_PATTERNS = [
        # You may get the next messages when an outdated item is updated upon use.
        # "Something appears different about the <item>, perhaps try doing that again."
        # Example: https://elanthipedia.play.net/Item:Leather_lotion
        /Something appears different about/,
        /perhaps try doing that again/
      ]

      STOW_ITEM_SUCCESS_PATTERNS = [
        *GET_ITEM_SUCCESS_PATTERNS,
        *PUT_AWAY_ITEM_SUCCESS_PATTERNS
      ]

      STOW_ITEM_FAILURE_PATTERNS = [
        *GET_ITEM_FAILURE_PATTERNS,
        *PUT_AWAY_ITEM_FAILURE_PATTERNS,
      ]

      STOW_ITEM_RETRY_PATTERNS = [
        *PUT_AWAY_ITEM_RETRY_PATTERNS
      ]

      RUMMAGE_SUCCESS_PATTERNS = [
        /^You rummage through .* and see (.*)\./,
        /^In the .* you see (.*)\./,
        /there is nothing/i
      ]

      RUMMAGE_FAILURE_PATTERNS = [
        /^You don't seem to be able to move/,
        /^I could not find/,
        /^I don't know what you are referring to/,
        /^What were you referring to/
      ]

      TAP_SUCCESS_PATTERNS = [
        /^You tap\s(?!into).*/, # The `.*` is needed to capture entire phrase. Methods parse it to know if an item is worn, stowed, etc.
        /^You (thump|drum) your finger/, # You tapped an item with fancy verbiage, ohh la la!
        /^As you tap/, # As you tap a large ice-veined leather and flamewood surveyor's case
        /^The orb is delicate/, # You tapped a favor orb
        /^You .* on the shoulder/, # You tapped someone
        /^You suddenly forget what you were doing/ # "tap my tessera" messaging when hands are full
      ]

      TAP_FAILURE_PATTERNS = [
        /^You don't seem to be able to move/,
        /^I could not find/,
        /^I don't know what you are referring to/,
        /^What were you referring to/
      ]

      OPEN_CONTAINER_SUCCESS_PATTERNS = [
        /^You open/,
        /^You slowly open/,
        /^The .* opens/,
        /^You unbutton/,
        /(It's|is) already open/,
        /^You spread your arms, carefully holding your bag well away from your body/
      ]

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
      ]

      CLOSE_CONTAINER_SUCCESS_PATTERNS = [
        /^You close/,
        /^You quickly close/,
        /^You pull/,
        /is already closed/
      ]

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
      ]

      CONTAINER_IS_CLOSED_PATTERNS = [
        /^But that's closed/,
        /^That is closed/,
        /^While it's closed/
      ]

      LOWER_SUCCESS_PATTERNS = [
        /^You lower/,
        # The next message is when item crumbles when leaves your hand, like a moonblade.
        /^As you open your hand to release the/
      ]

      LOWER_FAILURE_PATTERNS = [
        /^You don't seem to be able to move/,
        /^But you aren't holding anything/,
        /^Please rephrase that command/,
        /^What were you referring to/,
        /^I could not find what you were referring to/
      ]

      LIFT_SUCCESS_PATTERNS = [
        /^You pick up/
      ]

      LIFT_FAILURE_PATTERNS = [
        /^There are no items lying at your feet/,
        /^What did you want to try and lift/,
        /can't quite lift it/,
        /^You are not strong enough to pick that up/
      ]

      GIVE_ITEM_SUCCESS_PATTERNS = [
        /has accepted your offer/,
        /your ticket and are handed back/,
        /Please don't lose this ticket!/,
        /^You hand .* gives you back a repair ticket/,
        /^You hand .* your ticket and are handed back/
      ]

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
      ]

      #########################################
      # TRASH ITEM
      #########################################

      def dispose_trash(item, worn_trashcan = nil, worn_trashcan_verb = nil)
        return unless item
        return unless DRCI.get_item_if_not_held?(item)

        if worn_trashcan
          case DRC.bput("put my #{item} in my #{worn_trashcan}", DROP_TRASH_RETRY_PATTERNS, DROP_TRASH_SUCCESS_PATTERNS, DROP_TRASH_FAILURE_PATTERNS, /^Perhaps you should be holding that first/)
          when /^Perhaps you should be holding that first/
            return (DRCI.get_item?(item) && DRCI.dispose_trash(item, worn_trashcan, worn_trashcan_verb))
          when *DROP_TRASH_RETRY_PATTERNS
            return DRCI.dispose_trash(item, worn_trashcan, worn_trashcan_verb)
          when *DROP_TRASH_SUCCESS_PATTERNS
            if worn_trashcan_verb
              DRC.bput("#{worn_trashcan_verb} my #{worn_trashcan}", *WORN_TRASHCAN_VERB_PATTERNS)
              DRC.bput("#{worn_trashcan_verb} my #{worn_trashcan}", *WORN_TRASHCAN_VERB_PATTERNS)
            end
            return true
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
            trash_command = "feed my #{item} to gelapod"
          end

          trash_command = "put my #{item} in #{trashcan}" unless trashcan == 'gelapod'

          case DRC.bput(trash_command, DROP_TRASH_SUCCESS_PATTERNS, DROP_TRASH_FAILURE_PATTERNS, DROP_TRASH_RETRY_PATTERNS, /^Perhaps you should be holding that first/)
          when /^Perhaps you should be holding that first/
            return (DRCI.get_item?(item) && DRCI.dispose_trash(item))
          when *DROP_TRASH_RETRY_PATTERNS
            # If still didn't dispose of trash after retry
            # then don't return yet, will try to drop it later.
            return true if dispose_trash(item)
          when *DROP_TRASH_SUCCESS_PATTERNS
            return true
          end
        end

        # No trash bins or not able to put item in a bin, just drop it.
        case DRC.bput("drop my #{item}", DROP_TRASH_SUCCESS_PATTERNS, DROP_TRASH_FAILURE_PATTERNS, DROP_TRASH_RETRY_PATTERNS, /^Perhaps you should be holding that first/, /^But you aren't holding that/)
        when /^Perhaps you should be holding that first/, /^But you aren't holding that/
          return (DRCI.get_item?(item) && DRCI.dispose_trash(item))
        when *DROP_TRASH_RETRY_PATTERNS
          return dispose_trash(item)
        when *DROP_TRASH_SUCCESS_PATTERNS
          return true
        else
          return false
        end
      end

      #########################################
      # SEARCH FOR ITEM
      #########################################

      def search?(item)
        /Your .* is in/ =~ DRC.bput("inv search #{item}", /^You can't seem to find anything/, /Your .* is in/)
      end

      # Taps items to check if you're wearing it.
      def wearing?(item)
        tap(item) =~ /wearing/
      end

      # Taps item to determine if it's in the given container.
      def inside?(item, container = nil)
        tap(item, container) =~ /inside/
      end

      # Taps an item to confirm it exists.
      def exists?(item, container = nil)
        case tap(item, container)
        when *TAP_SUCCESS_PATTERNS
          true
        else
          false
        end
      end

      # Taps an item and returns the match string.
      # If no container specified then generically taps whatever's in your immediate inventory.
      def tap(item, container = nil)
        return nil unless item

        from = container
        from = "from #{container}" if container && !(container =~ /^(in|on|under|behind|from) /i)
        DRC.bput("tap my #{item} #{from}", *TAP_SUCCESS_PATTERNS, *TAP_FAILURE_PATTERNS)
      end

      def in_hands?(item)
        in_hand?(item, 'either')
      end

      def in_left_hand?(item)
        in_hand?(item, 'left')
      end

      def in_right_hand?(item)
        in_hand?(item, 'right')
      end

      # Checks if the item is in one or more hands.
      # Hand options are: left, right, either, both.
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
          DRC.message("Unknown hand: #{which_hand}. Valid options are: left, right, either, both")
          false
        end
      end

      def have_item_by_look?(item, container)
        return false unless item

        item = item.delete_prefix('my ')
        preposition = 'in my' if container && !(container =~ /^((in|on|under|behind|from) )?my /i)

        case DRC.bput("look at my #{item} #{preposition} #{container}", item, /^You see nothing unusual/, /^I could not find/, /^What were you referring to/)
        when /You see nothing unusual/, item
          true
        else
          false
        end
      end

      #########################################
      # COUNT ITEMS
      #########################################

      def count_item_parts(item)
        match_messages = [
          /and see there (?:is|are) (.+) left\./,
          /There (?:is|are) (?:only )?(.+) parts? left/,
          /There's (?:only )?(.+) parts? left/,
          /The (?:.+) has (.+) uses remaining./,
          /There are enough left to create (.+) more/,
          /You count out (.+) pieces? of material there/,
          /There (?:is|are) (.+) scrolls? left for use with crafting/
        ]
        count = 0
        $ORDINALS.each do |ordinal|
          case DRC.bput("count my #{ordinal} #{item}",
                        'I could not find what you were referring to.',
                        'tell you much of anything.',
                        *match_messages)
          when 'I could not find what you were referring to.'
            break
          when 'tell you much of anything.'
            echo "ERROR: count_item_parts called on non-stackable item: #{item}"
            count = count_items(item)
            break
          when *match_messages
            countval = Regexp.last_match(1).tr('-', ' ')
            if countval.match?(/\A\d+\z/)
              count += Integer(countval)
            else
              count += DRC.text2num(countval)
            end
          end
          waitrt?
        end
        count
      end

      # Counts items in a container that is inferred by first tapping the item.
      # If you want to count items in a specific container, use `count_items_in_container(item, container)`
      def count_items(item)
        /inside your (.*)/ =~ tap(item)
        container = Regexp.last_match(1)
        return 0 if container.nil?

        count_items_in_container(item, container)
      end

      # Counts items in a container.
      # If you don't know which container the items are in, use `count_items(item)` to infer it.
      def count_items_in_container(item, container)
        contents = DRC.bput("rummage /C #{item.split.last} in my #{container}", /^You rummage .*/, /That would accomplish nothing/)
        # This regexp avoids counting the quoted item name in the message, as
        # well as avoiding finding the item as a substring of other items.
        contents.scan(/ #{item}\W/).size
      end

      # Identifies how many more lockpicks that the container can hold.
      # Designed to work on lockpick stackers.
      # https://elanthipedia.play.net/Lockpick_rings
      def count_lockpick_container(container)
        count = DRC.bput("appraise my #{container} quick", /it appears to be full/, /it might hold an additional \d+/, /\d+ lockpicks would probably fit/).scan(/\d+/).first.to_i
        waitrt?
        count
      end

      def get_box_list_in_container(container)
        DRC.rummage('B', container)
      end

      def get_scroll_list_in_container(container)
        DRC.rummage('SC', container)
      end

      # Takes in the noun of the configured necro material stacker, and returns the current material item count.
      def count_necro_stacker(necro_stacker)
        DRC.bput("study my #{necro_stacker}", /currently holds \d+ items/).scan(/\d+/).first.to_i
      end

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

      def stow_hands
        (!DRC.left_hand || stow_hand('left')) &&
          (!DRC.right_hand || stow_hand('right'))
      end

      def stow_hand(hand)
        braid_regex = /The braided (.+) is too long/
        case DRC.bput("stow #{hand}", braid_regex, CONTAINER_IS_CLOSED_PATTERNS, STOW_ITEM_SUCCESS_PATTERNS, STOW_ITEM_FAILURE_PATTERNS, STOW_ITEM_RETRY_PATTERNS)
        when braid_regex
          dispose_trash(DRC.get_noun(Regexp.last_match(1)))
        when *STOW_ITEM_RETRY_PATTERNS
          stow_hand(hand)
        when *STOW_ITEM_SUCCESS_PATTERNS
          true
        else
          false
        end
      end

      #########################################
      # GET ITEM
      #########################################

      # Gets an item unless you are already hold it.
      # Use this method to avoid having two of an item
      # in your hands when you only want one.
      #
      # Returns true if the item is in your hand
      # or we were able to get it to your hand.
      def get_item_if_not_held?(item, container = nil)
        return false unless item
        return true if in_hands?(item)

        return get_item(item, container)
      end

      # Provide a predicate-named method to follow convention.
      def get_item?(item, container = nil)
        get_item(item, container)
      end

      # Gets an item, optionally from a specific container.
      # If no container specified then generically grabs from the room/your person.
      # Can provide an array of containers to try, too, in case some might be empty.
      def get_item(item, container = nil)
        if container.is_a?(Array)
          container.each do |c|
            return true if get_item_safe(item, c)
          end
          return false
        end
        get_item_safe(item, container)
      end

      # Same as 'get_item_unsafe' but ensures that
      # the container argument is prefixed with 'my' qualifier.
      def get_item_safe?(item, container = nil)
        item = "my #{item}" if item && !(item =~ /^my /i)
        container = "my #{container}" if container && !(container =~ /^((in|on|under|behind|from) )?my /i)
        get_item_unsafe(item, container)
      end

      def get_item_safe(item, container = nil)
        get_item_safe?(item, container)
      end

      # Gets an item, optionally from a specific container.
      # If no container specified then generically grabs from the room/your person.
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

      # Workaround to game changes where you must periodically look in
      # the portal for the contents to be available.
      # http://forums.play.net/forums/DragonRealms/Discussions%20with%20DragonRealms%20Staff%20and%20Players/Game%20Master%20and%20Official%20Announcements/view/1899
      def get_item_from_eddy_portal?(item, container)
        # Ensure the eddy is open then look in it to force the contents to be loaded.
        return false unless DRCI.open_container?('my eddy') && DRCI.look_in_container(container)

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

      def tie_item?(item, container)
        case DRC.bput("tie my #{item} to my #{container}", TIE_ITEM_SUCCESS_PATTERNS, TIE_ITEM_FAILURE_PATTERNS)
        when *TIE_ITEM_SUCCESS_PATTERNS
          true
        else
          false
        end
      end

      def untie_item?(item, container = nil)
        place = container ? "from my #{container}" : nil
        case DRC.bput("untie my #{item} #{place}", UNTIE_ITEM_SUCCESS_PATTERNS, UNTIE_ITEM_FAILURE_PATTERNS)
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
      def wear_item?(item)
        wear_item_safe?(item)
      end

      # Same as 'wear_item_unsafe?' but ensures that
      # the item name is prefixed with 'my' qualifier.
      def wear_item_safe?(item)
        item = "my #{item}" if item && !(item =~ /^my /i)
        wear_item_unsafe?(item)
      end

      # Wears an item from your hands.
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

      # Removes an item you're wearing.
      def remove_item?(item)
        remove_item_safe?(item)
      end

      # Same as 'remove_item_unsafe?' but ensures that
      # the item name is prefixed with 'my' qualifier.
      def remove_item_safe?(item)
        item = "my #{item}" if item && !(item =~ /^my /i)
        remove_item_unsafe?(item)
      end

      # Removes an item you're wearing.
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

      # Stows an item into its default container. See STORE HELP for details.
      # Same as 'stow_item_safe?'.
      def stow_item?(item)
        stow_item_safe?(item)
      end

      # Stows an item into its default container. See STORE HELP for details.
      # Same as 'stow_item_unsafe?' but ensures that
      # the item argument is prefixed with 'my '.
      def stow_item_safe?(item)
        item = "my #{item}" if item && !(item =~ /^my /i)
        stow_item_unsafe?(item)
      end

      # Stows an item into its default container. See STORE HELP for details.
      # Unless you include the 'my ' prefix in the item then this may
      # try to stow an item on the ground rather than something in your inventory.
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

      # Lowers the item to the ground.
      # Determines which hand is holding the item then lowers it to your feet slot.
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

      ## Implementing a suggestion by Gildaren for a simple predicate method
      ## You can pass this only an item and it will attempt to lift that item and return true/false
      ## You can pass this both an item and true and it will lift that item and return the result of stow_item? on that item
      ## You can pass this both an item and the name of a container and return the result of put_away_item? on that item and that container
      def lift?(item = nil, stow = nil)
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

      # Checks if the container is empty.
      # Returns true if certain the container is empty.
      # Returns false if certain the container is not empty.
      # Returns nil if unable to determine either way (e.g. can't open container or look in it).
      def container_is_empty?(container)
        look_in_container(container).empty?
      end

      # Returns a list of item descriptions from the `INVENTORY <type|slot>` verb output.
      # Where <type> can be armor, weapon, fluff, container, or combat.
      # Where <slot> can be any phrase from INV SLOTS LIST command.
      def get_inventory_by_type(type = 'combat', line_count = 40)
        case DRC.bput("inventory #{type}", /Use INVENTORY HELP for more options/, /The INVENTORY command is the best way/, /You can't do that/)
        when /The INVENTORY command is the best way/, /You can't do that/
          DRC.message("Unrecognized inventory type: #{type}. Valid options are ARMOR, WEAPON, FLUFF, CONTAINER, COMBAT, or any slot from INVENTORY SLOTS LIST.")
          return []
        end
        # Multiple lines may have been printed to the game window,
        # grab the last several lines for analysis.
        snapshot = reget(line_count)
        # Unless you're looking for items at your feet, this is noise.
        items_at_feet = snapshot.grep(/(^Lying at your feet)/).any?
        # If the snapshot found all the inventory then begin processing.
        if snapshot.grep(/^All of your (#{type}|items)|^You aren't wearing anything like that|Both of your hands are empty/).any? && snapshot.grep(/Use INVENTORY HELP/).any?
          snapshot
            .map(&:strip)
            .reverse
            .take_while { |line| [/^All of your (#{type}|items)/, /^You aren't wearing anything like that/, /Both of your hands are empty/].none? { |phrase| phrase =~ line } }
            .drop_while { |line| !line.start_with?('[Use INVENTORY HELP for more options.]') }
            .drop(1)
            .reverse
            .take_while { |line| !items_at_feet || !line.start_with?('Lying at your feet') }
            .map { |item| item.gsub(/^(a|an|some)\s+/, '').gsub(/\s+\(closed\)/, '') }
        else
          # Otherwise, retry the command. Other actions may have flooded the game window.
          get_inventory_by_type(type, line_count + 40)
        end
      end

      # Gets a list of items found in a container via RUMMAGE or LOOK.
      # Default is 'rummage' which returns the full item tap descriptions (e.g. some grey ice skates with black laces)
      # You can pass in 'LOOK' to get back the short item names, which is easier to parse to know the adjective and noun (e.g. some grey ice skates)
      def get_item_list(container, verb = 'rummage')
        case verb
        when /^(r|rummage)$/i
          rummage_container(container)
        when /^(l|look)$/i
          look_in_container(container)
        end
      end

      # Gets a list of items by RUMMAGE the container.
      # Returns a list (empty or otherwise) if able to rummage the container.
      # Returns nil if unable to determine if container's contents (e.g. can't open it or rummage it).
      def rummage_container(container)
        container = "my #{container}" unless container.nil? || container =~ /^my /i
        contents = DRC.bput("rummage #{container}", CONTAINER_IS_CLOSED_PATTERNS, RUMMAGE_SUCCESS_PATTERNS, RUMMAGE_FAILURE_PATTERNS)
        case contents
        when *RUMMAGE_FAILURE_PATTERNS
          return nil
        when *CONTAINER_IS_CLOSED_PATTERNS
          return nil unless open_container?(container)

          rummage_container(container)
        else
          contents
            .match(/You rummage through .* and see (?:a|an|some) (?<items>.*)\./)[:items] # Get string of just the comma separated item list
            .sub(/ and (?=a|an|some)/, ", ") # replace " and " for the last item into " , "
            .split(/, (?:a|an|some) /) # Split at a, an, or some, but only when it follows a comma
        end
      end

      # Gets a list of items by LOOK in the container.
      # Returns a list (empty or otherwise) if able to look in the container.
      # Returns nil if unable to determine if container's contents (e.g. can't open it or look in it).
      def look_in_container(container)
        container = "my #{container}" unless container.nil? || container =~ /^my /i
        contents = DRC.bput("look in #{container}", CONTAINER_IS_CLOSED_PATTERNS, RUMMAGE_SUCCESS_PATTERNS, RUMMAGE_FAILURE_PATTERNS)
        case contents
        when *RUMMAGE_FAILURE_PATTERNS
          return nil
        when *CONTAINER_IS_CLOSED_PATTERNS
          return nil unless open_container?(container)

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

      # Puts away an item, optionally into a specific container.
      # If no container specified then uses the default stow location.
      # Can provide an array of containers to try, too, in case some might be full.
      def put_away_item?(item, container = nil)
        if container.is_a?(Array)
          container.each do |c|
            return true if put_away_item_safe?(item, c)
          end
          return false
        end
        put_away_item_safe?(item, container)
      end

      # Same as 'put_away_item_unsafe?' but ensures that
      # the container argument is prefixed with 'my' qualifier.
      def put_away_item_safe?(item, container = nil)
        item = "my #{item}" if item && !(item =~ /^my /i)
        container = "my #{container}" unless container.nil? || container =~ /^my /i
        put_away_item_unsafe?(item, container)
      end

      # Puts away an item, optionally into a specific container, optionally
      # using a container preposition (e.g. "ON shelf")
      # If no container specified then uses the default stow location.
      # If no preposition specified, defaults to "in" (e.g. "IN cabinet")
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

      def open_container?(container)
        case DRC.bput("open #{container}", OPEN_CONTAINER_SUCCESS_PATTERNS, OPEN_CONTAINER_FAILURE_PATTERNS)
        when *OPEN_CONTAINER_SUCCESS_PATTERNS
          return true
        end
        return false
      end

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

      def give_item?(target, item = nil)
        command = item ? "give my #{item} to #{target}" : "give #{target}"
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
          if DRC.right_hand.include?(item)
            give_item?(target)
          elsif DRC.left_hand.include?(item)
            fput("swap")
            give_item?(target)
          end
        end
      end

      # If you accept then returns the name of the person whose offer you accepted. This serves as a "truthy" value, too.
      # If you don't, or aren't able to, accept then returns false.
      def accept_item?
        case DRC.bput("accept", "You accept .* offer and are now holding", "You have no offers", "Both of your hands are full", "would push you over your item limit")
        when /You accept (?<name>\w+)'s offer and are now holding/
          Regexp.last_match[:name]
        else
          false
        end
      end

      #########################################
      # GEM POUCH HANDLING ROUTINES
      #########################################
      def swap_out_full_gempouch?(gem_pouch_adjective, gem_pouch_noun, full_pouch_container = nil, spare_gem_pouch_container = nil, should_tie_gem_pouches = false)
        unless DRC.left_hand.nil? || DRC.right_hand.nil?
          DRC.message("No free hand. Not swapping pouches now.")
          return false
        end

        unless remove_and_stow_pouch?(gem_pouch_adjective, gem_pouch_noun, full_pouch_container)
          DRC.message("Remove and stow pouch routine failed.")
          return false
        end

        unless get_item?("#{gem_pouch_adjective} #{gem_pouch_noun}", spare_gem_pouch_container)
          DRC.message("No spare pouch found.")
          return false
        end

        unless wear_item?("#{gem_pouch_adjective} #{gem_pouch_noun}")
          DRC.message("Could not wear new pouch.")
          return false
        end

        tie_gem_pouch(gem_pouch_adjective, gem_pouch_noun) if should_tie_gem_pouches

        return true
      end

      def remove_and_stow_pouch?(gem_pouch_adjective, gem_pouch_noun, full_pouch_container = nil)
        unless remove_item?("#{gem_pouch_adjective} #{gem_pouch_noun}")
          DRC.message("Unable to remove existing pouch.")
          return false
        end
        if put_away_item?("#{gem_pouch_adjective} #{gem_pouch_noun}", full_pouch_container)
          return true
        elsif stow_item?("#{gem_pouch_adjective} #{gem_pouch_noun}")
          return true
        else
          return false
        end
      end

      def tie_gem_pouch(gem_pouch_adjective, gem_pouch_noun)
        DRC.bput("tie my #{gem_pouch_adjective} #{gem_pouch_noun}", 'you tie', "it's empty?", 'has already been tied off')
      end

      def fill_gem_pouch_with_container(gem_pouch_adjective, gem_pouch_noun, source_container, full_pouch_container = nil, spare_gem_pouch_container = nil, should_tie_gem_pouches = false)
        Flags.add("pouch-full", /is too full to fit any more/)
        case DRC.bput("fill my #{gem_pouch_adjective} #{gem_pouch_noun} with my #{source_container}",
                      /^You open/,
                      /is too full to fit/,
                      /^You'd better tie it up before putting/,
                      /You'll need to tie it up before/,
                      /Please rephrase that command/,
                      'What were you referring to',
                      "There aren't any gems",
                      'You fill your')
        when /Please rephrase that command/
          DRC.message("Container #{source_container} not found. Skipping fill")
          return
        when /^You'd better tie it up before putting/, /You'll need to tie it up before/
          # This is equivalent to a full pouch, unless we should tie pouches, in which case we tie and retry
          unless should_tie_gem_pouches
            unless swap_out_full_gempouch?(gem_pouch_adjective, gem_pouch_noun, full_pouch_container, spare_gem_pouch_container, should_tie_gem_pouches)
              DRC.message("Could not swap gem pouches.")
              return
            end
            fill_gem_pouch_with_container(gem_pouch_adjective, gem_pouch_noun, source_container, full_pouch_container, spare_gem_pouch_container, should_tie_gem_pouches)
          end
          tie_gem_pouch(gem_pouch_adjective, gem_pouch_noun) if should_tie_gem_pouches
          fill_gem_pouch_with_container(gem_pouch_adjective, gem_pouch_noun, source_container, full_pouch_container, spare_gem_pouch_container, should_tie_gem_pouches)
        end
        if Flags["pouch-full"]
          unless swap_out_full_gempouch?(gem_pouch_adjective, gem_pouch_noun, full_pouch_container, spare_gem_pouch_container, should_tie_gem_pouches)
            DRC.message("Could not swap gem pouches.")
            return
          end
          fill_gem_pouch_with_container(gem_pouch_adjective, gem_pouch_noun, source_container, full_pouch_container, spare_gem_pouch_container, should_tie_gem_pouches)
          tie_gem_pouch(gem_pouch_adjective, gem_pouch_noun) if should_tie_gem_pouches
          Flags.reset("pouch-full")
        end
      end
    end
  end
end
