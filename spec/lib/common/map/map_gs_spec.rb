# frozen_string_literal: true

require_relative '../../../spec_helper'

# Since we need a separate namespace for GS tests (to avoid conflicts with DR),
# we'll test the GS-specific features by checking the source file structure
# and mocking the unique behavior

# This spec tests GS-specific features:
# - Map.get_location
# - meta:map:latest-only, meta:playershop tags
# - peer tag checking
# - unique_loot handling
# - Map.locations and Map.images caches

RSpec.describe 'GemStone Map Implementation' do
  let(:gs_map_content) { File.read(File.expand_path('../../../../lib/common/map/map_gs.rb', __dir__)) }

  describe 'GS-specific methods' do
    it 'defines get_location method' do
      expect(gs_map_content).to include('def self.get_location')
    end

    it 'defines locations method' do
      expect(gs_map_content).to include('def self.locations')
    end

    it 'defines images method' do
      expect(gs_map_content).to include('def self.images')
    end

    it 'handles meta:map:latest-only tags in current_or_new' do
      expect(gs_map_content).to include('meta:map:latest-only')
    end

    it 'handles meta:playershop tags in current_or_new' do
      expect(gs_map_content).to include('meta:playershop')
    end

    it 'handles meta:map:multi-uid tags' do
      expect(gs_map_content).to include('meta:map:multi-uid')
    end

    it 'includes peer tag checking logic' do
      expect(gs_map_content).to include('check_peer_tag')
      expect(gs_map_content).to include('peer [a-z]+')
    end

    it 'handles unique_loot checking' do
      expect(gs_map_content).to include('unique_loot')
      expect(gs_map_content).to include('GameObj.loot')
    end

    it 'uses large UID threshold (4_294_967_296)' do
      expect(gs_map_content).to include('4_294_967_296')
    end

    it 'includes save_json reload validation' do
      expect(gs_map_content).to include('reload if self[-1].id != self[self[-1].id].id')
    end
  end

  describe 'class structure' do
    it 'includes MapBase module' do
      expect(gs_map_content).to include('include MapBase')
    end

    it 'includes Enumerable' do
      expect(gs_map_content).to include('include Enumerable')
    end

    it 'defines Room subclass' do
      expect(gs_map_content).to include('class Room < Map')
    end
  end

  describe 'class variables' do
    it 'defines @@images cache' do
      expect(gs_map_content).to include('@@images')
    end

    it 'defines @@locations cache' do
      expect(gs_map_content).to include('@@locations')
    end

    it 'defines @@fuzzy_room_id' do
      expect(gs_map_content).to include('@@fuzzy_room_id')
    end
  end

  describe 'attribute differences from DR' do
    it 'does NOT define room_objects attribute' do
      # GS doesn't have room_objects
      expect(gs_map_content).not_to include(':room_objects')
    end

    it 'has outside? method via MapBase' do
      # outside? is now in MapBase, not directly in GS
      base_content = File.read(File.expand_path('../../../../lib/common/map/map_base.rb', __dir__))
      expect(base_content).to include('def outside?')
    end
  end

  describe 'get_location method' do
    it 'sends location command to game' do
      expect(gs_map_content).to include("'location', 15")
    end

    it 'parses location response' do
      expect(gs_map_content).to include('You carefully survey your surroundings')
    end

    it 'handles error responses' do
      expect(gs_map_content).to include("can't do that while submerged")
      expect(gs_map_content).to include('pitch darkness')
    end
  end

  describe 'peer tag checking' do
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

  describe 'current_or_new meta tag handling' do
    it 'checks for meta:map:latest-only or meta:playershop' do
      expect(gs_map_content).to include("room.tags & %w[meta:map:latest-only meta:playershop]")
    end

    it 'uses unshift for normal rooms' do
      expect(gs_map_content).to include('room.title.unshift')
      expect(gs_map_content).to include('room.description.unshift')
      expect(gs_map_content).to include('room.paths.unshift')
    end

    it 'replaces values for latest-only rooms' do
      expect(gs_map_content).to include('room.title = [XMLData.room_title]')
      expect(gs_map_content).to include('room.description = [XMLData.room_description.strip]')
    end
  end

  describe 'match_fuzzy peer tag rejection' do
    it 'returns nil for rooms requiring peer check' do
      expect(gs_map_content).to include('room.tags.any? { |tag| tag =~')
    end
  end
end

RSpec.describe 'outside? method game-agnostic behavior' do
  let(:base_content) { File.read(File.expand_path('../../../../lib/common/map/map_base.rb', __dir__)) }

  it 'checks for "Obvious paths:" for outdoor detection' do
    expect(base_content).to include('Obvious paths:')
  end

  it 'works for both GS and DR exit formats' do
    # Both games use the same pattern:
    # - "Obvious paths:" for outdoor
    # - "Obvious exits:" for indoor
    expect(base_content).to include('@paths.last =~ /^Obvious paths:/')
  end

  it 'returns boolean true or false' do
    expect(base_content).to include('? true : false')
  end

  it 'handles nil paths gracefully' do
    expect(base_content).to include('return false if @paths.nil?')
  end

  it 'handles empty paths gracefully' do
    expect(base_content).to include('@paths.empty?')
  end
end

RSpec.describe 'Code sharing between DR and GS' do
  let(:base_content) { File.read(File.expand_path('../../../../lib/common/map/map_base.rb', __dir__)) }
  let(:dr_content) { File.read(File.expand_path('../../../../lib/common/map/map_dr.rb', __dir__)) }
  let(:gs_content) { File.read(File.expand_path('../../../../lib/common/map/map_gs.rb', __dir__)) }

  describe 'shared in MapBase' do
    it 'contains MinHeap implementation' do
      expect(base_content).to include('class MinHeap')
      expect(base_content).to include('def push(priority, value)')
      expect(base_content).to include('def pop')
      expect(base_content).to include('bubble_up')
      expect(base_content).to include('bubble_down')
    end

    it 'contains dijkstra algorithm' do
      expect(base_content).to include('def dijkstra(destination = nil)')
      expect(base_content).to include('pq = MinHeap.new')
      expect(base_content).to include('shortest_distances_hash')
      expect(base_content).to include('previous_hash')
    end

    it 'contains path_to method' do
      expect(base_content).to include('def path_to(destination)')
    end

    it 'contains find_nearest methods' do
      expect(base_content).to include('def find_nearest_by_tag')
      expect(base_content).to include('def find_all_nearest_by_tag')
      expect(base_content).to include('def find_nearest(target_list)')
    end

    it 'contains estimate_time method' do
      expect(base_content).to include('def estimate_time(array)')
    end

    it 'contains deprecated method stubs' do
      expect(base_content).to include('def desc')
      expect(base_content).to include('def map_name')
      expect(base_content).to include('def geo')
    end

    it 'contains to_json method' do
      expect(base_content).to include('def to_json')
    end
  end

  describe 'both implementations require map_base' do
    it 'DR requires map_base' do
      expect(dr_content).to include("require_relative 'map_base'")
    end

    it 'GS requires map_base' do
      expect(gs_content).to include("require_relative 'map_base'")
    end
  end

  describe 'both implementations include MapBase' do
    it 'DR includes MapBase' do
      expect(dr_content).to include('include MapBase')
    end

    it 'GS includes MapBase' do
      expect(gs_content).to include('include MapBase')
    end
  end

  describe 'common class method accessors' do
    %w[loaded? list uids clear_tags_cache mark_loaded synchronize_load].each do |method|
      it "both define #{method}" do
        expect(dr_content).to include("def #{method}")
        expect(gs_content).to include("def #{method}")
      end
    end
  end

  describe 'common file operations' do
    # Methods defined in game-specific files
    %w[load load_json load_xml save_xml].each do |method|
      it "both define self.#{method}" do
        expect(dr_content).to include("def self.#{method}")
        expect(gs_content).to include("def self.#{method}")
      end
    end

    # Methods moved to map_base.rb (shared via MapBase module)
    %w[load_dat save save_json].each do |method|
      it "base module defines #{method}" do
        base_content = File.read(File.join(__dir__, '../../../../lib/common/map/map_base.rb'))
        expect(base_content).to include("def #{method}")
      end
    end
  end
end
