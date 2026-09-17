# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/dispatcher'

RSpec.describe Lich::WebUI::Dispatcher do
  let(:dispatcher) { described_class.new }
  let(:owner) { Object.new }

  after { dispatcher.shutdown }

  it 'delivers one page in receipt order on one owner dispatch thread' do
    delivered = Queue.new
    3.times do |index|
      dispatcher.enqueue(
        owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'button',
        event: :activate, coalescable: false
      ) { delivered << [index, Thread.current] }
    end
    results = 3.times.map { delivered.pop }

    expect(results.map(&:first)).to eq([0, 1, 2])
    expect(results.map(&:last).uniq.length).to eq(1)
    expect(results.first.last).not_to eq(Thread.current)
  end

  # Every handler exception in every native WebUI script was discarded: the
  # rescue logged only the exception class, through a logger Lich never
  # supplied, and the owner was never told.
  describe 'a callback that raises' do
    it 'tells the log the message, class and script frame, and the owner the message' do
      logged = Queue.new
      told = Queue.new
      reporting = described_class.new(logger: ->(level, message) { logged << [level, message] },
                                      notifier: ->(owner, message) { told << [owner, message] })
      script = Struct.new(:name).new('map')
      begin
        reporting.enqueue(owner: script, page_id: 'page', viewer_id: 'viewer', cid: 'button:go',
                          event: :activate, coalescable: false) do
          raise NoMethodError, "undefined method 'centre' for nil", ['map:2466:in \'recentre\'', 'lib/webui/dispatcher.rb:146:in \'run_owner\'']
        end
        level, message = logged.pop
        expect(level).to eq(:error)
        expect(message).to include("error in WebUI handler activate on button:go: undefined method 'centre' for nil at map:2466")
        expect(message).to include('owner=map error=NoMethodError')
        expect(message).to include("\n\tmap:2466")
        expect(told.pop).to eq([script, "error in WebUI handler activate on button:go: undefined method 'centre' for nil at map:2466"])
      ensure
        reporting.shutdown
      end
    end

    it 'goes on to the next callback for the same owner' do
      ran = Queue.new
      dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'a', event: :activate,
                         coalescable: false) { raise 'first' }
      dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'b', event: :activate,
                         coalescable: false) { ran << :second }
      expect(ran.pop).to eq(:second)
    end

    it 'by default tells a Script owner through respond, and no one else' do
      stub_const('Script', Class.new)
      said = []
      dispatcher.define_singleton_method(:respond) { |message| said << message }
      expect(dispatcher.send(:notify_script, Script.new, 'boom')).to eq(['boom'])
      expect(dispatcher.send(:notify_script, Object.new, 'boom')).to be_nil
      expect(said).to eq(['boom'])
    end
  end

  it 'runs different owners independently' do
    started = Queue.new
    release = Queue.new
    two_owners = [Object.new, Object.new]
    two_owners.each do |candidate|
      dispatcher.enqueue(
        owner: candidate, page_id: 'page', viewer_id: 'viewer', cid: 'button',
        event: :activate, coalescable: false
      ) do
        started << Thread.current
        release.pop
      end
    end

    threads = 2.times.map { started.pop }
    expect(threads.uniq.length).to eq(2)
    2.times { release << true }
  end

  it 'ignores every callback return value' do
    delivered = Queue.new
    [nil, false, [], Thread.current].each do |value|
      dispatcher.enqueue(
        owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'button',
        event: :activate, coalescable: false
      ) do
        delivered << value
        value
      end
    end

    expect(4.times.map { delivered.pop }).to eq([nil, false, [], Thread.current])
  end

  it 'coalesces only consecutive coalescable events and preserves terminals' do
    started = Queue.new
    release = Queue.new
    delivered = Queue.new
    dispatcher.enqueue(
      owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'blocker',
      event: :activate, coalescable: false
    ) do
      started << true
      release.pop
    end
    started.pop
    expect(dispatcher.enqueue(
      owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'input', event: :change, coalescable: true
    ) { delivered << 1 }).to eq(:queued)
    expect(dispatcher.enqueue(
      owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'input', event: :change, coalescable: true
    ) { delivered << 2 }).to eq(:coalesced)
    3.times do |index|
      dispatcher.enqueue(
        owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'button',
        event: :activate, coalescable: false
      ) { delivered << index + 3 }
    end
    release << true

    expect(4.times.map { delivered.pop }).to eq([2, 3, 4, 5])
  end

  it 'refuses overflow without dropping an already accepted terminal event' do
    started = Queue.new
    release = Queue.new
    dispatcher.enqueue(
      owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'blocker',
      event: :activate, coalescable: false
    ) do
      started << true
      release.pop
    end
    started.pop
    described_class::VIEWER_LIMIT.times do |index|
      dispatcher.enqueue(
        owner: owner, page_id: 'page', viewer_id: 'viewer', cid: "button-#{index}",
        event: :activate, coalescable: false
      ) {}
    end

    expect do
      dispatcher.enqueue(
        owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'overflow',
        event: :activate, coalescable: false
      ) {}
    end.to raise_error(Lich::WebUI::Dispatcher::OverflowError)
  ensure
    release << true
  end

  # Bounds are enforced by evicting the oldest coalescable events first.
  # This pins the eviction result so the count bookkeeping inside
  # enforce_bounds! can change shape without changing what survives.
  it 'evicts the oldest coalescable events, one per excess, to admit a new event at the limit' do
    started = Queue.new
    release = Queue.new
    delivered = Queue.new
    dispatcher.enqueue(
      owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'blocker',
      event: :activate, coalescable: false
    ) do
      started << true
      release.pop
    end
    started.pop
    # Distinct cids, so none of these coalesce with its predecessor.
    described_class::VIEWER_LIMIT.times do |index|
      dispatcher.enqueue(
        owner: owner, page_id: 'page', viewer_id: 'viewer', cid: "input-#{index}",
        event: :change, coalescable: true
      ) { delivered << index }
    end
    2.times do |extra|
      expect(dispatcher.enqueue(
        owner: owner, page_id: 'page', viewer_id: 'viewer', cid: "terminal-#{extra}",
        event: :activate, coalescable: false
      ) { delivered << "terminal-#{extra}" }).to eq(:queued)
    end
    release << true

    results = described_class::VIEWER_LIMIT.times.map { delivered.pop }
    # The two oldest coalescable events made room; everything else survived in order.
    expect(results).to eq([*2...described_class::VIEWER_LIMIT, 'terminal-0', 'terminal-1'])
  end

  # shutdown_owner waits a bounded time for the owner's callback and then
  # drops the owner state whether or not it returned. Enqueuing for the same
  # owner afterwards found no state, made a fresh one, and started a second
  # worker beside the first, still blocked in its callback. Late producers
  # are real: browser-exit callbacks and timers fire after teardown.
  it 'refuses a late enqueue for a shut-down owner instead of reviving it' do
    stub_const('Lich::WebUI::Dispatcher::SHUTDOWN_JOIN_TIMEOUT', 0.05)
    started = Queue.new
    release = Queue.new
    ran = Queue.new
    dispatcher.enqueue(
      owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'blocker',
      event: :activate, coalescable: false
    ) do
      started << true
      release.pop
      ran << :first
    end
    started.pop

    expect(dispatcher.shutdown_owner(owner)).to be(true)
    expect do
      dispatcher.enqueue(
        owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'late',
        event: :activate, coalescable: false
      ) { ran << :late }
    end.to raise_error(Lich::WebUI::Dispatcher::TerminatedError)

    release << true
    expect(ran.pop).to eq(:first)
    sleep 0.05
    expect(ran).to be_empty
    expect(dispatcher.shutdown_owner(owner)).to be(false)
  end

  # The sequential case above passed while a concurrent one still revived
  # the owner: the tombstone check and the state lookup were two critical
  # sections, and a shutdown landing between them left the lookup to create
  # a fresh worker. The state lookup itself now refuses a tombstoned owner,
  # so there is no gap for a shutdown to land in.
  it 'refuses to create a worker state for an owner shut down since the enqueue began' do
    dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'a', event: :activate, coalescable: false) { nil }
    expect(dispatcher.shutdown_owner(owner)).to be(true)
    expect { dispatcher.send(:owner_state, owner) }.to raise_error(Lich::WebUI::Dispatcher::TerminatedError)
    # Nothing was created: the owner is not back in the table, so a second
    # shutdown finds nothing to stop.
    expect(dispatcher.shutdown_owner(owner)).to be(false)
  end

  it 'does not revive an owner when an enqueue races its shutdown' do
    ran = Queue.new
    workers = 50.times.map do
      subject_owner = Object.new
      dispatcher.enqueue(owner: subject_owner, page_id: 'page', viewer_id: 'viewer', cid: 'warm', event: :activate, coalescable: false) { nil }
      subject_owner
    end
    threads = workers.flat_map do |subject_owner|
      [
        Thread.new { dispatcher.shutdown_owner(subject_owner) },
        Thread.new do
          dispatcher.enqueue(owner: subject_owner, page_id: 'page', viewer_id: 'viewer', cid: 'late', event: :activate, coalescable: false) { ran << subject_owner }
        rescue Lich::WebUI::Dispatcher::TerminatedError, Lich::WebUI::Dispatcher::Error
          nil
        end
      ]
    end
    threads.each(&:join)
    sleep 0.1
    # Whatever ran, ran on a worker that existed before its shutdown; no
    # owner has a live worker afterwards.
    workers.each { |subject_owner| expect(dispatcher.shutdown_owner(subject_owner)).to be(false) }
  end

  it 'refuses synchronous waits from callbacks instead of deadlocking' do
    result = Queue.new
    dispatcher.enqueue(
      owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'button',
      event: :activate, coalescable: false
    ) do
      result << begin
        dispatcher.await('page')
      rescue StandardError => error
        error
      end
    end

    expect(result.pop).to be_a(Lich::WebUI::Dispatcher::ReentryError)
  end

  # There is one refusal, not two: the dispatcher never provides a
  # synchronous wait. Whether the caller was the page's own callback only
  # changes what the message says, so a script author can tell a deadlock
  # they nearly wrote from a wait they simply cannot have.
  it 'refuses every synchronous wait with one error that names re-entry when it is one' do
    outside = begin
      dispatcher.await('page')
    rescue StandardError => error
      error
    end
    inside = Queue.new
    dispatcher.enqueue(
      owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'button',
      event: :activate, coalescable: false
    ) do
      inside << begin
        dispatcher.await('page')
      rescue StandardError => error
        error
      end
    end
    inside = inside.pop

    expect(outside).to be_a(Lich::WebUI::Dispatcher::ReentryError)
    expect(outside.message).to eq('synchronous event waits are refused (page=page)')
    expect(outside.page_id).to eq('page')
    expect(inside).to be_a(Lich::WebUI::Dispatcher::ReentryError)
    expect(inside.message).to eq(
      "synchronous event waits are refused; this is a re-entry from the page's own callback (page=page)"
    )
    expect(inside.page_id).to eq('page')
  end
end
