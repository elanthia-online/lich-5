# frozen_string_literal: true

require_relative '../../spec_helper'
require 'tmpdir'
require_relative '../../../lib/common/gameobj'
require_relative '../../../lib/common/inventory'

# A top-level Game stub so Inventory.refresh has something to send through.
# In the full engine this resolves to the concrete GameBase::Game; here we only
# need an object that responds to ._puts so the handshake can be exercised.
module Game
  def self._puts(_str); end
end unless defined?(Game)

# End-to-end behavior of the Inventory read model against the REAL 418-item
# DragonRealms capture in spec/fixtures/inventory/, plus the hand-built edge
# cases the wire lets us trust (truncation, continuations, cycles, empties).
RSpec.describe Lich::Common::Inventory do
  # The authoritative wire capture: one <inventoryManager> line, 418 <i> items,
  # 42 worn / 1 in room / 5 on / 370 in, 21 locked containers, the weight-
  # nullifying eddy, and a max-less ring-holder. Real ground truth, not a mock.
  let(:full_capture) do
    File.read(File.join(FIXTURE_DIR, 'inventory', 'dr_full_inventory.xml'))
  end

  # Notable exist ids within the capture, used across examples.
  let(:lootpouch_id)  { '40236126' } # worn, in_max=1700 -> 170 lb cap, 7 children, no in_encum
  let(:eddy_id)       { '40235966' } # worn, in_encum=0 (weight-nullifying), in_max=17000
  let(:tyrium_hand_id) { '40235982' } # worn, NO max, 5 rings worn ON it
  let(:trunk_id)      { '40236132' } # locked treasure box: 0 children, in_max=400
  let(:folio_id)      { '40236052' } # merely closed (unlocked): 1 child enumerated
  let(:folio_child_id) { '40236053' }
  let(:fount_id)      { '34491' }    # loc='room'
  let(:sentinel_id)   { '40235999' } # worn, in_max=99990 (no-weight-limit sentinel)
  let(:hematite_id)   { '40236133' } # a plain leaf, weight 1

  before do
    allow(Lich).to receive(:log)
    # The type/sellable bridge pools identity via GameObj.index_or_create, so
    # isolate GameObj's shared index and classification cache between examples.
    %i[@@index @@type_cache].each do |cv|
      Lich::Common::GameObj.class_variable_get(cv).clear if Lich::Common::GameObj.class_variable_defined?(cv)
    end
    described_class.reset!
  end

  # ---------------------------------------------------------------------------
  # Parsing a real capture into the data model
  # ---------------------------------------------------------------------------
  describe 'parsing the full capture' do
    before { described_class.observe(full_capture) }

    it 'indexes every item in the response' do
      expect(described_class.all.size).to eq(418)
    end

    it 'collects worn items into the worn bucket' do
      expect(described_class.worn.size).to eq(42)
      expect(described_class.worn).to all(be_worn)
    end

    it 'collects the single ground item into the room bucket' do
      expect(described_class.room.map(&:id)).to eq([fount_id])
      expect(described_class[fount_id]).to be_in_room
    end

    it 'records the envelope room id as metadata' do
      expect(described_class.room_id).to eq('230007')
    end

    it 'parses identity fields for an item' do
      pack = described_class[lootpouch_id]
      expect(pack.noun).to eq('lootpouch')
      expect(pack.name).to eq('a leather lootpouch')
      expect(pack.long).to eq('a punka leather lootpouch')
      expect(pack.weight).to eq(10)
    end

    it 'decodes XML entities in the long description' do
      folio = described_class[folio_id]
      expect(folio.long).to include('"Warrior Mage"')
    end

    it 'links a nested item to its parent' do
      scroll = described_class[folio_child_id]
      expect(scroll.parent_id).to eq(folio_id)
      expect(scroll.parent_item).to eq(described_class[folio_id])
    end
  end

  # ---------------------------------------------------------------------------
  # Container classification and capacity/weight math
  # ---------------------------------------------------------------------------
  describe 'container facets' do
    before { described_class.observe(full_capture) }

    it 'treats an item with a weight limit as a container' do
      expect(described_class[lootpouch_id]).to be_container
    end

    it 'treats a max-less holder with children as a container' do
      hand = described_class[tyrium_hand_id]
      expect(hand).to be_container
      expect(hand.capacity_lbs).to be_nil
    end

    it 'treats a plain object with neither children nor a max as not a container' do
      expect(described_class[hematite_id]).not_to be_container
    end

    it 'converts in_max to a pound capacity' do
      expect(described_class[lootpouch_id].capacity_lbs).to eq(170)
    end

    it 'treats the 99990 in_max as a no-weight-limit sentinel (nil capacity)' do
      expect(described_class[sentinel_id].capacity_lbs).to be_nil
    end

    it 'sums direct children weight for used_lbs when there is no in_encum' do
      expect(described_class[lootpouch_id].used_lbs).to eq(84)
    end

    it 'prefers in_encum for used_lbs (a weight-nullifying container reads 0)' do
      expect(described_class[eddy_id].used_lbs).to eq(0)
    end

    it 'computes space_left from capacity and used weight' do
      expect(described_class[lootpouch_id].space_left).to eq(170 - 84)
    end

    it 'returns nil space_left when capacity is unknown (no crash)' do
      hand = described_class[tyrium_hand_id]
      expect(hand.used_lbs).to eq(5)
      expect(hand.space_left).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # Closed vs locked (they differ) -- spec section 5
  # ---------------------------------------------------------------------------
  describe 'closed vs locked containers' do
    before { described_class.observe(full_capture) }

    it 'enumerates the contents of a merely-closed (unlocked) container' do
      folio = described_class[folio_id]
      expect(folio).to be_closed
      expect(folio).not_to be_locked
      expect(folio.contents.map(&:id)).to eq([folio_child_id])
    end

    it 'treats a locked container as opaque, never empty' do
      trunk = described_class[trunk_id]
      expect(trunk).to be_locked
      expect(trunk).to be_opaque
      expect(trunk.contents).to eq([])
    end

    it 'reports nil used_lbs and space_left for a locked container' do
      trunk = described_class[trunk_id]
      expect(trunk.used_lbs).to be_nil
      expect(trunk.space_left).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # contents relation filtering
  # ---------------------------------------------------------------------------
  describe '#contents relation filtering' do
    before { described_class.observe(full_capture) }

    it 'returns items worn ON a holder for contents(:on)' do
      hand = described_class[tyrium_hand_id]
      expect(hand.contents(:on).size).to eq(5)
      expect(hand.contents(:in)).to eq([])
    end

    it 'returns all children regardless of relation when unfiltered' do
      hand = described_class[tyrium_hand_id]
      expect(hand.contents.size).to eq(5)
    end
  end

  # ---------------------------------------------------------------------------
  # Recursive carried weight
  # ---------------------------------------------------------------------------
  describe '#total_weight' do
    before { described_class.observe(full_capture) }

    it 'short-circuits a weight-nullifying container to its own weight' do
      # The eddy weighs 10 lb; its heavy contents do not count (in_encum=0).
      expect(described_class[eddy_id].total_weight).to eq(10)
    end

    it 'sums a container subtree that has no in_encum' do
      # tyrium hand (2 lb) + 5 rings (1 lb each) = 7 lb.
      expect(described_class[tyrium_hand_id].total_weight).to eq(7)
    end
  end

  # ---------------------------------------------------------------------------
  # Query API
  # ---------------------------------------------------------------------------
  describe 'query API' do
    before { described_class.observe(full_capture) }

    it 'finds an item anywhere by noun substring' do
      expect(described_class.find('hematite')&.id).to eq(hematite_id)
    end

    it 'finds an item anywhere by regexp' do
      expect(described_class.find(/lootpouch/)&.id).to eq(lootpouch_id)
    end

    it 'returns nil when nothing matches find' do
      expect(described_class.find('nonexistent-xyzzy')).to be_nil
    end

    it 'filters by exact noun with where' do
      # Five rings worn ON the tyrium hand plus two worn directly (a gloomwood
      # ring and the lockpick ring) -- where searches the whole tree, not one
      # container.
      rings = described_class.where(noun: 'ring')
      expect(rings.size).to eq(7)
    end

    it 'lists only containers' do
      expect(described_class.containers).to all(be_container)
      expect(described_class.containers).to include(described_class[lootpouch_id])
      expect(described_class.containers).not_to include(described_class[hematite_id])
    end
  end

  # ---------------------------------------------------------------------------
  # GameObj type/sellable bridge (m4): derived from the item's own noun/name,
  # NOT from GameObj[id] (which is nil for delta items in unopened containers).
  # ---------------------------------------------------------------------------
  describe 'type/sellable classification for a delta item' do
    let(:type_data) do
      <<~XML
        <data>
          <type name="weapon">
            <name>sword|blade</name>
            <noun>sword</noun>
          </type>
          <sellable name="gem">
            <name>diamond</name>
            <noun>diamond</noun>
          </sellable>
        </data>
      XML
    end

    it 'classifies an item that is absent from every GameObj registry' do
      Dir.mktmpdir do |dir|
        file = File.join(dir, 'gameobj-data.xml')
        File.write(file, type_data)
        stub_const('DATA_DIR', dir)
        Lich::Common::GameObj.load_data(file)

        described_class.observe(
          "<inventoryManager id='imx' room='1'>" \
          "<i id='999000' loc='worn,player' name=\"a,leather,pack\" weight='5' in_max='1000'/>" \
          "<i id='999001' loc='in,999000' name=\"a,steel,sword\" weight='10'/>" \
          "</inventoryManager>"
        )

        # The item is not registered anywhere in GameObj...
        expect(Lich::Common::GameObj['999001']).to be_nil
        # ...yet Inventory still classifies it from its own noun/name.
        expect(described_class['999001'].type).to include('weapon')
      end
    end

    it 'classifies via full_name using the long description' do
      # 'ancient runescored' appears ONLY in the long, and this type entry keys
      # solely on full_name. Classification succeeds only because the bridge
      # feeds the long-derived name (with the article split into before_name so
      # GameObj#full_name reconstructs the whole phrase) -- the short "an amulet"
      # would never match.
      Dir.mktmpdir do |dir|
        file = File.join(dir, 'gameobj-data.xml')
        File.write(file, <<~XML)
          <data>
            <type name="relic">
              <full_name>ancient runescored</full_name>
            </type>
          </data>
        XML
        stub_const('DATA_DIR', dir)
        Lich::Common::GameObj.load_data(file)

        described_class.observe(
          "<inventoryManager id='imx' room='1'>" \
          "<i id='888001' loc='worn,player' name=\"an,,amulet\" " \
          "long=\"an ancient runescored amulet\" weight='1'/>" \
          "</inventoryManager>"
        )

        expect(described_class['888001'].type).to include('relic')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # observe as a read-only tap
  # ---------------------------------------------------------------------------
  describe '.observe read-only contract' do
    it 'returns the server string unchanged' do
      expect(described_class.observe(full_capture)).to equal(full_capture)
    end

    it 'ignores strings that are not an inventoryManager response' do
      described_class.observe('<prompt time="123">&gt;</prompt>')
      expect(described_class.all).to eq([])
      expect(described_class.feed_available?).to be(false)
    end

    it 'passively absorbs a complete initial response' do
      described_class.observe(full_capture)
      expect(described_class.feed_available?).to be(true)
      expect(described_class.all.size).to eq(418)
      expect(described_class.last_updated).to be_a(Time)
      expect(described_class.age).to be >= 0
    end
  end

  # ---------------------------------------------------------------------------
  # Fail-closed behavior (M2 truncation, continuations, empties)
  # ---------------------------------------------------------------------------
  describe '.observe fail-closed behavior' do
    it 'discards a truncated line rather than absorbing a partial tree' do
      truncated = full_capture[0, 20_000] # cut mid-stream, no closing tag
      described_class.observe(truncated)
      expect(described_class.all).to eq([])
    end

    it 'keeps the prior snapshot when a truncated line arrives' do
      described_class.observe(full_capture)
      described_class.observe(full_capture[0, 20_000])
      expect(described_class.all.size).to eq(418)
    end

    it 'discards a response missing its closing tag even if Ox does not error' do
      described_class.observe("<inventoryManager id='x' room='1'><i id='1' loc='worn,player' name=\"a,,thing\" weight='1'/>")
      expect(described_class.all).to eq([])
    end

    it 'never treats a continuation fragment (root/after envelope) as a full snapshot' do
      described_class.observe(full_capture)
      described_class.observe("<inventoryManager id='x' room='1' root='5' after='9'><i id='1' loc='worn,player' name=\"a,,thing\" weight='1'/></inventoryManager>")
      expect(described_class.all.size).to eq(418)
    end

    it 'never absorbs a paginated response that carries a continuation child' do
      described_class.observe(full_capture)
      described_class.observe("<inventoryManager id='x' room='1'><i id='1' loc='worn,player' name=\"a,,thing\" weight='1'/><continuation root='5' last='9'/></inventoryManager>")
      expect(described_class.all.size).to eq(418)
    end

    it 'does not let a zero-item passive response overwrite a non-empty snapshot' do
      described_class.observe(full_capture)
      described_class.observe("<inventoryManager id='y' room='1'></inventoryManager>")
      expect(described_class.all.size).to eq(418)
    end

    it 'handles a self-closing empty envelope without raising' do
      expect { described_class.observe("<inventoryManager id='z' room='1'/>") }.not_to raise_error
      expect(described_class.all).to eq([])
    end
  end

  # ---------------------------------------------------------------------------
  # Crash safety (M1): observe must never raise onto the parser thread.
  # ---------------------------------------------------------------------------
  describe '.observe crash safety' do
    it 'swallows an unexpected build error and keeps the prior snapshot' do
      described_class.observe(full_capture)
      allow(described_class).to receive(:build_snapshot).and_raise(StandardError, 'boom')

      expect { described_class.observe(full_capture) }.not_to raise_error
      expect(described_class.all.size).to eq(418)
    end
  end

  # ---------------------------------------------------------------------------
  # Cycle/orphan safety in the tree traversal
  # ---------------------------------------------------------------------------
  describe 'cyclic loc safety' do
    let(:cyclic) do
      "<inventoryManager id='c' room='1'>" \
      "<i id='1' loc='in,2' name=\"a,,ouroboros\" weight='3' in_max='100'/>" \
      "<i id='2' loc='in,1' name=\"a,,ouroboros\" weight='3' in_max='100'/>" \
      "</inventoryManager>"
    end

    it 'absorbs a self-referential loc without hanging' do
      expect { described_class.observe(cyclic) }.not_to raise_error
      expect(described_class['1']).not_to be_nil
    end

    it 'terminates total_weight on a cycle' do
      described_class.observe(cyclic)
      expect { described_class['1'].total_weight }.not_to raise_error
    end
  end

  # ---------------------------------------------------------------------------
  # refresh handshake (m11) + immutability + timeout + feed-absent backoff (m7)
  # ---------------------------------------------------------------------------
  describe '.refresh' do
    # Simulate the server: whatever id refresh sends, echo the full capture
    # back through observe with that id, inline, as if the server answered.
    def answer_with_capture
      allow(Game).to receive(:_puts) do |cmd|
        id = cmd[/_inventory manager (\S+)/, 1]
        described_class.observe(full_capture.sub(/id='[^']*'/, "id='#{id}'"))
      end
    end

    it 'sends the load verb and returns the snapshot for that id' do
      answer_with_capture
      snapshot = described_class.refresh(timeout: 2)
      expect(Game).to have_received(:_puts).with(/\A_inventory manager im/)
      expect(snapshot.all.size).to eq(418)
    end

    it 'returns an immutable snapshot the caller can hold across later swaps' do
      answer_with_capture
      snapshot = described_class.refresh(timeout: 2)

      # A later passive response swaps the global snapshot...
      described_class.observe("<inventoryManager id='later' room='9'><i id='1' loc='worn,player' name=\"a,,thing\" weight='1'/></inventoryManager>")

      expect(described_class.all.size).to eq(1)  # global moved on
      expect(snapshot.all.size).to eq(418)       # returned object is stable
    end

    it 'returns nil when the response never arrives within the timeout' do
      allow(Game).to receive(:_puts) # no answer
      expect(described_class.refresh(timeout: 0.15)).to be_nil
    end

    context 'when the feed is structurally absent' do
      before do
        allow(Game).to receive(:_puts) # never answers
        allow(described_class).to receive(:monotonic_now).and_return(1_000.0)
      end

      it 'fast-fails without sending once consecutive probes have timed out' do
        described_class.refresh(timeout: 0.1) # timeout 1
        described_class.refresh(timeout: 0.1) # timeout 2 -> marks absent
        expect(Game).to have_received(:_puts).twice

        described_class.refresh(timeout: 0.1) # inside backoff window -> no send
        expect(Game).to have_received(:_puts).twice
      end

      it 're-probes once the backoff window elapses' do
        described_class.refresh(timeout: 0.1)
        described_class.refresh(timeout: 0.1) # marks absent until now + backoff
        allow(described_class).to receive(:monotonic_now).and_return(1_000.0 + 3_600)

        described_class.refresh(timeout: 0.1) # backoff elapsed -> probes again
        expect(Game).to have_received(:_puts).exactly(3).times
      end
    end

    it 'does not mark the feed absent after a response has already been seen' do
      described_class.observe(full_capture) # feed now known-present
      allow(Game).to receive(:_puts)        # a later refresh happens to time out

      described_class.refresh(timeout: 0.1)
      described_class.refresh(timeout: 0.1)

      expect(described_class.feed_available?).to be(true)
    end
  end

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------
  describe 'metadata' do
    it 'reports feed availability, age, and room id after a capture' do
      expect(described_class.feed_available?).to be(false)
      described_class.observe(full_capture)
      expect(described_class.feed_available?).to be(true)
      expect(described_class.room_id).to eq('230007')
      expect(described_class.age).to be_a(Float)
    end
  end
end
