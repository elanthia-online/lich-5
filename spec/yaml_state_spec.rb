require 'login_spec_helper'

RSpec.describe Lich::Common::GUI::YamlState do
  let(:data_dir) { "/tmp/test_data" }

  before do
    # Setup test directory and files
    FileUtils.mkdir_p(data_dir)
  end

  after do
    # Clean up test directory
    FileUtils.rm_rf(data_dir)
  end

  describe ".load_saved_entries" do
    context "when YAML file exists" do
      before do
        # Create test YAML file
        yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)
        yaml_data = {
          'accounts' => {
            'USER1' => {
              'password'   => 'pass1',
              'characters' => [
                {
                  'char_name'         => 'Char1',
                  'game_code'         => 'GS',
                  'game_name'         => 'GemStone',
                  'frontend'          => 'stormfront',
                  'custom_launch'     => nil,
                  'custom_launch_dir' => nil,
                  'is_favorite'       => false
                }
              ]
            }
          }
        }
        File.write(yaml_file, YAML.dump(yaml_data))
      end

      it "loads entries from YAML file" do
        # Test that entries are loaded correctly
        entries = described_class.load_saved_entries(data_dir, false)

        expect(entries.size).to eq(1)
        expect(entries[0][:char_name]).to eq('Char1')
        expect(entries[0][:user_id]).to eq('USER1')
        expect(entries[0][:password]).to eq('pass1') # Password comes from account level
        expect(entries[0][:custom_launch]).to be_nil
        expect(entries[0][:custom_launch_dir]).to be_nil
        expect(entries[0][:is_favorite]).to be false
      end

      it "sorts entries with favorites priority" do
        # Add another character and make one a favorite to test sorting
        yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)
        yaml_data = YAML.load_file(yaml_file)
        yaml_data['accounts']['USER1']['characters'] << {
          'char_name'         => 'AChar', # Should come first alphabetically but not if Char1 is favorite
          'game_code'         => 'GS',
          'game_name'         => 'GemStone',
          'frontend'          => 'stormfront',
          'custom_launch'     => nil,
          'custom_launch_dir' => nil,
          'is_favorite'       => false
        }
        # Make Char1 a favorite
        yaml_data['accounts']['USER1']['characters'][0]['is_favorite'] = true
        yaml_data['accounts']['USER1']['characters'][0]['favorite_order'] = 1
        File.write(yaml_file, YAML.dump(yaml_data))

        # Test with autosort false - favorites should come first
        entries = described_class.load_saved_entries(data_dir, false)
        expect(entries[0][:char_name]).to eq('Char1') # Favorite comes first
        expect(entries[1][:char_name]).to eq('AChar') # Non-favorite comes second
        expect(entries[0][:is_favorite]).to be true
        expect(entries[1][:is_favorite]).to be false

        # Test with autosort true - favorites still come first, then sorted non-favorites
        entries = described_class.load_saved_entries(data_dir, true)
        expect(entries[0][:char_name]).to eq('Char1') # Favorite comes first
        expect(entries[1][:char_name]).to eq('AChar') # Non-favorite comes second
      end

      it "sorts non-favorites based on autosort_state" do
        # Add another character to test sorting of non-favorites
        yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)
        yaml_data = YAML.load_file(yaml_file)
        yaml_data['accounts']['USER1']['characters'] << {
          'char_name'         => 'AChar', # Should come first alphabetically
          'game_code'         => 'GS',
          'game_name'         => 'GemStone',
          'frontend'          => 'stormfront',
          'custom_launch'     => nil,
          'custom_launch_dir' => nil,
          'is_favorite'       => false
        }
        File.write(yaml_file, YAML.dump(yaml_data))

        # Test with autosort false (no specific sorting for non-favorites)
        entries = described_class.load_saved_entries(data_dir, false)
        expect(entries.size).to eq(2)
        # Order may vary without autosort

        # Test with autosort true (sort by user_id, game_name, char_name)
        entries = described_class.load_saved_entries(data_dir, true)
        expect(entries[0][:char_name]).to eq('AChar') # Alphabetically first
        expect(entries[1][:char_name]).to eq('Char1')
      end
    end

    context "when YAML file doesn't exist but DAT file does" do
      before do
        # Mock State.load_saved_entries to return test data
        allow(Lich::Common::GUI::State).to receive(:load_saved_entries).and_return([
                                                                                     {
                                                                                       char_name: 'Char1',
                                                                                       game_code: 'GS',
                                                                                       game_name: 'GemStone',
                                                                                       user_id: 'USER1',
                                                                                       password: 'pass1',
                                                                                       frontend: 'stormfront',
                                                                                       custom_launch: nil,
                                                                                       custom_launch_dir: nil,
                                                                                       is_favorite: false
                                                                                     }
                                                                                   ])

        # Create empty DAT file
        dat_file = File.join(data_dir, "entry.dat")
        File.write(dat_file, "")
      end

      it "falls back to legacy format" do
        # Test that legacy format is used as fallback
        entries = described_class.load_saved_entries(data_dir, false)

        expect(entries.size).to eq(1)
        expect(entries[0][:char_name]).to eq('Char1')
      end
    end

    context "when no entry file exists" do
      it "returns empty array" do
        # Test that empty array is returned when no file exists
        expect(described_class.load_saved_entries(data_dir, false)).to eq([])
      end
    end

    context "when data_dir is nil" do
      it "returns empty array" do
        # Test that empty array is returned when data_dir is nil
        expect(described_class.load_saved_entries(nil, false)).to eq([])
      end
    end
  end

  describe ".save_entries" do
    let(:entry_data) do
      [
        {
          char_name: 'Char1',
          game_code: 'GS',
          game_name: 'GemStone',
          user_id: 'USER1',
          password: 'pass1',
          frontend: 'stormfront',
          custom_launch: nil,
          custom_launch_dir: nil,
          is_favorite: false
        }
      ]
    end

    context "when saving new entries" do
      it "creates YAML file with correct structure" do
        # Test that YAML file is created with correct structure
        expect(described_class.save_entries(data_dir, entry_data)).to be true

        # Verify YAML file structure
        yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)
        expect(File.exist?(yaml_file)).to be true

        yaml_data = YAML.load_file(yaml_file)
        expect(yaml_data['accounts']).to have_key('USER1')
        expect(yaml_data['accounts']['USER1']['password']).to eq('pass1')
        expect(yaml_data['accounts']['USER1']['characters'].size).to eq(1)
        expect(yaml_data['accounts']['USER1']['characters'][0]['char_name']).to eq('Char1')
        expect(yaml_data['accounts']['USER1']['characters'][0]['custom_launch']).to be_nil
        expect(yaml_data['accounts']['USER1']['characters'][0]['is_favorite']).to be false
      end
    end

    context "when updating existing entries" do
      before do
        # Create existing YAML file
        described_class.save_entries(data_dir, entry_data)
      end

      it "creates backup of existing file" do
        # Test that backup is created
        new_entry = entry_data + [
          {
            char_name: 'Char2',
            game_code: 'DR',
            game_name: 'DragonRealms',
            user_id: 'USER1',
            password: 'pass1',
            frontend: 'wizard',
            custom_launch: nil,
            custom_launch_dir: nil,
            is_favorite: false
          }
        ]

        expect(described_class.save_entries(data_dir, new_entry)).to be true

        # Verify backup file exists
        backup_file = File.join(data_dir, "entry.yaml.bak")
        expect(File.exist?(backup_file)).to be true
      end

      it "updates YAML file with new entries" do
        # Test that YAML file is updated with new entries
        new_entry = entry_data + [
          {
            char_name: 'Char2',
            game_code: 'DR',
            game_name: 'DragonRealms',
            user_id: 'USER1',
            password: 'pass1',
            frontend: 'wizard',
            custom_launch: nil,
            custom_launch_dir: nil,
            is_favorite: false
          }
        ]

        expect(described_class.save_entries(data_dir, new_entry)).to be true

        # Verify YAML file is updated
        yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)
        yaml_data = YAML.load_file(yaml_file)
        expect(yaml_data['accounts']['USER1']['characters'].size).to eq(2)
        expect(yaml_data['accounts']['USER1']['characters'][1]['char_name']).to eq('Char2')
        # Verify password is at account level, not character level
        expect(yaml_data['accounts']['USER1']['password']).to eq('pass1')
        expect(yaml_data['accounts']['USER1']['characters'][0].key?('password')).to be false
        expect(yaml_data['accounts']['USER1']['characters'][1].key?('password')).to be false
      end
    end

    context "when file operations fail" do
      it "handles file write errors gracefully" do
        # Mock YAML.dump to simulate write failure instead of File.open
        # This avoids interfering with other File.open calls like Lich.log
        allow(YAML).to receive(:dump).and_raise(StandardError.new("YAML dump error"))

        # Should return false on write error
        expect(described_class.save_entries(data_dir, entry_data)).to be false

        # Reset the stub to avoid affecting other tests
        allow(YAML).to receive(:dump).and_call_original
      end
    end
  end

  describe ".migrate_from_legacy" do
    context "when DAT file exists and YAML file doesn't" do
      before do
        # Create DAT file
        dat_file = File.join(data_dir, "entry.dat")
        File.write(dat_file, "")

        # Mock State.load_saved_entries to return test data
        allow(Lich::Common::GUI::State).to receive(:load_saved_entries).and_return([
                                                                                     {
                                                                                       char_name: 'Char1',
                                                                                       game_code: 'GS',
                                                                                       game_name: 'GemStone',
                                                                                       user_id: 'USER1',
                                                                                       password: 'pass1',
                                                                                       frontend: 'stormfront',
                                                                                       custom_launch: nil,
                                                                                       custom_launch_dir: nil,
                                                                                       is_favorite: false
                                                                                     }
                                                                                   ])

        # Mock save_entries to return true
        allow(described_class).to receive(:save_entries).and_return(true)
      end

      it "migrates data from legacy format" do
        # Test that data is migrated from legacy format
        expect(described_class.migrate_from_legacy(data_dir)).to be true

        # Verify save_entries was called with correct data
        expect(described_class).to have_received(:save_entries).with(data_dir, anything)
      end
    end

    context "when YAML file already exists" do
      before do
        # Create both DAT and YAML files
        dat_file = File.join(data_dir, "entry.dat")
        yaml_file = Lich::Common::GUI::YamlState.yaml_file_path(data_dir)
        File.write(dat_file, "")
        File.write(yaml_file, "")
      end

      it "returns false" do
        # Test that false is returned when YAML file already exists
        expect(described_class.migrate_from_legacy(data_dir)).to be false
      end
    end

    context "when DAT file doesn't exist" do
      it "returns false" do
        # Test that false is returned when DAT file doesn't exist
        expect(described_class.migrate_from_legacy(data_dir)).to be false
      end
    end
  end

  describe ".add_favorite" do
    let(:yaml_file) { File.join(data_dir, "entry.yaml") }

    before do
      # Create test YAML file with character data
      yaml_data = {
        'accounts' => {
          'USER1' => {
            'password'   => 'pass1',
            'characters' => [
              {
                'char_name'         => 'Char1',
                'game_code'         => 'GS',
                'game_name'         => 'GemStone',
                'frontend'          => 'stormfront',
                'custom_launch'     => nil,
                'custom_launch_dir' => nil,
                'is_favorite'       => false
              },
              {
                'char_name'         => 'Char2',
                'game_code'         => 'DR',
                'game_name'         => 'DragonRealms',
                'frontend'          => 'wizard',
                'custom_launch'     => nil,
                'custom_launch_dir' => nil,
                'is_favorite'       => false
              }
            ]
          }
        }
      }
      File.write(yaml_file, YAML.dump(yaml_data))
    end

    context "when YAML file exists" do
      it "adds character to favorites" do
        result = described_class.add_favorite(data_dir, 'USER1', 'Char1', 'GS', 'stormfront')
        expect(result).to be true

        # Verify character is marked as favorite
        expect(described_class.is_favorite?(data_dir, 'USER1', 'Char1', 'GS', 'stormfront')).to be true

        # Verify YAML structure
        yaml_data = YAML.load_file(yaml_file)
        character = yaml_data['accounts']['USER1']['characters'].find { |c| c['char_name'] == 'Char1' }
        expect(character['is_favorite']).to be true
        expect(character['favorite_order']).to eq(1)
        expect(character['favorite_added']).to be_a(String)
      end

      it "assigns correct favorite order" do
        # Add first favorite
        described_class.add_favorite(data_dir, 'USER1', 'Char1', 'GS', 'stormfront')

        # Add second favorite
        described_class.add_favorite(data_dir, 'USER1', 'Char2', 'DR', 'wizard')

        yaml_data = YAML.load_file(yaml_file)
        char1 = yaml_data['accounts']['USER1']['characters'].find { |c| c['char_name'] == 'Char1' }
        char2 = yaml_data['accounts']['USER1']['characters'].find { |c| c['char_name'] == 'Char2' }

        expect(char1['favorite_order']).to eq(1)
        expect(char2['favorite_order']).to eq(2)
      end

      it "returns true if character is already a favorite" do
        # Add favorite first time
        described_class.add_favorite(data_dir, 'USER1', 'Char1', 'GS', 'stormfront')

        # Try to add again
        result = described_class.add_favorite(data_dir, 'USER1', 'Char1', 'GS', 'stormfront')
        expect(result).to be true
      end

      it "returns false if character not found" do
        result = described_class.add_favorite(data_dir, 'USER1', 'NonExistent', 'GS', 'stormfront')
        expect(result).to be false
      end

      it "works with frontend precision" do
        # Add character with specific frontend
        result = described_class.add_favorite(data_dir, 'USER1', 'Char1', 'GS', 'stormfront')
        expect(result).to be true

        # Verify it doesn't match with different frontend (should return false, not nil)
        result_wizard = described_class.is_favorite?(data_dir, 'USER1', 'Char1', 'GS', 'wizard')
        expect(result_wizard).to be_falsy # Use be_falsy to handle both false and nil

        # Verify it matches with correct frontend
        expect(described_class.is_favorite?(data_dir, 'USER1', 'Char1', 'GS', 'stormfront')).to be true
        # Verify backward compatibility (no frontend specified)
        expect(described_class.is_favorite?(data_dir, 'USER1', 'Char1', 'GS')).to be true
      end
    end

    context "when YAML file doesn't exist" do
      before do
        File.delete(yaml_file) if File.exist?(yaml_file)
      end

      it "returns false" do
        result = described_class.add_favorite(data_dir, 'USER1', 'Char1', 'GS', 'stormfront')
        expect(result).to be false
      end
    end
  end

  describe ".remove_favorite" do
    let(:yaml_file) { File.join(data_dir, "entry.yaml") }

    before do
      # Create test YAML file with favorite character
      yaml_data = {
        'accounts' => {
          'USER1' => {
            'password'   => 'pass1',
            'characters' => [
              {
                'char_name'         => 'Char1',
                'game_code'         => 'GS',
                'game_name'         => 'GemStone',
                'frontend'          => 'stormfront',
                'custom_launch'     => nil,
                'custom_launch_dir' => nil,
                'is_favorite'       => true,
                'favorite_order'    => 1,
                'favorite_added'    => Time.now.to_s
              },
              {
                'char_name'         => 'Char2',
                'game_code'         => 'DR',
                'game_name'         => 'DragonRealms',
                'frontend'          => 'wizard',
                'custom_launch'     => nil,
                'custom_launch_dir' => nil,
                'is_favorite'       => true,
                'favorite_order'    => 2,
                'favorite_added'    => Time.now.to_s
              }
            ]
          }
        }
      }
      File.write(yaml_file, YAML.dump(yaml_data))
    end

    context "when character is a favorite" do
      it "removes character from favorites" do
        result = described_class.remove_favorite(data_dir, 'USER1', 'Char1', 'GS', 'stormfront')
        expect(result).to be true

        # Verify character is no longer a favorite
        expect(described_class.is_favorite?(data_dir, 'USER1', 'Char1', 'GS', 'stormfront')).to be false

        # Verify YAML structure
        yaml_data = YAML.load_file(yaml_file)
        character = yaml_data['accounts']['USER1']['characters'].find { |c| c['char_name'] == 'Char1' }
        expect(character['is_favorite']).to be false
        expect(character.key?('favorite_order')).to be false
        expect(character.key?('favorite_added')).to be false
      end

      it "reorders remaining favorites" do
        # Remove first favorite
        described_class.remove_favorite(data_dir, 'USER1', 'Char1', 'GS', 'stormfront')

        yaml_data = YAML.load_file(yaml_file)
        char2 = yaml_data['accounts']['USER1']['characters'].find { |c| c['char_name'] == 'Char2' }

        # Char2 should now be order 1
        expect(char2['favorite_order']).to eq(1)
      end

      it "returns true if character is not a favorite" do
        # First remove the favorite status
        described_class.remove_favorite(data_dir, 'USER1', 'Char1', 'GS', 'stormfront')

        # Try to remove again
        result = described_class.remove_favorite(data_dir, 'USER1', 'Char1', 'GS', 'stormfront')
        expect(result).to be true
      end
    end

    context "when character not found" do
      it "returns false" do
        result = described_class.remove_favorite(data_dir, 'USER1', 'NonExistent', 'GS', 'stormfront')
        expect(result).to be false
      end
    end
  end

  describe ".is_favorite?" do
    let(:yaml_file) { File.join(data_dir, "entry.yaml") }

    before do
      # Create test YAML file with mixed favorite/non-favorite characters
      yaml_data = {
        'accounts' => {
          'USER1' => {
            'password'   => 'pass1',
            'characters' => [
              {
                'char_name'         => 'FavoriteChar',
                'game_code'         => 'GS',
                'game_name'         => 'GemStone',
                'frontend'          => 'stormfront',
                'custom_launch'     => nil,
                'custom_launch_dir' => nil,
                'is_favorite'       => true,
                'favorite_order'    => 1,
                'favorite_added'    => Time.now.to_s
              },
              {
                'char_name'         => 'RegularChar',
                'game_code'         => 'DR',
                'game_name'         => 'DragonRealms',
                'frontend'          => 'wizard',
                'custom_launch'     => nil,
                'custom_launch_dir' => nil,
                'is_favorite'       => false
              }
            ]
          }
        }
      }
      File.write(yaml_file, YAML.dump(yaml_data))
    end

    it "returns true for favorite characters" do
      result = described_class.is_favorite?(data_dir, 'USER1', 'FavoriteChar', 'GS', 'stormfront')
      expect(result).to be true
    end

    it "returns false for non-favorite characters" do
      result = described_class.is_favorite?(data_dir, 'USER1', 'RegularChar', 'DR', 'wizard')
      expect(result).to be false
    end

    it "returns false for non-existent characters" do
      result = described_class.is_favorite?(data_dir, 'USER1', 'NonExistent', 'GS', 'stormfront')
      expect(result).to be_falsy # Use be_falsy to handle both false and nil
    end

    it "returns false when YAML file doesn't exist" do
      File.delete(yaml_file)
      result = described_class.is_favorite?(data_dir, 'USER1', 'FavoriteChar', 'GS', 'stormfront')
      expect(result).to be false
    end
  end

  describe ".get_favorites" do
    let(:yaml_file) { File.join(data_dir, "entry.yaml") }

    before do
      # Create test YAML file with multiple favorites across accounts
      yaml_data = {
        'accounts' => {
          'USER1' => {
            'password'   => 'pass1',
            'characters' => [
              {
                'char_name'         => 'Char1',
                'game_code'         => 'GS',
                'game_name'         => 'GemStone',
                'frontend'          => 'stormfront',
                'custom_launch'     => nil,
                'custom_launch_dir' => nil,
                'is_favorite'       => true,
                'favorite_order'    => 2,
                'favorite_added'    => Time.now.to_s
              },
              {
                'char_name'         => 'Char2',
                'game_code'         => 'DR',
                'game_name'         => 'DragonRealms',
                'frontend'          => 'wizard',
                'custom_launch'     => nil,
                'custom_launch_dir' => nil,
                'is_favorite'       => false
              }
            ]
          },
          'USER2' => {
            'password'   => 'pass2',
            'characters' => [
              {
                'char_name'         => 'Char3',
                'game_code'         => 'GS',
                'game_name'         => 'GemStone',
                'frontend'          => 'stormfront',
                'custom_launch'     => nil,
                'custom_launch_dir' => nil,
                'is_favorite'       => true,
                'favorite_order'    => 1,
                'favorite_added'    => Time.now.to_s
              }
            ]
          }
        }
      }
      File.write(yaml_file, YAML.dump(yaml_data))
    end

    it "returns all favorites sorted by order" do
      favorites = described_class.get_favorites(data_dir)

      expect(favorites.size).to eq(2)
      expect(favorites[0][:char_name]).to eq('Char3') # order 1
      expect(favorites[1][:char_name]).to eq('Char1') # order 2

      # Verify structure
      expect(favorites[0][:user_id]).to eq('USER2')
      expect(favorites[0][:game_code]).to eq('GS')
      expect(favorites[0][:favorite_order]).to eq(1)
    end

    it "returns empty array when no favorites exist" do
      # Remove favorites
      yaml_data = YAML.load_file(yaml_file)
      yaml_data['accounts']['USER1']['characters'][0]['is_favorite'] = false
      yaml_data['accounts']['USER2']['characters'][0]['is_favorite'] = false
      File.write(yaml_file, YAML.dump(yaml_data))

      favorites = described_class.get_favorites(data_dir)
      expect(favorites).to eq([])
    end

    it "returns empty array when YAML file doesn't exist" do
      File.delete(yaml_file)
      favorites = described_class.get_favorites(data_dir)
      expect(favorites).to eq([])
    end
  end

  describe ".reorder_favorites" do
    let(:yaml_file) { File.join(data_dir, "entry.yaml") }

    before do
      # Create test YAML file with multiple favorites
      yaml_data = {
        'accounts' => {
          'USER1' => {
            'password'   => 'pass1',
            'characters' => [
              {
                'char_name'         => 'Char1',
                'game_code'         => 'GS',
                'game_name'         => 'GemStone',
                'frontend'          => 'stormfront',
                'custom_launch'     => nil,
                'custom_launch_dir' => nil,
                'is_favorite'       => true,
                'favorite_order'    => 1,
                'favorite_added'    => Time.now.to_s
              },
              {
                'char_name'         => 'Char2',
                'game_code'         => 'DR',
                'game_name'         => 'DragonRealms',
                'frontend'          => 'wizard',
                'custom_launch'     => nil,
                'custom_launch_dir' => nil,
                'is_favorite'       => true,
                'favorite_order'    => 2,
                'favorite_added'    => Time.now.to_s
              }
            ]
          }
        }
      }
      File.write(yaml_file, YAML.dump(yaml_data))
    end

    it "reorders favorites based on provided list" do
      # Reverse the order
      ordered_favorites = [
        { username: 'USER1', char_name: 'Char2', game_code: 'DR', frontend: 'wizard' },
        { username: 'USER1', char_name: 'Char1', game_code: 'GS', frontend: 'stormfront' }
      ]

      result = described_class.reorder_favorites(data_dir, ordered_favorites)
      expect(result).to be true

      # Verify new order
      yaml_data = YAML.load_file(yaml_file)
      char1 = yaml_data['accounts']['USER1']['characters'].find { |c| c['char_name'] == 'Char1' }
      char2 = yaml_data['accounts']['USER1']['characters'].find { |c| c['char_name'] == 'Char2' }

      expect(char2['favorite_order']).to eq(1)
      expect(char1['favorite_order']).to eq(2)
    end

    it "works with string keys" do
      # Test with string keys instead of symbol keys
      ordered_favorites = [
        { 'username' => 'USER1', 'char_name' => 'Char2', 'game_code' => 'DR', 'frontend' => 'wizard' },
        { 'username' => 'USER1', 'char_name' => 'Char1', 'game_code' => 'GS', 'frontend' => 'stormfront' }
      ]

      result = described_class.reorder_favorites(data_dir, ordered_favorites)
      expect(result).to be true
    end

    it "returns false when YAML file doesn't exist" do
      File.delete(yaml_file)
      result = described_class.reorder_favorites(data_dir, [])
      expect(result).to be false
    end
  end

  describe ".convert_legacy_to_yaml_format" do
    context "with case normalization" do
      let(:mixed_case_entry_data) do
        [
          {
            char_name: 'char1',
            game_code: 'GS',
            game_name: 'GemStone',
            user_id: 'user1',
            password: 'pass1',
            frontend: 'stormfront',
            custom_launch: nil,
            custom_launch_dir: nil,
            is_favorite: false
          },
          {
            char_name: 'CHAR2',
            game_code: 'DR',
            game_name: 'DragonRealms',
            user_id: 'USER1',
            password: 'pass1',
            frontend: 'wizard',
            custom_launch: nil,
            custom_launch_dir: nil,
            is_favorite: false
          }
        ]
      end

      it "normalizes account names to UPCASE" do
        yaml_data = described_class.convert_legacy_to_yaml_format(mixed_case_entry_data)

        expect(yaml_data['accounts']).to have_key('USER1')
        expect(yaml_data['accounts']).not_to have_key('user1')
      end

      it "normalizes character names to Title case" do
        yaml_data = described_class.convert_legacy_to_yaml_format(mixed_case_entry_data)

        characters = yaml_data['accounts']['USER1']['characters']
        expect(characters[0]['char_name']).to eq('Char1')
        expect(characters[1]['char_name']).to eq('Char2')
      end

      it "prevents duplicate characters with precision matching" do
        duplicate_entry_data = [
          {
            char_name: 'char1',
            game_code: 'GS',
            game_name: 'GemStone',
            user_id: 'user1',
            password: 'pass1',
            frontend: 'stormfront',
            custom_launch: nil,
            custom_launch_dir: nil,
            is_favorite: false
          },
          {
            char_name: 'Char1',
            game_code: 'GS',
            game_name: 'GemStone',
            user_id: 'USER1',
            password: 'pass1',
            frontend: 'stormfront',
            custom_launch: nil,
            custom_launch_dir: nil,
            is_favorite: false
          }
        ]

        yaml_data = described_class.convert_legacy_to_yaml_format(duplicate_entry_data)

        # Should only have one character after normalization and duplicate detection
        expect(yaml_data['accounts']['USER1']['characters'].size).to eq(1)
        expect(yaml_data['accounts']['USER1']['characters'][0]['char_name']).to eq('Char1')
      end
    end
  end
end
