# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/limitedarray'

RSpec.describe 'Lich::Common::Script execution guard scope' do
  let(:script_class) { Lich::Common::Script }
  let(:interrupted) { Lich::Common::ScriptExecutionGuard::Interrupted }
  let(:buffer) { Lich::Common::LimitedArray.new }
  let(:script) do
    script_class.allocate.tap do |instance|
      instance.instance_variable_set(:@downstream_buffer, buffer)
      instance.instance_variable_set(:@want_downstream, true)
      instance.instance_variable_set(:@want_downstream_xml, false)
      instance.instance_variable_set(:@want_script_output, false)
      instance.instance_variable_set(:@paused, false)
      instance.instance_variable_set(:@ignore_pause, false)
    end
  end

  before(:context) do
    require_relative '../../../lib/common/script'
  end

  after(:context) do
    %i[SubScript ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
      Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
  end

  after do
    Array(@workers).each { |worker| worker.kill; worker.join }
  end

  def bound_to_script
    key = script_class::CLEANUP_SCRIPT_THREAD_KEY
    previous = Thread.current.thread_variable_get(key)
    Thread.current.thread_variable_set(key, script)
    yield
  ensure
    Thread.current.thread_variable_set(key, previous)
  end

  def worker(&block)
    @workers ||= []
    Thread.new do
      bound_to_script(&block)
    rescue Lich::Common::ScriptExecutionGuard::Interrupted => error
      error
    end.tap { |thread| @workers << thread }
  end

  it 'advertises the script-instance execution guard protocol' do
    expect(script_class::EXECUTION_GUARD_PROTOCOL).to eq(1)
  end

  def joined_value(thread)
    expect(thread.join(1)).to equal(thread)
    thread.value
  end

  it 'activates for its block, preserves the return value and closes on normal exit' do
    handle = nil
    calls = []
    result = script.with_execution_guard(->(command) { calls << command; true }) do |guard|
      handle = guard
      expect(script.execution_guard_active?).to be(true)
      expect(script.check_execution_guard!(command: 'cast #123')).to be(true)
      :finished
    end
    expect(result).to eq(:finished)
    expect(calls).to eq([nil, 'cast #123', nil])
    expect(script.execution_guard_active?).to be(false)
    expect(handle).to be_cancelled
  end

  it 'rejects nesting without removing or replacing the outer guard' do
    commands = []
    script.with_execution_guard(->(command) { commands << command; true }) do
      expect { script.with_execution_guard(->(_) { false }) { :inner } }.to raise_error(ArgumentError, /already/)
      expect(script.execution_guard_active?).to be(true)
      script.check_execution_guard!(command: 'outer still active')
    end
    expect(commands).to include('outer still active')
  end

  it 'cleans up after a block error and permits a later independent scope' do
    expect { script.with_execution_guard(->(_) { true }) { raise 'body failed' } }.to raise_error(RuntimeError, 'body failed')
    expect(script.execution_guard_active?).to be(false)
    expect(script.with_execution_guard(->(_) { true }) { :new_scope }).to eq(:new_scope)
  end

  it 'rejects missing blocks and failed initial policy without leaving a guard installed' do
    expect { script.with_execution_guard(->(_) { true }) }.to raise_error(ArgumentError, /block/)
    ran = false
    expect { script.with_execution_guard(->(_) { false }) { ran = true } }.to raise_error(interrupted)
    expect(ran).to be(false)
    expect(script.execution_guard_active?).to be(false)
  end

  it 'keeps ordinary unguarded buffer access and checkpoints unchanged' do
    expect(script.check_execution_guard!(command: 'ordinary command')).to be(true)
    expect(script.gets?).to be_nil
    buffer.push('first')
    buffer.push('second')
    expect(script.gets).to eq('first')
    expect(script.gets?).to eq('second')
    expect(script.gets(0.001)).to be_nil
    expect(script.execution_sleep(0)).to eq(0)
  end

  it 'interrupts a guarded idle gets without needing incoming game output' do
    started = Queue.new
    expect do
      script.with_execution_guard(->(_) { true }) do |guard|
        reader = worker { started << true; script.gets }
        expect(started.pop(timeout: 1)).to be(true)
        guard.cancel!(:room_changed)
        expect(joined_value(reader).reason).to eq(:room_changed)
      end
    end.to raise_error(interrupted) { |error| expect(error.reason).to eq(:room_changed) }
    expect(buffer).to be_empty
    expect(script.execution_guard_active?).to be(false)
  end

  it 'interrupts gets and gets? while their disabled-stream fallback is waiting' do
    script.instance_variable_set(:@want_downstream, false)
    allow(script).to receive(:echo)
    entered = Queue.new
    allow(script).to receive(:execution_sleep).and_wrap_original do |original, duration|
      entered << duration
      original.call(duration)
    end

    %i[gets gets?].each do |read|
      expect do
        script.with_execution_guard(->(_) { true }) do |guard|
          reader = worker { script.public_send(read) }
          expect(entered.pop(timeout: 1)).to eq(2)
          guard.cancel!(:manual_stop)
          expect(joined_value(reader).reason).to eq(:manual_stop)
        end
      end.to raise_error(interrupted) { |error| expect(error.reason).to eq(:manual_stop) }
    end
  end

  it 'checks cancellation even when gets and gets? have a continuously available line' do
    %i[gets gets?].each do |read|
      buffer.push('available')
      expect do
        script.with_execution_guard(->(_) { true }) do |guard|
          guard.cancel!(:manual_hold)
          script.public_send(read)
        end
      end.to raise_error(interrupted) { |error| expect(error.reason).to eq(:manual_hold) }
      expect(buffer.try_shift).to eq('available')
    end
  end

  it 'preserves guarded data reads and bounded empty-buffer timeouts' do
    script.with_execution_guard(->(_) { true }) do
      buffer.push('accepted')
      expect(script.gets).to eq('accepted')
      expect(script.gets?).to be_nil
      expect(script.gets(0.001)).to be_nil
    end
  end

  it 'rechecks cancellation after the real buffer returns a line' do
    buffer.push('must not be returned')
    expect do
      script.with_execution_guard(->(_) { true }) do |guard|
        allow(buffer).to receive(:wait_shift).and_wrap_original do |original, *args|
          line = original.call(*args)
          guard.cancel!(:room_changed)
          line
        end
        script.gets
        raise 'cancelled read returned a line'
      end
    end.to raise_error(interrupted) { |error| expect(error.reason).to eq(:room_changed) }
  end

  it 'rechecks cancellation after a non-blocking buffer read' do
    buffer.push('must not be returned')
    expect do
      script.with_execution_guard(->(_) { true }) do |guard|
        allow(buffer).to receive(:try_shift).and_wrap_original do |original, *args|
          line = original.call(*args)
          guard.cancel!(:room_changed)
          line
        end
        script.gets?
        raise 'cancelled non-blocking read returned a line'
      end
    end.to raise_error(interrupted) { |error| expect(error.reason).to eq(:room_changed) }
  end

  it 'matches unguarded gets for zero, expired and coercible timeouts with buffered input' do
    [0, -1, '0', '-1', '0.001'].each do |timeout|
      buffer.push('ordinary')
      expect(script.gets(timeout)).to eq('ordinary')
      script.with_execution_guard(->(_) { true }) do
        buffer.push('guarded')
        expect(script.gets(timeout)).to eq('guarded')
        expect(script.gets(timeout)).to be_nil
      end
    end
  end

  it 'keeps false and nil timeouts unbounded and reads buffered input under a guard' do
    script.with_execution_guard(->(_) { true }) do
      [false, nil].each do |timeout|
        buffer.push('available')
        expect(script.gets(timeout)).to eq('available')
      end
    end
  end

  it 'enforces cancellation before consuming buffered input even with a zero timeout' do
    buffer.push('preserved')
    expect do
      script.with_execution_guard(->(_) { true }) do |guard|
        guard.cancel!(:manual_hold)
        script.gets(0)
      end
    end.to raise_error(interrupted)
    expect(buffer.try_shift).to eq('preserved')
  end

  it 'interrupts pause while policy reads the current script without recursion or deadlock' do
    entered = Queue.new
    observed = Queue.new
    expect do
      bound_to_script do
        policy = lambda do |_|
          observed << script_class.current
          entered << true if script.paused?
          true
        end
        script.with_execution_guard(policy) do |guard|
          script.instance_variable_set(:@paused, true)
          waiter = worker { script.wait_while_paused! }
          expect(entered.pop(timeout: 1)).to be(true)
          guard.cancel!(:paused_cancel)
          expect(joined_value(waiter).reason).to eq(:paused_cancel)
        end
      end
    end.to raise_error(interrupted)
    expect(observed.pop).to equal(script)
    expect(script.execution_guard_active?).to be(false)
  end

  it 'interrupts native execution_sleep and shares cancellation across workers' do
    started = Queue.new
    expect do
      script.with_execution_guard(->(_) { true }) do |guard|
        sleepers = 2.times.map { worker { started << true; script.execution_sleep(30) } }
        2.times { expect(started.pop(timeout: 1)).to be(true) }
        guard.cancel!(:deadline)
        expect(sleepers.map { |thread| joined_value(thread).reason }).to eq([:deadline, :deadline])
      end
    end.to raise_error(interrupted) { |error| expect(error.reason).to eq(:deadline) }
  end

  it 'rechecks a rescued worker cancellation when leaving the scope' do
    expect do
      script.with_execution_guard(->(_) { true }) do |guard|
        guard.cancel!(:manual_stop)
        expect(joined_value(worker { script.check_execution_guard! }).reason).to eq(:manual_stop)
        :helper_rescued_it
      end
    end.to raise_error(interrupted) { |error| expect(error.reason).to eq(:manual_stop) }
    expect(script.execution_guard_active?).to be(false)
  end
end
