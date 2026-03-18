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

    expect(described_class.ensure_service!).to be(true)

    discovery = JSON.parse(File.read(File.join(temp_dir, 'lich-active-sessions.json')), symbolize_names: true)
    expect(discovery[:owner_pid]).to eq(Process.pid)
    expect(discovery[:auth_token]).to be_a(String)
    expect(discovery[:auth_token]).not_to be_empty
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

    allow(described_class).to receive(:snapshot).and_return(
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
end
