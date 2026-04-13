# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/feature_flags'

# Ensure SQLite3::BusyException is available for specs even without the gem
unless defined?(SQLite3::BusyException)
  module SQLite3
    class BusyException < StandardError; end
  end
end

unless defined?(SQLite3::SQLException)
  module SQLite3
    class SQLException < StandardError; end
  end
end

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

  describe 'BusyException retry behavior for .enabled?' do
    before do
      allow(Lich).to receive(:log)
      allow(described_class).to receive(:sleep)
    end

    it 'returns the value after one BusyException then success' do
      call_count = 0
      allow(db).to receive(:get_first_value) do
        call_count += 1
        raise SQLite3::BusyException, 'database is locked' if call_count == 1
        'true'
      end

      expect(described_class.enabled?(:demo_flag)).to be(true)
      expect(call_count).to eq(2)
    end

    it 'returns the value after two BusyExceptions then success' do
      call_count = 0
      allow(db).to receive(:get_first_value) do
        call_count += 1
        raise SQLite3::BusyException, 'database is locked' if call_count <= 2
        'true'
      end

      expect(described_class.enabled?(:demo_flag)).to be(true)
      expect(call_count).to eq(3)
    end

    it 'falls through to default after 3 BusyExceptions (max_attempts exhausted)' do
      allow(db).to receive(:get_first_value).and_raise(SQLite3::BusyException, 'database is locked')

      expect(described_class.enabled?(:demo_flag)).to be(false)
      expect(Lich).to have_received(:log).with(/FeatureFlags read failed/)
    end

    it 'sleeps with progressive backoff on retries' do
      call_count = 0
      allow(db).to receive(:get_first_value) do
        call_count += 1
        raise SQLite3::BusyException, 'database is locked' if call_count <= 2
        '1'
      end

      described_class.enabled?(:demo_flag)

      expect(described_class).to have_received(:sleep).with(0.05).ordered
      expect(described_class).to have_received(:sleep).with(0.10).ordered
    end

    it 'does not retry on non-BusyException errors' do
      allow(db).to receive(:get_first_value).and_raise(SQLite3::SQLException, 'no such table')

      expect(described_class.enabled?(:demo_flag)).to be(false)
      expect(described_class).not_to have_received(:sleep)
    end
  end

  describe 'BusyException retry behavior for .set' do
    before do
      allow(Lich).to receive(:log)
      allow(described_class).to receive(:sleep)
    end

    it 'returns true after one BusyException then success' do
      call_count = 0
      allow(db).to receive(:execute) do
        call_count += 1
        raise SQLite3::BusyException, 'database is locked' if call_count == 1
        nil
      end

      expect(described_class.set(:demo_flag, true)).to be(true)
      expect(call_count).to eq(2)
    end

    it 'falls through to error handler after 3 BusyExceptions' do
      allow(db).to receive(:execute).and_raise(SQLite3::BusyException, 'database is locked')

      expect(described_class.set(:demo_flag, true)).to be(false)
      expect(Lich).to have_received(:log).with(/FeatureFlags write failed/)
    end

    it 'sleeps with progressive backoff on retries' do
      call_count = 0
      allow(db).to receive(:execute) do
        call_count += 1
        raise SQLite3::BusyException, 'database is locked' if call_count <= 2
        nil
      end

      described_class.set(:demo_flag, true)

      expect(described_class).to have_received(:sleep).with(0.05).ordered
      expect(described_class).to have_received(:sleep).with(0.10).ordered
    end
  end

  describe 'concurrent access simulation' do
    before do
      allow(Lich).to receive(:log)
      allow(described_class).to receive(:sleep)
    end

    it 'all threads eventually get a result with intermittent BusyExceptions' do
      call_count = Concurrent::AtomicFixnum.new(0) rescue 0
      # Use a simple thread-safe counter via Mutex if Concurrent is unavailable
      mutex = Mutex.new
      counter = 0

      allow(db).to receive(:get_first_value) do
        current = mutex.synchronize { counter += 1; counter }
        # Every other call raises BusyException (simulating contention)
        raise SQLite3::BusyException, 'database is locked' if current.odd? && current < 10
        'true'
      end

      results = []
      threads = 5.times.map do
        Thread.new do
          result = described_class.enabled?(:demo_flag)
          mutex.synchronize { results << result }
        end
      end

      threads.each(&:join)

      # All threads should have gotten a boolean result (no unhandled exceptions)
      expect(results.length).to eq(5)
      results.each do |r|
        expect([true, false]).to include(r)
      end
    end
  end
end
