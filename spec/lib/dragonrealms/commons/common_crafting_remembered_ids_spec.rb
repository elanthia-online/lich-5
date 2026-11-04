# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'common/gameobj'
require 'common/inventory'
require 'dragonrealms/commons/common'
require 'dragonrealms/commons/common-items'
require 'dragonrealms/commons/common-travel'
require 'dragonrealms/commons/common-crafting'

DRCC = Lich::DragonRealms::DRCC unless defined?(DRCC)

# DRCC.get_crafting_item and check_consumables GET an item by its own id once
# DRCC knows it: from its memo of ids it moved (a PUT or STOW by id in
# stow_crafting_item, or a GET that put one matching item in hand), else from
# the Inventory feed's existing snapshot. A missed id is forgotten and the
# L6 by-name GET follows. Everything runs the real DRCC, DRCI readers and
# Inventory snapshot over the real GameObj hands and worn list; only the game
# (DRC.bput) is scripted, with verbatim replies.
#
# The ids and names are Mahtra's (2026-11-05 09:18): she wears a "heavy silk
# duffel bag" #2391122 as her crafting bag while sewing a "duffel bag"; after
# the cut the half-made bag #4101793 is in her left hand, and "get my pins
# from my duffel bag" found it instead of the worn one. The pins ids are
# illustrative.
RSpec.describe Lich::DragonRealms::DRCC do
  let(:gameobj) { Lich::Common::GameObj }
  let(:inventory) { Lich::Common::Inventory }
  let(:drc) { Lich::DragonRealms::DRC }
  let(:drci) { Lich::DragonRealms::DRCI }
  let(:drct) { Lich::DragonRealms::DRCT }
  let(:memo) { described_class::CRAFTING_ITEM_IDS }

  let(:silk_duffel) { ['2391122', 'bag', 'heavy silk duffel bag'] }
  let(:half_made) { ['4101793', 'bag', 'duffel bag'] }
  let(:pack) { ['758573', 'pack', "scuffed traveler's pack"] }
  let(:pins) { ['4101800', 'pins', 'sepia pins'] }
  let(:new_pins) { ['4101801', 'pins', 'sepia pins'] }
  let(:iron_pins) { ['4101802', 'pins', 'straight iron pins'] }

  let(:got_pins) { 'You get some sepia pins from inside your heavy silk duffel bag.' }
  let(:put_pins) { 'You put your pins in your heavy silk duffel bag.' }
  let(:not_found) { 'What were you referring to?' }
  let(:could_not_find) { 'I could not find what you were referring to.' }
  let(:no_free_hand) { 'You need a free hand to do that.' }

  let(:sent) { [] }
  let(:replies) { Hash.new { |_hash, command| raise "unexpected command #{command.inspect}" } }
  let(:effects) { {} }

  def hands(right: nil, left: nil)
    gameobj.new_right_hand(*(right || [nil, nil, 'Empty']))
    gameobj.new_left_hand(*(left || [nil, nil, 'Empty']))
  end

  def worn(*items)
    gameobj.clear_inv
    items.each { |id, noun, name| gameobj.new_inv(id, noun, name) }
  end

  # The game answers +command+ with +lines+, one per send; a block runs at
  # the first send (the hands change as the game answers).
  def game(command, *lines, &effect)
    replies[command] = lines
    effects[command] = effect if effect
  end

  # A real Inventory snapshot, as the parser thread builds it from one
  # passive <inventoryManager> line: the worn silk duffel bag holding +items+
  # (id, "before,adjective,noun" name), and the pack holding +in_pack+.
  def feed(items, in_pack: [])
    xml = +"<inventoryManager id='imx' room='1'>"
    xml << "<i id='2391122' loc='worn,player' name=\"a heavy silk,duffel,bag\" weight='5' in_max='500'/>"
    xml << "<i id='758573' loc='worn,player' name=\"a scuffed,traveler's,pack\" weight='5' in_max='500'/>"
    items.each { |id, name| xml << "<i id='#{id}' loc='in,2391122' name=\"#{name}\" weight='1'/>" }
    in_pack.each { |id, name| xml << "<i id='#{id}' loc='in,758573' name=\"#{name}\" weight='1'/>" }
    xml << '</inventoryManager>'
    inventory.observe(xml)
    # The feed mirrors worn items into GameObj.inv; set the worn list the
    # example means after it.
    worn(silk_duffel, pack)
  end

  def get_pins(skip_exit = true)
    described_class.get_crafting_item('pins', 'duffel bag', ['pins'], nil, skip_exit)
  end

  # Mahtra stows the pins she holds next to the half-made bag: the PUT goes
  # by both ids, and DRCC remembers the pins' id.
  def stow_pins(pins_obj = pins)
    hands(right: pins_obj, left: half_made)
    game("put ##{pins_obj[0]} in #2391122", put_pins) { hands(left: half_made) }
    expect(described_class.stow_crafting_item('pins', 'duffel bag', nil)).to be(true)
    sent.clear
  end

  around(:each) do |example|
    example.run
  rescue SystemExit
    raise 'DRCC stopped the script where the example expected it to continue'
  end

  before(:each) do
    allow(Lich).to receive(:log)
    inventory.reset!
    worn(silk_duffel, pack)
    hands(left: half_made)
    allow(drc).to receive(:bput) do |command, *patterns|
      sent << command
      line = replies[command].shift.to_s
      effects.delete(command)&.call
      match = patterns.flatten.lazy.map { |p| line.match(p.is_a?(Regexp) ? p : /#{p}/i) }.find(&:itself)
      raise "real bput would wait 15 s: #{line.inspect} matches none of #{patterns.flatten.inspect}" if match.nil? && !line.empty?

      match ? match.to_a.first : ''
    end
    allow(described_class).to receive(:fput) { |command| sent << command }
    allow(described_class).to receive(:waitrt?)
    allow(described_class).to receive(:pause)
    allow(drc).to receive(:beep)
    allow(drct).to receive(:walk_to) do |room|
      sent << "walk #{room}"
      true
    end
    allow(Room).to receive(:current) { OpenStruct.new(id: 8775) }
    allow(Lich::Messaging).to receive(:msg)
  end

  after(:each) do
    inventory.reset!
    gameobj.clear_inv
    hands
  end

  describe '.get_crafting_item' do
    context 'with the half-made duffel bag in hand (Mahtra, 2026-11-05 09:18)' do
      it 'GETs the pins by name the first time, then by the id it saw in hand' do
        game('get my pins from #2391122', got_pins) { hands(right: pins, left: half_made) }
        expect(get_pins).to be(true)
        hands(left: half_made)
        game('get #4101800', got_pins) { hands(right: pins, left: half_made) }
        expect(get_pins).to be(true)
        expect(sent).to eq(['get my pins from #2391122', 'get #4101800'])
      end

      it 'GETs by the id stow_crafting_item put away, never naming any duffel bag' do
        stow_pins
        game('get #4101800', got_pins) { hands(right: pins, left: half_made) }
        expect(get_pins).to be(true)
        expect(sent).to eq(['get #4101800'])
      end

      it 'keeps going by id across a whole sew loop' do
        3.times do
          stow_pins
          game('get #4101800', got_pins) { hands(right: pins, left: half_made) }
          expect(get_pins).to be(true)
          expect(sent).to eq(['get #4101800'])
          sent.clear
        end
      end
    end

    context 'when the remembered id is stale' do
      before(:each) { stow_pins }

      [
        ['What were you referring to?', :not_found],
        ['I could not find what you were referring to.', :could_not_find]
      ].each do |reply, _label|
        it "forgets it after #{reply.inspect} and GETs by name, one extra command, no pause" do
          game('get #4101800', reply)
          game('get my pins from #2391122', got_pins) { hands(right: new_pins, left: half_made) }
          expect(get_pins).to be(true)
          expect(sent).to eq(['get #4101800', 'get my pins from #2391122'])
          expect(described_class).not_to have_received(:pause)
        end
      end

      it 'remembers the replacement pins the by-name GET found' do
        game('get #4101800', not_found)
        game('get my pins from #2391122', got_pins) { hands(right: new_pins, left: half_made) }
        get_pins
        hands(left: half_made)
        sent.clear
        game('get #4101801', got_pins) { hands(right: new_pins, left: half_made) }
        expect(get_pins).to be(true)
        expect(sent).to eq(['get #4101801'])
      end

      it 'is a final failure only when the by-name GET finds nothing either' do
        game('get #4101800', not_found)
        game('get my pins from #2391122', not_found)
        expect(get_pins).to be(false)
        expect(sent).to eq(['get #4101800', 'get my pins from #2391122'])
        expect(Lich::Messaging).to have_received(:msg).with('bold', 'DRCC: You seem to be missing: pins')
      end

      it 'does not try the dead id again on the next GET' do
        game('get #4101800', not_found)
        game('get my pins from #2391122', not_found, not_found)
        get_pins
        sent.clear
        get_pins
        expect(sent).to eq(['get my pins from #2391122'])
      end

      # "You need a free hand" says nothing about the id: it is final, as
      # for the by-name GET, and no second GET is sent.
      it 'is a final failure on "You need a free hand to do that." with no by-name GET' do
        hands(right: iron_pins, left: half_made)
        game('get #4101800', no_free_hand)
        expect(get_pins).to be(false)
        expect(sent).to eq(['get #4101800'])
        expect(Lich::Messaging).to have_received(:msg).with('bold', 'DRCC: No free hand to get: pins')
      end

      it 'answers a timed-out GET by id by the id in hand' do
        game('get #4101800', '') { hands(right: pins, left: half_made) }
        expect(get_pins).to be(true)
        expect(sent).to eq(['get #4101800'])
      end

      it 'unties by id after "You should untie"' do
        game('get #4101800', 'You should untie the pins first.')
        game('untie #4101800', 'You untie the pins.') { hands(right: pins, left: half_made) }
        expect(get_pins).to be(true)
        expect(sent).to eq(['get #4101800', 'untie #4101800'])
      end
    end

    # The id names a different item now: stock that became the half-made
    # product keeps going under its old name in the memo.
    it 'puts back an item the name no longer matches, forgets the id, then GETs by name' do
      stow_pins
      hands
      game('get #4101800', 'You get a duffel bag from inside your heavy silk duffel bag.') { hands(right: ['4101800', 'bag', 'duffel bag']) }
      game('put #4101800 in #2391122', 'You put your bag in your heavy silk duffel bag.') { hands }
      game('get my pins from #2391122', got_pins) { hands(right: new_pins) }
      expect(get_pins).to be(true)
      expect(sent).to eq(['get #4101800', 'put #4101800 in #2391122', 'get my pins from #2391122'])
      expect(memo.dead?('4101800')).to be(true)
    end

    it 'says so and GETs by name when the mismatched item will not go back' do
      stow_pins
      game('get #4101800', 'You get a duffel bag from inside your heavy silk duffel bag.') { hands(right: ['4101800', 'bag', 'duffel bag'], left: half_made) }
      game('put #4101800 in #2391122', 'There isn\'t any more room in the heavy silk duffel bag for that.')
      game('get my pins from #2391122', no_free_hand)
      expect(get_pins).to be(false)
      expect(sent).to eq(['get #4101800', 'put #4101800 in #2391122', 'get my pins from #2391122'])
      expect(Lich::Messaging).to have_received(:msg)
        .with('bold', 'DRCC: #4101800 is no longer pins. Could not put it back; getting pins by name.')
    end

    it 'shares the memo between a bag named and the same bag given as an Integer id' do
      stow_pins
      game('get #4101800', got_pins) { hands(right: pins, left: half_made) }
      expect(described_class.get_crafting_item('pins', 2_391_122, ['pins'], nil)).to be(true)
      expect(sent).to eq(['get #4101800'])
    end

    it 'GETs by name while the remembered pins are already in hand' do
      stow_pins
      hands(right: pins)
      game('get my pins from #2391122', got_pins) { hands(right: pins, left: new_pins) }
      expect(get_pins).to be(true)
      expect(sent).to eq(['get my pins from #2391122'])
    end

    it 'keys the memo by bag: pins put in the duffel bag are not GOT by id for the pack' do
      stow_pins
      game('get my pins from #758573', got_pins) { hands(right: new_pins, left: half_made) }
      expect(described_class.get_crafting_item('pins', 'pack', ['pins'], nil)).to be(true)
      expect(sent).to eq(['get my pins from #758573'])
    end

    it 'keys the memo by normalized name: "My  Pins" uses the "pins" id' do
      stow_pins
      game('get #4101800', got_pins) { hands(right: pins, left: half_made) }
      expect(described_class.get_crafting_item('My  Pins', 'duffel bag', ['pins'], nil)).to be(true)
      expect(sent).to eq(['get #4101800'])
    end

    it 'never uses an id for an "other" name' do
      stow_pins
      game('get my other pins', got_pins)
      expect(described_class.get_crafting_item('other pins', 'duffel bag', nil, nil)).to be(true)
      expect(sent).to eq(['get my other pins'])
    end

    it 'leaves a "#<id>" name exactly as L6 sends it' do
      stow_pins
      game('get #4101802', got_pins) { hands(right: iron_pins, left: half_made) }
      expect(described_class.get_crafting_item('#4101802', 'duffel bag', nil, nil)).to be(true)
      expect(sent).to eq(['get #4101802'])
    end

    it 'unties a belt tool by name first, then GETs by id when the belt has none' do
      stow_pins
      belt = { 'name' => 'tool belt', 'items' => ['pins'] }
      game('untie my pins from my tool belt', 'Untie what?')
      game('get #4101800', got_pins) { hands(right: pins, left: half_made) }
      expect(described_class.get_crafting_item('pins', 'duffel bag', ['pins'], belt)).to be(true)
      expect(sent).to eq(['untie my pins from my tool belt', 'get #4101800'])
    end

    it 'treats Integer and String hand ids alike' do
      game('get my pins from #2391122', got_pins) { hands(right: [4_101_800, 'pins', 'sepia pins'], left: half_made) }
      get_pins
      hands(left: half_made)
      sent.clear
      game('get #4101800', got_pins) { hands(right: [4_101_800, 'pins', 'sepia pins'], left: half_made) }
      expect(get_pins).to be(true)
      expect(sent).to eq(['get #4101800'])
    end

    it 'remembers nothing when two new matching items arrive' do
      hands
      game('get my pins from #2391122', got_pins) { hands(right: pins, left: new_pins) }
      get_pins
      hands
      sent.clear
      game('get my pins from #2391122', got_pins)
      get_pins
      expect(sent).to eq(['get my pins from #2391122'])
    end
  end

  describe '.stow_crafting_item' do
    # A combined stack comes back under a new id, neither input's: both
    # the pins put and the stack remembered in the bag are gone.
    it 'forgets the id put and the id remembered for the bag when the PUT combines' do
      stow_pins
      hands(right: new_pins, left: half_made)
      game('put #4101801 in #2391122', 'You combine your pins with the pins in your heavy silk duffel bag.') { hands(left: half_made) }
      expect(described_class.stow_crafting_item('pins', 'duffel bag', nil)).to be(true)
      expect(memo.size).to eq(0)
      expect([memo.dead?('4101800'), memo.dead?('4101801')]).to eq([true, true])
      sent.clear
      game('get my pins from #2391122', got_pins) { hands(right: new_pins, left: half_made) }
      get_pins
      expect(sent).to eq(['get my pins from #2391122'])
    end

    it 'remembers the id after a STOW fallback by id works' do
      hands(right: pins, left: half_made)
      game('put #4101800 in #2391122', 'There isn\'t any more room in the heavy silk duffel bag for that.')
      game('stow #4101800', 'You put your pins in your scuffed traveler\'s pack.') { hands(left: half_made) }
      expect(described_class.stow_crafting_item('pins', 'duffel bag', nil)).to be(true)
      sent.clear
      game('get #4101800', 'You get some sepia pins from inside your scuffed traveler\'s pack.') { hands(right: pins, left: half_made) }
      expect(get_pins).to be(true)
      expect(sent).to eq(['get #4101800'])
    end

    it 'remembers nothing for a failed PUT' do
      hands(right: pins, left: half_made)
      game('put #4101800 in #2391122', 'Perhaps you should be holding that first.')
      expect(described_class.stow_crafting_item('pins', 'duffel bag', nil)).to be(false)
      expect(memo.size).to eq(0)
    end

    it 'remembers nothing for a PUT by name (two pins held)' do
      hands(right: pins, left: new_pins)
      game('put my pins in #2391122', put_pins) { hands(left: new_pins) }
      expect(described_class.stow_crafting_item('pins', 'duffel bag', nil)).to be(true)
      expect(memo.size).to eq(0)
    end
  end

  describe 'the Inventory feed' do
    before(:each) { hands }

    it 'is never asked for, nor refreshed, while unavailable' do
      allow(inventory).to receive(:refresh)
      game('get my pins from #2391122', got_pins) { hands(right: pins) }
      expect(get_pins).to be(true)
      expect(inventory).not_to have_received(:refresh)
      expect(sent).to eq(['get my pins from #2391122'])
    end

    it 'gives the first GET the one matching item in the bag, by id' do
      feed([%w[4101800 some,sepia,pins], %w[4101850 a,linen,cloth]])
      allow(inventory).to receive(:refresh)
      game('get #4101800', got_pins) { hands(right: pins) }
      expect(get_pins).to be(true)
      expect(sent).to eq(['get #4101800'])
      expect(inventory).not_to have_received(:refresh)
    end

    it 'gives no id when two items in the bag match' do
      feed([%w[4101800 some,sepia,pins], ['4101802', 'some straight,iron,pins']])
      game('get my pins from #2391122', got_pins) { hands(right: pins) }
      expect(get_pins).to be(true)
      expect(sent).to eq(['get my pins from #2391122'])
    end

    it 'uses the adjectives to pick one: "sepia pins" is not the iron pins' do
      feed([%w[4101800 some,sepia,pins], ['4101802', 'some straight,iron,pins']])
      game('get #4101800', got_pins) { hands(right: pins) }
      expect(described_class.get_crafting_item('sepia pins', 'duffel bag', ['sepia pins'], nil)).to be(true)
      expect(sent).to eq(['get #4101800'])
    end

    it 'needs the noun equal: "pin" is not the pins' do
      feed([%w[4101800 some,sepia,pins]])
      game('get my pin from #2391122', not_found)
      expect(described_class.get_crafting_item('pin', 'duffel bag', ['pin'], nil, true)).to be(false)
      expect(sent).to eq(['get my pin from #2391122'])
    end

    it 'looks only in the crafting bag, not in other containers' do
      feed([], in_pack: [%w[4101800 some,sepia,pins]])
      game('get my pins from #2391122', got_pins) { hands(right: pins) }
      get_pins
      expect(sent).to eq(['get my pins from #2391122'])
    end

    it 'gives no id when the crafting bag is not one worn item' do
      feed([%w[4101800 some,sepia,pins]])
      worn(silk_duffel, ['2391123', 'bag', 'canvas duffel bag'])
      game('get my pins from my duffel bag', got_pins) { hands(right: pins) }
      get_pins
      expect(sent).to eq(['get my pins from my duffel bag'])
    end

    it 'forgets a feed id that misses and GETs by name, then not again' do
      feed([%w[4101800 some,sepia,pins]])
      game('get #4101800', could_not_find)
      game('get my pins from #2391122', got_pins) { hands(right: new_pins) }
      expect(get_pins).to be(true)
      hands
      game('get #4101801', got_pins) { hands(right: new_pins) }
      expect(get_pins).to be(true)
      expect(sent).to eq(['get #4101800', 'get my pins from #2391122', 'get #4101801'])
    end

    it 'gives no id the feed lists in the bag while that item is in hand' do
      feed([%w[4101800 some,sepia,pins]])
      hands(right: pins)
      game('get my pins from #2391122', got_pins) { hands(right: pins, left: new_pins) }
      get_pins
      expect(sent).to eq(['get my pins from #2391122'])
    end

    it 'prefers the memo over the feed' do
      feed([%w[4101800 some,sepia,pins]])
      stow_pins(new_pins)
      hands
      game('get #4101801', got_pins) { hands(right: new_pins) }
      get_pins
      expect(sent).to eq(['get #4101801'])
    end

    context 'when the feed answered but no snapshot is held' do
      before(:each) do
        allow(inventory).to receive(:feed_available?).and_return(true)
        allow(inventory).to receive(:current).and_return(nil)
      end

      it 'sends one short refresh, then none within the interval' do
        snapshot = nil
        allow(inventory).to receive(:refresh) do |timeout:|
          sent << "refresh #{timeout}"
          snapshot
        end
        game('get my pins from #2391122', got_pins, got_pins)
        get_pins
        hands
        get_pins
        expect(sent).to eq(['refresh 2', 'get my pins from #2391122', 'get my pins from #2391122'])
      end

      it 'answers a refresh that raises with no id' do
        allow(inventory).to receive(:refresh).and_raise(IOError, 'gone')
        game('get my pins from #2391122', got_pins) { hands(right: pins) }
        expect(get_pins).to be(true)
        expect(sent).to eq(['get my pins from #2391122'])
      end
    end
  end

  describe '.check_consumables' do
    let(:count_ok) { 'The sepia pins has 12 uses remaining.' }

    before(:each) do
      allow(drct).to receive(:order_item) do |room, number|
        sent << "order #{number} at #{room}"
        hands(right: new_pins, left: half_made)
        'takes some coins from you'
      end
      allow(drct).to receive(:dispose) do |name|
        sent << "dispose #{name}"
        hands(left: half_made)
      end
    end

    def check
      described_class.check_consumables('pins', 'tool-room', 5, 'duffel bag', [], nil, 5)
    end

    it 'GETs, counts and puts back the remembered pins by id' do
      stow_pins
      game('get #4101800', got_pins) { hands(right: pins, left: half_made) }
      game('count #4101800', count_ok)
      game('put #4101800 in #2391122', put_pins) { hands(left: half_made) }
      expect(check).to be(true)
      expect(sent).to eq(['get #4101800', 'count #4101800', 'put #4101800 in #2391122', 'walk 8775'])
    end

    it 'falls back to the by-name GET before ordering when the id is stale' do
      stow_pins
      game('get #4101800', not_found)
      game('get my pins from #2391122', got_pins) { hands(right: new_pins, left: half_made) }
      game('count #4101801', count_ok)
      game('put #4101801 in #2391122', put_pins) { hands(left: half_made) }
      expect(check).to be(true)
      expect(sent).to eq(['get #4101800', 'get my pins from #2391122', 'count #4101801', 'put #4101801 in #2391122', 'walk 8775'])
    end

    it 'orders only after both the id and the name miss' do
      stow_pins
      game('get #4101800', could_not_find)
      game('get my pins from #2391122', could_not_find)
      game('put #4101801 in #2391122', put_pins) { hands(left: half_made) }
      expect(check).to be(true)
      expect(sent).to eq(['get #4101800', 'get my pins from #2391122', 'order 5 at tool-room', 'put #4101801 in #2391122', 'walk 8775'])
    end

    it 'returns false on "You need a free hand to do that." with no by-name GET and no order' do
      stow_pins
      hands(right: iron_pins, left: half_made)
      game('get #4101800', no_free_hand)
      expect(check).to be(false)
      expect(sent).to eq(['get #4101800'])
    end

    it 'forgets disposed pins and replaces them by name, not by the dead id' do
      stow_pins
      game('get #4101800', got_pins) { hands(right: pins, left: half_made) }
      game('count #4101800', 'The sepia pins has 2 uses remaining.')
      game('get my pins from #2391122', not_found)
      game('put #4101801 in #2391122', put_pins) { hands(left: half_made) }
      expect(check).to be(true)
      expect(sent).to eq(['get #4101800', 'count #4101800', 'dispose #4101800', 'get my pins from #2391122',
                          'order 5 at tool-room', 'put #4101801 in #2391122', 'walk 8775'])
      expect(memo.dead?('4101800')).to be(true)
    end

    it 'counts the id it got even when two pins are held' do
      stow_pins
      hands(right: iron_pins)
      game('get #4101800', got_pins) { hands(right: iron_pins, left: pins) }
      game('count #4101800', count_ok)
      # The PUT stays as L6 sends it: with two pins held, by name.
      game('put my pins in #2391122', put_pins) { hands(right: iron_pins) }
      expect(check).to be(true)
      expect(sent).to eq(['get #4101800', 'count #4101800', 'put my pins in #2391122', 'walk 8775'])
    end

    it 'takes the first GET from the feed' do
      hands
      feed([%w[4101800 some,sepia,pins]])
      game('get #4101800', got_pins) { hands(right: pins) }
      game('count #4101800', count_ok)
      game('put #4101800 in #2391122', put_pins) { hands }
      expect(check).to be(true)
      expect(sent).to eq(['get #4101800', 'count #4101800', 'put #4101800 in #2391122', 'walk 8775'])
    end
  end

  describe 'DRCI.stored_id' do
    before(:each) { feed([%w[4101800 some,sepia,pins], %w[4101850 a,linen,cloth]], in_pack: [%w[4101851 some,iron,pins]]) }

    let(:snapshot) { inventory.current }

    it 'finds the one match by the container id, with or without "#", String or Integer' do
      ['#2391122', '2391122', 2_391_122, ' #2391122 '].each do |container|
        expect(drci.stored_id('pins', container, snapshot: snapshot)).to eq('4101800')
      end
    end

    it 'drops a leading "my " and ignores case' do
      expect(drci.stored_id('my Sepia PINS', '#2391122', snapshot: snapshot)).to eq('4101800')
    end

    it 'gives nil for a nil snapshot, a nil name, a name container, or an unknown container' do
      expect(drci.stored_id('pins', '#2391122', snapshot: nil)).to be_nil
      expect(drci.stored_id(nil, '#2391122', snapshot: snapshot)).to be_nil
      expect(drci.stored_id('pins', 'duffel bag', snapshot: snapshot)).to be_nil
      expect(drci.stored_id('pins', '#999', snapshot: snapshot)).to be_nil
    end

    it 'gives nil for "other" and for a word that is not the noun' do
      expect(drci.stored_id('other pins', '#2391122', snapshot: snapshot)).to be_nil
      expect(drci.stored_id('sepia', '#2391122', snapshot: snapshot)).to be_nil
    end

    it 'gives nil for a locked container, whose contents are unknown' do
      inventory.observe("<inventoryManager id='imx' room='1'><i id='2391122' loc='worn,player' name=\"a heavy silk,duffel,bag\" " \
                        "weight='5' in_max='500' flags='closed,locked'/><i id='4101800' loc='in,2391122' name=\"some,sepia,pins\" weight='1'/>" \
                        '</inventoryManager>')
      expect(inventory.current['2391122']).to be_locked
      expect(drci.stored_id('pins', '#2391122', snapshot: inventory.current)).to be_nil
    end
  end

  # Named by a String so this file still loads (and its other examples run
  # and fail) on a tree without the memo.
  describe 'ItemIdMemo' do
    subject(:ids) { memo_class.new(3) }

    let(:memo_class) { described_class.const_get(:ItemIdMemo) }

    it 'drops the oldest pair past the cap' do
      4.times { |i| ids.remember(['#1', "item#{i}"], i.to_s) }
      expect(ids.size).to eq(3)
      expect(ids.fetch(['#1', 'item0'])).to be_nil
      expect(ids.fetch(['#1', 'item3'])).to eq('3')
    end

    it 'counts a re-remembered key as newest' do
      3.times { |i| ids.remember(['#1', "item#{i}"], i.to_s) }
      ids.remember(['#1', 'item0'], '0')
      ids.remember(['#1', 'item3'], '3')
      expect(ids.fetch(['#1', 'item0'])).to eq('0')
      expect(ids.fetch(['#1', 'item1'])).to be_nil
    end

    it 'keeps an id under its latest key only' do
      ids.remember(['#1', 'leather'], '7')
      ids.remember(['#1', 'duffel bag'], '7')
      expect(ids.fetch(['#1', 'leather'])).to be_nil
      expect(ids.fetch(['#1', 'duffel bag'])).to eq('7')
    end

    it 'bounds the dead ids too, and un-deads a remembered one' do
      5.times { |i| ids.forget(i.to_s) }
      expect(ids.dead?('0')).to be(false)
      expect(ids.dead?('4')).to be(true)
      ids.remember(['#1', 'pins'], '4')
      expect(ids.dead?('4')).to be(false)
    end

    it 'is the size of the cap at most under concurrent writers and readers' do
      shared = memo_class.new(described_class::CRAFTING_ITEM_IDS_MAX)
      errors = Queue.new
      threads = Array.new(8) do |t|
        Thread.new do
          500.times do |i|
            key = ['#2391122', "item#{t}-#{i % 40}"]
            shared.remember(key, "#{t}#{i % 40}")
            value = shared.fetch(key)
            errors << [key, value] unless value.nil? || value == "#{t}#{i % 40}"
            shared.forget("#{t}#{(i + 7) % 40}") if i.odd?
            shared.dead?("#{t}#{i % 40}")
          end
        rescue StandardError => e
          errors << e
        end
      end
      threads.each(&:join)
      expect(errors.size).to eq(0)
      expect(shared.size).to be <= described_class::CRAFTING_ITEM_IDS_MAX
    end

    it 'allows one feed refresh per interval' do
      expect(ids.feed_refresh_due?(300)).to be(true)
      expect(ids.feed_refresh_due?(300)).to be(false)
      ids.clear
      expect(ids.feed_refresh_due?(0)).to be(true)
      expect(ids.feed_refresh_due?(0)).to be(true)
    end
  end
end
