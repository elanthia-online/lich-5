# frozen_string_literal: true

require 'rspec'
require 'fileutils'
require 'tmpdir'
require_relative 'login_spec_helper'
require_relative '../lib/common/gui/state'
require_relative '../lib/common/gui/yaml_state'
require_relative '../lib/common/gui/master_password_manager'
require_relative '../lib/common/gui/master_password_prompt'

# Alias for easier test access
State = Lich::Common::GUI::State

# Stub required dependencies at module/class level (no redefining)
module Lich
  def self.log(message)
    # Stub logger - no-op for tests
  end
end

RSpec.describe Lich::Common::GUI::YamlState do
  let(:temp_dir) { Dir.mktmpdir }
  let(:data_dir) { temp_dir }
  let(:yaml_file) { File.join(data_dir, 'entry.yaml') }
  let(:dat_file) { File.join(data_dir, 'entry.dat') }

  after { FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir) }

  describe '.migrate_from_legacy with enhanced mode' do
    before do
      # Create a dummy entry.dat file for each test
      File.write(dat_file, 'dummy')

      # Stub the external dependencies on actual classes
      allow(Lich::Common::GUI::MasterPasswordManager).to receive(:retrieve_master_password).and_return(nil)
      allow(Lich::Common::GUI::MasterPasswordManager).to receive(:create_validation_test).and_return('validation_test')
      allow(Lich::Common::GUI::MasterPasswordManager).to receive(:store_master_password).and_return(true)
      allow(Lich::Common::GUI::MasterPasswordPrompt).to receive(:show_create_master_password_dialog).and_return('TestPassword123')
      allow(State).to receive(:load_saved_entries).and_return([])
      allow(described_class).to receive(:save_entries).and_return(true)
      allow(described_class).to receive(:encrypt_password).and_return('encrypted')
    end

    context 'when user successfully creates master password' do
      it 'calls ensure_master_password_exists' do
        allow(described_class).to receive(:ensure_master_password_exists)
          .and_return('TestMasterPassword123')
        allow(State).to receive(:load_saved_entries).and_return([])
        allow(described_class).to receive(:save_entries).and_return(true)

        described_class.migrate_from_legacy(data_dir, encryption_mode: :enhanced)

        expect(described_class).to have_received(:ensure_master_password_exists).once
      end

      it 'returns true on success' do
        allow(described_class).to receive(:ensure_master_password_exists)
          .and_return('TestMasterPassword123')

        legacy_entries = [
          {
            user_id: 'testuser',
            password: 'plaintext_password',
            char_name: 'TestChar',
            game_code: 'GS3',
            game_name: 'GemStone III',
            frontend: 'Lich'
          }
        ]

        allow(State).to receive(:load_saved_entries).and_return(legacy_entries)
        allow(described_class).to receive(:encrypt_password).and_return('encrypted_password')
        allow(described_class).to receive(:save_entries).and_return(true)

        result = described_class.migrate_from_legacy(data_dir, encryption_mode: :enhanced)

        expect(result).to be true
      end

      it 'passes master_password to encrypt_password' do
        master_password = 'TestMasterPassword123'

        allow(described_class).to receive(:ensure_master_password_exists)
          .and_return(master_password)

        legacy_entries = [
          {
            user_id: 'testuser',
            password: 'plaintext_password',
            char_name: 'TestChar',
            game_code: 'GS3',
            game_name: 'GemStone III',
            frontend: 'Lich'
          }
        ]

        allow(State).to receive(:load_saved_entries).and_return(legacy_entries)
        allow(described_class).to receive(:save_entries).and_return(true)

        expect(described_class).to receive(:encrypt_password)
          .with(
            'plaintext_password',
            mode: :enhanced,
            account_name: 'testuser',
            master_password: master_password
          )
          .and_return('encrypted_password')

        described_class.migrate_from_legacy(data_dir, encryption_mode: :enhanced)
      end

      it 'adds encryption_mode to entries' do
        allow(described_class).to receive(:ensure_master_password_exists)
          .and_return('TestMasterPassword123')

        legacy_entries = [
          {
            user_id: 'testuser',
            password: 'plaintext_password',
            char_name: 'TestChar',
            game_code: 'GS3',
            game_name: 'GemStone III',
            frontend: 'Lich'
          }
        ]

        allow(State).to receive(:load_saved_entries).and_return(legacy_entries)
        allow(described_class).to receive(:encrypt_password).and_return('encrypted_password')

        expect(described_class).to receive(:save_entries) do |_, entries|
          expect(entries.first[:encryption_mode]).to eq(:enhanced)
          true
        end

        described_class.migrate_from_legacy(data_dir, encryption_mode: :enhanced)
      end

      it 'encrypts each password' do
        allow(described_class).to receive(:ensure_master_password_exists)
          .and_return('TestMasterPassword123')

        legacy_entries = [
          {
            user_id: 'user1',
            password: 'password1',
            char_name: 'Char1',
            game_code: 'GS3',
            game_name: 'GemStone III',
            frontend: 'Lich'
          },
          {
            user_id: 'user2',
            password: 'password2',
            char_name: 'Char2',
            game_code: 'GS3',
            game_name: 'GemStone III',
            frontend: 'Lich'
          }
        ]

        allow(State).to receive(:load_saved_entries).and_return(legacy_entries)
        allow(described_class).to receive(:save_entries).and_return(true)

        expect(described_class).to receive(:encrypt_password).twice.and_return('encrypted')

        described_class.migrate_from_legacy(data_dir, encryption_mode: :enhanced)
      end
    end

    context 'when master password creation is cancelled' do
      it 'returns false' do
        allow(described_class).to receive(:ensure_master_password_exists)
          .and_return(nil)

        result = described_class.migrate_from_legacy(data_dir, encryption_mode: :enhanced)

        expect(result).to be false
      end

      it 'does not load legacy entries' do
        allow(described_class).to receive(:ensure_master_password_exists)
          .and_return(nil)

        expect(State).not_to receive(:load_saved_entries)

        described_class.migrate_from_legacy(data_dir, encryption_mode: :enhanced)
      end
    end

    context 'with other encryption modes' do
      it 'does not call ensure_master_password_exists for plaintext mode' do
        allow(State).to receive(:load_saved_entries).and_return([])
        allow(described_class).to receive(:save_entries).and_return(true)

        expect(described_class).not_to receive(:ensure_master_password_exists)

        described_class.migrate_from_legacy(data_dir, encryption_mode: :plaintext)
      end

      it 'does not call ensure_master_password_exists for account_name mode' do
        allow(State).to receive(:load_saved_entries).and_return([])
        allow(described_class).to receive(:save_entries).and_return(true)

        expect(described_class).not_to receive(:ensure_master_password_exists)

        described_class.migrate_from_legacy(data_dir, encryption_mode: :account_name)
      end
    end
  end

  describe '.ensure_master_password_exists' do
    context 'when master password already in Keychain' do
      before do
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:retrieve_master_password)
          .and_return('ExistingPassword123')
      end

      it 'returns existing password without prompting' do
        existing_password = 'ExistingPassword123'

        result = described_class.send(:ensure_master_password_exists)

        expect(result).to eq(existing_password)
      end
    end

    context 'when master password not in Keychain' do
      before do
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:retrieve_master_password)
          .and_return(nil)
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:create_validation_test)
          .and_return('validation_test')
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:store_master_password)
          .and_return(true)
      end

      it 'shows dialog to create password' do
        allow(Lich::Common::GUI::MasterPasswordPrompt).to receive(:show_create_master_password_dialog)
          .and_return('NewPassword123')

        described_class.send(:ensure_master_password_exists)

        expect(Lich::Common::GUI::MasterPasswordPrompt).to have_received(:show_create_master_password_dialog).once
      end

      it 'returns nil if user cancels' do
        allow(Lich::Common::GUI::MasterPasswordPrompt).to receive(:show_create_master_password_dialog)
          .and_return(nil)

        result = described_class.send(:ensure_master_password_exists)

        expect(result).to be_nil
      end

      it 'creates validation test' do
        password = 'NewPassword123'

        allow(Lich::Common::GUI::MasterPasswordPrompt).to receive(:show_create_master_password_dialog)
          .and_return(password)

        expect(Lich::Common::GUI::MasterPasswordManager).to receive(:create_validation_test)
          .with(password)
          .and_return('validation_test')

        described_class.send(:ensure_master_password_exists)
      end

      it 'returns password and validation test on success' do
        password = 'NewPassword123'

        allow(Lich::Common::GUI::MasterPasswordPrompt).to receive(:show_create_master_password_dialog)
          .and_return(password)

        result = described_class.send(:ensure_master_password_exists)

        expect(result).to be_a(Hash)
        expect(result[:password]).to eq(password)
        expect(result[:validation_test]).to eq('validation_test')
      end
    end
  end

  describe '.migrate_to_encryption_format' do
    before do
      # Setup default stubs for all tests in this context
      allow(described_class).to receive(:encrypt_password).and_return('encrypted')
    end

    context 'with enhanced mode' do
      it 'adds encryption_mode field' do
        yaml_data = { 'accounts' => {} }

        result = described_class.migrate_to_encryption_format(yaml_data)

        expect(result['encryption_mode']).to eq('plaintext')
      end

      it 'adds master_password_validation_test field' do
        yaml_data = { 'accounts' => {} }

        result = described_class.migrate_to_encryption_format(yaml_data)

        expect(result).to have_key('master_password_validation_test')
        expect(result['master_password_validation_test']).to be_nil
      end

      it 'preserves existing encryption_mode' do
        yaml_data = {
          'accounts'        => {},
          'encryption_mode' => 'enhanced'
        }

        result = described_class.migrate_to_encryption_format(yaml_data)

        expect(result['encryption_mode']).to eq('enhanced')
      end
    end

    context 'with non-hash input' do
      it 'returns non-hash input unchanged' do
        result = described_class.migrate_to_encryption_format(nil)
        expect(result).to be_nil

        result = described_class.migrate_to_encryption_format([])
        expect(result).to eq([])

        result = described_class.migrate_to_encryption_format('string')
        expect(result).to eq('string')
      end
    end
  end

  # Integration tests skipped - require full infrastructure setup
  # describe 'integration: full master_password conversion flow' do
  #   Requires complete infrastructure including actual encryption, Keychain, etc.
  # end
end
