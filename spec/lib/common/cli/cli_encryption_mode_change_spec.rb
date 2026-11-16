# frozen_string_literal: true

require 'tmpdir'
require 'yaml'
require 'fileutils'
require_relative '../../../support/data_dir'
require_relative '../../../login_spec_helper'
require_relative '../../../../lib/common/cli/cli_encryption_mode_change'

RSpec.describe Lich::Common::CLI::EncryptionModeChange do
  let(:temp_dir) { Dir.mktmpdir }
  let(:yaml_file) { File.join(temp_dir, 'entry.yaml') }
  let(:entry_store) { Lich::Common::Authentication::EntryStore }
  let(:manager) { Lich::Common::GUI::MasterPasswordManager }
  let(:minimum) { manager::MIN_PASSWORD_LENGTH }

  before do
    File.write(yaml_file, YAML.dump('encryption_mode' => 'plaintext', 'accounts' => { 'DOUG' => { 'password' => 'synthetic' } }))
    allow(entry_store).to receive(:yaml_file_path).and_return(yaml_file)
    allow(entry_store).to receive(:change_encryption_mode).and_return(true)
    allow($stdout).to receive(:puts)
  end

  after { FileUtils.rm_rf(temp_dir) }

  describe '.change_mode to enhanced with a --master-password value' do
    it 'refuses a password shorter than the shared minimum before writing anything' do
      short = 'x' * (minimum - 1)

      expect(described_class.change_mode(:enhanced, short)).to eq(1)
      expect(entry_store).not_to have_received(:change_encryption_mode)
      expect($stdout).to have_received(:puts).with("error: New master password must be at least #{minimum} characters.")
    end

    it 'refuses a password with edge whitespace through the shared new-password check' do
      allow(manager).to receive(:new_password_refusal).and_call_original

      expect(described_class.change_mode(:enhanced, ' padded-secret ')).to eq(1)
      expect(manager).to have_received(:new_password_refusal).with(' padded-secret ')
      expect(entry_store).not_to have_received(:change_encryption_mode)
      expect($stdout).to have_received(:puts).with('error: New master password cannot begin or end with whitespace.')
    end

    it 'accepts a password of exactly the minimum length' do
      exact = 'x' * minimum

      expect(described_class.change_mode(:enhanced, exact)).to eq(0)
      expect(entry_store).to have_received(:change_encryption_mode).with(anything, :enhanced, exact)
    end
  end

  describe '.change_mode to enhanced with a prompted password' do
    before do
      # Synthetic credential store only: no keychain is read or written.
      allow(manager).to receive(:retrieve_master_password).and_return(nil)
      allow(manager).to receive(:new_password_refusal).and_call_original
      allow($stdout).to receive(:print)
    end

    it 'refuses a new password with edge whitespace through the shared check' do
      allow($stdin).to receive(:gets).and_return(" padded-secret\n", " padded-secret\n")

      expect(described_class.change_mode(:enhanced)).to eq(4)
      expect(manager).to have_received(:new_password_refusal).with(' padded-secret')
      expect(entry_store).not_to have_received(:change_encryption_mode)
      expect($stdout).to have_received(:puts).with('error: New master password cannot begin or end with whitespace.')
    end
  end

  describe '.change_mode leaving enhanced' do
    before do
      File.write(yaml_file, YAML.dump('encryption_mode'                 => 'enhanced',
                                      'master_password_validation_test' => manager.create_validation_test(existing),
                                      'accounts'                        => { 'DOUG' => { 'password' => 'synthetic' } }))
      allow($stdout).to receive(:print)
    end

    context 'with a short existing master password' do
      let(:existing) { 'short' }

      it 'unlocks it as typed, with no length rule' do
        allow($stdin).to receive(:gets).and_return("short\n")

        expect(described_class.change_mode(:standard)).to eq(0)
        expect(entry_store).to have_received(:change_encryption_mode).with(anything, :standard, nil)
      end
    end

    context 'with an existing master password that has edge spaces' do
      let(:existing) { ' padded secret ' }

      it 'unlocks it with only the line terminator removed' do
        allow($stdin).to receive(:gets).and_return(" padded secret \n")

        expect(described_class.change_mode(:standard)).to eq(0)
        expect(entry_store).to have_received(:change_encryption_mode).with(anything, :standard, nil)
      end
    end
  end
end
