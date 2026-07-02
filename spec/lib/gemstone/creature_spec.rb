# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/creature'

RSpec.describe Lich::Gemstone::CreatureTemplate do
  describe 'has_blood? / has_bones? / muggable?' do
    it 'default to nil (unknown) rather than false when uncatalogued' do
      template = described_class.new(name: 'unknown creature')

      expect(template.has_blood?).to be_nil
      expect(template.has_bones?).to be_nil
      expect(template.muggable?).to be_nil
    end

    it 'return the catalogued true/false value without coercion' do
      template = described_class.new(name: 'skeleton', has_blood: false, has_bones: true, muggable: false)

      expect(template.has_blood?).to eq(false)
      expect(template.has_bones?).to eq(true)
      expect(template.muggable?).to eq(false)
    end
  end
end

RSpec.describe Lich::Gemstone::CreatureInstance do
  before { described_class.clear }

  describe '#add_status / #has_status?' do
    it 'normalizes symbol and string statuses to the same stored entry' do
      creature = described_class.register('test creature', 1)

      creature.add_status(:stunned)

      expect(creature.has_status?('stunned')).to be true
      expect(creature.has_status?(:stunned)).to be true
    end
  end

  describe '#muckled?' do
    %w[webbed stunned sleeping immobilized rooted].each do |status|
      it "is true when #{status} is active" do
        creature = described_class.register('test creature', 1)
        creature.add_status(status)

        expect(creature.muckled?).to be true
      end
    end

    it 'is true when dead' do
      creature = described_class.register('test creature', 1)
      creature.sync_crtr_status('dead' => '1')

      expect(creature.muckled?).to be true
    end

    it 'is false for penalty-only or positional statuses (disoriented, prone, calm), unlike the others' do
      creature = described_class.register('test creature', 1)
      creature.add_status(:disoriented)
      creature.add_status(:prone)
      creature.add_status(:calm)

      expect(creature.muckled?).to be false
    end

    it 'is false with no relevant status active' do
      creature = described_class.register('test creature', 1)

      expect(creature.muckled?).to be false
    end
  end

  describe '#flag_active?' do
    it 'matches a status name, a classification flag name, or its negation' do
      creature = described_class.register('test creature', 6)
      creature.sync_crtr_status('hostile' => '1', 'prone' => '1')

      expect(creature.flag_active?(:prone)).to be true
      expect(creature.flag_active?('hostile')).to be true
      expect(creature.flag_active?(:dead)).to be false
      expect(creature.flag_active?(:nonexistent_flag)).to be false
    end
  end

  describe 'room roster (.mark_in_room / .clear_room / .current_room_ids)' do
    it 'marks a creature in the room on registration, including re-registration of an existing one' do
      described_class.register('sea nymph', 607736)
      expect(described_class.current_room_ids).to eq([607736])

      described_class.register('sea nymph', 607736) # already known, e.g. a later room-objs refresh
      expect(described_class.current_room_ids).to eq([607736])
    end

    it 'clear_room empties the roster without touching the persistent registry' do
      described_class.register('sea nymph', 607736)

      described_class.clear_room

      expect(described_class.current_room_ids).to be_empty
      expect(described_class[607736]).not_to be_nil
    end

    it 'clear also resets the room roster' do
      described_class.register('sea nymph', 607736)

      described_class.clear

      expect(described_class.current_room_ids).to be_empty
    end

    context 'debug echo' do
      after { Lich::Gemstone::Creature.debug_on(false) }

      def capture_class_respond
        messages = []
        allow(described_class).to receive(:respond) { |msg| messages << msg }
        messages
      end

      it 'echoes "in room" when an already-known creature reappears after a room-roster clear' do
        Lich::Gemstone::Creature.debug_on(true)
        described_class.register('sea nymph', 607736)
        described_class.clear_room # e.g. a nav/room-objs refresh - instance persists, roster doesn't
        messages = capture_class_respond

        described_class.register('sea nymph', 607736)

        expect(messages).to include('--- sea nymph (607736): in room')
      end

      it 'stays silent on re-registration when nothing changed and debug is off' do
        described_class.register('sea nymph', 607736)
        messages = capture_class_respond

        described_class.register('sea nymph', 607736)

        expect(messages).to be_empty
      end

      it 'echoes a count on clear_room, but only when there was something to clear' do
        Lich::Gemstone::Creature.debug_on(true)
        described_class.register('sea nymph', 607736)
        described_class.register('carrion worm', 607744)
        messages = capture_class_respond

        described_class.clear_room
        expect(messages).to include('--- room: roster cleared (2 creatures)')

        messages.clear
        described_class.clear_room
        expect(messages).to be_empty
      end
    end
  end

  describe '#sync_crtr_status' do
    # Replays the sequence captured from a live GST session (nymph exist=607736):
    # arrival with hostile only, a stun landing, then a lethal hit.
    it 'applies active flags on first sight without setting anything else' do
      creature = described_class.register('sea nymph', 607736)

      creature.sync_crtr_status('hostile' => '1')

      expect(creature.crtr_flag?(:hostile)).to be true
      expect(creature.has_status?('stunned')).to be false
    end

    it 'is a full snapshot: a flag missing from a later tag clears it, not just accumulates' do
      creature = described_class.register('sea nymph', 607736)
      creature.sync_crtr_status('hostile' => '1', 'stunned' => '1')
      expect(creature.has_status?('stunned')).to be true

      creature.sync_crtr_status('hostile' => '1', 'dead' => '1', 'prone' => '1')

      expect(creature.has_status?('stunned')).to be false
      expect(creature.crtr_flag?(:dead)).to be true
      expect(creature.has_status?('prone')).to be true
      expect(creature.crtr_flag?(:hostile)).to be true
    end

    it 'maps XML attribute spellings onto the vocabulary already used by message-based status detection' do
      creature = described_class.register('test creature', 2)

      creature.sync_crtr_status('immobile' => '1', 'calmed' => '1')

      expect(creature.has_status?('immobilized')).to be true
      expect(creature.has_status?('calm')).to be true
    end

    it 'never touches statuses outside its own vocabulary (e.g. bind, set by other means)' do
      creature = described_class.register('test creature', 3)
      creature.add_status(:bind)

      creature.sync_crtr_status('hostile' => '1')

      expect(creature.has_status?('bind')).to be true
    end

    it 'defaults classification flags to false, not nil, until a crtrStatus tag has been seen' do
      creature = described_class.register('test creature', 4)

      expect(creature.crtr_flag?(:mini_boss)).to be false
    end

    it 'reads mixed-case XML attributes (AscensionBoss, MiniBoss) into snake_case flags' do
      creature = described_class.register('test creature', 5)

      creature.sync_crtr_status('AscensionBoss' => '1', 'MiniBoss' => '0')

      expect(creature.crtr_flag?(:ascension_boss)).to be true
      expect(creature.crtr_flag?(:mini_boss)).to be false
    end
  end

  describe 'debug levels (Creature.debug_on)' do
    after { Lich::Gemstone::Creature.debug_on(false) }

    # Stubs respond on this one instance and hands back the array it appends
    # to - simpler than any_instance_of, and scoped to the creature under test.
    def capture_respond(creature)
      messages = []
      allow(creature).to receive(:respond) { |msg| messages << msg }
      messages
    end

    it ':changes (default) logs one transition line per changed flag, headered with name and id' do
      Lich::Gemstone::Creature.debug_on(:changes)
      creature = described_class.register('sea nymph', 607736)
      messages = capture_respond(creature)

      creature.sync_crtr_status('hostile' => '1')

      expect(messages.size).to eq(Lich::Gemstone::CreatureInstance::CRTR_CLASSIFICATION_FLAGS.size)
      expect(messages).to include('--- sea nymph (607736): ~flag: hostile=true')
    end

    it ':changes logs nothing once flags reach steady state' do
      Lich::Gemstone::Creature.debug_on(:changes)
      creature = described_class.register('sea nymph', 607736)
      creature.sync_crtr_status('hostile' => '1')
      messages = capture_respond(creature)

      creature.sync_crtr_status('hostile' => '1')

      expect(messages).to be_empty
    end

    it ':all logs one consolidated snapshot naming every known flag, every call' do
      Lich::Gemstone::Creature.debug_on(:all)
      creature = described_class.register('sea nymph', 607736)
      messages = capture_respond(creature)

      creature.sync_crtr_status('hostile' => '1', 'stunned' => '1')

      snapshot = messages.find { |m| m.include?('crtrStatus:') }
      expect(snapshot).to start_with('--- sea nymph (607736):')
      expect(Lich::Gemstone::CreatureInstance::ALL_CRTR_FLAGS.values.uniq).to all(
        satisfy { |key| snapshot.include?("#{key}=") }
      )
    end

    it ':active filters the snapshot to only currently-true flags' do
      Lich::Gemstone::Creature.debug_on(:active)
      creature = described_class.register('sea nymph', 607736)
      messages = capture_respond(creature)

      creature.sync_crtr_status('hostile' => '1', 'stunned' => '1')

      snapshot = messages.find { |m| m.include?('crtrStatus:') }
      expect(snapshot).to include('hostile=true').and include('stunned=true')
      expect(snapshot).not_to include('dead=false')
    end

    it 'false silences everything' do
      Lich::Gemstone::Creature.debug_on(false)
      creature = described_class.register('sea nymph', 607736)
      messages = capture_respond(creature)

      creature.sync_crtr_status('hostile' => '1')

      expect(messages).to be_empty
    end

    it 'headers plain status/registration echoes the same way, independent of level' do
      Lich::Gemstone::Creature.debug_on(true)
      creature = described_class.register('carrion worm', 607744)
      messages = capture_respond(creature)

      creature.add_status(:webbed)

      expect(messages).to include('--- carrion worm (607744): +status: webbed (no auto-expiry)')
    end
  end

  describe '#valid_target?' do
    it 'is true for an ordinary hostile creature' do
      creature = described_class.register('sea nymph', 1)
      expect(creature.valid_target?).to be true
    end

    it 'is false once crtrStatus reports dead' do
      creature = described_class.register('sea nymph', 1)
      creature.sync_crtr_status('dead' => '1')
      expect(creature.valid_target?).to be false
    end

    it 'is false once HP-based dead? is true, even without a dead crtrStatus flag' do
      creature = described_class.register('sea nymph', 1)
      creature.add_damage(creature.max_hp)
      expect(creature.valid_target?).to be false
    end

    it 'excludes animated decoys but keeps the animated slush exception' do
      expect(described_class.register('animated corpse', 1).valid_target?).to be false
      expect(described_class.register('animated slush', 2).valid_target?).to be true
    end

    it 'excludes appendage/limb sub-targets but keeps the named kraken tentacle exception' do
      expect(described_class.register('generic tentacle', 1, 'tentacle').valid_target?).to be false
      expect(described_class.register('amaranthine kraken tentacle', 2, 'tentacle').valid_target?).to be true
    end
  end
end

RSpec.describe Lich::Gemstone::Creature do
  before do
    Lich::Gemstone::CreatureInstance.clear
    XMLData.current_target_ids = []
  end

  describe '.targets' do
    it 'requires hostile, unlike valid_target? alone - room presence is not enough' do
      hostile = Lich::Gemstone::CreatureInstance.register('sea nymph', 1)
      hostile.sync_crtr_status('hostile' => '1')
      Lich::Gemstone::CreatureInstance.register('field rabbit', 2).sync_crtr_status('hostile' => '0')

      expect(described_class.targets.map(&:id)).to eq([1])
    end

    it 'still excludes dead/decoy/appendage noise even when hostile' do
      dead = Lich::Gemstone::CreatureInstance.register('dead thing', 3)
      dead.sync_crtr_status('hostile' => '1', 'dead' => '1')
      alive = Lich::Gemstone::CreatureInstance.register('sea nymph', 1)
      alive.sync_crtr_status('hostile' => '1')

      expect(described_class.targets.map(&:id)).to eq([1])
    end

    it 'sources room membership from its own roster, not GameObj or current_target_ids alone' do
      registered = Lich::Gemstone::CreatureInstance.register('sea nymph', 1)
      registered.sync_crtr_status('hostile' => '1')

      expect(described_class.targets.map(&:id)).to eq([1])
    end

    it 'ignores current_target_ids entirely - it is a sticky last-selected-target dropdown, not a presence signal' do
      # Confirmed via a live capture: the server only resends dDBTarget when
      # the target *list* changes, not when the current target leaves or
      # dies - it stayed pointed at a departed creature's id through a dozen
      # room changes and a zone change. Anything sourced from it alone (not
      # also in the room roster) must not leak into an "authoritative"
      # in-room list.
      stale = Lich::Gemstone::CreatureInstance.new(9, 'thing', 'departed thing')
      stale.sync_crtr_status('hostile' => '1')
      Lich::Gemstone::CreatureInstance.class_variable_get(:@@instances)[9] = stale
      XMLData.current_target_ids = ['9'] # registered, hostile, but never marked into the room roster

      expect(described_class.targets.map(&:id)).to eq([])
    end

    it 'returns an empty array when nothing hostile is present' do
      expect(described_class.targets).to eq([])
    end

    it 'AND-filters on top of the hostile baseline, including not_ negation' do
      prone = Lich::Gemstone::CreatureInstance.register('carrion worm', 1)
      prone.sync_crtr_status('hostile' => '1', 'prone' => '1')
      standing = Lich::Gemstone::CreatureInstance.register('sea nymph', 2)
      standing.sync_crtr_status('hostile' => '1')

      expect(described_class.targets(:prone).map(&:id)).to eq([1])
      expect(described_class.targets(:not_prone).map(&:id)).to eq([2])
    end

    it 'never returns dead things, even asked for by name - that contradiction is exactly what .in_room is for' do
      dead = Lich::Gemstone::CreatureInstance.register('carrion worm', 1)
      dead.sync_crtr_status('hostile' => '1', 'dead' => '1')

      expect(described_class.targets(:dead)).to eq([])
    end
  end

  describe '.in_room' do
    it 'has no hostile/valid baseline - returns everyone in the room roster' do
      Lich::Gemstone::CreatureInstance.register('sea nymph', 1).sync_crtr_status('hostile' => '1')
      Lich::Gemstone::CreatureInstance.register('field rabbit', 2).sync_crtr_status('hostile' => '0')
      dead = Lich::Gemstone::CreatureInstance.register('carrion worm', 3)
      dead.sync_crtr_status('hostile' => '1', 'dead' => '1')

      expect(described_class.in_room.map(&:id)).to contain_exactly(1, 2, 3)
    end

    it 'finds dead things to loot - the case .targets(:dead) cannot serve' do
      dead = Lich::Gemstone::CreatureInstance.register('carrion worm', 1)
      dead.sync_crtr_status('hostile' => '1', 'dead' => '1')
      Lich::Gemstone::CreatureInstance.register('sea nymph', 2).sync_crtr_status('hostile' => '1')

      expect(described_class.in_room(:dead).map(&:id)).to eq([1])
    end

    it 'also ignores current_target_ids, same as .targets' do
      stale = Lich::Gemstone::CreatureInstance.new(9, 'thing', 'departed thing')
      Lich::Gemstone::CreatureInstance.class_variable_get(:@@instances)[9] = stale
      XMLData.current_target_ids = ['9']

      expect(described_class.in_room.map(&:id)).to eq([])
    end
  end
end
