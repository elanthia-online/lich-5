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

  describe '.get_crafting_item' do
    # Reference the modules the way production resolves them, so the stubs hit
    # the same objects whether or not other specs load the real commons.
    let(:drc) { Lich::DragonRealms::DRC }
    let(:drci) { Lich::DragonRealms::DRCI }
    let(:drct) { Lich::DragonRealms::DRCT }
    let(:belt) { { 'name' => 'toolbelt', 'items' => ['mallet'] } }

    # Replies by reply class, worded as the GET/UNTIE patterns match them.
    let(:got) { 'You get' }
    let(:heavy) { "can't quite lift it" }
    let(:not_found) { 'What were you' }
    let(:tied) { 'You should untie' }
    let(:untied) { 'You untie' }
    let(:untie_what) { 'Untie what' }
    let(:wounded) { 'Your wounds hinder your ability to do that' }
    let(:pickup) { 'You pick up' }
    let(:already) { 'You are already' }

    let(:sent) { [] }

    # Feeds +replies+ to bput in order, recording each command; the last reply
    # repeats, as a stuck game state would. Like the real bput, it returns the
    # text matched by the first pattern (in argument order) that matches the
    # reply, or '' when none does, so a pattern missing from a bput call shows
    # up as a timeout instead of passing unnoticed.
    def reply_with(*replies)
      queue = replies.dup
      allow(drc).to receive(:bput) do |command, *patterns|
        sent << command
        bput_result(queue.size > 1 ? queue.shift : queue.first, patterns)
      end
    end

    def bput_result(reply, patterns)
      patterns.flatten.map { |pattern| reply.match(pattern) }.compact.first.to_a.first || ''
    end

    # An exit that escapes an example ends rspec early with status 0, which
    # would hide every later failure. Turn it into a failure of the example.
    around(:each) do |example|
      example.run
    rescue SystemExit
      raise 'get_crafting_item stopped the script where the example expected it to continue'
    end

    before(:each) do
      allow(drc).to receive(:beep)
      allow(drc).to receive(:wait_for_script_to_complete)
      allow(drct).to receive(:walk_to)
      allow(Room).to receive(:current).and_return(OpenStruct.new(id: 1234))
      allow(Lich::Messaging).to receive(:msg)
      allow(drci).to receive(:in_hands?).and_return(false)
    end

    context 'when the GET succeeds' do
      ['You get', 'You pick up', 'You are already'].each do |reply|
        it "returns true for #{reply.inspect}" do
          reply_with(reply)
          expect(DRCC.get_crafting_item('mallet', 'backpack', ['mallet'], nil)).to be true
          expect(sent).to eq(['get my mallet from my backpack'])
        end
      end
    end

    # Both not-found replies, so dropping either pattern from the GET fails here.
    ['What do you', 'What were you'].each do |reply|
      context "when the item cannot be found (\"#{reply}\") and skip_exit is false (default)" do
        it 'halts the script instead of continuing' do
          reply_with(reply)

          expect { DRCC.get_crafting_item('mallet', 'backpack', nil, nil) }.to raise_error(SystemExit)
          expect(drc).to have_received(:beep)
        end
      end

      context "when the item cannot be found (\"#{reply}\") and skip_exit is true" do
        it 'returns false without halting the script' do
          reply_with(reply)

          result = nil
          expect { result = DRCC.get_crafting_item('mallet', 'backpack', nil, nil, true) }.not_to raise_error
          expect(result).to be false
          expect(Lich::Messaging).to have_received(:msg).with('bold', 'DRCC: You seem to be missing: mallet')
          expect(Lich::Messaging).not_to have_received(:msg).with('bold', /Stopping script/)
        end
      end
    end

    context 'when the item is already in hand after the retry pause' do
      it 'returns true without halting, even when skip_exit is false' do
        reply_with(not_found)
        allow(drci).to receive(:in_hands?).with('mallet').and_return(true)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, nil)).to be true
        expect(drc).not_to have_received(:beep)
      end
    end

    context 'when the game says it "can\'t quite lift it"' do
      it 'stops the script after one GET when skip_exit is false' do
        reply_with(heavy)

        expect { DRCC.get_crafting_item('bronze ingot', 'backpack', ['bronze ingot'], nil) }.to raise_error(SystemExit)
        expect(sent).to eq(['get my bronze ingot from my backpack'])
        expect(drc).to have_received(:beep)
        expect(Lich::Messaging).to have_received(:msg).with('bold', "DRCC: You can't quite lift: bronze ingot")
        expect(Lich::Messaging).to have_received(:msg).with('bold', /Stopping script/)
      end

      it 'returns false after one GET when skip_exit is true' do
        reply_with(heavy)

        expect(DRCC.get_crafting_item('bronze ingot', 'backpack', ['bronze ingot'], nil, true)).to be false
        expect(sent).to eq(['get my bronze ingot from my backpack'])
        expect(Lich::Messaging).not_to have_received(:msg).with('bold', /Stopping script/)
      end

      it 'does not GET again even when the next reply would succeed' do
        reply_with(heavy, got)

        expect(DRCC.get_crafting_item('bronze ingot', 'backpack', ['bronze ingot'], nil, true)).to be false
        expect(sent.size).to eq(1)
      end
    end

    context 'when the item is on the crafting belt' do
      it 'returns true after the untie, without a GET' do
        reply_with(untied)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, belt)).to be true
        expect(sent).to eq(['untie my mallet from my toolbelt'])
      end

      it 'returns true without a GET when the belt untie says it is already in hand' do
        reply_with('You are already', got)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, belt)).to be true
        expect(sent).to eq(['untie my mallet from my toolbelt'])
      end

      it 'falls back to GET when the belt untie times out' do
        reply_with('', got)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, belt)).to be true
        expect(sent).to eq(['untie my mallet from my toolbelt', 'get my mallet'])
        expect(drci).not_to have_received(:in_hands?)
      end

      it 'falls back to GET when the belt untie finds nothing' do
        reply_with(untie_what, got)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, belt)).to be true
        expect(sent).to eq(['untie my mallet from my toolbelt', 'get my mallet'])
      end

      it 'visits safe-room once when wounds hinder, then unties again' do
        reply_with(wounded, untied)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, belt)).to be true
        expect(drc).to have_received(:wait_for_script_to_complete).with('safe-room', ['force']).once
        expect(drct).to have_received(:walk_to).with(1234).once
        expect(sent).to eq(['untie my mallet from my toolbelt'] * 2)
      end

      it 'returns false after one safe-room trip when wounds persist and skip_exit is true' do
        reply_with(wounded)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, belt, true)).to be false
        expect(drc).to have_received(:wait_for_script_to_complete).once
        expect(sent).to eq(['untie my mallet from my toolbelt'] * 2)
        expect(Lich::Messaging).to have_received(:msg).with('bold', 'DRCC: Your wounds still hinder untying: mallet')
      end

      it 'stops the script after one safe-room trip when wounds persist and skip_exit is false' do
        reply_with(wounded)

        expect { DRCC.get_crafting_item('mallet', 'backpack', nil, belt) }.to raise_error(SystemExit)
        expect(drc).to have_received(:wait_for_script_to_complete).once
      end

      it 'returns true without stopping when wounds persist but the item is in hand' do
        reply_with(wounded)
        allow(drci).to receive(:in_hands?).with('mallet').and_return(true)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, belt)).to be true
        expect(drc).to have_received(:wait_for_script_to_complete).once
        expect(sent).to eq(['untie my mallet from my toolbelt'] * 2)
        expect(drc).not_to have_received(:beep)
      end

      it 'keeps skip_exit after the safe-room trip when the item then is missing' do
        reply_with(wounded, untie_what, not_found)

        result = nil
        expect { result = DRCC.get_crafting_item('mallet', 'backpack', nil, belt, true) }.not_to raise_error
        expect(result).to be false
        expect(sent).to eq(['untie my mallet from my toolbelt', 'untie my mallet from my toolbelt', 'get my mallet'])
      end

      # The belt untie and the plain untie each get one safe-room visit, so
      # this call makes two; neither untie is sent more than twice.
      it 'visits safe-room once per untie command when the belt falls through to a tied GET' do
        reply_with(wounded, untie_what, tied, wounded)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, belt, true)).to be false
        expect(drc).to have_received(:wait_for_script_to_complete).with('safe-room', ['force']).twice
        expect(sent).to eq(['untie my mallet from my toolbelt'] * 2 + ['get my mallet'] + ['untie my mallet'] * 2)
        expect(Lich::Messaging).to have_received(:msg).with('bold', 'DRCC: Your wounds still hinder untying: mallet')
      end
    end

    context 'when the GET says the item is tied' do
      it 'returns true after the untie' do
        reply_with(tied, untied)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, nil)).to be true
        expect(sent).to eq(['get my mallet', 'untie my mallet'])
      end

      it 'visits safe-room once when wounds hinder, then unties again' do
        reply_with(tied, wounded, untied)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, nil)).to be true
        expect(drc).to have_received(:wait_for_script_to_complete).once
        expect(sent).to eq(['get my mallet', 'untie my mallet', 'untie my mallet'])
      end

      it 'returns false after one safe-room trip when wounds persist and skip_exit is true' do
        reply_with(tied, wounded)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, nil, true)).to be false
        expect(drc).to have_received(:wait_for_script_to_complete).once
        expect(sent).to eq(['get my mallet', 'untie my mallet', 'untie my mallet'])
      end

      it 'stops the script when wounds persist and skip_exit is false' do
        reply_with(tied, wounded)

        expect { DRCC.get_crafting_item('mallet', 'backpack', nil, nil) }.to raise_error(SystemExit)
      end

      it 'returns true without stopping when wounds persist but the item is in hand' do
        reply_with(tied, wounded)
        allow(drci).to receive(:in_hands?).with('mallet').and_return(true)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, nil)).to be true
        expect(drc).to have_received(:wait_for_script_to_complete).once
        expect(sent).to eq(['get my mallet', 'untie my mallet', 'untie my mallet'])
        expect(drc).not_to have_received(:beep)
      end

      it 'returns true when the untie finds nothing but the item is in hand' do
        reply_with(tied, untie_what)
        allow(drci).to receive(:in_hands?).with('mallet').and_return(true)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, nil)).to be true
        expect(sent).to eq(['get my mallet', 'untie my mallet'])
        expect(drc).not_to have_received(:beep)
      end

      it 'stops the script when the untie finds nothing and the item is not in hand' do
        reply_with(tied, untie_what)

        expect { DRCC.get_crafting_item('mallet', 'backpack', nil, nil) }.to raise_error(SystemExit)
        expect(sent).to eq(['get my mallet', 'untie my mallet'])
        expect(drc).to have_received(:beep)
        expect(Lich::Messaging).to have_received(:msg).with('bold', /Cannot continue crafting/)
      end

      it 'returns false when the untie finds nothing, the item is not in hand, and skip_exit is true' do
        reply_with(tied, untie_what)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, nil, true)).to be false
        expect(sent).to eq(['get my mallet', 'untie my mallet'])
        expect(drc).to have_received(:beep)
        expect(Lich::Messaging).not_to have_received(:msg).with('bold', /Cannot continue crafting/)
      end

      it 'reports whether the item is in hand when the untie times out, without stopping' do
        reply_with(tied, '')

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, nil)).to be false
        expect(sent).to eq(['get my mallet', 'untie my mallet'])

        sent.clear
        reply_with(tied, '')
        allow(drci).to receive(:in_hands?).with('mallet').and_return(true)
        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, nil)).to be true
        expect(sent).to eq(['get my mallet', 'untie my mallet'])
        expect(drc).not_to have_received(:beep)
      end
    end

    # Each untie arm detects wounds with the pattern its caller waits for, so
    # editing one wounds constant cannot silently skip the safe-room trip.
    context 'when a wounds pattern differs from the other' do
      it 'visits safe-room on the belt path when BELT_UNTIE_WOUNDED alone matches' do
        stub_const('Lich::DragonRealms::DRCC::BELT_UNTIE_WOUNDED', /^Belt wounds hinder/)
        reply_with('Belt wounds hinder', untied)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, belt, true)).to be true
        expect(drc).to have_received(:wait_for_script_to_complete).with('safe-room', ['force']).once
      end

      it 'visits safe-room on the "You should untie" path when UNTIE_WOUNDED alone matches' do
        stub_const('Lich::DragonRealms::DRCC::UNTIE_WOUNDED', /^Plain wounds hinder/)
        reply_with(tied, 'Plain wounds hinder', untied)

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, nil, true)).to be true
        expect(drc).to have_received(:wait_for_script_to_complete).with('safe-room', ['force']).once
      end
    end

    context 'when the GET reply matches nothing (bput timed out)' do
      it 'reports whether the item is in hand and does not stop the script' do
        reply_with('')

        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, nil)).to be false
        allow(drci).to receive(:in_hands?).with('mallet').and_return(true)
        expect(DRCC.get_crafting_item('mallet', 'backpack', nil, nil)).to be true
        expect(drc).not_to have_received(:beep)
      end
    end

    # The untie and failure helpers are internal; scripts can only reach them
    # through get_crafting_item.
    context 'its helpers' do
      it 'are not public DRCC methods' do
        expect(DRCC).not_to respond_to(:untie_crafting_item)
        expect(DRCC).not_to respond_to(:crafting_item_failed)
        expect { DRCC.crafting_item_failed('x', true) }.to raise_error(NoMethodError, /private method/)
      end
    end

    # Every ordered sequence of four replies (the last one repeats), from the
    # belt and without it, with the item in hand afterwards and without: the
    # method always ends with a boolean or, without skip_exit, an exit. It
    # sends each command at most twice (the GET once), and visits safe-room at
    # most once per untie command. With the item in hand, only a GET answered
    # "can't quite lift it" ends in anything but true.
    context 'across every sequence of four replies' do
      let(:replies) { [got, pickup, already, heavy, not_found, tied, untied, untie_what, wounded, ''] }

      # Stubbed once, reading the loop's state, as re-stubbing in every one of
      # the 80,000 iterations would dominate the run time.
      it 'is bounded and honours skip_exit' do
        queue = []
        exchanges = []
        held = false
        trips = 0
        allow(drc).to receive(:bput) do |command, *patterns|
          sent << command
          reply = queue.size > 1 ? queue.shift : queue.first
          exchanges << [command, reply]
          bput_result(reply, patterns)
        end
        allow(drci).to receive(:in_hands?) { held }
        allow(drc).to receive(:wait_for_script_to_complete) { trips += 1 }

        replies.product(replies, replies, replies).each do |sequence|
          [nil, belt].each do |which_belt|
            [true, false].each do |skip_exit|
              [true, false].each do |held_after|
                sent.clear
                exchanges.clear
                queue = sequence.dup
                held = held_after
                trips = 0
                label = "#{sequence.inspect} belt=#{!which_belt.nil?} skip_exit=#{skip_exit} held=#{held_after}"

                result = :exited
                begin
                  result = DRCC.get_crafting_item('mallet', 'backpack', nil, which_belt, skip_exit)
                  expect(result).to(satisfy(label) { |value| [true, false].include?(value) })
                rescue SystemExit
                  expect(skip_exit).to be(false), "exited despite skip_exit: #{label}"
                end
                expect(trips).to be <= sent.uniq.count { |command| command.start_with?('untie') }, label
                expect(sent.tally.values.max).to be <= 2, label
                expect(sent.count { |command| command.start_with?('get') }).to be <= 1, label
                next unless held_after

                lifted = exchanges.none? { |command, reply| command.start_with?('get') && reply == heavy }
                expect(result == true).to eq(lifted), label
              end
            end
          end
        end
      end
    end
  end
end
