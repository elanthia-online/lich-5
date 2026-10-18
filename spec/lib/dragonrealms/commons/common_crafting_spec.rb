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

  describe '.recipe_lookup' do
    # Shapes and names are taken from base-recipes.yaml. 'a metal targe' is a
    # substring of 'a metal target shield', and 'a weighted staff' exists in
    # two disciplines with different volumes.
    let(:aventail) { { 'name' => 'a metal ring aventail', 'type' => 'armorsmithing', 'chapter' => 1, 'volume' => 5 } }
    let(:target_shield) { { 'name' => 'a metal target shield', 'type' => 'armorsmithing', 'chapter' => 5, 'volume' => 8 } }
    let(:targe) { { 'name' => 'a metal targe', 'type' => 'armorsmithing', 'chapter' => 5, 'volume' => 7 } }
    let(:pike) { { 'name' => 'a metal pike', 'type' => 'weaponsmithing', 'chapter' => 7, 'volume' => 16 } }
    let(:pike_staff) { { 'name' => 'a metal pike staff', 'type' => 'weaponsmithing', 'chapter' => 7, 'volume' => 18 } }
    let(:smith_staff) { { 'name' => 'a weighted staff', 'type' => 'weaponsmithing', 'chapter' => 8, 'volume' => 10 } }
    let(:shaping_staff) { { 'name' => 'a weighted staff', 'type' => 'shaping', 'chapter' => 9, 'volume' => 9 } }
    let(:recipes) { [aventail, target_shield, targe, pike, pike_staff, smith_staff, shaping_staff] }

    let(:menu_lines) { [] }
    let(:messages) { [] }

    before(:each) do
      allow(DRCC).to receive(:respond) { |line| menu_lines << line }
      allow(Lich::Messaging).to receive(:msg) { |_type, text, **_opts| messages << text }
    end

    def reprompts
      messages.grep(/is not on the list/)
    end

    # Stubs get with a finite list of input lines. recipe_lookup loops until
    # it accepts a number, so a stub that repeats its last value forever would
    # turn a regression into a hang; this raises instead once input runs out.
    # (The empty? check, not `shift || raise`, lets a literal nil be fed.)
    def feed_input(*lines)
      queue = lines.dup
      allow(DRCC).to receive(:get) do
        raise 'get called after input ran out' if queue.empty?

        queue.shift
      end
    end

    def hint
      messages.grep(/full name/)
    end

    context 'when no recipe matches' do
      it 'returns nil and says so without reading input' do
        expect(DRCC).not_to receive(:get)

        expect(DRCC.recipe_lookup(recipes, 'mithril anvil')).to be_nil
        expect(messages).to include('DRCC: No recipe in base-recipes.yaml matches mithril anvil')
      end
    end

    context 'when exactly one recipe matches' do
      it 'returns that recipe without reading input' do
        expect(DRCC).not_to receive(:get)

        expect(DRCC.recipe_lookup(recipes, 'pike staff')).to equal(pike_staff)
      end
    end

    context 'when the full name is given and other names contain it' do
      it 'returns the exact-name recipe without showing the menu' do
        expect(DRCC).not_to receive(:get)

        expect(DRCC.recipe_lookup(recipes, 'a metal pike')).to equal(pike)
        expect(menu_lines).to be_empty
      end

      it 'returns the exact-name recipe even when it is a substring of an earlier name' do
        expect(DRCC).not_to receive(:get)

        expect(DRCC.recipe_lookup(recipes, 'a metal targe')).to equal(targe)
      end
    end

    context 'when a partial name matches several recipes' do
      it 'lists the matches as a numbered menu in recipe order' do
        feed_input('1')

        DRCC.recipe_lookup(recipes, 'metal targ')

        expect(menu_lines).to eq(['    1: a metal target shield', '    2: a metal targe'])
        expect(hint.length).to eq(1)
      end

      it 'returns the first entry when 1 is chosen' do
        feed_input('1')

        expect(DRCC.recipe_lookup(recipes, 'metal targ')).to equal(target_shield)
      end

      it 'returns the recipe at the chosen position, not one whose name merely contains it' do
        feed_input('2')

        expect(DRCC.recipe_lookup(recipes, 'metal targ')).to equal(targe)
      end

      it 'matches the partial name case-insensitively' do
        feed_input('2')

        expect(DRCC.recipe_lookup(recipes, 'METAL PIKE')).to equal(pike_staff)
      end

      it 'accepts a choice surrounded by whitespace and a trailing newline' do
        feed_input("  2 \n")

        expect(DRCC.recipe_lookup(recipes, 'metal targ')).to equal(targe)
      end

      it 're-prompts on one past the end of the menu instead of returning an unrelated recipe' do
        feed_input('3', '2')

        expect(DRCC.recipe_lookup(recipes, 'metal targ')).to equal(targe)
        expect(DRCC).to have_received(:get).twice
        expect(reprompts).to eq(["DRCC: 3 is not on the list. Enter a number from 1 to 2 with #{$clean_lich_char}send #"])
      end

      it 're-prompts on a large number instead of returning the first recipe in the list' do
        feed_input('999', '1')

        expect(DRCC.recipe_lookup(recipes, 'metal pike')).to equal(pike)
        expect(reprompts.length).to eq(1)
      end

      it 're-prompts on 0 instead of returning the last menu entry' do
        feed_input('0', '1')

        expect(DRCC.recipe_lookup(recipes, 'metal targ')).to equal(target_shield)
        expect(reprompts).to eq(["DRCC: 0 is not on the list. Enter a number from 1 to 2 with #{$clean_lich_char}send #"])
      end

      it 're-prompts on a zero-padded zero' do
        feed_input('00', '2')

        expect(DRCC.recipe_lookup(recipes, 'metal targ')).to equal(targe)
        expect(reprompts.length).to eq(1)
      end

      it 'keeps re-prompting through several bad numbers' do
        feed_input('0', '3', '42', '2')

        expect(DRCC.recipe_lookup(recipes, 'metal targ')).to equal(targe)
        expect(reprompts.length).to eq(3)
      end

      it 'accepts the last entry exactly at the upper bound' do
        feed_input('2')

        expect(DRCC.recipe_lookup(recipes, 'metal pike')).to equal(pike_staff)
        expect(reprompts).to be_empty
      end

      it 'silently skips lines that are not a bare number, then takes the next valid choice' do
        feed_input('abc', '', 'an unrelated line', '2x', '-1', '+1', '1.5', '2')

        expect(DRCC.recipe_lookup(recipes, 'metal targ')).to equal(targe)
        expect(DRCC).to have_received(:get).exactly(8).times
        expect(reprompts).to be_empty
      end

      it 'skips a nil line (a read that returned nothing) instead of raising' do
        feed_input(nil, '2')

        expect(DRCC.recipe_lookup(recipes, 'metal targ')).to equal(targe)
        expect(DRCC).to have_received(:get).twice
        expect(reprompts).to be_empty
      end

      it 'never returns nil once the menu is shown' do
        feed_input('0', '7', 'x', '1')

        result = DRCC.recipe_lookup(recipes, 'metal targ')
        expect(result).not_to be_nil
        expect(result['volume']).to eq(8)
      end
    end

    context 'when two recipes share the same name' do
      it 'labels the duplicate names with their type and chapter' do
        feed_input('1')

        DRCC.recipe_lookup(recipes, 'a weighted staff')

        expect(menu_lines).to eq(['    1: a weighted staff (weaponsmithing, chapter 8)',
                                  '    2: a weighted staff (shaping, chapter 9)'])
      end

      it 'does not suggest typing the full name when the full name was typed' do
        feed_input('1')

        DRCC.recipe_lookup(recipes, 'a weighted staff')

        expect(hint).to be_empty
        expect(messages).to include("DRCC: Please select desired recipe #{$clean_lich_char}send #")
      end

      it 'does not suggest the full name when every listed name is a duplicate' do
        feed_input('1')

        DRCC.recipe_lookup(recipes, 'weighted staff')

        expect(hint).to be_empty
        expect(menu_lines.length).to eq(2)
      end

      it 'still suggests the full name when a partial name also lists a unique name' do
        feed_input('1')

        DRCC.recipe_lookup(recipes, 'staff')

        expect(hint.length).to eq(1)
        expect(menu_lines.length).to eq(3)
      end

      it 'returns the second recipe when the second entry is chosen' do
        feed_input('2')

        expect(DRCC.recipe_lookup(recipes, 'a weighted staff')).to equal(shaping_staff)
      end

      it 'labels only the duplicated names when the menu also has unique names' do
        feed_input('3')

        result = DRCC.recipe_lookup(recipes, 'staff')

        expect(menu_lines).to eq(['    1: a metal pike staff',
                                  '    2: a weighted staff (weaponsmithing, chapter 8)',
                                  '    3: a weighted staff (shaping, chapter 9)'])
        expect(result).to equal(shaping_staff)
      end
    end
  end

  describe '.find_recipe' do
    context 'when the character is too distracted to turn the book (in combat)' do
      it 'halts the script instead of falling through to read the book' do
        allow(DRC).to receive(:bput).with(/^turn my book to chapter/, any_args)
                                    .and_return('You are too distracted to be doing that right now')
        # The read should never be reached once we halt.
        expect(DRC).not_to receive(:bput).with(/^read my/, any_args)

        expect { DRCC.find_recipe(1, 'a shield') }.to raise_error(SystemExit)
      end
    end
  end

  describe '.find_recipe2' do
    context 'when the character is too distracted to turn the book (in combat)' do
      it 'halts the script instead of falling through to read the book' do
        allow(DRC).to receive(:bput).with(/^turn my book to chapter/, any_args)
                                    .and_return('You are too distracted to be doing that right now')
        expect(DRC).not_to receive(:bput).with(/^read my/, any_args)

        expect { DRCC.find_recipe2(1, 'a shield') }.to raise_error(SystemExit)
      end
    end
  end

  describe '.get_crafting_item' do
    before(:each) do
      allow(DRC).to receive(:beep)
      # No belt path, no bag lookup: 'get my <name>' resolves to the not-found branch.
      allow(DRC).to receive(:bput).and_return('What do you')
    end

    context 'when the item cannot be found and skip_exit is false (default)' do
      it 'halts the script instead of continuing' do
        allow(DRCI).to receive(:in_hands?).and_return(false)

        expect { DRCC.get_crafting_item('mallet', 'backpack', nil, nil) }.to raise_error(SystemExit)
      end
    end

    context 'when the item cannot be found and skip_exit is true' do
      it 'returns nil without halting the script' do
        allow(DRCI).to receive(:in_hands?).and_return(false)

        result = nil
        expect { result = DRCC.get_crafting_item('mallet', 'backpack', nil, nil, true) }.not_to raise_error
        expect(result).to be_nil
      end
    end

    context 'when the item is already in hand after the retry pause' do
      it 'returns early without halting, even when skip_exit is false' do
        allow(DRCI).to receive(:in_hands?).and_return(true)

        expect { DRCC.get_crafting_item('mallet', 'backpack', nil, nil) }.not_to raise_error
      end
    end
  end
end
