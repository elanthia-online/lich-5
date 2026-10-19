# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'json'
require 'fileutils'
require 'timeout'
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

require_relative '../../../support/data_dir'

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
  previous_nav_rm: 11111,
  nav_count: 0
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
    map_class.reset_resolutions
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
  def build_room(id, title:, description:, exits:, uid: [], tags: [], wayto: {})
    map_class.new(id, [title], [description], [exits], uid,
                  nil, nil, nil, wayto, {}, nil, nil, tags)
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
    map_class.reset_resolutions
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

    it 'matches a live reading missing the final period through the tolerant pass' do
      build_room(0, title: 'Garden Path', description: 'A winding garden path.', exits: 'Obvious paths: east', uid: [150013])
      live_room(title: 'Garden Path', description: 'A winding garden path', exits: 'Obvious paths: east', room_id: 0)
      expect(map_class.match_current(nil)).to eq(0)
    end

    it 'no longer matches on title and paths alone when the room window is disabled' do
      build_room(0, title: 'Dim Cellar', description: 'The stored cellar description.', exits: 'Obvious paths: up', uid: [])
      live_room(title: 'Dim Cellar', description: 'A completely different live description',
                exits: 'Obvious paths: up', room_id: 0, window_disabled: true)
      expect(map_class.match_current(nil)).to be_nil
    end

    it 'still matches a disabled room window by its full description' do
      build_room(0, title: 'Dim Cellar', description: 'The stored cellar description.', exits: 'Obvious paths: up', uid: [])
      live_room(title: 'Dim Cellar', description: 'The stored cellar description.',
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

  # ---------------------------------------------------------------------------
  # Without a usable UID a room is identified by title, description and exits
  # together, and only when one room fits. Several rooms that fit are told apart
  # only by which one the last resolved room leads to; otherwise the room is
  # unresolved rather than the first of them.
  describe 'strict text fallback' do
    let(:title) { '[Segoltha River, In The Water]' }
    let(:desc)  { 'The murky water swirls around you.' }
    let(:exits) { 'Obvious paths: north, south.' }

    def twin(id, uid: [], wayto: {}, tags: [], exits: nil)
      build_room(id, title: title, description: desc, exits: exits || self.exits, uid: uid, wayto: wayto, tags: tags)
    end

    def live(room_id: 0, exits: nil, description: nil, room_count: 1)
      live_room(title: title, description: description || desc, exits: exits || self.exits,
                room_id: room_id, room_count: room_count)
    end

    # The game reports an arrival: a <nav> after leaving a room it showed with
    # +uid+ (0 for none).
    def arrive_from(uid)
      XMLData.previous_nav_rm = uid
      XMLData.nav_count = XMLData.nav_count.to_i + 1
    end

    # Record +id+ as the room resolved for an earlier display (room count 0;
    # the live helpers default to 1), as Map.current does when it resolves it,
    # then arrive from it.
    def came_from(id)
      XMLData.room_count = 0
      map_class.set_current(id)
      arrive_from(XMLData.room_id)
    end

    context 'with several identical rooms and no UID to tell them apart' do
      it 'is unresolved when nothing was resolved before' do
        twin(10)
        twin(11)
        live
        expect(map_class.match_current(nil)).to be_nil
        expect(map_class.match_fuzzy).to be_nil
      end

      it 'is unresolved when the live UID is one the map does not have' do
        twin(10)
        twin(11)
        live(room_id: 777_001)
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'takes the only one the last resolved room leads to, not the first' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '11' => 'north' })
        twin(10)
        twin(11)
        came_from(1)
        live
        expect(map_class.match_current(nil)).to eq(11)
        expect(map_class.match_fuzzy).to eq(11)
      end

      it 'is unresolved when the last resolved room leads to more than one' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.',
                      wayto: { '10' => 'north', '11' => 'south' })
        twin(10)
        twin(11)
        came_from(1)
        live
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'is unresolved when the last resolved room leads to none of them' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '5' => 'north' })
        twin(10)
        twin(11)
        came_from(1)
        live
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'is unresolved when the last resolved room is one of them and leads to another' do
        # A fresh display of identical text cannot say whether the character
        # stayed in 10 or moved to its neighbour 11.
        twin(10, wayto: { '11' => 'north' })
        twin(11, wayto: { '10' => 'south' })
        came_from(10)
        live
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'stays in the last resolved room when it is one of them and leads to none of the others' do
        twin(10)
        twin(11)
        came_from(11)
        live
        expect(map_class.match_current(nil)).to eq(11)
      end

      it 'ignores the -1 sentinel and a hole as the last resolved room' do
        twin(10)
        twin(11, wayto: {})
        came_from(-1)
        live
        expect(map_class.match_current(nil)).to be_nil
        came_from(500)
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'treats a room whose wayto is nil as leading nowhere' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.').wayto = nil
        twin(10)
        twin(11)
        came_from(1)
        live
        expect(map_class.match_current(nil)).to be_nil
      end
    end

    context 'when a stored UID vetoes one of several identical rooms' do
      it 'is unresolved when the survivor cannot be reached from the last resolved room' do
        # A UID room and a no-UID copy of it elsewhere in the map: the live UID
        # belongs to neither, so the copy is not taken for the live room.
        twin(10, uid: [500])
        twin(11)
        live(room_id: 999)
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'takes the survivor when the last resolved room leads to it' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '11' => 'north' })
        twin(10, uid: [500])
        twin(11)
        came_from(1)
        live(room_id: 999)
        expect(map_class.match_current(nil)).to eq(11)
      end

      it 'is unresolved when the last resolved room leads to both the vetoed room and the survivor' do
        # A copy that shares the UID room's neighbours: the live room may be the
        # UID room under a UID the map lacks, so the copy is not taken for it.
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.',
                      wayto: { '10' => 'north', '11' => 'go door' })
        twin(10, uid: [500])
        twin(11)
        came_from(1)
        live(room_id: 999)
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'is unresolved when every candidate is vetoed, even the reachable one' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '10' => 'north' })
        twin(10, uid: [500])
        twin(11, uid: [501])
        came_from(1)
        live(room_id: 999)
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'does not take the survivor because the vetoed room is the one reachable' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '10' => 'north' })
        twin(10, uid: [500])
        twin(11)
        came_from(1)
        live(room_id: 999)
        expect(map_class.match_current(nil)).to be_nil
      end
    end

    context 'when the game shows no UID and a UID room has a no-UID copy' do
      it 'is unresolved without a last resolved room' do
        twin(10)
        twin(11, uid: [500])
        live
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'takes the UID room when it is the one reached, even though the copy is listed first' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '11' => 'north' })
        twin(10)
        twin(11, uid: [500])
        came_from(1)
        live
        expect(map_class.match_current(nil)).to eq(11)
      end
    end

    context 'under fog' do
      let(:fog) { 'Obvious paths: obscured by a thick fog' }

      it 'resolves a title and description that only one room has' do
        twin(10, exits: 'Obvious paths: north.')
        build_room(11, title: title, description: 'Other water.', exits: 'Obvious paths: south.')
        live(exits: fog)
        expect(map_class.match_current(nil)).to eq(10)
      end

      it 'is unresolved when rooms with different exits share the title and description' do
        twin(10, exits: 'Obvious paths: north.')
        twin(11, exits: 'Obvious paths: south.')
        live(exits: fog)
        expect(map_class.match_current(nil)).to be_nil
        expect(map_class.match_fuzzy).to be_nil
      end

      it 'takes the one of them the last resolved room leads to' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '11' => 'north' })
        twin(10, exits: 'Obvious paths: north.')
        twin(11, exits: 'Obvious paths: south.')
        came_from(1)
        live(exits: fog)
        expect(map_class.match_current(nil)).to eq(11)
      end

      it 'recognises the "Obvious exits" form of the fog line' do
        twin(10, exits: 'Obvious exits: out.')
        twin(11, exits: 'Obvious exits: north.')
        live(exits: 'Obvious exits: obscured by a thick fog')
        expect(map_class.match_current(nil)).to be_nil
      end
    end

    context 'with a description that has drifted from the map' do
      def drifted(id, description, uid: [], wayto: {}, exits: nil, tags: [])
        build_room(id, title: title, description: description, exits: exits || self.exits,
                       uid: uid, wayto: wayto, tags: tags)
      end

      let(:stored) { 'The murky water swirls around you.  Reeds sway along the near bank.' }

      it 'matches a live description sharing one whole sentence with the stored one' do
        drifted(10, stored)
        live(description: 'The murky water swirls around you.  A heron watches from the shallows.')
        expect(map_class.match_current(nil)).to eq(10)
        expect(map_class.match_fuzzy).to eq(10)
      end

      it 'matches a live sentence found inside a longer stored sentence' do
        drifted(10, 'Brush flanks the road at the western end of a big clearing, near a stream.  Higher up is a meadow.')
        live(description: 'Brush flanks the road at the western end of a big clearing.  Water flows downhill.')
        expect(map_class.match_current(nil)).to eq(10)
      end

      it 'matches a day/night variant the map lacks through a sentence of a stored variant' do
        map_class.new(10, [title], ['Sunlight glitters on the water.  The far bank is lined with willows.',
                                    'Moonlight glints on the water.  The far bank is lined with willows.'],
                      [exits], [])
        live(description: 'Starlight barely touches the water.  The far bank is lined with willows.')
        expect(map_class.match_current(nil)).to eq(10)
      end

      it 'still needs the exact title' do
        drifted(10, stored)
        live_room(title: '[Segoltha River, Near The Bank]', description: 'The murky water swirls around you.',
                  exits: exits, room_id: 0)
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'still needs the exact exits' do
        drifted(10, stored)
        live(description: 'The murky water swirls around you.  A heron watches.', exits: 'Obvious paths: east.')
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'does not match on title and exits when the live description is empty' do
        twin(10)
        live(description: '')
        expect(map_class.match_current(nil)).to be_nil
        expect(map_class.match_fuzzy).to be_nil
      end

      it 'does not match on title and exits when the live description is nil' do
        twin(10)
        live_room(title: title, description: nil, exits: exits, room_id: 0)
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'does not match when the live description has a double period' do
        twin(10)
        live(description: 'Something else entirely.. Really.')
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'does not match on a fragment shorter than four words, such as a closing quote mark' do
        drifted(10, 'A clerk says, "Welcome to the river ferry."  Ropes creak overhead.')
        live(description: 'A painted sign reads, "Ferry closed until spring."')
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'does not match on a short stored phrase the live text happens to contain' do
        drifted(10, 'Something stirs.  Nothing else here resembles the live room.')
        live(description: 'Something stirs.  Fish dart through the weeds below.')
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'is unresolved when two rooms share the sentence and nothing tells them apart' do
        drifted(10, stored)
        drifted(11, 'The murky water swirls around you.  Driftwood bobs past.')
        live(description: 'The murky water swirls around you.  A heron watches.')
        expect(map_class.match_current(nil)).to be_nil
        expect(map_class.match_fuzzy).to be_nil
      end

      it 'takes the one of them the previous room leads to' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '11' => 'north' })
        drifted(10, stored)
        drifted(11, 'The murky water swirls around you.  Driftwood bobs past.')
        came_from(1)
        live(description: 'The murky water swirls around you.  A heron watches.')
        expect(map_class.match_current(nil)).to eq(11)
      end

      it 'lets the live UID veto a drifted room storing another UID' do
        drifted(10, stored, uid: [500])
        live(description: 'The murky water swirls around you.  A heron watches.', room_id: 777_010)
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'drops a vetoed drifted room and keeps its no-UID copy only when the previous room leads to it' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '11' => 'north' })
        drifted(10, stored, uid: [500])
        drifted(11, 'The murky water swirls around you.  Driftwood bobs past.')
        live(description: 'The murky water swirls around you.  A heron watches.', room_id: 777_011)
        expect(map_class.match_current(nil)).to be_nil
        came_from(1)
        live(description: 'The murky water swirls around you.  A heron watches.', room_id: 777_011)
        expect(map_class.match_current(nil)).to eq(11)
      end

      it 'is not tried when exact matches exist but cannot be told apart' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '12' => 'north' })
        twin(10)
        twin(11)
        drifted(12, "#{desc}  Reeds sway along the near bank.")
        came_from(1)
        live
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'is not tried when the only exact match is vetoed by the live UID' do
        twin(10, uid: [500])
        drifted(11, "#{desc}  Reeds sway along the near bank.")
        live(room_id: 777_012)
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'skips a map room missing its description or title, exactly and tolerantly' do
        map_class.new(10, [title], nil, [exits], [])
        map_class.new(11, nil, nil, nil, [])
        drifted(12, stored)
        live(description: 'The murky water swirls around you.  A heron watches.')
        expect(map_class.match_current(nil)).to eq(12)
        live(description: 'Nothing here is like any stored room at all.', room_count: 2)
        expect(map_class.match_current(nil)).to be_nil
      end

      it 'without a script, refuses a peer-tagged room it matched' do
        drifted(10, stored, tags: ['peer north =~ /a dock/'])
        live(description: 'The murky water swirls around you.  A heron watches.')
        expect(map_class.match_fuzzy).to be_nil
        expect(map_class.match_current(nil)).to eq(10)
      end

      context 'under fog' do
        let(:fog) { 'Obvious paths: obscured by a thick fog' }

        it 'resolves a title and drifted description that only one room has' do
          drifted(10, stored, exits: 'Obvious paths: north.')
          drifted(11, 'Other water entirely, cold and green.', exits: 'Obvious paths: south.')
          live(description: 'The murky water swirls around you.  A heron watches.', exits: fog)
          expect(map_class.match_current(nil)).to eq(10)
        end

        it 'is unresolved when rooms with different exits share the sentence' do
          drifted(10, stored, exits: 'Obvious paths: north.')
          drifted(11, 'The murky water swirls around you.  Driftwood bobs past.', exits: 'Obvious paths: south.')
          live(description: 'The murky water swirls around you.  A heron watches.', exits: fog)
          expect(map_class.match_current(nil)).to be_nil
        end
      end
    end

    it 'resolves a no-UID room the game shows with a UID the map lacks (as at a private forge)' do
      twin(10)
      live(room_id: 777_002)
      expect(map_class.match_current(nil)).to eq(10)
      expect(map_class.match_fuzzy).to eq(10)
    end

    it 'treats a stored UID of 0 as no UID' do
      twin(10, uid: [0])
      live(room_id: 777_003)
      expect(map_class.match_current(nil)).to eq(10)
    end

    it 'still lets a live UID veto a room storing 0 alongside a real UID' do
      twin(10, uid: [0, 500])
      live(room_id: 777_004)
      expect(map_class.match_current(nil)).to be_nil
    end

    it 'does not resolve a peer-tagged room picked by adjacency without a script' do
      build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '11' => 'north' })
      twin(10)
      twin(11, tags: ['peer north =~ /a dock/'])
      came_from(1)
      live
      expect(map_class.match_fuzzy).to be_nil
      expect(map_class.match_current(nil)).to eq(11)
    end

    it 'leaves the scanned rooms untouched' do
      twin(10, uid: [500])
      twin(11)
      live(room_id: 999)
      map_class.match_current(nil)
      expect(map_class[10].uid).to eq([500])
      expect(map_class[11].uid).to eq([])
    end

    describe 'a room display that changes mid-match' do
      it 'match_fuzzy re-reads the room instead of spinning' do
        twin(10)
        build_room(11, title: '[Riverbank]', description: 'Mud.', exits: 'Obvious paths: north.')
        live
        reads = 0
        allow(XMLData).to receive(:room_count) do
          reads += 1
          if reads == 1
            1
          else
            XMLData.room_title = '[Riverbank]'
            XMLData.room_description = 'Mud.'
            XMLData.room_exits_string = 'Obvious paths: north.'
            2
          end
        end
        result = Timeout.timeout(5) { map_class.match_fuzzy }
        expect(result).to eq(11)
      end

      it 'match_current re-reads the room' do
        twin(10)
        build_room(11, title: '[Riverbank]', description: 'Mud.', exits: 'Obvious paths: north.')
        live
        reads = 0
        allow(XMLData).to receive(:room_count) do
          reads += 1
          if reads == 1
            1
          else
            XMLData.room_title = '[Riverbank]'
            XMLData.room_description = 'Mud.'
            XMLData.room_exits_string = 'Obvious paths: north.'
            2
          end
        end
        result = Timeout.timeout(5) { map_class.match_current(nil) }
        expect(result).to eq(11)
      end
    end

    describe 'through Map.current' do
      before(:each) { Script.current = :test_script }

      it 'still resolves a UID the map has to its room, whatever rooms share its text' do
        twin(10)
        twin(11, uid: [500])
        map_class.load_uids
        live(room_id: 500)
        expect(map_class.current&.id).to eq(11)
      end

      it 'resolves an ambiguous room after walking into it from a resolved room' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', uid: [400],
                      wayto: { '11' => 'north' })
        twin(10)
        twin(11)
        map_class.load_uids
        live_room(title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', room_id: 400, room_count: 1)
        expect(map_class.current&.id).to eq(1)
        arrive_from(400)
        live(room_count: 2)
        expect(map_class.current&.id).to eq(11)
        expect(map_class.previous&.id).to eq(1)
      end

      it 'stays unresolved in an ambiguous room entered with no resolved room behind it' do
        twin(10)
        twin(11)
        map_class.load_uids
        live(room_count: 1)
        expect(map_class.current).to be_nil
        live(room_count: 2)
        expect(map_class.current).to be_nil
      end

      it 'returns the cached room while the room count is unchanged' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '11' => 'north' })
        twin(10)
        twin(11)
        came_from(1)
        live(room_count: 7)
        expect(map_class.current&.id).to eq(11)
        expect(map_class).not_to receive(:text_candidates)
        expect(map_class.current&.id).to eq(11)
      end
    end

    # DR resolves a room only when asked, so the room resolved last can be
    # several moves old, or the live room itself resolved a moment ago. The
    # identical rooms are told apart from the room the character was in before
    # the live display.
    describe 'the room the character was in before' do
      let(:bank) { { title: '[Bank]', description: 'B.', exits: 'Obvious paths: east.' } }

      def bank_room(id, uid:, wayto:)
        build_room(id, **bank, uid: uid, wayto: wayto)
      end

      def live_bank(uid, room_count)
        live_room(**bank, room_id: uid, room_count: room_count)
      end

      it 'gives the same answer when a scriptless hook and a script resolve the same display' do
        bank_room(1, uid: [9], wayto: { '10' => 'east' })
        twin(10, wayto: { '11' => 'north', '1' => 'west' })
        twin(11, wayto: { '10' => 'south' })
        map_class.load_uids
        live_bank(9, 1)
        expect(map_class.current&.id).to eq(1)
        arrive_from(9)
        live(room_count: 2)
        Script.current = nil
        expect(map_class.current&.id).to eq(10)
        Script.current = :test_script
        expect(map_class.current&.id).to eq(10)
        Script.current = nil
        expect(map_class.current&.id).to eq(10)
      end

      it 'trusts no earlier resolution before the game has reported a previous room' do
        bank_room(1, uid: [9], wayto: { '10' => 'east' })
        twin(10, wayto: { '11' => 'north', '1' => 'west' })
        twin(11, wayto: { '10' => 'south' })
        map_class.load_uids
        live_bank(9, 1)
        expect(map_class.current&.id).to eq(1)
        live(room_count: 2)
        expect(XMLData.previous_nav_rm).to be_nil
        expect(map_class.current).to be_nil
        Script.current = :test_script
        expect(map_class.current).to be_nil
      end

      it 'uses the room resolved for an earlier display when the room left showed no UID' do
        bank_room(1, uid: [], wayto: { '10' => 'east' })
        twin(10, wayto: { '11' => 'north', '1' => 'west' })
        twin(11, wayto: { '10' => 'south' })
        live_bank(0, 1)
        expect(map_class.current&.id).to eq(1)
        arrive_from(0)
        live(room_count: 2)
        expect(map_class.current&.id).to eq(10)
        Script.current = :test_script
        expect(map_class.current&.id).to eq(10)
      end

      it 'does not use the room resolved for an earlier display when the game showed it with a UID the room left lacks' do
        bank_room(1, uid: [9], wayto: { '10' => 'east' })
        twin(10)
        twin(11)
        map_class.load_uids
        live_bank(9, 1)
        expect(map_class.current&.id).to eq(1)
        arrive_from(0)
        live(room_count: 2)
        expect(map_class.current).to be_nil
      end

      it 'resolves the destination of a walk that never asked for the rooms on the way' do
        # A start room resolved, two moves with no resolution, then arrival in
        # a room with an identical copy elsewhere in the map.
        build_room(5, title: '[Start]', description: 'S.', exits: 'Obvious paths: east.', uid: [100], wayto: { '7' => 'east' })
        build_room(7, title: '[Mid]', description: 'M.', exits: 'Obvious paths: east, west.', uid: [101],
                      wayto: { '10' => 'east', '5' => 'west' })
        twin(10, wayto: { '7' => 'west' })
        twin(30)
        map_class.load_uids
        live_room(title: '[Start]', description: 'S.', exits: 'Obvious paths: east.', room_id: 100, room_count: 1)
        expect(map_class.current&.id).to eq(5)
        arrive_from(101)
        live(room_count: 3)
        expect(map_class.current&.id).to eq(10)
      end

      it 'does not take the copy an old resolution leads to when the game names the room it left' do
        # S leads to 20; S -> M -> 10 was walked without asking. 10 and 20 are identical.
        build_room(5, title: '[Start]', description: 'S.', exits: 'Obvious paths: east, west.', uid: [100],
                      wayto: { '20' => 'east', '7' => 'west' })
        build_room(7, title: '[Mid]', description: 'M.', exits: 'Obvious paths: east.', uid: [101], wayto: { '10' => 'north' })
        twin(10)
        twin(20)
        map_class.load_uids
        live_room(title: '[Start]', description: 'S.', exits: 'Obvious paths: east, west.', room_id: 100, room_count: 1)
        expect(map_class.current&.id).to eq(5)
        arrive_from(101)
        live(room_count: 3)
        expect(map_class.current&.id).to eq(10)
      end

      it 'is unresolved, not the copy an old resolution leads to, when the room left had no UID' do
        # S leads to 20; S -> M -> 10 was walked without asking, and M has no UID.
        build_room(5, title: '[Start]', description: 'S.', exits: 'Obvious paths: east, west.', uid: [100],
                      wayto: { '20' => 'east', '7' => 'west' })
        build_room(7, title: '[Mid]', description: 'M.', exits: 'Obvious paths: east.', wayto: { '10' => 'north' })
        twin(10)
        twin(20)
        map_class.load_uids
        live_room(title: '[Start]', description: 'S.', exits: 'Obvious paths: east, west.', room_id: 100, room_count: 1)
        expect(map_class.current&.id).to eq(5)
        arrive_from(0)
        live(room_count: 3)
        expect(map_class.current).to be_nil
      end

      it 'uses an earlier resolution shown with the UID the game names when several rooms share it' do
        bank_room(1, uid: [9], wayto: { '10' => 'east' })
        bank_room(2, uid: [9], wayto: { '11' => 'east' })
        twin(10)
        twin(11)
        map_class.load_uids
        XMLData.room_id = 9
        came_from(2)
        live(room_count: 1)
        expect(XMLData.previous_nav_rm).to eq(9)
        expect(map_class.current&.id).to eq(11)
      end

      it 'does not use an earlier resolution shown with another UID when several rooms share the named one' do
        bank_room(1, uid: [9], wayto: { '10' => 'east' })
        bank_room(2, uid: [9], wayto: { '11' => 'east' })
        twin(10)
        twin(11)
        map_class.load_uids
        XMLData.room_id = 8
        came_from(2)
        XMLData.previous_nav_rm = 9
        live(room_count: 1)
        expect(map_class.current).to be_nil
      end

      it 'does not use a resolution made two arrivals ago, even when no room on the way had a UID' do
        # S leads to 20; S -> M -> 10 was walked without asking. No room has a UID.
        build_room(5, title: '[Start]', description: 'S.', exits: 'Obvious paths: east, west.', wayto: { '20' => 'east', '7' => 'west' })
        build_room(7, title: '[Mid]', description: 'M.', exits: 'Obvious paths: east.', wayto: { '10' => 'north' })
        twin(10)
        twin(20)
        arrive_from(0)
        live_room(title: '[Start]', description: 'S.', exits: 'Obvious paths: east, west.', room_id: 0, room_count: 1)
        expect(map_class.current&.id).to eq(5)
        arrive_from(0)
        arrive_from(0)
        live(room_count: 5)
        expect(map_class.current).to be_nil
      end

      it 'uses a resolution of the live room made before a later display with no arrival between' do
        twin(10)
        twin(11)
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '10' => 'north' })
        came_from(1)
        live(room_count: 1)
        expect(map_class.current&.id).to eq(10)
        live(room_count: 2) # a second display of the same room, no <nav>
        map_class.class_variable_set(:@@current_room_count, -1)
        map_class.class_variable_set(:@@fuzzy_room_count, -1)
        expect(map_class.anchor_room&.id).to eq(10)
        expect(map_class.current&.id).to eq(10)
      end

      it 'does not reach past a display that resolved to nothing' do
        bank_room(1, uid: [], wayto: { '10' => 'east' })
        twin(10)
        twin(11)
        came_from(1)
        XMLData.room_count = 1
        map_class.set_current(nil)
        live(room_count: 2)
        expect(map_class.current).to be_nil
      end

      it 'keeps a resolved room when a later resolution of the same display finds nothing' do
        # A script resolves a peer-tagged room that scriptless matching declines.
        bank_room(1, uid: [9], wayto: { '11' => 'east' })
        twin(10)
        twin(11, tags: ['peer north =~ /a dock/'], wayto: { '12' => 'north' })
        build_room(12, title: '[Dock]', description: 'Planks.', exits: 'Obvious paths: south.', wayto: { '11' => 'south' })
        build_room(13, title: '[Dock]', description: 'Planks.', exits: 'Obvious paths: south.')
        map_class.load_uids
        Script.current = :test_script
        live_bank(9, 1)
        expect(map_class.current&.id).to eq(1)
        arrive_from(9)
        live(room_count: 2)
        expect(map_class.current&.id).to eq(11)
        Script.current = nil
        expect(map_class.current).to be_nil
        Script.current = :test_script
        arrive_from(0)
        live_room(title: '[Dock]', description: 'Planks.', exits: 'Obvious paths: south.', room_id: 0, room_count: 3)
        expect(map_class.current&.id).to eq(12)
      end

      it 'forgets earlier resolutions when the map is cleared' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '11' => 'north' })
        came_from(1)
        map_class.clear
        map_class.class_variable_set(:@@loaded, true)
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '11' => 'north' })
        twin(10)
        twin(11)
        live(room_count: 1)
        expect(map_class.current).to be_nil
      end

      it 'does not take the room the game says was just left for an identical live room' do
        # Identical cells with no wayto between them; the game showed the room
        # left with its UID and shows the live room without one.
        twin(53, uid: [241_518])
        twin(54, uid: [241_517])
        map_class.load_uids
        arrive_from(241_517)
        live(room_count: 2)
        expect(map_class.anchor_room&.id).to eq(54)
        expect(map_class.current).to be_nil
        Script.current = :test_script
        expect(map_class.current).to be_nil
      end

      it 'takes the identical room the room just left leads to' do
        twin(53, wayto: { '54' => 'south' })
        twin(54, uid: [241_517], wayto: { '53' => 'north' })
        map_class.load_uids
        arrive_from(241_517)
        live(room_count: 2)
        expect(map_class.current&.id).to eq(53)
        Script.current = :test_script
        expect(map_class.current&.id).to eq(53)
      end

      it 'does not take the room just left when it was resolved one arrival ago under a shared UID' do
        # Two cells share UID 9, so the game's UID does not name the room left;
        # the earlier resolution does, and it is not the live room.
        twin(53, uid: [9])
        twin(54, uid: [9], wayto: { '55' => 'east' })
        twin(55)
        map_class.load_uids
        XMLData.room_id = 9
        came_from(54)
        live(room_count: 1)
        expect(map_class.anchor_room&.id).to eq(54)
        expect(map_class.current&.id).to eq(55)
      end

      it 'keeps the anchor itself when it stores both the UID left and the live UID' do
        # One map cell holds two game rooms (UIDs 7 and 8); a move between them
        # stays in the cell. Another cell also stores 8, so the UID alone is
        # ambiguous.
        twin(10, uid: [7, 8])
        twin(11, uid: [8])
        map_class.load_uids
        map_class.class_variable_set(:@@current_room_id, nil)
        arrive_from(7)
        live(room_id: 8, room_count: 2)
        expect(map_class.anchor_room&.id).to eq(10)
        expect(map_class.current&.id).to eq(10)
      end

      it 'ignores a resolution noted with a later room count' do
        build_room(1, title: 'Riverbank', description: 'Mud.', exits: 'Obvious paths: north.', wayto: { '11' => 'north' })
        twin(10)
        twin(11)
        XMLData.room_count = 5
        map_class.set_current(1)
        arrive_from(0)
        live(room_count: 2)
        expect(map_class.current).to be_nil
      end
    end

    describe '.current_or_new in an ambiguous room' do
      before(:each) { Script.current = :test_script }

      it 'mints one room for repeated displays, not a new copy on every display' do
        allow(map_class).to receive(:echo)
        twin(10)
        twin(11)
        arrive_from(0)
        ids = (1..3).map do |count|
          live(room_count: count)
          map_class.current_or_new&.id
        end
        expect(ids).to eq([12, 12, 12])
        expect(map_class.list.compact.size).to eq(3)
      end

      it 'says when the room it maps as new matches several mapped rooms' do
        messages = []
        allow(map_class).to receive(:echo) { |msg| messages << msg }
        twin(10)
        twin(11)
        live(room_count: 1)
        expect(map_class.current_or_new&.id).to eq(12)
        expect(messages).to include(a_string_matching(/2 mapped rooms match this room/))
      end

      it 'says so when the mapped rooms only share a sentence with it' do
        messages = []
        allow(map_class).to receive(:echo) { |msg| messages << msg }
        twin(10)
        twin(11)
        live(room_count: 1, description: "#{desc}  A heron watches from the shallows.")
        expect(map_class.current_or_new&.id).to eq(12)
        expect(messages).to include(a_string_matching(/2 mapped rooms match this room/))
      end

      it 'does not warn when the room it maps matches no mapped room' do
        messages = []
        allow(map_class).to receive(:echo) { |msg| messages << msg }
        twin(10)
        live(room_count: 1, description: 'Something new.')
        expect(map_class.current_or_new&.id).to eq(11)
        expect(messages.grep(/mapped rooms match/)).to be_empty
      end
    end
  end
end
