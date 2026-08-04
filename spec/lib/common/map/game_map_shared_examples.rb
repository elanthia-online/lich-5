# frozen_string_literal: true

require 'json'
require 'timeout'

# Shared examples, not a spec file. RSpec's default pattern is
# spec/**/*_spec.rb, so this is never auto-loaded or run on its own; the two
# game specs require it explicitly. It lives here rather than in spec_helper
# because spec_helper is for infrastructure, and these are test bodies. It is
# not in map_base_spec.rb either, since running a single game spec would then
# fail to find the group.
#
# Requires MapLoader and the game mocks from spec_helper, which both callers
# have already loaded.

# =============================================================================
# Shared behaviour every game Map class must exhibit
# =============================================================================
# Room lookup, the tag index, tag storage, pathfinding, outside? and JSON map
# loading all live in MapBase, so GemStone and DragonRealms must behave
# identically for them. Running one group against both games means a divergence
# fails for the game that drifted, which parallel copies in each spec file
# cannot guarantee.
#
# Usage: it_behaves_like 'a game Map class', :gs
RSpec.shared_examples 'a game Map class' do |game|
  let(:map_class) { MapLoader.use(game) }
  let(:map_game) { "rspec-#{game}" }
  let(:map_dir) { File.join(DATA_DIR, map_game) }

  before do
    MapLoader.use(game)
    allow(XMLData).to receive(:game).and_return(map_game)
    map_class.class_variable_set(:@@loaded, true)
    map_class.class_variable_get(:@@list).clear
    map_class.class_variable_set(:@@current_room_id, nil)
    map_class.class_variable_set(:@@previous_room_id, nil)
    map_class.clear_tags_cache
  end

  after do
    FileUtils.rm_rf(map_dir)
    map_class.class_variable_get(:@@list).clear
    # The loading examples deliberately set this false; restore it so the flag
    # does not leak into whatever example runs next.
    map_class.class_variable_set(:@@loaded, true)
    map_class.clear_tags_cache
  end

  # The first 15 constructor parameters are identical in both games.
  def shared_room(id, title:, description:, paths: ['Obvious paths: north'], tags: [], uid: [])
    map_class.new(id, [title], [description], paths, uid,
                  nil, nil, nil, {}, {}, nil, nil, tags)
  end

  describe 'room lookup' do
    before do
      shared_room(1, title: '[Market Row]', description: 'Stalls line the muddy street.', tags: ['shop'])
      shared_room(4, title: '[Quiet Lane]', description: 'Marble counters gleam here.')
      shared_room(6, title: '[Bank Lobby]', description: 'Stalls line the far wall.', tags: ['bank'])
    end

    it 'finds a room by integer id' do
      expect(map_class[6].id).to eq(6)
    end

    it 'finds a room by numeric string' do
      expect(map_class['4'].id).to eq(4)
    end

    it 'finds a room by uid' do
      map_class[4].uid = [9001]
      map_class.load_uids

      expect(map_class['u9001'].id).to eq(4)
    end

    it 'indexes uids across a sparse list without raising' do
      # The list here has holes at 0, 2, 3 and 5. load_uids compacts, so indexing
      # uids across a sparse map does not depend on Lich's NilClass patch.
      expect(map_class.class_variable_get(:@@list)[3]).to be_nil
      map_class[1].uid = [9001]
      map_class[6].uid = [9002]

      expect { map_class.load_uids }.not_to raise_error
      expect(map_class['u9002'].id).to eq(6)
    end

    it 'returns nil for an unknown uid rather than room 0' do
      # nil.to_i is 0, so the uid branch used to hand back whatever sat at index
      # 0. Room 0 has to exist for that to be observable.
      shared_room(0, title: '[Zero]', description: 'zeroth')

      expect(map_class['u999999']).to be_nil
    end

    it 'finds a room by exact title' do
      expect(map_class['[Bank Lobby]'].id).to eq(6)
    end

    it 'prefers a title match over an earlier description match' do
      expect(map_class['[Quiet Lane]'].id).to eq(4)
    end

    it 'falls back to an exact description match' do
      expect(map_class['Marble counters'].id).to eq(4)
    end

    it 'returns the first room when several descriptions match' do
      expect(map_class['Stalls line'].id).to eq(1)
    end

    it 'falls back to the loose regex form last' do
      expect(map_class['Stalls line...muddy street'].id).to eq(1)
    end

    it 'returns nil when nothing matches' do
      expect(map_class['zzz nothing zzz']).to be_nil
    end

    it 'walks past nil holes without raising' do
      expect(map_class.class_variable_get(:@@list)[5]).to be_nil
      expect { map_class['zzz nothing zzz'] }.not_to raise_error
    end
  end

  describe 'tag index' do
    before do
      shared_room(1, title: '[One]', description: 'first', tags: ['shop'])
      shared_room(4, title: '[Four]', description: 'fourth')
      shared_room(6, title: '[Six]', description: 'sixth', tags: ['bank'])
    end

    it 'reports the tag names present' do
      expect(map_class.tags.sort).to eq(%w[bank shop])
    end

    it 'returns the room ids carrying a tag' do
      expect(map_class.rooms_by_tag('shop')).to eq([1])
    end

    it 'returns ids of rooms carrying the tag in ascending order' do
      shared_room(2, title: '[Two]', description: 'second', tags: ['shop'])
      shared_room(0, title: '[Zero]', description: 'zeroth', tags: ['shop'])

      expect(map_class.rooms_by_tag('shop')).to eq([0, 1, 2])
    end

    it 'returns an empty list for an unknown tag' do
      expect(map_class.rooms_by_tag('nope')).to eq([])
    end

    it 'hands back a copy a caller cannot corrupt' do
      map_class.rooms_by_tag('shop').clear

      expect(map_class.rooms_by_tag('shop')).to eq([1])
    end

    describe 'shared with the Room subclass' do
      # Room subclasses Map and inherits these class methods. The cache lives on
      # class-instance variables, which subclasses do not share, so without a
      # single owner a query through Room memoises a second cache that Map's
      # invalidations never reach.
      let(:room_class) { Lich::Common::Room }

      it 'answers the same tag names through either class' do
        expect(room_class.tags.sort).to eq(map_class.tags.sort)
      end

      it 'answers the same room ids through either class' do
        expect(room_class.rooms_by_tag('shop')).to eq(map_class.rooms_by_tag('shop'))
      end

      it 'sees a mutation made after priming through Room' do
        room_class.tags # prime through the subclass
        map_class[1].tags = ['bank']

        expect(room_class.tags).to include('bank')
      end

      it 'drops the old tag from the Room view too' do
        room_class.tags # prime through the subclass
        map_class[1].tags = ['bank']

        expect(room_class.rooms_by_tag('shop')).to eq([])
      end

      it 'sees an in place append made after priming through Room' do
        room_class.rooms_by_tag('shop') # prime through the subclass
        map_class[4].tags << 'shop'

        expect(room_class.rooms_by_tag('shop')).to eq([1, 4])
      end

      it 'resolves both classes to the same cache host' do
        expect(room_class.send(:tag_cache_host)).to equal(map_class)
      end
    end

    it 'keeps the cache off the public surface' do
      expect(map_class).not_to respond_to(:tag_index)
    end

    it 'picks up a tag appended in place' do
      map_class[4].tags << 'shop'

      expect(map_class.rooms_by_tag('shop')).to eq([1, 4])
    end

    it 'picks up a tag deleted in place' do
      map_class[1].tags.delete('shop')

      expect(map_class.rooms_by_tag('shop')).to eq([])
    end

    it 'picks up a whole list assignment' do
      map_class[4].tags = %w[shop inn]

      expect(map_class.rooms_by_tag('inn')).to eq([4])
    end

    it 'picks up an in place clear' do
      map_class[1].tags.clear

      expect(map_class.rooms_by_tag('shop')).to eq([])
    end

    it 'is reflected in .tags as well' do
      map_class[4].tags << 'inn'

      expect(map_class.tags).to include('inn')
    end

    it 'picks up a newly constructed room' do
      map_class.rooms_by_tag('shop') # prime the cache
      shared_room(8, title: '[Eight]', description: 'eighth', tags: ['shop'])

      expect(map_class.rooms_by_tag('shop')).to eq([1, 8])
    end

    it 'picks up a room replaced at an existing id' do
      map_class.rooms_by_tag('shop') # prime the cache
      shared_room(4, title: '[Four]', description: 'fourth', tags: ['shop'])

      expect(map_class.rooms_by_tag('shop')).to eq([1, 4])
    end

    it 'stays consistent while reads and invalidations run concurrently' do
      # A stress check, not proof: the interleaving #tag_index guards against is
      # a few instructions wide and not reliably reachable from a test, so this
      # catches gross corruption rather than the specific window. The ordering
      # argument for that window is spelled out at #tag_index.
      expected = map_class.rooms_by_tag('shop')
      readers = 4.times.map do
        Thread.new { 40.times { map_class.rooms_by_tag('shop') } }
      end
      writer = Thread.new { 40.times { map_class.reset_tag_index } }
      (readers + [writer]).each(&:join)

      expect(map_class.rooms_by_tag('shop')).to eq(expected)
    end

    it 'rebuilds after clear_tags_cache' do
      map_class.rooms_by_tag('shop') # prime, so the spy only sees the rebuild
      allow(map_class).to receive(:build_tag_index).and_call_original

      map_class.clear_tags_cache
      map_class.rooms_by_tag('shop')

      expect(map_class).to have_received(:build_tag_index).once
    end

    it 'does not rebuild while the cache is valid' do
      map_class.rooms_by_tag('shop') # prime
      allow(map_class).to receive(:build_tag_index).and_call_original

      3.times { map_class.rooms_by_tag('shop') }

      expect(map_class).not_to have_received(:build_tag_index)
    end
  end

  describe 'tag storage' do
    before { shared_room(1, title: '[One]', description: 'first', tags: [+'shop']) }

    it 'wraps room tags in a TagList' do
      expect(map_class[1].tags).to be_a(Lich::Common::TagList)
    end

    it 'keeps them comparable to a plain Array' do
      expect(map_class[1].tags).to eq(['shop'])
    end

    it 'freezes the stored names' do
      expect(map_class[1].tags.first).to be_frozen
    end

    it 'raises rather than allowing a rename in place' do
      expect { map_class[1].tags.first.replace('bank') }.to raise_error(FrozenError)
    end

    # Marshal skips the constructor, so a room restored that way carries a plain
    # Array in @tags rather than a TagList. Rebuild that shape here.
    let(:legacy_list) do
      restored = Marshal.load(Marshal.dump(map_class.class_variable_get(:@@list)))
      restored.compact.each { |room| room.instance_variable_set(:@tags, ['shop']) }
      restored
    end

    it 'starts from a room whose tags are a plain Array' do
      expect(legacy_list.compact.first.instance_variable_get(:@tags)).to be_an(Array)
      expect(legacy_list.compact.first.instance_variable_get(:@tags)).not_to be_a(Lich::Common::TagList)
    end

    it 'rewraps plain Array tags assigned through list=' do
      map_class.list = legacy_list

      expect(map_class[1].tags).to be_a(Lich::Common::TagList)
    end

    it 'still indexes the loaded tags' do
      map_class.list = legacy_list

      expect(map_class.rooms_by_tag('shop')).to eq([1])
    end

    it 'invalidates on an in place tag change after the assignment' do
      map_class.list = legacy_list
      map_class.rooms_by_tag('shop') # prime the cache

      map_class[1].tags << 'bank'

      expect(map_class.rooms_by_tag('bank')).to eq([1])
    end

    it 'drops a cache carried over from the previous map' do
      map_class.list = legacy_list
      map_class.rooms_by_tag('shop') # prime against the loaded list

      map_class.list = []

      expect(map_class.rooms_by_tag('shop')).to eq([])
    end
  end

  describe 'outside?' do
    def room_with_paths(paths)
      shared_room(1, title: '[Room]', description: 'desc', paths: paths)
    end

    it 'is outside when the last path line reads Obvious paths' do
      expect(room_with_paths(['Obvious paths: north, south'])).to be_outside
    end

    it 'is not outside when the last path line reads Obvious exits' do
      expect(room_with_paths(['Obvious exits: north, south'])).not_to be_outside
    end

    it 'reads the last entry, not the first' do
      expect(room_with_paths(['Obvious paths: north', 'Obvious exits: south'])).not_to be_outside
    end

    it 'is inside whenever it is not outside' do
      expect(room_with_paths(['Obvious exits: north'])).to be_inside
    end

    it 'returns false for nil paths' do
      expect(room_with_paths(nil).outside?).to be false
    end

    it 'returns false for empty paths' do
      expect(room_with_paths([]).outside?).to be false
    end

    it 'returns an actual boolean rather than a match offset' do
      expect(room_with_paths(['Obvious paths: north']).outside?).to be(true)
    end
  end

  describe 'pathfinding' do
    before do
      shared_room(1, title: '[One]', description: 'first', tags: ['shop'])
      shared_room(2, title: '[Two]', description: 'second')
      map_class[1].wayto['2'] = 'north'
      map_class[1].timeto['2'] = 0.5
      map_class[2].wayto['1'] = 'south'
      map_class[2].timeto['1'] = 0.5
    end

    it 'reconstructs a path' do
      expect(map_class[1].path_to(2)).to eq([2])
    end

    it 'returns two Hashes keyed by room id' do
      expect(map_class[1].dijkstra.map(&:class)).to eq([Hash, Hash])
    end

    it 'answers to the transitional dijkstra_hashes name as well' do
      expect(map_class[1].dijkstra_hashes.map(&:class)).to eq([Hash, Hash])
    end

    it 'reads the same by room id either way' do
      previous, distances = map_class[1].dijkstra(2)

      expect(distances[2]).to eq(0.5)
      expect(previous[2]).to eq(1)
    end

    it 'yields nil for a room it never reached' do
      _, distances = map_class[1].dijkstra

      expect(distances[999_999]).to be_nil
    end

    it 'sizes the result by rooms reached, not by highest id' do
      # This is the one observable change: the Array form was sized by the
      # highest id reached, so #size was highest-id-plus-one.
      _, distances = map_class[1].dijkstra

      expect(distances.size).to eq(2)
    end

    it 'keys the hashes only by rooms it reached' do
      _, distances = map_class[1].dijkstra

      expect(distances.keys.sort).to eq([1, 2])
    end

    it 'finds the nearest room carrying a tag' do
      expect(map_class[2].find_nearest_by_tag('shop')).to eq(1)
    end

    it 'returns the room itself when it already carries the tag' do
      expect(map_class[1].find_nearest_by_tag('shop')).to eq(1)
    end
  end

  describe 'shared implementation ownership' do
    it 'takes load from MapBase rather than the game class' do
      expect(map_class.method(:load).owner).to eq(Lich::Common::MapBase::ClassMethods)
    end

    it 'takes room lookup from MapBase rather than the game class' do
      expect(map_class.method(:[]).owner).to eq(Lich::Common::MapBase::ClassMethods)
    end

    it 'takes the pathfinding methods from MapBase' do
      room = shared_room(1, title: '[One]', description: 'first')

      expect(room.method(:path_to).owner).to eq(Lich::Common::MapBase::InstanceMethods)
      expect(room.method(:dijkstra).owner).to eq(Lich::Common::MapBase::InstanceMethods)
      expect(room.method(:find_nearest_by_tag).owner).to eq(Lich::Common::MapBase::InstanceMethods)
    end

    %i[save_json estimate_time rooms_by_tag tag_names reset_tag_index
       normalize_tag_lists legacy_map_files report_unsupported_map_files
       get_free_id tags previous_uid match_no_uid match_multi_ids
       set_current set_fuzzy load_json parse_map_json json_map_files
       validate_room_json! map_loaded_message].each do |method|
      it "takes .#{method} from MapBase" do
        expect(map_class.method(method).owner).to eq(Lich::Common::MapBase::ClassMethods)
      end
    end

    it 'aliases save to save_json' do
      expect(map_class.method(:save)).to eq(map_class.method(:save_json))
    end

    it 'exposes the room-navigation accessors the shared code needs' do
      %i[current_room_id current_room_id= previous_room_id previous_room_id=].each do |accessor|
        expect(map_class).to respond_to(accessor)
      end
    end

    it 'leaves the Room shim as a plain subclass' do
      expect(Lich::Common::Room.singleton_methods(false)).to be_empty
    end

    it 'no longer responds to the removed legacy loaders' do
      expect(map_class).not_to respond_to(:load_dat)
      expect(map_class).not_to respond_to(:load_xml)
      expect(map_class).not_to respond_to(:save_xml)
    end

    it 'includes MapBase' do
      expect(map_class.ancestors).to include(Lich::Common::MapBase)
    end

    it 'defines Room as a subclass of Map' do
      expect(Lich::Common::Room.superclass).to eq(map_class)
    end

    %i[loaded? list raw_list uids clear_tags_cache mark_loaded synchronize_load
       room_from_json].each do |method|
      it "the game class responds to .#{method}" do
        expect(map_class).to respond_to(method)
      end
    end

    %i[dijkstra dijkstra_hashes path_to find_nearest find_nearest_by_tag
       find_all_nearest_by_tag to_json].each do |method|
      it "provides ##{method} to the game class" do
        room = shared_room(1, title: '[One]', description: 'first')

        expect(room.method(method).owner).to eq(Lich::Common::MapBase::InstanceMethods)
      end
    end

    %i[desc map_name geo].each do |method|
      it "keeps the deprecated ##{method} stub" do
        expect(shared_room(1, title: '[One]', description: 'first')).to respond_to(method)
      end
    end

    it 'provides MinHeap' do
      expect(Lich::Common::MinHeap).to be_a(Class)
    end
  end

  # These are byte-identical in both game files, so they belong here rather than
  # being covered for one game and not the other.
  describe 'room bookkeeping identical in both games' do
    describe '.get_free_id' do
      it 'returns one past the highest room id' do
        shared_room(1, title: '[A]', description: 'a')
        shared_room(5, title: '[B]', description: 'b')
        shared_room(3, title: '[C]', description: 'c')

        expect(map_class.get_free_id).to eq(6)
      end

      it 'skips gaps rather than reusing them' do
        shared_room(0, title: '[A]', description: 'a')
        shared_room(9, title: '[B]', description: 'b')

        expect(map_class.get_free_id).to eq(10)
      end

      it 'returns 1 for an empty map rather than raising' do
        expect(map_class.class_variable_get(:@@list).compact).to be_empty

        expect(map_class.get_free_id).to eq(1)
      end

      it 'ignores nil holes when finding the highest id' do
        shared_room(3, title: '[A]', description: 'a')

        expect(map_class.get_free_id).to eq(4)
      end
    end

    describe '.previous_uid' do
      it 'reports the uid the game last navigated from' do
        allow(XMLData).to receive(:previous_nav_rm).and_return(4242)

        expect(map_class.previous_uid).to eq(4242)
      end
    end

    describe '.set_current' do
      before { shared_room(1, title: '[A]', description: 'a') }

      it 'returns the room for the id it was given' do
        expect(map_class.set_current(1).id).to eq(1)
      end

      it 'returns nil for a nil id' do
        expect(map_class.set_current(nil)).to be_nil
      end

      it 'remembers the room it moved away from' do
        map_class.set_current(1)
        shared_room(2, title: '[B]', description: 'b')
        map_class.set_current(2)

        expect(map_class.previous.id).to eq(1)
      end

      it 'does not record a previous room when the id is unchanged' do
        map_class.set_current(1)
        map_class.set_current(1)

        expect(map_class.class_variable_get(:@@previous_room_id)).to be_nil
      end
    end

    describe '.set_fuzzy' do
      before { shared_room(1, title: '[A]', description: 'a') }

      it 'returns the room for the id it was given' do
        expect(map_class.set_fuzzy(1).id).to eq(1)
      end

      it 'returns nil for a nil id' do
        expect(map_class.set_fuzzy(nil)).to be_nil
      end

      it 'leaves the previous room alone when handed nil' do
        map_class.set_fuzzy(1)
        shared_room(2, title: '[B]', description: 'b')
        map_class.set_fuzzy(2)
        before_nil = map_class.class_variable_get(:@@previous_room_id)

        map_class.set_fuzzy(nil)

        expect(map_class.class_variable_get(:@@previous_room_id)).to eq(before_nil)
      end
    end

    describe '.match_no_uid' do
      before { shared_room(1, title: '[A]', description: 'a') }

      it 'matches against the running script when there is one' do
        allow(Script).to receive(:current).and_return(double('Script'))
        allow(map_class).to receive(:match_current).and_return(1)

        expect(map_class.match_no_uid.id).to eq(1)
      end

      it 'falls back to fuzzy matching with no script' do
        allow(Script).to receive(:current).and_return(nil)
        allow(map_class).to receive(:match_fuzzy).and_return(1)

        expect(map_class.match_no_uid.id).to eq(1)
      end

      it 'does not fuzzy match while a script is running' do
        allow(Script).to receive(:current).and_return(double('Script'))
        allow(map_class).to receive(:match_current).and_return(1)
        allow(map_class).to receive(:match_fuzzy)

        map_class.match_no_uid

        expect(map_class).not_to have_received(:match_fuzzy)
      end
    end

    # These paths used to lean on Lich's NilClass patch, which the spec
    # environment does not load, so they raised here and behaved differently in
    # production. They now say what they mean.
    describe 'missing rooms on the negative paths' do
      it 'match_multi_ids returns nil when the current room id is stale' do
        shared_room(1, title: '[A]', description: 'a')
        map_class.current_room_id = 9999

        expect(map_class.match_multi_ids([1])).to be_nil
      end

      it 'match_multi_ids returns nil when the current room id is nil' do
        shared_room(1, title: '[A]', description: 'a')
        map_class.current_room_id = nil

        expect(map_class.match_multi_ids([1])).to be_nil
      end

      it 'estimate_time applies the default for a room that is gone' do
        shared_room(1, title: '[A]', description: 'a')

        # 0.2 per hop is the historical default when no timeto is found.
        expect(map_class.estimate_time([1, 7777, 1])).to be_within(0.001).of(0.4)
      end

      it 'estimate_time does not raise on a path naming a missing room' do
        shared_room(1, title: '[A]', description: 'a')

        expect { map_class.estimate_time([1, 7777]) }.not_to raise_error
      end

      it 'dijkstra skips a dangling wayto edge rather than losing the search' do
        room = shared_room(1, title: '[A]', description: 'a')
        room.wayto['4242'] = 'go'
        room.timeto['4242'] = 0.5

        previous, distances = map_class[1].dijkstra

        expect(previous).to be_a(Hash)
        expect(distances[1]).to eq(0)
      end

      it 'dijkstra still reaches the rooms that do exist alongside a dangling edge' do
        first = shared_room(1, title: '[A]', description: 'a')
        shared_room(2, title: '[B]', description: 'b')
        first.wayto['2'] = 'north'
        first.timeto['2'] = 0.5
        first.wayto['4242'] = 'go'
        first.timeto['4242'] = 0.5

        _, distances = map_class[1].dijkstra

        expect(distances[2]).to eq(0.5)
        # The dangling id still gets a distance, because the weight comes from
        # the source room's timeto; it is only skipped when it cannot be
        # dereferenced to continue the search.
        expect(distances[4242]).to eq(0.5)
      end

      it 'save_json succeeds on an empty map' do
        path = File.join(map_dir, 'saved.json')
        FileUtils.mkdir_p(map_dir)

        expect { map_class.save_json(path) }.not_to raise_error
      end

      it 'save_json does not reload when the map is empty' do
        path = File.join(map_dir, 'saved.json')
        FileUtils.mkdir_p(map_dir)
        allow(map_class).to receive(:reload)

        map_class.save_json(path)

        expect(map_class).not_to have_received(:reload)
      end
    end

    describe '.match_multi_ids' do
      before do
        shared_room(1, title: '[A]', description: 'a')
        shared_room(2, title: '[B]', description: 'b')
        shared_room(3, title: '[C]', description: 'c')
        map_class[1].wayto['2'] = 'north'
        map_class.set_current(1)
      end

      it 'picks the single candidate reachable from the current room' do
        expect(map_class.match_multi_ids([2, 3])).to eq(2)
      end

      it 'returns nil when no candidate is reachable' do
        expect(map_class.match_multi_ids([3])).to be_nil
      end

      it 'returns nil when more than one candidate is reachable' do
        map_class[1].wayto['3'] = 'south'

        expect(map_class.match_multi_ids([2, 3])).to be_nil
      end
    end
  end

  describe 'JSON-only map loading' do
    before do
      FileUtils.mkdir_p(map_dir)
      map_class.class_variable_set(:@@loaded, false)
      allow(map_class).to receive(:respond)
      # load_json names the running script when it reports success.
      allow(Script).to receive(:current).and_return(double('Script', name: 'spec'))
    end

    # Successful loading had no coverage: the examples below only exercised the
    # missing-database and legacy-format paths.
    describe 'a valid JSON database' do
      def write_map(rooms)
        File.write(File.join(map_dir, 'map-1.json'), JSON.dump(rooms))
      end

      def json_room(id, uid: [], tags: [])
        { 'id' => id, 'title' => ["[Room #{id}]"], 'description' => ["Room #{id} description."],
          'paths' => ['Obvious paths: north'], 'uid' => uid, 'tags' => tags,
          'wayto' => {}, 'timeto' => {} }
      end

      it 'loads a dense map' do
        write_map([json_room(0), json_room(1)])

        expect(map_class.load).to be true
      end

      it 'loads a sparse map, ids far apart' do
        write_map([json_room(1), json_room(900)])

        expect(map_class.load).to be true
      end

      it 'names the script that triggered the load' do
        allow(Script).to receive(:current).and_return(double('Script', name: 'go2'))
        write_map([json_room(1)])
        map_class.load

        expect(map_class).to have_received(:respond).with(/go2 Map loaded/)
      end

      it 'omits the name when no script is running' do
        allow(Script).to receive(:current).and_return(nil)
        write_map([json_room(1)])
        map_class.load

        expect(map_class).to have_received(:respond).with(/^--- Map loaded/)
      end

      it 'loads with no script running' do
        allow(Script).to receive(:current).and_return(nil)
        write_map([json_room(1)])

        expect { map_class.load }.not_to raise_error
        expect(map_class[1].id).to eq(1)
      end

      it 'marks the map loaded' do
        write_map([json_room(1)])
        map_class.load

        expect(map_class.loaded?).to be true
      end

      it 'makes the rooms findable by id' do
        write_map([json_room(1), json_room(900)])
        map_class.load

        expect(map_class[900].id).to eq(900)
      end

      it 'indexes uids from a sparse map' do
        write_map([json_room(1, uid: [4242]), json_room(900)])
        map_class.load

        expect(map_class['u4242'].id).to eq(1)
      end

      it 'wraps loaded tags in a TagList' do
        write_map([json_room(1, tags: ['shop'])])
        map_class.load

        expect(map_class[1].tags).to be_a(Lich::Common::TagList)
      end

      it 'indexes loaded tags' do
        write_map([json_room(1, tags: ['shop']), json_room(900, tags: ['shop'])])
        map_class.load

        expect(map_class.rooms_by_tag('shop')).to eq([1, 900])
      end

      it 'finds a room by title after loading' do
        write_map([json_room(7)])
        map_class.load

        expect(map_class['[Room 7]'].id).to eq(7)
      end

      it 'falls back to an older database when the newest is malformed' do
        # load reads the highest-numbered file first.
        File.write(File.join(map_dir, 'map-2.json'), 'not json at all')
        write_map([json_room(1)])

        expect(map_class.load).to be true
        expect(map_class[1].id).to eq(1)
      end

      it 'reports the file it could not load' do
        File.write(File.join(map_dir, 'map-2.json'), 'not json at all')
        write_map([json_room(1)])
        map_class.load

        expect(map_class).to have_received(:respond).with(/failed to load .*map-2\.json/)
      end

      it 'leaves no rooms behind from the file it abandoned' do
        # Parses, registers room 500, then fails on room 501: wayto is a String,
        # so .keys raises after the defaults have been applied. Failing mid-file
        # is the point; a truncated file would fail before anything was
        # registered and so would not exercise the partial cleanup.
        File.write(File.join(map_dir, 'map-2.json'),
                   "[#{JSON.dump(json_room(500))}, #{JSON.dump('id' => 501, 'wayto' => 'not a hash')}]")
        write_map([json_room(1)])
        map_class.load

        expect(map_class[500]).to be_nil
        expect(map_class.class_variable_get(:@@list).compact.map(&:id)).to eq([1])
      end

      it 'falls back when the newest database is truncated' do
        File.write(File.join(map_dir, 'map-2.json'), '[{"id": 500, "title": ["[Room 500]"]')
        write_map([json_room(1)])

        expect(map_class.load).to be true
        expect(map_class[1].id).to eq(1)
      end

      it 'tolerates null wayto and timeto rather than treating them as corrupt' do
        File.write(File.join(map_dir, 'map-1.json'),
                   "[#{JSON.dump('id' => 1, 'title' => ['[R1]'], 'description' => ['d'],
                                 'paths' => ['Obvious paths: north'], 'wayto' => nil,
                                 'timeto' => nil)}]")

        expect(map_class.load).to be true
        expect(map_class[1].wayto).to eq({})
        expect(map_class[1].timeto).to eq({})
      end

      # The shipped mapdb has rooms with no description or paths, such as the
      # fog transitions, so these must load rather than being rejected.
      it 'loads a room with no description' do
        File.write(File.join(map_dir, 'map-1.json'),
                   JSON.dump([{ 'id' => 12_099, 'title' => ['[Lost in an Ethereal Fog]'],
                                'wayto' => { '24029' => 'east' }, 'timeto' => { '24029' => 120 },
                                'tags' => ['no-auto-map'], 'uid' => [4_562_100] }]))

        expect(map_class.load).to be true
        expect(map_class[12_099].description).to eq([])
      end

      it 'loads a room with no paths' do
        File.write(File.join(map_dir, 'map-1.json'),
                   JSON.dump([{ 'id' => 12_099, 'title' => ['[Lost in an Ethereal Fog]'] }]))

        expect(map_class.load).to be true
        expect(map_class[12_099].paths).to eq([])
      end

      it 'keeps such a room usable' do
        File.write(File.join(map_dir, 'map-1.json'),
                   JSON.dump([{ 'id' => 12_099, 'title' => ['[Lost in an Ethereal Fog]'],
                                'uid' => [4_562_100] }]))
        map_class.load

        expect(map_class['u4562100'].id).to eq(12_099)
        expect(map_class[12_099].outside?).to be false
      end

      it 'rejects a database whose room id is not an Integer' do
        File.write(File.join(map_dir, 'map-2.json'),
                   JSON.dump([{ 'id' => 'five', 'title' => ['[R5]'] }]))
        write_map([json_room(1)])

        expect(map_class.load).to be true
        expect(map_class[1].id).to eq(1)
      end

      it 'names the id it could not use' do
        File.write(File.join(map_dir, 'map-2.json'),
                   JSON.dump([{ 'id' => 'five', 'title' => ['[R5]'] }]))
        write_map([json_room(1)])
        map_class.load

        expect(map_class).to have_received(:respond).with(/room id is not an Integer/)
      end

      it 'returns false when every candidate is malformed' do
        File.write(File.join(map_dir, 'map-1.json'), 'not json')
        File.write(File.join(map_dir, 'map-2.json'), 'also not json')

        expect(map_class.load).to be false
      end

      it 'does not mark the map loaded when every candidate is malformed' do
        File.write(File.join(map_dir, 'map-1.json'), 'not json')

        map_class.load

        expect(map_class.loaded?).to be false
      end
    end

    it 'refuses a directory holding only legacy formats' do
      File.binwrite(File.join(map_dir, 'map-1.dat'), Marshal.dump([]))
      File.write(File.join(map_dir, 'map.xml'), '<map></map>')

      expect(map_class.load).to be false
    end

    it 'refuses a .dat map database' do
      File.binwrite(File.join(map_dir, 'map-1.dat'), Marshal.dump([]))

      expect(map_class.load).to be false
    end

    it 'refuses an .xml map database' do
      File.write(File.join(map_dir, 'map-1.xml'), '<map></map>')

      expect(map_class.load).to be false
    end

    it 'names the legacy files it found' do
      File.binwrite(File.join(map_dir, 'map-1.dat'), Marshal.dump([]))
      File.write(File.join(map_dir, 'map.xml'), '<map></map>')
      map_class.load

      expect(map_class).to have_received(:respond).with(/map-1\.dat, map\.xml/)
    end

    it 'explains that the format is unsupported' do
      File.binwrite(File.join(map_dir, 'map-1.dat'), Marshal.dump([]))
      map_class.load

      expect(map_class).to have_received(:respond).with(/no longer supported/)
    end

    it 'refuses an explicitly named legacy path without raising' do
      path = File.join(map_dir, 'map-1.dat')
      File.binwrite(path, Marshal.dump([]))

      expect { map_class.load(path) }.not_to raise_error
    end

    it 'returns false for an explicitly named legacy path' do
      path = File.join(map_dir, 'map-1.dat')
      File.binwrite(path, Marshal.dump([]))

      expect(map_class.load(path)).to be false
    end

    it 'names the explicitly requested legacy file' do
      path = File.join(map_dir, 'map-1.dat')
      File.binwrite(path, Marshal.dump([]))
      map_class.load(path)

      expect(map_class).to have_received(:respond).with(/no longer supported: map-1\.dat/)
    end

    it 'stays quiet about legacy formats when there are none' do
      map_class.load

      expect(map_class).not_to have_received(:respond).with(/no longer supported/)
    end

    it 'recovers from an unusable candidate without deadlocking on the load mutex' do
      # The rescue path runs with the load mutex held, so it must not reach for
      # anything that re-enters it.
      File.write(File.join(map_dir, 'map-2.json'), 'not json')
      File.write(File.join(map_dir, 'map-1.json'),
                 JSON.dump([{ 'id' => 1, 'title' => ['[R1]'], 'description' => ['d'],
                              'paths' => ['Obvious paths: north'], 'wayto' => {}, 'timeto' => {} }]))

      expect { Timeout.timeout(5) { map_class.load } }.not_to raise_error
      expect(map_class[1].id).to eq(1)
    end

    it 'reports rather than raising when the data directory does not exist' do
      FileUtils.rm_rf(map_dir)

      result = nil
      expect { result = map_class.load }.not_to raise_error
      expect(result).to be false
      expect(map_class).to have_received(:respond).with(/no map database found/)
    end

    it 'still reports when no map database is present at all' do
      map_class.load

      expect(map_class).to have_received(:respond).with(/no map database found/)
    end
  end
end
