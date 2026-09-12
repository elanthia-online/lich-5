require_relative '../../spec_helper'
require_relative '../../../lib/common/script_execution_guard'

RSpec.describe Lich::Common::ScriptExecutionGuard do
  def interruption(guard, **options)
    guard.checkpoint!(**options)
    raise 'expected interruption'
  rescue described_class::Interrupted => error
    error
  end

  it 'accepts only a Proc at construction' do
    expect { described_class.new(nil) }.to raise_error(ArgumentError)
  end

  it 'passes nil checkpoints and immutable command copies to the callback' do
    seen = []
    command = +'cast #123'
    guard = described_class.new(->(value) { seen << value; true })
    expect(guard.checkpoint!).to be(true)
    expect(guard.checkpoint!(command: command)).to be(true)
    expect(seen).to eq([nil, command])
    expect(seen.last).to be_frozen
    expect(seen.last).not_to equal(command)
    expect(command).not_to be_frozen
  end

  it 'requires literal true and does not silently retry a rejected write' do
    calls = 0
    guard = described_class.new(->(_) { calls += 1; :truthy })
    expect(interruption(guard, command: 'cast #123').reason).to eq(:command_rejected)
    expect(interruption(guard).reason).to eq(:command_rejected)
    expect(calls).to eq(1)
  end

  it 'latches a rejected cooperative checkpoint' do
    guard = described_class.new(->(_) { false })
    expect(interruption(guard).reason).to eq(:checkpoint_rejected)
    expect(guard).to be_cancelled
  end

  it 'turns callback exceptions into cancellation without exposing their content or cause' do
    guard = described_class.new(->(_) { raise 'private command secret' })
    error = interruption(guard, command: 'private command secret')
    expect(error.reason).to eq(:callback_error)
    expect(error.message).not_to include('private', 'secret')
    expect(error.cause).to be_nil
    expect(interruption(guard).reason).to eq(:callback_error)
  end

  it 'also latches exceptions outside StandardError' do
    guard = described_class.new(->(_) { raise SyntaxError, 'private error' })
    expect(interruption(guard).reason).to eq(:callback_error)
  end

  it 'permits reentrant read-only checkpoints without calling the callback recursively' do
    calls = 0
    guard = described_class.new(->(_) { calls += 1; guard.checkpoint! })
    expect(guard.checkpoint!(command: 'cast #123')).to be(true)
    expect(calls).to eq(1)
  end

  it 'rejects and latches a callback send even if the callback rescues interruption' do
    guard = described_class.new(lambda do |_|
      begin
        guard.checkpoint!(command: 'nested send')
      rescue described_class::Interrupted
        true
      end
    end)
    expect(interruption(guard).reason).to eq(:reentrant_command)
    expect(interruption(guard).reason).to eq(:reentrant_command)
  end

  it 'does not hold its mutex while calling policy code and rechecks cancellation afterward' do
    guard = described_class.new(lambda do |_|
      canceller = Thread.new { guard.cancel!(:room_changed) }
      expect(canceller.join(1)).to equal(canceller)
      true
    end)
    expect(interruption(guard, command: 'cast #123').reason).to eq(:room_changed)
  end

  it 'shares sticky cancellation with another thread already inside its callback' do
    entered = Queue.new
    release = Queue.new
    guard = described_class.new(->(_) { entered << true; release.pop; true })
    worker = Thread.new { interruption(guard, command: 'cast #123') }
    entered.pop
    guard.cancel!(:manual_hold)
    guard.cancel!(:later_reason)
    release << true
    expect(worker.value.reason).to eq(:manual_hold)
    expect(interruption(guard).reason).to eq(:manual_hold)
  ensure
    worker&.kill
    worker&.join
  end

  it 'does not mistake a different thread checkpoint for read-only callback recursion' do
    entered = Queue.new
    release = Queue.new
    calls = Queue.new
    guard = described_class.new(lambda do |command|
      calls << command
      if command
        entered << true
        release.pop
      end
      true
    end)
    worker = Thread.new { guard.checkpoint!(command: 'cast #123') }
    entered.pop
    expect(guard.checkpoint!).to be(true)
    release << true
    expect(worker.value).to be(true)
    expect([calls.pop, calls.pop]).to eq(['cast #123', nil])
  ensure
    worker&.kill
    worker&.join
  end

  it 'rejects invalid command values without invoking the policy' do
    guard = described_class.new(->(_) { raise 'must not call' })
    expect(interruption(guard, command: [:send]).reason).to eq(:invalid_command)
  end

  it 'closes permanently and sanitizes explicit cancellation labels' do
    guard = described_class.new(->(_) { true })
    guard.close!
    expect(interruption(guard).reason).to eq(:closed)
    other = described_class.new(->(_) { true })
    other.cancel!('cast #123 private command')
    expect(interruption(other).reason).to eq(:cancelled)
  end
end
