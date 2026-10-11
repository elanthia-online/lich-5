# frozen_string_literal: true

require 'rspec'
require 'tmpdir'
require 'yaml'
require 'fileutils'

require_relative '../../../login_spec_helper'
require_relative '../../../../lib/common/authentication/account_characters'

# Runs against real entry.yaml files and the real AccountManager; only the game
# server call (Authentication.authenticate) is stubbed.
RSpec.describe Lich::Common::Authentication::AccountCharacters do
  let(:data_dir) { Dir.mktmpdir }
  let(:yaml_file) { File.join(data_dir, 'entry.yaml') }
  let(:error_class) { described_class::Error }

  after { FileUtils.rm_rf(data_dir) }

  def write_entries(accounts, encryption_mode = 'plaintext')
    File.write(yaml_file, { 'encryption_mode' => encryption_mode, 'accounts' => accounts }.to_yaml)
  end

  def stored_characters(account)
    YAML.safe_load_file(yaml_file, permitted_classes: [Symbol]).dig('accounts', account, 'characters')
  end

  def character(name, game_code, frontend, extra = {})
    { 'char_name' => name, 'game_code' => game_code, 'game_name' => 'DragonRealms', 'frontend' => frontend }.merge(extra)
  end

  describe '.stored_password' do
    it 'raises :account_not_found when entry.yaml does not exist' do
      expect { described_class.stored_password(data_dir, 'DOUG') }
        .to raise_error(error_class) { |e| expect(e.reason).to eq(:account_not_found) }
    end

    it 'raises :account_not_found for an unknown account' do
      write_entries('OTHER' => { 'password' => 'secret', 'characters' => [] })

      expect { described_class.stored_password(data_dir, 'DOUG') }
        .to raise_error(error_class) { |e| expect(e.reason).to eq(:account_not_found) }
    end

    it 'looks the account up upcased, as it is stored' do
      write_entries('DOUG' => { 'password' => 'secret', 'characters' => [] })

      expect(described_class.stored_password(data_dir, 'doug')).to eq('secret')
    end

    it 'raises :decrypt_failed instead of returning nil when no password is saved' do
      write_entries('DOUG' => { 'characters' => [] })

      expect { described_class.stored_password(data_dir, 'DOUG') }
        .to raise_error(error_class) { |e| expect(e.reason).to eq(:decrypt_failed) }
    end

    it 'raises :decrypt_failed when the stored password cannot be decrypted' do
      write_entries({ 'DOUG' => { 'password' => 'not-base64-ciphertext!', 'characters' => [] } }, 'standard')

      expect { described_class.stored_password(data_dir, 'DOUG') }
        .to raise_error(error_class) { |e| expect(e.reason).to eq(:decrypt_failed) }
    end
  end

  describe '.default_frontend' do
    it "uses the frontend most of the account's characters use" do
      write_entries('DOUG' => { 'password' => 'p', 'characters' => [
                      character('Alpha', 'DR', 'wizard'),
                      character('Beta', 'DR', 'wizard'),
                      character('Gamma', 'DR', 'genie')
                    ] })

      expect(described_class.default_frontend(data_dir, 'DOUG')).to eq('wizard')
    end

    it "does not take another account's preference" do
      write_entries(
        'DOUG'  => { 'password' => 'p', 'characters' => [] },
        'OTHER' => { 'password' => 'p', 'characters' => [character('Alpha', 'DR', 'genie')] }
      )

      expect(described_class.default_frontend(data_dir, 'DOUG')).to eq('stormfront')
    end

    it 'falls back to stormfront when the account has no characters key at all' do
      write_entries('DOUG' => { 'password' => 'p' })

      expect(described_class.default_frontend(data_dir, 'DOUG')).to eq('stormfront')
    end

    it 'falls back to stormfront when entry.yaml does not exist' do
      expect(described_class.default_frontend(data_dir, 'DOUG')).to eq('stormfront')
    end
  end

  describe '.fetch_characters' do
    it 'asks the server for the legacy character list' do
      rows = [{ char_name: 'Alpha', game_code: 'DR', game_name: 'DragonRealms' }]
      expect(Lich::Common::Authentication).to receive(:authenticate)
        .with(account: 'DOUG', password: 'secret', legacy: true).and_return(rows)

      expect(described_class.fetch_characters('DOUG', 'secret')).to eq(rows)
    end

    [nil, [], 'error: something'].each do |response|
      it "raises :no_characters when the server returns #{response.inspect}" do
        allow(Lich::Common::Authentication).to receive(:authenticate).and_return(response)

        expect { described_class.fetch_characters('DOUG', 'secret') }
          .to raise_error(error_class) { |e| expect(e.reason).to eq(:no_characters) }
      end
    end

    it 'lets authentication failures through unchanged' do
      allow(Lich::Common::Authentication).to receive(:authenticate).and_raise(Lich::Common::Authentication::FatalAuthError, 'Error(PASSWORD)')

      expect { described_class.fetch_characters('DOUG', 'secret') }
        .to raise_error(Lich::Common::Authentication::FatalAuthError, 'Error(PASSWORD)')
    end
  end

  describe '.store_new_characters' do
    let(:server_rows) do
      [
        { char_name: 'alpha', game_code: 'DR', game_name: 'DragonRealms' },
        { char_name: 'Newbie', game_code: 'DR', game_name: 'DragonRealms' }
      ]
    end

    it 'appends only unknown characters and leaves stored records exactly as they were' do
      stored = character('Alpha', 'DR', 'genie', 'favorite' => true, 'custom_launch' => 'warlock')
      write_entries('DOUG' => { 'password' => 'secret', 'characters' => [stored] })

      result = described_class.store_new_characters(data_dir, 'DOUG', 'secret', server_rows, 'wizard')

      expect(result).to eq(found: 2, added: 1)
      characters = stored_characters('DOUG')
      expect(characters.length).to eq(2)
      expect(characters.find { |c| c['char_name'] == 'Alpha' }).to include(stored)
      expect(characters.find { |c| c['char_name'] == 'Newbie' }).to include('game_code' => 'DR', 'frontend' => 'wizard')
    end

    it 'stores new characters with stormfront when no frontend is given' do
      write_entries('DOUG' => { 'password' => 'secret', 'characters' => [] })

      described_class.store_new_characters(data_dir, 'DOUG', 'secret', server_rows, nil)

      expect(stored_characters('DOUG').map { |c| c['frontend'] }.uniq).to eq(['stormfront'])
    end

    it 'adds characters to an account that has no characters key yet' do
      write_entries('DOUG' => { 'password' => 'secret' })

      result = described_class.store_new_characters(data_dir, 'DOUG', 'secret', server_rows, 'wizard')

      expect(result).to eq(found: 2, added: 2)
      expect(stored_characters('DOUG').map { |c| c['char_name'] }).to contain_exactly('Alpha', 'Newbie')
    end

    it 'treats the same name in another game as a new character' do
      write_entries('DOUG' => { 'password' => 'secret', 'characters' => [character('Newbie', 'GS3', 'wizard')] })

      result = described_class.store_new_characters(data_dir, 'DOUG', 'secret', server_rows, 'wizard')

      expect(result).to eq(found: 2, added: 2)
    end

    it 'does not rewrite entry.yaml when nothing is new' do
      write_entries('DOUG' => { 'password' => 'secret', 'characters' => [
                      character('Alpha', 'DR', 'genie'), character('Newbie', 'DR', 'genie')
                    ] })
      before = File.read(yaml_file)

      result = described_class.store_new_characters(data_dir, 'DOUG', 'secret', server_rows, 'wizard')

      expect(result).to eq(found: 2, added: 0)
      expect(File.read(yaml_file)).to eq(before)
    end

    it 'raises :no_characters when no row is a usable character' do
      write_entries('DOUG' => { 'password' => 'secret', 'characters' => [] })

      expect { described_class.store_new_characters(data_dir, 'DOUG', 'secret', [{ char_name: 'Alpha' }], 'wizard') }
        .to raise_error(error_class) { |e| expect(e.reason).to eq(:no_characters) }
    end

    it 'raises :save_failed when entry.yaml cannot be written' do
      write_entries('DOUG' => { 'password' => 'secret', 'characters' => [] })
      allow(Lich::Common::GUI::AccountManager).to receive(:add_or_update_account).and_return(false)

      expect { described_class.store_new_characters(data_dir, 'DOUG', 'secret', server_rows, 'wizard') }
        .to raise_error(error_class) { |e| expect(e.reason).to eq(:save_failed) }
    end
  end
end
