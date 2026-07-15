# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/async_processor'

# Narrow, isolated coverage for AsyncProcessor's two GC.compact call sites
# (#shutdown, and the hourly path inside the private #cleanup_dead_threads),
# both of which moved from a raw GC.compact to
# Lich::Util::GtkCompaction.safe_compact! in this branch. Deliberately does
# not exercise real chunk processing / Processor.process / thread spawning
# -- that's full combat integration, out of scope here. The only thing
# being locked down is: does this class still call GC.compact directly
# anywhere (it must not), and does it delegate to safe_compact! at the
# right times.
RSpec.describe Lich::Gemstone::Combat::AsyncProcessor do
  before do
    stub_const('Lich::Gemstone::Combat::Tracker', Module.new)
    allow(Lich::Gemstone::Combat::Tracker).to receive(:debug?).and_return(false)
  end

  describe '#shutdown' do
    it 'joins and clears the thread pool' do
      processor = described_class.new
      thread = instance_double(Thread, alive?: false, join: true)
      processor.instance_variable_set(:@thread_pool, [thread])
      allow(GC).to receive(:start)
      allow(Lich::Util::GtkCompaction).to receive(:safe_compact!)

      processor.shutdown

      expect(thread).to have_received(:join)
      expect(processor.instance_variable_get(:@thread_pool)).to be_empty
    end

    it 'calls GC.start with no arguments' do
      processor = described_class.new
      allow(GC).to receive(:start)
      allow(Lich::Util::GtkCompaction).to receive(:safe_compact!)

      processor.shutdown

      expect(GC).to have_received(:start).with(no_args)
    end

    it 'delegates compaction to Lich::Util::GtkCompaction.safe_compact!' do
      processor = described_class.new
      allow(GC).to receive(:start)
      allow(Lich::Util::GtkCompaction).to receive(:safe_compact!)

      processor.shutdown

      expect(Lich::Util::GtkCompaction).to have_received(:safe_compact!)
    end

    it 'never calls GC.compact directly' do
      # This is the exact regression this file exists to catch: a future
      # edit that reverts (or "simplifies") this back to a raw GC.compact
      # call bypasses GtkCompaction's safety logic entirely.
      processor = described_class.new
      allow(GC).to receive(:start)
      allow(GC).to receive(:compact)
      allow(Lich::Util::GtkCompaction).to receive(:safe_compact!)

      processor.shutdown

      expect(GC).not_to have_received(:compact)
    end

    it 'still compacts correctly when Tracker.debug? is true (debug logging does not interfere)' do
      # Every other example in this file stubs Tracker.debug? to false, so
      # the "Waiting for N threads..." respond call is otherwise dead code
      # as far as this spec is concerned.
      allow(Lich::Gemstone::Combat::Tracker).to receive(:debug?).and_return(true)
      processor = described_class.new
      thread = instance_double(Thread, alive?: false, join: true)
      processor.instance_variable_set(:@thread_pool, [thread])
      allow(GC).to receive(:start)
      allow(Lich::Util::GtkCompaction).to receive(:safe_compact!)

      expect { processor.shutdown }.not_to raise_error
      expect(Lich::Util::GtkCompaction).to have_received(:safe_compact!)
    end
  end

  describe '#cleanup_dead_threads (private -- hourly compaction path)' do
    def stub_compact_supported(supported)
      allow(GC).to receive(:respond_to?).and_call_original
      allow(GC).to receive(:respond_to?).with(:compact).and_return(supported)
    end

    it 'does not compact exactly at the 3600s boundary (strictly greater-than, not >=)' do
      # Real Time.now drifts forward between instance_variable_set and the
      # actual check inside cleanup_dead_threads -- a few microseconds of
      # test overhead is enough to push "exactly 3600" past the boundary
      # and defeat the point of a boundary test. Freeze time so both sides
      # of the comparison see the exact same instant.
      frozen_now = Time.now
      allow(Time).to receive(:now).and_return(frozen_now)
      processor = described_class.new
      processor.instance_variable_set(:@last_compact, frozen_now - 3600)
      stub_compact_supported(true)
      allow(Lich::Util::GtkCompaction).to receive(:safe_compact!)

      processor.send(:cleanup_dead_threads)

      expect(Lich::Util::GtkCompaction).not_to have_received(:safe_compact!)
    end

    it 'does not compact when @last_compact is in the future (clock skew), and does not raise' do
      processor = described_class.new
      processor.instance_variable_set(:@last_compact, Time.now + 60)
      stub_compact_supported(true)
      allow(Lich::Util::GtkCompaction).to receive(:safe_compact!)

      expect { processor.send(:cleanup_dead_threads) }.not_to raise_error
      expect(Lich::Util::GtkCompaction).not_to have_received(:safe_compact!)
    end

    it 'does not compact when the hourly interval has not elapsed' do
      processor = described_class.new
      processor.instance_variable_set(:@last_compact, Time.now)
      stub_compact_supported(true)
      allow(Lich::Util::GtkCompaction).to receive(:safe_compact!)

      processor.send(:cleanup_dead_threads)

      expect(Lich::Util::GtkCompaction).not_to have_received(:safe_compact!)
    end

    it 'delegates to Lich::Util::GtkCompaction.safe_compact! once the hourly interval has elapsed' do
      processor = described_class.new
      processor.instance_variable_set(:@last_compact, Time.now - 3601)
      stub_compact_supported(true)
      allow(GC).to receive(:start)
      allow(Lich::Util::GtkCompaction).to receive(:safe_compact!)

      processor.send(:cleanup_dead_threads)

      expect(Lich::Util::GtkCompaction).to have_received(:safe_compact!)
    end

    it 'updates @last_compact after compacting, so it does not fire again immediately' do
      processor = described_class.new
      stale_time = Time.now - 3601
      processor.instance_variable_set(:@last_compact, stale_time)
      stub_compact_supported(true)
      allow(GC).to receive(:start)
      allow(Lich::Util::GtkCompaction).to receive(:safe_compact!)

      processor.send(:cleanup_dead_threads)

      expect(processor.instance_variable_get(:@last_compact)).to be > stale_time
    end

    it 'does not compact when GC does not respond_to?(:compact), even past the hourly interval' do
      processor = described_class.new
      processor.instance_variable_set(:@last_compact, Time.now - 3601)
      stub_compact_supported(false)
      allow(Lich::Util::GtkCompaction).to receive(:safe_compact!)

      processor.send(:cleanup_dead_threads)

      expect(Lich::Util::GtkCompaction).not_to have_received(:safe_compact!)
    end

    it 'never calls GC.compact directly' do
      processor = described_class.new
      processor.instance_variable_set(:@last_compact, Time.now - 3601)
      stub_compact_supported(true)
      allow(GC).to receive(:start)
      allow(GC).to receive(:compact)
      allow(Lich::Util::GtkCompaction).to receive(:safe_compact!)

      processor.send(:cleanup_dead_threads)

      expect(GC).not_to have_received(:compact)
    end

    it 'does not trigger safe_compact! merely from dead-thread cleanup when the hourly interval has not elapsed' do
      # Adversarial: this method has two independent GC-triggering
      # branches (dead-thread count > 10 -> plain GC.start; hourly elapsed
      # -> safe_compact!). Confirms they stay decoupled -- a busy pool with
      # many dead threads must not accidentally also trigger compaction.
      processor = described_class.new
      processor.instance_variable_set(:@last_compact, Time.now)
      processor.instance_variable_set(:@thread_pool, Array.new(15) { instance_double(Thread, alive?: false) })
      stub_compact_supported(true)
      allow(GC).to receive(:start)
      allow(Lich::Util::GtkCompaction).to receive(:safe_compact!)

      processor.send(:cleanup_dead_threads)

      expect(GC).to have_received(:start)
      expect(Lich::Util::GtkCompaction).not_to have_received(:safe_compact!)
    end
  end
end
