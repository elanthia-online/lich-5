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

    it 'names a creature (via apply_room_name) from the stream-order backfill and derives its noun' do
      creature = described_class.sync('99353095', 'hostile' => '1')
      creature.apply_room_name('a jeol moradu')

      expect(creature.name).to eq('a jeol moradu')
      expect(creature.noun).to eq('moradu')
    end

    it 'applies the room name to an already id-first-registered instance' do
      described_class.sync('99353095', 'hostile' => '1') # id-first, no name
      expect(described_class[99353095].name).to be_nil

      described_class[99353095].apply_room_name('a jeol moradu')
      expect(described_class[99353095].name).to eq('a jeol moradu')
      expect(described_class[99353095].noun).to eq('moradu')
    end

    it 'leaves name and noun nil when no room name is applied' do
      described_class.sync('99353095', 'hostile' => '1')

      expect(described_class[99353095].name).to be_nil
      expect(described_class[99353095].noun).to be_nil
    end

    it 'does not let a stream-order room name overwrite an assess-set name' do
      described_class.feed_assess(
        name: 'A jeol moradu', id: '99353095', number: 1,
        relation: 'behind you', range: :melee, self: false, pc: false
      )
      # A later refresh's positional guess must never clobber the authoritative
      # assess name (they normally match; this pins the precedence).
      described_class[99353095].apply_room_name('a wrong name')

      expect(described_class[99353095].name).to eq('a jeol moradu')
      expect(described_class[99353095].noun).to eq('moradu')
    end

    it 'a nil room name (count-gate skip) leaves an existing name intact' do
      creature = described_class.sync('99353095', 'hostile' => '1')
      creature.apply_room_name('a jeol moradu')
      # count mismatch on a later refresh -> the gate applies no name at all
      creature.apply_room_name(nil)

      expect(creature.name).to eq('a jeol moradu')
      expect(creature.noun).to eq('moradu')
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

    it 'keeps a crtrStatus flag word (immobile) out of assess conditions' do
      # "immobile" appears in the assess parenthetical AND as a crtrStatus flag;
      # it must be tracked via crtr_flag? (fresh), not duplicated into conditions.
      described_class.sync('103723880', 'hostile' => '1', 'immobile' => '1')
      described_class.feed_assess(
        name: 'A jeol moradu', id: '103723880', number: 1,
        status: 'immobile and slightly off balance', relation: 'facing',
        target: 'Holdigor', target_id: '-10592432', range: :melee, self: false, pc: false
      )

      c = described_class[103723880]
      expect(c.balance).to eq('slightly off')
      expect(c.off_balance?).to be true
      expect(c.conditions).to eq([]) # immobile excluded (it is a crtrStatus flag)
      expect(c.has_status?('immobilized')).to be true # tracked via crtrStatus, fresh
    end

    it 'excludes stunned (a crtrStatus flag) and parses a multi-word balance' do
      described_class.sync('103732844', 'hostile' => '1', 'stunned' => '1')
      described_class.feed_assess(
        name: 'A void-black umbral moth', id: '103732844', number: 1,
        status: 'stunned and very badly balanced', relation: 'facing',
        target: 'you', target_id: nil, range: :melee, self: false, pc: false
      )

      c = described_class[103732844]
      expect(c.balance).to eq('very badly') # multi-word DR_BALANCE_VALUES entry
      expect(c.off_balance?).to be true
      expect(c.conditions).to eq([]) # stunned excluded (crtrStatus flag)
      expect(c.has_status?('stunned')).to be true # tracked via crtrStatus, fresh
      expect(c.noun).to eq('moth') # trailing noun of a multi-word name
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

    it 'stores the engaged target name and its assess number when present' do
      described_class.feed_assess(
        name: 'A jeol moradu', id: '99353095', number: 5,
        status: 'solidly balanced', relation: 'facing', target: 'a plague spawn',
        target_number: 2, target_id: '99351111', range: :melee, self: false, pc: false
      )

      c = described_class[99353095]
      expect(c.target).to eq('a plague spawn')
      expect(c.target_number).to eq(2)
      expect(c.target_id).to eq('99351111')
    end
  end

  describe 'assess status parsing (parse_assess_status edge cases)' do
    def assess(id, status)
      described_class.feed_assess(
        name: 'A jeol moradu', id: id, number: 1, status: status,
        relation: 'facing', range: :melee, self: false, pc: false
      )
      described_class[id.to_i]
    end

    it 'parses multiple assess-only afflictions' do
      c = assess('1', 'cursed and poisoned and solidly balanced')
      expect(c.balance).to eq('solidly')
      expect(c.conditions).to eq(%w[cursed poisoned])
      expect(c.cursed?).to be true
      expect(c.condition?('poisoned')).to be true
    end

    it 'drops crtrStatus flag words even when mixed with real afflictions' do
      c = assess('2', 'cursed and stunned and off balance')
      expect(c.balance).to eq('off')
      expect(c.conditions).to eq(['cursed']) # stunned excluded, cursed kept
    end

    it 'handles a status with afflictions but no balance phrase' do
      c = assess('3', 'cursed')
      expect(c.balance).to be_nil
      expect(c.off_balance?).to be false # unknown balance is not "off"
      expect(c.conditions).to eq(['cursed'])
    end

    it 'handles an empty or nil status (still enriched, no balance/conditions)' do
      empty = assess('4', '')
      expect(empty.balance).to be_nil
      expect(empty.conditions).to eq([])
      expect(empty.enriched?).to be true

      nilst = assess('5', nil)
      expect(nilst.balance).to be_nil
      expect(nilst.conditions).to eq([])
      expect(nilst.enriched?).to be true
    end

    it 'maps the balance ladder for off_balance? on both sides of "solidly"' do
      expect(assess('10', 'incredibly balanced').off_balance?).to be false
      expect(assess('11', 'nimbly balanced').off_balance?).to be false
      expect(assess('12', 'solidly balanced').off_balance?).to be false
      expect(assess('13', 'somewhat off balance').off_balance?).to be true # multi-word, below solidly
      expect(assess('14', 'hopelessly balanced').off_balance?).to be true
      expect(assess('13', 'somewhat off balance').balance).to eq('somewhat off')
    end

    it 'parses the "imbalanced" phrasing used by the worst balance levels' do
      # Real log form: the worst levels say "extremely imbalanced", not
      # "...balanced". Must still capture the descriptor (and be off_balance?).
      c = assess('20', 'cursed and extremely imbalanced')
      expect(c.balance).to eq('extremely')
      expect(c.off_balance?).to be true
      expect(c.conditions).to eq(['cursed']) # "extremely imbalanced" is balance, not a condition
    end

    it 'parses "friendly" and an Oxford-comma condition list (real log form)' do
      c = assess('21', 'friendly, cursed, and nimbly balanced')
      expect(c.balance).to eq('nimbly')
      expect(c.conditions).to eq(%w[friendly cursed])
      expect(c.friendly?).to be true # assess friend/foe marker
      expect(c.cursed?).to be true
    end

    it 'drops a crtrStatus flag from an Oxford-comma list, keeping real conditions' do
      # "hidden, cursed, and solidly balanced" -> hidden excluded (crtrStatus),
      # cursed kept; validates comma handling + flag exclusion together.
      c = assess('22', 'hidden, cursed, and solidly balanced')
      expect(c.balance).to eq('solidly')
      expect(c.conditions).to eq(['cursed'])
    end
  end

  describe '#noun (derive_noun) across DragonRealms name shapes' do
    def named(id, assess_name)
      described_class.feed_assess(
        name: assess_name, id: id, number: 1, status: 'solidly balanced',
        relation: 'facing', range: :melee, self: false, pc: false
      )
      described_class[id.to_i]
    end

    it 'takes the trailing noun of a multi-word name' do
      expect(named('1', 'A void-black umbral moth').noun).to eq('moth')
    end

    it 'keeps an apostrophe when it is part of the trailing noun' do
      expect(named('2', "A lesser Adan'f").noun).to eq("adan'f") # downcased
    end

    it 'takes the last word past an apostrophe-bearing adjective' do
      expect(named('3', "An elder Adan'f blademaster").noun).to eq('blademaster')
    end

    it 'is robust to trailing whitespace or punctuation on the name' do
      # end-anchored matching would return nil here; scan+last must not.
      expect(named('4', 'A jeol moradu ').noun).to eq('moradu')
      expect(named('5', 'A jeol moradu.').noun).to eq('moradu')
    end
  end

  describe 'hidden (a crtrStatus flag DR emits but the maps originally omitted)' do
    it 'tracks a hidden creature via has_status? from crtrStatus' do
      described_class.sync('9001', 'hostile' => '1', 'hidden' => '1')

      c = described_class[9001]
      expect(c.has_status?('hidden')).to be true
    end

    it 'clears hidden on a later snapshot that drops it' do
      described_class.sync('9001', 'hostile' => '1', 'hidden' => '1')
      described_class.sync('9001', 'hostile' => '1') # came out of hiding

      expect(described_class[9001].has_status?('hidden')).to be false
    end

    it 'excludes hidden from assess conditions (now a known crtrStatus flag)' do
      described_class.sync('9001', 'hostile' => '1', 'hidden' => '1')
      described_class.feed_assess(
        name: 'A jeol moradu', id: '9001', number: 1,
        status: 'hidden and solidly balanced', relation: 'facing',
        range: :melee, self: false, pc: false
      )

      c = described_class[9001]
      expect(c.conditions).to eq([]) # hidden excluded, tracked via crtrStatus
      expect(c.has_status?('hidden')).to be true
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
