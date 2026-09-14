# frozen_string_literal: true

require 'rspec'
require_relative '../../../../lib/common/authentication/launch_result'

RSpec.describe Lich::Common::Authentication::LaunchResult do
  describe '.normalize' do
    it 'downcases keys and freezes the result' do
      result = described_class.normalize('GAMEHOST' => 'h', 'KEY' => 'k')
      expect(result).to eq('gamehost' => 'h', 'key' => 'k')
      expect(result).to be_frozen
    end

    it 'passes through keys that are already lowercase strings' do
      result = described_class.normalize('gamehost' => 'h', 'key' => 'k')
      expect(result).to eq('gamehost' => 'h', 'key' => 'k')
    end

    it 'accepts symbol keys' do
      result = described_class.normalize(gamehost: 'h', key: 'k')
      expect(result).to eq('gamehost' => 'h', 'key' => 'k')
    end

    it 'does not require gamehost/gameport (the EAccess generator path can omit them)' do
      expect { described_class.normalize('key' => 'abc') }.not_to raise_error
    end

    it 'raises when key is missing' do
      expect {
        described_class.normalize('gamehost' => 'h', 'gameport' => 'p')
      }.to raise_error(described_class::MissingLaunchDataError, /key/)
    end

    it 'raises when key is present but blank' do
      expect {
        described_class.normalize('key' => '')
      }.to raise_error(described_class::MissingLaunchDataError)
    end
  end
end
