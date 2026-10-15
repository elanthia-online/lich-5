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
      expect(facade.instance_class).to be(registry)
      shared.each { |m| expect(facade).to respond_to(m), "#{facade}.#{m}" }
    end
  end

  it 'keeps each game\'s deltas on that game only' do
    expect(Lich::Gemstone::Creature).to respond_to(:damage_report, :print_damage_report)
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
end
