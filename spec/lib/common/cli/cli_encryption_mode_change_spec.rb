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
  let(:minimum) { Lich::Common::GUI::MasterPasswordManager::MIN_PASSWORD_LENGTH }

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
      expect($stdout).to have_received(:puts).with("error: Password must be at least #{minimum} characters")
    end

    it 'accepts a password of exactly the minimum length' do
      exact = 'x' * minimum

      expect(described_class.change_mode(:enhanced, exact)).to eq(0)
      expect(entry_store).to have_received(:change_encryption_mode).with(anything, :enhanced, exact)
    end
  end
end
