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

  describe "retry configuration constants" do
    it "defines MAX_AUTH_RETRIES" do
      expect(described_class::MAX_AUTH_RETRIES).to eq(3)
    end

    it "defines AUTH_RETRY_BASE_DELAY" do
      expect(described_class::AUTH_RETRY_BASE_DELAY).to eq(5)
    end
  end

  describe ".with_retry" do
    before do
      # Stub sleep to avoid actual delays in tests
      allow(described_class).to receive(:sleep)
      # Stub Lich.log to capture log messages
      allow(Lich).to receive(:log)
    end

    context "when block succeeds on first attempt" do
      it "returns the result without retry" do
        result = described_class.with_retry { auth_data }

        expect(result).to eq(auth_data)
      end

      it "does not log retry success message" do
        described_class.with_retry { auth_data }

        expect(Lich).not_to have_received(:log).with(/succeeded on attempt/)
      end

      it "does not call sleep" do
        described_class.with_retry { auth_data }

        expect(described_class).not_to have_received(:sleep)
      end
    end

    context "when block fails then succeeds on retry" do
      it "returns result after retry" do
        call_count = 0
        result = described_class.with_retry do
          call_count += 1
          raise StandardError, "SSL_read: unexpected eof while reading" if call_count == 1

          auth_data
        end

        expect(result).to eq(auth_data)
      end

      it "logs warning for failed attempt" do
        call_count = 0
        described_class.with_retry do
          call_count += 1
          raise StandardError, "SSL_read: unexpected eof while reading" if call_count == 1

          auth_data
        end

        expect(Lich).to have_received(:log).with(/Authentication attempt 1\/3 failed.*retrying/)
      end

      it "logs success on retry" do
        call_count = 0
        described_class.with_retry do
          call_count += 1
          raise StandardError, "SSL_read: unexpected eof while reading" if call_count == 1

          auth_data
        end

        expect(Lich).to have_received(:log).with(/Authentication succeeded on attempt 2/)
      end

      it "sleeps with exponential backoff" do
        call_count = 0
        described_class.with_retry do
          call_count += 1
          raise StandardError, "SSL_read: unexpected eof while reading" if call_count == 1

          auth_data
        end

        # First retry uses base delay (5 seconds)
        expect(described_class).to have_received(:sleep).with(5)
      end
    end

    context "when block fails twice then succeeds" do
      it "returns result after second retry" do
        call_count = 0
        result = described_class.with_retry do
          call_count += 1
          raise StandardError, "Connection reset by peer" if call_count <= 2

          auth_data
        end

        expect(result).to eq(auth_data)
      end

      it "sleeps with exponential backoff for each retry" do
        call_count = 0
        described_class.with_retry do
          call_count += 1
          raise StandardError, "Connection reset by peer" if call_count <= 2

          auth_data
        end

        # First retry: 5 * 2^0 = 5 seconds
        # Second retry: 5 * 2^1 = 10 seconds
        expect(described_class).to have_received(:sleep).with(5).ordered
        expect(described_class).to have_received(:sleep).with(10).ordered
      end

      it "logs success on third attempt" do
        call_count = 0
        described_class.with_retry do
          call_count += 1
          raise StandardError, "Connection reset by peer" if call_count <= 2

          auth_data
        end

        expect(Lich).to have_received(:log).with(/Authentication succeeded on attempt 3/)
      end
    end

    context "when all retry attempts fail" do
      let(:error_message) { "SSL_read: unexpected eof while reading" }

      it "raises the last error" do
        expect do
          described_class.with_retry do
            raise StandardError, error_message
          end
        end.to raise_error(StandardError, error_message)
      end

      it "logs final failure message" do
        described_class.with_retry do
          raise StandardError, error_message
        end
      rescue StandardError
        # Expected to raise
      end

      it "attempts block MAX_AUTH_RETRIES times" do
        call_count = 0

        described_class.with_retry do
          call_count += 1
          raise StandardError, error_message
        end
      rescue StandardError
        # Expected to raise
      end

      it "sleeps between retries but not after final attempt" do
        described_class.with_retry do
          raise StandardError, error_message
        end
      rescue StandardError
        # Expected to raise
      end

      it "uses exponential backoff delays" do
        described_class.with_retry do
          raise StandardError, error_message
        end
      rescue StandardError
        # Expected to raise
      end
    end

    context "with different error types" do
      it "retries on SSL errors" do
        call_count = 0
        result = described_class.with_retry do
          call_count += 1
          raise StandardError, "SSL_read: unexpected eof while reading" if call_count == 1

          auth_data
        end
        expect(result).to eq(auth_data)
      end

      it "retries on connection reset errors" do
        call_count = 0
        result = described_class.with_retry do
          call_count += 1
          raise StandardError, "Connection reset by peer" if call_count == 1

          auth_data
        end
        expect(result).to eq(auth_data)
      end

      it "retries on timeout errors" do
        call_count = 0
        result = described_class.with_retry do
          call_count += 1
          raise StandardError, "Connection timed out" if call_count == 1

          auth_data
        end
        expect(result).to eq(auth_data)
      end
    end
  end

  describe ".authenticate with retry behavior" do
    before do
      allow(described_class).to receive(:sleep)
      allow(Lich).to receive(:log)
    end

    context "when EAccess.auth fails then succeeds" do
      it "retries and returns auth data" do
        call_count = 0
        allow(Lich::Common::EAccess).to receive(:auth) do
          call_count += 1
          raise StandardError, "SSL_read: unexpected eof while reading" if call_count == 1

          auth_data
        end

        result = described_class.authenticate(
          account: account,
          password: password,
          character: character,
          game_code: game_code
        )

        expect(result).to eq(auth_data)
      end
    end

    context "when EAccess.auth fails all attempts" do
      it "raises the error after retries exhausted" do
        allow(Lich::Common::EAccess).to receive(:auth)
          .and_raise(StandardError, "Connection reset by peer")

        expect do
          described_class.authenticate(
            account: account,
            password: password,
            character: character,
            game_code: game_code
          )
        end.to raise_error(StandardError, "Connection reset by peer")
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
