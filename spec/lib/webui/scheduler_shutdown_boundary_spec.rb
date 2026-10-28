# frozen_string_literal: true

require_relative '../../spec_helper'
require 'timeout'
require 'webui/scheduler'

RSpec.describe Lich::WebUI::Scheduler, 'shutdown boundary' do
  let(:owner) { Object.new }
  let(:dispatcher) { double('dispatcher') }
  let(:messages) { [] }
  let(:logger) { ->(*entry) { messages << entry } }
  let(:scheduler) { described_class.new(dispatcher: dispatcher, admission: ->(_) {}, logger: logger) }

  it 'returns within the join budget, diagnoses a stalled timing worker and cancels its queued source' do
    stub_const('Lich::WebUI::Scheduler::SHUTDOWN_JOIN_TIMEOUT', 0.05)
    entered, release = Queue.new, Queue.new
    calls = []
    queued_work = nil
    allow(dispatcher).to receive(:enqueue) do |**_options, &work|
      queued_work = work
      entered << true
      release.pop
    end
    id = scheduler.schedule(owner, 0) { calls << :called; true }
    Timeout.timeout(1) { entered.pop }

    stopping = Thread.new { scheduler.shutdown }
    expect(stopping.join(0.5)).to equal(stopping)
    expect(stopping.value).to be_nil
    expect(messages).to eq([[:warning, 'WebUI scheduler thread did not stop within 0.05s']])
    expect(scheduler.cancel(owner, id)).to be(false)
    expect { scheduler.schedule(owner, 0) {} }.to raise_error(Lich::WebUI::Error, /stopped/)
    queued_work.call
    expect(calls).to be_empty
  ensure
    release << true if release
    stopping&.join(1)
    scheduler.shutdown
  end

  it 'joins an ordinary waiting worker without warning and leaves no callbacks live' do
    id = scheduler.schedule(owner, 60_000) { raise 'canceled callback ran' }
    expect(scheduler.shutdown).to be_nil
    expect(scheduler.cancel(owner, id)).to be(false)
    expect(messages).to be_empty
    expect(scheduler.shutdown).to be_nil
  ensure
    scheduler.shutdown
  end

  it 'isolates an ordinary logger failure when the join times out' do
    worker = double('stalled timing worker', join: nil)
    allow(Lich::WebUI::HostThread).to receive(:start).and_return(worker)
    allow(logger).to receive(:call).and_raise(IOError, 'closed diagnostic sink')
    scheduler.schedule(owner, 10) {}
    expect { scheduler.shutdown }.not_to raise_error
  end
end
