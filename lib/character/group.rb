require "ostruct"
require "benchmark"
require "lib/character/disk"

module Games
  module Gemstone
    class Group
      @@members ||= []
      @@leader  ||= nil
      @@checked ||= false
      @@status  ||= :closed

      def self.clear()
        @@members = []
        @@checked = false
      end

      def self.checked?
        @@checked
      end

      def self.push(*members)
        members.each do |member|
          @@members.push(member) unless include?(member)
        end
      end

      def self.delete(*members)
        gone = members.map(&:id)
        @@members.reject! do |m| gone.include?(m.id) end
      end

      def self.members
        maybe_check
        @@members.dup
      end

      def self._members
        @@members
      end

      def self.disks
        return [Disk.find_by_name(Char.name)].compact unless Group.leader?
        members.map(&:noun).map do |noun| Disk.find_by_name(noun) end.compact
      end

      def self.to_s
        @@members.to_s
      end

      def self.checked=(flag)
        @@checked = flag
      end

      def self.status=(state)
        @@status = state
      end

      def self.status()
        @@status
      end

      def self.open?
        maybe_check
        @@status.eql?(:open)
      end

      def self.closed?
        not open?
      end

      # ran at the initialization of a script
      def self.check
        Group.clear()
        ttl = Time.now + 3
        Game._puts "<c>group\r\n"
        wait_until { Group.checked? or Time.now > ttl }
        @@members.dup
      end

      def self.maybe_check
        Group.check unless checked?
      end

      def self.nonmembers
        GameObj.pcs.to_a.reject { |pc| ids.include?(pc.id) }
      end

      def self.leader=(char)
        @@leader = char
      end

      def self.leader
        @@leader
      end

      def self.leader?
        @@leader.eql?(:self)
      end

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

      def self.ids
        @@members.map(&:id)
      end

      def self.include?(*members)
        members.all? { |m| ids.include?(m.id) }
      end

      def self.broken?
        if Group.leader?
          (GameObj.pcs.map(&:noun) & @@members.map(&:noun)).size < @@members.size
        else
          GameObj.pcs.find do |pc| pc.noun.eql?(Group.leader.noun) end.nil?
        end
      end

      def self.method_missing(method, *args, &block)
        @@members.send(method, *args, &block)
      end
    end

    class Group
      module Observer
        module Term
          ##
          ## passive messages
          ##
          # <a exist="-10467645" noun="Oreh">Oreh</a> joins your group.
          JOIN    = %r{^<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> joins your group.$}
          # <a exist="-10467645" noun="Oreh">Oreh</a> leaves your group
          LEAVE   = %r{^<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> leaves your group.$}
          # You add <a exist="-10467645" noun="Oreh">Oreh</a> to your group.
          ADD     = %r{^You add <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> to your group.$}
          # You remove <a exist="-10467645" noun="Oreh">Oreh</a> from the group.
          REMOVE  = %r{^You remove <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> from the group.$}
          NOOP    = %r{^But <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> is already a member of your group!$}
          # <a exist="-10488845" noun="Etanamir">Etanamir</a> designates you as the new leader of the group.
          HAS_LEADER = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> designates you as the new leader of the group\.$}
          SWAP_LEADER = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> designates <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> as the new leader of the group.}

          # You designate <a exist="-10778599" noun="Ondreian">Ondreian</a> as the new leader of the group.
          GAVE_LEADER_AWAY = %r{You designate <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> as the new leader of the group\.$}
          # You disband your group.
          DISBAND = %r{^You disband your group}
          # <a exist="-10488845" noun="Etanamir">Etanamir</a> adds you to <a exist="-10488845" noun="Etanamir">his</a> group.
          ADDED_TO_NEW_GROUP = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> adds you to <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> group.}
          # You join <a exist="-10488845" noun="Etanamir">Etanamir</a>.
          JOINED_NEW_GROUP = %r{You join <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a>\.$}
          # <a exist="-10488845" noun="Etanamir">Etanamir</a> adds <a exist="-10974229" noun="Szan">Szan</a> to <a exist="-10488845" noun="Etanamir">his</a> group.
          LEADER_ADDED_MEMBER = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> adds <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> to <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> group\.$}
          # <a exist="-10488845" noun="Etanamir">Etanamir</a> removes <a exist="-10974229" noun="Szan">Szan</a> from the group.
          LEADER_REMOVED_MEMBER = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> removes <a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a> from the group\.$}
          ##
          ## active messages
          ##
          NO_GROUP = /You are not currently in a group/
          MEMBER   = /<a exist="(?<id>.*?)" noun="(?<name>.*?)">(?:.*?)<\/a> is (?<type>(?:the leader|also a member) of your group|following you)\./
          STATUS   = /^Your group status is currently (?<status>open|closed)\./

          GROUP_EMPTIED    = %[<indicator id='IconJOINED' visible='n'/>]
          GROUP_EXISTS     = %[<indicator id='IconJOINED' visible='y'/>]
          GIVEN_LEADERSHIP = %[designates you as the new leader of the group.]

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
          )

          EXIST = %r{<a exist="(?<id>[\d-]+)" noun="(?<noun>[A-Za-z]+)">(?<name>\w+?)</a>}
        end

        CALLBACK = ->line {
          begin
            # fast first-pass
            if line.include?("group") or line.include?("following you") or line.include?("IconJOINED")
              # more detailed pass
              if (match_data = Observer.wants?(line))
                Observer.consume(line.strip, match_data)
              end
            end
          rescue => exception
            respond(exception)
            respond(exception.backtrace)
          ensure
            return line
          end
        }

        def self.exist(xml)
          xml.scan(Group::Observer::Term::EXIST).map { |id, _noun, _name| GameObj[id] }
        end

        def self.wants?(line)
          line.strip.match(Term::ANY) or
            line.include?(Term::GROUP_EMPTIED)
        end

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

          if line.include?("is following you")
            Group.leader = :self
          elsif line.include?("is the leader of your group")
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
          when Term::JOIN, Term::ADD, Term::NOOP, Term::MEMBER
            return Group.push(*people)
          when Term::LEAVE, Term::REMOVE
            return Group.delete(*people)
          end
        end

        def self.attach()
          remove() if DownstreamHook.list.include?(self.name)
          DownstreamHook.add(self.name, CALLBACK)
        end

        def self.remove()
          DownstreamHook.remove(self.name)
        end
      end

      Observer.attach()
    end
  end
end
