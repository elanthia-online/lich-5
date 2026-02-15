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

    context 'with custom launch without directory' do
      let(:custom_entry) do
        char_entry.merge(
          custom_launch: '/path/to/frontend',
          custom_launch_dir: nil
        )
      end

      it 'adds only CUSTOMLAUNCH' do
        result = described_class.format_launch_data(launch_data_hash, custom_entry)

        expect(result).to include('CUSTOMLAUNCH=/path/to/frontend')
        expect(result).not_to include('CUSTOMLAUNCHDIR=')
      end
    end
  end

  describe '.decrypt_and_authenticate' do
    let(:entry_data) { { encryption_mode: 'plaintext' } }
    let(:plaintext_password) { 'test_password' }

    before do
      allow(Lich).to receive(:log)
      allow(Lich::Common::GUI::YamlState).to receive(:decrypt_password)
        .and_return(plaintext_password)
    end

    context 'when authentication succeeds' do
      before do
        allow(Lich::Common::GUI::Authentication).to receive(:authenticate)
          .and_return(launch_data_hash)
      end

      it 'returns formatted launch data' do
        result = described_class.decrypt_and_authenticate(char_entry, entry_data)

        expect(result).to be_an(Array)
        expect(result).to include('KEY=test_key')
        expect(result).to include('SERVER=game.example.com')
      end

      it 'calls Authentication.authenticate with correct parameters' do
        expect(Lich::Common::GUI::Authentication).to receive(:authenticate).with(
          account: 'test_account',
          password: plaintext_password,
          character: 'TestChar',
          game_code: 'DR'
        )

        described_class.decrypt_and_authenticate(char_entry, entry_data)
      end
    end

    context 'when authentication fails' do
      before do
        allow(Lich::Common::GUI::Authentication).to receive(:authenticate)
          .and_raise(StandardError, 'Connection reset by peer')
      end

      it 'returns nil' do
        result = described_class.decrypt_and_authenticate(char_entry, entry_data)

        expect(result).to be_nil
      end

      it 'logs the authentication failure' do
        described_class.decrypt_and_authenticate(char_entry, entry_data)

        expect(Lich).to have_received(:log).with(/Authentication failed: Connection reset by peer/)
      end
    end

    context 'when password decryption fails' do
      before do
        allow(Lich::Common::GUI::YamlState).to receive(:decrypt_password)
          .and_raise(StandardError, 'Decryption error')
      end

      it 'returns nil' do
        result = described_class.decrypt_and_authenticate(char_entry, entry_data)

        expect(result).to be_nil
      end

      it 'logs the decryption failure' do
        described_class.decrypt_and_authenticate(char_entry, entry_data)

        expect(Lich).to have_received(:log).with(/Failed to decrypt password: Decryption error/)
      end
    end

    context 'when decrypted password is nil' do
      before do
        allow(Lich::Common::GUI::YamlState).to receive(:decrypt_password)
          .and_return(nil)
      end

      it 'returns nil' do
        result = described_class.decrypt_and_authenticate(char_entry, entry_data)

        expect(result).to be_nil
      end

      it 'logs the missing password error' do
        described_class.decrypt_and_authenticate(char_entry, entry_data)

        expect(Lich).to have_received(:log).with(/No password available for character/)
      end
    end
  end
end
