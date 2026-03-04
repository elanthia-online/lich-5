# frozen_string_literal: true

require 'rspec'
require 'fileutils'
require 'tmpdir'
require_relative '../../../login_spec_helper'
require_relative '../../../../lib/common/gui/state'
require_relative '../../../../lib/common/authentication/entry_store'
require_relative '../../../../lib/common/gui/master_password_manager'
require_relative '../../../../lib/common/gui/master_password_prompt'

# Alias for easier test access
State = Lich::Common::GUI::State

# Stub required dependencies at module/class level (no redefining)
module Lich
  def self.log(message)
    # Stub logger - no-op for tests
  end
end

RSpec.describe Lich::Common::Authentication::EntryStore do
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

  # ============================================================================
  # Round-trip Tests - High-risk areas for regression detection
  # ============================================================================

  describe 'round-trip: save_entries / load_saved_entries' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:yaml_file) { File.join(temp_dir, 'entry.yaml') }

    after { FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir) }

    context 'with plaintext mode' do
      let(:entries) do
        [
          {
            user_id: 'TESTUSER',
            password: 'testpassword123',
            char_name: 'Testchar',
            game_code: 'GS3',
            game_name: 'GemStone IV',
            frontend: 'stormfront',
            custom_launch: nil,
            custom_launch_dir: nil,
            is_favorite: false,
            favorite_order: nil,
            encryption_mode: :plaintext
          }
        ]
      end

      it 'preserves entry data through save/load cycle' do
        # Save entries
        result = described_class.save_entries(temp_dir, entries)
        expect(result).to be true
        expect(File.exist?(yaml_file)).to be true

        # Load entries back
        loaded = described_class.load_saved_entries(temp_dir, false)

        expect(loaded.length).to eq(1)
        expect(loaded.first[:user_id]).to eq('TESTUSER')
        expect(loaded.first[:password]).to eq('testpassword123')
        expect(loaded.first[:char_name]).to eq('Testchar')
        expect(loaded.first[:game_code]).to eq('GS3')
        expect(loaded.first[:frontend]).to eq('stormfront')
      end

      it 'preserves multiple entries with same account' do
        multi_entries = [
          {
            user_id: 'TESTUSER',
            password: 'testpassword123',
            char_name: 'Char1',
            game_code: 'GS3',
            game_name: 'GemStone IV',
            frontend: 'stormfront',
            encryption_mode: :plaintext
          },
          {
            user_id: 'TESTUSER',
            password: 'testpassword123',
            char_name: 'Char2',
            game_code: 'GS3',
            game_name: 'GemStone IV',
            frontend: 'wizard',
            encryption_mode: :plaintext
          }
        ]

        described_class.save_entries(temp_dir, multi_entries)
        loaded = described_class.load_saved_entries(temp_dir, false)

        expect(loaded.length).to eq(2)
        char_names = loaded.map { |e| e[:char_name] }
        expect(char_names).to contain_exactly('Char1', 'Char2')
      end

      it 'preserves favorite metadata' do
        favorite_entries = [
          {
            user_id: 'TESTUSER',
            password: 'testpassword123',
            char_name: 'Favorite',
            game_code: 'GS3',
            game_name: 'GemStone IV',
            frontend: 'stormfront',
            is_favorite: true,
            favorite_order: 1,
            encryption_mode: :plaintext
          }
        ]

        described_class.save_entries(temp_dir, favorite_entries)
        loaded = described_class.load_saved_entries(temp_dir, false)

        expect(loaded.first[:is_favorite]).to be true
        expect(loaded.first[:favorite_order]).to eq(1)
      end
    end

    context 'with standard encryption mode' do
      let(:entries) do
        [
          {
            user_id: 'ENCUSER',
            password: 'secretpassword',
            char_name: 'Encchar',
            game_code: 'DR',
            game_name: 'DragonRealms',
            frontend: 'wizard',
            encryption_mode: :standard
          }
        ]
      end

      before do
        # Pre-create an existing YAML with standard encryption mode
        # Note: PasswordCipher uses :standard mode internally
        yaml_data = {
          'encryption_mode'                 => 'standard',
          'master_password_validation_test' => nil,
          'accounts'                        => {
            'ENCUSER' => {
              'password'   => Lich::Common::GUI::PasswordCipher.encrypt(
                'secretpassword',
                mode: :standard,
                account_name: 'ENCUSER'
              ),
              'characters' => [
                {
                  'char_name' => 'Encchar',
                  'game_code' => 'DR',
                  'game_name' => 'DragonRealms',
                  'frontend'  => 'wizard'
                }
              ]
            }
          }
        }
        File.write(yaml_file, YAML.dump(yaml_data))
      end

      it 'decrypts passwords on load' do
        loaded = described_class.load_saved_entries(temp_dir, false)

        expect(loaded.length).to eq(1)
        expect(loaded.first[:password]).to eq('secretpassword')
      end
    end
  end

  describe 'round-trip: encrypt_password / decrypt_password' do
    context 'with plaintext mode' do
      it 'returns password unchanged for both encrypt and decrypt' do
        password = 'myplaintextpassword'

        encrypted = described_class.encrypt_password(password, mode: :plaintext)
        expect(encrypted).to eq(password)

        decrypted = described_class.decrypt_password(password, mode: :plaintext)
        expect(decrypted).to eq(password)
      end
    end

    context 'with standard mode (account-based encryption)' do
      # Note: PasswordCipher uses :standard mode internally for account-based encryption
      let(:password) { 'supersecretpassword123' }
      let(:account_name) { 'TESTACCOUNT' }

      it 'encrypts and decrypts password correctly' do
        encrypted = described_class.encrypt_password(
          password,
          mode: :standard,
          account_name: account_name
        )

        # Encrypted should be different from original
        expect(encrypted).not_to eq(password)

        # Decrypt should return original
        decrypted = described_class.decrypt_password(
          encrypted,
          mode: :standard,
          account_name: account_name
        )
        expect(decrypted).to eq(password)
      end

      it 'encrypts to different output with different account' do
        encrypted1 = described_class.encrypt_password(
          password,
          mode: :standard,
          account_name: 'ACCOUNT1'
        )
        encrypted2 = described_class.encrypt_password(
          password,
          mode: :standard,
          account_name: 'ACCOUNT2'
        )

        # Different accounts should produce different encrypted outputs
        # (due to different derived keys)
        expect(encrypted1).not_to eq(encrypted2)
      end

      it 'handles special characters in password' do
        special_password = 'p@$$w0rd!#%^&*(){}[]|\\:;"\'<>,.?/'

        encrypted = described_class.encrypt_password(
          special_password,
          mode: :standard,
          account_name: account_name
        )
        decrypted = described_class.decrypt_password(
          encrypted,
          mode: :standard,
          account_name: account_name
        )

        expect(decrypted).to eq(special_password)
      end

      it 'handles unicode characters in password' do
        unicode_password = 'pässwörd123日本語'

        encrypted = described_class.encrypt_password(
          unicode_password,
          mode: :standard,
          account_name: account_name
        )
        decrypted = described_class.decrypt_password(
          encrypted,
          mode: :standard,
          account_name: account_name
        )

        expect(decrypted).to eq(unicode_password)
      end
    end

    context 'with enhanced mode' do
      let(:password) { 'enhancedsecretpassword' }
      let(:master_password) { 'MyMasterPassword123!' }

      before do
        # Stub MasterPasswordManager for auto-retrieval in decrypt
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:retrieve_master_password)
          .and_return(master_password)
      end

      it 'encrypts and decrypts password correctly' do
        encrypted = described_class.encrypt_password(
          password,
          mode: :enhanced,
          master_password: master_password
        )

        expect(encrypted).not_to eq(password)

        decrypted = described_class.decrypt_password(
          encrypted,
          mode: :enhanced,
          master_password: master_password
        )
        expect(decrypted).to eq(password)
      end

      it 'auto-retrieves master password from keychain on decrypt' do
        encrypted = described_class.encrypt_password(
          password,
          mode: :enhanced,
          master_password: master_password
        )

        # Call decrypt without providing master_password
        decrypted = described_class.decrypt_password(
          encrypted,
          mode: :enhanced
        )

        expect(decrypted).to eq(password)
        expect(Lich::Common::GUI::MasterPasswordManager).to have_received(:retrieve_master_password)
      end

      it 'raises error when master password not found in keychain' do
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:retrieve_master_password)
          .and_return(nil)

        encrypted = described_class.encrypt_password(
          password,
          mode: :enhanced,
          master_password: master_password
        )

        expect {
          described_class.decrypt_password(encrypted, mode: :enhanced)
        }.to raise_error(StandardError, /Master password not found/)
      end
    end
  end

  describe 'round-trip: convert_yaml_to_legacy_format / convert_legacy_to_yaml_format' do
    let(:legacy_entries) do
      [
        {
          user_id: 'TESTUSER',
          password: 'password123',
          char_name: 'Testchar',
          game_code: 'GS3',
          game_name: 'GemStone IV',
          frontend: 'stormfront',
          custom_launch: nil,
          custom_launch_dir: nil,
          is_favorite: false,
          favorite_order: nil,
          encryption_mode: :plaintext
        },
        {
          user_id: 'TESTUSER',
          password: 'password123',
          char_name: 'Anotherchar',
          game_code: 'DR',
          game_name: 'DragonRealms',
          frontend: 'wizard',
          custom_launch: '/custom/path',
          custom_launch_dir: '/custom/dir',
          is_favorite: true,
          favorite_order: 1,
          encryption_mode: :plaintext
        },
        {
          user_id: 'OTHERUSER',
          password: 'otherpassword',
          char_name: 'Otherchar',
          game_code: 'GS3',
          game_name: 'GemStone IV',
          frontend: 'avalon',
          is_favorite: false,
          encryption_mode: :plaintext
        }
      ]
    end

    it 'preserves all entry data through legacy->yaml->legacy conversion' do
      # Convert legacy to YAML
      yaml_data = described_class.convert_legacy_to_yaml_format(legacy_entries)

      # Convert back to legacy
      roundtrip_entries = described_class.convert_yaml_to_legacy_format(yaml_data)

      expect(roundtrip_entries.length).to eq(3)

      # Check first entry
      testchar = roundtrip_entries.find { |e| e[:char_name] == 'Testchar' }
      expect(testchar[:user_id]).to eq('TESTUSER')
      expect(testchar[:password]).to eq('password123')
      expect(testchar[:game_code]).to eq('GS3')
      expect(testchar[:frontend]).to eq('stormfront')

      # Check entry with custom_launch
      anotherchar = roundtrip_entries.find { |e| e[:char_name] == 'Anotherchar' }
      expect(anotherchar[:custom_launch]).to eq('/custom/path')
      expect(anotherchar[:custom_launch_dir]).to eq('/custom/dir')
      expect(anotherchar[:is_favorite]).to be true
      expect(anotherchar[:favorite_order]).to eq(1)

      # Check other user entry
      otherchar = roundtrip_entries.find { |e| e[:char_name] == 'Otherchar' }
      expect(otherchar[:user_id]).to eq('OTHERUSER')
      expect(otherchar[:password]).to eq('otherpassword')
    end

    it 'preserves encryption_mode through conversion' do
      # Note: Using :plaintext here since convert_yaml_to_legacy_format
      # would attempt decryption with other modes
      plaintext_entries = legacy_entries.map { |e| e.merge(encryption_mode: :plaintext) }

      yaml_data = described_class.convert_legacy_to_yaml_format(plaintext_entries)
      roundtrip_entries = described_class.convert_yaml_to_legacy_format(yaml_data)

      expect(roundtrip_entries.all? { |e| e[:encryption_mode] == :plaintext }).to be true
    end

    it 'preserves validation_test through conversion' do
      validation_test = { 'encrypted' => 'abc123', 'plaintext' => 'VALID' }

      yaml_data = described_class.convert_legacy_to_yaml_format(legacy_entries, validation_test)

      expect(yaml_data['master_password_validation_test']).to eq(validation_test)
    end

    it 'normalizes account names to uppercase' do
      lowercase_entries = [
        {
          user_id: 'lowercase',
          password: 'pass',
          char_name: 'Char',
          game_code: 'GS3',
          game_name: 'GemStone IV',
          frontend: 'stormfront',
          encryption_mode: :plaintext
        }
      ]

      yaml_data = described_class.convert_legacy_to_yaml_format(lowercase_entries)
      roundtrip_entries = described_class.convert_yaml_to_legacy_format(yaml_data)

      expect(roundtrip_entries.first[:user_id]).to eq('LOWERCASE')
    end

    it 'normalizes character names to title case' do
      odd_case_entries = [
        {
          user_id: 'USER',
          password: 'pass',
          char_name: 'ALLCAPS',
          game_code: 'GS3',
          game_name: 'GemStone IV',
          frontend: 'stormfront',
          encryption_mode: :plaintext
        }
      ]

      yaml_data = described_class.convert_legacy_to_yaml_format(odd_case_entries)
      roundtrip_entries = described_class.convert_yaml_to_legacy_format(yaml_data)

      expect(roundtrip_entries.first[:char_name]).to eq('Allcaps')
    end

    it 'deduplicates entries with same account/char/game/frontend/custom_launch' do
      duplicate_entries = [
        {
          user_id: 'USER',
          password: 'pass',
          char_name: 'Char',
          game_code: 'GS3',
          game_name: 'GemStone IV',
          frontend: 'stormfront',
          custom_launch: nil,
          encryption_mode: :plaintext
        },
        {
          user_id: 'USER',
          password: 'pass',
          char_name: 'Char',
          game_code: 'GS3',
          game_name: 'GemStone IV',
          frontend: 'stormfront',
          custom_launch: nil,
          encryption_mode: :plaintext
        }
      ]

      yaml_data = described_class.convert_legacy_to_yaml_format(duplicate_entries)
      roundtrip_entries = described_class.convert_yaml_to_legacy_format(yaml_data)

      expect(roundtrip_entries.length).to eq(1)
    end

    it 'allows same char with different custom_launch values' do
      different_launch_entries = [
        {
          user_id: 'USER',
          password: 'pass',
          char_name: 'Char',
          game_code: 'GS3',
          game_name: 'GemStone IV',
          frontend: 'stormfront',
          custom_launch: '/path/one',
          encryption_mode: :plaintext
        },
        {
          user_id: 'USER',
          password: 'pass',
          char_name: 'Char',
          game_code: 'GS3',
          game_name: 'GemStone IV',
          frontend: 'stormfront',
          custom_launch: '/path/two',
          encryption_mode: :plaintext
        }
      ]

      yaml_data = described_class.convert_legacy_to_yaml_format(different_launch_entries)
      roundtrip_entries = described_class.convert_yaml_to_legacy_format(yaml_data)

      expect(roundtrip_entries.length).to eq(2)
      launches = roundtrip_entries.map { |e| e[:custom_launch] }
      expect(launches).to contain_exactly('/path/one', '/path/two')
    end
  end
end
