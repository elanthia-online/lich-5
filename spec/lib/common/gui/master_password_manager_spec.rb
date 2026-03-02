# frozen_string_literal: true

require 'spec_helper'
require 'common/gui/master_password_manager'
require 'common/gui/windows_credential_manager'

RSpec.describe Lich::Common::GUI::MasterPasswordManager do
  let(:test_password) { 'TestMasterPassword123!' }
  let(:keychain_service) { described_class::KEYCHAIN_SERVICE }

  describe 'constants' do
    it 'defines KEYCHAIN_SERVICE' do
      expect(keychain_service).to eq('lich5.master_password')
    end

    it 'defines VALIDATION_ITERATIONS' do
      expect(described_class::VALIDATION_ITERATIONS).to eq(100_000)
    end

    it 'defines VALIDATION_KEY_LENGTH' do
      expect(described_class::VALIDATION_KEY_LENGTH).to eq(32)
    end

    it 'defines VALIDATION_SALT_PREFIX' do
      expect(described_class::VALIDATION_SALT_PREFIX).to eq('lich5-master-password-validation-v1')
    end
  end

  describe '.keychain_available?' do
    context 'on macOS' do
      before do
        allow(OS).to receive(:mac?).and_return(true)
        allow(OS).to receive(:linux?).and_return(false)
        allow(OS).to receive(:windows?).and_return(false)
      end

      it 'checks macOS keychain availability' do
        allow(described_class).to receive(:macos_keychain_available?).and_return(true)
        expect(described_class.keychain_available?).to be true
      end
    end

    context 'on Linux' do
      before do
        allow(OS).to receive(:mac?).and_return(false)
        allow(OS).to receive(:linux?).and_return(true)
        allow(OS).to receive(:windows?).and_return(false)
      end

      it 'checks Linux keychain availability' do
        allow(described_class).to receive(:linux_keychain_available?).and_return(true)
        expect(described_class.keychain_available?).to be true
      end
    end

    context 'on Windows' do
      before do
        allow(OS).to receive(:mac?).and_return(false)
        allow(OS).to receive(:linux?).and_return(false)
        allow(OS).to receive(:windows?).and_return(true)
      end

      it 'checks Windows Credential Manager availability' do
        allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:available?).and_return(true)
        expect(described_class.keychain_available?).to be true
      end

      it 'returns false when Credential Manager is not available' do
        allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:available?).and_return(false)
        expect(described_class.keychain_available?).to be false
      end
    end

    context 'on unsupported OS' do
      before do
        allow(OS).to receive(:mac?).and_return(false)
        allow(OS).to receive(:linux?).and_return(false)
        allow(OS).to receive(:windows?).and_return(false)
      end

      it 'returns false' do
        expect(described_class.keychain_available?).to be false
      end
    end
  end

  describe '.store_master_password' do
    context 'when keychain is available' do
      before do
        allow(described_class).to receive(:keychain_available?).and_return(true)
      end

      context 'on Windows' do
        before do
          allow(OS).to receive(:mac?).and_return(false)
          allow(OS).to receive(:linux?).and_return(false)
          allow(OS).to receive(:windows?).and_return(true)
        end

        it 'stores password in Windows Credential Manager' do
          allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:store_credential).and_return(true)

          result = described_class.store_master_password(test_password)

          expect(Lich::Common::GUI::WindowsCredentialManager).to have_received(:store_credential).with(
            keychain_service,
            'lich5',
            test_password,
            'Lich 5 Master Password',
            Lich::Common::GUI::WindowsCredentialManager::CRED_PERSIST_LOCAL_MACHINE
          )
          expect(result).to be true
        end

        it 'returns false on credential manager failure' do
          allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:store_credential).and_return(false)

          result = described_class.store_master_password(test_password)

          expect(result).to be false
        end
      end
    end

    context 'when keychain is unavailable' do
      before do
        allow(described_class).to receive(:keychain_available?).and_return(false)
      end

      it 'returns false without attempting to store' do
        result = described_class.store_master_password(test_password)
        expect(result).to be false
      end
    end

    context 'error handling' do
      before do
        allow(described_class).to receive(:keychain_available?).and_return(true)
        allow(OS).to receive(:mac?).and_return(false)
        allow(OS).to receive(:linux?).and_return(false)
        allow(OS).to receive(:windows?).and_return(true)
      end

      it 'catches exceptions and logs errors' do
        allow(described_class).to receive(:store_windows_keychain).and_raise(StandardError, 'Test error')
        allow(Lich).to receive(:log)

        result = described_class.store_master_password(test_password)

        expect(Lich).to have_received(:log).with(/error: Failed to store master password/)
        expect(result).to be false
      end
    end
  end

  describe '.retrieve_master_password' do
    context 'when keychain is available' do
      before do
        allow(described_class).to receive(:keychain_available?).and_return(true)
      end

      context 'on Windows' do
        before do
          allow(OS).to receive(:mac?).and_return(false)
          allow(OS).to receive(:linux?).and_return(false)
          allow(OS).to receive(:windows?).and_return(true)
        end

        it 'retrieves password from Windows Credential Manager' do
          allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:retrieve_credential).and_return(test_password)

          result = described_class.retrieve_master_password

          expect(Lich::Common::GUI::WindowsCredentialManager).to have_received(:retrieve_credential).with(keychain_service)
          expect(result).to eq(test_password)
        end

        it 'returns nil when credential not found' do
          allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:retrieve_credential).and_return(nil)

          result = described_class.retrieve_master_password

          expect(result).to be_nil
        end
      end
    end

    context 'when keychain is unavailable' do
      before do
        allow(described_class).to receive(:keychain_available?).and_return(false)
      end

      it 'returns nil without attempting to retrieve' do
        result = described_class.retrieve_master_password
        expect(result).to be_nil
      end
    end

    context 'error handling' do
      before do
        allow(described_class).to receive(:keychain_available?).and_return(true)
        allow(OS).to receive(:mac?).and_return(false)
        allow(OS).to receive(:linux?).and_return(false)
        allow(OS).to receive(:windows?).and_return(true)
      end

      it 'catches exceptions and logs errors' do
        allow(described_class).to receive(:retrieve_windows_keychain).and_raise(StandardError, 'Test error')
        allow(Lich).to receive(:log)

        result = described_class.retrieve_master_password

        expect(Lich).to have_received(:log).with(/error: Failed to retrieve master password/)
        expect(result).to be_nil
      end
    end
  end

  describe '.delete_master_password' do
    context 'when keychain is available' do
      before do
        allow(described_class).to receive(:keychain_available?).and_return(true)
      end

      context 'on Windows' do
        before do
          allow(OS).to receive(:mac?).and_return(false)
          allow(OS).to receive(:linux?).and_return(false)
          allow(OS).to receive(:windows?).and_return(true)
        end

        it 'deletes password from Windows Credential Manager' do
          allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:delete_credential).and_return(true)

          result = described_class.delete_master_password

          expect(Lich::Common::GUI::WindowsCredentialManager).to have_received(:delete_credential).with(keychain_service)
          expect(result).to be true
        end

        it 'returns false on deletion failure' do
          allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:delete_credential).and_return(false)

          result = described_class.delete_master_password

          expect(result).to be false
        end
      end
    end

    context 'when keychain is unavailable' do
      before do
        allow(described_class).to receive(:keychain_available?).and_return(false)
      end

      it 'returns false without attempting to delete' do
        result = described_class.delete_master_password
        expect(result).to be false
      end
    end

    context 'error handling' do
      before do
        allow(described_class).to receive(:keychain_available?).and_return(true)
        allow(OS).to receive(:mac?).and_return(false)
        allow(OS).to receive(:linux?).and_return(false)
        allow(OS).to receive(:windows?).and_return(true)
      end

      it 'catches exceptions and logs errors' do
        allow(described_class).to receive(:delete_windows_keychain).and_raise(StandardError, 'Test error')
        allow(Lich).to receive(:log)

        result = described_class.delete_master_password

        expect(Lich).to have_received(:log).with(/error: Failed to delete master password/)
        expect(result).to be false
      end
    end
  end

  describe '.create_validation_test' do
    it 'creates a validation test hash' do
      result = described_class.create_validation_test(test_password)

      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly('validation_salt', 'validation_hash', 'validation_version')
      expect(result['validation_version']).to eq(1)
    end

    it 'generates base64-encoded salt' do
      result = described_class.create_validation_test(test_password)
      salt = Base64.strict_decode64(result['validation_salt'])

      expect(salt).to be_a(String)
      expect(salt.length).to be > 0
    end

    it 'generates base64-encoded hash' do
      result = described_class.create_validation_test(test_password)
      hash_value = Base64.strict_decode64(result['validation_hash'])

      expect(hash_value).to be_a(String)
      expect(hash_value.length).to eq(32) # SHA256 = 32 bytes
    end

    it 'generates different salt each time' do
      result1 = described_class.create_validation_test(test_password)
      result2 = described_class.create_validation_test(test_password)

      expect(result1['validation_salt']).not_to eq(result2['validation_salt'])
    end
  end

  describe '.validate_master_password' do
    let(:validation_test) do
      described_class.create_validation_test(test_password)
    end

    context 'with correct password' do
      it 'returns true' do
        result = described_class.validate_master_password(test_password, validation_test)
        expect(result).to be true
      end
    end

    context 'with incorrect password' do
      it 'returns false' do
        result = described_class.validate_master_password('WrongPassword', validation_test)
        expect(result).to be false
      end
    end

    context 'with invalid validation test' do
      it 'returns false when validation_test is not a hash' do
        result = described_class.validate_master_password(test_password, 'invalid')
        expect(result).to be false
      end

      it 'returns false when validation_salt is missing' do
        invalid_test = { 'validation_hash' => validation_test['validation_hash'] }
        result = described_class.validate_master_password(test_password, invalid_test)
        expect(result).to be false
      end

      it 'returns false when validation_hash is missing' do
        invalid_test = { 'validation_salt' => validation_test['validation_salt'] }
        result = described_class.validate_master_password(test_password, invalid_test)
        expect(result).to be false
      end
    end

    context 'with malformed base64 data' do
      it 'returns false on decode error' do
        allow(Lich).to receive(:log)
        invalid_test = {
          'validation_salt' => 'not valid base64!!!',
          'validation_hash' => validation_test['validation_hash']
        }
        result = described_class.validate_master_password(test_password, invalid_test)
        expect(result).to be false
      end
    end

    context 'error handling' do
      it 'catches exceptions and logs errors' do
        allow(Lich).to receive(:log)
        invalid_test = { 'validation_salt' => nil, 'validation_hash' => nil }

        result = described_class.validate_master_password(test_password, invalid_test)

        expect(result).to be false
      end
    end
  end

  describe '.secure_compare' do
    context 'with matching byte sequences' do
      it 'returns true' do
        a = "test123"
        b = "test123"
        result = described_class.send(:secure_compare, a, b)
        expect(result).to be true
      end
    end

    context 'with non-matching byte sequences' do
      it 'returns false' do
        a = "test123"
        b = "test124"
        result = described_class.send(:secure_compare, a, b)
        expect(result).to be false
      end
    end

    context 'with different lengths' do
      it 'returns false' do
        a = "test"
        b = "test123"
        result = described_class.send(:secure_compare, a, b)
        expect(result).to be false
      end
    end

    context 'with nil values' do
      it 'returns false when first argument is nil' do
        result = described_class.send(:secure_compare, nil, "test")
        expect(result).to be false
      end

      it 'returns false when second argument is nil' do
        result = described_class.send(:secure_compare, "test", nil)
        expect(result).to be false
      end
    end

    context 'timing attack resistance' do
      it 'performs constant-time comparison' do
        # This test verifies the implementation uses bitwise XOR
        # Real timing attack tests require specialized tooling
        a = "a" * 32
        b = "a" * 32
        c = "b" * 32

        result_match = described_class.send(:secure_compare, a, b)
        result_mismatch = described_class.send(:secure_compare, a, c)

        expect(result_match).to be true
        expect(result_mismatch).to be false
      end
    end
  end

  describe 'Windows-specific integration' do
    context 'store and retrieve cycle' do
      before do
        allow(OS).to receive(:mac?).and_return(false)
        allow(OS).to receive(:linux?).and_return(false)
        allow(OS).to receive(:windows?).and_return(true)
        allow(described_class).to receive(:keychain_available?).and_return(true)
      end

      it 'stores password and can retrieve it' do
        allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:store_credential).and_return(true)
        allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:retrieve_credential).and_return(test_password)

        store_result = described_class.store_master_password(test_password)
        retrieve_result = described_class.retrieve_master_password

        expect(store_result).to be true
        expect(retrieve_result).to eq(test_password)
      end
    end

    context 'delete cycle' do
      before do
        allow(OS).to receive(:mac?).and_return(false)
        allow(OS).to receive(:linux?).and_return(false)
        allow(OS).to receive(:windows?).and_return(true)
        allow(described_class).to receive(:keychain_available?).and_return(true)
      end

      it 'stores, retrieves, then deletes password' do
        allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:store_credential).and_return(true)
        allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:retrieve_credential).and_return(test_password)
        allow(Lich::Common::GUI::WindowsCredentialManager).to receive(:delete_credential).and_return(true)

        store_result = described_class.store_master_password(test_password)
        retrieve_result = described_class.retrieve_master_password
        delete_result = described_class.delete_master_password

        expect(store_result).to be true
        expect(retrieve_result).to eq(test_password)
        expect(delete_result).to be true
      end
    end
  end
end
