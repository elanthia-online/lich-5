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

  it 'rejects non-positive and non-integer bounds' do
    expect { buffer.max_size = 0 }.to raise_error(ArgumentError, /positive Integer/)
    expect { buffer.max_size = -1 }.to raise_error(ArgumentError, /positive Integer/)
    expect { buffer.max_size = '3' }.to raise_error(ArgumentError, /positive Integer/)
  end

  it 'trims existing entries when max_size decreases' do
    4.times { |value| buffer.push(value) }

    buffer.max_size = 2

    expect(buffer).to eq([2, 3])
  end

  it 'enforces the bound through append-style inherited APIs' do
    buffer.max_size = 3

    buffer << 0
    buffer.append(1)
    buffer.concat([2, 3])

    expect(buffer).to eq([1, 2, 3])
  end

  it 'enforces the bound through arbitrary replacement APIs' do
    buffer.max_size = 3
    buffer.replace([0, 1, 2])
    buffer.insert(3, 3)
    buffer[3, 0] = [4]

    expect(buffer).to eq([2, 3, 4])
  end

  it 'enforces the bound when flattening expands nested entries' do
    buffer.max_size = 3
    buffer.replace([[0, 1], 2, 3])

    buffer.flatten!

    expect(buffer).to eq([1, 2, 3])
  end

  it 'overrides every mutator defined directly by Array' do
    array_mutators = Array.instance_methods(false).select do |method_name|
      method_name.to_s.end_with?('!') || %i[<< []= append clear concat delete delete_at delete_if fill insert keep_if pop prepend push replace shift unshift].include?(method_name)
    end

    expect(array_mutators).to all(satisfy { |method_name| described_class.instance_method(method_name).owner == described_class })
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

  it 'gives a duplicate independent synchronization state' do
    buffer.max_size = 3
    buffer.push('one')

    duplicate = buffer.dup

    expect(duplicate).to eq(['one'])
    expect(duplicate.max_size).to eq(3)
    expect(duplicate.instance_variable_get(:@mutex)).not_to equal(buffer.instance_variable_get(:@mutex))
    expect(duplicate.instance_variable_get(:@condition)).not_to equal(buffer.instance_variable_get(:@condition))
  end

  it 'returns and clears one atomic snapshot' do
    buffer.push('one')
    buffer.push('two')

    snapshot = buffer.clear_snapshot

    expect(snapshot).to eq(%w[one two])
    expect(buffer).to be_empty
    expect(snapshot.instance_variable_get(:@mutex)).not_to equal(buffer.instance_variable_get(:@mutex))
    expect(snapshot.instance_variable_get(:@condition)).not_to equal(buffer.instance_variable_get(:@condition))
  end
end
