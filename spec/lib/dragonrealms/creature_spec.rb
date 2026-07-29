# frozen_string_literal: true

require_relative '../../spec_helper'
require 'dragonrealms/creature'

# DragonRealms creature tracking, built on Lich::Common::CreatureBase. These
# examples pin down the DragonRealms-specific behaviour: id-first registration
# from <crtrStatus> (name-less), name/position backfill from the assess stream,
# and the DragonRealms valid_target? rule. The shared registry/roster/query
# contract is covered by spec/lib/common/creature/creature_base_spec.rb.
RSpec.describe Lich::DragonRealms::Creature do
  before do
    described_class.clear
    $creature_debug = nil
  end

  describe '.sync (the automatic <crtrStatus> feed)' do
    it 'registers a creature id-first, with no name, and applies its flags' do
      described_class.sync('99353095', 'hostile' => '1', 'immobile' => '1')

      creature = described_class[99353095]
      expect(creature).not_to be_nil
      expect(creature.name).to be_nil
      expect(creature.crtr_flag?(:hostile)).to be true
      expect(creature.has_status?('immobilized')).to be true
    end

    it 'marks the synced creature present in the room' do
      described_class.sync('99353095', 'hostile' => '1')

      expect(described_class[99353095]).not_to be_nil
      expect(Lich::DragonRealms::CreatureInstance.current_room_ids).to eq([99353095])
    end

    it 'reconciles a later snapshot on the same id as a full snapshot' do
      described_class.sync('99353095', 'hostile' => '1', 'immobile' => '1')
      described_class.sync('99353095', 'hostile' => '1') # immobile dropped

      creature = described_class[99353095]
      expect(creature.has_status?('immobilized')).to be false
      expect(creature.crtr_flag?(:hostile)).to be true
    end

    it 'exposes synced hostiles through .targets even before any name is known' do
      described_class.sync('99353095', 'hostile' => '1')
      described_class.sync('99355263', 'hostile' => '1', 'disengaged' => '1')

      expect(described_class.targets.map(&:id)).to contain_exactly(99353095, 99355263)
    end

    it 'names a creature from the stream-order backfill and derives its noun' do
      described_class.sync('99353095', { 'hostile' => '1' }, 'a jeol moradu')

      creature = described_class[99353095]
      expect(creature.name).to eq('a jeol moradu')
      expect(creature.noun).to eq('moradu')
    end

    it 'backfills the name onto an already id-first-registered instance' do
      described_class.sync('99353095', 'hostile' => '1') # id-first, no name
      expect(described_class[99353095].name).to be_nil

      described_class.sync('99353095', { 'hostile' => '1' }, 'a jeol moradu')
      expect(described_class[99353095].name).to eq('a jeol moradu')
      expect(described_class[99353095].noun).to eq('moradu')
    end

    it 'leaves name and noun nil when no backfill name is supplied' do
      described_class.sync('99353095', 'hostile' => '1')

      expect(described_class[99353095].name).to be_nil
      expect(described_class[99353095].noun).to be_nil
    end

    it 'does not let a stream-order name overwrite an assess-set name' do
      described_class.feed_assess(
        name: 'A jeol moradu', id: '99353095', number: 1,
        relation: 'behind you', range: :melee, self: false, pc: false
      )
      # A later refresh's positional guess must never clobber the authoritative
      # assess name (they normally match; this pins the precedence).
      described_class.sync('99353095', { 'hostile' => '1' }, 'a wrong name')

      expect(described_class[99353095].name).to eq('a jeol moradu')
      expect(described_class[99353095].noun).to eq('moradu')
    end
  end

  describe '.feed_assess (the id-to-name tie-in)' do
    it 'backfills name, assess number, relation and range onto a synced id' do
      described_class.sync('99353095', 'hostile' => '1', 'immobile' => '1')

      described_class.feed_assess(
        name: 'A jeol moradu', id: '99353095', number: 1,
        status: 'cursed and solidly balanced', relation: 'behind you',
        target_id: nil, range: :melee, self: false, pc: false
      )

      creature = described_class[99353095]
      expect(creature.name).to eq('a jeol moradu') # downcased to match DR vocab
      expect(creature.noun).to eq('moradu') # derived from the name
      expect(creature.assess_number).to eq(1)
      expect(creature.relation).to eq('behind you')
      expect(creature.range).to eq(:melee)
      expect(creature.assess_status).to eq('cursed and solidly balanced')
      # parsed breakdown of the parenthetical
      expect(creature.balance).to eq('solidly')
      expect(creature.off_balance?).to be false
      expect(creature.conditions).to eq(['cursed'])
      expect(creature.cursed?).to be true
      expect(creature.condition?('poisoned')).to be false
      expect(creature.enriched?).to be true
      # flags from the earlier crtrStatus are preserved through the backfill
      expect(creature.crtr_flag?(:hostile)).to be true
      expect(creature.has_status?('immobilized')).to be true
    end

    it 'parses balance, target and open-ended conditions from assess' do
      described_class.feed_assess(
        name: 'A jeol moradu', id: '99355263', number: 6,
        status: 'poisoned and off balance', relation: 'facing',
        target: 'Mithandres', target_number: nil, target_id: '-10579963',
        range: :melee, self: false, pc: false
      )

      c = described_class[99355263]
      expect(c.balance).to eq('off')
      expect(c.off_balance?).to be true
      expect(c.conditions).to eq(['poisoned'])
      # generic predicate covers not-yet-confirmed statuses like poisoned
      expect(c.condition?('poisoned')).to be true
      expect(c.cursed?).to be false
      expect(c.target).to eq('Mithandres')
      expect(c.target_id).to eq('-10579963')
    end

    it 'is not enriched (and has empty conditions/nil balance) until an assess arrives' do
      described_class.sync('99353095', 'hostile' => '1')

      c = described_class[99353095]
      expect(c.enriched?).to be false
      expect(c.balance).to be_nil
      expect(c.conditions).to eq([])
      expect(c.off_balance?).to be false
    end

    it 'reports prone from crtrStatus (a push flag), not from assess conditions' do
      # prone/sleeping/stunned/etc. are crtrStatus flags, kept out of #conditions.
      described_class.sync('99353095', 'hostile' => '1', 'prone' => '1')
      described_class.feed_assess(
        name: 'A jeol moradu', id: '99353095', number: 1,
        status: 'cursed and solidly balanced', range: :melee, self: false, pc: false
      )

      c = described_class[99353095]
      expect(c.has_status?('prone')).to be true # from crtrStatus
      expect(c.conditions).to eq(['cursed']) # assess conditions exclude prone
    end

    it 'registers a creature from assess when no crtrStatus has been seen yet' do
      described_class.feed_assess(
        name: 'A jeol moradu', id: '99355263', number: 3,
        status: 'solidly balanced', relation: 'flanking',
        target_id: '-10544759', range: :pole, self: false, pc: false
      )

      creature = described_class[99355263]
      expect(creature).not_to be_nil
      expect(creature.name).to eq('a jeol moradu')
      expect(creature.target_id).to eq('-10544759')
      expect(creature.range).to eq(:pole)
    end

    it 'ignores an entry with no id' do
      expect(described_class.feed_assess(name: 'You', id: nil, self: true, pc: false)).to be_nil
      expect(described_class.all).to be_empty
    end
  end

  describe '#valid_target?' do
    it 'is true for a live creature and false once crtrStatus reports it dead' do
      creature = described_class.sync('99353095', 'hostile' => '1')
      expect(creature.valid_target?).to be true

      described_class.sync('99353095', 'hostile' => '1', 'dead' => '1')
      expect(creature.valid_target?).to be false
    end

    it 'drops dead creatures from .targets but keeps them in .in_room for looting' do
      described_class.sync('99353095', 'hostile' => '1', 'dead' => '1')
      described_class.sync('99353135', 'hostile' => '1')

      expect(described_class.targets.map(&:id)).to eq([99353135])
      expect(described_class.in_room.map(&:id)).to contain_exactly(99353095, 99353135)
    end
  end

  describe '.cleanup_old (positional, per the shared base contract)' do
    # #configure mutates per-class state on CreatureInstance; restore defaults so
    # nothing leaks into another example under random ordering.
    after { described_class.configure }

    it 'accepts a positional age and removes aged creatures' do
      old = described_class.register('an orc', 1)
      old.instance_variable_set(:@created_at, Time.now - 10_800) # 3 hours old
      described_class.register('a kobold', 2)

      # A keyword-only facade would raise ArgumentError against the positional
      # base method; the fix keeps the facade positional.
      removed = nil
      expect { removed = described_class.cleanup_old(600) }.not_to raise_error

      expect(removed).to eq(1)
      expect(described_class[1]).to be_nil
      expect(described_class[2]).not_to be_nil
    end

    it 'defaults to a 600s cutoff when called with no argument' do
      old = described_class.register('an orc', 1)
      old.instance_variable_set(:@created_at, Time.now - 601)
      described_class.register('a kobold', 2)

      expect(described_class.cleanup_old).to eq(1)
    end
  end
end
