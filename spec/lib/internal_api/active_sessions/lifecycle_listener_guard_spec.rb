# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative '../../../../lib/internal_api/active_sessions'

# Resets the process-local lifecycle singleton state between examples so each
# example can describe one lifecycle scenario without inheriting thread or
# listener state from previous runs.
#
# @param lifecycle [Module]
# @return [void]
def reset_lifecycle!(lifecycle)
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
end

# Adversarial spec suite targeting the listener state guard bug.
#
# Root cause: update_listener and clear_listener guarded local instance
# variable writes behind ActiveSessions.enabled?, so a transient feature flag
# failure (DB not ready, SQLite contention, etc.) permanently lost the
# listener port. Every subsequent heartbeat sent listener_port: nil.
RSpec.describe Lich::InternalAPI::ActiveSessions::Lifecycle, 'listener state guards' do
  let(:lifecycle) { described_class }

  before do
    reset_lifecycle!(lifecycle)

    # Simulate a started lifecycle (heartbeat running, session registered)
    lifecycle.instance_variable_set(:@started, true)
    lifecycle.instance_variable_set(:@running, true)
    lifecycle.instance_variable_set(:@session_name, 'Gnarta')
    lifecycle.instance_variable_set(:@role, 'headless')
    lifecycle.instance_variable_set(:@started_at, 1_775_850_546)
    lifecycle.instance_variable_set(:@lifecycle_generation, 1)
  end

  # -- update_listener --------------------------------------------------------

  describe '.update_listener' do
    context 'when enabled? is true' do
      before do
        allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_return(true)
        allow(Lich::InternalAPI::ActiveSessions).to receive(:register_session).and_return(true)
      end

      it 'sets local state and upserts' do
        lifecycle.update_listener(host: '127.0.0.1', port: 44021, connected: false)

        payload = lifecycle.current_payload
        expect(payload[:listener_host]).to eq('127.0.0.1')
        expect(payload[:listener_port]).to eq(44021)
        expect(payload[:connected]).to eq(false)
        expect(Lich::InternalAPI::ActiveSessions).to have_received(:register_session).once
      end
    end

    context 'when enabled? is false (the bug scenario)' do
      before do
        allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_return(false)
        allow(Lich::InternalAPI::ActiveSessions).to receive(:register_session)
      end

      it 'still sets local state so heartbeats carry the port' do
        lifecycle.update_listener(host: '127.0.0.1', port: 44021, connected: false)

        payload = lifecycle.current_payload
        expect(payload[:listener_port]).to eq(44021)
        expect(payload[:listener_host]).to eq('127.0.0.1')
        expect(payload[:connected]).to eq(false)
      end

      it 'does not attempt a remote upsert' do
        lifecycle.update_listener(host: '127.0.0.1', port: 44021, connected: false)

        expect(Lich::InternalAPI::ActiveSessions).not_to have_received(:register_session)
      end
    end

    context 'when enabled? transitions from false to true across heartbeats' do
      it 'heartbeat picks up the port that update_listener saved while disabled' do
        call_count = 0
        allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?) do
          call_count += 1
          # First call (from update_listener): false
          # Subsequent calls (from heartbeat upserts): true
          call_count > 1
        end
        allow(Lich::InternalAPI::ActiveSessions).to receive(:register_session).and_return(true)

        # update_listener called while enabled? is false
        lifecycle.update_listener(host: '127.0.0.1', port: 44021, connected: false)

        # Simulate heartbeat: build_current_payload reads local state, upserts
        # (This exercises upsert_current_session directly via the public payload
        # to confirm the local state is correct for future upserts.)
        payload = lifecycle.current_payload
        expect(payload[:listener_port]).to eq(44021),
          'heartbeat payload must include port saved during disabled window'
      end
    end

    context 'when enabled? raises (transient DB error)' do
      before do
        allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_raise(StandardError, 'SQLite3::BusyException')
        allow(Lich::InternalAPI::ActiveSessions).to receive(:register_session)
      end

      it 'still saves local state (exception only affects upsert)' do
        # The enabled? call is in the upsert guard, not the state-setting path.
        # An exception there should not prevent local state from being updated.
        # If this raises, the caller (detachable_client_thread) rescues it, but
        # the local state must already be set before the exception can occur.
        lifecycle.update_listener(host: '127.0.0.1', port: 44021, connected: false) rescue nil

        payload = lifecycle.current_payload
        expect(payload[:listener_port]).to eq(44021),
          'local state must be set before enabled? is evaluated'
      end
    end

    context 'when update_listener is called multiple times (reconnect cycle)' do
      before do
        allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_return(true)
        allow(Lich::InternalAPI::ActiveSessions).to receive(:register_session).and_return(true)
      end

      it 'tracks the latest port through create/accept/disconnect/recreate' do
        # Server created on port 44021
        lifecycle.update_listener(host: '127.0.0.1', port: 44021, connected: false)
        expect(lifecycle.current_payload[:listener_port]).to eq(44021)

        # Client connects
        lifecycle.update_listener(host: '127.0.0.1', port: 44021, connected: true)
        expect(lifecycle.current_payload[:connected]).to eq(true)

        # Client disconnects, server torn down
        lifecycle.clear_listener

        # Server recreated on new port (OS assigned)
        lifecycle.update_listener(host: '127.0.0.1', port: 39887, connected: false)
        payload = lifecycle.current_payload
        expect(payload[:listener_port]).to eq(39887)
        expect(payload[:connected]).to eq(false)
      end
    end
  end

  # -- clear_listener ---------------------------------------------------------

  describe '.clear_listener' do
    before do
      # Pre-set listener state
      lifecycle.instance_variable_set(:@listener_host, '127.0.0.1')
      lifecycle.instance_variable_set(:@listener_port, 44021)
      lifecycle.instance_variable_set(:@listener_connected, true)
    end

    context 'when enabled? is true' do
      before do
        allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_return(true)
        allow(Lich::InternalAPI::ActiveSessions).to receive(:register_session).and_return(true)
      end

      it 'clears local state and upserts' do
        lifecycle.clear_listener

        payload = lifecycle.current_payload
        expect(payload[:listener_host]).to be_nil
        expect(payload[:listener_port]).to be_nil
        expect(Lich::InternalAPI::ActiveSessions).to have_received(:register_session).once
      end
    end

    context 'when enabled? is false' do
      before do
        allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_return(false)
        allow(Lich::InternalAPI::ActiveSessions).to receive(:register_session)
      end

      it 'still clears local state so heartbeats reflect teardown' do
        lifecycle.clear_listener

        payload = lifecycle.current_payload
        expect(payload[:listener_port]).to be_nil
        expect(payload[:listener_host]).to be_nil
      end

      it 'does not attempt a remote upsert' do
        lifecycle.clear_listener

        expect(Lich::InternalAPI::ActiveSessions).not_to have_received(:register_session)
      end
    end

    context 'when lifecycle is not started' do
      before do
        lifecycle.instance_variable_set(:@started, false)
        allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_return(true)
        allow(Lich::InternalAPI::ActiveSessions).to receive(:register_session)
      end

      it 'clears local state but skips upsert' do
        lifecycle.clear_listener

        payload = lifecycle.current_payload
        expect(payload[:listener_port]).to be_nil
        expect(Lich::InternalAPI::ActiveSessions).not_to have_received(:register_session)
      end
    end
  end

  # -- Race condition: heartbeat vs update_listener ---------------------------

  describe 'heartbeat interleaving with update_listener' do
    before do
      allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_return(true)
    end

    it 'heartbeat payload always reflects the latest local state' do
      # Simulate: update_listener sets port, then heartbeat reads payload
      payloads = []
      allow(Lich::InternalAPI::ActiveSessions).to receive(:register_session) do |payload|
        payloads << payload.dup
        true
      end

      lifecycle.update_listener(host: '127.0.0.1', port: 44021, connected: false)

      # Heartbeat fires -- payload must include port 44021
      heartbeat_payload = lifecycle.current_payload
      expect(heartbeat_payload[:listener_port]).to eq(44021)
      expect(payloads.last[:listener_port]).to eq(44021)
    end

    it 'after clear_listener, heartbeat payload has nil port' do
      allow(Lich::InternalAPI::ActiveSessions).to receive(:register_session).and_return(true)

      lifecycle.update_listener(host: '127.0.0.1', port: 44021, connected: false)
      lifecycle.clear_listener

      heartbeat_payload = lifecycle.current_payload
      expect(heartbeat_payload[:listener_port]).to be_nil
    end
  end

  # -- connected field derivation ---------------------------------------------

  describe 'connected field in payload' do
    before do
      allow(Lich::InternalAPI::ActiveSessions).to receive(:enabled?).and_return(true)
      allow(Lich::InternalAPI::ActiveSessions).to receive(:register_session).and_return(true)
    end

    it 'defaults to true when no listener port is set (headless)' do
      payload = lifecycle.current_payload
      expect(payload[:listener_port]).to be_nil
      expect(payload[:connected]).to eq(true),
        'headless sessions with no listener report connected: true'
    end

    it 'reflects listener_connected when a port is set' do
      lifecycle.update_listener(host: '127.0.0.1', port: 44021, connected: false)
      expect(lifecycle.current_payload[:connected]).to eq(false)

      lifecycle.update_listener(host: '127.0.0.1', port: 44021, connected: true)
      expect(lifecycle.current_payload[:connected]).to eq(true)
    end

    it 'reverts to true after clear_listener removes the port' do
      lifecycle.update_listener(host: '127.0.0.1', port: 44021, connected: false)
      expect(lifecycle.current_payload[:connected]).to eq(false)

      lifecycle.clear_listener
      expect(lifecycle.current_payload[:connected]).to eq(true),
        'after clear_listener, connected should derive from nil port (true)'
    end
  end
end
