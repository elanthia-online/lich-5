# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/feature_flags'

RSpec.describe Lich::Common::FeatureFlags do
  let(:db) { instance_double('Database') }

  before do
    allow(Lich).to receive(:db).and_return(db)
    allow(Lich).to receive(:respond_to?).and_call_original
    allow(Lich).to receive(:respond_to?).with(:db).and_return(true)
    described_class.clear_cache!
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

  describe 'caching' do
    it 'hits DB on first call but serves from cache on second call within TTL' do
      allow(db).to receive(:get_first_value).and_return('true')

      described_class.enabled?(:cached_flag)
      described_class.enabled?(:cached_flag)

      expect(db).to have_received(:get_first_value).once
    end

    it 'hits DB again after TTL expires' do
      now = Time.at(1000.0)
      allow(Time).to receive(:now).and_return(now)
      allow(db).to receive(:get_first_value).and_return('true')

      described_class.enabled?(:ttl_flag)

      # Advance past TTL
      allow(Time).to receive(:now).and_return(Time.at(1061.0))

      described_class.enabled?(:ttl_flag)

      expect(db).to have_received(:get_first_value).twice
    end

    it 'maintains independent cache entries for different flag names' do
      allow(db).to receive(:get_first_value).and_return('true', 'false')

      described_class.enabled?(:flag_a)
      described_class.enabled?(:flag_b)

      expect(db).to have_received(:get_first_value).twice
      expect(described_class.enabled?(:flag_a)).to be(true)
      expect(described_class.enabled?(:flag_b)).to be(false)
    end

    it 'stores the resolved boolean, not the raw DB string' do
      allow(db).to receive(:get_first_value).and_return('YES')

      result = described_class.enabled?(:bool_flag)

      expect(result).to be(true)
      expect(result).not_to eq('YES')
    end

    it 'caches nil DB result (unpersisted flag) as the default value' do
      allow(db).to receive(:get_first_value).and_return(nil)

      described_class.enabled?(:missing_flag)
      result = described_class.enabled?(:missing_flag)

      expect(result).to be(false)
      expect(db).to have_received(:get_first_value).once
    end

    it 'does not cache when the database handle is unavailable' do
      allow(Lich).to receive(:db).and_return(nil)

      described_class.enabled?(:no_db_flag)

      # DB becomes available
      allow(Lich).to receive(:db).and_return(db)
      allow(db).to receive(:get_first_value).and_return('true')

      expect(described_class.enabled?(:no_db_flag)).to be(true)
    end

    it 'does not cache when DB raises an error so next call retries' do
      call_count = 0
      allow(db).to receive(:get_first_value) do
        call_count += 1
        raise StandardError, 'db down' if call_count == 1

        'true'
      end
      allow(Lich).to receive(:log)

      # First call -- DB error, returns default, not cached
      expect(described_class.enabled?(:retry_flag)).to be(false)

      # Second call -- DB recovered, should hit DB again
      expect(described_class.enabled?(:retry_flag)).to be(true)
      expect(call_count).to eq(2)
    end
  end

  describe 'cache write-through on .set' do
    it 'writes the new resolved value to cache on successful set' do
      allow(db).to receive(:get_first_value).and_return('true')
      allow(db).to receive(:execute)

      described_class.enabled?(:inv_flag)
      described_class.set(:inv_flag, false)

      # Cache now holds the set value -- no DB read needed
      expect(described_class.enabled?(:inv_flag)).to be(false)
      expect(db).to have_received(:get_first_value).once
    end

    it 'does not affect other flags cache entries' do
      allow(db).to receive(:get_first_value).and_return('true')
      allow(db).to receive(:execute)

      described_class.enabled?(:keep_flag)
      described_class.enabled?(:change_flag)

      described_class.set(:change_flag, false)

      # keep_flag should still be cached (no extra DB call)
      described_class.enabled?(:keep_flag)
      # get_first_value was called twice (once per flag), not a third time
      expect(db).to have_received(:get_first_value).twice
    end

    it 'does not update cache when .set fails with a DB error' do
      allow(db).to receive(:get_first_value).and_return('true')
      allow(db).to receive(:execute).and_raise(StandardError, 'write failed')
      allow(Lich).to receive(:log)

      described_class.enabled?(:stable_flag)
      described_class.set(:stable_flag, false)

      # Cache should still hold the original value -- no extra DB read
      expect(described_class.enabled?(:stable_flag)).to be(true)
      expect(db).to have_received(:get_first_value).once
    end
  end

  describe '.clear_cache!' do
    it 'clears all cached entries, forcing DB reads' do
      allow(db).to receive(:get_first_value).and_return('true')

      described_class.enabled?(:cc_flag)
      described_class.clear_cache!
      described_class.enabled?(:cc_flag)

      expect(db).to have_received(:get_first_value).twice
    end

    it 'is safe to call when cache is already empty' do
      expect { described_class.clear_cache! }.not_to raise_error
    end

    it 'is safe to call concurrently from multiple threads' do
      threads = 10.times.map do
        Thread.new { 50.times { described_class.clear_cache! } }
      end

      expect { threads.each(&:join) }.not_to raise_error
    end
  end

  describe 'thread safety' do
    it 'returns valid results when multiple threads call enabled? concurrently' do
      allow(db).to receive(:get_first_value).and_return('true')

      results = Queue.new
      threads = 10.times.map do
        Thread.new do
          20.times do
            results << described_class.enabled?(:thread_flag)
          end
        end
      end

      threads.each(&:join)

      200.times do
        expect(results.pop).to be(true)
      end
    end

    it 'does not deadlock when threads call enabled? and set concurrently' do
      allow(db).to receive(:get_first_value).and_return('true')
      allow(db).to receive(:execute)

      threads = []
      5.times do
        threads << Thread.new { 20.times { described_class.enabled?(:dl_flag) } }
        threads << Thread.new { 20.times { described_class.set(:dl_flag, true) } }
      end

      # Use a timeout to detect deadlock -- if threads don't finish in
      # 5 seconds, something is stuck
      finished = threads.map { |t| t.join(5) }
      expect(finished).to all(be_truthy)
    end

    it 'cache mutex does not cause starvation under contention' do
      allow(db).to receive(:get_first_value).and_return('on')
      allow(db).to receive(:execute)

      completed = Concurrent::AtomicFixnum.new(0) if defined?(Concurrent)
      completed = Queue.new unless defined?(Concurrent)

      threads = 8.times.map do
        Thread.new do
          30.times do
            described_class.enabled?(:contention_flag)
            described_class.set(:contention_flag, true)
          end
          if completed.is_a?(Queue)
            completed << 1
          else
            completed.increment
          end
        end
      end

      timed_out = threads.any? { |t| t.join(10).nil? }
      expect(timed_out).to be(false)

      count = completed.is_a?(Queue) ? completed.size : completed.value
      expect(count).to eq(8)
    end
  end

  describe 'TTL edge cases' do
    it 'keeps cache entry valid at exactly the TTL boundary' do
      now = Time.at(2000.0)
      allow(Time).to receive(:now).and_return(now)
      allow(db).to receive(:get_first_value).and_return('true')

      described_class.enabled?(:boundary_flag)

      # At exactly TTL seconds, age == TTL, and the > check is false
      ttl = described_class::CACHE_TTL_SECONDS
      allow(Time).to receive(:now).and_return(Time.at(2000.0 + ttl))

      described_class.enabled?(:boundary_flag)

      expect(db).to have_received(:get_first_value).once
    end

    it 'expires cache entry just past the TTL boundary' do
      now = Time.at(2000.0)
      allow(Time).to receive(:now).and_return(now)
      allow(db).to receive(:get_first_value).and_return('true')

      described_class.enabled?(:boundary_flag)

      ttl = described_class::CACHE_TTL_SECONDS
      allow(Time).to receive(:now).and_return(Time.at(2000.0 + ttl + 0.001))

      described_class.enabled?(:boundary_flag)

      expect(db).to have_received(:get_first_value).twice
    end

    it 'does not crash with a negative TTL and always goes to DB' do
      stub_const("#{described_class}::CACHE_TTL_SECONDS", -1)
      allow(db).to receive(:get_first_value).and_return('true')

      3.times { described_class.enabled?(:neg_ttl_flag) }

      expect(db).to have_received(:get_first_value).exactly(3).times
    end

    it 'treats backward clock movement as cache expiration' do
      allow(db).to receive(:get_first_value).and_return('true')

      # Cache at t=2000
      allow(Time).to receive(:now).and_return(Time.at(2000.0))
      described_class.enabled?(:clock_flag)

      # Clock jumps backward to t=1000, age = (1000 - 2000) = -1000
      # Negative age is treated as expired to avoid unbounded staleness
      allow(Time).to receive(:now).and_return(Time.at(1000.0))
      described_class.enabled?(:clock_flag)

      expect(db).to have_received(:get_first_value).twice
    end
  end

  describe 'adversarial scenarios' do
    it 'serves stale value until TTL then returns fresh value' do
      now = Time.at(3000.0)
      allow(Time).to receive(:now).and_return(now)
      allow(db).to receive(:get_first_value).and_return('true')

      expect(described_class.enabled?(:stale_flag)).to be(true)

      # DB value changes behind our back
      allow(db).to receive(:get_first_value).and_return('false')

      # Still within TTL -- stale cached value served
      allow(Time).to receive(:now).and_return(Time.at(3030.0))
      expect(described_class.enabled?(:stale_flag)).to be(true)

      # Past TTL -- fresh DB value served
      allow(Time).to receive(:now).and_return(Time.at(3061.0))
      expect(described_class.enabled?(:stale_flag)).to be(false)
    end

    it 'serves fresh value after rapid set/enabled? interleaving' do
      allow(db).to receive(:get_first_value).and_return('true')
      allow(db).to receive(:execute)

      described_class.enabled?(:rapid_flag)

      # set writes through to cache
      described_class.set(:rapid_flag, false)

      # Next enabled? serves from cache with the set value
      expect(described_class.enabled?(:rapid_flag)).to be(false)
      expect(db).to have_received(:get_first_value).once
    end

    it 'serves cached values when DB goes down, then falls back to default after TTL' do
      now = Time.at(4000.0)
      allow(Time).to receive(:now).and_return(now)
      allow(db).to receive(:get_first_value).and_return('true')
      allow(Lich).to receive(:log)

      # Populate cache
      expect(described_class.enabled?(:downtime_flag)).to be(true)

      # DB goes down
      allow(db).to receive(:get_first_value).and_raise(StandardError, 'connection refused')

      # Within TTL -- cached value still served, no DB call
      allow(Time).to receive(:now).and_return(Time.at(4030.0))
      expect(described_class.enabled?(:downtime_flag)).to be(true)

      # Past TTL -- cache expired, DB call fails, fallback to default
      allow(Time).to receive(:now).and_return(Time.at(4061.0))
      expect(described_class.enabled?(:downtime_flag)).to be(false)
    end
  end
end
