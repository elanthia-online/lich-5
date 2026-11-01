# frozen_string_literal: true

require_relative '../spec_helper'
require 'open3'
require 'common/gui/master_password_manager'

# Proves spec/support/real_keychain_fence.rb: a spec that reaches the OS
# keychain without a double fails with the fence message, while everything
# else still runs. The examples never execute a keychain tool: every call that
# would reach one is either fenced or replaced by a stub in the example itself.
RSpec.describe RealKeychainFence do
  let(:manager) { Lich::Common::GUI::MasterPasswordManager }

  describe 'manager shell-out wrappers' do
    RealKeychainFence::MANAGER_METHODS.each do |name|
      it "raises with the fence message from #{name}" do
        args = name.to_s.start_with?('store_') ? ['not-a-real-password'] : []

        expect { manager.send(name, *args) }
          .to raise_error(RealKeychainFence::Reached, /#{name}.*would touch the real keychain/)
      end
    end

    it 'makes store_master_password return false when the manager is not doubled' do
      allow(OS).to receive(:mac?).and_return(false)
      allow(OS).to receive(:windows?).and_return(false)
      allow(OS).to receive(:linux?).and_return(true)
      allow(manager).to receive(:linux_keychain_available?).and_return(true)

      expect(Lich).to receive(:log).with(/store_linux_keychain.*would touch the real keychain/)
      expect(manager.store_master_password('not-a-real-password')).to be false
    end

    it 'makes a strict retrieve raise IOError when the manager is not doubled' do
      allow(OS).to receive(:mac?).and_return(false)
      allow(OS).to receive(:windows?).and_return(false)
      allow(OS).to receive(:linux?).and_return(true)
      allow(manager).to receive(:linux_keychain_available?).and_return(true)

      expect { manager.retrieve_master_password(strict: true) }
        .to raise_error(IOError, /previous master password state is unknown/)
    end

    it 'lets an example stub of a wrapper win' do
      allow(manager).to receive(:retrieve_linux_keychain).and_return('stubbed-value')

      expect(manager.send(:retrieve_linux_keychain)).to eq('stubbed-value')
    end
  end

  describe 'Windows credential calls' do
    let(:windows_manager) do
      Module.new do
        RealKeychainFence::WINDOWS_METHODS.each { |name| define_singleton_method(name) { |*| :reached_the_os } }
      end
    end

    before do
      stub_const(RealKeychainFence::WINDOWS_MANAGER, windows_manager)
      RealKeychainFence.apply
    end

    RealKeychainFence::WINDOWS_METHODS.each do |name|
      it "raises with the fence message from #{name}" do
        expect { windows_manager.public_send(name, 'target') }
          .to raise_error(RealKeychainFence::Reached, /#{name}.*would touch the real keychain/)
      end
    end

    it 'lets an example stub of a Windows call win' do
      allow(windows_manager).to receive(:CredWriteW).and_return(true)

      expect(windows_manager.CredWriteW('target')).to be true
    end
  end

  describe 'Open3.capture3' do
    it 'raises for the macOS and Linux keychain tools by bare name' do
      %w[security secret-tool].each do |tool|
        expect { Open3.capture3(tool, 'lookup') }
          .to raise_error(RealKeychainFence::Reached, /Open3\.capture3\(#{tool}\).*would touch the real keychain/)
      end
    end

    it 'recognizes the keychain tools by absolute path' do
      expect('/usr/bin/security').to match(RealKeychainFence::TOOL)
      expect('/usr/bin/secret-tool').to match(RealKeychainFence::TOOL)
      expect('/usr/bin/security-wrapper').not_to match(RealKeychainFence::TOOL)
    end

    it 'passes an unrelated command through, options included' do
      output, error, status = Open3.capture3('cat', stdin_data: 'passed through')

      expect([output, error, status.success?]).to eq(['passed through', '', true])
    end

    it 'lets an example stub of Open3.capture3 win' do
      status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture3).and_return(['stubbed', '', status])

      expect(Open3.capture3('security', 'lookup').first).to eq('stubbed')
    end
  end

  describe 'in a group that defines its own allow and receive helpers' do
    def allow(*)
      raise 'the fence must not use the example allow helper'
    end

    def receive(*)
      raise 'the fence must not use the example receive helper'
    end

    it 'still fences' do
      expect { Open3.capture3('secret-tool', 'lookup') }.to raise_error(RealKeychainFence::Reached)
    end
  end

  describe 'opt-out' do
    def own_definition?(owner, name)
      owner.method(name).source_location.first.include?('/rspec-mocks')
    end

    it 'fences by default' do
      expect(own_definition?(Open3, :capture3)).to be true
      expect(own_definition?(manager, :store_linux_keychain)).to be true
    end

    it 'leaves everything unfenced with real_keychain: true', real_keychain: true do
      expect(own_definition?(Open3, :capture3)).to be false
      expect(own_definition?(manager, :store_linux_keychain)).to be false
    end
  end
end
