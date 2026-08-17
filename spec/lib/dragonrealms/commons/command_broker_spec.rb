# frozen_string_literal: true

require_relative '../../../spec_helper'

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'command-broker.rb')

RSpec.describe Lich::DragonRealms::Broker do
  subject(:broker) { described_class.new }

  # Keep a helper thread alive until released, so it can stand in as a foreign
  # (live) lease holder without racing the test.
  def live_holder
    gate = Queue.new
    thread = Thread.new { gate.pop }
    Thread.pass until thread.status == 'sleep' || !thread.alive?
    [thread, gate]
  end

  def dead_thread
    t = Thread.new {}
    t.join
    t
  end

  def hold_lease_with(thread, name: 'peer', intent: nil, acquired_at: 0.0)
    broker.instance_variable_set(:@owner, thread)
    broker.instance_variable_set(:@depth, 1)
    broker.instance_variable_set(:@acquired_at, acquired_at)
    broker.instance_variable_set(:@holder_name, name)
    broker.instance_variable_set(:@intent, intent)
  end

  def messages
    Lich::Messaging.messages.map { |m| m[:message] }
  end

  describe '#exclusive (happy path)' do
    it 'yields, returns the block value, and frees the lease' do
      result = broker.exclusive(intent: 'study') { 42 }
      expect(result).to eq(42)
      expect(broker.held?).to be false
    end

    it 'returns a falsey block value faithfully (not confused with timeout)' do
      expect(broker.exclusive { false }).to be false
      expect(broker.exclusive { nil }).to be_nil
    end

    it 'reports ownership while inside the block' do
      broker.exclusive do
        expect(broker.held?).to be true
        expect(broker.mine?).to be true
        expect(broker.owner_name).not_to be_nil
      end
      expect(broker.held?).to be false
      expect(broker.mine?).to be false
      expect(broker.owner_name).to be_nil
    end

    it 'releases the lease even when the block raises' do
      expect { broker.exclusive { raise 'boom' } }.to raise_error('boom')
      expect(broker.held?).to be false
    end

    it 'logs grant and release mirroring the DRC pause messages' do
      broker.exclusive(intent: 'study') { :ok }
      expect(messages).to include(a_string_matching(/DRC: Broker lease granted to .*\(study\)/))
      expect(messages).to include(a_string_matching(/DRC: Broker lease released by .*\(study\)/))
    end
  end

  describe '#exclusive reentrancy' do
    it 'lets the same thread re-enter without deadlocking and frees once' do
      inner_ran = false
      broker.exclusive(intent: 'outer') do
        broker.exclusive(intent: 'inner') { inner_ran = true }
        # inner release must NOT free the lease the outer call still holds
        expect(broker.held?).to be true
        expect(broker.mine?).to be true
      end
      expect(inner_ran).to be true
      expect(broker.held?).to be false
    end
  end

  describe '#exclusive timeout' do
    it 'returns :broker_timeout without running the block when held by a live peer' do
      thread, gate = live_holder
      hold_lease_with(thread)
      allow(broker).to receive(:now).and_return(0.0, 100.0)

      ran = false
      result = broker.exclusive(timeout: 30) { ran = true }

      expect(result).to eq(:broker_timeout)
      expect(ran).to be false
    ensure
      gate << :go
      thread.join
    end
  end

  describe '#exclusive!' do
    it 'returns the block value on success' do
      expect(broker.exclusive!(timeout: 5) { 7 }).to eq(7)
      expect(broker.held?).to be false
    end

    it 'raises LeaseTimeout when the lease cannot be acquired in time' do
      thread, gate = live_holder
      hold_lease_with(thread)
      allow(broker).to receive(:now).and_return(0.0, 100.0)

      expect { broker.exclusive!(timeout: 30) { :never } }
        .to raise_error(described_class::LeaseTimeout, /could not acquire command lease/)
    ensure
      gate << :go
      thread.join
    end
  end

  describe 'dead-holder reconciliation' do
    it 'reclaims a lease whose holder thread has died, on the next acquire' do
      hold_lease_with(dead_thread, name: 'zombie')

      expect(broker.exclusive(timeout: 5) { :ran }).to eq(:ran)
      expect(broker.held?).to be false
      expect(messages).to include(a_string_matching(/reclaiming lease from dead holder zombie/))
    end
  end

  describe '#tick_watchdog' do
    it 'reclaims a dead holder proactively' do
      hold_lease_with(dead_thread, name: 'zombie')
      broker.tick_watchdog
      expect(broker.held?).to be false
    end

    it 'warns about an over-long LIVE holder but does not revoke it' do
      thread, gate = live_holder
      hold_lease_with(thread, name: 'slow', acquired_at: 0.0)
      allow(broker).to receive(:now).and_return(1000.0)

      broker.tick_watchdog(warn_after: 90)

      expect(broker.held?).to be true
      warning = messages.find { |m| m.include?('possible stuck holder') }
      expect(warning).to match(/lease held 1000s by slow/)
      # The holder thread's backtrace is appended so the wedge is diagnosable.
      expect(warning).to match(/\.rb:\d+/)
    ensure
      gate << :go
      thread.join
    end

    it 'does not warn before the threshold' do
      thread, gate = live_holder
      hold_lease_with(thread, name: 'slow', acquired_at: 0.0)
      allow(broker).to receive(:now).and_return(10.0)

      broker.tick_watchdog(warn_after: 90)

      expect(messages).not_to include(a_string_matching(/possible stuck holder/))
    ensure
      gate << :go
      thread.join
    end
  end

  describe 'waiter ordering (#next_token_locked)' do
    it 'grants highest priority first, FIFO within a band' do
      broker.instance_variable_set(:@waiters, [
                                     { thread: :a, priority: :normal, seq: 1 },
                                     { thread: :b, priority: :high,   seq: 2 },
                                     { thread: :c, priority: :normal, seq: 3 },
                                     { thread: :d, priority: :high,   seq: 4 },
                                   ])
      expect(broker.send(:next_token_locked)[:thread]).to eq(:b)
    end

    it 'falls back to FIFO when no high-priority waiters remain' do
      broker.instance_variable_set(:@waiters, [
                                     { thread: :c, priority: :normal, seq: 3 },
                                     { thread: :a, priority: :normal, seq: 1 },
                                   ])
      expect(broker.send(:next_token_locked)[:thread]).to eq(:a)
    end
  end

  describe 'priority normalization' do
    it 'coerces an unknown priority to :normal' do
      expect(broker.send(:normalize_priority, :bogus)).to eq(:normal)
      expect(broker.send(:normalize_priority, :high)).to eq(:high)
      expect(broker.send(:normalize_priority, :normal)).to eq(:normal)
    end
  end

  describe 'class-level facade' do
    after { described_class.reset_instance! }

    it 'delegates to a shared singleton instance' do
      expect(described_class.exclusive(timeout: 5) { :ok }).to eq(:ok)
      expect(described_class.held?).to be false
      expect(described_class.instance).to be(described_class.instance)
    end

    it 'hands every thread the same instance under concurrent first use' do
      described_class.reset_instance!
      ids = Queue.new
      threads = Array.new(24) { Thread.new { ids << described_class.instance.object_id } }
      threads.each(&:join)
      seen = []
      seen << ids.pop until ids.empty?
      expect(seen.uniq.length).to eq(1)
    end
  end

  describe 'watchdog lifecycle' do
    it 'starts idempotently and stops cleanly' do
      t1 = broker.start_watchdog!(interval: 60)
      t2 = broker.start_watchdog!(interval: 60)
      expect(t1).to be(t2)
      expect(t1.alive?).to be true

      broker.stop_watchdog!
      expect(t1.alive?).to be false
    end

    it 'is a no-op to stop when never started' do
      expect { broker.stop_watchdog! }.not_to raise_error
    end

    it 'reset_instance! stops the singleton watchdog thread' do
      described_class.instance.start_watchdog!(interval: 60)
      thread = described_class.instance.instance_variable_get(:@watchdog)
      expect(thread.alive?).to be true

      described_class.reset_instance!
      expect(thread.alive?).to be false
    end
  end

  # End-to-end with real threads: exercises the actual ConditionVariable park
  # and broadcast (the stubbed timeout/ordering tests above never wait). Bounded
  # spins/joins so a regression fails fast instead of hanging the suite.
  describe 'concurrency (real threads)' do
    def wait_for_waiters(target)
      200.times do
        return if broker.instance_variable_get(:@waiters).length >= target

        sleep 0.005
      end
      raise "waiters never reached #{target}"
    end

    def join_all(*threads)
      threads.each { |t| raise 'broker thread hung' unless t.join(2) }
    end

    it 'parks a waiter (pausing no one) and grants it on release' do
      order = Queue.new
      holding = Queue.new
      release_now = Queue.new

      holder = Thread.new do
        broker.exclusive(intent: 'holder') do
          holding << :held
          release_now.pop
          order << :holder_done
        end
      end
      holding.pop # holder now owns the lease

      waiter = Thread.new { broker.exclusive(intent: 'waiter') { order << :waiter_ran } }
      wait_for_waiters(1) # waiter is parked, not pausing the holder

      release_now << :go
      join_all(holder, waiter)

      expect([order.pop, order.pop]).to eq(%i[holder_done waiter_ran])
      expect(broker.held?).to be false
    end

    it 'grants a high-priority waiter ahead of an earlier normal waiter' do
      order = Queue.new
      holding = Queue.new
      release_now = Queue.new

      holder = Thread.new do
        broker.exclusive(intent: 'holder') do
          holding << :held
          release_now.pop
        end
      end
      holding.pop

      normal = Thread.new { broker.exclusive(priority: :normal) { order << :normal } }
      wait_for_waiters(1)
      high = Thread.new { broker.exclusive(priority: :high) { order << :high } }
      wait_for_waiters(2)

      release_now << :go
      join_all(holder, normal, high)

      expect([order.pop, order.pop]).to eq(%i[high normal])
    end
  end
end
