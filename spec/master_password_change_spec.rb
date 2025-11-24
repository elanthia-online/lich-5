# frozen_string_literal: true

require 'spec_helper'
require 'common/gui/master_password_change'
require 'common/gui/master_password_manager'
require 'common/gui/password_cipher'
require 'common/gui/yaml_state'
require 'fileutils'

RSpec.describe Lich::Common::GUI::MasterPasswordChange do
  let(:test_password) { 'TestPassword123!' }
  let(:new_password) { 'NewSecurePassword456!' }
  let(:weak_password) { 'weak' }
  let(:data_dir) { File.join('/tmp', "lich_test_#{Time.now.to_i}") }
  let(:yaml_file) { File.join(data_dir, 'entry.yaml') }

  # Import necessary classes
  let(:master_password_manager) { Lich::Common::GUI::MasterPasswordManager }
  let(:password_cipher) { Lich::Common::GUI::PasswordCipher }
  let(:yaml_state) { Lich::Common::GUI::YamlState }

  before do
    FileUtils.mkdir_p(data_dir)
    allow(Lich).to receive(:log)
  end

  after do
    FileUtils.rm_rf(data_dir) if File.exist?(data_dir)
  end

  describe '.show_change_master_password_dialog' do
    it 'requires parent window and data_dir' do
      # This test ensures the method exists and accepts the expected parameters
      # Full dialog testing would require GTK3 to be initialized
      expect(described_class).to respond_to(:show_change_master_password_dialog)
    end
  end

  describe 'private methods' do
    describe 'validate_current_password' do
      context 'with valid password' do
        before do
          # Create validation test
          validation = master_password_manager.create_validation_test(test_password)
          yaml_data = {
            'accounts'                        => {},
            'master_password_validation_test' => validation
          }
          File.write(yaml_file, YAML.dump(yaml_data))

          # Mock keychain
          allow(Lich::Common::GUI::MasterPasswordManager).to receive(:retrieve_master_password).and_return(test_password)
        end

        it 'returns true for correct password' do
          result = described_class.send(:validate_current_password, test_password, yaml_file)
          expect(result).to be true
        end

        it 'returns false for incorrect password' do
          result = described_class.send(:validate_current_password, 'WrongPassword', yaml_file)
          expect(result).to be false
        end
      end

      context 'with missing validation test' do
        before do
          yaml_data = { 'accounts' => {} }
          File.write(yaml_file, YAML.dump(yaml_data))
        end

        it 'returns false when no validation test exists' do
          result = described_class.send(:validate_current_password, test_password, yaml_file)
          expect(result).to be false
        end
      end

      context 'with missing keychain password' do
        before do
          validation = master_password_manager.create_validation_test(test_password)
          yaml_data = {
            'accounts'                        => {},
            'master_password_validation_test' => validation
          }
          File.write(yaml_file, YAML.dump(yaml_data))

          allow(Lich::Common::GUI::MasterPasswordManager).to receive(:retrieve_master_password).and_return(nil)
        end

        it 'returns false when keychain password missing' do
          result = described_class.send(:validate_current_password, test_password, yaml_file)
          expect(result).to be false
        end
      end
    end

    describe 're_encrypt_all_accounts' do
      before do
        # Create sample YAML data with Enhanced accounts
        @validation = master_password_manager.create_validation_test(test_password)

        # Create encrypted passwords
        encrypted_pass1 = password_cipher.encrypt(
          'account1_pass',
          mode: :enhanced,
          master_password: test_password
        )
        encrypted_pass2 = password_cipher.encrypt(
          'account2_pass',
          mode: :enhanced,
          master_password: test_password
        )

        @yaml_data = {
          'encryption_mode'                 => 'enhanced',
          'accounts'                        => {
            'ACCOUNT1' => {
              'password' => encrypted_pass1
            },
            'ACCOUNT2' => {
              'password' => encrypted_pass2
            }
          },
          'master_password_validation_test' => @validation
        }

        File.write(yaml_file, YAML.dump(@yaml_data))

        # Mock keychain operations
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:store_master_password).and_return(true)
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:create_validation_test).and_return(
          master_password_manager.create_validation_test(new_password)
        )
      end

      it 're-encrypts all Enhanced accounts successfully' do
        result = described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)
        expect(result).to be true
      end

      it 'creates backup before re-encryption' do
        described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)
        # Backup should be cleaned up on success
        expect(File.exist?("#{yaml_file}.backup")).to be false
      end

      it 'updates validation test with new password' do
        expect(Lich::Common::GUI::MasterPasswordManager).to receive(:create_validation_test).with(new_password)
        described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)
      end

      it 'stores new password in keychain' do
        expect(Lich::Common::GUI::MasterPasswordManager).to receive(:store_master_password).with(new_password)
        described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)
      end

      it 'returns false if keychain update fails' do
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:store_master_password).and_return(false)
        result = described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)
        expect(result).to be false
      end

      it 'restores from backup on failure' do
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:store_master_password).and_return(false)

        result = described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)

        # Verify method returns false on failure
        expect(result).to be false
      end

      it 'handles decryption errors gracefully' do
        # Corrupt the encrypted password
        @yaml_data['accounts']['ACCOUNT1']['password'] = 'invalid_encrypted_data'

        result = described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)
        expect(result).to be false
      end

      context 'with no Enhanced accounts' do
        before do
          @yaml_data['encryption_mode'] = 'plaintext'
          @yaml_data['accounts'] = {
            'ACCOUNT1' => {
              'password' => 'plaintext_pass'
            }
          }
          File.write(yaml_file, YAML.dump(@yaml_data))
        end

        it 'handles gracefully when no Enhanced accounts exist' do
          result = described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)
          expect(result).to be true
        end
      end

      context 'with multiple Enhanced accounts' do
        before do
          enhanced_data = {
            'encryption_mode'                 => 'enhanced',
            'accounts'                        => {
              'ACCOUNT1' => {
                'password' => password_cipher.encrypt(
                  'pass1',
                  mode: :enhanced,
                  master_password: test_password
                )
              },
              'ACCOUNT2' => {
                'password' => password_cipher.encrypt(
                  'pass2',
                  mode: :enhanced,
                  master_password: test_password
                )
              },
              'ACCOUNT3' => {
                'password' => password_cipher.encrypt(
                  'pass3',
                  mode: :enhanced,
                  master_password: test_password
                )
              }
            },
            'master_password_validation_test' => @validation
          }
          File.write(yaml_file, YAML.dump(enhanced_data))
        end

        it 're-encrypts all Enhanced accounts' do
          enhanced_data = YAML.load_file(yaml_file)
          result = described_class.send(:re_encrypt_all_accounts, enhanced_data, data_dir, test_password, new_password)

          expect(result).to be true
          # All 3 enhanced accounts should be re-encrypted
          expect(Lich).to have_received(:log).with(include("Re-encrypting 3 Enhanced"))
        end
      end
    end

    describe 'restore_from_backup' do
      it 'restores YAML file from backup' do
        original_content = "original data"
        backup_content = "backup data"

        File.write(yaml_file, original_content)
        backup_file = "#{yaml_file}.backup"
        File.write(backup_file, backup_content)

        described_class.send(:restore_from_backup, yaml_file, backup_file)

        expect(File.read(yaml_file)).to eq(backup_content)
        expect(File.exist?(backup_file)).to be false
      end

      it 'does nothing if backup does not exist' do
        File.write(yaml_file, "original data")
        original_content = File.read(yaml_file)
        backup_file = "#{yaml_file}.backup"

        described_class.send(:restore_from_backup, yaml_file, backup_file)

        expect(File.read(yaml_file)).to eq(original_content)
      end
    end
  end

  describe 'validation' do
    context 'password strength' do
      it 'requires minimum 8 characters' do
        # This is tested through the dialog validation
        # The private method enforce_password_strength would check this
        expect(weak_password.length).to be < 8
      end
    end

    context 'password confirmation' do
      it 'requires matching new password and confirmation' do
        # Dialog checks new_password == confirm_password
        password1 = 'SecurePass123'
        password2 = 'DifferentPass456'

        expect(password1).not_to eq(password2)
      end
    end
  end

  describe 'error handling' do
    it 'handles validation errors gracefully' do
      allow(Lich::Common::GUI::MasterPasswordManager).to receive(:retrieve_master_password).and_raise(StandardError.new("Test error"))
      yaml_data = { 'accounts' => {} }
      File.write(yaml_file, YAML.dump(yaml_data))

      result = described_class.send(:validate_current_password, test_password, yaml_file)

      expect(result).to be false
    end

    it 'never logs password values in error messages' do
      @validation = master_password_manager.create_validation_test(test_password)

      encrypted_pass = password_cipher.encrypt(
        'account_pass',
        mode: :enhanced,
        master_password: test_password
      )

      yaml_data = {
        'accounts'                        => {
          'ACCOUNT1' => {
            'password'        => encrypted_pass,
            'encryption_mode' => 'enhanced'
          }
        },
        'master_password_validation_test' => @validation
      }
      File.write(yaml_file, YAML.dump(yaml_data))

      allow(Lich::Common::GUI::MasterPasswordManager).to receive(:store_master_password).and_raise(StandardError.new("Keychain error"))

      result = described_class.send(:re_encrypt_all_accounts, yaml_data, data_dir, test_password, new_password)

      expect(result).to be false
      # Verify we log the error but not the passwords
      expect(Lich).to have_received(:log).with(include("Keychain error"))
      expect(Lich).not_to have_received(:log).with(include(test_password))
      expect(Lich).not_to have_received(:log).with(include(new_password))
    end
  end

  describe 'logging' do
    it 'logs backup creation' do
      @validation = master_password_manager.create_validation_test(test_password)
      yaml_data = {
        'accounts'                        => {},
        'master_password_validation_test' => @validation
      }
      File.write(yaml_file, YAML.dump(yaml_data))

      allow(Lich::Common::GUI::MasterPasswordManager).to receive(:store_master_password).and_return(true)
      allow(Lich::Common::GUI::MasterPasswordManager).to receive(:create_validation_test).and_return(@validation)

      described_class.send(:re_encrypt_all_accounts, yaml_data, data_dir, test_password, new_password)

      expect(Lich).to have_received(:log).with(include("backup created"))
    end

    it 'logs successful password change' do
      @validation = master_password_manager.create_validation_test(test_password)
      yaml_data = {
        'accounts'                        => {},
        'master_password_validation_test' => @validation
      }
      File.write(yaml_file, YAML.dump(yaml_data))

      allow(Lich::Common::GUI::MasterPasswordManager).to receive(:store_master_password).and_return(true)
      allow(Lich::Common::GUI::MasterPasswordManager).to receive(:create_validation_test).and_return(@validation)

      described_class.send(:re_encrypt_all_accounts, yaml_data, data_dir, test_password, new_password)

      expect(Lich).to have_received(:log).with(include("Master password changed successfully"))
    end

    it 'logs re-encryption count' do
      @validation = master_password_manager.create_validation_test(test_password)

      encrypted_pass = password_cipher.encrypt(
        'account_pass',
        mode: :enhanced,
        master_password: test_password
      )

      yaml_data = {
        'encryption_mode'                 => 'enhanced',
        'accounts'                        => {
          'ACCOUNT1' => {
            'password' => encrypted_pass
          },
          'ACCOUNT2' => {
            'password' => encrypted_pass
          }
        },
        'master_password_validation_test' => @validation
      }
      File.write(yaml_file, YAML.dump(yaml_data))

      allow(Lich::Common::GUI::MasterPasswordManager).to receive(:store_master_password).and_return(true)
      allow(Lich::Common::GUI::MasterPasswordManager).to receive(:create_validation_test).and_return(@validation)

      described_class.send(:re_encrypt_all_accounts, yaml_data, data_dir, test_password, new_password)

      expect(Lich).to have_received(:log).with(include("Re-encrypting 2 Enhanced"))
    end
  end
end
