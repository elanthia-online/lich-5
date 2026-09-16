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
    # dying worker's sentinel, on a queue nothing drains again. Wait for
    # the thread to actually block (or finish, in the unlocked case)
    # rather than sleeping and hoping it got scheduled.
    wait_until_parked(ingest)
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

  # Blocks until +thread+ is parked on a lock (status 'sleep') or has
  # finished, bounded so a wedged test fails instead of hanging.
  def wait_until_parked(thread, deadline: 5)
    finish = Process.clock_gettime(Process::CLOCK_MONOTONIC) + deadline
    until thread.stop?
      raise "thread never parked: #{thread.status.inspect}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > finish

      Thread.pass
    end
  end

  # Holds the worker's shutdown open at the sentinel, ingests one chunk in
  # that window, then lets shutdown finish. Yields [old worker, ingest
  # thread] once both the lifecycle call and the ingest have returned.
  def with_chunk_arriving_during(lifecycle)
    tracker.send(:initialize_processor)
    first = tracker.instance_variable_get(:@async_processor)
    in_shutdown = Queue.new
    release = Queue.new
    real_shutdown = first.method(:shutdown)
    allow(first).to receive(:shutdown) do
      in_shutdown << true
      release.pop
      real_shutdown.call
    end

    caller = Thread.new(&lifecycle)
    in_shutdown.pop
    ingest = Thread.new { tracker.process(['You swing a broadsword at a rat!']) }
    wait_until_parked(ingest)
    release << true
    caller.join
    ingest.join
    first
  end

  # The same race as reload_defs!, at the other two places the worker is
  # replaced or torn down.
  it 'disable! neither strands a chunk behind the dying worker nor parses it afterwards' do
    parsed = 0
    allow(Lich::Gemstone::Combat::Processor).to receive(:process) { parsed += 1 }
    allow(tracker).to receive(:save_settings)
    allow(tracker).to receive(:remove_downstream_hook)

    tracker.send(:initialize_processor)
    first = tracker.instance_variable_get(:@async_processor)

    # The chunk has to be PAST process's leading enabled? check when
    # disable! starts, or it is simply dropped there and the race is never
    # run. Hold it inside the relevance filter, which runs after that check.
    in_filter = Queue.new
    resume_filter = Queue.new
    allow(tracker).to receive(:combat_relevant?) do
      in_filter << true
      resume_filter.pop
      true
    end
    in_shutdown = Queue.new
    release = Queue.new
    real_shutdown = first.method(:shutdown)
    allow(first).to receive(:shutdown) do
      in_shutdown << true
      release.pop
      real_shutdown.call
    end

    ingest = Thread.new { tracker.process(['You swing a broadsword at a rat!']) }
    in_filter.pop
    disabler = Thread.new { tracker.disable! }
    in_shutdown.pop
    # disable! is now inside the drain. Let the chunk go: with the lock it
    # parks, then finds tracking off and drops; without it, it is pushed to
    # the worker being torn down and parsed after disable! has returned.
    resume_filter << true
    wait_until_parked(ingest)
    release << true
    disabler.join
    ingest.join

    expect(tracker.enabled?).to be(false)
    expect(first.stats[:queued]).to eq(0)
    expect(parsed).to eq(0)
  end

  it 'configure(max_threads:) hands a chunk arriving mid-swap to the new worker' do
    processed = Queue.new
    allow(Lich::Gemstone::Combat::Processor).to receive(:process) { |chunk, **_| processed << chunk }
    allow(tracker).to receive(:save_settings)

    first = with_chunk_arriving_during(-> { tracker.configure(max_threads: 1) })

    second = tracker.instance_variable_get(:@async_processor)
    expect(second).not_to equal(first)
    second.shutdown
    expect(second.stats[:total]).to eq(1)
    expect(first.stats[:total]).to eq(0)
    expect(processed.size).to eq(1)
  end

  # Subscribers to :definitions_reloaded are arbitrary script code. Run under
  # the ingestion lock, a slow one stalls the game-stream hook thread and one
  # that reloads again hits recursive locking; so they run after release.
  it 'notifies definitions_reloaded subscribers after releasing the ingestion lock' do
    lock = tracker.instance_variable_get(:@reload_lock)
    held = :unset
    Lich::Common::Events.on('combat.definitions_reloaded', name: 'spec-lock-probe') { |_t, _d| held = lock.locked? }

    tracker.reload_defs!

    expect(held).to be(false)
  ensure
    Lich::Common::Events.off('spec-lock-probe')
  end

  it 'leaves no worker behind when tracking is off' do
    tracker.send(:initialize_processor)
    tracker.instance_variable_set(:@enabled, false)
    tracker.reload_defs!
    expect(tracker.instance_variable_get(:@async_processor)).to be_nil
  end
end
