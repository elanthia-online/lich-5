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

# ── Mock DRC ──────────────────────────────────────────────────────────
# Define at top level first, then alias into Lich::DragonRealms so code
# inside the namespace resolves correctly.
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

  def self.retreat(_ignored = []); end
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

  def self.put_away_item_unsafe?(_item, _container = nil, _preposition = 'in')
    true
  end

  def self.dispose_trash(_item, _container = nil, _verb = nil); end
end unless defined?(DRCI)

Lich::DragonRealms::DRCI = DRCI unless defined?(Lich::DragonRealms::DRCI)

# ── Mock DRRoom ───────────────────────────────────────────────────────
module DRRoom
  def self.npcs
    []
  end

  def self.pcs
    []
  end

  def self.group_members
    []
  end
end unless defined?(DRRoom)

Lich::DragonRealms::DRRoom = DRRoom unless defined?(Lich::DragonRealms::DRRoom)

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

# ── Mock DRCA ─────────────────────────────────────────────────────────
module DRCA
  def self.perc_mana
    0
  end
end unless defined?(DRCA)

Lich::DragonRealms::DRCA = DRCA unless defined?(Lich::DragonRealms::DRCA)

# Mock Room for walk_to
class Room
  class << self
    def current
      @current ||= OpenStruct.new(id: 1, dijkstra: [nil, {}])
    end

    def current=(room)
      @current = room
    end
  end
end unless defined?(Room)

# Mock Map
class Map
  class << self
    def list
      []
    end

    def dijkstra(_id, _target = nil)
      [nil, {}]
    end

    def findpath(_room, _target)
      []
    end

    def [](_id)
      nil
    end
  end
end unless defined?(Map)

# Mock XMLData — use define_singleton_method to work with both module and OpenStruct
module XMLData; end unless defined?(XMLData)
XMLData.define_singleton_method(:room_description) { '' } unless XMLData.respond_to?(:room_description)
XMLData.define_singleton_method(:room_title) { '' } unless XMLData.respond_to?(:room_title)
XMLData.define_singleton_method(:room_exits) { [] } unless XMLData.respond_to?(:room_exits)

# Mock UserVars
module UserVars
  @friends ||= []
  @hunting_nemesis ||= []

  class << self
    attr_accessor :friends, :hunting_nemesis
  end
end unless defined?(UserVars)

# Mock Flags
module Flags
  class << self
    def add(_name, *_patterns); end

    def delete(_name); end

    def reset(_name); end

    def [](_name); end
  end
end unless defined?(Flags)

# Mock Script
class Script
  class << self
    def running
      []
    end

    def running?(_name)
      false
    end
  end
end unless defined?(Script)

# Mock StringProc for walk_to unknown room path
class StringProc
  def call; end
end unless defined?(StringProc)

# Stub game helper methods
module Kernel
  def pause(_seconds = nil); end

  def waitrt?; end

  def echo(_msg); end

  def fput(_cmd); end

  def move(_dir); end

  def start_script(_name, _args = [], **_opts)
    Object.new
  end

  def kill_script(_handle); end

  # Note: get_data is provided by spec_helper.rb — do not redefine here
end

# Load the module under test
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-travel.rb')

DRCT = Lich::DragonRealms::DRCT unless defined?(DRCT)

RSpec.describe DRCT do
  before(:each) do
    Lich::Messaging.clear_messages!
    allow(Room).to receive(:current).and_return(OpenStruct.new(id: 19_073, dijkstra: [nil, {}]))
  end

  # ─── Constants ─────────────────────────────────────────────────────

  describe 'constants' do
    it 'DIRECTION_REVERSE is frozen' do
      expect(DRCT::DIRECTION_REVERSE).to be_frozen
    end

    it 'DIRECTION_REVERSE contains all 10 direction pairs' do
      expect(DRCT::DIRECTION_REVERSE.size).to eq(10)
    end

    it 'DIRECTION_REVERSE is symmetric' do
      DRCT::DIRECTION_REVERSE.each do |dir, rev|
        expect(DRCT::DIRECTION_REVERSE[rev]).to eq(dir)
      end
    end

    it 'SELL_SUCCESS_PATTERNS is frozen' do
      expect(DRCT::SELL_SUCCESS_PATTERNS).to be_frozen
    end

    it 'SELL_FAILURE_PATTERNS is frozen' do
      expect(DRCT::SELL_FAILURE_PATTERNS).to be_frozen
    end

    it 'BUY_PRICE_PATTERNS is frozen' do
      expect(DRCT::BUY_PRICE_PATTERNS).to be_frozen
    end

    it 'BUY_PRICE_PATTERNS all use named capture :amount' do
      DRCT::BUY_PRICE_PATTERNS.each do |pattern|
        expect(pattern.named_captures).to include('amount')
      end
    end

    it 'BUY_NON_PRICE_PATTERNS is frozen' do
      expect(DRCT::BUY_NON_PRICE_PATTERNS).to be_frozen
    end

    it 'ASK_SUCCESS_PATTERNS is frozen' do
      expect(DRCT::ASK_SUCCESS_PATTERNS).to be_frozen
    end

    it 'ASK_FAILURE_PATTERNS is frozen' do
      expect(DRCT::ASK_FAILURE_PATTERNS).to be_frozen
    end
  end

  # ─── sell_item ─────────────────────────────────────────────────────

  describe '.sell_item' do
    before(:each) do
      allow(DRCT).to receive(:walk_to).and_return(true)
    end

    it 'returns false if item not in hands' do
      allow(DRCI).to receive(:in_hands?).with('sword').and_return(false)
      expect(DRCT.sell_item(100, 'sword')).to eq(false)
    end

    it 'does not walk_to if item not in hands' do
      allow(DRCI).to receive(:in_hands?).with('sword').and_return(false)
      expect(DRCT).not_to receive(:walk_to)
      DRCT.sell_item(100, 'sword')
    end

    it 'returns true when merchant accepts the item' do
      allow(DRCI).to receive(:in_hands?).with('sword').and_return(true)
      allow(DRC).to receive(:bput).and_return('hands you 50 kronars')
      expect(DRCT.sell_item(100, 'sword')).to eq(true)
    end

    it 'returns false when merchant rejects the item' do
      allow(DRCI).to receive(:in_hands?).with('sword').and_return(true)
      allow(DRC).to receive(:bput).and_return("That's not worth anything")
      expect(DRCT.sell_item(100, 'sword')).to eq(false)
    end

    it 'returns false for pelt-only merchant' do
      allow(DRCI).to receive(:in_hands?).with('sword').and_return(true)
      allow(DRC).to receive(:bput).and_return('I only deal in pelts')
      expect(DRCT.sell_item(100, 'sword')).to eq(false)
    end
  end

  # ─── buy_item ──────────────────────────────────────────────────────

  describe '.buy_item' do
    before(:each) do
      allow(DRCT).to receive(:walk_to).and_return(true)
    end

    it 'extracts amount from "prepared to offer" pattern and calls fput offer' do
      allow(DRC).to receive(:bput).and_return('prepared to offer it to you for 500 kronars')
      expect(DRCT).to receive(:fput).with('offer 500')
      DRCT.buy_item(100, 'arrow')
    end

    it 'extracts amount from "humble sum" pattern' do
      allow(DRC).to receive(:bput).and_return('Let me but ask the humble sum of 250 coins')
      expect(DRCT).to receive(:fput).with('offer 250')
      DRCT.buy_item(100, 'bolt')
    end

    it 'extracts amount from "it would be just" pattern' do
      allow(DRC).to receive(:bput).and_return('it would be just 100 lirums')
      expect(DRCT).to receive(:fput).with('offer 100')
      DRCT.buy_item(100, 'rope')
    end

    it 'extracts amount from "cost you just" pattern' do
      allow(DRC).to receive(:bput).and_return('cost you just 75 dokoras')
      expect(DRCT).to receive(:fput).with('offer 75')
      DRCT.buy_item(100, 'pouch')
    end

    it 'extracts amount from "copper kronars" pattern' do
      allow(DRC).to receive(:bput).and_return('That will be 300 copper kronars please')
      expect(DRCT).to receive(:fput).with('offer 300')
      DRCT.buy_item(100, 'lockpick')
    end

    it 'does not call fput when "You decide to purchase"' do
      allow(DRC).to receive(:bput).and_return('You decide to purchase')
      expect(DRCT).not_to receive(:fput)
      DRCT.buy_item(100, 'something')
    end

    it 'does not call fput when "Buy what"' do
      allow(DRC).to receive(:bput).and_return('Buy what')
      expect(DRCT).not_to receive(:fput)
      DRCT.buy_item(100, 'nothing')
    end

    it 'does not call fput when bput returns nil' do
      allow(DRC).to receive(:bput).and_return(nil)
      expect(DRCT).not_to receive(:fput)
      DRCT.buy_item(100, 'item')
    end
  end

  # ─── ask_for_item? ─────────────────────────────────────────────────

  describe '.ask_for_item?' do
    before(:each) do
      allow(DRCT).to receive(:walk_to).and_return(true)
    end

    it 'returns true when merchant hands you the item' do
      allow(DRC).to receive(:bput).and_return('hands you a bundle of rope')
      expect(DRCT.ask_for_item?(100, 'merchant', 'rope')).to eq(true)
    end

    it 'returns false when merchant does not know about item' do
      allow(DRC).to receive(:bput).and_return('does not seem to know anything about that')
      expect(DRCT.ask_for_item?(100, 'merchant', 'widget')).to eq(false)
    end

    it 'returns false when no one to speak to' do
      allow(DRC).to receive(:bput).and_return('To whom are you speaking')
      expect(DRCT.ask_for_item?(100, 'nobody', 'rope')).to eq(false)
    end

    it 'returns false for "All I know about"' do
      allow(DRC).to receive(:bput).and_return('All I know about that is...')
      expect(DRCT.ask_for_item?(100, 'merchant', 'rope')).to eq(false)
    end
  end

  # ─── order_item ────────────────────────────────────────────────────

  describe '.order_item' do
    before(:each) do
      allow(DRCT).to receive(:walk_to).and_return(true)
    end

    it 'returns early when not enough coins' do
      allow(DRC).to receive(:bput).and_return("you don't have enough coins")
      expect(DRC).to receive(:bput).once
      DRCT.order_item(100, 5)
    end

    it 'orders twice on "Just order it again"' do
      allow(DRC).to receive(:bput).and_return('Just order it again', 'takes some coins from you')
      expect(DRC).to receive(:bput).twice
      DRCT.order_item(100, 5)
    end
  end

  # ─── dispose ───────────────────────────────────────────────────────

  describe '.dispose' do
    it 'returns immediately when item is nil' do
      expect(DRCT).not_to receive(:walk_to)
      expect(DRCI).not_to receive(:dispose_trash)
      DRCT.dispose(nil)
    end

    it 'walks to trash room and disposes when room provided' do
      expect(DRCT).to receive(:walk_to).with(200)
      expect(DRCI).to receive(:dispose_trash).with('junk', nil, nil)
      DRCT.dispose('junk', 200)
    end

    it 'skips walk_to when no trash room provided' do
      expect(DRCT).not_to receive(:walk_to)
      expect(DRCI).to receive(:dispose_trash).with('junk', nil, nil)
      DRCT.dispose('junk')
    end

    it 'passes worn trashcan and verb to dispose_trash' do
      allow(DRCT).to receive(:walk_to)
      expect(DRCI).to receive(:dispose_trash).with('junk', 'bin', 'push')
      DRCT.dispose('junk', 200, 'bin', 'push')
    end
  end

  # ─── refill_lockpick_container ─────────────────────────────────────

  describe '.refill_lockpick_container' do
    let(:lockpick_type) { 'steel' }
    let(:hometown) { 'Crossing' }
    let(:container) { 'lockpick ring' }
    let(:town_data) { { 'Crossing' => { 'locksmithing' => { 'id' => 19_073 } } } }

    before(:each) do
      # Stub get_data to return proper town data (get_data is a Kernel function from dependency.lic)
      allow_any_instance_of(Object).to receive(:get_data).with('town').and_return(town_data)
      allow(DRCT).to receive(:walk_to).and_return(true)
      allow(DRCT).to receive(:buy_item)
      allow(DRC).to receive(:fix_standing)
      allow(XMLData).to receive(:room_exits).and_return([])
    end

    it 'returns immediately when count is 0' do
      expect(DRCI).not_to receive(:put_away_item_unsafe?)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 0)
    end

    it 'calls DRCI.put_away_item_unsafe? with on preposition' do
      expect(DRCI).to receive(:put_away_item_unsafe?)
        .with('my lockpick', 'my lockpick ring', 'on')
        .and_return(true)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 1)
    end

    it 'buys and stores multiple lockpicks when count > 1' do
      expect(DRCT).to receive(:buy_item).exactly(3).times
      expect(DRCI).to receive(:put_away_item_unsafe?)
        .with('my lockpick', 'my lockpick ring', 'on')
        .exactly(3).times
        .and_return(true)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 3)
    end

    it 'breaks and logs error when put_away_item_unsafe? returns false' do
      expect(DRCI).to receive(:put_away_item_unsafe?)
        .with('my lockpick', 'my lockpick ring', 'on')
        .and_return(false)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 3)

      expect(Lich::Messaging.messages.last[:type]).to eq('bold')
      expect(Lich::Messaging.messages.last[:message]).to include('DRCT:')
      expect(Lich::Messaging.messages.last[:message]).to include('Failed to put lockpick')
    end

    it 'only buys one lockpick when first put fails' do
      expect(DRCT).to receive(:buy_item).once
      allow(DRCI).to receive(:put_away_item_unsafe?).and_return(false)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 5)
    end

    it 'logs error when no locksmith location found' do
      # Provide data where locksmithing id is explicitly nil
      nil_town_data = { 'Crossing' => { 'locksmithing' => { 'id' => nil } } }
      allow_any_instance_of(Object).to receive(:get_data).with('town').and_return(nil_town_data)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 1)

      expect(Lich::Messaging.messages.last[:message]).to include('No locksmith location')
    end

    it 'logs error and returns when could not reach locksmith' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 999))
      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 1)

      expect(Lich::Messaging.messages.last[:message]).to include('Could not reach locksmith')
    end

    it 'moves out if room has an out exit' do
      allow(DRCI).to receive(:put_away_item_unsafe?).and_return(true)
      allow(XMLData).to receive(:room_exits).and_return(['out', 'north'])
      expect(DRCT).to receive(:move).with('out')

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 1)
    end
  end

  # ─── walk_to ───────────────────────────────────────────────────────

  describe '.walk_to' do
    it 'returns false for nil target' do
      expect(DRCT.walk_to(nil)).to eq(false)
    end

    it 'returns true when already in target room' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      expect(DRCT.walk_to(100)).to eq(true)
    end

    it 'returns true when already in target room (string number)' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      expect(DRCT.walk_to('100')).to eq(true)
    end

    it 'delegates string tags to tag_to_id' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      expect(DRCT).to receive(:tag_to_id).with('bank').and_return(100)
      expect(DRCT.walk_to('bank')).to eq(true)
    end

    it 'returns false when tag_to_id returns nil' do
      allow(DRCT).to receive(:tag_to_id).and_return(nil)
      expect(DRCT.walk_to('nonexistent')).to eq(false)
    end

    it 'calls DRC.fix_standing before navigating' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      allow(DRC).to receive(:fix_standing)
      allow(Script).to receive(:running).and_return([])
      expect(DRC).to receive(:fix_standing)
      DRCT.walk_to(200, false)
    end

    it 'ensures flags are deleted even if an error occurs' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      allow(DRC).to receive(:fix_standing)
      allow(Script).to receive(:running).and_raise(RuntimeError, 'test error')

      expect(Flags).to receive(:delete).with('travel-closed-shop')
      expect(Flags).to receive(:delete).with('travel-engaged')

      expect { DRCT.walk_to(200) }.to raise_error(RuntimeError, 'test error')
    end

    it 'uses Lich::Messaging.msg instead of echo for failure' do
      call_count = 0
      allow(Room).to receive(:current) do
        call_count += 1
        # First walk_to call: 4 checks at id 100 (not target)
        # Recursive walk_to call: returns 200 (at target)
        OpenStruct.new(id: call_count <= 4 ? 100 : 200)
      end
      allow(DRC).to receive(:fix_standing)
      allow(Script).to receive(:running).and_return([])

      DRCT.walk_to(200, true)

      bold_msgs = Lich::Messaging.messages.select { |m| m[:type] == 'bold' }
      expect(bold_msgs.any? { |m| m[:message].include?('DRCT:') && m[:message].include?('Failed to navigate') }).to eq(true)
    end
  end

  # ─── tag_to_id ─────────────────────────────────────────────────────

  describe '.tag_to_id' do
    it 'returns nil and logs when no targets found' do
      allow(Map).to receive(:list).and_return([])
      result = DRCT.tag_to_id('bank')

      expect(result).to be_nil
      expect(Lich::Messaging.messages.last[:type]).to eq('bold')
      expect(Lich::Messaging.messages.last[:message]).to include("No go2 targets matching 'bank'")
    end

    it 'returns current room ID when already at target' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100, dijkstra: [nil, {}]))
      room_obj = OpenStruct.new(id: 100, tags: ['bank'])
      allow(Map).to receive(:list).and_return([room_obj])

      result = DRCT.tag_to_id('bank')
      expect(result).to eq(100)
    end

    it 'returns nearest room by dijkstra distance' do
      current = OpenStruct.new(id: 1)
      allow(current).to receive(:dijkstra).with([100, 200]).and_return([nil, { 100 => 5, 200 => 10 }])
      allow(Room).to receive(:current).and_return(current)
      room_a = OpenStruct.new(id: 100, tags: ['bank'])
      room_b = OpenStruct.new(id: 200, tags: ['bank'])
      allow(Map).to receive(:list).and_return([room_a, room_b])
      allow(Map).to receive(:[]).with(100).and_return(room_a)

      result = DRCT.tag_to_id('bank')
      expect(result).to eq(100)
    end

    it 'returns nil and logs when no path found to any target' do
      current = OpenStruct.new(id: 1)
      allow(current).to receive(:dijkstra).with([100]).and_return([nil, {}])
      allow(Room).to receive(:current).and_return(current)
      room_a = OpenStruct.new(id: 100, tags: ['bank'])
      allow(Map).to receive(:list).and_return([room_a])

      result = DRCT.tag_to_id('bank')
      expect(result).to be_nil
      expect(Lich::Messaging.messages.last[:message]).to include("Couldn't find a path")
    end

    it 'returns nil and logs when Map[] returns nil for target' do
      current = OpenStruct.new(id: 1)
      allow(current).to receive(:dijkstra).with([100]).and_return([nil, { 100 => 5 }])
      allow(Room).to receive(:current).and_return(current)
      room_a = OpenStruct.new(id: 100, tags: ['bank'])
      allow(Map).to receive(:list).and_return([room_a])
      allow(Map).to receive(:[]).with(100).and_return(nil)

      result = DRCT.tag_to_id('bank')
      expect(result).to be_nil
      expect(Lich::Messaging.messages.last[:message]).to include('Something went wrong')
    end

    it 'does not call exit (returns nil instead)' do
      allow(Map).to receive(:list).and_return([])
      # If exit were called, this would raise SystemExit
      result = DRCT.tag_to_id('bank')
      expect(result).to be_nil
    end
  end

  # ─── retreat ───────────────────────────────────────────────────────

  describe '.retreat' do
    it 'calls DRC.retreat when NPCs are present' do
      allow(DRRoom).to receive(:npcs).and_return(['goblin'])
      expect(DRC).to receive(:retreat).with([])
      DRCT.retreat
    end

    it 'skips retreat when no NPCs' do
      allow(DRRoom).to receive(:npcs).and_return([])
      expect(DRC).not_to receive(:retreat)
      DRCT.retreat
    end

    it 'skips retreat when all NPCs are ignored' do
      allow(DRRoom).to receive(:npcs).and_return(['rat'])
      expect(DRC).not_to receive(:retreat)
      DRCT.retreat(['rat'])
    end

    it 'retreats when some NPCs are not ignored' do
      allow(DRRoom).to receive(:npcs).and_return(['goblin', 'rat'])
      expect(DRC).to receive(:retreat).with(['rat'])
      DRCT.retreat(['rat'])
    end
  end

  # ─── reverse_path ──────────────────────────────────────────────────

  describe '.reverse_path' do
    it 'reverses a simple north-east path' do
      expect(DRCT.reverse_path(%w[north east])).to eq(%w[west south])
    end

    it 'reverses a single direction' do
      expect(DRCT.reverse_path(['up'])).to eq(['down'])
    end

    it 'reverses all diagonal directions' do
      path = %w[northeast northwest southeast southwest]
      expected = %w[northeast northwest southeast southwest]
      expect(DRCT.reverse_path(path)).to eq(expected)
    end

    it 'returns empty array for empty path' do
      expect(DRCT.reverse_path([])).to eq([])
    end

    it 'returns nil and logs error for unknown direction' do
      result = DRCT.reverse_path(%w[north ne])
      expect(result).to be_nil
      expect(Lich::Messaging.messages.last[:type]).to eq('bold')
      expect(Lich::Messaging.messages.last[:message]).to include("No reverse direction found for 'ne'")
    end

    it 'does not call exit for unknown direction' do
      # If exit were called, this would raise SystemExit
      result = DRCT.reverse_path(['baddir'])
      expect(result).to be_nil
    end

    it 'reverses a complex multi-step path' do
      path = %w[north north east south east up]
      expected = %w[down west north west south south]
      expect(DRCT.reverse_path(path)).to eq(expected)
    end
  end

  # ─── sort_destinations ─────────────────────────────────────────────

  describe '.sort_destinations' do
    it 'sorts rooms by shortest distance' do
      distances = { 100 => 5, 200 => 2, 300 => 8 }
      allow(Map).to receive(:dijkstra).and_return([nil, distances])
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 1))

      result = DRCT.sort_destinations([300, 100, 200])
      expect(result).to eq([200, 100, 300])
    end

    it 'removes unreachable rooms' do
      distances = { 100 => 5 }
      allow(Map).to receive(:dijkstra).and_return([nil, distances])
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 1))

      result = DRCT.sort_destinations([100, 200, 300])
      expect(result).to eq([100])
    end

    it 'converts string IDs to integers' do
      distances = { 100 => 5, 200 => 2 }
      allow(Map).to receive(:dijkstra).and_return([nil, distances])
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 1))

      result = DRCT.sort_destinations(%w[200 100])
      expect(result).to eq([200, 100])
    end

    it 'keeps current room even if nil in distances' do
      distances = {}
      allow(Map).to receive(:dijkstra).and_return([nil, distances])
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))

      result = DRCT.sort_destinations([100, 200])
      expect(result).to eq([100])
    end
  end

  # ─── time_to_room ──────────────────────────────────────────────────

  describe '.time_to_room' do
    it 'returns shortest distance between rooms' do
      allow(Map).to receive(:dijkstra).with(100, 200).and_return([nil, { 200 => 15 }])
      expect(DRCT.time_to_room(100, 200)).to eq(15)
    end

    it 'returns nil for unreachable destination' do
      allow(Map).to receive(:dijkstra).with(100, 999).and_return([nil, {}])
      expect(DRCT.time_to_room(100, 999)).to be_nil
    end
  end

  # ─── get_hometown_target_id ────────────────────────────────────────

  describe '.get_hometown_target_id' do
    it 'returns target ID on first attempt' do
      allow(DRCT).to receive(:get_data).with('town').and_return(
        { 'Crossing' => { 'locksmithing' => { 'id' => 19_073 } } }
      )
      expect(DRCT.get_hometown_target_id('Crossing', 'locksmithing')).to eq(19_073)
    end

    it 'retries and returns on second attempt' do
      call_count = 0
      allow(DRCT).to receive(:get_data).with('town') do
        call_count += 1
        if call_count == 1
          { 'Crossing' => {} }
        else
          { 'Crossing' => { 'locksmithing' => { 'id' => 19_073 } } }
        end
      end

      expect(DRCT.get_hometown_target_id('Crossing', 'locksmithing')).to eq(19_073)
    end

    it 'returns nil when target does not exist on both attempts' do
      allow(DRCT).to receive(:get_data).with('town').and_return(
        { 'Crossing' => {} }
      )
      expect(DRCT.get_hometown_target_id('Crossing', 'nonexistent')).to be_nil
    end
  end

  # ─── find_empty_room ───────────────────────────────────────────────

  describe '.find_empty_room' do
    before(:each) do
      allow(DRCT).to receive(:walk_to).and_return(true)
      allow(DRRoom).to receive(:pcs).and_return([])
      allow(DRRoom).to receive(:group_members).and_return([])
    end

    it 'returns true when empty room found (no other PCs)' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      result = DRCT.find_empty_room([100], nil)
      expect(result).to eq(true)
    end

    it 'returns true using predicate when provided' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      predicate = ->(_attempt) { true }
      result = DRCT.find_empty_room([100], nil, predicate)
      expect(result).to eq(true)
    end

    it 'skips rooms with non-group PCs' do
      allow(Room).to receive(:current).and_return(
        OpenStruct.new(id: 100),
        OpenStruct.new(id: 200)
      )
      allow(DRRoom).to receive(:pcs).and_return(['stranger'], [])
      allow(DRRoom).to receive(:group_members).and_return([])

      result = DRCT.find_empty_room([100, 200], nil)
      expect(result).to eq(true)
    end

    it 'returns false after max_search_attempts' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      allow(DRRoom).to receive(:pcs).and_return(['stranger'])

      result = DRCT.find_empty_room([100], nil, nil, 0, false, 1)
      expect(result).to eq(false)
    end

    it 'checks mana when min_mana > 0 for non-moon-mage/trader' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      allow(DRRoom).to receive(:pcs).and_return([])
      allow(DRStats).to receive(:moon_mage?).and_return(false)
      allow(DRStats).to receive(:trader?).and_return(false)
      allow(DRCA).to receive(:perc_mana).and_return(50)

      result = DRCT.find_empty_room([100], nil, nil, 30)
      expect(result).to eq(true)
    end

    it 'skips mana check for moon mages' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      allow(DRRoom).to receive(:pcs).and_return([])
      allow(DRStats).to receive(:moon_mage?).and_return(true)

      result = DRCT.find_empty_room([100], nil, nil, 100)
      expect(result).to eq(true)
    end

    it 'skips mana check for traders' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      allow(DRRoom).to receive(:pcs).and_return([])
      allow(DRStats).to receive(:trader?).and_return(true)

      result = DRCT.find_empty_room([100], nil, nil, 100)
      expect(result).to eq(true)
    end

    it 'relaxes mana when strict_mana is false and empty rooms found' do
      call_count = 0
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 100))
      allow(DRRoom).to receive(:pcs).and_return([])
      allow(DRStats).to receive(:moon_mage?).and_return(false)
      allow(DRStats).to receive(:trader?).and_return(false)
      allow(DRCA).to receive(:perc_mana) do
        call_count += 1
        call_count <= 1 ? 10 : 10
      end

      result = DRCT.find_empty_room([100], nil, nil, 50, false, 2)
      expect(result).to eq(true)
      expect(Lich::Messaging.messages.any? { |m| m[:message].include?('not with the right mana') }).to eq(true)
    end
  end

  # ─── find_sorted_empty_room ────────────────────────────────────────

  describe '.find_sorted_empty_room' do
    it 'sorts rooms before searching' do
      distances = { 200 => 2, 100 => 5 }
      allow(Map).to receive(:dijkstra).and_return([nil, distances])
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 1))
      allow(DRCT).to receive(:find_empty_room) do |rooms, _idle, _pred|
        expect(rooms).to eq([200, 100])
        true
      end

      DRCT.find_sorted_empty_room([100, 200], nil)
    end
  end
end
