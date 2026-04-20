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
    allow(described_class).to receive(:enabled?).and_return(false)

    expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)
    expect(described_class.send(:ensure_service_internal!, allow_bootstrap: false)).to be(false)
  end

  it 'still honors the normal gate for callers that do not pass assume_enabled' do
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
