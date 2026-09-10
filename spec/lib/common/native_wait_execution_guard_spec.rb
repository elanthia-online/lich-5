# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/limitedarray'
require_relative '../../../lib/common/feature_flags'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'

# Load exact production definitions into an isolated receiver. Requiring all of
# global_defs would replace shared helpers used by unrelated randomized specs.
# Only Script's constant reference changes to its fully qualified native class.
module NativeWaitExecutionGuardSpec
  class Harness; end
  path = File.expand_path('../../../lib/global_defs.rb', __dir__)
  lines = File.readlines(path)
  %w[fput dothistimeout get? clear pause waitrt? waitcastrt? wait_until wait_while].each do |name|
    first = lines.index { |line| line.match?(/^def #{Regexp.escape(name)}(?:\(|\s*$)/) }
    raise "native #{name} missing" unless first

    offset = lines[(first + 1)..].index { |line| line.match?(/^end\s*$/) }
    raise "native #{name} terminator missing" unless offset

    code = lines[first..(first + offset + 1)].join.gsub(/\bScript\./, 'Lich::Common::Script.')
    Harness.class_eval(code, path, first + 1)
  end
end

RSpec.describe 'Native command and roundtime execution guard checkpoints' do
  let(:script_class) { Lich::Common::Script }
  let(:owner) { script_class.allocate }
  let(:buffer) { Lich::Common::LimitedArray.new }
  let(:harness) { NativeWaitExecutionGuardSpec::Harness.new }
  let(:writes) { [] }
  let(:response) { '...wait 30 seconds.' }
  let(:interrupted) { Lich::Common::ScriptExecutionGuard::Interrupted }

  before(:context) do
    require_relative '../../../lib/common/script'
  end

  after(:context) do
    %i[SubScript ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |name|
      Lich::Common.send(:remove_const, name) if Lich::Common.const_defined?(name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
  end

  before do
    owner.want_downstream = true
    owner.instance_variable_set(:@downstream_buffer, buffer)
    allow(script_class).to receive(:__resolve_current).and_return(owner)
    allow(harness).to receive(:put) do |command|
      owner.check_execution_guard!(command: command)
      writes << command
      buffer << response
    end
    allow(harness).to receive(:echo)
    allow(harness).to receive(:respond)
  end

  # Main thread cancels only after the native helper enters its real long sleep.
  # No polling guesses or 30-second waits: failed checkpoints leave a worker
  # which this helper joins briefly, then tears down before reporting failure.
  def cancel_during_native_sleep
    guards, entered = Queue.new, Queue.new
    result = {}
    allow(owner).to receive(:execution_sleep).and_wrap_original do |method, duration|
      entered << duration
      method.call(duration)
    end
    worker = Thread.new do
      owner.with_execution_guard(->(_command) { true }) do |guard|
        guards << guard
        result[:value] = yield
      end
    rescue StandardError => error
      result[:error] = error
    end
    guard = guards.pop(timeout: 0.5)
    expect(guard).not_to be_nil
    expect(entered.pop(timeout: 0.5)).to be > 20
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    guard.cancel!(:cancelled)
    expect(worker.join(0.5)).to eq(worker)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.5
    expect(result[:error]).to be_a(interrupted)
    expect(owner.execution_guard_active?).to be(false)
  ensure
    worker&.kill if worker&.alive?
    worker&.join(0.1)
  end

  it 'unwinds fput during a wait-30 response without resending the command' do
    cancel_during_native_sleep { harness.fput('attack #123') }
    expect(writes).to eq(['attack #123'])
  end

  it 'unwinds dothistimeout during a wait-30 response without retrying the action' do
    cancel_during_native_sleep { harness.dothistimeout('prepare 101', 60, /ready/) }
    expect(writes).to eq(['prepare 101'])
  end

  it 'unwinds native waitrt? during a long roundtime' do
    allow(harness).to receive(:checkrt).and_return(30.0)
    cancel_during_native_sleep { harness.waitrt? }
    expect(writes).to be_empty
  end

  it 'unwinds native waitcastrt? during a long cast roundtime' do
    allow(harness).to receive(:checkcastrt).and_return(30.0)
    cancel_during_native_sleep { harness.waitcastrt? }
    expect(writes).to be_empty
  end

  it 'checks real Script.gets? even when a continuous stream never sleeps' do
    # Isolate the gets? checkpoint from Script.current's additional pause gate.
    allow(owner).to receive(:wait_while_paused!)
    reads = 0
    expect do
      owner.with_execution_guard(->(_command) { true }) do |guard|
        allow(buffer).to receive(:try_shift) do
          reads += 1
          raise 'missing hot-stream checkpoint' if reads > 20

          guard.cancel!(:cancelled) if reads == 3
          'unrelated room chatter'
        end
        expect do
          harness.dothistimeout('look', 60, /never matches/)
        end.to raise_error(interrupted)
        # Guard remains latched until scope exit even if callers catch it.
      end
    end.to raise_error(interrupted)
    expect(reads).to eq(3)
    expect(writes).to eq(['look'])
    expect(owner.execution_guard_active?).to be(false)
  end

  context 'without an installed guard' do
    let(:response) { 'Your spell is ready.' }

    it 'keeps native fput return and downstream pushback behavior' do
      expect(harness.fput('prepare 101')).to eq(response)
      expect(writes).to eq(['prepare 101'])
      expect(buffer.to_a).to eq([response])
    end

    it 'keeps native dothistimeout success matching behavior' do
      expect(harness.dothistimeout('prepare 101', 5, /ready/)).to eq(response)
      expect(writes).to eq(['prepare 101'])
      expect(buffer).to be_empty
    end

    it 'keeps native zero-roundtime return values' do
      allow(harness).to receive(:checkrt).and_return(0)
      allow(harness).to receive(:checkcastrt).and_return(0)
      expect(harness.waitrt?).to be(false)
      expect(harness.waitcastrt?).to be(false)
    end
  end

  %i[wait_until wait_while].each do |method|
    it "restores thread priority when #{method} unwinds on cancellation" do
      original_priority = Thread.current.priority
      Thread.current.priority = 1
      expect do
        owner.with_execution_guard(->(_command) { true }) do |guard|
          harness.public_send(method) do
            guard.cancel!(:cancelled)
            owner.check_execution_guard!
          end
        end
      end.to raise_error(interrupted)
      expect(Thread.current.priority).to eq(1)
    ensure
      Thread.current.priority = original_priority
    end
  end
end
