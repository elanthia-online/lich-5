require 'rspec'

# Setup load path (standalone spec, no spec_helper dependency)
LIB_DIR = File.join(File.expand_path('../../../..', __dir__), 'lib') unless defined?(LIB_DIR)

# Mock Lich::Messaging before loading the module under test
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
end unless defined?(Lich::Messaging)

# Mock DRC — define at top level for compatibility with other spec files.
# Use *_args for flexible argument counts since different callers pass
# different numbers of arguments.
module DRC
  def self.bput(*_args); nil; end

  def self.right_hand; nil; end

  def self.left_hand; nil; end

  def self.right_hand_noun; nil; end

  def self.fix_standing; end

  def self.retreat; end
end unless defined?(DRC)

# Add methods that other spec files' DRC mock may be missing
DRC.define_singleton_method(:right_hand) { nil } unless DRC.respond_to?(:right_hand)
DRC.define_singleton_method(:left_hand) { nil } unless DRC.respond_to?(:left_hand)
DRC.define_singleton_method(:right_hand_noun) { nil } unless DRC.respond_to?(:right_hand_noun)
DRC.define_singleton_method(:fix_standing) {} unless DRC.respond_to?(:fix_standing)
DRC.define_singleton_method(:retreat) {} unless DRC.respond_to?(:retreat)

# Mock DRStats
module DRStats
  def self.moon_mage?; false; end

  def self.warrior_mage?; false; end

  def self.guild; 'Unknown'; end
end unless defined?(DRStats)

# Mock DRCMM
module DRCMM
  def self.hold_moon_weapon?; false; end

  def self.is_moon_weapon?(*_args); false; end
end unless defined?(DRCMM)

# Mock DRCI — use *_args for all methods since other code (e.g. common-crafting)
# may call put_away_item? and get_item? with 1 or 2 arguments.
module DRCI
  def self.tap(*_args); nil; end

  def self.get_item?(*_args); true; end

  def self.put_away_item?(*_args); true; end
end unless defined?(DRCI)

# Add methods that other spec files' DRCI mock may be missing
DRCI.define_singleton_method(:tap) { |*_args| nil } unless DRCI.respond_to?(:tap)

# Stub game helper methods that DRCS calls directly via module_function/Kernel
module Kernel
  def pause(_seconds); end
  def waitrt?; end
end

# Ensure namespaced constants point to the same top-level mocks.
# Code inside Lich::DragonRealms::DRCS resolves bare constants (DRC, DRCI, etc.)
# to the Lich::DragonRealms namespace first. Without these aliases, expect/allow
# calls on top-level constants won't intercept calls from the code under test.
module Lich
  module DragonRealms
    DRC = ::DRC unless defined?(Lich::DragonRealms::DRC)
    DRStats = ::DRStats unless defined?(Lich::DragonRealms::DRStats)
    DRCMM = ::DRCMM unless defined?(Lich::DragonRealms::DRCMM)
    DRCI = ::DRCI unless defined?(Lich::DragonRealms::DRCI)
  end
end

# Load the module under test
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-summoning.rb')

DRCS = Lich::DragonRealms::DRCS

RSpec.describe DRCS do
  before(:each) do
    Lich::Messaging.clear_messages!
  end

  # ─── Constants ──────────────────────────────────────────────────────

  describe 'constants' do
    it 'freezes all array/hash constants' do
      expect(DRCS::SUMMON_WEAPON_RESPONSES).to be_frozen
      expect(DRCS::BREAK_WEAPON_RESPONSES).to be_frozen
      expect(DRCS::MOON_SKILL_TO_SHAPE).to be_frozen
      expect(DRCS::MOON_SHAPE_RESPONSES).to be_frozen
      expect(DRCS::WM_SHAPE_FAILURES).to be_frozen
      expect(DRCS::TURN_WEAPON_RESPONSES).to be_frozen
      expect(DRCS::PUSH_WEAPON_RESPONSES).to be_frozen
      expect(DRCS::PULL_WEAPON_RESPONSES).to be_frozen
      expect(DRCS::SUMMON_ADMITTANCE_RESPONSES).to be_frozen
      expect(DRCS::WM_ELEMENT_ADJECTIVES).to be_frozen
    end

    it 'maps moon mage skills to shapes' do
      expect(DRCS::MOON_SKILL_TO_SHAPE['Staves']).to eq('blunt')
      expect(DRCS::MOON_SKILL_TO_SHAPE['Twohanded Edged']).to eq('huge')
      expect(DRCS::MOON_SKILL_TO_SHAPE['Large Edged']).to eq('heavy')
      expect(DRCS::MOON_SKILL_TO_SHAPE['Small Edged']).to eq('normal')
    end
  end

  # ─── get_ingot ──────────────────────────────────────────────────────

  describe '.get_ingot' do
    it 'returns true and does nothing when ingot is nil' do
      expect(DRCI).not_to receive(:get_item?)
      expect(DRCS.get_ingot(nil, true)).to be true
    end

    it 'calls DRCI.get_item? and returns true on success' do
      expect(DRCI).to receive(:get_item?).with('animite ingot').and_return(true)
      expect(DRCS.get_ingot('animite', false)).to be true
    end

    it 'calls swap after getting ingot when swap is true' do
      expect(DRCI).to receive(:get_item?).with('animite ingot').and_return(true)
      expect(DRC).to receive(:bput).with('swap', 'You move')
      DRCS.get_ingot('animite', true)
    end

    it 'does not swap when swap is false' do
      expect(DRCI).to receive(:get_item?).with('animite ingot').and_return(true)
      expect(DRC).not_to receive(:bput).with('swap', anything)
      DRCS.get_ingot('animite', false)
    end

    it 'returns false and logs message when get_item? fails' do
      expect(DRCI).to receive(:get_item?).with('animite ingot').and_return(false)
      expect(DRCS.get_ingot('animite', true)).to be false
      expect(Lich::Messaging.messages.last[:message]).to include('Could not get animite ingot')
    end
  end

  # ─── stow_ingot ────────────────────────────────────────────────────

  describe '.stow_ingot' do
    it 'returns true and does nothing when ingot is nil' do
      expect(DRCI).not_to receive(:put_away_item?)
      expect(DRCS.stow_ingot(nil)).to be true
    end

    it 'calls DRCI.put_away_item? and returns true on success' do
      expect(DRCI).to receive(:put_away_item?).with('animite ingot').and_return(true)
      expect(DRCS.stow_ingot('animite')).to be true
    end

    it 'returns false and logs message when put_away_item? fails' do
      expect(DRCI).to receive(:put_away_item?).with('animite ingot').and_return(false)
      expect(DRCS.stow_ingot('animite')).to be false
      expect(Lich::Messaging.messages.last[:message]).to include('Could not stow animite ingot')
    end
  end

  # ─── break_summoned_weapon ─────────────────────────────────────────

  describe '.break_summoned_weapon' do
    it 'returns early when item is nil' do
      expect(DRC).not_to receive(:bput)
      DRCS.break_summoned_weapon(nil)
    end

    it 'sends break command with expected responses' do
      expect(DRC).to receive(:bput).with('break my electric sword', *DRCS::BREAK_WEAPON_RESPONSES)
      DRCS.break_summoned_weapon('electric sword')
    end
  end

  # ─── summon_admittance ─────────────────────────────────────────────

  describe '.summon_admittance' do
    it 'sends summon admittance and waits' do
      expect(DRC).to receive(:bput).with('summon admittance', *DRCS::SUMMON_ADMITTANCE_RESPONSES).and_return('You align yourself to it')
      expect(DRC).to receive(:fix_standing)
      DRCS.summon_admittance
    end

    it 'retreats and retries when too distracted' do
      expect(DRC).to receive(:bput).with('summon admittance', *DRCS::SUMMON_ADMITTANCE_RESPONSES).and_return('You are a bit too distracted', 'You align yourself to it')
      expect(DRC).to receive(:retreat).once
      expect(DRC).to receive(:fix_standing)
      DRCS.summon_admittance
    end

    it 'handles fatal proximity response' do
      expect(DRC).to receive(:bput).with('summon admittance', *DRCS::SUMMON_ADMITTANCE_RESPONSES).and_return('Going any further while in this plane would be fatal')
      expect(DRC).to receive(:fix_standing)
      DRCS.summon_admittance
    end
  end

  # ─── summon_weapon ─────────────────────────────────────────────────

  describe '.summon_weapon' do
    context 'as a Moon Mage' do
      before do
        allow(DRStats).to receive(:moon_mage?).and_return(true)
      end

      it 'delegates to DRCMM.hold_moon_weapon?' do
        expect(DRCMM).to receive(:hold_moon_weapon?)
        expect(DRC).to receive(:fix_standing)
        DRCS.summon_weapon
      end
    end

    context 'as a Warrior Mage' do
      before do
        allow(DRStats).to receive(:moon_mage?).and_return(false)
        allow(DRStats).to receive(:warrior_mage?).and_return(true)
      end

      it 'gets ingot, summons, and stows ingot on success' do
        expect(DRCI).to receive(:get_item?).with('animite ingot').and_return(true)
        expect(DRC).to receive(:bput).with('swap', 'You move')
        expect(DRC).to receive(:bput).with('summon weapon fire Large Edged', *DRCS::SUMMON_WEAPON_RESPONSES).and_return('you draw out')
        expect(DRCI).to receive(:put_away_item?).with('animite ingot').and_return(true)
        expect(DRC).to receive(:fix_standing)
        DRCS.summon_weapon(nil, 'fire', 'animite', 'Large Edged')
      end

      it 'retries after summon admittance on charge failure' do
        expect(DRCI).to receive(:get_item?).with('animite ingot').and_return(true)
        expect(DRC).to receive(:bput).with('swap', 'You move')
        expect(DRC).to receive(:bput).with('summon weapon fire Large Edged', *DRCS::SUMMON_WEAPON_RESPONSES).and_return(DRCS::LACK_CHARGE, 'you draw out')
        expect(DRC).to receive(:bput).with('summon admittance', *DRCS::SUMMON_ADMITTANCE_RESPONSES).and_return('You align yourself to it')
        expect(DRC).to receive(:fix_standing).twice
        expect(DRCI).to receive(:put_away_item?).with('animite ingot').and_return(true)
        DRCS.summon_weapon(nil, 'fire', 'animite', 'Large Edged')
      end

      it 'skips summon when ingot retrieval fails' do
        expect(DRCI).to receive(:get_item?).with('animite ingot').and_return(false)
        expect(DRC).not_to receive(:bput).with(/summon weapon/, any_args)
        DRCS.summon_weapon(nil, 'fire', 'animite', 'Large Edged')
      end

      it 'works without an ingot' do
        expect(DRCI).not_to receive(:get_item?)
        expect(DRC).to receive(:bput).with('summon weapon fire Large Edged', *DRCS::SUMMON_WEAPON_RESPONSES).and_return('you draw out')
        expect(DRCI).not_to receive(:put_away_item?)
        expect(DRC).to receive(:fix_standing)
        DRCS.summon_weapon(nil, 'fire', nil, 'Large Edged')
      end
    end

    context 'as unsupported guild' do
      before do
        allow(DRStats).to receive(:moon_mage?).and_return(false)
        allow(DRStats).to receive(:warrior_mage?).and_return(false)
        allow(DRStats).to receive(:guild).and_return('Bard')
      end

      it 'logs unable to summon message' do
        expect(DRC).to receive(:fix_standing)
        DRCS.summon_weapon
        expect(Lich::Messaging.messages.last[:message]).to include('Unable to summon weapons as a Bard')
      end
    end
  end

  # ─── identify_summoned_weapon ──────────────────────────────────────

  describe '.identify_summoned_weapon' do
    context 'as a Moon Mage' do
      before do
        allow(DRStats).to receive(:moon_mage?).and_return(true)
      end

      it 'returns right hand when holding a moon weapon' do
        allow(DRC).to receive(:right_hand).and_return('red-hot moonblade')
        allow(DRCMM).to receive(:is_moon_weapon?).with('red-hot moonblade').and_return(true)
        expect(DRCS.identify_summoned_weapon).to eq('red-hot moonblade')
      end

      it 'returns left hand when moon weapon is in left hand' do
        allow(DRC).to receive(:right_hand).and_return('shield')
        allow(DRC).to receive(:left_hand).and_return('blue-white moonstaff')
        allow(DRCMM).to receive(:is_moon_weapon?).with('shield').and_return(false)
        allow(DRCMM).to receive(:is_moon_weapon?).with('blue-white moonstaff').and_return(true)
        expect(DRCS.identify_summoned_weapon).to eq('blue-white moonstaff')
      end

      it 'returns nil when no moon weapon in either hand' do
        allow(DRC).to receive(:right_hand).and_return('shield')
        allow(DRC).to receive(:left_hand).and_return(nil)
        allow(DRCMM).to receive(:is_moon_weapon?).and_return(false)
        expect(DRCS.identify_summoned_weapon).to be_nil
      end
    end

    context 'as a Warrior Mage' do
      before do
        allow(DRStats).to receive(:moon_mage?).and_return(false)
        allow(DRStats).to receive(:warrior_mage?).and_return(true)
      end

      it 'identifies summoned weapon in right hand via tap' do
        allow(DRC).to receive(:right_hand).and_return('electric sword')
        allow(DRCI).to receive(:tap).with('electric sword').and_return('You tap an electric sword that you are holding.')
        expect(DRCS.identify_summoned_weapon).to eq('electric sword')
      end

      it 'identifies summoned weapon in left hand via tap' do
        allow(DRC).to receive(:right_hand).and_return('shield')
        allow(DRC).to receive(:left_hand).and_return('fiery short sword')
        allow(DRCI).to receive(:tap).with('shield').and_return('You tap a shield that you are holding.')
        allow(DRCI).to receive(:tap).with('fiery short sword').and_return('You tap a fiery short sword that you are holding.')
        expect(DRCS.identify_summoned_weapon).to eq('fiery short sword')
      end

      it 'returns nil when no summoned weapon found' do
        allow(DRC).to receive(:right_hand).and_return('broadsword')
        allow(DRC).to receive(:left_hand).and_return(nil)
        allow(DRCI).to receive(:tap).with('broadsword').and_return('You tap a broadsword that you are holding.')
        allow(DRCI).to receive(:tap).with(nil).and_return(nil)
        expect(DRCS.identify_summoned_weapon).to be_nil
      end

      it 'handles stone element adjective' do
        allow(DRC).to receive(:right_hand).and_return('stone mace')
        allow(DRCI).to receive(:tap).with('stone mace').and_return('You tap a stone mace that you are holding.')
        expect(DRCS.identify_summoned_weapon).to eq('stone mace')
      end

      it 'handles icy element adjective' do
        allow(DRC).to receive(:right_hand).and_return('icy halberd')
        allow(DRCI).to receive(:tap).with('icy halberd').and_return('You tap an icy halberd that you are holding.')
        expect(DRCS.identify_summoned_weapon).to eq('icy halberd')
      end

      it 'handles custom adjective from settings' do
        settings = double('settings', summoned_weapons_adjective: 'blazing')
        allow(DRC).to receive(:right_hand).and_return('blazing sword')
        allow(DRCI).to receive(:tap).with('blazing sword').and_return('You tap a blazing sword that you are holding.')
        expect(DRCS.identify_summoned_weapon(settings)).to eq('blazing sword')
      end
    end

    context 'as unsupported guild' do
      before do
        allow(DRStats).to receive(:moon_mage?).and_return(false)
        allow(DRStats).to receive(:warrior_mage?).and_return(false)
        allow(DRStats).to receive(:guild).and_return('Trader')
      end

      it 'logs unable to identify message' do
        DRCS.identify_summoned_weapon
        expect(Lich::Messaging.messages.last[:message]).to include('Unable to identify summoned weapons as a Trader')
      end
    end
  end

  # ─── shape_summoned_weapon ─────────────────────────────────────────

  describe '.shape_summoned_weapon' do
    context 'as a Moon Mage' do
      before do
        allow(DRStats).to receive(:moon_mage?).and_return(true)
        allow(DRC).to receive(:right_hand).and_return('red-hot moonblade')
        allow(DRCMM).to receive(:is_moon_weapon?).with('red-hot moonblade').and_return(true)
      end

      it 'shapes moon weapon with skill lookup' do
        allow(DRCMM).to receive(:hold_moon_weapon?).and_return(true)
        expect(DRC).to receive(:bput).with('shape red-hot moonblade to heavy', *DRCS::MOON_SHAPE_RESPONSES)
        DRCS.shape_summoned_weapon('Large Edged')
      end

      it 'skips shape when hold_moon_weapon? fails' do
        allow(DRCMM).to receive(:hold_moon_weapon?).and_return(false)
        expect(DRC).not_to receive(:bput).with(/shape/, any_args)
        DRCS.shape_summoned_weapon('Large Edged')
      end
    end

    context 'as a Warrior Mage' do
      before do
        allow(DRStats).to receive(:moon_mage?).and_return(false)
        allow(DRStats).to receive(:warrior_mage?).and_return(true)
        allow(DRC).to receive(:right_hand).and_return('electric sword')
        allow(DRCI).to receive(:tap).with('electric sword').and_return('You tap an electric sword that you are holding.')
        allow(DRCI).to receive(:tap).with(nil).and_return(nil)
        allow(DRC).to receive(:left_hand).and_return(nil)
      end

      it 'shapes weapon successfully' do
        expect(DRC).to receive(:bput).with('shape my electric sword to Large Edged', *(DRCS::WM_SHAPE_FAILURES + ['What type of weapon were you trying'])).and_return('You reach out')
        DRCS.shape_summoned_weapon('Large Edged')
      end

      it 'retries after summon admittance on charge failure' do
        expect(DRC).to receive(:bput).with('shape my electric sword to Large Edged', *(DRCS::WM_SHAPE_FAILURES + ['What type of weapon were you trying'])).and_return(DRCS::LACK_CHARGE)
        expect(DRC).to receive(:bput).with('summon admittance', *DRCS::SUMMON_ADMITTANCE_RESPONSES).and_return('You align yourself to it')
        expect(DRC).to receive(:fix_standing)
        expect(DRC).to receive(:bput).with('shape my electric sword to Large Edged', *DRCS::WM_SHAPE_FAILURES).and_return('You reach out')
        DRCS.shape_summoned_weapon('Large Edged')
      end

      it 'retries without custom adjective on "What type of weapon" error' do
        settings = double('settings', summoned_weapons_adjective: 'blazing')
        allow(DRC).to receive(:right_hand).and_return('blazing sword')
        allow(DRCI).to receive(:tap).with('blazing sword').and_return('You tap a blazing sword that you are holding.')

        expect(DRC).to receive(:bput).with('shape my blazing sword to Large Edged', *(DRCS::WM_SHAPE_FAILURES + ['What type of weapon were you trying'])).and_return('What type of weapon were you trying')
        expect(DRC).to receive(:bput).with('shape my  sword to Large Edged', *DRCS::WM_SHAPE_FAILURES).and_return('You reach out')
        DRCS.shape_summoned_weapon('Large Edged', nil, settings)
      end

      it 'skips shape when ingot retrieval fails' do
        expect(DRCI).to receive(:get_item?).with('animite ingot').and_return(false)
        expect(DRC).not_to receive(:bput).with(/shape/, any_args)
        DRCS.shape_summoned_weapon('Large Edged', 'animite')
      end

      it 'gets and stows ingot around shape command' do
        expect(DRCI).to receive(:get_item?).with('animite ingot').and_return(true)
        expect(DRC).to receive(:bput).with('shape my electric sword to Large Edged', *(DRCS::WM_SHAPE_FAILURES + ['What type of weapon were you trying'])).and_return('You reach out')
        expect(DRCI).to receive(:put_away_item?).with('animite ingot').and_return(true)
        DRCS.shape_summoned_weapon('Large Edged', 'animite')
      end
    end

    context 'as unsupported guild' do
      before do
        allow(DRStats).to receive(:moon_mage?).and_return(false)
        allow(DRStats).to receive(:warrior_mage?).and_return(false)
        allow(DRStats).to receive(:guild).and_return('Empath')
      end

      it 'logs unable to shape message' do
        DRCS.shape_summoned_weapon('Large Edged')
        expect(Lich::Messaging.messages.last[:message]).to include('Unable to shape weapons as a Empath')
      end
    end
  end

  # ─── turn_summoned_weapon ──────────────────────────────────────────

  describe '.turn_summoned_weapon' do
    before do
      allow(DRC).to receive(:right_hand_noun).and_return('sword')
    end

    it 'turns weapon successfully' do
      expect(DRC).to receive(:bput).with('turn my sword', *DRCS::TURN_WEAPON_RESPONSES).and_return('You reach out')
      DRCS.turn_summoned_weapon
    end

    it 'retries after summon admittance on charge failure' do
      expect(DRC).to receive(:bput).with('turn my sword', *DRCS::TURN_WEAPON_RESPONSES).and_return(DRCS::LACK_CHARGE, 'You reach out')
      expect(DRC).to receive(:bput).with('summon admittance', *DRCS::SUMMON_ADMITTANCE_RESPONSES).and_return('You align yourself to it')
      expect(DRC).to receive(:fix_standing)
      DRCS.turn_summoned_weapon
    end
  end

  # ─── push_summoned_weapon ──────────────────────────────────────────

  describe '.push_summoned_weapon' do
    before do
      allow(DRC).to receive(:right_hand_noun).and_return('sword')
    end

    it 'pushes weapon successfully' do
      expect(DRC).to receive(:bput).with('push my sword', *DRCS::PUSH_WEAPON_RESPONSES).and_return('Closing your eyes')
      DRCS.push_summoned_weapon
    end

    it 'retries after summon admittance on charge failure' do
      expect(DRC).to receive(:bput).with('push my sword', *DRCS::PUSH_WEAPON_RESPONSES).and_return(DRCS::LACK_CHARGE, 'Closing your eyes')
      expect(DRC).to receive(:bput).with('summon admittance', *DRCS::SUMMON_ADMITTANCE_RESPONSES).and_return('You align yourself to it')
      expect(DRC).to receive(:fix_standing)
      DRCS.push_summoned_weapon
    end

    it 'handles already-at-max response' do
      expect(DRC).to receive(:bput).with('push my sword', *DRCS::PUSH_WEAPON_RESPONSES).and_return("That's as")
      DRCS.push_summoned_weapon
    end
  end

  # ─── pull_summoned_weapon ──────────────────────────────────────────

  describe '.pull_summoned_weapon' do
    before do
      allow(DRC).to receive(:right_hand_noun).and_return('sword')
    end

    it 'pulls weapon successfully' do
      expect(DRC).to receive(:bput).with('pull my sword', *DRCS::PULL_WEAPON_RESPONSES).and_return('Closing your eyes')
      DRCS.pull_summoned_weapon
    end

    it 'retries after summon admittance on charge failure' do
      expect(DRC).to receive(:bput).with('pull my sword', *DRCS::PULL_WEAPON_RESPONSES).and_return(DRCS::LACK_CHARGE, 'Closing your eyes')
      expect(DRC).to receive(:bput).with('summon admittance', *DRCS::SUMMON_ADMITTANCE_RESPONSES).and_return('You align yourself to it')
      expect(DRC).to receive(:fix_standing)
      DRCS.pull_summoned_weapon
    end

    it 'handles already-at-max response' do
      expect(DRC).to receive(:bput).with('pull my sword', *DRCS::PULL_WEAPON_RESPONSES).and_return("That's as")
      DRCS.pull_summoned_weapon
    end
  end
end
