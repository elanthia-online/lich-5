# frozen_string_literal: true

require 'rspec'

# Define LICH_VERSION for version checks
LICH_VERSION = '5.14.0' unless defined?(LICH_VERSION)

# Mock dependencies before requiring
module Lich
  def self.log(_message)
    # no-op for tests
  end
end unless defined?(Lich)

module Lich
  module Util
    def self.install_gem_requirements(_gems)
      # no-op for tests
    end
  end
end unless defined?(Lich::Util)

module Lich
  module Messaging
    def self.msg(_level, _message)
      # no-op for tests
    end
  end
end unless defined?(Lich::Messaging)

module GameConfig
  DEFAULT_REALM = 'prime'
  DEFAULT_GAME_NAME = 'Unknown Game'
end unless defined?(GameConfig)

require_relative '../../../../lib/common/authentication/login_helpers'

RSpec.describe Lich::Common::Authentication::LoginHelpers do
  describe 'constants' do
    it 'defines VALID_GAME_CODES' do
      expect(described_class::VALID_GAME_CODES).to include('GS3', 'DR', 'GSX', 'DRX')
    end

    it 'defines VALID_FRONTENDS' do
      expect(described_class::VALID_FRONTENDS).to include('stormfront', 'wizard', 'avalon')
    end

    it 'defines VALID_REALMS' do
      expect(described_class::VALID_REALMS).to include('prime', 'platinum', 'shattered', 'test')
    end

    it 'defines GEMSTONE_FLAGS' do
      expect(described_class::GEMSTONE_FLAGS).to eq(%w[--gemstone --gs])
    end

    it 'defines DRAGONREALMS_FLAGS' do
      expect(described_class::DRAGONREALMS_FLAGS).to eq(%w[--dragonrealms --dr])
    end

    it 'defines GAME_CODE_TO_NAME mappings' do
      expect(described_class::GAME_CODE_TO_NAME['GS3']).to eq('GemStone IV')
      expect(described_class::GAME_CODE_TO_NAME['DR']).to eq('DragonRealms')
    end
  end

  describe '.realm_from_game_code' do
    it 'returns platinum for GSX' do
      expect(described_class.realm_from_game_code('GSX')).to eq('platinum')
    end

    it 'returns shattered for GSF' do
      expect(described_class.realm_from_game_code('GSF')).to eq('shattered')
    end

    it 'returns test for GST' do
      expect(described_class.realm_from_game_code('GST')).to eq('test')
    end

    it 'returns default realm for unknown codes' do
      expect(described_class.realm_from_game_code('UNKNOWN')).to eq(GameConfig::DEFAULT_REALM)
    end

    it 'handles case insensitivity' do
      expect(described_class.realm_from_game_code('gsx')).to eq('platinum')
    end
  end

  describe '.realm_to_game_code' do
    it 'returns GS3 for prime' do
      expect(described_class.realm_to_game_code('prime')).to eq('GS3')
    end

    it 'returns GSX for platinum' do
      expect(described_class.realm_to_game_code('platinum')).to eq('GSX')
    end

    it 'returns GSF for shattered' do
      expect(described_class.realm_to_game_code('shattered')).to eq('GSF')
    end

    it 'returns GST for test' do
      expect(described_class.realm_to_game_code('test')).to eq('GST')
    end

    it 'returns nil for unknown realms' do
      expect(described_class.realm_to_game_code('unknown')).to be_nil
    end
  end

  describe '.game_name_from_game_code' do
    it 'returns GemStone IV for GS3' do
      expect(described_class.game_name_from_game_code('GS3')).to eq('GemStone IV')
    end

    it 'returns DragonRealms for DR' do
      expect(described_class.game_name_from_game_code('DR')).to eq('DragonRealms')
    end

    it 'returns default name for unknown codes' do
      expect(described_class.game_name_from_game_code('UNKNOWN')).to eq(GameConfig::DEFAULT_GAME_NAME)
    end
  end

  describe '.valid_realm?' do
    it 'returns true for prime' do
      expect(described_class.valid_realm?('prime')).to be true
    end

    it 'returns true for platinum' do
      expect(described_class.valid_realm?('platinum')).to be true
    end

    it 'returns false for unknown realm' do
      expect(described_class.valid_realm?('unknown')).to be false
    end
  end

  describe 'FRONTEND_PATTERN' do
    it 'matches --stormfront' do
      match = '--stormfront'.match(described_class::FRONTEND_PATTERN)
      expect(match[:fe]).to eq('stormfront')
    end

    it 'matches --wizard' do
      match = '--wizard'.match(described_class::FRONTEND_PATTERN)
      expect(match[:fe]).to eq('wizard')
    end

    it 'matches --avalon' do
      match = '--avalon'.match(described_class::FRONTEND_PATTERN)
      expect(match[:fe]).to eq('avalon')
    end

    it 'does not match invalid frontends' do
      expect('--invalid'.match(described_class::FRONTEND_PATTERN)).to be_nil
    end
  end

  describe 'INSTANCE_PATTERN' do
    it 'matches --GS3' do
      match = '--GS3'.match(described_class::INSTANCE_PATTERN)
      expect(match[:inst]).to eq('GS3')
    end

    it 'matches --DR' do
      match = '--DR'.match(described_class::INSTANCE_PATTERN)
      expect(match[:inst]).to eq('DR')
    end

    it 'matches case insensitively' do
      match = '--gs3'.match(described_class::INSTANCE_PATTERN)
      expect(match[:inst]).to eq('gs3')
    end
  end

  describe 'CUSTOM_LAUNCH_PATTERN' do
    it 'extracts custom launch value' do
      match = '--custom-launch=/path/to/launch'.match(described_class::CUSTOM_LAUNCH_PATTERN)
      expect(match[:cl]).to eq('/path/to/launch')
    end

    it 'does not match without value' do
      expect('--custom-launch'.match(described_class::CUSTOM_LAUNCH_PATTERN)).to be_nil
    end
  end

  describe '.symbolize_keys' do
    it 'converts string keys to symbols' do
      input = { 'name' => 'Test', 'value' => 123 }
      result = described_class.symbolize_keys(input)
      expect(result).to eq({ name: 'Test', value: 123 })
    end

    it 'handles nested hashes' do
      input = { 'outer' => { 'inner' => 'value' } }
      result = described_class.symbolize_keys(input)
      expect(result).to eq({ outer: { inner: 'value' } })
    end

    it 'handles arrays of hashes' do
      input = [{ 'a' => 1 }, { 'b' => 2 }]
      result = described_class.symbolize_keys(input)
      expect(result).to eq([{ a: 1 }, { b: 2 }])
    end

    it 'returns non-hash/array values unchanged' do
      expect(described_class.symbolize_keys('string')).to eq('string')
      expect(described_class.symbolize_keys(123)).to eq(123)
    end
  end

  describe '.data_format' do
    it 'returns :legacy_array for array data' do
      expect(described_class.data_format([{ char_name: 'Test' }])).to eq(:legacy_array)
    end

    it 'returns :yaml_accounts for hash with :accounts key' do
      expect(described_class.data_format({ accounts: {} })).to eq(:yaml_accounts)
    end

    it 'returns :unknown for other data types' do
      expect(described_class.data_format({ other: 'data' })).to eq(:unknown)
      expect(described_class.data_format('string')).to eq(:unknown)
    end
  end

  describe '.find_character_by_attributes' do
    let(:legacy_data) do
      [
        { char_name: 'Testchar', game_code: 'GS3', frontend: 'stormfront' },
        { char_name: 'Testchar', game_code: 'GSX', frontend: 'wizard' },
        { char_name: 'Otherchar', game_code: 'GS3', frontend: 'stormfront' }
      ]
    end

    let(:yaml_data) do
      {
        accounts: {
          'TESTUSER' => {
            password: 'secret',
            characters: [
              { char_name: 'Testchar', game_code: 'GS3', frontend: 'stormfront' },
              { char_name: 'Testchar', game_code: 'GSX', frontend: 'wizard' }
            ]
          }
        }
      }
    end

    context 'with legacy array data' do
      it 'finds character by name' do
        results = described_class.find_character_by_attributes(legacy_data, char_name: 'Testchar')
        expect(results.length).to eq(2)
        expect(results.all? { |r| r[:char_name] == 'Testchar' }).to be true
      end

      it 'finds character by name and game_code' do
        results = described_class.find_character_by_attributes(
          legacy_data,
          char_name: 'Testchar',
          game_code: 'GS3'
        )
        expect(results.length).to eq(1)
        expect(results.first[:game_code]).to eq('GS3')
      end

      it 'returns empty array when no match' do
        results = described_class.find_character_by_attributes(
          legacy_data,
          char_name: 'Nonexistent'
        )
        expect(results).to be_empty
      end

      it 'is case insensitive for character names' do
        results = described_class.find_character_by_attributes(
          legacy_data,
          char_name: 'TESTCHAR'
        )
        expect(results.length).to eq(2)
      end
    end

    context 'with YAML accounts data' do
      it 'finds character and includes account info' do
        results = described_class.find_character_by_attributes(yaml_data, char_name: 'Testchar')
        expect(results.length).to eq(2)
        expect(results.first[:username]).to eq('TESTUSER')
        expect(results.first[:password]).to eq('secret')
      end
    end

    context 'with GST fallback to GS3' do
      it 'falls back to GS3 when GST not found' do
        results = described_class.find_character_by_attributes(
          legacy_data,
          char_name: 'Testchar',
          game_code: 'GST'
        )
        # Should find GS3 entry as fallback
        expect(results.length).to eq(1)
        expect(results.first[:game_code]).to eq('GS3')
      end
    end
  end

  describe '.select_best_fit' do
    let(:char_data_sets) do
      [
        { char_name: 'Testchar', game_code: 'GS3', frontend: 'stormfront' },
        { char_name: 'Testchar', game_code: 'GS3', frontend: 'wizard' },
        { char_name: 'Testchar', game_code: 'GSX', frontend: 'stormfront' }
      ]
    end

    it 'returns nil for empty array' do
      result = described_class.select_best_fit(
        char_data_sets: [],
        requested_character: 'Test'
      )
      expect(result).to be_nil
    end

    it 'returns nil for nil array' do
      result = described_class.select_best_fit(
        char_data_sets: nil,
        requested_character: 'Test'
      )
      expect(result).to be_nil
    end

    it 'returns nil when no character name match' do
      result = described_class.select_best_fit(
        char_data_sets: char_data_sets,
        requested_character: 'Nonexistent'
      )
      expect(result).to be_nil
    end

    it 'returns first match when only character specified' do
      result = described_class.select_best_fit(
        char_data_sets: char_data_sets,
        requested_character: 'Testchar'
      )
      expect(result).not_to be_nil
      expect(result[:char_name]).to eq('Testchar')
    end

    it 'filters by game instance when specified' do
      result = described_class.select_best_fit(
        char_data_sets: char_data_sets,
        requested_character: 'Testchar',
        requested_instance: 'GSX'
      )
      expect(result[:game_code]).to eq('GSX')
    end

    it 'prefers frontend match when specified' do
      result = described_class.select_best_fit(
        char_data_sets: char_data_sets,
        requested_character: 'Testchar',
        requested_instance: 'GS3',
        requested_fe: 'wizard'
      )
      expect(result[:frontend]).to eq('wizard')
    end

    it 'returns nil for invalid game instance' do
      result = described_class.select_best_fit(
        char_data_sets: char_data_sets,
        requested_character: 'Testchar',
        requested_instance: 'INVALID'
      )
      expect(result).to be_nil
    end
  end

  describe '.resolve_instance' do
    it 'returns GS3 for --gemstone' do
      expect(described_class.resolve_instance(['--gemstone'])).to eq('GS3')
    end

    it 'returns GS3 for --gs (alias)' do
      expect(described_class.resolve_instance(['--gs'])).to eq('GS3')
    end

    it 'returns GST for --gemstone --test' do
      expect(described_class.resolve_instance(['--gemstone', '--test'])).to eq('GST')
    end

    it 'returns GSX for --gemstone --platinum' do
      expect(described_class.resolve_instance(['--gemstone', '--platinum'])).to eq('GSX')
    end

    it 'returns DR for --dragonrealms' do
      expect(described_class.resolve_instance(['--dragonrealms'])).to eq('DR')
    end

    it 'returns DR for --dr (alias)' do
      expect(described_class.resolve_instance(['--dr'])).to eq('DR')
    end

    it 'returns DRF for --dragonrealms --fallen' do
      expect(described_class.resolve_instance(['--dragonrealms', '--fallen'])).to eq('DRF')
    end

    it 'returns direct game code for --GS3' do
      expect(described_class.resolve_instance(['--GS3'])).to eq('GS3')
    end

    it 'returns :__unset when no instance flags present' do
      expect(described_class.resolve_instance(['--stormfront'])).to eq(:__unset)
    end

    it 'ignores bare --login and dark-mode modifiers when resolving instance' do
      expect(described_class.resolve_instance(['--login', 'Tsetem', '--dark-mode=true'])).to eq(:__unset)
    end

    it 'ignores optional path modifiers used by persistent launcher child sessions' do
      expect(described_class.resolve_instance(['--home=/tmp/lich', '--data=/tmp/data'])).to eq(:__unset)
    end

    it 'returns nil for unknown option-like flags (probable invalid instance intent)' do
      expect(described_class.resolve_instance(['--invalid-instance-flag'])).to be_nil
    end
  end

  describe '.resolve_login_args' do
    before do
      # Mock Lich::Messaging for debug output
      allow(Lich::Messaging).to receive(:msg) if defined?(Lich::Messaging)
    end

    it 'parses instance, frontend, and custom_launch' do
      instance, frontend, custom_launch = described_class.resolve_login_args(
        ['--GS3', '--stormfront', '--custom-launch=warlock']
      )
      expect(instance).to eq('GS3')
      expect(frontend).to eq('stormfront')
      expect(custom_launch).to eq('warlock')
    end

    it 'returns :__unset for missing values' do
      instance, frontend, custom_launch = described_class.resolve_login_args(['--GS3'])
      expect(instance).to eq('GS3')
      expect(frontend).to eq(:__unset)
      expect(custom_launch).to eq(:__unset)
    end
  end

  describe '.format_launch_flag' do
    it 'returns nil for empty game code' do
      expect(described_class.format_launch_flag('')).to be_nil
      expect(described_class.format_launch_flag(nil)).to be_nil
    end

    it 'returns formatted flag for valid game code' do
      # Assuming lich_version_at_least?(5, 12, 0) returns true in test environment
      result = described_class.format_launch_flag('GS3')
      expect(result).to match(/--G?S?3?/i)
    end
  end
end
