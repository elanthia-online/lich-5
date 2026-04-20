# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative '../../../../lib/internal_api/active_sessions'

# Resets the process-local lifecycle singleton state between examples so each
# example can describe one lifecycle scenario without inheriting thread or
# listener state from previous runs.
#
# @param lifecycle [Module]
# @return [void]
def reset_active_sessions_lifecycle!(lifecycle)
  lifecycle.instance_variable_set(:@heartbeat_thread, nil)
  lifecycle.instance_variable_set(:@running, false)
  lifecycle.instance_variable_set(:@started, false)
  lifecycle.instance_variable_set(:@listener_host, nil)
  lifecycle.instance_variable_set(:@listener_port, nil)
  lifecycle.instance_variable_set(:@listener_connected, false)
  lifecycle.instance_variable_set(:@session_name, nil)
  lifecycle.instance_variable_set(:@role, nil)
  lifecycle.instance_variable_set(:@started_at, nil)
  lifecycle.instance_variable_set(:@mutex, Mutex.new)
  lifecycle.instance_variable_set(:@registration_mutex, Mutex.new)
  lifecycle.instance_variable_set(:@lifecycle_generation, 0)
  lifecycle.instance_variable_set(:@feature_enabled, false)
end

RSpec.describe Lich::InternalAPI::ActiveSessions::Lifecycle do
  before do
    reset_active_sessions_lifecycle!(described_class)

    allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_return(true)
    allow(Lich::InternalAPI::ActiveSessions).to receive(:register_session_admitted).and_return(true)
    allow(Lich::InternalAPI::ActiveSessions).to receive(:unregister_session_admitted).and_return(true)
  end

  describe '.start and .stop' do
    it 'does nothing when the feature flag is disabled' do
      allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_return(false)

      expect(described_class.start(session_name: 'Tsetem', role: 'session')).to be(false)
      expect(described_class.stop).to be(false)
      expect(Lich::InternalAPI::ActiveSessions).not_to have_received(:register_session_admitted)
    end

    it 'registers once, heartbeats from the captured thread block, and unregisters on stop' do
      # Capture the heartbeat block directly so the spec can exercise the loop
      # deterministically without waiting on a real background thread.
      heartbeat_thread = instance_double(Thread)
      captured_block = nil

      allow(Thread).to receive(:new) do |&block|
        captured_block = block
        heartbeat_thread
      end
      allow(heartbeat_thread).to receive(:join).with(0.5)
      allow(heartbeat_thread).to receive(:alive?).and_return(false)
      allow(heartbeat_thread).to receive(:kill)

      sleep_calls = 0
      allow(described_class).to receive(:sleep) do |_seconds|
        sleep_calls += 1
        described_class.instance_variable_set(:@running, false) if sleep_calls >= 2
      end

      expect(described_class.start(session_name: 'Tsetem', role: 'session', heartbeat_interval: 1)).to be(true)
      expect(captured_block).not_to be_nil

      captured_block.call

      expect(Lich::InternalAPI::ActiveSessions).to have_received(:register_session_admitted).at_least(:once)
      expect(described_class.stop).to be(true)
      expect(Lich::InternalAPI::ActiveSessions).to have_received(:unregister_session_admitted).with(pid: Process.pid)
    end

    it 'still stops cleanly when enabled? would raise after startup' do
      heartbeat_thread = instance_double(Thread)
      captured_block = nil

      allow(Thread).to receive(:new) do |&block|
        captured_block = block
        heartbeat_thread
      end
      allow(heartbeat_thread).to receive(:join).with(0.5)
      allow(heartbeat_thread).to receive(:alive?).and_return(false)
      allow(heartbeat_thread).to receive(:kill)

      expect(described_class.start(session_name: 'Tsetem', role: 'session', heartbeat_interval: 1)).to be(true)
      expect(captured_block).not_to be_nil

      allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_raise('should not be called')

      expect(described_class.stop).to be(true)
      expect(Lich::InternalAPI::ActiveSessions).to have_received(:unregister_session_admitted).with(pid: Process.pid)
    end
  end

  describe '.update_listener and .clear_listener' do
    it 'includes detachable listener metadata in current payload updates' do
      described_class.instance_variable_set(:@started, true)
      described_class.instance_variable_set(:@session_name, 'Tsetem')
      described_class.instance_variable_set(:@role, 'detachable')
      described_class.instance_variable_set(:@started_at, 1_700_000_000)

      described_class.update_listener(host: '127.0.0.1', port: 7000, connected: true)

      expect(Lich::InternalAPI::ActiveSessions).to have_received(:register_session_admitted).with(
        hash_including(
          session_name: 'Tsetem',
          listener_host: '127.0.0.1',
          listener_port: 7000,
          connected: true
        )
      )

      described_class.clear_listener

      expect(Lich::InternalAPI::ActiveSessions).to have_received(:register_session_admitted).with(
        hash_including(
          listener_host: nil,
          listener_port: nil,
          connected: true
        )
      )
    end

    it 'does not re-check the feature flag for listener state updates after start' do
      described_class.instance_variable_set(:@started, true)
      described_class.instance_variable_set(:@feature_enabled, true)
      described_class.instance_variable_set(:@session_name, 'Tsetem')
      described_class.instance_variable_set(:@role, 'detachable')
      described_class.instance_variable_set(:@started_at, 1_700_000_000)

      allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_raise('should not be called')

      expect do
        described_class.update_listener(host: '127.0.0.1', port: 7000, connected: true)
        described_class.clear_listener
      end.not_to raise_error
    end
  end

  describe 'feature gate usage' do
    it 'checks the feature flag once at lifecycle start and not again for heartbeat upserts' do
      heartbeat_thread = instance_double(Thread)
      captured_block = nil

      allow(Thread).to receive(:new) do |&block|
        captured_block = block
        heartbeat_thread
      end
      allow(heartbeat_thread).to receive(:join).with(0.5)
      allow(heartbeat_thread).to receive(:alive?).and_return(false)
      allow(heartbeat_thread).to receive(:kill)

      enabled_calls = 0
      allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?) do
        enabled_calls += 1
        true
      end

      sleep_calls = 0
      allow(described_class).to receive(:sleep) do |_seconds|
        sleep_calls += 1
        described_class.instance_variable_set(:@running, false) if sleep_calls >= 2
      end

      expect(described_class.start(session_name: 'Tsetem', role: 'session', heartbeat_interval: 1)).to be(true)
      captured_block.call

      expect(enabled_calls).to eq(1)
    end

    it 'continues heartbeat upserts even if enabled? would raise after lifecycle start' do
      heartbeat_thread = instance_double(Thread)
      captured_block = nil

      allow(Thread).to receive(:new) do |&block|
        captured_block = block
        heartbeat_thread
      end
      allow(heartbeat_thread).to receive(:join).with(0.5)
      allow(heartbeat_thread).to receive(:alive?).and_return(false)
      allow(heartbeat_thread).to receive(:kill)

      expect(described_class.start(session_name: 'Tsetem', role: 'session', heartbeat_interval: 1)).to be(true)
      expect(captured_block).not_to be_nil

      allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_raise('should not be called')

      sleep_calls = 0
      allow(described_class).to receive(:sleep) do |_seconds|
        sleep_calls += 1
        described_class.instance_variable_set(:@running, false) if sleep_calls >= 2
      end

      expect { captured_block.call }.not_to raise_error
      expect(Lich::InternalAPI::ActiveSessions).to have_received(:register_session_admitted).with(
        hash_including(session_name: 'Tsetem')
      ).at_least(:once)
    end

    it 'does not mutate listener state before lifecycle start' do
      described_class.update_listener(host: '127.0.0.1', port: 7000, connected: true)

      expect(described_class.current_payload).to include(
        listener_host: nil,
        listener_port: nil,
        connected: true
      )
    end

    it 'uses live service state for cleanup after startup admission when the flag later turns off' do
      heartbeat_thread = instance_double(Thread)

      allow(Thread).to receive(:new).and_return(heartbeat_thread)
      allow(heartbeat_thread).to receive(:join).with(0.5)
      allow(heartbeat_thread).to receive(:alive?).and_return(false)
      allow(heartbeat_thread).to receive(:kill)
      allow(Lich::InternalAPI::ActiveSessions).to receive(:cleanup_discovery_if_last_session!)

      expect(described_class.start(session_name: 'Tsetem', role: 'session', heartbeat_interval: 1)).to be(true)

      allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_return(false)

      expect(described_class.stop).to be(true)
      expect(Lich::InternalAPI::ActiveSessions).to have_received(:cleanup_discovery_if_last_session!)
    end
  end
end
