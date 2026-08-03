# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'fileutils'
require_relative 'game_map_shared_examples'

# The shared spec_helper XMLData module does not declare every room field the
# GemStone matchers read. Add them idempotently, the same way map_dr_spec does,
# so the specs below can drive them by plain assignment.
if defined?(XMLData) && XMLData.is_a?(Module)
  module XMLData
    class << self
      attr_accessor :room_exits_string, :room_count, :room_window_disabled
    end
  end
end

# =============================================================================
# GemStone Map implementation
# =============================================================================
# map_gs.rb and map_dr.rb both define Lich::Common::Map, so MapLoader.use swaps
# the loaded class rather than letting the two collide. See spec_helper.
RSpec.describe 'GemStone Map implementation' do
  let(:map_class) { MapLoader.use(:gs) }
  let(:room) do
    map_class.class_variable_set(:@@loaded, true)
    map_class.new(1, ['[Room]'], ['desc'], ['Obvious paths: north'])
  end

  before do
    MapLoader.use(:gs)
    # Mark the map loaded so nothing here falls through to a real Map.load,
    # which would read DATA_DIR from the filesystem. Without this the examples
    # only pass when an earlier one happens to have left @@loaded true.
    map_class.class_variable_set(:@@loaded, true)
    map_class.class_variable_get(:@@list).clear
    # get_location memoises, so clear it or an example inherits a cached
    # location and skips the lookup path entirely.
    map_class.class_variable_set(:@@current_location, nil)
    map_class.class_variable_set(:@@current_location_count, nil)
    map_class.clear_tags_cache
  end

  describe 'GemStone-only class methods' do
    %i[get_location locations images current_or_new].each do |method|
      it "responds to .#{method}" do
        expect(map_class).to respond_to(method)
      end
    end
  end

  describe 'class structure' do
    it 'includes Enumerable, which DragonRealms does not' do
      expect(map_class.ancestors).to include(Enumerable)
    end
  end

  describe 'class variables' do
    %i[@@images @@locations @@fuzzy_room_id].each do |name|
      it "defines #{name}" do
        expect(map_class.class_variables).to include(name)
      end
    end
  end

  describe 'attribute differences from DR' do
    it 'does not expose room_objects, which is DragonRealms only' do
      expect(room).not_to respond_to(:room_objects)
    end

    it 'takes outside? from MapBase' do
      expect(room.method(:outside?).owner).to eq(Lich::Common::MapBase::InstanceMethods)
    end
  end

  describe '.get_location' do
    let(:script) { double('Script', want_downstream: false, 'want_downstream=': nil) }

    before do
      # XMLData in the spec environment is a bare module, so the room counter
      # get_location compares against has to be stubbed in.
      allow(XMLData).to receive(:room_count).and_return(1)
      map_class.class_variable_set(:@@current_location_count, nil)
      allow(Script).to receive(:current).and_return(script)
      allow(map_class).to receive(:waitrt?)
    end

    it 'asks the game for the location' do
      allow(map_class).to receive(:dothistimeout).and_return('You carefully survey your surroundings and guess that your current location is Wehnimer\'s Landing or somewhere close to it.')

      map_class.get_location

      expect(map_class).to have_received(:dothistimeout).with('location', 15, kind_of(Regexp))
    end

    it 'extracts the location name from a successful survey' do
      allow(map_class).to receive(:dothistimeout).and_return('You carefully survey your surroundings and guess that your current location is Wehnimer\'s Landing or somewhere close to it.')

      expect(map_class.get_location).to eq("Wehnimer's Landing")
    end

    it 'returns false when submerged' do
      allow(map_class).to receive(:dothistimeout).and_return("You can't do that while submerged under water.")

      expect(map_class.get_location).to be false
    end

    it 'returns false in pitch darkness' do
      allow(map_class).to receive(:dothistimeout).and_return("Not in pitch darkness you don't.")

      expect(map_class.get_location).to be false
    end

    it 'returns false when the survey fails' do
      allow(map_class).to receive(:dothistimeout)
        .and_return('You carefully survey your surroundings but are unable to guess your current location.')

      expect(map_class.get_location).to be false
    end

    it 'caches the answer for the same room count' do
      allow(map_class).to receive(:dothistimeout).and_return('You carefully survey your surroundings and guess that your current location is Icemule Trace or somewhere close to it.')

      2.times { map_class.get_location }

      expect(map_class).to have_received(:dothistimeout).once
    end

    it 'returns nil when no script is running' do
      allow(Script).to receive(:current).and_return(nil)

      expect(map_class.get_location).to be_nil
    end
  end

  describe '.match_current peer tag handling' do
    # check_peer_tag is a proc local to .match_current, so it is reached by
    # driving match_current with a peer-tagged room. Spying on DownstreamHook.add
    # captures the squelch proc, which is then called directly to prove
    # suppression and removal without needing a real server round trip.
    let(:want_downstream_writes) { [] }
    let(:hooks) { {} }
    let(:removed_hooks) { [] }
    let(:commands) { [] }
    let(:peer_script) do
      # name is needed because the real hook registry records the owning script.
      double('Script', want_downstream: false, 'ignore_pause=': nil, name: 'spec').tap do |s|
        allow(s).to receive(:want_downstream=) { |value| want_downstream_writes << value }
      end
    end

    # map_gs.rb sits inside module Lich::Common, so it resolves DownstreamHook to
    # the real registry when hook_registry.rb is loaded and to spec_helper's mock
    # otherwise. Stub whichever one is actually in play.
    let(:downstream_hook) do
      if Lich::Common.const_defined?(:DownstreamHook, false)
        Lich::Common::DownstreamHook
      else
        ::DownstreamHook
      end
    end

    before do
      allow(Script).to receive(:current).and_return(peer_script)
      allow(map_class).to receive(:waitrt?)
      allow(map_class).to receive(:put) { |command| commands << command }
      allow(downstream_hook).to receive(:add) { |name, callable, **_opts| hooks[name] = callable }
      allow(downstream_hook).to receive(:remove) { |name| removed_hooks << name }
      $_SERVERBUFFER_.clear
      allow(XMLData).to receive_messages(room_count: 1, room_title: '[Ledge]',
                                         room_description: 'A narrow ledge.',
                                         room_exits_string: 'Obvious paths: down')
    end

    # Deliberately sparse: nothing here seeds room 0, so the matchers have to
    # walk a hole to reach room 1.
    def seed_peer_room(tag)
      map_class.new(1, ['[Ledge]'], ['A narrow ledge.'], ['Obvious paths: down'],
                    [], nil, nil, nil, {}, {}, nil, nil, [tag])
    end

    def peer_succeeds(direction: 'down')
      allow(map_class).to receive(:dothistimeout).and_return("You peer #{direction}...")
      allow(map_class).to receive(:get?).and_return('a chasm yawns below', 'Obvious paths: down')
    end

    describe 'tag parsing' do
      it 'issues the peer command for the direction in the tag' do
        seed_peer_room('peer down =~ /a chasm/')
        peer_succeeds

        map_class.match_current(peer_script)

        expect(map_class).to have_received(:dothistimeout).with('peer down', 3, anything)
      end

      it 'reads the direction rather than assuming one' do
        seed_peer_room('peer east =~ /a chasm/')
        peer_succeeds(direction: 'east')

        map_class.match_current(peer_script)

        expect(map_class).to have_received(:dothistimeout).with('peer east', 3, anything)
      end

      it 'turns the description on for the set desc on prefix' do
        $_SERVERBUFFER_.push('<style id="roomDesc"/><')
        seed_peer_room('set desc on; peer down =~ /a chasm/')
        peer_succeeds

        map_class.match_current(peer_script)

        expect(commands).to include('set description on')
      end

      it 'turns the description back off afterwards' do
        $_SERVERBUFFER_.push('<style id="roomDesc"/><')
        seed_peer_room('set desc on; peer down =~ /a chasm/')
        peer_succeeds

        map_class.match_current(peer_script)

        expect(commands).to eq(['set description on', 'set description off'])
      end

      it 'leaves the description alone without the prefix' do
        seed_peer_room('peer down =~ /a chasm/')
        peer_succeeds

        map_class.match_current(peer_script)

        expect(commands).to be_empty
      end
    end

    describe 'squelch hook' do
      before do
        seed_peer_room('peer down =~ /a chasm/')
        peer_succeeds
        map_class.match_current(peer_script)
      end

      it 'registers under the squelch-peer name' do
        expect(hooks).to have_key('squelch-peer')
      end

      it 'registers without persisting' do
        expect(downstream_hook).to have_received(:add).with('squelch-peer', anything, persist: false)
      end

      it 'passes unrelated output through untouched' do
        expect(hooks['squelch-peer'].call('Some unrelated line')).to eq('Some unrelated line')
      end

      it 'suppresses the peer response itself' do
        expect(hooks['squelch-peer'].call('You peer down and see a chasm')).to be_nil
      end

      it 'keeps suppressing once started' do
        squelch = hooks['squelch-peer']
        squelch.call('You peer down')

        expect(squelch.call('a chasm yawns below')).to be_nil
      end

      it 'removes itself when the prompt arrives' do
        squelch = hooks['squelch-peer']
        squelch.call('You peer down')
        squelch.call('<prompt time="1"/>')

        expect(removed_hooks).to include('squelch-peer')
      end

      it 'does not remove itself before the prompt' do
        squelch = hooks['squelch-peer']
        removed_hooks.clear # the command scope already removed it on the way out

        squelch.call('You peer down')

        expect(removed_hooks).to be_empty
      end
    end

    describe 'matching' do
      it 'resolves the room when the peer output satisfies the requirement' do
        seed_peer_room('peer down =~ /a chasm/')
        peer_succeeds

        expect(map_class.match_current(peer_script)).to eq(1)
      end

      it 'rejects the room when the peer output does not satisfy it' do
        seed_peer_room('peer down =~ /a waterfall/')
        peer_succeeds

        expect(map_class.match_current(peer_script)).to be_nil
      end
    end

    describe 'command scope cleanup' do
      before { seed_peer_room('peer down =~ /a chasm/') }

      it 'removes the hook after a successful command' do
        peer_succeeds
        map_class.match_current(peer_script)

        expect(removed_hooks).to include('squelch-peer')
      end

      it 'removes the hook after a usage error' do
        allow(map_class).to receive(:dothistimeout).and_return('[Usage: PEER <direction>]')
        map_class.match_current(peer_script)

        expect(removed_hooks).to include('squelch-peer')
      end

      it 'removes the hook after a timeout' do
        allow(map_class).to receive(:dothistimeout).and_return(nil)
        map_class.match_current(peer_script)

        expect(removed_hooks).to include('squelch-peer')
      end

      it 'removes the hook when the command raises' do
        allow(map_class).to receive(:dothistimeout).and_raise('peer blew up')

        expect { map_class.match_current(peer_script) }.to raise_error('peer blew up')
        expect(removed_hooks).to include('squelch-peer')
      end

      it 'restores want_downstream when the command raises' do
        allow(map_class).to receive(:dothistimeout).and_raise('peer blew up')

        expect { map_class.match_current(peer_script) }.to raise_error('peer blew up')
        expect(want_downstream_writes.last).to be false
      end

      it 'removes the hook exactly once per attempt' do
        peer_succeeds
        map_class.match_current(peer_script)

        expect(removed_hooks.count('squelch-peer')).to eq(want_downstream_writes.count(true))
      end
    end

    describe 'when the peer command fails' do
      before do
        seed_peer_room('peer down =~ /a chasm/')
        allow(map_class).to receive(:dothistimeout).and_return('[Usage: PEER <direction>]')
      end

      it 'rejects the room rather than raising' do
        expect { map_class.match_current(peer_script) }.not_to raise_error
      end

      it 'does not resolve a room' do
        expect(map_class.match_current(peer_script)).to be_nil
      end

      it 'leaves want_downstream restored' do
        map_class.match_current(peer_script)

        expect(want_downstream_writes.last).to be false
      end

      it 'balances every enable with a restore' do
        # match_current makes two matching passes, so the peer attempt happens
        # more than once; what matters is that each enable is paired.
        map_class.match_current(peer_script)

        expect(want_downstream_writes.count(true)).to eq(want_downstream_writes.count(false))
      end
    end
  end

  describe '.current_or_new' do
    let(:script) do
      double('Script', want_downstream: false, 'want_downstream=': nil, 'ignore_pause=': nil)
    end

    # Deliberately sparse: nothing here seeds room 0, so both the uid path and
    # the match_current matchers have to walk a hole to reach room 1.
    def seed_room(tags: [], uid: [], title: '[Town Square]', description: 'A plaza.')
      room = map_class.new(1, [title], [description], ['Obvious paths: north'],
                           [], nil, nil, nil, {}, {}, nil, nil, tags)
      room.uid = uid
      map_class.load_uids
      room
    end

    before do
      allow(Script).to receive(:current).and_return(script)
      allow(map_class).to receive(:waitrt?)
      allow(map_class).to receive(:dothistimeout)
        .and_return('You carefully survey your surroundings and guess that your current location is Test or somewhere close to it.')
      allow(XMLData).to receive(:room_count).and_return(1)
      allow(XMLData).to receive(:room_exits_string).and_return('Obvious paths: north')
    end

    # The live uid maps straight to room 1, so the room is resolved without
    # matching on text and the newly seen title and description are merged in.
    context 'when the live uid already maps to a room' do
      before do
        allow(XMLData).to receive_messages(room_id: 500,
                                           room_title: '[Town Square, North]',
                                           room_description: 'A wider plaza.')
      end

      it 'returns the room matching the current uid' do
        seed_room(uid: [500])

        expect(map_class.current_or_new.id).to eq(1)
      end

      it 'unshifts a newly seen title onto an ordinary room' do
        seed_room(uid: [500])
        map_class.current_or_new

        expect(map_class[1].title).to eq(['[Town Square, North]', '[Town Square]'])
      end

      it 'unshifts a newly seen description onto an ordinary room' do
        seed_room(uid: [500])
        map_class.current_or_new

        expect(map_class[1].description).to eq(['A wider plaza.', 'A plaza.'])
      end

      it 'replaces rather than accumulates for meta:map:latest-only' do
        seed_room(uid: [500], tags: ['meta:map:latest-only'])
        map_class.current_or_new

        expect(map_class[1].title).to eq(['[Town Square, North]'])
        expect(map_class[1].description).to eq(['A wider plaza.'])
      end

      it 'replaces rather than accumulates for meta:playershop' do
        seed_room(uid: [500], tags: ['meta:playershop'])
        map_class.current_or_new

        expect(map_class[1].title).to eq(['[Town Square, North]'])
      end
    end

    # No room carries the live uid, so resolution falls through to matching the
    # live reading against the stored title, description and exits.
    context 'when the room is resolved by matching the live reading' do
      before do
        allow(XMLData).to receive_messages(room_title: '[Town Square]',
                                           room_description: 'A plaza.')
      end

      it 'resolves the matching room rather than creating one' do
        seed_room
        allow(XMLData).to receive(:room_id).and_return(500)

        expect(map_class.current_or_new.id).to eq(1)
        expect(map_class.class_variable_get(:@@list).compact.map(&:id)).to eq([1])
      end

      it 'records the newly seen uid on the resolved room' do
        room = seed_room
        allow(XMLData).to receive(:room_id).and_return(500)
        expect(room.uid).to be_empty # the uid is genuinely new

        map_class.current_or_new

        expect(map_class[1].uid).to include(500)
      end

      it 'makes the new uid resolvable afterwards' do
        seed_room
        allow(XMLData).to receive(:room_id).and_return(500)
        map_class.current_or_new

        expect(map_class.ids_from_uid(500)).to eq([1])
      end

      it 'does not record a room id above the 4_294_967_296 threshold' do
        seed_room
        allow(XMLData).to receive(:room_id).and_return(4_294_967_297)

        resolved = map_class.current_or_new

        expect(resolved.id).to eq(1)
        expect(resolved.uid).not_to include(4_294_967_297)
      end

      it 'refuses to add a second uid to a single-uid room' do
        seed_room(uid: [999])
        allow(XMLData).to receive(:room_id).and_return(500)

        resolved = map_class.current_or_new

        expect(resolved.id).not_to eq(1)
        expect(map_class[1].uid).to eq([999])
      end

      it 'allows a second uid when the room is tagged meta:map:multi-uid' do
        seed_room(uid: [999], tags: ['meta:map:multi-uid'])
        allow(XMLData).to receive(:room_id).and_return(500)

        resolved = map_class.current_or_new

        expect(resolved.id).to eq(1)
        expect(map_class[1].uid).to contain_exactly(999, 500)
      end
    end
  end

  describe '.match_fuzzy' do
    # Mirrors the build_room/live_room helpers map_dr_spec uses.
    def build_room(id, title:, description:, exits:, tags: [])
      map_class.new(id, [title], [description], [exits], [],
                    nil, nil, nil, {}, {}, nil, nil, tags)
    end

    def live_room(title:, description:, exits:, room_count: 1)
      XMLData.room_title = title
      XMLData.room_description = description
      XMLData.room_exits_string = exits
      XMLData.room_count = room_count
    end

    before { map_class.class_variable_set(:@@fuzzy_room_count, -1) }

    it 'resolves a room whose title, description and exits all match' do
      build_room(0, title: 'Town Square', description: 'A wide plaza.', exits: 'Obvious paths: north')
      live_room(title: 'Town Square', description: 'A wide plaza.', exits: 'Obvious paths: north')

      expect(map_class.match_fuzzy).to eq(0)
    end

    it 'returns nil when nothing matches' do
      build_room(0, title: 'Town Square', description: 'A wide plaza.', exits: 'Obvious paths: north')
      live_room(title: 'Elsewhere', description: 'Nowhere.', exits: 'Obvious paths: south')

      expect(map_class.match_fuzzy).to be_nil
    end

    it 'rejects a room carrying a peer disambiguation tag' do
      build_room(0, title: 'Foggy Ledge', description: 'A narrow ledge.',
                    exits: 'Obvious paths: down', tags: ['peer down =~ /a chasm/'])
      live_room(title: 'Foggy Ledge', description: 'A narrow ledge.', exits: 'Obvious paths: down')

      expect(map_class.match_fuzzy).to be_nil
    end

    it 'rejects a peer tag carrying the set desc on prefix' do
      build_room(0, title: 'Foggy Ledge', description: 'A narrow ledge.',
                    exits: 'Obvious paths: down', tags: ['set desc on; peer down =~ /a chasm/'])
      live_room(title: 'Foggy Ledge', description: 'A narrow ledge.', exits: 'Obvious paths: down')

      expect(map_class.match_fuzzy).to be_nil
    end

    it 'accepts a room whose tags only look peer-like' do
      build_room(0, title: 'Foggy Ledge', description: 'A narrow ledge.',
                    exits: 'Obvious paths: down', tags: ['peers down =~ /a chasm/'])
      live_room(title: 'Foggy Ledge', description: 'A narrow ledge.', exits: 'Obvious paths: down')

      expect(map_class.match_fuzzy).to eq(0)
    end

    it 'rejects a room whose unique_loot is not on the ground' do
      allow(GameObj).to receive(:loot).and_return([])
      room = build_room(0, title: 'Vault', description: 'Shelves.', exits: 'Obvious paths: out')
      room.unique_loot = ['a brass key']
      live_room(title: 'Vault', description: 'Shelves.', exits: 'Obvious paths: out')

      expect(map_class.match_fuzzy).to be_nil
    end

    it 'accepts a room whose unique_loot is present' do
      allow(GameObj).to receive(:loot).and_return([double('Item', name: 'a brass key')])
      room = build_room(0, title: 'Vault', description: 'Shelves.', exits: 'Obvious paths: out')
      room.unique_loot = ['a brass key']
      live_room(title: 'Vault', description: 'Shelves.', exits: 'Obvious paths: out')

      expect(map_class.match_fuzzy).to eq(0)
    end

    it 'matches through fog regardless of the recorded exits' do
      build_room(0, title: 'Misty Path', description: 'Grey all around.', exits: 'Obvious paths: north')
      live_room(title: 'Misty Path', description: 'Grey all around.',
                exits: 'Obvious paths: obscured by a thick fog')

      expect(map_class.match_fuzzy).to eq(0)
    end
  end
end

# =============================================================================
# GemStone Map runtime behaviour
# =============================================================================
RSpec.describe 'GemStone Map runtime behaviour' do
  it_behaves_like 'a game Map class', :gs

  let(:map_class) { MapLoader.use(:gs) }

  before { MapLoader.use(:gs) }

  describe 'the loader put the GemStone class in place' do
    it 'loaded the GemStone implementation, not the DragonRealms one' do
      # DragonRealms adds four optional genie parameters. If both files were
      # loaded into the same class, whichever came last would own #initialize
      # and this count would change, so this is what proves the swap held.
      expect(map_class.instance_method(:initialize).parameters.length).to eq(15)
    end

    it 'exposes the GemStone-only helpers' do
      expect(map_class).to respond_to(:current_or_new)
    end
  end
end
