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
      def sell_item(room, item)
        return false unless DRCI.in_hands?(item)

        walk_to(room)

        case DRC.bput("sell #{DRCI.item_ref(item)}", *SELL_SUCCESS_PATTERNS, *SELL_FAILURE_PATTERNS)
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

      # Navigate to +target_room+ using the go2 script.
      #
      # From a room Room.current cannot resolve, the walk goes to
      # {walk_from_unknown_room} instead of go2. In practice that fails at once
      # without moving: any room {match_unknown_room} accepts is one the map's
      # own resolver (Map.current) already resolves. The hand walker only moves
      # when the live room changes between the Room.current read and the match.
      #
      # @param target_room [Integer, String] room id or map tag (e.g. 'bank')
      # @param restart_on_fail [Boolean] retry navigation on failure
      # @param retry_depth [Integer] internal counter -- callers should not set this
      # @return [Boolean] true if the character is now in the target room
      def walk_to(target_room, restart_on_fail = true, retry_depth: 0)
        target_room = tag_to_id(target_room) if target_room.is_a?(String) && target_room.count("a-zA-Z") > 0

        return false if target_room.nil?

        room_num = target_room.to_i
        # Room.current is nil when the room could not be resolved. Under Lich's
        # NilClass patch nil.id yielded nil, so the comparison simply failed.
        return true if room_num == Room.current&.id

        DRC.fix_standing

        return walk_from_unknown_room(room_num, restart_on_fail, retry_depth) if Room.current&.id.nil?

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

        arrived = arrived_at?(room_num)
        if !arrived && restart_on_fail
          if retry_depth >= MAX_WALK_TO_RETRIES
            Lich::Messaging.msg('bold', "DRCT: Failed to navigate to room #{room_num} after #{MAX_WALK_TO_RETRIES} retries, giving up.")
            return false
          end
          Lich::Messaging.msg('bold', "DRCT: Failed to navigate to room #{room_num}, attempting again (#{retry_depth + 1}/#{MAX_WALK_TO_RETRIES}).")
          return walk_to(room_num, true, retry_depth: retry_depth + 1)
        end
        arrived
      end

      # Whether the character stands in +room_num+: by Room.current when the
      # map resolves the room, otherwise by a unique title, description and
      # exits match (see {match_unknown_room}). That fallback only differs from
      # Room.current when the live room changed between the two reads.
      #
      # @param room_num [Integer] room id
      # @return [Boolean]
      def arrived_at?(room_num)
        current_id = Room.current&.id
        return current_id == room_num unless current_id.nil?

        match_unknown_room&.id == room_num
      end

      # Find the map room the character is standing in when Room.current could
      # not resolve it. A room is only identified when its title, description
      # AND exits all match the live room, and exactly one map room does. A
      # title and description match alone is not enough, and fogged-over exits
      # match nothing.
      #
      # A stored UID vetoes the match the same way the map's own resolver does
      # (Map.resolve_matched_room): when the game shows a live UID and the room
      # carries UIDs that do not include it, that room is not accepted. A vetoed
      # room still counts as a candidate, so a vetoed look-alike next to a room
      # with no stored UID makes the match ambiguous and nothing is returned.
      # The two cases look identical from here: the character may stand in the
      # room without a UID (the vetoed one is a different room), or in the
      # vetoed room itself, whose stored UID list is stale or incomplete. Taking
      # the room without a UID would report arrival in the second case with
      # nothing sent, so the match fails instead.
      #
      # With a script running, Map.current takes the first title, description
      # and exits match unless its UIDs veto it, so a room this method accepts
      # is normally one Room.current resolves as well. It returns a room
      # Room.current did not resolve only when the live room changed between
      # the two reads.
      #
      # @return [Lich::Common::Map, nil] the single matching room; nil when no
      #   room or more than one room matches, when the single match is vetoed
      #   by its UID, or when the live room text is missing
      def match_unknown_room
        title = XMLData.room_title.to_s
        description = XMLData.room_description.to_s.strip
        exits = XMLData.room_exits_string.to_s.strip
        return nil if title.empty? || description.empty? || exits.empty?

        rooms = Map.list.select do |room|
          room &&
            room.title.include?(title) &&
            room.description.include?(description) &&
            room.paths.include?(exits)
        end
        return nil unless rooms.length == 1
        return nil if uid_excludes?(rooms.first, XMLData.room_id.to_i)

        rooms.first
      end

      # Whether +room+'s stored UIDs rule out the live UID: the game shows one
      # (non-zero) and the room has UIDs that do not include it.
      #
      # @param room [Lich::Common::Map] a map room
      # @param live_uid [Integer] XMLData.room_id (0 when the game shows none)
      # @return [Boolean]
      def uid_excludes?(room, live_uid)
        return false if live_uid.zero?

        uids = Array(room.uid)
        uids.any? && !uids.include?(live_uid)
      end

      # Walk toward +room_num+ from a room Room.current cannot resolve, one map
      # edge at a time, always the first hop of the map path (as go2 would
      # take it). As soon as Room.current resolves again the
      # walk hands back to walk_to (and go2). A hand-back before any move
      # (the room resolved between walk_to's read and this one) spends one of
      # the MAX_WALK_TO_RETRIES, so the two cannot call each other forever.
      #
      # Arrival is checked after every move. A move that lands in the expected
      # next room is progress and does not spend a retry; a move that does not
      # (blocked, or the character ended up somewhere unexpected) spends one of
      # the MAX_WALK_TO_RETRIES, and is not retried at all when
      # +restart_on_fail+ is false. A move the game reports as a wrong exit
      # (move returned false) ends the walk. Moves are capped at the first
      # path's length plus MAX_WALK_TO_RETRIES so a map that loops cannot walk
      # forever.
      #
      # Under the map's own resolver this normally ends on the first iteration
      # with "Failed to find a matching room" (see {match_unknown_room}).
      #
      # @param room_num [Integer] target room id
      # @param restart_on_fail [Boolean] retry a move that made no progress
      # @param retry_depth [Integer] retries already spent by walk_to
      # @return [Boolean] true if the character is now in the target room
      def walk_from_unknown_room(room_num, restart_on_fail, retry_depth)
        Lich::Messaging.msg('plain', "DRCT: In an unknown room, manually attempting to navigate to #{room_num}")
        retries = retry_depth
        moves = 0
        max_moves = nil

        loop do
          current_id = Room.current&.id
          return true if current_id == room_num
          # The map knows where we are again; go2 is the better walker.
          unless current_id.nil?
            # walk_to sent us here because Room.current was nil, and nothing
            # has moved since. A hand-back with no move spends a retry, so a
            # room that resolves on one read and not the next cannot bounce
            # between walk_to and this walker forever. The budget may already
            # be spent by go2 failures in walk_to, so the give-up message
            # does not claim the room alternated more than once.
            if moves.zero?
              if retries >= MAX_WALK_TO_RETRIES
                Lich::Messaging.msg('bold', "DRCT: Room #{current_id} resolved again without a move; no retries left (#{MAX_WALK_TO_RETRIES}), giving up.")
                return false
              end
              retries += 1
              # Logged so walk_to's "attempting again (n/N)" count does not
              # appear to skip the retry spent here.
              Lich::Messaging.msg('plain', "DRCT: Room #{current_id} resolved again without a move, handing back (retry #{retries}/#{MAX_WALK_TO_RETRIES}).")
            end
            return walk_to(room_num, restart_on_fail, retry_depth: retries)
          end

          room = match_unknown_room
          if room.nil?
            Lich::Messaging.msg('bold', 'DRCT: Failed to find a matching room from unknown location.')
            return false
          end
          return true if room.id == room_num

          # Map[] indexes an Array, so Map[-1] is the last room, not nil.
          target = room_num.negative? ? nil : Map[room_num]
          # Map.findpath(room, nil) searches for room 0, so a target the map
          # does not know would walk toward whatever room 0 is.
          path = target.nil? ? nil : Map.findpath(room, target)
          # Follow the map path like go2 does. A direct edge the pathfinder
          # skips (no usable timeto) is one go2 would not take either.
          next_id = path&.first
          way = next_id.nil? ? nil : room.wayto[next_id.to_s]
          if way.nil?
            Lich::Messaging.msg('bold', "DRCT: No map path from room #{room.id} to room #{room_num}, giving up.")
            return false
          end

          max_moves ||= path.length + MAX_WALK_TO_RETRIES
          if moves >= max_moves
            Lich::Messaging.msg('bold', "DRCT: Did not reach room #{room_num} from an unknown room within #{max_moves} moves, giving up.")
            return false
          end
          moves += 1

          if way.is_a?(StringProc)
            way.call
          elsif move(way) == false
            Lich::Messaging.msg('bold', "DRCT: The exit '#{way}' from room #{room.id} did not work, giving up.")
            return false
          end

          landed_id = Room.current&.id || match_unknown_room&.id
          next if landed_id == next_id || landed_id == room_num

          unless restart_on_fail
            Lich::Messaging.msg('bold', "DRCT: Failed to navigate from unknown room to room #{room_num}, giving up.")
            return false
          end
          if retries >= MAX_WALK_TO_RETRIES
            Lich::Messaging.msg('bold', "DRCT: Failed to navigate from unknown room after #{MAX_WALK_TO_RETRIES} retries, giving up.")
            return false
          end
          retries += 1
        end
      end

      # Internal helpers of walk_to; module_function would otherwise make
      # them public DRCT methods.
      private_class_method :arrived_at?, :match_unknown_room, :uid_excludes?, :walk_from_unknown_room

      def tag_to_id(target)
        start_room = Room.current.id
        target_list = Map.rooms_by_tag(target)

        if target_list.empty?
          Lich::Messaging.msg('bold', "DRCT: No go2 targets matching '#{target}' found.")
          return nil
        end

        if target_list.include?(start_room)
          Lich::Messaging.msg('plain', "DRCT: You're already here.")
          return start_room
        end
        _previous, shortest_distances = Room.current.dijkstra(target_list)
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
