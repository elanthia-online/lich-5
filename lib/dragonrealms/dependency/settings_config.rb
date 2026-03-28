# frozen_string_literal: true

=begin
  DR-specific configuration for SettingsTransformer.

  Contains the key names, data file types, UserVars mappings,
  hometown lookup keys, denylists, and legacy migrations that
  describe how to transform DragonRealms user settings.
=end

module Lich
  module DragonRealms
    module SettingsConfig
      TRANSFORM_CONFIG = {
        # Phase 1: Default empty values
        empty_data_type: 'empty',

        # Phase 2: Spell enrichment
        spell_data_type: 'spells',

        waggle_set_keys: %w[waggle_sets].freeze,

        spell_map_enrich_name_keys: %w[buff_spells necromancer_healing].freeze,

        spell_map_enrich_data_keys: %w[
          buff_spells combat_spell_training cyclic_training_spells
          magic_training training_spells crafting_training_spells
          necromancer_healing
        ].freeze,

        spell_list_keys: %w[offensive_spells].freeze,

        single_spell_keys: %w[crossing_training_sorcery].freeze,

        offensive_spells_key: 'offensive_spells',
        battle_cries_key: 'battle_cries',

        # Phase 3: Composed lists
        composed_lists: [
          {
            target_key: 'lootables',
            base_data_keys: [
              { type: 'items', key: :lootables },
              { type: 'items', key: :box_nouns },
              { type: 'items', key: :gem_nouns },
              { type: 'items', key: :scroll_nouns },
            ].freeze,
            additions_key: 'loot_additions',
            subtractions_key: 'loot_subtractions',
          }.freeze,
        ].freeze,

        # Phase 4: UserVars fallback
        uservars_fallback: [
          { setting_key: 'crossing_training_sorcery_room', uservars_key: :crossing_training_sorcery_room, mode: :default },
          { setting_key: 'compost_room', uservars_key: :compost_room, mode: :default },
          { setting_key: 'engineering_room', uservars_key: :engineering_room, mode: :default },
          { setting_key: 'outfitting_room', uservars_key: :outfitting_room, mode: :default },
          { setting_key: 'alchemy_room', uservars_key: :alchemy_room, mode: :default },
          { setting_key: 'safe_room', uservars_key: :safe_room, mode: :default },
          { setting_key: 'safe_room_id', uservars_key: :safe_room_id, mode: :default },
          { setting_key: 'safe_room_empath', uservars_key: :safe_room_empath, mode: :default },
          { setting_key: 'safe_room_empaths', uservars_key: :safe_room_empaths, mode: :append },
          { setting_key: 'slack_username', uservars_key: :slack_username, mode: :default },
          { setting_key: 'bankbot_name', uservars_key: :bankbot_name, mode: :default },
          { setting_key: 'bankbot_room_id', uservars_key: :bankbot_room_id, mode: :default },
          { setting_key: 'prehunt_buffs', uservars_key: :prehunt_buffs, mode: :default },
          { setting_key: 'hometown', uservars_key: :hometown, mode: :default },
        ].freeze,

        global_overrides: [
          { setting_key: 'hometown', global_var: '$HOMETOWN' }.freeze,
        ].freeze,

        # Phase 5: Hometown-based room lookups
        hometown_lookup_keys: %w[
          alchemy_room bankbot_room_id compost_room
          crossing_training_sorcery_room enchanting_room
          engineering_room feed_cloak_room forage_override_room
          lockpick_room_id outdoor_room outfitting_room
          prehunt_buffing_room safe_room safe_room_id
          theurgy_prayer_mat_room
        ].freeze,

        # Phase 6: Denylists
        denylists: [
          {
            setting_keys: %w[safe_room safe_room_id].freeze,
            blocked_values: [5713].freeze,
          }.freeze,
        ].freeze,

        # Phase 7: Legacy migrations
        legacy_migrations: [
          { type: :append_if_flag, target_key: 'appraisal_training', value: 'pouches', flag_key: 'train_appraisal_with_pouches' }.freeze,
          { type: :append_if_flag, target_key: 'appraisal_training', value: 'gear', flag_key: 'train_appraisal_with_gear' }.freeze,
          { type: :append_if_flag, target_key: 'astrology_training', value: 'events', flag_key: 'predict_event' }.freeze,
          { type: :append_if_nested, target_key: 'astrology_training', value: 'ways', source_key: 'astral_plane_training', nested_key: 'train_in_ap' }.freeze,
        ].freeze,
      }.freeze
    end
  end
end
