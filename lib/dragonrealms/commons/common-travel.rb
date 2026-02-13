# frozen_string_literal: true

module Lich
  module DragonRealms
    module DRCT
      module_function

      DIRECTION_REVERSE = {
        'northeast' => 'southwest',
        'southwest' => 'northeast',
        'northwest' => 'southeast',
        'southeast' => 'northwest',
        'north'     => 'south',
        'south'     => 'north',
        'east'      => 'west',
        'west'      => 'east',
        'up'        => 'down',
        'down'      => 'up'
      }.each_value(&:freeze).freeze unless defined?(DIRECTION_REVERSE)

      SELL_SUCCESS_PATTERNS = [
        /hands? you \d+ (?:kronars|lirums|dokoras)/i
      ].each(&:freeze).freeze unless defined?(SELL_SUCCESS_PATTERNS)

      SELL_FAILURE_PATTERNS = [
        /I need to examine the merchandise first/,
        /That's not worth anything/,
        /I only deal in pelts/,
        /There's folk around here that'd slit a throat for this/
      ].each(&:freeze).freeze unless defined?(SELL_FAILURE_PATTERNS)

      BUY_PRICE_PATTERNS = [
        /prepared to offer it to you for (?<amount>.*) (?:kronar|lirum|dokora)s?/,
        /Let me but ask the humble sum of (?<amount>.*) coins/,
        /it would be just (?<amount>\d*) (?:kronar|lirum|dokora)s?/,
        /for a (?:mere )?(?<amount>\d*) (?:kronar|lirum|dokora)s?/,
        /I can let that go for\.\.\.(?<amount>.*) (?:kronar|lirum|dokora)s?/,
        /cost you (?:just )?(?<amount>.*) (?:kronar|lirum|dokora)s?/,
        /it may be yours for just (?<amount>.*) (?:kronar|lirum|dokora)s?/,
        /I'll give that to you for (?<amount>.*) (?:kronar|lirum|dokora)s?/,
        /I'll let you have it for (?<amount>.*) (?:kronar|lirum|dokora)s?/i,
        /I ask that you give (?<amount>.*) copper (?:kronar|lirum|dokora)s?/,
        /it'll be (?<amount>.*) (?:kronar|lirum|dokora)s?/,
        /the price of (?<amount>.*) coins? is all I ask/,
        /tis only (?<amount>.*) (?:kronar|lirum|dokora)s?/,
        /That will be (?<amount>.*) copper (?:kronar|lirum|dokora)s? please/,
        /That'll be (?<amount>.*) copper (?:kronar|lirum|dokora)s?/,
        /to you for (?<amount>.*) (?:kronar|lirum|dokora)s?/,
        /I ask (?<amount>.*) copper (?:kronar|lirum|dokora)s or if you would prefer/,
        /Cost you just (?<amount>.*) (?:kronar|lirum|dokora)s?, okie dokie\?/i,
        /It will cost just (?<amount>.*) (?:kronar|lirum|dokora)s?/i,
        /I would suggest (?<amount>.*) (?:kronar|lirum|dokora)s?/i,
        /to you for (?<amount>.*) (?:kronar|lirum|dokora)s?/i,
        /asking (?<amount>.*) (?:kronar|lirum|dokora)s?/i
      ].each(&:freeze).freeze unless defined?(BUY_PRICE_PATTERNS)

      BUY_NON_PRICE_PATTERNS = [
        'You decide to purchase',
        'Buy what'
      ].each(&:freeze).freeze unless defined?(BUY_NON_PRICE_PATTERNS)

      ASK_SUCCESS_PATTERNS = [
        /hands you/
      ].each(&:freeze).freeze unless defined?(ASK_SUCCESS_PATTERNS)

      ASK_FAILURE_PATTERNS = [
        /does not seem to know anything about that/,
        /All I know about/,
        /To whom are you speaking/,
        /Usage: ASK/
      ].each(&:freeze).freeze unless defined?(ASK_FAILURE_PATTERNS)

      # Visit a merchant and sell an item.
      # Usually to sell junk at pawn shops.
      def sell_item(room, item)
        return false unless DRCI.in_hands?(item)

        walk_to(room)

        case DRC.bput("sell my #{item}", *SELL_SUCCESS_PATTERNS, *SELL_FAILURE_PATTERNS)
        when *SELL_SUCCESS_PATTERNS
          true
        when *SELL_FAILURE_PATTERNS
          false
        end
      end

      # Visit a merchant and buy an item by offering their asking price.
      # Usually for restocking ammunition or other misc items.
      def buy_item(room, item)
        walk_to(room)

        all_patterns = BUY_PRICE_PATTERNS + BUY_NON_PRICE_PATTERNS
        result = DRC.bput("buy #{item}", *all_patterns)

        match_data = BUY_PRICE_PATTERNS.lazy.filter_map { |p| p.match(result) }.first
        amount = match_data[:amount] if match_data

        fput("offer #{amount}") if amount
      end

      # Visit a merchant and ask for an item.
      # Usually this is for bundling ropes or gem pouches.
      def ask_for_item?(room, name, item)
        walk_to(room)

        case DRC.bput("ask #{name} for #{item}", *ASK_SUCCESS_PATTERNS, *ASK_FAILURE_PATTERNS)
        when *ASK_SUCCESS_PATTERNS
          true
        else
          false
        end
      end

      # Visit a merchant and order from a menu.
      def order_item(room, item_number)
        walk_to(room)

        return if DRC.bput("order #{item_number}", 'Just order it again', 'you don\'t have enough coins') == 'you don\'t have enough coins'

        DRC.bput("order #{item_number}", 'takes some coins from you')
      end

      def dispose(item, trash_room = nil, worn_trashcan = nil, worn_trashcan_verb = nil)
        return unless item

        DRCT.walk_to(trash_room) unless trash_room.nil?
        DRCI.dispose_trash(item, worn_trashcan, worn_trashcan_verb)
      end

      def refill_lockpick_container(lockpick_type, hometown, container, count)
        return if count < 1

        room = get_data('town')[hometown]['locksmithing']['id']

        if room.nil?
          Lich::Messaging.msg('bold', 'DRCT: No locksmith location found for current hometown. Skipping refilling.')
          return
        end

        walk_to(room)
        if Room.current.id != room
          Lich::Messaging.msg('bold', 'DRCT: Could not reach locksmith location. Skipping refilling.')
          return
        end

        count.times do
          buy_item(room, "#{lockpick_type} lockpick")
          unless DRCI.put_away_item_unsafe?('my lockpick', "my #{container}", 'on')
            Lich::Messaging.msg('bold', "DRCT: Failed to put lockpick on #{container}. Check your lockpick settings — mixing types in a container is not allowed.")
            break
          end
        end

        # Be polite to Thieves, who need the room to be empty
        DRC.fix_standing
        move('out') if XMLData.room_exits.include?('out')
      end

      def walk_to(target_room, restart_on_fail = true)
        target_room = tag_to_id(target_room) if target_room.is_a?(String) && target_room.count("a-zA-Z") > 0

        return false if target_room.nil?

        room_num = target_room.to_i
        return true if room_num == Room.current.id

        DRC.fix_standing

        if Room.current.id.nil?
          Lich::Messaging.msg('plain', "DRCT: In an unknown room, manually attempting to navigate to #{room_num}")
          rooms = Map.list.select { |room| room.description.include?(XMLData.room_description.strip) && room.title.include?(XMLData.room_title) }
          if rooms.empty? || rooms.length > 1
            Lich::Messaging.msg('bold', 'DRCT: Failed to find a matching room from unknown location.')
            return false
          end
          room = rooms.first
          return true if room_num == room.id

          if room.wayto[room_num.to_s]
            move room.wayto[room_num.to_s]
            return room_num == room.id
          end
          path = Map.findpath(room, Map[room_num])
          way = room.wayto[path.first.to_s]
          if way.is_a?(StringProc)
            way.call
          else
            move way
          end
          return walk_to(room_num)
        end

        script_handle = start_script('go2', [room_num.to_s], force: true)

        timer = Time.now
        prev_room = XMLData.room_description + XMLData.room_title

        Flags.add('travel-closed-shop', 'The door is locked up tightly for the night', 'You smash your nose', '^A servant (blocks|stops)')
        Flags.add('travel-engaged', 'You are engaged')

        begin
          while Script.running.include?(script_handle)
            if Flags['travel-closed-shop']
              Flags.reset('travel-closed-shop')
              kill_script(script_handle)
              if /You open/ !~ DRC.bput('open door', 'It is locked', 'You .+', 'What were')
                restart_on_fail = false
                break
              end
              timer = Time.now
              script_handle = start_script('go2', [room_num.to_s])
            end
            if Flags['travel-engaged']
              Flags.reset('travel-engaged')
              kill_script(script_handle)
              DRC.retreat
              timer = Time.now
              script_handle = start_script('go2', [room_num.to_s])
            end
            if (Time.now - timer) > 90
              kill_script(script_handle)
              pause 0.5 while Script.running.include?(script_handle)
              break unless restart_on_fail

              timer = Time.now
              script_handle = start_script('go2', [room_num.to_s])
            end
            if Script.running?('escort') || Script.running?('bescort') || (XMLData.room_description + XMLData.room_title) != prev_room || XMLData.room_description =~ /The terrain constantly changes as you travel along on your journey/
              timer = Time.now
            end
            prev_room = XMLData.room_description + XMLData.room_title
            pause 0.5
          end
        ensure
          Flags.delete('travel-closed-shop')
          Flags.delete('travel-engaged')
        end

        if room_num != Room.current.id && restart_on_fail
          Lich::Messaging.msg('bold', "DRCT: Failed to navigate to room #{room_num}, attempting again.")
          walk_to(room_num)
        end
        room_num == Room.current.id
      end

      def tag_to_id(target)
        start_room = Room.current.id
        target_list = Map.list.find_all { |room| room.tags.include?(target) }.collect { |room| room.id }

        if target_list.empty?
          Lich::Messaging.msg('bold', "DRCT: No go2 targets matching '#{target}' found.")
          return nil
        end

        if target_list.include?(start_room)
          Lich::Messaging.msg('plain', "DRCT: You're already here.")
          return start_room
        end
        _previous, shortest_distances = Room.current.dijkstra(target_list)
        target_list.delete_if { |room_id| shortest_distances[room_id].nil? }
        if target_list.empty?
          Lich::Messaging.msg('bold', "DRCT: Couldn't find a path from here to any room with a '#{target}' tag.")
          return nil
        end

        target_id = target_list.sort { |a, b| shortest_distances[a] <=> shortest_distances[b] }.first
        unless target_id && (destination = Map[target_id])
          Lich::Messaging.msg('bold', "DRCT: Something went wrong! Debug failed with target_id=#{target_id}, destination=#{destination}, tag='#{target}'.")
          return nil
        end
        target_id
      end

      def retreat(ignored_npcs = [])
        return if (DRRoom.npcs - ignored_npcs).empty?

        DRC.retreat(ignored_npcs)
      end

      def find_empty_room(search_rooms, idle_room, predicate = nil, min_mana = 0, strict_mana = false, max_search_attempts = Float::INFINITY, prioritize_buddies = false)
        search_attempt = 0
        check_mana = min_mana > 0
        rooms_searched = 0
        loop do
          search_attempt += 1
          Lich::Messaging.msg('plain', "DRCT: Search attempt #{search_attempt} of #{max_search_attempts} to find a suitable room.")
          found_empty = false
          search_rooms.each do |room_id|
            walk_to(room_id)
            pause 0.1 until room_id == Room.current.id

            rooms_searched += 1

            if prioritize_buddies && (rooms_searched <= search_rooms.size)
              suitable_room = ((DRRoom.pcs & UserVars.friends).any? && (DRRoom.pcs & UserVars.hunting_nemesis).none?)
              if rooms_searched == search_rooms.size && (DRRoom.pcs & UserVars.friends).empty? && (DRRoom.pcs & UserVars.hunting_nemesis).empty?
                Lich::Messaging.msg('plain', 'DRCT: Reached last room in list, and found no buddies. Retrying for empty room.')
                return find_empty_room(search_rooms, idle_room, predicate, min_mana, strict_mana, max_search_attempts, false)
              end
            else
              suitable_room = predicate ? predicate.call(search_attempt) : (DRRoom.pcs - DRRoom.group_members).empty?
            end
            if suitable_room && check_mana && !(DRStats.moon_mage? || DRStats.trader?)
              found_empty = true
              suitable_room = (DRCA.perc_mana >= min_mana)
            end
            return true if suitable_room
          end

          if found_empty && check_mana && !strict_mana
            check_mana = false
            Lich::Messaging.msg('plain', 'DRCT: Empty rooms found, but not with the right mana. Going to use those anyway.')
            next
          end

          check_mana = min_mana > 0

          if idle_room && search_attempt < max_search_attempts
            idle_room = idle_room.sample if idle_room.is_a?(Array)
            walk_to(idle_room)
            wait_time = rand(20..40)
            Lich::Messaging.msg('plain', "DRCT: Failed to find an empty room, pausing #{wait_time} seconds.")
            pause wait_time
          else
            Lich::Messaging.msg('plain', 'DRCT: Failed to find an empty room, stopping the search.')
            return false
          end
        end
      end

      def sort_destinations(target_list)
        target_list = target_list.collect(&:to_i)
        _previous, shortest_distances = Map.dijkstra(Room.current.id)
        target_list.delete_if { |room_num| shortest_distances[room_num].nil? && room_num != Room.current.id }
        target_list.sort { |a, b| shortest_distances[a] <=> shortest_distances[b] }
      end

      def find_sorted_empty_room(search_rooms, idle_room, predicate = nil)
        sorted_rooms = sort_destinations(search_rooms)
        find_empty_room(sorted_rooms, idle_room, predicate)
      end

      def time_to_room(origin, destination)
        _previous, shortest_paths = Map.dijkstra(origin, destination)
        shortest_paths[destination]
      end

      def reverse_path(path)
        path.reverse.map do |dir|
          reversed = DIRECTION_REVERSE[dir]
          unless reversed
            Lich::Messaging.msg('bold', "DRCT: No reverse direction found for '#{dir}'. Use full direction names (e.g., 'northeast' not 'ne'). Path must be an array.")
            return nil
          end
          reversed
        end
      end

      def get_hometown_target_id(hometown, target)
        hometown_data = get_data('town')[hometown]
        target_id = hometown_data[target] && hometown_data[target]['id']
        unless target_id
          Lich::Messaging.msg('plain', "DRCT: get_hometown_target_id failed first attempt for #{target} in #{hometown}. Trying again.") if $common_travel_debug
          pause 2
          hometown_data = get_data('town')[hometown]
          target_id = hometown_data[target] && hometown_data[target]['id']
          unless target_id
            Lich::Messaging.msg('plain', "DRCT: get_hometown_target_id failed second attempt for #{target} in #{hometown}. Likely target doesn't exist.") if $common_travel_debug
            target_id = nil
          else
            Lich::Messaging.msg('plain', "DRCT: get_hometown_target_id succeeded second attempt for #{target} in #{hometown}.") if $common_travel_debug
          end
        end
        Lich::Messaging.msg('plain', "DRCT: target_id = #{target_id}") if $common_travel_debug
        target_id
      end
    end
  end
end
