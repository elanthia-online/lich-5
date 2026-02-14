# frozen_string_literal: true

require 'login_spec_helper'
require 'common/cli/cli_login'

RSpec.describe Lich::Common::CLI::CLILogin do
  let(:char_entry) do
    {
      username: 'test_account',
      char_name: 'TestChar',
      game_code: 'DR',
      frontend: 'stormfront',
      password: 'encrypted_password'
    }
  end

  let(:plaintext_password) { 'test_password' }

  let(:launch_data_hash) do
    {
      'key'          => 'test_key',
      'server'       => 'game.example.com',
      'port'         => '8080',
      'gamefile'     => 'STORM.EXE',
      'game'         => 'STORM',
      'fullgamename' => 'StormFront'
    }
  end

  describe 'retry configuration constants' do
    it 'defines MAX_AUTH_RETRIES' do
      expect(described_class::MAX_AUTH_RETRIES).to eq(3)
    end

    it 'defines AUTH_RETRY_BASE_DELAY' do
      expect(described_class::AUTH_RETRY_BASE_DELAY).to eq(5)
    end
  end

  describe '.authenticate_with_retry' do
    before do
      # Stub sleep to avoid actual delays in tests
      allow(described_class).to receive(:sleep)
      # Stub Lich.log to capture log messages
      allow(Lich).to receive(:log)
    end

    context 'when authentication succeeds on first attempt' do
      before do
        allow(Lich::Common::GUI::Authentication).to receive(:authenticate)
          .and_return(launch_data_hash)
      end

      it 'returns formatted launch data' do
        result = described_class.authenticate_with_retry(char_entry, plaintext_password)

        expect(result).to be_an(Array)
        expect(result).to include('KEY=test_key')
        expect(result).to include('SERVER=game.example.com')
      end

      it 'does not log retry success message' do
        described_class.authenticate_with_retry(char_entry, plaintext_password)

        expect(Lich).not_to have_received(:log).with(/succeeded on attempt/)
      end

      it 'does not call sleep' do
        described_class.authenticate_with_retry(char_entry, plaintext_password)

        expect(described_class).not_to have_received(:sleep)
      end
    end

    context 'when authentication fails then succeeds on retry' do
      before do
        call_count = 0
        allow(Lich::Common::GUI::Authentication).to receive(:authenticate) do
          call_count += 1
          if call_count == 1
            raise StandardError, 'SSL_read: unexpected eof while reading'
          else
            launch_data_hash
          end
        end
      end

      it 'returns launch data after retry' do
        result = described_class.authenticate_with_retry(char_entry, plaintext_password)

        expect(result).to be_an(Array)
        expect(result).to include('KEY=test_key')
      end

      it 'logs warning for failed attempt' do
        described_class.authenticate_with_retry(char_entry, plaintext_password)

        expect(Lich).to have_received(:log).with(/Authentication attempt 1\/3 failed.*retrying/)
      end

      it 'logs success on retry' do
        described_class.authenticate_with_retry(char_entry, plaintext_password)

        expect(Lich).to have_received(:log).with(/Authentication succeeded on attempt 2/)
      end

      it 'sleeps with exponential backoff' do
        described_class.authenticate_with_retry(char_entry, plaintext_password)

        # First retry uses base delay (5 seconds)
        expect(described_class).to have_received(:sleep).with(5)
      end
    end

    context 'when authentication fails on second attempt then succeeds' do
      before do
        call_count = 0
        allow(Lich::Common::GUI::Authentication).to receive(:authenticate) do
          call_count += 1
          if call_count <= 2
            raise StandardError, 'Connection reset by peer'
          else
            launch_data_hash
          end
        end
      end

      it 'returns launch data after second retry' do
        result = described_class.authenticate_with_retry(char_entry, plaintext_password)

        expect(result).to be_an(Array)
        expect(result).to include('KEY=test_key')
      end

      it 'sleeps with exponential backoff for each retry' do
        described_class.authenticate_with_retry(char_entry, plaintext_password)

        # First retry: 5 * 2^0 = 5 seconds
        # Second retry: 5 * 2^1 = 10 seconds
        expect(described_class).to have_received(:sleep).with(5).ordered
        expect(described_class).to have_received(:sleep).with(10).ordered
      end

      it 'logs success on third attempt' do
        described_class.authenticate_with_retry(char_entry, plaintext_password)

        expect(Lich).to have_received(:log).with(/Authentication succeeded on attempt 3/)
      end
    end

    context 'when all retry attempts fail' do
      let(:error_message) { 'SSL_read: unexpected eof while reading' }

      before do
        allow(Lich::Common::GUI::Authentication).to receive(:authenticate)
          .and_raise(StandardError, error_message)
      end

      it 'returns nil' do
        result = described_class.authenticate_with_retry(char_entry, plaintext_password)

        expect(result).to be_nil
      end

      it 'logs final failure message' do
        described_class.authenticate_with_retry(char_entry, plaintext_password)

        expect(Lich).to have_received(:log).with(/Authentication failed after 3 attempts.*#{error_message}/)
      end

      it 'attempts authentication MAX_AUTH_RETRIES times' do
        described_class.authenticate_with_retry(char_entry, plaintext_password)

        expect(Lich::Common::GUI::Authentication).to have_received(:authenticate).exactly(3).times
      end

      it 'sleeps between retries but not after final attempt' do
        described_class.authenticate_with_retry(char_entry, plaintext_password)

        # Should sleep twice (after attempts 1 and 2, not after attempt 3)
        expect(described_class).to have_received(:sleep).exactly(2).times
      end

      it 'uses exponential backoff delays' do
        described_class.authenticate_with_retry(char_entry, plaintext_password)

        expect(described_class).to have_received(:sleep).with(5).ordered   # 5 * 2^0
        expect(described_class).to have_received(:sleep).with(10).ordered  # 5 * 2^1
      end
    end

    context 'with different error types' do
      it 'retries on SSL errors' do
        call_count = 0
        allow(Lich::Common::GUI::Authentication).to receive(:authenticate) do
          call_count += 1
          raise StandardError, 'SSL_read: unexpected eof while reading' if call_count == 1

          launch_data_hash
        end

        result = described_class.authenticate_with_retry(char_entry, plaintext_password)
        expect(result).to be_an(Array)
      end

      it 'retries on connection reset errors' do
        call_count = 0
        allow(Lich::Common::GUI::Authentication).to receive(:authenticate) do
          call_count += 1
          raise StandardError, 'Connection reset by peer' if call_count == 1

          launch_data_hash
        end

        result = described_class.authenticate_with_retry(char_entry, plaintext_password)
        expect(result).to be_an(Array)
      end

      it 'retries on timeout errors' do
        call_count = 0
        allow(Lich::Common::GUI::Authentication).to receive(:authenticate) do
          call_count += 1
          raise StandardError, 'Connection timed out' if call_count == 1

          launch_data_hash
        end

        result = described_class.authenticate_with_retry(char_entry, plaintext_password)
        expect(result).to be_an(Array)
      end
    end
  end

  describe '.format_launch_data' do
    it 'formats launch data hash to array of KEY=value strings' do
      result = described_class.format_launch_data(launch_data_hash, char_entry)

      expect(result).to be_an(Array)
      expect(result).to include('KEY=test_key')
      expect(result).to include('SERVER=game.example.com')
      expect(result).to include('PORT=8080')
    end

    context 'with wizard frontend' do
      let(:wizard_entry) { char_entry.merge(frontend: 'wizard') }

      it 'modifies GAMEFILE, GAME, and FULLGAMENAME for wizard' do
        result = described_class.format_launch_data(launch_data_hash, wizard_entry)

        expect(result).to include('GAMEFILE=WIZARD.EXE')
        expect(result).to include('GAME=WIZ')
        expect(result).to include('FULLGAMENAME=Wizard Front End')
      end
    end

    context 'with avalon frontend' do
      let(:avalon_entry) { char_entry.merge(frontend: 'avalon') }

      it 'modifies GAME for avalon' do
        result = described_class.format_launch_data(launch_data_hash, avalon_entry)

        expect(result).to include('GAME=AVALON')
        expect(result).to include('GAMEFILE=STORM.EXE') # unchanged
      end
    end

    context 'with custom launch' do
      let(:custom_entry) do
        char_entry.merge(
          custom_launch: '/path/to/frontend',
          custom_launch_dir: '/path/to'
        )
      end

      it 'adds CUSTOMLAUNCH and CUSTOMLAUNCHDIR' do
        result = described_class.format_launch_data(launch_data_hash, custom_entry)

        expect(result).to include('CUSTOMLAUNCH=/path/to/frontend')
        expect(result).to include('CUSTOMLAUNCHDIR=/path/to')
      end
    end
  end
end
