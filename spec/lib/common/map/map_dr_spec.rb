# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'json'
require 'fileutils'
require_relative 'game_map_shared_examples'

# Mock StringProc
class StringProc
  def initialize(string)
    @string = string
  end

  def call(*_args)
    eval(@string)
  end

  def _dump(_level = nil)
    @string
  end

  def to_json(*args)
    ";e #{_dump}".to_json(args)
  end

  def class
    Proc
  end

  def is_a?(klass)
    klass == Proc || super
  end
end unless defined?(StringProc)

# Mock DATA_DIR
DATA_DIR = '/tmp/lich_test_data' unless defined?(DATA_DIR)

# Update XMLData mock for DR
XMLData = OpenStruct.new(
  game: 'DR',
  name: 'TestChar',
  room_id: 12345,
  room_count: 1,
  room_title: '[Test Room]',
  room_description: 'A test room description.',
  room_exits_string: 'Obvious paths: north, south',
  room_window_disabled: false,
  previous_nav_rm: 11111
) unless defined?(XMLData)

# When the shared spec_helper XMLData module wins (the usual case), it does not
# declare the DR-specific room fields the matchers read. Add them idempotently
# so the matching specs below can drive them via plain assignment.
if defined?(XMLData) && XMLData.is_a?(Module)
  module XMLData
    class << self
      attr_accessor :room_exits_string, :room_count, :room_window_disabled, :previous_nav_rm
    end
  end
end

# Mock Script
module Script
  def self.current
    @current_script
  end

  def self.set_current(script)
    @current_script = script
  end

  def self.clear_current!
    @current_script = nil
  end
end unless defined?(Script)

# Mock global methods
def echo(msg)
  @echo_messages ||= []
  @echo_messages << msg
end

def respond(msg)
  @respond_messages ||= []
  @respond_messages << msg
end

def put(cmd); end

# Load the DR map
MapLoader.use(:dr)

RSpec.describe Lich::Common::Map, 'DragonRealms implementation' do
  it_behaves_like 'a game Map class', :dr

  let(:map_class) { Lich::Common::Map }

  before { MapLoader.use(:dr) }

  before(:each) do
    # Clear room registry via the public API
    map_class.clear rescue nil
    # NOTE: class_variable_set is acceptable here because Map has no reset! method.
    # map_class.clear handles @@rooms but leaves @@uids and the room-navigation class
    # variables (@@previous_room_id, @@current_room_id, @@current_room_count) at their
    # last values, which would bleed across tests. Reset them directly until a reset!
    # method is added to Map. TODO: add Map.reset! to production code.
    map_class.class_variable_set(:@@uids, {})
    map_class.class_variable_set(:@@previous_room_id, -1)
    map_class.class_variable_set(:@@current_room_id, -1)
    map_class.class_variable_set(:@@current_room_count, -1)
  end

  describe 'class structure' do
    it 'includes MapBase module' do
      expect(map_class.included_modules).to include(Lich::Common::MapBase)
    end

    it 'includes Enumerable' do
      expect(map_class.included_modules).to include(Enumerable)
    end
  end

  describe 'attributes' do
    let(:room) do
      map_class.new(
        1,
        ['Test Title'],
        ['Test description'],
        ['Obvious paths: north'],
        [12345],
        'Test Location',
        'temperate',
        'urban',
        { '2' => 'north' },
        { '2' => 0.2 },
        'test.png',
        [10, 20, 30, 40],
        ['test-tag'],
        false,
        nil,
        ['chest', 'box']
      )
    end

    it 'has id attribute' do
      expect(room.id).to eq(1)
    end

    it 'has title attribute' do
      expect(room.title).to eq(['Test Title'])
    end

    it 'has description attribute' do
      expect(room.description).to eq(['Test description'])
    end

    it 'has paths attribute' do
      expect(room.paths).to eq(['Obvious paths: north'])
    end

    it 'has uid attribute' do
      expect(room.uid).to eq([12345])
    end

    it 'has location attribute' do
      expect(room.location).to eq('Test Location')
    end

    it 'has climate attribute' do
      expect(room.climate).to eq('temperate')
    end

    it 'has terrain attribute' do
      expect(room.terrain).to eq('urban')
    end

    it 'has wayto attribute' do
      expect(room.wayto).to eq({ '2' => 'north' })
    end

    it 'has timeto attribute' do
      expect(room.timeto).to eq({ '2' => 0.2 })
    end

    it 'has image attribute' do
      expect(room.image).to eq('test.png')
    end

    it 'has image_coords attribute' do
      expect(room.image_coords).to eq([10, 20, 30, 40])
    end

    it 'has tags attribute' do
      expect(room.tags).to eq(['test-tag'])
    end

    it 'has check_location attribute' do
      expect(room.check_location).to eq(false)
    end

    it 'has unique_loot attribute' do
      expect(room.unique_loot).to be_nil
    end

    it 'has room_objects attribute (DR-specific)' do
      expect(room).to respond_to(:room_objects)
    end
  end

  describe '#to_s' do
    let(:room) do
      map_class.new(
        42,
        ['[Town Square]'],
        ['You are in a town square.'],
        ['Obvious paths: north, east'],
        [99999]
      )
    end

    it 'returns formatted string representation' do
      str = room.to_s
      expect(str).to include('#42')
      expect(str).to include('99999')
      expect(str).to include('[Town Square]')
      expect(str).to include('You are in a town square.')
      expect(str).to include('Obvious paths: north, east')
    end
  end

  describe '#outside?' do
    it 'returns true for Obvious paths:' do
      room = map_class.new(1, ['Title'], ['Desc'], ['Obvious paths: north'])
      expect(room.outside?).to be true
    end

    it 'returns false for Obvious exits:' do
      room = map_class.new(1, ['Title'], ['Desc'], ['Obvious exits: north'])
      expect(room.outside?).to be false
    end
  end

  describe '#inside?' do
    it 'returns true for Obvious exits:' do
      room = map_class.new(1, ['Title'], ['Desc'], ['Obvious exits: north'])
      expect(room.inside?).to be true
    end

    it 'returns false for Obvious paths:' do
      room = map_class.new(1, ['Title'], ['Desc'], ['Obvious paths: north'])
      expect(room.inside?).to be false
    end
  end

  # NOTE: Several nested before blocks below use class_variable_set(:@@loaded, true).
  # This is acceptable because Map has no reset! or public setter for the @@loaded guard.
  # Setting @@loaded=true is the only way to put the map into a testable "loaded" state
  # without loading an actual map file. The outer before(:each) calls map_class.clear
  # which resets @@loaded back to false between tests.
  describe 'class methods' do
    describe '.loaded?' do
      it 'returns false initially' do
        expect(map_class.loaded?).to be false
      end
    end

    describe '.get_free_id' do
      before do
        # Set @@loaded=true so methods that guard on loaded? are accessible (see NOTE above)
        map_class.class_variable_set(:@@loaded, true)
        map_class.new(1, ['A'], ['a'], ['path'])
        map_class.new(5, ['B'], ['b'], ['path'])
        map_class.new(3, ['C'], ['c'], ['path'])
      end

      it 'returns next available id' do
        expect(map_class.get_free_id).to eq(6)
      end
    end

    describe '.[]' do
      before do
        map_class.class_variable_set(:@@loaded, true) # see NOTE above
        map_class.new(1, ['Title A'], ['Description A'], ['path'])
        map_class.new(2, ['Title B'], ['Description B'], ['path'])
      end

      it 'retrieves room by integer id' do
        room = map_class[1]
        expect(room.title).to eq(['Title A'])
      end

      it 'retrieves room by string id' do
        room = map_class['2']
        expect(room.title).to eq(['Title B'])
      end

      it 'retrieves room by uid with u prefix' do
        map_class.class_variable_get(:@@uids)[99999] = [1]
        room = map_class['u99999']
        expect(room.title).to eq(['Title A'])
      end

      it 'searches by title substring' do
        room = map_class['Title A']
        expect(room.id).to eq(1)
      end

      it 'returns nil for non-existent room' do
        expect(map_class[999]).to be_nil
      end
    end

    describe '.previous' do
      before do
        map_class.class_variable_set(:@@loaded, true) # see NOTE above
        map_class.new(1, ['Room A'], ['desc'], ['path'])
        map_class.new(2, ['Room B'], ['desc'], ['path'])
        # NOTE: @@previous_room_id has no public setter; class_variable_set is the only
        # way to simulate a previous-room navigation state for this test.
        map_class.class_variable_set(:@@previous_room_id, 1)
      end

      it 'returns previous room' do
        expect(map_class.previous.id).to eq(1)
      end
    end

    describe '.previous_uid' do
      it 'returns XMLData.previous_nav_rm' do
        allow(XMLData).to receive(:previous_nav_rm).and_return(22222)
        expect(map_class.previous_uid).to eq(22222)
      end
    end

    describe 'UID management' do
      describe '.uids_add' do
        it 'adds uid mapping' do
          map_class.uids_add(12345, 1)
          expect(map_class.ids_from_uid(12345)).to eq([1])
        end

        it 'appends to existing uid' do
          map_class.uids_add(12345, 1)
          map_class.uids_add(12345, 2)
          expect(map_class.ids_from_uid(12345)).to eq([1, 2])
        end

        it 'does not duplicate ids' do
          map_class.uids_add(12345, 1)
          map_class.uids_add(12345, 1)
          expect(map_class.ids_from_uid(12345)).to eq([1])
        end
      end

      describe '.ids_from_uid' do
        it 'returns empty array for unknown uid' do
          expect(map_class.ids_from_uid(99999)).to eq([])
        end

        it 'returns empty array for uid 0' do
          map_class.uids_add(0, 1)
          expect(map_class.ids_from_uid(0)).to eq([])
        end
      end
    end

    describe '.tags' do
      before do
        map_class.class_variable_set(:@@loaded, true) # see NOTE above
        map_class.new(1, ['A'], ['a'], ['path'], [], nil, nil, nil, {}, {}, nil, nil, ['tag1', 'tag2'])
        map_class.new(2, ['B'], ['b'], ['path'], [], nil, nil, nil, {}, {}, nil, nil, ['tag2', 'tag3'])
      end

      it 'returns unique tags from all rooms' do
        tags = map_class.tags
        expect(tags).to include('tag1')
        expect(tags).to include('tag2')
        expect(tags).to include('tag3')
        expect(tags.count('tag2')).to eq(1) # No duplicates
      end
    end

    describe '.clear' do
      before do
        map_class.class_variable_set(:@@loaded, true) # see NOTE above
        map_class.new(1, ['A'], ['a'], ['path'])
      end

      it 'clears the map list' do
        map_class.clear
        # Access @@list directly since list method would trigger load
        expect(map_class.class_variable_get(:@@list)).to be_empty
      end

      it 'resets loaded flag' do
        map_class.clear
        expect(map_class.loaded?).to be false
      end
    end

    describe '.reload' do
      it 'calls clear then load' do
        expect(map_class).to receive(:clear).ordered
        expect(map_class).to receive(:load).ordered
        map_class.reload
      end
    end
  end

  describe 'Genie field support' do
    describe '#initialize' do
      it 'accepts genie fields as parameters' do
        room = map_class.new(
          1, ['Title'], ['Desc'], ['path'], [1], nil, nil, nil, {}, {}, nil, nil, [], nil, nil, nil,
          'node42', 'zone7', 'pos1'
        )

        expect(room.genie_id).to eq('node42')
        expect(room.genie_zone).to eq('zone7')
        expect(room.genie_pos).to eq('pos1')
      end

      it 'defaults genie fields to nil' do
        room = map_class.new(1, ['Title'], ['Desc'], ['path'])

        expect(room.genie_id).to be_nil
        expect(room.genie_zone).to be_nil
        expect(room.genie_pos).to be_nil
      end
    end

    describe '#json_extra_fields' do
      it 'returns genie fields hash' do
        room = map_class.new(
          1, ['Title'], ['Desc'], ['path'], [1], nil, nil, nil, {}, {}, nil, nil, [], nil, nil, nil,
          'node42', 'zone7', 'pos1'
        )

        extra = room.json_extra_fields
        expect(extra[:genie_id]).to eq('node42')
        expect(extra[:genie_zone]).to eq('zone7')
        expect(extra[:genie_pos]).to eq('pos1')
      end
    end

    describe '#to_json with genie fields' do
      it 'includes genie fields when present' do
        room = map_class.new(
          1, ['Title'], ['Desc'], ['path'], [1], nil, nil, nil, {}, {}, nil, nil, [], nil, nil, nil,
          'node42', 'zone7', nil
        )

        json = room.to_json
        parsed = JSON.parse(json)
        expect(parsed['genie_id']).to eq('node42')
        expect(parsed['genie_zone']).to eq('zone7')
      end

      it 'excludes genie fields when nil' do
        room = map_class.new(1, ['Title'], ['Desc'], ['path'])

        json = room.to_json
        parsed = JSON.parse(json)
        expect(parsed).not_to have_key('genie_id')
        expect(parsed).not_to have_key('genie_zone')
        expect(parsed).not_to have_key('genie_pos')
      end
    end

    describe '.by_genie_ref' do
      before do
        map_class.class_variable_set(:@@loaded, true)
        map_class.new(
          1, ['Room A'], ['desc'], ['path'], [], nil, nil, nil, {}, {}, nil, nil, [], nil, nil, nil,
          '42', '7', nil
        )
        map_class.new(
          2, ['Room B'], ['desc'], ['path'], [], nil, nil, nil, {}, {}, nil, nil, [], nil, nil, nil,
          '99', '7', nil
        )
        map_class.new(
          3, ['Room C'], ['desc'], ['path'], [], nil, nil, nil, {}, {}, nil, nil, [], nil, nil, nil,
          '42', '10', nil
        )
      end

      it 'finds room by zone and node id' do
        room = map_class.by_genie_ref('7', '42')
        expect(room.id).to eq(1)
      end

      it 'returns nil for nonexistent reference' do
        room = map_class.by_genie_ref('999', '999')
        expect(room).to be_nil
      end

      it 'converts integer arguments to strings for comparison' do
        room = map_class.by_genie_ref(7, 42)
        expect(room.id).to eq(1)
      end
    end
  end

  describe 'JSON serialization' do
    let(:room) do
      map_class.new(
        1,
        ['Test Room'],
        ['A test description'],
        ['Obvious paths: north'],
        [12345],
        'Test Area',
        'temperate',
        'urban',
        { '2' => 'north' },
        { '2' => 0.5 },
        nil,
        nil,
        ['shop'],
        false,
        nil
      )
    end

    it 'serializes to JSON' do
      json = room.to_json
      parsed = JSON.parse(json)

      expect(parsed['id']).to eq(1)
      expect(parsed['title']).to eq(['Test Room'])
      expect(parsed['paths']).to eq(['Obvious paths: north'])
      expect(parsed['wayto']).to eq({ '2' => 'north' })
      expect(parsed['timeto']).to eq({ '2' => 0.5 })
      expect(parsed['tags']).to eq(['shop'])
    end

    it 'omits nil values' do
      json = room.to_json
      parsed = JSON.parse(json)

      expect(parsed).not_to have_key('image')
      expect(parsed).not_to have_key('image_coords')
    end
  end

  describe 'nav-tag room id integration' do
    it 'previous_uid returns XMLData.previous_nav_rm (now populated from the <nav> tag)' do
      XMLData.previous_nav_rm = 4242
      expect(map_class.previous_uid).to eq(4242)
    end

    it 'ids_from_uid treats 0 as "no uid" even if a room was stamped with it' do
      map_class.uids_add(0, 9)
      expect(map_class.ids_from_uid(0)).to eq([])
    end

    it 'ids_from_uid resolves a real (nonzero) uid to its room ids' do
      map_class.uids_add(230008, 5)
      expect(map_class.ids_from_uid(230008)).to eq([5])
    end
  end

  # DR sometimes streams a blank/incomplete arrival before the <nav> UID lands: room_id 0, the
  # description is only the "pitch dark" placeholder, and there are no exits. current_or_new must
  # not mint a junk room from that frame (it would orphan/duplicate the real room); it keeps the
  # current room until a real frame/UID arrives.
  describe 'blank/incomplete arrival-frame guard (current_or_new)' do
    before do
      allow(Script).to receive(:current).and_return(double('script'))
      allow(map_class).to receive(:current).and_return(nil) # force the create/guard path
      map_class.class_variable_set(:@@loaded, true)
      # Seed a room so get_free_id has a base and there is a "current" to fall back to.
      map_class.new(1, ['[[Seed Room]]'], ['seed desc'], ['Obvious exits: north'], [])
      map_class.class_variable_set(:@@current_room_id, 1)
    end

    def stub_frame(room_id:, title:, description:, exits:)
      allow(XMLData).to receive(:room_id).and_return(room_id)
      allow(XMLData).to receive(:room_title).and_return(title)
      allow(XMLData).to receive(:room_description).and_return(description)
      allow(XMLData).to receive(:room_exits_string).and_return(exits)
    end

    it 'does not mint a stub when the frame is blank (no uid, pitch-dark desc, no exits)' do
      stub_frame(room_id: 0, title: '[]',
                 description: "It's pitch dark and you can't see a thing!", exits: '')
      expect { map_class.current_or_new }.not_to(change { map_class.list.compact.size })
    end

    it 'keeps the current room when it skips the blank frame' do
      stub_frame(room_id: 0, title: '[]',
                 description: "It's pitch dark and you can't see a thing!", exits: '')
      expect(map_class.current_or_new).to eq(map_class[1])
    end

    it 'still maps a normal complete arrival into a new room' do
      stub_frame(room_id: 54202, title: '[[Catacombs, Labyrinth]]',
                 description: 'The narrow passageways of these burial chambers give rise to new horrors.',
                 exits: 'Obvious exits: east, west')
      expect { map_class.current_or_new }.to change { map_class.list.compact.size }.by(1)
    end

    # Before any room resolves, @@current_room_id is the -1 sentinel. A blank frame
    # must not fall back to set_current(-1), which would index @@list[-1] (the last
    # room) and make an unrelated room current; it returns nil instead.
    it 'returns nil (not the last room) for a blank frame when no room has resolved yet' do
      map_class.class_variable_set(:@@current_room_id, -1)
      stub_frame(room_id: 0, title: '[]',
                 description: "It's pitch dark and you can't see a thing!", exits: '')
      expect(map_class.current_or_new).to be_nil
    end

    it 'does not mint a stub for a blank frame when current_room_id is the -1 sentinel' do
      map_class.class_variable_set(:@@current_room_id, -1)
      stub_frame(room_id: 0, title: '[]',
                 description: "It's pitch dark and you can't see a thing!", exits: '')
      expect { map_class.current_or_new }.not_to(change { map_class.list.compact.size })
    end
  end
end

RSpec.describe Lich::Common::Room, 'DragonRealms' do
  before { MapLoader.use(:dr) }
  it 'inherits from Map' do
    expect(Lich::Common::Room.superclass).to eq(Lich::Common::Map)
  end

  it 'delegates method_missing to super' do
    expect { Lich::Common::Room.nonexistent_method }.to raise_error(NoMethodError)
  end
end

# =============================================================================
# UID-aware room resolution
# =============================================================================
# Exercises the shared UID-disambiguation helper (resolve_matched_room) and the
# two matchers that delegate to it (match_current for scripted matching,
# match_fuzzy for scriptless matching), plus the end-to-end Map.current path.
#
# The behavior under test is the "no-UID fallback" invariant: a stored UID must
# never make a room *less* resolvable than an otherwise identical room with no
# UID. When the game exposes a live UID (XMLData.room_id != 0), a UID'd room only
# matches if the live UID is among its stored UIDs; when the game exposes no UID
# (XMLData.room_id == 0), UID disambiguation is skipped and the
# title/description/paths match is trusted regardless of any stored UID.
RSpec.describe Lich::Common::Map, 'UID-aware room resolution' do
  let(:map_class) { Lich::Common::Map }

  before { MapLoader.use(:dr) }

  # Build and register a room. Ids need not be dense: the matchers and load_uids
  # both skip nil holes.
  def build_room(id, title:, description:, exits:, uid: [], tags: [])
    map_class.new(id, [title], [description], [exits], uid,
                  nil, nil, nil, {}, {}, nil, nil, tags)
  end

  # Point the live XMLData room fields at a single room reading.
  def live_room(title:, description:, exits:, room_id:, room_count: 1, window_disabled: false)
    XMLData.room_title           = title
    XMLData.room_description     = description
    XMLData.room_exits_string    = exits
    XMLData.room_id              = room_id
    XMLData.room_count           = room_count
    XMLData.room_window_disabled = window_disabled
  end

  before(:each) do
    map_class.clear rescue nil
    # clear resets @@loaded to false; the matchers must not try to load a file,
    # so mark the (empty) registry loaded and reset every navigation cache var.
    map_class.class_variable_set(:@@uids, {})
    map_class.class_variable_set(:@@previous_room_id, -1)
    map_class.class_variable_set(:@@current_room_id, -1)
    map_class.class_variable_set(:@@current_room_count, -1)
    map_class.class_variable_set(:@@fuzzy_room_count, -1)
    map_class.class_variable_set(:@@loaded, true)
    Script.current = nil
  end

  # ---------------------------------------------------------------------------
  describe '.peer_disambiguation_tag?' do
    it 'is true for a bare peer tag' do
      room = build_room(0, title: 'T', description: 'D', exits: 'E', tags: ['peer window =~ /a guard/'])
      expect(map_class.peer_disambiguation_tag?(room)).to be true
    end

    it 'is true for a peer tag carrying the "set desc on; " prefix' do
      room = build_room(0, title: 'T', description: 'D', exits: 'E', tags: ['set desc on; peer east =~ /a door/'])
      expect(map_class.peer_disambiguation_tag?(room)).to be true
    end

    it 'is true when at least one of several tags is a peer tag' do
      room = build_room(0, title: 'T', description: 'D', exits: 'E', tags: ['no-uid', 'peer north =~ /trail/'])
      expect(map_class.peer_disambiguation_tag?(room)).to be true
    end

    it 'is false for a room with no tags' do
      room = build_room(0, title: 'T', description: 'D', exits: 'E', tags: [])
      expect(map_class.peer_disambiguation_tag?(room)).to be false
    end

    it 'is false for a peer-like tag missing the =~ clause' do
      room = build_room(0, title: 'T', description: 'D', exits: 'E', tags: ['peer east'])
      expect(map_class.peer_disambiguation_tag?(room)).to be false
    end

    it 'is false when the verb is "peers" rather than "peer "' do
      room = build_room(0, title: 'T', description: 'D', exits: 'E', tags: ['peers east =~ /door/'])
      expect(map_class.peer_disambiguation_tag?(room)).to be false
    end

    it 'is false for an unrelated tag' do
      room = build_room(0, title: 'T', description: 'D', exits: 'E', tags: ['lich-map-no-uid-room'])
      expect(map_class.peer_disambiguation_tag?(room)).to be false
    end
  end

  # ---------------------------------------------------------------------------
  describe '.resolve_matched_room' do
    context 'when the matched room has no stored UID' do
      it 'resolves to the room id when the game exposes a UID (exact path)' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [])
        XMLData.room_id = 4242
        expect(map_class.resolve_matched_room(room, honor_peer_tags: false)).to eq(0)
      end

      it 'resolves to the room id when the game exposes no UID (exact path)' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [])
        XMLData.room_id = 0
        expect(map_class.resolve_matched_room(room, honor_peer_tags: false)).to eq(0)
      end

      it 'resolves to the room id when the game exposes a UID (fuzzy path, no peer tag)' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [])
        XMLData.room_id = 4242
        expect(map_class.resolve_matched_room(room, honor_peer_tags: true)).to eq(0)
      end
    end

    context 'when the game exposes a UID the room carries' do
      it 'resolves to the room id (exact path)' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [500])
        XMLData.room_id = 500
        expect(map_class.resolve_matched_room(room, honor_peer_tags: false)).to eq(0)
      end

      it 'resolves to the room id (fuzzy path) even when a peer tag is present, because the UID branch wins' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [500], tags: ['peer east =~ /gate/'])
        XMLData.room_id = 500
        expect(map_class.resolve_matched_room(room, honor_peer_tags: true)).to eq(0)
      end

      it 'resolves to the room id when the live UID is the second of several stored UIDs' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [500, 501])
        XMLData.room_id = 501
        expect(map_class.resolve_matched_room(room, honor_peer_tags: false)).to eq(0)
      end
    end

    context 'when the game exposes a UID the room does not carry' do
      it 'rejects the match with nil (exact path)' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [500])
        XMLData.room_id = 999
        expect(map_class.resolve_matched_room(room, honor_peer_tags: false)).to be_nil
      end

      it 'rejects the match with nil (fuzzy path)' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [500])
        XMLData.room_id = 999
        expect(map_class.resolve_matched_room(room, honor_peer_tags: true)).to be_nil
      end

      it 'rejects the match with nil when none of several stored UIDs match' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [500, 501])
        XMLData.room_id = 888
        expect(map_class.resolve_matched_room(room, honor_peer_tags: false)).to be_nil
      end
    end

    context 'when the game exposes no UID (room_id 0) on a UID-stamped room -- the no-UID fallback fix' do
      it 'resolves to the room id instead of nil (exact path)' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [500])
        XMLData.room_id = 0
        expect(map_class.resolve_matched_room(room, honor_peer_tags: false)).to eq(0)
      end

      it 'resolves to the room id instead of nil (fuzzy path, no peer tag)' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [500])
        XMLData.room_id = 0
        expect(map_class.resolve_matched_room(room, honor_peer_tags: true)).to eq(0)
      end

      it 'resolves to the room id for a multi-UID room' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [500, 501])
        XMLData.room_id = 0
        expect(map_class.resolve_matched_room(room, honor_peer_tags: false)).to eq(0)
      end
    end

    context 'peer-disambiguation tag interplay' do
      it 'rejects a no-UID peer room with nil on the fuzzy path (game exposes a UID)' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [], tags: ['peer east =~ /gate/'])
        XMLData.room_id = 4242
        expect(map_class.resolve_matched_room(room, honor_peer_tags: true)).to be_nil
      end

      it 'ignores the peer tag on the exact path and resolves to the room id' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [], tags: ['peer east =~ /gate/'])
        XMLData.room_id = 4242
        expect(map_class.resolve_matched_room(room, honor_peer_tags: false)).to eq(0)
      end

      it 'still rejects a no-UID peer room with nil on the fuzzy path when the game exposes no UID' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [], tags: ['peer east =~ /gate/'])
        XMLData.room_id = 0
        expect(map_class.resolve_matched_room(room, honor_peer_tags: true)).to be_nil
      end

      it 'rejects a UID room with a peer tag on the fuzzy path once the UID branch is skipped for room_id 0' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [500], tags: ['peer east =~ /gate/'])
        XMLData.room_id = 0
        expect(map_class.resolve_matched_room(room, honor_peer_tags: true)).to be_nil
      end

      it 'resolves a UID room with a peer tag on the exact path for room_id 0 (peer never consulted)' do
        room = build_room(0, title: 'T', description: 'D', exits: 'E', uid: [500], tags: ['peer east =~ /gate/'])
        XMLData.room_id = 0
        expect(map_class.resolve_matched_room(room, honor_peer_tags: false)).to eq(0)
      end
    end
  end

  # ---------------------------------------------------------------------------
  describe '.match_current' do
    it 'resolves a UID room by exact match when the game exposes a matching UID' do
      build_room(0, title: 'Town Square', description: 'A wide plaza.', exits: 'Obvious paths: north', uid: [70])
      live_room(title: 'Town Square', description: 'A wide plaza.', exits: 'Obvious paths: north', room_id: 70)
      expect(map_class.match_current(nil)).to eq(0)
    end

    it 'rejects a UID room by exact match when the game exposes a non-matching UID' do
      build_room(0, title: 'Town Square', description: 'A wide plaza.', exits: 'Obvious paths: north', uid: [70])
      live_room(title: 'Town Square', description: 'A wide plaza.', exits: 'Obvious paths: north', room_id: 71)
      expect(map_class.match_current(nil)).to be_nil
    end

    it 'resolves a UID room by exact match when the game exposes no UID (the fix)' do
      build_room(0, title: 'Auditorium', description: 'Rows of seats.', exits: 'Obvious paths: out', uid: [12015])
      live_room(title: 'Auditorium', description: 'Rows of seats.', exits: 'Obvious paths: out', room_id: 0)
      expect(map_class.match_current(nil)).to eq(0)
    end

    it 'resolves a no-UID room by exact match' do
      build_room(0, title: 'Auditorium', description: 'Rows of seats.', exits: 'Obvious paths: out', uid: [])
      live_room(title: 'Auditorium', description: 'Rows of seats.', exits: 'Obvious paths: out', room_id: 0)
      expect(map_class.match_current(nil)).to eq(0)
    end

    it 'ignores a peer-disambiguation tag on the exact path and resolves the room' do
      build_room(0, title: 'Foggy Ledge', description: 'A narrow ledge.', exits: 'Obvious paths: down',
                    uid: [], tags: ['peer down =~ /a chasm/'])
      live_room(title: 'Foggy Ledge', description: 'A narrow ledge.', exits: 'Obvious paths: down', room_id: 0)
      expect(map_class.match_current(nil)).to eq(0)
    end

    it 'falls back to the punctuation-tolerant regex description branch and applies the fix' do
      # Stored description ends with a period; live reading drops it, so the exact
      # include? fails and the regex branch must carry the match.
      build_room(0, title: 'Garden Path', description: 'A winding path.', exits: 'Obvious paths: east', uid: [150013])
      live_room(title: 'Garden Path', description: 'A winding path', exits: 'Obvious paths: east', room_id: 0)
      expect(map_class.match_current(nil)).to eq(0)
    end

    it 'matches on title and paths alone when the room window is disabled' do
      build_room(0, title: 'Dim Cellar', description: 'The stored cellar description.', exits: 'Obvious paths: up', uid: [])
      live_room(title: 'Dim Cellar', description: 'A completely different live description',
                exits: 'Obvious paths: up', room_id: 0, window_disabled: true)
      expect(map_class.match_current(nil)).to eq(0)
    end

    it 'ignores the paths line when exits are obscured by fog' do
      build_room(0, title: 'Misty Field', description: 'Fog rolls across the field.', exits: 'Obvious paths: north, south', uid: [])
      live_room(title: 'Misty Field', description: 'Fog rolls across the field.',
                exits: 'Obvious paths: obscured by a thick fog', room_id: 0)
      expect(map_class.match_current(nil)).to eq(0)
    end

    it 'returns nil when nothing matches' do
      build_room(0, title: 'Town Square', description: 'A wide plaza.', exits: 'Obvious paths: north', uid: [])
      live_room(title: 'Nowhere', description: 'The void.', exits: 'Obvious paths: none', room_id: 0)
      expect(map_class.match_current(nil)).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  describe '.match_fuzzy' do
    it 'resolves a UID room when the game exposes a matching UID' do
      build_room(0, title: 'Town Square', description: 'A wide plaza.', exits: 'Obvious paths: north', uid: [70])
      live_room(title: 'Town Square', description: 'A wide plaza.', exits: 'Obvious paths: north', room_id: 70)
      expect(map_class.match_fuzzy).to eq(0)
    end

    it 'resolves a UID room when the game exposes no UID (the fix)' do
      build_room(0, title: 'Auditorium', description: 'Rows of seats.', exits: 'Obvious paths: out', uid: [12015])
      live_room(title: 'Auditorium', description: 'Rows of seats.', exits: 'Obvious paths: out', room_id: 0)
      expect(map_class.match_fuzzy).to eq(0)
    end

    it 'rejects a no-UID peer room with nil (cannot peer without a script)' do
      build_room(0, title: 'Foggy Ledge', description: 'A narrow ledge.', exits: 'Obvious paths: down',
                    uid: [], tags: ['peer down =~ /a chasm/'])
      live_room(title: 'Foggy Ledge', description: 'A narrow ledge.', exits: 'Obvious paths: down', room_id: 0)
      expect(map_class.match_fuzzy).to be_nil
    end

    it 'rejects a UID peer room with nil once the UID branch is skipped for room_id 0' do
      build_room(0, title: 'Foggy Ledge', description: 'A narrow ledge.', exits: 'Obvious paths: down',
                    uid: [700], tags: ['peer down =~ /a chasm/'])
      live_room(title: 'Foggy Ledge', description: 'A narrow ledge.', exits: 'Obvious paths: down', room_id: 0)
      expect(map_class.match_fuzzy).to be_nil
    end

    it 'resolves a UID peer room when the game exposes the matching UID (UID branch wins over peer)' do
      build_room(0, title: 'Foggy Ledge', description: 'A narrow ledge.', exits: 'Obvious paths: down',
                    uid: [700], tags: ['peer down =~ /a chasm/'])
      live_room(title: 'Foggy Ledge', description: 'A narrow ledge.', exits: 'Obvious paths: down', room_id: 700)
      expect(map_class.match_fuzzy).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  describe '.current (end-to-end)' do
    before(:each) { Script.current = :test_script }

    it 'resolves via the UID fast path when the game exposes a stamped UID' do
      build_room(0, title: 'Crossroads', description: 'Roads meet here.', exits: 'Obvious paths: north', uid: [800])
      map_class.load_uids
      live_room(title: 'Crossroads', description: 'Roads meet here.', exits: 'Obvious paths: north', room_id: 800)
      expect(map_class.current&.id).to eq(0)
    end

    it 'disambiguates day/night variants sharing title/description/paths via the UID fast path' do
      # Two distinct real rooms with identical text but different UIDs -- the exact
      # matcher alone would collapse them, the UID index keeps them apart.
      build_room(0, title: 'Bazaar Stall', description: 'A crowded stall.', exits: 'Obvious paths: out', uid: [3014010])
      build_room(1, title: 'Bazaar Stall', description: 'A crowded stall.', exits: 'Obvious paths: out', uid: [3014027])
      map_class.load_uids

      live_room(title: 'Bazaar Stall', description: 'A crowded stall.', exits: 'Obvious paths: out', room_id: 3014027)
      expect(map_class.current&.id).to eq(1)

      map_class.class_variable_set(:@@current_room_id, -1)
      map_class.class_variable_set(:@@current_room_count, -1)
      live_room(title: 'Bazaar Stall', description: 'A crowded stall.', exits: 'Obvious paths: out', room_id: 3014010)
      expect(map_class.current&.id).to eq(0)
    end

    it 'still resolves a room carrying a stray UID when the game reports no UID (Ancient Tower 9375 regression)' do
      # A genuinely no-UID room that had a stray UID stamped onto it: the game
      # reports room_id 0, so the UID fast path finds nothing and the exact matcher
      # must trust the title/description/paths match rather than returning nil.
      build_room(0, title: 'Abandoned Workshop', description: 'Dusty benches line the walls.',
                    exits: 'Obvious paths: out', uid: [253306])
      map_class.load_uids
      live_room(title: 'Abandoned Workshop', description: 'Dusty benches line the walls.',
                exits: 'Obvious paths: out', room_id: 0)
      expect(map_class.current&.id).to eq(0)
    end

    it 'resolves an ordinary no-UID room when the game reports no UID' do
      build_room(0, title: 'Root Cellar', description: 'Cold and damp.', exits: 'Obvious paths: up', uid: [])
      map_class.load_uids
      live_room(title: 'Root Cellar', description: 'Cold and damp.', exits: 'Obvious paths: up', room_id: 0)
      expect(map_class.current&.id).to eq(0)
    end

    it 'returns nil when the game reports no UID and nothing matches' do
      build_room(0, title: 'Root Cellar', description: 'Cold and damp.', exits: 'Obvious paths: up', uid: [])
      map_class.load_uids
      live_room(title: 'Unknown Void', description: 'Nothing here.', exits: 'Obvious paths: none', room_id: 0)
      expect(map_class.current).to be_nil
    end
  end
end
