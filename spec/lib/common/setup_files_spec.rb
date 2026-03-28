# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/settings_transformer'
require 'common/setup_files'

RSpec.describe Lich::Common::SetupFiles do
  let(:tmpdir) { Dir.mktmpdir('setup-files-test') }
  let(:profiles_dir) { File.join(tmpdir, 'profiles') }
  let(:data_dir) { File.join(tmpdir, 'data') }
  let(:setup_files) { described_class.new }

  before do
    stub_const('SCRIPT_DIR', tmpdir)
    FileUtils.mkdir_p(profiles_dir)
    FileUtils.mkdir_p(data_dir)
    allow(setup_files).to receive(:echo)
    allow(setup_files).to receive(:checkname).and_return('TestChar')
  end

  after { FileUtils.remove_entry(tmpdir, true) }

  describe 'FileInfo' do
    let(:file_info) do
      described_class::FileInfo.new(
        path: '/tmp',
        name: 'test.yaml',
        data: { setting: 'value', nested: { key: 'inner' } },
        mtime: Time.now
      )
    end

    it 'deep clones data to prevent mutation' do
      data1 = file_info.data
      data1[:setting] = 'changed'
      expect(file_info.data[:setting]).to eq('value')
    end

    it 'peeks at a single property with deep clone' do
      nested = file_info.peek(:nested)
      nested[:key] = 'mutated'
      expect(file_info.peek(:nested)[:key]).to eq('inner')
    end

    it 'returns nil for missing properties' do
      expect(file_info.peek(:missing)).to be_nil
    end

    it 'formats to_s as filepath' do
      expect(file_info.to_s).to eq('/tmp/test.yaml')
    end
  end

  describe '#get_settings' do
    before do
      File.write(File.join(profiles_dir, 'base.yaml'), { hometown: 'Crossing', loot_coins: true }.to_yaml)
      File.write(File.join(profiles_dir, 'base-empty.yaml'), { loot_additions: [], loot_subtractions: [] }.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), { hometown: 'Shard' }.to_yaml)
    end

    it 'returns an OpenStruct' do
      result = setup_files.get_settings
      expect(result).to be_a(OpenStruct)
    end

    it 'merges base and character settings (character wins)' do
      result = setup_files.get_settings
      expect(result.hometown).to eq('Shard')
    end

    it 'includes base defaults for nil settings' do
      result = setup_files.get_settings
      expect(result.loot_coins).to eq(true)
    end
  end

  describe '#get_data' do
    before do
      File.write(File.join(data_dir, 'base-spells.yaml'), { spell_data: { 'Shield' => { 'mana' => 3 } } }.to_yaml)
    end

    it 'returns data as an OpenStruct' do
      result = setup_files.get_data('spells')
      expect(result).to be_a(OpenStruct)
    end

    it 'loads data from the correct file' do
      result = setup_files.get_data('spells')
      expect(result.spell_data).to eq({ 'Shield' => { 'mana' => 3 } })
    end
  end

  describe '#reload' do
    before do
      File.write(File.join(profiles_dir, 'base.yaml'), { version: 1 }.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {}.to_yaml)
    end

    it 'reloads changed files' do
      setup_files.get_settings
      File.write(File.join(profiles_dir, 'base.yaml'), { version: 2 }.to_yaml)
      # Touch file to ensure mtime changes
      FileUtils.touch(File.join(profiles_dir, 'base.yaml'), mtime: Time.now + 1)
      setup_files.reload
      result = setup_files.get_settings
      expect(result.version).to eq(2)
    end
  end

  describe 'cascading includes' do
    before do
      File.write(File.join(profiles_dir, 'base.yaml'), { base_setting: true }.to_yaml)
      File.write(File.join(profiles_dir, 'base-empty.yaml'), {}.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), { include: ['combat'] }.to_yaml)
      File.write(File.join(profiles_dir, 'include-combat.yaml'), { combat_style: 'aggressive', include: ['weapons'] }.to_yaml)
      File.write(File.join(profiles_dir, 'include-weapons.yaml'), { primary_weapon: 'sword' }.to_yaml)
    end

    it 'resolves nested includes depth-first' do
      result = setup_files.get_settings
      expect(result.primary_weapon).to eq('sword')
      expect(result.combat_style).to eq('aggressive')
      expect(result.base_setting).to eq(true)
    end

    it 'character settings override included settings' do
      File.write(File.join(profiles_dir, 'include-combat.yaml'), { combat_style: 'aggressive', hometown: 'Dirge' }.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), { include: ['combat'], hometown: 'Shard' }.to_yaml)
      result = setup_files.get_settings
      expect(result.hometown).to eq('Shard')
    end
  end

  describe 'caching' do
    before do
      File.write(File.join(profiles_dir, 'base.yaml'), { cached: true }.to_yaml)
      File.write(File.join(profiles_dir, 'base-empty.yaml'), {}.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {}.to_yaml)
    end

    it 'does not re-read unchanged files' do
      setup_files.get_settings
      # Spy on safe_load_yaml to verify it's not called again
      expect(setup_files).not_to receive(:safe_load_yaml).with(File.join(profiles_dir, 'base.yaml'))
      setup_files.get_settings
    end
  end

  describe 'union_keys' do
    before do
      File.write(File.join(profiles_dir, 'base.yaml'), {
        'union_keys' => ['autostarts'],
        'autostarts' => %w[esp afk]
      }.to_yaml)
      File.write(File.join(profiles_dir, 'base-empty.yaml'), { 'empty_values' => {} }.to_yaml)
      File.write(File.join(data_dir, 'base-empty.yaml'), { 'empty_values' => {} }.to_yaml)
      File.write(File.join(data_dir, 'base-spells.yaml'), { 'spell_data' => {}, 'battle_cries' => {} }.to_yaml)
      File.write(File.join(data_dir, 'base-items.yaml'), {
        'lootables' => [], 'box_nouns' => [], 'gem_nouns' => [], 'scroll_nouns' => []
      }.to_yaml)
    end

    it 'unions arrays for keys listed in union_keys' do
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {
        'autostarts' => %w[healer moonwatch]
      }.to_yaml)
      settings = setup_files.get_settings
      expect(settings.autostarts).to match_array(%w[esp afk healer moonwatch])
    end

    it 'overwrites arrays for keys NOT listed in union_keys' do
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {
        'gear' => %w[staff]
      }.to_yaml)
      File.write(File.join(profiles_dir, 'base.yaml'), {
        'union_keys' => ['autostarts'],
        'autostarts' => %w[esp],
        'gear'       => %w[sword shield]
      }.to_yaml)
      settings = setup_files.get_settings
      expect(settings.gear).to eq(%w[staff])
    end

    it 'has no effect when union_keys is not set' do
      File.write(File.join(profiles_dir, 'base.yaml'), {
        'autostarts' => %w[esp afk]
      }.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {
        'autostarts' => %w[healer]
      }.to_yaml)
      settings = setup_files.get_settings
      expect(settings.autostarts).to eq(%w[healer])
    end

    it 'collects union_keys from multiple files' do
      File.write(File.join(profiles_dir, 'base.yaml'), {
        'union_keys' => ['autostarts'],
        'autostarts' => %w[esp],
        'gear'       => %w[sword]
      }.to_yaml)
      File.write(File.join(profiles_dir, 'include-shared.yaml'), {
        'union_keys' => ['gear'],
        'gear'       => %w[shield]
      }.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {
        'include'    => ['shared'],
        'autostarts' => %w[healer],
        'gear'       => %w[staff]
      }.to_yaml)
      settings = setup_files.get_settings
      expect(settings.autostarts).to match_array(%w[esp healer])
      expect(settings.gear).to match_array(%w[sword shield staff])
    end

    it 'deduplicates unioned arrays' do
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {
        'autostarts' => %w[esp healer]
      }.to_yaml)
      settings = setup_files.get_settings
      expect(settings.autostarts).to match_array(%w[esp afk healer])
      expect(settings.autostarts.length).to eq(3)
    end
  end
end
