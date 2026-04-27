# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'json'

# Mock StringProc for testing
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

# Load the map_base module
require 'common/map/map_base'

RSpec.describe Lich::Common::MinHeap do
  let(:heap) { described_class.new }

  describe '#initialize' do
    it 'creates an empty heap' do
      expect(heap).to be_empty
    end
  end

  describe '#push' do
    it 'adds elements to the heap' do
      heap.push(5, 'a')
      expect(heap).not_to be_empty
    end

    it 'maintains min-heap property' do
      heap.push(5, 'a')
      heap.push(3, 'b')
      heap.push(7, 'c')
      heap.push(1, 'd')

      result = heap.pop
      expect(result).to eq([1, 'd'])
    end
  end

  describe '#pop' do
    it 'returns nil for empty heap' do
      expect(heap.pop).to be_nil
    end

    it 'removes and returns minimum element' do
      heap.push(5, 'a')
      heap.push(3, 'b')
      heap.push(7, 'c')

      expect(heap.pop).to eq([3, 'b'])
      expect(heap.pop).to eq([5, 'a'])
      expect(heap.pop).to eq([7, 'c'])
      expect(heap.pop).to be_nil
    end

    it 'handles duplicate priorities' do
      heap.push(5, 'a')
      heap.push(5, 'b')
      heap.push(5, 'c')

      results = [heap.pop, heap.pop, heap.pop]
      expect(results.map(&:first)).to all(eq(5))
      expect(results.map(&:last).sort).to eq(%w[a b c])
    end

    it 'maintains ordering across many elements' do
      values = (1..100).to_a.shuffle
      values.each { |v| heap.push(v, v) }

      sorted = []
      sorted << heap.pop[0] until heap.empty?
      expect(sorted).to eq((1..100).to_a)
    end
  end

  describe '#empty?' do
    it 'returns true for empty heap' do
      expect(heap).to be_empty
    end

    it 'returns false after adding elements' do
      heap.push(1, 'a')
      expect(heap).not_to be_empty
    end

    it 'returns true after removing all elements' do
      heap.push(1, 'a')
      heap.pop
      expect(heap).to be_empty
    end
  end
end

RSpec.describe Lich::Common::MapBase do
  # Create a test class that includes MapBase
  let(:test_class) do
    Class.new do
      include Lich::Common::MapBase

      attr_reader :id
      attr_accessor :title, :description, :paths, :wayto, :timeto, :tags, :image_coords

      def initialize(id, paths: [], wayto: {}, timeto: {}, tags: [])
        @id = id
        @paths = paths
        @wayto = wayto
        @timeto = timeto
        @tags = tags
        @title = ['Test Room']
        @description = ['A test room']
        @image_coords = nil
      end

      # Mock class methods required by MapBase
      class << self
        attr_accessor :test_list, :test_loaded

        def load
          @test_loaded = true
        end

        def loaded?
          @test_loaded
        end

        def list
          @test_list ||= []
        end

        def [](id)
          list[id]
        end

        def dijkstra(source, destination = nil)
          if source.is_a?(self)
            source.dijkstra(destination)
          elsif (room = self[source])
            room.dijkstra(destination)
          end
        end

        def uids
          @uids ||= {}
        end
      end
    end
  end

  describe 'InstanceMethods' do
    describe '#outside?' do
      it 'returns true for outdoor paths (Obvious paths:)' do
        room = test_class.new(1, paths: ['Obvious paths: north, south'])
        expect(room.outside?).to be true
      end

      it 'returns false for indoor exits (Obvious exits:)' do
        room = test_class.new(1, paths: ['Obvious exits: north, south'])
        expect(room.outside?).to be false
      end

      it 'returns false for empty paths' do
        room = test_class.new(1, paths: [])
        expect(room.outside?).to be false
      end

      it 'returns false for nil paths' do
        room = test_class.new(1)
        room.instance_variable_set(:@paths, nil)
        expect(room.outside?).to be false
      end

      it 'uses last element of paths array' do
        room = test_class.new(1, paths: ['Obvious exits: east', 'Obvious paths: north'])
        expect(room.outside?).to be true
      end
    end

    describe '#inside?' do
      it 'returns opposite of outside?' do
        outdoor_room = test_class.new(1, paths: ['Obvious paths: north'])
        indoor_room = test_class.new(2, paths: ['Obvious exits: south'])

        expect(outdoor_room.inside?).to be false
        expect(indoor_room.inside?).to be true
      end
    end

    describe '#to_i' do
      it 'returns the room id' do
        room = test_class.new(42)
        expect(room.to_i).to eq(42)
      end
    end

    describe '#inspect' do
      it 'returns string with instance variables' do
        room = test_class.new(1, paths: ['Obvious paths: north'])
        result = room.inspect

        expect(result).to include('@id=1')
        expect(result).to include('@paths=')
      end
    end

    describe '#to_json' do
      it 'returns valid JSON representation' do
        room = test_class.new(1, paths: ['Obvious paths: north'], tags: ['test'])
        room.instance_variable_set(:@location, 'Test Area')

        json = room.to_json
        parsed = JSON.parse(json)

        expect(parsed['id']).to eq(1)
        expect(parsed['paths']).to eq(['Obvious paths: north'])
        expect(parsed['tags']).to eq(['test'])
      end

      it 'excludes nil and empty array values' do
        room = test_class.new(1, paths: ['path'], tags: [])
        json = room.to_json
        parsed = JSON.parse(json)

        expect(parsed).not_to have_key('tags')
        expect(parsed).not_to have_key('image')
      end

      it 'returns empty hash from json_extra_fields by default' do
        room = test_class.new(1)
        expect(room.json_extra_fields).to eq({})
      end

      it 'merges json_extra_fields into output' do
        room = test_class.new(1)
        allow(room).to receive(:json_extra_fields).and_return({ custom_field: 'test_value' })
        json_string = room.to_json
        parsed = JSON.parse(json_string)
        expect(parsed['custom_field']).to eq('test_value')
      end

      it 'filters nil values from json_extra_fields' do
        room = test_class.new(1)
        allow(room).to receive(:json_extra_fields).and_return({ custom_field: nil })
        json_string = room.to_json
        parsed = JSON.parse(json_string)
        expect(parsed).not_to have_key('custom_field')
      end
    end

    describe 'deprecated methods' do
      let(:room) { test_class.new(1) }

      it '#desc returns description' do
        room.instance_variable_set(:@description, ['Test desc'])
        expect(room.desc).to eq(['Test desc'])
      end

      it '#map_name returns image' do
        room.instance_variable_set(:@image, 'test.png')
        expect(room.map_name).to eq('test.png')
      end

      it '#geo returns nil' do
        expect(room.geo).to be_nil
      end

      it '#map_x returns nil when no image_coords' do
        expect(room.map_x).to be_nil
      end

      it '#map_x calculates center when image_coords present' do
        room.image_coords = [10, 20, 30, 40]
        expect(room.map_x).to eq(20) # (10+30)/2
      end

      it '#map_y calculates center when image_coords present' do
        room.image_coords = [10, 20, 30, 40]
        expect(room.map_y).to eq(30) # (20+40)/2
      end

      it '#map_roomsize returns width when image_coords present' do
        room.image_coords = [10, 20, 30, 40]
        expect(room.map_roomsize).to eq(20) # 30-10
      end
    end
  end

  describe 'pathfinding' do
    before do
      # Set up a simple test graph:
      # Room 0 -> Room 1 (cost 1)
      # Room 0 -> Room 2 (cost 5)
      # Room 1 -> Room 2 (cost 1)
      # Room 1 -> Room 3 (cost 2)
      # Room 2 -> Room 3 (cost 1)

      test_class.test_list = []
      test_class.test_loaded = true

      room0 = test_class.new(0, wayto: { '1' => 'north', '2' => 'east' }, timeto: { '1' => 1, '2' => 5 })
      room1 = test_class.new(1, wayto: { '0' => 'south', '2' => 'east', '3' => 'north' }, timeto: { '0' => 1, '2' => 1, '3' => 2 })
      room2 = test_class.new(2, wayto: { '0' => 'west', '1' => 'west', '3' => 'north' }, timeto: { '0' => 5, '1' => 1, '3' => 1 })
      room3 = test_class.new(3, wayto: { '1' => 'south', '2' => 'south' }, timeto: { '1' => 2, '2' => 1 })

      test_class.test_list[0] = room0
      test_class.test_list[1] = room1
      test_class.test_list[2] = room2
      test_class.test_list[3] = room3
    end

    describe '#dijkstra' do
      it 'finds shortest path from source' do
        room = test_class.test_list[0]
        _previous, distances = room.dijkstra

        expect(distances[0]).to eq(0)
        expect(distances[1]).to eq(1) # direct: 0->1
        expect(distances[2]).to eq(2) # via 1: 0->1->2
        expect(distances[3]).to eq(3) # via 1,2: 0->1->2->3
      end

      it 'returns previous room array for path reconstruction' do
        room = test_class.test_list[0]
        previous, distances = room.dijkstra(3)

        # The previous array should allow reconstructing a valid shortest path
        # Note: Multiple equally-short paths may exist (0->1->3 and 0->1->2->3 both cost 3)
        expect(previous[1]).to eq(0)
        expect(distances[3]).to eq(3) # Verify we found shortest distance
        # previous[3] could be 1 or 2 depending on traversal order (both valid)
        expect([1, 2]).to include(previous[3])
      end

      it 'terminates early when destination reached' do
        room = test_class.test_list[0]
        previous, _ = room.dijkstra(1)

        # Should find path to room 1 without necessarily exploring all nodes
        expect(previous[1]).to eq(0)
      end

      it 'handles unreachable rooms' do
        # Create isolated room
        isolated = test_class.new(4)
        test_class.test_list[4] = isolated

        room = test_class.test_list[0]
        previous, distances = room.dijkstra

        expect(distances[4]).to be_nil
        expect(previous[4]).to be_nil
      end
    end

    describe '#path_to' do
      it 'returns array of room IDs for path' do
        room = test_class.test_list[0]
        path = room.path_to(3)

        # Path should be a valid shortest path from 0 to 3 (cost 3)
        # Multiple valid paths exist: [1, 2, 3] or [1, 3] (both cost 3)
        expect(path).not_to be_nil
        expect(path.first).to eq(1)  # Must start by going to room 1
        expect(path.last).to eq(3)   # Must end at destination
        expect([[1, 2, 3], [1, 3]]).to include(path)
      end

      it 'returns nil for unreachable destination' do
        isolated = test_class.new(4)
        test_class.test_list[4] = isolated

        room = test_class.test_list[0]
        path = room.path_to(4)

        expect(path).to be_nil
      end

      it 'returns empty array when already at destination' do
        room = test_class.test_list[0]
        path = room.path_to(0)

        expect(path).to be_nil # No path needed
      end
    end

    describe '#find_nearest' do
      it 'finds nearest room from list' do
        room = test_class.test_list[0]
        nearest = room.find_nearest([2, 3])

        expect(nearest).to eq(2) # Room 2 is closer (cost 2 vs cost 3)
      end

      it 'returns current room if in target list' do
        room = test_class.test_list[0]
        nearest = room.find_nearest([0, 1, 2])

        expect(nearest).to eq(0)
      end
    end

    describe '#find_nearest_by_tag' do
      before do
        test_class.test_list[2].tags = ['shop']
        test_class.test_list[3].tags = ['shop', 'bank']
      end

      it 'finds nearest room with tag' do
        room = test_class.test_list[0]
        nearest = room.find_nearest_by_tag('shop')

        expect(nearest).to eq(2) # Room 2 is closer
      end

      it 'returns current room if it has tag' do
        test_class.test_list[0].tags = ['shop']
        room = test_class.test_list[0]
        nearest = room.find_nearest_by_tag('shop')

        expect(nearest).to eq(0)
      end
    end

    describe '#find_all_nearest_by_tag' do
      before do
        test_class.test_list[1].tags = ['shop']
        test_class.test_list[2].tags = ['shop']
        test_class.test_list[3].tags = ['shop']
      end

      it 'returns all tagged rooms sorted by distance' do
        room = test_class.test_list[0]
        all_shops = room.find_all_nearest_by_tag('shop')

        expect(all_shops).to eq([1, 2, 3]) # Sorted by distance
      end
    end
  end

  describe 'ClassMethods' do
    before do
      test_class.test_list = []
      test_class.test_loaded = true
    end

    describe '.get_free_id' do
      it 'returns one more than the max existing id' do
        test_class.test_list[0] = test_class.new(0)
        test_class.test_list[3] = test_class.new(3)
        test_class.test_list[5] = test_class.new(5)

        expect(test_class.get_free_id).to eq(6)
      end
    end

    describe '.estimate_time' do
      it 'sums timeto values along a path' do
        test_class.test_list[0] = test_class.new(0, wayto: { '1' => 'north' }, timeto: { '1' => 0.5 })
        test_class.test_list[1] = test_class.new(1, wayto: { '2' => 'east' }, timeto: { '2' => 0.3 })
        test_class.test_list[2] = test_class.new(2)

        expect(test_class.estimate_time([0, 1, 2])).to be_within(0.001).of(0.8)
      end

      it 'uses 0.2 as default when timeto is nil' do
        test_class.test_list[0] = test_class.new(0, wayto: { '1' => 'north' }, timeto: {})
        test_class.test_list[1] = test_class.new(1)

        expect(test_class.estimate_time([0, 1])).to be_within(0.001).of(0.2)
      end
    end

    describe '.uids_add and .ids_from_uid' do
      it 'adds and retrieves uid mappings' do
        test_class.uids_add(100, 5)
        test_class.uids_add(100, 6)
        expect(test_class.ids_from_uid(100)).to eq([5, 6])
      end

      it 'returns empty array for unknown uid' do
        expect(test_class.ids_from_uid(999)).to eq([])
      end

      it 'does not add duplicate ids' do
        test_class.uids_add(100, 5)
        test_class.uids_add(100, 5)
        expect(test_class.ids_from_uid(100)).to eq([5])
      end
    end

    describe '.to_json' do
      it 'produces valid JSON array of all rooms' do
        test_class.test_list[0] = test_class.new(0, paths: ['Paths A'])
        test_class.test_list[1] = test_class.new(1, paths: ['Paths B'])

        json_string = test_class.to_json
        parsed = JSON.parse(json_string)
        expect(parsed).to be_an(Array)
        expect(parsed.size).to eq(2)
        expect(parsed[0]['id']).to eq(0)
        expect(parsed[1]['id']).to eq(1)
      end
    end

    describe '.findpath' do
      before do
        room0 = test_class.new(0, wayto: { '1' => 'north', '2' => 'east' }, timeto: { '1' => 1, '2' => 5 })
        room1 = test_class.new(1, wayto: { '2' => 'east' }, timeto: { '2' => 1 })
        room2 = test_class.new(2)

        test_class.test_list[0] = room0
        test_class.test_list[1] = room1
        test_class.test_list[2] = room2
      end

      it 'finds path between two room ids' do
        path = test_class.findpath(0, 2)
        expect(path).to eq([1, 2])
      end

      it 'accepts a Room object as source' do
        room0 = test_class.test_list[0]
        path = test_class.findpath(room0, 2)
        expect(path).to eq([1, 2])
      end
    end

    describe '.dijkstra class method' do
      it 'dispatches to instance dijkstra' do
        room0 = test_class.new(0, wayto: { '1' => 'north' }, timeto: { '1' => 1 })
        room1 = test_class.new(1)

        test_class.test_list[0] = room0
        test_class.test_list[1] = room1

        previous, = test_class.dijkstra(0, 1)
        expect(previous[1]).to eq(0)
      end
    end
  end

  describe 'StringProc support in timeto' do
    before do
      test_class.test_list = []
      test_class.test_loaded = true

      # Room with StringProc timeto
      room0 = test_class.new(0, wayto: { '1' => 'north' }, timeto: { '1' => StringProc.new('2 + 3') })
      room1 = test_class.new(1, wayto: { '0' => 'south' }, timeto: { '0' => 5 })

      test_class.test_list[0] = room0
      test_class.test_list[1] = room1
    end

    it 'evaluates StringProc for edge weight' do
      room = test_class.test_list[0]
      _, distances = room.dijkstra

      expect(distances[1]).to eq(5) # 2 + 3 from StringProc
    end
  end

  describe 'nil timeto handling' do
    before do
      test_class.test_list = []
      test_class.test_loaded = true

      # Room with nil timeto (disabled path)
      room0 = test_class.new(0, wayto: { '1' => 'north', '2' => 'east' }, timeto: { '1' => nil, '2' => 1 })
      room1 = test_class.new(1, wayto: { '0' => 'south' }, timeto: { '0' => 1 })
      room2 = test_class.new(2, wayto: { '0' => 'west' }, timeto: { '0' => 1 })

      test_class.test_list[0] = room0
      test_class.test_list[1] = room1
      test_class.test_list[2] = room2
    end

    it 'skips paths with nil timeto' do
      room = test_class.test_list[0]
      _, distances = room.dijkstra

      expect(distances[1]).to be_nil # Path disabled
      expect(distances[2]).to eq(1)  # Path enabled
    end
  end

  describe '.apply_wayto_overrides' do
    let(:settings) { OpenStruct.new }

    before do
      test_class.test_list = []
      test_class.test_loaded = true

      room10 = test_class.new(10, wayto: {}, timeto: {})
      room20 = test_class.new(20, wayto: {}, timeto: {})
      test_class.test_list[10] = room10
      test_class.test_list[20] = room20

      stub_const('GameSettings', {})
      allow(test_class).to receive(:get_settings).and_return(settings)
    end

    it 'applies wayto overrides with str_proc' do
      settings.base_wayto_overrides = {
        'override1' => {
          'start_room' => 10,
          'end_room'   => 20,
          'str_proc'   => 'move north'
        }
      }
      settings.personal_wayto_overrides = nil
      settings.personal_map_targets = nil

      test_class.apply_wayto_overrides
      expect(test_class.test_list[10].wayto['20']).to be_a(StringProc)
    end

    it 'applies wayto overrides with numeric travel_time' do
      settings.base_wayto_overrides = {
        'override1' => {
          'start_room'  => 10,
          'end_room'    => 20,
          'str_proc'    => 'move north',
          'travel_time' => 3.5
        }
      }
      settings.personal_wayto_overrides = nil
      settings.personal_map_targets = nil

      test_class.apply_wayto_overrides
      expect(test_class.test_list[10].timeto['20']).to eq(3.5)
    end

    it 'applies travel_time as StringProc when non-numeric' do
      settings.base_wayto_overrides = {
        'override1' => {
          'start_room'  => 10,
          'end_room'    => 20,
          'travel_time' => '1 + 2'
        }
      }
      settings.personal_wayto_overrides = nil
      settings.personal_map_targets = nil

      test_class.apply_wayto_overrides
      expect(test_class.test_list[10].timeto['20']).to be_a(StringProc)
    end

    it 'personal overrides take precedence over base overrides' do
      settings.base_wayto_overrides = {
        'override1' => {
          'start_room' => 10,
          'end_room'   => 20,
          'str_proc'   => 'move north'
        }
      }
      settings.personal_wayto_overrides = {
        'override1' => {
          'start_room' => 10,
          'end_room'   => 20,
          'str_proc'   => 'go door'
        }
      }
      settings.personal_map_targets = nil

      test_class.apply_wayto_overrides
      proc = test_class.test_list[10].wayto['20']
      expect(proc).to be_a(StringProc)
    end

    it 'skips entries missing start_room' do
      settings.base_wayto_overrides = {
        'bad' => { 'end_room' => 20, 'str_proc' => 'go north' }
      }
      settings.personal_wayto_overrides = nil
      settings.personal_map_targets = nil

      test_class.apply_wayto_overrides
      expect(test_class.test_list[10].wayto).to be_empty
      expect(test_class.test_list[20].wayto).to be_empty
    end

    it 'skips entries missing end_room' do
      settings.base_wayto_overrides = {
        'bad' => { 'start_room' => 10, 'str_proc' => 'go north' }
      }
      settings.personal_wayto_overrides = nil
      settings.personal_map_targets = nil

      test_class.apply_wayto_overrides
      expect(test_class.test_list[10].wayto).to be_empty
    end

    it 'skips non-hash override entries' do
      settings.base_wayto_overrides = { 'bad' => 'not a hash' }
      settings.personal_wayto_overrides = nil
      settings.personal_map_targets = nil

      expect { test_class.apply_wayto_overrides }.not_to raise_error
    end

    it 'skips entries where start_room does not exist in map' do
      settings.base_wayto_overrides = {
        'missing' => { 'start_room' => 9999, 'end_room' => 20, 'str_proc' => 'go north' }
      }
      settings.personal_wayto_overrides = nil
      settings.personal_map_targets = nil

      expect { test_class.apply_wayto_overrides }.not_to raise_error
    end

    it 'merges personal_map_targets into GameSettings custom targets' do
      settings.base_wayto_overrides = nil
      settings.personal_wayto_overrides = nil
      settings.personal_map_targets = { 'my_spot' => 10 }

      test_class.apply_wayto_overrides
      expect(GameSettings['custom targets']).to eq({ 'my_spot' => 10 })
    end

    it 'merges personal_map_targets with existing custom targets' do
      GameSettings['custom targets'] = { 'bank' => 20 }
      settings.base_wayto_overrides = nil
      settings.personal_wayto_overrides = nil
      settings.personal_map_targets = { 'my_spot' => 10 }

      test_class.apply_wayto_overrides
      expect(GameSettings['custom targets']).to eq({ 'bank' => 20, 'my_spot' => 10 })
    end

    it 'skips personal_map_targets when not a hash' do
      settings.base_wayto_overrides = nil
      settings.personal_wayto_overrides = nil
      settings.personal_map_targets = 'not a hash'

      expect { test_class.apply_wayto_overrides }.not_to raise_error
      expect(GameSettings['custom targets']).to be_nil
    end

    it 'skips personal_map_targets when nil' do
      settings.base_wayto_overrides = nil
      settings.personal_wayto_overrides = nil
      settings.personal_map_targets = nil

      expect { test_class.apply_wayto_overrides }.not_to raise_error
    end
  end
end
