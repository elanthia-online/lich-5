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

  it 'reports an indeterminate favorite state when persistence fails' do
    entry = catalog.entries.first
    allow(catalog).to receive(:write_yaml).and_return(false)

    expect(catalog.toggle_favorite(entry.key)).to be_nil
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
end
