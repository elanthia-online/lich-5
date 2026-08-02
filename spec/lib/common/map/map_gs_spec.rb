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
#
# A handful of examples below still assert against the source text. Those cover
# GemStone-only game interaction (peer tag squelching, current_or_new meta tags,
# get_location's command and responses) that needs DownstreamHook and command
# round-trip mocking to exercise properly. They are marked and want converting
# in their own change; everything else here is behavioural.
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

  # The only source-level block left in this file. check_peer_tag is a proc local
  # to .match_current rather than a callable method, and reaching it needs a
  # DownstreamHook round trip plus a peer command response. The peer tag matching
  # itself is covered behaviourally under .match_fuzzy above; what remains here is
  # the squelching plumbing. Convert once a DownstreamHook harness exists.
  describe '.match_current peer tag handling (source-level)' do
    let(:gs_map_content) { File.read(File.expand_path('../../../../lib/common/map/map_gs.rb', __dir__)) }

    it 'extracts peer direction from tag' do
      expect(gs_map_content).to include('peer_direction')
    end

    it 'handles set desc on prefix' do
      expect(gs_map_content).to include('set desc on;')
    end

    it 'uses DownstreamHook for squelching' do
      expect(gs_map_content).to include('DownstreamHook')
      expect(gs_map_content).to include('squelch-peer')
    end
  end

  describe '.current_or_new' do
    let(:script) { double('Script', want_downstream: false, 'want_downstream=': nil) }

    # Room 0 keeps the list dense: load_uids has no nil guard and depends on
    # Lich's NilClass patch, which spec_helper does not apply.
    def seed_room(tags: [], uid: [500])
      map_class.new(0, ['[Start]'], ['start'], ['Obvious paths: north'])
      room = map_class.new(1, ['[Town Square]'], ['A plaza.'], ['Obvious paths: north'],
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
      allow(XMLData).to receive_messages(room_count: 1, room_id: 500,
                                         room_title: '[Town Square, North]',
                                         room_description: 'A wider plaza.',
                                         room_exits_string: 'Obvious paths: north')
    end

    it 'returns the room matching the current uid' do
      seed_room

      expect(map_class.current_or_new.id).to eq(1)
    end

    it 'unshifts a newly seen title onto an ordinary room' do
      seed_room
      map_class.current_or_new

      expect(map_class[1].title).to eq(['[Town Square, North]', '[Town Square]'])
    end

    it 'unshifts a newly seen description onto an ordinary room' do
      seed_room
      map_class.current_or_new

      expect(map_class[1].description).to eq(['A wider plaza.', 'A plaza.'])
    end

    it 'replaces rather than accumulates for meta:map:latest-only' do
      seed_room(tags: ['meta:map:latest-only'])
      map_class.current_or_new

      expect(map_class[1].title).to eq(['[Town Square, North]'])
      expect(map_class[1].description).to eq(['A wider plaza.'])
    end

    it 'replaces rather than accumulates for meta:playershop' do
      seed_room(tags: ['meta:playershop'])
      map_class.current_or_new

      expect(map_class[1].title).to eq(['[Town Square, North]'])
    end

    it 'records a newly seen uid on the room' do
      seed_room(uid: [500])
      allow(XMLData).to receive(:room_id).and_return(500)
      map_class.current_or_new

      expect(map_class[1].uid).to include(500)
    end

    it 'ignores room ids above the 4_294_967_296 threshold' do
      seed_room
      allow(XMLData).to receive(:room_id).and_return(4_294_967_297)
      map_class.current_or_new

      expect(map_class[1].uid).not_to include(4_294_967_297)
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
