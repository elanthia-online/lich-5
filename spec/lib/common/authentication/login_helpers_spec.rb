# frozen_string_literal: true

require 'rspec'

# Mock dependencies before requiring
module Lich
  def self.log(_message)
    # no-op for tests
  end

  module Util
    def self.install_gem_requirements(_gems)
      # no-op for tests
    end
  end
end unless defined?(Lich)

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
end
