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

  describe '.repair_own_tools' do
    let(:info) { { 'finisher-room' => 8776, 'finisher-number' => 6 } }
    let(:bag) { 'backpack' }
    let(:bag_items) { [] }
    let(:belt) { nil }
    let(:sent) { [] }
    let(:stowed) { [] }

    # Replies keyed by the repair command; any command not listed succeeds.
    # DRC.bput returns the matched text, so the stubs return the pattern constants.
    def stub_repair_replies(replies = {})
      allow(DRC).to receive(:bput) do |command, *_patterns|
        sent << command
        replies.fetch(command, DRCC::REPAIR_SUCCESS)
      end
    end

    before(:each) do
      allow(DRCC).to receive(:check_consumables)
      allow(DRCC).to receive(:get_crafting_item)
      allow(DRCC).to receive(:stow_crafting_item) { |name, *_rest| stowed << name }
      allow(DRC).to receive(:right_hand).and_return('hammer')
    end

    context 'when the rub reply says the character is engaged' do
      before { stub_repair_replies('rub my hammer with my wire brush' => DRCC::REPAIR_ENGAGED) }

      it 'stows the tool once and the wire brush once' do
        DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(stowed.count('hammer')).to eq(1)
        expect(stowed.count('wire brush')).to eq(1)
      end

      it 'does not fetch or work on the remaining tools' do
        DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(DRCC).not_to have_received(:get_crafting_item).with('tongs', any_args)
        expect(sent).to eq(['rub my hammer with my wire brush'])
        expect(stowed).to eq(['wire brush', 'hammer'])
      end

      it 'tells the user why repairs stopped' do
        DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(Lich::Messaging.messages.map { |m| m[:message] }).to eq(['DRCC: Cannot repair in combat.'])
      end
    end

    context 'when the rub reply says the character cannot figure out how' do
      before { stub_repair_replies('rub my hammer with my wire brush' => DRCC::REPAIR_CONFUSED) }

      it 'stows the brush and the tool once each and skips the oil for that tool' do
        DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(stowed.first(2)).to eq(['wire brush', 'hammer'])
        expect(sent).not_to include('pour my oil on my hammer')
      end

      it 'moves on and repairs the next tool' do
        DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(sent).to eq(['rub my hammer with my wire brush',
                            'rub my tongs with my wire brush', 'pour my oil on my tongs'])
        expect(stowed).to eq(['wire brush', 'hammer', 'wire brush', 'oil', 'tongs'])
      end

      it 'names the tool it could not repair' do
        DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(Lich::Messaging.messages.map { |m| m[:message] })
          .to eq(['DRCC: Cannot repair hammer, skipping it.'])
      end
    end

    context 'when the pour reply says the character cannot figure out how after a successful rub' do
      before { stub_repair_replies('pour my oil on my hammer' => DRCC::REPAIR_CONFUSED) }

      it 'stows the brush, the oil and the tool once each and repairs the next tool' do
        DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(stowed).to eq(['wire brush', 'oil', 'hammer', 'wire brush', 'oil', 'tongs'])
      end
    end

    context 'when the pour reply says the character is engaged after a successful rub' do
      before { stub_repair_replies('pour my oil on my hammer' => DRCC::REPAIR_ENGAGED) }

      it 'stows the brush, the oil and the tool once each and skips the next tool' do
        DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(stowed).to eq(['wire brush', 'oil', 'hammer'])
        expect(sent).to eq(['rub my hammer with my wire brush', 'pour my oil on my hammer'])
      end
    end

    context 'when the last tool hits a stop reply' do
      before { stub_repair_replies('rub my tongs with my wire brush' => DRCC::REPAIR_ENGAGED) }

      it 'keeps the earlier repairs and stows the last tool once' do
        DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(stowed).to eq(['wire brush', 'oil', 'hammer', 'wire brush', 'tongs'])
      end
    end

    context 'when every reply succeeds' do
      before { stub_repair_replies }

      it 'rubs and oils every tool and stows each once' do
        DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(sent).to eq(['rub my hammer with my wire brush', 'pour my oil on my hammer',
                            'rub my tongs with my wire brush', 'pour my oil on my tongs'])
        expect(stowed).to eq(['wire brush', 'oil', 'hammer', 'wire brush', 'oil', 'tongs'])
      end
    end

    context 'when a tool is not damaged enough' do
      before { stub_repair_replies('rub my hammer with my wire brush' => DRCC::REPAIR_NOT_NEEDED) }

      it 'skips the oil for that tool and still repairs the next one' do
        DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(sent).to eq(['rub my hammer with my wire brush',
                            'rub my tongs with my wire brush', 'pour my oil on my tongs'])
        expect(stowed).to eq(['wire brush', 'hammer', 'wire brush', 'oil', 'tongs'])
      end
    end

    context 'when the repair is a Proper Forging Tool Care success before a stop reply' do
      before do
        stub_repair_replies('pour my oil on my hammer' => DRCC::REPAIR_ENGAGED)
        # Stubbed rather than set: depending on load order Flags is the spec mock or the production class.
        allow(Flags).to receive(:[]).and_call_original
        allow(Flags).to receive(:[]).with('proper-repair').and_return(true)
        allow(Flags).to receive(:reset)
      end

      it 'still records the immunity and clears the flag' do
        DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(UserVars.immune_list.keys).to eq(['hammer'])
        expect(Flags).to have_received(:reset).with('proper-repair').once
      end
    end

    # Runs the real stow_crafting_item. Tie attempts are counted whether they
    # go through DRCI.tie_item? (DRCI is the spec_helper mock or the real
    # module, depending on load order) or straight through DRC.bput, so the
    # examples hold however the belt tie is implemented. The first tie
    # succeeds; any later tie finds nothing in hand and fails, and safe-room
    # raises, so a second tie that falls back to it fails the example at once.
    context 'with the real stow_crafting_item and a belt tool' do
      let(:belt) { { 'name' => 'forging belt', 'items' => ['hammer'] } }
      let(:tie_command) { 'tie my hammer to my forging belt' }
      let(:tie_replies) { ['You tie your hammer to your forging belt.'] }

      def next_tie_reply
        sent << tie_command
        tie_replies.shift || 'Tie what?'
      end

      def stub_belt_replies(rub_reply)
        allow(DRCI).to receive(:tie_item?).with('hammer', 'forging belt') { next_tie_reply.start_with?('You tie') }
        allow(DRC).to receive(:bput) do |command, *_patterns|
          next next_tie_reply if command == tie_command

          sent << command
          case command
          when 'rub my hammer with my wire brush' then rub_reply
          when /^put my / then 'You put'
          else DRCC::REPAIR_SUCCESS
          end
        end
      end

      before do
        allow(DRCC).to receive(:stow_crafting_item).and_call_original
        allow(DRC).to receive(:wait_for_script_to_complete).and_raise('safe-room run')
        allow(DRCT).to receive(:walk_to)
      end

      it 'ties the tool once and never sends it to the safe room when engaged' do
        stub_belt_replies(DRCC::REPAIR_ENGAGED)

        DRCC.repair_own_tools(info, %w[hammer], bag, bag_items, belt)

        expect(sent.count(tie_command)).to eq(1)
        expect(sent).to eq(['rub my hammer with my wire brush', 'put my wire brush in my backpack', tie_command])
      end

      it 'ties the tool once and never sends it to the safe room when it cannot figure out how' do
        stub_belt_replies(DRCC::REPAIR_CONFUSED)

        DRCC.repair_own_tools(info, %w[hammer], bag, bag_items, belt)

        expect(sent.count(tie_command)).to eq(1)
        expect(sent).to eq(['rub my hammer with my wire brush', 'put my wire brush in my backpack', tie_command])
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
