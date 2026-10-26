# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui'
require 'weakref'

RSpec.describe 'Runtime render coordination' do
  let(:registry) { Lich::WebUI::Registry.new }
  let(:runtime) { Lich::WebUI::Runtime.new(registry: registry) }
  let(:owner) { Object.new }

  after { runtime.shutdown }

  it 'coalesces repeated changes into the original worker and admits fresh work after it retires' do
    entered, release, repeated = Queue.new, Queue.new, Queue.new
    key = Object.new
    calls = 0
    worker = nil
    runtime.schedule_render(key, owner: owner, delay: 0) do
      calls += 1
      if calls == 1
        entered << Thread.current
        release.pop
      else
        repeated << true
      end
    end
    worker = entered.pop(timeout: 2)
    replacement = double('coalesced replacement')
    expect(replacement).not_to receive(:call)
    3.times { runtime.schedule_render(key, owner: owner, delay: 0) { replacement.call } }
    release << true
    expect(repeated.pop(timeout: 2)).to be(true)
    expect(worker.join(2)).to equal(worker)
    expect(calls).to eq(2)
    fresh = Queue.new
    runtime.schedule_render(key, owner: owner, delay: 0) { fresh << Thread.current }
    worker = fresh.pop(timeout: 2)
    expect(worker.join(2)).to equal(worker)
  ensure
    release&.push(true)
    worker&.join(2)
  end

  it 'keeps equal-looking keys and owners independent while termination closes admission before joining' do
    value = Struct.new(:label)
    first_owner, second_owner = value.new('owner'), value.new('owner')
    first_key, second_key = value.new('key'), value.new('key')
    entered, releases, joining = Queue.new, [Queue.new, Queue.new], Queue.new
    workers = []
    stopper = nil
    [first_owner, second_owner].each_with_index do |selected, index|
      key = index.zero? ? first_key : second_key
      runtime.schedule_render(key, owner: selected, delay: 0) do
        entered << [index, Thread.current]
        releases[index].pop
      end
    end
    2.times do
      index, worker = entered.pop(timeout: 2)
      workers[index] = worker
    end
    expect(workers.uniq.length).to eq(2)
    allow(workers[0]).to receive(:join).and_wrap_original do |original, *args|
      joining << true
      original.call(*args)
    end
    stopper = Thread.new { runtime.terminate_owner(first_owner) }
    expect(joining.pop(timeout: 2)).to be(true)
    expect(stopper).to be_alive
    expect do
      runtime.schedule_render(Object.new, owner: first_owner, delay: 0) {}
    end.to raise_error(Lich::WebUI::Error, 'render owner is terminated')
    admitted = Queue.new
    runtime.schedule_render(Object.new, owner: second_owner, delay: 0) { admitted << Thread.current }
    extra = admitted.pop(timeout: 2)
    expect(extra.join(2)).to equal(extra)
    releases[0] << true
    expect(stopper.join(2)).to equal(stopper)
    expect(workers[1]).to be_alive
    releases[1] << true
    expect(workers[1].join(2)).to equal(workers[1])
  ensure
    releases&.each { |release| release << true }
    stopper&.join(2)
    workers&.compact&.each { |worker| worker.join(2) }
  end

  it 'closes host render admission before joining already accepted work' do
    entered, release, joining = Queue.new, Queue.new, Queue.new
    worker = stopper = nil
    runtime.schedule_render(Object.new, owner: owner, delay: 0) do
      entered << Thread.current
      release.pop
    end
    worker = entered.pop(timeout: 2)
    allow(worker).to receive(:join).and_wrap_original do |original, *args|
      joining << true
      original.call(*args)
    end
    stopper = Thread.new { runtime.shutdown }
    expect(joining.pop(timeout: 2)).to be(true)
    expect(stopper).to be_alive
    expect do
      runtime.schedule_render(Object.new, owner: Object.new, delay: 0) {}
    end.to raise_error(Lich::WebUI::Error, 'render owner is terminated')
    release << true
    expect(stopper.join(2)).to equal(stopper)
  ensure
    release&.push(true)
    stopper&.join(2)
    worker&.join(2)
  end

  it 'can terminate its owner from the render worker without joining itself' do
    finished = Queue.new
    runtime.schedule_render(Object.new, owner: owner, delay: 0) do
      runtime.terminate_owner(owner)
      finished << Thread.current
    end
    worker = finished.pop(timeout: 2)
    expect(worker.join(2)).to equal(worker)
    expect do
      runtime.schedule_render(Object.new, owner: owner, delay: 0) {}
    end.to raise_error(Lich::WebUI::Error, 'render owner is terminated')
  end

  it 'reports a failed worker once and releases its key for later work' do
    logs, entered = Queue.new, Queue.new
    host = Lich::WebUI::Runtime.new(registry: registry, logger: ->(level, message) { logs << [level, message] })
    selected = Struct.new(:webui_owner_id).new('render-owner')
    key = Object.new
    host.schedule_render(key, owner: selected, delay: 0) do
      entered << Thread.current
      raise 'private failure detail'
    end
    worker = entered.pop(timeout: 2)
    expect(worker.join(2)).to equal(worker)
    expect(logs.pop(timeout: 2)).to eq([:error, 'WebUI refresh failed owner=render-owner error=RuntimeError'])
    expect(logs).to be_empty
    host.schedule_render(key, owner: selected, delay: 0) { entered << Thread.current }
    worker = entered.pop(timeout: 2)
    expect(worker.join(2)).to equal(worker)
    expect(logs).to be_empty
  ensure
    host&.shutdown
  end

  it 'does not retain an owner solely through render retirement records' do
    reference = Thread.new do
      retired = Object.new
      runtime.terminate_owner(retired)
      WeakRef.new(retired)
    end.value
    3.times { GC.start(full_mark: true, immediate_sweep: true) }
    expect(reference.weakref_alive?).not_to be(true)
  end
end
