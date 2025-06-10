require 'login_spec_helper'

RSpec.describe Lich::Common::GUI::AccountManager do
  let(:data_dir) { "/tmp/test_data" }
  let(:username) { "test_user" }
  let(:password) { "test_password" }

  before do
    # Setup test directory and files
    FileUtils.mkdir_p(data_dir)
  end

  after do
    # Clean up test directory
    FileUtils.rm_rf(data_dir)
  end

  describe ".add_or_update_account" do
    context "when account doesn't exist" do
      it "creates a new account" do
        # Test that a new account is created with correct structure
        expect(described_class.add_or_update_account(data_dir, username, password)).to be true

        # Verify YAML file structure
        yaml_file = File.join(data_dir, "entry.yml")
        expect(File.exist?(yaml_file)).to be true

        yaml_data = YAML.load_file(yaml_file)
        expect(yaml_data['accounts']).to have_key(username)
        expect(yaml_data['accounts'][username]['password']).to eq(password)
        expect(yaml_data['accounts'][username]['characters']).to eq([])
      end
    end

    context "when account exists" do
      before do
        # Create existing account
        described_class.add_or_update_account(data_dir, username, "old_password")
      end

      it "updates the account password" do
        # Test that the account password is updated
        expect(described_class.add_or_update_account(data_dir, username, password)).to be true

        # Verify password is updated
        yaml_file = File.join(data_dir, "entry.yml")
        yaml_data = YAML.load_file(yaml_file)
        expect(yaml_data['accounts'][username]['password']).to eq(password)
      end

      it "preserves existing characters" do
        # Add a character first
        yaml_file = File.join(data_dir, "entry.yml")
        yaml_data = YAML.load_file(yaml_file)
        yaml_data['accounts'][username]['characters'] = [{ 'char_name' => 'TestChar', 'game_code' => 'GS', 'game_name' => 'GemStone', 'frontend' => 'stormfront' }]
        File.write(yaml_file, YAML.dump(yaml_data))

        # Update password
        expect(described_class.add_or_update_account(data_dir, username, password)).to be true

        # Verify characters are preserved
        yaml_data = YAML.load_file(yaml_file)
        expect(yaml_data['accounts'][username]['characters'].size).to eq(1)
        expect(yaml_data['accounts'][username]['characters'][0]['char_name']).to eq('TestChar')
      end
    end

    context "when file operations fail" do
      it "handles YAML load errors" do
        # Create invalid YAML file
        yaml_file = File.join(data_dir, "entry.yml")
        File.write(yaml_file, "invalid: yaml: content: - ]")

        # Should handle error and create new structure
        expect(described_class.add_or_update_account(data_dir, username, password)).to be true

        # Verify new structure was created
        yaml_data = YAML.load_file(yaml_file)
        expect(yaml_data['accounts']).to have_key(username)
      end

      it "handles file write errors" do
        # Mock file write error - updated to use verified_file_operation
        allow(Lich::Common::GUI::Utilities).to receive(:verified_file_operation).and_return(false)

        # Should return false on write error
        expect(described_class.add_or_update_account(data_dir, username, password)).to be false
      end
    end
  end

  describe ".remove_account" do
    context "when account exists" do
      before do
        # Create existing account
        described_class.add_or_update_account(data_dir, username, "password")
      end

      it "removes the account" do
        # Test that the account is removed
        expect(described_class.remove_account(data_dir, username)).to be true

        # Verify account is removed
        yaml_file = File.join(data_dir, "entry.yml")
        yaml_data = YAML.load_file(yaml_file)
        expect(yaml_data['accounts']).not_to have_key(username)
      end
    end

    context "when account doesn't exist" do
      before do
        # Create YAML file without the account
        yaml_file = File.join(data_dir, "entry.yml")
        File.write(yaml_file, YAML.dump({ 'accounts' => {} }))
      end

      it "returns false" do
        # Test that false is returned when account doesn't exist
        expect(described_class.remove_account(data_dir, username)).to be false
      end
    end

    context "when file doesn't exist" do
      it "returns false" do
        # Test that false is returned when file doesn't exist
        expect(described_class.remove_account(data_dir, username)).to be false
      end
    end
  end

  describe ".change_password" do
    it "delegates to add_or_update_account" do
      # Test that change_password delegates to add_or_update_account
      expect(described_class).to receive(:add_or_update_account).with(data_dir, username, password)
      described_class.change_password(data_dir, username, password)
    end
  end

  describe ".add_character" do
    let(:character_data) do
      {
        char_name: "TestChar",
        game_code: "GS",
        game_name: "GemStone",
        frontend: "stormfront",
        custom_launch: nil,
        custom_launch_dir: nil
      }
    end

    before do
      # Create account
      described_class.add_or_update_account(data_dir, username, "password")
    end

    context "when account exists" do
      it "adds a character to the account" do
        # Test that the character is added
        expect(described_class.add_character(data_dir, username, character_data)).to be true

        # Verify character is added
        yaml_file = File.join(data_dir, "entry.yml")
        yaml_data = YAML.load_file(yaml_file)
        expect(yaml_data['accounts'][username]['characters'].size).to eq(1)
        expect(yaml_data['accounts'][username]['characters'][0]['char_name']).to eq(character_data[:char_name])
        expect(yaml_data['accounts'][username]['characters'][0]['game_code']).to eq(character_data[:game_code])
      end

      it "adds multiple characters to the account" do
        # Add first character
        described_class.add_character(data_dir, username, character_data)

        # Add second character
        second_character = character_data.merge(char_name: "SecondChar")
        expect(described_class.add_character(data_dir, username, second_character)).to be true

        # Verify both characters are present
        yaml_file = File.join(data_dir, "entry.yml")
        yaml_data = YAML.load_file(yaml_file)
        expect(yaml_data['accounts'][username]['characters'].size).to eq(2)
        expect(yaml_data['accounts'][username]['characters'][1]['char_name']).to eq("SecondChar")
      end
    end

    context "when account doesn't exist" do
      it "returns false" do
        # Test that false is returned when account doesn't exist
        expect(described_class.add_character(data_dir, "nonexistent", character_data)).to be false
      end
    end
  end

  describe ".remove_character" do
    let(:char_name) { "TestChar" }
    let(:game_code) { "GS" }

    before do
      # Create account with character
      described_class.add_or_update_account(data_dir, username, "password")
      yaml_file = File.join(data_dir, "entry.yml")
      yaml_data = YAML.load_file(yaml_file)
      yaml_data['accounts'][username]['characters'] = [
        {
          'char_name' => char_name,
          'game_code' => game_code,
          'game_name' => 'GemStone',
          'frontend'  => 'stormfront'
        }
      ]
      File.write(yaml_file, YAML.dump(yaml_data))
    end

    context "when character exists" do
      it "removes the character" do
        # Test that the character is removed
        expect(described_class.remove_character(data_dir, username, char_name, game_code)).to be true

        # Verify character is removed
        yaml_file = File.join(data_dir, "entry.yml")
        yaml_data = YAML.load_file(yaml_file)
        expect(yaml_data['accounts'][username]['characters'].size).to eq(0)
      end
    end

    context "when character doesn't exist" do
      it "returns false" do
        # Test that false is returned when character doesn't exist
        expect(described_class.remove_character(data_dir, username, "NonexistentChar", game_code)).to be false
      end
    end

    context "when account doesn't exist" do
      it "returns false" do
        # Test that false is returned when account doesn't exist
        expect(described_class.remove_character(data_dir, "nonexistent", char_name, game_code)).to be false
      end
    end
  end

  describe ".get_all_accounts" do
    context "when accounts exist" do
      before do
        # Create accounts with characters
        described_class.add_or_update_account(data_dir, "user1", "pass1")
        described_class.add_character(data_dir, "user1", {
          char_name: "Char1",
          game_code: "GS",
          game_name: "GemStone",
          frontend: "stormfront"
        })

        described_class.add_or_update_account(data_dir, "user2", "pass2")
        described_class.add_character(data_dir, "user2", {
          char_name: "Char2",
          game_code: "DR",
          game_name: "DragonRealms",
          frontend: "wizard"
        })
      end

      it "returns all accounts with their characters" do
        # Test that all accounts and characters are returned
        accounts = described_class.get_all_accounts(data_dir)

        expect(accounts.keys).to contain_exactly("user1", "user2")
        expect(accounts["user1"].size).to eq(1)
        expect(accounts["user1"][0][:char_name]).to eq("Char1")
        expect(accounts["user2"].size).to eq(1)
        expect(accounts["user2"][0][:char_name]).to eq("Char2")
      end
    end

    context "when no accounts exist" do
      before do
        # Create empty YAML file
        yaml_file = File.join(data_dir, "entry.yml")
        File.write(yaml_file, YAML.dump({ 'accounts' => {} }))
      end

      it "returns empty hash" do
        # Test that empty hash is returned when no accounts exist
        expect(described_class.get_all_accounts(data_dir)).to eq({})
      end
    end

    context "when file doesn't exist" do
      it "returns empty hash" do
        # Test that empty hash is returned when file doesn't exist
        expect(described_class.get_all_accounts(data_dir)).to eq({})
      end
    end
  end

  describe ".get_accounts" do
    context "when accounts exist" do
      before do
        # Create accounts
        described_class.add_or_update_account(data_dir, "user1", "pass1")
        described_class.add_or_update_account(data_dir, "user2", "pass2")
      end

      it "returns array of account usernames" do
        # Test that array of account usernames is returned
        accounts = described_class.get_accounts(data_dir)

        expect(accounts).to contain_exactly("user1", "user2")
      end
    end

    context "when no accounts exist" do
      before do
        # Create empty YAML file
        yaml_file = File.join(data_dir, "entry.yml")
        File.write(yaml_file, YAML.dump({ 'accounts' => {} }))
      end

      it "returns empty array" do
        # Test that empty array is returned when no accounts exist
        expect(described_class.get_accounts(data_dir)).to eq([])
      end
    end

    context "when file doesn't exist" do
      it "returns empty array" do
        # Test that empty array is returned when file doesn't exist
        expect(described_class.get_accounts(data_dir)).to eq([])
      end
    end
  end

  describe ".get_characters" do
    context "when account with characters exists" do
      before do
        # Create account with characters
        described_class.add_or_update_account(data_dir, username, "password")
        described_class.add_character(data_dir, username, {
          char_name: "Char1",
          game_code: "GS",
          game_name: "GemStone",
          frontend: "stormfront"
        })
        described_class.add_character(data_dir, username, {
          char_name: "Char2",
          game_code: "DR",
          game_name: "DragonRealms",
          frontend: "wizard"
        })
      end

      it "returns array of character data hashes" do
        # Test that array of character data hashes is returned
        characters = described_class.get_characters(data_dir, username)

        expect(characters.size).to eq(2)
        expect(characters[0][:char_name]).to eq("Char1")
        expect(characters[1][:char_name]).to eq("Char2")
      end
    end

    context "when account exists but has no characters" do
      before do
        # Create account without characters
        described_class.add_or_update_account(data_dir, username, "password")
      end

      it "returns empty array" do
        # Test that empty array is returned when account has no characters
        expect(described_class.get_characters(data_dir, username)).to eq([])
      end
    end

    context "when account doesn't exist" do
      before do
        # Create YAML file without the account
        yaml_file = File.join(data_dir, "entry.yml")
        File.write(yaml_file, YAML.dump({ 'accounts' => {} }))
      end

      it "returns empty array" do
        # Test that empty array is returned when account doesn't exist
        expect(described_class.get_characters(data_dir, username)).to eq([])
      end
    end

    context "when file doesn't exist" do
      it "returns empty array" do
        # Test that empty array is returned when file doesn't exist
        expect(described_class.get_characters(data_dir, username)).to eq([])
      end
    end
  end
end
