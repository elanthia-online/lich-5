# frozen_string_literal: true

require_relative '../../../spec_helper'

# Load production code
require 'dragonrealms/commons/common-crafting'

DRCC = Lich::DragonRealms::DRCC unless defined?(DRCC)

describe DRCC do
  describe '.logbook_item' do
    let(:logbook) { 'outfitting' }
    let(:noun) { 'rucksack' }
    let(:container) { 'duffel bag' }

    before(:each) do
      allow(DRCI).to receive(:get_item?).and_return(true)
      allow(DRCI).to receive(:put_away_item?).and_return(true)
      allow(DRCI).to receive(:dispose_trash)
    end

    context 'when bundle succeeds' do
      it 'gets logbook, bundles item, and puts logbook away' do
        allow(DRC).to receive(:bput).and_return('You notate the')

        expect(DRCI).to receive(:get_item?).with('outfitting logbook').ordered
        expect(DRC).to receive(:bput).with('bundle my rucksack with my logbook',
                                           'You notate the',
                                           'This work order has expired',
                                           'The work order requires items of a higher quality',
                                           "That isn't the correct type of item for this work order.",
                                           'You need to be holding').ordered
        expect(DRCI).to receive(:put_away_item?).with('outfitting logbook', 'duffel bag').and_return(true).ordered

        DRCC.logbook_item(logbook, noun, container)
      end

      it 'does not dispose of the item' do
        allow(DRC).to receive(:bput).and_return('You notate the')

        expect(DRCI).not_to receive(:dispose_trash)

        DRCC.logbook_item(logbook, noun, container)
      end
    end

    context 'when work order has expired' do
      it 'disposes the crafted item via dispose_trash when work order has expired' do
        allow(DRC).to receive(:bput).and_return('This work order has expired')

        expect(DRCI).to receive(:dispose_trash).with('rucksack')

        DRCC.logbook_item(logbook, noun, container)
      end
    end

    context 'when item quality is too low' do
      it 'disposes the crafted item via dispose_trash when quality is below work order requirements' do
        allow(DRC).to receive(:bput).and_return('The work order requires items of a higher quality')

        expect(DRCI).to receive(:dispose_trash).with('rucksack')

        DRCC.logbook_item(logbook, noun, container)
      end
    end

    context 'when item is wrong type' do
      it 'disposes the crafted item via dispose_trash when item type does not match work order' do
        allow(DRC).to receive(:bput).and_return("That isn't the correct type of item for this work order.")

        expect(DRCI).to receive(:dispose_trash).with('rucksack')

        DRCC.logbook_item(logbook, noun, container)
      end
    end

    context 'when item is not in hand' do
      it 'retrieves the item from container and retries bundle' do
        allow(DRC).to receive(:bput).and_return('You need to be holding', 'You notate the')
        allow(DRCI).to receive(:get_item?).and_return(true)

        expect(DRCI).to receive(:get_item?).with('outfitting logbook').ordered
        expect(DRC).to receive(:bput).with('bundle my rucksack with my logbook',
                                           'You notate the',
                                           'This work order has expired',
                                           'The work order requires items of a higher quality',
                                           "That isn't the correct type of item for this work order.",
                                           'You need to be holding').and_return('You need to be holding').ordered
        expect(DRCI).to receive(:get_item?).with('rucksack', 'duffel bag').and_return(true).ordered
        expect(DRC).to receive(:bput).with('bundle my rucksack with my logbook',
                                           'You notate the',
                                           'This work order has expired',
                                           'The work order requires items of a higher quality',
                                           "That isn't the correct type of item for this work order.").and_return('You notate the').ordered

        DRCC.logbook_item(logbook, noun, container)
      end

      it 'does not retry bundle if item cannot be retrieved' do
        allow(DRC).to receive(:bput).and_return('You need to be holding')
        allow(DRCI).to receive(:get_item?).with('outfitting logbook').and_return(true)
        allow(DRCI).to receive(:get_item?).with('rucksack', 'duffel bag').and_return(false)

        expect(DRC).to receive(:bput).once

        DRCC.logbook_item(logbook, noun, container)
      end

      it 'disposes item if retry bundle returns expired' do
        allow(DRCI).to receive(:get_item?).with('outfitting logbook').and_return(true)
        allow(DRCI).to receive(:get_item?).with('rucksack', 'duffel bag').and_return(true)
        allow(DRC).to receive(:bput)
          .with('bundle my rucksack with my logbook',
                'You notate the',
                'This work order has expired',
                'The work order requires items of a higher quality',
                "That isn't the correct type of item for this work order.",
                'You need to be holding')
          .and_return('You need to be holding')
        allow(DRC).to receive(:bput)
          .with('bundle my rucksack with my logbook',
                'You notate the',
                'This work order has expired',
                'The work order requires items of a higher quality',
                "That isn't the correct type of item for this work order.")
          .and_return('This work order has expired')

        expect(DRCI).to receive(:dispose_trash).with('rucksack')

        DRCC.logbook_item(logbook, noun, container)
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

        DRCC.logbook_item(logbook, noun, container)
      end

      it 'does not call plain stow if container put succeeds' do
        allow(DRC).to receive(:bput).and_return('You notate the')
        allow(DRCI).to receive(:get_item?).with('outfitting logbook').and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('outfitting logbook', 'duffel bag').and_return(true)

        expect(DRCI).not_to receive(:put_away_item?).with('outfitting logbook')

        DRCC.logbook_item(logbook, noun, container)
      end
    end
  end

  describe '.crafting_hometown' do
    it 'prefers force_crafting_town when set' do
      settings = OpenStruct.new(force_crafting_town: 'Shard', hometown: 'Crossing')
      expect(DRCC.crafting_hometown(settings)).to eq('Shard')
    end

    it 'falls back to hometown when force_crafting_town is unset' do
      settings = OpenStruct.new(force_crafting_town: nil, hometown: 'Crossing')
      expect(DRCC.crafting_hometown(settings)).to eq('Crossing')
    end
  end

  describe '.use_private_forge?' do
    it 'is true when use_private_forge is set' do
      expect(DRCC.use_private_forge?(OpenStruct.new(use_private_forge: true))).to be true
    end

    it 'is true when the legacy forge_use_private_forge is set' do
      expect(DRCC.use_private_forge?(OpenStruct.new(forge_use_private_forge: true))).to be true
    end

    it 'is false (not nil) when neither is set' do
      expect(DRCC.use_private_forge?(OpenStruct.new)).to be false
    end
  end

  describe '.private_forge_cost' do
    it 'uses forge_private_forge_cost when present' do
      expect(DRCC.private_forge_cost(OpenStruct.new(forge_private_forge_cost: 12_345))).to eq(12_345)
    end

    it 'defaults to DEFAULT_PRIVATE_FORGE_COST (50_000)' do
      expect(DRCC::DEFAULT_PRIVATE_FORGE_COST).to eq(50_000)
      expect(DRCC.private_forge_cost(OpenStruct.new)).to eq(50_000)
    end
  end

  describe '.private_forge_room' do
    before do
      allow(DRCC).to receive(:get_data).with('crafting').and_return(
        'blacksmithing' => {
          'Shard'      => { 'private_forge' => 51_058 },
          'Riverhaven' => {}
        }
      )
    end

    it 'returns the room id for a town with a private forge' do
      expect(DRCC.private_forge_room('Shard')).to eq(51_058)
    end

    it 'returns nil for a town without one' do
      expect(DRCC.private_forge_room('Riverhaven')).to be_nil
    end
  end

  describe '.towns_with_private_forge' do
    it 'lists only blacksmithing towns that define a private forge' do
      allow(DRCC).to receive(:get_data).with('crafting').and_return(
        'blacksmithing' => {
          'Shard'      => { 'private_forge' => 51_058 },
          'Crossing'   => { 'private_forge' => 16_936 },
          'Riverhaven' => {}
        }
      )
      expect(DRCC.towns_with_private_forge).to contain_exactly('Shard', 'Crossing')
    end
  end

  describe '.go_to_private_forge' do
    # Reference the modules the way production resolves them (Lich::DragonRealms::*),
    # so stubs hit the same object whether or not the real commons are loaded by
    # other specs in the full-suite run.
    let(:money) { Lich::DragonRealms::DRCM }
    let(:travel) { Lich::DragonRealms::DRCT }
    let(:settings) { OpenStruct.new(hometown: 'Shard') }

    before do
      allow(DRCC).to receive(:private_forge_room).with('Shard').and_return(51_058)
      allow(DRCC).to receive(:private_forge_cost).and_return(50_000)
      allow(money).to receive(:ensure_copper_on_hand).and_return(true)
      allow(travel).to receive(:walk_to)
      allow(DRC).to receive(:bput)
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 51_058))
    end

    it 'returns false and does not spend when the town has no private forge' do
      allow(DRCC).to receive(:private_forge_room).with('Shard').and_return(nil)
      expect(money).not_to receive(:ensure_copper_on_hand)
      expect(DRCC.go_to_private_forge('Shard', settings)).to be false
    end

    it 'returns false and does not walk when funds cannot be secured' do
      allow(money).to receive(:ensure_copper_on_hand).and_return(false)
      expect(travel).not_to receive(:walk_to)
      expect(DRCC.go_to_private_forge('Shard', settings)).to be false
    end

    it 'walks to the forge and returns true on arrival without trying the door' do
      expect(travel).to receive(:walk_to).with(51_058)
      expect(DRC).not_to receive(:bput)
      expect(DRCC.go_to_private_forge('Shard', settings)).to be true
    end

    it 'tries the door when walk_to did not arrive, then confirms arrival' do
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 999), OpenStruct.new(id: 51_058))
      expect(DRC).to receive(:bput).with('go door', any_args)
      expect(DRCC.go_to_private_forge('Shard', settings)).to be true
    end
  end
end
