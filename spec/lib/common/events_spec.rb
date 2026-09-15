# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/events'

RSpec.describe Lich::Common::Events do
  # on_change callbacks registered by Combat::Messages (if loaded elsewhere in
  # the run) must survive this spec, so only clear subscriptions, never on_change.
  after { described_class.clear! }

  def as_script(name)
    Script.current = OpenStruct.new(name: name)
  end

  describe '.on / .emit' do
    it 'delivers (topic, payload) to an exact-topic subscriber' do
      seen = []
      described_class.on('go2.status') { |topic, payload| seen << [topic, payload] }
      described_class.emit('go2.status', phase: :moving)
      described_class.emit('go2.other', phase: :moving)
      expect(seen).to eq([['go2.status', { phase: :moving }]])
    end

    it 'accepts symbols and stringifies them' do
      seen = []
      described_class.on(:'go2.status') { |t, _| seen << t }
      described_class.emit(:'go2.status')
      expect(seen).to eq(['go2.status'])
    end

    it "matches a family wildcard 'combat.*' but not the bare family name" do
      seen = []
      described_class.on('combat.*') { |t, _| seen << t }
      described_class.emit('combat.damage')
      described_class.emit('combat')
      described_class.emit('combatant.x')
      expect(seen).to eq(['combat.damage'])
    end

    it "'*' (and an empty topic list) receives everything" do
      star = []
      empty = []
      described_class.on('*') { |t, _| star << t }
      described_class.on { |t, _| empty << t }
      described_class.emit('a.b')
      described_class.emit('c')
      expect(star).to eq(['a.b', 'c'])
      expect(empty).to eq(['a.b', 'c'])
    end

    it 'returns the number of handlers invoked' do
      described_class.on('x') { nil }
      described_class.on('*') { nil }
      expect(described_class.emit('x')).to eq(2)
      expect(described_class.emit('y')).to eq(1)
      expect(described_class.emit('z.z')).to eq(1)
    end

    it 'requires a block' do
      expect { described_class.on('x') }.to raise_error(ArgumentError)
    end

    it 'isolates and logs a raising subscriber without breaking the others' do
      allow(Lich).to receive(:log)
      survivor = []
      described_class.on('x', name: 'bad') { raise 'boom' }
      described_class.on('x', name: 'good') { |_, p| survivor << p }
      expect { described_class.emit('x', 1) }.not_to raise_error
      expect(survivor).to eq([1])
      expect(Lich).to have_received(:log).with(/Events subscriber bad \(x\): boom/)
    end
  end

  describe 'names and .off' do
    it 'named registration is idempotent - re-registering replaces' do
      seen = []
      described_class.on('x', name: 'sup') { seen << :first }
      described_class.on('x', name: 'sup') { seen << :second }
      described_class.emit('x')
      expect(seen).to eq([:second])
      expect(described_class.names).to eq(['sup'])
    end

    it 'generates a distinct name for anonymous subscriptions and returns it' do
      as_script('eohunter')
      a = described_class.on('x') { nil }
      b = described_class.on('x') { nil }
      expect(a).to start_with('eohunter#')
      expect(a).not_to eq(b)
      expect(described_class.names).to contain_exactly(a, b)
    end

    it 'unsubscribes by name or by the registered block' do
      seen = []
      blk = proc { |*a| seen << a }
      described_class.on('x', name: 'n', &blk)
      expect(described_class.off('n')).to be(true)
      described_class.on('x', &blk)
      expect(described_class.off(blk)).to be(true)
      expect(described_class.off('nope')).to be(false)
      described_class.emit('x')
      expect(seen).to be_empty
    end
  end

  describe '.any_for?' do
    it 'reports whether any subscription would receive a topic' do
      expect(described_class.any_for?('combat.damage')).to be(false)
      described_class.on('combat.*') { nil }
      expect(described_class.any_for?('combat.damage')).to be(true)
      expect(described_class.any_for?('go2.status')).to be(false)
    end
  end

  describe 'ownership and script death' do
    it 'records the registering script as owner' do
      as_script('eohunter')
      described_class.on('x', name: 'n') { nil }
      expect(described_class.list).to eq([['n', ['x'], 'eohunter', false]])
    end

    it 'removes persist: false subscriptions when the owner dies (the default)' do
      owner = as_script('crashy')
      described_class.on('x', name: 'scoped') { nil }
      expect(described_class.cleanup_on_death(owner.object_id)).to eq(1)
      expect(described_class.names).to be_empty
    end

    it 'keeps persist: true subscriptions past owner death' do
      owner = as_script('daemon')
      described_class.on('x', name: 'kept', persist: true) { nil }
      expect(described_class.cleanup_on_death(owner.object_id)).to eq(0)
      expect(described_class.names).to eq(['kept'])
    end

    it 'is keyed on object_id, so a same-named sibling script is unaffected' do
      first = as_script('twin')
      described_class.on('x', name: 'a') { nil }
      second = as_script('twin')
      described_class.on('x', name: 'b') { nil }
      described_class.cleanup_on_death(first.object_id)
      expect(described_class.names).to eq(['b'])
      described_class.cleanup_on_death(second.object_id)
      expect(described_class.names).to be_empty
    end

    it 'never removes a subscription registered outside any script' do
      Script.current = nil
      described_class.on('x', name: 'core') { nil }
      expect(described_class.cleanup_on_death(nil)).to eq(0)
      expect(described_class.names).to eq(['core'])
    end

    it 'is wired into ScriptDeath' do
      owner = as_script('dying')
      described_class.on('x', name: 'scoped') { nil }
      Lich::Common::ScriptDeath.run(owner)
      expect(described_class.names).to be_empty
    end
  end

  describe '.clear!' do
    it 'with a prefix removes only that family (and catch-alls)' do
      described_class.on('combat.damage', name: 'c1') { nil }
      described_class.on('combat.*', name: 'c2') { nil }
      described_class.on('go2.status', name: 'g') { nil }
      described_class.on('*', name: 'all') { nil }
      expect(described_class.clear!('combat.')).to eq(3)
      expect(described_class.names).to eq(['g'])
    end
  end

  describe '.on_change' do
    after { described_class.off_change(@cb) if @cb }

    it 'fires on on, off, clear! and owner death' do
      fired = 0
      @cb = described_class.on_change { fired += 1 }
      owner = as_script('s')
      described_class.on('x', name: 'a') { nil }
      described_class.off('a')
      described_class.on('x', name: 'b') { nil }
      described_class.cleanup_on_death(owner.object_id)
      described_class.on('x', name: 'c') { nil }
      described_class.clear!
      expect(fired).to eq(6)
    end

    it 'with a prefix fires only for that family or a catch-all' do
      fired = []
      @cb = described_class.on_change(prefix: 'combat.') { fired << :hit }
      described_class.on('go2.status', name: 'g') { nil }
      expect(fired).to be_empty
      described_class.on('combat.damage', name: 'c') { nil }
      described_class.on('*', name: 'all') { nil }
      expect(fired.length).to eq(2)
    end

    it 'notifies the family a named subscription left when it is re-registered elsewhere' do
      fired = []
      @cb = described_class.on_change(prefix: 'combat.') { fired << described_class.any_for?('combat.bolted') }
      described_class.on('combat.bolted', name: 'supervisor') { nil }
      described_class.on('go2.status', name: 'supervisor') { nil }
      expect(fired).to eq([true, false])
      described_class.off('supervisor')
      expect(described_class.names).to be_empty
    end

    it 'isolates a raising on_change callback' do
      allow(Lich).to receive(:log)
      @cb = described_class.on_change { raise 'boom' }
      expect { described_class.on('x') { nil } }.not_to raise_error
      expect(Lich).to have_received(:log).with(/Events on_change: boom/)
    end
  end

  it 'delivers concurrently registered subscriptions without raising' do
    seen = Queue.new
    threads = 8.times.map do |i|
      Thread.new { 50.times { |j| described_class.on("t.#{i}", name: "#{i}-#{j}") { |t, _| seen << t } } }
    end
    emitter = Thread.new { 200.times { described_class.emit('t.0') } }
    (threads + [emitter]).each(&:join)
    expect(described_class.names.length).to eq(400)
    expect { described_class.emit('t.1') }.not_to raise_error
  end
end
