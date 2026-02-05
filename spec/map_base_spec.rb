# frozen_string_literal: true

require 'rspec'
require 'json'

LIB_DIR = File.join(File.expand_path('..', File.dirname(__FILE__)), 'lib') unless defined?(LIB_DIR)

# Minimal mocks for map_base.rb dependencies
unless defined?(StringProc)
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
  end
end

unless defined?(XMLData)
  module XMLData
    class << self
      attr_accessor :game
    end
  end
end

DATA_DIR = '/tmp/lich_test_data' unless defined?(DATA_DIR)

def respond(msg = '')
  # mock
end

def echo(msg = '')
  # mock
end

require File.join(LIB_DIR, 'common', 'map', 'map_base.rb')

RSpec.describe Lich::Common::MinHeap do
  subject(:heap) { described_class.new }

  describe '#push and #pop' do
    it 'returns nil when empty' do
      expect(heap.pop).to be_nil
    end

    it 'returns the single pushed element' do
      heap.push(5, :a)
      expect(heap.pop).to eq([5, :a])
    end

    it 'pops elements in priority order' do
      heap.push(3, :c)
      heap.push(1, :a)
      heap.push(2, :b)

      expect(heap.pop).to eq([1, :a])
      expect(heap.pop).to eq([2, :b])
      expect(heap.pop).to eq([3, :c])
    end

    it 'handles duplicate priorities' do
      heap.push(1, :a)
      heap.push(1, :b)

      result = [heap.pop, heap.pop].map(&:last)
      expect(result).to contain_exactly(:a, :b)
    end

    it 'handles many elements correctly' do
      values = (1..100).to_a.shuffle
      values.each { |v| heap.push(v, v) }

      sorted = []
      sorted << heap.pop[0] until heap.empty?
      expect(sorted).to eq((1..100).to_a)
    end
  end

  describe '#empty?' do
    it 'is true when newly created' do
      expect(heap).to be_empty
    end

    it 'is false after push' do
      heap.push(1, :a)
      expect(heap).not_to be_empty
    end

    it 'is true after popping all elements' do
      heap.push(1, :a)
      heap.pop
      expect(heap).to be_empty
    end
  end
end

# Create a concrete test class that includes MapBase
# This mimics how map_dr.rb and map_gs.rb use it
module TestMap
  class Map
    include Lich::Common::MapBase

    @@loaded = false
    @@load_mutex = Mutex.new
    @@list = []
    @@tags = []
    @@uids = {}

    attr_reader :id
    attr_accessor :title, :description, :paths, :location, :climate, :terrain,
                  :wayto, :timeto, :image, :image_coords, :tags, :check_location,
                  :unique_loot, :uid

    def initialize(id, title = [], description = [], paths = [], uid = [],
                   location = nil, climate = nil, terrain = nil,
                   wayto = {}, timeto = {}, image = nil, image_coords = nil,
                   tags = [], check_location = nil, unique_loot = nil)
      @id = id
      @title = title
      @description = description
      @paths = paths
      @uid = uid
      @location = location
      @climate = climate
      @terrain = terrain
      @wayto = wayto
      @timeto = timeto
      @image = image
      @image_coords = image_coords
      @tags = tags
      @check_location = check_location
      @unique_loot = unique_loot
      @@list[@id] = self
    end

    class << self
      def loaded?
        @@loaded
      end

      def list
        @@list
      end

      def list=(value)
        @@list = value
      end

      def uids
        @@uids
      end

      def clear_tags_cache
        @@tags.clear
      end

      def mark_loaded
        @@loaded = true
      end

      def synchronize_load(&block)
        @@load_mutex.synchronize(&block)
      end

      def load
        @@loaded = true
      end

      def [](val)
        self.load unless @@loaded
        if val.is_a?(Integer) || val =~ /^[0-9]+$/
          @@list[val.to_i]
        else
          @@list.find { |room| room&.title&.include?(val) }
        end
      end

      def clear_test_data
        @@list = []
        @@tags = []
        @@uids = {}
        @@loaded = false
      end
    end
  end
end

RSpec.describe Lich::Common::MapBase do
  before(:each) do
    TestMap::Map.clear_test_data
    TestMap::Map.mark_loaded
  end

  describe 'InstanceMethods' do
    let(:room) do
      TestMap::Map.new(
        42,
        ['[Town Square]'],
        ['A busy town square.'],
        ['Obvious paths: north, south, east'],
        [12_345],
        'Wehnimers Landing',
        nil, nil,
        { '43' => 'north', '44' => 'south' },
        { '43' => 0.2, '44' => 0.3 },
        'wl-square',
        [100, 200, 108, 208],
        %w[town bank],
        nil, nil
      )
    end

    describe '#to_i' do
      it 'returns the room id' do
        expect(room.to_i).to eq(42)
      end
    end

    describe '#outside?' do
      it 'returns true when paths say "Obvious paths:"' do
        expect(room.outside?).to be true
      end

      it 'returns false when paths say "Obvious exits:"' do
        room.paths = ['Obvious exits: north, south']
        expect(room.outside?).to be false
      end

      it 'returns false when paths is empty' do
        room.paths = []
        expect(room.outside?).to be false
      end

      it 'returns false when paths is nil' do
        room.paths = nil
        expect(room.outside?).to be false
      end
    end

    describe '#inside?' do
      it 'returns false when outside' do
        expect(room.inside?).to be false
      end

      it 'returns true when paths say "Obvious exits:"' do
        room.paths = ['Obvious exits: north']
        expect(room.inside?).to be true
      end
    end

    describe '#desc' do
      it 'returns the description' do
        expect(room.desc).to eq(['A busy town square.'])
      end
    end

    describe '#map_name' do
      it 'returns the image name' do
        expect(room.map_name).to eq('wl-square')
      end
    end

    describe '#map_x' do
      it 'returns the center x coordinate' do
        expect(room.map_x).to eq(104)
      end

      it 'returns nil when image_coords is nil' do
        room.image_coords = nil
        expect(room.map_x).to be_nil
      end
    end

    describe '#map_y' do
      it 'returns the center y coordinate' do
        expect(room.map_y).to eq(204)
      end

      it 'returns nil when image_coords is nil' do
        room.image_coords = nil
        expect(room.map_y).to be_nil
      end
    end

    describe '#map_roomsize' do
      it 'returns the room size' do
        expect(room.map_roomsize).to eq(8)
      end

      it 'returns nil when image_coords is nil' do
        room.image_coords = nil
        expect(room.map_roomsize).to be_nil
      end
    end

    describe '#geo' do
      it 'returns nil' do
        expect(room.geo).to be_nil
      end
    end

    describe '#inspect' do
      it 'includes instance variable details' do
        result = room.inspect
        expect(result).to include('@id=42')
        expect(result).to include('@title=')
      end
    end

    describe '#to_json' do
      it 'produces valid JSON' do
        json_string = room.to_json
        parsed = JSON.parse(json_string)
        expect(parsed['id']).to eq(42)
        expect(parsed['title']).to eq(['[Town Square]'])
        expect(parsed['wayto']).to eq({ '43' => 'north', '44' => 'south' })
      end

      it 'excludes nil fields' do
        json_string = room.to_json
        parsed = JSON.parse(json_string)
        expect(parsed).not_to have_key('climate')
        expect(parsed).not_to have_key('terrain')
      end

      it 'excludes empty array fields' do
        room.tags = []
        json_string = room.to_json
        parsed = JSON.parse(json_string)
        expect(parsed).not_to have_key('tags')
      end

      it 'returns empty hash from json_extra_fields by default' do
        expect(room.json_extra_fields).to eq({})
      end

      it 'merges json_extra_fields into output' do
        allow(room).to receive(:json_extra_fields).and_return({ custom_field: 'test_value' })
        json_string = room.to_json
        parsed = JSON.parse(json_string)
        expect(parsed['custom_field']).to eq('test_value')
      end

      it 'filters nil values from json_extra_fields' do
        allow(room).to receive(:json_extra_fields).and_return({ custom_field: nil })
        json_string = room.to_json
        parsed = JSON.parse(json_string)
        expect(parsed).not_to have_key('custom_field')
      end
    end
  end

  describe 'ClassMethods' do
    describe '.get_free_id' do
      it 'returns one more than the max existing id' do
        TestMap::Map.new(0, ['Room 0'])
        TestMap::Map.new(5, ['Room 5'])
        TestMap::Map.new(3, ['Room 3'])

        expect(TestMap::Map.get_free_id).to eq(6)
      end
    end

    describe '.estimate_time' do
      it 'sums timeto values along a path' do
        TestMap::Map.new(0, [], [], [], [], nil, nil, nil,
                         { '1' => 'north' }, { '1' => 0.5 })
        TestMap::Map.new(1, [], [], [], [], nil, nil, nil,
                         { '2' => 'east' }, { '2' => 0.3 })
        TestMap::Map.new(2)

        expect(TestMap::Map.estimate_time([0, 1, 2])).to be_within(0.001).of(0.8)
      end

      it 'uses 0.2 as default when timeto is nil' do
        TestMap::Map.new(0, [], [], [], [], nil, nil, nil,
                         { '1' => 'north' }, {})
        TestMap::Map.new(1)

        expect(TestMap::Map.estimate_time([0, 1])).to be_within(0.001).of(0.2)
      end

      it 'raises on non-array input' do
        expect { TestMap::Map.estimate_time('not an array') }.to raise_error(Exception)
      end
    end

    describe '.uids_add and .ids_from_uid' do
      it 'adds and retrieves uid mappings' do
        TestMap::Map.uids_add(100, 5)
        TestMap::Map.uids_add(100, 6)
        expect(TestMap::Map.ids_from_uid(100)).to eq([5, 6])
      end

      it 'returns empty array for unknown uid' do
        expect(TestMap::Map.ids_from_uid(999)).to eq([])
      end

      it 'does not add duplicate ids' do
        TestMap::Map.uids_add(100, 5)
        TestMap::Map.uids_add(100, 5)
        expect(TestMap::Map.ids_from_uid(100)).to eq([5])
      end
    end

    describe '.to_json' do
      it 'produces valid JSON array' do
        TestMap::Map.new(0, ['Room A'], ['Desc A'], ['Paths A'])
        TestMap::Map.new(1, ['Room B'], ['Desc B'], ['Paths B'])

        json_string = TestMap::Map.to_json
        parsed = JSON.parse(json_string)
        expect(parsed).to be_an(Array)
        expect(parsed.size).to eq(2)
        expect(parsed[0]['id']).to eq(0)
        expect(parsed[1]['id']).to eq(1)
      end
    end
  end

  describe 'pathfinding' do
    # Build a small graph:
    #   0 --0.2--> 1 --0.3--> 2
    #   |                      ^
    #   +--------1.0-----------+
    before(:each) do
      TestMap::Map.new(0, [], [], [], [], nil, nil, nil,
                       { '1' => 'north', '2' => 'east' },
                       { '1' => 0.2, '2' => 1.0 })
      TestMap::Map.new(1, [], [], [], [], nil, nil, nil,
                       { '2' => 'east' },
                       { '2' => 0.3 })
      TestMap::Map.new(2, [], [], [], [], nil, nil, nil,
                       {}, {})
    end

    describe '#dijkstra' do
      it 'finds shortest distances' do
        room0 = TestMap::Map.list[0]
        _, distances = room0.dijkstra

        expect(distances[0]).to eq(0)
        expect(distances[1]).to eq(0.2)
        expect(distances[2]).to eq(0.5) # 0.2 + 0.3 < 1.0
      end

      it 'returns previous pointers for path reconstruction' do
        room0 = TestMap::Map.list[0]
        previous, = room0.dijkstra

        expect(previous[1]).to eq(0)
        expect(previous[2]).to eq(1) # via room 1, not direct
      end

      it 'terminates early when destination reached' do
        room0 = TestMap::Map.list[0]
        previous, _ = room0.dijkstra(1)

        expect(previous[1]).to eq(0)
      end
    end

    describe '#path_to' do
      it 'returns the shortest path excluding source' do
        room0 = TestMap::Map.list[0]
        path = room0.path_to(2)

        expect(path).to eq([1, 2])
      end

      it 'returns nil when no path exists' do
        TestMap::Map.new(99, [], [], [], [], nil, nil, nil, {}, {})
        room0 = TestMap::Map.list[0]
        path = room0.path_to(99)

        expect(path).to be_nil
      end

      it 'returns single-element path for adjacent rooms' do
        room0 = TestMap::Map.list[0]
        path = room0.path_to(1)

        expect(path).to eq([1])
      end
    end

    describe '#find_nearest' do
      it 'finds the nearest room from a list' do
        room0 = TestMap::Map.list[0]
        nearest = room0.find_nearest([1, 2])

        expect(nearest).to eq(1)
      end

      it 'returns self id when included in target list' do
        room0 = TestMap::Map.list[0]
        nearest = room0.find_nearest([0, 1, 2])

        expect(nearest).to eq(0)
      end
    end

    describe '#find_nearest_by_tag' do
      it 'finds the nearest room with a matching tag' do
        TestMap::Map.list[2].tags = ['bank']

        room0 = TestMap::Map.list[0]
        nearest = room0.find_nearest_by_tag('bank')

        expect(nearest).to eq(2)
      end

      it 'returns self id when current room has the tag' do
        TestMap::Map.list[0].tags = ['bank']

        room0 = TestMap::Map.list[0]
        nearest = room0.find_nearest_by_tag('bank')

        expect(nearest).to eq(0)
      end
    end

    describe '#find_all_nearest_by_tag' do
      it 'returns all tagged rooms sorted by distance' do
        TestMap::Map.list[1].tags = ['shop']
        TestMap::Map.list[2].tags = ['shop']

        room0 = TestMap::Map.list[0]
        result = room0.find_all_nearest_by_tag('shop')

        expect(result).to eq([1, 2])
      end
    end

    describe '.findpath' do
      it 'finds path between two room ids' do
        path = TestMap::Map.findpath(0, 2)
        expect(path).to eq([1, 2])
      end

      it 'accepts a Room object as source' do
        room0 = TestMap::Map.list[0]
        path = TestMap::Map.findpath(room0, 2)
        expect(path).to eq([1, 2])
      end
    end

    describe '.dijkstra class method' do
      it 'dispatches to instance dijkstra' do
        previous, _ = TestMap::Map.dijkstra(0, 2)
        expect(previous[2]).to eq(1)
      end
    end
  end
end
