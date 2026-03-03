# frozen_string_literal: true

# Integration spec for authentication module namespace resolution
#
# This spec verifies that cross-module references resolve correctly at runtime.
# It catches namespace errors like:
#   - uninitialized constant Lich::Common::Authentication::EntryStore::PasswordCipher
#   - uninitialized constant Lich::Common::Authentication::EntryStore::Utilities
#   - undefined method 'prepare_launch_data' for module Lich::Common::Authentication
#
# These errors occur when modules reference other modules without full namespaces,
# and are NOT caught by unit tests that mock the cross-module calls.

require_relative '../../../login_spec_helper'

RSpec.describe 'Authentication module integration' do
  describe 'namespace resolution' do
    # These tests verify that module references resolve correctly.
    # They exercise the actual code paths (with minimal mocking) to catch
    # namespace errors that unit tests miss.

    describe 'EntryStore -> PasswordCipher' do
      it 'can call encrypt_password without namespace error' do
        # This would raise "uninitialized constant PasswordCipher" if
        # EntryStore used bare PasswordCipher instead of Lich::Common::GUI::PasswordCipher
        expect {
          Lich::Common::Authentication::EntryStore.encrypt_password(
            'test_password',
            mode: :standard,
            account_name: 'TESTUSER'
          )
        }.not_to raise_error
      end

      it 'can call decrypt_password without namespace error' do
        # First encrypt a password
        encrypted = Lich::Common::Authentication::EntryStore.encrypt_password(
          'test_password',
          mode: :standard,
          account_name: 'TESTUSER'
        )

        # This would raise "uninitialized constant PasswordCipher" if namespace is wrong
        expect {
          Lich::Common::Authentication::EntryStore.decrypt_password(
            encrypted,
            mode: :standard,
            account_name: 'TESTUSER'
          )
        }.not_to raise_error
      end
    end

    describe 'EntryStore -> Utilities' do
      it 'references Lich::Common::GUI::Utilities correctly' do
        # Verify the constant is accessible from the module's perspective
        # This catches "uninitialized constant EntryStore::Utilities"
        expect(Lich::Common::GUI::Utilities).to be_a(Module)
        expect(Lich::Common::GUI::Utilities).to respond_to(:safe_file_operation)
      end
    end

    describe 'EntryStore -> State' do
      it 'references Lich::Common::GUI::State correctly' do
        # Verify the constant is accessible
        expect(Lich::Common::GUI::State).to be_a(Module)
        expect(Lich::Common::GUI::State).to respond_to(:load_saved_entries)
      end
    end

    describe 'Authentication::LaunchData' do
      it 'has prepare method accessible' do
        # This catches "undefined method 'prepare_launch_data'" when
        # code calls Authentication.prepare_launch_data instead of
        # Authentication::LaunchData.prepare
        expect(Lich::Common::Authentication::LaunchData).to respond_to(:prepare)
      end

      it 'can call prepare without namespace error' do
        auth_data = {
          'key'    => 'test_key',
          'server' => 'test.example.com',
          'port'   => '8080'
        }

        expect {
          Lich::Common::Authentication::LaunchData.prepare(
            auth_data,
            'stormfront'
          )
        }.not_to raise_error
      end
    end

    describe 'Authentication module' do
      it 'has authenticate method accessible' do
        # authenticate is defined directly on Authentication module, not a separate Authenticator
        expect(Lich::Common::Authentication).to respond_to(:authenticate)
      end
    end
  end

  describe 'module loading order' do
    # Verify that requiring gui_login.rb loads all dependencies correctly
    # This catches missing require statements

    it 'loads EntryStore module' do
      expect(defined?(Lich::Common::Authentication::EntryStore)).to eq('constant')
    end

    it 'loads LaunchData module' do
      expect(defined?(Lich::Common::Authentication::LaunchData)).to eq('constant')
    end

    it 'loads Authentication module with authenticate method' do
      # authenticator.rb adds authenticate method to Authentication module
      expect(Lich::Common::Authentication).to respond_to(:authenticate)
    end

    it 'loads PasswordCipher module' do
      expect(defined?(Lich::Common::GUI::PasswordCipher)).to eq('constant')
    end

    it 'loads Utilities module' do
      expect(defined?(Lich::Common::GUI::Utilities)).to eq('constant')
    end

    it 'loads State module' do
      expect(defined?(Lich::Common::GUI::State)).to eq('constant')
    end

    it 'loads MasterPasswordManager module' do
      expect(defined?(Lich::Common::GUI::MasterPasswordManager)).to eq('constant')
    end
  end

  describe 'cross-module method signatures' do
    # Verify that methods have expected signatures
    # This catches API changes that break callers

    it 'PasswordCipher.encrypt accepts expected parameters' do
      method = Lich::Common::GUI::PasswordCipher.method(:encrypt)
      param_names = method.parameters.map(&:last)

      expect(param_names).to include(:password)
      expect(param_names).to include(:mode)
    end

    it 'PasswordCipher.decrypt accepts expected parameters' do
      method = Lich::Common::GUI::PasswordCipher.method(:decrypt)
      param_names = method.parameters.map(&:last)

      expect(param_names).to include(:encrypted_password)
      expect(param_names).to include(:mode)
    end

    it 'LaunchData.prepare accepts expected parameters' do
      method = Lich::Common::Authentication::LaunchData.method(:prepare)
      # Should accept: auth_data, frontend, custom_launch = nil, custom_launch_dir = nil
      expect(method.arity.abs).to be >= 2
    end

    it 'Utilities.safe_file_operation accepts expected parameters' do
      method = Lich::Common::GUI::Utilities.method(:safe_file_operation)
      # Should accept: file_path, operation, content = nil
      expect(method.arity.abs).to be >= 2
    end
  end
end
