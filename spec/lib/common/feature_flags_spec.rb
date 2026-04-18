# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/feature_flags'

RSpec.describe Lich::Common::FeatureFlags do
  let(:db) { instance_double('Database') }

  before do
    allow(Lich).to receive(:db).and_return(db)
    allow(Lich).to receive(:respond_to?).and_call_original
    allow(Lich).to receive(:respond_to?).with(:db).and_return(true)
  end

  describe '.enabled?' do
    it 'raises ArgumentError for a blank flag name' do
      expect { described_class.enabled?('   ') }.to raise_error(ArgumentError, /non-empty/)
    end

    it 'raises ArgumentError for a flag name with unsupported characters' do
      expect { described_class.enabled?('demo-flag') }.to raise_error(ArgumentError, /must match/)
    end

    it 'returns false when the feature flag is not persisted' do
      allow(db).to receive(:get_first_value).and_return(nil)

      expect(described_class.enabled?(:unconfigured_flag)).to be(false)
    end

    %w[1 true on yes TRUE ON YES].each do |truthy_value|
      it "returns true for the persisted value #{truthy_value.inspect}" do
        allow(db).to receive(:get_first_value).and_return(truthy_value)

        expect(described_class.enabled?(:demo_flag)).to be(true)
      end
    end

    it 'returns false for falsey persisted values' do
      allow(db).to receive(:get_first_value).and_return('false')

      expect(described_class.enabled?(:demo_flag)).to be(false)
    end

    it 'returns false when the database handle is unavailable' do
      allow(Lich).to receive(:db).and_return(nil)

      expect(described_class.enabled?(:demo_flag)).to be(false)
    end

    it 'returns the default value and logs when the read raises an error' do
      stub_const("#{described_class}::DEFAULTS", { demo_flag: true }.freeze)
      allow(db).to receive(:get_first_value).and_raise(StandardError, 'read failed')
      allow(Lich).to receive(:log)

      expect(described_class.enabled?(:demo_flag)).to be(true)
      expect(Lich).to have_received(:log).with(/FeatureFlags read failed/)
    end
  end

  describe '.set' do
    it 'raises ArgumentError for a blank flag name' do
      expect { described_class.set('', true) }.to raise_error(ArgumentError, /non-empty/)
    end

    it 'raises ArgumentError for a flag name with unsupported characters' do
      expect { described_class.set('demo-flag', true) }.to raise_error(ArgumentError, /must match/)
    end

    it 'persists the feature flag using the lich_settings prefix' do
      expect(db).to receive(:execute).with(
        'INSERT OR REPLACE INTO lich_settings(name, value) VALUES(?, ?);',
        ['feature_flag:demo_flag', 'true']
      )

      expect(described_class.set(:demo_flag, true)).to be(true)
    end

    it 'returns false when the database handle is unavailable' do
      allow(Lich).to receive(:db).and_return(nil)

      expect(described_class.set(:demo_flag, true)).to be(false)
    end

    it 'returns false and logs when the write raises an error' do
      allow(db).to receive(:execute).and_raise(StandardError, 'write failed')
      allow(Lich).to receive(:log)

      expect(described_class.set(:demo_flag, true)).to be(false)
      expect(Lich).to have_received(:log).with(/FeatureFlags write failed/)
    end
  end

end
