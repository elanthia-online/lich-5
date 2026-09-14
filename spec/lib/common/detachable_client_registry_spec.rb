# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/detachable_client_registry'

RSpec.describe Lich::Common::DetachableClientRegistry do
  subject(:registry) { described_class.new }

  let(:first) { Object.new }
  let(:second) { Object.new }

  it 'registers clients in primary order without duplicates' do
    expect(registry.register(first)).to be true
    expect(registry.register(second)).to be false
    expect(registry.register(first)).to be false

    expect(registry.snapshot).to eq([first, second])
    expect(registry.primary).to equal(first)
    expect(registry.primary?(first)).to be true
  end

  it 'promotes the next client when the primary unregisters' do
    registry.register(first)
    registry.register(second)

    expect(registry.unregister(first)).to eq([true, false])
    expect(registry.primary).to equal(second)
  end

  it 'reports the transition to empty only for a removed final client' do
    registry.register(first)

    expect(registry.unregister(first)).to eq([true, true])
    expect(registry.unregister(first)).to eq([false, true])
  end

  it 'returns snapshots that cannot mutate the registry' do
    registry.register(first)

    registry.snapshot.clear

    expect(registry.count).to eq(1)
  end

  it 'atomically removes and returns every client' do
    registry.register(first)
    registry.register(second)

    expect(registry.remove_all).to eq([first, second])
    expect(registry).to be_empty
  end

  it 'retains every client registered concurrently' do
    clients = 50.times.map { Object.new }

    clients.map { |client| Thread.new { registry.register(client) } }.each(&:join)

    expect(registry.snapshot).to match_array(clients)
  end
end
