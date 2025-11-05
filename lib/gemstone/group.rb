require "ostruct"
require "benchmark"
require_relative 'disk'

module Lich
  module Gemstone
    # Manages group membership and leadership in Gemstone IV.
    # Tracks group members, leader status, and group state (open/closed).
    # Automatically updates based on game output through the Observer pattern.
    #
    # @example Check if player is group leader
    #   Group.leader? #=> true or false
    #
    # @example Get all group members
    #   members = Group.members #=> [GameObj, GameObj, ...]
    #
    # @example Add a member to the group
    #   Group.add("PlayerName")
    #
    class Group
      @@members ||= []
      @@leader  ||= nil
      @@checked ||= false
      @@status  ||= :closed

      # Clears all group members and resets the checked flag.
      # Does not change leader status.
      #
      # @return [Array] Empty array
      def self.clear()
        @@members = []
        @@checked = false
      end

      # Checks if group data has been verified with the game.
      #
      # @return [Boolean] true if group data has been checked
      def self.checked?
        @@checked
      end

      # Adds one or more members to the group if they're not already included.
      # Does not duplicate members.
      #
      # @param members [Array<GameObj>] one or more GameObj instances to add
      # @return [Array<GameObj>] the updated members array
      def self.push(*members)
        members.each do |member|
          @@members.push(member) unless include?(member)
        end
      end

      # Removes one or more members from the group by ID.
      #
      # @param members [Array<GameObj>] one or more GameObj instances to remove
      # @return [Array<GameObj>] the updated members array
      def self.delete(*members)
        gone = members.map(&:id)
        @@members.reject! do |m| gone.include?(m.id) end
      end

      # Replaces the entire members list with new members.
      # Used when receiving a complete group listing from the game.
      #
      # @param members [Array<GameObj>] the complete list of group members
      # @return [Array<GameObj>] the new members array
      def self.refresh(*members)
        @@members = members.dup
      end

      # Returns a copy of the current group members.
      # Automatically checks group status if not already checked.
      #
      # @return [Array<GameObj>] copy of the members array
      def self.members
        maybe_check
        @@members.dup
      end

      # Returns the internal members array without checking or copying.
      # Used internally by the Observer to avoid infinite loops.
      #
      # @api private
      # @return [Array<GameObj>] the internal members array
      def self._members
        @@members
      end

      # Returns Disk objects for all group members.
      # If the player is leader with no members, returns only the player's disk.
      # Always includes the current character's disk if available.
      #
      # @return [Array<Disk>] array of Disk objects for group members
      def self.disks
        return [Disk.find_by_name(Char.name)].compact if Group.leader? && members.empty?
        member_disks = members.map(&:noun).compact.map { |noun| Disk.find_by_name(noun) }.compact
        member_disks.push(Disk.find_by_name(Char.name)) if Disk.find_by_name(Char.name)
        return member_disks
      end

      # String representation of the group members.
      #
      # @return [String] string representation of members array
      def self.to_s
        @@members.to_s
      end

      # Sets the checked flag indicating group data has been verified.
      #
      # @param flag [Boolean] true if group data is verified
      # @return [Boolean] the flag value
      def self.checked=(flag)
        @@checked = flag
      end

      # Sets the group status (open or closed).
      #
      # @param state [Symbol] :open or :closed
      # @return [Symbol] the status value
      def self.status=(state)
        @@status = state
      end

      # Gets the current group status.
      #
      # @return [Symbol] :open or :closed
      def self.status()
        @@status
      end

      # Checks if the group is open to new members.
      # Automatically verifies group status if not already checked.
      #
      # @return [Boolean] true if group status is open
      def self.open?
        maybe_check
        @@status.eql?(:open)
      end

      # Checks if the group is closed to new members.
      #
      # @return [Boolean] true if group status is not open
      def self.closed?
        not open?
      end

      # Actively checks group status by sending the GROUP command to the game.
      # Clears current group data and waits up to 3 seconds for response.
      # Should be called at script initialization.
      #
      # @return [Array<GameObj>] copy of the members array after checking
      def self.check
        Group.clear()
        ttl = Time.now + 3
        Game._puts "<c>group\r\n"
        wait_until { Group.checked? or Time.now > ttl }
        @@members.dup
      end

      # Checks group status only if not already checked.
      #
      # @return [Array<GameObj>, nil] members array if check was needed, nil otherwise
      def self.maybe_check
        Group.check unless checked?
      end

      # Returns all PCs in the room who are not in the group.
      #
      # @return [Array<GameObj>] array of PC GameObj instances not in group
      def self.nonmembers
        GameObj.pcs.to_a.reject { |pc| ids.include?(pc.id) }
      end

      # Sets the group leader.
      #
      # @param char [Symbol, GameObj] :self if current player is leader, or GameObj of leader
      # @return [Symbol, GameObj] the leader value
      def self.leader=(char)
        @@leader = char
      end

      # Gets the current group leader.
      #
      # @return [Symbol, GameObj] :self if current player is leader, or GameObj of leader
      def self.leader
        @@leader
      end

      # Checks if the current player is the group leader.
      #
      # @return [Boolean] true if current player is leader
      def self.leader?
        @@leader.eql?(:self)
      end

      # Adds one or more members to the group by sending GROUP commands.
      # Handles both String names and GameObj instances.
      # Can accept nested arrays of members.
      #
      # @param members [Array<String, GameObj, Array>] members to add
      # @return [Array<Hash>] array of results, each containing :ok or :err key with member
      # @example Add a single member
      #   Group.add("PlayerName")
      # @example Add multiple members
      #   Group.add("Player1", "Player2")
      def self.add(*members)
        members.map do |member|
          if member.is_a?(Array)
            Group.add(*member)
          else
            member = GameObj.pcs.find { |pc| pc.noun.eql?(member) } if member.is_a?(String)

            break if member.nil?

            result = dothistimeout("group ##{member.id}", 3, Regexp.union(
                                                               %r{You add #{member.noun} to your group},
                                                               %r{#{member.noun}'s group status is closed},
                                                               %r{But #{member.noun} is already a member of your group}
                                                             ))

            case result
            when %r{You add}, %r{already a member}
              Group.push(member)
              { ok: member }
            when %r{closed}
              Group.delete(member)
              { err: member }
            else
            end
          end
        end
      end

      # Returns array of all member IDs.
      #
      # @return [Array<String>] array of member IDs
      def self.ids
        @@members.map(&:id)
      end

      # Returns array of all member nouns (names).
      #
      # @return [Array<String>] array of member nouns
      def self.nouns
        @@members.map(&:noun)
      end

      # Checks if all specified members are in the group.
      #
      # @param members [Array<GameObj>] members to check
      # @return [Boolean] true if all members are in the group
      def self.include?(*members)
        members.all? { |m| ids.include?(m.id) }
      end

      # Checks if the group state is broken or inconsistent.
      # Waits for any claim locks to release before checking.
      # For leaders: checks if member list matches actual PCs in room.
      # For members: checks if leader is still present.
      #
      # @return [Boolean] true if group state is inconsistent
      def self.broken?
        sleep(0.1) while Lich::Gemstone::Claim::Lock.locked?
        if Group.leader?
          return true if (GameObj.pcs.empty? || GameObj.pcs.nil?) && !@@members.empty?
          return false if (GameObj.pcs.empty? || GameObj.pcs.nil?) && @@members.empty?
          (GameObj.pcs.map(&:noun) & @@members.map(&:noun)).size < @@members.size
        else
          GameObj.pcs.find do |pc| pc.noun.eql?(Group.leader.noun) end.nil?
        end
      end

      # Delegates missing methods to the members array.
      # Allows Group to act like an Array in many contexts.
      #
      # @api private
      def self.method_missing(method, *args, &block)
        @@members.send(method, *args, &block)
      end
    end

    class Group
      # Observes game output and automatically updates Group state.
      # Watches for group-related messages and updates membership, leadership, and status.
      module Observer
        # Regular expressions and constants for matching group-related game output.
        module Term
          # Matches when someone joins your group
          # @example "<a exist="-10467645" noun="Oreh">Oreh</a> joins your group."
          JOIN    = %r{^<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> joins your group.\r?\n?$}
          
          # Matches when someone leaves your group
          # @example "<a exist="-10467645" noun="Oreh">Oreh</a> leaves your group"
          LEAVE   = %r{^<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> leaves your group.\r?\n?$}
          
          # Matches when you add someone to your group
          # @example "You add <a exist="-10467645" noun="Oreh">Oreh</a> to your group."
          ADD     = %r{^You add <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> to your group.\r?\n?$}
          
          # Matches when you remove someone from the group
          # @example "You remove <a exist="-10467645" noun="Oreh">Oreh</a> from the group."
          REMOVE  = %r{^You remove <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> from the group.\r?\n?$}
          
          # Matches when trying to add someone already in group
          # @example "But <a exist="-10467645" noun="Oreh">Oreh</a> is already a member of your group!"
          NOOP    = %r{^But <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> is already a member of your group!\r?\n?$}
          
          # Matches when you receive leadership
          # @example "<a exist="-10488845" noun="Etanamir">Etanamir</a> designates you as the new leader of the group."
          HAS_LEADER = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> designates you as the new leader of the group\.\r?\n?$}
          
          # Matches when leadership changes to another player
          # @example "<a exist="-10488845" noun="Etanamir">Etanamir</a> designates <a exist="-10488845" noun="Ondreian">Ondreian</a> as the new leader of the group."
          SWAP_LEADER = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> designates <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> as the new leader of the group.\r?\n?$}

          # Matches when you give away leadership
          # @example "You designate <a exist="-10778599" noun="Ondreian">Ondreian</a> as the new leader of the group."
          GAVE_LEADER_AWAY = %r{You designate <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> as the new leader of the group\.\r?\n?$}
          
          # Matches when you disband the group
          # @example "You disband your group."
          DISBAND = %r{^You disband your group}
          
          # Matches when you're added to someone's group
          # @example "<a exist="-10488845" noun="Etanamir">Etanamir</a> adds you to <a exist="-10488845" noun="Etanamir">his</a> group."
          ADDED_TO_NEW_GROUP = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> adds you to <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> group.\r?\n?$}
          
          # Matches when you join someone's group
          # @example "You join <a exist="-10488845" noun="Etanamir">Etanamir</a>."
          JOINED_NEW_GROUP = %r{You join <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a>\.\r?\n?$}
          
          # Matches when your leader adds another member
          # @example "<a exist="-10488845" noun="Etanamir">Etanamir</a> adds <a exist="-10974229" noun="Szan">Szan</a> to <a exist="-10488845" noun="Etanamir">his</a> group."
          LEADER_ADDED_MEMBER = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> adds <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> to <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> group\.\r?\n?$}
          
          # Matches when your leader removes a member
          # @example "<a exist="-10488845" noun="Etanamir">Etanamir</a> removes <a exist="-10974229" noun="Szan">Szan</a> from the group."
          LEADER_REMOVED_MEMBER = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> removes <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> from the group\.\r?\n?$}
          
          # Matches when you grab someone's hand (reserved demeanor)
          # @example "You grab <a exist="-10070682" noun="Dicate">Dicate's</a> hand."
          HOLD_RESERVED_FIRST = %r{^You grab <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>[\w']+?)</a> hand.\r?\n?$}
          
          # Matches when you hold someone's hand (neutral demeanor)
          HOLD_NEUTRAL_FIRST = %r{^You reach out and hold <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>[\w']+?)</a> hand.\r?\n?$}
          
          # Matches when you take someone's hand (friendly demeanor)
          HOLD_FRIENDLY_FIRST = %r{^You gently take hold of <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>[\w']+?)</a> hand.\r?\n?$}
          
          # Matches when you clasp someone's hand (warm demeanor)
          HOLD_WARM_FIRST = %r{^You clasp <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>[\w']+?)</a> hand tenderly.\r?\n?$}
          
          # Matches when someone grabs your hand (reserved demeanor)
          # @example "<indicator id='IconJOINED' visible='y'/><a exist="-10966483" noun="Nisugi">Nisugi</a> grabs your hand."
          HOLD_RESERVED_SECOND = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> grabs your hand.\r?\n?$}
          
          # Matches when someone holds your hand (neutral demeanor)
          HOLD_NEUTRAL_SECOND = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> reaches out and holds your hand.\r?\n?$}
          
          # Matches when someone takes your hand (friendly demeanor)
          HOLD_FRIENDLY_SECOND = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> gently takes hold of your hand.\r?\n?$}
          
          # Matches when someone clasps your hand (warm demeanor)
          HOLD_WARM_SECOND = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> clasps your hand tenderly.\r?\n?$}
          
          # Matches when you observe someone grabbing another's hand (reserved demeanor)
          # @example "<a exist="-10966483" noun="Nisugi">Nisugi</a> grabs <a exist="-10070682" noun="Dicate">Dicate's</a> hand."
          HOLD_RESERVED_THIRD = %r{^<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>[\w']+?)</a> grabs <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>[\w']+?)</a> hand.\r?\n?$}
          
          # Matches when you observe someone holding another's hand (neutral demeanor)
          HOLD_NEUTRAL_THIRD = %r{^<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>[\w']+?)</a> reaches out and holds <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>[\w']+?)</a> hand.\r?\n?$}
          
          # Matches when you observe someone taking another's hand (friendly demeanor)
          HOLD_FRIENDLY_THIRD = %r{^<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>[\w']+?)</a> gently takes hold of <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>[\w']+?)</a> hand.\r?\n?$}
          
          # Matches when you observe someone clasping another's hand (warm demeanor)
          HOLD_WARM_THIRD = %r{^<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> clasps <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>[\w']+?)</a> hand tenderly.\r?\n?$}
          
          # Matches when someone else joins another's group
          # @example "<a exist="-10154507" noun="Zoleta">Zoleta</a> joins <a exist="-10966483" noun="Nisugi">Nisugi's</a> group."
          OTHER_JOINED_GROUP = %r{^<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> joins <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>[\w']+?)</a> group.\r?\n?$}
          
          # Matches when not in any group
          NO_GROUP = /^You are not currently in a group/
          
          # Matches group member listing from GROUP command
          # @example "You are leading PlayerName, PlayerName2."
          # @example "You are grouped with LeaderName, PlayerName."
          MEMBER   = /^You are (?:leading|grouped with) (.*)/
          
          # Matches group status line
          # @example "Your group status is currently open."
          STATUS   = /^Your group status is currently (?<status>open|closed)\./

          # UI indicator showing group is empty
          GROUP_EMPTIED    = %[<indicator id='IconJOINED' visible='n'/>]
          
          # UI indicator showing group exists
          GROUP_EXISTS     = %[<indicator id='IconJOINED' visible='y'/>]
          
          # Text indicating leadership transfer
          GIVEN_LEADERSHIP = %[designates you as the new leader of the group.]

          # Combined regex matching any group-related message
          ANY = Regexp.union(
            JOIN,
            LEAVE,
            ADD,
            REMOVE,
            DISBAND,
            NOOP,
            STATUS,
            NO_GROUP,
            MEMBER,
            HAS_LEADER,
            SWAP_LEADER,
            LEADER_ADDED_MEMBER,
            LEADER_REMOVED_MEMBER,
            ADDED_TO_NEW_GROUP,
            JOINED_NEW_GROUP,
            GAVE_LEADER_AWAY,
            HOLD_RESERVED_FIRST,
            HOLD_NEUTRAL_FIRST,
            HOLD_FRIENDLY_FIRST,
            HOLD_WARM_FIRST,
            HOLD_RESERVED_SECOND,
            HOLD_NEUTRAL_SECOND,
            HOLD_FRIENDLY_SECOND,
            HOLD_WARM_SECOND,
            HOLD_RESERVED_THIRD,
            HOLD_NEUTRAL_THIRD,
            HOLD_FRIENDLY_THIRD,
            HOLD_WARM_THIRD,
            OTHER_JOINED_GROUP,
          )

          # Regex for extracting character data from XML tags
          EXIST = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>[\w']+?)</a>}
        end

        # Extracts GameObj instances from XML character links in game output.
        #
        # @param xml [String] game output containing character XML tags
        # @return [Array<GameObj>] array of GameObj instances found in the XML
        def self.exist(xml)
          xml.scan(Group::Observer::Term::EXIST).map { |id, _noun, _name| GameObj[id] }
        end

        # Checks if a line of game output contains group-related information.
        #
        # @param line [String] line of game output
        # @return [Boolean] true if line contains group information
        def self.wants?(line)
          line.strip.match(Term::ANY) or
            line.include?(Term::GROUP_EMPTIED)
        end

        # Processes a line of group-related game output and updates Group state.
        # Handles all types of group changes: joins, leaves, leadership changes, etc.
        #
        # @param line [String] line of game output
        # @param match_data [MatchData] regex match data from the line
        # @return [void]
        def self.consume(line, match_data)
          if line.include?(Term::GIVEN_LEADERSHIP)
            return Group.leader = :self
          end

          ## Group indicator changed!
          if line.include?(Term::GROUP_EMPTIED)
            Group.leader = :self
            return Group._members.clear
          end

          people = exist(line)

          if line.include?("You are leading")
            Group.leader = :self
          elsif line.include?("You are grouped with")
            Group.leader = people.first
          end

          case line
          when Term::NO_GROUP, Term::DISBAND
            Group.leader = :self
            return Group._members.clear
          when Term::STATUS
            Group.status = match_data[:status].to_sym
            return Group.checked = true
          when Term::GAVE_LEADER_AWAY
            Group.push(people.first)
            return Group.leader = people.first
          when Term::ADDED_TO_NEW_GROUP, Term::JOINED_NEW_GROUP
            Group.checked = false
            Group.push(people.first)
            return Group.leader = people.first
          when Term::SWAP_LEADER
            (old_leader, new_leader) = people
            Group.push(*people) if Group.include?(old_leader) or Group.include?(new_leader)
            return Group.leader = new_leader
          when Term::LEADER_ADDED_MEMBER
            (leader, added) = people
            Group.push(added) if Group.include?(leader)
          when Term::LEADER_REMOVED_MEMBER
            (leader, removed) = people
            return Group.delete(removed) if Group.include?(leader)
          when Term::JOIN, Term::ADD, Term::NOOP
            return Group.push(*people)
          when Term::MEMBER
            return Group.refresh(*people)
          when Term::HOLD_FRIENDLY_FIRST, Term::HOLD_NEUTRAL_FIRST, Term::HOLD_RESERVED_FIRST, Term::HOLD_WARM_FIRST
            return Group.push(people.first)
          when Term::HOLD_FRIENDLY_SECOND, Term::HOLD_NEUTRAL_SECOND, Term::HOLD_RESERVED_SECOND, Term::HOLD_WARM_SECOND
            Group.checked = false
            Group.push(people.first)
            return Group.leader = people.first
          when Term::HOLD_FRIENDLY_THIRD, Term::HOLD_NEUTRAL_THIRD, Term::HOLD_RESERVED_THIRD, Term::HOLD_WARM_THIRD
            (leader, added) = people
            Group.push(added) if Group.include?(leader)
          when Term::OTHER_JOINED_GROUP
            (added, leader) = people
            Group.push(added) if Group.include?(leader)
          when Term::LEAVE, Term::REMOVE
            return Group.delete(*people)
          end
        end
      end
    end
  end
end
