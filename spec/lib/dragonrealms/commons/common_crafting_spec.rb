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

  describe '.empty_crucible?' do
    # Reference the modules the way production resolves them, so the stubs hit
    # the same objects whether or not the real commons are loaded.
    let(:common) { Lich::DragonRealms::DRC }
    let(:items) { Lich::DragonRealms::DRCI }
    let(:sent) { [] }
    let(:look_replies) { [] }
    # Nouns whose GET from the crucible fails (get_item_unsafe returns false).
    let(:stuck) { [] }
    let(:empty) { 'There is nothing in there.' }
    let(:molten) { 'In the large crucible you see some molten bronze.' }
    let(:nugget) { 'In the large crucible you see a bronze nugget.' }

    before(:each) do
      # Same contract as the real DRC.bput: String patterns become /pattern/i and
      # the matched text (not the whole line) is returned. The last reply repeats.
      allow(common).to receive(:bput) do |command, *patterns|
        sent << command
        next 'You tap a large crucible' if command == 'tap crucible'

        line = look_replies.length > 1 ? look_replies.shift : look_replies.first
        match = patterns.flatten.lazy.map { |p| line.match(p.is_a?(Regexp) ? p : /#{p}/i) }.find(&:itself)
        match ? match.to_a.first : ''
      end
      allow(DRCC).to receive(:fput) { |command| sent << command }
      allow(items).to receive(:get_item_unsafe) do |item, container|
        sent << "get #{item} from #{container}"
        !stuck.include?(item)
      end
      allow(items).to receive(:dispose_trash) { |item| sent << "dispose #{item}" }
      allow(items).to receive(:in_hands?) { |item| held.include?(item) }
    end

    # Nouns the player is already holding (DRCI.in_hands? returns true).
    let(:held) { [] }

    it 'returns true for an empty crucible' do
      look_replies << empty
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc'])
    end

    it 'returns false when there is no crucible' do
      look_replies << 'I could not find what you were referring to.'
      expect(DRCC.empty_crucible?).to be(false)
      expect(sent).to eq(['look in cruc'])
    end

    it 'returns false without retrying when the look times out' do
      look_replies << 'Something unrelated scrolls by.'
      expect(DRCC.empty_crucible?).to be(false)
      expect(sent).to eq(['look in cruc'])
    end

    it 'tilts molten metal out instead of trying to pick it up' do
      look_replies.push(molten, empty)
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'tilt crucible', 'tilt crucible', 'look in cruc'])
    end

    it 'tilts the metal first, then clears the clutter left behind' do
      look_replies.push('In the large crucible you see some molten bronze and a bronze nugget.', nugget, empty)
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'tilt crucible', 'tilt crucible',
                          'look in cruc', 'get nugget from crucible', 'dispose nugget',
                          'look in cruc'])
    end

    it 'gets and disposes of solid clutter' do
      look_replies.push(nugget, empty)
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'get nugget from crucible', 'dispose nugget', 'look in cruc'])
    end

    it 'returns true when the crucible empties on the last allowed pass' do
      look_replies.push(molten, molten, molten, empty)
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent.count('tilt crucible')).to eq(6)
      expect(sent.count('look in cruc')).to eq(4)
      expect(Lich::Messaging.messages).to be_empty
    end

    it 'gives up after 3 passes when the molten metal stays' do
      look_replies << molten
      expect(DRCC.empty_crucible?).to be(false)
      expect(sent.count('tilt crucible')).to eq(6)
      expect(sent.count('look in cruc')).to eq(4)
      expect(sent.grep(/^get /)).to be_empty
      expect(Lich::Messaging.messages.last).to include(type: 'bold')
      expect(Lich::Messaging.messages.last[:message]).to include('still not empty after 3 attempts to tilt or clear it')
    end

    it 'gives up after 3 passes when the clutter cannot be removed' do
      look_replies << nugget
      stuck << 'nugget'
      expect(DRCC.empty_crucible?).to be(false)
      expect(sent.count('get nugget from crucible')).to eq(3)
      expect(sent.count('look in cruc')).to eq(4)
      expect(Lich::Messaging.messages.last[:message]).to include('still not empty after 3 attempts to tilt or clear it')
    end

    it 'counts a tilt and the clears after it against the same 3-pass budget' do
      look_replies.push(molten, nugget)
      stuck << 'nugget'
      expect(DRCC.empty_crucible?).to be(false)
      expect(sent).to eq(['look in cruc', 'tilt crucible', 'tilt crucible',
                          'look in cruc', 'get nugget from crucible',
                          'look in cruc', 'get nugget from crucible',
                          'look in cruc'])
      expect(Lich::Messaging.messages.last).to include(type: 'bold')
      expect(Lich::Messaging.messages.last[:message]).to include('still not empty after 3 attempts to tilt or clear it')
    end

    it 'does not dispose of clutter it failed to pick up from the crucible' do
      look_replies.push(nugget, empty)
      stuck << 'nugget'
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'get nugget from crucible', 'look in cruc'])
      expect(items).not_to have_received(:dispose_trash)
    end

    it 'disposes only of the clutter items it picked up' do
      look_replies.push('In the large crucible you see a bronze nugget and a granite rock.', empty)
      stuck << 'rock'
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'get nugget from crucible', 'dispose nugget',
                          'get rock from crucible', 'look in cruc'])
    end

    it 'tilts molten metal listed after solid clutter instead of picking it up' do
      look_replies.push('In the large crucible you see a bronze nugget and some molten bronze.', nugget, empty)
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'tilt crucible', 'tilt crucible',
                          'look in cruc', 'get nugget from crucible', 'dispose nugget',
                          'look in cruc'])
    end

    it 'tilts molten metal listed without an article' do
      look_replies.push('In the large crucible you see molten bronze.', empty)
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'tilt crucible', 'tilt crucible', 'look in cruc'])
    end

    it 'skips an entry with no noun to pick up and gives up after one look' do
      # The real DRC.get_noun returns nil for a name that does not end in a
      # word (see common_spec.rb); the spec_helper stub never does.
      allow(common).to receive(:get_noun).with('a 5').and_return(nil)
      look_replies << 'In the large crucible you see a 5.'
      expect(DRCC.empty_crucible?).to be(false)
      expect(sent).to eq(['look in cruc'])
      expect(items).not_to have_received(:in_hands?)
      expect(items).not_to have_received(:get_item_unsafe)
    end

    it 'tilts molten metal anywhere in a comma-separated list' do
      look_replies.push('In the large crucible you see a bronze nugget, some molten iron and a granite rock.', empty)
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'tilt crucible', 'tilt crucible', 'look in cruc'])
    end

    [
      'a bronze nugget, molten iron and a granite rock',
      'a bronze nugget and molten iron',
      'a bronze nugget, a granite rock, and molten iron'
    ].each do |list|
      it "tilts bare molten metal that is not first in the list: #{list}" do
        look_replies.push("In the large crucible you see #{list}.", empty)
        expect(DRCC.empty_crucible?).to be(true)
        expect(sent).to eq(['look in cruc', 'tilt crucible', 'tilt crucible', 'look in cruc'])
      end
    end

    it 'does not split a solid item at a molten-hued word after and' do
      look_replies.push('In the large crucible you see a bronze nugget and molten-hued ingot.', empty)
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'get ingot from crucible', 'dispose ingot', 'look in cruc'])
    end

    it 'clears the entry glued to a molten-hued item on the next pass' do
      look_replies.push('In the large crucible you see a bronze nugget and molten-hued ingot.',
                        'In the large crucible you see a bronze nugget.', empty)
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'get ingot from crucible', 'dispose ingot',
                          'look in cruc', 'get nugget from crucible', 'dispose nugget',
                          'look in cruc'])
    end

    it 'picks up a solid item whose description only contains the word molten' do
      look_replies.push('In the large crucible you see a nugget of once-molten bronze.', empty)
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'get bronze from crucible', 'dispose bronze', 'look in cruc'])
    end

    %w[wand band stand].each do |noun|
      it "tilts molten metal listed after a #{noun}" do
        look_replies.push("In the large crucible you see a gold #{noun} and some molten bronze.", empty)
        expect(DRCC.empty_crucible?).to be(true)
        expect(sent).to eq(['look in cruc', 'tilt crucible', 'tilt crucible', 'look in cruc'])
      end
    end

    it 'tilts molten metal at the end of a list with a serial comma' do
      look_replies.push('In the large crucible you see a bronze nugget, a granite rock, and some molten iron.', empty)
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'tilt crucible', 'tilt crucible', 'look in cruc'])
    end

    it 'picks up every item of a serial-comma list by its own noun' do
      look_replies.push('In the large crucible you see a bronze nugget, a granite rock, and a steel bar.', empty)
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'get nugget from crucible', 'dispose nugget',
                          'get rock from crucible', 'dispose rock',
                          'get bar from crucible', 'dispose bar', 'look in cruc'])
    end

    it 'does not cut a noun ending in "and" when splitting the list' do
      look_replies.push('In the large crucible you see a gold wand and a steel bar.', empty)
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'get wand from crucible', 'dispose wand',
                          'get bar from crucible', 'dispose bar', 'look in cruc'])
    end

    it 'picks up a solid item whose adjective starts with molten' do
      look_replies.push('In the large crucible you see a nugget and a molten-hued ingot.', empty)
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'get nugget from crucible', 'dispose nugget',
                          'get ingot from crucible', 'dispose ingot', 'look in cruc'])
    end

    it 'leaves clutter alone when the player already holds an item with that noun' do
      look_replies << 'In the large crucible you see a steel bar.'
      held << 'bar'
      expect(DRCC.empty_crucible?).to be(false)
      expect(sent).to eq(['look in cruc'])
      expect(items).not_to have_received(:get_item_unsafe)
      expect(items).not_to have_received(:dispose_trash)
      expect(Lich::Messaging.messages.last).to include(type: 'bold')
      expect(Lich::Messaging.messages.last[:message]).to include('Not clearing the bar')
    end

    it 'clears the other clutter, then gives up on the held noun without more passes' do
      look_replies.push('In the large crucible you see a steel bar and a bronze nugget.',
                        'In the large crucible you see a steel bar.')
      held << 'bar'
      expect(DRCC.empty_crucible?).to be(false)
      expect(sent).to eq(['look in cruc', 'get nugget from crucible', 'dispose nugget', 'look in cruc'])
    end

    it 'still tilts molten metal while holding an item with the same noun' do
      look_replies.push(molten, empty)
      held << 'bronze'
      expect(DRCC.empty_crucible?).to be(true)
      expect(sent).to eq(['look in cruc', 'tilt crucible', 'tilt crucible', 'look in cruc'])
    end

    it 'lets find_empty_crucible move on from a crucible that will not empty' do
      look_replies << molten
      travel = Lich::DragonRealms::DRCT
      allow(DRCC).to receive(:get_data).with('crafting').and_return(
        'blacksmithing' => { 'Crossing' => { 'crucibles' => [1, 2], 'idle-room' => 3 } }
      )
      allow(Lich::DragonRealms::DRRoom).to receive(:pcs).and_return([])
      allow(Lich::DragonRealms::DRRoom).to receive(:group_members).and_return([])
      allow(DRCC).to receive(:clean_anvil?)
      predicate_results = []
      allow(travel).to receive(:find_sorted_empty_room) do |_rooms, _idle, predicate|
        predicate_results << predicate.call
      end
      DRCC.find_empty_crucible('Crossing')

      expect(predicate_results).to eq([false])
      expect(sent.first).to eq('tap crucible')
      expect(sent.count('look in cruc')).to eq(8)
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
