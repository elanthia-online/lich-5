# frozen_string_literal: true

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

require 'rexml/document'
require 'rexml/streamlistener'
require 'open-uri'
require "common/spell"
require "attributes/skills"
require 'tmpdir'

module Lich
  module Common
    class Spell
      class Spellsong
        def self.timeleft
          return 0.0
        end
      end
    end
  end
end

Dir.mktmpdir do |dir|
  local_filename = File.join(dir, "effect-list.xml")
  print "Downloading effect-list.xml..."
  download = URI.open('https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts/effect-list.xml').read
  File.write(local_filename, download)
  Lich::Common::Spell.load(local_filename)
  puts " Done!"
end

LIB_DIR = File.join(File.expand_path("..", File.dirname(__FILE__)), 'lib')

module XMLData
  @dialogs = {}
  def self.game
    "rspec"
  end

  def self.name
    "testing"
  end

  def self.indicator
    { 'IconSTUNNED' => 'n',
      'IconDEAD'    => 'n',
      'IconWEBBED'  => false }
  end

  def self.save_dialogs(kind, attributes)
    @dialogs[kind] ||= {}
    return @dialogs[kind] = attributes
  end

  def self.dialogs
    @dialogs ||= {}
  end
end

# stub in Effects module for testing
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

module Lich
  module Gemstone
    class Spellsong
      @@renewed ||= Time.at(Time.now.to_i - 1200)
      def Spellsong.renewed
        @@renewed = Time.now
      end

      def Spellsong.timeleft
        8
      end
    end
  end
end

require "common/sharedbuffer"
require "common/buffer"
require "games"
require "gemstone/overwatch"
require "gemstone/infomon"
require "attributes/stats"
require "attributes/resources"
require "attributes/enhancive"
require "gemstone/currency"
require "gemstone/infomon/status"
require "gemstone/experience"
require "util/util"
require "gemstone/psms"
require "gemstone/psms/ascension"

module Lich
  module Gemstone
    module Infomon
      def self.respond(msg)
        pp msg
      end
    end
  end
end

describe Lich::Gemstone::Enhancive do
  before(:each) do
    Lich::Gemstone::Infomon.reset!
  end

  describe "stat accessors" do
    it "returns OpenStruct with value and cap" do
      Lich::Gemstone::Infomon.set("enhancive.stat.strength", 41)
      result = Lich::Gemstone::Enhancive.strength
      expect(result).to be_a(OpenStruct)
      expect(result.value).to eq(41)
      expect(result.cap).to eq(40)
    end

    it "provides shorthand aliases (str, con, etc.)" do
      Lich::Gemstone::Infomon.set("enhancive.stat.strength", 35)
      Lich::Gemstone::Infomon.set("enhancive.stat.constitution", 20)
      expect(Lich::Gemstone::Enhancive.str).to eq(35)
      expect(Lich::Gemstone::Enhancive.con).to eq(20)
    end

    it "returns 0 for unset stats" do
      expect(Lich::Gemstone::Enhancive.strength.value).to eq(0)
      expect(Lich::Gemstone::Enhancive.str).to eq(0)
    end

    it "detects over-cap stats" do
      Lich::Gemstone::Infomon.set("enhancive.stat.strength", 41)
      Lich::Gemstone::Infomon.set("enhancive.stat.agility", 44)
      Lich::Gemstone::Infomon.set("enhancive.stat.wisdom", 30)
      expect(Lich::Gemstone::Enhancive.stat_over_cap?(:strength)).to be(true)
      expect(Lich::Gemstone::Enhancive.stat_over_cap?(:agility)).to be(true)
      expect(Lich::Gemstone::Enhancive.stat_over_cap?(:wisdom)).to be(false)
    end

    it "returns list of over-cap stats" do
      Lich::Gemstone::Infomon.set("enhancive.stat.strength", 41)
      Lich::Gemstone::Infomon.set("enhancive.stat.agility", 44)
      Lich::Gemstone::Infomon.set("enhancive.stat.wisdom", 30)
      over_cap = Lich::Gemstone::Enhancive.over_cap_stats
      expect(over_cap).to include(:strength, :agility)
      expect(over_cap).not_to include(:wisdom)
    end
  end

  describe "skill accessors" do
    it "returns OpenStruct with ranks, bonus, and cap" do
      Lich::Gemstone::Infomon.set("enhancive.skill.edged_weapons.ranks", 10)
      Lich::Gemstone::Infomon.set("enhancive.skill.edged_weapons.bonus", 50)
      result = Lich::Gemstone::Enhancive.edged_weapons
      expect(result).to be_a(OpenStruct)
      expect(result.ranks).to eq(10)
      expect(result.bonus).to eq(50)
      expect(result.cap).to eq(50)
    end

    it "provides shorthand aliases" do
      Lich::Gemstone::Infomon.set("enhancive.skill.edged_weapons.bonus", 45)
      expect(Lich::Gemstone::Enhancive.edgedweapons.bonus).to eq(45)
    end

    it "detects over-cap skills" do
      Lich::Gemstone::Infomon.set("enhancive.skill.ambush.bonus", 52)
      Lich::Gemstone::Infomon.set("enhancive.skill.dodging.bonus", 48)
      expect(Lich::Gemstone::Enhancive.skill_over_cap?(:ambush)).to be(true)
      expect(Lich::Gemstone::Enhancive.skill_over_cap?(:dodging)).to be(false)
    end
  end

  describe "resource accessors" do
    it "returns value and correct cap per resource" do
      Lich::Gemstone::Infomon.set("enhancive.resource.max_mana", 18)
      Lich::Gemstone::Infomon.set("enhancive.resource.max_health", 14)
      Lich::Gemstone::Infomon.set("enhancive.resource.mana_recovery", 30)

      expect(Lich::Gemstone::Enhancive.max_mana.value).to eq(18)
      expect(Lich::Gemstone::Enhancive.max_mana.cap).to eq(600)
      expect(Lich::Gemstone::Enhancive.max_health.value).to eq(14)
      expect(Lich::Gemstone::Enhancive.max_health.cap).to eq(300)
      expect(Lich::Gemstone::Enhancive.mana_recovery.value).to eq(30)
      expect(Lich::Gemstone::Enhancive.mana_recovery.cap).to eq(50)
    end

    it "provides convenience aliases" do
      Lich::Gemstone::Infomon.set("enhancive.resource.max_mana", 18)
      expect(Lich::Gemstone::Enhancive.mana.value).to eq(18)
    end
  end

  describe "spell accessors" do
    it "returns array of spell numbers" do
      Lich::Gemstone::Infomon.set("enhancive.spells", "215,506,1109")
      expect(Lich::Gemstone::Enhancive.spells).to eq([215, 506, 1109])
    end

    it "returns empty array when no spells" do
      expect(Lich::Gemstone::Enhancive.spells).to eq([])
    end

    it "checks for specific spell knowledge" do
      Lich::Gemstone::Infomon.set("enhancive.spells", "215,506,1109")
      expect(Lich::Gemstone::Enhancive.knows_spell?(215)).to be(true)
      expect(Lich::Gemstone::Enhancive.knows_spell?(101)).to be(false)
    end
  end

  describe "statistics accessors" do
    it "returns item count, property count, total amount" do
      Lich::Gemstone::Infomon.set("enhancive.stats.item_count", 42)
      Lich::Gemstone::Infomon.set("enhancive.stats.property_count", 134)
      Lich::Gemstone::Infomon.set("enhancive.stats.total_amount", 910)

      expect(Lich::Gemstone::Enhancive.item_count).to eq(42)
      expect(Lich::Gemstone::Enhancive.property_count).to eq(134)
      expect(Lich::Gemstone::Enhancive.total_amount).to eq(910)
    end
  end

  describe "active state" do
    it "returns true when enhancives are on" do
      Lich::Gemstone::Infomon.set("enhancive.active", true)
      expect(Lich::Gemstone::Enhancive.active?).to be(true)
    end

    it "returns false when enhancives are off" do
      Lich::Gemstone::Infomon.set("enhancive.active", false)
      expect(Lich::Gemstone::Enhancive.active?).to be(false)
    end

    it "returns false when not set" do
      expect(Lich::Gemstone::Enhancive.active?).to be(false)
    end
  end

  describe "pauses" do
    it "returns the number of pauses available" do
      Lich::Gemstone::Infomon.set("enhancive.pauses", 1233)
      expect(Lich::Gemstone::Enhancive.pauses).to eq(1233)
    end

    it "returns 0 when not set" do
      expect(Lich::Gemstone::Enhancive.pauses).to eq(0)
    end
  end

  describe "reset_all" do
    it "resets all enhancive values to 0" do
      Lich::Gemstone::Infomon.set("enhancive.stat.strength", 41)
      Lich::Gemstone::Infomon.set("enhancive.skill.ambush.bonus", 52)
      Lich::Gemstone::Infomon.set("enhancive.resource.max_mana", 18)
      Lich::Gemstone::Infomon.set("enhancive.spells", "215,506")
      Lich::Gemstone::Infomon.set("enhancive.stats.item_count", 42)

      Lich::Gemstone::Enhancive.reset_all
      sleep 0.1 # Allow async queue to process

      expect(Lich::Gemstone::Enhancive.strength.value).to eq(0)
      expect(Lich::Gemstone::Enhancive.ambush.bonus).to eq(0)
      expect(Lich::Gemstone::Enhancive.max_mana.value).to eq(0)
      expect(Lich::Gemstone::Enhancive.spells).to eq([])
      expect(Lich::Gemstone::Enhancive.item_count).to eq(0)
    end
  end
end

describe Lich::Gemstone::Infomon::Parser, "enhancive patterns" do
  before(:each) do
    Lich::Gemstone::Infomon.reset!
  end

  context "enhancive totals parsing" do
    it "parses complete inventory enhancive totals output" do
      output = <<~EnhanciveTotals
        Stats:
              Strength (STR): 41/40
          Constitution (CON): 37/40
             Dexterity (DEX): 40/40
               Agility (AGI): 44/40
            Discipline (DIS): 40/40
                  Aura (AUR):  6/40
                 Logic (LOG): 20/40
             Intuition (INT): 35/40
                Wisdom (WIS): 41/40
        Skills:
                   Spirit Mana Control Ranks:  5/50
                              Survival Ranks:  9/50
                     Two Weapon Combat Bonus: 19/50
                             Armor Use Bonus:  8/50
                      Combat Maneuvers Bonus: 20/50
                         Edged Weapons Bonus: 50/50
                    Two-Handed Weapons Bonus:  5/50
                        Ranged Weapons Bonus: 50/50
                                Ambush Bonus: 52/50
                               Dodging Bonus: 48/50
                         Harness Power Bonus:  8/50
                   Spirit Mana Control Bonus:  9/50
                  Elemental Lore - Air Bonus:  3/50
                Elemental Lore - Earth Bonus:  3/50
            Spiritual Lore - Blessings Bonus: 50/50
            Spiritual Lore - Summoning Bonus: 47/50
          Mental Lore - Transformation Bonus: 31/50
                              Survival Bonus:  4/50
                       Disarming Traps Bonus:  5/50
                   Stalking and Hiding Bonus: 52/50
                            Perception Bonus:  2/50

        Resources:
                  Max Mana:  18/600
                Max Health:  14/300
               Max Stamina:  21/300
             Mana Recovery:  30/50
          Stamina Recovery:  43/50

        Self Knowledge Spells:
          215, 506, 1109

        Statistics:
          Enhancive Items: 42
          Enhancive Properties: 134
          Total Enhancive Amount: 910

        For more details, see INVENTORY ENHANCIVE TOTALS DETAILS.
      EnhanciveTotals

      output.split("\n").each { |line| Lich::Gemstone::Infomon::Parser.parse(line) }
      sleep 0.1 # Allow async queue to process

      # Check stats
      expect(Lich::Gemstone::Enhancive.strength.value).to eq(41)
      expect(Lich::Gemstone::Enhancive.constitution.value).to eq(37)
      expect(Lich::Gemstone::Enhancive.agility.value).to eq(44)
      expect(Lich::Gemstone::Enhancive.wisdom.value).to eq(41)

      # Check skills
      expect(Lich::Gemstone::Enhancive.spirit_mana_control.ranks).to eq(5)
      expect(Lich::Gemstone::Enhancive.two_weapon_combat.bonus).to eq(19)
      expect(Lich::Gemstone::Enhancive.edged_weapons.bonus).to eq(50)
      expect(Lich::Gemstone::Enhancive.ambush.bonus).to eq(52)
      expect(Lich::Gemstone::Enhancive.stalking_and_hiding.bonus).to eq(52)

      # Check resources
      expect(Lich::Gemstone::Enhancive.max_mana.value).to eq(18)
      expect(Lich::Gemstone::Enhancive.max_health.value).to eq(14)
      expect(Lich::Gemstone::Enhancive.mana_recovery.value).to eq(30)

      # Check spells
      expect(Lich::Gemstone::Enhancive.spells).to eq([215, 506, 1109])
      expect(Lich::Gemstone::Enhancive.knows_spell?(215)).to be(true)
      expect(Lich::Gemstone::Enhancive.knows_spell?(1109)).to be(true)

      # Check statistics
      expect(Lich::Gemstone::Enhancive.item_count).to eq(42)
      expect(Lich::Gemstone::Enhancive.property_count).to eq(134)
      expect(Lich::Gemstone::Enhancive.total_amount).to eq(910)
    end

    it "handles 'No enhancive item bonuses found' by resetting all values" do
      # Set some values first
      Lich::Gemstone::Infomon.set("enhancive.stat.strength", 41)
      Lich::Gemstone::Infomon.set("enhancive.skill.ambush.bonus", 52)

      Lich::Gemstone::Infomon::Parser.parse("No enhancive item bonuses found.")
      sleep 0.1

      expect(Lich::Gemstone::Enhancive.strength.value).to eq(0)
      expect(Lich::Gemstone::Enhancive.ambush.bonus).to eq(0)
    end

    it "resets all values before parsing new data (flush semantics)" do
      # Set an old value that won't be in the new output
      Lich::Gemstone::Infomon.set("enhancive.stat.influence", 30)
      Lich::Gemstone::Infomon.set("enhancive.skill.climbing.bonus", 20)

      # Parse minimal output (only has strength)
      output = <<~MinimalOutput
        Stats:
              Strength (STR): 10/40
        Skills:

        Resources:

        Self Knowledge Spells:

        Statistics:
          Enhancive Items: 1
          Enhancive Properties: 1
          Total Enhancive Amount: 10

        For more details, see INVENTORY ENHANCIVE TOTALS DETAILS.
      MinimalOutput

      output.split("\n").each { |line| Lich::Gemstone::Infomon::Parser.parse(line) }
      sleep 0.1

      # New value should be set
      expect(Lich::Gemstone::Enhancive.strength.value).to eq(10)
      # Old values should be reset to 0
      expect(Lich::Gemstone::Enhancive.climbing.bonus).to eq(0)
    end
  end

  context "enhancive active state" do
    it "sets enhancive.active to true on EnhanciveOn patterns" do
      test_patterns = [
        "You are now accepting the benefits of your enhancive inventory items.",
        "You are already accepting the benefits of any and all enhancive items in your inventory.",
        "You are currently accepting the benefits of any and all enhancive items in your inventory."
      ]

      test_patterns.each do |pattern|
        Lich::Gemstone::Infomon.set("enhancive.active", false)
        Lich::Gemstone::Infomon::Parser.parse(pattern)
        expect(Lich::Gemstone::Enhancive.active?).to be(true), "Failed for pattern: #{pattern}"
      end
    end

    it "sets enhancive.active to false on EnhanciveOff patterns" do
      test_patterns = [
        "You are no longer accepting the benefits of your enhancive inventory items.",
        "You already are not accepting the benefits of any enhancive items in your inventory.",
        "You are not currently accepting the benefit of any enhancive items in your inventory."
      ]

      test_patterns.each do |pattern|
        Lich::Gemstone::Infomon.set("enhancive.active", true)
        Lich::Gemstone::Infomon::Parser.parse(pattern)
        expect(Lich::Gemstone::Enhancive.active?).to be(false), "Failed for pattern: #{pattern}"
      end
    end
  end

  context "enhancive pauses" do
    it "parses enhancive pauses count" do
      Lich::Gemstone::Infomon::Parser.parse("You currently have 1233 enhancive pauses available.")
      expect(Lich::Gemstone::Enhancive.pauses).to eq(1233)
    end

    it "handles singular pause" do
      Lich::Gemstone::Infomon::Parser.parse("You currently have 1 enhancive pause available.")
      expect(Lich::Gemstone::Enhancive.pauses).to eq(1)
    end
  end
end
