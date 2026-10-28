# frozen_string_literal: true

require_relative '../../spec_helper'
require 'open3'
require 'rbconfig'
require 'webui/dispatcher'

RSpec.describe Lich::WebUI::Dispatcher do
  let(:dispatcher) { described_class.new }
  let(:owner) { Object.new }

  after { dispatcher.shutdown }

  it 'refuses a new owner after full dispatcher shutdown' do
    dispatcher.shutdown
    expect do
      dispatcher.enqueue(owner: Object.new, page_id: nil, viewer_id: nil, cid: nil,
                         event: :callback, coalescable: false) {}
    end.to raise_error(Lich::WebUI::Error, /stopped/)
  end

  it 'refuses late callbacks after an owner has been terminated' do
    delivered = Queue.new
    dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'button',
                       event: :activate, coalescable: false) { delivered << true }
    delivered.pop
    dispatcher.shutdown_owner(owner)

    expect do
      dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'late',
                         event: :activate, coalescable: false) { delivered << :late }
    end.to raise_error(Lich::WebUI::Error, /terminated/)
  end

  it 'disposes rejected work after owner termination without invoking it' do
    dispatcher.shutdown_owner(owner)
    disposed = []
    called = []
    expect do
      dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'button', event: :activate,
                         coalescable: false, cleanup: -> { disposed << true }) { called << true }
    end.to raise_error(Lich::WebUI::Error, /terminated/)
    expect(disposed).to eq([true])
    expect(called).to be_empty
  end

  it 'keeps consecutive edits from different viewers separate' do
    started = Queue.new
    release = Queue.new
    delivered = Queue.new
    dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'first', cid: 'blocker',
                       event: :activate, coalescable: false) { started << true; release.pop }
    started.pop
    dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'first', cid: 'entry',
                       event: :change, coalescable: true) { delivered << :first }
    result = dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'second', cid: 'entry',
                                event: :change, coalescable: true) { delivered << :second }
    expect(result).to eq(:queued)
    release << true
    expect([delivered.pop, delivered.pop]).to eq([:first, :second])
  ensure
    release << true
  end

  it 'does not terminate a distinct owner that compares equal' do
    first = +'same'
    second = +'same'
    dispatcher.shutdown_owner(first)
    expect(dispatcher.enqueue(owner: second, page_id: 'page', viewer_id: 'viewer', cid: 'button',
                              event: :activate, coalescable: false) {}).to eq(:queued)
  end

  it 'retains termination for a symbol owner' do
    dispatcher.shutdown_owner(:core)
    expect do
      dispatcher.enqueue(owner: :core, page_id: 'page', viewer_id: 'viewer', cid: 'button',
                         event: :activate, coalescable: false) {}
    end.to raise_error(Lich::WebUI::Error, /terminated/)
  end

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
    disposed = []
    dispatcher.enqueue(
      owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'blocker',
      event: :activate, coalescable: false
    ) do
      started << true
      release.pop
    end
    started.pop
    expect(dispatcher.enqueue(
      owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'input', event: :change, coalescable: true,
      cleanup: -> { disposed << :replaced }
    ) { delivered << 1 }).to eq(:queued)
    expect(dispatcher.enqueue(
      owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'input', event: :change, coalescable: true
    ) { delivered << 2 }).to eq(:coalesced)
    expect(disposed).to eq([:replaced])
    3.times do |index|
      dispatcher.enqueue(
        owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'button',
        event: :activate, coalescable: false
      ) { delivered << index + 3 }
    end
    release << true

    expect(4.times.map { delivered.pop }).to eq([2, 3, 4, 5])
  end

  it 'disposes evicted edits while retaining already accepted terminal callbacks' do
    stub_const('Lich::WebUI::Dispatcher::VIEWER_LIMIT', 2)
    started = Queue.new
    release = Queue.new
    delivered = Queue.new
    disposed = []
    dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'blocker', event: :activate,
                       coalescable: false) { started << true; release.pop }
    started.pop
    dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'edit', event: :change,
                       coalescable: true, cleanup: -> { disposed << :evicted }) { delivered << :edit }
    2.times do |index|
      dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'viewer', cid: "terminal-#{index}", event: :activate,
                         coalescable: false) { delivered << index }
    end
    expect(disposed).to eq([:evicted])
    release << true
    expect([delivered.pop, delivered.pop]).to eq([0, 1])
  ensure
    release << true
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

  it 'contains script-class failures and stops only the owner on exit, in a fresh process' do
    code = <<~RUBY_CODE
      require 'webui/dispatcher'
      logs = Queue.new
      dispatcher = Lich::WebUI::Dispatcher.new(logger: ->(level, message) { logs << [level, message] })
      owner = Object.new
      enqueue = lambda do |cleanup: nil, &work|
        dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'button',
                           event: :activate, coalescable: false, cleanup: cleanup, &work)
      end
      done = Queue.new
      enqueue.call { raise LoadError, 'missing' }
      enqueue.call { done << :after_load_error }
      abort 'LoadError abandoned the queue' unless done.pop == :after_load_error

      gate = Queue.new
      started = Queue.new
      ran = []
      disposed = Queue.new
      enqueue.call { started << true; gate.pop; exit 3 }
      started.pop
      enqueue.call(cleanup: -> { disposed << :queued }) { ran << :replayed }
      gate << true
      abort 'queued work was not disposed' unless disposed.pop == :queued
      abort 'queued work ran after exit' unless ran.empty?
      begin
        enqueue.call {}
        abort 'owner still admitting after exit'
      rescue Lich::WebUI::Error => error
        abort "wrong refusal: \#{error.message}" unless error.message.include?('terminated')
      end
      messages = []
      messages << logs.pop until logs.empty?
      abort 'no exit diagnostic' unless messages.any? { |level, text| level == :warning && text.include?('status=3') }
      puts 'ready'
    RUBY_CODE
    output, errors, status = Open3.capture3(RbConfig.ruby, '-I', LIB_DIR, '-e', code)
    expect(status.success?).to be(true), errors
    expect(output).to eq("ready\n")
  end

  it 'retires a killed worker, disposing queued callbacks without running them' do
    started = Queue.new
    disposed = []
    ran = []
    dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'blocker',
                       event: :activate, coalescable: false) { started << Thread.current; sleep }
    worker = started.pop
    dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'queued', event: :activate,
                       coalescable: false, cleanup: -> { disposed << :queued }) { ran << :queued }
    worker.kill
    worker.join

    expect(disposed).to eq([:queued])
    expect(ran).to be_empty
    expect do
      dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'late',
                         event: :activate, coalescable: false) {}
    end.to raise_error(Lich::WebUI::Error, /terminated/)
  end

  it 'starts workers outside the enqueuing script thread group' do
    script_group = ThreadGroup.new
    seen = Queue.new
    Thread.new do
      script_group.add(Thread.current)
      dispatcher.enqueue(owner: owner, page_id: 'page', viewer_id: 'viewer', cid: 'button',
                         event: :activate, coalescable: false) { seen << Thread.current.group }
    end.join

    expect(seen.pop).to equal(ThreadGroup::Default)
  end

  it 'finishes every owner shutdown when one worker ended with a script-class exception' do
    dead = Thread.new do
      Thread.current.report_on_exception = false
      raise LoadError, 'worker died'
    end
    sleep 0.01 while dead.status
    workers = [->(&_block) { dead }, ->(&block) { Thread.new(&block) }]
    isolated = described_class.new(thread_factory: ->(&block) { workers.shift.call(&block) })
    other = Object.new
    [owner, other].each do |candidate|
      isolated.enqueue(owner: candidate, page_id: 'page', viewer_id: 'viewer', cid: 'button',
                       event: :activate, coalescable: false) {}
    end

    expect { isolated.shutdown }.not_to raise_error
    expect do
      isolated.enqueue(owner: other, page_id: 'page', viewer_id: 'viewer', cid: 'late',
                       event: :activate, coalescable: false) {}
    end.to raise_error(Lich::WebUI::Error, /stopped/)
    expect(isolated.shutdown_owner(other)).to be(false)
  end
end
