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
        if result =~ /As you drop .+ it dissolves into vapor\./
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
        } unless result =~ /You can only wear two items in that location\./

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
