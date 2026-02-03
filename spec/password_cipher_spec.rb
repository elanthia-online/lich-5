# frozen_string_literal: true

require 'login_spec_helper'
require_relative '../lib/common/gui/password_cipher'

RSpec.describe Lich::Common::GUI::PasswordCipher do
  let(:password) { 'MySecurePassword123!' }
  let(:account_name) { 'TestAccount' }
  let(:master_password) { 'MasterPass456!' }

  describe '.encrypt and .decrypt' do
    context 'with standard mode' do
      it 'encrypts and decrypts password successfully' do
        encrypted = described_class.encrypt(password, mode: :standard, account_name: account_name)
        expect(encrypted).not_to eq(password)
        expect(encrypted).to be_a(String)

        decrypted = described_class.decrypt(encrypted, mode: :standard, account_name: account_name)
        expect(decrypted).to eq(password)
      end

      it 'produces different output each time due to IV' do
        encrypted1 = described_class.encrypt(password, mode: :standard, account_name: account_name)
        encrypted2 = described_class.encrypt(password, mode: :standard, account_name: account_name)
        expect(encrypted1).not_to eq(encrypted2)

        # But both decrypt to same password
        expect(described_class.decrypt(encrypted1, mode: :standard, account_name: account_name)).to eq(password)
        expect(described_class.decrypt(encrypted2, mode: :standard, account_name: account_name)).to eq(password)
      end

      it 'fails to decrypt with wrong account name' do
        encrypted = described_class.encrypt(password, mode: :standard, account_name: account_name)
        expect do
          described_class.decrypt(encrypted, mode: :standard, account_name: 'WrongAccount')
        end.to raise_error(Lich::Common::GUI::PasswordCipher::DecryptionError)
      end
    end

    context 'with enhanced mode' do
      it 'encrypts and decrypts password successfully' do
        encrypted = described_class.encrypt(password, mode: :enhanced, master_password: master_password)
        expect(encrypted).not_to eq(password)
        expect(encrypted).to be_a(String)

        decrypted = described_class.decrypt(encrypted, mode: :enhanced, master_password: master_password)
        expect(decrypted).to eq(password)
      end

      it 'produces different output each time due to IV' do
        encrypted1 = described_class.encrypt(password, mode: :enhanced, master_password: master_password)
        encrypted2 = described_class.encrypt(password, mode: :enhanced, master_password: master_password)
        expect(encrypted1).not_to eq(encrypted2)

        # But both decrypt to same password
        expect(described_class.decrypt(encrypted1, mode: :enhanced, master_password: master_password)).to eq(password)
        expect(described_class.decrypt(encrypted2, mode: :enhanced, master_password: master_password)).to eq(password)
      end

      it 'fails to decrypt with wrong master password' do
        encrypted = described_class.encrypt(password, mode: :enhanced, master_password: master_password)
        expect do
          described_class.decrypt(encrypted, mode: :enhanced, master_password: 'WrongMasterPass')
        end.to raise_error(Lich::Common::GUI::PasswordCipher::DecryptionError)
      end
    end

    context 'error handling' do
      it 'raises error for invalid mode' do
        expect do
          described_class.encrypt(password, mode: :invalid_mode)
        end.to raise_error(ArgumentError, /Unsupported encryption mode/)
      end

      it 'raises error when account_name missing for standard mode' do
        expect do
          described_class.encrypt(password, mode: :standard)
        end.to raise_error(ArgumentError, /account_name required/)
      end

      it 'raises error when master_password missing for enhanced mode' do
        expect do
          described_class.encrypt(password, mode: :enhanced)
        end.to raise_error(ArgumentError, /master_password required/)
      end

      it 'raises DecryptionError for corrupted data' do
        expect do
          described_class.decrypt('corrupted_base64_data', mode: :standard, account_name: account_name)
        end.to raise_error(Lich::Common::GUI::PasswordCipher::DecryptionError)
      end

      it 'raises DecryptionError for truncated encrypted data' do
        encrypted = described_class.encrypt(password, mode: :standard, account_name: account_name)
        truncated = encrypted[0..10] # Only first few characters
        expect do
          described_class.decrypt(truncated, mode: :standard, account_name: account_name)
        end.to raise_error(Lich::Common::GUI::PasswordCipher::DecryptionError)
      end
    end

    context 'special characters and edge cases' do
      it 'handles empty password' do
        encrypted = described_class.encrypt('', mode: :standard, account_name: account_name)
        decrypted = described_class.decrypt(encrypted, mode: :standard, account_name: account_name)
        expect(decrypted).to eq('')
      end

      it 'handles password with special characters' do
        special_password = "p@$$w0rd!#%^&*()'\"<>?,./\\|`~"
        encrypted = described_class.encrypt(special_password, mode: :standard, account_name: account_name)
        decrypted = described_class.decrypt(encrypted, mode: :standard, account_name: account_name)
        expect(decrypted).to eq(special_password)
      end

      it 'handles password with unicode characters' do
        unicode_password = 'пароль密码🔐'
        encrypted = described_class.encrypt(unicode_password, mode: :standard, account_name: account_name)
        decrypted = described_class.decrypt(encrypted, mode: :standard, account_name: account_name)
        expect(decrypted).to eq(unicode_password)
      end

      it 'handles very long password' do
        long_password = 'a' * 1000
        encrypted = described_class.encrypt(long_password, mode: :standard, account_name: account_name)
        decrypted = described_class.decrypt(encrypted, mode: :standard, account_name: account_name)
        expect(decrypted).to eq(long_password)
      end
    end
  end

  describe 'security properties' do
    it 'encrypted output is Base64-encoded' do
      encrypted = described_class.encrypt(password, mode: :standard, account_name: account_name)
      expect(encrypted).to match(/\A[A-Za-z0-9+\/]+=*\z/)
    end

    it 'encrypted output is longer than plaintext' do
      encrypted = described_class.encrypt(password, mode: :standard, account_name: account_name)
      # Encrypted should be longer due to IV (16 bytes) + ciphertext + Base64 encoding
      expect(encrypted.length).to be > password.length
    end

    it 'different passwords produce different ciphertexts' do
      encrypted1 = described_class.encrypt('password1', mode: :standard, account_name: account_name)
      encrypted2 = described_class.encrypt('password2', mode: :standard, account_name: account_name)
      expect(encrypted1).not_to eq(encrypted2)
    end
  end
end
