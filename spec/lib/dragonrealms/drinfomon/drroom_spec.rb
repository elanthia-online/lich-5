# frozen_string_literal: true

require_relative '../../../spec_helper'

require_relative '../../../../lib/dragonrealms/drinfomon/drroom'
require 'dragonrealms/creature'

RSpec.describe Lich::DragonRealms::DRRoom do
  before(:each) do
    # Use RSpec stubs for XMLData methods - automatically cleaned up after each test
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

    # Every script reads the same array, so one script's << or delete used to
    # change what every other script saw until the next room refresh.
    %i[npcs dead_npcs].each do |field|
      describe ".#{field} is read-only" do
        it 'raises FrozenError when a script mutates it in place' do
          described_class.public_send(:"#{field}=", %w[goblin goblin])
          expect { described_class.public_send(field) << 'troll' }.to raise_error(FrozenError)
          expect { described_class.public_send(field).delete('goblin') }.to raise_error(FrozenError)
          expect(described_class.public_send(field)).to eq(%w[goblin goblin])
        end

        it "leaves the caller's array unfrozen and unshared" do
          source = %w[goblin]
          described_class.public_send(:"#{field}=", source)
          source << 'troll'
          expect(source).not_to be_frozen
          expect(described_class.public_send(field)).to eq(%w[goblin])
        end

        it 'hands out a copy the script can edit' do
          described_class.public_send(:"#{field}=", %w[goblin])
          copy = described_class.public_send(field).dup
          copy << 'troll'
          expect(copy).to eq(%w[goblin troll])
          expect(described_class.public_send(field)).to eq(%w[goblin])
        end
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

  describe '.unignored_npcs' do
    let(:creatures) { Lich::DragonRealms::Creature }

    before { creatures.clear }
    after { creatures.clear }

    # Registers each [name, noun] as a creature in the room, then sets
    # DRRoom.npcs the way drparser would for the same room.
    def room(*named, npcs:)
      named.each_with_index { |(name, noun), i| creatures.register(name, 1000 + i, noun) }
      described_class.npcs = npcs
    end

    it 'drops every copy of an ignored noun' do
      described_class.npcs = %w[kobold moradu moradu]
      expect(described_class.unignored_npcs(['moradu'])).to eq(['kobold'])
    end

    it 'returns all NPCs for a nil or empty ignore list' do
      described_class.npcs = %w[kobold moradu]
      expect(described_class.unignored_npcs(nil)).to eq(%w[kobold moradu])
      expect(described_class.unignored_npcs([])).to eq(%w[kobold moradu])
    end

    it 'returns a new array and leaves DRRoom.npcs alone' do
      described_class.npcs = %w[kobold moradu]
      result = described_class.unignored_npcs(['kobold'])
      result << 'troll'
      expect(described_class.npcs).to eq(%w[kobold moradu])
    end

    it 'skips a pet named in full but not a wild creature of the same noun' do
      room(['a spectral white leopard with luminous blue eyes', 'leopard'], ['a sinewy leopard', 'leopard'],
           npcs: %w[leopard leopard])
      expect(described_class.unignored_npcs(['spectral white leopard'])).to eq(['leopard'])
      expect(described_class.unignored_npcs(['leopard'])).to eq([])
    end

    it "honours both the game's noun and the noun DRRoom.npcs lists" do
      room(['a majestic dragon with fiery crimson eyes and void-black scales', 'dragon'], ['a jeol moradu', 'moradu'],
           npcs: %w[moradu scales])
      expect(described_class.unignored_npcs(['dragon'])).to eq(['moradu'])
      expect(described_class.unignored_npcs(['scales'])).to eq(['moradu'])
      expect(described_class.unignored_npcs(['eyes'])).to eq(%w[moradu scales])
    end

    it 'falls back to the noun rule while the roster and DRRoom.npcs disagree' do
      room(['a spectral white leopard with luminous blue eyes', 'leopard'], npcs: %w[leopard leopard])
      expect(described_class.unignored_npcs(['spectral white leopard'])).to eq(%w[leopard leopard])
    end

    it 'falls back to the noun rule while a creature has no name' do
      creatures.sync('2000', 'hostile' => '1')
      room(['a spectral white leopard with luminous blue eyes', 'leopard'], npcs: %w[leopard leopard])
      expect(described_class.unignored_npcs(['spectral white leopard'])).to eq(%w[leopard leopard])
    end

    it 'falls back to the noun rule when a name reduces to no noun' do
      room(['a training dummy 2', nil], ['a jeol moradu', 'moradu'], npcs: ['moradu'])
      expect(described_class.unignored_npcs(['jeol moradu'])).to eq(['moradu'])
    end

    it "keeps a legacy creature's derived last-word noun from naming it" do
      creatures.sync('3000', 'hostile' => '1')
      creatures['3000'].apply_room_name('a spectral white leopard with luminous blue eyes')
      described_class.npcs = ['leopard']
      expect(described_class.unignored_npcs(['eyes'])).to eq(['leopard'])
      expect(described_class.unignored_npcs(['spectral white leopard'])).to eq([])
    end

    it 'leaves dead creatures out of the roster it pairs with DRRoom.npcs' do
      room(['a spectral white leopard with luminous blue eyes', 'leopard'], ['a sinewy leopard', 'leopard'],
           npcs: ['leopard'])
      creatures.sync('1001', 'dead' => '1')
      expect(described_class.unignored_npcs(['spectral white leopard'])).to eq([])
    end
  end
end
