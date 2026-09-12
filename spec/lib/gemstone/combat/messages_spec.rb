# frozen_string_literal: true

require 'rspec'

# Fine-grained guards, per spec_helper's convention: module reopening is
# process-global for the rest of the run, so an unguarded definition here
# would win permanently for every other spec that loads later. Nothing in
# this file asserts on the captured messages - Lich.log only needs to
# exist for the worker's rescue to call.
module Lich
  def self.log(msg); (@logged ||= []) << msg; end unless respond_to?(:log)

  def self.logged = @logged ||= []
  module Gemstone; module Combat; end; end
end

require_relative '../../../../lib/gemstone/combat/messages'

# The subscription gate: nothing scans, and no hook exists, until a
# message event has a subscriber; only the subscribed families scan.
RSpec.describe Lich::Gemstone::Combat::Messages do
  let(:observers) { Lich::Gemstone::Combat::Observers }

  after do
    observers.clear!
    described_class.shutdown
  end

  it 'has no active family and no hook with nobody subscribed' do
    expect(described_class.active_families).to eq([])
    expect(described_class.installed?).to be(false)
    expect(described_class.scan('You bolt!')).to eq([])
  end

  it 'activates only the subscribed family, and drops it on unsubscribe' do
    handler = observers.on(:bolted) { nil }
    expect(described_class.active_families.map(&:name)).to eq([:ambush])
    expect(described_class.scan('You bolt!').map(&:first)).to eq([:bolted])
    expect(described_class.scan('You shiver slightly as an invisible rash covers your body.')).to eq([]) # hazard not subscribed
    observers.off(handler)
    expect(described_class.active_families).to eq([])
  end

  it 'a combat subscription activates nothing' do
    observers.on(:damage) { nil }
    expect(described_class.active_families).to eq([])
  end

  it ':any activates every family' do
    observers.on { nil }
    expect(described_class.active_families.size).to eq(described_class.families.size)
  end

  it 'process emits the events with the raw line' do
    seen = []
    observers.on(:ambusher, :bolted) { |type, data| seen << [type, data] }
    described_class.process('You bolt!')
    expect(seen).to eq([[:bolted, { raw: 'You bolt!' }]])
  end

  it 'delivers enqueued lines through the worker' do
    seen = Queue.new
    observers.on(:itchy_curse) { |type, _| seen << type }
    described_class.enqueue('You shiver slightly as an invisible rash covers your body.')
    expect(seen.pop).to eq(:itchy_curse)
    expect(described_class.stats[:matched]).to be >= 1
  end

  it 'knows which types are message events' do
    expect(described_class.event?(:disarm_seen)).to be(true)
    expect(described_class.event?(:damage)).to be(false)
  end

  it 'puts the hook up with the first subscription and takes it down with the last' do
    hooks = {}
    stub_const('DownstreamHook', Class.new do
      define_singleton_method(:add) { |name, action, persist: nil| hooks[name] = [action, persist] }
      define_singleton_method(:remove) { |name| hooks.delete(name) }
    end)
    handler = observers.on(:rooted) { nil }
    expect(described_class.installed?).to be(true)
    expect(hooks.keys).to eq([described_class::HOOK_ID])
    expect(hooks.values.first.last).to be(true)
    expect(hooks.values.first.first.call('a line')).to eq('a line')
    observers.off(handler)
    expect(described_class.installed?).to be(false)
    expect(hooks).to be_empty
  end

  # The stale-uninstall interleaving: a refresh! that computed an empty
  # active set publishes it, is overtaken by a refresh! that subscribes and
  # installs, then runs its own uninstall! afterwards. On the unfixed code
  # that left @active non-empty with the hook gone, so no line ever reached
  # a live subscriber again. Holding @mutex across read-decide-act makes the
  # two serialize. The pause is injected into the mutex the production code
  # uses, so the sequence is forced rather than hoped for.
  it 'never leaves a live subscriber without a hook when refreshes interleave' do
    hooks = {}
    stub_const('DownstreamHook', Class.new do
      define_singleton_method(:add) { |name, action, persist: nil| hooks[name] = [action, persist] }
      define_singleton_method(:remove) { |name| hooks.delete(name) }
    end)

    real_mutex = described_class.instance_variable_get(:@mutex)
    paused = Queue.new
    resume = Queue.new
    arm = { on: false }

    pausing = Object.new
    pausing.define_singleton_method(:synchronize) do |&blk|
      result = real_mutex.synchronize(&blk)
      # Release the lock first, then stall in the gap between publishing
      # @active and acting on it - the window the old code left open.
      if arm[:on]
        arm[:on] = false
        paused << :in_gap
        resume.pop
      end
      result
    end
    described_class.instance_variable_set(:@mutex, pausing)

    begin
      arm[:on] = true
      stale = Thread.new { described_class.refresh! }
      paused.pop # stale has published its empty @active, not yet uninstalled

      observers.on(:rooted) { nil } # subscribes, refreshes, installs

      resume << :go
      stale.join(2)
    ensure
      described_class.instance_variable_set(:@mutex, real_mutex)
    end

    expect(described_class.active_families.map(&:name)).to eq([:hold])
    expect(described_class.installed?).to be(true)
    expect(hooks.keys).to eq([described_class::HOOK_ID])
  end
end
