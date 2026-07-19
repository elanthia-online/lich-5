# frozen_string_literal: true

require 'timeout'

require_relative '../../spec_helper'
require_relative '../../../lib/common/shutdown_watchdog'

RSpec.describe Lich::Common::ShutdownWatchdog do
  before do
    described_class.instance_variable_set(:@armed, false)
    described_class.instance_variable_set(:@thread, nil)
    described_class.instance_variable_set(:@mutex, Mutex.new)
    described_class.instance_variable_set(:@condition, ConditionVariable.new)
  end

  after do
    described_class.disarm
    described_class.instance_variable_get(:@thread)&.join(1)
  end

  describe '.arm' do
    it 'invokes on_expire after the deadline elapses' do
      fired = Queue.new
      expect(described_class.arm(timeout: 0.02, on_expire: -> { fired << :expired })).to be(true)

      expect(Timeout.timeout(2) { fired.pop }).to eq(:expired)
    end

    it 'dumps thread diagnostics before forcing exit' do
      allow(Lich::Common::ShutdownLog).to receive(:error)
      fired = Queue.new
      described_class.arm(timeout: 0.02, on_expire: -> { fired << :expired })

      Timeout.timeout(2) { fired.pop }

      expect(Lich::Common::ShutdownLog).to have_received(:error).at_least(:once)
    end

    it 'does not fire once disarmed before the deadline' do
      fired = Queue.new
      described_class.arm(timeout: 5, on_expire: -> { fired << :expired })

      described_class.disarm
      described_class.instance_variable_get(:@thread)&.join(1)

      sleep 0.05
      expect(fired).to be_empty
    end

    it 'is a no-op when the timeout is zero (disabled)' do
      expect(described_class.arm(timeout: 0, on_expire: -> { raise 'should not run' })).to be(false)
      expect(described_class.armed?).to be(false)
    end

    it 'is a no-op when the timeout is negative' do
      expect(described_class.arm(timeout: -5, on_expire: -> { raise 'should not run' })).to be(false)
    end

    it 'refuses to arm twice concurrently' do
      described_class.arm(timeout: 5, on_expire: -> {})
      expect(described_class.arm(timeout: 5, on_expire: -> {})).to be(false)
    end

    it 'can be re-armed after being disarmed' do
      described_class.arm(timeout: 5, on_expire: -> {})
      described_class.disarm
      described_class.instance_variable_get(:@thread)&.join(1)

      expect(described_class.arm(timeout: 5, on_expire: -> {})).to be(true)
    end
  end

  describe '.disarm' do
    it 'is safe to call when not armed' do
      expect { described_class.disarm }.not_to raise_error
      expect(described_class.armed?).to be(false)
    end
  end

  describe '.configured_timeout' do
    it 'falls back to the default when no settings backend is available' do
      hide_const('Lich')
      expect(described_class.configured_timeout).to eq(described_class::DEFAULT_TIMEOUT_SECONDS)
    end
  end
end
