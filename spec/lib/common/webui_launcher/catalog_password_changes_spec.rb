# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../spec_helper'
require_relative '../../../login_spec_helper'
require 'common/webui_launcher/catalog'

RSpec.describe Lich::Common::WebUILauncher::Catalog, 'password changes through the entry store' do
  let(:data_dir) { Dir.mktmpdir('webui-catalog') }
  let(:manager) { Lich::Common::GUI::MasterPasswordManager }
  let(:entry_store) { Lich::Common::Authentication::EntryStore }
  let(:catalog) { described_class.new(data_dir: data_dir, entry_store: entry_store, master_password_manager: manager) }
  let(:current_master) { 'synthetic-current-master' }
  let(:new_master) { 'synthetic-new-master' }
  let(:path) { File.join(data_dir, 'entry.yaml') }
  let(:keychain) { { password: current_master } }

  before do
    encrypted = entry_store.encrypt_password('server-origin-canary', mode: :enhanced, account_name: 'DOUG',
                                                                     master_password: current_master)
    File.write(path, YAML.dump(
                       'encryption_mode' => 'enhanced', 'master_password_validation_test' => 'old-validation',
                       'accounts' => { 'DOUG' => { 'password' => encrypted, 'characters' => [] } }
                     ))
    allow(manager).to receive(:validate_master_password).and_return(true)
    allow(manager).to receive(:create_validation_test).and_return('new-validation')
    allow(manager).to receive(:retrieve_master_password) { |**| keychain[:password] }
    allow(manager).to receive(:store_master_password) do |password|
      keychain[:password] = password
      true
    end
  end

  after { FileUtils.remove_entry(data_dir) }

  describe '#change_master_password' do
    it 'publishes the re-encrypted accounts through the catalog manager' do
      expect(catalog.change_master_password(current_master, new_master)).to be(true)

      saved = YAML.safe_load_file(path)
      expect(saved['master_password_validation_test']).to eq('new-validation')
      expect(keychain[:password]).to eq(new_master)
      expect(entry_store.decrypt_password(saved['accounts']['DOUG']['password'], mode: :enhanced,
                                                                               account_name: 'DOUG', master_password: new_master))
        .to eq('server-origin-canary')
    end
  end

  describe '#change_encryption_mode' do
    it 'drives the entry store through the catalog manager, never the real module' do
      injected = class_double(Lich::Common::GUI::MasterPasswordManager)
      allow(injected).to receive(:retrieve_master_password) { |**| keychain[:password] }
      allow(injected).to receive(:delete_master_password) do
        keychain[:password] = nil
        true
      end
      isolated = described_class.new(data_dir: data_dir, entry_store: entry_store, master_password_manager: injected)
      allow(manager).to receive(:delete_master_password).and_raise('real keychain reached')

      expect(isolated.change_encryption_mode(:standard)).to be(true)

      expect(YAML.safe_load_file(path)['encryption_mode']).to eq('standard')
      expect(keychain[:password]).to be_nil
      expect(injected).to have_received(:delete_master_password)
      expect(manager).not_to have_received(:delete_master_password)
    end
  end

  describe '#change_account_password' do
    it 'asks for the master password when enhanced encryption has none in the keychain' do
      keychain[:password] = nil
      before = File.binread(path)

      expect { catalog.change_account_password('DOUG', 'server-origin-canary', 'replacement') }
        .to raise_error(described_class::MasterPasswordRequired)
      expect(File.binread(path)).to eq(before)
    end

    it 'changes the account password when the master password is unlocked' do
      expect(catalog.change_account_password('DOUG', 'server-origin-canary', 'replacement')).to be(true)

      saved = YAML.safe_load_file(path)
      expect(entry_store.decrypt_password(saved['accounts']['DOUG']['password'], mode: :enhanced,
                                                                               account_name: 'DOUG', master_password: current_master))
        .to eq('replacement')
    end
  end
end
