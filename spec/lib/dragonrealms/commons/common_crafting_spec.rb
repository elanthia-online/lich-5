# frozen_string_literal: true

require_relative '../../../spec_helper'

# Load production code. common-items is loaded so DRCC reaches the real DRCI
# (and its pattern constants) whether this file runs alone or in the suite.
require 'dragonrealms/commons/common-items'
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

  describe '.stow_crafting_item' do
    let(:belt) { { 'name' => "forger's belt", 'items' => ['tongs'] } }
    let(:tie) { "tie my tongs to my forger's belt" }
    let(:put) { 'put my tongs in my backpack' }
    let(:wounds) { 'Your wounds hinder your ability to do that.' }
    let(:attach) { "You attach the tongs to your forger's belt." }
    let(:sent) { [] }
    let(:tie_replies) { [] }
    let(:put_reply) { 'You put your tongs in your backpack.' }
    # The safe-room stub moves the character, so only a room id read before
    # the trip walks back to the crafting room (8775).
    let(:room_id) { [8775] }

    before(:each) do
      # Same contract as the real DRC.bput: String patterns become /pattern/i and
      # the matched text (not the whole line) is returned; '' on a timeout.
      # A non-empty reply that no pattern matches raises: the real bput would
      # wait out its 15 s timeout and print a debug block instead.
      allow(DRC).to receive(:bput) do |command, *patterns|
        sent << command
        # main retried without limit; stop the example instead of the stack.
        raise 'tie sent a third time' if sent.count { |c| c.start_with?('tie ') } > 2

        line = command.start_with?('tie ') ? tie_replies.shift.to_s : put_reply
        match = patterns.flatten.lazy.map { |p| line.match(p.is_a?(Regexp) ? p : /#{p}/i) }.find(&:itself)
        raise "real bput would wait 15 s: #{line.inspect} matches none of #{patterns.flatten.inspect}" if match.nil? && !line.empty?

        match ? match.to_a.first : ''
      end
      allow(DRC).to receive(:wait_for_script_to_complete) do |script, args|
        sent << "#{script} #{args.join(' ')}"
        room_id[0] = 1
      end
      allow(DRCT).to receive(:walk_to) { |room| sent << "walk #{room}" }
      allow(Room).to receive(:current) { OpenStruct.new(id: room_id.first) }
      allow(DRCC).to receive(:fput) { |command| sent << command }
      allow(Lich::Messaging).to receive(:msg)
    end

    it 'keeps the belt tie helper out of the public DRCC API' do
      expect(DRCC).not_to respond_to(:tie_to_crafting_belt?)
      expect { DRCC.tie_to_crafting_belt?('tongs', belt) }.to raise_error(NoMethodError, /private method/)
    end

    it 'returns nil without sending anything when there is no tool name' do
      expect(DRCC.stow_crafting_item(nil, 'backpack', belt)).to be_nil
      expect(sent).to be_empty
    end

    it 'ties a belt tool and returns true' do
      tie_replies << attach
      expect(DRCC.stow_crafting_item('tongs', 'backpack', belt)).to be(true)
      expect(sent).to eq([tie])
      expect(Lich::Messaging).not_to have_received(:msg)
    end

    it 'counts a tool that is already tied off as tied' do
      tie_replies << 'The tongs has already been tied off.'
      expect(DRCC.stow_crafting_item('tongs', 'backpack', belt)).to be(true)
      expect(sent).to eq([tie])
    end

    it 'puts a tool that is not on the belt list in the bag without a tie' do
      expect(DRCC.stow_crafting_item('hammer', 'backpack', belt)).to be(true)
      expect(sent).to eq(['put my hammer in my backpack'])
    end

    it 'puts the tool in the bag when there is no belt' do
      expect(DRCC.stow_crafting_item('tongs', 'backpack', nil)).to be(true)
      expect(sent).to eq([put])
    end

    [
      "There's no more free ties on the belt.",
      'Tie what?',
      'You must be holding the tongs to do that.',
      'You are a little too busy to do that.',
      'The tongs doesn\'t seem to fit.',
      'You should close the fan first.',
      "Tie it off when it's empty?",
      ''
    ].each do |reply|
      it "puts the tool in the bag without a safe-room trip after #{reply.empty? ? 'no reply' : reply.inspect}" do
        tie_replies << reply
        expect(DRCC.stow_crafting_item('tongs', 'backpack', belt)).to be(true)
        expect(sent).to eq([tie, put])
        expect(Lich::Messaging).to have_received(:msg)
          .with('bold', "DRCC: Failed to tie tongs to forger's belt. Stowing it off the belt instead.").once
      end
    end

    it 'goes to safe-room once for wounds, then ties again' do
      tie_replies.push(wounds, attach)
      expect(DRCC.stow_crafting_item('tongs', 'backpack', belt)).to be(true)
      expect(sent).to eq([tie, 'safe-room force', 'walk 8775', tie])
      expect(Lich::Messaging).to have_received(:msg)
        .with('bold', "DRCC: Wounds hinder tying tongs to forger's belt. Visiting safe-room, then trying once more.").once
      expect(Lich::Messaging).not_to have_received(:msg).with('bold', /Failed to tie/)
    end

    it 'puts the tool in the bag when wounds still hinder the tie after safe-room' do
      tie_replies.push(wounds, wounds)
      expect(DRCC.stow_crafting_item('tongs', 'backpack', belt)).to be(true)
      expect(sent).to eq([tie, 'safe-room force', 'walk 8775', tie, put])
      expect(Lich::Messaging).to have_received(:msg).with('bold', /Wounds hinder tying tongs/).once
      expect(Lich::Messaging).to have_received(:msg).with('bold', /Failed to tie tongs/).once
    end

    it 'puts the tool in the bag when the tie after safe-room fails another way' do
      tie_replies.push(wounds, 'Tie what?')
      expect(DRCC.stow_crafting_item('tongs', 'backpack', belt)).to be(true)
      expect(sent).to eq([tie, 'safe-room force', 'walk 8775', tie, put])
    end

    context 'when the bag has no room' do
      let(:put_reply) { "There's no room in the backpack." }

      it 'stows the tool after a failed tie and returns true' do
        tie_replies << 'Tie what?'
        expect(DRCC.stow_crafting_item('tongs', 'backpack', belt)).to be(true)
        expect(sent).to eq([tie, put, 'stow my tongs'])
      end
    end

    context 'when the bag refuses the tool' do
      let(:put_reply) { "You can't put that there." }

      it 'returns false, as for any bag tool, after putting it in the other bag' do
        tie_replies << "There's no more free ties on the belt."
        expect(DRCC.stow_crafting_item('tongs', 'backpack', belt)).to be(false)
        expect(sent).to eq([tie, put, 'put my tongs in my other backpack'])
      end
    end

    # Every ordered pair of tie replies DRCI knows (and a timeout): the trip
    # and the retry happen only for wounds, at most once, and anything that
    # isn't a tie ends in the bag. DRCI's /^You don't seem to be able to move/
    # is left out: the real bput skips that line, so the outcome is the
    # timeout ('') case covered here.
    describe 'for every pair of tie replies' do
      success = ["You attach the tongs to your forger's belt.", 'You tie the tongs to the belt.',
                 'The tongs has already been tied off.']
      refusals = ["There's no more free ties on the belt.", 'Tie what?', 'You are a little too busy to do that.',
                  'You must be holding the tongs to do that.', 'You should close the fan first.',
                  'The tongs doesn\'t seem to fit.', "Tie it off when it's empty?", '']
      wound = 'Your wounds hinder your ability to do that.'
      replies = success + refusals + [wound]

      replies.product(replies).each do |first, second|
        it "is bounded after #{first.inspect} then #{second.inspect}" do
          tie_replies.push(first, second)
          result = DRCC.stow_crafting_item('tongs', 'backpack', belt)

          retried = first == wound
          tied = success.include?(retried ? second : first)
          expected = [tie]
          expected += ['safe-room force', 'walk 8775', tie] if retried
          expected << put unless tied
          expect(sent).to eq(expected)
          expect(result).to be(true)
        end
      end
    end
  end
end
