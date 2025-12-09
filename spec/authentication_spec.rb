require 'login_spec_helper'

RSpec.describe Lich::Common::GUI::Authentication do
  let(:account) { "test_user" }
  let(:password) { "test_password" }
  let(:character) { "TestChar" }
  let(:game_code) { "GS" }
  let(:auth_data) { { "key" => "value", "server" => "game.example.com" } }

  describe ".authenticate" do
    before do
      # Mock EAccess.auth to return test data
      allow(Lich::Common::EAccess).to receive(:auth).and_return(auth_data)
    end

    context "with character and game_code" do
      it "calls EAccess.auth with character and game_code" do
        # Test that EAccess.auth is called with correct parameters
        expect(Lich::Common::EAccess).to receive(:auth).with(
          account: account,
          password: password,
          character: character,
          game_code: game_code
        )

        result = described_class.authenticate(
          account: account,
          password: password,
          character: character,
          game_code: game_code
        )

        expect(result).to eq(auth_data)
      end
    end

    context "with legacy authentication" do
      it "calls EAccess.auth with legacy flag" do
        # Test that EAccess.auth is called with legacy flag
        expect(Lich::Common::EAccess).to receive(:auth).with(
          account: account,
          password: password,
          legacy: true
        )

        result = described_class.authenticate(
          account: account,
          password: password,
          legacy: true
        )

        expect(result).to eq(auth_data)
      end
    end

    context "with basic authentication" do
      it "calls EAccess.auth with account and password only" do
        # Test that EAccess.auth is called with account and password only
        expect(Lich::Common::EAccess).to receive(:auth).with(
          account: account,
          password: password
        )

        result = described_class.authenticate(
          account: account,
          password: password
        )

        expect(result).to eq(auth_data)
      end
    end
  end

  describe ".prepare_launch_data" do
    let(:auth_data) do
      {
        "key"          => "value",
        "server"       => "game.example.com",
        "port"         => "8080",
        "gamefile"     => "STORM.EXE",
        "game"         => "STORM",
        "fullgamename" => "StormFront"
      }
    end

    context "with different frontends" do
      it "formats launch data for wizard frontend" do
        # Test that launch data is formatted correctly for wizard frontend
        result = described_class.prepare_launch_data(auth_data, "wizard")

        expect(result).to include("KEY=value")
        expect(result).to include("SERVER=game.example.com")
        expect(result).to include("PORT=8080")
        expect(result).to include("GAMEFILE=WIZARD.EXE")
        expect(result).to include("GAME=WIZ")
        expect(result).to include("FULLGAMENAME=Wizard Front End")
      end

      it "formats launch data for avalon frontend" do
        # Test that launch data is formatted correctly for avalon frontend
        result = described_class.prepare_launch_data(auth_data, "avalon")

        expect(result).to include("KEY=value")
        expect(result).to include("SERVER=game.example.com")
        expect(result).to include("PORT=8080")
        expect(result).to include("GAMEFILE=STORM.EXE")
        expect(result).to include("GAME=AVALON")
        expect(result).to include("FULLGAMENAME=StormFront")
      end

      it "formats launch data for suks frontend" do
        # Test that launch data is formatted correctly for suks frontend
        result = described_class.prepare_launch_data(auth_data, "suks")

        expect(result).to include("KEY=value")
        expect(result).to include("SERVER=game.example.com")
        expect(result).to include("PORT=8080")
        expect(result).to include("GAMEFILE=WIZARD.EXE")
        expect(result).to include("GAME=SUKS")
        expect(result).to include("FULLGAMENAME=StormFront")
      end

      it "doesn't modify launch data for stormfront frontend" do
        # Test that launch data is not modified for stormfront frontend
        result = described_class.prepare_launch_data(auth_data, "stormfront")

        expect(result).to include("KEY=value")
        expect(result).to include("SERVER=game.example.com")
        expect(result).to include("PORT=8080")
        expect(result).to include("GAMEFILE=STORM.EXE")
        expect(result).to include("GAME=STORM")
        expect(result).to include("FULLGAMENAME=StormFront")
      end
    end

    context "with custom launch information" do
      it "adds custom launch information to launch data" do
        # Test that custom launch information is added to launch data
        result = described_class.prepare_launch_data(
          auth_data,
          "stormfront",
          "custom_command",
          "/path/to/custom"
        )

        expect(result).to include("CUSTOMLAUNCH=custom_command")
        expect(result).to include("CUSTOMLAUNCHDIR=/path/to/custom")
      end

      it "adds only custom launch command when directory is nil" do
        # Test that only custom launch command is added when directory is nil
        result = described_class.prepare_launch_data(
          auth_data,
          "stormfront",
          "custom_command"
        )

        expect(result).to include("CUSTOMLAUNCH=custom_command")
        expect(result).not_to include("CUSTOMLAUNCHDIR=")
      end
    end
  end

  describe ".create_entry_data" do
    let(:char_name) { "TestChar" }
    let(:game_code) { "GS" }
    let(:game_name) { "GemStone" }
    let(:user_id) { "test_user" }
    let(:password) { "test_password" }
    let(:frontend) { "stormfront" }

    context "with required parameters" do
      it "creates entry data hash with required fields" do
        # Test that entry data hash is created with required fields
        result = described_class.create_entry_data(
          char_name: char_name,
          game_code: game_code,
          game_name: game_name,
          user_id: user_id,
          password: password,
          frontend: frontend
        )

        expect(result[:char_name]).to eq(char_name)
        expect(result[:game_code]).to eq(game_code)
        expect(result[:game_name]).to eq(game_name)
        expect(result[:user_id]).to eq(user_id)
        expect(result[:password]).to eq(password)
        expect(result[:frontend]).to eq(frontend)
        expect(result[:custom_launch]).to be_nil
        expect(result[:custom_launch_dir]).to be_nil
      end
    end

    context "with optional parameters" do
      it "creates entry data hash with optional fields" do
        # Test that entry data hash is created with optional fields
        result = described_class.create_entry_data(
          char_name: char_name,
          game_code: game_code,
          game_name: game_name,
          user_id: user_id,
          password: password,
          frontend: frontend,
          custom_launch: "custom_command",
          custom_launch_dir: "/path/to/custom"
        )

        expect(result[:char_name]).to eq(char_name)
        expect(result[:game_code]).to eq(game_code)
        expect(result[:game_name]).to eq(game_name)
        expect(result[:user_id]).to eq(user_id)
        expect(result[:password]).to eq(password)
        expect(result[:frontend]).to eq(frontend)
        expect(result[:custom_launch]).to eq("custom_command")
        expect(result[:custom_launch_dir]).to eq("/path/to/custom")
      end
    end
  end
end
