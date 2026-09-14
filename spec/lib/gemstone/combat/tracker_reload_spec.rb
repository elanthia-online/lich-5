# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/processor'

# Tracker.reload_defs! is the documented in-session path after editing the
# supplement file. It has to be callable, and it has to replace the async
# worker without losing chunks that arrive while the old one is draining.
RSpec.describe 'Tracker.reload_defs!' do
  let(:tracker) { Lich::Gemstone::Combat::Tracker }

  around do |example|
    store_feature = File.expand_path('common/db_store.rb', LIB_DIR)
    store_preloaded = $LOADED_FEATURES.include?(store_feature)
    example.run
  ensure
    $LOADED_FEATURES.delete(store_feature) unless store_preloaded
  end

  before do
    stub_const('Lich::Gemstone::Combat::Tracker', Module.new)
    stub_const('Lich::Common::DB_Store', Module.new)
    allow(Thread).to receive(:new).and_return(nil)
    load File.join(LIB_DIR, 'gemstone/combat/tracker.rb')
    allow(Thread).to receive(:new).and_call_original
    allow(Lich::Gemstone::Combat::Processor).to receive(:process)
    tracker.instance_variable_set(:@settings, tracker::DEFAULT_SETTINGS.merge(max_threads: 1, enabled: true))
    tracker.instance_variable_set(:@initialized, true)
    tracker.instance_variable_set(:@enabled, true)
    allow(Lich::Gemstone::Combat::Definitions::Supplements).to receive(:reload_defs!).and_return([])
  end

  # Below the module's `private`, `Tracker.reload_defs!` raised NoMethodError
  # for every caller the docs point at (`;e ...reload_defs!`, a script, the
  # tracker's own debug output).
  it 'is callable as a public method' do
    expect(tracker.respond_to?(:reload_defs!)).to be(true)
    expect { tracker.reload_defs! }.not_to raise_error
  end

  it 'reports the files Supplements reloaded' do
    allow(Lich::Gemstone::Combat::Definitions::Supplements).to receive(:reload_defs!).and_return(%w[a.rb b.rb])
    expect(tracker.reload_defs!).to eq(%w[a.rb b.rb])
  end

  # Ingestion read @async_processor, then the reload drained and replaced
  # that worker, and the push landed behind the old queue's shutdown
  # sentinel -- a chunk accepted from the game stream and never parsed.
  it 'does not strand a chunk that arrives while the worker is being replaced' do
    processed = Queue.new
    allow(Lich::Gemstone::Combat::Processor).to receive(:process) { |chunk, **_| processed << chunk }

    tracker.send(:initialize_processor)
    first = tracker.instance_variable_get(:@async_processor)
    expect(first).not_to be_nil

    # The window is INSIDE shutdown: the sentinel is on the queue and the
    # worker is on its way out, but @async_processor still points at it.
    # A chunk enqueued here lands behind that sentinel and is never parsed.
    in_shutdown = Queue.new
    release = Queue.new
    real_shutdown = first.method(:shutdown)
    allow(first).to receive(:shutdown) do
      in_shutdown << true
      release.pop
      real_shutdown.call
    end

    reloader = Thread.new { tracker.reload_defs! }
    in_shutdown.pop

    ingest = Thread.new { tracker.process(['You swing a broadsword at a rat!']) }
    # With the lock, this thread parks until the swap completes and its
    # chunk goes to the NEW worker. Without it, the push lands behind the
    # dying worker's sentinel, on a queue nothing drains again.
    sleep 0.1
    release << true
    reloader.join
    ingest.join

    second = tracker.instance_variable_get(:@async_processor)
    expect(second).not_to equal(first)

    # It has to be the NEW worker that parsed it. Asserting only "was it
    # parsed at all" would pass either way: the old worker drains whatever
    # it reaches before its sentinel. Each processor counts its own chunks,
    # so this says which queue the push actually reached.
    second.shutdown
    expect(second.stats[:total]).to eq(1)
    expect(first.stats[:total]).to eq(0)
    expect(processed.size).to eq(1)
  end

  it 'leaves no worker behind when tracking is off' do
    tracker.send(:initialize_processor)
    tracker.instance_variable_set(:@enabled, false)
    tracker.reload_defs!
    expect(tracker.instance_variable_get(:@async_processor)).to be_nil
  end
end
