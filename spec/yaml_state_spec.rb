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
        yaml_file = File.join(data_dir, "entry.yml")
        yaml_data = {
          'accounts' => {
            'user1' => {
              'password'   => 'pass1',
              'characters' => [
                {
                  'char_name' => 'Char1',
                  'game_code' => 'GS',
                  'game_name' => 'GemStone',
                  'frontend'  => 'stormfront'
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
        expect(entries[0][:user_id]).to eq('user1')
        expect(entries[0][:password]).to eq('pass1')
      end

      it "sorts entries based on autosort_state" do
        # Add another character to test sorting
        yaml_file = File.join(data_dir, "entry.yml")
        yaml_data = YAML.load_file(yaml_file)
        yaml_data['accounts']['user1']['characters'] << {
          'char_name' => 'AChar', # Should come first alphabetically
          'game_code' => 'GS',
          'game_name' => 'GemStone',
          'frontend'  => 'stormfront'
        }
        File.write(yaml_file, YAML.dump(yaml_data))

        # Test with autosort false (sort by account and character)
        entries = described_class.load_saved_entries(data_dir, false)
        expect(entries[0][:char_name]).to eq('AChar')
        expect(entries[1][:char_name]).to eq('Char1')

        # Test with autosort true (sort by account, game, character)
        entries = described_class.load_saved_entries(data_dir, true)
        expect(entries[0][:char_name]).to eq('AChar')
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
                                                                                       user_id: 'user1',
                                                                                       password: 'pass1',
                                                                                       frontend: 'stormfront'
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
          user_id: 'user1',
          password: 'pass1',
          frontend: 'stormfront'
        }
      ]
    end

    context "when saving new entries" do
      it "creates YAML file with correct structure" do
        # Test that YAML file is created with correct structure
        expect(described_class.save_entries(data_dir, entry_data)).to be true

        # Verify YAML file structure
        yaml_file = File.join(data_dir, "entry.yml")
        expect(File.exist?(yaml_file)).to be true

        yaml_data = YAML.load_file(yaml_file)
        expect(yaml_data['accounts']).to have_key('user1')
        expect(yaml_data['accounts']['user1']['password']).to eq('pass1')
        expect(yaml_data['accounts']['user1']['characters'].size).to eq(1)
        expect(yaml_data['accounts']['user1']['characters'][0]['char_name']).to eq('Char1')
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
            user_id: 'user1',
            password: 'pass1',
            frontend: 'wizard'
          }
        ]

        expect(described_class.save_entries(data_dir, new_entry)).to be true

        # Verify backup file exists
        backup_file = File.join(data_dir, "entry.yml.bak")
        expect(File.exist?(backup_file)).to be true
      end

      it "updates YAML file with new entries" do
        # Test that YAML file is updated with new entries
        new_entry = entry_data + [
          {
            char_name: 'Char2',
            game_code: 'DR',
            game_name: 'DragonRealms',
            user_id: 'user1',
            password: 'pass1',
            frontend: 'wizard'
          }
        ]

        expect(described_class.save_entries(data_dir, new_entry)).to be true

        # Verify YAML file is updated
        yaml_file = File.join(data_dir, "entry.yml")
        yaml_data = YAML.load_file(yaml_file)
        expect(yaml_data['accounts']['user1']['characters'].size).to eq(2)
        expect(yaml_data['accounts']['user1']['characters'][1]['char_name']).to eq('Char2')
      end
    end

    context "when file operations fail" do
      it "handles file write errors" do
        # First reset any previous stubs to ensure clean state
        allow(File).to receive(:open).and_call_original

        # Use a custom matcher that only affects the specific yaml file
        yaml_file = File.join(data_dir, "entry.yml")
        allow(File).to receive(:open).with(yaml_file, 'w').and_raise(StandardError.new("Write error"))

        # Should return false on write error
        expect(described_class.save_entries(data_dir, entry_data)).to be false

        # Reset the stub to avoid affecting other tests
        allow(File).to receive(:open).and_call_original
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
                                                                                       user_id: 'user1',
                                                                                       password: 'pass1',
                                                                                       frontend: 'stormfront'
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
        yaml_file = File.join(data_dir, "entry.yml")
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

  describe ".validate_yaml_structure" do
    context "with valid YAML structure" do
      let(:valid_yaml) do
        {
          'accounts' => {
            'user1' => {
              'password'   => 'pass1',
              'characters' => [
                {
                  'char_name' => 'Char1',
                  'game_code' => 'GS',
                  'game_name' => 'GemStone',
                  'frontend'  => 'stormfront'
                }
              ]
            }
          }
        }
      end

      it "returns true" do
        # Test that true is returned for valid structure
        expect(described_class.validate_yaml_structure(valid_yaml)).to be true
      end
    end

    context "with invalid YAML structure" do
      it "returns false when not a hash" do
        # Test that false is returned when not a hash
        expect(described_class.validate_yaml_structure([])).to be false
      end

      it "returns false when missing accounts key" do
        # Test that false is returned when missing accounts key
        expect(described_class.validate_yaml_structure({ 'users' => {} })).to be false
      end

      it "returns false when accounts is not a hash" do
        # Test that false is returned when accounts is not a hash
        expect(described_class.validate_yaml_structure({ 'accounts' => [] })).to be false
      end

      it "returns false when account data is not a hash" do
        # Test that false is returned when account data is not a hash
        expect(described_class.validate_yaml_structure({ 'accounts' => { 'user1' => [] } })).to be false
      end

      it "returns false when missing password key" do
        # Test that false is returned when missing password key
        expect(described_class.validate_yaml_structure({
          'accounts' => {
            'user1' => {
              'characters' => []
            }
          }
        })).to be false
      end

      it "returns false when missing characters key" do
        # Test that false is returned when missing characters key
        expect(described_class.validate_yaml_structure({
          'accounts' => {
            'user1' => {
              'password' => 'pass1'
            }
          }
        })).to be false
      end

      it "returns false when characters is not an array" do
        # Test that false is returned when characters is not an array
        expect(described_class.validate_yaml_structure({
          'accounts' => {
            'user1' => {
              'password'   => 'pass1',
              'characters' => {}
            }
          }
        })).to be false
      end

      it "returns false when character data is missing required keys" do
        # Test that false is returned when character data is missing required keys
        expect(described_class.validate_yaml_structure({
          'accounts' => {
            'user1' => {
              'password'   => 'pass1',
              'characters' => [
                {
                  'char_name' => 'Char1',
                  'game_code' => 'GS'
                  # Missing game_name and frontend
                }
              ]
            }
          }
        })).to be false
      end
    end
  end
end
