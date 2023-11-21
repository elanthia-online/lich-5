
module Claim
  Lock            = Mutex.new
  @claimed_room   ||= nil
  @last_room      ||= nil
  @mine           ||= false
  @buffer         = []
  @others         = []
  @timestamp      = Time.now

  def self.claim_room(id)
    @claimed_room = id.to_i
    @timestamp    = Time.now
    Log.out("claimed #{@claimed_room}", label: %i(claim room)) if defined? Log
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
    info = {'Current Room' => XMLData.room_id,
            'Mine' => Claim.mine?,
            'Claimed Room' => Claim.claimed_room,
            'Checked' => Claim.checked?,
            'Last Room' => Claim.last_room,
            'Others' => Claim.others}
    respond JSON.pretty_generate(info)
  end

  def self.mine?
    self.current?
  end

  def self.others
    @others
  end

  def self.members
    return [] unless defined? Group

    if Group.checked?
      Group.members.map(&:noun)
    else
      []
    end
  end

  def self.clustered
    return [] unless defined? Cluster 
    Cluster.connected
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
      Log.out(e)
    ensure
      Lock.unlock if Lock.owned?
    end
  end

end