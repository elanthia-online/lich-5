class Script
  def Script.current
    nil
  end
end

module Lich
  def self.log(msg)
    debug_filename = "debug-#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}.log"
    $stderr = File.open(debug_filename, 'w')
    begin
      $stderr.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}: #{msg}"
    end
  end
end

class NilClass
  def method_missing(*)
    nil
  end
end

module XMLData
  @dialogs = {}
  def self.game
    "rspec"
  end

  def self.name
    "testing"
  end

  def self.indicator
    # shimming together a hash to test 'muckled?' results
    { 'IconSTUNNED' => 'n',
      'IconDEAD'    => 'n',
      'IconWEBBED'  => false }
  end

  def self.save_dialogs(kind, attributes)
    # shimming together response for testing status checks
    @dialogs[kind] ||= {}
    return @dialogs[kind] = attributes
  end

  def self.dialogs
    @dialogs ||= {}
  end

  def self.stamina
    return 20 # some PSM require 30, so we should have negative testing ability
  end
end

# stub in Effects module for testing - not suitable for testing Effects itself
module Lich
module Util
module Effects
  class Registry
    include Enumerable

    def initialize(dialog)
      @dialog = dialog
    end

    def to_h
      XMLData.dialogs.fetch(@dialog, {})
    end

    def each()
      to_h.each { |k, v| yield(k, v) }
    end

    def active?(effect)
      expiry = to_h.fetch(effect, 0)
      expiry.to_f > Time.now.to_f
    end

    def time_left(effect)
      expiry = to_h.fetch(effect, 0)
      if to_h.fetch(effect, 0) != 0
        ((expiry - Time.now) / 60.to_f)
      else
        expiry
      end
    end
  end

  Spells    = Registry.new("Active Spells")
  Buffs     = Registry.new("Buffs")
  Debuffs   = Registry.new("Debuffs")
  Cooldowns = Registry.new("Cooldowns")
end
end
end

module Char
  def self.name
    "testing"
  end
end

require 'rexml/document'
require 'rexml/streamlistener'
require 'open-uri'
require "attributes/spellsong"
require "common/spell"
require 'tmpdir'

Dir.mktmpdir do |dir|
  local_filename = File.join(dir, "effect-list.xml")
  print "Downloading effect-list.xml..."
  download = URI.open('https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts/effect-list.xml').read
  File.write(local_filename, download)
  Lich::Common::Spell.load(local_filename)
  puts " Done!"
end

LIB_DIR = File.join(File.expand_path("..", File.dirname(__FILE__)), 'lib')

require 'util/util'
require 'gemstone/psms'
require 'gemstone/infomon'
require 'attributes/skills'

# we need to set up some test data, stealing from infomon_spec.rb
describe Lich::Gemstone::Infomon, ".setup!" do
  context "can set itself up" do
    it "creates a db" do
      Lich::Gemstone::Infomon.setup!
      File.exist?(Lich::Gemstone::Infomon.file) or fail("infomon sqlite db was not created")
    end
  end

  context "can set up data" do
    it "creates key/value pair for our testing" do
      Lich::Gemstone::Infomon.set("cman.acrobatsleap", 0)
      Lich::Gemstone::Infomon.set("cman.bearhug", 0)
      Lich::Gemstone::Infomon.set("cman.berserk", 0)
      Lich::Gemstone::Infomon.set("weapon.reactiveshot", 0)
      Lich::Gemstone::Infomon.set("weapon.reversestrike", 0)
      Lich::Gemstone::Infomon.set("weapon.spinkick", 0)
      Lich::Gemstone::Infomon.set("weapon.thrash", 0)
      Lich::Gemstone::Infomon.set("weapon.twinhammer", 1)
      Lich::Gemstone::Infomon.set("weapon.volley", 0)
      Lich::Gemstone::Infomon.set("weapon.wblade", 0)
      Lich::Gemstone::Infomon.set("weapon.whirlwind", 0)
      Lich::Gemstone::Infomon.set("armor.blessing", 0)
      Lich::Gemstone::Infomon.set("armor.reinforcement", 0)
      Lich::Gemstone::Infomon.set("armor.support", 0)
      Lich::Gemstone::Infomon.set("shield.tfocus", 0)
      Lich::Gemstone::Infomon.set("cman.krynch", 1)
      Lich::Gemstone::Infomon.set("cman.mongoose", 1)
      Lich::Gemstone::Infomon.set("cman.vaultkick", 1)
      Lich::Gemstone::Infomon.set("feat.martialmastery", 1)
      Lich::Gemstone::Infomon.set("feat.tattoo", 1)
    end
  end
end

describe Lich::Gemstone::PSMS, ".name_normal(name)" do
  context "it normalizes PSM name requests" do
    it "normalizes text full name PSM requests" do
      expect(Lich::Gemstone::PSMS.name_normal("Rolling Krynch Stance")).to eq("rolling_krynch_stance")
    end
    it "normalizes symbol full name PSM requests" do
      expect(Lich::Gemstone::PSMS.name_normal(:vault_kick)).to eq("vault_kick")
    end
    it "normalizes text with underscore name PSM requests" do
      expect(Lich::Gemstone::PSMS.name_normal("sunder_shield")).to eq("sunder_shield")
    end
    it "normalizes simple symbol name PSM requests" do
      expect(Lich::Gemstone::PSMS.name_normal(:blessings)).to eq("blessings")
    end
    it "does not attempt to compare validity, just normalize requests" do
      expect(Lich::Gemstone::PSMS.name_normal("this is my request")).to eq("this_is_my_request")
    end
    it "has intake of all case character types and will perform the function" do
      expect(Lich::Gemstone::PSMS.name_normal("THIS simply CANNOT be")).to eq("this_simply_cannot_be")
    end
  end
end

## FIXME: Error out due to name CMan in psms.rb not fully qualified / works in prod
describe Lich::Gemstone::PSMS, "assess(name, type)" do
  context "<psm>.name should return rank known" do
    it "parses request and determines resopnse" do
      expect(Lich::Gemstone::CMan[:vaultkick]).to eq(1)
      expect(Lich::Gemstone::Weapon["Twin Hammerfists"]).to eq(1)
      expect(Lich::Gemstone::Armor["reinforcement"]).to eq(0)
      expect(Lich::Gemstone::Feat[:mystic_tattoo]).to eq(1)
    end
    it "checks if PSM known (rank > 0) and returns true / false" do
      expect(Lich::Gemstone::CMan.known?(:bearhug)).to be(false)
      expect(Lich::Gemstone::Weapon.known?(:twin_hammerfists)).to be(true)
      expect(Lich::Gemstone::Armor.known?("blessing")).to be(false)
      expect(Lich::Gemstone::Feat.known?("Martial MASTERY")).to be(true)
    end
    it "or determines if an unknown PSM (error) is requested" do
      expect { Lich::Gemstone::CMan["Doug Spell"] }.to raise_error(StandardError, "Aborting script - The referenced CMan skill doug_spell is invalid.\r\nCheck your PSM category (Armor, CMan, Feat, Shield, Warcry, Weapon) and your spelling of doug_spell.")
      expect { Lich::Gemstone::Armor.known?(:favorite_dessert) }.to raise_error(StandardError, "Aborting script - The referenced Armor skill favorite_dessert is invalid.\r\nCheck your PSM category (Armor, CMan, Feat, Shield, Warcry, Weapon) and your spelling of favorite_dessert.")
    end
  end
end

describe Lich::Gemstone::PSMS, ".affordable?(name)" do
  context "<psm>, name should determine available (cost < stamina)" do
    it "checks to see if the PSM cost < current stamina" do
      # it does not distinguish at this phase if PSM is known or not known
      expect(Lich::Gemstone::Armor.affordable?(:support)).to be(true)
      expect(Lich::Gemstone::CMan.affordable?("rolling_krynch_stance")).to be(false)
    end
    it "or returns erroneous requests as above" do
      expect { Lich::Gemstone::Feat.affordable?("Touch this!") }.to raise_error(StandardError, "Aborting script - The referenced Feat skill touch_this! is invalid.\r\nCheck your PSM category (Armor, CMan, Feat, Shield, Warcry, Weapon) and your spelling of touch_this!.")
    end
  end
end

describe Lich::Gemstone::PSMS, ".can_forcert?(times)" do
  context "<psm>, times should determine if forced roundtime (forcert) rounds can be performed" do
    it "checks to see if the character can perform the given number of forcert rounds" do
      Lich::Gemstone::Infomon.set("skill.multi_opponent_combat", 10)
      expect(Lich::Gemstone::PSMS.can_forcert?(1)).to be(true)
      expect(Lich::Gemstone::PSMS.can_forcert?(4)).to be(false)
      Lich::Gemstone::Infomon.set("skill.multi_opponent_combat", 200)
      expect(Lich::Gemstone::PSMS.can_forcert?(4)).to be(true)
    end
  end
end

describe Lich::Gemstone::PSMS, ".max_forcert_count" do
  context "<psm>, times should determine the maximum number of forced roundtime (forcert) rounds" do
    it "checks to see if the character can perform the given number of forcert rounds" do
      Lich::Gemstone::Infomon.set("skill.multi_opponent_combat", 10)
      expect(Lich::Gemstone::PSMS.max_forcert_count).to eq(1)
      Lich::Gemstone::Infomon.set("skill.multi_opponent_combat", 200)
      expect(Lich::Gemstone::PSMS.max_forcert_count).to eq(4)
    end
  end
end
