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
