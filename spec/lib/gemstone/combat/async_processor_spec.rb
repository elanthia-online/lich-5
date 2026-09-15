# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/async_processor'

# AsyncProcessor is a single ordered worker thread fed by a Queue. This spec
# locks down:
#   1. The GC.compact regression guard carried over from the thread-pool era:
#      shutdown must route compaction through GtkCompaction.safe_compact!,
#      never a raw GC.compact (raw compaction is unsafe alongside gtk3).
#   2. Queue-worker semantics: chunks are processed in arrival order on one
#      thread, enqueueing never blocks, a Processor error doesn't kill the
#      worker, and shutdown drains queued work before joining.
RSpec.describe Lich::Gemstone::Combat::AsyncProcessor do
  before do
    stub_const('Lich::Gemstone::Combat::Tracker', Module.new)
    allow(Lich::Gemstone::Combat::Tracker).to receive(:debug?).and_return(false)
    stub_const('Lich::Gemstone::Combat::Processor', Module.new)
    allow(Lich::Gemstone::Combat::Processor).to receive(:process)
  end

  def quiet_gc
    allow(GC).to receive(:start)
    allow(Lich::Util::GtkCompaction).to receive(:safe_compact!)
  end

  describe '#process_async' do
    it 'copies ingress provenance before delayed processing instead of reading current context' do
      entered, release, seen = Queue.new, Queue.new, []
      allow(Lich::Gemstone::Combat::Processor).to receive(:process) do |chunk, **metadata|
        if chunk == ['block']
          entered << true
          release.pop
        else
          seen << metadata[:source]
        end
      end
      quiet_gc
      processor = described_class.new
      processor.process_async(['block'])
      entered.pop
      source = { connection_id: 123, game: +'GSIV', character: +'Testmage', room_epoch: 4, sequence: 8, received_at: 10.0 }
      processor.process_async(['attack'], source: source)
      source[:character].replace('Changed')
      source[:room_epoch] = 5
      release << true
      processor.shutdown
      expect(seen.first).to include(character: 'Testmage', room_epoch: 4, sequence: 8, received_at: 10.0)
      expect(seen.first).to be_frozen
      expect(seen.first[:character]).to be_frozen
    ensure
      release << true if release && release.empty?
    end

    it 'processes chunks in arrival order on the worker thread' do
      seen = []
      allow(Lich::Gemstone::Combat::Processor).to receive(:process) { |chunk| seen << chunk.first }
      quiet_gc

      processor = described_class.new
      processor.process_async(['one'])
      processor.process_async(['two'])
      processor.process_async(['three'])
      processor.shutdown

      expect(seen).to eq(%w[one two three])
    end

    it 'ignores empty chunks' do
      quiet_gc
      processor = described_class.new
      processor.process_async([])
      processor.shutdown

      expect(Lich::Gemstone::Combat::Processor).not_to have_received(:process)
    end

    it 'survives a Processor error and keeps processing later chunks' do
      seen = []
      allow(Lich::Gemstone::Combat::Processor).to receive(:process) do |chunk|
        raise 'boom' if chunk.first == 'bad'
        seen << chunk.first
      end
      quiet_gc

      processor = described_class.new
      processor.process_async(['bad'])
      processor.process_async(['good'])
      processor.shutdown

      expect(seen).to eq(['good'])
    end
  end

  describe '#shutdown' do
    it 'drains queued chunks before the worker exits' do
      processed = 0
      allow(Lich::Gemstone::Combat::Processor).to receive(:process) { processed += 1 }
      quiet_gc

      processor = described_class.new
      5.times { processor.process_async(['line']) }
      processor.shutdown

      expect(processed).to eq(5)
    end

    it 'stops the worker thread' do
      quiet_gc
      processor = described_class.new
      processor.shutdown

      expect(processor.stats[:worker_alive]).to be false
    end

    it 'calls GC.start with no arguments' do
      quiet_gc
      processor = described_class.new
      processor.shutdown

      expect(GC).to have_received(:start).with(no_args)
    end

    it 'delegates compaction to Lich::Util::GtkCompaction.safe_compact!' do
      quiet_gc
      processor = described_class.new
      processor.shutdown

      expect(Lich::Util::GtkCompaction).to have_received(:safe_compact!)
    end

    it 'never calls GC.compact directly' do
      # The exact regression this guard exists to catch: a future edit that
      # "simplifies" back to a raw GC.compact call bypasses GtkCompaction's
      # safety logic entirely.
      quiet_gc
      allow(GC).to receive(:compact)
      processor = described_class.new
      processor.shutdown

      expect(GC).not_to have_received(:compact)
    end

    it 'does not raise when Tracker.debug? is true (debug logging does not interfere)' do
      allow(Lich::Gemstone::Combat::Tracker).to receive(:debug?).and_return(true)
      quiet_gc
      processor = described_class.new

      expect { processor.shutdown }.not_to raise_error
      expect(Lich::Util::GtkCompaction).to have_received(:safe_compact!)
    end
  end

  describe '#stats' do
    it 'reports queue and processing counters' do
      quiet_gc
      processor = described_class.new
      processor.process_async(['line'])
      processor.shutdown

      stats = processor.stats
      expect(stats[:total]).to eq(1)
      expect(stats[:queued]).to eq(0)
      expect(stats[:active]).to eq(0)
    end
  end
end
