require 'rspec'

# NilClass monkey-patch (matches lich runtime behavior)
class NilClass
  def method_missing(*)
    nil
  end
end

# Mock DRC (module)
module DRC
  def self.bput(*_args)
    nil
  end

  def self.left_hand
    nil
  end

  def self.right_hand
    nil
  end
end unless defined?(DRC)

# Mock DRCI (module)
module DRCI
  def self.in_hands?(*_args)
    false
  end

  def self.get_item?(*_args)
    true
  end

  def self.put_away_item?(*_args)
    true
  end

  def self.untie_item?(*_args)
    true
  end

  def self.tie_item?(*_args)
    true
  end

  def self.remove_item?(*_args)
    true
  end

  def self.wear_item?(*_args)
    true
  end
end unless defined?(DRCI)

# Mock Lich::Messaging
module Lich
  module Messaging
    def self.msg(_type, _message)
      nil
    end
  end
end unless defined?(Lich::Messaging)

# Mock Script
class Script
  def self.running?(_name)
    true
  end
end unless defined?(Script)

# Mock UserVars
module UserVars
  @data = {}

  class << self
    def method_missing(method_name, *args)
      name = method_name.to_s
      if name.end_with?('=')
        @data[name.chomp('=')] = args.first
      else
        @data[name]
      end
    end

    def respond_to_missing?(*, **)
      true
    end
  end
end unless defined?(UserVars)

require_relative '../../../../lib/dragonrealms/commons/common-moonmage'

DRCMM = Lich::DragonRealms::DRCMM unless defined?(DRCMM)

RSpec.describe DRCMM do
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
    # Positive cases
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

    # Negative cases
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
      it 'attempts to wear both and returns true if either succeeds' do
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
        'visible' => ['katamba', 'xibar', 'yavash']
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
        'visible' => ['katamba', 'xibar']
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
      UserVars.moons = {
        'visible' => []
      }
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
      UserVars.moons = {
        'xibar'   => { 'timer' => 10 },
        'visible' => ['xibar']
      }
      expect(DRCMM.bright_celestial_object?).to be true
    end

    it 'returns true when yavash is visible' do
      UserVars.sun = { 'day' => false, 'timer' => 0 }
      UserVars.moons = {
        'yavash'  => { 'timer' => 10 },
        'visible' => ['yavash']
      }
      expect(DRCMM.bright_celestial_object?).to be true
    end

    it 'returns false when only katamba is visible (not bright)' do
      UserVars.sun = { 'day' => false, 'timer' => 0 }
      UserVars.moons = {
        'katamba' => { 'timer' => 10 },
        'visible' => ['katamba']
      }
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
      UserVars.moons = {
        'katamba' => { 'timer' => 10 },
        'visible' => ['katamba']
      }
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
        UserVars.moons = {
          'katamba' => { 'timer' => 10 },
          'visible' => ['katamba']
        }
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
        expect(Lich::Messaging).to receive(:msg).with('bold', 'No moon available to cast Moongate')
        DRCMM.set_moon_data(data)
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

    it 'predicts weather' do
      expect(DRC).to receive(:bput).with('predict weather', anything, anything, anything, anything, anything)
      DRCMM.predict('weather')
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
  # get_telescope? (new API)
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
      it 'unties from the tied item' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        expect(DRCI).to receive(:untie_item?).with('telescope', 'belt').and_return(true)
        expect(DRCMM.get_telescope?('telescope', storage)).to be true
      end
    end

    context 'with container storage' do
      it 'gets from container' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        expect(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(true)
        expect(DRCMM.get_telescope?('telescope', storage)).to be true
      end

      it 'falls back to get from anywhere when container fails' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(false)
        expect(DRCI).to receive(:get_item?).with('telescope').and_return(true)
        DRCMM.get_telescope?('telescope', storage)
      end

      it 'sends plain message when falling back' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(true)
        expect(Lich::Messaging).to receive(:msg).with('plain', anything)
        DRCMM.get_telescope?('telescope', storage)
      end
    end

    context 'with no storage specified' do
      it 'gets from anywhere' do
        storage = {}
        allow(DRCI).to receive(:in_hands?).and_return(false)
        expect(DRCI).to receive(:get_item?).with('telescope').and_return(true)
        DRCMM.get_telescope?('telescope', storage)
      end
    end

    context 'with custom telescope name' do
      it 'uses the custom name' do
        storage = { 'container' => 'sack' }
        allow(DRCI).to receive(:in_hands?).with('spyglass').and_return(false)
        expect(DRCI).to receive(:get_item?).with('spyglass', 'sack').and_return(true)
        DRCMM.get_telescope?('spyglass', storage)
      end
    end
  end

  # ================================================================
  # store_telescope? (new API)
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
      it 'ties to the tied item' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).and_return(true)
        expect(DRCI).to receive(:tie_item?).with('telescope', 'belt')
        DRCMM.store_telescope?('telescope', storage)
      end
    end

    context 'with container storage' do
      it 'puts in container' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).and_return(true)
        expect(DRCI).to receive(:put_away_item?).with('telescope', 'backpack')
        DRCMM.store_telescope?('telescope', storage)
      end
    end

    context 'with no storage specified' do
      it 'puts away anywhere' do
        storage = {}
        allow(DRCI).to receive(:in_hands?).and_return(true)
        expect(DRCI).to receive(:put_away_item?).with('telescope')
        DRCMM.store_telescope?('telescope', storage)
      end
    end
  end

  # ================================================================
  # get_telescope (old API, deprecated)
  # ================================================================
  describe '.get_telescope' do
    it 'unties when storage has tied key' do
      storage = { 'tied' => 'belt' }
      expect(DRC).to receive(:bput).with("untie telescope from my belt", anything, anything, anything, anything, anything)
      DRCMM.get_telescope(storage)
    end

    it 'gets from container when storage has container key' do
      storage = { 'container' => 'backpack' }
      expect(DRC).to receive(:bput).with("get telescope in my backpack", anything, anything, anything, anything, anything, anything)
      DRCMM.get_telescope(storage)
    end

    it 'gets from anywhere when no storage keys' do
      storage = {}
      expect(DRC).to receive(:bput).with('get my telescope', anything, anything, anything, anything, anything, anything)
      DRCMM.get_telescope(storage)
    end
  end

  # ================================================================
  # store_telescope (old API, deprecated)
  # ================================================================
  describe '.store_telescope' do
    it 'ties when storage has tied key' do
      storage = { 'tied' => 'belt' }
      expect(DRC).to receive(:bput).with("tie telescope to my belt", anything, anything, anything)
      DRCMM.store_telescope(storage)
    end

    it 'puts in container when storage has container key' do
      storage = { 'container' => 'backpack' }
      expect(DRC).to receive(:bput).with("put telescope in my backpack", anything)
      DRCMM.store_telescope(storage)
    end

    it 'stows when no storage keys' do
      storage = {}
      expect(DRC).to receive(:bput).with('stow my telescope', anything, anything)
      DRCMM.store_telescope(storage)
    end
  end

  # ================================================================
  # center_telescope
  # ================================================================
  describe '.center_telescope' do
    it 'sends bold message when target not visible' do
      allow(DRC).to receive(:bput).and_return('The pain is too much')
      expect(Lich::Messaging).to receive(:msg).with('bold', 'Planet katamba not visible. Are you indoors perhaps?')
      DRCMM.center_telescope('katamba')
    end

    it 'sends bold message when sky not visible' do
      allow(DRC).to receive(:bput).and_return("That's a bit tough to do when you can't see the sky")
      expect(Lich::Messaging).to receive(:msg).with('bold', 'Planet katamba not visible. Are you indoors perhaps?')
      DRCMM.center_telescope('katamba')
    end
  end

  # ================================================================
  # get_bones (old API — bug fix regression test)
  # ================================================================
  describe '.get_bones' do
    it 'uses storage["tied"] in the tied branch (bug fix)' do
      storage = { 'tied' => 'belt', 'container' => 'backpack' }
      expect(DRC).to receive(:bput).with("untie bones from my belt", anything, anything)
      DRCMM.get_bones(storage)
    end

    it 'uses storage["container"] in the else branch' do
      storage = { 'container' => 'backpack' }
      expect(DRC).to receive(:bput).with("get bones from my backpack", anything)
      DRCMM.get_bones(storage)
    end
  end

  # ================================================================
  # store_bones (old API — bug fix regression test)
  # ================================================================
  describe '.store_bones' do
    it 'uses storage["tied"] in the tied branch (bug fix)' do
      storage = { 'tied' => 'belt', 'container' => 'backpack' }
      expect(DRC).to receive(:bput).with("tie bones to my belt", anything, anything)
      DRCMM.store_bones(storage)
    end

    it 'uses storage["container"] in the else branch' do
      storage = { 'container' => 'backpack' }
      expect(DRC).to receive(:bput).with("put bones in my backpack", anything)
      DRCMM.store_bones(storage)
    end
  end

  # ================================================================
  # get_bones? (new API)
  # ================================================================
  describe '.get_bones?' do
    it 'unties when storage has tied key' do
      storage = { 'tied' => 'belt' }
      expect(DRCI).to receive(:untie_item?).with('bones', 'belt')
      DRCMM.get_bones?(storage)
    end

    it 'gets from container when storage has container key' do
      storage = { 'container' => 'backpack' }
      expect(DRCI).to receive(:get_item?).with('bones', 'backpack')
      DRCMM.get_bones?(storage)
    end

    it 'gets from anywhere when no storage keys' do
      storage = {}
      expect(DRCI).to receive(:get_item?).with('bones')
      DRCMM.get_bones?(storage)
    end
  end

  # ================================================================
  # store_bones? (new API)
  # ================================================================
  describe '.store_bones?' do
    it 'ties when storage has tied key' do
      storage = { 'tied' => 'belt' }
      expect(DRCI).to receive(:tie_item?).with('bones', 'belt')
      DRCMM.store_bones?(storage)
    end

    it 'puts in container when storage has container key' do
      storage = { 'container' => 'backpack' }
      expect(DRCI).to receive(:put_away_item?).with('bones', 'backpack')
      DRCMM.store_bones?(storage)
    end

    it 'puts away anywhere when no storage keys' do
      storage = {}
      expect(DRCI).to receive(:put_away_item?).with('bones')
      DRCMM.store_bones?(storage)
    end
  end

  # ================================================================
  # get_div_tool? (new API)
  # ================================================================
  describe '.get_div_tool?' do
    it 'unties when tool has tied key' do
      tool = { 'name' => 'charts', 'tied' => true, 'container' => 'belt' }
      expect(DRCI).to receive(:untie_item?).with('charts', 'belt')
      DRCMM.get_div_tool?(tool)
    end

    it 'removes when tool has worn key' do
      tool = { 'name' => 'mirror', 'worn' => true }
      expect(DRCI).to receive(:remove_item?).with('mirror')
      DRCMM.get_div_tool?(tool)
    end

    it 'gets from container otherwise' do
      tool = { 'name' => 'bones', 'container' => 'sack' }
      expect(DRCI).to receive(:get_item?).with('bones', 'sack')
      DRCMM.get_div_tool?(tool)
    end
  end

  # ================================================================
  # store_div_tool? (new API)
  # ================================================================
  describe '.store_div_tool?' do
    it 'ties when tool has tied key' do
      tool = { 'name' => 'charts', 'tied' => true, 'container' => 'belt' }
      expect(DRCI).to receive(:tie_item?).with('charts', 'belt')
      DRCMM.store_div_tool?(tool)
    end

    it 'wears when tool has worn key' do
      tool = { 'name' => 'mirror', 'worn' => true }
      expect(DRCI).to receive(:wear_item?).with('mirror')
      DRCMM.store_div_tool?(tool)
    end

    it 'puts in container otherwise' do
      tool = { 'name' => 'bones', 'container' => 'sack' }
      expect(DRCI).to receive(:put_away_item?).with('bones', 'sack')
      DRCMM.store_div_tool?(tool)
    end
  end

  # ================================================================
  # get_div_tool (old API, deprecated)
  # ================================================================
  describe '.get_div_tool' do
    it 'unties when tool has tied key' do
      tool = { 'name' => 'charts', 'tied' => true, 'container' => 'belt' }
      expect(DRC).to receive(:bput).with("untie charts from my belt", 'charts')
      DRCMM.get_div_tool(tool)
    end

    it 'removes when tool has worn key' do
      tool = { 'name' => 'mirror', 'worn' => true }
      expect(DRC).to receive(:bput).with("remove my mirror", 'mirror')
      DRCMM.get_div_tool(tool)
    end

    it 'gets from container otherwise' do
      tool = { 'name' => 'bones', 'container' => 'sack' }
      expect(DRC).to receive(:bput).with("get my bones from my sack", 'bones', 'you get')
      DRCMM.get_div_tool(tool)
    end
  end

  # ================================================================
  # store_div_tool (old API, deprecated)
  # ================================================================
  describe '.store_div_tool' do
    it 'ties when tool has tied key' do
      tool = { 'name' => 'charts', 'tied' => true, 'container' => 'belt' }
      expect(DRC).to receive(:bput).with("tie charts to my belt", 'charts')
      DRCMM.store_div_tool(tool)
    end

    it 'wears when tool has worn key' do
      tool = { 'name' => 'mirror', 'worn' => true }
      expect(DRC).to receive(:bput).with("wear my mirror", 'mirror')
      DRCMM.store_div_tool(tool)
    end

    it 'puts in container otherwise' do
      tool = { 'name' => 'bones', 'container' => 'sack' }
      expect(DRC).to receive(:bput).with("put bones in my sack", 'bones', 'You put')
      DRCMM.store_div_tool(tool)
    end
  end
end
