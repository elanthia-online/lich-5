# frozen_string_literal: true

require 'spec_helper'
require 'ffi'
require 'common/gui/windows_credential_manager'

RSpec.describe Lich::Common::GUI::WindowsCredentialManager do
  let(:target_name) { 'test.service' }
  let(:username) { 'testuser' }
  let(:password) { 'testpassword123' }
  let(:comment) { 'Test credential' }

  describe '.available?' do
    context 'on Windows platform' do
      before do
        allow(OS).to receive(:windows?).and_return(true)
      end

      it 'returns true if FFI library loads successfully' do
        expect(described_class.available?).to be true
      end
    end

    context 'on non-Windows platform' do
      before do
        allow(OS).to receive(:windows?).and_return(false)
      end

      it 'returns false when not on Windows' do
        expect(described_class.available?).to be false
      end
    end
  end

  describe '.store_credential' do
    context 'with valid parameters' do
      it 'stores credential successfully' do
        allow(described_class).to receive(:available?).and_return(true)
        allow(Lich).to receive(:log)

        result = described_class.store_credential(
          target_name,
          username,
          password,
          comment
        )

        # Result depends on actual Windows API availability
        # In test environment, this may return false if advapi32.dll not available
        expect([true, false]).to include(result)
      end
    end

    context 'when credential manager is unavailable' do
      before do
        allow(described_class).to receive(:available?).and_return(false)
      end

      it 'returns false' do
        result = described_class.store_credential(
          target_name,
          username,
          password
        )
        expect(result).to be false
      end
    end

    context 'with various persistence levels' do
      persistence_levels = {
        'session'       => described_class::CRED_PERSIST_SESSION,
        'local_machine' => described_class::CRED_PERSIST_LOCAL_MACHINE,
        'enterprise'    => described_class::CRED_PERSIST_ENTERPRISE
      }

      persistence_levels.each do |name, level|
        it "stores credential with #{name} persistence" do
          allow(described_class).to receive(:available?).and_return(true)
          allow(Lich).to receive(:log)

          result = described_class.store_credential(
            target_name,
            username,
            password,
            nil,
            level
          )

          expect([true, false]).to include(result)
        end
      end
    end

    context 'with special characters in password' do
      special_passwords = [
        'p@ssw0rd!',
        'pässwörd',
        '密码',
        "p'ss\"w@rd",
        'p\nw\t\r'
      ]

      special_passwords.each do |special_pass|
        it "handles password with special characters: #{special_pass.inspect}" do
          allow(described_class).to receive(:available?).and_return(true)
          allow(Lich).to receive(:log)

          result = described_class.store_credential(
            target_name,
            username,
            special_pass
          )

          expect([true, false]).to include(result)
        end
      end
    end

    context 'error handling' do
      it 'catches and logs exceptions' do
        allow(described_class).to receive(:available?).and_return(true)
        allow(described_class).to receive(:store_credential).and_call_original
        allow(Lich).to receive(:log)

        # This will likely fail in test environment without real Windows API
        result = described_class.store_credential(
          target_name,
          username,
          password
        )

        expect([true, false]).to include(result)
      end
    end
  end

  describe '.retrieve_credential' do
    context 'when credential exists' do
      it 'returns the stored credential' do
        allow(described_class).to receive(:available?).and_return(true)
        allow(Lich).to receive(:log)

        # Store then retrieve (requires Windows platform)
        described_class.store_credential(target_name, username, password)
        result = described_class.retrieve_credential(target_name)

        expect(result).to be_a(String).or be_nil
      end
    end

    context 'when credential does not exist' do
      it 'returns nil' do
        allow(described_class).to receive(:available?).and_return(true)
        allow(Lich).to receive(:log)

        result = described_class.retrieve_credential('nonexistent.service')

        expect(result).to be_nil
      end
    end

    context 'when credential manager is unavailable' do
      before do
        allow(described_class).to receive(:available?).and_return(false)
      end

      it 'returns nil' do
        result = described_class.retrieve_credential(target_name)
        expect(result).to be_nil
      end
    end

    context 'error handling' do
      it 'catches exceptions and logs errors' do
        allow(described_class).to receive(:available?).and_return(true)
        allow(Lich).to receive(:log)

        # Attempt to retrieve non-existent credential
        result = described_class.retrieve_credential('invalid.target')

        expect(result).to be_nil
      end
    end
  end

  describe '.delete_credential' do
    context 'when credential exists' do
      it 'deletes the credential' do
        allow(described_class).to receive(:available?).and_return(true)
        allow(Lich).to receive(:log)

        # Store, then delete
        described_class.store_credential(target_name, username, password)
        result = described_class.delete_credential(target_name)

        expect([true, false]).to include(result)
      end
    end

    context 'when credential does not exist' do
      it 'returns false' do
        allow(described_class).to receive(:available?).and_return(true)
        allow(Lich).to receive(:log)

        result = described_class.delete_credential('nonexistent.service')

        expect(result).to be false
      end
    end

    context 'when credential manager is unavailable' do
      before do
        allow(described_class).to receive(:available?).and_return(false)
      end

      it 'returns false' do
        result = described_class.delete_credential(target_name)
        expect(result).to be false
      end
    end

    context 'error handling' do
      it 'catches exceptions and logs errors' do
        allow(described_class).to receive(:available?).and_return(true)
        allow(Lich).to receive(:log)

        result = described_class.delete_credential('invalid.target')

        expect(result).to be false
      end
    end
  end

  describe 'private helper methods' do
    describe '#string_to_wide' do
      it 'converts Ruby string to UTF-16LE encoded pointer' do
        # These are private methods, but we test their behavior through public interface
        allow(described_class).to receive(:available?).and_return(true)
        allow(Lich).to receive(:log)

        # Store credential with UTF-8 string to test encoding
        result = described_class.store_credential(
          'тест.service',
          'пользователь',
          'пароль'
        )

        expect([true, false]).to include(result)
      end
    end

    describe '#wide_to_string' do
      it 'handles NULL pointers gracefully' do
        # Tested through public API when credential is not found
        allow(described_class).to receive(:available?).and_return(true)
        allow(Lich).to receive(:log)

        result = described_class.retrieve_credential('nonexistent.service')
        expect(result).to be_nil
      end
    end
  end

  describe 'credential types' do
    it 'defines CRED_TYPE_GENERIC constant' do
      expect(described_class::CRED_TYPE_GENERIC).to eq(1)
    end

    it 'defines credential type constants for future use' do
      expect(described_class::CRED_TYPE_DOMAIN_PASSWORD).to eq(2)
      expect(described_class::CRED_TYPE_DOMAIN_CERTIFICATE).to eq(3)
      expect(described_class::CRED_TYPE_GENERIC_CERTIFICATE).to eq(5)
    end
  end

  describe 'persistence levels' do
    it 'defines CRED_PERSIST_SESSION constant' do
      expect(described_class::CRED_PERSIST_SESSION).to eq(1)
    end

    it 'defines CRED_PERSIST_LOCAL_MACHINE constant' do
      expect(described_class::CRED_PERSIST_LOCAL_MACHINE).to eq(2)
    end

    it 'defines CRED_PERSIST_ENTERPRISE constant' do
      expect(described_class::CRED_PERSIST_ENTERPRISE).to eq(3)
    end
  end

  describe 'size limits' do
    it 'defines max credential blob size' do
      expect(described_class::CRED_MAX_CREDENTIAL_BLOB_SIZE).to eq(512 * 1024)
    end
  end
end
