# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/creature'
require 'dragonrealms/creature'

# Both games' script-facing Creature module share one facade
# (Lich::Common::CreatureFacade) and keep only their own deltas.
RSpec.describe Lich::Common::CreatureFacade do
  shared = %i[debug_on [] targets in_room clear_room register configure stats clear cleanup_old all]

  it 'gives both games the same shared surface, each over its own registry' do
    { Lich::Gemstone::Creature     => Lich::Gemstone::CreatureInstance,
      Lich::DragonRealms::Creature => Lich::DragonRealms::CreatureInstance }.each do |facade, registry|
      expect(facade.singleton_class.ancestors).to include(described_class)
      expect(facade.send(:instance_class)).to be(registry)
      shared.each { |m| expect(facade).to respond_to(m), "#{facade}.#{m}" }
    end
  end

  # instance_class only tells the facade which registry to use. It stays
  # private so it doesn't become part of the public Creature API.
  it 'keeps instance_class off the public Creature API' do
    [Lich::Gemstone::Creature, Lich::DragonRealms::Creature].each do |facade|
      expect(facade).not_to respond_to(:instance_class)
      expect { facade.instance_class }.to raise_error(NoMethodError, /private method/)
    end
  end

  # GemStone's deltas are overrides of shared methods (register, stats); its
  # damage_report delegators were dropped with the methods they forwarded to.
  it 'keeps each game\'s deltas on that game only' do
    expect(Lich::Gemstone::Creature.method(:register).owner).to be(Lich::Gemstone::Creature.singleton_class)
    expect(Lich::Gemstone::Creature).not_to respond_to(:damage_report, :print_damage_report)
    expect(Lich::Gemstone::Creature).not_to respond_to(:sync, :feed_assess)
    expect(Lich::DragonRealms::Creature).to respond_to(:sync, :feed_assess)
    expect(Lich::DragonRealms::Creature).not_to respond_to(:damage_report)
  end

  it 'keeps the GemStone stats keys, in their original order' do
    expect(Lich::Gemstone::Creature.stats.keys).to eq(%i[instances templates max_size auto_register cleanup_max_age])
    expect(Lich::DragonRealms::Creature.stats.keys).to eq(%i[instances max_size auto_register cleanup_max_age])
  end

  it 'still starts a fresh GemStone instance when a known id arrives under a new name' do
    Lich::Gemstone::Creature.clear
    first = Lich::Gemstone::Creature.register('a kobold', 9001, 'kobold')
    second = Lich::Gemstone::Creature.register('a rat', 9001, 'rat')
    expect(second).not_to be(first)
    expect(Lich::Gemstone::Creature[9001].name).to eq('a rat')
  ensure
    Lich::Gemstone::Creature.clear
  end

  it 'routes the shared calls to each game\'s registry' do
    Lich::DragonRealms::Creature.clear
    Lich::DragonRealms::Creature.sync('4001', { 'hostile' => '1' })
    expect(Lich::DragonRealms::Creature.all.map(&:id)).to eq([4001])
    expect(Lich::DragonRealms::Creature.targets.map(&:id)).to eq([4001])
  ensure
    Lich::DragonRealms::Creature.clear
  end

  # Each shared delegator forwards its arguments and reads its own game's
  # registry, with no state leaking into the other game's registry.
  {
    Lich::Gemstone::Creature     => Lich::DragonRealms::Creature,
    Lich::DragonRealms::Creature => Lich::Gemstone::Creature
  }.each do |facade, other|
    context "on #{facade}" do
      around do |example|
        saved = facade.stats.slice(:max_size, :auto_register, :cleanup_max_age)
        facade.clear
        other.clear
        example.run
      ensure
        facade.configure(**saved)
        facade.clear
        other.clear
      end

      it 'forwards the noun to register' do
        facade.register('a big kobold', 9101, 'beast')
        expect(facade[9101].noun).to eq('beast')
        expect(other[9101]).to be_nil
      end

      it 'reports the configured registry settings in stats' do
        facade.configure(max_size: 7, auto_register: false, cleanup_max_age: 42)
        expect(facade.stats).to include(instances: 0, max_size: 7, auto_register: false, cleanup_max_age: 42)
        expect(other.stats[:max_size]).not_to eq(7)
      end

      it 'forwards an explicit age to cleanup_old' do
        facade.register('a kobold', 9102, 'kobold')
        facade.clear_room
        facade.clear_room # out of the current and previous (sheltered) rosters
        facade[9102].instance_variable_set(:@last_seen_at, Time.now - 100)
        expect(facade.cleanup_old(1_000)).to eq(0)
        expect(facade.cleanup_old(10)).to eq(1)
        expect(facade.all).to be_empty
      end

      it 'lists in_room and clears only its own registry' do
        facade.register('a kobold', 9103, 'kobold')
        other.register('a kobold', 9103, 'kobold')
        expect(facade.in_room.map(&:id)).to eq([9103])
        facade.clear
        expect(facade.all).to be_empty
        expect(other.all.map(&:id)).to eq([9103])
      end
    end
  end
end
