# frozen_string_literal: true

# NOTE: This spec must be run individually, not combined with map_gs_spec.rb.
# Both map_dr.rb and map_gs.rb define Lich::Common::Map (one per game).
# Run: rspec spec/map_dr_spec.rb

require 'rspec'
require 'json'

LIB_DIR = File.join(File.expand_path('..', File.dirname(__FILE__)), 'lib') unless defined?(LIB_DIR)

# Minimal mocks for map_dr.rb dependencies
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

module XMLData
  class << self
    attr_accessor :game, :room_count, :room_id, :room_title, :room_description,
                  :room_exits_string, :room_window_disabled, :previous_nav_rm
  end
end unless defined?(XMLData)

DATA_DIR = '/tmp/lich_test_data' unless defined?(DATA_DIR)

module Script
  class << self
    def current
      nil
    end
  end
end unless defined?(Script)

def respond(msg = '')
  # mock
end

def echo(msg = '')
  # mock
end

require File.join(LIB_DIR, 'common', 'map', 'map_dr.rb')

RSpec.describe Lich::Common::Map do
  # Reset class state between tests
  before(:each) do
    # Clear the list and reset loaded state
    Lich::Common::Map.send(:class_variable_set, :@@list, [])
    Lich::Common::Map.send(:class_variable_set, :@@tags, [])
    Lich::Common::Map.send(:class_variable_set, :@@uids, {})
    Lich::Common::Map.send(:class_variable_set, :@@loaded, true)
  end

  describe 'Genie field support' do
    describe '#initialize' do
      it 'accepts genie fields as parameters' do
        room = Lich::Common::Map.new(
          1, ['[Crossing]'], ['The main square.'], ['Obvious paths: north'],
          [100], nil, nil, nil, {}, {}, nil, nil, [], nil, nil, nil,
          'node42', 'zone1', [520, 120, 0]
        )

        expect(room.genie_id).to eq('node42')
        expect(room.genie_zone).to eq('zone1')
        expect(room.genie_pos).to eq([520, 120, 0])
      end

      it 'defaults genie fields to nil' do
        room = Lich::Common::Map.new(
          2, ['[Town]'], ['A town.'], ['Obvious paths: east'],
          [200]
        )

        expect(room.genie_id).to be_nil
        expect(room.genie_zone).to be_nil
        expect(room.genie_pos).to be_nil
      end
    end

    describe 'attr_accessor' do
      let(:room) do
        Lich::Common::Map.new(3, ['[Room]'], ['Desc.'], ['Paths'])
      end

      it 'allows reading and writing genie_id' do
        room.genie_id = 'node99'
        expect(room.genie_id).to eq('node99')
      end

      it 'allows reading and writing genie_zone' do
        room.genie_zone = 'zone55'
        expect(room.genie_zone).to eq('zone55')
      end

      it 'allows reading and writing genie_pos' do
        room.genie_pos = [100, 200, 0]
        expect(room.genie_pos).to eq([100, 200, 0])
      end
    end

    describe '#json_extra_fields' do
      it 'returns genie fields hash' do
        room = Lich::Common::Map.new(
          10, ['[Room]'], ['Desc'], ['Paths'],
          [], nil, nil, nil, {}, {}, nil, nil, [], nil, nil, nil,
          'node5', 'zone3', [100, 200, 0]
        )

        extra = room.json_extra_fields
        expect(extra[:genie_id]).to eq('node5')
        expect(extra[:genie_zone]).to eq('zone3')
        expect(extra[:genie_pos]).to eq([100, 200, 0])
      end
    end

    describe '#to_json' do
      it 'includes genie fields when present' do
        room = Lich::Common::Map.new(
          10, ['[Room]'], ['Desc'], ['Paths'],
          [], nil, nil, nil, {}, {}, nil, nil, [], nil, nil, nil,
          'node5', 'zone3', [100, 200, 0]
        )

        json_string = room.to_json
        parsed = JSON.parse(json_string)

        expect(parsed['genie_id']).to eq('node5')
        expect(parsed['genie_zone']).to eq('zone3')
        expect(parsed['genie_pos']).to eq([100, 200, 0])
      end

      it 'excludes genie fields when nil' do
        room = Lich::Common::Map.new(
          11, ['[Room]'], ['Desc'], ['Paths']
        )

        json_string = room.to_json
        parsed = JSON.parse(json_string)

        expect(parsed).not_to have_key('genie_id')
        expect(parsed).not_to have_key('genie_zone')
        expect(parsed).not_to have_key('genie_pos')
      end
    end

    describe '.by_genie_ref' do
      before(:each) do
        Lich::Common::Map.new(
          20, ['[Room A]'], ['Desc A'], ['Paths'],
          [], nil, nil, nil, {}, {}, nil, nil, [], nil, nil, nil,
          '42', '1', [520, 120, 0]
        )
        Lich::Common::Map.new(
          21, ['[Room B]'], ['Desc B'], ['Paths'],
          [], nil, nil, nil, {}, {}, nil, nil, [], nil, nil, nil,
          '335', '1', [540, 140, 0]
        )
        Lich::Common::Map.new(
          22, ['[Room C]'], ['Desc C'], ['Paths'],
          [], nil, nil, nil, {}, {}, nil, nil, [], nil, nil, nil,
          '1', '2', [100, 100, 0]
        )
      end

      it 'finds room by zone and node id' do
        room = Lich::Common::Map.by_genie_ref('1', '42')
        expect(room).not_to be_nil
        expect(room.id).to eq(20)
      end

      it 'finds different node in same zone' do
        room = Lich::Common::Map.by_genie_ref('1', '335')
        expect(room).not_to be_nil
        expect(room.id).to eq(21)
      end

      it 'finds node in different zone' do
        room = Lich::Common::Map.by_genie_ref('2', '1')
        expect(room).not_to be_nil
        expect(room.id).to eq(22)
      end

      it 'returns nil for nonexistent reference' do
        room = Lich::Common::Map.by_genie_ref('999', '999')
        expect(room).to be_nil
      end

      it 'converts integer arguments to strings for comparison' do
        room = Lich::Common::Map.by_genie_ref(1, 42)
        expect(room).not_to be_nil
        expect(room.id).to eq(20)
      end
    end
  end

  describe 'standard Map functionality' do
    describe '#to_s' do
      it 'formats room as string' do
        room = Lich::Common::Map.new(
          50, ['[Town Square]'], ['A busy square.'], ['Obvious paths: north'],
          [12_345]
        )
        result = room.to_s
        expect(result).to include('#50')
        expect(result).to include('12345')
        expect(result).to include('[Town Square]')
      end
    end

    describe '.[]' do
      before(:each) do
        Lich::Common::Map.new(0, ['[Room Zero]'], ['Zero desc'], ['Paths'])
        Lich::Common::Map.new(1, ['[Room One]'], ['One desc'], ['Paths'])
      end

      it 'looks up by integer id' do
        room = Lich::Common::Map[0]
        expect(room.title).to eq(['[Room Zero]'])
      end

      it 'looks up by string id' do
        room = Lich::Common::Map['1']
        expect(room.title).to eq(['[Room One]'])
      end

      it 'looks up by title search' do
        room = Lich::Common::Map['Room One']
        expect(room).not_to be_nil
        expect(room.id).to eq(1)
      end
    end

    describe 'Room alias' do
      it 'exists as subclass of Map' do
        expect(Lich::Common::Room.superclass).to eq(Lich::Common::Map)
      end
    end
  end
end
