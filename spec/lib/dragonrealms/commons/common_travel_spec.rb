# frozen_string_literal: true

require 'rspec'

# Setup load path (standalone spec, no spec_helper dependency)
LIB_DIR = File.join(File.expand_path('../../../..', __dir__), 'lib') unless defined?(LIB_DIR)

# Mock Lich::Messaging before loading the module under test
module Lich
  module Messaging
    @messages = []

    class << self
      def messages
        @messages ||= []
      end

      def clear_messages!
        @messages = []
      end

      def msg(type, message)
        @messages ||= []
        @messages << { type: type, message: message }
      end
    end
  end
end unless defined?(Lich::Messaging)

# Mock DRC (module) — common.rb
module Lich
  module DragonRealms
    module DRC
      module_function

      def bput(_command, *_patterns)
        nil
      end

      def right_hand
        nil
      end

      def left_hand
        nil
      end

      def message(_msg); end

      def fix_standing; end
    end
  end
end unless defined?(Lich::DragonRealms::DRC)

DRC = Lich::DragonRealms::DRC unless defined?(DRC)

# Mock DRCI (module) — common-items.rb
module Lich
  module DragonRealms
    module DRCI
      module_function

      def in_hands?(_item)
        false
      end

      def put_away_item_unsafe?(_item, _container = nil, _preposition = 'in')
        true
      end

      def dispose_trash(_item, _container = nil, _verb = nil); end
    end
  end
end unless defined?(Lich::DragonRealms::DRCI)

DRCI = Lich::DragonRealms::DRCI unless defined?(DRCI)

# Mock DRRoom (module)
module Lich
  module DragonRealms
    module DRRoom
      module_function

      def npcs
        []
      end
    end
  end
end unless defined?(Lich::DragonRealms::DRRoom)

DRRoom = Lich::DragonRealms::DRRoom unless defined?(DRRoom)

# Mock DRStats (module)
module Lich
  module DragonRealms
    module DRStats
      module_function

      def moon_mage?
        false
      end

      def trader?
        false
      end
    end
  end
end unless defined?(Lich::DragonRealms::DRStats)

DRStats = Lich::DragonRealms::DRStats unless defined?(DRStats)

# Mock DRCA (module)
module Lich
  module DragonRealms
    module DRCA
      module_function

      def perc_mana
        0
      end
    end
  end
end unless defined?(Lich::DragonRealms::DRCA)

DRCA = Lich::DragonRealms::DRCA unless defined?(DRCA)

# Mock Room for walk_to
# Always define/redefine methods (no `unless defined?` guard) because
# games_spec.rb may define Room first without `current=`.
class Room
  class << self
    def current
      @current ||= OpenStruct.new(id: 1, dijkstra: [nil, {}])
    end

    def current=(room)
      @current = room
    end
  end
end

# Mock Map — always define needed methods (games_spec.rb Map lacks dijkstra/list)
class Map
  class << self
    def list
      []
    end

    def dijkstra(_id, _target = nil)
      [nil, {}]
    end

    def [](_id)
      nil
    end
  end
end

# Mock XMLData — always define needed methods (games_spec.rb XMLData lacks room_description/room_exits)
module XMLData
  class << self
    def room_description
      ''
    end

    def room_title
      ''
    end

    def room_exits
      []
    end
  end
end

# Mock UserVars — always define needed methods
module UserVars
  @friends ||= []
  @hunting_nemesis ||= []

  class << self
    attr_accessor :friends, :hunting_nemesis
  end
end

# Mock Flags — always define needed methods
module Flags
  class << self
    def add(_name, *_patterns); end
    def delete(_name); end
    def reset(_name); end
    def [](_name); end
  end
end

# Mock Script — always define needed methods (games_spec.rb Script lacks running/running?)
class Script
  class << self
    def running
      []
    end

    def running?(_name)
      false
    end
  end
end

# Stub game helper methods
module Kernel
  def pause(_seconds = nil); end
  def waitrt?; end
  def echo(_msg); end
  def fput(_cmd); end
  def move(_dir); end

  def start_script(_name, _args = [], **_opts)
    Object.new
  end

  def kill_script(_handle); end

  def get_data(key)
    return { 'Crossing' => { 'locksmithing' => { 'id' => 19_073 } } } if key == 'town'

    {}
  end
end

require 'ostruct'

# Load the module under test
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-travel.rb')

DRCT = Lich::DragonRealms::DRCT unless defined?(DRCT)

RSpec.describe DRCT do
  before(:each) do
    Lich::Messaging.clear_messages!
    Room.current = OpenStruct.new(id: 19_073, dijkstra: [nil, {}])
  end

  # ─── refill_lockpick_container ─────────────────────────────────────

  describe '.refill_lockpick_container' do
    let(:lockpick_type) { 'steel' }
    let(:hometown) { 'Crossing' }
    let(:container) { 'lockpick ring' }

    before(:each) do
      allow(DRCT).to receive(:walk_to).and_return(true)
      allow(DRCT).to receive(:buy_item)
      allow(DRC).to receive(:fix_standing)
      allow(XMLData).to receive(:room_exits).and_return([])
    end

    it 'returns immediately when count is 0' do
      expect(DRCI).not_to receive(:put_away_item_unsafe?)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 0)
    end

    it 'calls DRCI.put_away_item_unsafe? with on preposition' do
      expect(DRCI).to receive(:put_away_item_unsafe?)
        .with('my lockpick', 'my lockpick ring', 'on')
        .and_return(true)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 1)
    end

    it 'buys and stores multiple lockpicks when count > 1' do
      expect(DRCT).to receive(:buy_item).exactly(3).times
      expect(DRCI).to receive(:put_away_item_unsafe?)
        .with('my lockpick', 'my lockpick ring', 'on')
        .exactly(3).times
        .and_return(true)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 3)
    end

    it 'breaks and logs error when put_away_item_unsafe? returns false' do
      expect(DRCI).to receive(:put_away_item_unsafe?)
        .with('my lockpick', 'my lockpick ring', 'on')
        .and_return(false)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 3)

      expect(Lich::Messaging.messages.last[:type]).to eq('bold')
      expect(Lich::Messaging.messages.last[:message]).to include('DRCT:')
      expect(Lich::Messaging.messages.last[:message]).to include('Failed to put lockpick')
    end

    it 'only buys one lockpick when first put fails' do
      expect(DRCT).to receive(:buy_item).once
      allow(DRCI).to receive(:put_away_item_unsafe?).and_return(false)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 5)
    end
  end
end
