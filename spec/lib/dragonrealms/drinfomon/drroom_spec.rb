# frozen_string_literal: true

require 'rspec'

# Define XMLData module if not already defined
module XMLData
end unless defined?(XMLData)

require_relative '../../../../lib/dragonrealms/drinfomon/drroom'

RSpec.describe Lich::DragonRealms::DRRoom do
  let(:described_class) { Lich::DragonRealms::DRRoom }

  before(:each) do
    # Use RSpec stubs for XMLData methods - automatically cleaned up after each test
    # This prevents polluting global state that breaks other specs
    allow(XMLData).to receive(:room_exits).and_return(['north', 'south'])
    allow(XMLData).to receive(:room_title).and_return('[Test Room]')
    allow(XMLData).to receive(:room_description).and_return('A test room description.')

    # Reset all class variables
    described_class.npcs = []
    described_class.pcs = []
    described_class.group_members = []
    described_class.pcs_prone = []
    described_class.pcs_sitting = []
    described_class.dead_npcs = []
    described_class.room_objs = []
  end

  describe 'NPC accessors' do
    describe '.npcs' do
      it 'returns empty array by default' do
        expect(described_class.npcs).to eq([])
      end

      it 'can be set and retrieved' do
        described_class.npcs = ['a goblin', 'a troll']
        expect(described_class.npcs).to eq(['a goblin', 'a troll'])
      end
    end

    describe '.dead_npcs' do
      it 'returns empty array by default' do
        expect(described_class.dead_npcs).to eq([])
      end

      it 'can be set and retrieved' do
        described_class.dead_npcs = ['a dead goblin']
        expect(described_class.dead_npcs).to eq(['a dead goblin'])
      end
    end
  end

  describe 'PC accessors' do
    describe '.pcs' do
      it 'returns empty array by default' do
        expect(described_class.pcs).to eq([])
      end

      it 'can be set and retrieved' do
        described_class.pcs = ['Gandalf', 'Frodo']
        expect(described_class.pcs).to eq(['Gandalf', 'Frodo'])
      end
    end

    describe '.pcs_prone' do
      it 'returns empty array by default' do
        expect(described_class.pcs_prone).to eq([])
      end

      it 'can be set and retrieved' do
        described_class.pcs_prone = ['FallenHero']
        expect(described_class.pcs_prone).to eq(['FallenHero'])
      end
    end

    describe '.pcs_sitting' do
      it 'returns empty array by default' do
        expect(described_class.pcs_sitting).to eq([])
      end

      it 'can be set and retrieved' do
        described_class.pcs_sitting = ['RestingWarrior']
        expect(described_class.pcs_sitting).to eq(['RestingWarrior'])
      end
    end
  end

  describe 'group accessors' do
    describe '.group_members' do
      it 'returns empty array by default' do
        expect(described_class.group_members).to eq([])
      end

      it 'can be set and retrieved' do
        described_class.group_members = ['Ally1', 'Ally2']
        expect(described_class.group_members).to eq(['Ally1', 'Ally2'])
      end
    end
  end

  describe 'room object accessors' do
    describe '.room_objs' do
      it 'returns empty array by default' do
        expect(described_class.room_objs).to eq([])
      end

      it 'can be set and retrieved' do
        described_class.room_objs = ['a brass chest', 'a silver ring']
        expect(described_class.room_objs).to eq(['a brass chest', 'a silver ring'])
      end
    end
  end

  describe 'XMLData delegators' do
    describe '.exits' do
      it 'returns XMLData.room_exits' do
        expect(described_class.exits).to eq(['north', 'south'])
      end
    end

    describe '.title' do
      it 'returns XMLData.room_title' do
        expect(described_class.title).to eq('[Test Room]')
      end
    end

    describe '.description' do
      it 'returns XMLData.room_description' do
        expect(described_class.description).to eq('A test room description.')
      end
    end
  end
end
