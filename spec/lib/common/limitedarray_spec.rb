# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/limitedarray'

RSpec.describe Lich::Common::LimitedArray do
  subject(:buffer) { described_class.new }

  it 'evicts the oldest item when push exceeds max_size' do
    buffer.max_size = 3
    4.times { |value| buffer.push(value) }

    expect(buffer).to eq([1, 2, 3])
  end

  it 'preserves a restored front item when unshift exceeds max_size' do
    buffer.max_size = 3
    buffer.push('one')
    buffer.push('two')
    buffer.push('three')

    buffer.unshift('restored')

    expect(buffer).to eq(%w[restored one two])
  end

  it 'wakes a blocked waiter when an item is pushed' do
    waiter = Thread.new { buffer.wait_shift }
    sleep 0.02

    buffer.push('line')

    expect(waiter.value).to eq('line')
  end

  it 'wakes a blocked waiter when an item is unshifted' do
    waiter = Thread.new { buffer.wait_shift }
    sleep 0.02

    buffer.unshift('restored')

    expect(waiter.value).to eq('restored')
  end

  it 'returns nil when wait_shift times out' do
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    expect(buffer.wait_shift(0.03)).to be_nil
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).to be >= 0.02
  end

  it 'shifts without blocking through try_shift' do
    expect(buffer.try_shift).to be_nil
    buffer.push('line')
    expect(buffer.try_shift).to eq('line')
  end

  it 'returns and clears one atomic snapshot' do
    buffer.push('one')
    buffer.push('two')

    expect(buffer.clear_snapshot).to eq(%w[one two])
    expect(buffer).to be_empty
  end
end
