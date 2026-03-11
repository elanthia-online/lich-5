# frozen_string_literal: true

require_relative '../../../spec_helper'
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

      def msg(type, message, **_opts)
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

module DRStats
  def self.guild; 'Warrior Mage'; end
  def self.encumbrance; 'None'; end
  def self.barbarian?; false; end
  def self.thief?; false; end
end unless defined?(DRStats)
Lich::DragonRealms::DRStats = DRStats unless defined?(Lich::DragonRealms::DRStats)

class DRSkill
  def self.getrank(_skill); 0; end
end unless defined?(DRSkill)
Lich::DragonRealms::DRSkill = DRSkill unless defined?(Lich::DragonRealms::DRSkill)

module DRSpells
  def self.active_spells; {}; end
end unless defined?(DRSpells)
Lich::DragonRealms::DRSpells = DRSpells unless defined?(Lich::DragonRealms::DRSpells)

module DRC
  module_function

  def bput(*_args)
    nil
  end

  def left_hand
    nil
  end

  def right_hand
    nil
  end

  def get_noun(*_args)
    nil
  end

  def text2num(*_args)
    0
  end

  def rummage(*_args)
    []
  end

  # Mock DRC::Item class for in_hand? method
  class Item
    attr_reader :short_regex

    def initialize(text)
      @short_regex = /#{Regexp.escape(text)}/i
    end

    def self.from_text(text)
      new(text)
    end
  end
end unless defined?(DRC)
Lich::DragonRealms::DRC = DRC unless defined?(Lich::DragonRealms::DRC)

class DRRoom
  def self.npcs; []; end
  def self.room_objs; []; end
end unless defined?(DRRoom)
Lich::DragonRealms::DRRoom = DRRoom unless defined?(Lich::DragonRealms::DRRoom)

class Room
  def self.current
    OpenStruct.new(tags: [])
  end
end unless defined?(Room)

# Mock XMLData for room_title
# XMLData may be a module (from this file) or OpenStruct (from spec_helper.rb).
# Always add methods if missing, using define_singleton_method to work with both.
module XMLData; end unless defined?(XMLData)
XMLData.define_singleton_method(:room_title) { '' } unless XMLData.respond_to?(:room_title)
XMLData.define_singleton_method(:server_time) { Time.at(1234567890) } unless XMLData.respond_to?(:server_time)

module Flags
  @flags = {}

  def self.add(name, *_args)
    @flags[name] = false
  end

  def self.delete(name)
    @flags.delete(name)
  end

  def self.reset(name)
    @flags[name] = false
  end

  def self.[](name)
    @flags[name]
  end

  def self.[]=(name, value)
    @flags[name] = value
  end
end unless defined?(Flags)

# Always reopen Script to add attributes/methods needed by tests.
# Other specs may define Script first (spec_helper.rb has a minimal version),
# so we augment rather than replace to avoid cross-spec failures.
class Script
  attr_accessor :paused, :no_pause_all, :name

  def paused?; @paused || false; end
  def pause; end
  def unpause; end

  class << self
    def running
      []
    end unless method_defined?(:running)

    def running?(_name)
      false
    end unless method_defined?(:running?)

    def exists?(_name)
      true
    end unless method_defined?(:exists?)

    def current
      nil
    end unless method_defined?(:current)

    def self
      OpenStruct.new(name: 'test')
    end unless method_defined?(:self)
  end
end

module UserVars
  @vars = {}
  class << self
    def method_missing(name, *args)
      name.to_s.end_with?('=') ? @vars[name.to_s.chomp('=')] = args.first : @vars[name.to_s]
    end

    def respond_to_missing?(_name, _include_private = false); true; end
  end
end unless defined?(UserVars)

# Mock Frontend module (added in PR #1170)
module Frontend
  def self.supports_gsl?; false; end
end unless defined?(Frontend)

$pause_all_lock = Mutex.new unless defined?($pause_all_lock)
$safe_pause_lock = Mutex.new unless defined?($safe_pause_lock)
$ORDINALS = %w[first second third fourth fifth sixth seventh eighth ninth tenth] unless defined?($ORDINALS)

# NOTE: `clear` MUST be private — a public Kernel `clear` is inherited by all objects,
# causing `Effects::Buffs.respond_to?(:clear)` to return true in qstrike_spec,
# which breaks buff cleanup. Private methods don't appear in `respond_to?` checks
# but are still callable as bare method calls within module_function methods like bput.
module Kernel
  def clear; end
  private :clear

  def pause(_seconds = nil); end
  def waitrt?; end
  def fput(_cmd); end
  def put(_cmd); end
  def get?; nil; end
  def echo(_msg); end
  def standing?; true; end
  def hiding?; false; end
  def invisible?; false; end
  def stunned?; false; end
  def webbed?; false; end
  def start_script(_name, _args = [], _flags = {}); nil; end
  def get_data(_key); OpenStruct.new(spell_data: {}); end unless defined?(get_data)
  def _respond(*_args); end
  def custom_require; proc { |_name| nil }; end

  def reget(*_args)
    []
  end
end

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-items.rb')

# Alias the real module at top level
DRCI = Lich::DragonRealms::DRCI unless defined?(DRCI)

RSpec.describe Lich::DragonRealms::DRCI do
  # Helper to stub game methods
  def stub_bput(response)
    allow(DRC).to receive(:bput).and_return(response)
  end

  describe 'constants' do
    describe 'TRASH_STORAGE' do
      it 'is frozen' do
        expect(described_class::TRASH_STORAGE).to be_frozen
      end

      it 'contains expected trash receptacles' do
        expect(described_class::TRASH_STORAGE).to include('barrel', 'bucket', 'bin', 'urn')
      end
    end

    describe 'pattern constants' do
      %i[
        DROP_TRASH_SUCCESS_PATTERNS
        DROP_TRASH_FAILURE_PATTERNS
        DROP_TRASH_RETRY_PATTERNS
        GET_ITEM_SUCCESS_PATTERNS
        GET_ITEM_FAILURE_PATTERNS
        WEAR_ITEM_SUCCESS_PATTERNS
        WEAR_ITEM_FAILURE_PATTERNS
        TIE_ITEM_SUCCESS_PATTERNS
        TIE_ITEM_FAILURE_PATTERNS
        UNTIE_ITEM_SUCCESS_PATTERNS
        UNTIE_ITEM_FAILURE_PATTERNS
        REMOVE_ITEM_SUCCESS_PATTERNS
        REMOVE_ITEM_FAILURE_PATTERNS
        PUT_AWAY_ITEM_SUCCESS_PATTERNS
        PUT_AWAY_ITEM_FAILURE_PATTERNS
        PUT_AWAY_ITEM_RETRY_PATTERNS
        STOW_ITEM_SUCCESS_PATTERNS
        STOW_ITEM_FAILURE_PATTERNS
        STOW_ITEM_RETRY_PATTERNS
        RUMMAGE_SUCCESS_PATTERNS
        RUMMAGE_FAILURE_PATTERNS
        TAP_SUCCESS_PATTERNS
        TAP_FAILURE_PATTERNS
        OPEN_CONTAINER_SUCCESS_PATTERNS
        OPEN_CONTAINER_FAILURE_PATTERNS
        CLOSE_CONTAINER_SUCCESS_PATTERNS
        CLOSE_CONTAINER_FAILURE_PATTERNS
        CONTAINER_IS_CLOSED_PATTERNS
        LOWER_SUCCESS_PATTERNS
        LOWER_FAILURE_PATTERNS
        LIFT_SUCCESS_PATTERNS
        LIFT_FAILURE_PATTERNS
        GIVE_ITEM_SUCCESS_PATTERNS
        GIVE_ITEM_FAILURE_PATTERNS
        COUNT_PART_PATTERNS
        BRAID_TOO_LONG_PATTERN
        ACCEPT_SUCCESS_PATTERN
      ].each do |const_name|
        it "#{const_name} is frozen" do
          expect(described_class.const_get(const_name)).to be_frozen
        end
      end
    end
  end

  describe '#item_ref' do
    context 'when value is nil' do
      it 'returns nil' do
        expect(described_class.item_ref(nil)).to be_nil
      end
    end

    context 'when value already starts with "my "' do
      it 'returns the value unchanged' do
        expect(described_class.item_ref('my sword')).to eq('my sword')
      end

      it 'handles case-insensitive "My "' do
        expect(described_class.item_ref('My sword')).to eq('My sword')
      end

      it 'handles case-insensitive "MY "' do
        expect(described_class.item_ref('MY sword')).to eq('MY sword')
      end
    end

    context 'when value starts with "#" (item ID)' do
      it 'returns the value unchanged' do
        expect(described_class.item_ref('#12345')).to eq('#12345')
      end

      it 'handles ID with container reference' do
        expect(described_class.item_ref('#12345 in #67890')).to eq('#12345 in #67890')
      end
    end

    context 'when value is a plain item name' do
      it 'prefixes with "my "' do
        expect(described_class.item_ref('sword')).to eq('my sword')
      end

      it 'handles item names with adjectives' do
        expect(described_class.item_ref('steel sword')).to eq('my steel sword')
      end

      it 'handles container names' do
        expect(described_class.item_ref('backpack')).to eq('my backpack')
      end
    end

    context 'integration with dispose_trash commands' do
      it 'uses item_ref for item references' do
        # Verify that item_ref is used in dispose_trash by checking the method exists
        expect(described_class).to respond_to(:item_ref)
      end
    end
  end

  describe '#dispose_trash' do
    before do
      allow(described_class).to receive(:get_item_if_not_held?).and_return(true)
      allow(Room).to receive(:current).and_return(OpenStruct.new(tags: []))
      allow(DRRoom).to receive(:room_objs).and_return([])
    end

    context 'when item is nil' do
      it 'returns nil' do
        expect(described_class.dispose_trash(nil)).to be_nil
      end
    end

    context 'when dropping succeeds' do
      it 'returns true' do
        stub_bput('You drop a rock.')
        expect(described_class.dispose_trash('rock')).to be true
      end
    end

    context 'when dropping fails' do
      it 'returns false and logs message' do
        stub_bput("What were you referring to?")
        expect(Lich::Messaging).to receive(:msg).with('bold', /Failed to dispose/)
        expect(described_class.dispose_trash('rock')).to be false
      end
    end

    context 'with worn trashcan' do
      it 'puts item in worn trashcan first' do
        allow(described_class).to receive(:get_item_if_not_held?).and_return(true)
        expect(DRC).to receive(:bput).with(/put my rock in my trashbag/, any_args).and_return('You put your rock in your trashbag.')
        expect(described_class.dispose_trash('rock', 'trashbag')).to be true
      end
    end
  end

  describe '#search?' do
    it 'returns true when item is found' do
      stub_bput('A rock is in your pack.')
      expect(described_class.search?('rock')).to be_truthy
    end

    it 'returns false when item is not found' do
      stub_bput("You can't seem to find anything")
      expect(described_class.search?('rock')).to be_falsey
    end
  end

  describe '#wearing?' do
    before do
      allow(described_class).to receive(:tap).and_return('You tap a cloak that you are wearing.')
    end

    it 'returns true when item is worn' do
      expect(described_class.wearing?('cloak')).to be_truthy
    end

    it 'returns false when item is not worn' do
      allow(described_class).to receive(:tap).and_return('You tap a sword inside your backpack.')
      expect(described_class.wearing?('sword')).to be_falsey
    end
  end

  describe '#inside?' do
    it 'returns true when item is inside container' do
      allow(described_class).to receive(:tap).and_return('You tap a gem inside your pouch.')
      expect(described_class.inside?('gem', 'pouch')).to be_truthy
    end

    it 'returns false when item is not inside' do
      allow(described_class).to receive(:tap).and_return('You tap a gem that you are wearing.')
      expect(described_class.inside?('gem', 'pouch')).to be_falsey
    end
  end

  describe '#exists?' do
    it 'returns true when tap succeeds' do
      allow(described_class).to receive(:tap).and_return('You tap a rock.')
      expect(described_class.exists?('rock')).to be true
    end

    it 'returns false when tap fails' do
      allow(described_class).to receive(:tap).and_return('What were you referring to?')
      expect(described_class.exists?('rock')).to be false
    end
  end

  describe '#tap' do
    context 'when item is nil' do
      it 'returns nil' do
        expect(described_class.tap(nil)).to be_nil
      end
    end

    it 'taps item without container' do
      expect(DRC).to receive(:bput).with('tap my sword ', any_args).and_return('You tap a sword.')
      described_class.tap('sword')
    end

    it 'taps item from container' do
      expect(DRC).to receive(:bput).with('tap my gem from my pouch', any_args).and_return('You tap a gem.')
      described_class.tap('gem', 'pouch')
    end
  end

  describe '#in_hands?' do
    before do
      allow(DRC).to receive(:left_hand).and_return('sword')
      allow(DRC).to receive(:right_hand).and_return(nil)
    end

    it 'returns true when item is in either hand' do
      expect(described_class.in_hands?('sword')).to be_truthy
    end

    it 'returns false when item is not in hands' do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      expect(described_class.in_hands?('axe')).to be_falsey
    end
  end

  describe '#in_hand?' do
    before do
      allow(DRC).to receive(:left_hand).and_return('sword')
      allow(DRC).to receive(:right_hand).and_return('shield')
    end

    context 'with left hand' do
      it 'returns truthy when item matches' do
        expect(described_class.in_hand?('sword', 'left')).to be_truthy
      end

      it 'returns falsey when item does not match' do
        expect(described_class.in_hand?('axe', 'left')).to be_falsey
      end
    end

    context 'with right hand' do
      it 'returns truthy when item matches' do
        expect(described_class.in_hand?('shield', 'right')).to be_truthy
      end
    end

    context 'with either hand' do
      it 'returns truthy when item in left' do
        expect(described_class.in_hand?('sword', 'either')).to be_truthy
      end

      it 'returns truthy when item in right' do
        expect(described_class.in_hand?('shield', 'either')).to be_truthy
      end
    end

    context 'with both hands' do
      it 'returns truthy when same item in both' do
        allow(DRC).to receive(:right_hand).and_return('sword')
        expect(described_class.in_hand?('sword', 'both')).to be_truthy
      end

      it 'returns falsey when different items' do
        expect(described_class.in_hand?('sword', 'both')).to be_falsey
      end
    end

    context 'with invalid hand' do
      it 'returns false and logs message' do
        expect(Lich::Messaging).to receive(:msg).with('bold', /Unknown hand/)
        expect(described_class.in_hand?('sword', 'middle')).to be false
      end
    end

    context 'when item is nil' do
      it 'returns false' do
        expect(described_class.in_hand?(nil)).to be false
      end
    end
  end

  describe '#count_items' do
    it 'returns 0 when tap returns no container' do
      allow(described_class).to receive(:tap).and_return('You tap a rock.')
      expect(described_class.count_items('rock')).to eq(0)
    end

    it 'extracts container and counts items' do
      allow(described_class).to receive(:tap).and_return('You tap a gem inside your pouch.')
      # The regex captures 'pouch.' including the period - this is how the original code works
      allow(described_class).to receive(:count_items_in_container).with('gem', 'pouch.').and_return(5)
      expect(described_class.count_items('gem')).to eq(5)
    end
  end

  describe '#count_items_in_container' do
    it 'counts matching items' do
      stub_bput('You rummage through your pouch and see a gem, a gem, and a rock.')
      expect(described_class.count_items_in_container('gem', 'pouch')).to eq(2)
    end
  end

  describe '#stow_hands' do
    it 'stows both hands when occupied' do
      allow(DRC).to receive(:left_hand).and_return('sword')
      allow(DRC).to receive(:right_hand).and_return('shield')
      allow(described_class).to receive(:stow_hand).and_return(true)
      expect(described_class.stow_hands).to be true
    end

    it 'returns true when hands are empty' do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      expect(described_class.stow_hands).to be true
    end
  end

  describe '#stow_hand' do
    context 'when stow succeeds' do
      it 'returns true' do
        stub_bput('You put your sword in your pack.')
        expect(described_class.stow_hand('left')).to be true
      end
    end

    context 'when braid is too long' do
      it 'disposes of the braid' do
        allow(DRC).to receive(:bput).and_return('The braided rope is too long')
        allow(DRC).to receive(:get_noun).and_return('rope')
        expect(described_class).to receive(:dispose_trash).with('rope')
        described_class.stow_hand('left')
      end
    end

    context 'when stow fails' do
      it 'returns false' do
        stub_bput("Stow what?")
        expect(described_class.stow_hand('left')).to be false
      end
    end
  end

  describe '#get_item_if_not_held?' do
    context 'when item is nil' do
      it 'returns false' do
        expect(described_class.get_item_if_not_held?(nil)).to be false
      end
    end

    context 'when already holding item' do
      it 'returns true without getting' do
        allow(described_class).to receive(:in_hands?).and_return(true)
        expect(described_class).not_to receive(:get_item)
        expect(described_class.get_item_if_not_held?('sword')).to be true
      end
    end

    context 'when not holding item' do
      it 'gets the item' do
        allow(described_class).to receive(:in_hands?).and_return(false)
        expect(described_class).to receive(:get_item).with('sword', nil).and_return(true)
        expect(described_class.get_item_if_not_held?('sword')).to be true
      end
    end
  end

  describe '#get_item' do
    context 'with array of containers' do
      it 'tries each container until success' do
        allow(described_class).to receive(:get_item_safe).and_return(false, true)
        expect(described_class.get_item('sword', %w[pack bag])).to be true
      end

      it 'returns false if all containers fail' do
        allow(described_class).to receive(:get_item_safe).and_return(false)
        expect(described_class.get_item('sword', %w[pack bag])).to be false
      end
    end

    context 'with single container' do
      it 'delegates to get_item_safe' do
        expect(described_class).to receive(:get_item_safe).with('sword', 'pack').and_return(true)
        described_class.get_item('sword', 'pack')
      end
    end
  end

  describe '#get_item_safe?' do
    it 'adds my prefix to item' do
      expect(described_class).to receive(:get_item_unsafe).with('my sword', 'my pack').and_return(true)
      described_class.get_item_safe?('sword', 'pack')
    end

    it 'preserves existing my prefix' do
      expect(described_class).to receive(:get_item_unsafe).with('my sword', 'my pack').and_return(true)
      described_class.get_item_safe?('my sword', 'my pack')
    end
  end

  describe '#get_item_unsafe' do
    context 'when get succeeds' do
      it 'returns true' do
        stub_bput('You get a sword.')
        expect(described_class.get_item_unsafe('sword', nil)).to be true
      end
    end

    context 'when get fails' do
      it 'returns false' do
        stub_bput('Get what?')
        expect(described_class.get_item_unsafe('sword', nil)).to be false
      end
    end
  end

  describe '#tie_item?' do
    context 'when tie succeeds' do
      it 'returns true' do
        stub_bput('You carefully tie your rope to your belt.')
        expect(described_class.tie_item?('rope', 'belt')).to be true
      end
    end

    context 'when attach succeeds' do
      it 'returns true' do
        stub_bput('You attach your rope to your belt.')
        expect(described_class.tie_item?('rope', 'belt')).to be true
      end
    end

    context 'when tie fails' do
      it 'returns false' do
        stub_bput("There's no more free ties.")
        expect(described_class.tie_item?('rope', 'belt')).to be false
      end
    end
  end

  describe '#untie_item?' do
    context 'when untie succeeds' do
      it 'returns true' do
        stub_bput('You untie your rope from your belt.')
        expect(described_class.untie_item?('rope', 'belt')).to be true
      end
    end

    context 'when untie fails' do
      it 'returns false' do
        stub_bput('Untie what?')
        expect(described_class.untie_item?('rope', 'belt')).to be false
      end
    end
  end

  describe '#wear_item?' do
    context 'when wear succeeds' do
      it 'returns true' do
        stub_bput('You put on your cloak.')
        expect(described_class.wear_item?('cloak')).to be true
      end
    end

    context 'when wear fails' do
      it 'returns false' do
        stub_bput("You can't wear that.")
        expect(described_class.wear_item?('cloak')).to be false
      end
    end
  end

  describe '#remove_item?' do
    context 'when remove succeeds' do
      it 'returns true' do
        stub_bput('You remove a cloak.')
        expect(described_class.remove_item?('cloak')).to be true
      end
    end

    context 'when remove fails' do
      it 'returns false' do
        stub_bput("You aren't wearing that.")
        expect(described_class.remove_item?('cloak')).to be false
      end
    end
  end

  describe '#stow_item?' do
    context 'when stow succeeds' do
      it 'returns true' do
        stub_bput('You put your sword in your pack.')
        expect(described_class.stow_item?('sword')).to be true
      end
    end

    context 'when stow fails' do
      it 'returns false' do
        stub_bput('Stow what?')
        expect(described_class.stow_item?('sword')).to be false
      end
    end

    context 'with retry pattern' do
      it 'retries the stow' do
        allow(DRC).to receive(:bput).and_return('Something appears different about', 'You put your sword in your pack.')
        expect(described_class.stow_item?('sword')).to be true
      end
    end
  end

  describe '#lower_item?' do
    context 'when item not in hands' do
      it 'returns false' do
        allow(described_class).to receive(:in_hands?).and_return(false)
        expect(described_class.lower_item?('sword')).to be false
      end
    end

    context 'when lower succeeds' do
      it 'returns true' do
        allow(described_class).to receive(:in_hands?).and_return(true)
        allow(DRC).to receive(:left_hand).and_return('sword')
        stub_bput('You lower your sword to the ground.')
        expect(described_class.lower_item?('sword')).to be true
      end
    end

    context 'when lower fails' do
      it 'returns false' do
        allow(described_class).to receive(:in_hands?).and_return(true)
        allow(DRC).to receive(:left_hand).and_return('sword')
        stub_bput("But you aren't holding anything.")
        expect(described_class.lower_item?('sword')).to be false
      end
    end
  end

  describe '#lift?' do
    context 'when lift succeeds' do
      it 'returns true' do
        stub_bput('You pick up a sword.')
        expect(described_class.lift?('sword')).to be true
      end
    end

    context 'when lift fails' do
      it 'returns false' do
        stub_bput('There are no items lying at your feet.')
        expect(described_class.lift?('sword')).to be false
      end
    end

    context 'with stow parameter as string' do
      it 'calls put_away_item?' do
        allow(DRC).to receive(:bput).and_return('You pick up a sword.')
        expect(described_class).to receive(:put_away_item?).with('sword', 'pack').and_return(true)
        described_class.lift?('sword', 'pack')
      end
    end

    context 'with stow parameter as true' do
      it 'calls stow_item?' do
        allow(DRC).to receive(:bput).and_return('You pick up a sword.')
        expect(described_class).to receive(:stow_item?).with('sword').and_return(true)
        described_class.lift?('sword', true)
      end
    end
  end

  describe '#container_is_empty?' do
    it 'returns true when container is empty' do
      allow(described_class).to receive(:look_in_container).and_return([])
      expect(described_class.container_is_empty?('pack')).to be true
    end

    it 'returns false when container has items' do
      allow(described_class).to receive(:look_in_container).and_return(['sword', 'shield'])
      expect(described_class.container_is_empty?('pack')).to be false
    end
  end

  describe '#rummage_container' do
    context 'when rummage succeeds' do
      it 'returns list of items' do
        stub_bput('You rummage through your pack and see a sword, a shield, and some gems.')
        result = described_class.rummage_container('pack')
        expect(result).to include('sword')
      end
    end

    context 'when rummage fails' do
      it 'returns nil and logs message' do
        stub_bput('I could not find what you were referring to.')
        expect(Lich::Messaging).to receive(:msg).with('bold', /Unable to rummage/)
        expect(described_class.rummage_container('pack')).to be_nil
      end
    end

    context 'when container is closed' do
      it 'tries to open and retry' do
        allow(DRC).to receive(:bput).and_return("That is closed.", 'You rummage through your pack and see a sword.')
        allow(described_class).to receive(:open_container?).and_return(true)
        result = described_class.rummage_container('pack')
        expect(result).to include('sword')
      end
    end
  end

  describe '#look_in_container' do
    context 'when look succeeds' do
      it 'returns list of items' do
        stub_bput('In the pack you see a sword and a shield.')
        result = described_class.look_in_container('pack')
        expect(result).to include('sword')
      end
    end

    context 'when look fails' do
      it 'returns nil and logs message' do
        stub_bput('I could not find what you were referring to.')
        expect(Lich::Messaging).to receive(:msg).with('bold', /Unable to look in/)
        expect(described_class.look_in_container('pack')).to be_nil
      end
    end
  end

  describe '#put_away_item?' do
    context 'with array of containers' do
      it 'tries each container until success' do
        allow(described_class).to receive(:put_away_item_safe?).and_return(false, true)
        expect(described_class.put_away_item?('sword', %w[pack bag])).to be true
      end
    end

    context 'when put succeeds' do
      it 'returns true' do
        stub_bput('You put your sword in your pack.')
        expect(described_class.put_away_item?('sword', 'pack')).to be true
      end
    end

    context 'when put fails' do
      it 'returns false' do
        stub_bput("There isn't any more room in your pack.")
        expect(described_class.put_away_item?('sword', 'pack')).to be false
      end
    end
  end

  describe '#open_container?' do
    context 'when open succeeds' do
      it 'returns true' do
        stub_bput('You open your pack.')
        expect(described_class.open_container?('pack')).to be true
      end
    end

    context 'when already open' do
      it 'returns true' do
        stub_bput("It's already open.")
        expect(described_class.open_container?('pack')).to be true
      end
    end

    context 'when open fails' do
      it 'returns false' do
        stub_bput('Open what?')
        expect(described_class.open_container?('pack')).to be false
      end
    end
  end

  describe '#close_container?' do
    context 'when close succeeds' do
      it 'returns true' do
        stub_bput('You close your pack.')
        expect(described_class.close_container?('pack')).to be true
      end
    end

    context 'when close fails' do
      it 'returns false' do
        stub_bput("You can't do that.")
        expect(described_class.close_container?('pack')).to be false
      end
    end
  end

  describe '#give_item?' do
    context 'when give succeeds' do
      it 'returns true' do
        stub_bput('Playerone has accepted your offer.')
        expect(described_class.give_item?('Playerone', 'sword')).to be true
      end
    end

    context 'when give fails' do
      it 'returns false' do
        stub_bput('Playerone has declined the offer.')
        expect(described_class.give_item?('Playerone', 'sword')).to be false
      end
    end

    context 'with retry pattern' do
      it 'retries the give' do
        allow(DRC).to receive(:bput).and_return('GIVE it again', 'Playerone has accepted your offer.')
        allow(described_class).to receive(:waitrt)
        expect(described_class.give_item?('Playerone', 'sword')).to be true
      end
    end
  end

  describe '#accept_item?' do
    context 'when accept succeeds' do
      it 'returns the giver name' do
        stub_bput("You accept Playerone's offer and are now holding a sword.")
        expect(described_class.accept_item?).to eq('Playerone')
      end
    end

    context 'when no offers' do
      it 'returns false' do
        stub_bput('You have no offers')
        expect(described_class.accept_item?).to be false
      end
    end

    context 'when hands full' do
      it 'returns false' do
        stub_bput('Both of your hands are full')
        expect(described_class.accept_item?).to be false
      end
    end
  end

  describe '#swap_out_full_gempouch?' do
    let(:adj) { 'leather' }
    let(:noun) { 'pouch' }

    before do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
    end

    context 'when no free hand' do
      it 'returns false and logs message' do
        allow(DRC).to receive(:left_hand).and_return('sword')
        allow(DRC).to receive(:right_hand).and_return('shield')
        expect(Lich::Messaging).to receive(:msg).with('bold', /No free hand/)
        expect(described_class.swap_out_full_gempouch?(adj, noun)).to be false
      end
    end

    context 'when swap succeeds' do
      it 'returns true' do
        allow(described_class).to receive(:remove_and_stow_pouch?).and_return(true)
        allow(described_class).to receive(:check_belt_for_pouch?).and_return(false)
        allow(described_class).to receive(:get_item?).and_return(true)
        allow(described_class).to receive(:wear_item?).and_return(true)
        expect(described_class.swap_out_full_gempouch?(adj, noun)).to be true
      end
    end

    context 'when remove fails' do
      it 'returns false and logs message' do
        allow(described_class).to receive(:remove_and_stow_pouch?).and_return(false)
        expect(Lich::Messaging).to receive(:msg).with('bold', /Remove and stow pouch routine failed/)
        expect(described_class.swap_out_full_gempouch?(adj, noun)).to be false
      end
    end

    context 'when get spare pouch fails' do
      it 'returns false and logs message' do
        allow(described_class).to receive(:remove_and_stow_pouch?).and_return(true)
        allow(described_class).to receive(:check_belt_for_pouch?).and_return(false)
        allow(described_class).to receive(:get_item?).and_return(false)
        expect(Lich::Messaging).to receive(:msg).with('bold', /No spare pouch found/)
        expect(described_class.swap_out_full_gempouch?(adj, noun)).to be false
      end
    end

    context 'when wear fails' do
      it 'returns false and logs message' do
        allow(described_class).to receive(:remove_and_stow_pouch?).and_return(true)
        allow(described_class).to receive(:check_belt_for_pouch?).and_return(false)
        allow(described_class).to receive(:get_item?).and_return(true)
        allow(described_class).to receive(:wear_item?).and_return(false)
        expect(Lich::Messaging).to receive(:msg).with('bold', /Could not wear new pouch/)
        expect(described_class.swap_out_full_gempouch?(adj, noun)).to be false
      end
    end
  end

  describe '#remove_and_stow_pouch?' do
    let(:adj) { 'leather' }
    let(:noun) { 'pouch' }

    context 'when remove fails' do
      it 'returns false and logs message' do
        allow(described_class).to receive(:remove_item?).and_return(false)
        expect(Lich::Messaging).to receive(:msg).with('bold', /Unable to remove existing pouch/)
        expect(described_class.remove_and_stow_pouch?(adj, noun)).to be false
      end
    end

    context 'when put_away succeeds' do
      it 'returns true' do
        allow(described_class).to receive(:remove_item?).and_return(true)
        allow(described_class).to receive(:put_away_item?).and_return(true)
        expect(described_class.remove_and_stow_pouch?(adj, noun, 'container')).to be true
      end
    end

    context 'when put_away fails but stow succeeds' do
      it 'returns true' do
        allow(described_class).to receive(:remove_item?).and_return(true)
        allow(described_class).to receive(:put_away_item?).and_return(false)
        allow(described_class).to receive(:stow_item?).and_return(true)
        expect(described_class.remove_and_stow_pouch?(adj, noun, 'container')).to be true
      end
    end

    context 'when both put_away and stow fail' do
      it 'returns false' do
        allow(described_class).to receive(:remove_item?).and_return(true)
        allow(described_class).to receive(:put_away_item?).and_return(false)
        allow(described_class).to receive(:stow_item?).and_return(false)
        expect(described_class.remove_and_stow_pouch?(adj, noun, 'container')).to be false
      end
    end
  end

  describe '#fill_gem_pouch_with_container' do
    let(:adj) { 'leather' }
    let(:noun) { 'pouch' }
    let(:source) { 'sack' }

    before do
      allow(Flags).to receive(:add)
      allow(Flags).to receive(:delete)
      allow(Flags).to receive(:reset)
      allow(Flags).to receive(:[]).and_return(false)
    end

    it 'adds and deletes flag properly' do
      stub_bput('You fill your pouch.')
      expect(Flags).to receive(:add).with('pouch-full', anything)
      expect(Flags).to receive(:delete).with('pouch-full')
      described_class.fill_gem_pouch_with_container(adj, noun, source)
    end

    context 'when container not found' do
      it 'logs message and returns' do
        stub_bput('Please rephrase that command')
        expect(Lich::Messaging).to receive(:msg).with('bold', /Fill failed/)
        expect(Flags).to receive(:delete).with('pouch-full')
        described_class.fill_gem_pouch_with_container(adj, noun, source)
      end
    end
  end

  describe '#count_item_parts' do
    before do
      allow(described_class).to receive(:waitrt?)
    end

    context 'when item not found' do
      it 'returns 0' do
        stub_bput('I could not find what you were referring to.')
        expect(described_class.count_item_parts('ingot')).to eq(0)
      end
    end

    context 'when item is non-stackable' do
      it 'logs message and counts items instead' do
        allow(DRC).to receive(:bput).and_return('tell you much of anything.')
        allow(described_class).to receive(:count_items).and_return(3)
        expect(Lich::Messaging).to receive(:msg).with('bold', /non-stackable item/)
        expect(described_class.count_item_parts('sword')).to eq(3)
      end
    end

    context 'when counting parts with text number' do
      it 'returns the count using text2num' do
        allow(DRC).to receive(:bput).and_return('There are five parts left.', 'I could not find what you were referring to.')
        allow(DRC).to receive(:text2num).with('five').and_return(5)
        expect(described_class.count_item_parts('ingot')).to eq(5)
      end
    end

    context 'with numeric count' do
      it 'parses numeric value' do
        allow(DRC).to receive(:bput).and_return('There are 10 parts left.', 'I could not find what you were referring to.')
        expect(described_class.count_item_parts('ingot')).to eq(10)
      end
    end

    context 'with multiple ordinals' do
      it 'counts across multiple stacks' do
        allow(DRC).to receive(:bput).and_return(
          'There are 5 parts left.',
          'There are 3 parts left.',
          'I could not find what you were referring to.'
        )
        expect(described_class.count_item_parts('ingot')).to eq(8)
      end
    end
  end

  describe '#count_items_in_container' do
    it 'counts matching items in container' do
      stub_bput('You rummage through your pouch and see a gem, a gem, and a rock.')
      expect(described_class.count_items_in_container('gem', 'pouch')).to eq(2)
    end

    it 'returns 0 when no matching items' do
      stub_bput('You rummage through your pouch and see a rock.')
      expect(described_class.count_items_in_container('gem', 'pouch')).to eq(0)
    end

    it 'returns 0 when container is empty' do
      stub_bput('That would accomplish nothing.')
      expect(described_class.count_items_in_container('gem', 'pouch')).to eq(0)
    end
  end

  describe '#count_lockpick_container' do
    before { allow(described_class).to receive(:waitrt?) }

    it 'returns capacity when container has space' do
      stub_bput('it might hold an additional 15 lockpicks.')
      expect(described_class.count_lockpick_container('ring')).to eq(15)
    end

    it 'returns 0 when container is full' do
      stub_bput('it appears to be full.')
      expect(described_class.count_lockpick_container('ring')).to eq(0)
    end

    it 'returns count when empty' do
      stub_bput('25 lockpicks would probably fit.')
      expect(described_class.count_lockpick_container('ring')).to eq(25)
    end
  end

  describe '#count_necro_stacker' do
    it 'returns the item count' do
      stub_bput('The stacker currently holds 42 items.')
      expect(described_class.count_necro_stacker('stacker')).to eq(42)
    end

    it 'returns 0 when no match' do
      stub_bput('You see nothing special.')
      expect(described_class.count_necro_stacker('stacker')).to eq(0)
    end
  end

  describe '#count_all_boxes' do
    let(:settings) do
      OpenStruct.new(
        picking_box_source: 'pack',
        pick: {
          'picking_box_sources' => ['bag'],
          'blacklist_container' => 'sack',
          'too_hard_container'  => nil
        }
      )
    end

    it 'counts boxes across all configured containers' do
      allow(described_class).to receive(:get_box_list_in_container).and_return(['box1'], ['box2', 'box3'], [])
      expect(described_class.count_all_boxes(settings)).to eq(3)
    end

    it 'handles empty containers' do
      allow(described_class).to receive(:get_box_list_in_container).and_return([])
      expect(described_class.count_all_boxes(settings)).to eq(0)
    end
  end

  describe '#get_box_list_in_container' do
    it 'delegates to DRC.rummage' do
      expect(DRC).to receive(:rummage).with('B', 'pack').and_return(['box1', 'box2'])
      expect(described_class.get_box_list_in_container('pack')).to eq(['box1', 'box2'])
    end
  end

  describe '#get_scroll_list_in_container' do
    it 'delegates to DRC.rummage' do
      expect(DRC).to receive(:rummage).with('SC', 'pack').and_return(['scroll1'])
      expect(described_class.get_scroll_list_in_container('pack')).to eq(['scroll1'])
    end
  end

  describe '#get_inventory_by_type' do
    before do
      allow(described_class).to receive(:reget).and_return([
                                                             'All of your combat items:',
                                                             'a sword',
                                                             'a shield',
                                                             '[Use INVENTORY HELP for more options.]'
                                                           ])
    end

    context 'when type is valid' do
      it 'returns list of items' do
        stub_bput('Use INVENTORY HELP for more options.')
        result = described_class.get_inventory_by_type('combat')
        expect(result).to include('sword')
      end
    end

    context 'when type is invalid' do
      it 'returns empty array and logs message' do
        stub_bput('The INVENTORY command is the best way')
        expect(Lich::Messaging).to receive(:msg).with('bold', /Unrecognized inventory type/)
        expect(described_class.get_inventory_by_type('invalid')).to eq([])
      end
    end
  end

  describe '#get_item_list' do
    it 'delegates to rummage_container for rummage verb' do
      expect(described_class).to receive(:rummage_container).with('pack').and_return(['sword'])
      expect(described_class.get_item_list('pack', 'rummage')).to eq(['sword'])
    end

    it 'delegates to look_in_container for look verb' do
      expect(described_class).to receive(:look_in_container).with('pack').and_return(['sword'])
      expect(described_class.get_item_list('pack', 'look')).to eq(['sword'])
    end
  end

  describe '#have_item_by_look?' do
    context 'when item is nil' do
      it 'returns false' do
        expect(described_class.have_item_by_look?(nil, 'pack')).to be false
      end
    end

    context 'when item exists' do
      it 'returns true' do
        stub_bput('You see nothing unusual about the sword.')
        expect(described_class.have_item_by_look?('sword', 'pack')).to be true
      end
    end

    context 'when item not found' do
      it 'returns false' do
        stub_bput('I could not find what you were referring to.')
        expect(described_class.have_item_by_look?('sword', 'pack')).to be false
      end
    end
  end

  describe '#get_item_from_eddy_portal?' do
    before do
      allow(described_class).to receive(:open_container?).and_return(true)
      allow(described_class).to receive(:look_in_container).and_return(['item'])
    end

    context 'when eddy cannot be opened' do
      it 'returns false' do
        allow(described_class).to receive(:open_container?).and_return(false)
        expect(described_class.get_item_from_eddy_portal?('gem', 'portal')).to be false
      end
    end

    context 'when get succeeds' do
      it 'returns true' do
        stub_bput('You get a gem from the portal.')
        expect(described_class.get_item_from_eddy_portal?('gem', 'portal')).to be true
      end
    end

    context 'when get fails' do
      it 'returns false' do
        stub_bput('Get what?')
        expect(described_class.get_item_from_eddy_portal?('gem', 'portal')).to be false
      end
    end
  end

  describe '#tie_gem_pouch' do
    it 'delegates to tie_gem_pouch? (deprecated method)' do
      allow(described_class).to receive(:tie_gem_pouch?).and_return(true)
      expect(described_class).to receive(:tie_gem_pouch?).with('leather', 'pouch')
      described_class.tie_gem_pouch('leather', 'pouch')
    end
  end

  describe '#get_item_safe' do
    it 'delegates to get_item_safe?' do
      expect(described_class).to receive(:get_item_safe?).with('sword', 'pack').and_return(true)
      expect(described_class.get_item_safe('sword', 'pack')).to be true
    end
  end

  describe '#put_away_item_safe?' do
    it 'adds my prefix and delegates to put_away_item_unsafe?' do
      expect(described_class).to receive(:put_away_item_unsafe?).with('my sword', 'my pack').and_return(true)
      described_class.put_away_item_safe?('sword', 'pack')
    end
  end

  describe '#wear_item_safe?' do
    it 'adds my prefix and delegates to wear_item_unsafe?' do
      expect(described_class).to receive(:wear_item_unsafe?).with('my cloak').and_return(true)
      described_class.wear_item_safe?('cloak')
    end
  end

  describe '#remove_item_safe?' do
    it 'adds my prefix and delegates to remove_item_unsafe?' do
      expect(described_class).to receive(:remove_item_unsafe?).with('my cloak').and_return(true)
      described_class.remove_item_safe?('cloak')
    end
  end

  describe '#stow_item_safe?' do
    it 'adds my prefix and delegates to stow_item_unsafe?' do
      expect(described_class).to receive(:stow_item_unsafe?).with('my sword').and_return(true)
      described_class.stow_item_safe?('sword')
    end
  end

  #########################################
  # GEM POUCH HANDLING - NEW TESTS
  #########################################

  describe 'gem pouch constants' do
    describe 'FILL_POUCH_SUCCESS_PATTERNS' do
      it 'is frozen' do
        expect(described_class::FILL_POUCH_SUCCESS_PATTERNS).to be_frozen
      end

      it 'contains expected patterns' do
        patterns = described_class::FILL_POUCH_SUCCESS_PATTERNS
        expect(patterns.any? { |p| 'You open your pouch'.match?(p) }).to be true
        expect(patterns.any? { |p| 'You fill your pouch with gems'.match?(p) }).to be true
        expect(patterns.any? { |p| "There aren't any gems".match?(p) }).to be true
      end
    end

    describe 'FILL_POUCH_NEEDS_TIE_PATTERNS' do
      it 'is frozen' do
        expect(described_class::FILL_POUCH_NEEDS_TIE_PATTERNS).to be_frozen
      end

      it 'contains expected patterns' do
        patterns = described_class::FILL_POUCH_NEEDS_TIE_PATTERNS
        expect(patterns.any? { |p| "You'd better tie it up before putting".match?(p) }).to be true
        expect(patterns.any? { |p| "You'll need to tie it up before".match?(p) }).to be true
      end
    end

    describe 'FILL_POUCH_FULL_PATTERN' do
      it 'is frozen' do
        expect(described_class::FILL_POUCH_FULL_PATTERN).to be_frozen
      end

      it 'matches full pouch message' do
        expect('is too full to fit any more').to match(described_class::FILL_POUCH_FULL_PATTERN)
      end
    end

    describe 'FILL_POUCH_FAILURE_PATTERNS' do
      it 'is frozen' do
        expect(described_class::FILL_POUCH_FAILURE_PATTERNS).to be_frozen
      end

      it 'contains expected patterns' do
        patterns = described_class::FILL_POUCH_FAILURE_PATTERNS
        expect(patterns.any? { |p| 'Please rephrase that command'.match?(p) }).to be true
        expect(patterns.any? { |p| 'What were you referring to'.match?(p) }).to be true
      end

      it 'does not contain empty source pattern (moved to success)' do
        patterns = described_class::FILL_POUCH_FAILURE_PATTERNS
        expect(patterns.any? { |p| "There aren't any gems".match?(p) }).to be false
      end
    end

    describe 'INV_BELT_START_PATTERN' do
      it 'is frozen' do
        expect(described_class::INV_BELT_START_PATTERN).to be_frozen
      end

      it 'matches belt inventory header' do
        expect('All of your items worn attached to the belt:').to match(described_class::INV_BELT_START_PATTERN)
      end
    end

    describe 'INV_BELT_END_PATTERN' do
      it 'is frozen' do
        expect(described_class::INV_BELT_END_PATTERN).to be_frozen
      end

      it 'matches inventory help footer' do
        expect('[Use INVENTORY HELP for more options.]').to match(described_class::INV_BELT_END_PATTERN)
      end
    end

    describe 'TIE_ITEM_SUCCESS_PATTERNS' do
      it 'includes already tied pattern' do
        patterns = described_class::TIE_ITEM_SUCCESS_PATTERNS
        expect(patterns.any? { |p| 'has already been tied off'.match?(p) }).to be true
      end

      it 'includes empty container rhetorical question' do
        patterns = described_class::TIE_ITEM_SUCCESS_PATTERNS
        expect(patterns.any? { |p| "Tie it off when it's empty?  Why?".match?(p) }).to be true
      end
    end
  end

  describe '#check_belt_for_pouch?' do
    let(:adj) { 'soft' }
    let(:noun) { 'pouch' }

    context 'when issue_command returns nil (timeout)' do
      it 'returns false' do
        allow(Lich::Util).to receive(:issue_command).and_return(nil)
        expect(described_class.check_belt_for_pouch?(adj, noun)).to be false
      end
    end

    context 'when issue_command returns empty array' do
      it 'returns false' do
        allow(Lich::Util).to receive(:issue_command).and_return([])
        expect(described_class.check_belt_for_pouch?(adj, noun)).to be false
      end
    end

    context 'when matching gem pouch found on belt' do
      it 'returns true' do
        belt_contents = [
          'All of your items worn attached to the belt:',
          '  a soft gem pouch (closed)',
          '  a leather wallet',
          '  a lockpick ring'
        ]
        allow(Lich::Util).to receive(:issue_command).and_return(belt_contents)
        expect(described_class.check_belt_for_pouch?(adj, noun)).to be true
      end
    end

    context 'when no matching gem pouch found' do
      it 'returns false' do
        belt_contents = [
          'All of your items worn attached to the belt:',
          '  a leather wallet',
          '  a lockpick ring'
        ]
        allow(Lich::Util).to receive(:issue_command).and_return(belt_contents)
        expect(described_class.check_belt_for_pouch?(adj, noun)).to be false
      end
    end

    context 'when non-gem pouch found' do
      it 'returns false (requires gem in name)' do
        belt_contents = [
          'All of your items worn attached to the belt:',
          '  a soft leather pouch',
          '  a lockpick ring'
        ]
        allow(Lich::Util).to receive(:issue_command).and_return(belt_contents)
        expect(described_class.check_belt_for_pouch?(adj, noun)).to be false
      end
    end

    context 'with different adjective' do
      it 'matches the configured adjective' do
        belt_contents = [
          'All of your items worn attached to the belt:',
          '  a large gem pouch (closed)',
          '  a soft gem pouch (closed)'
        ]
        allow(Lich::Util).to receive(:issue_command).and_return(belt_contents)
        expect(described_class.check_belt_for_pouch?('large', 'pouch')).to be true
        expect(described_class.check_belt_for_pouch?('fuzzy', 'pouch')).to be false
      end
    end

    it 'calls issue_command with correct parameters' do
      expect(Lich::Util).to receive(:issue_command).with(
        'inv belt',
        described_class::INV_BELT_START_PATTERN,
        described_class::INV_BELT_END_PATTERN,
        timeout: 3,
        silent: true,
        quiet: true,
        usexml: false,
        include_end: false
      ).and_return([])
      described_class.check_belt_for_pouch?(adj, noun)
    end
  end

  describe '#tie_gem_pouch?' do
    let(:adj) { 'soft' }
    let(:noun) { 'pouch' }

    context 'when tie succeeds' do
      it 'returns true' do
        allow(described_class).to receive(:tie_item?).and_return(true)
        expect(described_class.tie_gem_pouch?(adj, noun)).to be true
      end
    end

    context 'when tie fails' do
      it 'returns false' do
        allow(described_class).to receive(:tie_item?).and_return(false)
        expect(described_class.tie_gem_pouch?(adj, noun)).to be false
      end
    end

    it 'delegates to tie_item? with combined name' do
      expect(described_class).to receive(:tie_item?).with('soft pouch').and_return(true)
      described_class.tie_gem_pouch?(adj, noun)
    end
  end

  describe '#tie_gem_pouch (deprecated)' do
    let(:adj) { 'soft' }
    let(:noun) { 'pouch' }

    context 'when tie succeeds' do
      it 'does not log error message' do
        allow(described_class).to receive(:tie_gem_pouch?).and_return(true)
        expect(Lich::Messaging).not_to receive(:msg)
        described_class.tie_gem_pouch(adj, noun)
      end
    end

    context 'when tie fails' do
      it 'logs error message' do
        allow(described_class).to receive(:tie_gem_pouch?).and_return(false)
        expect(Lich::Messaging).to receive(:msg).with('bold', /Failed to tie soft pouch/)
        described_class.tie_gem_pouch(adj, noun)
      end
    end

    it 'delegates to tie_gem_pouch?' do
      expect(described_class).to receive(:tie_gem_pouch?).with(adj, noun).and_return(true)
      described_class.tie_gem_pouch(adj, noun)
    end
  end

  describe '#remove_and_stow_pouch? (simplified)' do
    let(:adj) { 'soft' }
    let(:noun) { 'pouch' }

    context 'when remove fails' do
      it 'returns false and logs message' do
        allow(described_class).to receive(:remove_item?).and_return(false)
        expect(Lich::Messaging).to receive(:msg).with('bold', /Unable to remove existing pouch/)
        expect(described_class.remove_and_stow_pouch?(adj, noun)).to be false
      end
    end

    context 'when put_away succeeds' do
      it 'returns true' do
        allow(described_class).to receive(:remove_item?).and_return(true)
        allow(described_class).to receive(:put_away_item?).and_return(true)
        expect(described_class.remove_and_stow_pouch?(adj, noun, 'container')).to be true
      end

      it 'does not call stow_item?' do
        allow(described_class).to receive(:remove_item?).and_return(true)
        allow(described_class).to receive(:put_away_item?).and_return(true)
        expect(described_class).not_to receive(:stow_item?)
        described_class.remove_and_stow_pouch?(adj, noun, 'container')
      end
    end

    context 'when put_away fails but stow succeeds' do
      it 'returns true via || fallback' do
        allow(described_class).to receive(:remove_item?).and_return(true)
        allow(described_class).to receive(:put_away_item?).and_return(false)
        allow(described_class).to receive(:stow_item?).and_return(true)
        expect(described_class.remove_and_stow_pouch?(adj, noun, 'container')).to be true
      end
    end

    context 'when both put_away and stow fail' do
      it 'returns false' do
        allow(described_class).to receive(:remove_item?).and_return(true)
        allow(described_class).to receive(:put_away_item?).and_return(false)
        allow(described_class).to receive(:stow_item?).and_return(false)
        expect(described_class.remove_and_stow_pouch?(adj, noun, 'container')).to be false
      end
    end
  end

  describe '#swap_out_full_gempouch? (with belt check)' do
    let(:adj) { 'soft' }
    let(:noun) { 'pouch' }

    before do
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
      allow(described_class).to receive(:remove_and_stow_pouch?).and_return(true)
    end

    context 'when no free hand' do
      it 'returns false and logs message' do
        allow(DRC).to receive(:left_hand).and_return('sword')
        allow(DRC).to receive(:right_hand).and_return('shield')
        expect(Lich::Messaging).to receive(:msg).with('bold', /No free hand/)
        expect(described_class.swap_out_full_gempouch?(adj, noun)).to be false
      end
    end

    context 'when remove_and_stow fails' do
      it 'returns false and logs message' do
        allow(described_class).to receive(:remove_and_stow_pouch?).and_return(false)
        expect(Lich::Messaging).to receive(:msg).with('bold', /Remove and stow pouch routine failed/)
        expect(described_class.swap_out_full_gempouch?(adj, noun)).to be false
      end
    end

    context 'when pouch found on belt' do
      before do
        allow(described_class).to receive(:check_belt_for_pouch?).and_return(true)
      end

      it 'logs informational message about using belt pouch' do
        allow(described_class).to receive(:untie_item?).and_return(true)
        allow(described_class).to receive(:wear_item?).and_return(true)
        expect(Lich::Messaging).to receive(:msg).with('plain', /Found existing.*on belt/)
        described_class.swap_out_full_gempouch?(adj, noun, nil, 'spare_container')
      end

      it 'unties the belt pouch' do
        allow(described_class).to receive(:wear_item?).and_return(true)
        expect(described_class).to receive(:untie_item?).with("#{adj} #{noun}").and_return(true)
        described_class.swap_out_full_gempouch?(adj, noun, nil, 'spare_container')
      end

      context 'when untie fails' do
        it 'returns false and logs message' do
          allow(described_class).to receive(:untie_item?).and_return(false)
          # First logs plain "Found existing..." then bold "Could not untie..."
          allow(Lich::Messaging).to receive(:msg).with('plain', /Found existing/)
          expect(Lich::Messaging).to receive(:msg).with('bold', /Could not untie existing pouch/)
          expect(described_class.swap_out_full_gempouch?(adj, noun, nil, 'spare_container')).to be false
        end
      end

      it 'does not call get_item?' do
        allow(described_class).to receive(:untie_item?).and_return(true)
        allow(described_class).to receive(:wear_item?).and_return(true)
        expect(described_class).not_to receive(:get_item?)
        described_class.swap_out_full_gempouch?(adj, noun, nil, 'spare_container')
      end
    end

    context 'when no pouch on belt' do
      before do
        allow(described_class).to receive(:check_belt_for_pouch?).and_return(false)
      end

      it 'gets pouch from spare container' do
        allow(described_class).to receive(:wear_item?).and_return(true)
        expect(described_class).to receive(:get_item?).with("#{adj} #{noun}", 'spare_container').and_return(true)
        described_class.swap_out_full_gempouch?(adj, noun, nil, 'spare_container')
      end

      context 'when get_item fails' do
        it 'returns false and logs message' do
          allow(described_class).to receive(:get_item?).and_return(false)
          expect(Lich::Messaging).to receive(:msg).with('bold', /No spare pouch found/)
          expect(described_class.swap_out_full_gempouch?(adj, noun, nil, 'spare_container')).to be false
        end
      end
    end

    context 'when wear fails' do
      it 'returns false and logs message' do
        allow(described_class).to receive(:check_belt_for_pouch?).and_return(false)
        allow(described_class).to receive(:get_item?).and_return(true)
        allow(described_class).to receive(:wear_item?).and_return(false)
        expect(Lich::Messaging).to receive(:msg).with('bold', /Could not wear new pouch/)
        expect(described_class.swap_out_full_gempouch?(adj, noun, nil, 'spare_container')).to be false
      end
    end

    context 'when should_tie_gem_pouches is true' do
      before do
        allow(described_class).to receive(:check_belt_for_pouch?).and_return(false)
        allow(described_class).to receive(:get_item?).and_return(true)
        allow(described_class).to receive(:wear_item?).and_return(true)
      end

      context 'when tie succeeds' do
        it 'returns true' do
          allow(described_class).to receive(:tie_gem_pouch?).and_return(true)
          expect(described_class.swap_out_full_gempouch?(adj, noun, nil, 'spare', true)).to be true
        end
      end

      context 'when tie fails' do
        it 'logs warning but still returns true (pouch is worn)' do
          allow(described_class).to receive(:tie_gem_pouch?).and_return(false)
          expect(Lich::Messaging).to receive(:msg).with('bold', /Could not tie new pouch/)
          expect(described_class.swap_out_full_gempouch?(adj, noun, nil, 'spare', true)).to be true
        end
      end
    end

    context 'when should_tie_gem_pouches is false' do
      it 'does not call tie_gem_pouch?' do
        allow(described_class).to receive(:check_belt_for_pouch?).and_return(false)
        allow(described_class).to receive(:get_item?).and_return(true)
        allow(described_class).to receive(:wear_item?).and_return(true)
        expect(described_class).not_to receive(:tie_gem_pouch?)
        described_class.swap_out_full_gempouch?(adj, noun, nil, 'spare', false)
      end
    end
  end

  describe '#fill_gem_pouch_with_container (with constants and proper returns)' do
    let(:adj) { 'soft' }
    let(:noun) { 'pouch' }
    let(:source) { 'sack' }

    before do
      allow(Flags).to receive(:add)
      allow(Flags).to receive(:delete)
      allow(Flags).to receive(:reset)
      allow(Flags).to receive(:[]).and_return(false)
    end

    it 'adds flag with FILL_POUCH_FULL_PATTERN constant' do
      stub_bput('You fill your pouch.')
      expect(Flags).to receive(:add).with('pouch-full', described_class::FILL_POUCH_FULL_PATTERN)
      described_class.fill_gem_pouch_with_container(adj, noun, source)
    end

    it 'always deletes flag in ensure block' do
      allow(DRC).to receive(:bput).and_raise(StandardError)
      expect(Flags).to receive(:delete).with('pouch-full')
      expect { described_class.fill_gem_pouch_with_container(adj, noun, source) }.to raise_error(StandardError)
    end

    context 'when container not found' do
      it 'logs message and returns early' do
        stub_bput('Please rephrase that command')
        expect(Lich::Messaging).to receive(:msg).with('bold', /Fill failed/)
        described_class.fill_gem_pouch_with_container(adj, noun, source)
      end
    end

    context 'when no gems in container' do
      it 'completes successfully (empty source is valid)' do
        stub_bput("There aren't any gems")
        expect(Lich::Messaging).not_to receive(:msg).with('bold', /Fill failed/)
        described_class.fill_gem_pouch_with_container(adj, noun, source)
      end
    end

    context 'when pouch needs to be tied (should_tie_gem_pouches=true)' do
      it 'ties pouch and recursively retries' do
        # First call returns needs tie, second call succeeds
        # tie_gem_pouch? called twice: once when needs tie, once after successful fill
        call_count = 0
        allow(DRC).to receive(:bput) do
          call_count += 1
          call_count == 1 ? "You'd better tie it up before putting" : 'You fill your pouch.'
        end
        expect(described_class).to receive(:tie_gem_pouch?).with(adj, noun).at_least(:once).and_return(true)
        described_class.fill_gem_pouch_with_container(adj, noun, source, nil, nil, true)
      end
    end

    context 'when pouch needs to be tied (should_tie_gem_pouches=false)' do
      it 'swaps out the pouch instead' do
        call_count = 0
        allow(DRC).to receive(:bput) do
          call_count += 1
          call_count == 1 ? "You'd better tie it up before putting" : 'You fill your pouch.'
        end
        expect(described_class).to receive(:swap_out_full_gempouch?).and_return(true)
        described_class.fill_gem_pouch_with_container(adj, noun, source, nil, 'spare', false)
      end

      it 'logs and returns if swap fails' do
        stub_bput("You'd better tie it up before putting")
        allow(described_class).to receive(:swap_out_full_gempouch?).and_return(false)
        expect(Lich::Messaging).to receive(:msg).with('bold', /Could not swap gem pouches/)
        described_class.fill_gem_pouch_with_container(adj, noun, source, nil, 'spare', false)
      end
    end

    context 'when pouch is full (direct match)' do
      it 'swaps out the pouch and recursively retries' do
        call_count = 0
        allow(DRC).to receive(:bput) do
          call_count += 1
          call_count == 1 ? 'is too full to fit' : 'You fill your pouch.'
        end
        expect(described_class).to receive(:swap_out_full_gempouch?).and_return(true)
        described_class.fill_gem_pouch_with_container(adj, noun, source, nil, 'spare', false)
      end
    end

    context 'when pouch fills up mid-operation (flag set)' do
      it 'resets flag, swaps pouch, and retries' do
        # First call succeeds but flag is set, second call succeeds
        call_count = 0
        allow(DRC).to receive(:bput) do
          call_count += 1
          'You fill your pouch.'
        end
        allow(Flags).to receive(:[]).with('pouch-full').and_return(true, false)
        expect(Flags).to receive(:reset).with('pouch-full')
        expect(described_class).to receive(:swap_out_full_gempouch?).and_return(true)
        described_class.fill_gem_pouch_with_container(adj, noun, source, nil, 'spare', false)
      end
    end

    context 'when fill succeeds' do
      before { stub_bput('You fill your pouch.') }

      it 'ties pouch if should_tie_gem_pouches is true' do
        expect(described_class).to receive(:tie_gem_pouch?).with(adj, noun)
        described_class.fill_gem_pouch_with_container(adj, noun, source, nil, nil, true)
      end

      it 'does not tie pouch if should_tie_gem_pouches is false' do
        expect(described_class).not_to receive(:tie_gem_pouch?)
        described_class.fill_gem_pouch_with_container(adj, noun, source, nil, nil, false)
      end
    end
  end
end
