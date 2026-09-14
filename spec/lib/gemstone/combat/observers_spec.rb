# frozen_string_literal: true

require 'rspec'

# Load Observers standalone - it has no Lich dependencies beyond Lich.log
# (provided as a test double) and Lich::Common::Events, which it is a facade
# over since 5.22.
module Lich
  def self.log(msg); (@logged ||= []) << msg; end

  def self.logged = @logged ||= []
  module Gemstone; module Combat; end; end
end

# Stand-in for the script registry Events reads the owner from.
class Script
  class << self
    attr_accessor :current
  end
end unless defined?(Script)

require_relative '../../../../lib/gemstone/combat/observers'

RSpec.describe Lich::Gemstone::Combat::Observers do
  after { described_class.clear! }

  it 'delivers events to type subscribers with (type, data)' do
    seen = []
    described_class.on(:damage) { |type, data| seen << [type, data] }
    described_class.emit(:damage, id: 1, amount: 45)
    described_class.emit(:wound, id: 1, rank: 2)
    expect(seen).to eq([[:damage, { id: 1, amount: 45 }]])
  end

  it 'supports multi-type and :any subscriptions' do
    seen = []
    described_class.on(:damage, :wound) { |type, _| seen << type }
    all = []
    described_class.on { |type, _| all << type }
    described_class.emit(:damage, {})
    described_class.emit(:status, {})
    expect(seen).to eq([:damage])
    expect(all).to eq([:damage, :status])
  end

  it 'unsubscribes via off' do
    seen = []
    handler = described_class.on(:damage) { |*args| seen << args }
    described_class.off(handler)
    described_class.emit(:damage, {})
    expect(seen).to be_empty
  end

  it 'isolates and logs raising subscribers without breaking others' do
    survivor = []
    described_class.on(:damage) { raise 'boom' }
    described_class.on(:damage) { |_, d| survivor << d }
    expect { described_class.emit(:damage, id: 1) }.not_to raise_error
    expect(survivor).to eq([{ id: 1 }])
    expect(Lich.logged.last).to include('Events subscriber').and include('(combat.damage): boom')
  end

  it 'named registration is idempotent - re-registering replaces' do
    seen = []
    described_class.on(:damage, name: 'bar') { seen << :first }
    described_class.on(:damage, name: 'bar') { seen << :second }
    described_class.emit(:damage, {})
    expect(seen).to eq([:second])
  end

  it 'unsubscribes by name' do
    seen = []
    described_class.on(:damage, name: 'bar') { seen << 1 }
    described_class.off('bar')
    described_class.emit(:damage, {})
    expect(seen).to be_empty
  end

  it 'is the combat.* family on the shared Events board' do
    seen = []
    Lich::Common::Events.on('combat.damage') { |topic, data| seen << [topic, data] }
    described_class.emit(:damage, id: 7)
    expect(seen).to eq([['combat.damage', { id: 7 }]])
    expect(Lich::Common::Events.any_for?('combat.damage')).to be(true)
  end

  it 'clear! leaves other topic families alone' do
    other = []
    Lich::Common::Events.on('go2.status', name: 'sup') { |_, d| other << d }
    described_class.on(:damage) { nil }
    described_class.clear!
    Lich::Common::Events.emit('go2.status', :ok)
    expect(other).to eq([:ok])
    Lich::Common::Events.off('sup')
  end

  it 'drops a script-owned subscription when that script dies' do
    script = Struct.new(:name).new('combat_stats')
    Script.current = script
    seen = []
    described_class.on(:damage) { |*a| seen << a }
    Script.current = nil
    Lich::Common::Events.cleanup_on_death(script.object_id)
    described_class.emit(:damage, {})
    expect(seen).to be_empty
    expect(described_class.any_for?(:damage)).to be(false)
  end

  it 'reports whether a type has subscribers' do
    expect(described_class.any_for?(:damage)).to be(false)
    described_class.on(:damage) { nil }
    expect(described_class.any_for?(:damage)).to be(true)
    expect(described_class.any_for?(:wound)).to be(false)
  end
end
