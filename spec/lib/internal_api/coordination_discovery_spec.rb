# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/internal_api/coordination/discovery'

RSpec.describe Lich::InternalAPI::Coordination::Discovery do
  let(:coordination) { Lich::InternalAPI::Coordination }
  let(:native) { Lich::InternalAPI::ActiveSessions }
  let(:identity) { { game: 'GS3', character: 'Synthetic', incarnation: 'synthetic-incarnation', connection_generation: 0, run_id: 'test-run' } }
  let(:descriptor) { { protocol_version: 1, host: '127.0.0.1', port: 12_345, identity: identity } }
  let(:session) { instance_double(coordination::Session, descriptor: descriptor) }
  let(:registry) { native::Registry.new(process_checker: ->(_pid) { true }) }
  let(:api) { double('native active sessions') }
  let(:discovery) { described_class.new(enabled: true, active_sessions: api) }
  let(:character_record) do
    { pid: Process.pid, session_name: 'Synthetic', role: 'detachable', connected: true,
      hidden: true, started_at: 123, listener_host: '127.0.0.1', listener_port: 4567, unrelated: 'preserved' }
  end

  before do
    allow(api).to receive(:register_session) do |payload|
      registry.upsert(payload)
      true
    end
    allow(api).to receive(:query_snapshot) { registry.snapshot }
  end

  it 'is inert unless explicitly enabled' do
    disabled = described_class.new(active_sessions: api)
    expect(session).not_to receive(:descriptor)
    expect(api).not_to receive(:register_session)
    expect(api).not_to receive(:query_snapshot)

    expect(disabled.publish(session)).to be(false)
    expect(disabled.resolve(identity: identity, read_token: 'read-secret')).to be_nil
  end

  it 'merges only endpoint metadata and preserves unrelated native character fields' do
    registry.upsert(character_record)
    expect(discovery.publish(session)).to be(true)
    expect(api).to have_received(:register_session).with(pid: Process.pid, coordination: descriptor)
    expect(registry.session(Process.pid)).to include(character_record.merge(coordination: descriptor))

    # Ordinary native lifecycle updates continue to preserve this opt-in key.
    registry.upsert(pid: Process.pid, connected: false)
    expect(registry.session(Process.pid)).to include(coordination: descriptor, connected: false)
  end

  it 'refuses absent or malformed descriptors, including accidentally included credentials' do
    [nil, descriptor.merge(read_token: 'secret'), descriptor.merge(host: '192.0.2.1'),
     descriptor.merge(port: 0), descriptor.merge(identity: identity.merge(incarnation: nil))].each do |value|
      allow(session).to receive(:descriptor).and_return(value)
      expect(discovery.publish(session)).to be(false)
    end
    expect(api).not_to have_received(:register_session)
  end

  it 'reports native publication failure without assuming discovery is enabled' do
    allow(api).to receive(:register_session).and_return(false)
    expect(discovery.publish(session)).to be(false)
  end

  it 'returns unavailable for missing, malformed, or unavailable native discovery' do
    [nil, {}, { source: 'ActiveSessionsAPI', sessions: [], error: 'unavailable' },
     { source: 'other', sessions: [] }, { source: 'ActiveSessionsAPI', sessions: nil }].each do |value|
      allow(api).to receive(:query_snapshot).and_return(value)
      expect(discovery.resolve(identity: identity, read_token: 'read-secret')).to be_nil
    end
  end

  it 'requires full identity and one unambiguous matching registration before connecting' do
    registry.upsert(pid: Process.pid, coordination: descriptor)
    expect(coordination::Client).not_to receive(:new)
    identity.keys.each do |key|
      changed = identity.merge(key => (key == :connection_generation ? 1 : 'different'))
      expect(discovery.resolve(identity: changed, read_token: 'read-secret')).to be_nil
    end
    registry.upsert(pid: Process.pid + 1, coordination: descriptor)
    expect(discovery.resolve(identity: identity, read_token: 'read-secret')).to be_nil
  end

  it 'refuses untrusted malformed registration metadata without connecting' do
    expect(coordination::Client).not_to receive(:new)
    [nil, false, 'invalid', descriptor.merge(auth_token: 'secret'), descriptor.merge(port: -1)].each do |value|
      registry.upsert(pid: Process.pid, coordination: value)
      expect(discovery.resolve(identity: identity, read_token: 'read-secret')).to be_nil
    end
  end

  it 'requires an authenticated identity check and re-queries discovery on each resolution' do
    registry.upsert(pid: Process.pid, coordination: descriptor)
    client = instance_double(coordination::Client, ping: true)
    allow(coordination::Client).to receive(:new).with(descriptor: descriptor, read_token: 'read-secret', max_age: 1.0, timeout: 0.25).and_return(client)
    expect(discovery.resolve(identity: identity, read_token: 'read-secret')).to equal(client)
    allow(client).to receive(:ping).and_return(false)
    expect(discovery.resolve(identity: identity, read_token: 'read-secret')).to be_nil
    allow(api).to receive(:query_snapshot).and_return(source: 'ActiveSessionsAPI', sessions: [], error: 'owner lost')
    expect(discovery.resolve(identity: identity, read_token: 'read-secret')).to be_nil
    expect(api).to have_received(:query_snapshot).exactly(3).times
  end

  context 'with native registry and endpoint transports' do
    let(:discovery) { described_class.new(enabled: true) }

    before do
      @directory = Dir.mktmpdir('coordination-discovery')
      stub_const('ACTIVE_SESSION_DIR', @directory)
      @endpoint = coordination::Session.new(game: 'GS3', character: 'Synthetic', run_id: 'test-run', read_token: 'read-secret', enabled: true)
      expect(@endpoint.start).to be(true)
      expect(native.register_session(character_record)).to be(true)
    end

    after do
      @endpoint&.close
      native.stop_service!
      FileUtils.remove_entry(@directory)
    end

    it 'authenticates discovery, rejects reconnect and close staleness, and preserves native registration' do
      first_identity = @endpoint.identity
      expect(discovery.publish(@endpoint)).to be(true)
      expect(discovery.resolve(identity: first_identity, read_token: 'wrong-secret')).to be_nil
      expect(discovery.resolve(identity: first_identity, read_token: 'read-secret')).to be_a(coordination::Client)
      @endpoint.reconnect
      expect(discovery.resolve(identity: first_identity, read_token: 'read-secret')).to be_nil
      expect(discovery.resolve(identity: @endpoint.identity, read_token: 'read-secret')).to be_nil
      expect(discovery.publish(@endpoint)).to be(true)
      expect(discovery.resolve(identity: @endpoint.identity, read_token: 'read-secret')).to be_a(coordination::Client)

      @endpoint.close
      expect(discovery.publish(@endpoint)).to be(false)
      expect(discovery.resolve(identity: @endpoint.identity, read_token: 'read-secret')).to be_nil
      record = native.query_snapshot.fetch(:sessions).find { |entry| entry[:pid] == Process.pid }
      expect(record).to include(character_record)
      expect(record[:coordination].keys).to contain_exactly(:protocol_version, :host, :port, :identity)
    end

    it 'requires explicit republication after native owner restart while an existing peer remains direct' do
      expect(discovery.publish(@endpoint)).to be(true)
      verified_peer = discovery.resolve(identity: @endpoint.identity, read_token: 'read-secret')
      expect(verified_peer).to be_a(coordination::Client)
      native.stop_service!
      expect(discovery.resolve(identity: @endpoint.identity, read_token: 'read-secret')).to be_nil
      expect(verified_peer.ping).to be(true)

      expect(native.register_session(character_record)).to be(true)
      expect(discovery.resolve(identity: @endpoint.identity, read_token: 'read-secret')).to be_nil
      expect(discovery.publish(@endpoint)).to be(true)
      expect(discovery.resolve(identity: @endpoint.identity, read_token: 'read-secret')).to be_a(coordination::Client)
      expect(native.query_snapshot.fetch(:sessions).first).to include(character_record)
    end
  end
end
