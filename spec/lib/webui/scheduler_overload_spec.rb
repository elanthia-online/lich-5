# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/scheduler'

RSpec.describe Lich::WebUI::Scheduler do
  let(:owner) { Object.new }
  let(:dispatcher) { double('dispatcher') }
  let(:messages) { [] }
  let(:scheduler) { described_class.new(dispatcher: dispatcher, admission: ->(_) {}, logger: ->(*entry) { messages << entry }) }
  let(:clock) { 100.0 }

  before do
    allow(Lich::WebUI::HostThread).to receive(:start).and_return(double('timing worker', join: nil))
    allow(scheduler).to receive(:now) { clock }
  end

  after { scheduler.shutdown }

  def source_for(id)
    scheduler.instance_variable_get(:@sources).fetch(id)
  end

  def submit_tick(id, source)
    source[:state] = :queued
    scheduler.send(:submit, id, source)
  end

  it 'retains a repeating source through overload, bounds retries and diagnostics, and executes after recovery' do
    runs = []
    id = scheduler.schedule(owner, 0) { runs << :tick; true }
    source = source_for(id)
    allow(dispatcher).to receive(:enqueue) do |**options, &_work|
      options.fetch(:cleanup).call
      raise Lich::WebUI::Dispatcher::OverflowError, 'full'
    end
    2.times do
      submit_tick(id, source)
      expect(source_for(id)).to equal(source)
      expect(source[:state]).to eq(:waiting)
      expect(source[:due]).to eq(clock + described_class::OVERLOAD_RETRY_INTERVAL)
    end
    expect(messages.length).to eq(1)
    expect(runs).to be_empty
    allow(dispatcher).to receive(:enqueue) do |**options, &work|
      work.call
      options.fetch(:cleanup).call
    end
    submit_tick(id, source)
    expect(runs).to eq([:tick])
    expect(source[:state]).to eq(:waiting)
    expect(source[:due]).to eq(clock + described_class::MIN_INTERVAL)
  end

  it 'does not resurrect a source canceled during overload admission' do
    id = scheduler.schedule(owner, 10) { true }
    source = source_for(id)
    allow(dispatcher).to receive(:enqueue) do |**options|
      scheduler.cancel(owner, id)
      options.fetch(:cleanup).call
      raise Lich::WebUI::Dispatcher::OverflowError, 'full'
    end
    submit_tick(id, source)
    expect(scheduler.cancel(owner, id)).to be(false)
    expect(messages).to be_empty
  end

  it 'retires terminal refusals and accepted work canceled before admission returns' do
    id = scheduler.schedule(owner, 10) { true }
    source = source_for(id)
    allow(dispatcher).to receive(:enqueue) do |**options|
      options.fetch(:cleanup).call
      raise Lich::WebUI::Error, 'terminated'
    end
    submit_tick(id, source)
    expect(scheduler.cancel(owner, id)).to be(false)
    id = scheduler.schedule(owner, 10) { true }
    source = source_for(id)
    allow(dispatcher).to receive(:enqueue) { |**options| options.fetch(:cleanup).call; :queued }
    submit_tick(id, source)
    expect(scheduler.cancel(owner, id)).to be(false)
  end

  it 'retires accepted work canceled after admission and ignores a stale queued callback' do
    calls = []
    id = scheduler.schedule(owner, 10) { calls << :called; true }
    source = source_for(id)
    cleanup = work = nil
    allow(dispatcher).to receive(:enqueue) { |**options, &block| cleanup = options.fetch(:cleanup); work = block; :queued }
    submit_tick(id, source)
    cleanup.call
    work.call
    expect(calls).to be_empty
    expect(scheduler.cancel(owner, id)).to be(false)
  end
end
