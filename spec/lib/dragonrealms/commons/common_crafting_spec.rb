# frozen_string_literal: true

require 'rspec'
require 'ostruct'

# Setup load path (standalone spec, no spec_helper dependency)
LIB_DIR = File.join(File.expand_path('../../../..', __dir__), 'lib') unless defined?(LIB_DIR)
$LOAD_PATH.unshift(LIB_DIR) unless $LOAD_PATH.include?(LIB_DIR)

# Ensure Lich::DragonRealms namespace exists
module Lich
  module DragonRealms; end
  module Messaging
    def self.msg(*_args); end
  end unless defined?(Lich::Messaging)
end

# Mock NilClass method_missing (matches Lich runtime behavior)
class NilClass
  def method_missing(*)
    nil
  end
end

# Mock dependencies — define at top level, then alias into namespace
# so that code inside Lich::DragonRealms and specs target the same object.
module DRC
  def self.bput(*_args)
    nil
  end

  def self.beep; end

  def self.get_noun(*_args)
    nil
  end

  def self.right_hand
    nil
  end

  def self.left_hand
    nil
  end

  def self.wait_for_script_to_complete(*_args); end
end unless defined?(DRC)

module DRCI
  def self.get_item?(*_args)
    true
  end

  def self.get_item_unsafe(*_args)
    true
  end

  def self.put_away_item?(*_args)
    true
  end

  def self.dispose_trash(*_args)
    nil
  end

  def self.in_hands?(*_args)
    false
  end

  def self.stow_hands(*_args)
    nil
  end

  def self.tie_item?(*_args)
    true
  end

  def self.untie_item?(*_args)
    true
  end

  def self.open_container?(*_args)
    true
  end

  def self.count_items_in_container(*_args)
    0
  end
end unless defined?(DRCI)

module DRCT
  def self.find_sorted_empty_room(*_args)
    nil
  end

  def self.walk_to(*_args)
    nil
  end

  def self.dispose(*_args)
    nil
  end

  def self.order_item(*_args)
    nil
  end
end unless defined?(DRCT)

module DRCM
  def self.town_currency(*_args)
    'kronars'
  end
end unless defined?(DRCM)

class DRRoom
  def self.pcs
    []
  end

  def self.group_members
    []
  end
end unless defined?(DRRoom)

class Room
  def self.current
    OpenStruct.new(id: 1)
  end
end unless defined?(Room)

class UserVars
  class << self
    attr_accessor :immune_list
  end
end unless defined?(UserVars)

class Flags
  @flags = {}

  def self.[](name)
    @flags[name]
  end

  def self.add(name, *_patterns)
    @flags[name] = nil
  end

  def self.reset(name)
    @flags[name] = nil
  end

  def self.delete(name)
    @flags.delete(name)
  end
end unless defined?(Flags)

# Mock global variables used by the module
$PRIMARY_SIGILS_PATTERN = /primary/ unless defined?($PRIMARY_SIGILS_PATTERN)
$SECONDARY_SIGILS_PATTERN = /secondary/ unless defined?($SECONDARY_SIGILS_PATTERN)
$VOL_MAP = { 'tiny' => 1, 'small' => 2, 'medium' => 5, 'large' => 10 }.freeze unless defined?($VOL_MAP)
$clean_lich_char = ';' unless defined?($clean_lich_char)

# Namespace aliases — MUST be BEFORE require so code resolves correctly.
module Lich
  module DragonRealms
    DRC = ::DRC unless defined?(Lich::DragonRealms::DRC)
    DRCI = ::DRCI unless defined?(Lich::DragonRealms::DRCI)
    DRCT = ::DRCT unless defined?(Lich::DragonRealms::DRCT)
    DRCM = ::DRCM unless defined?(Lich::DragonRealms::DRCM)
    DRRoom = ::DRRoom unless defined?(Lich::DragonRealms::DRRoom)
  end
end

# Mock Kernel methods used by module_function code
module Kernel
  def get_data(*)
    {
      'blacksmithing' => {
        'Crossing' => {
          'crucibles'   => [1, 2],
          'anvils'      => [3, 4],
          'grindstones' => [5, 6],
          'idle-room'   => 10
        }
      },
      'tailoring'     => {
        'Crossing' => {
          'spinning-rooms' => [7, 8],
          'sewing-rooms'   => [9, 10],
          'loom-rooms'     => [11, 12],
          'idle-room'      => 20
        }
      },
      'shaping'       => {
        'Crossing' => {
          'shaping-rooms' => [13, 14],
          'idle-room'     => 30
        }
      },
      'remedies'      => {
        'Crossing' => {
          'press-grinder-rooms' => [15, 16]
        }
      },
      'artificing'    => {
        'Crossing' => {
          'brazier-rooms' => [17, 18],
          'idle-room'     => 40
        }
      },
      'stock'         => {
        'bronze'  => { 'stock-value' => 100 },
        'leather' => { 'stock-value' => 50 }
      }
    }
  end

  def waitrt?; end
  def pause(*_args); end
  def fput(*_args); end
  def respond(*_args); end
  def get; 'input' end

  private :get_data, :waitrt?, :pause, :fput, :respond, :get
end

require 'dragonrealms/commons/common-crafting'

RSpec.describe Lich::DragonRealms::DRCC do
  # Use described_class throughout to ensure we target the real module

  describe 'constants' do
    it 'defines frozen pattern constants' do
      expect(described_class::LOOK_CRUCIBLE_NOT_FOUND).to eq('^I could not find')
      expect(described_class::LOOK_CRUCIBLE_EMPTY).to eq('^There is nothing in there')
      expect(described_class::LOOK_CRUCIBLE_SEE_PATTERN).to be_frozen
      expect(described_class::PARTS_CANNOT_PURCHASE).to be_frozen
      expect(described_class::COUNT_USES_MESSAGES).to be_frozen
    end

    it 'PARTS_CANNOT_PURCHASE contains expected items' do
      expect(described_class::PARTS_CANNOT_PURCHASE).to include('sufil', 'gem', 'ingot')
    end

    it 'defines all bundle patterns' do
      expect(described_class::BUNDLE_SUCCESS).to eq('You notate the')
      expect(described_class::BUNDLE_EXPIRED).to eq('This work order has expired')
      expect(described_class::BUNDLE_QUALITY).to eq('The work order requires items of a higher quality')
      expect(described_class::BUNDLE_WRONG_TYPE).to eq("That isn't the correct type of item for this work order.")
      expect(described_class::BUNDLE_NOT_HOLDING).to eq('You need to be holding')
    end

    it 'defines all repair patterns' do
      expect(described_class::REPAIR_SUCCESS).to eq('Roundtime')
      expect(described_class::REPAIR_NOT_NEEDED).to eq('not damaged enough')
      expect(described_class::REPAIR_ENGAGED).to eq('You cannot do that while engaged!')
    end
  end

  describe '.empty_crucible?' do
    before do
      allow(described_class).to receive(:fput)
    end

    it 'returns true when crucible is empty' do
      allow(DRC).to receive(:bput).and_return('There is nothing in there')
      expect(described_class.empty_crucible?).to be true
    end

    it 'returns false when crucible not found' do
      allow(DRC).to receive(:bput).and_return('I could not find')
      expect(described_class.empty_crucible?).to be false
    end

    it 'tilts crucible when molten metal present and recurses' do
      allow(DRC).to receive(:bput).and_return('crucible you see some molten', 'There is nothing in there')
      expect(described_class).to receive(:fput).with('tilt crucible').twice
      expect(described_class.empty_crucible?).to be true
    end

    it 'cleans out items in crucible and recurses' do
      allow(DRC).to receive(:bput).and_return('In the iron crucible you see some bronze.', 'There is nothing in there')
      allow(DRC).to receive(:get_noun).and_return('bronze')
      allow(DRCI).to receive(:get_item_unsafe)
      allow(DRCI).to receive(:dispose_trash)

      expect(DRCI).to receive(:get_item_unsafe).with('bronze', 'crucible')
      expect(DRCI).to receive(:dispose_trash).with('bronze')
      expect(described_class.empty_crucible?).to be true
    end
  end

  describe '.clean_anvil?' do
    before do
      allow(described_class).to receive(:fput)
      allow(described_class).to receive(:pause)
      allow(described_class).to receive(:waitrt?)
    end

    it 'returns true when anvil is clean' do
      allow(DRC).to receive(:bput).and_return('surface looks clean and ready')
      expect(described_class.clean_anvil?).to be true
    end

    it 'returns false when anvil not found' do
      allow(DRC).to receive(:bput).and_return('I could not find')
      expect(described_class.clean_anvil?).to be false
    end

    it 'cleans anvil with drag action' do
      allow(DRC).to receive(:bput).and_return('anvil you see some junk.', 'You drag the')
      expect(described_class).to receive(:fput).with('clean anvil')
      expect(described_class.clean_anvil?).to be true
    end

    it 'gets clutter when not yours' do
      allow(DRC).to receive(:bput).and_return('anvil you see some junk.', 'remove them yourself', 'is not yours')
      expect(described_class).to receive(:fput).with('clean anvil').twice
      expect(described_class.clean_anvil?).to be true
    end
  end

  describe '.find_wheel' do
    it 'finds spinning rooms for hometown' do
      expect(DRCT).to receive(:find_sorted_empty_room).with([7, 8], 20)
      described_class.find_wheel('Crossing')
    end
  end

  describe '.find_sewing_room' do
    it 'walks to override room when provided' do
      expect(DRCT).to receive(:walk_to).with(999)
      described_class.find_sewing_room('Crossing', 999)
    end

    it 'finds sewing rooms when no override' do
      expect(DRCT).to receive(:find_sorted_empty_room).with([9, 10], 20)
      described_class.find_sewing_room('Crossing')
    end
  end

  describe '.find_loom_room' do
    it 'walks to override room when provided' do
      expect(DRCT).to receive(:walk_to).with(888)
      described_class.find_loom_room('Crossing', 888)
    end

    it 'finds loom rooms when no override' do
      expect(DRCT).to receive(:find_sorted_empty_room).with([11, 12], 20)
      described_class.find_loom_room('Crossing')
    end
  end

  describe '.find_shaping_room' do
    it 'walks to override room when provided' do
      expect(DRCT).to receive(:walk_to).with(777)
      described_class.find_shaping_room('Crossing', 777)
    end

    it 'finds shaping rooms when no override' do
      expect(DRCT).to receive(:find_sorted_empty_room).with([13, 14], 30)
      described_class.find_shaping_room('Crossing')
    end
  end

  describe '.recipe_lookup' do
    let(:recipes) do
      [
        { 'name' => 'a metal pike' },
        { 'name' => 'a metal sword' },
        { 'name' => 'metal pike head' }
      ]
    end

    it 'returns nil and logs when no match found' do
      expect(Lich::Messaging).to receive(:msg).with('bold', /No recipe.*matches.*unknown/)
      result = described_class.recipe_lookup(recipes, 'unknown')
      expect(result).to be_nil
    end

    it 'returns recipe when exactly one match' do
      result = described_class.recipe_lookup(recipes, 'metal sword')
      expect(result['name']).to eq('a metal sword')
    end

    it 'returns exact match when found among multiple partial matches' do
      result = described_class.recipe_lookup(recipes, 'a metal pike')
      expect(result['name']).to eq('a metal pike')
    end
  end

  describe '.find_recipe' do
    before do
      allow(described_class).to receive(:fput)
    end

    it 'turns book to chapter and reads for page number' do
      allow(DRC).to receive(:bput).and_return('You turn', 'Page 5: a metal pike')

      result = described_class.find_recipe(3, 'metal pike')
      expect(result).to eq('5')
    end

    it 'handles distracted response with combat exit' do
      allow(DRC).to receive(:bput).and_return('You are too distracted to be doing that right now')
      expect(Lich::Messaging).to receive(:msg).with('bold', /Cannot turn book/)
      expect(described_class).to receive(:fput).with('look')
      expect(described_class).to receive(:fput).with('exit')

      described_class.find_recipe(3, 'metal pike')
    end
  end

  describe '.get_crafting_item' do
    let(:bag) { 'backpack' }
    let(:bag_items) { ['hammer'] }
    let(:belt) { { 'name' => 'toolbelt', 'items' => ['tongs'] } }

    before do
      allow(described_class).to receive(:waitrt?)
      allow(described_class).to receive(:pause)
    end

    it 'gets item from bag when in bag_items list' do
      expect(DRC).to receive(:bput).with('get my hammer from my backpack', anything, anything, anything, anything, anything, anything, anything).and_return('You get')
      described_class.get_crafting_item('hammer', bag, bag_items, nil)
    end

    it 'unties from belt when item is a belt item' do
      expect(DRC).to receive(:bput).with("untie my tongs from my toolbelt", anything, anything, anything, anything).and_return('You untie')
      described_class.get_crafting_item('tongs', bag, bag_items, belt)
    end

    it 'returns nil with skip_exit when item not found' do
      allow(DRC).to receive(:bput).and_return('What do you')
      allow(DRCI).to receive(:in_hands?).and_return(false)
      expect(Lich::Messaging).to receive(:msg).with('bold', /missing.*shovel/)

      result = described_class.get_crafting_item('shovel', bag, bag_items, nil, true)
      expect(result).to be_nil
    end

    it 'returns nil and logs when item missing and not skipping exit' do
      allow(DRC).to receive(:bput).and_return('What do you')
      allow(DRCI).to receive(:in_hands?).and_return(false)
      expect(Lich::Messaging).to receive(:msg).with('bold', /missing/).once
      expect(Lich::Messaging).to receive(:msg).with('bold', /Cannot continue/).once

      result = described_class.get_crafting_item('shovel', bag, bag_items, nil, false)
      expect(result).to be_nil
    end
  end

  describe '.stow_crafting_item' do
    let(:bag) { 'backpack' }
    let(:belt) { { 'name' => 'toolbelt', 'items' => ['tongs'] } }

    before do
      allow(described_class).to receive(:waitrt?)
      allow(described_class).to receive(:fput)
    end

    it 'returns nil immediately when name is nil' do
      result = described_class.stow_crafting_item(nil, bag, nil)
      expect(result).to be_nil
    end

    it 'ties belt item to belt using DRCI.tie_item?' do
      expect(DRCI).to receive(:tie_item?).with('tongs', 'toolbelt').and_return(true)
      result = described_class.stow_crafting_item('tongs', bag, belt)
      expect(result).to be true
    end

    it 'logs failure when tie fails' do
      # First call fails, second call succeeds (simulating recovery after safe-room)
      call_count = 0
      allow(DRCI).to receive(:tie_item?) do
        call_count += 1
        call_count > 1
      end
      allow(DRC).to receive(:wait_for_script_to_complete)
      allow(DRCT).to receive(:walk_to)

      expect(Lich::Messaging).to receive(:msg).with('bold', /Failed to tie/)

      described_class.stow_crafting_item('tongs', bag, belt)
    end

    it 'puts non-belt item in bag' do
      expect(DRC).to receive(:bput).with('put my hammer in my backpack', anything, anything, anything, anything, anything, anything, anything, anything).and_return('You put your')
      result = described_class.stow_crafting_item('hammer', bag, nil)
      expect(result).to be true
    end

    it 'uses fput stow when bag is too full' do
      allow(DRC).to receive(:bput).and_return("There's no room")
      expect(described_class).to receive(:fput).with('stow my hammer')
      described_class.stow_crafting_item('hammer', bag, nil)
    end
  end

  describe '.crafting_cost' do
    let(:recipe) { { 'volume' => 10 } }
    let(:material) { { 'stock-volume' => 5, 'stock-value' => 100, 'stock-name' => 'bronze' } }

    it 'calculates cost with material in kronars' do
      allow(DRCM).to receive(:town_currency).and_return('kronars')
      result = described_class.crafting_cost(recipe, 'Crossing', nil, 1, material)
      # 2 stock units * 100 + 1000 consumables = 1200
      expect(result).to eq(1200)
    end

    it 'converts to lirums' do
      allow(DRCM).to receive(:town_currency).and_return('lirums')
      result = described_class.crafting_cost(recipe, 'Crossing', nil, 1, material)
      expect(result).to eq((1200 * 0.8).ceil)
    end

    it 'converts to dokoras' do
      allow(DRCM).to receive(:town_currency).and_return('dokoras')
      result = described_class.crafting_cost(recipe, 'Crossing', nil, 1, material)
      expect(result).to eq((1200 * 0.7216).ceil)
    end

    it 'adds parts cost when parts provided' do
      allow(DRCM).to receive(:town_currency).and_return('kronars')
      parts = ['bronze', 'leather']
      # 200 base + 100 (bronze) + 50 (leather) + 1000 = 1350
      result = described_class.crafting_cost(recipe, 'Crossing', parts, 1, material)
      expect(result).to eq(1350)
    end

    it 'excludes non-purchasable parts' do
      allow(DRCM).to receive(:town_currency).and_return('kronars')
      parts = ['bronze', 'gem', 'ingot'] # gem and ingot are in PARTS_CANNOT_PURCHASE
      # 200 base + 100 (bronze) + 1000 = 1300
      result = described_class.crafting_cost(recipe, 'Crossing', parts, 1, material)
      expect(result).to eq(1300)
    end
  end

  describe '.check_consumables' do
    let(:bag) { 'backpack' }
    let(:bag_items) { ['oil'] }
    let(:belt) { nil }

    before do
      allow(DRCT).to receive(:walk_to)
      allow(described_class).to receive(:stow_crafting_item)
    end

    it 'orders new consumable when not found' do
      allow(DRC).to receive(:bput).and_return('What were')
      expect(DRCT).to receive(:order_item).with(123, 5)

      described_class.check_consumables('oil', 123, 5, bag, bag_items, belt)
    end

    it 'disposes and reorders when count is too low' do
      # First call: get succeeds, count is low -> dispose -> recurse
      # Second call (recursion): get fails -> order new
      call_count = 0
      allow(DRC).to receive(:bput) do |_cmd, *_patterns|
        call_count += 1
        case call_count
        when 1 then 'You get' # get consumable - success
        when 2 then 'The oil has 1 uses remaining' # count - too low
        when 3 then 'What were' # recursive get - not found, will order
        else 'done'
        end
      end

      expect(DRCT).to receive(:dispose).with('oil')
      expect(DRCT).to receive(:order_item).with(123, 5)

      described_class.check_consumables('oil', 123, 5, bag, bag_items, belt, 3)
    end

    it 'keeps consumable when count is sufficient' do
      allow(DRC).to receive(:bput).and_return('You get', 'The oil has 10 uses remaining')
      expect(DRCT).not_to receive(:dispose)
      expect(described_class).to receive(:stow_crafting_item).with('oil', bag, belt)

      described_class.check_consumables('oil', 123, 5, bag, bag_items, belt, 3)
    end
  end

  describe '.get_adjust_tongs?' do
    let(:bag) { 'backpack' }
    let(:bag_items) { ['tongs'] }
    let(:belt) { nil }

    before do
      allow(DRCI).to receive(:in_hands?).and_return(false)
      allow(described_class).to receive(:get_crafting_item)
      allow(described_class).to receive(:stow_crafting_item)
    end

    context 'when usage is shovel' do
      it 'returns true when already a shovel' do
        described_class.instance_variable_set(:@tongs_status, 'shovel')
        expect(described_class.get_adjust_tongs?('shovel', bag, bag_items, belt, true)).to be true
      end

      it 'returns false when not adjustable' do
        described_class.instance_variable_set(:@tongs_status, nil)
        expect(described_class.get_adjust_tongs?('shovel', bag, bag_items, belt, false)).to be false
      end

      it 'adjusts to shovel configuration when adjustable' do
        described_class.instance_variable_set(:@tongs_status, nil)
        allow(DRC).to receive(:bput).with('adjust my tongs', anything, anything, anything, anything).and_return('You lock the tongs')

        result = described_class.get_adjust_tongs?('shovel', bag, bag_items, belt, true)
        expect(result).to be true
        expect(described_class.instance_variable_get(:@tongs_status)).to eq('shovel')
      end

      it 'double-adjusts when wrong configuration' do
        described_class.instance_variable_set(:@tongs_status, nil)
        # First call returns wrong config, second call with single pattern returns success
        allow(DRC).to receive(:bput).with('adjust my tongs', anything, anything, anything, anything).and_return('With a yank you fold the shovel')
        allow(DRC).to receive(:bput).with('adjust my tongs', described_class::ADJUST_TONGS_SHOVEL).and_return('You lock the tongs')

        result = described_class.get_adjust_tongs?('shovel', bag, bag_items, belt, true)
        expect(result).to be true
      end
    end

    context 'when usage is tongs' do
      it 'returns true when already tongs' do
        described_class.instance_variable_set(:@tongs_status, 'tongs')
        expect(described_class.get_adjust_tongs?('tongs', bag, bag_items, belt, true)).to be true
      end

      it 'adjusts to tongs configuration' do
        described_class.instance_variable_set(:@tongs_status, nil)
        allow(DRC).to receive(:bput).with('adjust my tongs', anything, anything, anything, anything).and_return('With a yank you fold the shovel')

        result = described_class.get_adjust_tongs?('tongs', bag, bag_items, belt, true)
        expect(result).to be true
        expect(described_class.instance_variable_get(:@tongs_status)).to eq('tongs')
      end
    end

    context 'when usage is reset' do
      it 'resets status and adjusts to shovel' do
        described_class.instance_variable_set(:@tongs_status, 'tongs')
        allow(DRC).to receive(:bput).and_return('You lock the tongs')

        described_class.get_adjust_tongs?('reset shovel', bag, bag_items, belt)
        expect(described_class.instance_variable_get(:@tongs_status)).to eq('shovel')
      end
    end
  end

  describe '.logbook_item' do
    let(:logbook) { 'outfitting' }
    let(:noun) { 'rucksack' }
    let(:container) { 'duffel bag' }

    before do
      allow(DRCI).to receive(:get_item?).and_return(true)
      allow(DRCI).to receive(:put_away_item?).and_return(true)
      allow(DRCI).to receive(:dispose_trash)
    end

    context 'when bundle succeeds' do
      it 'gets logbook, bundles item, and puts logbook away' do
        allow(DRC).to receive(:bput).and_return('You notate the')

        expect(DRCI).to receive(:get_item?).with('outfitting logbook').ordered
        expect(DRC).to receive(:bput).with('bundle my rucksack with my logbook',
                                           described_class::BUNDLE_SUCCESS,
                                           described_class::BUNDLE_EXPIRED,
                                           described_class::BUNDLE_QUALITY,
                                           described_class::BUNDLE_WRONG_TYPE,
                                           described_class::BUNDLE_NOT_HOLDING).ordered
        expect(DRCI).to receive(:put_away_item?).with('outfitting logbook', 'duffel bag').and_return(true).ordered

        described_class.logbook_item(logbook, noun, container)
      end

      it 'does not dispose of the item' do
        allow(DRC).to receive(:bput).and_return('You notate the')

        expect(DRCI).not_to receive(:dispose_trash)

        described_class.logbook_item(logbook, noun, container)
      end
    end

    context 'when work order has expired' do
      it 'disposes the item' do
        allow(DRC).to receive(:bput).and_return('This work order has expired')

        expect(DRCI).to receive(:dispose_trash).with('rucksack')

        described_class.logbook_item(logbook, noun, container)
      end
    end

    context 'when item quality is too low' do
      it 'disposes the item' do
        allow(DRC).to receive(:bput).and_return('The work order requires items of a higher quality')

        expect(DRCI).to receive(:dispose_trash).with('rucksack')

        described_class.logbook_item(logbook, noun, container)
      end
    end

    context 'when item is wrong type' do
      it 'disposes the item' do
        allow(DRC).to receive(:bput).and_return("That isn't the correct type of item for this work order.")

        expect(DRCI).to receive(:dispose_trash).with('rucksack')

        described_class.logbook_item(logbook, noun, container)
      end
    end

    context 'when item is not in hand' do
      it 'retrieves the item from container and retries bundle' do
        allow(DRC).to receive(:bput).and_return('You need to be holding', 'You notate the')
        allow(DRCI).to receive(:get_item?).and_return(true)

        expect(DRCI).to receive(:get_item?).with('outfitting logbook').ordered
        expect(DRC).to receive(:bput).with('bundle my rucksack with my logbook',
                                           described_class::BUNDLE_SUCCESS,
                                           described_class::BUNDLE_EXPIRED,
                                           described_class::BUNDLE_QUALITY,
                                           described_class::BUNDLE_WRONG_TYPE,
                                           described_class::BUNDLE_NOT_HOLDING).and_return('You need to be holding').ordered
        expect(DRCI).to receive(:get_item?).with('rucksack', 'duffel bag').and_return(true).ordered
        expect(DRC).to receive(:bput).with('bundle my rucksack with my logbook',
                                           described_class::BUNDLE_SUCCESS,
                                           described_class::BUNDLE_EXPIRED,
                                           described_class::BUNDLE_QUALITY,
                                           described_class::BUNDLE_WRONG_TYPE).and_return('You notate the').ordered

        described_class.logbook_item(logbook, noun, container)
      end

      it 'does not retry bundle if item cannot be retrieved' do
        allow(DRC).to receive(:bput).and_return('You need to be holding')
        allow(DRCI).to receive(:get_item?).with('outfitting logbook').and_return(true)
        allow(DRCI).to receive(:get_item?).with('rucksack', 'duffel bag').and_return(false)

        expect(DRC).to receive(:bput).once

        described_class.logbook_item(logbook, noun, container)
      end

      it 'disposes item if retry bundle returns expired' do
        allow(DRCI).to receive(:get_item?).with('outfitting logbook').and_return(true)
        allow(DRCI).to receive(:get_item?).with('rucksack', 'duffel bag').and_return(true)
        allow(DRC).to receive(:bput)
          .with('bundle my rucksack with my logbook',
                described_class::BUNDLE_SUCCESS,
                described_class::BUNDLE_EXPIRED,
                described_class::BUNDLE_QUALITY,
                described_class::BUNDLE_WRONG_TYPE,
                described_class::BUNDLE_NOT_HOLDING)
          .and_return('You need to be holding')
        allow(DRC).to receive(:bput)
          .with('bundle my rucksack with my logbook',
                described_class::BUNDLE_SUCCESS,
                described_class::BUNDLE_EXPIRED,
                described_class::BUNDLE_QUALITY,
                described_class::BUNDLE_WRONG_TYPE)
          .and_return('This work order has expired')

        expect(DRCI).to receive(:dispose_trash).with('rucksack')

        described_class.logbook_item(logbook, noun, container)
      end
    end

    context 'when putting logbook away' do
      it 'falls back to plain stow if container put fails' do
        allow(DRC).to receive(:bput).and_return('You notate the')
        allow(DRCI).to receive(:get_item?).with('outfitting logbook').and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('outfitting logbook', 'duffel bag').and_return(false)
        allow(DRCI).to receive(:put_away_item?).with('outfitting logbook').and_return(true)

        expect(DRCI).to receive(:put_away_item?).with('outfitting logbook', 'duffel bag').ordered
        expect(DRCI).to receive(:put_away_item?).with('outfitting logbook').ordered

        described_class.logbook_item(logbook, noun, container)
      end

      it 'does not call plain stow if container put succeeds' do
        allow(DRC).to receive(:bput).and_return('You notate the')
        allow(DRCI).to receive(:get_item?).with('outfitting logbook').and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('outfitting logbook', 'duffel bag').and_return(true)

        expect(DRCI).not_to receive(:put_away_item?).with('outfitting logbook')

        described_class.logbook_item(logbook, noun, container)
      end
    end
  end

  describe '.order_enchant' do
    let(:bag) { 'backpack' }
    let(:belt) { nil }

    before do
      allow(DRCT).to receive(:order_item)
      allow(described_class).to receive(:stow_crafting_item)
      allow(DRC).to receive(:left_hand).and_return(nil)
      allow(DRC).to receive(:right_hand).and_return(nil)
    end

    it 'orders items the specified number of times' do
      expect(DRCT).to receive(:order_item).with(123, 5).exactly(3).times
      described_class.order_enchant(123, 3, 5, bag, belt)
    end

    it 'stows both hands after each order' do
      expect(described_class).to receive(:stow_crafting_item).exactly(6).times # 2 per order * 3
      described_class.order_enchant(123, 3, 5, bag, belt)
    end
  end

  describe '.fount' do
    let(:bag) { 'backpack' }
    let(:bag_items) { ['fount'] }
    let(:belt) { nil }

    before do
      allow(described_class).to receive(:get_crafting_item)
      allow(described_class).to receive(:order_enchant)
      allow(DRCT).to receive(:dispose)
      allow(DRCI).to receive(:stow_hands)
    end

    it 'checks fount uses and orders more if low' do
      allow(DRC).to receive(:bput).and_return('You tap fount inside your backpack', 'This appears to be a crafting tool and it has approximately 1 uses remaining')
      expect(described_class).to receive(:order_enchant).with(123, 3, 5, bag, belt)

      described_class.fount(123, 3, 5, 2, bag, bag_items, belt)
    end

    it 'does not reorder if uses sufficient' do
      allow(DRC).to receive(:bput).and_return('You tap fount inside your backpack', 'This appears to be a crafting tool and it has approximately 10 uses remaining')
      expect(described_class).not_to receive(:order_enchant)

      described_class.fount(123, 3, 5, 2, bag, bag_items, belt)
    end

    it 'checks fount on brazier when not in bag' do
      allow(DRC).to receive(:bput).and_return('I could not find what you were referring to.', 'You tap fount atop a iron brazier.', 'This appears to be a crafting tool and it has approximately 10 uses remaining')
      expect(described_class).not_to receive(:order_enchant)

      described_class.fount(123, 3, 5, 2, bag, bag_items, belt)
    end
  end

  describe '.clean_brazier?' do
    before do
      allow(described_class).to receive(:empty_brazier)
    end

    it 'returns true when brazier is empty' do
      allow(DRC).to receive(:bput).and_return('There is nothing on there')
      expect(described_class.clean_brazier?).to be true
    end

    it 'cleans brazier when items present' do
      allow(DRC).to receive(:bput).and_return('On the iron brazier you see some sigil.', 'You prepare to clean off the brazier', 'a massive ball of flame jets forward')
      expect(described_class.clean_brazier?).to be true
    end
  end

  describe '.empty_brazier' do
    it 'gets and disposes items from brazier' do
      allow(DRC).to receive(:bput).and_return('On the iron brazier you see a sigil and a fount.')
      expect(DRC).to receive(:bput).with('get sigil from brazier', described_class::BRAZIER_GET_SUCCESS)
      expect(DRC).to receive(:bput).with('get fount from brazier', described_class::BRAZIER_GET_SUCCESS)
      expect(DRCT).to receive(:dispose).with('sigil')
      expect(DRCT).to receive(:dispose).with('fount')

      described_class.empty_brazier
    end

    it 'returns when nothing on brazier' do
      allow(DRC).to receive(:bput).and_return('There is nothing')
      expect(DRCT).not_to receive(:dispose)

      described_class.empty_brazier
    end
  end

  describe '.count_raw_metal' do
    it 'returns nil and logs when no materials found' do
      allow(DRC).to receive(:bput).and_return('crafting materials but there is nothing in there like that.')
      expect(Lich::Messaging).to receive(:msg).with('bold', 'DRCC: No materials found.')

      result = described_class.count_raw_metal('backpack')
      expect(result).to be_nil
    end

    it 'returns nil and logs when container not found' do
      allow(DRC).to receive(:bput).and_return("I don't know what you are referring to")
      expect(Lich::Messaging).to receive(:msg).with('bold', 'DRCC: Container not found.')

      result = described_class.count_raw_metal('backpack')
      expect(result).to be_nil
    end

    it 'opens container if closed and recurses' do
      allow(DRC).to receive(:bput).and_return("While it's closed", 'crafting materials but there is nothing in there like that.')
      allow(DRCI).to receive(:open_container?).and_return(true)
      expect(Lich::Messaging).to receive(:msg).with('bold', 'DRCC: No materials found.')

      described_class.count_raw_metal('backpack')
    end

    it 'parses and returns metal hash' do
      allow(DRC).to receive(:bput).and_return('looking for crafting materials and see a tiny bronze ingot and a small bronze ingot.')

      result = described_class.count_raw_metal('backpack')
      expect(result).to eq({ 'bronze' => [3, 2] }) # 1+2 volume, 2 pieces
    end

    it 'returns specific type when requested' do
      allow(DRC).to receive(:bput).and_return('looking for crafting materials and see a tiny bronze ingot and a small iron ingot.')

      result = described_class.count_raw_metal('backpack', 'bronze')
      expect(result).to eq([1, 1]) # 1 volume, 1 piece
    end
  end

  describe '.check_for_existing_sigil?' do
    let(:bag) { 'backpack' }
    let(:belt) { nil }
    let(:info) { { 'stock-room' => 123 } }

    before do
      allow(described_class).to receive(:order_enchant)
    end

    it 'returns true when enough sigils exist' do
      allow(DRCI).to receive(:count_items_in_container).and_return(5)

      result = described_class.check_for_existing_sigil?('fire', 1, 3, bag, belt, info)
      expect(result).to be true
    end

    it 'orders more when count is low for primary/secondary sigils' do
      allow(DRCI).to receive(:count_items_in_container).and_return(1)
      allow(DRC).to receive(:bput).and_return('stuff')

      expect(described_class).to receive(:order_enchant).with(123, 2, 1, bag, belt)

      result = described_class.check_for_existing_sigil?('primary', 1, 3, bag, belt, info)
      expect(result).to be true
    end

    it 'returns false and logs for non-purchasable sigils when low' do
      allow(DRCI).to receive(:count_items_in_container).and_return(1)
      expect(Lich::Messaging).to receive(:msg).with('bold', /Not enough.*sigil-scroll/)

      result = described_class.check_for_existing_sigil?('unknown', 1, 3, bag, belt, info)
      expect(result).to be false
    end
  end
end
