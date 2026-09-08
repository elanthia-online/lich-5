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

# A second, unrelated host class. Proves each including class gets its own
# registry, roster and configuration: GemStone and DragonRealms must never share
# creature state even though they share this code. Kept at file scope for the
# same reason SampleCreature is - a normal constant, not a constant-in-a-block.
class OtherSampleCreature
  include Lich::Common::CreatureBase

  attr_reader :id, :noun, :name, :created_at

  def initialize(id, noun, name)
    @id = id.to_i
    @noun = noun
    @name = name
    @created_at = Time.now
    initialize_status_tracking
  end

  def valid_target?
    !crtr_flag?(:dead)
  end

  def respond(*); end
  def self.respond(*); end
end

RSpec.describe Lich::Common::CreatureBase do
  before do
    SampleCreature.clear
    OtherSampleCreature.clear
    # Reset configuration to defaults. #configure mutates per-class instance vars
    # that would otherwise leak across examples under random ordering; calling it
    # with no arguments restores the documented defaults.
    SampleCreature.configure
    OtherSampleCreature.configure
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

      # Fast-forward past the expiry rather than sleeping. Compute the target
      # time before stubbing so it never reads back through the stub.
      later = Time.now + 6
      allow(Time).to receive(:now).and_return(later)
      expect(creature.has_status?('web')).to be false
    end

    # The crit tables report position as "PRONE"/"KNEELING"/"SITTING";
    # messaging and <crtrStatus> use lowercase. Membership is exact, so an
    # uncanonicalized uppercase add could never be removed or matched.
    it 'canonicalizes case at the boundary, whatever the producer sends' do
      creature = SampleCreature.register('kobold', 1)

      creature.add_status('PRONE')
      expect(creature.has_status?('prone')).to be true
      expect(creature.statuses).to include('prone')

      creature.remove_status('prone')
      expect(creature.has_status?('PRONE')).to be false
    end

    # A 3s roundtime followed by an overlapping 20s one kept the 3s expiry
    # and reported the creature free ~19 seconds early.
    it 'extends a timed status when re-added with a longer duration' do
      creature = SampleCreature.register('kobold', 1)

      creature.add_status('roundtime', 3)
      creature.add_status('roundtime', 20)

      later = Time.now + 10 # past the first expiry, inside the second
      allow(Time).to receive(:now).and_return(later)
      expect(creature.has_status?('roundtime')).to be true
    end

    it 'never shortens a timed status on re-add' do
      creature = SampleCreature.register('kobold', 1)

      creature.add_status('roundtime', 20)
      creature.add_status('roundtime', 3)

      later = Time.now + 10
      allow(Time).to receive(:now).and_return(later)
      expect(creature.has_status?('roundtime')).to be true
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

    # Two writers share @status: this feed, and the combat parser reading
    # messaging. The feed is a full snapshot only of what it reports, so it
    # owns removal for those states - but it never reports blind, poisoned,
    # natures_decay and friends. Reconciling those against it would clear
    # them on the next tag, leaving no way to model them at all.
    it 'never clears message-only statuses the feed does not report' do
      creature = SampleCreature.register('kobold', 1)
      message_only = %w[blind poisoned natures_decay sunburst tangleweed sounds roundtime]
      message_only.each { |s| creature.add_status(s) }
      creature.add_status('stunned') # this one the feed DOES own

      creature.sync_crtr_status('hostile' => '1') # a tag with no statuses set

      expect(creature.statuses).to match_array(message_only)
      expect(creature.has_status?('stunned')).to be false
    end

    it 'owns removal for every status it can report' do
      creature = SampleCreature.register('kobold', 1)
      described = Lich::Common::CreatureBase::CRTR_STATUS_FLAGS
      described.each_value { |status| creature.add_status(status) }

      creature.sync_crtr_status('hostile' => '1')

      expect(creature.statuses).to be_empty
    end
  end

  describe '#flag_active?' do
    it 'matches either a status or a classification flag' do
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

  describe 'unknown filters (F3)' do
    before do
      hostile = SampleCreature.register('kobold', 1)
      hostile.sync_crtr_status('hostile' => '1', 'prone' => '1')
    end

    it 'treats a positive unknown filter as matching nothing' do
      expect(SampleCreature.in_room(:bogus)).to eq([])
      expect(SampleCreature.targets(:bogus)).to eq([])
    end

    it 'treats a negated unknown filter as matching nothing, not everything' do
      # Regression: `:not_prnoe` (a typo of :not_prone) used to invert
      # "unknown matches nothing" into "matches everything", silently widening
      # the query to every candidate in the room.
      expect(SampleCreature.in_room(:not_prnoe)).to eq([])
      expect(SampleCreature.targets(:not_prnoe)).to eq([])
    end

    it 'lets an unknown filter anywhere in an AND chain collapse the whole result' do
      # :prone alone would match the kobold; because filters are ANDed, the
      # unknown filter must still zero the result regardless of position.
      expect(SampleCreature.in_room(:prone, :not_bogus)).to eq([])
      expect(SampleCreature.in_room(:not_bogus, :prone)).to eq([])
    end

    it 'still returns empty for a known filter that no candidate has' do
      # A known-but-absent filter and an unknown filter both yield empty; only
      # the reason differs. This pins the known path so the F3 fix cannot
      # accidentally start rejecting legitimate filters.
      expect(SampleCreature.in_room(:webbed)).to eq([])
    end

    it 'still honours a known negation alongside real matches' do
      standing = SampleCreature.register('goblin', 2)
      standing.sync_crtr_status('hostile' => '1')

      expect(SampleCreature.in_room(:not_prone).map(&:id)).to eq([2])
    end
  end

  describe 'defensive copy of the room roster (F1)' do
    it 'hands back a copy so external mutation cannot corrupt the live roster' do
      SampleCreature.register('kobold', 1)

      snapshot = SampleCreature.current_room_ids
      snapshot << 999
      snapshot.clear

      expect(SampleCreature.current_room_ids).to eq([1])
    end

    it 'returns a fresh array on each call' do
      SampleCreature.register('kobold', 1)

      expect(SampleCreature.current_room_ids).not_to equal(SampleCreature.current_room_ids)
    end

    it 'keeps target/in_room queries intact after a returned copy is mutated' do
      hostile = SampleCreature.register('kobold', 1)
      hostile.sync_crtr_status('hostile' => '1')

      SampleCreature.current_room_ids.clear # must not touch the live roster

      expect(SampleCreature.targets.map(&:id)).to eq([1])
      expect(SampleCreature.in_room.map(&:id)).to eq([1])
    end
  end

  describe 'auto-registration toggle (F2)' do
    it 'creates no instance when auto-registration is disabled' do
      SampleCreature.configure(auto_register: false)

      expect(SampleCreature.register('kobold', 1)).to be_nil
      expect(SampleCreature[1]).to be_nil
      expect(SampleCreature.size).to eq(0)
    end

    it 'still records room presence with auto-registration off' do
      SampleCreature.configure(auto_register: false)

      SampleCreature.register('kobold', 42)

      expect(SampleCreature.current_room_ids).to eq([42])
    end

    it 're-marks an already-known creature into the room while auto-registration is off' do
      known = SampleCreature.register('kobold', 42) # registered while enabled (default)
      SampleCreature.clear_room                     # e.g. a nav / room-objs refresh
      SampleCreature.configure(auto_register: false)

      SampleCreature.register('kobold', 42)         # reappears; no new instance created

      expect(SampleCreature.current_room_ids).to eq([42])
      expect(SampleCreature[42]).to equal(known)    # same instance, not duplicated
      expect(SampleCreature.size).to eq(1)
    end
  end

  describe 'capacity and configuration boundaries' do
    it 'exposes lazy defaults on a freshly-including class before any configure' do
      klass = Class.new { include Lich::Common::CreatureBase }

      expect(klass.max_size).to eq(1000)
      expect(klass.auto_register?).to be true
      expect(klass.size).to eq(0)
      expect(klass.full?).to be false
      expect(klass.current_room_ids).to eq([])
    end

    it 'reports full? exactly at the configured capacity' do
      SampleCreature.configure(max_size: 2)
      expect(SampleCreature.full?).to be false

      SampleCreature.register('a', 1)
      expect(SampleCreature.full?).to be false

      SampleCreature.register('b', 2)
      expect(SampleCreature.full?).to be true
    end

    it 'refuses a newcomer when full and nothing is old enough to evict' do
      SampleCreature.configure(max_size: 2)
      SampleCreature.register('a', 1)
      SampleCreature.register('b', 2)

      overflow = SampleCreature.register('c', 3)

      expect(overflow).to be_nil
      expect(SampleCreature.size).to eq(2)
      expect(SampleCreature[3]).to be_nil
    end

    it 'evicts an aged creature to make room, then registers the newcomer' do
      SampleCreature.configure(max_size: 2)
      old = SampleCreature.register('old', 1)
      old.instance_variable_set(:@created_at, Time.now - 10_800) # 3 hours old
      SampleCreature.register('fresh', 2)
      expect(SampleCreature.full?).to be true

      newcomer = SampleCreature.register('new', 3)

      expect(newcomer).not_to be_nil
      expect(SampleCreature[1]).to be_nil # aged one evicted
      expect(SampleCreature[3]).to equal(newcomer)
      expect(SampleCreature.size).to eq(2)
    end

    it 'defaults cleanup_old to a 600s cutoff when called with no argument' do
      old = SampleCreature.register('old', 1)
      old.instance_variable_set(:@created_at, Time.now - 601)
      SampleCreature.register('fresh', 2)

      expect(SampleCreature.cleanup_old).to eq(1)
      expect(SampleCreature[1]).to be_nil
      expect(SampleCreature[2]).not_to be_nil
    end
  end

  describe 'per-class isolation across including classes' do
    it 'keeps registries independent' do
      SampleCreature.register('kobold', 1)
      OtherSampleCreature.register('spider', 1)
      OtherSampleCreature.register('spider', 2)

      expect(SampleCreature.all.map(&:id)).to eq([1])
      expect(OtherSampleCreature.all.map(&:id)).to contain_exactly(1, 2)
      expect(SampleCreature[2]).to be_nil
    end

    it 'keeps room rosters independent' do
      SampleCreature.register('kobold', 1)
      OtherSampleCreature.register('spider', 9)

      expect(SampleCreature.current_room_ids).to eq([1])
      expect(OtherSampleCreature.current_room_ids).to eq([9])
    end

    it 'keeps configuration independent' do
      SampleCreature.configure(max_size: 5, auto_register: false)

      expect(OtherSampleCreature.max_size).to eq(1000)
      expect(OtherSampleCreature.auto_register?).to be true
    end

    it 'clearing one class leaves the other untouched' do
      SampleCreature.register('kobold', 1)
      OtherSampleCreature.register('spider', 1)

      SampleCreature.clear

      expect(SampleCreature.all).to be_empty
      expect(OtherSampleCreature.all.map(&:id)).to eq([1])
    end
  end
end
