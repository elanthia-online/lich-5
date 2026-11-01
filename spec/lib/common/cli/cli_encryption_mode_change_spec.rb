# frozen_string_literal: true

require 'stringio'
require 'tmpdir'

require_relative '../../../spec_helper'
require_relative '../../../login_spec_helper'
require_relative '../../../../lib/common/cli/cli_encryption_mode_change'

RSpec.describe Lich::Common::CLI::EncryptionModeChange do
  let(:data_dir) { Dir.mktmpdir('cli-mode-change') }
  let(:entry_store) { Lich::Common::Authentication::EntryStore }
  let(:manager) { Lich::Common::GUI::MasterPasswordManager }
  let(:minimum) { manager::MIN_PASSWORD_LENGTH }

  around do |example|
    original_stdout = $stdout
    $stdout = StringIO.new
    example.run
  ensure
    $stdout = original_stdout
    FileUtils.remove_entry(data_dir)
  end

  before do
    stub_const('DATA_DIR', data_dir)
    File.write(entry_store.yaml_file_path(data_dir), YAML.dump('encryption_mode' => 'plaintext', 'accounts' => {}))
    allow(Lich).to receive(:log)
  end

  describe '.change_mode' do
    it 'hands the domain method the credential provider it must use' do
      allow(entry_store).to receive(:change_encryption_mode).and_return(true)

      expect(described_class.change_mode(:enhanced, 'synthetic-master')).to eq(0)

      expect(entry_store).to have_received(:change_encryption_mode)
        .with(data_dir, :enhanced, 'synthetic-master', manager: Lich::Common::GUI::MasterPasswordManager)
    end
  end

  describe '.change_mode to enhanced with a --master-password value' do
    before { allow(entry_store).to receive(:change_encryption_mode).and_return(true) }

    it 'refuses a password shorter than the shared minimum before writing anything' do
      short = 'x' * (minimum - 1)

      expect(described_class.change_mode(:enhanced, short)).to eq(1)
      expect(entry_store).not_to have_received(:change_encryption_mode)
      expect($stdout.string).to include("error: New master password must be at least #{minimum} characters.")
    end

    it 'refuses a password with edge whitespace through the shared new-password check' do
      allow(manager).to receive(:new_password_refusal).and_call_original

      expect(described_class.change_mode(:enhanced, ' padded-secret ')).to eq(1)
      expect(manager).to have_received(:new_password_refusal).with(' padded-secret ')
      expect(entry_store).not_to have_received(:change_encryption_mode)
      expect($stdout.string).to include('error: New master password cannot begin or end with whitespace.')
    end

    it 'accepts a password of exactly the minimum length' do
      exact = 'x' * minimum

      expect(described_class.change_mode(:enhanced, exact)).to eq(0)
      expect(entry_store).to have_received(:change_encryption_mode)
        .with(data_dir, :enhanced, exact, manager: Lich::Common::GUI::MasterPasswordManager)
    end
  end

  describe '.change_mode to enhanced with a prompted password' do
    before do
      # Synthetic credential store only: no keychain is read or written.
      allow(manager).to receive(:retrieve_master_password).and_return(nil)
      allow(manager).to receive(:new_password_refusal).and_call_original
      allow(entry_store).to receive(:change_encryption_mode).and_return(true)
    end

    it 'refuses a new password with edge whitespace through the shared check' do
      allow($stdin).to receive(:gets).and_return(" padded-secret\n", " padded-secret\n")

      expect(described_class.change_mode(:enhanced)).to eq(4)
      expect(manager).to have_received(:new_password_refusal).with(' padded-secret')
      expect(entry_store).not_to have_received(:change_encryption_mode)
      expect($stdout.string).to include('error: New master password cannot begin or end with whitespace.')
    end
  end

  describe '.change_mode leaving enhanced' do
    before do
      File.write(entry_store.yaml_file_path(data_dir),
                 YAML.dump('encryption_mode'                 => 'enhanced',
                           'master_password_validation_test' => manager.create_validation_test(existing),
                           'accounts'                        => {}))
      allow(entry_store).to receive(:change_encryption_mode).and_return(true)
    end

    context 'with a short existing master password' do
      let(:existing) { 'short' }

      it 'unlocks it as typed, with no length rule' do
        allow($stdin).to receive(:gets).and_return("short\n")

        expect(described_class.change_mode(:standard)).to eq(0)
        expect(entry_store).to have_received(:change_encryption_mode).with(data_dir, :standard, nil, manager: manager)
      end
    end

    context 'with an existing master password that has edge spaces' do
      let(:existing) { ' padded secret ' }

      it 'unlocks it with only the line terminator removed' do
        allow($stdin).to receive(:gets).and_return(" padded secret \n")

        expect(described_class.change_mode(:standard)).to eq(0)
        expect(entry_store).to have_received(:change_encryption_mode).with(data_dir, :standard, nil, manager: manager)
      end
    end
  end
end
