# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'common/creature/creature_base'

# Exercises the game-agnostic Lich::Common::CreatureBase mixin directly, through
# a minimal host class that stands in for a real game's CreatureInstance. The
# host supplies only what the base documents as required: a
# `new(id, noun, name)` constructor, a `created_at` reader, and a
# `valid_target?` predicate. Everything else under test comes from the mixin.
#
# GemStone- and DragonRealms-specific behaviour is covered by their own specs;
# these examples pin down only the shared contract.

# A deliberately tiny stand-in creature. `valid_target?` mirrors the simplest
# real rule (alive), so the shared target queries have something to call. Kept
# at file scope so it is a normal constant, not a constant-in-a-block.
class SampleCreature
  include Lich::Common::CreatureBase

  attr_reader :id, :noun, :name, :created_at

  def initialize(id, noun, name)
    @id = id.to_i
    @noun = noun
    @name = name
    @created_at = Time.now
    initialize_status_tracking
  end

  # Alive == attackable, for the purposes of the shared #targets query.
  def valid_target?
    !crtr_flag?(:dead)
  end

  # No-op debug sink so debug-guarded code paths never raise in isolation.
  def respond(*); end
  def self.respond(*); end
end

RSpec.describe Lich::Common::CreatureBase do
  before do
    SampleCreature.clear
    $creature_debug = nil
  end

  describe 'instance status tracking' do
    it 'stores symbol and string statuses as the same canonical entry' do
      creature = SampleCreature.register('kobold', 1)

      creature.add_status(:stunned)

      expect(creature.has_status?('stunned')).to be true
      expect(creature.has_status?(:stunned)).to be true
    end

    it 'auto-expires a timed status once its duration has elapsed' do
      creature = SampleCreature.register('kobold', 1)

      creature.add_status('web', 5) # 5-second lifetime
      expect(creature.has_status?('web')).to be true

      # Fast-forward past the expiry rather than sleeping.
      allow(Time).to receive(:now).and_return(Time.now + 6)
      expect(creature.has_status?('web')).to be false
    end

    it 'keeps a status with no configured duration until it is removed explicitly' do
      creature = SampleCreature.register('kobold', 1)

      creature.add_status('stunned') # nil duration in STATUS_DURATIONS
      expect(creature.has_status?('stunned')).to be true

      creature.remove_status('stunned')
      expect(creature.has_status?('stunned')).to be false
    end
  end

  describe '#sync_crtr_status' do
    it 'maps XML flag spellings onto the canonical status vocabulary' do
      creature = SampleCreature.register('kobold', 1)

      creature.sync_crtr_status('immobile' => '1', 'calmed' => '1')

      expect(creature.has_status?('immobilized')).to be true
      expect(creature.has_status?('calm')).to be true
    end

    it 'reads classification flags, including mixed-case XML names, as booleans' do
      creature = SampleCreature.register('kobold', 1)

      creature.sync_crtr_status('hostile' => '1', 'AscensionBoss' => '1', 'MiniBoss' => '0')

      expect(creature.crtr_flag?(:hostile)).to be true
      expect(creature.crtr_flag?(:ascension_boss)).to be true
      expect(creature.crtr_flag?(:mini_boss)).to be false
      expect(creature.crtr_flag?(:never_sent)).to be false
    end

    it 'treats each tag as a full snapshot: a flag absent from a later tag clears' do
      creature = SampleCreature.register('kobold', 1)
      creature.sync_crtr_status('hostile' => '1', 'stunned' => '1')
      expect(creature.has_status?('stunned')).to be true

      creature.sync_crtr_status('hostile' => '1', 'dead' => '1')

      expect(creature.has_status?('stunned')).to be false
      expect(creature.crtr_flag?(:dead)).to be true
      expect(creature.crtr_flag?(:hostile)).to be true
    end

    it 'leaves statuses outside its own vocabulary untouched' do
      creature = SampleCreature.register('kobold', 1)
      creature.add_status('bind') # not a crtrStatus-managed status

      creature.sync_crtr_status('hostile' => '1')

      expect(creature.has_status?('bind')).to be true
    end
  end

  describe '#flag_active?' do
    it 'matches a status, a classification flag, or a not_ negation' do
      creature = SampleCreature.register('kobold', 1)
      creature.sync_crtr_status('hostile' => '1', 'prone' => '1')

      expect(creature.flag_active?(:prone)).to be true
      expect(creature.flag_active?('hostile')).to be true
      expect(creature.flag_active?(:dead)).to be false
    end
  end

  describe 'the id-keyed registry' do
    it 'registers a creature under its integer id and looks it back up' do
      registered = SampleCreature.register('kobold', 42, 'kobold')

      expect(SampleCreature[42]).to equal(registered)
      expect(registered.name).to eq('kobold')
      expect(registered.noun).to eq('kobold')
    end

    it 'accepts a nil name so an id-first feed can backfill the name later' do
      registered = SampleCreature.register(nil, 42)
      expect(registered.name).to be_nil

      # A later feed learns the name for the same id.
      registered.instance_variable_set(:@name, 'jeol moradu')
      expect(SampleCreature[42].name).to eq('jeol moradu')
    end

    it 'returns the existing instance instead of duplicating a known id' do
      first = SampleCreature.register('kobold', 42)
      second = SampleCreature.register('kobold', 42)

      expect(second).to equal(first)
      expect(SampleCreature.all.size).to eq(1)
    end

    it 'clears every instance and the room roster on #clear' do
      SampleCreature.register('kobold', 42)

      SampleCreature.clear

      expect(SampleCreature.all).to be_empty
      expect(SampleCreature.current_room_ids).to be_empty
    end

    it 'removes only instances older than the cleanup cutoff' do
      old = SampleCreature.register('old kobold', 1)
      old.instance_variable_set(:@created_at, Time.now - 3600)
      SampleCreature.register('fresh kobold', 2)

      removed = SampleCreature.cleanup_old(600)

      expect(removed).to eq(1)
      expect(SampleCreature[1]).to be_nil
      expect(SampleCreature[2]).not_to be_nil
    end
  end

  describe 'the current-room roster' do
    it 'marks a creature into the room on registration' do
      SampleCreature.register('kobold', 42)
      expect(SampleCreature.current_room_ids).to eq([42])
    end

    it 'clears the roster without evicting the persistent registry' do
      SampleCreature.register('kobold', 42)

      SampleCreature.clear_room

      expect(SampleCreature.current_room_ids).to be_empty
      expect(SampleCreature[42]).not_to be_nil
    end

    it 're-marks a known creature into the roster when it reappears after a clear' do
      SampleCreature.register('kobold', 42)
      SampleCreature.clear_room

      SampleCreature.register('kobold', 42)

      expect(SampleCreature.current_room_ids).to eq([42])
    end
  end

  describe '.targets and .in_room' do
    it 'targets only hostile, valid creatures present in the room' do
      hostile = SampleCreature.register('kobold', 1)
      hostile.sync_crtr_status('hostile' => '1')
      SampleCreature.register('rabbit', 2).sync_crtr_status('hostile' => '0')

      expect(SampleCreature.targets.map(&:id)).to eq([1])
    end

    it 'excludes dead creatures from targets even when they are hostile' do
      dead = SampleCreature.register('kobold', 1)
      dead.sync_crtr_status('hostile' => '1', 'dead' => '1')

      expect(SampleCreature.targets).to eq([])
    end

    it 'AND-filters targets on a named flag, honouring not_ negation' do
      prone = SampleCreature.register('kobold', 1)
      prone.sync_crtr_status('hostile' => '1', 'prone' => '1')
      standing = SampleCreature.register('goblin', 2)
      standing.sync_crtr_status('hostile' => '1')

      expect(SampleCreature.targets(:prone).map(&:id)).to eq([1])
      expect(SampleCreature.targets(:not_prone).map(&:id)).to eq([2])
    end

    it 'in_room returns everyone in the roster, including non-hostile and dead' do
      SampleCreature.register('kobold', 1).sync_crtr_status('hostile' => '1')
      SampleCreature.register('rabbit', 2).sync_crtr_status('hostile' => '0')
      SampleCreature.register('corpse', 3).sync_crtr_status('hostile' => '1', 'dead' => '1')

      expect(SampleCreature.in_room.map(&:id)).to contain_exactly(1, 2, 3)
    end

    it 'in_room can find dead creatures that targets deliberately hides' do
      SampleCreature.register('corpse', 1).sync_crtr_status('hostile' => '1', 'dead' => '1')

      expect(SampleCreature.in_room(:dead).map(&:id)).to eq([1])
    end

    it 'sources room membership from the roster, not the registry alone' do
      registered = SampleCreature.register('kobold', 1)
      registered.sync_crtr_status('hostile' => '1')
      SampleCreature.clear_room # still registered, but no longer present

      expect(SampleCreature.targets).to eq([])
      expect(SampleCreature.in_room).to eq([])
    end
  end
end
