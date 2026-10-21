# frozen_string_literal: true

module Lich
  module DragonRealms
    module DRCT
      module_function

      # Direction reversal mapping for path reversal
      # Note: With frozen_string_literal: true, string literals are already frozen
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
      }.freeze unless defined?(DIRECTION_REVERSE)

      # Patterns indicating successful sale at a merchant
      SELL_SUCCESS_PATTERNS = [
        /hands? you \d+ (?:kronars|lirums|dokoras)/i
      ].freeze unless defined?(SELL_SUCCESS_PATTERNS)

      # Patterns indicating failed sale attempt
      SELL_FAILURE_PATTERNS = [
        /I need to examine the merchandise first/,
        /That's not worth anything/,
        /I only deal in pelts/,
        /There's folk around here that'd slit a throat for this/
      ].freeze unless defined?(SELL_FAILURE_PATTERNS)

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
      ].freeze unless defined?(BUY_PRICE_PATTERNS)

      # Patterns indicating buy action without price info
      BUY_NON_PRICE_PATTERNS = [
        'You decide to purchase',
        'Buy what'
      ].freeze unless defined?(BUY_NON_PRICE_PATTERNS)

      # Patterns indicating successful ASK request
      ASK_SUCCESS_PATTERNS = [
        /hands you/
      ].freeze unless defined?(ASK_SUCCESS_PATTERNS)

      # Patterns indicating failed ASK request
      ASK_FAILURE_PATTERNS = [
        /does not seem to know anything about that/,
        /All I know about/,
        /To whom are you speaking/,
        /Usage: ASK/
      ].freeze unless defined?(ASK_FAILURE_PATTERNS)

      # Visit a merchant and sell an item.
      # Usually to sell junk at pawn shops.
      #
      # The item is referenced through {DRCI.item_ref}, like the DRCI verbs: a
      # noun gets "my ", while "my sword" and "#<id>" are sent unchanged.
      #
      # Returns false without selling when the item is not in hand or the
      # walk to +room+ fails, so the item is never offered in another room.
      def sell_item(room, item)
        return false unless DRCI.in_hands?(item)
        return false unless walk_to_merchant(room, "selling #{item}")

        case DRC.bput("sell #{DRCI.item_ref(item)}", *SELL_SUCCESS_PATTERNS, *SELL_FAILURE_PATTERNS)
        when *SELL_SUCCESS_PATTERNS
          true
        when *SELL_FAILURE_PATTERNS
          false
        end
      end

      # Visit a merchant and buy an item by offering their asking price.
      # Usually for restocking ammunition or other misc items.
      #
      # Returns nil without buying when the walk to +room+ fails, so nothing
      # is bought from whichever merchant stands in another room.
      def buy_item(room, item)
        return unless walk_to_merchant(room, "buying #{item}")

        all_patterns = BUY_PRICE_PATTERNS + BUY_NON_PRICE_PATTERNS
        result = DRC.bput("buy #{item}", *all_patterns)

        match_data = BUY_PRICE_PATTERNS.lazy.filter_map { |p| p.match(result) }.first
        amount = match_data[:amount] if match_data

        fput("offer #{amount}") if amount
      end

      # Visit a merchant and ask for an item.
      # Usually this is for bundling ropes or gem pouches.
      #
      # Returns false without asking when the walk to +room+ fails.
      def ask_for_item?(room, name, item)
        return false unless walk_to_merchant(room, "asking #{name} for #{item}")

        case DRC.bput("ask #{name} for #{item}", *ASK_SUCCESS_PATTERNS, *ASK_FAILURE_PATTERNS)
        when *ASK_SUCCESS_PATTERNS
          true
        else
          false
        end
      end

      # Visit a merchant and order from a menu.
      #
      # Returns nil without ordering when the walk to +room+ fails: ORDER takes
      # a menu number, so the same ORDER in another shop could buy another item.
      def order_item(room, item_number)
        return unless walk_to_merchant(room, "ordering #{item_number}")

        return if DRC.bput("order #{item_number}", 'Just order it again', 'you don\'t have enough coins') == 'you don\'t have enough coins'

        DRC.bput("order #{item_number}", 'takes some coins from you')
      end

      # Internal to the merchant helpers above; not meant for scripts.
      # Walks to the merchant's +room+ (a room id or map tag; this can take
      # minutes, like walk_to) and returns walk_to's result. When the walk
      # fails it says which purchase or sale was skipped, because walk_to is
      # silent on some failures, e.g. a nil room or a locked shop door.
      # A map tag with no rooms gets one line here instead of walk_to's own
      # "No go2 targets" line followed by this one.
      # @api private
      def walk_to_merchant(room, action)
        if map_tag?(room) && Map.rooms_by_tag(room).empty?
          Lich::Messaging.msg('bold', "DRCT: No go2 targets matching '#{room}' found, so not #{action}.")
          return false
        end

        return true if walk_to(room)

        where = if room.nil?
                  'the shop (no room given)'
                elsif map_tag?(room)
                  "a room tagged #{room}"
                else
                  "room #{room}"
                end
        Lich::Messaging.msg('bold', "DRCT: Could not reach #{where}, so not #{action}.")
        false
      end

      # Internal: true when walk_to reads +room+ as a map tag (a String with
      # a letter in it) rather than a room id. Shared by walk_to and
      # walk_to_merchant so the failure message names the room the same way
      # walk_to looked it up.
      # @api private
      def map_tag?(room)
        room.is_a?(String) && room.count('a-zA-Z') > 0
      end

      private_class_method :walk_to_merchant, :map_tag?

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
            Lich::Messaging.msg('bold', "DRCT: Failed to put lockpick on #{container}. Check your lockpick settings - mixing types in a container is not allowed.")
            break
          end
        end

        # Be polite to Thieves, who need the room to be empty
        DRC.fix_standing
        move('out') if XMLData.room_exits.include?('out')
      end

      # Maximum number of times walk_to will retry navigation before giving up.
      # Prevents unbounded recursion (and eventual SystemStackError) when the
      # game server connection is lost or go2 repeatedly fails.
      MAX_WALK_TO_RETRIES = 3

      # Seconds walk_to waits for Room.current to resolve a room it could not
      # resolve at first, before treating the room as unresolved. This also
      # bounds how fast a caller that loops on walk_to without checking the
      # result retries from such a room.
      WALK_TO_UNRESOLVED_WAIT = 1

      # Navigate to +target_room+ using the go2 script.
      #
      # Room.current (the map's resolver, Map.current) is the only rule for
      # where the character is, both for the start room and for arrival, so
      # walk_to is exactly as strict as that resolver and no stricter. From a
      # room it cannot resolve, even after waiting WALK_TO_UNRESOLVED_WAIT
      # seconds, walk_to sends nothing and returns false; this holds for tag
      # targets too (see tag_to_id).
      #
      # @param target_room [Integer, String] room id or map tag (e.g. 'bank')
      # @param restart_on_fail [Boolean] retry navigation on failure
      # @param retry_depth [Integer] internal counter -- callers should not set this
      # @return [Boolean] true if the character is now in the target room
      def walk_to(target_room, restart_on_fail = true, retry_depth: 0)
        target_room = tag_to_id(target_room) if map_tag?(target_room)

        return false if target_room.nil?

        room_num = target_room.to_i
        current_id = walk_to_current_room_id
        return true if room_num == current_id
        return walk_to_unresolved_failure(room_num) if current_id.nil?

        DRC.fix_standing

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

        current_id = walk_to_current_room_id
        arrived = current_id == room_num
        if !arrived && restart_on_fail
          return walk_to_unresolved_failure(room_num) if current_id.nil?

          if retry_depth >= MAX_WALK_TO_RETRIES
            Lich::Messaging.msg('bold', "DRCT: Failed to navigate to room #{room_num} after #{MAX_WALK_TO_RETRIES} retries, giving up.")
            return false
          end
          Lich::Messaging.msg('bold', "DRCT: Failed to navigate to room #{room_num}, attempting again (#{retry_depth + 1}/#{MAX_WALK_TO_RETRIES}).")
          return walk_to(room_num, true, retry_depth: retry_depth + 1)
        end
        arrived
      end

      # The room Room.current resolves, or nil when it still cannot resolve
      # the room after waiting WALK_TO_UNRESOLVED_WAIT seconds. Room.current
      # is nil for an unresolved room, and nil is falsy with or without Lich's
      # NilClass patch, so this reads the same either way.
      def walk_to_current_room
        room = Room.current
        return room if room

        pause WALK_TO_UNRESOLVED_WAIT
        Room.current
      end

      # The id of walk_to_current_room, or nil when it is unresolved.
      def walk_to_current_room_id
        walk_to_current_room&.id
      end

      def walk_to_unresolved_failure(room_num)
        walk_to_unresolved_message("cannot walk to room #{room_num}")
        false
      end

      # Logs that the current room is unresolved, followed by +consequence+
      # (what the caller could not do because of it).
      def walk_to_unresolved_message(consequence)
        Lich::Messaging.msg('bold', "DRCT: Unable to resolve the current room, #{consequence}.")
      end

      private_class_method :walk_to_current_room, :walk_to_current_room_id,
                           :walk_to_unresolved_failure, :walk_to_unresolved_message

      # The id of the nearest room tagged +target+, measured from the room
      # Room.current resolves, or nil (with a message) when there is none or
      # the current room is still unresolved after walk_to_current_room's wait.
      def tag_to_id(target)
        target_list = Map.rooms_by_tag(target)

        if target_list.empty?
          Lich::Messaging.msg('bold', "DRCT: No go2 targets matching '#{target}' found.")
          return nil
        end

        start = walk_to_current_room
        if start.nil?
          walk_to_unresolved_message("cannot find the nearest room tagged '#{target}'")
          return nil
        end

        start_room = start.id
        if target_list.include?(start_room)
          Lich::Messaging.msg('plain', "DRCT: You're already here.")
          return start_room
        end
        _previous, shortest_distances = start.dijkstra(target_list)
        if shortest_distances.nil?
          Lich::Messaging.msg('bold', "DRCT: Pathfinding failed while looking for a '#{target}' tag.")
          return nil
        end

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

      # find_empty_room gives up after this many searches in a row in which
      # walk_to reached none of the search rooms. Searches that reach a room
      # but find it occupied are not counted: those wait for max_search_attempts.
      MAX_UNREACHABLE_SEARCHES = 3

      # rejected_by_predicate is internal: the buddy pass hands the empty-room
      # search the positions (indexes into search_rooms, so a room id listed
      # twice is judged per visit) the predicate just rejected, which that
      # search's first attempt skips instead of running the predicate (and its
      # side effects) again in the same rooms straight away.
      def find_empty_room(search_rooms, idle_room, predicate = nil, min_mana = 0, strict_mana = false, max_search_attempts = Float::INFINITY, prioritize_buddies = false, rejected_by_predicate: [])
        # With an idle room and no max_search_attempts, an empty list would
        # idle forever without searching anything.
        if search_rooms.nil? || search_rooms.empty?
          Lich::Messaging.msg('bold', 'DRCT: No rooms to search, stopping the search.')
          return false
        end

        search_attempt = 0
        unreachable_searches = 0
        buddy_pass_rejected = []
        check_mana = min_mana > 0
        loop do
          search_attempt += 1
          Lich::Messaging.msg('plain', "DRCT: Search attempt #{search_attempt} of #{max_search_attempts} to find a suitable room.")
          found_empty = false
          reached_any = false
          search_rooms.each_with_index do |room_id, index|
            if search_attempt == 1 && rejected_by_predicate.include?(index)
              # Reached and judged by the buddy pass a moment ago.
              reached_any = true
              next
            end

            # walk_to returns true when it believes it reached the target and
            # false when it could not confirm arrival (see walk_to); such a room
            # is skipped for this pass rather than waiting for Room.current to
            # change.
            reached = walk_to(room_id)
            reached_any ||= reached

            last_buddy_room = false
            nemesis_with_buddy = false
            predicate_rejected = false
            if prioritize_buddies
              # The buddy pass is the first pass over the rooms, and it never
              # runs past its last room: it returns at a buddy room or, at the
              # last room, through the fallback below. A room is a buddy room
              # if it has a friend and no nemesis, and the caller's predicate
              # (if any) accepts it -- the predicate is only asked in rooms
              # with a friend, so the buddy pass doesn't run the caller's
              # checks (which may search or speak) in other rooms. An
              # unreachable room is skipped.
              buddy_here = reached && (DRRoom.pcs & UserVars.friends).any?
              nemesis_with_buddy = buddy_here && (DRRoom.pcs & UserVars.hunting_nemesis).any?
              suitable_room = buddy_here && !nemesis_with_buddy
              if suitable_room && predicate
                suitable_room = predicate.call(search_attempt)
                predicate_rejected = !suitable_room
                buddy_pass_rejected << index if predicate_rejected
              end
              last_buddy_room = index == search_rooms.size - 1
            else
              # walk_to returned false: skip the room for this pass.
              next unless reached

              suitable_room = predicate ? predicate.call(search_attempt) : (DRRoom.pcs - DRRoom.group_members).empty?
            end
            mana_short = false
            if suitable_room && check_mana && !(DRStats.moon_mage? || DRStats.trader?)
              found_empty = true
              suitable_room = (DRCA.perc_mana >= min_mana)
              mana_short = !suitable_room
            end
            return true if suitable_room
            next unless last_buddy_room

            # The buddy pass ended without a buddy room. Start the empty-room
            # search now instead of idling for another attempt. It checks mana
            # first and relaxes it (without strict_mana) only if no room has
            # enough.
            outcome = if !reached
                        'Could not reach last room in list, and found no buddies.'
                      elsif mana_short
                        'Reached last room in list, and found buddies but not the right mana.'
                      elsif nemesis_with_buddy
                        'Reached last room in list, and found buddies but also a nemesis.'
                      elsif predicate_rejected
                        'Reached last room in list, and found buddies but the room did not suit.'
                      else
                        'Reached last room in list, and found no buddies.'
                      end
            Lich::Messaging.msg('plain', "DRCT: #{outcome} Retrying for empty room.")
            return find_empty_room(search_rooms, idle_room, predicate, min_mana, strict_mana, max_search_attempts, false, rejected_by_predicate: buddy_pass_rejected)
          end

          if found_empty && check_mana && !strict_mana
            check_mana = false
            Lich::Messaging.msg('plain', 'DRCT: Empty rooms found, but not with the right mana. Going to use those anyway.')
            next
          end

          check_mana = min_mana > 0

          # Waiting at the idle room cannot help if no search room can be
          # reached, so a run of such searches ends the search even when
          # max_search_attempts is unbounded.
          unreachable_searches = reached_any ? 0 : unreachable_searches + 1
          if unreachable_searches >= MAX_UNREACHABLE_SEARCHES
            rooms = search_rooms.size == 1 ? 'the search room' : "any of the #{search_rooms.size} search rooms"
            Lich::Messaging.msg('bold', "DRCT: Could not reach #{rooms} in #{unreachable_searches} searches, stopping the search.")
            return false
          end

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
        # Pathfinding failed; hand back what was asked for rather than nothing.
        return target_list if shortest_distances.nil?

        target_list.delete_if { |room_num| shortest_distances[room_num].nil? && room_num != Room.current.id }
        # The current room is kept above even without a distance, so sort on a
        # fallback rather than handing nil to the comparator. dijkstra seeds the
        # source at 0, so this is defensive rather than a live case.
        target_list.sort_by { |room_num| shortest_distances[room_num] || Float::INFINITY }
      end

      def find_sorted_empty_room(search_rooms, idle_room, predicate = nil)
        sorted_rooms = sort_destinations(search_rooms)
        find_empty_room(sorted_rooms, idle_room, predicate)
      end

      def time_to_room(origin, destination)
        # Results are keyed by Integer room id, and dijkstra only terminates
        # early when the destination compares as an Integer.
        destination = destination.to_i
        _previous, shortest_paths = Map.dijkstra(origin, destination)
        return nil if shortest_paths.nil?

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
