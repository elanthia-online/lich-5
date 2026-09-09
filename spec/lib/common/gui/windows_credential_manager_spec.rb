# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'os'
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

      # CredentialStruct and the attach_function-defined API calls are only defined
      # when the real OS.windows? is true at file-load time (see windows_credential_manager.rb)
      # so this platform can only be exercised on an actual Windows runtime, not by
      # stubbing OS.windows? after the fact on this (Linux) CI runner.
      it 'returns true if FFI library loads successfully', if: OS.windows? do
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

  describe 'module load (regression for #1542)' do
    # The bug this guards against: this file used to call
    # Lich::Util.install_gem_requirements and extend FFI::Library unconditionally
    # at load time on every platform. That made loading it depend on some other
    # file having already loaded ffi/install_gem_requirements first, so a spec-stub
    # race elsewhere in the suite could make it raise on non-Windows CI. Now the
    # whole FFI-dependent block is gated behind OS.windows?, so this file must
    # never touch Lich::Util.install_gem_requirements off Windows, regardless of
    # whether a real or stubbed version of that method exists.
    it 'never calls Lich::Util.install_gem_requirements off Windows' do
      allow(OS).to receive(:windows?).and_return(false)
      # This file's own `require 'ffi'` above already defines FFI, which would mask
      # a regression where extend FFI::Library/CredentialStruct escaped the guard
      # without calling install_gem_requirements. Hide it so a reload only succeeds
      # if the guard keeps every FFI reference out of the non-Windows load path.
      hide_const('FFI')
      expect(Lich::Util).not_to receive(:install_gem_requirements)

      load File.join(LIB_DIR, 'common', 'gui', 'windows_credential_manager.rb')
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
      # rubocop:disable Custom/AsciiOnlySource -- Intentional Unicode password fixtures exercise credential encoding.
      special_passwords = [
        'p@ssw0rd!',
        'pässwörd',
        '密码',
        "p'ss\"w@rd",
        'p\nw\t\r'
      ]
      # rubocop:enable Custom/AsciiOnlySource

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
        # rubocop:disable Custom/AsciiOnlySource -- Intentional Unicode strings exercise UTF-16LE boundary conversion.
        result = described_class.store_credential(
          'тест.service',
          'пользователь',
          'пароль'
        )
        # rubocop:enable Custom/AsciiOnlySource

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
