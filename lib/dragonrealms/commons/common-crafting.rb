# frozen_string_literal: true

module Lich
  module DragonRealms
    module DRCC
      module_function

      # Pattern constants for bput responses
      LOOK_CRUCIBLE_NOT_FOUND = '^I could not find'
      LOOK_CRUCIBLE_EMPTY = '^There is nothing in there'
      LOOK_CRUCIBLE_SEE_PATTERN = /^In the .* crucible you see (?<items>.*)\./.freeze
      LOOK_CRUCIBLE_MOLTEN = 'crucible you see some molten'

      LOOK_ANVIL_NOT_FOUND = '^I could not find'
      LOOK_ANVIL_CLEAN = 'surface looks clean and ready'
      LOOK_ANVIL_SEE_PATTERN = /anvil you see (?<items>.*)\./.freeze

      CLEAN_ANVIL_DRAG = 'You drag the'
      CLEAN_ANVIL_REMOVE = 'remove them yourself'
      GET_ANVIL_SUCCESS = 'You get'
      GET_ANVIL_NOT_YOURS = 'is not yours'
      PUT_BUCKET_SUCCESS = 'You drop'

      BOOK_CHAPTER_TURN_SUCCESS = 'You turn'
      BOOK_CHAPTER_DISTRACTED = 'You are too distracted to be doing that right now'
      BOOK_CHAPTER_ALREADY = 'The .* is already turned'
      BOOK_CHAPTER2_SUCCESS = /^You turn your .* to chapter/
      BOOK_CHAPTER2_ALREADY = /^The .* is already turned to chapter/
      BOOK_PAGE_SUCCESS = /^You turn your .* to page/
      BOOK_PAGE_ALREADY = /^You are already on page/
      BOOK_DISCIPLINE_SUCCESS = /^You turn the .* to the section on/
      BOOK_STUDY_SUCCESS = /^Roundtime/

      BELT_UNTIE_SUCCESS = /^You (remove|untie)/
      BELT_UNTIE_ALREADY = /^You are already/
      BELT_UNTIE_NOT_FOUND = /^Untie what/
      BELT_UNTIE_WOUNDED = /^Your wounds hinder your ability to do that/

      GET_CRAFTING_SUCCESS = /^You get/
      GET_CRAFTING_ALREADY = /^You are already/
      GET_CRAFTING_NOT_FOUND_WHAT = /^What do you/
      GET_CRAFTING_NOT_FOUND_WERE = /^What were you/
      GET_CRAFTING_PICKUP = /^You pick up/
      GET_CRAFTING_HEAVY = /can't quite lift it/
      GET_CRAFTING_TIED = /^You should untie/

      UNTIE_SUCCESS = /^You (remove|untie)/
      UNTIE_NOT_FOUND = /^Untie what/
      UNTIE_WOUNDED = /^Your wounds hinder your ability to do that/

      TIE_BELT_SUCCESS = 'you attach'
      TIE_BELT_WOUNDED = 'Your wounds hinder'

      PUT_BAG_TUCK = 'You tuck'
      PUT_BAG_PUT = 'You put your'
      PUT_BAG_NOT_FOUND = 'What were you referring to'
      PUT_BAG_TOO_BIG = /is too \w+ to fit/
      PUT_BAG_WEIRD = "Weirdly, you can't manage"
      PUT_BAG_NO_ROOM = "There's no room"
      PUT_BAG_CANT_THERE = "You can't put that there"
      PUT_BAG_COMBINE = 'You combine'

      # Parts that cannot be purchased from crafting shops
      PARTS_CANNOT_PURCHASE = %w[
        sufil blue\ flower muljin belradi dioica hulnik aloe eghmok
        lujeakave yelith cebi blocil hulij nuloe hisan gem pebble
        ring gwethdesuan brazier burin any ingot mechanism
      ].freeze

      REPAIR_SUCCESS = 'Roundtime'
      REPAIR_NOT_NEEDED = 'not damaged enough'
      REPAIR_ENGAGED = 'You cannot do that while engaged!'
      REPAIR_CONFUSED = 'cannot figure out how'
      REPAIR_POUR_WHAT = 'Pour what'

      CONSUMABLE_GET_SUCCESS = 'You get'
      CONSUMABLE_GET_NOT_FOUND = 'What were'
      COUNT_USES_PATTERN = /(\d+)/.freeze
      COUNT_USES_MESSAGES = [
        'The .* has (\d+) uses remaining',
        'You count out (\d+) yards of material there'
      ].freeze

      ADJUST_TONGS_SHOVEL = 'You lock the tongs'
      ADJUST_TONGS_TONGS = 'With a yank you fold the shovel'
      ADJUST_TONGS_CANNOT = 'You cannot adjust'
      ADJUST_TONGS_UNKNOWN = 'You have no idea how'

      BUNDLE_SUCCESS = 'You notate the'
      BUNDLE_EXPIRED = 'This work order has expired'
      BUNDLE_QUALITY = 'The work order requires items of a higher quality'
      BUNDLE_WRONG_TYPE = "That isn't the correct type of item for this work order."
      BUNDLE_NOT_HOLDING = 'You need to be holding'

      FOUNT_TAP_IN_BAG = /You tap .* inside your .*/
      FOUNT_TAP_ON_BAG = /You tap .*your .*/
      FOUNT_TAP_NOT_FOUND = /I could not find what you were referring to./
      FOUNT_TAP_ON_BRAZIER = /You tap .* atop a .*brazier./
      FOUNT_ANALYZE_PATTERN = /This appears to be a crafting tool and it has approximately (?<uses>\d+) uses remaining/.freeze

      BRAZIER_NOTHING = 'There is nothing on there'
      BRAZIER_SEE_PATTERN = /On the (?:.*)brazier you see (?<items>.*)\./.freeze
      BRAZIER_CLEAN_PREPARE = 'You prepare to clean off the brazier'
      BRAZIER_CLEAN_NOTHING = 'There is nothing'
      BRAZIER_CLEAN_NOT_LIT = 'The brazier is not currently lit'
      BRAZIER_CLEAN_FLAME = 'a massive ball of flame jets forward and singes everything nearby'
      BRAZIER_GET_SUCCESS = 'You get'

      RUMMAGE_NOTHING = /crafting materials but there is nothing in there like that\.$/
      RUMMAGE_CLOSED = /While it\'s closed/
      RUMMAGE_NOT_FOUND = /I don\'t know what you are referring to/
      RUMMAGE_INVISIBLE = /You feel about/
      RUMMAGE_NOTHING_ACCOMPLISH = /That would accomplish nothing/
      RUMMAGE_SUCCESS_PATTERN = /looking for crafting materials and see (?<materials>.*)\.$/

      TAP_CRUCIBLE_NOT_FOUND = 'I could not'
      TAP_CRUCIBLE_SUCCESS = /You tap.*crucible/
      TAP_ANVIL_NOT_FOUND = 'I could not'
      TAP_ANVIL_SUCCESS = /You tap.*anvil/
      TAP_GRINDSTONE_NOT_FOUND = 'I could not'
      TAP_GRINDSTONE_SUCCESS = 'You tap.*grindstone'
      TAP_GRINDER_NOT_FOUND = 'I could not'
      TAP_GRINDER_SUCCESS = 'You tap.*grinder'

      SIGIL_COUNT_NOTHING = 'but there is nothing in there like that'

      def empty_crucible?
        case result = DRC.bput('look in cruc',
                               LOOK_CRUCIBLE_NOT_FOUND,
                               LOOK_CRUCIBLE_EMPTY,
                               LOOK_CRUCIBLE_SEE_PATTERN)
        when /There is nothing in there/i
          true
        when /I could not find/
          false
        when LOOK_CRUCIBLE_MOLTEN
          fput('tilt crucible')
          fput('tilt crucible')
          return DRCC.empty_crucible?
        when /crucible you see/
          match = result.match(LOOK_CRUCIBLE_SEE_PATTERN)
          return false unless match

          clutter = match[:items]
                    .split(/(?:,|and) (?:some|an|a)/)
                    .map(&:strip)
          clutter.each do |junk|
            junk = DRC.get_noun(junk)
            DRCI.get_item_unsafe(junk, 'crucible')
            DRCI.dispose_trash(junk)
          end
          return DRCC.empty_crucible?
        else
          false
        end
      end

      def find_empty_crucible(hometown)
        return if DRC.bput('tap crucible', TAP_CRUCIBLE_NOT_FOUND, TAP_CRUCIBLE_SUCCESS) =~ TAP_CRUCIBLE_SUCCESS && (DRRoom.pcs - DRRoom.group_members).empty? && empty_crucible?

        crucibles = get_data('crafting')['blacksmithing'][hometown]['crucibles']
        idle_room = get_data('crafting')['blacksmithing'][hometown]['idle-room']
        DRCT.find_sorted_empty_room(crucibles, idle_room, proc { (DRRoom.pcs - DRRoom.group_members).empty? && empty_crucible? })
        DRCC.clean_anvil?
      end

      def clean_anvil?
        case result = DRC.bput('look on anvil', LOOK_ANVIL_NOT_FOUND, LOOK_ANVIL_CLEAN, LOOK_ANVIL_SEE_PATTERN)
        when /surface looks clean and ready/i
          true
        when /I could not find/
          false
        when /anvil you see/
          match = result.match(LOOK_ANVIL_SEE_PATTERN)
          return false unless match

          clutter = match[:items].split.last
          case DRC.bput('clean anvil', CLEAN_ANVIL_DRAG, CLEAN_ANVIL_REMOVE)
          when /drag/
            fput('clean anvil')
            pause
            waitrt?
          else
            case DRC.bput("get #{clutter} from anvil", GET_ANVIL_SUCCESS, GET_ANVIL_NOT_YOURS)
            when GET_ANVIL_NOT_YOURS
              fput('clean anvil')
              fput('clean anvil')
            when GET_ANVIL_SUCCESS
              DRC.bput("put #{clutter} in bucket", PUT_BUCKET_SUCCESS)
            else
              return false
            end
          end
          true
        else
          false
        end
      end

      def find_wheel(hometown)
        wheels = get_data('crafting')['tailoring'][hometown]['spinning-rooms']
        idle_room = get_data('crafting')['tailoring'][hometown]['idle-room']
        DRCT.find_sorted_empty_room(wheels, idle_room)
      end

      def find_anvil(hometown)
        return if DRC.bput('tap anvil', TAP_ANVIL_NOT_FOUND, TAP_ANVIL_SUCCESS) =~ TAP_ANVIL_SUCCESS && (DRRoom.pcs - DRRoom.group_members).empty? && clean_anvil?

        anvils = get_data('crafting')['blacksmithing'][hometown]['anvils']
        idle_room = get_data('crafting')['blacksmithing'][hometown]['idle-room']
        DRCT.find_sorted_empty_room(anvils, idle_room, proc { (DRRoom.pcs - DRRoom.group_members).empty? && clean_anvil? })
        DRCC.empty_crucible?
      end

      def find_grindstone(hometown)
        return unless DRC.bput('tap grindstone', TAP_GRINDSTONE_NOT_FOUND, TAP_GRINDSTONE_SUCCESS) == TAP_GRINDSTONE_NOT_FOUND

        grindstones = get_data('crafting')['blacksmithing'][hometown]['grindstones']
        idle_room = get_data('crafting')['blacksmithing'][hometown]['idle-room']
        DRCT.find_sorted_empty_room(grindstones, idle_room)
      end

      def find_sewing_room(hometown, override = nil)
        if override
          DRCT.walk_to(override)
        else
          sewingrooms = get_data('crafting')['tailoring'][hometown]['sewing-rooms']
          idle_room = get_data('crafting')['tailoring'][hometown]['idle-room']
          DRCT.find_sorted_empty_room(sewingrooms, idle_room)
        end
      end

      def find_loom_room(hometown, override = nil)
        if override
          DRCT.walk_to(override)
        else
          loom_rooms = get_data('crafting')['tailoring'][hometown]['loom-rooms']
          idle_room = get_data('crafting')['tailoring'][hometown]['idle-room']
          DRCT.find_sorted_empty_room(loom_rooms, idle_room)
        end
      end

      def find_shaping_room(hometown, override = nil)
        if override
          DRCT.walk_to(override)
        else
          shapingrooms = get_data('crafting')['shaping'][hometown]['shaping-rooms']
          idle_room = get_data('crafting')['shaping'][hometown]['idle-room']
          DRCT.find_sorted_empty_room(shapingrooms, idle_room)
        end
      end

      def find_press_grinder_room(hometown)
        return unless DRC.bput('tap grinder', TAP_GRINDER_NOT_FOUND, TAP_GRINDER_SUCCESS) == TAP_GRINDER_NOT_FOUND

        pressgrinderrooms = get_data('crafting')['remedies'][hometown]['press-grinder-rooms']
        DRCT.walk_to(pressgrinderrooms[0])
      end

      def find_enchanting_room(hometown, override = nil)
        if override
          DRCT.walk_to(override)
        else
          enchanting_rooms = get_data('crafting')['artificing'][hometown]['brazier-rooms']
          idle_room = get_data('crafting')['artificing'][hometown]['idle-room']
          DRCT.find_sorted_empty_room(enchanting_rooms, idle_room, proc { (DRRoom.pcs - DRRoom.group_members).empty? && clean_brazier? })
        end
      end

      def recipe_lookup(recipes, item_name)
        match_names = recipes.map { |x| x['name'] }.select { |x| x =~ /#{item_name}/i }
        case match_names.length
        when 0
          Lich::Messaging.msg('bold', "DRCC: No recipe in base-recipes.yaml matches #{item_name}")
          nil
        when 1
          recipes.find { |x| x['name'] =~ /#{item_name}/i }
        else
          exact_matches = recipes.map { |x| x['name'] }.select { |x| x == item_name }

          if exact_matches.length == 1
            return recipes.find { |x| x['name'] == item_name }
          end

          Lich::Messaging.msg('bold', "DRCC: Using the full name of the item you wish to craft will avoid this in the future (e.g. 'a metal pike' vs 'metal pike')")
          Lich::Messaging.msg('plain', "DRCC: Please select desired recipe #{$clean_lich_char}send #")
          match_names.each_with_index { |x, i| respond "    #{i + 1}: #{x}" }
          line = get until line.strip =~ /^(\d+)$/
          match = line.strip.match(/^(?<num>\d+)$/)
          item_name = match_names[match[:num].to_i - 1]
          recipes.find { |x| x['name'] =~ /#{item_name}/i }
        end
      end

      def find_recipe(chapter, match_string, book = 'book')
        case DRC.bput("turn my #{book} to chapter #{chapter}", BOOK_CHAPTER_TURN_SUCCESS, BOOK_CHAPTER_DISTRACTED, BOOK_CHAPTER_ALREADY)
        when BOOK_CHAPTER_DISTRACTED
          Lich::Messaging.msg('bold', 'DRCC: Cannot turn book, assuming engaged in combat.')
          fput('look')
          fput('exit')
        end

        recipe = DRC.bput("read my #{book}", "Page \\d+:\\s(?:some|a|an)?\\s*#{match_string}").split('Page').find { |x| x =~ /#{match_string}/i }
        match = recipe&.match(/(?<page>\d+):/)
        match&.[](:page)
      end

      def find_recipe2(chapter, match_string, book = 'book', discipline = nil)
        DRC.bput("turn my #{book} to discipline #{discipline}", BOOK_DISCIPLINE_SUCCESS) unless discipline.nil?
        case DRC.bput("turn my #{book} to chapter #{chapter}", BOOK_CHAPTER2_SUCCESS, BOOK_CHAPTER2_ALREADY, BOOK_CHAPTER_DISTRACTED)
        when BOOK_CHAPTER_DISTRACTED
          Lich::Messaging.msg('bold', 'DRCC: Cannot turn book, assuming engaged in combat.')
          fput('look')
          fput('exit')
        end

        recipe = DRC.bput("read my #{book}", "Page \\d+:\\s(?:some|a|an)?\\s*#{match_string}").split('Page').find { |x| x =~ /#{match_string}/i }
        match = recipe&.match(/(?<page>\d+):/)
        page = match&.[](:page)
        DRC.bput("turn my #{book} to page #{page}", BOOK_PAGE_SUCCESS, BOOK_PAGE_ALREADY)
        DRC.bput("study my #{book}", BOOK_STUDY_SUCCESS)
      end

      def get_crafting_item(name, bag, bag_items, belt, skip_exit = false)
        waitrt?
        if belt && belt['items'].find { |item| /\b#{name}/i =~ item || /\b#{item}/i =~ name }
          case DRC.bput("untie my #{name} from my #{belt['name']}", BELT_UNTIE_SUCCESS, BELT_UNTIE_ALREADY, BELT_UNTIE_NOT_FOUND, BELT_UNTIE_WOUNDED)
          when BELT_UNTIE_SUCCESS, BELT_UNTIE_ALREADY
            return
          when BELT_UNTIE_WOUNDED
            craft_room = Room.current.id
            DRC.wait_for_script_to_complete('safe-room', ['force'])
            DRCT.walk_to(craft_room)
            return get_crafting_item(name, bag, bag_items, belt)
          end
        end
        command = "get my #{name}"
        command += " from my #{bag}" if bag_items && bag_items.include?(name)
        case DRC.bput(command, GET_CRAFTING_SUCCESS, GET_CRAFTING_ALREADY, GET_CRAFTING_NOT_FOUND_WHAT, GET_CRAFTING_NOT_FOUND_WERE, GET_CRAFTING_PICKUP, GET_CRAFTING_HEAVY, GET_CRAFTING_TIED)
        when GET_CRAFTING_NOT_FOUND_WHAT, GET_CRAFTING_NOT_FOUND_WERE
          pause 2
          return if DRCI.in_hands?(name)

          DRC.beep
          Lich::Messaging.msg('bold', "DRCC: You seem to be missing: #{name}")
          return nil if skip_exit

          Lich::Messaging.msg('bold', 'DRCC: Cannot continue crafting without required item. Stopping script.')
          return nil
        when GET_CRAFTING_HEAVY
          get_crafting_item(name, bag, bag_items, belt)
        when GET_CRAFTING_TIED
          case DRC.bput("untie my #{name}", UNTIE_SUCCESS, UNTIE_NOT_FOUND, UNTIE_WOUNDED)
          when UNTIE_SUCCESS
            return
          when UNTIE_WOUNDED
            craft_room = Room.current.id
            DRC.wait_for_script_to_complete('safe-room', ['force'])
            DRCT.walk_to(craft_room)
            return get_crafting_item(name, bag, bag_items, belt)
          end
        end
      end

      def stow_crafting_item(name, bag, belt)
        return unless name

        waitrt?
        if belt && belt['items'].find { |item| /\b#{name}/i =~ item || /\b#{item}/i =~ name }
          unless DRCI.tie_item?(name, belt['name'])
            Lich::Messaging.msg('bold', "DRCC: Failed to tie #{name} to #{belt['name']}.")
            craft_room = Room.current.id
            DRC.wait_for_script_to_complete('safe-room', ['force'])
            DRCT.walk_to(craft_room)
            return stow_crafting_item(name, bag, belt)
          end
        else
          case DRC.bput("put my #{name} in my #{bag}", PUT_BAG_TUCK, PUT_BAG_PUT, PUT_BAG_NOT_FOUND, PUT_BAG_TOO_BIG, PUT_BAG_WEIRD, PUT_BAG_NO_ROOM, PUT_BAG_CANT_THERE, PUT_BAG_COMBINE)
          when PUT_BAG_TOO_BIG, PUT_BAG_WEIRD, PUT_BAG_NO_ROOM
            fput("stow my #{name}")
          when PUT_BAG_CANT_THERE
            fput("put my #{name} in my other #{bag}")
            return false
          end
        end
        true
      end

      def crafting_cost(recipe, hometown, parts, quantity, material)
        # To use this method, you'll need to pass:
        # recipe => This is a hash drawn directly from base-recipes eg {name: 'a metal ring cap', noun: 'cap', volume: 8, type: 'armorsmithing',etc}
        #     This is fetched via get_data('recipes').crafting_recipes('name')[<name of recipe>]
        # hometown => Just a string eg "Crossing"
        # parts => This is an array containing(if any) a list of parts required. Where base-recipes doesn't do this, you will need to format this.
        # quantity => an integer representing how many of each finished craft you intend to make. You can call this once per item, or once for all items.
        # material => This needs to be a hash drawn directly from base-crafting eg {stock-volume: 5, stock-number: 11, stock-name: 'bronze', stock-value: 562}
        #     This is fetched via get_data('crafting')['stock'][<name of material>]
        #     nil or false if not using stock materials

        currency = DRCM.town_currency(hometown)
        data = get_data('crafting')['stock'] # fetch parts data
        total = 0

        if material && %w[alabaster granite marble].any? { |x| material['stock-name'] == x } # stone isn't stackable, so just calculate stock*quantity
          total += material['stock-value'] * quantity
        elsif material # neither alchemy nor artificing have ONE stock material, they take various materials and combine them, so those are handled by parts below
          stock_to_order = ((recipe['volume'] / material['stock-volume'].to_f) * quantity).ceil
          total += (stock_to_order * material['stock-value'])
        end

        if parts
          parts_to_price = parts.reject { |part| PARTS_CANNOT_PURCHASE.include?(part) } # excludes things you cannot purchase, so won't error if you've got these.
          parts_to_price.each { |part| total += data[part]['stock-value'] * quantity } # adds the cost of each purchasable part to the total
        end

        total += 1000 # added to account for consumables, water, coal, etc

        case currency
        when 'kronars'
          total
        when 'lirums'
          (total * 0.800).ceil
        when 'dokoras'
          (total * 0.7216).ceil
        else
          total
        end
      end

      def repair_own_tools(info, tools, bag, bag_items, belt)
        UserVars.immune_list ||= {} # declaring a hash unless hash already
        tools = tools.to_a # Convert single tool string to array
        UserVars.immune_list.reject! { |_k, v| v < Time.now } # removing anything from the immune list that has an expired timer
        tools.reject! { |x| UserVars.immune_list[x] } # removing tools from the list of eligible repairs if they're still on the immune list
        return unless tools.size > 0 # skips the whole method if no tools are eligible for repairs

        DRCC.check_consumables('oil', info['finisher-room'], info['finisher-number'], bag, bag_items, belt, tools.size) # checks intelligently for enough oil uses to repair the number of tools eligible for repair
        DRCC.check_consumables('wire brush', info['finisher-room'], 10, bag, bag_items, belt, tools.size) # checks intelligently for enough brush uses to repair the number of tools eligible for repair
        repair_tool = ['wire brush', 'oil']
        tools.each do |tool_name| # begins repair cycle for each tool
          DRCC.get_crafting_item(tool_name, bag, bag_items, belt, true) # attempts to fetch the next tool, with the option (true) to continue if fetch fails
          next unless DRC.right_hand # if we don't get the next tool for whatever reason, we move on to the next tool.

          repair_tool.each do |x| # iterates once for each: wire brush, oil
            DRCC.get_crafting_item(x, bag, bag_items, belt)
            command = x == 'wire brush' ? "rub my #{tool_name} with my wire brush" : "pour my oil on my #{tool_name}" # changes the command based on the tool, instead of a second case statement, since it's just one of each

            case DRC.bput(command, REPAIR_SUCCESS, REPAIR_NOT_NEEDED, REPAIR_ENGAGED, REPAIR_CONFUSED, REPAIR_POUR_WHAT)
            when REPAIR_SUCCESS # successful partial repair (one brush or one oil)
              DRCC.stow_crafting_item(x, bag, belt)
              next # move to oil, or move out of loop
            when REPAIR_NOT_NEEDED # doesn't require repair, leaving loop for the next tool
              DRCC.stow_crafting_item(x, bag, belt)
              break # leave brush/oil loop and choose next tool
            when REPAIR_POUR_WHAT
              DRCC.check_consumables('oil', info['finisher-room'], info['finisher-number'], bag, bag_items, belt) # somehow ran out of oil, fetching more
              DRCC.get_crafting_item(x, bag, bag_items, belt)
              DRC.bput("pour my oil on my #{tool_name}", REPAIR_SUCCESS)
              DRCC.stow_crafting_item(x, bag, belt)
              next # oil done, next tool
            when REPAIR_ENGAGED
              Lich::Messaging.msg('bold', 'DRCC: Cannot repair in combat.')
              DRCC.stow_crafting_item(tool_name, bag, belt)
              DRCC.stow_crafting_item(x, bag, belt)
              break
            when REPAIR_CONFUSED
              Lich::Messaging.msg('bold', 'DRCC: Something has gone wrong with repair, exiting repair loop.')
              DRCC.stow_crafting_item(tool_name, bag, belt)
              DRCC.stow_crafting_item(x, bag, belt)
              break
            end
          end
          UserVars.immune_list.store(tool_name, Time.now + 7000) if Flags['proper-repair'] # if our flag picks up a Proper Forging Tool Care successful repair, we add that tool and a time of now plus 7000 seconds (just shy of 2 hours) to the list of immune tools
          Flags.reset('proper-repair')
          DRCC.stow_crafting_item(tool_name, bag, belt)
        end
        nil
      end

      def check_consumables(name, room, number, bag, bag_items, belt, count = 3)
        current = Room.current.id
        case DRC.bput("get my #{name} from my #{bag}", CONSUMABLE_GET_SUCCESS, CONSUMABLE_GET_NOT_FOUND)
        when CONSUMABLE_GET_SUCCESS
          count_result = DRC.bput("count my #{name}", *COUNT_USES_MESSAGES)
          match = count_result.match(COUNT_USES_PATTERN)
          if match && match[1].to_i < count
            DRCT.dispose(name)
            DRCC.check_consumables(name, room, number, bag, bag_items, belt, count)
          end
          DRCC.stow_crafting_item(name, bag, belt)
        else
          DRCT.order_item(room, number)
          DRCC.stow_crafting_item(name, bag, belt)
        end
        DRCT.walk_to(current)
      end

      def get_adjust_tongs?(usage, bag, bag_items, belt, adjustable_tongs = false)
        case usage
        when 'shovel' # looking for a shovel
          if @tongs_status == 'shovel' # tongs already a shovel
            DRCC.get_crafting_item('tongs', bag, bag_items, belt) unless DRCI.in_hands?('tongs') # get unless already holding
            return true # tongs previously set to shovel, in hands, adjusted to shovel.
          elsif !adjustable_tongs # determines state of tongs, works either nil or tongs
            return false # non-adjustable
          else
            DRCC.get_crafting_item('tongs', bag, bag_items, belt) unless DRCI.in_hands?('tongs') # get unless already holding

            case DRC.bput('adjust my tongs', ADJUST_TONGS_SHOVEL, ADJUST_TONGS_TONGS, ADJUST_TONGS_CANNOT, ADJUST_TONGS_UNKNOWN)
            when ADJUST_TONGS_CANNOT, ADJUST_TONGS_UNKNOWN # holding tongs, not adjustable, settings are wrong.
              Lich::Messaging.msg('bold', 'DRCC: Tongs are not adjustable. Please change yaml to reflect adjustable_tongs: false')
              DRCC.stow_crafting_item('tongs', bag, belt) # stows to make room for shovel
              return false
            when ADJUST_TONGS_TONGS # now tongs, adjust success but in wrong configuration
              DRC.bput('adjust my tongs', ADJUST_TONGS_SHOVEL) # now shovel, ready to work
              @tongs_status = 'shovel' # correcting instance variable
              return true # tongs as shovel
            when ADJUST_TONGS_SHOVEL # now shovel, adjust success
              @tongs_status = 'shovel' # setting instance variable
              return true # tongs as shovel
            end
          end

          # at this point, we either have tongs-in-shovel and a return of true, or tongs stowed(if in left hand) and a return of false

        when 'tongs' # looking for tongs
          DRCC.get_crafting_item('tongs', bag, bag_items, belt) unless DRCI.in_hands?('tongs') # get unless already holding. Here we are always getting tongs, never stowing tongs.
          if @tongs_status == 'tongs' # tongs as tongs already
            return true # tongs previously set to tongs, in hands, adjusted to tongs. this will not catch unscripted adjustments to tongs.
          elsif !adjustable_tongs # determines state of tongs, works either nil or shovel
            return false # have tongs, as tongs, but not adjustable.
          else

            case DRC.bput('adjust my tongs', ADJUST_TONGS_SHOVEL, ADJUST_TONGS_TONGS, ADJUST_TONGS_CANNOT, ADJUST_TONGS_UNKNOWN)
            when ADJUST_TONGS_CANNOT, ADJUST_TONGS_UNKNOWN # holding tongs, not adjustable, settings are wrong.
              Lich::Messaging.msg('bold', 'DRCC: Tongs are not adjustable. Please change yaml to reflect adjustable_tongs: false')
              return false # here we have tongs in hand, as tongs, but they're not adjustable, so this returns false.
            when ADJUST_TONGS_SHOVEL # now in shovel, adjust success but in wrong configuration
              DRC.bput('adjust my tongs', ADJUST_TONGS_TONGS) # now tongs, ready to work
              @tongs_status = 'tongs'
              return true # tongs as tongs AND adjustable
            when ADJUST_TONGS_TONGS # now tongs
              @tongs_status = 'tongs'
              return true # tongs as tongs AND adjustable
            end
          end

        when 'reset shovel', 'reset tongs' # Used at the top of a script, to determine state of tongs.
          @tongs_status = nil
          adjustable_tongs = true
          if usage == 'reset shovel'
            return DRCC.get_adjust_tongs?('shovel', bag, bag_items, belt, adjustable_tongs)
          elsif usage == 'reset tongs'
            return DRCC.get_adjust_tongs?('tongs', bag, bag_items, belt, adjustable_tongs)
          end
        end
      end

      def logbook_item(logbook, noun, container)
        DRCI.get_item?("#{logbook} logbook")
        bundle_result = DRC.bput("bundle my #{noun} with my logbook",
                                 BUNDLE_SUCCESS,
                                 BUNDLE_EXPIRED,
                                 BUNDLE_QUALITY,
                                 BUNDLE_WRONG_TYPE,
                                 BUNDLE_NOT_HOLDING)
        case bundle_result
        when BUNDLE_EXPIRED, BUNDLE_QUALITY, BUNDLE_WRONG_TYPE
          DRCI.dispose_trash(noun)
        when BUNDLE_NOT_HOLDING
          if DRCI.get_item?(noun, container)
            case DRC.bput("bundle my #{noun} with my logbook",
                          BUNDLE_SUCCESS,
                          BUNDLE_EXPIRED,
                          BUNDLE_QUALITY,
                          BUNDLE_WRONG_TYPE)
            when BUNDLE_EXPIRED, BUNDLE_QUALITY, BUNDLE_WRONG_TYPE
              DRCI.dispose_trash(noun)
            end
          end
        end
        DRCI.put_away_item?("#{logbook} logbook", container) || DRCI.put_away_item?("#{logbook} logbook")
      end

      def order_enchant(stock_room, stock_needed, stock_number, bag, belt)
        stock_needed.times do
          DRCT.order_item(stock_room, stock_number)
          stow_crafting_item(DRC.left_hand, bag, belt)
          stow_crafting_item(DRC.right_hand, bag, belt)
          next unless DRC.left_hand && DRC.right_hand
        end
      end

      def fount(stock_room, stock_needed, stock_number, quantity, bag, bag_items, belt)
        case DRC.bput('tap my fount', FOUNT_TAP_IN_BAG, FOUNT_TAP_ON_BAG, FOUNT_TAP_NOT_FOUND)
        when FOUNT_TAP_IN_BAG, FOUNT_TAP_ON_BAG
          analyze_result = DRC.bput('analyze my fount', FOUNT_ANALYZE_PATTERN)
          match = analyze_result.match(FOUNT_ANALYZE_PATTERN)
          if match && match[:uses].to_i < (quantity + 1)
            get_crafting_item('fount', bag, bag_items, belt)
            DRCT.dispose('fount')
            DRCI.stow_hands
            order_enchant(stock_room, stock_needed, stock_number, bag, belt)
          end
        when FOUNT_TAP_NOT_FOUND
          case DRC.bput('tap my fount on my brazier', FOUNT_TAP_ON_BRAZIER, FOUNT_TAP_NOT_FOUND)
          when FOUNT_TAP_ON_BRAZIER
            analyze_result = DRC.bput('analyze my fount on my brazier', FOUNT_ANALYZE_PATTERN)
            match = analyze_result.match(FOUNT_ANALYZE_PATTERN)
            if match && match[:uses].to_i < quantity
              DRCI.stow_hands
              order_enchant(stock_room, stock_needed, stock_number, bag, belt)
            end
          when FOUNT_TAP_NOT_FOUND
            order_enchant(stock_room, stock_needed, stock_number, bag, belt)
          end
        end
      end

      def clean_brazier?
        case DRC.bput('look on brazier', BRAZIER_NOTHING, BRAZIER_SEE_PATTERN)
        when /There is nothing on there/i
          true
        when /On the .* you see/
          case DRC.bput('clean brazier', BRAZIER_CLEAN_PREPARE, BRAZIER_CLEAN_NOTHING, BRAZIER_CLEAN_NOT_LIT)
          when BRAZIER_CLEAN_PREPARE
            DRC.bput('clean brazier', BRAZIER_CLEAN_FLAME)
          end
          empty_brazier
          true
        end
      end

      def empty_brazier
        result = DRC.bput('look on brazier', BRAZIER_SEE_PATTERN, BRAZIER_CLEAN_NOTHING)
        match = result.match(BRAZIER_SEE_PATTERN)
        return unless match

        items = match[:items]
        items = items.split(' and ')
        items.each do |item|
          item = item.split.last
          DRC.bput("get #{item} from brazier", BRAZIER_GET_SUCCESS)
          DRCT.dispose(item)
        end
      end

      def check_for_existing_sigil?(sigil, stock_number, quantity, bag, belt, info)
        merged = Regexp.union($PRIMARY_SIGILS_PATTERN, $SECONDARY_SIGILS_PATTERN)

        more = 0
        tmp_count = DRCI.count_items_in_container("#{sigil} sigil-scroll", bag).to_i

        if tmp_count >= quantity
          return true
        else
          if merged.match?("#{sigil} sigil")
            more = quantity - tmp_count
            # Found a weird challenge that made the temp_part_count equal 1 even though no "sigil" was in container
            # Check if there's really nothing in there - use bput to check for the nothing message
            nothing_result = DRC.bput("look in my #{bag}", SIGIL_COUNT_NOTHING, /.*/)
            more += 1 if nothing_result&.include?(SIGIL_COUNT_NOTHING)
            DRCC.order_enchant(info['stock-room'], more, stock_number, bag, belt)
            return true
          else
            Lich::Messaging.msg('bold', "DRCC: Not enough #{sigil} sigil-scroll(s). You can purchase or harvest #{more} more. We recommend using our sigilhunter script. Run #{$clean_lich_char}sigilhunter help for more information.")
            return false
          end
        end
      end

      def count_raw_metal(container, type = nil)
        result = DRC.bput("rummage /M #{container}", RUMMAGE_NOTHING, RUMMAGE_CLOSED, RUMMAGE_NOT_FOUND, RUMMAGE_INVISIBLE, RUMMAGE_NOTHING_ACCOMPLISH, RUMMAGE_SUCCESS_PATTERN)

        if result&.match?(RUMMAGE_NOTHING)
          Lich::Messaging.msg('bold', 'DRCC: No materials found.')
          return nil
        elsif result&.match?(RUMMAGE_CLOSED)
          return nil unless DRCI.open_container?(container)

          return count_raw_metal(container, type)
        elsif result&.match?(RUMMAGE_NOT_FOUND)
          Lich::Messaging.msg('bold', 'DRCC: Container not found.')
          return nil
        elsif result&.match?(RUMMAGE_INVISIBLE)
          Lich::Messaging.msg('bold', "DRCC: Try again when you're not invisible.")
          return nil
        end

        match = result&.match(RUMMAGE_SUCCESS_PATTERN)
        unless match
          Lich::Messaging.msg('bold', 'DRCC: Please report this error to the dev team on discord. Include a log snippet if possible.')
          return nil
        end

        h = {}
        list = match[:materials].sub(' and ', ', ').split(', ')
        list.each do |e|
          metal = e.split[2]
          volume = $VOL_MAP[e.split[1]]
          if h.key?(metal)
            h[metal][0] += volume
            h[metal][1] += 1
          else
            h[metal] = [volume, 1]
          end
        end
        h.each do |k, v|
          Lich::Messaging.msg('plain', "DRCC: #{k} - #{v[0]} volume - #{v[1]} pieces")
        end

        type.nil? ? h : h[type]
      end
    end
  end
end
