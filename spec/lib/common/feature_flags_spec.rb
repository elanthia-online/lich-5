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
    it 'raises ArgumentError for empty flag names' do
      expect { described_class.enabled?('   ') }.to raise_error(ArgumentError, /non-empty/)
    end

    it 'raises ArgumentError for nil flag names' do
      expect { described_class.enabled?(nil) }.to raise_error(ArgumentError, /non-empty/)
    end

    it 'returns default false when Lich.db is nil' do
      allow(Lich).to receive(:db).and_return(nil)

      expect(described_class.enabled?(:cli_hello_world_demo)).to be(false)
    end

    it 'uses default false when no value exists for a known flag' do
      allow(db).to receive(:get_first_value).and_return(nil)

      expect(described_class.enabled?(:cli_hello_world_demo)).to be(false)
    end

    it 'returns true for accepted truthy persisted values' do
      %w[1 true on yes TRUE ON YES].each do |truthy_value|
        allow(db).to receive(:get_first_value).and_return(truthy_value)
        expect(described_class.enabled?(:cli_hello_world_demo)).to be(true)
      end
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
    it 'raises ArgumentError for empty flag names' do
      expect { described_class.set(' ', true) }.to raise_error(ArgumentError, /non-empty/)
    end

    it 'raises ArgumentError for nil flag names' do
      expect { described_class.set(nil, true) }.to raise_error(ArgumentError, /non-empty/)
    end

    it 'writes the feature flag key/value to lich_settings' do
      expect(db).to receive(:execute).with(
        'INSERT OR REPLACE INTO lich_settings(name, value) VALUES(?, ?);',
        ['feature_flag:cli_hello_world_demo', 'true']
      )

      expect(described_class.set(:cli_hello_world_demo, true)).to be(true)
    end

    it 'logs and does not raise when db write fails' do
      allow(db).to receive(:execute).and_raise(StandardError, 'write failed')
      allow(Lich).to receive(:log)

      expect(described_class.set(:cli_hello_world_demo, true)).to be(false)
      expect(Lich).to have_received(:log).with(/FeatureFlags write failed/)
    end
  end
end
