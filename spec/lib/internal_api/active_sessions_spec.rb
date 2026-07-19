# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

require_relative '../../spec_helper'
require_relative '../../../lib/internal_api/active_sessions'

RSpec.describe Lich::InternalAPI::ActiveSessions do
  let(:temp_dir) { Dir.mktmpdir('active-sessions-spec') }

  before do
    stub_const('TEMP_DIR', temp_dir)
    described_class.instance_variable_set(:@registry, nil)
    described_class.instance_variable_set(:@server, nil)
    described_class.instance_variable_set(:@mutex, Mutex.new)
    allow(described_class).to receive(:enabled?).and_return(true)
    # The election path re-probes a discovered owner with a short backoff
    # before taking over. Neutralize the real delay so the suite stays fast
    # while still exercising the retry logic.
    allow(described_class).to receive(:sleep)
  end

  after do
    described_class.stop_service!
    FileUtils.rm_rf(temp_dir)
  end

  it 'starts a tokenized owner and writes discovery metadata' do
    fake_server = instance_double(
      Lich::InternalAPI::ActiveSessions::Server,
      start: true,
      stop: nil
    )
    fake_client = instance_double(Lich::InternalAPI::ActiveSessions::Client)
    allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(fake_server)
    allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(fake_client)
    allow(fake_client).to receive(:ping).and_return(false, true)
    allow(fake_server).to receive(:auth_token).and_return('generated-token')

    expect(described_class.ensure_service!).to be(true)

    discovery = JSON.parse(File.read(File.join(temp_dir, 'lich-active-sessions.json')), symbolize_names: true)
    expect(discovery[:owner_pid]).to eq(Process.pid)
    expect(discovery[:auth_token]).to eq('generated-token')
    expect(File.stat(File.join(temp_dir, 'lich-active-sessions.json')).mode & 0o777).to eq(0o600)
  end

  it 'reuses an existing healthy owner instead of creating a new server' do
    fake_client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: true)
    File.write(
      File.join(temp_dir, 'lich-active-sessions.json'),
      JSON.dump(owner_pid: 123, auth_token: 'shared-token', updated_at: Time.now.to_i)
    )

    allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(fake_client)
    expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)

    expect(described_class.ensure_service!).to be(true)
  end

  it 'returns sanitized service metadata without exposing the auth token' do
    fake_client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: true)
    File.write(
      File.join(temp_dir, 'lich-active-sessions.json'),
      JSON.dump(owner_pid: 321, auth_token: 'shared-token', updated_at: 1_700_000_000)
    )

    allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(fake_client)

    expect(described_class.service_info).to eq(
      source: 'ActiveSessionsAPI',
      owner_pid: 321,
      updated_at: 1_700_000_000,
      service_available: true
    )
  end

  it 'removes the discovery file when the owner is also the last remaining session' do
    File.write(
      File.join(temp_dir, 'lich-active-sessions.json'),
      JSON.dump(owner_pid: Process.pid, auth_token: 'shared-token', updated_at: Time.now.to_i)
    )

    allow(described_class).to receive(:query_snapshot).and_return(
      source: 'ActiveSessionsAPI',
      total: 0,
      connected: 0,
      detachable: 0,
      sessions: []
    )
    allow(described_class).to receive(:stop_service!).and_call_original

    described_class.cleanup_discovery_if_last_session!

    expect(File.exist?(File.join(temp_dir, 'lich-active-sessions.json'))).to be(false)
  end

  it 'keeps the discovery file when the snapshot is a fallback error' do
    discovery_file = File.join(temp_dir, 'lich-active-sessions.json')
    File.write(
      discovery_file,
      JSON.dump(owner_pid: Process.pid, auth_token: 'shared-token', updated_at: Time.now.to_i)
    )

    allow(described_class).to receive(:query_snapshot).and_return(
      source: 'ActiveSessionsAPI',
      total: 0,
      connected: 0,
      detachable: 0,
      sessions: [],
      error: 'service unavailable'
    )

    described_class.cleanup_discovery_if_last_session!

    expect(File.exist?(discovery_file)).to be(true)
  end

  describe '.ensure_service!' do
    # Stubs the service_client path to report no healthy external service,
    # forcing ensure_service! into the "start a new server" branch.
    #
    # @return [void]
    def stub_no_external_service
      dead_client = instance_double(Lich::InternalAPI::ActiveSessions::Client)
      allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(dead_client)
      allow(dead_client).to receive(:ping).and_return(false)
    end

    context 'when the existing server has a dead accept thread' do
      it 'stops the zombie, starts a replacement, and writes a fresh discovery file' do
        zombie_server = instance_double(
          Lich::InternalAPI::ActiveSessions::Server,
          running?: false,
          stop: nil,
          auth_token: 'zombie-token'
        )
        described_class.instance_variable_set(:@server, zombie_server)
        stub_no_external_service

        fresh_server = instance_double(
          Lich::InternalAPI::ActiveSessions::Server,
          start: true,
          stop: nil,
          auth_token: 'fresh-token'
        )
        allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(fresh_server)

        expect(zombie_server).to receive(:stop).ordered
        expect(described_class.ensure_service!).to be(true)

        discovery = JSON.parse(
          File.read(File.join(temp_dir, 'lich-active-sessions.json')),
          symbolize_names: true
        )
        expect(discovery[:auth_token]).to eq('fresh-token')
        expect(discovery[:owner_pid]).to eq(Process.pid)

        # Clean up injected double before after block calls stop_service!
        described_class.instance_variable_set(:@server, nil)
      end
    end

    context 'when the existing server has a healthy accept thread' do
      it 'reuses the healthy service without creating a new server' do
        healthy_client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: true)
        allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(healthy_client)
        File.write(
          File.join(temp_dir, 'lich-active-sessions.json'),
          JSON.dump(owner_pid: Process.pid, auth_token: 'healthy-token', updated_at: Time.now.to_i)
        )

        expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)
        expect(described_class.ensure_service!).to be(true)
      end
    end

    context 'when no prior server exists' do
      it 'creates a new server without zombie cleanup' do
        stub_no_external_service

        fresh_server = instance_double(
          Lich::InternalAPI::ActiveSessions::Server,
          start: true,
          stop: nil,
          auth_token: 'cold-start-token'
        )
        allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(fresh_server)

        expect(described_class.ensure_service!).to be(true)

        discovery = JSON.parse(
          File.read(File.join(temp_dir, 'lich-active-sessions.json')),
          symbolize_names: true
        )
        expect(discovery[:auth_token]).to eq('cold-start-token')
      end
    end

    context 'when the zombie is cleaned up but the replacement fails to start' do
      it 'returns false without writing a discovery file' do
        zombie_server = instance_double(
          Lich::InternalAPI::ActiveSessions::Server,
          running?: false,
          stop: nil,
          auth_token: 'zombie-token'
        )
        described_class.instance_variable_set(:@server, zombie_server)
        stub_no_external_service

        doomed_server = instance_double(
          Lich::InternalAPI::ActiveSessions::Server,
          start: false,
          stop: nil,
          auth_token: 'doomed-token'
        )
        allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(doomed_server)

        expect(described_class.ensure_service!).to be(false)
        expect(File.exist?(File.join(temp_dir, 'lich-active-sessions.json'))).to be(false)

        described_class.instance_variable_set(:@server, nil)
      end
    end

    context 'when zombie server.stop raises during cleanup' do
      it 'catches the error at the outer rescue and returns false' do
        zombie_server = instance_double(
          Lich::InternalAPI::ActiveSessions::Server,
          running?: false,
          auth_token: 'zombie-token'
        )
        allow(zombie_server).to receive(:stop).and_raise(Errno::EBADF, 'bad fd during stop')
        described_class.instance_variable_set(:@server, zombie_server)
        stub_no_external_service

        expect(described_class.ensure_service!).to be(false)

        described_class.instance_variable_set(:@server, nil)
      end
    end

    context 'when discovery points to a dead owner process' do
      it 'binds a replacement and overwrites the stale pointer' do
        # The former owner exited, so the port is free and the bind succeeds,
        # replacing the stale pointer with this process.
        stub_no_external_service
        File.write(
          File.join(temp_dir, 'lich-active-sessions.json'),
          JSON.dump(owner_pid: 99_999_999, auth_token: 'dead-owner-token', updated_at: Time.now.to_i)
        )

        fresh_server = instance_double(
          Lich::InternalAPI::ActiveSessions::Server,
          start: true,
          stop: nil,
          auth_token: 'replacement-token'
        )
        allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(fresh_server)

        expect(described_class.ensure_service!).to be(true)

        discovery = JSON.parse(
          File.read(File.join(temp_dir, 'lich-active-sessions.json')),
          symbolize_names: true
        )
        expect(discovery[:owner_pid]).to eq(Process.pid)
        expect(discovery[:auth_token]).to eq('replacement-token')
      end
    end

    context 'when discovery points to an owner that still holds the port' do
      it 'backs off without deleting the healthy owner\'s discovery pointer' do
        # A single probe fails transiently, but the owner is real and still
        # holds the port, so the replacement bind fails with EADDRINUSE.
        # Regression guard: earlier builds deleted the pointer here, knocking a
        # healthy owner offline for every peer under churn.
        stub_no_external_service
        discovery_file = File.join(temp_dir, 'lich-active-sessions.json')
        File.write(
          discovery_file,
          JSON.dump(owner_pid: 99_999_998, auth_token: 'live-owner-token', updated_at: Time.now.to_i)
        )

        contended_server = instance_double(
          Lich::InternalAPI::ActiveSessions::Server,
          start: false,
          stop: nil,
          auth_token: 'would-be-token'
        )
        allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(contended_server)

        expect(described_class.ensure_service!).to be(false)

        discovery = JSON.parse(File.read(discovery_file), symbolize_names: true)
        expect(discovery[:owner_pid]).to eq(99_999_998)
        expect(discovery[:auth_token]).to eq('live-owner-token')
      end
    end

    context 'when discovery names an owner whose pid was recycled and the port is free' do
      it 'takes over via a successful bind and overwrites the stale pointer' do
        # The recorded pid appears alive (recycled by an unrelated process),
        # but nobody holds the service port, so the bind succeeds. The bind --
        # not the bare liveness of a recycled pid -- decides ownership.
        stub_no_external_service
        discovery_file = File.join(temp_dir, 'lich-active-sessions.json')
        File.write(
          discovery_file,
          JSON.dump(owner_pid: 99_999_998, auth_token: 'recycled-pid-token', updated_at: Time.now.to_i)
        )

        fresh_server = instance_double(
          Lich::InternalAPI::ActiveSessions::Server,
          start: true,
          stop: nil,
          auth_token: 'takeover-token'
        )
        allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(fresh_server)

        expect(described_class.ensure_service!).to be(true)

        discovery = JSON.parse(File.read(discovery_file), symbolize_names: true)
        expect(discovery[:owner_pid]).to eq(Process.pid)
        expect(discovery[:auth_token]).to eq('takeover-token')
      end
    end

    context 'when a discovered owner answers on a retry after a transient miss' do
      it 'reuses the owner and never elects a replacement' do
        # First probe misses (churn-induced timeout), second probe succeeds.
        flaky_client = instance_double(Lich::InternalAPI::ActiveSessions::Client)
        allow(flaky_client).to receive(:ping).and_return(false, true)
        allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(flaky_client)
        File.write(
          File.join(temp_dir, 'lich-active-sessions.json'),
          JSON.dump(owner_pid: 4242, auth_token: 'flaky-owner-token', updated_at: Time.now.to_i)
        )

        expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)
        expect(described_class.ensure_service!).to be(true)
      end
    end

    context 'when server start fails' do
      it 'clears the @server reference so subsequent ticks do not report a zombie' do
        stub_no_external_service

        doomed_server = instance_double(
          Lich::InternalAPI::ActiveSessions::Server,
          start: false,
          stop: nil,
          auth_token: 'doomed-token'
        )
        allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(doomed_server)

        expect(described_class.ensure_service!).to be(false)
        expect(described_class.instance_variable_get(:@server)).to be_nil
      end
    end

    context 'owner self-recovery: accept thread dies and heartbeat restarts it' do
      it 'detects the dead accept thread and starts a replacement server on the next tick' do
        stub_no_external_service

        # First call: owner bootstraps successfully
        original_server = instance_double(
          Lich::InternalAPI::ActiveSessions::Server,
          start: true,
          stop: nil,
          auth_token: 'original-token'
        )
        allow(original_server).to receive(:running?).and_return(true)
        allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(original_server)

        expect(described_class.ensure_service!).to be(true)

        # Accept thread dies between ticks
        allow(original_server).to receive(:running?).and_return(false)

        # Heartbeat tick: should detect zombie, stop it, and bootstrap replacement
        replacement_server = instance_double(
          Lich::InternalAPI::ActiveSessions::Server,
          start: true,
          stop: nil,
          auth_token: 'recovered-token'
        )
        allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(replacement_server)

        expect(original_server).to receive(:stop)
        expect(described_class.ensure_service!).to be(true)

        discovery = JSON.parse(
          File.read(File.join(temp_dir, 'lich-active-sessions.json')),
          symbolize_names: true
        )
        expect(discovery[:auth_token]).to eq('recovered-token')

        described_class.instance_variable_set(:@server, nil)
      end
    end

    context 'peer behavior while owner is recovering' do
      it 'leaves the recovering owner\'s discovery pointer intact when the bind is contended' do
        # While an owner recovers its own accept thread it still holds the port,
        # so a peer's takeover bind fails. The peer must back off without
        # deleting the pointer, letting the owner re-assert itself.
        stub_no_external_service
        discovery_file = File.join(temp_dir, 'lich-active-sessions.json')
        File.write(
          discovery_file,
          JSON.dump(owner_pid: 99_999_997, auth_token: 'recovering-owner-token', updated_at: Time.now.to_i)
        )

        contended_server = instance_double(
          Lich::InternalAPI::ActiveSessions::Server,
          start: false,
          stop: nil,
          auth_token: 'would-be-token'
        )
        allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(contended_server)

        expect(described_class.ensure_service!).to be(false)

        discovery = JSON.parse(File.read(discovery_file), symbolize_names: true)
        expect(discovery[:owner_pid]).to eq(99_999_997)
        expect(discovery[:auth_token]).to eq('recovering-owner-token')
      end

      it 'fails gracefully on subsequent ticks after discovery is cleared' do
        stub_no_external_service

        doomed_server = instance_double(
          Lich::InternalAPI::ActiveSessions::Server,
          start: false,
          stop: nil,
          auth_token: 'doomed-token'
        )
        allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(doomed_server)

        results = 3.times.map { described_class.ensure_service! }

        expect(results).to all(be(false))
        expect(described_class.instance_variable_get(:@server)).to be_nil
      end
    end
  end

  describe 'owner discovery self-heal' do
    # Installs a running-owner server double for this process so the owner
    # fast path in ensure_service_internal! is exercised.
    #
    # @param auth_token [String] token the owned server advertises
    # @return [RSpec::Mocks::InstanceVerifyingDouble] the installed server double
    def install_running_owner(auth_token:)
      server = instance_double(
        Lich::InternalAPI::ActiveSessions::Server,
        running?: true,
        auth_token: auth_token,
        stop: nil
      )
      described_class.instance_variable_set(:@server, server)
      server
    end

    it 'recreates a discovery pointer that a peer deleted, within one tick' do
      install_running_owner(auth_token: 'owner-token')
      # Regression guard for the churn incident: a peer cleared the pointer,
      # so nothing is on disk when this owner's heartbeat runs.
      expect(described_class.ensure_service!).to be(true)

      discovery = JSON.parse(
        File.read(File.join(temp_dir, 'lich-active-sessions.json')),
        symbolize_names: true
      )
      expect(discovery[:owner_pid]).to eq(Process.pid)
      expect(discovery[:auth_token]).to eq('owner-token')
    end

    it 'overwrites a discovery pointer that a peer redirected to another owner' do
      install_running_owner(auth_token: 'owner-token')
      File.write(
        File.join(temp_dir, 'lich-active-sessions.json'),
        JSON.dump(owner_pid: 777, auth_token: 'usurper-token', updated_at: Time.now.to_i)
      )

      expect(described_class.ensure_service!).to be(true)

      discovery = JSON.parse(
        File.read(File.join(temp_dir, 'lich-active-sessions.json')),
        symbolize_names: true
      )
      expect(discovery[:owner_pid]).to eq(Process.pid)
      expect(discovery[:auth_token]).to eq('owner-token')
    end

    it 'does not rewrite discovery when the pointer already matches this owner' do
      install_running_owner(auth_token: 'owner-token')
      File.write(
        File.join(temp_dir, 'lich-active-sessions.json'),
        JSON.dump(owner_pid: Process.pid, auth_token: 'owner-token', updated_at: 1_700_000_000)
      )

      expect(described_class).not_to receive(:write_discovery)
      expect(described_class.ensure_service!).to be(true)
    end

    it 'reuses the owned server without probing an external service' do
      install_running_owner(auth_token: 'owner-token')

      expect(described_class).not_to receive(:service_available?)
      expect(described_class.ensure_service!).to be(true)
    end
  end

  it 'queries a discovered service without consulting the local feature flag state' do
    fake_client = instance_double(Lich::InternalAPI::ActiveSessions::Client)
    File.write(
      File.join(temp_dir, 'lich-active-sessions.json'),
      JSON.dump(owner_pid: 123, auth_token: 'shared-token', updated_at: Time.now.to_i)
    )

    allow(described_class).to receive(:enabled?).and_return(false)
    allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(fake_client)
    allow(fake_client).to receive(:snapshot).and_return(
      ok: true,
      payload: {
        source: 'ActiveSessionsAPI',
        total: 1,
        connected: 1,
        detachable: 1,
        sessions: [{ session_name: 'Char1' }]
      }
    )

    expect(described_class.query_snapshot[:total]).to eq(1)
  end

  it 'can register after the caller already admitted the feature gate without re-reading the flag' do
    fake_client = instance_double(Lich::InternalAPI::ActiveSessions::Client)
    File.write(
      File.join(temp_dir, 'lich-active-sessions.json'),
      JSON.dump(owner_pid: 123, auth_token: 'shared-token', updated_at: Time.now.to_i)
    )

    allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(fake_client)
    allow(fake_client).to receive(:ping).and_return(true)
    allow(fake_client).to receive(:upsert).and_return(ok: true)

    expect(described_class).not_to receive(:enabled?)

    expect(described_class.send(:register_session_admitted, { pid: 12_345 })).to be(true)
  end

  it 'bootstraps a replacement owner from admitted registration when no healthy service remains' do
    # No discovery file: simulates the previous owner having exited.
    fake_server = instance_double(
      Lich::InternalAPI::ActiveSessions::Server,
      start: true,
      stop: nil,
      auth_token: 'failover-token'
    )
    fake_client = instance_double(Lich::InternalAPI::ActiveSessions::Client)

    allow(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).and_return(fake_server)
    allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(fake_client)
    allow(fake_client).to receive(:upsert).and_return(ok: true)

    expect(described_class).to receive(:enabled?).and_return(true)

    expect(described_class.send(:register_session_admitted, { pid: Process.pid })).to be(true)

    discovery = JSON.parse(
      File.read(File.join(temp_dir, 'lich-active-sessions.json')),
      symbolize_names: true
    )
    expect(discovery[:owner_pid]).to eq(Process.pid)
    expect(discovery[:auth_token]).to eq('failover-token')
  end

  it 'does not bootstrap from admitted registration when the kill-switch is disabled' do
    allow(described_class).to receive(:enabled?).and_return(false)

    expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)

    expect(described_class.send(:register_session_admitted, { pid: Process.pid })).to be(false)
  end

  it 'can reuse an existing service after the caller already admitted the feature gate' do
    fake_client = instance_double(Lich::InternalAPI::ActiveSessions::Client, ping: true)
    File.write(
      File.join(temp_dir, 'lich-active-sessions.json'),
      JSON.dump(owner_pid: 123, auth_token: 'shared-token', updated_at: Time.now.to_i)
    )

    allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(fake_client)

    expect(described_class).not_to receive(:enabled?)
    expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)

    expect(described_class.send(:ensure_service_internal!, allow_bootstrap: false)).to be(true)
  end

  it 'does not bootstrap a new service from an admitted path once the real flag is off' do
    fake_client = instance_double(Lich::InternalAPI::ActiveSessions::Client)

    allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(fake_client)
    allow(fake_client).to receive(:ping).and_return(false)

    expect(described_class).not_to receive(:enabled?)
    expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)
    expect(described_class.send(:ensure_service_internal!, allow_bootstrap: false)).to be(false)
  end

  it 'still honors the normal gate for callers using only the public API surface' do
    allow(described_class).to receive(:enabled?).and_return(false)

    expect(described_class.register_session({ pid: 12_345 })).to be(false)
    expect(described_class.unregister_session(pid: 12_345)).to be(false)
    expect(described_class.ensure_service!).to be(false)
  end

  it 'can unregister after the caller already admitted the feature gate without re-reading the flag' do
    fake_client = instance_double(Lich::InternalAPI::ActiveSessions::Client)
    File.write(
      File.join(temp_dir, 'lich-active-sessions.json'),
      JSON.dump(owner_pid: 123, auth_token: 'shared-token', updated_at: Time.now.to_i)
    )

    allow(Lich::InternalAPI::ActiveSessions::Client).to receive(:new).and_return(fake_client)
    allow(fake_client).to receive(:ping).and_return(true)
    allow(fake_client).to receive(:remove).and_return(ok: true)

    expect(described_class).not_to receive(:enabled?)
    expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)

    expect(described_class.send(:unregister_session_admitted, pid: 12_345)).to be(true)
  end

  it 'keeps discovery when query_snapshot reports active sessions after the flag is off' do
    discovery_file = File.join(temp_dir, 'lich-active-sessions.json')
    File.write(
      discovery_file,
      JSON.dump(owner_pid: Process.pid, auth_token: 'shared-token', updated_at: Time.now.to_i)
    )

    allow(described_class).to receive(:query_snapshot).and_return(
      source: 'ActiveSessionsAPI',
      total: 2,
      connected: 2,
      detachable: 1,
      sessions: [{ session_name: 'Tsetem' }, { session_name: 'Another' }]
    )

    described_class.cleanup_discovery_if_last_session!

    expect(File.exist?(discovery_file)).to be(true)
  end
end
