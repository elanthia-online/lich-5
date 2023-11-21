# handles instances of modules that are game dependent
module GameLoader
  def self.gemstone
    require 'lib/map/map_gs.rb'
    require 'lib/spell'
    require 'lib/bounty'
    require 'lib/claim'
    require 'lib/infomon/infomon'
    require 'lib/attributes/resources'
    require 'lib/attributes/stats'
    require 'lib/attributes/spells'
    require 'lib/attributes/skills'
    require 'lib/attributes/society'
    require 'lib/infomon/status'
    require 'lib/experience'
    require 'lib/attributes/spellsong'
    require 'lib/infomon/activespell'
    ActiveSpell.watch!
    # PSMS (armor, cman, feat, shield, weapon) have moved
    # to ./lib/psms and are now called by psms.rb
    require 'lib/psms'
    require 'lib/attributes/char'
    require 'lib/infomon/currency'
  end

  def self.dragon_realms
    require 'lib/map/map_dr.rb'
    require 'lib/attributes/char'
  end

  def self.load!
    sleep 0.1 while XMLData.game.nil? or XMLData.game.empty?
    return self.dragon_realms if XMLData.game =~ /DR/
    return self.gemstone if XMLData.game =~ /GS/
    echo "could not load game specifics for %s" % XMLData.game
  end
end
