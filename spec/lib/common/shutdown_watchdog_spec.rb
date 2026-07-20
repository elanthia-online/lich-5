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

    it 'does not let a disarmed thread fire after a subsequent re-arm' do
      # Regression: an arm/disarm/arm sequence must not let the first (canceled)
      # thread observe the second arming's @armed flag and force an exit.
      first = Queue.new
      described_class.arm(timeout: 0.05, on_expire: -> { first << :first })
      described_class.disarm
      first_thread = described_class.instance_variable_get(:@thread)

      described_class.arm(timeout: 5, on_expire: -> {})
      first_thread&.join(1)
      sleep 0.15 # well past the first arming's 0.05s deadline

      expect(first).to be_empty
    end

    it 'uses an un-trappable Process.exit! as the default on_expire' do
      # Regression for the shipped defect: the default lambda was a bare
      # exit!(1), which resolved against the module and raised NoMethodError --
      # neutering the force-exit guarantee. The default must call a real method.
      exited = Queue.new
      allow(Process).to receive(:exit!) { |code| exited << code }

      described_class.arm(timeout: 0.02) # no on_expire -> exercise the real default

      expect(Timeout.timeout(2) { exited.pop }).to eq(1)
    end

    it 'ignores a spurious condition-variable wakeup and fires only after the real deadline' do
      # Regression: ConditionVariable#wait can return before its timeout on a
      # spurious wakeup. The watchdog must re-wait against a monotonic deadline
      # rather than treat any wakeup while armed as expiry.
      fired = Queue.new
      described_class.arm(timeout: 0.2, on_expire: -> { fired << :expired })

      sleep 0.05 # let the watchdog thread park in the timed wait
      mutex = described_class.instance_variable_get(:@mutex)
      condition = described_class.instance_variable_get(:@condition)
      mutex.synchronize { condition.signal } # spurious wakeup, still armed

      sleep 0.02
      expect(fired).to be_empty # the 0.2s deadline has not elapsed yet
      expect(described_class.armed?).to be(true)

      expect(Timeout.timeout(2) { fired.pop }).to eq(:expired) # still fires eventually
    end

    it 'still forces exit when diagnostics logging raises' do
      allow(Lich::Common::ShutdownLog).to receive(:error).and_raise(StandardError, 'log sink down')
      fired = Queue.new
      described_class.arm(timeout: 0.02, on_expire: -> { fired << :expired })

      expect(Timeout.timeout(2) { fired.pop }).to eq(:expired)
    end

    it 'treats a non-numeric timeout as disabled rather than arming' do
      expect(described_class.arm(timeout: 'not-a-number', on_expire: -> { raise 'should not run' })).to be(false)
      expect(described_class.armed?).to be(false)
    end

    it 'derives the deadline from configured_timeout when none is supplied' do
      allow(described_class).to receive(:configured_timeout).and_return(0)
      expect(described_class.arm(on_expire: -> { raise 'should not run' })).to be(false)
    end

    it 'admits only one winner when many threads race to arm' do
      results = Queue.new
      threads = Array.new(20) { Thread.new { results << described_class.arm(timeout: 5, on_expire: -> {}) } }
      threads.each(&:join)

      outcomes = Array.new(results.size) { results.pop }
      expect(outcomes.count(true)).to eq(1)
      expect(outcomes.count(false)).to eq(19)
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

    it 'falls back to the default (never silently disables) on a malformed value' do
      allow(Lich).to receive(:db).and_return(double(get_first_value: 'abc'))
      allow(Lich).to receive(:log)

      expect(described_class.configured_timeout).to eq(described_class::DEFAULT_TIMEOUT_SECONDS)
    end

    it 'honors an explicit positive override' do
      allow(Lich).to receive(:db).and_return(double(get_first_value: '90'))

      expect(described_class.configured_timeout).to eq(90)
    end

    it 'treats an explicit non-positive value as an intentional disable' do
      allow(Lich).to receive(:db).and_return(double(get_first_value: '0'))

      expect(described_class.configured_timeout).to eq(0)
    end

    it 'falls back to the default when the setting row is absent (nil)' do
      allow(Lich).to receive(:db).and_return(double(get_first_value: nil))

      expect(described_class.configured_timeout).to eq(described_class::DEFAULT_TIMEOUT_SECONDS)
    end

    it 'falls back to the default when the settings query raises' do
      db = double
      allow(db).to receive(:get_first_value).and_raise(StandardError, 'db locked')
      allow(Lich).to receive(:db).and_return(db)

      expect(described_class.configured_timeout).to eq(described_class::DEFAULT_TIMEOUT_SECONDS)
    end

    it 'parses a value with surrounding whitespace' do
      allow(Lich).to receive(:db).and_return(double(get_first_value: '  90  '))

      expect(described_class.configured_timeout).to eq(90)
    end

    it 'preserves an explicit negative value as an intentional disable' do
      allow(Lich).to receive(:db).and_return(double(get_first_value: '-5'))

      expect(described_class.configured_timeout).to eq(-5)
    end

    it 'rejects a non-integer numeric string and never silently disables' do
      allow(Lich).to receive(:db).and_return(double(get_first_value: '90.5'))
      allow(Lich).to receive(:log)

      expect(described_class.configured_timeout).to eq(described_class::DEFAULT_TIMEOUT_SECONDS)
    end
  end
end
