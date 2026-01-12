# frozen_string_literal: true

# Minimal mocks for QStrike testing
# QStrike only needs: Char.stamina, GameObj hands, Armaments::WeaponStats, Effects::Buffs

# Mock Script class
class Script
  def self.current
    nil
  end
end

# Mock Lich module
module Lich
  def self.log(_msg)
    # Suppress logging in tests
  end
end

# Mock NilClass for safe method chaining
class NilClass
  def method_missing(*)
    nil
  end
end

# Mock XMLData
module XMLData
  def self.game
    "GS"
  end

  def self.name
    "testing"
  end
end

# Mock Char module
module Char
  @stamina = 100

  def self.stamina
    @stamina
  end

  def self.set_stamina(value)
    @stamina = value
  end
end

# Mock GameObj hand items
class MockGameObj
  attr_accessor :id, :noun, :name, :type

  def initialize(id: nil, noun: nil, name: nil, type: nil)
    @id = id
    @noun = noun
    @name = name || "Empty"
    @type = type
  end
end

# Mock GameObj class
module GameObj
  @right_hand = MockGameObj.new
  @left_hand = MockGameObj.new

  def self.right_hand
    @right_hand
  end

  def self.left_hand
    @left_hand
  end

  def self.set_right_hand(obj)
    @right_hand = obj
  end

  def self.set_left_hand(obj)
    @left_hand = obj
  end

  def self.clear_hands
    @right_hand = MockGameObj.new
    @left_hand = MockGameObj.new
  end
end

# Mock Effects::Buffs for Striking Asp detection
module Effects
  class MockRegistry
    def initialize
      @effects = {}
    end

    def active?(effect)
      @effects[effect] == true
    end

    def set_active(effect, active)
      @effects[effect] = active
    end

    def clear
      @effects.clear
    end
  end

  Buffs = MockRegistry.new
end

# Mock CMan module for attack cost and rank lookups
module CMan
  @@combat_mans = {
    "tackle" => { short_name: "tackle", cost: { stamina: 7 } },
    "striking_asp" => { short_name: "striking_asp", cost: { stamina: 0 } }
  }.freeze
  @@cman_data = { "striking_asp" => 2 }

  def self.class_variable_get(name)
    case name
    when :@@combat_mans then @@combat_mans
    else {}
    end
  end

  def self.[](name)
    @@cman_data[name.to_s] || 0
  end
end

LIB_DIR = File.join(File.expand_path("..", File.dirname(__FILE__)), 'lib')

# Load util first (required by armaments)
require 'util/util'

# Only load armaments and qstrike - the minimal dependencies
require 'gemstone/armaments'
require 'gemstone/psms/qstrike'

describe Lich::Gemstone::QStrike do
  before(:each) do
    GameObj.clear_hands
    Char.set_stamina(100)
    Effects::Buffs.clear
    Lich::Gemstone::QStrike.clear_cache
  end

  describe ".ranged_weapon?" do
    it "returns false when left hand is empty" do
      expect(Lich::Gemstone::QStrike.ranged_weapon?).to be false
    end

    it "returns true when left hand has bow" do
      bow = MockGameObj.new(id: 1, noun: "longbow", name: "a wooden longbow")
      GameObj.set_left_hand(bow)
      expect(Lich::Gemstone::QStrike.ranged_weapon?).to be true
    end

    it "returns false when left hand has melee weapon" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_left_hand(sword)
      expect(Lich::Gemstone::QStrike.ranged_weapon?).to be false
    end
  end

  describe ".weapon_speed_for" do
    it "returns 0 for empty hand" do
      result = Lich::Gemstone::QStrike.weapon_speed_for(MockGameObj.new)
      expect(result[:equipment_speed]).to eq(0)
      expect(result[:base_rt]).to eq(0)
      expect(result[:category]).to be_nil
    end

    it "returns 0 for non-weapon (shield)" do
      shield = MockGameObj.new(id: 1, noun: "buckler", name: "a small buckler")
      result = Lich::Gemstone::QStrike.weapon_speed_for(shield)
      expect(result[:equipment_speed]).to eq(0)
    end

    it "returns base_rt * 1.0 for edged weapons" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      result = Lich::Gemstone::QStrike.weapon_speed_for(sword)
      expect(result[:base_rt]).to eq(5)
      expect(result[:category]).to eq(:edged)
      expect(result[:equipment_speed]).to eq(5) # 5 * 1.0
    end

    it "returns base_rt * 1.5 for two-handed weapons" do
      axe = MockGameObj.new(id: 1, noun: "battle axe", name: "a massive battle axe")
      result = Lich::Gemstone::QStrike.weapon_speed_for(axe)
      expect(result[:base_rt]).to eq(8)
      expect(result[:category]).to eq(:two_handed)
      expect(result[:equipment_speed]).to eq(12) # 8 * 1.5
    end

    it "returns base_rt * 1.5 for polearms" do
      halberd = MockGameObj.new(id: 1, noun: "halberd", name: "a steel halberd")
      result = Lich::Gemstone::QStrike.weapon_speed_for(halberd)
      expect(result[:base_rt]).to eq(6)
      expect(result[:category]).to eq(:polearm)
      expect(result[:equipment_speed]).to eq(9) # 6 * 1.5
    end

    it "returns base_rt * 2.5 for ranged weapons" do
      bow = MockGameObj.new(id: 1, noun: "longbow", name: "a wooden longbow")
      result = Lich::Gemstone::QStrike.weapon_speed_for(bow)
      expect(result[:base_rt]).to eq(7)
      expect(result[:category]).to eq(:ranged)
      expect(result[:equipment_speed]).to eq(17) # 7 * 2.5 = 17.5, truncated to 17
    end
  end

  describe ".primary_equipment_speed" do
    it "uses RIGHT hand for melee weapons" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_right_hand(sword)
      expect(Lich::Gemstone::QStrike.primary_equipment_speed).to eq(5)
    end

    it "uses LEFT hand for ranged weapons" do
      bow = MockGameObj.new(id: 1, noun: "longbow", name: "a wooden longbow")
      GameObj.set_left_hand(bow)
      expect(Lich::Gemstone::QStrike.primary_equipment_speed).to eq(17)
    end
  end

  describe ".secondary_equipment_speed" do
    it "uses LEFT hand for melee weapons" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      dagger = MockGameObj.new(id: 2, noun: "dagger", name: "a steel dagger")
      GameObj.set_right_hand(sword)
      GameObj.set_left_hand(dagger)
      expect(Lich::Gemstone::QStrike.secondary_equipment_speed).to eq(1) # dagger base_rt=1
    end

    it "returns 0 for shields (not a weapon)" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      shield = MockGameObj.new(id: 2, noun: "buckler", name: "a small buckler")
      GameObj.set_right_hand(sword)
      GameObj.set_left_hand(shield)
      expect(Lich::Gemstone::QStrike.secondary_equipment_speed).to eq(0)
    end

    it "returns 0 for empty left hand" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_right_hand(sword)
      expect(Lich::Gemstone::QStrike.secondary_equipment_speed).to eq(0)
    end
  end

  describe ".cost_per_second_reduction" do
    it "calculates correctly for sword + shield (10 + primary + 0)" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      shield = MockGameObj.new(id: 2, noun: "buckler", name: "a small buckler")
      GameObj.set_right_hand(sword)
      GameObj.set_left_hand(shield)
      # 10 + 5 + 0 = 15
      expect(Lich::Gemstone::QStrike.cost_per_second_reduction).to eq(15)
    end

    it "calculates correctly for dual wield (10 + primary + secondary/2)" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      dagger = MockGameObj.new(id: 2, noun: "dagger", name: "a steel dagger")
      GameObj.set_right_hand(sword)
      GameObj.set_left_hand(dagger)
      # 10 + 5 + (1/2) = 15 (integer division: 1/2 = 0)
      expect(Lich::Gemstone::QStrike.cost_per_second_reduction).to eq(15)
    end

    it "calculates correctly for two-handed weapon" do
      axe = MockGameObj.new(id: 1, noun: "battle axe", name: "a massive battle axe")
      GameObj.set_right_hand(axe)
      # 10 + 12 + 0 = 22
      expect(Lich::Gemstone::QStrike.cost_per_second_reduction).to eq(22)
    end

    it "calculates correctly for ranged weapon" do
      bow = MockGameObj.new(id: 1, noun: "longbow", name: "a wooden longbow")
      GameObj.set_left_hand(bow)
      # 10 + 17 + 0 = 27
      expect(Lich::Gemstone::QStrike.cost_per_second_reduction).to eq(27)
    end

    it "calculates correctly for empty hands (10)" do
      expect(Lich::Gemstone::QStrike.cost_per_second_reduction).to eq(10)
    end

    it "uses cached value when hands unchanged" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_right_hand(sword)

      # First call calculates
      first_result = Lich::Gemstone::QStrike.cost_per_second_reduction

      # Second call should use cache
      second_result = Lich::Gemstone::QStrike.cost_per_second_reduction

      expect(first_result).to eq(second_result)
      expect(first_result).to eq(15)
    end

    it "recalculates when hands change" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_right_hand(sword)

      first_result = Lich::Gemstone::QStrike.cost_per_second_reduction
      expect(first_result).to eq(15)

      # Change weapon
      axe = MockGameObj.new(id: 2, noun: "battle axe", name: "a massive battle axe")
      GameObj.set_right_hand(axe)

      second_result = Lich::Gemstone::QStrike.cost_per_second_reduction
      expect(second_result).to eq(22)
    end
  end

  describe ".striking_asp_active?" do
    it "returns false when stance is not active" do
      expect(Lich::Gemstone::QStrike.striking_asp_active?).to be false
    end

    it "returns true when stance is active" do
      Effects::Buffs.set_active('Striking Asp', true)
      expect(Lich::Gemstone::QStrike.striking_asp_active?).to be true
    end
  end

  describe ".striking_asp_multiplier" do
    it "returns 1.0 when stance not active" do
      expect(Lich::Gemstone::QStrike.striking_asp_multiplier).to eq(1.0)
    end

    it "returns correct multiplier based on rank when active" do
      Effects::Buffs.set_active('Striking Asp', true)
      # CMan mock returns rank 2 for striking_asp
      expect(Lich::Gemstone::QStrike.striking_asp_multiplier).to eq(0.5)
    end
  end

  describe ".lookup_attack_cost" do
    it "finds CMan costs by name" do
      # tackle has stamina cost of 7
      expect(Lich::Gemstone::QStrike.lookup_attack_cost("tackle")).to eq(7)
    end

    it "returns 0 for unknown attacks" do
      expect(Lich::Gemstone::QStrike.lookup_attack_cost("nonexistent_attack")).to eq(0)
    end
  end

  describe ".calculate" do
    before(:each) do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_right_hand(sword)
      Char.set_stamina(100)
    end

    it "returns optimal seconds of reduction" do
      result = Lich::Gemstone::QStrike.calculate(reserve: 1)
      # 100 stamina, reserve 1, cost 15/sec
      # (100 - 1) / 15 = 6.6, so 6 seconds
      expect(result[:seconds]).to eq(6)
      expect(result[:stamina_cost]).to eq(90)
      expect(result[:qstrike_cmd]).to eq("qstrike -6")
    end

    it "accounts for attack cost" do
      result = Lich::Gemstone::QStrike.calculate(reserve: 1, attack_cost: 10)
      # (100 - 1 - 10) / 15 = 5.9, so 5 seconds
      expect(result[:seconds]).to eq(5)
      expect(result[:attack_cost]).to eq(10)
    end

    it "respects reserve stamina" do
      result = Lich::Gemstone::QStrike.calculate(reserve: 50)
      # (100 - 50) / 15 = 3.3, so 3 seconds
      expect(result[:seconds]).to eq(3)
      expect(result[:reserve]).to eq(50)
    end

    it "returns 0 seconds when too expensive per second" do
      Char.set_stamina(5)
      result = Lich::Gemstone::QStrike.calculate(reserve: 1)
      # available = 5 - 1 = 4, cost/sec = 15, 4/15 = 0 -> too_expensive
      expect(result[:seconds]).to eq(0)
      expect(result[:qstrike_cmd]).to be_nil
      expect(result[:reason]).to eq(:too_expensive)
    end

    it "returns insufficient_stamina when available is zero or negative" do
      Char.set_stamina(10)
      result = Lich::Gemstone::QStrike.calculate(reserve: 5, attack_cost: 10)
      # available = 10 - 5 - 10 = -5 -> insufficient_stamina
      expect(result[:seconds]).to eq(0)
      expect(result[:qstrike_cmd]).to be_nil
      expect(result[:reason]).to eq(:insufficient_stamina)
    end

    it "caps at maximum reduction" do
      Char.set_stamina(500)
      result = Lich::Gemstone::QStrike.calculate(reserve: 1)
      expect(result[:seconds]).to eq(8) # MAX_REDUCTION
    end

    it "applies Striking Asp discount when active" do
      Effects::Buffs.set_active('Striking Asp', true)
      Lich::Gemstone::QStrike.clear_cache

      result = Lich::Gemstone::QStrike.calculate(reserve: 1)
      # With rank 2 Striking Asp: cost = 15 * 0.5 = 7 per second
      # (100 - 1) / 7 = 14.14, capped at 8
      expect(result[:seconds]).to eq(8)
      expect(result[:striking_asp_active]).to be true
    end
  end

  describe ".command" do
    it "returns qstrike command string" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_right_hand(sword)
      Char.set_stamina(100)

      expect(Lich::Gemstone::QStrike.command(reserve: 1)).to eq("qstrike -6")
    end

    it "returns nil when unaffordable" do
      Char.set_stamina(5)
      expect(Lich::Gemstone::QStrike.command(reserve: 10)).to be_nil
    end
  end

  describe ".affordable?" do
    it "returns true when reduction is affordable" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_right_hand(sword)
      Char.set_stamina(100)

      expect(Lich::Gemstone::QStrike.affordable?(reserve: 1)).to be true
    end

    it "returns false when reduction is not affordable" do
      Char.set_stamina(5)
      expect(Lich::Gemstone::QStrike.affordable?(reserve: 10)).to be false
    end
  end

  describe ".clear_cache" do
    it "clears the memoization cache" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_right_hand(sword)

      # Populate cache
      Lich::Gemstone::QStrike.cost_per_second_reduction

      # Clear it
      Lich::Gemstone::QStrike.clear_cache

      # Should not raise error and should recalculate
      expect(Lich::Gemstone::QStrike.cost_per_second_reduction).to eq(15)
    end
  end

  describe ".defaults" do
    it "returns default settings" do
      defaults = Lich::Gemstone::QStrike.defaults
      expect(defaults).to be_a(Hash)
      expect(defaults).to have_key(:reserve)
      expect(defaults).to have_key(:force)
    end

    it "allows setting defaults" do
      Lich::Gemstone::QStrike.set_default(:reserve, 10)
      expect(Lich::Gemstone::QStrike.default(:reserve)).to eq(10)
      # Restore
      Lich::Gemstone::QStrike.reset_defaults
    end

    it "returns factory defaults initially" do
      Lich::Gemstone::QStrike.reset_defaults
      expect(Lich::Gemstone::QStrike.default(:reserve)).to eq(1)
      expect(Lich::Gemstone::QStrike.default(:force)).to eq(false)
    end

    it "uses defaults in calculate when reserve not specified" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_right_hand(sword)
      Char.set_stamina(100)

      # Set custom reserve default
      Lich::Gemstone::QStrike.set_default(:reserve, 20)

      # Call without reserve parameter - should use default of 20
      result = Lich::Gemstone::QStrike.calculate
      # available = 100 - 20 = 80, cost = 15/sec, 80/15 = 5
      expect(result[:reserve]).to eq(20)
      expect(result[:seconds]).to eq(5)

      # Restore
      Lich::Gemstone::QStrike.reset_defaults
    end

    it "allows explicit reserve to override default" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_right_hand(sword)
      Char.set_stamina(100)

      Lich::Gemstone::QStrike.set_default(:reserve, 20)

      # Explicit reserve: 1 should override default
      result = Lich::Gemstone::QStrike.calculate(reserve: 1)
      expect(result[:reserve]).to eq(1)
      expect(result[:seconds]).to eq(6) # (100-1)/15 = 6

      Lich::Gemstone::QStrike.reset_defaults
    end
  end

  describe ".base_rt" do
    it "returns base RT for primary weapon" do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_right_hand(sword)
      expect(Lich::Gemstone::QStrike.base_rt).to eq(5)
    end

    it "returns 0 for empty hands" do
      expect(Lich::Gemstone::QStrike.base_rt).to eq(0)
    end
  end

  describe ".reduction_for_target_rt" do
    before(:each) do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_right_hand(sword)
    end

    it "calculates reduction needed for target RT" do
      # Base RT is 5, target RT is 2, so reduction is 3
      expect(Lich::Gemstone::QStrike.reduction_for_target_rt(2)).to eq(3)
    end

    it "returns 0 if target RT >= base RT" do
      expect(Lich::Gemstone::QStrike.reduction_for_target_rt(5)).to eq(0)
      expect(Lich::Gemstone::QStrike.reduction_for_target_rt(10)).to eq(0)
    end

    it "caps at MAX_REDUCTION" do
      # Base RT is 5, target RT is -5 would need 10 seconds, capped at 8
      expect(Lich::Gemstone::QStrike.reduction_for_target_rt(-3)).to eq(8)
    end
  end

  describe ".cost_for_reduction" do
    before(:each) do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_right_hand(sword)
    end

    it "calculates cost for specific reduction" do
      # cost_per_second is 15, so 3 seconds = 45
      expect(Lich::Gemstone::QStrike.cost_for_reduction(3)).to eq(45)
    end

    it "returns 0 for nil or zero reduction" do
      expect(Lich::Gemstone::QStrike.cost_for_reduction(nil)).to eq(0)
      expect(Lich::Gemstone::QStrike.cost_for_reduction(0)).to eq(0)
    end
  end

  describe ".resolve_reduction" do
    before(:each) do
      sword = MockGameObj.new(id: 1, noun: "broadsword", name: "a steel broadsword")
      GameObj.set_right_hand(sword)
      Char.set_stamina(100)
    end

    it "handles :max to return optimal reduction" do
      result = Lich::Gemstone::QStrike.resolve_reduction(:max, 1, 0)
      expect(result).to eq(6) # (100-1)/15 = 6
    end

    it "handles negative integer as reduce-by-N" do
      result = Lich::Gemstone::QStrike.resolve_reduction(-3, 1, 0)
      expect(result).to eq(3)
    end

    it "handles positive integer as target absolute RT" do
      # Base RT is 5, target is 2, so reduction is 3
      result = Lich::Gemstone::QStrike.resolve_reduction(2, 1, 0)
      expect(result).to eq(3)
    end
  end

  describe ".detect_attack_type" do
    it "detects CMan attacks" do
      expect(Lich::Gemstone::QStrike.detect_attack_type("tackle")).to eq(:cman)
    end

    it "returns :basic for unknown attacks" do
      expect(Lich::Gemstone::QStrike.detect_attack_type("attack")).to eq(:basic)
      expect(Lich::Gemstone::QStrike.detect_attack_type("mstrike")).to eq(:basic)
    end
  end

  describe ".normalize_attack_name" do
    it "normalizes attack names" do
      expect(Lich::Gemstone::QStrike.normalize_attack_name("Cripple Strike")).to eq("cripple_strike")
      expect(Lich::Gemstone::QStrike.normalize_attack_name(:tackle)).to eq("tackle")
    end
  end
end

# Top-level alias test
describe "QStrike alias" do
  it "provides top-level QStrike constant" do
    expect(defined?(QStrike)).to be_truthy
    expect(QStrike).to eq(Lich::Gemstone::QStrike)
  end
end
