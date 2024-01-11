module Lich
  module Claim
    Lock            = Mutex.new
    @claimed_room ||= nil
    @last_room    ||= nil
    @mine         ||= false
    @buffer         = []
    @others         = []
    @timestamp      = Time.now

    def self.claim_room(id)
      @claimed_room = id.to_i
      @timestamp    = Time.now
      Log.out("claimed #{@claimed_room}", label: %i(claim room)) if defined?(Log)
      Lock.unlock
    end

    def self.claimed_room
      @claimed_room
    end

    def self.last_room
      @last_room
    end

    def self.lock
      Lock.lock if !Lock.owned?
    end

    def self.unlock
      Lock.unlock if Lock.owned?
    end

    def self.current?
      Lock.synchronize { @mine.eql?(true) }
    end

    def self.checked?(room = nil)
      Lock.synchronize { XMLData.room_id == (room || @last_room) }
    end

    def self.info
      rows = [['XMLData.room_id', XMLData.room_id, 'Current room according to the XMLData'],
              ['Claim.mine?', Claim.mine?, 'Claim status on the current room'],
              ['Claim.claimed_room', Claim.claimed_room, 'Room id of the last claimed room'],
              ['Claim.checked?', Claim.checked?, "Has Claim finished parsing ROOMID\ndefault: the current room"],
              ['Claim.last_room', Claim.last_room, 'The last room checked by Claim, regardless of status'],
              ['Claim.others', Claim.others.join("\n"), "Other characters in the room\npotentially less grouped characters"]]
      info_table = Terminal::Table.new :headings => ['Property', 'Value', 'Description'],
                                       :rows     => rows,
                                       :style    => { :all_separators => true }
      Lich::Messaging.mono(info_table.to_s)
    end

    def self.mine?
      self.current?
    end

    def self.others
      @others
    end

    def self.members
      return [] unless defined? Group

      begin
        if Group.checked?
          return Group.members.map(&:noun)
        else
          return []
        end
      rescue
        return []
      end
    end

    def self.clustered
      begin
        return [] unless defined? Cluster
        Cluster.connected
      rescue
        return []
      end
    end

    def self.parser_handle(nav_rm, pcs)
      echo "Claim handled #{nav_rm} with xmlparser" if $claim_debug
      begin
        @others = pcs - self.clustered - self.members
        @last_room = nav_rm
        unless @others.empty?
          @mine = false
          return
        end
        @mine = true
        self.claim_room nav_rm unless nav_rm.nil?
      rescue StandardError => e
        if defined?(Log)
          Log.out(e)
        else
          respond("Claim Parser Error: #{e}")
        end
      ensure
        Lock.unlock if Lock.owned?
      end
    end
  end
end
