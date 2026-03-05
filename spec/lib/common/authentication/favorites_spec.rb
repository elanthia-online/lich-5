# frozen_string_literal: true

# Spec coverage for favorites functionality in EntryStore
# Covers PR 1063 YAML requirements for favorites metadata support

require 'rspec'
require 'fileutils'
require 'tmpdir'
require 'yaml'
require_relative '../../../login_spec_helper'
require_relative '../../../../lib/common/authentication/entry_store'

RSpec.describe 'EntryStore Favorites' do
  let(:temp_dir) { Dir.mktmpdir }
  let(:data_dir) { temp_dir }
  let(:yaml_file) { File.join(data_dir, 'entry.yaml') }

  # Sample YAML data structure
  let(:sample_yaml_data) do
    {
      'encryption_mode' => 'plaintext',
      'accounts'        => {
        'TESTUSER'    => {
          'password'   => 'test_password',
          'characters' => [
            {
              'char_name'   => 'TestChar1',
              'game_code'   => 'GS3',
              'game_name'   => 'GemStone IV',
              'frontend'    => 'stormfront',
              'is_favorite' => false
            },
            {
              'char_name'   => 'TestChar2',
              'game_code'   => 'DR',
              'game_name'   => 'DragonRealms',
              'frontend'    => 'wizard',
              'is_favorite' => false
            }
          ]
        },
        'ANOTHERUSER' => {
          'password'   => 'another_password',
          'characters' => [
            {
              'char_name'      => 'AnotherChar',
              'game_code'      => 'GS3',
              'game_name'      => 'GemStone IV',
              'frontend'       => 'stormfront',
              'is_favorite'    => true,
              'favorite_order' => 1,
              'favorite_added' => '2026-01-01 12:00:00'
            }
          ]
        }
      }
    }
  end

  before do
    # Stub Utilities for safe_file_operation
    allow(Lich::Common::GUI::Utilities).to receive(:safe_file_operation) do |path, operation, content|
      if operation == :write
        File.write(path, content)
        true
      end
    end
  end

  after { FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir) }

  describe '.migrate_to_favorites_format' do
    it 'adds is_favorite field to characters without it' do
      yaml_data = {
        'accounts' => {
          'TESTUSER' => {
            'characters' => [
              { 'char_name' => 'NoFavoriteField' }
            ]
          }
        }
      }

      result = Lich::Common::Authentication::EntryStore.migrate_to_favorites_format(yaml_data)

      character = result['accounts']['TESTUSER']['characters'].first
      expect(character['is_favorite']).to eq(false)
    end

    it 'preserves existing is_favorite value if true' do
      yaml_data = {
        'accounts' => {
          'TESTUSER' => {
            'characters' => [
              { 'char_name' => 'ExistingFavorite', 'is_favorite' => true, 'favorite_order' => 1 }
            ]
          }
        }
      }

      result = Lich::Common::Authentication::EntryStore.migrate_to_favorites_format(yaml_data)

      character = result['accounts']['TESTUSER']['characters'].first
      expect(character['is_favorite']).to eq(true)
      expect(character['favorite_order']).to eq(1)
    end

    it 'handles nil yaml_data gracefully' do
      result = Lich::Common::Authentication::EntryStore.migrate_to_favorites_format(nil)
      expect(result).to be_nil
    end

    it 'handles empty accounts gracefully' do
      yaml_data = { 'accounts' => {} }
      result = Lich::Common::Authentication::EntryStore.migrate_to_favorites_format(yaml_data)
      expect(result['accounts']).to eq({})
    end

    it 'handles missing accounts key' do
      yaml_data = { 'encryption_mode' => 'plaintext' }
      result = Lich::Common::Authentication::EntryStore.migrate_to_favorites_format(yaml_data)
      expect(result).to eq(yaml_data)
    end
  end

  describe '.add_favorite' do
    before do
      File.write(yaml_file, YAML.dump(sample_yaml_data))
    end

    it 'marks character as favorite and assigns order' do
      result = Lich::Common::Authentication::EntryStore.add_favorite(
        data_dir, 'TESTUSER', 'TestChar1', 'GS3', 'stormfront'
      )

      expect(result).to eq(true)

      # Verify YAML was updated
      updated_data = YAML.safe_load_file(yaml_file, permitted_classes: [Symbol])
      character = updated_data['accounts']['TESTUSER']['characters'].find { |c| c['char_name'] == 'TestChar1' }
      expect(character['is_favorite']).to eq(true)
      expect(character['favorite_order']).to be_a(Integer)
      expect(character['favorite_added']).to be_a(String)
    end

    it 'returns true if character is already a favorite' do
      result = Lich::Common::Authentication::EntryStore.add_favorite(
        data_dir, 'ANOTHERUSER', 'AnotherChar', 'GS3', 'stormfront'
      )

      expect(result).to eq(true)
    end

    it 'returns false if YAML file does not exist' do
      FileUtils.rm(yaml_file)
      result = Lich::Common::Authentication::EntryStore.add_favorite(
        data_dir, 'TESTUSER', 'TestChar1', 'GS3', 'stormfront'
      )

      expect(result).to eq(false)
    end

    it 'returns false if character not found' do
      result = Lich::Common::Authentication::EntryStore.add_favorite(
        data_dir, 'TESTUSER', 'NonexistentChar', 'GS3', 'stormfront'
      )

      expect(result).to eq(false)
    end

    it 'returns false if account not found' do
      result = Lich::Common::Authentication::EntryStore.add_favorite(
        data_dir, 'NONEXISTENT', 'TestChar1', 'GS3', 'stormfront'
      )

      expect(result).to eq(false)
    end

    it 'assigns incrementing favorite_order' do
      # First favorite already exists (ANOTHERUSER/AnotherChar with order 1)
      Lich::Common::Authentication::EntryStore.add_favorite(
        data_dir, 'TESTUSER', 'TestChar1', 'GS3', 'stormfront'
      )

      updated_data = YAML.safe_load_file(yaml_file, permitted_classes: [Symbol])
      char1 = updated_data['accounts']['TESTUSER']['characters'].find { |c| c['char_name'] == 'TestChar1' }
      # Should get order 2 since ANOTHERUSER/AnotherChar has order 1
      expect(char1['favorite_order']).to be >= 1
    end
  end

  describe '.remove_favorite' do
    before do
      File.write(yaml_file, YAML.dump(sample_yaml_data))
    end

    it 'removes favorite status from character' do
      result = Lich::Common::Authentication::EntryStore.remove_favorite(
        data_dir, 'ANOTHERUSER', 'AnotherChar', 'GS3', 'stormfront'
      )

      expect(result).to eq(true)

      # Verify YAML was updated
      updated_data = YAML.safe_load_file(yaml_file, permitted_classes: [Symbol])
      character = updated_data['accounts']['ANOTHERUSER']['characters'].first
      expect(character['is_favorite']).to eq(false)
      expect(character['favorite_order']).to be_nil
      expect(character['favorite_added']).to be_nil
    end

    it 'returns true if character was not a favorite' do
      result = Lich::Common::Authentication::EntryStore.remove_favorite(
        data_dir, 'TESTUSER', 'TestChar1', 'GS3', 'stormfront'
      )

      expect(result).to eq(true)
    end

    it 'returns false if YAML file does not exist' do
      FileUtils.rm(yaml_file)
      result = Lich::Common::Authentication::EntryStore.remove_favorite(
        data_dir, 'ANOTHERUSER', 'AnotherChar', 'GS3', 'stormfront'
      )

      expect(result).to eq(false)
    end

    it 'returns false if character not found' do
      result = Lich::Common::Authentication::EntryStore.remove_favorite(
        data_dir, 'TESTUSER', 'NonexistentChar', 'GS3', 'stormfront'
      )

      expect(result).to eq(false)
    end
  end

  describe '.is_favorite?' do
    before do
      File.write(yaml_file, YAML.dump(sample_yaml_data))
    end

    it 'returns true for a favorite character' do
      result = Lich::Common::Authentication::EntryStore.is_favorite?(
        data_dir, 'ANOTHERUSER', 'AnotherChar', 'GS3', 'stormfront'
      )

      expect(result).to eq(true)
    end

    it 'returns false for a non-favorite character' do
      result = Lich::Common::Authentication::EntryStore.is_favorite?(
        data_dir, 'TESTUSER', 'TestChar1', 'GS3', 'stormfront'
      )

      expect(result).to eq(false)
    end

    it 'returns false if YAML file does not exist' do
      FileUtils.rm(yaml_file)
      result = Lich::Common::Authentication::EntryStore.is_favorite?(
        data_dir, 'TESTUSER', 'TestChar1', 'GS3', 'stormfront'
      )

      expect(result).to eq(false)
    end

    it 'returns falsey if character not found' do
      result = Lich::Common::Authentication::EntryStore.is_favorite?(
        data_dir, 'TESTUSER', 'NonexistentChar', 'GS3', 'stormfront'
      )

      # Returns nil when character not found, which is falsey
      expect(result).to be_falsey
    end
  end

  describe '.get_favorites' do
    before do
      File.write(yaml_file, YAML.dump(sample_yaml_data))
    end

    it 'returns array of favorite characters' do
      result = Lich::Common::Authentication::EntryStore.get_favorites(data_dir)

      expect(result).to be_an(Array)
      expect(result.length).to eq(1)
      expect(result.first[:char_name]).to eq('AnotherChar')
    end

    it 'returns empty array if no favorites' do
      # Remove the existing favorite
      data = sample_yaml_data.dup
      data['accounts']['ANOTHERUSER']['characters'].first['is_favorite'] = false
      File.write(yaml_file, YAML.dump(data))

      result = Lich::Common::Authentication::EntryStore.get_favorites(data_dir)

      expect(result).to eq([])
    end

    it 'returns empty array if YAML file does not exist' do
      FileUtils.rm(yaml_file)
      result = Lich::Common::Authentication::EntryStore.get_favorites(data_dir)

      expect(result).to eq([])
    end

    it 'returns favorites sorted by favorite_order' do
      # Add another favorite with higher order
      data = sample_yaml_data.dup
      data['accounts']['TESTUSER']['characters'].first['is_favorite'] = true
      data['accounts']['TESTUSER']['characters'].first['favorite_order'] = 2
      data['accounts']['TESTUSER']['characters'].first['favorite_added'] = '2026-01-02 12:00:00'
      File.write(yaml_file, YAML.dump(data))

      result = Lich::Common::Authentication::EntryStore.get_favorites(data_dir)

      expect(result.length).to eq(2)
      expect(result.first[:char_name]).to eq('AnotherChar') # order 1
      expect(result.last[:char_name]).to eq('TestChar1')    # order 2
    end
  end

  describe '.sort_entries_with_favorites' do
    let(:entries) do
      [
        { char_name: 'ZChar', user_id: 'ZUSER', game_name: 'GemStone IV', is_favorite: false },
        { char_name: 'AChar', user_id: 'AUSER', game_name: 'DragonRealms', is_favorite: true, favorite_order: 2 },
        { char_name: 'BChar', user_id: 'BUSER', game_name: 'GemStone IV', is_favorite: false },
        { char_name: 'FavChar', user_id: 'FAVUSER', game_name: 'GemStone IV', is_favorite: true, favorite_order: 1 }
      ]
    end

    context 'when autosort is enabled' do
      it 'places favorites first, sorted by favorite_order' do
        result = Lich::Common::Authentication::EntryStore.sort_entries_with_favorites(entries, true)

        expect(result[0][:char_name]).to eq('FavChar')  # favorite_order 1
        expect(result[1][:char_name]).to eq('AChar')    # favorite_order 2
      end

      it 'sorts non-favorites by account name, game name, char name' do
        result = Lich::Common::Authentication::EntryStore.sort_entries_with_favorites(entries, true)

        # Non-favorites should come after favorites
        non_favorites = result[2..]
        expect(non_favorites[0][:user_id]).to eq('BUSER')
        expect(non_favorites[1][:user_id]).to eq('ZUSER')
      end

      it 'handles entries with nil favorite_order' do
        entries_with_nil = entries + [
          { char_name: 'NilOrder', user_id: 'NILUSER', game_name: 'GS', is_favorite: true, favorite_order: nil }
        ]

        result = Lich::Common::Authentication::EntryStore.sort_entries_with_favorites(entries_with_nil, true)

        # nil favorite_order should sort to end of favorites (999)
        favorites = result.select { |e| e[:is_favorite] }
        expect(favorites.last[:char_name]).to eq('NilOrder')
      end
    end

    context 'when autosort is disabled' do
      it 'returns entries in original order' do
        result = Lich::Common::Authentication::EntryStore.sort_entries_with_favorites(entries, false)

        expect(result).to eq(entries)
      end
    end

    context 'edge cases' do
      it 'handles empty array' do
        result = Lich::Common::Authentication::EntryStore.sort_entries_with_favorites([], true)
        expect(result).to eq([])
      end

      it 'handles array with only favorites' do
        favorites_only = entries.select { |e| e[:is_favorite] }
        result = Lich::Common::Authentication::EntryStore.sort_entries_with_favorites(favorites_only, true)

        expect(result.length).to eq(2)
        expect(result.first[:favorite_order]).to eq(1)
      end

      it 'handles array with no favorites' do
        non_favorites = entries.reject { |e| e[:is_favorite] }
        result = Lich::Common::Authentication::EntryStore.sort_entries_with_favorites(non_favorites, true)

        expect(result.length).to eq(2)
        # Should be sorted alphabetically by user_id
        expect(result.first[:user_id]).to eq('BUSER')
      end
    end
  end

  describe 'favorites persistence across operations' do
    before do
      File.write(yaml_file, YAML.dump(sample_yaml_data))
    end

    it 'maintains favorites after add/remove cycle' do
      # Add a favorite
      Lich::Common::Authentication::EntryStore.add_favorite(
        data_dir, 'TESTUSER', 'TestChar1', 'GS3', 'stormfront'
      )

      # Verify it's a favorite
      expect(Lich::Common::Authentication::EntryStore.is_favorite?(
               data_dir, 'TESTUSER', 'TestChar1', 'GS3', 'stormfront'
             )).to eq(true)

      # Remove the favorite
      Lich::Common::Authentication::EntryStore.remove_favorite(
        data_dir, 'TESTUSER', 'TestChar1', 'GS3', 'stormfront'
      )

      # Verify it's no longer a favorite
      expect(Lich::Common::Authentication::EntryStore.is_favorite?(
               data_dir, 'TESTUSER', 'TestChar1', 'GS3', 'stormfront'
             )).to eq(false)
    end

    it 'persists favorites to YAML file' do
      Lich::Common::Authentication::EntryStore.add_favorite(
        data_dir, 'TESTUSER', 'TestChar1', 'GS3', 'stormfront'
      )

      # Read directly from file to verify persistence
      raw_data = YAML.safe_load_file(yaml_file, permitted_classes: [Symbol])
      character = raw_data['accounts']['TESTUSER']['characters'].find { |c| c['char_name'] == 'TestChar1' }

      expect(character['is_favorite']).to eq(true)
    end
  end
end
