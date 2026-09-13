# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/internal_api/coordination'

RSpec.describe Lich::InternalAPI::Coordination::Operations do
  let(:now) { [100.0] }
  let(:identity) do
    { game: 'GS3', character: 'Skooshii', incarnation: 'session-one',
      connection_generation: 0, run_id: 'hunter-one' }.freeze
  end
  let(:peer) do
    { game: 'GS3', character: 'Calvix', incarnation: 'session-two',
      connection_generation: 0, run_id: 'lab-one' }.freeze
  end
  let(:session) { Struct.new(:identity).new(identity) }
  let(:operations) do
    { 'probe' => { required: [:value], optional: [:note] },
      'hold'  => { required: [], optional: [] } }
  end
  let(:grant) do
    described_class::Grant.new(session: session, peer: peer, control_token: 'control-token',
                               operations: operations, enabled: true, clock: -> { now.first })
  end
  let(:descriptor) do
    { protocol_version: 1, host: '127.0.0.1', port: 12_345, identity: identity, peer: peer }
  end
  let(:transport) do
    double('bounded transport').tap do |instance|
      allow(instance).to receive(:request) do |command, payload|
        grant.send(:route, command: command, auth: 'control-token', payload: payload)
      end
    end
  end
  let(:client) do
    described_class::Client.new(descriptor: descriptor, control_token: 'control-token',
                                local_identity: peer, transport: transport)
  end

  after { grant.close }

  it 'is inert unless explicitly enabled' do
    expect(Lich::InternalAPI::ActiveSessions::Server).not_to receive(:new)
    disabled = described_class::Grant.new(session: session, peer: peer, control_token: 'token',
                                          operations: operations)
    expect(disabled.start).to be(false)
    expect(disabled.descriptor).to be_nil
  ensure
    disabled&.close
  end

  it 'advertises an exact token-free descriptor over the bounded native transport' do
    server = instance_double(Lich::InternalAPI::ActiveSessions::Server, start: true, running?: true,
                             host: '127.0.0.1', port: 34_567, stop: nil)
    expect(Lich::InternalAPI::ActiveSessions::Server).to receive(:new).with(
      host: '127.0.0.1', port: 0, registry: nil, auth_token: 'control-token',
      request_handler: kind_of(Method), max_frame_bytes: 16_384, max_clients: 4, timeout: 0.25
    ).and_return(server)

    expect(grant.start).to be(true)
    expect(grant.descriptor).to eq(descriptor.merge(port: 34_567))
    expect(grant.descriptor.keys).to contain_exactly(:protocol_version, :host, :port, :identity, :peer)
    expect(grant.descriptor.to_s).not_to include('control-token')
  end

  it 'delivers a validated request to its owner and reports outcome separately from cleanup' do
    submitted = client.submit(request_id: 'request-one', operation: 'probe', arguments: { value: 7 })
    expect(submitted[:payload]).to include(state: 'pending', outcome: nil, cleanup: 'not_required')

    request = grant.next_request(owner_tick: 1)
    expect(request).to include(request_id: 'request-one', operation: 'probe',
                               arguments: { 'value' => 7 }, owner_tick: 1)
    expect(client.result(request_id: 'request-one')[:payload]).to include(state: 'running', cleanup: 'pending')

    settled = grant.settle(request_id: 'request-one', owner_tick: 2, outcome: :succeeded,
                           result: { 'observed' => true }, cleanup: :pending)
    expect(settled).to include(state: 'settled', outcome: 'succeeded', cleanup: 'pending',
                               result: { 'observed' => true })
    expect(client.result(request_id: 'request-one')[:payload]).to eq(settled)

    complete = grant.finish_cleanup(request_id: 'request-one', owner_tick: 3)
    expect(complete).to include(state: 'settled', outcome: 'succeeded', cleanup: 'complete', owner_tick: 3)
  end

  it 'returns one retained receipt for lost-response retries and rejects changed arguments' do
    first = client.submit(request_id: 'same-id', operation: 'probe', arguments: { value: 1, note: 'same' })
    duplicate = client.submit(request_id: 'same-id', operation: 'probe', arguments: { note: 'same', value: 1 })
    conflict = client.submit(request_id: 'same-id', operation: 'probe', arguments: { value: 2, note: 'same' })

    expect(first).to eq(duplicate)
    expect(conflict).to eq(ok: false, error: 'request_conflict')
    expect(grant.next_request(owner_tick: 1)[:request_id]).to eq('same-id')
    expect(grant.next_request(owner_tick: 2)).to be_nil
  end

  it 'does not renew issuance-to-use validity on a delayed first submission' do
    base = { protocol_version: 1, identity: identity, peer: peer, request_id: 'late-one' }
    ticket = transport.request('ticket', base.merge(operation: 'probe', arguments: { value: 1 }))
    now[0] += 6.0
    response = transport.request('submit', base.merge(ticket: ticket[:payload][:ticket]))

    expect(response[:payload]).to include(state: 'expired', outcome: 'cancelled',
                                          reason: 'ticket_expired', owner_tick: nil)
    expect(grant.next_request(owner_tick: 1)).to be_nil
    expect(transport.request('ticket', base.merge(operation: 'probe', arguments: { value: 1 }))[:payload][:state]).to eq('expired')
  end

  it 'rejects unsupported operations, incomplete arguments and malformed values before queueing' do
    expect(client.submit(request_id: 'unknown', operation: 'travel', arguments: {})).to eq(
      ok: false, error: 'unsupported_operation'
    )
    expect(client.submit(request_id: 'missing', operation: 'probe', arguments: {})).to eq(
      ok: false, error: 'invalid_arguments'
    )
    expect(client.submit(request_id: 'extra', operation: 'probe', arguments: { value: 1, eval: 'x' })).to eq(
      ok: false, error: 'invalid_arguments'
    )
    expect(client.submit(request_id: 'object', operation: 'probe', arguments: { value: Object.new })).to eq(
      ok: false, error: 'invalid_request'
    )
    expect(grant.next_request(owner_tick: 1)).to be_nil
  end

  it 'invalidates the old grant before admission when the native session generation changes' do
    grant
    session.identity = identity.merge(connection_generation: 1).freeze
    expect(client.submit(request_id: 'old-generation', operation: 'hold')).to eq(
      ok: false, error: 'identity_mismatch'
    )
    expect(grant.next_request(owner_tick: 1)).to be_nil
    expect(grant.revoked?).to be(true)
  end

  it 'closes admission on revocation without pretending running work has stopped' do
    client.submit(request_id: 'running', operation: 'hold')
    grant.next_request(owner_tick: 1)
    client.submit(request_id: 'waiting', operation: 'hold')

    grant.revoke('operator_revoked')
    expect(client.result(request_id: 'running')[:payload]).to include(state: 'running', cleanup: 'pending')
    expect(client.result(request_id: 'waiting')[:payload]).to include(
      state: 'revoked', outcome: 'cancelled', reason: 'operator_revoked'
    )
    expect(client.submit(request_id: 'new', operation: 'hold')).to eq(ok: false, error: 'grant_closed')
    expect(grant.next_request(owner_tick: 2)).to be_nil

    failed = grant.settle(request_id: 'running', owner_tick: 2, outcome: :failed,
                          reason: 'interrupted', cleanup: :pending)
    expect(failed).to include(state: 'settled', outcome: 'failed', cleanup: 'pending')
    expect(grant.finish_cleanup(request_id: 'running', owner_tick: 3)[:cleanup]).to eq('complete')
  end

  it 'fails closed at capacity without evicting valid replay protection' do
    limited = described_class::Grant.new(session: session, peer: peer, control_token: 'token',
                                         operations: operations, enabled: true, capacity: 1)
    limited_transport = double('limited transport')
    allow(limited_transport).to receive(:request) do |command, payload|
      limited.send(:route, command: command, auth: 'token', payload: payload)
    end
    limited_client = described_class::Client.new(descriptor: descriptor, control_token: 'token',
                                                 local_identity: peer, transport: limited_transport)

    expect(limited_client.submit(request_id: 'kept', operation: 'hold')[:ok]).to be(true)
    expect(limited_client.submit(request_id: 'rejected', operation: 'hold')).to eq(ok: false, error: 'grant_capacity')
    expect(limited_client.submit(request_id: 'kept', operation: 'hold')[:payload][:state]).to eq('pending')
  ensure
    limited&.close
  end

  it 'serializes simultaneous retries into one owner request' do
    grant
    replies = 12.times.map do
      Thread.new { client.submit(request_id: 'contended', operation: 'probe', arguments: { value: 9 }) }
    end.map(&:value)

    expect(replies).to all(include(ok: true))
    expect(replies.map { |reply| reply[:payload][:argument_digest] }.uniq.size).to eq(1)
    expect(grant.next_request(owner_tick: 1)[:request_id]).to eq('contended')
    expect(grant.next_request(owner_tick: 2)).to be_nil
  end

  it 'keeps result queries responsive while the owner retains running work' do
    client.submit(request_id: 'slow-owner', operation: 'hold')
    grant.next_request(owner_tick: 1)
    20.times do
      expect(client.result(request_id: 'slow-owner')[:payload]).to include(state: 'running', cleanup: 'pending')
    end
  end

  it 'will not publish a settlement from a regressed owner tick' do
    client.submit(request_id: 'tick-bound', operation: 'hold')
    grant.next_request(owner_tick: 1)
    grant.next_request(owner_tick: 2)

    expect do
      grant.settle(request_id: 'tick-bound', owner_tick: 1, outcome: :succeeded)
    end.to raise_error(ArgumentError, 'owner tick regressed')
    expect(client.result(request_id: 'tick-bound')[:payload][:state]).to eq('running')
  end

  it 'requires the exact owner thread for take, settlement and endpoint lifecycle' do
    client.submit(request_id: 'owner-only', operation: 'hold')
    errors = Queue.new
    thread = Thread.new do
      %i[start next settle close].each do |operation|
        begin
          case operation
          when :start then grant.start
          when :next then grant.next_request(owner_tick: 1)
          when :settle then grant.settle(request_id: 'owner-only', owner_tick: 1, outcome: :failed)
          when :close then grant.close
          end
        rescue StandardError => e
          errors << e
        end
      end
    end
    thread.join

    expect(4.times.map { errors.pop }).to all(be_a(ThreadError))
    expect(grant.next_request(owner_tick: 1)[:request_id]).to eq('owner-only')
  end

  it 'rejects invalid client receipts rather than trusting transport data' do
    bad = double('bad transport', request: { ok: true, payload: { state: 'settled' } })
    peer_client = described_class::Client.new(descriptor: descriptor, control_token: 'token',
                                              local_identity: peer, transport: bad)
    expect(peer_client.result(request_id: 'request'))
      .to eq(ok: false, error: 'invalid_receipt')
  end

  it 'rejects a validly shaped receipt for a different request ID' do
    receipt = {
      identity: identity, peer: peer, request_id: 'different', operation: 'hold', argument_digest: 'a' * 64,
      state: 'settled', outcome: 'succeeded', cleanup: 'complete', reason: nil,
      owner_tick: 1, result: nil
    }
    wrong = double('misrouted transport', request: { ok: true, payload: receipt })
    peer_client = described_class::Client.new(descriptor: descriptor, control_token: 'token',
                                              local_identity: peer, transport: wrong)
    expect(peer_client.result(request_id: 'expected'))
      .to eq(ok: false, error: 'invalid_receipt')
  end

  it 'rejects a valid receipt attributed to a different session pair' do
    receipt = {
      identity: identity.merge(run_id: 'other-owner'), peer: peer,
      request_id: 'expected', operation: 'hold', argument_digest: 'a' * 64,
      state: 'settled', outcome: 'succeeded', cleanup: 'complete', reason: nil,
      owner_tick: 1, result: nil
    }
    wrong = double('cross-session transport', request: { ok: true, payload: receipt })
    peer_client = described_class::Client.new(descriptor: descriptor, control_token: 'token',
                                              local_identity: peer, transport: wrong)
    expect(peer_client.result(request_id: 'expected'))
      .to eq(ok: false, error: 'invalid_receipt')
  end

  it 'works end to end over the real bounded loopback transport' do
    expect(grant.start).to be(true)
    network = described_class::Client.new(descriptor: grant.descriptor, control_token: 'control-token',
                                          local_identity: peer)
    expect(network.submit(request_id: 'network-one', operation: 'probe', arguments: { value: 4 })[:payload])
      .to include(state: 'pending')
    expect(grant.next_request(owner_tick: 1)).to include(request_id: 'network-one')
    grant.settle(request_id: 'network-one', owner_tick: 1, outcome: :succeeded, cleanup: :not_required)
    expect(network.result(request_id: 'network-one')[:payload]).to include(
      state: 'settled', outcome: 'succeeded', cleanup: 'not_required'
    )
  end
end
