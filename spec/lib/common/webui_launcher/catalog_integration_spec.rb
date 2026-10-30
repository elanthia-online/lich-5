# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../spec_helper'
require_relative '../../../login_spec_helper'
require 'common/webui_launcher/catalog'

RSpec.describe Lich::Common::WebUILauncher::Catalog, 'real entry-store integration' do
  let(:data_dir) { Dir.mktmpdir('webui-catalog') }
  let(:manager) do
    Class.new do
      def self.keychain_available? = true
      def self.retrieve_master_password = nil
    end
  end
  let(:catalog) { described_class.new(data_dir: data_dir, master_password_manager: manager) }

  before do
    File.write(File.join(data_dir, 'entry.yaml'), YAML.dump({
      'encryption_mode' => 'plaintext',
      'accounts'        => {
        'DOUG' => {
          'password'   => 'server-origin-canary',
          'characters' => [{
            'char_name' => 'Bera', 'game_code' => 'DR', 'game_name' => 'DragonRealms',
            'frontend' => 'wizard', 'is_favorite' => false,
          }],
        },
      },
    }))
  end

  after { FileUtils.remove_entry(data_dir) }

  it 'reads, sorts, mutates, persists, reloads, and removes real saved entries' do
    entry = catalog.entries.first
    expect(entry.char_name).to eq('Bera')
    expect(catalog.credential(entry.key).consume(&:dup)).to eq('server-origin-canary')

    expect(catalog.toggle_favorite(entry.key)).to be(true)
    expect(catalog.add_character('DOUG', {
      char_name: 'aldor', game_code: 'GS3', game_name: 'GemStone IV', frontend: 'stormfront',
      custom_launch: nil, custom_launch_dir: nil,
    })).to be(true)
    aldor = catalog.entries(autosort: true).find { |item| item.char_name == 'Aldor' }
    expect(catalog.update_character(aldor.key, {
      char_name: 'aldor prime', game_code: 'GS3', game_name: 'GemStone IV', frontend: 'stormfront',
      custom_launch: nil, custom_launch_dir: nil,
    })).to be(true)

    reloaded = described_class.new(data_dir: data_dir, master_password_manager: manager)
    expect(reloaded.entries.map(&:char_name)).to contain_exactly('Bera', 'Aldor Prime')
    expect(reloaded.entries.find { |item| item.char_name == 'Bera' }.favorite).to be(true)
    expect(reloaded.remove_entry(reloaded.entries.find { |item| item.char_name == 'Aldor Prime' }.key)).to be(true)
    expect(reloaded.remove_account('DOUG')).to be(true)
    expect(reloaded.entries).to be_empty
  end

  it 'edits one launch configuration without changing credentials or favorite metadata' do
    path = File.join(data_dir, 'entry.yaml')
    original = YAML.safe_load_file(path)
    original['master_password_validation_test'] = 'opaque-validation'
    character = original['accounts']['DOUG']['characters'].first
    character['is_favorite'] = true
    character['favorite_order'] = 3
    original['accounts']['DOUG']['characters'] << character.merge('custom_launch' => '/opt/other-client')
    File.write(path, YAML.dump(original))
    selected = catalog.entries.find { |entry| entry.custom_launch.nil? }
    expect(catalog.update_character(selected.key, selected.to_h.merge(frontend: 'profanity'))).to be(true)
    expected = Marshal.load(Marshal.dump(original))
    expected['accounts']['DOUG']['characters'].first.merge!('frontend' => 'profanity', 'custom_launch' => nil, 'custom_launch_dir' => nil)
    expect(YAML.safe_load_file(path)).to eq(expected)
    expect(catalog.update_character('stale-key', selected.to_h)).to be(false)
    expect(YAML.safe_load_file(path)).to eq(expected)
  end

  it 'reports an indeterminate favorite state when persistence fails' do
    entry = catalog.entries.first
    allow(catalog).to receive(:write_yaml).and_return(false)

    expect(catalog.toggle_favorite(entry.key)).to be_nil
  end

  it 'keeps surviving keys stable and refuses deleted keys after list positions change' do
    original = catalog.entries.first
    catalog.upsert_manual_entry(original.to_h.merge(char_name: 'Cera'), 'synthetic-password')
    survivor = catalog.entries.find { |entry| entry.char_name == 'Cera' }
    expect(catalog.remove_entry(original.key)).to be(true)

    expect(catalog.entries.first.key).to eq(survivor.key)
    expect(catalog.remove_entry(original.key)).to be(false)
    expect { catalog.credential(original.key) }.to raise_error(KeyError)
    expect(catalog.entries.map(&:char_name)).to eq(['Cera'])
    expect(catalog.toggle_favorite(survivor.key)).to be(true)
    expect(catalog.entries.first.key).to eq(survivor.key)
  end

  it 'gives custom-launch variants different keys without exposing their identity fields' do
    original = catalog.entries.first
    catalog.upsert_manual_entry(original.to_h.merge(custom_launch: '/synthetic/client'), 'synthetic-password')
    entries = catalog.entries
    expect(entries.map(&:key).uniq.size).to eq(2)
    expect(entries.map(&:key).join).not_to include('DOUG', 'Bera', '/synthetic/client')
    expect(described_class.new(data_dir: data_dir).entries.map(&:key)).to eq(entries.map(&:key))
  end

  it 'keeps pre-existing duplicate configurations renderable with distinct keys' do
    path = File.join(data_dir, 'entry.yaml')
    data = YAML.safe_load_file(path)
    characters = data['accounts']['DOUG']['characters']
    characters << characters.first.dup
    File.write(path, YAML.dump(data))

    keys = catalog.entries.map(&:key)
    expect(keys.uniq.size).to eq(2)
    expect(catalog.entries.map(&:key)).to eq(keys)
    expect(catalog.entries.map(&:char_name)).to eq(%w[Bera Bera])
  end

  it 'preserves saved order with AutoSort off and uses the established sorter when enabled' do
    path = File.join(data_dir, 'entry.yaml')
    data = YAML.safe_load_file(path)
    characters = (1..40).map do |index|
      { 'char_name' => format('C%02d', index), 'game_code' => 'GS3', 'game_name' => 'GemStone IV', 'frontend' => 'stormfront' }
    end
    characters[5].merge!('is_favorite' => true, 'favorite_order' => 2)
    characters[12].merge!('is_favorite' => true, 'favorite_order' => 1)
    data['accounts']['DOUG']['characters'] = characters
    File.write(path, YAML.dump(data))
    expect(catalog.entries.map(&:char_name)).to eq(characters.map { |character| character['char_name'] })
    expect(catalog.entries(autosort: true).map(&:char_name)).to eq(%w[C13 C06] + characters.reject { |character| character['is_favorite'] }.map { |character| character['char_name'] })
  end

  { empty: '', comment_only: "# No saved entries yet\n", null: "--- null\n" }.each do |kind, document|
    it "treats a #{kind} YAML document as an empty writable catalog" do
      path = File.join(data_dir, 'entry.yaml')
      File.write(path, document)

      expect(catalog.entries).to be_empty
      expect(catalog.accounts).to be_empty
      expect(catalog.encryption_mode).to eq(:plaintext)
      expect(File.read(path)).to eq(document)
      expect(catalog.upsert_manual_entry({ user_id: 'OTHER', char_name: 'New', game_code: 'GS3', frontend: 'stormfront' }, 'synthetic')).to be(true)
      expect(catalog.entries.map(&:char_name)).to eq(['New'])
    end
  end

  ["false\n", "[]\n"].each do |document|
    it "refuses the non-nil invalid catalog #{document.strip}" do
      path = File.join(data_dir, 'entry.yaml')
      File.write(path, document)

      expect { catalog.entries }.to raise_error(described_class::InvalidCatalogError)
      expect do
        catalog.upsert_manual_entry({ user_id: 'OTHER', char_name: 'New', game_code: 'GS3', frontend: 'stormfront' }, 'synthetic')
      end.to raise_error(described_class::InvalidCatalogError)
      expect(File.read(path)).to eq(document)
    end
  end

  it 'refuses writes rather than replacing a damaged catalog with an empty one' do
    path = File.join(data_dir, 'entry.yaml')
    damaged = "accounts: [unclosed\n"
    File.write(path, damaged)
    expect do
      catalog.upsert_manual_entry({ user_id: 'OTHER', char_name: 'New', game_code: 'GS3', frontend: 'stormfront' }, 'synthetic')
    end.to raise_error(described_class::InvalidCatalogError)
    expect(File.read(path)).to eq(damaged)
  end

  it 'normalizes missing display names before applying the established sorter' do
    path = File.join(data_dir, 'entry.yaml')
    data = YAML.safe_load_file(path)
    data['accounts']['DOUG']['characters'] << { 'char_name' => 'Aldor', 'game_code' => 'GS3', 'frontend' => 'stormfront' }
    File.write(path, YAML.dump(data))
    expect(catalog.entries(autosort: true).map(&:char_name)).to eq(%w[Aldor Bera])
  end

  describe 'master-password changes' do
    let(:current_password) { 'synthetic-current-master' }
    let(:new_password) { 'synthetic-new-master' }
    let(:entry_store) { Lich::Common::Authentication::EntryStore }
    let(:manager) do
      double('master password manager', validate_master_password: true,
                                       create_validation_test: 'new-validation', store_master_password: true)
    end
    let(:plaintexts) { [] }
    let(:keychain) { { password: current_password } }
    let(:path) { File.join(data_dir, 'entry.yaml') }

    before do
      allow(manager).to receive(:retrieve_master_password).with(strict: true) { keychain[:password] }
      allow(manager).to receive(:store_master_password) do |password|
        keychain[:password] = password
        true
      end
      data = YAML.load_file(path)
      data['encryption_mode'] = 'enhanced'
      data['master_password_validation_test'] = 'old-validation'
      data['accounts']['OTHER'] = { 'password' => 'second-account-canary', 'characters' => [] }
      data['accounts'].each do |name, account|
        account['password'] = entry_store.encrypt_password(
          account['password'], mode: :enhanced, account_name: name, master_password: current_password
        )
      end
      File.write(path, YAML.dump(data))
      allow(entry_store).to receive(:decrypt_password).and_wrap_original do |original, *args, **kwargs|
        original.call(*args, **kwargs).tap { |plaintext| plaintexts << plaintext }
      end
    end

    it 'persists re-encrypted accounts and clears each temporary plaintext' do
      expect(catalog.change_master_password(current_password, new_password)).to be(true)
      expect(plaintexts.size).to eq(2)
      expect(plaintexts).to all(eq(''))
      saved = YAML.load_file(path)
      expect(saved['master_password_validation_test']).to eq('new-validation')
      expect(manager).to have_received(:store_master_password).with(new_password).once
      expected = { 'DOUG' => 'server-origin-canary', 'OTHER' => 'second-account-canary' }
      expected.each do |name, password|
        expect(entry_store.decrypt_password(saved['accounts'][name]['password'], mode: :enhanced,
                                                                               account_name: name, master_password: new_password)).to eq(password)
      end
    end

    it 'retains matching YAML and keychain state if directory syncing fails after publication' do
      allow(OS).to receive(:windows?).and_return(false)
      directory = instance_double(File)
      allow(directory).to receive(:fsync).and_raise(Errno::EINVAL)
      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with(data_dir, File::RDONLY).and_yield(directory)

      expect(catalog.change_master_password(current_password, new_password)).to be(true)
      expect(manager).to have_received(:store_master_password).with(new_password).once
      expect(manager).not_to have_received(:store_master_password).with(current_password)
      saved = YAML.safe_load_file(path)
      expect(entry_store.decrypt_password(saved['accounts']['DOUG']['password'], mode: :enhanced,
                                                                               account_name: 'DOUG', master_password: new_password)).to eq('server-origin-canary')
    end

    it 'returns false without changing persisted data when validation fails' do
      allow(manager).to receive(:validate_master_password).and_return(false)
      before = File.binread(path)

      expect(catalog.change_master_password(current_password, new_password)).to be(false)
      expect(File.binread(path)).to eq(before)
      expect(manager).not_to have_received(:store_master_password)
      expect(plaintexts).to be_empty
    end

    it 'clears temporary plaintext and preserves the original encryption exception' do
      allow(entry_store).to receive(:encrypt_password).and_raise(IOError, 'synthetic encryption failure')
      before = File.binread(path)

      expect { catalog.change_master_password(current_password, new_password) }
        .to raise_error(IOError, 'synthetic encryption failure')
      expect(plaintexts).to eq([''])
      expect(File.binread(path)).to eq(before)
      expect(manager).not_to have_received(:store_master_password)
    end

    it 'restores the previous keychain value when persistence fails' do
      allow(File).to receive(:rename).and_raise(IOError, 'synthetic publication failure')
      before = File.binread(path)

      expect(catalog.change_master_password(current_password, new_password)).to be(false)
      expect(manager).to have_received(:store_master_password).with(new_password).once
      expect(manager).to have_received(:store_master_password).with(current_password).once
      expect(keychain[:password]).to eq(current_password)
      expect(File.binread(path)).to eq(before)
      expect(plaintexts).to all(eq(''))
    end

    it 'restores the observed keychain value when storage mutates it before reporting failure' do
      observed = 'synthetic-observed-keychain'
      keychain[:password] = observed
      allow(manager).to receive(:store_master_password) do |password|
        keychain[:password] = password
        password != new_password
      end
      before = File.binread(path)

      expect(catalog.change_master_password(current_password, new_password)).to be(false)
      expect(keychain[:password]).to eq(observed)
      expect(File.binread(path)).to eq(before)
      expect(plaintexts).to all(eq(''))
    end

    it 'refuses publication if the previous keychain state cannot be read' do
      allow(manager).to receive(:retrieve_master_password).with(strict: true).and_raise(IOError, 'synthetic read failure')
      before = File.binread(path)

      expect(catalog.change_master_password(current_password, new_password)).to be(false)
      expect(manager).not_to have_received(:store_master_password)
      expect(File.binread(path)).to eq(before)
    end

    %i[decrypt_password encrypt_password].each do |operation|
      it "refuses publication when #{operation} returns no credential" do
        allow(entry_store).to receive(operation).and_return(nil)
        before = File.binread(path)

        expect(catalog.change_master_password(current_password, new_password)).to be(false)
        expect(manager).not_to have_received(:store_master_password)
        expect(File.binread(path)).to eq(before)
        expect(plaintexts).to all(eq(''))
      end
    end
  end

  describe 'legacy entries without a YAML catalog' do
    let(:legacy_entries) do
      %w[Aldor Bera].map do |name|
        { user_id: 'DOUG', password: 'synthetic-legacy-password', char_name: name,
          game_code: 'GS3', game_name: 'GemStone IV', frontend: 'stormfront' }
      end
    end
    let(:legacy_path) { File.join(data_dir, 'entry.dat') }
    let(:yaml_path) { File.join(data_dir, 'entry.yaml') }

    before do
      File.unlink(yaml_path)
      File.binwrite(legacy_path, [Marshal.dump(legacy_entries)].pack('m'))
    end

    %i[manual account].each do |kind|
      it "refuses a partial #{kind} save while retaining every legacy entry" do
        original = File.binread(legacy_path)
        expect do
          if kind == :manual
            catalog.upsert_manual_entry(legacy_entries.first, 'replacement-password')
          else
            catalog.add_or_update_account('OTHER', 'replacement-password', [legacy_entries.first], frontend: 'stormfront')
          end
        end.to raise_error(described_class::LegacyConversionRequired)

        expect(File.exist?(yaml_path)).to be(false)
        expect(File.binread(legacy_path)).to eq(original)
        expect(catalog.entries.map(&:char_name)).to contain_exactly('Aldor', 'Bera')
        expect(catalog.legacy_conversion_needed?).to be(true)
      end
    end

    %i[plaintext standard enhanced].each do |mode|
      it "migrates real legacy data through EntryStore and reads it through the catalog in #{mode} mode" do
        master = mode == :enhanced ? 'synthetic-migration-master' : nil
        manager = Lich::Common::GUI::MasterPasswordManager
        allow(manager).to receive(:retrieve_master_password).and_return(master)
        allow(manager).to receive(:create_validation_test).with(master).and_call_original
        expect(manager).not_to receive(:store_master_password)

        expect(Lich::Common::Authentication::EntryStore.migrate_from_legacy(data_dir, encryption_mode: mode)).to be(true)

        saved = YAML.safe_load_file(yaml_path)
        expect(saved['encryption_mode']).to eq(mode.to_s)
        if master
          expect(manager.validate_master_password(master, saved['master_password_validation_test'])).to be(true)
        end
        catalog.entries.each do |entry|
          expect(catalog.credential(entry.key, master_password: master).consume(&:dup)).to eq('synthetic-legacy-password')
        end
        expect(catalog.entries.map(&:char_name)).to contain_exactly('Aldor', 'Bera')
      end
    end
  end

  it 'rejects a legacy payload containing nested objects' do
    legacy_dir = Dir.mktmpdir('webui-legacy-catalog')
    payload = [{ 'user_id' => 'DOUG', 'password' => { 'nested' => 'not allowed' } }]
    File.binwrite(File.join(legacy_dir, 'entry.dat'), [Marshal.dump(payload)].pack('m'))
    legacy_catalog = described_class.new(data_dir: legacy_dir, master_password_manager: manager)

    expect(legacy_catalog.entries).to be_empty
  ensure
    FileUtils.remove_entry(legacy_dir) if legacy_dir && File.directory?(legacy_dir)
  end

  describe 'account and character write compatibility' do
    let(:path) { File.join(data_dir, 'entry.yaml') }
    let(:character) { { char_name: '  cERA   TWO ', game_code: 'GS3', frontend: 'wizard' } }
    let(:store) { Lich::Common::Authentication::EntryStore }

    %w[plaintext standard enhanced].each do |mode|
      it "preserves #{mode} password preparation for manual and account writes" do
        data = YAML.safe_load_file(path)
        data['encryption_mode'] = mode
        File.write(path, YAML.dump(data))
        allow(manager).to receive(:retrieve_master_password).and_return('synthetic-master')
        master = mode == 'enhanced' ? 'synthetic-master' : nil
        expect(store).to receive(:encrypt_password)
          .with('synthetic-manual', mode: mode.to_sym, account_name: 'MANUAL', master_password: master).and_call_original
        expect(store).to receive(:encrypt_password)
          .with('synthetic-account', mode: mode.to_sym, account_name: 'ACCOUNT', master_password: master).and_call_original

        expect(catalog.upsert_manual_entry(character.merge(user_id: 'manual'), 'synthetic-manual')).to be(true)
        expect(catalog.add_or_update_account('account', 'synthetic-account', [character], frontend: 'wizard')).to be(true)
        saved = YAML.safe_load_file(path)
        %w[MANUAL ACCOUNT].zip(%w[synthetic-manual synthetic-account]).each do |name, password|
          expect(store.decrypt_password(saved['accounts'][name]['password'], mode: mode.to_sym,
                                                                               account_name: name, master_password: master)).to eq(password)
        end
        expect(saved['accounts']['MANUAL']['characters']).to eq([{
          'char_name' => 'Cera Two', 'game_code' => 'GS3', 'game_name' => '', 'frontend' => 'wizard',
          'custom_launch' => nil, 'custom_launch_dir' => nil,
        }])
        expect(saved['accounts']['ACCOUNT']['characters']).to eq([{
          'char_name' => 'Cera Two', 'game_code' => 'GS3', 'game_name' => '', 'frontend' => 'wizard',
        }])
      end
    end

    [nil, ''].each do |master|
      it "refuses both enhanced account writes with a #{master.inspect} master before encryption or persistence" do
        data = YAML.safe_load_file(path)
        data['encryption_mode'] = 'enhanced'
        File.write(path, YAML.dump(data))
        before = File.binread(path)
        allow(manager).to receive(:retrieve_master_password).and_return(master)
        expect(store).not_to receive(:encrypt_password)
        expect(store).not_to receive(:write_yaml_file)

        expect { catalog.upsert_manual_entry(character.merge(user_id: 'manual'), 'synthetic') }
          .to raise_error(described_class::MasterPasswordRequired, 'master password is required')
        expect { catalog.add_or_update_account('account', 'synthetic', [], frontend: 'wizard') }
          .to raise_error(described_class::MasterPasswordRequired, 'master password is required')
        expect(File.binread(path)).to eq(before)
      end
    end

    it 'retains required character fields and rejects missing names before writing' do
      before = File.binread(path)
      expect { catalog.add_character('DOUG', character) }.to raise_error(KeyError) { |error| expect(error.key).to eq(:game_name) }
      key = catalog.entries.first.key
      expect { catalog.update_character(key, character) }.to raise_error(KeyError) { |error| expect(error.key).to eq(:game_name) }
      expect { catalog.add_character('DOUG', character.except(:char_name)) }
        .to raise_error(KeyError) { |error| expect(error.key).to eq(:char_name) }
      expect(File.binread(path)).to eq(before)
    end

    it 'preserves character projection, identity and metadata while account matching ignores custom commands' do
      data = YAML.safe_load_file(path)
      saved = data['accounts']['DOUG']['characters'].first
      saved.merge!('custom_launch' => '/old', 'is_favorite' => true, 'favorite_order' => 2, 'extension' => 'retained')
      File.write(path, YAML.dump(data))
      entry = catalog.entries.first
      incoming = entry.to_h.merge(char_name: 'bera', game_name: 'changed label', custom_launch_dir: '/new')
      expect(catalog.upsert_manual_entry(incoming, 'synthetic')).to be(true)
      expect(catalog.entries.first.key).to eq(entry.key)
      expect(catalog.add_or_update_account('doug', 'synthetic', [incoming], frontend: 'wizard')).to be(true)
      expect(catalog.entries.size).to eq(1)
      expect(YAML.safe_load_file(path)['accounts']['DOUG']['characters'].first).to eq(
        saved.merge('game_name' => 'changed label', 'custom_launch_dir' => '/new')
      )
      expect(catalog.add_character('doug', character.merge(game_name: nil))).to be(true)
      added = catalog.entries.find { |item| item.char_name == 'Cera Two' }
      expect(catalog.update_character(added.key, character.merge(char_name: '  cERA THREE ', game_name: nil))).to be(true)
      expect(YAML.safe_load_file(path)['accounts']['DOUG']['characters'].last).to eq({
        'char_name' => 'Cera Three', 'game_code' => 'GS3', 'game_name' => '', 'frontend' => 'wizard',
        'custom_launch' => nil, 'custom_launch_dir' => nil,
      })
    end

    it 'returns false for either account writer failure without changing the persisted catalog' do
      before = File.binread(path)
      allow(store).to receive(:write_yaml_file).and_raise(IOError, 'synthetic write failure')

      expect(catalog.upsert_manual_entry(character.merge(user_id: 'manual'), 'synthetic')).to be(false)
      expect(catalog.add_or_update_account('account', 'synthetic', [character], frontend: 'wizard')).to be(false)
      expect(File.binread(path)).to eq(before)
    end
  end
end
