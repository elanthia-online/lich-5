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
    # Inventory now mirrors snapshots into GameObj's registries, so isolate all of
    # GameObj's shared state between examples (mirrors gameobj_spec.rb).
    g = Lich::Common::GameObj
    %i[@@inv @@loot @@contents @@room_desc @@npcs @@pcs @@index @@type_cache].each do |cv|
      g.class_variable_get(cv).clear if g.class_variable_defined?(cv)
    end
    g.class_variable_set(:@@right_hand, nil)
    g.class_variable_set(:@@left_hand, nil)
    # Reset the classification data to its pristine "not yet loaded" state too.
    # The fixture-loading examples populate @@type_data/@@sellable_data via
    # load_data, and (unlike @@type_cache above) nothing else clears them, so
    # without this an example's outcome would depend on run order.
    g.class_variable_set(:@@type_data, {})
    g.class_variable_set(:@@sellable_data, {})
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

    it 'counts items nested inside child containers in used_lbs (no in_encum)' do
      # outer (no in_encum) holds a 3 lb sack that itself holds a 5 lb stone.
      # used_lbs must be the sack's effective total (3 + 5 = 8), not just its
      # intrinsic 3 -- otherwise space_left overstates free capacity.
      described_class.reset!
      described_class.observe(
        "<inventoryManager id='iw' room='1'>" \
        "<i id='90000' loc='worn,player' name=\"a,canvas,pack\" weight='2' in_max='1000'/>" \
        "<i id='90001' loc='in,90000' name=\"a,cloth,sack\" weight='3' in_max='500'/>" \
        "<i id='90002' loc='in,90001' name=\"a,granite,stone\" weight='5'/>" \
        "</inventoryManager>"
      )
      outer = described_class['90000']
      expect(outer.used_lbs).to eq(8)
      expect(outer.space_left).to eq(100 - 8)
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

    it 'registers a delta item into GameObj and classifies it from its own noun/name' do
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

        # The delta item (in an unopened container) is now mirrored into GameObj's
        # @@contents, so GameObj[id] resolves it...
        expect(Lich::Common::GameObj['999001']).not_to be_nil
        expect(Lich::Common::GameObj.containers['999000'].map(&:id)).to include('999001')
        # ...and Inventory classifies it from its own noun/name.
        expect(described_class['999001'].type).to include('weapon')
      end
    end

    # Wire->GameObj field mappings supplied by the GameObj author (mrhoribu).
    # Simu wraps the core noun phrase in $_..._$; text after it is after_name,
    # the leading article is dropped (before_name nil).
    describe 'wire-to-GameObj name/before/after mapping' do
      def bridge_for(item_xml)
        described_class.observe("<inventoryManager id='imx' room='1'>#{item_xml}</inventoryManager>")
        described_class[item_xml[/id='(\d+)'/, 1]].send(:bridge_gameobj)
      end

      it 'splits a $_ core name and trailing descriptor into name and after_name' do
        gobj = bridge_for(
          "<i id='165666521' loc='righthand,player' name=\"a gnarled,rowan,crook\" " \
          "long=\"a $_gnarled rowan crook$_ wound with knotted yarn\" weight='2'/>"
        )
        expect(gobj.noun).to eq('crook')
        expect(gobj.name).to eq('gnarled rowan crook')
        expect(gobj.before_name).to be_nil
        expect(gobj.after_name).to eq('wound with knotted yarn')
      end

      it 'keeps a second $_ trailing descriptor as after_name' do
        gobj = bridge_for(
          "<i id='165666522' loc='worn,player' name=\"a voluminous,mist tartan,cloak\" " \
          "long=\"a $_voluminous mist tartan cloak$_ lined in silver-tipped aquerne\" weight='5' in_max='2500'/>"
        )
        expect(gobj.name).to eq('voluminous mist tartan cloak')
        expect(gobj.after_name).to eq('lined in silver-tipped aquerne')
      end

      it 'drops the leading article and leaves after_name nil when long has no markers' do
        gobj = bridge_for(
          "<i id='165666628' loc='worn,player' name=\"a tooled,leather coin,bag\" " \
          "long=\"a tooled leather drawstring coin bag\" weight='1'/>"
        )
        expect(gobj.noun).to eq('bag')
        expect(gobj.name).to eq('tooled leather drawstring coin bag')
        expect(gobj.before_name).to be_nil
        expect(gobj.after_name).to be_nil
      end

      it 'strips $_ highlight markers from the item long description' do
        described_class.observe(
          "<inventoryManager id='imx' room='1'>" \
          "<i id='165666521' loc='righthand,player' name=\"a gnarled,rowan,crook\" " \
          "long=\"a $_gnarled rowan crook$_ wound with knotted yarn\" weight='2'/>" \
          "</inventoryManager>"
        )
        expect(described_class['165666521'].long).to eq('a gnarled rowan crook wound with knotted yarn')
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
  # Relation-based buckets across the full DR vocabulary (real captured items:
  # skate in right hand, rapier in left hand, jade bowl at feet, lollipop on the
  # shared room ground, a worn pack).
  # ---------------------------------------------------------------------------
  describe 'location buckets' do
    let(:mixed_locations) do
      "<inventoryManager id='imq' room='230008'>" \
      "<i id='41032122' loc='righthand,player' name=\"some,ice,skates\" " \
      "long=\"some powdery blue jaguar-pelt ice skates with watered steel blades\" weight='5'/>" \
      "<i id='41032123' loc='lefthand,player' name=\"a,bronze,rapier\" weight='22'/>" \
      "<i id='41032124' loc='atfeet,player' name=\"a large,jade,bowl\" " \
      "long=\"a large jade bowl painted with lilac blossoms\" weight='20' in_max='1000'/>" \
      "<i id='41032121' loc='room' name=\"an enormous,Albreda,lollipop\" " \
      "long=\"an enormous slate Albreda lollipop covered in iridescent sugar crystals\" weight='1'/>" \
      "<i id='99001' loc='worn,player' name=\"a,leather,pack\" weight='10' in_max='1000'/>" \
      "</inventoryManager>"
    end

    before { described_class.observe(mixed_locations) }

    it 'puts only worn-relation items in the worn bucket (not hands or feet)' do
      expect(described_class.worn.map(&:id)).to eq(['99001'])
    end

    it 'exposes the right- and left-hand items' do
      expect(described_class.right_hand.id).to eq('41032122')
      expect(described_class.left_hand.id).to eq('41032123')
    end

    it 'does not treat a held item as worn' do
      skate = described_class['41032122']
      expect(skate).to be_in_right_hand
      expect(skate).to be_held
      expect(skate).not_to be_worn
    end

    it 'separates at-feet items from shared room-ground items' do
      expect(described_class.at_feet.map(&:id)).to eq(['41032124'])
      expect(described_class.room.map(&:id)).to eq(['41032121'])
      expect(described_class['41032124']).to be_at_feet
      expect(described_class['41032121']).to be_in_room
    end

    it 'counts held items in carried weight but not ground items' do
      # worn pack 10 + right-hand skate 5 + left-hand rapier 22 = 37; the jade
      # bowl (at feet) and lollipop (room ground) are not carried.
      expect(described_class.total_weight).to eq(37)
    end
  end

  # ---------------------------------------------------------------------------
  # GameObj mirror (Full integration): each relation lands in its GameObj home.
  # ---------------------------------------------------------------------------
  describe 'GameObj registry mirroring' do
    let(:game_obj) { Lich::Common::GameObj }

    before do
      described_class.observe(
        "<inventoryManager id='img' room='1'>" \
        "<i id='70001' loc='worn,player' name=\"a,leather,pack\" weight='10' in_max='1000'/>" \
        "<i id='70002' loc='in,70001' name=\"a,steel,dagger\" weight='5'/>" \
        "<i id='70003' loc='righthand,player' name=\"a,bronze,rapier\" weight='22'/>" \
        "<i id='70004' loc='lefthand,player' name=\"a,wooden,shield\" weight='30'/>" \
        "<i id='70005' loc='room' name=\"a,steel,bar\" weight='20'/>" \
        "<i id='70006' loc='atfeet,player' name=\"a,jade,bowl\" weight='20' in_max='1000'/>" \
        "</inventoryManager>"
      )
    end

    it 'nests in/on children under GameObj.contents (the real GameObj gap)' do
      expect(game_obj.containers['70001'].map(&:id)).to eq(['70002'])
    end

    it 'places worn items in GameObj.inv' do
      expect(game_obj.inv.map(&:id)).to include('70001')
    end

    it 'does NOT mirror hands into GameObj (classic <right>/<left> owns them)' do
      expect(game_obj.right_hand).to be_nil
      expect(game_obj.left_hand).to be_nil
    end

    it 'does NOT mirror room or at-feet items into GameObj.loot (classic room-objs owns it)' do
      # Both hands are dropped and loot is left to the classic room-objs stream;
      # room/at-feet items surface only via Inventory's own accessors.
      expect(game_obj.loot.to_a.map(&:id)).not_to include('70005', '70006')
      expect(described_class.room.map(&:id)).to eq(['70005'])
      expect(described_class.at_feet.map(&:id)).to eq(['70006'])
    end

    it 'still classifies a non-mirrored item via its pooled identity GameObj' do
      # Hands/room are not placed in a live registry, but are pooled via
      # index_or_create so the item still resolves and type/sellable still work
      # without raising.
      rapier = described_class['70003']
      expect(rapier.noun).to eq('rapier')
      expect { rapier.type }.not_to raise_error
    end

    it 'does not duplicate a worn item the classic stream already registered' do
      # Classic stream registered this exist id first, under a different name.
      game_obj.new_inv('80001', 'pack', 'a punka leather pack')
      described_class.observe(
        "<inventoryManager id='img2' room='1'>" \
        "<i id='80001' loc='worn,player' name=\"a,leather,pack\" weight='10' in_max='1000'/>" \
        "</inventoryManager>"
      )
      expect(game_obj.inv.count { |o| o.id == '80001' }).to eq(1)
    end
  end

  # ---------------------------------------------------------------------------
  # GameObj reconciliation (Option A): each snapshot ATOMICALLY wholesale-replaces
  # the two feed-owned registries (@@inv via begin_inv/commit_inv, each non-opaque
  # container via begin_container/commit_container), so moves/removals vanish after
  # the swap; opaque containers are preserved; vanished containers are deleted; and
  # an in-flight classic refresh for the same target is never truncated.
  # ---------------------------------------------------------------------------
  describe 'GameObj reconciliation across snapshots' do
    let(:game_obj) { Lich::Common::GameObj }

    def first_snapshot
      described_class.observe(
        "<inventoryManager id='s1' room='1'>" \
        "<i id='ca' loc='worn,player' name=\"a,leather,pack\" weight='10' in_max='1000'/>" \
        "<i id='cb' loc='worn,player' name=\"a,canvas,sack\" weight='8' in_max='1000'/>" \
        "<i id='x' loc='in,ca' name=\"a,steel,dagger\" weight='5'/>" \
        "<i id='w' loc='worn,player' name=\"a,silk,cloak\" weight='3' in_max='500'/>" \
        "</inventoryManager>"
      )
    end

    it 'moves an item to its new container and drops it from the old one' do
      first_snapshot
      expect(game_obj.containers['ca'].map(&:id)).to eq(['x'])

      # Second snapshot: 'x' has moved from container ca to container cb.
      described_class.observe(
        "<inventoryManager id='s2' room='1'>" \
        "<i id='ca' loc='worn,player' name=\"a,leather,pack\" weight='10' in_max='1000'/>" \
        "<i id='cb' loc='worn,player' name=\"a,canvas,sack\" weight='8' in_max='1000'/>" \
        "<i id='x' loc='in,cb' name=\"a,steel,dagger\" weight='5'/>" \
        "</inventoryManager>"
      )
      expect(game_obj.containers['ca'].map(&:id)).to eq([])
      expect(game_obj.containers['cb'].map(&:id)).to eq(['x'])
    end

    it 'drops a worn item the new snapshot no longer reports' do
      first_snapshot
      expect(game_obj.inv.map(&:id)).to include('w')

      described_class.observe(
        "<inventoryManager id='s2' room='1'>" \
        "<i id='ca' loc='worn,player' name=\"a,leather,pack\" weight='10' in_max='1000'/>" \
        "</inventoryManager>"
      )
      expect(game_obj.inv.map(&:id)).not_to include('w')
    end

    it 'wholesale-replaces @@inv from the feed (drops a classic worn entry the feed omits)' do
      # Under A the extended feed is authoritative for the complete worn set, so a
      # classic @@inv entry the feed does not report is evicted by the swap.
      first_snapshot
      game_obj.new_inv('classic-worn', 'ring', 'a plain ring')
      expect(game_obj.inv.map(&:id)).to include('classic-worn')

      described_class.observe(
        "<inventoryManager id='s2' room='1'>" \
        "<i id='ca' loc='worn,player' name=\"a,leather,pack\" weight='10' in_max='1000'/>" \
        "</inventoryManager>"
      )
      expect(game_obj.inv.map(&:id)).to eq(['ca'])
    end

    it 'preserves a container that turned opaque (locked) rather than emptying it' do
      described_class.observe(
        "<inventoryManager id='s1' room='1'>" \
        "<i id='lk' loc='worn,player' name=\"a,steel,coffer\" weight='5' in_max='400'/>" \
        "<i id='y' loc='in,lk' name=\"a,gold,coin\" weight='1'/>" \
        "</inventoryManager>"
      )
      expect(game_obj.containers['lk'].map(&:id)).to eq(['y'])

      # Now lk is locked -> opaque, reports zero children. Its last-known contents
      # must survive (not be wholesale-replaced with []).
      described_class.observe(
        "<inventoryManager id='s2' room='1'>" \
        "<i id='lk' loc='worn,player' name=\"a,steel,coffer\" weight='5' in_max='400' flags='closed,locked'/>" \
        "</inventoryManager>"
      )
      expect(game_obj.containers['lk'].map(&:id)).to eq(['y'])
    end

    it 'deletes a container that vanished from the tree entirely' do
      first_snapshot
      expect(game_obj.containers).to have_key('ca')

      # ca is gone from this snapshot (traded away / destroyed).
      described_class.observe(
        "<inventoryManager id='s2' room='1'>" \
        "<i id='cb' loc='worn,player' name=\"a,canvas,sack\" weight='8' in_max='1000'/>" \
        "</inventoryManager>"
      )
      expect(game_obj.containers).not_to have_key('ca')
    end

    it 'skips its @@inv replace while a classic inv refresh is open (no truncation)' do
      game_obj.begin_inv
      game_obj.new_inv('classic-staged', 'ring', 'a ring') # into @@staging_inv

      described_class.observe(
        "<inventoryManager id='s1' room='1'>" \
        "<i id='ca' loc='worn,player' name=\"a,leather,pack\" weight='10' in_max='1000'/>" \
        "</inventoryManager>"
      )
      # Inventory must NOT have committed/stomped the classic staging.
      expect(game_obj.inv_refresh_open?).to be(true)
      game_obj.commit_inv
      expect(game_obj.inv.map(&:id)).to eq(['classic-staged'])
    end

    it 'skips a container whose classic refresh is open (no truncation)' do
      game_obj.begin_container('cc')
      game_obj.new_inv('classic-child', 'gem', 'a gem', 'cc') # into @@staging_contents['cc']

      described_class.observe(
        "<inventoryManager id='s1' room='1'>" \
        "<i id='cc' loc='worn,player' name=\"a,mesh,pouch\" weight='2' in_max='300'/>" \
        "<i id='x2' loc='in,cc' name=\"a,steel,dagger\" weight='5'/>" \
        "</inventoryManager>"
      )
      # Inventory must NOT have committed/stomped the classic container staging.
      expect(game_obj.container_refresh_open?('cc')).to be(true)
      game_obj.commit_container('cc')
      expect(game_obj.containers['cc'].map(&:id)).to eq(['classic-child'])
    end

    it 'drops owned containers on reset!' do
      first_snapshot
      expect(game_obj.containers).to have_key('ca')

      described_class.reset!

      expect(game_obj.containers).not_to have_key('ca')
    end

    it 'defers deleting a vanished container while its classic refresh is open' do
      # Inventory owns container ca...
      first_snapshot
      expect(game_obj.containers).to have_key('ca')

      # ...the classic stream begins re-filling ca and stages a NEW child...
      game_obj.begin_container('ca')
      game_obj.new_inv('classic-child', 'gem', 'a gem', 'ca')

      # ...and a later snapshot omits ca entirely. The deletion loop must NOT abort
      # the in-flight classic staging (delete_container would drop @@staging_contents).
      described_class.observe(
        "<inventoryManager id='s2' room='1'>" \
        "<i id='cb' loc='worn,player' name=\"a,canvas,sack\" weight='8' in_max='1000'/>" \
        "</inventoryManager>"
      )
      expect(game_obj.container_refresh_open?('ca')).to be(true)
      game_obj.commit_container('ca')
      expect(game_obj.containers['ca'].map(&:id)).to eq(['classic-child'])
    end

    # A full INV LIST refresh owns EVERY container the instant it opens, but only
    # allocates a per-container staging buffer once an item line for that
    # container streams. A container the listing has not reached yet therefore
    # has no @@staging_contents key -- container_refresh_open? must still report
    # it as owned, or the observer publishes into / deletes it mid-refresh.
    it 'skips a container during an open full INV LIST refresh before it is streamed' do
      first_snapshot
      expect(game_obj.containers['ca'].map(&:id)).to eq(['x'])

      # INV LIST opens: owns all containers, but ca has not streamed yet.
      game_obj.begin_all_containers

      # A snapshot arrives mid-refresh reporting ca with different contents.
      described_class.observe(
        "<inventoryManager id='s2' room='1'>" \
        "<i id='ca' loc='worn,player' name=\"a,leather,pack\" weight='10' in_max='1000'/>" \
        "<i id='z' loc='in,ca' name=\"a,brass,key\" weight='1'/>" \
        "</inventoryManager>"
      )

      # The observer must defer to the open full refresh, leaving the live model
      # untouched rather than replacing ca's contents with z.
      expect(game_obj.container_refresh_open?('ca')).to be(true)
      expect(game_obj.containers['ca'].map(&:id)).to eq(['x'])
    end

    it 'defers deleting a container during an open full INV LIST refresh before it is streamed' do
      first_snapshot
      expect(game_obj.containers).to have_key('ca')

      # INV LIST opens: owns ca, but has not streamed it yet.
      game_obj.begin_all_containers

      # A snapshot omits ca entirely; the deletion loop must not drop it while the
      # full refresh (which will re-report ca) is still in flight.
      described_class.observe(
        "<inventoryManager id='s2' room='1'>" \
        "<i id='cb' loc='worn,player' name=\"a,canvas,sack\" weight='8' in_max='1000'/>" \
        "</inventoryManager>"
      )
      expect(game_obj.container_refresh_open?('ca')).to be(true)
      expect(game_obj.containers).to have_key('ca')
    end

    it 'preserves a descendant hidden behind an ancestor that turned opaque' do
      # A(pk) -> B(pouch) -> gem, all visible.
      described_class.observe(
        "<inventoryManager id='s1' room='1'>" \
        "<i id='pk' loc='worn,player' name=\"a,leather,pack\" weight='10' in_max='1000'/>" \
        "<i id='pouch' loc='in,pk' name=\"a,small,pouch\" weight='2' in_max='500'/>" \
        "<i id='gem' loc='in,pouch' name=\"a,shiny,gem\" weight='1'/>" \
        "</inventoryManager>"
      )
      expect(game_obj.containers['pouch'].map(&:id)).to eq(['gem'])

      # A is now locked (opaque): it reports zero children, so B and the gem are
      # simply absent -- unknowable, not confirmed gone. B's last-known contents
      # must survive rather than being deleted.
      described_class.observe(
        "<inventoryManager id='s2' room='1'>" \
        "<i id='pk' loc='worn,player' name=\"a,leather,pack\" weight='10' in_max='1000' flags='locked'/>" \
        "</inventoryManager>"
      )
      expect(game_obj.containers['pouch'].map(&:id)).to eq(['gem'])
    end

    it 'aborts only its own staging (never wedges it open) when a mirror write raises' do
      first_snapshot
      expect(game_obj.inv_refresh_open?).to be(false)

      # Injected fault: the SECOND worn registration this cycle raises.
      calls = 0
      allow(game_obj).to receive(:new_inv).and_wrap_original do |orig, *args|
        calls += 1
        raise 'injected mirror failure' if calls == 2

        orig.call(*args)
      end

      # observe must swallow it (parser-thread safety) and leave no half-open buffer.
      expect do
        described_class.observe(
          "<inventoryManager id='s2' room='1'>" \
          "<i id='r1' loc='worn,player' name=\"a,red,hat\" weight='1'/>" \
          "<i id='r2' loc='worn,player' name=\"a,blue,sock\" weight='1'/>" \
          "</inventoryManager>"
        )
      end.not_to raise_error
      expect(game_obj.inv_refresh_open?).to be(false)
    end
  end

  # ---------------------------------------------------------------------------
  # Snapshot immutability contract
  # ---------------------------------------------------------------------------
  describe 'published snapshot immutability' do
    before { described_class.observe(full_capture) }

    it 'freezes an item flags array so a consumer cannot mutate shared state' do
      trunk = described_class[trunk_id]
      expect(trunk.flags).to be_frozen
      expect { trunk.flags << 'tampered' }.to raise_error(FrozenError)
    end

    it 'freezes item identity strings' do
      pack = described_class[lootpouch_id]
      expect(pack.noun).to be_frozen
      expect(pack.name).to be_frozen
    end

    it 'freezes the snapshot room id so shared metadata cannot be mutated in place' do
      expect(described_class.current.room_id).to be_frozen
      expect { described_class.current.room_id.replace('changed') }.to raise_error(FrozenError)
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

    # Integrity checks the refresh path already enforces must also gate the passive
    # path, since observe writes the snapshot AND the GameObj registries directly on
    # the parser thread. Each of these must fail closed (keep the prior snapshot),
    # not absorb a malformed/stale response.

    it 'rejects a passive response whose state is stale (interrupted mid-build)' do
      described_class.observe(full_capture)
      described_class.observe(
        "<inventoryManager id='st' room='1' state='stale'>" \
        "<i id='1' loc='worn,player' name=\"a,,thing\" weight='1'/></inventoryManager>"
      )
      expect(described_class.all.size).to eq(418)
      expect(described_class['1']).to be_nil
    end

    it 'rejects a passive response with an unknown (non-nil) state' do
      described_class.observe(full_capture)
      described_class.observe(
        "<inventoryManager id='uk' room='1' state='rebuilding'>" \
        "<i id='1' loc='worn,player' name=\"a,,thing\" weight='1'/></inventoryManager>"
      )
      expect(described_class.all.size).to eq(418)
    end

    it 'rejects a passive response with a duplicate item id rather than collapsing it' do
      described_class.observe(full_capture)
      # Second occurrence would last-wins-overwrite the first, silently dropping the
      # worn placement; the whole response must be discarded instead.
      described_class.observe(
        "<inventoryManager id='dup' room='1'>" \
        "<i id='9' loc='worn,player' name=\"a,,pack\" weight='1'/>" \
        "<i id='9' loc='room' name=\"a,,pack\" weight='1'/></inventoryManager>"
      )
      expect(described_class.all.size).to eq(418)
      expect(described_class['9']).to be_nil
    end

    it 'rejects a passive response with an item that has no id' do
      described_class.observe(full_capture)
      described_class.observe(
        "<inventoryManager id='noid' room='1'>" \
        "<i loc='worn,player' name=\"a,,thing\" weight='1'/></inventoryManager>"
      )
      expect(described_class.all.size).to eq(418)
      expect(described_class.all.map(&:id)).not_to include(nil)
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
  # refresh lifecycle safety: cancellation and id reuse. Real threads with Queue
  # barriers (not sleeps) so we exercise actual parser/caller thread ownership.
  # ---------------------------------------------------------------------------
  describe 'refresh lifecycle safety' do
    it 'removes its routing state when the refresh thread is killed mid-exchange' do
      sent = Queue.new
      allow(Game).to receive(:_puts) { |cmd| sent << cmd }

      t = Thread.new { described_class.refresh(timeout: 30) }
      sent.pop # barrier: initial request sent -> the assembly is registered
      t.kill
      t.join

      expect(described_class.instance_variable_get(:@assemblies)).to be_empty
    end

    it 'never reuses a request id after reset!, even within the same clock second' do
      allow(described_class).to receive(:monotonic_now).and_return(1_000.0)
      ids = []
      allow(Game).to receive(:_puts) { |cmd| ids << cmd[/\bim\S+/] }

      Thread.new { described_class.refresh(timeout: 0.2) }.join
      described_class.reset!
      Thread.new { described_class.refresh(timeout: 0.2) }.join

      expect(ids.compact.size).to eq(2)
      expect(ids.compact.uniq.size).to eq(2)
    end

    it 'wakes a blocked refresh caller promptly on reset! instead of parking it until timeout' do
      allow(Game).to receive(:_puts) # server never answers
      result = Queue.new
      t = Thread.new { result << described_class.refresh(timeout: 30) }

      sleep 0.01 until described_class.instance_variable_get(:@assemblies).any?
      described_class.reset!

      expect(t.join(2)).to be_truthy # returned well within 2s, not parked ~30s
      expect(result.pop).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # refresh continuation/pagination assembly (matches the official Saga client:
  # an initial response announces <continuation> branches, each fetched with
  # `_inventory manager {id} continue {room} {root} {last}` and folded into one
  # snapshot).
  # ---------------------------------------------------------------------------
  describe '.refresh continuation assembly' do
    let(:game_obj) { Lich::Common::GameObj }

    # Initial response: top-level container 'ca' plus a continuation marker for
    # its contents. `branches` lets a test announce several at once; `child_of`
    # supplies the item(s) each continuation returns.
    def stub_server(initial_items:, initial_conts:, on_continue:)
      allow(Game).to receive(:_puts) do |cmd|
        if (m = cmd.match(/\A_inventory manager (\S+) continue (\S+) (\S+) (\S+)\z/))
          id, room, root, last = m.captures
          described_class.observe(on_continue.call(id, room, root, last))
        elsif (m = cmd.match(/\A_inventory manager (\S+)\z/))
          id = m[1]
          described_class.observe(
            "<inventoryManager id='#{id}' room='1'>#{initial_items}#{initial_conts}</inventoryManager>"
          )
        end
      end
    end

    it 'folds an initial response and its continuation branch into one snapshot' do
      stub_server(
        initial_items: "<i id='ca' loc='worn,player' name=\"a,leather,pack\" weight='10' in_max='1000'/>",
        initial_conts: "<continuation root='R1' last='L1'/>",
        on_continue: lambda { |id, room, root, last|
          "<inventoryManager id='#{id}' room='#{room}' root='#{root}' after='#{last}'>" \
          "<i id='x' loc='in,ca' name=\"a,steel,dagger\" weight='5'/>" \
          "</inventoryManager>"
        }
      )
      snap = described_class.refresh(timeout: 2)
      expect(snap.all.map(&:id)).to contain_exactly('ca', 'x')
      expect(snap['ca'].contents.map(&:id)).to eq(['x'])
    end

    it 'fetches every branch announced at once' do
      stub_server(
        initial_items: "<i id='ca' loc='worn,player' name=\"a,leather,pack\" weight='1' in_max='1000'/>",
        initial_conts: (1..3).map { |n| "<continuation root='R#{n}' last='L#{n}'/>" }.join,
        on_continue: lambda { |id, room, root, last|
          n = root[/\d+/]
          "<inventoryManager id='#{id}' room='#{room}' root='#{root}' after='#{last}'>" \
          "<i id='item#{n}' loc='in,ca' name=\"a,,thing#{n}\" weight='1'/>" \
          "</inventoryManager>"
        }
      )
      snap = described_class.refresh(timeout: 2)
      expect(snap['ca'].contents.map(&:id)).to contain_exactly('item1', 'item2', 'item3')
    end

    it 'follows a continuation announced by a continuation (nested branches)' do
      stub_server(
        initial_items: "<i id='ca' loc='worn,player' name=\"a,leather,pack\" weight='1' in_max='1000'/>",
        initial_conts: "<continuation root='R1' last='L1'/>",
        on_continue: lambda { |id, room, root, last|
          if root == 'R1'
            # first branch adds a sub-container and points at a deeper branch
            "<inventoryManager id='#{id}' room='#{room}' root='#{root}' after='#{last}'>" \
            "<i id='sub' loc='in,ca' name=\"a,,sack\" weight='1' in_max='500'/>" \
            "<continuation root='R2' last='L2'/>" \
            "</inventoryManager>"
          else
            "<inventoryManager id='#{id}' room='#{room}' root='#{root}' after='#{last}'>" \
            "<i id='deep' loc='in,sub' name=\"a,,gem\" weight='1'/>" \
            "</inventoryManager>"
          end
        }
      )
      snap = described_class.refresh(timeout: 2)
      expect(snap.all.map(&:id)).to contain_exactly('ca', 'sub', 'deep')
      expect(snap['sub'].contents.map(&:id)).to eq(['deep'])
    end

    it 'mirrors an assembled paginated snapshot into GameObj' do
      stub_server(
        initial_items: "<i id='ca' loc='worn,player' name=\"a,leather,pack\" weight='10' in_max='1000'/>",
        initial_conts: "<continuation root='R1' last='L1'/>",
        on_continue: lambda { |id, room, root, last|
          "<inventoryManager id='#{id}' room='#{room}' root='#{root}' after='#{last}'>" \
          "<i id='x' loc='in,ca' name=\"a,steel,dagger\" weight='5'/>" \
          "</inventoryManager>"
        }
      )
      described_class.refresh(timeout: 2)
      expect(game_obj.containers['ca'].map(&:id)).to eq(['x'])
    end

    it 'keeps at most MAX_CONCURRENT_CONTINUATIONS continuation requests in flight' do
      sent = []
      allow(Game).to receive(:_puts) do |cmd|
        sent << cmd
        next if cmd.include?('continue') # record continues but never answer them

        id = cmd[/_inventory manager (\S+)/, 1]
        branches = (1..6).map { |n| "<continuation root='R#{n}' last='L#{n}'/>" }.join
        described_class.observe(
          "<inventoryManager id='#{id}' room='1'>" \
          "<i id='ca' loc='worn,player' name=\"a,,pack\" weight='1' in_max='100'/>#{branches}" \
          "</inventoryManager>"
        )
      end
      described_class.refresh(timeout: 0.2)
      expect(sent.grep(/continue/).size).to eq(described_class::MAX_CONCURRENT_CONTINUATIONS)
    end

    it 'fails closed on a stale (interrupted) response' do
      allow(Game).to receive(:_puts) do |cmd|
        id = cmd[/_inventory manager (\S+)/, 1]
        described_class.observe("<inventoryManager id='#{id}' room='1' state='stale'></inventoryManager>")
      end
      expect(described_class.refresh(timeout: 1)).to be_nil
    end

    it 'fails closed when a continuation envelope does not match its request' do
      stub_server(
        initial_items: "<i id='ca' loc='worn,player' name=\"a,,pack\" weight='1' in_max='100'/>",
        initial_conts: "<continuation root='R1' last='L1'/>",
        on_continue: lambda { |id, room, root, _last|
          # echo the wrong cursor
          "<inventoryManager id='#{id}' room='#{room}' root='#{root}' after='WRONG'>" \
          "<i id='x' loc='in,ca' name=\"a,,dagger\" weight='1'/>" \
          "</inventoryManager>"
        }
      )
      expect(described_class.refresh(timeout: 1)).to be_nil
    end

    it 'fails closed when the server repeats a continuation cursor' do
      allow(Game).to receive(:_puts) do |cmd|
        id = cmd[/_inventory manager (\S+)/, 1]
        described_class.observe(
          "<inventoryManager id='#{id}' room='1'>" \
          "<i id='ca' loc='worn,player' name=\"a,,pack\" weight='1' in_max='100'/>" \
          "<continuation root='R1' last='L1'/><continuation root='R1' last='L1'/>" \
          "</inventoryManager>"
        )
      end
      expect(described_class.refresh(timeout: 1)).to be_nil
    end

    it 'fails closed on a duplicate item id across parts' do
      stub_server(
        initial_items: "<i id='ca' loc='worn,player' name=\"a,,pack\" weight='1' in_max='100'/>",
        initial_conts: "<continuation root='R1' last='L1'/>",
        on_continue: lambda { |id, room, root, last|
          "<inventoryManager id='#{id}' room='#{room}' root='#{root}' after='#{last}'>" \
          "<i id='ca' loc='worn,player' name=\"a,,pack\" weight='1' in_max='100'/>" \
          "</inventoryManager>"
        }
      )
      expect(described_class.refresh(timeout: 1)).to be_nil
    end

    it 'fails closed when a continuation item precedes its parent' do
      stub_server(
        initial_items: "<i id='ca' loc='worn,player' name=\"a,,pack\" weight='1' in_max='100'/>",
        initial_conts: "<continuation root='R1' last='L1'/>",
        on_continue: lambda { |id, room, root, last|
          "<inventoryManager id='#{id}' room='#{room}' root='#{root}' after='#{last}'>" \
          "<i id='x' loc='in,unknownparent' name=\"a,,dagger\" weight='1'/>" \
          "</inventoryManager>"
        }
      )
      expect(described_class.refresh(timeout: 1)).to be_nil
    end

    it 'returns nil (never raises) if assembling a part blows up unexpectedly' do
      allow(described_class).to receive(:build_item).and_raise(StandardError, 'boom')
      allow(Game).to receive(:_puts) do |cmd|
        id = cmd[/_inventory manager (\S+)/, 1]
        described_class.observe(
          "<inventoryManager id='#{id}' room='1'>" \
          "<i id='ca' loc='worn,player' name=\"a,,pack\" weight='1' in_max='100'/>" \
          "</inventoryManager>"
        )
      end
      expect { @result = described_class.refresh(timeout: 1) }.not_to raise_error
      expect(@result).to be_nil
    end

    it 'times out (nil) when an announced continuation never arrives' do
      allow(Game).to receive(:_puts) do |cmd|
        next if cmd.include?('continue') # never answer the continuation

        id = cmd[/_inventory manager (\S+)/, 1]
        described_class.observe(
          "<inventoryManager id='#{id}' room='1'>" \
          "<i id='ca' loc='worn,player' name=\"a,,pack\" weight='1' in_max='100'/>" \
          "<continuation root='R1' last='L1'/>" \
          "</inventoryManager>"
        )
      end
      expect(described_class.refresh(timeout: 0.2)).to be_nil
    end
  end

  describe 'retained containers and retired responses' do
    let(:game_obj) { Lich::Common::GameObj }

    def audit_item(id, parent = 'worn,player', extra = '')
      "<i id='#{id}' loc='#{parent}' name='a,,item' weight='1' #{extra}/>"
    end

    def audit_response(items, id: 'unsolicited')
      "<inventoryManager id='#{id}' room='1'>#{items}</inventoryManager>"
    end

    def visible_nested_tree
      audit_item('outer', 'worn,player', "in_max='100'") +
        audit_item('inner', 'in,outer', "in_max='50'") + audit_item('gem', 'in,inner')
    end

    def locked_outer
      audit_item('outer', 'worn,player', "in_max='100' flags='locked'")
    end

    before { @audit_workers = [] }

    after do
      @audit_workers.each { |worker| worker.kill if worker.alive? }
      @audit_workers.each { |worker| worker.join(1) }
      described_class.reset!
    end

    it 'preserves hidden descendants over repeated opaque snapshots' do
      described_class.observe(audit_response(visible_nested_tree))
      3.times do
        described_class.observe(audit_response(locked_outer))
        expect(game_obj.containers.fetch('inner').map(&:id)).to eq(['gem'])
      end
    end

    it 'removes retained descendants once their unlocked parent reports them absent' do
      described_class.observe(audit_response(visible_nested_tree))
      2.times { described_class.observe(audit_response(locked_outer)) }
      described_class.observe(audit_response(audit_item('outer', 'worn,player', "in_max='100'")))
      expect(game_obj.containers).not_to have_key('inner')
    end

    it 'removes retained descendants when their opaque ancestor itself disappears' do
      described_class.observe(audit_response(visible_nested_tree))
      2.times { described_class.observe(audit_response(locked_outer)) }
      described_class.observe(audit_response(audit_item('other')))
      expect(game_obj.containers).not_to have_key('outer')
      expect(game_obj.containers).not_to have_key('inner')
    end

    it 'uses a visible moved ancestor instead of its old opaque ancestry' do
      tree = visible_nested_tree + audit_item('deep', 'in,inner', "in_max='10'") + audit_item('stone', 'in,deep')
      described_class.observe(audit_response(tree))
      described_class.observe(audit_response(locked_outer))
      expect(game_obj.containers.fetch('deep').map(&:id)).to eq(['stone'])

      # Inner has moved onto the player and is visibly empty, while outer stays locked.
      described_class.observe(audit_response(locked_outer + audit_item('inner', 'worn,player', "in_max='50'")))
      expect(game_obj.containers).not_to have_key('deep')
    end

    it 'preserves a deeper subtree when the visible opaque boundary moves inward' do
      tree = visible_nested_tree + audit_item('deep', 'in,inner', "in_max='10'") + audit_item('stone', 'in,deep')
      described_class.observe(audit_response(tree))
      described_class.observe(audit_response(locked_outer))
      inner_locked = audit_item('outer', 'worn,player', "in_max='100'") +
                     audit_item('inner', 'in,outer', "in_max='50' flags='locked'")
      2.times do
        described_class.observe(audit_response(inner_locked))
        expect(game_obj.containers.fetch('deep').map(&:id)).to eq(['stone'])
      end
    end

    it 'defers deletion until a classic fill has committed, then cleans up' do
      described_class.observe(audit_response(visible_nested_tree))
      game_obj.begin_container('inner')
      game_obj.new_inv('classic', 'gem', 'a gem', 'inner')
      described_class.observe(audit_response(audit_item('other')))
      expect(game_obj.container_refresh_open?('inner')).to be(true)
      game_obj.commit_container('inner')
      expect(game_obj.containers.fetch('inner').map(&:id)).to eq(['classic'])
      described_class.observe(audit_response(audit_item('other')))
      expect(game_obj.containers).not_to have_key('inner')
    end

    # Each mode has the same postcondition, but distinct lifecycle exits.
    %i[kill reset timeout].each do |retirement|
      it "rejects a complete late response after #{retirement}" do
        sent = Queue.new
        allow(Game).to receive(:_puts) { |command| sent << command }
        worker = Thread.new { described_class.refresh(timeout: retirement == :timeout ? 0.03 : 5) }
        @audit_workers << worker
        command = sent.pop(timeout: 1) or raise 'refresh did not send'
        id = command.split.last
        worker.kill if retirement == :kill
        described_class.reset! if retirement == :reset
        expect(worker.join(1)).to eq(worker)

        described_class.observe(audit_response(audit_item('newer')))
        prior = described_class.current
        described_class.observe(audit_response(audit_item('retired'), id: id))
        expect(described_class.current).to equal(prior)
        expect(game_obj.inv.map(&:id)).to eq(['newer'])
      end
    end

    it 'accepts an active reply and ignores a duplicate after that reply is consumed' do
      request_id = nil
      allow(Game).to receive(:_puts) do |command|
        request_id = command.split.last
        described_class.observe(audit_response(audit_item('active'), id: request_id))
      end
      result = described_class.refresh(timeout: 1)
      expect(request_id).to match(/\Aim[0-9a-z]+\z/)
      expect(result.all.map(&:id)).to eq(['active'])
      described_class.observe(audit_response(audit_item('newer')))
      prior = described_class.current
      described_class.observe(audit_response(audit_item('duplicate'), id: request_id))
      expect(described_class.current).to equal(prior)
    end

    it 'does not expire retirement after other exchanges and repeated resets' do
      sent = Queue.new
      allow(Game).to receive(:_puts) { |command| sent << command }
      worker = Thread.new { described_class.refresh(timeout: 5) }
      @audit_workers << worker
      command = sent.pop(timeout: 1) or raise 'refresh did not send'
      retired_id = command.split.last
      worker.kill
      expect(worker.join(1)).to eq(worker)

      allow(Game).to receive(:_puts) do |request|
        described_class.observe(audit_response(audit_item('current'), id: request.split.last))
      end
      50.times do
        described_class.reset!
        expect(described_class.refresh(timeout: 1)).not_to be_nil
      end
      prior = described_class.current
      described_class.observe(audit_response(audit_item('retired'), id: retired_id))
      expect(described_class.current).to equal(prior)
    end

    it 'still accepts unrelated passive ids, including other im-prefixed ids' do
      %w[passive im-another-client im12345].each do |id|
        described_class.observe(audit_response(audit_item(id), id: id))
        expect(described_class.all.map(&:id)).to eq([id])
      end
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
