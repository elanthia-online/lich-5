# frozen_string_literal: true

require 'ostruct'

# Mock modules/classes at top level first, then alias into namespace
# This ensures expect() targets the same object the module code calls

module Lich
  module Messaging
    def self.msg(*_args); end
  end unless defined?(Lich::Messaging)

  module Util
    def self.issue_command(*_args); end
  end unless defined?(Lich::Util)
end

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

module DRRoom
  def self.room_objs
    []
  end
end unless defined?(DRRoom)

class Room
  def self.current
    OpenStruct.new(tags: [])
  end
end unless defined?(Room)

module XMLData
  def self.room_title
    ''
  end
end unless defined?(XMLData)

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

# Kernel-level methods that module_function code calls as bare methods
module Kernel
  def waitrt?; end

  def reget(*_args)
    []
  end
end unless Kernel.private_method_defined?(:waitrt?)

# Global ordinals constant
$ORDINALS = %w[first second third fourth fifth sixth seventh eighth ninth tenth] unless defined?($ORDINALS)

require_relative '../../../../lib/dragonrealms/commons/common-items'

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
      expect(DRC).to receive(:bput).with('tap my gem from pouch', any_args).and_return('You tap a gem.')
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
        allow(described_class).to receive(:get_item?).and_return(false)
        expect(Lich::Messaging).to receive(:msg).with('bold', /No spare pouch found/)
        expect(described_class.swap_out_full_gempouch?(adj, noun)).to be false
      end
    end

    context 'when wear fails' do
      it 'returns false and logs message' do
        allow(described_class).to receive(:remove_and_stow_pouch?).and_return(true)
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
        expect(Lich::Messaging).to receive(:msg).with('bold', /Container .* not found/)
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
end
