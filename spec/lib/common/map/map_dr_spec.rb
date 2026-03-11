# frozen_string_literal: true

require_relative '../../../spec_helper'

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
require 'common/map/map_dr'

RSpec.describe Lich::Common::Map, 'DragonRealms implementation' do
  let(:map_class) { Lich::Common::Map }

  before(:each) do
    # Clear class state before each test
    map_class.clear rescue nil
    # Reset additional class variables not handled by clear
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

  describe 'class methods' do
    describe '.loaded?' do
      it 'returns false initially' do
        expect(map_class.loaded?).to be false
      end
    end

    describe '.get_free_id' do
      before do
        # Manually mark loaded and add some rooms
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
        map_class.class_variable_set(:@@loaded, true)
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
        map_class.class_variable_set(:@@loaded, true)
        map_class.new(1, ['Room A'], ['desc'], ['path'])
        map_class.new(2, ['Room B'], ['desc'], ['path'])
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
        map_class.class_variable_set(:@@loaded, true)
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
        map_class.class_variable_set(:@@loaded, true)
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
end

RSpec.describe Lich::Common::Room, 'DragonRealms' do
  it 'inherits from Map' do
    expect(Lich::Common::Room.superclass).to eq(Lich::Common::Map)
  end

  it 'delegates method_missing to super' do
    expect { Lich::Common::Room.nonexistent_method }.to raise_error(NoMethodError)
  end
end
