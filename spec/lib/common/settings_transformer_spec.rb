# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/settings_transformer'

RSpec.describe Lich::Common::SettingsTransformer do
  let(:empty_config) { {} }

  let(:data_provider) do
    lambda { |_type| OpenStruct.new }
  end

  describe '.transform' do
    it 'returns an OpenStruct' do
      result = described_class.transform({}, empty_config, data_provider)
      expect(result).to be_a(OpenStruct)
    end

    it 'preserves existing settings' do
      result = described_class.transform({ 'hometown' => 'Crossing' }, empty_config, data_provider)
      expect(result.hometown).to eq('Crossing')
    end

    context 'error handling' do
      it 'returns empty OpenStruct on error' do
        bad_config = { empty_data_type: 'empty' }
        bad_provider = lambda { |_| raise 'kaboom' }
        result = described_class.transform({}, bad_config, bad_provider)
        expect(result).to be_a(OpenStruct)
      end
    end
  end

  describe 'Phase 1: apply_defaults' do
    let(:config) { { empty_data_type: 'empty' } }
    let(:data_provider) do
      lambda do |type|
        case type
        when 'empty'
          OpenStruct.new(empty_values: { 'loot_additions' => [], 'loot_subtractions' => [], 'autostarts' => [] })
        else
          OpenStruct.new
        end
      end
    end

    it 'populates nil settings with defaults' do
      result = described_class.transform({}, config, data_provider)
      expect(result.loot_additions).to eq([])
      expect(result.autostarts).to eq([])
    end

    it 'does not overwrite existing settings' do
      result = described_class.transform({ 'loot_additions' => ['gem'] }, config, data_provider)
      expect(result.loot_additions).to eq(['gem'])
    end
  end

  describe 'Phase 2: enrich_spells' do
    let(:spells_data) do
      {
        'Fire Ball' => { 'abbrev' => 'FB', 'skill' => 'Targeted Magic', 'mana' => 5 },
        'Shield'    => { 'abbrev' => 'SH', 'skill' => 'Augmentation', 'mana' => 3 },
      }
    end

    let(:data_provider) do
      lambda do |type|
        case type
        when 'spells'
          OpenStruct.new(spell_data: spells_data, battle_cries: {})
        else
          OpenStruct.new
        end
      end
    end

    let(:config) do
      {
        spell_data_type: 'spells',
        spell_map_enrich_name_keys: %w[buff_spells],
        spell_map_enrich_data_keys: [],
        spell_list_keys: [],
        single_spell_keys: [],
        waggle_set_keys: [],
      }
    end

    it 'enriches spell maps by injecting name and merging base data' do
      settings = { 'buff_spells' => { 'Shield' => { 'mana' => 10 } } }
      result = described_class.transform(settings, config, data_provider)
      shield = result.buff_spells['Shield']
      expect(shield['name']).to eq('Shield')
      expect(shield['skill']).to eq('Augmentation')
      expect(shield['mana']).to eq(10) # user override wins
    end

    context 'waggle sets' do
      let(:config) do
        {
          spell_data_type: 'spells',
          waggle_set_keys: %w[waggle_sets],
          spell_map_enrich_name_keys: [],
          spell_map_enrich_data_keys: [],
          spell_list_keys: [],
          single_spell_keys: [],
        }
      end

      it 'enriches spells within waggle sets' do
        settings = { 'waggle_sets' => { 'combat' => { 'Shield' => {} } } }
        result = described_class.transform(settings, config, data_provider)
        shield = result.waggle_sets['combat']['Shield']
        expect(shield['abbrev']).to eq('SH')
      end

      it 'handles non-hash waggle set entries' do
        settings = { 'waggle_sets' => { 'abilities' => %w[Berserk Rage] } }
        result = described_class.transform(settings, config, data_provider)
        expect(result.waggle_sets['abilities']).to eq(%w[Berserk Rage])
      end
    end

    context 'spell lists' do
      let(:config) do
        {
          spell_data_type: 'spells',
          spell_list_keys: %w[offensive_spells],
          offensive_spells_key: 'offensive_spells',
          waggle_set_keys: [],
          spell_map_enrich_name_keys: [],
          spell_map_enrich_data_keys: [],
          single_spell_keys: [],
        }
      end

      it 'enriches spell list entries' do
        settings = { 'offensive_spells' => [{ 'abbrev' => 'FB' }] }
        result = described_class.transform(settings, config, data_provider)
        fb = result.offensive_spells.first
        expect(fb['name']).to eq('Fire Ball')
        expect(fb['skill']).to eq('Targeted Magic')
      end

      it 'defaults TM spell prep to target' do
        settings = { 'offensive_spells' => [{ 'name' => 'Fire Ball', 'skill' => 'Targeted Magic' }] }
        result = described_class.transform(settings, config, data_provider)
        expect(result.offensive_spells.first['prep']).to eq('target')
      end
    end

    context 'single spell keys' do
      let(:config) do
        {
          spell_data_type: 'spells',
          single_spell_keys: %w[crossing_training_sorcery],
          waggle_set_keys: [],
          spell_map_enrich_name_keys: [],
          spell_map_enrich_data_keys: [],
          spell_list_keys: [],
        }
      end

      it 'enriches a single spell setting' do
        settings = { 'crossing_training_sorcery' => { 'abbrev' => 'FB' } }
        result = described_class.transform(settings, config, data_provider)
        expect(result.crossing_training_sorcery['name']).to eq('Fire Ball')
      end
    end
  end

  describe 'Phase 3: compose_lists' do
    let(:config) do
      {
        composed_lists: [
          {
            target_key: 'lootables',
            base_data_keys: [
              { type: 'items', key: :lootables },
              { type: 'items', key: :gem_nouns },
            ],
            additions_key: 'loot_additions',
            subtractions_key: 'loot_subtractions',
          }
        ]
      }
    end

    let(:data_provider) do
      lambda do |type|
        case type
        when 'items'
          OpenStruct.new(lootables: %w[coin gem], gem_nouns: %w[diamond ruby])
        else
          OpenStruct.new
        end
      end
    end

    it 'composes lists from base data, additions, and subtractions' do
      settings = { 'loot_additions' => ['special_gem'], 'loot_subtractions' => ['coin'] }
      result = described_class.transform(settings, config, data_provider)
      expect(result.lootables).to include('gem', 'diamond', 'ruby', 'special_gem')
      expect(result.lootables).not_to include('coin')
    end

    it 'deduplicates the result' do
      settings = { 'loot_additions' => ['gem'], 'loot_subtractions' => [] }
      result = described_class.transform(settings, config, data_provider)
      expect(result.lootables.count('gem')).to eq(1)
    end
  end

  describe 'Phase 4: apply_uservars_fallback' do
    let(:config) do
      {
        uservars_fallback: [
          { setting_key: 'hometown', uservars_key: :hometown, mode: :default },
          { setting_key: 'safe_room_empaths', uservars_key: :safe_room_empaths, mode: :append },
        ]
      }
    end

    before do
      UserVars.hometown = 'Shard'
      UserVars.safe_room_empaths = ['Empath1']
    end

    it 'falls back to UserVars when setting is nil' do
      result = described_class.transform({}, config, data_provider)
      expect(result.hometown).to eq('Shard')
    end

    it 'does not overwrite existing settings in default mode' do
      result = described_class.transform({ 'hometown' => 'Crossing' }, config, data_provider)
      expect(result.hometown).to eq('Crossing')
    end

    it 'appends UserVars values in append mode' do
      result = described_class.transform({ 'safe_room_empaths' => ['Empath2'] }, config, data_provider)
      expect(result.safe_room_empaths).to eq(['Empath2', 'Empath1'])
    end
  end

  describe 'Phase 5: apply_hometown_lookups' do
    let(:config) do
      { hometown_lookup_keys: %w[safe_room alchemy_room] }
    end

    it 'resolves Hash settings to hometown value' do
      settings = {
        'hometown'     => 'Crossing',
        'safe_room'    => { 'Crossing' => 1234, 'Shard' => 5678 },
        'alchemy_room' => 9999, # not a Hash, left alone
      }
      result = described_class.transform(settings, config, data_provider)
      expect(result.safe_room).to eq(1234)
      expect(result.alchemy_room).to eq(9999)
    end

    it 'leaves Hash settings unchanged if hometown key not found' do
      settings = {
        'hometown'  => 'Dirge',
        'safe_room' => { 'Crossing' => 1234 },
      }
      result = described_class.transform(settings, config, data_provider)
      expect(result.safe_room).to eq({ 'Crossing' => 1234 })
    end
  end

  describe 'Phase 7: apply_legacy_migrations' do
    let(:config) do
      {
        legacy_migrations: [
          { type: :append_if_flag, target_key: 'appraisal_training', value: 'pouches', flag_key: 'train_appraisal_with_pouches' },
          { type: :append_if_nested, target_key: 'astrology_training', value: 'ways', source_key: 'astral_plane_training', nested_key: 'train_in_ap' },
        ]
      }
    end

    it 'appends value when flag is true' do
      settings = { 'appraisal_training' => ['gear'], 'train_appraisal_with_pouches' => true }
      result = described_class.transform(settings, config, data_provider)
      expect(result.appraisal_training).to include('pouches')
    end

    it 'does not append when flag is false' do
      settings = { 'appraisal_training' => ['gear'], 'train_appraisal_with_pouches' => false }
      result = described_class.transform(settings, config, data_provider)
      expect(result.appraisal_training).not_to include('pouches')
    end

    it 'does not duplicate existing values' do
      settings = { 'appraisal_training' => ['pouches'], 'train_appraisal_with_pouches' => true }
      result = described_class.transform(settings, config, data_provider)
      expect(result.appraisal_training.count('pouches')).to eq(1)
    end

    it 'appends when nested key is truthy' do
      settings = { 'astrology_training' => [], 'astral_plane_training' => { 'train_in_ap' => true } }
      result = described_class.transform(settings, config, data_provider)
      expect(result.astrology_training).to include('ways')
    end
  end
end
