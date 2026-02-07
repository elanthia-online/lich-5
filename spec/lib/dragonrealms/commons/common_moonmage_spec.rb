# frozen_string_literal: true

require 'rspec'
require 'ostruct'

# Setup load path (standalone spec, no spec_helper dependency)
LIB_DIR = File.join(File.expand_path('../../../..', __dir__), 'lib') unless defined?(LIB_DIR)

# Ensure Lich::DragonRealms namespace exists
module Lich; module DragonRealms; end; end

# Mock Lich::Messaging — always reopen (no guard) because other specs
# may define Lich::Messaging without msg/messages/clear_messages!.
module Lich
  module Messaging
    @messages = []

    class << self
      def messages
        @messages ||= []
      end

      def clear_messages!
        @messages = []
      end

      def msg(type, message)
        @messages ||= []
        @messages << { type: type, message: message }
      end
    end
  end
end

# Mock Lich::Util for issue_command
module Lich
  module Util
    def self.issue_command(_command, _start, _end_pattern, **_opts)
      []
    end
  end
end unless defined?(Lich::Util)

# ── Mock DRC ──────────────────────────────────────────────────────────
module DRC
  def self.bput(_command, *_patterns)
    nil
  end

  def self.right_hand
    nil
  end

  def self.left_hand
    nil
  end

  def self.message(_msg); end

  def self.fix_standing; end
end unless defined?(DRC)

Lich::DragonRealms::DRC = DRC unless defined?(Lich::DragonRealms::DRC)

# ── Mock DRCI ─────────────────────────────────────────────────────────
module DRCI
  def self.in_hands?(_item)
    false
  end

  def self.get_item?(_item, _container = nil)
    true
  end

  def self.put_away_item?(_item, _container = nil)
    true
  end

  def self.tie_item?(_item, _container = nil)
    true
  end

  def self.untie_item?(_item, _container = nil)
    true
  end

  def self.wear_item?(_item)
    true
  end

  def self.remove_item?(_item)
    true
  end
end unless defined?(DRCI)

Lich::DragonRealms::DRCI = DRCI unless defined?(Lich::DragonRealms::DRCI)

# ── Mock DRStats ──────────────────────────────────────────────────────
module DRStats
  def self.moon_mage?
    false
  end

  def self.trader?
    false
  end
end unless defined?(DRStats)

Lich::DragonRealms::DRStats = DRStats unless defined?(Lich::DragonRealms::DRStats)

# ── Mock UserVars ─────────────────────────────────────────────────────
module UserVars
  @moons = {}
  @sun = {}

  class << self
    attr_accessor :moons, :sun
  end
end unless defined?(UserVars)

# ── Mock Script ───────────────────────────────────────────────────────
class Script
  def self.running?(_name)
    true
  end
end unless defined?(Script)

# ── Mock Flags ────────────────────────────────────────────────────────
module Flags
  @flags = {}

  class << self
    def add(name, *_patterns)
      @flags[name] = nil
    end

    def [](name)
      @flags[name]
    end

    def []=(name, value)
      @flags[name] = value
    end

    def reset(name)
      @flags[name] = nil
    end

    def delete(name)
      @flags.delete(name)
    end
  end
end unless defined?(Flags)

# Stub game helper methods
module Kernel
  def pause(_seconds = nil); end

  def waitrt?; end

  def echo(_msg); end

  def fput(_cmd); end

  def get_data(_key)
    OpenStruct.new(observe_finished_messages: [], constellations: [])
  end

  def custom_require
    proc { |_name| nil }
  end
end

# Load the module under test
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-moonmage.rb')

DRCMM = Lich::DragonRealms::DRCMM unless defined?(DRCMM)

RSpec.describe Lich::DragonRealms::DRCMM do
  before(:each) do
    Lich::Messaging.clear_messages!
  end

  # ================================================================
  # Constants
  # ================================================================
  describe 'constants' do
    it 'MOON_WEAPON_REGEX is frozen' do
      expect(DRCMM::MOON_WEAPON_REGEX).to be_frozen
    end

    it 'MOON_WEAPON_NAMES is frozen' do
      expect(DRCMM::MOON_WEAPON_NAMES).to be_frozen
    end

    it 'MOON_WEAR_MESSAGES is frozen' do
      expect(DRCMM::MOON_WEAR_MESSAGES).to be_frozen
    end

    it 'MOON_DROP_MESSAGES is frozen' do
      expect(DRCMM::MOON_DROP_MESSAGES).to be_frozen
    end

    it 'MOON_COLOR_TO_NAME is frozen' do
      expect(DRCMM::MOON_COLOR_TO_NAME).to be_frozen
    end

    it 'MOON_GLANCE_REGEX is frozen' do
      expect(DRCMM::MOON_GLANCE_REGEX).to be_frozen
    end

    it 'DIV_TOOL_VERBS is frozen' do
      expect(DRCMM::DIV_TOOL_VERBS).to be_frozen
    end

    it 'MOON_VISIBILITY_TIMER_THRESHOLD equals 4' do
      expect(DRCMM::MOON_VISIBILITY_TIMER_THRESHOLD).to eq(4)
    end
  end

  # ================================================================
  # is_moon_weapon?
  # ================================================================
  describe '.is_moon_weapon?' do
    it 'returns true for "black moonblade"' do
      expect(DRCMM.is_moon_weapon?('black moonblade')).to be true
    end

    it 'returns true for "red-hot moonblade"' do
      expect(DRCMM.is_moon_weapon?('red-hot moonblade')).to be true
    end

    it 'returns true for "blue-white moonblade"' do
      expect(DRCMM.is_moon_weapon?('blue-white moonblade')).to be true
    end

    it 'returns true for "black moonstaff"' do
      expect(DRCMM.is_moon_weapon?('black moonstaff')).to be true
    end

    it 'returns true for "red-hot moonstaff"' do
      expect(DRCMM.is_moon_weapon?('red-hot moonstaff')).to be true
    end

    it 'returns true for "blue-white moonstaff"' do
      expect(DRCMM.is_moon_weapon?('blue-white moonstaff')).to be true
    end

    it 'is case-insensitive' do
      expect(DRCMM.is_moon_weapon?('BLACK MOONBLADE')).to be true
      expect(DRCMM.is_moon_weapon?('Blue-White MoonStaff')).to be true
    end

    it 'returns false for nil' do
      expect(DRCMM.is_moon_weapon?(nil)).to be false
    end

    it 'returns false for empty string' do
      expect(DRCMM.is_moon_weapon?('')).to be false
    end

    it 'returns false for regular weapon' do
      expect(DRCMM.is_moon_weapon?('longsword')).to be false
    end

    it 'returns false for moonblade without color prefix' do
      expect(DRCMM.is_moon_weapon?('moonblade')).to be false
    end

    it 'returns false for moonstaff without color prefix' do
      expect(DRCMM.is_moon_weapon?('moonstaff')).to be false
    end

    it 'returns false for partial match with extra text' do
      expect(DRCMM.is_moon_weapon?('black moonblade and shield')).to be false
    end

    it 'returns false for invalid color prefix' do
      expect(DRCMM.is_moon_weapon?('green moonblade')).to be false
    end
  end

  # ================================================================
  # holding_moon_weapon?
  # ================================================================
  describe '.holding_moon_weapon?' do
    it 'returns true when left hand holds moon weapon' do
      allow(DRC).to receive(:left_hand).and_return('black moonblade')
      allow(DRC).to receive(:right_hand).and_return(nil)
      expect(DRCMM.holding_moon_weapon?).to be true
    end

    it 'returns true when right hand holds moon weapon' do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return('red-hot moonstaff')
      expect(DRCMM.holding_moon_weapon?).to be true
    end

    it 'returns true when both hands hold moon weapons' do
      allow(DRC).to receive(:left_hand).and_return('black moonblade')
      allow(DRC).to receive(:right_hand).and_return('blue-white moonstaff')
      expect(DRCMM.holding_moon_weapon?).to be true
    end

    it 'returns false when neither hand holds moon weapon' do
      allow(DRC).to receive(:left_hand).and_return('longsword')
      allow(DRC).to receive(:right_hand).and_return('shield')
      expect(DRCMM.holding_moon_weapon?).to be false
    end

    it 'returns false when both hands are empty' do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      expect(DRCMM.holding_moon_weapon?).to be false
    end
  end

  # ================================================================
  # wear_moon_weapon?
  # ================================================================
  describe '.wear_moon_weapon?' do
    context 'when holding a moon weapon in left hand' do
      before do
        allow(DRC).to receive(:left_hand).and_return('black moonblade')
        allow(DRC).to receive(:right_hand).and_return(nil)
      end

      it 'returns true when wear succeeds' do
        allow(DRC).to receive(:bput).and_return('telekinetic')
        expect(DRCMM.wear_moon_weapon?).to be true
      end

      it 'returns false when wear fails' do
        allow(DRC).to receive(:bput).and_return("You can't wear")
        expect(DRCMM.wear_moon_weapon?).to be false
      end
    end

    context 'when holding moon weapons in both hands' do
      it 'returns true if either wear succeeds' do
        allow(DRC).to receive(:left_hand).and_return('black moonblade')
        allow(DRC).to receive(:right_hand).and_return('red-hot moonstaff')
        allow(DRC).to receive(:bput).with('wear black moonblade', *DRCMM::MOON_WEAR_MESSAGES).and_return("You can't wear")
        allow(DRC).to receive(:bput).with('wear red-hot moonstaff', *DRCMM::MOON_WEAR_MESSAGES).and_return('telekinetic')
        expect(DRCMM.wear_moon_weapon?).to be true
      end
    end

    context 'when not holding any moon weapon' do
      it 'returns false without calling bput' do
        allow(DRC).to receive(:left_hand).and_return('longsword')
        allow(DRC).to receive(:right_hand).and_return(nil)
        expect(DRC).not_to receive(:bput)
        expect(DRCMM.wear_moon_weapon?).to be false
      end
    end
  end

  # ================================================================
  # drop_moon_weapon?
  # ================================================================
  describe '.drop_moon_weapon?' do
    context 'when holding a moon weapon' do
      before do
        allow(DRC).to receive(:left_hand).and_return('black moonblade')
        allow(DRC).to receive(:right_hand).and_return(nil)
      end

      it 'returns true when drop succeeds' do
        allow(DRC).to receive(:bput).and_return('As you open your hand')
        expect(DRCMM.drop_moon_weapon?).to be true
      end

      it 'returns false when drop fails' do
        allow(DRC).to receive(:bput).and_return('What were you referring to')
        expect(DRCMM.drop_moon_weapon?).to be false
      end
    end

    context 'when not holding a moon weapon' do
      it 'returns false without calling bput' do
        allow(DRC).to receive(:left_hand).and_return(nil)
        allow(DRC).to receive(:right_hand).and_return(nil)
        expect(DRC).not_to receive(:bput)
        expect(DRCMM.drop_moon_weapon?).to be false
      end
    end
  end

  # ================================================================
  # hold_moon_weapon?
  # ================================================================
  describe '.hold_moon_weapon?' do
    it 'returns true immediately if already holding one' do
      allow(DRC).to receive(:left_hand).and_return('black moonblade')
      allow(DRC).to receive(:right_hand).and_return(nil)
      expect(DRC).not_to receive(:bput)
      expect(DRCMM.hold_moon_weapon?).to be true
    end

    it 'returns false if both hands are full' do
      allow(DRC).to receive(:left_hand).and_return('longsword')
      allow(DRC).to receive(:right_hand).and_return('shield')
      expect(DRC).not_to receive(:bput)
      expect(DRCMM.hold_moon_weapon?).to be false
    end

    it 'returns true when grab succeeds for moonblade' do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('You glance at a wicked black moonblade')
      allow(DRC).to receive(:bput).with('hold my moonblade', anything, anything, anything, anything).and_return('You grab')
      expect(DRCMM.hold_moon_weapon?).to be true
    end

    it 'tries moonstaff after moonblade fails' do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('I could not find')
      allow(DRC).to receive(:bput).with('glance my moonstaff', anything, anything).and_return('You glance at a wicked blue-white moonstaff')
      allow(DRC).to receive(:bput).with('hold my moonstaff', anything, anything, anything, anything).and_return('You grab')
      expect(DRCMM.hold_moon_weapon?).to be true
    end

    it 'returns false when no moon weapon found' do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('I could not find')
      allow(DRC).to receive(:bput).with('glance my moonstaff', anything, anything).and_return('I could not find')
      expect(DRCMM.hold_moon_weapon?).to be false
    end

    it 'returns false when grab fails' do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('You glance at a wicked black moonblade')
      allow(DRC).to receive(:bput).with('hold my moonblade', anything, anything, anything, anything).and_return("You aren't wearing")
      expect(DRCMM.hold_moon_weapon?).to be false
    end
  end

  # ================================================================
  # moon_used_to_summon_weapon
  # ================================================================
  describe '.moon_used_to_summon_weapon' do
    it 'returns "katamba" for black moon weapon' do
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('You glance at a wicked black moonblade')
      expect(DRCMM.moon_used_to_summon_weapon).to eq('katamba')
    end

    it 'returns "yavash" for red-hot moon weapon' do
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('You glance at a fiery red-hot moonstaff')
      expect(DRCMM.moon_used_to_summon_weapon).to eq('yavash')
    end

    it 'returns "xibar" for blue-white moon weapon' do
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('You glance at a gleaming blue-white moonblade')
      expect(DRCMM.moon_used_to_summon_weapon).to eq('xibar')
    end

    it 'returns nil when no moon weapon found' do
      allow(DRC).to receive(:bput).and_return('I could not find')
      expect(DRCMM.moon_used_to_summon_weapon).to be_nil
    end

    it 'checks moonblade before moonstaff' do
      expect(DRC).to receive(:bput).with('glance my moonblade', anything, anything).ordered.and_return('You glance at a wicked black moonblade')
      expect(DRC).not_to receive(:bput).with('glance my moonstaff', anything, anything)
      DRCMM.moon_used_to_summon_weapon
    end

    it 'falls back to moonstaff when moonblade not found' do
      allow(DRC).to receive(:bput).with('glance my moonblade', anything, anything).and_return('I could not find')
      allow(DRC).to receive(:bput).with('glance my moonstaff', anything, anything).and_return('You glance at a wicked black moonstaff')
      expect(DRCMM.moon_used_to_summon_weapon).to eq('katamba')
    end
  end

  # ================================================================
  # visible_moons
  # ================================================================
  describe '.visible_moons' do
    before do
      allow(Script).to receive(:running?).with('moonwatch').and_return(true)
    end

    it 'returns moons that are visible and have timer >= threshold' do
      UserVars.moons = {
        'katamba' => { 'timer' => 10 },
        'xibar'   => { 'timer' => 5 },
        'yavash'  => { 'timer' => 2 },
        'visible' => %w[katamba xibar yavash]
      }
      expect(DRCMM.visible_moons).to contain_exactly('katamba', 'xibar')
    end

    it 'returns empty array when no moons are visible' do
      UserVars.moons = {
        'katamba' => { 'timer' => 0 },
        'visible' => []
      }
      expect(DRCMM.visible_moons).to be_empty
    end

    it 'excludes moons with timer below threshold' do
      UserVars.moons = {
        'katamba' => { 'timer' => 3 },
        'visible' => ['katamba']
      }
      expect(DRCMM.visible_moons).to be_empty
    end

    it 'includes moons with timer exactly at threshold' do
      UserVars.moons = {
        'katamba' => { 'timer' => 4 },
        'visible' => ['katamba']
      }
      expect(DRCMM.visible_moons).to contain_exactly('katamba')
    end

    it 'excludes moons not in visible list even with high timer' do
      UserVars.moons = {
        'katamba' => { 'timer' => 100 },
        'visible' => []
      }
      expect(DRCMM.visible_moons).to be_empty
    end
  end

  # ================================================================
  # moon_visible?
  # ================================================================
  describe '.moon_visible?' do
    before do
      allow(Script).to receive(:running?).with('moonwatch').and_return(true)
      UserVars.moons = {
        'katamba' => { 'timer' => 10 },
        'xibar'   => { 'timer' => 1 },
        'visible' => %w[katamba xibar]
      }
    end

    it 'returns true for visible moon with sufficient timer' do
      expect(DRCMM.moon_visible?('katamba')).to be true
    end

    it 'returns false for visible moon with low timer' do
      expect(DRCMM.moon_visible?('xibar')).to be false
    end

    it 'returns false for non-visible moon' do
      expect(DRCMM.moon_visible?('yavash')).to be false
    end
  end

  # ================================================================
  # moons_visible?
  # ================================================================
  describe '.moons_visible?' do
    before do
      allow(Script).to receive(:running?).with('moonwatch').and_return(true)
    end

    it 'returns true when at least one moon is visible with sufficient timer' do
      UserVars.moons = {
        'katamba' => { 'timer' => 10 },
        'visible' => ['katamba']
      }
      expect(DRCMM.moons_visible?).to be true
    end

    it 'returns false when no moons are visible' do
      UserVars.moons = { 'visible' => [] }
      expect(DRCMM.moons_visible?).to be false
    end

    it 'returns false when all visible moons have low timers' do
      UserVars.moons = {
        'katamba' => { 'timer' => 2 },
        'visible' => ['katamba']
      }
      expect(DRCMM.moons_visible?).to be false
    end
  end

  # ================================================================
  # bright_celestial_object?
  # ================================================================
  describe '.bright_celestial_object?' do
    before do
      allow(Script).to receive(:running?).with('moonwatch').and_return(true)
    end

    it 'returns true when sun is up with sufficient timer' do
      UserVars.sun = { 'day' => true, 'timer' => 10 }
      UserVars.moons = { 'visible' => [] }
      expect(DRCMM.bright_celestial_object?).to be true
    end

    it 'returns true when xibar is visible' do
      UserVars.sun = { 'day' => false, 'timer' => 0 }
      UserVars.moons = { 'xibar' => { 'timer' => 10 }, 'visible' => ['xibar'] }
      expect(DRCMM.bright_celestial_object?).to be true
    end

    it 'returns true when yavash is visible' do
      UserVars.sun = { 'day' => false, 'timer' => 0 }
      UserVars.moons = { 'yavash' => { 'timer' => 10 }, 'visible' => ['yavash'] }
      expect(DRCMM.bright_celestial_object?).to be true
    end

    it 'returns false when only katamba is visible (not bright)' do
      UserVars.sun = { 'day' => false, 'timer' => 0 }
      UserVars.moons = { 'katamba' => { 'timer' => 10 }, 'visible' => ['katamba'] }
      expect(DRCMM.bright_celestial_object?).to be false
    end

    it 'returns false when sun timer is below threshold' do
      UserVars.sun = { 'day' => true, 'timer' => 3 }
      UserVars.moons = { 'visible' => [] }
      expect(DRCMM.bright_celestial_object?).to be false
    end

    it 'returns false when nothing is visible' do
      UserVars.sun = { 'day' => false, 'timer' => 0 }
      UserVars.moons = { 'visible' => [] }
      expect(DRCMM.bright_celestial_object?).to be false
    end

    it 'returns false when sun is not daytime even with high timer' do
      UserVars.sun = { 'day' => false, 'timer' => 100 }
      UserVars.moons = { 'visible' => [] }
      expect(DRCMM.bright_celestial_object?).to be false
    end
  end

  # ================================================================
  # any_celestial_object?
  # ================================================================
  describe '.any_celestial_object?' do
    before do
      allow(Script).to receive(:running?).with('moonwatch').and_return(true)
    end

    it 'returns true when katamba is visible (unlike bright_celestial_object?)' do
      UserVars.sun = { 'day' => false, 'timer' => 0 }
      UserVars.moons = { 'katamba' => { 'timer' => 10 }, 'visible' => ['katamba'] }
      expect(DRCMM.any_celestial_object?).to be true
    end

    it 'returns true when sun is up' do
      UserVars.sun = { 'day' => true, 'timer' => 10 }
      UserVars.moons = { 'visible' => [] }
      expect(DRCMM.any_celestial_object?).to be true
    end

    it 'returns false when nothing is visible' do
      UserVars.sun = { 'day' => false, 'timer' => 0 }
      UserVars.moons = { 'visible' => [] }
      expect(DRCMM.any_celestial_object?).to be false
    end
  end

  # ================================================================
  # set_moon_data
  # ================================================================
  describe '.set_moon_data' do
    before do
      allow(Script).to receive(:running?).with('moonwatch').and_return(true)
    end

    context 'when data has no moon key' do
      it 'returns data unchanged' do
        data = { 'stats' => ['wisdom'] }
        expect(DRCMM.set_moon_data(data)).to eq(data)
      end
    end

    context 'when a moon is visible' do
      it 'sets cast to the first visible moon' do
        UserVars.moons = { 'katamba' => { 'timer' => 10 }, 'visible' => ['katamba'] }
        data = { 'moon' => true, 'name' => 'Moongate' }
        result = DRCMM.set_moon_data(data)
        expect(result['cast']).to eq('cast katamba')
      end
    end

    context 'when no moon is visible' do
      before do
        UserVars.moons = { 'visible' => [] }
      end

      it 'sets cast to "cast ambient" for Cage of Light' do
        data = { 'moon' => true, 'name' => 'Cage of Light' }
        result = DRCMM.set_moon_data(data)
        expect(result['cast']).to eq('cast ambient')
      end

      it 'sets cast to "cast ambient" for cage of light (case insensitive)' do
        data = { 'moon' => true, 'name' => 'CAGE OF LIGHT' }
        result = DRCMM.set_moon_data(data)
        expect(result['cast']).to eq('cast ambient')
      end

      it 'returns nil for other spells when no moon available' do
        data = { 'moon' => true, 'name' => 'Moongate' }
        result = DRCMM.set_moon_data(data)
        expect(result).to be_nil
      end

      it 'sends a bold message when no moon available for non-CoL spell' do
        data = { 'moon' => true, 'name' => 'Moongate' }
        DRCMM.set_moon_data(data)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('No moon available to cast Moongate')
      end
    end
  end

  # ================================================================
  # update_astral_data
  # ================================================================
  describe '.update_astral_data' do
    it 'delegates to set_moon_data when data has moon key' do
      data = { 'moon' => true, 'name' => 'Moongate' }
      expect(DRCMM).to receive(:set_moon_data).with(data).and_return(data)
      DRCMM.update_astral_data(data)
    end

    it 'delegates to set_planet_data when data has stats key' do
      data = { 'stats' => ['wisdom'] }
      settings = double('settings')
      expect(DRCMM).to receive(:set_planet_data).with(data, settings).and_return(data)
      DRCMM.update_astral_data(data, settings)
    end

    it 'returns data unchanged when neither moon nor stats' do
      data = { 'name' => 'Some Spell' }
      expect(DRCMM.update_astral_data(data)).to eq(data)
    end

    it 'prefers moon over stats when both keys present' do
      data = { 'moon' => true, 'stats' => ['wisdom'], 'name' => 'Moongate' }
      expect(DRCMM).to receive(:set_moon_data).with(data).and_return(data)
      expect(DRCMM).not_to receive(:set_planet_data)
      DRCMM.update_astral_data(data)
    end
  end

  # ================================================================
  # observe
  # ================================================================
  describe '.observe' do
    it 'observes heavens when thing is "heavens"' do
      expect(DRC).to receive(:bput).with('observe heavens', anything, anything, anything, anything, anything, anything)
      DRCMM.observe('heavens')
    end

    it 'observes thing in heavens for other arguments' do
      expect(DRC).to receive(:bput).with('observe katamba in heavens', anything, anything, anything, anything, anything, anything)
      DRCMM.observe('katamba')
    end
  end

  # ================================================================
  # predict
  # ================================================================
  describe '.predict' do
    it 'predicts state all when thing is "all"' do
      expect(DRC).to receive(:bput).with('predict state all', anything, anything, anything, anything, anything)
      DRCMM.predict('all')
    end

    it 'predicts the given thing otherwise' do
      expect(DRC).to receive(:bput).with('predict future', anything, anything, anything, anything, anything)
      DRCMM.predict('future')
    end
  end

  # ================================================================
  # study_sky
  # ================================================================
  describe '.study_sky' do
    it 'sends study sky command' do
      expect(DRC).to receive(:bput).with('study sky', anything, anything, anything, anything, anything)
      DRCMM.study_sky
    end
  end

  # ================================================================
  # align
  # ================================================================
  describe '.align' do
    it 'sends align command with skill' do
      expect(DRC).to receive(:bput).with('align survival', anything)
      DRCMM.align('survival')
    end
  end

  # ================================================================
  # center_telescope
  # ================================================================
  describe '.center_telescope' do
    it 'sends bold message when target not visible' do
      allow(DRC).to receive(:bput).and_return('The pain is too much')
      DRCMM.center_telescope('katamba')
      expect(Lich::Messaging.messages.last[:type]).to eq('bold')
      expect(Lich::Messaging.messages.last[:message]).to include('katamba')
    end

    it 'sends bold message when sky not visible' do
      allow(DRC).to receive(:bput).and_return("That's a bit tough to do when you can't see the sky")
      DRCMM.center_telescope('katamba')
      expect(Lich::Messaging.messages.last[:type]).to eq('bold')
      expect(Lich::Messaging.messages.last[:message]).to include('indoors')
    end
  end

  # ================================================================
  # get_telescope? (DRCI predicate version)
  # ================================================================
  describe '.get_telescope?' do
    context 'when telescope is already in hands' do
      it 'returns true without getting' do
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        expect(DRCI).not_to receive(:get_item?)
        expect(DRCMM.get_telescope?('telescope', {})).to be true
      end
    end

    context 'with tied storage' do
      it 'returns true when untie succeeds' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:untie_item?).with('telescope', 'belt').and_return(true)
        expect(DRCMM.get_telescope?('telescope', storage)).to be true
      end

      it 'returns false when untie fails' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:untie_item?).with('telescope', 'belt').and_return(false)
        expect(DRCMM.get_telescope?('telescope', storage)).to be false
      end
    end

    context 'with container storage' do
      it 'returns true when get from container succeeds' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(true)
        expect(DRCMM.get_telescope?('telescope', storage)).to be true
      end

      it 'falls back to get from anywhere when container fails' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(true)
        expect(DRCMM.get_telescope?('telescope', storage)).to be true
      end

      it 'returns false when both container and fallback fail' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(false)
        expect(DRCMM.get_telescope?('telescope', storage)).to be false
      end

      it 'sends plain message when falling back' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(true)
        DRCMM.get_telescope?('telescope', storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('plain')
      end
    end

    context 'with no storage specified' do
      it 'returns true when get succeeds' do
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(true)
        expect(DRCMM.get_telescope?('telescope', {})).to be true
      end

      it 'returns false when get fails' do
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(false)
        expect(DRCMM.get_telescope?('telescope', {})).to be false
      end
    end

    context 'with custom telescope name' do
      it 'uses the custom name' do
        storage = { 'container' => 'sack' }
        allow(DRCI).to receive(:in_hands?).with('spyglass').and_return(false)
        allow(DRCI).to receive(:get_item?).with('spyglass', 'sack').and_return(true)
        expect(DRCMM.get_telescope?('spyglass', storage)).to be true
      end
    end
  end

  # ================================================================
  # store_telescope? (DRCI predicate version)
  # ================================================================
  describe '.store_telescope?' do
    context 'when telescope is not in hands' do
      it 'returns true without storing' do
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        expect(DRCI).not_to receive(:put_away_item?)
        expect(DRCMM.store_telescope?('telescope', {})).to be true
      end
    end

    context 'with tied storage' do
      it 'returns true when tie succeeds' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).and_return(true)
        allow(DRCI).to receive(:tie_item?).with('telescope', 'belt').and_return(true)
        expect(DRCMM.store_telescope?('telescope', storage)).to be true
      end

      it 'returns false when tie fails' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).and_return(true)
        allow(DRCI).to receive(:tie_item?).with('telescope', 'belt').and_return(false)
        expect(DRCMM.store_telescope?('telescope', storage)).to be false
      end
    end

    context 'with container storage' do
      it 'returns true when put away succeeds' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope', 'backpack').and_return(true)
        expect(DRCMM.store_telescope?('telescope', storage)).to be true
      end

      it 'returns false when put away fails' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope', 'backpack').and_return(false)
        expect(DRCMM.store_telescope?('telescope', storage)).to be false
      end
    end

    context 'with no storage specified' do
      it 'returns true when put away succeeds' do
        allow(DRCI).to receive(:in_hands?).and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope').and_return(true)
        expect(DRCMM.store_telescope?('telescope', {})).to be true
      end

      it 'returns false when put away fails' do
        allow(DRCI).to receive(:in_hands?).and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope').and_return(false)
        expect(DRCMM.store_telescope?('telescope', {})).to be false
      end
    end
  end

  # ================================================================
  # get_telescope (deprecated — delegates to get_telescope?)
  # ================================================================
  describe '.get_telescope' do
    context 'when get_telescope? succeeds' do
      it 'returns without logging an error when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        allow(DRCI).to receive(:untie_item?).with('telescope', 'belt').and_return(true)
        DRCMM.get_telescope(storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging an error when in container' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(true)
        DRCMM.get_telescope(storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when already in hands' do
        storage = {}
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        DRCMM.get_telescope(storage)
        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when get_telescope? fails' do
      it 'logs a bold DRCMM-prefixed error message' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(false)
        DRCMM.get_telescope(storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to get telescope')
      end
    end
  end

  # ================================================================
  # store_telescope (deprecated — delegates to store_telescope?)
  # ================================================================
  describe '.store_telescope' do
    context 'when store_telescope? succeeds' do
      it 'returns without logging an error when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        allow(DRCI).to receive(:tie_item?).with('telescope', 'belt').and_return(true)
        DRCMM.store_telescope(storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging an error when in container' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope', 'backpack').and_return(true)
        DRCMM.store_telescope(storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when not in hands' do
        storage = {}
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        DRCMM.store_telescope(storage)
        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when store_telescope? fails' do
      it 'logs a bold DRCMM-prefixed error message' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope', 'backpack').and_return(false)
        DRCMM.store_telescope(storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to store telescope')
      end
    end
  end

  # ================================================================
  # get_bones? (DRCI predicate version)
  # ================================================================
  describe '.get_bones?' do
    context 'with tied storage' do
      it 'returns true when untie succeeds' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:untie_item?).with('bones', 'belt').and_return(true)
        expect(DRCMM.get_bones?(storage)).to be true
      end

      it 'returns false when untie fails' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:untie_item?).with('bones', 'belt').and_return(false)
        expect(DRCMM.get_bones?(storage)).to be false
      end
    end

    context 'with container storage' do
      it 'returns true when get succeeds' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(true)
        expect(DRCMM.get_bones?(storage)).to be true
      end

      it 'returns false when get fails' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(false)
        expect(DRCMM.get_bones?(storage)).to be false
      end
    end

    context 'with no storage specified' do
      it 'returns true when get succeeds' do
        storage = {}
        allow(DRCI).to receive(:get_item?).with('bones').and_return(true)
        expect(DRCMM.get_bones?(storage)).to be true
      end

      it 'returns false when get fails' do
        storage = {}
        allow(DRCI).to receive(:get_item?).with('bones').and_return(false)
        expect(DRCMM.get_bones?(storage)).to be false
      end
    end
  end

  # ================================================================
  # store_bones? (DRCI predicate version)
  # ================================================================
  describe '.store_bones?' do
    context 'with tied storage' do
      it 'returns true when tie succeeds' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:tie_item?).with('bones', 'belt').and_return(true)
        expect(DRCMM.store_bones?(storage)).to be true
      end

      it 'returns false when tie fails' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:tie_item?).with('bones', 'belt').and_return(false)
        expect(DRCMM.store_bones?(storage)).to be false
      end
    end

    context 'with container storage' do
      it 'returns true when put away succeeds' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(true)
        expect(DRCMM.store_bones?(storage)).to be true
      end

      it 'returns false when put away fails' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(false)
        expect(DRCMM.store_bones?(storage)).to be false
      end
    end

    context 'with no storage specified' do
      it 'returns true when put away succeeds' do
        storage = {}
        allow(DRCI).to receive(:put_away_item?).with('bones').and_return(true)
        expect(DRCMM.store_bones?(storage)).to be true
      end

      it 'returns false when put away fails' do
        storage = {}
        allow(DRCI).to receive(:put_away_item?).with('bones').and_return(false)
        expect(DRCMM.store_bones?(storage)).to be false
      end
    end
  end

  # ================================================================
  # get_bones (deprecated — delegates to get_bones?)
  # ================================================================
  describe '.get_bones' do
    context 'when get_bones? succeeds' do
      it 'returns without logging when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:untie_item?).with('bones', 'belt').and_return(true)
        DRCMM.get_bones(storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(true)
        DRCMM.get_bones(storage)
        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when get_bones? fails' do
      it 'logs a bold DRCMM-prefixed error message' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(false)
        DRCMM.get_bones(storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to get bones')
      end
    end
  end

  # ================================================================
  # store_bones (deprecated — delegates to store_bones?)
  # ================================================================
  describe '.store_bones' do
    context 'when store_bones? succeeds' do
      it 'returns without logging when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:tie_item?).with('bones', 'belt').and_return(true)
        DRCMM.store_bones(storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(true)
        DRCMM.store_bones(storage)
        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when store_bones? fails' do
      it 'logs a bold DRCMM-prefixed error message' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(false)
        DRCMM.store_bones(storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to store bones')
      end
    end
  end

  # ================================================================
  # roll_bones (migrated to use ? methods)
  # ================================================================
  describe '.roll_bones' do
    context 'when get_bones? succeeds' do
      before do
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(true)
        allow(DRC).to receive(:bput).with('roll my bones', 'roundtime').and_return('roundtime')
      end

      it 'rolls and stores bones on success' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(true)
        expect(DRC).to receive(:bput).with('roll my bones', 'roundtime')
        DRCMM.roll_bones(storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'logs error when store_bones? fails after rolling' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(false)
        DRCMM.roll_bones(storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to store bones after rolling')
      end
    end

    context 'when get_bones? fails' do
      it 'aborts without rolling and logs error' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(false)
        expect(DRC).not_to receive(:bput).with('roll my bones', anything)
        DRCMM.roll_bones(storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to get bones')
        expect(Lich::Messaging.messages.last[:message]).to include('aborting')
      end
    end
  end

  # ================================================================
  # get_div_tool? (DRCI predicate version)
  # ================================================================
  describe '.get_div_tool?' do
    context 'with tied tool' do
      it 'returns true when untie succeeds' do
        tool = { 'name' => 'charts', 'tied' => true, 'container' => 'belt' }
        allow(DRCI).to receive(:untie_item?).with('charts', 'belt').and_return(true)
        expect(DRCMM.get_div_tool?(tool)).to be true
      end

      it 'returns false when untie fails' do
        tool = { 'name' => 'charts', 'tied' => true, 'container' => 'belt' }
        allow(DRCI).to receive(:untie_item?).with('charts', 'belt').and_return(false)
        expect(DRCMM.get_div_tool?(tool)).to be false
      end
    end

    context 'with worn tool' do
      it 'returns true when remove succeeds' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:remove_item?).with('mirror').and_return(true)
        expect(DRCMM.get_div_tool?(tool)).to be true
      end

      it 'returns false when remove fails' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:remove_item?).with('mirror').and_return(false)
        expect(DRCMM.get_div_tool?(tool)).to be false
      end
    end

    context 'with container tool' do
      it 'returns true when get succeeds' do
        tool = { 'name' => 'bones', 'container' => 'sack' }
        allow(DRCI).to receive(:get_item?).with('bones', 'sack').and_return(true)
        expect(DRCMM.get_div_tool?(tool)).to be true
      end

      it 'returns false when get fails' do
        tool = { 'name' => 'bones', 'container' => 'sack' }
        allow(DRCI).to receive(:get_item?).with('bones', 'sack').and_return(false)
        expect(DRCMM.get_div_tool?(tool)).to be false
      end
    end
  end

  # ================================================================
  # store_div_tool? (DRCI predicate version)
  # ================================================================
  describe '.store_div_tool?' do
    context 'with tied tool' do
      it 'returns true when tie succeeds' do
        tool = { 'name' => 'charts', 'tied' => true, 'container' => 'belt' }
        allow(DRCI).to receive(:tie_item?).with('charts', 'belt').and_return(true)
        expect(DRCMM.store_div_tool?(tool)).to be true
      end

      it 'returns false when tie fails' do
        tool = { 'name' => 'charts', 'tied' => true, 'container' => 'belt' }
        allow(DRCI).to receive(:tie_item?).with('charts', 'belt').and_return(false)
        expect(DRCMM.store_div_tool?(tool)).to be false
      end
    end

    context 'with worn tool' do
      it 'returns true when wear succeeds' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:wear_item?).with('mirror').and_return(true)
        expect(DRCMM.store_div_tool?(tool)).to be true
      end

      it 'returns false when wear fails' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:wear_item?).with('mirror').and_return(false)
        expect(DRCMM.store_div_tool?(tool)).to be false
      end
    end

    context 'with container tool' do
      it 'returns true when put away succeeds' do
        tool = { 'name' => 'bones', 'container' => 'sack' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'sack').and_return(true)
        expect(DRCMM.store_div_tool?(tool)).to be true
      end

      it 'returns false when put away fails' do
        tool = { 'name' => 'bones', 'container' => 'sack' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'sack').and_return(false)
        expect(DRCMM.store_div_tool?(tool)).to be false
      end
    end
  end

  # ================================================================
  # get_div_tool (deprecated — delegates to get_div_tool?)
  # ================================================================
  describe '.get_div_tool' do
    context 'when get_div_tool? succeeds' do
      it 'returns without logging when tied' do
        tool = { 'name' => 'charts', 'tied' => true, 'container' => 'satchel' }
        allow(DRCI).to receive(:untie_item?).with('charts', 'satchel').and_return(true)
        DRCMM.get_div_tool(tool)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when worn' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:remove_item?).with('mirror').and_return(true)
        DRCMM.get_div_tool(tool)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(true)
        DRCMM.get_div_tool(tool)
        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when get_div_tool? fails' do
      it 'logs a bold DRCMM-prefixed error with tool name' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(false)
        DRCMM.get_div_tool(tool)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include("Failed to get divination tool 'charts'")
      end
    end
  end

  # ================================================================
  # store_div_tool (deprecated — delegates to store_div_tool?)
  # ================================================================
  describe '.store_div_tool' do
    context 'when store_div_tool? succeeds' do
      it 'returns without logging when tied' do
        tool = { 'name' => 'charts', 'tied' => true, 'container' => 'satchel' }
        allow(DRCI).to receive(:tie_item?).with('charts', 'satchel').and_return(true)
        DRCMM.store_div_tool(tool)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when worn' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:wear_item?).with('mirror').and_return(true)
        DRCMM.store_div_tool(tool)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:put_away_item?).with('charts', 'satchel').and_return(true)
        DRCMM.store_div_tool(tool)
        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when store_div_tool? fails' do
      it 'logs a bold DRCMM-prefixed error with tool name' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:put_away_item?).with('charts', 'satchel').and_return(false)
        DRCMM.store_div_tool(tool)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include("Failed to store divination tool 'charts'")
      end
    end
  end

  # ================================================================
  # use_div_tool (migrated to use ? methods)
  # ================================================================
  describe '.use_div_tool' do
    context 'when get_div_tool? succeeds' do
      it 'uses the tool and stores it on success' do
        tool_storage = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(true)
        allow(DRC).to receive(:bput).with('review my charts', 'roundtime').and_return('roundtime')
        allow(DRCI).to receive(:put_away_item?).with('charts', 'satchel').and_return(true)
        DRCMM.use_div_tool(tool_storage)
        expect(Lich::Messaging.messages).to be_empty
      end

      it 'logs error when store_div_tool? fails after using' do
        tool_storage = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(true)
        allow(DRC).to receive(:bput).with('review my charts', 'roundtime').and_return('roundtime')
        allow(DRCI).to receive(:put_away_item?).with('charts', 'satchel').and_return(false)
        DRCMM.use_div_tool(tool_storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include("Failed to store divination tool 'charts'")
      end

      it 'uses correct verb for bones tool' do
        tool_storage = { 'name' => 'bones', 'container' => 'sack' }
        allow(DRCI).to receive(:get_item?).with('bones', 'sack').and_return(true)
        expect(DRC).to receive(:bput).with('roll my bones', 'roundtime').and_return('roundtime')
        allow(DRCI).to receive(:put_away_item?).with('bones', 'sack').and_return(true)
        DRCMM.use_div_tool(tool_storage)
      end

      it 'uses correct verb for mirror tool' do
        tool_storage = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:remove_item?).with('mirror').and_return(true)
        expect(DRC).to receive(:bput).with('gaze my mirror', 'roundtime').and_return('roundtime')
        allow(DRCI).to receive(:wear_item?).with('mirror').and_return(true)
        DRCMM.use_div_tool(tool_storage)
      end

      it 'uses correct verb for bowl tool' do
        tool_storage = { 'name' => 'bowl', 'container' => 'sack' }
        allow(DRCI).to receive(:get_item?).with('bowl', 'sack').and_return(true)
        expect(DRC).to receive(:bput).with('gaze my bowl', 'roundtime').and_return('roundtime')
        allow(DRCI).to receive(:put_away_item?).with('bowl', 'sack').and_return(true)
        DRCMM.use_div_tool(tool_storage)
      end

      it 'uses correct verb for prism tool' do
        tool_storage = { 'name' => 'prism', 'container' => 'sack' }
        allow(DRCI).to receive(:get_item?).with('prism', 'sack').and_return(true)
        expect(DRC).to receive(:bput).with('raise my prism', 'roundtime').and_return('roundtime')
        allow(DRCI).to receive(:put_away_item?).with('prism', 'sack').and_return(true)
        DRCMM.use_div_tool(tool_storage)
      end
    end

    context 'when get_div_tool? fails' do
      it 'aborts without using the tool and logs error' do
        tool_storage = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(false)
        expect(DRC).not_to receive(:bput).with('review my charts', anything)
        DRCMM.use_div_tool(tool_storage)
        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include("Failed to get divination tool 'charts'")
        expect(Lich::Messaging.messages.last[:message]).to include('aborting')
      end
    end
  end
end
