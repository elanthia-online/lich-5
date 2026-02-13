# frozen_string_literal: true

require_relative '../../../spec_helper'

# ──────────────────────────────────────────────
# Mocks for game-specific dependencies
# ──────────────────────────────────────────────

module DRC
  def self.bput(_command, *_patterns)
    'default'
  end

  def self.retreat(*_args); end
  def self.fix_standing; end
  def self.release_invisibility; end
  def self.set_stance(_stance); end

  def self.get_noun(item)
    item.split.last
  end

  def self.right_hand
    @right_hand
  end

  def self.left_hand
    @left_hand
  end

  def self.right_hand=(val)
    @right_hand = val
  end

  def self.left_hand=(val)
    @left_hand = val
  end
end unless defined?(DRC)

module DRCI
  def self.remove_item?(_item)
    true
  end

  def self.untie_item?(_item, _container = nil)
    true
  end

  def self.get_item?(_item, _container = nil)
    true
  end

  def self.get_item(_item, _container = nil)
    true
  end

  def self.get_item_if_not_held?(_item, _container = nil)
    true
  end

  def self.wear_item?(_item)
    true
  end

  def self.stow_item?(_item)
    true
  end

  def self.tie_item?(_item, _container = nil)
    true
  end

  def self.put_away_item?(_item, _container = nil)
    true
  end

  def self.in_hands?(_item)
    false
  end

  def self.in_left_hand?(_item)
    false
  end

  def self.in_right_hand?(_item)
    false
  end

  def self.inside?(_item, _container)
    true
  end

  def self.dispose_trash(_item); end
end unless defined?(DRCI)

module DRSpells
  @active_spells = {}

  def self.active_spells
    @active_spells
  end

  def self.active_spells=(val)
    @active_spells = val
  end
end unless defined?(DRSpells)

module DRStats
  @mana = 100
  @concentration = 100
  @guild = 'Warrior Mage'
  @encumbrance = 'None'

  class << self
    attr_accessor :mana, :concentration, :guild, :encumbrance

    def barbarian?
      @guild == 'Barbarian'
    end

    def thief?
      @guild == 'Thief'
    end

    def trader?
      @guild == 'Trader'
    end

    def commoner?
      @guild == 'Commoner'
    end

    def moon_mage?
      @guild == 'Moon Mage'
    end

    def warrior_mage?
      @guild == 'Warrior Mage'
    end
  end
end unless defined?(DRStats)

class DRSkill
  def self.getrank(skill = nil, *_rest)
    @ranks ||= {}
    @ranks[skill] || 0
  end

  def self.getxp(skill = nil, *_rest)
    @xps ||= {}
    @xps[skill] || 0
  end

  def self.set_rank(skill, rank)
    @ranks ||= {}
    @ranks[skill] = rank
  end

  def self.set_xp(skill, xp)
    @xps ||= {}
    @xps[skill] = xp
  end
end unless defined?(DRSkill)

# Save mock references at load time — other spec files (e.g., drskill_spec)
# may replace top-level constants with real classes via force-alias patterns.
# These saved references let before(:all) swap the correct mocks into the
# Lich::DragonRealms namespace regardless of file-load order.
ARCANA_MOCK_DRSTATS  = DRStats
ARCANA_MOCK_DRSKILL  = DRSkill
ARCANA_MOCK_DRSPELLS = DRSpells

module DRCMM
  def self.update_astral_data(data, _settings)
    data
  end

  def self.set_moon_data(_data)
    true
  end
end unless defined?(DRCMM)

# Namespace aliases — ensure DRCA code resolves these to the same objects as top-level
module Lich
  module DragonRealms
    DRC = ::DRC unless defined?(Lich::DragonRealms::DRC)
    DRCI = ::DRCI unless defined?(Lich::DragonRealms::DRCI)
    DRCMM = ::DRCMM unless defined?(Lich::DragonRealms::DRCMM)
    DRSpells = ::DRSpells unless defined?(Lich::DragonRealms::DRSpells)
  end
end

module Flags
  @flags = {}
  @pending = {}

  def self.add(name, *_patterns)
    # Don't overwrite pending flags that are queued for the next read
    @flags[name] = nil unless @pending.key?(name)
  end

  def self.delete(name)
    @flags.delete(name)
  end

  def self.[]=(name, val)
    @flags[name] = val
  end

  def self.[](name)
    # Apply pending flag on first read
    if @pending.key?(name)
      @flags[name] = @pending.delete(name)
    end
    @flags[name]
  end

  # Set a flag that survives Flags.add calls (simulates game triggering the flag during bput)
  def self.set_pending(name, val)
    @pending[name] = val
  end

  def self.reset!
    @flags = {}
    @pending = {}
  end

  # common_moonmage_spec needs reset(name) to reset individual flags
  def self.reset(name)
    @flags[name] = nil
  end
end unless defined?(Flags)

module UserVars
  @data = {}
  @moons = {}
  @sun = nil

  class << self
    attr_accessor :discerns, :avtalia, :moons
    # song/climbing_song/instrument for common_spec.rb play_song? tests
    attr_accessor :song, :climbing_song, :instrument

    def sun
      @sun || { 'night' => false, 'day' => true }
    end

    def sun=(val)
      @sun = val
    end
  end
end unless defined?(UserVars)

# Mock Lich::Util for issue_command
module Lich
  module Util
    def self.issue_command(*_args, **_kwargs)
      []
    end
  end unless defined?(Lich::Util)
end

# Helper to extract bold messages from Lich::Messaging captures
def bold_messages
  Lich::Messaging.messages.select { |m| m[:type] == 'bold' }.map { |m| m[:message] }
end

# Mock global game functions
def get_data(_type)
  @mock_data ||= OpenStruct.new(
    prep_messages: ['You begin to', 'But you\'ve already prepared', 'Your desire to prepare this offensive spell suddenly slips away', 'Something in the area interferes with your spell preparations'],
    cast_messages: ['You gesture', 'Your target pattern dissipates'],
    invoke_messages: ['Your cambrinth absorbs', 'you find it too clumsy', 'Invoke what?'],
    charge_messages: ['Your cambrinth absorbs all of the energy', 'You are in no condition to do that', 'You\'ll have to hold it', 'you find it too clumsy'],
    segue_messages: ['You segue', 'You must be performing a cyclic spell to segue from', 'It is too soon to segue'],
    khri_preps: ['You focus your mind', 'Your mind and body are willing', 'Your body is willing'],
    spell_data: {},
    barb_abilities: {
      'Famine' => { 'type' => 'meditation', 'start_command' => 'meditate famine', 'activated_message' => 'You feel hungry' }
    }
  )
end unless defined?(get_data)

def pause(_seconds = 1); end unless defined?(pause)
def waitrt?; end unless defined?(waitrt?)
def waitcastrt?; end unless defined?(waitcastrt?)
def checkprep
  'None'
end unless defined?(checkprep)
def checkcastrt
  0
end unless defined?(checkcastrt)
def reget(_count, _pattern = nil)
  nil
end unless defined?(reget)
def kneeling?
  false
end unless defined?(kneeling?)

# Ensure XMLData has prepared_spell accessor for tests
# In CI, XMLData may be a module (not OpenStruct) so we must define the accessor explicitly
unless XMLData.respond_to?(:prepared_spell=)
  XMLData.singleton_class.attr_accessor(:prepared_spell)
end

# Load the module under test
require_relative '../../../../lib/dragonrealms/commons/common-arcana'

DRCA = Lich::DragonRealms::DRCA unless defined?(DRCA)

RSpec.describe Lich::DragonRealms::DRCA do
  # DRCA resolves DRStats/DRSkill/DRSpells within the Lich::DragonRealms namespace.
  # Other spec files may load real classes or incomplete mocks into that namespace.
  # Swap our full mock modules into both the namespace (for DRCA code) and the
  # top level (for allow/expect stubs in tests). Originals restored in after(:all).
  before(:all) do
    @saved_ns_constants = {}
    @saved_toplevel_constants = {}

    mocks = { DRStats: ARCANA_MOCK_DRSTATS, DRSkill: ARCANA_MOCK_DRSKILL, DRSpells: ARCANA_MOCK_DRSPELLS }

    mocks.each do |name, mock|
      # Save and swap in Lich::DragonRealms namespace
      if Lich::DragonRealms.const_defined?(name, false)
        @saved_ns_constants[name] = Lich::DragonRealms.const_get(name)
        Lich::DragonRealms.send(:remove_const, name)
      end
      Lich::DragonRealms.const_set(name, mock)

      # Save and swap at top level
      if Object.const_defined?(name)
        @saved_toplevel_constants[name] = Object.const_get(name)
        Object.send(:remove_const, name)
      end
      Object.const_set(name, mock)
    end
  end

  after(:all) do
    (@saved_ns_constants || {}).each do |name, original|
      Lich::DragonRealms.send(:remove_const, name) if Lich::DragonRealms.const_defined?(name, false)
      Lich::DragonRealms.const_set(name, original)
    end
    (@saved_toplevel_constants || {}).each do |name, original|
      Object.send(:remove_const, name) if Object.const_defined?(name)
      Object.const_set(name, original)
    end
  end

  before(:each) do
    Lich::Messaging.clear_messages!
    DRSpells.active_spells = {}
    Flags.reset!
  end

  # ──────────────────────────────────────────────
  # Constants
  # ──────────────────────────────────────────────
  describe 'constants' do
    it 'freezes CYCLIC_RELEASE_SUCCESS_PATTERNS' do
      expect(DRCA::CYCLIC_RELEASE_SUCCESS_PATTERNS).to be_frozen
    end

    it 'freezes INFUSE_OM_SUCCESS_PATTERNS' do
      expect(DRCA::INFUSE_OM_SUCCESS_PATTERNS).to be_frozen
    end

    it 'freezes INFUSE_OM_FAILURE_PATTERNS' do
      expect(DRCA::INFUSE_OM_FAILURE_PATTERNS).to be_frozen
    end

    it 'freezes WIELD_FOCUS_SUCCESS_PATTERNS' do
      expect(DRCA::WIELD_FOCUS_SUCCESS_PATTERNS).to be_frozen
    end

    it 'freezes WIELD_FOCUS_FAILURE_PATTERNS' do
      expect(DRCA::WIELD_FOCUS_FAILURE_PATTERNS).to be_frozen
    end

    it 'freezes SHEATHE_FOCUS_SUCCESS_PATTERNS' do
      expect(DRCA::SHEATHE_FOCUS_SUCCESS_PATTERNS).to be_frozen
    end

    it 'freezes SHEATHE_FOCUS_FAILURE_PATTERNS' do
      expect(DRCA::SHEATHE_FOCUS_FAILURE_PATTERNS).to be_frozen
    end

    it 'defines retry limits as positive integers' do
      expect(DRCA::INFUSE_OM_MAX_RETRIES).to be_a(Integer).and be > 0
      expect(DRCA::PREPARE_MAX_RETRIES).to be_a(Integer).and be > 0
      expect(DRCA::CAST_MAX_RETRIES).to be_a(Integer).and be > 0
      expect(DRCA::BARB_BUFF_MAX_RETRIES).to be_a(Integer).and be > 0
      expect(DRCA::STOW_FOCUS_MAX_RETRIES).to be_a(Integer).and be > 0
    end

    it 'contains regex patterns in CYCLIC_RELEASE_SUCCESS_PATTERNS' do
      DRCA::CYCLIC_RELEASE_SUCCESS_PATTERNS.each do |pattern|
        expect(pattern).to be_a(Regexp)
      end
    end

    it 'freezes STARLIGHT_MESSAGES' do
      expect(DRCA::STARLIGHT_MESSAGES).to be_frozen
    end

    it 'freezes CHARGE_LEVELS' do
      expect(DRCA::CHARGE_LEVELS).to be_frozen
    end

    it 'freezes USELESS_RUNESTONE_PATTERNS' do
      expect(DRCA::USELESS_RUNESTONE_PATTERNS).to be_frozen
    end

    it 'freezes GET_RUNESTONE_SUCCESS_PATTERNS' do
      expect(DRCA::GET_RUNESTONE_SUCCESS_PATTERNS).to be_frozen
    end

    it 'freezes GET_RUNESTONE_FAILURE_PATTERNS' do
      expect(DRCA::GET_RUNESTONE_FAILURE_PATTERNS).to be_frozen
    end

    it 'defines named capture patterns' do
      expect(DRCA::SYMBIOSIS_PATTERN).to be_a(Regexp)
      expect(DRCA::DISCERN_SORCERY_PATTERN).to be_a(Regexp)
      expect(DRCA::DISCERN_FULL_PATTERN).to be_a(Regexp)
      expect(DRCA::PERC_MANA_START_PATTERN).to be_a(Regexp)
      expect(DRCA::PERC_MANA_END_PATTERN).to be_a(Regexp)
    end
  end

  # ──────────────────────────────────────────────
  # infuse_om
  # ──────────────────────────────────────────────
  describe '.infuse_om' do
    it 'returns early when Osrel Meraud is not active' do
      DRSpells.active_spells = {}
      expect(DRC).not_to receive(:bput).with(/infuse om/, anything, anything)
      DRCA.infuse_om(true, 10)
    end

    it 'returns early when Osrel Meraud is at or above 90' do
      DRSpells.active_spells = { 'Osrel Meraud' => 91 }
      expect(DRC).not_to receive(:bput).with(/infuse om/, anything, anything)
      DRCA.infuse_om(true, 10)
    end

    it 'returns early when amount is nil' do
      DRSpells.active_spells = { 'Osrel Meraud' => 50 }
      expect(DRC).not_to receive(:bput).with(/infuse om/, anything, anything)
      DRCA.infuse_om(true, nil)
    end

    it 'breaks on success' do
      DRSpells.active_spells = { 'Osrel Meraud' => 50 }
      allow(DRStats).to receive(:mana).and_return(100)
      allow(DRC).to receive(:bput).with(/infuse om/, anything, anything).and_return('having reached its full capacity')
      DRCA.infuse_om(false, 10)
      # No exception means it didn't infinite loop
    end

    it 'gives up after INFUSE_OM_MAX_RETRIES' do
      DRSpells.active_spells = { 'Osrel Meraud' => 50 }
      allow(DRStats).to receive(:mana).and_return(100)
      allow(DRC).to receive(:bput).with(/infuse om/, anything, anything).and_return('as if it hungers for more')
      DRCA.infuse_om(false, 10)
      expect(bold_messages.any? { |m| m.include?('infuse_om exhausted') }).to be true
    end
  end

  # ──────────────────────────────────────────────
  # harness? / harness_mana
  # ──────────────────────────────────────────────
  describe '.harness?' do
    it 'returns truthy on success' do
      allow(DRC).to receive(:bput).with(/harness/, anything, anything).and_return('You tap into')
      expect(DRCA.harness?(10)).to be_truthy
    end

    it 'returns falsy on failure' do
      allow(DRC).to receive(:bput).with(/harness/, anything, anything).and_return('Strain though you may')
      expect(DRCA.harness?(10)).to be_falsy
    end
  end

  describe '.harness_mana' do
    it 'stops on first failure' do
      call_count = 0
      allow(DRC).to receive(:bput).with(/harness/, anything, anything) do
        call_count += 1
        call_count == 1 ? 'You tap into' : 'Strain though you may'
      end
      DRCA.harness_mana([10, 20, 30])
      expect(call_count).to eq(2)
    end
  end

  # ──────────────────────────────────────────────
  # activate_barb_buff?
  # ──────────────────────────────────────────────
  describe '.activate_barb_buff?' do
    it 'returns true when ability is already active' do
      DRSpells.active_spells = { 'Famine' => 300 }
      expect(DRCA.activate_barb_buff?('Famine')).to be true
    end

    it 'returns false when max retries exhausted' do
      DRSpells.active_spells = {}
      allow(DRC).to receive(:bput).with('meditate famine', anything, anything, anything, anything, anything, anything, anything, anything, anything).and_return('You must be unengaged')
      result = DRCA.activate_barb_buff?('Famine', 20, false, retries: 0)
      expect(result).to be false
      expect(bold_messages.any? { |m| m.include?('activate_barb_buff? exhausted') }).to be true
    end

    it 'returns true on successful activation' do
      DRSpells.active_spells = {}
      allow(DRC).to receive(:bput).with('meditate famine', anything, anything, anything, anything, anything, anything, anything, anything, anything).and_return('You feel hungry')
      result = DRCA.activate_barb_buff?('Famine', nil, false)
      expect(result).to be true
    end
  end

  # ──────────────────────────────────────────────
  # prepare?
  # ──────────────────────────────────────────────
  describe '.prepare?' do
    it 'returns false for nil abbrev' do
      expect(DRCA.prepare?(nil, 10)).to be false
    end

    it 'returns match on successful prep' do
      allow(DRC).to receive(:bput).with(/prepare/, anything).and_return('You begin to')
      result = DRCA.prepare?('fireball', 10)
      expect(result).to eq('You begin to')
    end

    it 'retries on offensive spell slip and gives up at 0 retries' do
      allow(DRC).to receive(:bput).with(/prepare/, anything).and_return('Your desire to prepare this offensive spell suddenly slips away')
      result = DRCA.prepare?('fireball', 10, false, 'prepare', false, nil, false, nil, retries: 0)
      expect(result).to be false
      expect(bold_messages.any? { |m| m.include?('prepare? exhausted') }).to be true
    end

    it 'returns false on area interference' do
      allow(DRC).to receive(:bput).with(/prepare/, anything).and_return('Something in the area interferes with your spell preparations')
      expect(DRCA.prepare?('fireball', 10)).to be false
    end
  end

  # ──────────────────────────────────────────────
  # spell_preparing / spell_prepared? / spell_preparing?
  # ──────────────────────────────────────────────
  describe '.spell_preparing' do
    it 'returns nil when no spell prepared' do
      XMLData.prepared_spell = 'None'
      expect(DRCA.spell_preparing).to be_nil
    end

    it 'returns nil for empty string' do
      XMLData.prepared_spell = ''
      expect(DRCA.spell_preparing).to be_nil
    end

    it 'returns the spell name when preparing' do
      XMLData.prepared_spell = 'Fire Ball'
      expect(DRCA.spell_preparing).to eq('Fire Ball')
    end
  end

  describe '.spell_preparing?' do
    it 'returns false when not preparing' do
      XMLData.prepared_spell = 'None'
      expect(DRCA.spell_preparing?).to be false
    end

    it 'returns true when preparing' do
      XMLData.prepared_spell = 'Fire Ball'
      expect(DRCA.spell_preparing?).to be true
    end
  end

  # ──────────────────────────────────────────────
  # cast?
  # ──────────────────────────────────────────────
  describe '.cast?' do
    before(:each) do
      allow(DRC).to receive(:bput).with('cast', anything).and_return('You gesture')
      Flags.reset!
    end

    it 'returns true on successful cast' do
      expect(DRCA.cast?).to be true
    end

    it 'returns false when spell-fail flag set' do
      allow(DRC).to receive(:bput).and_return('default')
      allow(DRC).to receive(:bput).with('cast', anything).and_return('You gesture')
      Flags.set_pending('spell-fail', ['Something is interfering with the spell'])
      expect(DRCA.cast?).to be false
    end

    it 'retries on cyclic-too-recent and gives up at 0 retries' do
      allow(DRC).to receive(:bput).with('cast', anything).and_return('You gesture')
      Flags.set_pending('cyclic-too-recent', ['The mental strain'])
      result = DRCA.cast?('cast', false, [], [], retries: 0)
      expect(result).to be false
      expect(bold_messages.any? { |m| m.include?('cast? exhausted') }).to be true
    end

    it 'falls back from barrage on barrage-fail' do
      allow(DRC).to receive(:bput).with('barrage', anything).and_return('You gesture')
      allow(DRC).to receive(:bput).with('cast', anything).and_return('You gesture')
      Flags.set_pending('barrage-fail', ['That was an invalid attack choice.'])
      result = DRCA.cast?('barrage', false, [], [])
      expect(result).to be_truthy
    end

    it 'gives up on barrage fallback at 0 retries' do
      allow(DRC).to receive(:bput).with('barrage', anything).and_return('You gesture')
      Flags.set_pending('barrage-fail', ['That was an invalid attack choice.'])
      result = DRCA.cast?('barrage', false, [], [], retries: 0)
      expect(result).to be false
      expect(bold_messages.any? { |m| m.include?('barrage fallback exhausted') }).to be true
    end

    it 'releases mana and symbiosis on spell-fail with symbiosis' do
      Flags.set_pending('spell-fail', ['Something is interfering'])
      allow(DRC).to receive(:bput).with('cast', anything).and_return('You gesture')
      allow(DRC).to receive(:bput).with('release mana', anything, anything)
      allow(DRC).to receive(:bput).with('release symbiosis', anything, anything)
      DRCA.cast?('cast', true)
    end
  end

  # ──────────────────────────────────────────────
  # backfired?
  # ──────────────────────────────────────────────
  describe '.backfired?' do
    it 'returns false by default' do
      expect(DRCA.backfired?).to be false
    end
  end

  # ──────────────────────────────────────────────
  # find_focus
  # ──────────────────────────────────────────────
  describe '.find_focus' do
    it 'returns nil when focus is nil' do
      expect(DRCA.find_focus(nil, false, nil, false)).to be_nil
    end

    it 'calls DRCI.remove_item? for worn focus' do
      expect(DRCI).to receive(:remove_item?).with('orb').and_return(true)
      expect(DRCA.find_focus('orb', true, nil, false)).to be true
    end

    it 'calls DRCI.untie_item? for tied focus' do
      expect(DRCI).to receive(:untie_item?).with('orb', 'belt').and_return(true)
      expect(DRCA.find_focus('orb', false, 'belt', false)).to be true
    end

    it 'uses wield bput for sheathed focus' do
      allow(DRC).to receive(:bput).with(/wield my orb/, anything, anything).and_return('You draw out')
      expect(DRCA.find_focus('orb', false, nil, true)).to be true
    end

    it 'returns false on wield failure' do
      allow(DRC).to receive(:bput).with(/wield my orb/, anything, anything).and_return('Wield what')
      expect(DRCA.find_focus('orb', false, nil, true)).to be false
    end

    it 'calls DRCI.get_item? for stowed focus' do
      expect(DRCI).to receive(:get_item?).with('orb').and_return(true)
      expect(DRCA.find_focus('orb', false, nil, false)).to be true
    end
  end

  # ──────────────────────────────────────────────
  # stow_focus
  # ──────────────────────────────────────────────
  describe '.stow_focus' do
    it 'returns nil when focus is nil' do
      expect(DRCA.stow_focus(nil, false, nil, false)).to be_nil
    end

    it 'calls DRCI.wear_item? for worn focus' do
      expect(DRCI).to receive(:wear_item?).with('orb').and_return(true)
      expect(DRCA.stow_focus('orb', true, nil, false)).to be true
    end

    it 'calls DRCI.tie_item? for tied focus' do
      expect(DRCI).to receive(:tie_item?).with('orb', 'belt').and_return(true)
      expect(DRCA.stow_focus('orb', false, 'belt', false)).to be true
    end

    it 'retries tie on failure and gives up at 0 retries' do
      expect(DRCI).to receive(:tie_item?).with('orb', 'belt').and_return(false)
      result = DRCA.stow_focus('orb', false, 'belt', false, retries: 0)
      expect(result).to be false
      expect(bold_messages.any? { |m| m.include?('stow_focus exhausted') }).to be true
    end

    it 'uses sheathe bput for sheathed focus' do
      allow(DRC).to receive(:bput).with(/sheathe my orb/, anything, anything).and_return('You sheathe')
      expect(DRCA.stow_focus('orb', false, nil, true)).to be true
    end

    it 'returns false on sheathe failure' do
      allow(DRC).to receive(:bput).with(/sheathe my orb/, anything, anything).and_return("Sheathe your sword where")
      expect(DRCA.stow_focus('orb', false, nil, true)).to be false
    end

    it 'calls DRCI.stow_item? for stowed focus' do
      expect(DRCI).to receive(:stow_item?).with('orb').and_return(true)
      expect(DRCA.stow_focus('orb', false, nil, false)).to be true
    end
  end

  # ──────────────────────────────────────────────
  # find_cambrinth / stow_cambrinth / skilled_to_charge_while_worn?
  # ──────────────────────────────────────────────
  describe '.find_cambrinth' do
    it 'gets stored cambrinth from stow or tries remove' do
      expect(DRCI).to receive(:get_item_if_not_held?).with('armband').and_return(true)
      DRCA.find_cambrinth('armband', true, 50)
    end

    it 'checks hands then removes then gets for non-skilled worn' do
      allow(DRSkill).to receive(:getrank).with('Arcana').and_return(0)
      expect(DRCI).to receive(:in_hands?).with('armband').and_return(true)
      DRCA.find_cambrinth('armband', false, 50)
    end

    it 'returns true when skilled to charge while worn' do
      allow(DRSkill).to receive(:getrank).with('Arcana').and_return(999)
      expect(DRCA.find_cambrinth('armband', false, 50)).to be true
    end
  end

  describe '.stow_cambrinth' do
    it 'stows stored cambrinth' do
      allow(DRCI).to receive(:get_item_if_not_held?).and_return(true)
      expect(DRCI).to receive(:stow_item?).with('armband').and_return(true)
      DRCA.stow_cambrinth('armband', true, 50)
    end

    it 'wears cambrinth if in hands' do
      allow(DRCI).to receive(:in_hands?).with('armband').and_return(true)
      expect(DRCI).to receive(:wear_item?).with('armband').and_return(true)
      DRCA.stow_cambrinth('armband', false, 50)
    end

    it 'returns true if not in hands and not stored' do
      allow(DRCI).to receive(:in_hands?).with('armband').and_return(false)
      expect(DRCA.stow_cambrinth('armband', false, 50)).to be true
    end
  end

  describe '.skilled_to_charge_while_worn?' do
    it 'returns true when arcana rank is sufficient' do
      allow(DRSkill).to receive(:getrank).with('Arcana').and_return(300)
      expect(DRCA.skilled_to_charge_while_worn?(50)).to be true
    end

    it 'returns false when arcana rank is insufficient' do
      allow(DRSkill).to receive(:getrank).with('Arcana').and_return(100)
      expect(DRCA.skilled_to_charge_while_worn?(50)).to be false
    end
  end

  # ──────────────────────────────────────────────
  # charge_and_invoke
  # ──────────────────────────────────────────────
  describe '.charge_and_invoke' do
    it 'returns early for nil charges' do
      expect(DRCA).not_to receive(:charge?)
      DRCA.charge_and_invoke('armband', nil, nil)
    end

    it 'returns early for empty charges' do
      expect(DRCA).not_to receive(:charge?)
      DRCA.charge_and_invoke('armband', nil, [])
    end

    it 'charges and invokes with exact amount' do
      allow(DRCA).to receive(:charge?).and_return(true)
      expect(DRCA).to receive(:invoke).with('armband', nil, 30)
      DRCA.charge_and_invoke('armband', nil, [10, 20], true)
    end

    it 'invokes without amount when invoke_exact_amount is nil' do
      allow(DRCA).to receive(:charge?).and_return(true)
      expect(DRCA).to receive(:invoke).with('armband', nil, nil)
      DRCA.charge_and_invoke('armband', nil, [10, 20], nil)
    end

    it 'stops charging on first charge failure' do
      charge_count = 0
      allow(DRCA).to receive(:charge?) do
        charge_count += 1
        charge_count == 1
      end
      allow(DRCA).to receive(:invoke)
      DRCA.charge_and_invoke('armband', nil, [10, 20, 30], nil)
      expect(charge_count).to eq(2)
    end
  end

  # ──────────────────────────────────────────────
  # invoke
  # ──────────────────────────────────────────────
  describe '.invoke' do
    it 'returns early for nil cambrinth' do
      expect(DRC).not_to receive(:bput)
      DRCA.invoke(nil, nil, nil)
    end

    it 'invokes successfully' do
      allow(DRC).to receive(:bput).and_return('Your cambrinth absorbs')
      DRCA.invoke('armband', nil, 10)
    end

    it 'warns and retries on clumsy error when not in hands' do
      allow(DRC).to receive(:bput).and_return('you find it too clumsy', 'Your cambrinth absorbs')
      allow(DRCI).to receive(:in_hands?).with('armband').and_return(false, true)
      allow(DRCA).to receive(:find_cambrinth)
      allow(DRCA).to receive(:stow_cambrinth)
      DRCA.invoke('armband', nil, 10)
      expect(bold_messages.any? { |m| m.include?('arcana skill is too low to invoke') }).to be true
    end
  end

  # ──────────────────────────────────────────────
  # charge?
  # ──────────────────────────────────────────────
  describe '.charge?' do
    it 'returns truthy on success' do
      allow(DRC).to receive(:bput).and_return('Your cambrinth absorbs all of the energy')
      expect(DRCA.charge?('armband', 10)).to be_truthy
    end

    it 'tries harness on no condition' do
      allow(DRC).to receive(:bput).with(/charge my armband/, anything, anything).and_return('You are in no condition to do that')
      expect(DRCA).to receive(:harness?).with(10).and_return(true)
      expect(DRCA.charge?('armband', 10)).to be true
    end

    it 'warns on missing cambrinth' do
      allow(DRC).to receive(:bput).with(/charge my armband/, anything, anything).and_return("You'll have to hold it")
      allow(DRCI).to receive(:in_hands?).and_return(true)
      DRCA.charge?('armband', 10)
      expect(bold_messages.any? { |m| m.include?('where did your cambrinth go') }).to be true
    end
  end

  # ──────────────────────────────────────────────
  # release_cyclics
  # ──────────────────────────────────────────────
  describe '.release_cyclics' do
    it 'releases active cyclics' do
      spell_data = {
        'Fire Rain' => { 'cyclic' => true, 'abbrev' => 'fr' },
        'Fire Ball' => { 'cyclic' => false, 'abbrev' => 'fb' }
      }
      DRSpells.active_spells = { 'Fire Rain' => 300 }
      mock_data = double('data', spell_data: spell_data)
      allow(DRCA).to receive(:get_data).with('spells').and_return(mock_data)
      expect(DRC).to receive(:bput).with('release fr', DRCA::CYCLIC_RELEASE_SUCCESS_PATTERNS, 'Release what?')
      DRCA.release_cyclics
    end

    it 'skips spells in no-release list' do
      spell_data = { 'Fire Rain' => { 'cyclic' => true, 'abbrev' => 'fr' } }
      DRSpells.active_spells = { 'Fire Rain' => 300 }
      mock_data = double('data', spell_data: spell_data)
      allow(DRCA).to receive(:get_data).with('spells').and_return(mock_data)
      expect(DRC).not_to receive(:bput).with('release fr', anything, anything)
      DRCA.release_cyclics(['Fire Rain'])
    end
  end

  # ──────────────────────────────────────────────
  # prepare_to_cast_runestone? / get_runestone?
  # ──────────────────────────────────────────────
  describe '.prepare_to_cast_runestone?' do
    let(:settings) { OpenStruct.new(runestone_storage: 'pouch') }
    let(:spell) { { 'runestone_name' => 'moonstone' } }

    it 'returns true when runestone is available' do
      allow(DRCI).to receive(:inside?).and_return(true)
      allow(DRCI).to receive(:in_hands?).and_return(true)
      expect(DRCA.prepare_to_cast_runestone?(spell, settings)).to be true
    end

    it 'returns false with message when out of runestones' do
      allow(DRCI).to receive(:inside?).and_return(false)
      expect(DRCA.prepare_to_cast_runestone?(spell, settings)).to be false
      expect(bold_messages.any? { |m| m.include?('out of moonstone') }).to be true
    end
  end

  describe '.get_runestone?' do
    let(:settings) { OpenStruct.new(runestone_storage: 'pouch') }

    it 'returns true if already in hands' do
      allow(DRCI).to receive(:in_hands?).with('moonstone').and_return(true)
      expect(DRCA.get_runestone?('moonstone', settings)).to be true
    end

    it 'returns true on successful get' do
      allow(DRCI).to receive(:in_hands?).with('moonstone').and_return(false)
      allow(DRC).to receive(:bput).and_return('You get a moonstone')
      expect(DRCA.get_runestone?('moonstone', settings)).to be true
    end

    it 'returns false and disposes useless runestone' do
      allow(DRCI).to receive(:in_hands?).with('moonstone').and_return(false)
      allow(DRC).to receive(:bput).and_return('You get a useless moonstone')
      expect(DRCI).to receive(:dispose_trash).with('moonstone')
      expect(DRCA.get_runestone?('moonstone', settings)).to be false
      expect(bold_messages.any? { |m| m.include?('useless moonstone') }).to be true
    end

    it 'returns false when runestone not found' do
      allow(DRCI).to receive(:in_hands?).with('moonstone').and_return(false)
      allow(DRC).to receive(:bput).and_return('What were you referring to')
      expect(DRCA.get_runestone?('moonstone', settings)).to be false
      expect(bold_messages.any? { |m| m.include?('could not find moonstone') }).to be true
    end
  end

  # ──────────────────────────────────────────────
  # cast_spell? / cast_spell
  # ──────────────────────────────────────────────
  describe '.cast_spell?' do
    it 'returns true when cast_spell returns truthy' do
      allow(DRCA).to receive(:cast_spell).and_return('You gesture')
      expect(DRCA.cast_spell?({}, {})).to be true
    end

    it 'returns false when cast_spell returns nil' do
      allow(DRCA).to receive(:cast_spell).and_return(nil)
      expect(DRCA.cast_spell?(nil, {})).to be false
    end
  end

  describe '.cast_spell' do
    it 'returns nil for nil data' do
      expect(DRCA.cast_spell(nil, {})).to be_nil
    end

    it 'returns nil for nil settings' do
      expect(DRCA.cast_spell({}, nil)).to be_nil
    end
  end

  # ──────────────────────────────────────────────
  # segue?
  # ──────────────────────────────────────────────
  describe '.segue?' do
    it 'returns true on successful segue' do
      allow(DRC).to receive(:bput).and_return('You segue')
      expect(DRCA.segue?('ae', 10)).to be true
    end

    it 'returns false when not performing cyclic' do
      allow(DRC).to receive(:bput).and_return('You must be performing a cyclic spell to segue from')
      expect(DRCA.segue?('ae', 10)).to be false
    end
  end

  # ──────────────────────────────────────────────
  # check_to_harness
  # ──────────────────────────────────────────────
  describe '.check_to_harness' do
    it 'returns false when should_harness is false' do
      expect(DRCA.check_to_harness(false)).to be false
    end

    it 'returns false when Attunement xp exceeds Arcana xp' do
      DRSkill.set_xp('Attunement', 30)
      DRSkill.set_xp('Arcana', 10)
      expect(DRCA.check_to_harness(true)).to be false
    end

    it 'returns true when Arcana xp >= Attunement xp' do
      DRSkill.set_xp('Attunement', 10)
      DRSkill.set_xp('Arcana', 30)
      expect(DRCA.check_to_harness(true)).to be true
    end
  end

  # ──────────────────────────────────────────────
  # normalize_cambrinth_items (private, tested via cast_spell)
  # ──────────────────────────────────────────────
  describe 'normalize_cambrinth_items (via cast_spell)' do
    it 'normalizes settings when cambrinth_items name is nil' do
      settings = OpenStruct.new(
        cambrinth_items: [{ 'name' => nil }],
        cambrinth: 'armband',
        cambrinth_cap: 50,
        stored_cambrinth: false,
        use_harness_when_arcana_locked: false,
        dedicated_camb_use: nil,
        cambrinth_invoke_exact_amount: nil,
        osrel_no_harness: true,
        osrel_amount: 0,
        waggle_spells_mana_threshold: 10,
        waggle_spells_concentration_threshold: 10
      )
      data = { 'abbrev' => 'fb', 'mana' => 10, 'cambrinth' => [5] }
      allow(DRCA).to receive(:prepare?).and_return('You begin to')
      allow(DRCA).to receive(:cast?).and_return(true)
      allow(DRCA).to receive(:find_charge_invoke_stow)
      DRCA.cast_spell(data, settings)
      expect(settings.cambrinth_items[0]['name']).to eq('armband')
    end
  end

  # ──────────────────────────────────────────────
  # choose_avtalia
  # ──────────────────────────────────────────────
  describe '.choose_avtalia' do
    it 'returns nil when no cambrinth matches' do
      allow(UserVars).to receive(:avtalia).and_return({})
      expect(DRCA.choose_avtalia(10, 50)).to be_nil
    end
  end

  # ──────────────────────────────────────────────
  # check_elemental_charge
  # ──────────────────────────────────────────────
  describe '.check_elemental_charge' do
    it 'returns 0 for non-warrior-mages' do
      DRStats.guild = 'Bard'
      expect(DRCA.check_elemental_charge).to eq(0)
    end

    it 'returns correct charge level for warrior mage' do
      DRStats.guild = 'Warrior Mage'
      allow(DRC).to receive(:bput).and_return('A charge dances through your body.')
      expect(DRCA.check_elemental_charge).to eq(3)
    end
  end

  # ──────────────────────────────────────────────
  # perc_symbiotic_research / release_magical_research
  # ──────────────────────────────────────────────
  describe '.perc_symbiotic_research' do
    it 'returns symbiosis type when active' do
      allow(DRC).to receive(:bput).and_return('combine the weaves of the lunar symbiosis')
      expect(DRCA.perc_symbiotic_research).to eq('lunar')
    end

    it 'returns nil when no symbiosis active' do
      allow(DRC).to receive(:bput).and_return('Roundtime')
      expect(DRCA.perc_symbiotic_research).to be_nil
    end
  end

  describe '.release_magical_research' do
    it 'sends release symbiosis twice' do
      expect(DRC).to receive(:bput).with('release symbiosis', anything, anything, anything).twice
      DRCA.release_magical_research
    end
  end

  # ──────────────────────────────────────────────
  # perc_mana
  # ──────────────────────────────────────────────
  describe '.perc_mana' do
    it 'returns nil for barbarians' do
      DRStats.guild = 'Barbarian'
      expect(DRCA.perc_mana).to be_nil
    end

    it 'returns nil for thieves' do
      DRStats.guild = 'Thief'
      expect(DRCA.perc_mana).to be_nil
    end

    it 'returns mana levels for moon mages via issue_command' do
      DRStats.guild = 'Moon Mage'
      mock_lines = [
        'The developing streams of Enlightened Geometry mana flowing through',
        'The developing streams of Moonlight Manipulation mana flowing through',
        'The developing streams of Perception mana flowing through',
        'The developing streams of Psychic Projection mana flowing through'
      ]
      allow(Lich::Util).to receive(:issue_command).and_return(mock_lines)
      allow(DRCA).to receive(:parse_mana_message).and_return(3)
      result = DRCA.perc_mana
      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly('enlightened_geometry', 'moonlight_manipulation', 'perception', 'psychic_projection')
    end

    it 'returns nil when issue_command times out for moon mage' do
      DRStats.guild = 'Moon Mage'
      allow(Lich::Util).to receive(:issue_command).and_return(nil)
      expect(DRCA.perc_mana).to be_nil
    end

    it 'returns parsed mana for non-moon-mage casters' do
      DRStats.guild = 'Warrior Mage'
      allow(DRC).to receive(:bput).and_return('You reach out with your senses and see developing')
      allow(DRCA).to receive(:parse_mana_message).and_return(5)
      expect(DRCA.perc_mana).to eq(5)
    end
  end

  # ──────────────────────────────────────────────
  # shatter_regalia?
  # ──────────────────────────────────────────────
  describe '.shatter_regalia?' do
    it 'returns false for non-traders' do
      DRStats.guild = 'Warrior Mage'
      expect(DRCA.shatter_regalia?).to be false
    end

    it 'returns false for empty regalia' do
      DRStats.guild = 'Trader'
      expect(DRCA.shatter_regalia?([])).to be false
    end

    it 'removes each regalia item' do
      DRStats.guild = 'Trader'
      expect(DRC).to receive(:bput).with(/remove my gauntlet/, anything, anything, anything)
      expect(DRCA.shatter_regalia?(['gauntlet'])).to be true
    end
  end

  # ──────────────────────────────────────────────
  # find_charge_invoke_stow
  # ──────────────────────────────────────────────
  describe '.find_charge_invoke_stow' do
    it 'returns early for nil charges' do
      expect(DRCA).not_to receive(:find_cambrinth)
      DRCA.find_charge_invoke_stow('armband', false, 50, nil, nil)
    end

    it 'calls find, charge_and_invoke, and stow in sequence' do
      expect(DRCA).to receive(:find_cambrinth).with('armband', false, 50).ordered
      expect(DRCA).to receive(:charge_and_invoke).with('armband', nil, [10], nil).ordered
      expect(DRCA).to receive(:stow_cambrinth).with('armband', false, 50).ordered
      DRCA.find_charge_invoke_stow('armband', false, 50, nil, [10])
    end
  end
end
