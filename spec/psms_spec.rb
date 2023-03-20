require "psms"
require "psms/armor"
require "psms/cman"
require "psms/feat"
require "psms/shield"
require "psms/weapon"
require "infomon/infomon"

module Char
  def self.name
    "testing"
  end
end

module XMLData
  def self.game
    "rspec"
  end

  def self.stamina
    return 20 # some PSM require 30, so we should have negative testing ability
  end
end

# we need to set up some test data, stealing from infomon_spec.rb
describe Infomon, ".setup!" do
  context "can set itself up" do
    it "creates a db" do
      Infomon.setup!
      File.exist?(Infomon.file) or fail("infomon sqlite db was not created")
    end
  end

  context "can set up data" do
    it "creates key/value pair for our testing" do
      Infomon.set("psm.acrobatsleap", 0)
      Infomon.set("psm.bearhug", 0)
      Infomon.set("psm.berserk", 0)
      Infomon.set("psm.reactiveshot", 0)
      Infomon.set("psm.reversestrike", 0)
      Infomon.set("psm.spinkick", 0)
      Infomon.set("psm.thrash", 0)
      Infomon.set("psm.twinhammer", 1)
      Infomon.set("psm.volley", 0)
      Infomon.set("psm.wblade", 0)
      Infomon.set("psm.whirlwind", 0)
      Infomon.set("psm.blessing", 0)
      Infomon.set("psm.reinforcement", 0)
      Infomon.set("psm.support", 0)
      Infomon.set("psm.tfocus", 0)
      Infomon.set("psm.krynch", 1)
      Infomon.set("psm.mongoose", 1)
      Infomon.set("psm.vaultkick", 1)
      Infomon.set("psm.martialmastery", 1)
      Infomon.set("psm.tattoo", 1)
    end
  end
end

describe PSM, "._name_normal(name)" do
  context "it normalizes PSM name requests" do
    it "normalizes text full name PSM requests" do
      expect(PSM._name_normal("Rolling Krynch Stance")).to eq(%w[rolling_krynch_stance])
    end
    it "normalizes symbol full name PSM requests" do
      expect(PSM._name_normal(:vault_kick)).to eq(%w[vault_kick])
    end
    it "normalizes text with underscore name PSM requests" do
      expect(PSM._name_normal("sunder_shield")).to eq(%w[sunder_shield])
    end
    it "normalizes simple symbol name PSM requests" do
      expect(PSM._name_normal(:blessings)).to eq(%w[blessings])
    end
    it "does not attempt to compare validity, just normalize requests" do
      expect(PSM._name_normal("this is my request")).to eq(%w[this_is_my_request])
    end
    it "has intake of all case character types and will perform the function" do
      expect(PSM._name_normal("THIS simply CANNOT be")).to eq(%w[this_simply_cannot_be])
    end
  end
end

describe PSM, "assess(name, type)" do
  context "<psm>.name should return rank known" do
    it "parses request and determines resopnse" do
      expect(CMan[:vaultkick]).to eq(1)
      expect(Weapon["Twin Hammerfists"]).to eq(1)
      expect(Armor["reinforcement"]).to eq(0)
      expect(Feat[:mystical_tattoo]).to eq(1)
    end
    it "checks if PSM known (rank > 0) and returns true / false" do
      expect(CMan.known?(:bearhug)).to eq(FALSE)
      expect(Weapon.known?(:twin_hammerfists)).to eq(TRUE)
      expect(Armor.known?("blessings")).to eq(FALSE)
      expect(Feat.known?("Martial MASTERY")).to eq(TRUE)
    end
    it "determines if an unknown PSM (error) is requested" do
      expect(CMan["Doug Spell"]).to eq(%[doug_spell is not a defined CMan.  Was it moved to another Ability?])
      expect(Armor.known?(:favorite_dessert)).to eq(%[favorite_dessert is not a defined Armor.  Was it moved to another Ability?])
    end
  end
end

describe PSM, ".affordable?(name)" do
  context "<psm>, name should determine available (cost < stamina)" do
    it "returns erroneous requests as above" do
      expect(Feat.affordable?("Touch this!")).to eq(%[touch_this! is not a defined Feat.  Was it moved to another Ability?])
    end
    it "checks to see if the PSM cost < current stamina" do
      # it does not distinguish at this phase if PSM is known or not known
      expect(Armor.affordable?(:support)).to eq(TRUE)
      expect(CMan.affordable?("rolling_krynch_stance")).to eq(FALSE)
    end
  end
end

# each PSM type still does the .available? check, but the check depends on PSM module assses and affordable, in addition to Effects Debuffs checks.  These two methods are the heart of all PSM queries.
