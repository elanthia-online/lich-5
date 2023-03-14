module GameLoader
  def self.gemstone
    require 'lib/map/map_gs.rb'
    require 'lib/stats/stats_gs.rb'
  end

  def self.dragon_realms
    require 'lib/map/map_dr.rb'
    require 'lib/stats/stats_dr.rb'
  end

  def self.load!
    sleep 0.1 while XMLData.game.nil? or XMLData.game.empty?
    return self.dragon_realms if XMLData.game =~ /DR/
    return self.gemstone if XMLData.game =~ /GS/
    echo "could not load game specifics for %s" % XMLData.game
  end
end
