# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/webui'
require 'timeout'

RSpec.describe Lich::WebUI::Scheduler do
  let(:service) { Lich::WebUI::Service.new(logger: ->(*args) { @logs << args }) }
  let(:owner) { Object.new }
  let(:scheduler) { service.runtime.scheduler }
  let(:handle) { scheduler.for_owner(owner) }

  before { @logs = [] }
  after { service.stop }

  def barrier
    ready = Queue.new
    service.runtime.dispatch(owner: owner) { ready << Thread.current }
    ready.pop(timeout: 2)
  end

  def queued(id)
    Timeout.timeout(2) do
      loop do
        state = scheduler.instance_variable_get(:@mutex).synchronize { scheduler.instance_variable_get(:@sources)[id]&.fetch(:state) }
        break if state == :queued

        sleep 0.001
      end
    end
  end

  it 'runs repeated callbacks on the existing owner worker and stops on false/nil' do
    worker = barrier
    results = Queue.new
    count = 0
    id = handle.schedule(1) { results << Thread.current; (count += 1) < 3 }
    expect(3.times.map { results.pop(timeout: 2) }).to eq([worker] * 3)
    barrier
    expect(handle.cancel(id)).to be(false)
    second = handle.schedule(0) { results << :once; nil }
    expect(results.pop(timeout: 2)).to eq(:once)
    barrier
    expect(handle.cancel(second)).to be(false)
  end

  it 'cancels already queued work before it executes and never overlaps ticks' do
    started, release, results = Queue.new, Queue.new, Queue.new
    service.runtime.dispatch(owner: owner) { started << true; release.pop }
    expect(started.pop(timeout: 2)).to be(true)
    id = handle.schedule(0) { results << :unexpected; true }
    queued(id)
    sleep 0.01
    expect(handle.cancel(id)).to be(true)
    expect(handle.cancel(id)).to be(false)
    release << true
    barrier
    expect(results).to be_empty
  ensure
    release << true
  end

  it 'lets an executing callback finish but cancellation prevents rearming' do
    started, release = Queue.new, Queue.new
    calls = 0
    id = handle.schedule(0) { calls += 1; started << true; release.pop; true }
    expect(started.pop(timeout: 2)).to be(true)
    expect(handle.cancel(id)).to be(true)
    release << true
    barrier
    expect(calls).to eq(1)
    expect(handle.cancel(id)).to be(false)
  ensure
    release << true
  end

  it 'uses owner identity, refuses foreign removal, and keeps handle cleanup scoped' do
    other = scheduler.for_owner(Object.new)
    native = scheduler.for_owner(owner)
    id = handle.schedule(60_000) { true }
    retained = native.schedule(60_000) { true }
    expect { other.cancel(id) }.to raise_error(Lich::WebUI::Error, /another owner/)
    handle.cancel_all
    expect(handle.cancel(id)).to be(false)
    expect(native.cancel(retained)).to be(true)
    expect(other.cancel(id)).to be(false)
  end

  it 'retires failed callbacks and permits later owner work' do
    failed = Queue.new
    id = handle.schedule(0) { failed << true; raise 'fixture failure' }
    expect(failed.pop(timeout: 2)).to be(true)
    expect(barrier).to be_a(Thread)
    expect(handle.cancel(id)).to be(false)
    expect(@logs.flatten.join).to include('callback failed')
  end

  it 'closes admission and retires sources on owner and host shutdown' do
    id = handle.schedule(60_000) { true }
    service.runtime.terminate_owner(owner)
    expect(handle.cancel(id)).to be(false)
    expect { handle.schedule(0) {} }.to raise_error(Lich::WebUI::Error)
    other = scheduler.for_owner(Object.new)
    other.schedule(60_000) { true }
    service.stop
    expect { other.schedule(0) {} }.to raise_error(Lich::WebUI::Error)
    expect(scheduler.instance_variable_get(:@thread)).not_to be_alive
  end

  it 'bounds intervals, owner sources and total host sources without allocating extra threads' do
    [-1, 0.5, Float::NAN, described_class::MAX_INTERVAL_MS + 1].each do |interval|
      expect { handle.schedule(interval) {} }.to raise_error(ArgumentError)
    end
    expect { handle.schedule(0) }.to raise_error(ArgumentError)
    stub_const('Lich::WebUI::Scheduler::OWNER_LIMIT', 2)
    stub_const('Lich::WebUI::Scheduler::HOST_LIMIT', 3)
    2.times { handle.schedule(60_000) { true } }
    thread = scheduler.instance_variable_get(:@thread)
    expect { handle.schedule(0) {} }.to raise_error(Lich::WebUI::Error, /limit/)
    scheduler.for_owner(Object.new).schedule(60_000) { true }
    expect { scheduler.for_owner(Object.new).schedule(0) {} }.to raise_error(Lich::WebUI::Error, /limit/)
    expect(scheduler.instance_variable_get(:@thread)).to equal(thread)
    expect(thread.group).to equal(ThreadGroup::Default)
  end

  it 'retires sources refused by a full dispatcher without leaking their registrations' do
    started, release = Queue.new, Queue.new
    service.runtime.dispatch(owner: owner) { started << true; release.pop }
    expect(started.pop(timeout: 2)).to be(true)
    stub_const('Lich::WebUI::Dispatcher::VIEWER_LIMIT', 1)
    service.runtime.dispatch(owner: owner) {}
    id = handle.schedule(0) { raise 'must not run' }
    Timeout.timeout(2) { sleep 0.001 until @logs.flatten.join.include?('scheduled callback refused') }
    expect(handle.cancel(id)).to be(false)
  ensure
    release << true
  end

  it 'does not let cleanup from a completed tick cancel a subsequently queued tick' do
    items = Queue.new
    dispatcher = Object.new
    dispatcher.define_singleton_method(:enqueue) { |cleanup:, **, &work| items << [work, cleanup] }
    clock = described_class.new(dispatcher: dispatcher, admission: ->(_) {}, logger: ->(*) {})
    calls = 0
    port = clock.for_owner(owner)
    id = port.schedule(0) { (calls += 1) < 2 }
    first = items.pop(timeout: 2)
    expect(first).not_to be_nil
    first[0].call
    second = items.pop(timeout: 2)
    expect(second).not_to be_nil
    first[1].call
    second[0].call
    second[1].call
    expect(calls).to eq(2)
    expect(port.cancel(id)).to be(false)
  ensure
    clock&.shutdown
  end
end
