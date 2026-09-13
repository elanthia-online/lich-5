# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/internal_api/coordination'
require 'timeout'

RSpec.describe Lich::InternalAPI::Coordination do
  let(:now) { [100.0] }
  let(:session) do
    described_class::Session.new(game: 'GS3', character: 'Example', run_id: 'hunt-1',
                                 read_token: 'explicit-read-token', enabled: true, clock: -> { now.first })
  end
  let(:projection) do
    { identity: session.identity, sequence: 1, owner_tick: 1, connected: true,
      room: { id: 42, epoch: 7 }, readiness: { ready: true, coherence: 'coherent' },
      sources: { room: { version: 3, age: 0.1, room_epoch: 7, connection_generation: 0 },
                 readiness: { version: 8, age: 0.2, room_epoch: 7, connection_generation: 0 } } }
  end
  let(:descriptor) do
    { protocol_version: 1, host: '127.0.0.1', port: 12_345, identity: session.identity }
  end
  let(:transport) do
    double('existing JSON transport').tap do |instance|
      allow(instance).to receive(:request) { |command, payload| session.send(:handle, command, payload) }
    end
  end
  let(:client) do
    described_class::Client.new(descriptor: descriptor, read_token: 'explicit-read-token',
                                clock: -> { now.first }, transport: transport)
  end

  after { session.close }

  it 'does not create a listener or threads by default' do
    expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)
    disabled = described_class::Session.new(game: 'GS3', character: 'Example', run_id: 'run', read_token: 'token')
    expect(disabled.start).to be(false)
    expect(disabled.descriptor).to be_nil
    expect(disabled.publish(**projection.merge(identity: disabled.identity))).to be(false)
  ensure
    disabled&.close
  end

  it 'reuses the bounded native transport and advertises no credential' do
    server = instance_double(Lich::InternalAPI::ActiveSessions::Server, start: true, running?: true,
                             host: '127.0.0.1', port: 34_567, stop: nil)
    expect(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).with(
      host: '127.0.0.1', port: 0, registry: nil, auth_token: 'explicit-read-token',
      request_handler: kind_of(Method), max_frame_bytes: 16_384, max_clients: 4, timeout: 0.25
    ).and_return(server)
    expect(session.start).to be(true)
    expect(session.descriptor).to eq(descriptor.merge(port: 34_567))
    expect(session.descriptor.keys).to contain_exactly(:protocol_version, :host, :port, :identity)
    expect(server).to receive(:stop)
    session.close
    expect(session.start).to be(false)
  end

  it 'copies owner data into an immutable published snapshot' do
    expect(session.publish(**projection)).to be(true)
    projection[:room][:id] = 999
    snapshot = client.snapshot[:payload]
    expect(snapshot[:room][:id]).to eq(42)
    expect(snapshot[:ready]).to be(true)
    expect { snapshot[:room][:id] = 123 }.to raise_error(FrozenError)
  end

  it 'requires a completed advancing owner tick as well as an advancing sequence' do
    expect(session.publish(**projection)).to be(true)
    expect(session.publish(**projection.merge(sequence: 2))).to be(false)
    expect(session.publish(**projection.merge(owner_tick: 2))).to be(false)
    expect(session.publish(**projection.merge(sequence: 0, owner_tick: 0))).to be(false)
  end

  it 'does not freshen old observations on a new owner tick or ping' do
    session.publish(**projection)
    now[0] += 2.0
    expect(client.ping).to be(true)
    projection[:sources].each_value { |source| source[:age] = 0.0 }
    expect(session.publish(**projection.merge(sequence: 2, owner_tick: 2))).to be(true)
    result = client.snapshot[:payload]
    expect(result[:age]).to eq(0.0)
    expect(result[:sources][:readiness][:age]).to be_within(0.00001).of(2.2)
    expect(result[:ready]).to be(false)
  end

  it 'rejects regressing sources and changes disguised as the same observation' do
    session.publish(**projection)
    projection[:sequence] = projection[:owner_tick] = 2
    projection[:sources][:room][:version] -= 1
    expect(session.publish(**projection)).to be(false)
    projection[:sources][:room][:version] += 1
    projection[:room][:id] = 99
    expect(session.publish(**projection)).to be(false)
  end

  it 'remembers source versions across unavailable publications' do
    session.publish(**projection)
    unknown = projection.merge(sequence: 2, owner_tick: 2, sources: { room: nil, readiness: nil })
    expect(session.publish(**unknown)).to be(true)
    projection[:sources][:room][:version] -= 1
    expect(session.publish(**projection.merge(sequence: 3, owner_tick: 3))).to be(false)
  end

  it 'expires an unchanged published copy even while the endpoint answers' do
    session.publish(**projection)
    expect(client.snapshot[:payload][:ready]).to be(true)
    now[0] += 2.0
    expect(client.ping).to be(true)
    expect(client.snapshot[:payload][:ready]).to be(false)
  end

  it 'never treats unknown, mixed, missing, disconnected or mismatched sources as ready' do
    cases = [
      { readiness: { ready: true, coherence: 'unknown' } },
      { readiness: { ready: true, coherence: 'mixed' } },
      { readiness: { ready: nil, coherence: 'coherent' } },
      { sources: { room: nil, readiness: nil } },
      { connected: false }, { connected: nil },
      { room: { id: nil, epoch: nil } },
      { sources: projection[:sources].merge(room: projection[:sources][:room].merge(room_epoch: 8)) },
      { sources: projection[:sources].merge(room: projection[:sources][:room].merge(connection_generation: 9)) }
    ]
    cases.each do |change|
      isolated = described_class::Session.new(game: 'GS3', character: 'Example', run_id: 'hunt-1', read_token: 'token', enabled: true)
      expect(isolated.publish(**projection.merge(change).merge(identity: isolated.identity))).to be(true)
      response = isolated.send(:handle, 'snapshot', protocol_version: 1, expected_identity: isolated.identity, fields: %w[room readiness])
      peer = described_class::Client.new(descriptor: descriptor.merge(identity: isolated.identity), read_token: 'token',
                                         transport: double(request: response))
      expect(peer.snapshot[:payload][:ready]).to be(false)
      isolated.close
    end
  end

  it 'adds its whole local round trip to reported ages without comparing clocks' do
    session.publish(**projection)
    ticks = [5_000.0, 5_000.9]
    peer = described_class::Client.new(descriptor: descriptor, read_token: 'token', clock: -> { ticks.shift }, transport: transport)
    result = peer.snapshot[:payload]
    expect(result[:sources][:readiness][:age]).to be_within(0.00001).of(1.1)
    expect(result[:ready]).to be(false)
  end

  it 'ages a replayed snapshot by receiver-local elapsed time' do
    session.publish(**projection)
    response = session.send(:handle, 'snapshot', protocol_version: 1, expected_identity: session.identity, fields: %w[room readiness])
    allow(transport).to receive(:request).and_return(response)
    expect(client.snapshot[:payload][:ready]).to be(true)
    now[0] += 10.0
    replay = client.snapshot[:payload]
    expect(replay[:age]).to eq(10.0)
    expect(replay[:sources][:readiness][:age]).to be_within(0.00001).of(10.2)
    expect(replay[:ready]).to be(false)
  end

  it 'preserves source age floors across new owner ticks and unavailable sources' do
    session.publish(**projection)
    response = session.send(:handle, 'snapshot', protocol_version: 1, expected_identity: session.identity, fields: %w[room readiness])
    allow(transport).to receive(:request).and_return(response)
    expect(client.snapshot[:payload][:ready]).to be(true)
    unknown = response[:payload].merge(sequence: 2, owner_tick: 2, sources: { room: nil, readiness: nil })
    allow(transport).to receive(:request).and_return(ok: true, payload: unknown)
    now[0] += 0.5
    expect(client.snapshot[:payload][:ready]).to be(false)
    repeated_sources = response[:payload].merge(sequence: 3, owner_tick: 3)
    allow(transport).to receive(:request).and_return(ok: true, payload: repeated_sources)
    now[0] += 9.5
    stale = client.snapshot[:payload]
    expect(stale[:age]).to eq(0.0)
    expect(stale[:sources][:readiness][:age]).to be_within(0.00001).of(10.2)
    expect(stale[:ready]).to be(false)

    fresh_sources = repeated_sources[:sources].transform_values { |source| source.merge(version: source[:version] + 1, age: 0.0) }
    fresh = repeated_sources.merge(sequence: 4, owner_tick: 4, sources: fresh_sources)
    allow(transport).to receive(:request).and_return(ok: true, payload: fresh)
    expect(client.snapshot[:payload][:ready]).to be(true)
  end

  it 'retains the previous round-trip age bound when a later replay is faster' do
    session.publish(**projection)
    response = session.send(:handle, 'snapshot', protocol_version: 1, expected_identity: session.identity, fields: %w[room readiness])
    allow(transport).to receive(:request).and_return(response)
    ticks = [5_000.0, 5_000.7, 5_000.9, 5_000.9]
    peer = described_class::Client.new(descriptor: descriptor, read_token: 'token', clock: -> { ticks.shift }, transport: transport)
    expect(peer.snapshot[:payload][:ready]).to be(true)
    replay = peer.snapshot[:payload]
    expect(replay[:sources][:readiness][:age]).to be_within(0.00001).of(1.1)
    expect(replay[:ready]).to be(false)
  end

  it 'rejects a concurrent snapshot promptly instead of queuing behind transport I/O' do
    session.publish(**projection)
    entered = Queue.new
    release = Queue.new
    expect(transport).to receive(:request).once do |command, payload|
      entered << true
      release.pop
      session.send(:handle, command, payload)
    end
    first = Thread.new { client.snapshot }
    Timeout.timeout(1) { entered.pop }
    busy = Timeout.timeout(0.25) { client.snapshot }
    expect(busy).to eq(ok: false, error: 'snapshot busy')
    release << true
    expect(first.value[:ok]).to be(true)
  ensure
    release << true if release
    first&.join(1)
    first&.kill if first&.alive?
  end

  it 'requires the exact protocol, identity, and selected field set on every route' do
    session.publish(**projection)
    base = { protocol_version: 1, expected_identity: session.identity }
    expect(session.send(:handle, 'ping', base)[:ok]).to be(true)
    expect(session.send(:handle, 'ping', base.merge(protocol_version: 2))[:ok]).to be(false)
    expect(session.send(:handle, 'ping', base.merge(expected_identity: session.identity.merge(run_id: 'other')))[:ok]).to be(false)
    expect(session.send(:handle, 'snapshot', base.merge(fields: ['world']))[:ok]).to be(false)
    expect(session.send(:handle, 'snapshot', base.merge(fields: %w[room readiness], eval: 'anything'))[:ok]).to be(false)
    expect(session.send(:route, command: 'ping', auth: 'token', payload: base, eval: 'anything')[:ok]).to be(false)
    %w[upsert remove hold release request result eval execute].each do |command|
      expect(session.send(:handle, command, base)[:ok]).to be(false)
    end
  end

  it 'invalidates the previous generation and published copy on reconnect' do
    session.publish(**projection)
    expect(client.snapshot[:ok]).to be(true)
    old_identity = session.identity
    session.reconnect
    expect(session.identity[:incarnation]).to eq(old_identity[:incarnation])
    expect(session.identity[:connection_generation]).to eq(1)
    expect(client.ping).to be(false)
    expect(client.snapshot[:ok]).to be(false)
    expect(session.publish(**projection.merge(sequence: 2, owner_tick: 2))).to be(false)
    expect(session.send(:handle, 'snapshot', protocol_version: 1, expected_identity: session.identity, fields: %w[room readiness])[:ok]).to be(false)
  end

  it 'rejects malformed, identity-mismatched, and version-mismatched responses' do
    session.publish(**projection)
    response = session.send(:handle, 'snapshot', protocol_version: 1, expected_identity: session.identity, fields: %w[room readiness])
    invalid = [response[:payload].merge(protocol_version: 99), response[:payload].merge(extra: 'world'),
               response[:payload].merge(identity: session.identity.merge(character: 'Other')),
               response[:payload].merge(age: -1), response[:payload].merge(age: Float::NAN),
               response[:payload].merge(sources: { room: 'bad', readiness: nil })]
    invalid.each do |payload|
      allow(transport).to receive(:request).and_return(ok: true, payload: payload)
      expect(client.snapshot[:ok]).to be(false)
    end
  end

  it 'accepts repeated reads but rejects rollback and non-advancing owner ticks' do
    session.publish(**projection)
    expect(client.snapshot[:ok]).to be(true)
    expect(client.snapshot[:ok]).to be(true)
    response = session.send(:handle, 'snapshot', protocol_version: 1, expected_identity: session.identity, fields: %w[room readiness])
    [response[:payload].merge(sequence: 0), response[:payload].merge(sequence: 2, owner_tick: 1),
     response[:payload].merge(sequence: 2, owner_tick: 2, sources: projection[:sources].merge(room: projection[:sources][:room].merge(version: 0)))].each do |payload|
      allow(transport).to receive(:request).and_return(ok: true, payload: payload)
      expect(client.snapshot[:ok]).to be(false)
    end
  end

  it 'rejects unknown or oversized owner fields instead of exporting arbitrary state' do
    expect(session.publish(**projection.merge(room: { id: 1, epoch: 1, world: {} }))).to be(false)
    expect(session.publish(**projection.merge(readiness: { ready: true, coherence: 'coherent', arbitrary: 'data' }))).to be(false)
    expect(session.publish(**projection.merge(room: { id: 'x' * 257, epoch: 1 }))).to be(false)
  end

  it 'rejects non-loopback descriptors and missing explicit read credentials' do
    expect { described_class::Client.new(descriptor: descriptor.merge(host: 'example.org'), read_token: 'token') }.to raise_error(ArgumentError)
    expect { described_class::Client.new(descriptor: descriptor, read_token: '') }.to raise_error(ArgumentError)
  end

  it 'serves only authenticated read snapshots over the reused loopback transport', :real_socket do
    expect(session.start).to be(true)
    expect(session.publish(**projection)).to be(true)
    peer = described_class::Client.new(descriptor: session.descriptor, read_token: 'explicit-read-token')
    expect(peer.ping).to be(true)
    expect(peer.snapshot[:payload][:ready]).to be(true)
    unauthorized = described_class::Client.new(descriptor: session.descriptor, read_token: 'native-discovery-token')
    expect(unauthorized.ping).to be(false)
    expect(unauthorized.snapshot[:ok]).to be(false)
    raw = Lich::InternalAPI::ActiveSessions::Client.new(
      host: session.descriptor[:host], port: session.descriptor[:port], auth_token: 'explicit-read-token',
      max_frame_bytes: 16_384, timeout: 0.25
    )
    expect(raw.request('upsert', pid: 123)[:ok]).to be(false)
    session.reconnect
    expect(peer.ping).to be(false)
    session.close
    expect(peer.ping).to be(false)
  end
end
