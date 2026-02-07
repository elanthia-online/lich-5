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

# Mock Lich::Util for issue_command
module Lich
  module Util
    def self.issue_command(_command, _start, _end_pattern, **_opts)
      []
    end
  end
end unless defined?(Lich::Util)

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

      def get_item?(_item, _container = nil)
        true
      end

      def put_away_item?(_item, _container = nil)
        true
      end

      def tie_item?(_item, _container = nil)
        true
      end

      def untie_item?(_item, _container = nil)
        true
      end

      def wear_item?(_item)
        true
      end

      def remove_item?(_item)
        true
      end
    end
  end
end unless defined?(Lich::DragonRealms::DRCI)

DRCI = Lich::DragonRealms::DRCI unless defined?(DRCI)

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

# Mock UserVars for moon data
module UserVars
  @moons = {}
  @sun = {}

  class << self
    attr_accessor :moons, :sun
  end
end unless defined?(UserVars)

# Stub game helper methods
module Kernel
  def pause(_seconds = nil); end
  def waitrt?; end
  def echo(_msg); end
  def fput(_cmd); end
  def get_data(_key)
    OpenStruct.new(observe_finished_messages: [])
  end
end

require 'ostruct'

# Load the module under test
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-moonmage.rb')

DRCMM = Lich::DragonRealms::DRCMM unless defined?(DRCMM)

RSpec.describe DRCMM do
  before(:each) do
    Lich::Messaging.clear_messages!
  end

  # ─── Deprecated get_telescope ──────────────────────────────────────

  describe '.get_telescope' do
    context 'when get_telescope? succeeds' do
      it 'returns without logging an error when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        allow(DRCI).to receive(:untie_item?).with('telescope', 'belt').and_return(true)

        DRCMM.get_telescope(storage)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging an error when in container' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(true)

        DRCMM.get_telescope(storage)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when already in hands' do
        storage = {}
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)

        DRCMM.get_telescope(storage)

        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when get_telescope? fails' do
      it 'logs an error message' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(false)

        DRCMM.get_telescope(storage)

        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to get telescope')
      end
    end
  end

  # ─── Deprecated store_telescope ────────────────────────────────────

  describe '.store_telescope' do
    context 'when store_telescope? succeeds' do
      it 'returns without logging an error when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        allow(DRCI).to receive(:tie_item?).with('telescope', 'belt').and_return(true)

        DRCMM.store_telescope(storage)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging an error when in container' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope', 'backpack').and_return(true)

        DRCMM.store_telescope(storage)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when not in hands' do
        storage = {}
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)

        DRCMM.store_telescope(storage)

        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when store_telescope? fails' do
      it 'logs an error message' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope', 'backpack').and_return(false)

        DRCMM.store_telescope(storage)

        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to store telescope')
      end
    end
  end

  # ─── Deprecated get_bones ──────────────────────────────────────────

  describe '.get_bones' do
    context 'when get_bones? succeeds' do
      it 'returns without logging when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:untie_item?).with('bones', 'belt').and_return(true)

        DRCMM.get_bones(storage)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(true)

        DRCMM.get_bones(storage)

        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when get_bones? fails' do
      it 'logs an error message' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(false)

        DRCMM.get_bones(storage)

        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to get bones')
      end
    end
  end

  # ─── Deprecated store_bones ────────────────────────────────────────

  describe '.store_bones' do
    context 'when store_bones? succeeds' do
      it 'returns without logging when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:tie_item?).with('bones', 'belt').and_return(true)

        DRCMM.store_bones(storage)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(true)

        DRCMM.store_bones(storage)

        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when store_bones? fails' do
      it 'logs an error message' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(false)

        DRCMM.store_bones(storage)

        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to store bones')
      end
    end
  end

  # ─── Deprecated get_div_tool ───────────────────────────────────────

  describe '.get_div_tool' do
    context 'when get_div_tool? succeeds' do
      it 'returns without logging when tied' do
        tool = { 'name' => 'charts', 'container' => 'satchel', 'tied' => true }
        allow(DRCI).to receive(:untie_item?).with('charts', 'satchel').and_return(true)

        DRCMM.get_div_tool(tool)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when worn' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:remove_item?).with('mirror').and_return(true)

        DRCMM.get_div_tool(tool)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(true)

        DRCMM.get_div_tool(tool)

        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when get_div_tool? fails' do
      it 'logs an error message with tool name' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(false)

        DRCMM.get_div_tool(tool)

        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include("Failed to get divination tool 'charts'")
      end
    end
  end

  # ─── Deprecated store_div_tool ─────────────────────────────────────

  describe '.store_div_tool' do
    context 'when store_div_tool? succeeds' do
      it 'returns without logging when tied' do
        tool = { 'name' => 'charts', 'container' => 'satchel', 'tied' => true }
        allow(DRCI).to receive(:tie_item?).with('charts', 'satchel').and_return(true)

        DRCMM.store_div_tool(tool)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when worn' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:wear_item?).with('mirror').and_return(true)

        DRCMM.store_div_tool(tool)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:put_away_item?).with('charts', 'satchel').and_return(true)

        DRCMM.store_div_tool(tool)

        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when store_div_tool? fails' do
      it 'logs an error message with tool name' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:put_away_item?).with('charts', 'satchel').and_return(false)

        DRCMM.store_div_tool(tool)

        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include("Failed to store divination tool 'charts'")
      end
    end
  end

  # ─── get_telescope? (DRCI predicate version) ──────────────────────

  describe '.get_telescope?' do
    it 'returns true when already in hands' do
      allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)

      expect(DRCMM.get_telescope?('telescope', {})).to be true
    end

    it 'calls untie_item? when tied' do
      storage = { 'tied' => 'belt' }
      allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
      expect(DRCI).to receive(:untie_item?).with('telescope', 'belt').and_return(true)

      expect(DRCMM.get_telescope?('telescope', storage)).to be true
    end

    it 'calls get_item? with container when container specified' do
      storage = { 'container' => 'backpack' }
      allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
      expect(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(true)

      expect(DRCMM.get_telescope?('telescope', storage)).to be true
    end

    it 'calls get_item? without container when no storage specified' do
      storage = {}
      allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
      expect(DRCI).to receive(:get_item?).with('telescope').and_return(true)

      expect(DRCMM.get_telescope?('telescope', storage)).to be true
    end
  end

  # ─── store_telescope? (DRCI predicate version) ────────────────────

  describe '.store_telescope?' do
    it 'returns true when not in hands' do
      allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)

      expect(DRCMM.store_telescope?('telescope', {})).to be true
    end

    it 'calls tie_item? when tied' do
      storage = { 'tied' => 'belt' }
      allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
      expect(DRCI).to receive(:tie_item?).with('telescope', 'belt').and_return(true)

      expect(DRCMM.store_telescope?('telescope', storage)).to be true
    end

    it 'calls put_away_item? with container when container specified' do
      storage = { 'container' => 'backpack' }
      allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
      expect(DRCI).to receive(:put_away_item?).with('telescope', 'backpack').and_return(true)

      expect(DRCMM.store_telescope?('telescope', storage)).to be true
    end
  end

  # ─── get_bones? (DRCI predicate version) ──────────────────────────

  describe '.get_bones?' do
    it 'calls untie_item? when tied' do
      storage = { 'tied' => 'belt' }
      expect(DRCI).to receive(:untie_item?).with('bones', 'belt').and_return(true)

      expect(DRCMM.get_bones?(storage)).to be true
    end

    it 'calls get_item? with container when container specified' do
      storage = { 'container' => 'pouch' }
      expect(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(true)

      expect(DRCMM.get_bones?(storage)).to be true
    end

    it 'calls get_item? without container when no storage specified' do
      storage = {}
      expect(DRCI).to receive(:get_item?).with('bones').and_return(true)

      expect(DRCMM.get_bones?(storage)).to be true
    end
  end

  # ─── store_bones? (DRCI predicate version) ────────────────────────

  describe '.store_bones?' do
    it 'calls tie_item? when tied' do
      storage = { 'tied' => 'belt' }
      expect(DRCI).to receive(:tie_item?).with('bones', 'belt').and_return(true)

      expect(DRCMM.store_bones?(storage)).to be true
    end

    it 'calls put_away_item? with container when container specified' do
      storage = { 'container' => 'pouch' }
      expect(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(true)

      expect(DRCMM.store_bones?(storage)).to be true
    end

    it 'calls put_away_item? without container when no storage specified' do
      storage = {}
      expect(DRCI).to receive(:put_away_item?).with('bones').and_return(true)

      expect(DRCMM.store_bones?(storage)).to be true
    end
  end

  # ─── get_div_tool? (DRCI predicate version) ───────────────────────

  describe '.get_div_tool?' do
    it 'calls untie_item? when tied' do
      tool = { 'name' => 'charts', 'container' => 'satchel', 'tied' => true }
      expect(DRCI).to receive(:untie_item?).with('charts', 'satchel').and_return(true)

      expect(DRCMM.get_div_tool?(tool)).to be true
    end

    it 'calls remove_item? when worn' do
      tool = { 'name' => 'mirror', 'worn' => true }
      expect(DRCI).to receive(:remove_item?).with('mirror').and_return(true)

      expect(DRCMM.get_div_tool?(tool)).to be true
    end

    it 'calls get_item? with container when in container' do
      tool = { 'name' => 'charts', 'container' => 'satchel' }
      expect(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(true)

      expect(DRCMM.get_div_tool?(tool)).to be true
    end
  end

  # ─── store_div_tool? (DRCI predicate version) ─────────────────────

  describe '.store_div_tool?' do
    it 'calls tie_item? when tied' do
      tool = { 'name' => 'charts', 'container' => 'satchel', 'tied' => true }
      expect(DRCI).to receive(:tie_item?).with('charts', 'satchel').and_return(true)

      expect(DRCMM.store_div_tool?(tool)).to be true
    end

    it 'calls wear_item? when worn' do
      tool = { 'name' => 'mirror', 'worn' => true }
      expect(DRCI).to receive(:wear_item?).with('mirror').and_return(true)

      expect(DRCMM.store_div_tool?(tool)).to be true
    end

    it 'calls put_away_item? with container when in container' do
      tool = { 'name' => 'charts', 'container' => 'satchel' }
      expect(DRCI).to receive(:put_away_item?).with('charts', 'satchel').and_return(true)

      expect(DRCMM.store_div_tool?(tool)).to be true
    end
  end
end
