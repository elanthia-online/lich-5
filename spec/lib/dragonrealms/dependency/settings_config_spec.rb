# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'dragonrealms/dependency/settings_config'

RSpec.describe Lich::DragonRealms::SettingsConfig do
  let(:config) { described_class::TRANSFORM_CONFIG }

  describe 'TRANSFORM_CONFIG' do
    it 'is frozen' do
      expect(config).to be_frozen
    end

    it 'has required top-level keys' do
      expect(config).to include(
        :empty_data_type, :spell_data_type,
        :waggle_set_keys, :spell_map_enrich_name_keys,
        :spell_map_enrich_data_keys, :spell_list_keys,
        :single_spell_keys, :offensive_spells_key,
        :battle_cries_key, :composed_lists,
        :uservars_fallback, :global_overrides,
        :hometown_lookup_keys, :denylists,
        :legacy_migrations
      )
    end

    it 'references expected DR spell setting keys' do
      expect(config[:spell_map_enrich_data_keys]).to include('buff_spells', 'combat_spell_training')
    end

    it 'references expected DR hometown lookup keys' do
      expect(config[:hometown_lookup_keys]).to include('safe_room', 'alchemy_room', 'engineering_room')
    end

    it 'includes lootables composition' do
      lootables_config = config[:composed_lists].find { |c| c[:target_key] == 'lootables' }
      expect(lootables_config).not_to be_nil
      expect(lootables_config[:base_data_keys].map { |k| k[:key] }).to include(:lootables, :box_nouns, :gem_nouns, :scroll_nouns)
    end

    it 'has all legacy migration entries' do
      expect(config[:legacy_migrations].length).to eq(4)
    end

    it 'blocks room 5713' do
      denylist = config[:denylists].first
      expect(denylist[:blocked_values]).to include(5713)
    end
  end
end
