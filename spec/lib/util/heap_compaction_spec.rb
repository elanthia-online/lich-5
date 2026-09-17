# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/util/heap_compaction'

# HeapCompaction is the one place core compacts the heap. With nothing
# installed it is a plain GC.compact; a runtime that must guard compaction
# (lib/util/gtk_compaction.rb) installs a strategy and every later call
# goes through it.
RSpec.describe Lich::Util::HeapCompaction do
  around do |example|
    previous = described_class.strategy
    described_class.strategy = nil
    example.run
  ensure
    described_class.strategy = previous
  end

  it 'compacts through GC.compact when no strategy is installed' do
    allow(GC).to receive(:respond_to?).and_call_original
    allow(GC).to receive(:respond_to?).with(:compact).and_return(true)
    allow(GC).to receive(:compact).and_return(:compacted)

    expect(described_class.compact!).to eq(:compacted)
    expect(GC).to have_received(:compact)
  end

  it 'does nothing when the Ruby cannot compact' do
    allow(GC).to receive(:respond_to?).and_call_original
    allow(GC).to receive(:respond_to?).with(:compact).and_return(false)
    allow(GC).to receive(:compact)

    expect(described_class.compact!).to be_nil
    expect(GC).not_to have_received(:compact)
  end

  it 'routes compaction through an installed strategy instead of GC.compact' do
    allow(GC).to receive(:respond_to?).and_call_original
    allow(GC).to receive(:respond_to?).with(:compact).and_return(true)
    allow(GC).to receive(:compact)
    calls = 0
    described_class.strategy = -> { calls += 1; :guarded }

    expect(described_class.compact!).to eq(:guarded)
    expect(calls).to eq(1)
    expect(GC).not_to have_received(:compact)
  end

  it 'restores GC.compact when the strategy is cleared' do
    allow(GC).to receive(:respond_to?).and_call_original
    allow(GC).to receive(:respond_to?).with(:compact).and_return(true)
    allow(GC).to receive(:compact)
    described_class.strategy = -> { :guarded }
    described_class.strategy = nil

    described_class.compact!

    expect(GC).to have_received(:compact)
  end
end
