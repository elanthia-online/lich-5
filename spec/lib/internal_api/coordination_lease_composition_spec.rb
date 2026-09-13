# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/internal_api/coordination'

module CoordinationLeaseCompositionFixtures
  # Test-only reference store. It is deliberately not a public Leases
  # implementation; it makes the stabilization gate executable against the
  # existing discrete-operation delivery contract.
  class SyntheticLeaseStore
    attr_reader :apply_counts

    def initialize(clock:)
      @clock = clock
      @mutex = Mutex.new
      @leases = {}
      @fences = Hash.new(0)
      @results = {}
      @apply_counts = Hash.new(0)
      @next_lease = 0
    end

    def apply(request_id:, operation:, arguments:)
      @mutex.synchronize do
        return @results.fetch(request_id) if @results.key?(request_id)

        @apply_counts[request_id] += 1
        @results[request_id] = public_send(operation, **arguments.transform_keys(&:to_sym)).freeze
      end
    end

    def claim(resource:, participant:, holder:, ttl:)
      current = active(resource)
      return failure('held', current) if current

      @next_lease += 1
      acquired_at = @clock.call
      install(resource, participant, holder, "lease-#{@next_lease}", acquired_at, ttl)
    end

    def renew(resource:, participant:, holder:, lease_id:, fence:, ttl:)
      current = exact(resource, participant, holder, lease_id, fence)
      return failure('stale_fence', current) unless current

      current[:expires_at] = @clock.call + ttl
      success(current)
    end

    def resume(resource:, participant:, holder:, lease_id:, fence:, ttl:)
      current = @leases[resource]
      unless current && current[:participant] == participant && current[:lease_id] == lease_id &&
             current[:fence] == fence && !current[:released] && current[:expires_at] > @clock.call
        return failure('stale_fence', current)
      end

      @fences[resource] += 1
      current[:holder] = holder
      current[:fence] = @fences[resource]
      current[:expires_at] = @clock.call + ttl
      success(current)
    end

    def release(resource:, participant:, holder:, lease_id:, fence:)
      current = exact(resource, participant, holder, lease_id, fence)
      return success(@leases[resource]) if @leases[resource]&.dig(:released)
      return failure('stale_fence', current) unless current

      current[:released] = true
      success(current)
    end

    def reclaim(resource:, participant:, holder:, ttl:)
      current = @leases[resource]
      return failure('not_expired', current) if current && !current[:released] && current[:expires_at] > @clock.call

      @next_lease += 1
      install(resource, participant, holder, "lease-#{@next_lease}", @clock.call, ttl)
    end

    def authorized?(resource:, holder:, fence:)
      current = active(resource)
      current && current[:holder] == holder && current[:fence] == fence
    end

    private

    def active(resource)
      current = @leases[resource]
      current if current && !current[:released] && current[:expires_at] > @clock.call
    end

    def exact(resource, participant, holder, lease_id, fence)
      current = active(resource)
      current if current && current.values_at(:participant, :holder, :lease_id, :fence) ==
                            [participant, holder, lease_id, fence]
    end

    def install(resource, participant, holder, lease_id, acquired_at, ttl)
      @fences[resource] += 1
      @leases[resource] = {
        resource: resource, participant: participant, holder: holder,
        lease_id: lease_id, fence: @fences[resource], acquired_at: acquired_at,
        expires_at: @clock.call + ttl, released: false
      }
      success(@leases[resource])
    end

    def success(lease)
      { ok: true, lease: lease&.dup }
    end

    def failure(reason, lease)
      { ok: false, reason: reason, lease: lease&.dup }
    end
  end

  class DirectOperationTransport
    def initialize(grant, token)
      @grant = grant
      @token = token
    end

    def request(command, payload)
      @grant.send(:route, command: command, auth: @token, payload: payload)
    end
  end

  Peer = Struct.new(:grant, :client, :identity, keyword_init: true)
end

RSpec.describe 'Coordination operation/lease composition gate' do
  let(:now) { [100.0] }
  let(:clock) { -> { now.first } }
  let(:owner_identity) do
    { game: 'TEST', character: 'Authority', incarnation: 'authority-one',
      connection_generation: 0, run_id: 'lease-harness' }.freeze
  end
  let(:session) { Struct.new(:identity).new(owner_identity) }
  let(:definitions) do
    {
      'claim'   => { required: %i[resource participant holder ttl], optional: [] },
      'renew'   => { required: %i[resource participant holder lease_id fence ttl], optional: [] },
      'resume'  => { required: %i[resource participant holder lease_id fence ttl], optional: [] },
      'release' => { required: %i[resource participant holder lease_id fence], optional: [] },
      'reclaim' => { required: %i[resource participant holder ttl], optional: [] }
    }
  end
  let(:store) { CoordinationLeaseCompositionFixtures::SyntheticLeaseStore.new(clock: clock) }
  let(:peers) { %w[Alpha Beta Gamma].map.with_index { |name, index| build_peer(name, index) } }

  after { peers.each { |peer| peer.grant.close } }

  def build_peer(name, index)
    identity = {
      game: 'TEST', character: name, incarnation: "#{name.downcase}-one",
      connection_generation: 0, run_id: 'lease-harness'
    }.freeze
    token = "token-#{name.downcase}"
    grant = Lich::InternalAPI::Coordination::Operations::Grant.new(
      session: session, peer: identity, control_token: token,
      operations: definitions, enabled: true, clock: clock
    )
    descriptor = {
      protocol_version: 1, host: '127.0.0.1', port: 10_000 + index,
      identity: owner_identity, peer: identity
    }
    client = Lich::InternalAPI::Coordination::Operations::Client.new(
      descriptor: descriptor, control_token: token, local_identity: identity,
      transport: CoordinationLeaseCompositionFixtures::DirectOperationTransport.new(grant, token)
    )
    CoordinationLeaseCompositionFixtures::Peer.new(grant: grant, client: client, identity: identity)
  end

  def apply(peer, tick, request_id)
    request = peer.grant.next_request(owner_tick: tick)
    expect(request[:request_id]).to eq(request_id)
    result = store.apply(request_id: request_id, operation: request[:operation], arguments: request[:arguments])
    peer.grant.settle(
      request_id: request_id, owner_tick: tick, outcome: result[:ok] ? :succeeded : :failed,
      reason: result[:reason], result: result, cleanup: :not_required
    )
    result
  end

  it 'yields exactly one fenced owner for simultaneous claims through discrete operations' do
    replies = peers.map.with_index do |peer, index|
      Thread.new do
        peer.client.submit(
          request_id: "claim-#{index}", operation: 'claim',
          arguments: { resource: 'pool-one', participant: peer.identity[:character],
                       holder: peer.identity[:incarnation], ttl: 10 }
        )
      end
    end.map(&:value)
    expect(replies).to all(include(ok: true))

    results = peers.map.with_index { |peer, index| apply(peer, 1, "claim-#{index}") }
    winners = results.select { |result| result[:ok] }
    expect(winners.length).to eq(1)
    lease = winners.first[:lease]
    expect(store.authorized?(resource: 'pool-one', holder: lease[:holder], fence: lease[:fence])).to be(true)
  end

  it 'keeps renew and release idempotent through immutable operation IDs' do
    peer = peers.first
    peer.client.submit(request_id: 'claim', operation: 'claim',
                       arguments: { resource: 'pool', participant: 'durable-alpha',
                                    holder: 'alpha-one', ttl: 10 })
    lease = apply(peer, 1, 'claim')[:lease]

    renew = { resource: 'pool', participant: 'durable-alpha', holder: 'alpha-one',
              lease_id: lease[:lease_id], fence: lease[:fence], ttl: 20 }
    first = peer.client.submit(request_id: 'renew', operation: 'renew', arguments: renew)
    duplicate = peer.client.submit(request_id: 'renew', operation: 'renew', arguments: renew)
    expect(duplicate).to eq(first)
    apply(peer, 2, 'renew')
    expect(peer.grant.next_request(owner_tick: 3)).to be_nil
    expect(store.apply_counts['renew']).to eq(1)

    release = renew.reject { |key, _| key == :ttl }
    peer.client.submit(request_id: 'release', operation: 'release', arguments: release)
    apply(peer, 4, 'release')
    expect(peer.client.submit(request_id: 'release', operation: 'release', arguments: release)[:payload])
      .to include(state: 'settled', outcome: 'succeeded')
    expect(store.apply_counts['release']).to eq(1)
  end

  it 'resumes durable standing under a new holder while fencing the stale incarnation' do
    peer = peers.first
    peer.client.submit(request_id: 'claim', operation: 'claim',
                       arguments: { resource: 'pool', participant: 'durable-alpha',
                                    holder: 'alpha-old', ttl: 10 })
    original = apply(peer, 1, 'claim')[:lease]
    resume = { resource: 'pool', participant: 'durable-alpha', holder: 'alpha-new',
               lease_id: original[:lease_id], fence: original[:fence], ttl: 10 }
    peer.client.submit(request_id: 'resume', operation: 'resume', arguments: resume)
    resumed = apply(peer, 2, 'resume')[:lease]

    expect(resumed[:acquired_at]).to eq(original[:acquired_at])
    expect(resumed[:fence]).to be > original[:fence]
    expect(store.authorized?(resource: 'pool', holder: 'alpha-old', fence: original[:fence])).to be(false)
    expect(store.authorized?(resource: 'pool', holder: 'alpha-new', fence: resumed[:fence])).to be(true)
  end

  it 'keeps unknown cleanup distinct from release and permits fenced reclaim only after expiry' do
    owner, reclaimer = peers.first(2)
    owner.client.submit(request_id: 'claim', operation: 'claim',
                        arguments: { resource: 'pool', participant: 'durable-alpha',
                                     holder: 'alpha-one', ttl: 5 })
    lease = apply(owner, 1, 'claim')[:lease]
    owner.client.submit(request_id: 'lost-release', operation: 'release',
                        arguments: { resource: 'pool', participant: 'durable-alpha',
                                     holder: 'alpha-one', lease_id: lease[:lease_id], fence: lease[:fence] })
    owner.grant.next_request(owner_tick: 2)
    receipt = owner.grant.settle(request_id: 'lost-release', owner_tick: 2, outcome: :unknown,
                                 reason: 'owner_lost', cleanup: :unknown)

    expect(receipt).to include(outcome: 'unknown', cleanup: 'unknown')
    expect(store.authorized?(resource: 'pool', holder: 'alpha-one', fence: lease[:fence])).to be(true)

    now[0] += 6
    reclaimer.client.submit(request_id: 'reclaim', operation: 'reclaim',
                            arguments: { resource: 'pool', participant: 'durable-beta',
                                         holder: 'beta-one', ttl: 10 })
    reclaimed = apply(reclaimer, 1, 'reclaim')[:lease]
    expect(reclaimed[:fence]).to be > lease[:fence]
    expect(store.authorized?(resource: 'pool', holder: 'alpha-one', fence: lease[:fence])).to be(false)
    expect(store.authorized?(resource: 'pool', holder: 'beta-one', fence: reclaimed[:fence])).to be(true)
  end
end
