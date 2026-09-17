# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../spec_helper'
require_relative '../../../login_spec_helper'
require 'common/webui_launcher/catalog'

RSpec.describe Lich::Common::WebUILauncher::Catalog, 'the saved entry is the one acted on' do
  # Review 2026-09-17 (b), F6: the launcher saved a manual entry and then
  # looked it up again by account, character, game and frontend -- the
  # first of two entries differing only in their custom launch command,
  # which may be the other one. The save answers with the key it wrote.
  it 'answers an upsert with the key of that entry, and sets the favorite on it alone' do
    Dir.mktmpdir('webui-catalog') do |dir|
      catalog = described_class.new(data_dir: dir)
      first = { user_id: 'REVIEW', char_name: 'Char', game_code: 'GS3', game_name: 'Game', frontend: 'stormfront', custom_launch: 'command-one' }
      second = first.merge(custom_launch: 'command-two')
      first_key = catalog.upsert_manual_entry(first, 'synthetic')
      second_key = catalog.upsert_manual_entry(second, 'synthetic')

      expect([first_key, second_key]).to all(start_with('entry-'))
      expect(first_key).not_to eq(second_key)
      expect(catalog.entries.find { |entry| entry.key == second_key }.custom_launch).to eq('command-two')

      expect(catalog.set_favorite(second_key, true)).to be(true)
      expect(catalog.set_favorite(second_key, true)).to be(true)
      favorites = catalog.entries.select(&:favorite).map(&:custom_launch)
      expect(favorites).to eq(['command-two'])
      expect(catalog.upsert_manual_entry(second, 'synthetic')).to eq(second_key)
    end
  end
end

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

  # Keys were generated from the enumeration position on every read, so
  # removing Alpha renamed Beta to Alpha's old key. A stale editor,
  # confirmation or queued operation holding Beta's key then acted on the
  # entry that had moved into it; another launcher or process editing the
  # shared file was enough to bring that about.
  it 'keeps an entry key stable when another process removes an earlier entry' do
    %w[Aldor Cyra].each do |name|
      catalog.add_character('DOUG', {
        char_name: name, game_code: 'GS3', game_name: 'GemStone IV', frontend: 'stormfront',
        custom_launch: nil, custom_launch_dir: nil,
      })
    end
    before = catalog.entries.to_h { |entry| [entry.char_name, entry.key] }
    expect(before.values.uniq.length).to eq(3)

    other_process = described_class.new(data_dir: data_dir, master_password_manager: manager)
    expect(other_process.remove_entry(before.fetch('Bera'))).to be(true)

    after = catalog.entries.to_h { |entry| [entry.char_name, entry.key] }
    expect(after.fetch('Aldor')).to eq(before.fetch('Aldor'))
    expect(after.fetch('Cyra')).to eq(before.fetch('Cyra'))
    expect(after).not_to have_value(before.fetch('Bera'))
    expect { catalog.credential(before.fetch('Bera')) }.to raise_error(KeyError)
  end

  # The catalog permits the same character under one account with different
  # frontends or custom launch commands. Those were told apart by an ordinal
  # on the shared digest, so removing the first moved the second onto the
  # first's key (review 2026-09-17, R8).
  it 'keeps the key of a same-character entry when its sibling with another frontend is removed' do
    %w[stormfront wizard].each do |frontend|
      catalog.add_character('DOUG', {
        char_name: 'Aldor', game_code: 'GS3', game_name: 'GemStone IV', frontend: frontend,
        custom_launch: nil, custom_launch_dir: nil,
      })
    end
    catalog.add_character('DOUG', {
      char_name: 'Aldor', game_code: 'GS3', game_name: 'GemStone IV', frontend: 'stormfront',
      custom_launch: 'custom.exe %1', custom_launch_dir: nil,
    })
    keys_of = ->(entries) { entries.to_h { |entry| [[entry.frontend, entry.custom_launch], entry.key] } }
    before = keys_of.call(catalog.entries.select { |entry| entry.char_name == 'Aldor' })
    expect(before.keys).to contain_exactly(['stormfront', nil], ['wizard', nil], ['stormfront', 'custom.exe %1'])
    expect(before.values).to all(match(/\Aentry-[0-9a-f]{12}\z/)), 'no entry needs an ordinal'

    expect(catalog.remove_entry(before.fetch(['stormfront', nil]))).to be(true)
    after = keys_of.call(catalog.entries.select { |entry| entry.char_name == 'Aldor' })
    expect(after.fetch(['wizard', nil])).to eq(before.fetch(['wizard', nil]))
    expect(after.fetch(['stormfront', 'custom.exe %1'])).to eq(before.fetch(['stormfront', 'custom.exe %1']))
    expect { catalog.credential(before.fetch(['stormfront', nil])) }.to raise_error(KeyError)
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
