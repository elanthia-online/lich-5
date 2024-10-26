# handles instances of modules that are game dependent
module GameLoader
  def self.common_before
    require File.join(LIB_DIR, 'log.rb')
  end

  def self.gemstone
    self.common_before
    require File.join(LIB_DIR, 'map', 'map_gs.rb')
    require File.join(LIB_DIR, 'spell.rb')
    require File.join(LIB_DIR, 'effects.rb')
    require File.join(LIB_DIR, 'bounty.rb')
    require File.join(LIB_DIR, 'claim.rb')
    require File.join(LIB_DIR, 'infomon', 'infomon.rb')
    require File.join(LIB_DIR, 'attributes', 'resources.rb')
    require File.join(LIB_DIR, 'attributes', 'stats.rb')
    require File.join(LIB_DIR, 'attributes', 'spells.rb')
    require File.join(LIB_DIR, 'attributes', 'skills.rb')
    require File.join(LIB_DIR, 'attributes', 'society.rb')
    require File.join(LIB_DIR, 'infomon', 'status.rb')
    require File.join(LIB_DIR, 'experience.rb')
    require File.join(LIB_DIR, 'attributes', 'spellsong.rb')
    require File.join(LIB_DIR, 'infomon', 'activespell.rb')
    ActiveSpell.watch!
    # PSMS (armor, cman, feat, shield, weapon) have moved
    # to ./lib/psms and are now called by psms.rb
    require File.join(LIB_DIR, 'psms.rb')
    require File.join(LIB_DIR, 'attributes', 'char.rb')
    require File.join(LIB_DIR, 'infomon', 'currency.rb')
    require File.join(LIB_DIR, 'character', 'disk.rb')
    require File.join(LIB_DIR, 'character', 'group.rb')
    require File.join(LIB_DIR, 'critranks')
    # self.common_after
  end

  def self.dragon_realms
    self.common_before
    require File.join(LIB_DIR, 'map', 'map_dr.rb')
    require File.join(LIB_DIR, 'attributes', 'char.rb')
    require File.join(LIB_DIR, 'dragonrealms', 'drinfomon', 'drinfomon.rb')
    # self.common_after
  end

  def self.common_after
    nil
  end

  def self.load!
    sleep 0.1 while XMLData.game.nil? or XMLData.game.empty?
    return self.dragon_realms if XMLData.game =~ /DR/
    return self.gemstone if XMLData.game =~ /GS/
    echo "could not load game specifics for %s" % XMLData.game
  end
end
