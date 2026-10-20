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

  describe '.repair_own_tools' do
    let(:info) { { 'finisher-room' => 8776, 'finisher-number' => 6 } }
    let(:bag) { 'backpack' }
    let(:bag_items) { [] }
    let(:belt) { nil }
    let(:sent) { [] }
    let(:stowed) { [] }

    # Replies keyed by the repair command; any command not listed succeeds.
    # An Array value gives successive replies to the same command.
    # DRC.bput returns the matched text, so the stubs return the pattern constants.
    def stub_repair_replies(replies = {})
      allow(DRC).to receive(:bput) do |command, *_patterns|
        sent << command
        reply = replies.fetch(command, DRCC::REPAIR_SUCCESS)
        reply.is_a?(Array) ? (reply.shift || DRCC::REPAIR_SUCCESS) : reply
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

    context 'when the pour reply is Pour what and the retry says the character is engaged' do
      before { stub_repair_replies('pour my oil on my hammer' => [DRCC::REPAIR_POUR_WHAT, DRCC::REPAIR_ENGAGED]) }

      it 'stows the oil and the tool once each and skips the next tool' do
        DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(sent).to eq(['rub my hammer with my wire brush', 'pour my oil on my hammer', 'pour my oil on my hammer'])
        expect(stowed).to eq(['wire brush', 'oil', 'hammer'])
      end

      it 'waits for the engaged reply on the retry and tells the user why repairs stopped' do
        result = DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(DRC).to have_received(:bput)
          .with('pour my oil on my hammer', DRCC::REPAIR_SUCCESS, DRCC::REPAIR_ENGAGED)
        expect(Lich::Messaging.messages.map { |m| m[:message] }).to eq(['DRCC: Cannot repair in combat.'])
        expect(result).to eq(:engaged)
      end
    end

    context 'when the pour reply is Pour what and the retry succeeds' do
      before { stub_repair_replies('pour my oil on my hammer' => [DRCC::REPAIR_POUR_WHAT, DRCC::REPAIR_SUCCESS]) }

      it 'fetches more oil and goes on to the next tool' do
        result = DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)

        expect(DRCC).to have_received(:check_consumables).with('oil', 8776, 6, bag, bag_items, belt)
        expect(stowed).to eq(['wire brush', 'oil', 'hammer', 'wire brush', 'oil', 'tongs'])
        expect(result).to be_nil
      end
    end

    describe 'return value' do
      it 'is :engaged when an engaged reply stops the repairs' do
        stub_repair_replies('rub my hammer with my wire brush' => DRCC::REPAIR_ENGAGED)

        expect(DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)).to eq(:engaged)
      end

      it 'is nil when every tool is worked through' do
        stub_repair_replies('rub my hammer with my wire brush' => DRCC::REPAIR_CONFUSED)

        expect(DRCC.repair_own_tools(info, %w[hammer tongs], bag, bag_items, belt)).to be_nil
      end

      it 'is nil when no tool is eligible' do
        stub_repair_replies

        expect(DRCC.repair_own_tools(info, [], bag, bag_items, belt)).to be_nil
        expect(sent).to be_empty
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

      it 'does not suggest the full name when the typed duplicate full name is also part of a unique name' do
        # Synthetic recipe: no name in base-recipes.yaml contains a duplicated
        # name, but the menu then lists a unique name and only the typed-name
        # check keeps the hint away.
        staff_sling = { 'name' => 'a weighted staff sling', 'type' => 'shaping', 'chapter' => 9, 'volume' => 3 }
        feed_input('1')

        DRCC.recipe_lookup(recipes + [staff_sling], 'a weighted staff')

        expect(menu_lines.length).to eq(3)
        expect(hint).to be_empty
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

    # Synthetic data: base-recipes.yaml has no two recipes sharing a name,
    # type and chapter, but nothing in the data format prevents it.
    context 'when two recipes share the same name, type and chapter' do
      let(:short_staff) { { 'name' => 'a weighted staff', 'type' => 'shaping', 'chapter' => 9, 'volume' => 6 } }

      it 'adds the volume so the two menu lines differ' do
        feed_input('3')

        result = DRCC.recipe_lookup(recipes + [short_staff], 'a weighted staff')

        expect(menu_lines).to eq(['    1: a weighted staff (weaponsmithing, chapter 8)',
                                  '    2: a weighted staff (shaping, chapter 9, volume 9)',
                                  '    3: a weighted staff (shaping, chapter 9, volume 6)'])
        expect(result).to equal(short_staff)
      end

      it 'leaves out the volume when an entry has none' do
        no_volume = { 'name' => 'a weighted staff', 'type' => 'shaping', 'chapter' => 9 }
        feed_input('3')

        result = DRCC.recipe_lookup(recipes + [no_volume], 'a weighted staff')

        expect(menu_lines).to eq(['    1: a weighted staff (weaponsmithing, chapter 8)',
                                  '    2: a weighted staff (shaping, chapter 9, volume 9)',
                                  '    3: a weighted staff (shaping, chapter 9)'])
        expect(result).to equal(no_volume)
      end
    end

    # Synthetic data: an entry duplicated in full (name, type, chapter and
    # volume) would otherwise give two identical menu lines.
    context 'when two recipes share the name, type, chapter and volume' do
      let(:dup_staff) { { 'name' => 'a weighted staff', 'type' => 'shaping', 'chapter' => 9, 'volume' => 9 } }

      it 'numbers the identical entries so every menu line differs' do
        feed_input('3')

        result = DRCC.recipe_lookup(recipes + [dup_staff], 'a weighted staff')

        expect(menu_lines).to eq(['    1: a weighted staff (weaponsmithing, chapter 8)',
                                  '    2: a weighted staff (shaping, chapter 9, volume 9, entry 1 of 2)',
                                  '    3: a weighted staff (shaping, chapter 9, volume 9, entry 2 of 2)'])
        expect(menu_lines.uniq.length).to eq(3)
        expect(result).to equal(dup_staff)
      end

      it 'numbers identical entries that have no volume' do
        bare_a = { 'name' => 'a weighted staff', 'type' => 'shaping', 'chapter' => 9 }
        bare_b = { 'name' => 'a weighted staff', 'type' => 'shaping', 'chapter' => 9 }
        feed_input('3')

        result = DRCC.recipe_lookup([smith_staff, bare_a, bare_b], 'a weighted staff')

        expect(menu_lines).to eq(['    1: a weighted staff (weaponsmithing, chapter 8)',
                                  '    2: a weighted staff (shaping, chapter 9, entry 1 of 2)',
                                  '    3: a weighted staff (shaping, chapter 9, entry 2 of 2)'])
        expect(result).to equal(bare_b)
      end
    end

    context 'menu helpers' do
      it 'keeps them off the public DRCC interface' do
        expect(DRCC).not_to respond_to(:recipe_menu_labels)
        expect(DRCC).not_to respond_to(:recipe_menu_choice)
        expect { DRCC.recipe_menu_choice(1) }.to raise_error(NoMethodError, /private method/)
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

    it 'prints the held-noun message once, not again on the next pass' do
      look_replies.push('In the large crucible you see a steel bar and a bronze nugget.',
                        'In the large crucible you see a steel bar.')
      held << 'bar'
      expect(DRCC.empty_crucible?).to be(false)
      held_messages = Lich::Messaging.messages.select { |m| m[:message].include?('Not clearing the bar') }
      expect(held_messages.length).to eq(1)
    end

    it 'prints the held-noun message once when two entries share the held noun' do
      look_replies << 'In the large crucible you see a steel bar and an iron bar.'
      held << 'bar'
      expect(DRCC.empty_crucible?).to be(false)
      held_messages = Lich::Messaging.messages.select { |m| m[:message].include?('Not clearing the bar') }
      expect(held_messages.length).to eq(1)
      expect(sent).to eq(['look in cruc'])
    end

    it 'prints the held-noun message on a later pass when it first shows up there' do
      look_replies.push(molten, 'In the large crucible you see a steel bar.')
      held << 'bar'
      expect(DRCC.empty_crucible?).to be(false)
      expect(sent).to eq(['look in cruc', 'tilt crucible', 'tilt crucible', 'look in cruc'])
      held_messages = Lich::Messaging.messages.select { |m| m[:message].include?('Not clearing the bar') }
      expect(held_messages.length).to eq(1)
    end

    it 'prints one held-noun message per distinct noun' do
      look_replies << 'In the large crucible you see a steel bar and a bronze nugget.'
      held.push('bar', 'nugget')
      expect(DRCC.empty_crucible?).to be(false)
      held_messages = Lich::Messaging.messages.map { |m| m[:message] }.grep(/Not clearing the/)
      expect(held_messages).to eq(['DRCC: Not clearing the bar from the crucible while you are holding something that matches it.',
                                   'DRCC: Not clearing the nugget from the crucible while you are holding something that matches it.'])
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

  describe '.stow_crafting_item' do
    let(:belt) { { 'name' => "forger's belt", 'items' => ['tongs'] } }
    let(:tie) { "tie my tongs to my forger's belt" }
    let(:bag_put) { 'put my tongs in my backpack' }
    let(:wounds) { 'Your wounds hinder your ability to do that.' }
    let(:attach) { "You attach the tongs to your forger's belt." }
    let(:sent) { [] }
    let(:tie_replies) { [] }
    let(:bag_put_reply) { 'You put your tongs in your backpack.' }
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

        line = command.start_with?('tie ') ? tie_replies.shift.to_s : bag_put_reply
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
      expect(sent).to eq([bag_put])
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
        expect(sent).to eq([tie, bag_put])
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
      expect(sent).to eq([tie, 'safe-room force', 'walk 8775', tie, bag_put])
      expect(Lich::Messaging).to have_received(:msg).with('bold', /Wounds hinder tying tongs/).once
      expect(Lich::Messaging).to have_received(:msg).with('bold', /Failed to tie tongs/).once
    end

    it 'puts the tool in the bag when the tie after safe-room fails another way' do
      tie_replies.push(wounds, 'Tie what?')
      expect(DRCC.stow_crafting_item('tongs', 'backpack', belt)).to be(true)
      expect(sent).to eq([tie, 'safe-room force', 'walk 8775', tie, bag_put])
    end

    context 'when the bag has no room' do
      let(:bag_put_reply) { "There's no room in the backpack." }

      it 'stows the tool after a failed tie and returns true' do
        tie_replies << 'Tie what?'
        expect(DRCC.stow_crafting_item('tongs', 'backpack', belt)).to be(true)
        expect(sent).to eq([tie, bag_put, 'stow my tongs'])
      end
    end

    context 'when the bag refuses the tool' do
      let(:bag_put_reply) { "You can't put that there." }

      it 'returns false, as for any bag tool, after putting it in the other bag' do
        tie_replies << "There's no more free ties on the belt."
        expect(DRCC.stow_crafting_item('tongs', 'backpack', belt)).to be(false)
        expect(sent).to eq([tie, bag_put, 'put my tongs in my other backpack'])
      end
    end

    # Every tie reply DRCI knows (and a timeout), alone and after wounds: the
    # trip and the retry happen only for wounds, at most once, and anything
    # that isn't a tie ends in the bag. A second reply is only read after
    # wounds, so pairs that start with anything else add no behaviour.
    # DRCI's /^You don't seem to be able to move/ is left out: the real bput
    # skips that line, so the outcome is the timeout ('') case covered here.
    describe 'for every tie reply, alone and after wounds' do
      success = ["You attach the tongs to your forger's belt.", 'You tie the tongs to the belt.',
                 'The tongs has already been tied off.']
      refusals = ["There's no more free ties on the belt.", 'Tie what?', 'You are a little too busy to do that.',
                  'You must be holding the tongs to do that.', 'You should close the fan first.',
                  'The tongs doesn\'t seem to fit.', "Tie it off when it's empty?", '']
      wound = 'Your wounds hinder your ability to do that.'
      replies = success + refusals + [wound]

      sequences = (success + refusals).map { |reply| [reply] } + replies.map { |reply| [wound, reply] }
      sequences.each do |sequence|
        it "is bounded after #{sequence.map(&:inspect).join(' then ')}" do
          tie_replies.push(*sequence)
          result = DRCC.stow_crafting_item('tongs', 'backpack', belt)

          retried = sequence.first == wound
          tied = success.include?(sequence.last)
          expected = [tie]
          expected += ['safe-room force', 'walk 8775', tie] if retried
          expected << bag_put unless tied
          expect(sent).to eq(expected)
          expect(result).to be(true)
        end
      end
    end
  end
end
