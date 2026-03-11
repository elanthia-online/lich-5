# frozen_string_literal: true

require 'rspec'
require_relative '../../login_spec_helper'
require_relative '../../../lib/common/feature_flags'

RSpec.describe Lich::Common::FeatureFlags do
  let(:db) { instance_double('Database') }

  before do
    allow(Lich).to receive(:db).and_return(db)
    allow(Lich).to receive(:respond_to?).and_call_original
    allow(Lich).to receive(:respond_to?).with(:db).and_return(true)
  end

  describe '.enabled?' do
    it 'returns default false when Lich.db is nil' do
      allow(Lich).to receive(:db).and_return(nil)

      expect(described_class.enabled?(:cli_hello_world_demo)).to be(false)
    end

    it 'uses default false when no value exists for a known flag' do
      allow(db).to receive(:get_first_value).and_return(nil)

      expect(described_class.enabled?(:cli_hello_world_demo)).to be(false)
    end

    it 'returns true for truthy persisted values' do
      allow(db).to receive(:get_first_value).and_return('true')

      expect(described_class.enabled?(:cli_hello_world_demo)).to be(true)
    end

    it 'returns false for falsey persisted values' do
      allow(db).to receive(:get_first_value).and_return('false')

      expect(described_class.enabled?(:cli_hello_world_demo)).to be(false)
    end

    it 'returns false for unknown flags without persisted values' do
      allow(db).to receive(:get_first_value).and_return(nil)

      expect(described_class.enabled?(:nonexistent_flag)).to be(false)
    end

    it 'returns default false and logs when db read raises an error' do
      allow(db).to receive(:get_first_value).and_raise(StandardError, 'read failed')
      allow(Lich).to receive(:log)

      expect(described_class.enabled?(:cli_hello_world_demo)).to be(false)
      expect(Lich).to have_received(:log).with(/FeatureFlags read failed/)
    end
  end

  describe '.set' do
    it 'writes the feature flag key/value to lich_settings' do
      expect(db).to receive(:execute).with(
        'INSERT OR REPLACE INTO lich_settings(name, value) VALUES(?, ?);',
        ['feature_flag:cli_hello_world_demo', 'true']
      )

      described_class.set(:cli_hello_world_demo, true)
    end
  end
end
