=begin
stash.rb: Core lich file for extending free_hands, empty_hands functions in
  item / container script indifferent method.  Usage will ensure no regex is
  required to be maintained.

    Maintainer: Elanthia-Online
    Original Author: Tillmen, Ondreian, others
    game: Gemstone
    tags: CORE, spells
    required: Lich > 5.0.19
    version: 1.2.1

  changelog:
    version 1.2.1
     * Added support for weapon displayers
    version 1.2.0
     * Added sheath support and TWC support
    version 1.1.0
     * Added ethereal weapon support
    version 1.0.0
     * Initial release

=end

module Lich
  module Stash
    def self.find_container(param)
      GameObj.inv.find do |container|
        container.name =~ %r[#{param}]
      end or fail "could not find Container[name: #{param}]"
    end

    def self.container(param)
      @weapon_displayer ||= []
      container = find_container(param)
      unless @weapon_displayer.include?(container.id)
        result = Lich::Util.issue_command("look in ##{container.id}", /In the .*$|That is closed\.|^You glance at/, silent: true, quiet: true) if container.contents.nil?
        fput "open ##{container.id}" if result.include?('That is closed.')
        @weapon_displayer.push(container.id) if GameObj.containers.find { |item| item[0] == container.id }.nil?
      end
      return container
    end

    def self.try_or_fail(seconds: 2, command: nil)
      fput(command)
      expiry = Time.now + seconds
      wait_until do yield or Time.now > expiry end
      fail "Error[command: #{command}, seconds: #{seconds}]" if Time.now > expiry
    end

    def self.add_to_bag(bag, item)
      bag = container(bag)
      try_or_fail(command: "_drag ##{item.id} ##{bag.id}") do
        20.times {
          return true if ![GameObj.right_hand, GameObj.left_hand].map(&:id).compact.include?(item.id) && @weapon_displayer.include?(bag.id)
          return true if (![GameObj.right_hand, GameObj.left_hand].map(&:id).compact.include?(item.id) and bag.contents.to_a.map(&:id).include?(item.id))
          return true if item.name =~ /^ethereal \w+$/ && ![GameObj.right_hand, GameObj.left_hand].map(&:id).compact.include?(item.id)
          sleep 0.1
        }
        return false
      end
    end

    def self.sheath_bags
      # find ready list settings for sheaths only; regex courtesy Eloot
      @sheath = {}
      @checked_sheaths = false
      sheath_list_match = /(?:sheath|secondary sheath):\s+<d\scmd="store\s(\w+)\sclear">[^<]+<a\sexist="(\d+)"\snoun="[^"]+">([^<]+)<\/a>(?:\s[^<]+)?<\/d>/

      ready_lines = Lich::Util.issue_command("ready list", /Your current settings are/, /To change your default item for a category that is already set/, silent: true, quiet: true)
      ready_lines.each { |line|
        if line =~ sheath_list_match
          sheath_obj = Regexp.last_match(3).to_s.downcase
          sheath_type = Regexp.last_match(1).to_s.downcase.gsub('2', 'secondary_')
          @sheath.store(sheath_type.to_sym, Stash.find_container(sheath_obj))
        end
      }
      @checked_sheaths = true
    end

    def self.stash_hands(right: false, left: false, both: false)
      $fill_hands_actions ||= Array.new
      $fill_left_hand_actions ||= Array.new
      $fill_right_hand_actions ||= Array.new

      actions = Array.new
      right_hand = GameObj.right_hand
      left_hand = GameObj.left_hand

      # extending to use sheath / 2sheath wherever possible
      Stash.sheath_bags unless @checked_sheaths
      if @sheath.has_key?(:sheath)
        unless @sheath.has_key?(:secondary_sheath)
          sheath = second_sheath = @sheath.fetch(:sheath)
        else
          sheath = @sheath.fetch(:sheath) if @sheath.has_key?(:sheath)
          second_sheath = @sheath.fetch(:secondary_sheath) if @sheath.has_key?(:secondary_sheath)
        end
      elsif @sheath.has_key?(:secondary_sheath)
        sheath = second_sheath = @sheath.fetch(:secondary_sheath)
      else
        sheath = second_sheath = nil
      end
      # weaponsack for both hands
      if UserVars.weapon and UserVars.weaponsack and not UserVars.weapon.empty? and not UserVars.weaponsack.empty? and (right_hand.name =~ /#{Regexp.escape(UserVars.weapon.strip)}/i or right_hand.name =~ /#{Regexp.escape(UserVars.weapon).sub(' ', ' .*')}/i)
        weaponsack = GameObj.inv.find { |obj| obj.name =~ /#{Regexp.escape(UserVars.weaponsack.strip)}/i } || GameObj.inv.find { |obj| obj.name =~ /#{Regexp.escape(UserVars.weaponsack).sub(' ', ' .*')}/i }
      end
      # lootsack for both hands
      if UserVars.lootsack.nil? or UserVars.lootsack.empty?
        lootsack = nil
      else
        lootsack = GameObj.inv.find { |obj| obj.name =~ /#{Regexp.escape(UserVars.lootsack.strip)}/i } || GameObj.inv.find { |obj| obj.name =~ /#{Regexp.escape(UserVars.lootsack).sub(' ', ' .*')}/i }
      end
      # finding another container if needed
      other_containers_var = nil
      other_containers = proc {
        results = Lich::Util.issue_command('inventory containers', /^(?:You are carrying nothing at this time|You are wearing)/, silent: true, quiet: true)
        other_containers_ids = results.to_s.scan(/exist=\\"(.*?)\\"/).flatten - [lootsack.id]
        other_containers_var = GameObj.inv.find_all { |obj| other_containers_ids.include?(obj.id) }
        other_containers_var
      }

      if (left || both) && left_hand.id
        waitrt?
        if (left_hand.noun =~ /shield|buckler|targe|heater|parma|aegis|scutum|greatshield|mantlet|pavis|arbalest|bow|crossbow|yumi|arbalest/)\
          and (wear_result = dothistimeout("wear ##{left_hand.id}", 8, /^You .*#{left_hand.noun}|^With careful precision, you|^You toss the shield|^You can only wear \w+ items in that location\.$|^You can't wear that\.$/)) and (wear_result !~ /^You can only wear \w+ items in that location\.$|^You can't wear that\.$/)
          actions.unshift proc {
            dothistimeout "remove ##{left_hand.id}", 3, /^You (?:remove|sling|unsling)|^With a slight roll of your shoulder, you|^You .*#{left_hand.noun}|^Remove what\?/
            20.times { break if GameObj.left_hand.id == left_hand.id or GameObj.right_hand.id == left_hand.id; sleep 0.1 }

            if GameObj.right_hand.id == left_hand.id
              dothistimeout 'swap', 3, /^You don't have anything to swap!|^You swap/
            end
          }
        else
          actions.unshift proc {
            if left_hand.name =~ /^ethereal \w+$/
              fput "rub #{left_hand.noun} tattoo"
              20.times { break if (GameObj.left_hand.name == left_hand.name) or (GameObj.right_hand.name == left_hand.name); sleep 0.1 }
            else
              fput "get ##{left_hand.id}"
              20.times { break if (GameObj.left_hand.id == left_hand.id) or (GameObj.right_hand.id == left_hand.id); sleep 0.1 }
            end

            if GameObj.right_hand.id == left_hand.id or (GameObj.right_hand.name == left_hand.name && left_hand.name =~ /^ethereal \w+$/)
              dothistimeout 'swap', 3, /^You don't have anything to swap!|^You swap/
            end
          }
          if !second_sheath.nil? && GameObj.left_hand.type =~ /weapon/
            result = Lich::Stash.add_to_bag(second_sheath, GameObj.left_hand)
          elsif weaponsack && GameObj.left_hand.type =~ /weapon/
            result = Lich::Stash::add_to_bag(weaponsack, GameObj.left_hand)
          elsif lootsack
            result = Lich::Stash::add_to_bag(lootsack, GameObj.left_hand)
          else
            result = nil
          end
          if result.nil? or !result
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
            20.times { break if GameObj.left_hand.name == right_hand.name or GameObj.right_hand.name == right_hand.name; sleep 0.1 }
          else
            fput "get ##{right_hand.id}"
            20.times { break if GameObj.left_hand.id == right_hand.id or GameObj.right_hand.id == right_hand.id; sleep 0.1 }
          end

          if GameObj.left_hand.id == right_hand.id or (GameObj.left_hand.name == right_hand.name && right_hand.name =~ /^ethereal \w+$/)
            dothistimeout 'swap', 3, /^You don't have anything to swap!|^You swap/
          end
        }

        if !sheath.nil? && GameObj.right_hand.type =~ /weapon/
          result = Lich::Stash.add_to_bag(sheath, GameObj.right_hand)
        elsif weaponsack && GameObj.right_hand.type =~ /weapon/
          result = Lich::Stash::add_to_bag(weaponsack, GameObj.right_hand)
        elsif lootsack
          result = Lich::Stash::add_to_bag(lootsack, GameObj.right_hand)
        else
          result = nil
        end
        sleep 0.1
        if result.nil? or !result
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
