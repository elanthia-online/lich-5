# frozen_string_literal: true

require_relative '../spec_helper'
require 'stash'

module Kernel
  def dothistimeout(_action, _timeout, _success_line); end unless method_defined?(:dothistimeout)
end

# A GameObj the production code recognises as one (is_a? GameObj), with the
# readers Stash touches. spec_helper's MockGameObj is not a GameObj subclass.
class StashItem < Lich::Common::GameObj
  attr_accessor :id, :noun, :name, :type

  def initialize(id: nil, noun: nil, name: 'Empty', type: nil)
    super(id, noun, name)
    @type = type
  end
end

# The inventory tree as Stash sees it: a snapshot answering [] and all, holding
# items that know their parent and their closed / locked flags.
InvItem = Struct.new(:id, :noun, :name, :parent_item, :flags, :relation, keyword_init: true) do
  def closed? = flags.include?('closed')
  def locked? = flags.include?('locked')
  def in_room? = relation == 'room'
  def at_feet? = relation == 'atfeet'
end

class FakeInventory
  attr_accessor :items, :refreshes

  def initialize(items = [])
    @items = items
    @refreshes = 0
  end

  def refresh(*) = (@refreshes += 1; self)
  def current = self
  def [](id) = @items.find { |i| i.id == id.to_s }
  def all = @items
end

RSpec.describe Lich::Stash, 'named items' do
  let(:sword)  { StashItem.new(id: '101', noun: 'broadsword', name: 'vultite hand-forged broadsword', type: 'weapon') }
  let(:dagger) { StashItem.new(id: '102', noun: 'dagger', name: 'steel dagger', type: 'weapon') }
  let(:shield) { StashItem.new(id: '103', noun: 'shield', name: 'steel shield', type: 'shield') }
  let(:cloak)  { StashItem.new(id: '104', noun: 'cloak', name: 'black cloak', type: 'clothing') }
  let(:sack)   { StashItem.new(id: '105', noun: 'sack', name: 'leather sack', type: 'container') }
  let(:empty)  { StashItem.new }

  let(:ready_list) { { weapon: nil, shield: nil, sheath: nil } }

  before do
    GameObj.clear_hands
    allow(GameObj).to receive(:inv).and_return([cloak, sack, shield])
    allow(GameObj).to receive(:containers).and_return({ '105' => [sword, dagger] })
    allow(GameObj).to receive(:[]) { |id| [sword, dagger, shield, cloak, sack].find { |o| o.id == id.to_s } }

    stub_const('Lich::Gemstone::ReadyList', Class.new do
      class << self
        attr_accessor :ready_list, :valid

        def valid?(*) = valid
        def check(*); end
      end
    end)
    Lich::Gemstone::ReadyList.ready_list = ready_list
    Lich::Gemstone::ReadyList.valid = true
    stub_const('ReadyList', Lich::Gemstone::ReadyList)

    allow(described_class).to receive(:waitrt?)
    allow(described_class).to receive(:dothistimeout)
    allow(described_class).to receive(:stash_hands)
    allow(described_class).to receive(:sleep)
    stub_const('Lich::Common::Inventory', inventory)
  end

  let(:inventory) { FakeInventory.new }

  # Make the next fput of `command` land `item` in `hand`, the way the game would.
  def on_fput(command, item, hand)
    allow(described_class).to receive(:fput).with(command) do
      hand == :right ? GameObj.set_right_hand(item) : GameObj.set_left_hand(item)
    end
  end

  describe '.find_item' do
    it 'returns a GameObj untouched' do
      expect(described_class.find_item(sword)).to be(sword)
    end

    it 'looks an id up as a string or integer' do
      expect(described_class.find_item('102')).to be(dagger)
      expect(described_class.find_item(102)).to be(dagger)
    end

    it 'matches a name case-insensitively with non-adjacent words' do
      expect(described_class.find_item('Vultite Broadsword')).to be(sword)
    end

    it 'searches hands, worn items, and known container contents' do
      GameObj.set_right_hand(dagger)
      expect(described_class.find_item('dagger').id).to eq('102')
      expect(described_class.find_item('cloak')).to be(cloak)
      expect(described_class.find_item('broadsword')).to be(sword)
    end

    it 'resolves a ready-list slot' do
      ready_list[:weapon] = sword
      expect(described_class.find_item(:weapon)).to be(sword)
    end

    it 'checks the ready list first when it is stale' do
      Lich::Gemstone::ReadyList.valid = false
      expect(Lich::Gemstone::ReadyList).to receive(:check).with(silent: true, quiet: true)
      described_class.find_item(:weapon, loud_fail: false)
    end

    it 'raises on an unknown slot' do
      expect { described_class.find_item(:hat) }.to raise_error(RuntimeError, /unknown ready-list slot/)
    end

    it 'raises when a name matches more than one item' do
      expect { described_class.find_item('steel') }.to raise_error(RuntimeError, /matches 2 items/)
    end

    it 'raises when nothing matches, or returns nil when asked not to' do
      expect { described_class.find_item('halberd') }.to raise_error(RuntimeError, /could not find/)
      expect(described_class.find_item('halberd', loud_fail: false)).to be_nil
    end
  end

  describe '.hand_holding / .in_hand?' do
    it 'reports which hand holds the item' do
      GameObj.set_left_hand(shield)
      expect(described_class.hand_holding(shield)).to eq(:left)
      expect(described_class.hand_holding(sword)).to be_nil
      expect(described_class.in_hand?(shield)).to be true
      expect(described_class.in_hand?('103')).to be true
    end
  end

  describe '.wield' do
    it 'is a no-op when the item is already in a hand and no hand was asked for' do
      GameObj.set_left_hand(sword)
      expect(described_class).not_to receive(:fput)
      expect(described_class.wield('broadsword').id).to eq('101')
    end

    it 'swaps when the item is in the other hand' do
      GameObj.set_left_hand(sword)
      expect(described_class).to receive(:dothistimeout).with('swap', 3, anything) do
        GameObj.set_right_hand(sword)
        GameObj.set_left_hand(empty)
      end
      expect(described_class.wield('broadsword', hand: :right).id).to eq('101')
    end

    it 'fetches from a container by id without opening when it is open' do
      inventory.items = [InvItem.new(id: '105', noun: 'sack', name: 'leather sack', flags: []),
                         InvItem.new(id: '101', noun: 'broadsword', name: 'vultite hand-forged broadsword', flags: [])]
      inventory.items[1].parent_item = inventory.items[0]
      expect(described_class).not_to receive(:dothistimeout)
      on_fput('get #101', sword, :right)
      expect(described_class.wield('broadsword').id).to eq('101')
      expect(GameObj.right_hand.id).to eq('101')
    end

    context 'with closed containers' do
      let(:chest) { InvItem.new(id: '200', noun: 'chest', name: 'oak chest', flags: ['closed']) }
      let(:pouch) { InvItem.new(id: '201', noun: 'pouch', name: 'silk pouch', flags: ['closed'], parent_item: nil) }
      let(:gem)   { StashItem.new(id: '202', noun: 'ruby', name: 'blood-red ruby', type: 'gem') }

      before do
        pouch.parent_item = chest
        inventory.items = [chest, pouch, InvItem.new(id: '202', noun: 'ruby', name: 'blood-red ruby', flags: [], parent_item: pouch)]
        allow(GameObj).to receive(:[]) { |id| ([sword, dagger, shield, cloak, sack, gem]).find { |o| o.id == id.to_s } }
      end

      it 'opens each closed container on the way, outermost first, then gets' do
        expect(described_class).to receive(:dothistimeout).with('open #200', 3, described_class::OPEN_CONFIRM).ordered.and_return('You open an oak chest.')
        expect(described_class).to receive(:dothistimeout).with('open #201', 3, described_class::OPEN_CONFIRM).ordered.and_return('You open a silk pouch.')
        on_fput('get #202', gem, :right)
        expect(described_class.wield(gem).id).to eq('202')
      end

      it 'treats "already open" as open' do
        chest.flags.clear
        allow(described_class).to receive(:dothistimeout).with('open #201', anything, anything).and_return('That is already open.')
        on_fput('get #202', gem, :right)
        expect(described_class.wield(gem).id).to eq('202')
      end

      it 'raises without sending get when a container is locked' do
        chest.flags << 'locked'
        expect(described_class).not_to receive(:fput)
        expect { described_class.wield(gem) }.to raise_error(RuntimeError, /locked or would not open/)
      end

      it 'raises when the open is refused' do
        allow(described_class).to receive(:dothistimeout).with('open #200', anything, anything).and_return("You can't open that.")
        expect { described_class.wield(gem) }.to raise_error(RuntimeError, /locked or would not open/)
      end

      it 'finds an item by name that only the inventory tree knows about' do
        expect(described_class.find_item('blood-red ruby').id).to eq('202')
        expect(inventory.refreshes).to eq(1)
      end
    end

    it 'refreshes, opens, and retries once when the item does not arrive' do
      sack_entry = InvItem.new(id: '105', noun: 'sack', name: 'leather sack', flags: [])
      inventory.items = [sack_entry, InvItem.new(id: '101', noun: 'broadsword', name: 'vultite hand-forged broadsword', flags: [], parent_item: sack_entry)]
      calls = 0
      allow(described_class).to receive(:fput).with('get #101') do
        calls += 1
        GameObj.set_right_hand(sword) if calls == 2
      end
      # The refresh after the first miss is what reveals the sack was closed meanwhile.
      allow(inventory).to receive(:refresh) { sack_entry.flags = ['closed']; inventory }
      expect(described_class).to receive(:dothistimeout).with('open #105', anything, anything).and_return('You open a leather sack.')
      expect(described_class.wield(sword).id).to eq('101')
      expect(calls).to eq(2)
    end

    it 'removes a worn item instead of getting it' do
      ready_list[:shield] = shield
      on_fput('remove #103', shield, :left)
      expect(described_class.wield(:shield, hand: :left).id).to eq('103')
    end

    it 'empties the target hand first when it is occupied' do
      GameObj.set_right_hand(dagger)
      expect(described_class).to receive(:stash_hands).with(right: true) { GameObj.set_right_hand(empty) }
      on_fput('get #101', sword, :right)
      described_class.wield(sword, hand: :right)
    end

    it 'frees the right hand when both are full and no hand was asked for' do
      GameObj.set_right_hand(dagger)
      GameObj.set_left_hand(shield)
      expect(described_class).to receive(:stash_hands).with(right: true) { GameObj.set_right_hand(empty) }
      on_fput('get #101', sword, :right)
      described_class.wield(sword)
    end

    it 'swaps after fetching when the game put it in the wrong hand' do
      on_fput('get #101', sword, :right)
      expect(described_class).to receive(:dothistimeout).with('swap', 3, anything) do
        GameObj.set_left_hand(sword)
        GameObj.set_right_hand(empty)
      end
      expect(described_class.wield(sword, hand: :left).id).to eq('101')
    end

    it 'raises when the item never arrives, after one refresh and retry' do
      allow(described_class).to receive(:fput)
      expect { described_class.wield(sword) }.to raise_error(RuntimeError, /did not arrive/)
      expect(inventory.refreshes).to eq(1)
    end

    it 'rejects a bad hand' do
      expect { described_class.wield(sword, hand: :both) }.to raise_error(RuntimeError, /hand must be/)
    end
  end

  describe '.hands' do
    it 'leaves both hands alone by default' do
      GameObj.set_right_hand(dagger)
      expect(described_class).not_to receive(:fput)
      expect(described_class).not_to receive(:stash_hands)
      result = described_class.hands
      expect(result[:right]).to have_attributes(id: '102')
      expect(result[:left]).to be_nil
    end

    it 'empties a hand given nil' do
      GameObj.set_right_hand(dagger)
      expect(described_class).to receive(:stash_hands).with(right: true) { GameObj.set_right_hand(empty) }
      expect(described_class.hands(right: nil)[:right]).to be_nil
    end

    it 'wields into each hand' do
      on_fput('get #101', sword, :right)
      on_fput('remove #103', shield, :left)
      result = described_class.hands(right: 'broadsword', left: 'steel shield')
      expect(result[:right].id).to eq('101')
      expect(result[:left].id).to eq('103')
    end

    it 'swaps once when the two wanted items are in each other\'s hands' do
      GameObj.set_right_hand(shield)
      GameObj.set_left_hand(sword)
      expect(described_class).to receive(:dothistimeout).with('swap', 3, anything).once do
        GameObj.set_right_hand(sword)
        GameObj.set_left_hand(shield)
      end
      expect(described_class).not_to receive(:fput)
      described_class.hands(right: sword, left: shield)
    end

    it 'resolves names before touching anything, so an ambiguous name changes nothing' do
      GameObj.set_right_hand(dagger)
      expect(described_class).not_to receive(:stash_hands)
      expect { described_class.hands(right: nil, left: 'steel') }.to raise_error(RuntimeError, /matches 2 items/)
    end
  end
end
