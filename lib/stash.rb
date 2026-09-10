=begin
stash.rb: Core lich file for extending free_hands, empty_hands functions in
  item / container script indifferent method.  Usage will ensure no regex is
  required to be maintained.
=end

module Lich
  module Stash
    @weapon_displayer ||= []
    @bandolier_weapon ||= {}
    @worn_items ||= {}

    def self.find_container(param, loud_fail: true)
      param = param.name if param.is_a?(GameObj) # (Lich::Gemstone::GameObj)
      found_container = GameObj.inv.find do |container|
        container.name =~ %r[#{param.strip}]i || container.name =~ %r[#{param.sub(' ', ' .*')}]i
      end
      if found_container.nil? && loud_fail
        fail "could not find Container[name: #{param}]"
      else
        return found_container
      end
    end

    def self.container(param)
      container_to_check = find_container(param)
      unless @weapon_displayer.include?(container_to_check.id)
        result = Lich::Util.issue_command("look in ##{container_to_check.id}", /In the .*$|That is closed\.|^You glance at/, silent: true, quiet: true) if container_to_check.contents.nil?
        fput "open ##{container_to_check.id}" if result.include?('That is closed.')
        @weapon_displayer.push(container_to_check.id) if GameObj.containers.find { |item| item[0] == container_to_check.id }.nil?
      end
      return container_to_check
    end

    def self.try_or_fail(seconds: 2, command: nil)
      result = fput(command)
      expiry = Time.now + seconds
      wait_until do yield(result) || Time.now > expiry end
      fail "Error[command: #{command}, seconds: #{seconds}]" if Time.now > expiry
    end

    def self.add_to_bag(bag, item)
      bag = container(bag)
      try_or_fail(command: "_drag ##{item.id} ##{bag.id}") do |result|
        # Check for vapor message first (bandolier)
        if result.is_a?(String) && result =~ /As you drop .+ it dissolves into vapor\./
          @bandolier_weapon[item.name] = "unknown"
          return true
        end

        20.times {
          return true if @bandolier_weapon[item.name]
          return true if ![GameObj.right_hand, GameObj.left_hand].map(&:id).compact.include?(item.id) && @weapon_displayer.include?(bag.id)
          return true if (![GameObj.right_hand, GameObj.left_hand].map(&:id).compact.include?(item.id) && bag.contents.to_a.map(&:id).include?(item.id))
          return true if item.name =~ /^ethereal \w+$/ && ![GameObj.right_hand, GameObj.left_hand].map(&:id).compact.include?(item.id)
          sleep 0.1
        }
        return false
      end
    end

    def self.wear_to_inv(item)
      try_or_fail(command: "wear ##{item.id}") do |result|
        20.times {
          return true if (![GameObj.right_hand, GameObj.left_hand].map(&:id).compact.include?(item.id) && GameObj.inv.to_a.map(&:id).include?(item.id))
          return true if item.name =~ /^ethereal \w+$/ && ![GameObj.right_hand, GameObj.left_hand].map(&:id).compact.include?(item.id)
          sleep 0.1
        } unless result.is_a?(String) && result =~ /You can only wear two items in that location\./

        return @worn_items[item.name] = false
      end
    end

    def self.find_bandolier_bag(item)
      # Return cached value if valid and item exists in inventory
      cached_id = @bandolier_weapon[item.name]
      return cached_id if cached_id && cached_id != "unknown" &&
                          GameObj.inv.any? { |inv_item| inv_item.id == cached_id }

      # Regex patterns for parsing
      look_in_regex = Regexp.union(
        /^I could not find what you were referring to./,
        /^Surrounded by some swirling mist is /,
        /^In the /,
        /contains (?:DOSE|TINCTURE)s of the following /,
        /There is nothing in there\./,
        /<exposeContainer/,
        /<dialogData/,
        /<container/,
        /you glance/,
        /That is closed\./
      )

      item_regex = %r{<a exist="(?<id>[^"]+)" noun="(?<noun>[^"]+)">(?<name>[^<]+)</a>}

      # Collect all containers from inventory
      waitrt?
      results = Lich::Util.issue_command("inventory containers", /^You are holding /, timeout: 3, silent: true, quiet: true)
      containers = results.flat_map { |line|
        line.scan(item_regex).map { |id, _noun, _name| GameObj[id] }
      }.compact

      # Find container with the item using mist indicator
      item_noun_regex = /\b#{Regexp.escape(item.noun)}\b/
      found_container = containers.find do |container|
        waitrt?
        results = Lich::Util.issue_command(
          "look in ##{container.id}",
          look_in_regex,
          timeout: 2,
          silent: true,
          quiet: true
        )

        results.any? { |line|
          line.include?("Surrounded by some swirling mist is") && line.match?(item_noun_regex)
        }
      end

      @bandolier_weapon[item.name] = found_container&.id || "unknown"
    end

    def self.stash_hands(right: false, left: false, both: false)
      $fill_hands_actions ||= Array.new
      $fill_left_hand_actions ||= Array.new
      $fill_right_hand_actions ||= Array.new

      actions = Array.new
      right_hand = GameObj.right_hand
      left_hand = GameObj.left_hand

      # extending to use sheath / 2sheath wherever possible
      unless ReadyList.valid?
        ReadyList.check(silent: true, quiet: true)
      end
      # extending to use default stow container wherever possible
      unless StowList.valid?
        StowList.check(silent: true, quiet: true)
      end
      if ReadyList.sheath
        unless ReadyList.secondary_sheath
          sheath = second_sheath = ReadyList.sheath
        else
          sheath = ReadyList.sheath if ReadyList.sheath
          second_sheath = ReadyList.secondary_sheath if ReadyList.secondary_sheath
        end
      elsif ReadyList.secondary_sheath
        sheath = second_sheath = ReadyList.secondary_sheath
      else
        sheath = second_sheath = nil
      end
      # weaponsack for both hands
      if UserVars.weapon.is_a?(String) && UserVars.weaponsack.is_a?(String) && !UserVars.weapon.empty? && !UserVars.weaponsack.empty? && (right_hand.name =~ /#{Regexp.escape(UserVars.weapon.strip)}/i || right_hand.name =~ /#{Regexp.escape(UserVars.weapon).sub(' ', ' .*')}/i)
        weaponsack = nil unless (weaponsack = find_container(UserVars.weaponsack, loud_fail: false)).is_a?(GameObj) # (Lich::Gemstone::GameObj)
      end
      # lootsack for both hands
      if !UserVars.lootsack.is_a?(String) || UserVars.lootsack.empty?
        lootsack = nil
      else
        lootsack = nil unless (lootsack = find_container(UserVars.lootsack, loud_fail: false)).is_a?(GameObj) # (Lich::Gemstone::GameObj)
      end
      # finding another container if needed
      other_containers_var = nil
      other_containers = proc {
        results = Lich::Util.issue_command('inventory containers', /^(?:You are (?:carrying nothing|holding no containers) at this time|You are wearing)/, silent: true, quiet: true)
        other_containers_ids = results.to_s.scan(/exist=\\"(.*?)\\"/).flatten - [lootsack.id]
        other_containers_var = GameObj.inv.find_all { |obj| other_containers_ids.include?(obj.id) }
        other_containers_var
      }

      if (left || both) && left_hand.id
        waitrt?
        if (left_hand.noun =~ /shield|buckler|targe|heater|parma|aegis|scutum|greatshield|mantlet|pavis|arbalest|bow|crossbow|yumi|arbalest/) && @worn_items[left_hand.name] != false && Lich::Stash::wear_to_inv(left_hand)
          actions.unshift proc {
            fput "remove ##{left_hand.id}"
            20.times { break if GameObj.left_hand.id == left_hand.id || GameObj.right_hand.id == left_hand.id; sleep 0.1 }

            if GameObj.right_hand.id == left_hand.id
              dothistimeout 'swap', 3, /^You don't have anything to swap!|^You swap/
            end
          }
        else
          actions.unshift proc {
            if left_hand.name =~ /^ethereal \w+$/
              fput "rub #{left_hand.noun} tattoo"
              20.times { break if (GameObj.left_hand.name == left_hand.name) || (GameObj.right_hand.name == left_hand.name); sleep 0.1 }
            elsif @bandolier_weapon[left_hand.name]
              fput "rub ##{find_bandolier_bag(left_hand)}"
              20.times { break if (GameObj.left_hand.name == left_hand.name) || (GameObj.right_hand.name == left_hand.name); sleep 0.1 }
            else
              fput "get ##{left_hand.id}"
              20.times { break if (GameObj.left_hand.id == left_hand.id) || (GameObj.right_hand.id == left_hand.id); sleep 0.1 }
            end

            if GameObj.right_hand.id == left_hand.id || (GameObj.right_hand.name == left_hand.name && left_hand.name =~ /^ethereal \w+$/)
              dothistimeout 'swap', 3, /^You don't have anything to swap!|^You swap/
            end
          }
          if (ready_item = ReadyList.ready_list.find { |_k, v| v.id.eql?(GameObj.left_hand.id) }) && ReadyList.store_list[ready_item[0]]
            result = Lich::Stash.add_to_bag(sheath, GameObj.left_hand) if ReadyList.store_list[ready_item[0]].eql?("put in sheath")
            result = Lich::Stash.add_to_bag(second_sheath, GameObj.left_hand) if ReadyList.store_list[ready_item[0]].eql?("put in secondary sheath")
            result = Lich::Stash.add_to_bag(StowList.default, GameObj.left_hand) if ["worn if possible, stowed otherwise", "stowed"].include?(ReadyList.store_list[ready_item[0]])
          elsif !second_sheath.nil? && GameObj.left_hand.type =~ /weapon/
            result = Lich::Stash.add_to_bag(second_sheath, GameObj.left_hand)
          elsif weaponsack && GameObj.left_hand.type =~ /weapon/
            result = Lich::Stash::add_to_bag(weaponsack, GameObj.left_hand)
          elsif lootsack
            result = Lich::Stash::add_to_bag(lootsack, GameObj.left_hand)
          else
            result = nil
          end
          if result.nil? || !result
            for container in other_containers.call
              result = Lich::Stash::add_to_bag(container, GameObj.left_hand)
              break if result
            end
          end
        end
      end
      if (right || both) && right_hand.id
        waitrt?
        actions.unshift proc {
          if right_hand.name =~ /^ethereal \w+$/
            fput "rub #{right_hand.noun} tattoo"
            20.times { break if GameObj.left_hand.name == right_hand.name || GameObj.right_hand.name == right_hand.name; sleep 0.1 }
          elsif @bandolier_weapon[right_hand.name]
            fput "rub ##{find_bandolier_bag(right_hand)}"
            20.times { break if GameObj.left_hand.name == right_hand.name || GameObj.right_hand.name == right_hand.name; sleep 0.1 }
          else
            fput "get ##{right_hand.id}"
            20.times { break if GameObj.left_hand.id == right_hand.id || GameObj.right_hand.id == right_hand.id; sleep 0.1 }
          end

          if GameObj.left_hand.id == right_hand.id || (GameObj.left_hand.name == right_hand.name && right_hand.name =~ /^ethereal \w+$/)
            dothistimeout 'swap', 3, /^You don't have anything to swap!|^You swap/
          end
        }
        if (ready_item = ReadyList.ready_list.find { |_k, v| v.id.eql?(GameObj.right_hand.id) }) && ReadyList.store_list[ready_item[0]]
          result = Lich::Stash.add_to_bag(sheath, GameObj.right_hand) if ReadyList.store_list[ready_item[0]].eql?("put in sheath")
          result = Lich::Stash.add_to_bag(second_sheath, GameObj.right_hand) if ReadyList.store_list[ready_item[0]].eql?("put in secondary sheath")
          result = Lich::Stash.add_to_bag(StowList.default, GameObj.right_hand) if ["worn if possible, stowed otherwise", "stowed"].include?(ReadyList.store_list[ready_item[0]])
        elsif !sheath.nil? && GameObj.right_hand.type =~ /weapon/
          result = Lich::Stash.add_to_bag(sheath, GameObj.right_hand)
        elsif weaponsack && GameObj.right_hand.type =~ /weapon/
          result = Lich::Stash::add_to_bag(weaponsack, GameObj.right_hand)
        elsif lootsack
          result = Lich::Stash::add_to_bag(lootsack, GameObj.right_hand)
        else
          result = nil
        end
        sleep 0.1
        if result.nil? || !result
          for container in other_containers.call
            result = Lich::Stash::add_to_bag(container, GameObj.right_hand)
            break if result
          end
        end
      end
      $fill_hands_actions.push(actions) if both
      $fill_left_hand_actions.push(actions) if left
      $fill_right_hand_actions.push(actions) if right
    end

    # -------------------------------------------------------------------------
    # Named items: find, wield, and reconcile both hands to a wanted state.
    #
    # stash_hands / equip_hands remember and restore whatever was held. The
    # methods below are the other half: "put THIS item in my hand", where the
    # item is named by a profile string, an id, a GameObj, or a ready-list slot.
    # Every command is sent by id, so an ambiguous noun never reaches the game.
    # -------------------------------------------------------------------------

    HANDS = %i[right left].freeze

    ITEM_CONFIRM_TRIES = 20
    ITEM_CONFIRM_SLEEP = 0.1

    # Resolve an item reference to a GameObj without sending anything.
    #
    # @param param [GameObj, Integer, String, Symbol] a GameObj; an id; a
    #   ready-list slot (:weapon, :shield, ...); or a name matched the way
    #   find_container matches, case-insensitive and with words allowed to be
    #   non-adjacent ("vultite broadsword" matches "vultite hand-forged broadsword")
    # @param loud_fail [Boolean] raise when nothing matches
    # @return [GameObj, nil] the best candidate from find_items for a name
    # @raise [RuntimeError] when loud_fail and the item is missing
    def self.find_item(param, loud_fail: true)
      return param if param.is_a?(GameObj)

      found = case param
              when Integer then GameObj[param.to_s]
              when Symbol then find_ready_item(param)
              when String
                param =~ /\A\d+\z/ ? GameObj[param] : find_items(param).first
              end
      fail "could not find Item[#{param.inspect}]" if found.nil? && loud_fail
      found
    end

    # Every distinct item a name could mean, best first, without sending
    # anything. Ordered by how specific the match is (whole name, then part
    # of the name, then noun only) and then by where the item is (hands,
    # ready list, worn, containers), which is the order the game itself
    # resolves a bare noun in. Items with identical names are interchangeable
    # and collapse to the first.
    #
    # @param name [String]
    # @return [Array<GameObj>] empty when nothing matches
    def self.find_items(name)
      ranked = known_items_ranked.select { |obj, _loc| name_matches?(obj, name) }
      ranked = inventory_matches(name).map { |obj| [obj, 4] } if ranked.empty?
      ranked.sort_by.with_index { |(obj, loc), i| [match_specificity(obj, name), loc, i] }
                    .map(&:first)
            .uniq(&:id)
            .uniq(&:name)
    end

    # The full inventory tree, refreshed on request through the game's
    # inventory manager. This is what knows about items in containers Lich
    # has never looked in, and whether each container is closed right now.
    #
    # @param refresh [Boolean] ask the game for a fresh tree (one command)
    # @return [Lich::Common::Inventory::Snapshot, nil]
    def self.inventory(refresh: true)
      return nil unless defined?(Lich::Common::Inventory)
      refresh ? Lich::Common::Inventory.refresh : Lich::Common::Inventory.current
    rescue StandardError
      nil
    end

    # Open every closed container between the item and the player, outermost
    # first, confirming each. Locked containers are left alone.
    #
    # @param item [GameObj]
    # @return [Boolean] false when a container on the way is locked or would not open
    def self.open_path_to(item)
      snapshot = inventory(refresh: false) || inventory
      entry = snapshot && snapshot[item.id]
      return true if entry.nil? # Inventory does not know it; nothing to open

      chain = []
      parent = entry.parent_item
      while parent
        chain.unshift(parent)
        parent = parent.parent_item
      end
      chain.each do |container|
        next unless container.closed?
        return false if container.locked?
        return false unless open_container(container.id)
      end
      true
    end

    OPEN_CONFIRM = /^You open|^That is already open|^It is already open|^You can't|^You don't seem|^You need|is locked/.freeze

    # @param id [String] container id
    # @return [Boolean] whether the container is open afterwards
    def self.open_container(id)
      waitrt?
      result = dothistimeout("open ##{id}", 3, OPEN_CONFIRM)
      return true if result =~ /^You open|already open/
      false
    end

    # @return [Symbol, nil] :right or :left when the item is in that hand
    def self.hand_holding(item)
      id = item.is_a?(GameObj) ? item.id : item.to_s
      return nil if id.nil?
      return :right if GameObj.right_hand&.id == id
      return :left if GameObj.left_hand&.id == id
      nil
    end

    # @return [Boolean]
    def self.in_hand?(item)
      !hand_holding(item).nil?
    end

    # Get a named item into a hand.
    #
    # Worn items are removed, items in containers are fetched (opening the
    # container first when Lich knows it is closed), and the target hand is
    # emptied through stash_hands beforehand so nothing is dropped. When no
    # hand is given the item goes wherever the game puts it.
    #
    # @param param [GameObj, Integer, String, Symbol] see find_item
    # @param hand [Symbol, nil] :right, :left, or nil for either
    # @return [GameObj] the item now in hand
    # @raise [RuntimeError] when the item cannot be found or never arrives
    def self.wield(param, hand: nil)
      fail "wield: hand must be :right, :left or nil, got #{hand.inspect}" unless hand.nil? || HANDS.include?(hand)
      if param.is_a?(String) && param !~ /\A\d+\z/
        candidates = find_items(param)
        fail "could not find Item[#{param.inspect}]" if candidates.empty?
        item = candidates.first
        echo "wield: #{param} -> #{item.name} (of #{candidates.size} kinds: #{candidates.map(&:name).join(', ')})" if candidates.size > 1
      else
        item = find_item(param)
      end

      holding = hand_holding(item)
      if holding
        return item if hand.nil? || holding == hand
        waitrt?
        dothistimeout 'swap', 3, /^You don't have anything to swap!|^You swap/
        return item if hand_holding(item) == hand
        fail "wield: could not move #{item.name} to the #{hand} hand"
      end

      waitrt?
      if hand
        stash_hands(**{ hand => true }) unless empty_hand?(hand)
      elsif !empty_hand?(:right) && !empty_hand?(:left)
        stash_hands(right: true)
      end

      fail "wield: a container holding #{item.name} is locked or would not open" unless open_path_to(item)

      fetch = worn?(item) ? "remove ##{item.id}" : "get ##{item.id}"
      fput fetch
      ITEM_CONFIRM_TRIES.times { break if in_hand?(item); sleep ITEM_CONFIRM_SLEEP }

      # Did not arrive: the usual cause is a container closed since Lich last
      # saw inside it. Ask the game for the current tree, open, try once more.
      unless in_hand?(item)
        inventory
        fail "wield: a container holding #{item.name} is locked or would not open" unless open_path_to(item)
        fput fetch
        ITEM_CONFIRM_TRIES.times { break if in_hand?(item); sleep ITEM_CONFIRM_SLEEP }
      end
      fail "wield: #{item.name} did not arrive in hand" unless in_hand?(item)

      if hand && hand_holding(item) != hand
        dothistimeout 'swap', 3, /^You don't have anything to swap!|^You swap/
        fail "wield: could not move #{item.name} to the #{hand} hand" unless hand_holding(item) == hand
      end
      item
    end

    # Reconcile both hands to a wanted state without dropping anything.
    #
    #   Stash.hands(right: 'broadsword', left: :shield)   # wield both
    #   Stash.hands(right: nil)                           # empty the right hand, leave left alone
    #   Stash.hands(left: :keep, right: 'runestaff')
    #
    # Each hand takes :keep (leave it, the default), nil (empty it), or any item
    # reference find_item accepts. An item already in the other hand is swapped
    # across rather than stashed and fetched.
    #
    # @return [Hash{Symbol => GameObj, nil}] what each hand holds afterwards
    def self.hands(right: :keep, left: :keep)
      wanted = { right: right, left: left }
      resolved = wanted.transform_values { |want| want == :keep || want.nil? ? want : find_item(want) }
      if resolved[:right].is_a?(GameObj) && resolved[:left].is_a?(GameObj) && resolved[:right].id == resolved[:left].id
        raise ArgumentError, "hands: #{resolved[:right].name} was asked for in both hands"
      end

      # A wanted item sitting in the hand the caller asked to keep can only be
      # moved by a swap, which would change that hand. Refuse before touching anything.
      HANDS.each do |hand|
        other = hand == :right ? :left : :right
        item = resolved[hand]
        next unless item.is_a?(GameObj) && wanted[other] == :keep && hand_holding(item) == other
        raise ArgumentError, "hands: #{item.name} is in the #{other} hand, which was asked to be kept"
      end

      # Both wanted items are present but in each other's hands: one swap.
      if resolved[:right].is_a?(GameObj) && resolved[:left].is_a?(GameObj) &&
         hand_holding(resolved[:right]) == :left && hand_holding(resolved[:left]) == :right
        waitrt?
        dothistimeout 'swap', 3, /^You don't have anything to swap!|^You swap/
      end

      # Empty first, so a wanted item can land in a freed hand.
      HANDS.each do |hand|
        next unless resolved[hand].nil? && wanted.key?(hand) && !(wanted[hand] == :keep)
        stash_hands(**{ hand => true }) unless empty_hand?(hand)
      end

      HANDS.each do |hand|
        item = resolved[hand]
        next unless item.is_a?(GameObj)
        wield(item, hand: hand)
      end

      { right: GameObj.right_hand&.id ? GameObj.right_hand : nil,
        left: GameObj.left_hand&.id ? GameObj.left_hand : nil }
    end

    # @param hand [Symbol] :right or :left
    # @return [Boolean]
    def self.empty_hand?(hand)
      obj = hand == :right ? GameObj.right_hand : GameObj.left_hand
      obj.nil? || obj.id.nil?
    end

    # @return [Boolean] whether the item is in worn inventory (needs REMOVE, not GET)
    def self.worn?(item)
      GameObj.inv.to_a.any? { |obj| obj.id == item.id }
    end

    # @return [GameObj, nil] the container Lich knows the item to be inside,
    #   from the looked-in registries or the inventory tree
    def self.container_holding(item)
      entry = GameObj.containers.find { |_id, items| items.to_a.any? { |obj| obj.id == item.id } }
      return GameObj.inv.to_a.find { |obj| obj.id == entry.first } || GameObj[entry.first] if entry

      snapshot = inventory(refresh: false)
      parent = snapshot && snapshot[item.id]&.parent_item
      parent && GameObj[parent.id]
    end

    # Items from the inventory tree whose name matches, as GameObjs. Inventory
    # registers a GameObj for every item it sees, so the id lookup succeeds
    # even for items in containers nobody has looked in.
    #
    # @return [Array<GameObj>]
    def self.inventory_matches(param)
      snapshot = inventory
      return [] if snapshot.nil?
      snapshot.all.select { |item| name_matches?(item, param) }
                  .reject { |item| item.in_room? || item.at_feet? }
                  .map { |item| GameObj[item.id] }
                  .compact
    end

    # @return [GameObj, nil] the item in a ready-list slot, checking the list once if needed
    def self.find_ready_item(slot)
      fail "unknown ready-list slot #{slot.inspect}" unless ReadyList.ready_list.key?(slot)
      ReadyList.check(silent: true, quiet: true) unless ReadyList.valid?
      ReadyList.ready_list[slot]
    end

    # known_items with a location rank: 0 hands, 1 ready list, 2 worn, 3 in a container.
    #
    # @return [Array<Array(GameObj, Integer)>]
    def self.known_items_ranked
      hands = [GameObj.right_hand, GameObj.left_hand].compact.reject { |obj| obj.id.nil? }
      ready = ReadyList.checked? ? ReadyList.ready_list.values.compact : []
      hands.map { |obj| [obj, 0] } +
        ready.map { |obj| [obj, 1] } +
        GameObj.inv.to_a.map { |obj| [obj, 2] } +
        GameObj.containers.values.flatten.map { |obj| [obj, 3] }
    end

    # 0 when the name is the whole item name, 1 when it is a run of whole
    # words inside it, 2 when only the noun (or a loose match) hit.
    def self.match_specificity(obj, name)
      wanted = name.strip.downcase
      actual = obj.name.to_s.downcase
      return 0 if actual == wanted
      return 1 if actual =~ /(?:\A|\s)#{Regexp.escape(wanted)}(?:\s|\z)/ && wanted.include?(' ')
      2
    end

    # Every item Lich currently knows the character has: hands, worn, and the
    # contents of containers that have been looked in.
    #
    # @return [Array<GameObj>]
    def self.known_items
      hands = [GameObj.right_hand, GameObj.left_hand].compact.reject { |obj| obj.id.nil? }
      hands + GameObj.inv.to_a + GameObj.containers.values.flatten
    end

    # Same matching find_container uses, so a profile string means the same
    # thing whether it names a bag or a weapon.
    def self.name_matches?(obj, param)
      obj.name =~ %r[#{param.strip}]i || obj.name =~ %r[#{param.sub(' ', ' .*')}]i
    end

    private_class_method :find_ready_item, :known_items, :known_items_ranked, :match_specificity, :name_matches?, :inventory_matches

    def self.equip_hands(left: false, right: false, both: false)
      if both
        for action in $fill_hands_actions.pop
          action.call
        end
      elsif left
        for action in $fill_left_hand_actions.pop
          action.call
        end
      elsif right
        for action in $fill_right_hand_actions.pop
          action.call
        end
      else
        if $fill_right_hand_actions.length > 0
          for action in $fill_right_hand_actions.pop
            action.call
          end
        elsif $fill_left_hand_actions.length > 0
          for action in $fill_left_hand_actions.pop
            action.call
          end
        end
      end
    end
  end
end
