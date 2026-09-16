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
end
