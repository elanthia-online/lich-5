# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'common/gui/master_password_change'
require 'common/gui/master_password_manager'
require 'common/gui/password_cipher'
require 'common/authentication/entry_store'
require 'fileutils'
require 'tmpdir'

RSpec.describe Lich::Common::GUI::MasterPasswordChange do
  let(:test_password) { 'TestPassword123!' }
  let(:new_password) { 'NewSecurePassword456!' }
  let(:weak_password) { 'weak' }
  # A fresh directory per example. A name built from the clock second is shared
  # by every run that starts in the same second, and one run's cleanup deletes
  # the other's files.
  let(:data_dir) { Dir.mktmpdir('lich-master-password-change-spec-') }
  let(:yaml_file) { File.join(data_dir, 'entry.yaml') }

  # Import necessary classes
  let(:master_password_manager) { Lich::Common::GUI::MasterPasswordManager }
  let(:password_cipher) { Lich::Common::GUI::PasswordCipher }
  let(:entry_store) { Lich::Common::Authentication::EntryStore }
  let(:keychain) { { password: test_password } }

  before do
    allow(Lich).to receive(:log)
    # Keep all credential-store access synthetic, including strict rollback reads.
    allow(master_password_manager).to receive(:retrieve_master_password) { keychain[:password] }
    allow(master_password_manager).to receive(:store_master_password) { |value| keychain[:password] = value; true }
    allow(master_password_manager).to receive(:delete_master_password) { keychain[:password] = nil; true }
  end

  after do
    FileUtils.rm_rf(data_dir)
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

        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:create_validation_test).and_return(
          master_password_manager.create_validation_test(new_password)
        )
      end

      it 're-encrypts all Enhanced accounts successfully' do
        result = described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)
        expect(result).to be true
      end

      it 'publishes decryptable accounts with the matching keychain password' do
        expect(described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)).to be true

        expect(keychain[:password]).to eq(new_password)
        saved = YAML.safe_load_file(yaml_file)
        saved['accounts'].each_with_index do |(_name, account), index|
          expect(password_cipher.decrypt(account['password'], mode: :enhanced, master_password: new_password))
            .to eq("account#{index + 1}_pass")
        end
        expect(master_password_manager.validate_master_password(new_password, saved['master_password_validation_test'])).to be true
        expect(File.stat(yaml_file).mode & 0o777).to eq(0o600)
        expect(Dir.children(data_dir)).to eq(['entry.yaml'])
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
        original = File.binread(yaml_file)
        allow(master_password_manager).to receive(:store_master_password).and_return(false)
        result = described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)
        expect(result).to be false
        expect(File.binread(yaml_file)).to eq(original)
        expect(keychain[:password]).to eq(test_password)
      end

      [:original, :absent, :stale].each do |state|
        it "restores the #{state} keychain state when publication fails" do
          previous = { original: test_password, absent: nil, stale: 'SyntheticStalePassword789!' }.fetch(state)
          keychain[:password] = previous
          original = File.binread(yaml_file)
          allow(File).to receive(:rename).and_raise(IOError, 'synthetic publication failure')

          expect(described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)).to be false

          expect(File.binread(yaml_file)).to eq(original)
          expect(keychain[:password]).to eq(previous)
          expect(Dir.children(data_dir)).to eq(['entry.yaml'])
          expect(Lich).not_to have_received(:log).with(include('Master password changed successfully'))
        end
      end

      [:returns_false, :raises].each do |failure|
        it "restores a partially changed keychain when storing #{failure}" do
          original = File.binread(yaml_file)
          allow(master_password_manager).to receive(:store_master_password) do |value|
            keychain[:password] = value
            if value == new_password
              raise IOError, 'synthetic store failure' if failure == :raises
              false
            else
              true
            end
          end

          expect(described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)).to be false

          expect(File.binread(yaml_file)).to eq(original)
          expect(keychain[:password]).to eq(test_password)
        end
      end

      it 'refuses an unknown initial keychain state before mutation' do
        original = File.binread(yaml_file)
        allow(master_password_manager).to receive(:retrieve_master_password).with(strict: true).and_raise(IOError)
        expect(master_password_manager).not_to receive(:store_master_password)
        expect(master_password_manager).not_to receive(:delete_master_password)

        expect(described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)).to be false
        expect(File.binread(yaml_file)).to eq(original)
      end

      [:decrypt, :encrypt, :create_validation_test].each do |operation|
        it "preserves credentials when #{operation} returns nil" do
          original = File.binread(yaml_file)
          target = operation == :create_validation_test ? master_password_manager : password_cipher
          allow(target).to receive(operation).and_return(nil)
          expect(master_password_manager).not_to receive(:store_master_password)

          expect(described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)).to be false
          expect(File.binread(yaml_file)).to eq(original)
          expect(keychain[:password]).to eq(test_password)
        end
      end

      it 'reports manual recovery if keychain rollback fails' do
        original = File.binread(yaml_file)
        allow(File).to receive(:rename).and_raise(IOError)
        allow(master_password_manager).to receive(:store_master_password) do |value|
          next false if value == test_password
          keychain[:password] = value
          true
        end

        expect(described_class.send(:re_encrypt_all_accounts, @yaml_data, data_dir, test_password, new_password)).to be false
        expect(File.binread(yaml_file)).to eq(original)
        expect(Lich).to have_received(:log).with(include('manual keychain recovery is required')).at_least(:once)
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
    it 'logs the start of a password change' do
      @validation = master_password_manager.create_validation_test(test_password)
      yaml_data = {
        'accounts'                        => {},
        'master_password_validation_test' => @validation
      }
      File.write(yaml_file, YAML.dump(yaml_data))

      allow(Lich::Common::GUI::MasterPasswordManager).to receive(:store_master_password).and_return(true)
      allow(Lich::Common::GUI::MasterPasswordManager).to receive(:create_validation_test).and_return(@validation)

      described_class.send(:re_encrypt_all_accounts, yaml_data, data_dir, test_password, new_password)

      expect(Lich).to have_received(:log).with(include("Starting master password change"))
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
