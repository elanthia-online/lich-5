# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/main/detachable_session_name'

RSpec.describe Lich::Main::DetachableSessionName do
  describe '.from_launch_data' do
    it 'returns nil for nil launch data' do
      expect(described_class.from_launch_data(nil)).to be_nil
    end

    it 'returns nil when no CHARACTER or NAME field is present' do
      launch_data = ['GAMECODE=DR', 'GAMEHOST=dr.simutronics.net', 'GAMEPORT=11024']
      expect(described_class.from_launch_data(launch_data)).to be_nil
    end

    it 'resolves and capitalizes a CHARACTER field' do
      launch_data = ['GAMECODE=DR', 'CHARACTER=mahtra']
      expect(described_class.from_launch_data(launch_data)).to eq('Mahtra')
    end

    it 'resolves a NAME field' do
      launch_data = ['GAMECODE=DR', 'NAME=mahtra']
      expect(described_class.from_launch_data(launch_data)).to eq('Mahtra')
    end

    it 'matches the field name case-insensitively' do
      launch_data = ['character=mahtra']
      expect(described_class.from_launch_data(launch_data)).to eq('Mahtra')
    end

    it 'strips surrounding whitespace from the value' do
      launch_data = ['CHARACTER=  mahtra  ']
      expect(described_class.from_launch_data(launch_data)).to eq('Mahtra')
    end

    it 'returns nil for a blank value' do
      launch_data = ['CHARACTER=']
      expect(described_class.from_launch_data(launch_data)).to be_nil
    end

    it 'returns nil for a whitespace-only value' do
      launch_data = ['CHARACTER=   ']
      expect(described_class.from_launch_data(launch_data)).to be_nil
    end

    it 'prefers the first matching field when both are present' do
      launch_data = ['CHARACTER=mahtra', 'NAME=other']
      expect(described_class.from_launch_data(launch_data)).to eq('Mahtra')
    end
  end
end
