# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/creature'
require 'tmpdir'

RSpec.describe Lich::Gemstone::CreatureTemplate do
  before do
    described_class.class_variable_set(:@@templates, {})
    described_class.class_variable_set(:@@loaded, false)
  end

  describe '.load_all' do
    around do |example|
      Dir.mktmpdir do |dir|
        @dir = dir
        example.run
      end
    end

    def write_template(filename, content)
      File.write(File.join(@dir, filename), content)
    end

    it 'loads every non-template .rb file in the directory' do
      write_template('alpha_wolf.rb', '{ name: "alpha wolf", level: 5 }')
      write_template('beta_wolf.rb', '{ name: "beta wolf", level: 6 }')

      described_class.load_all(@dir)

      expect(described_class.all.map(&:name)).to contain_exactly('alpha wolf', 'beta wolf')
    end

    it 'skips _creature_template.rb itself' do
      write_template('_creature_template.rb', '{ name: "should not load" }')

      described_class.load_all(@dir)

      expect(described_class.all).to be_empty
    end

    it "prefers the file's own :name over the filename-derived one, preserving characters a slug can't" do
      # Regression: load_all used to overwrite :name (and the lookup key)
      # from the filename unconditionally, so a real name with a hyphen
      # ("shield-maiden") silently became "shield maiden" after a
      # filename round-trip, breaking exact-name lookup at runtime.
      write_template('shield_maiden.rb', '{ name: "shield-maiden", level: 10 }')

      described_class.load_all(@dir)

      template = described_class['shield-maiden']
      expect(template).not_to be_nil
      expect(template.name).to eq('shield-maiden')
    end

    it "falls back to the filename-derived name when the file doesn't set one" do
      write_template('grey_wolf.rb', '{ level: 5 }')

      described_class.load_all(@dir)

      template = described_class['grey wolf']
      expect(template).not_to be_nil
      expect(template.name).to eq('grey wolf')
    end

    it 'does not raise on a file with malformed Ruby, and skips it' do
      write_template('broken.rb', '{ this is not : valid ruby ][')

      expect { described_class.load_all(@dir) }.not_to raise_error
      expect(described_class.all).to be_empty
    end

    it 'skips a file that evals to something other than a Hash' do
      write_template('not_a_hash.rb', '"just a string"')

      described_class.load_all(@dir)

      expect(described_class.all).to be_empty
    end

    it 'lets a later colliding name silently overwrite an earlier one (documents current behavior)' do
      # Reproduces the real spectre/shadowy_spectre collision without
      # depending on real repo data: BOON_ADJECTIVES strips "shadowy " from
      # the name, so both files normalize to the same lookup key, and only
      # one survives - whichever Dir[] happens to enumerate last.
      write_template('spectre.rb', '{ name: "spectre", level: 50 }')
      write_template('shadowy_spectre.rb', '{ name: "shadowy spectre", level: 80 }')

      described_class.load_all(@dir)

      expect(described_class.all.size).to eq(1)
      expect(described_class['spectre']).not_to be_nil
    end

    it 'logs a debug warning when a collision happens, naming both the key and the file' do
      write_template('spectre.rb', '{ name: "spectre", level: 50 }')
      write_template('shadowy_spectre.rb', '{ name: "shadowy spectre", level: 80 }')
      messages = []
      allow(described_class).to receive(:respond) { |msg| messages << msg }
      $creature_debug = true

      begin
        described_class.load_all(@dir)
      ensure
        $creature_debug = false
      end

      expect(messages.any? { |m| m.include?('collides') && m.include?('spectre') }).to be true
    end
  end
end

RSpec.describe Lich::Gemstone::CreatureTemplate do
  describe 'rooms / rooms_by_area / boundary_rooms' do
    # A five-room map: the creature is found in 1 <-> 2 <-> 3 (uids
    # 101..103), room 4 borders room 3 bidirectionally, room 5 has only a
    # one-way edge INTO room 1. Room ids are uid - 100.
    let(:fake_map) do
      rooms = {
        1 => double('room', id: 1, wayto: { '2' => 'e' }),
        2 => double('room', id: 2, wayto: { '1' => 'w', '3' => 'e' }),
        3 => double('room', id: 3, wayto: { '2' => 'w', '4' => 'out' }),
        4 => double('room', id: 4, wayto: { '3' => 'in' }),
        5 => double('room', id: 5, wayto: { '1' => 'go gate' })
      }
      # plain double: lib/common/map isn't loaded in the spec env, and the
      # accessors resolve the constant lazily at call time anyway
      map = double('Map')
      allow(map).to receive(:ids_from_uid) { |u| rooms.key?(u - 100) ? [u - 100] : [] }
      allow(map).to receive(:[]) { |id| rooms[id] }
      allow(map).to receive(:list).and_return(rooms.values)
      map
    end

    let(:template) do
      described_class.new(name: 'gap wolf',
                          areas: [{ name: 'Strip', uids: [101..101, 103..103] },
                                  { name: 'Middle', uids: [102..102] },
                                  { name: 'Unmapped', uids: [900..900] }])
    end

    before { stub_const('Lich::Common::Map', fake_map) }

    it 'combines all ranges into one sorted room list, dropping uids the mapdb does not know' do
      expect(template.rooms).to eq([1, 2, 3])
    end

    it 'keys converted room ids by area name' do
      expect(template.rooms_by_area).to eq('Strip' => [1, 3], 'Middle' => [2], 'Unmapped' => [])
    end

    it "returns bordering rooms from edges in either direction, excluding the creature's own rooms" do
      expect(template.boundary_rooms).to eq([4, 5])
    end
  end

  describe 'messaging attack lines' do
    let(:messaging) do
      Lich::Gemstone::Messaging.new(
        bite: 'A wolf tries to bite you!',
        claw: ['A wolf claws at you!', 'A wolf rakes {pronoun} claws at you!'],
        attack: 'A shan ranger swings {weapon} at you!'
      )
    end

    it 'matches a literal message' do
      expect(messaging.match(:bite, 'A wolf tries to bite you!')).to eq({})
    end

    it 'matches any variant when the field holds several' do
      expect(messaging.match(:claw, 'A wolf claws at you!')).to eq({})
    end

    it 'captures a placeholder from a templated variant' do
      expect(messaging.match(:claw, 'A wolf rakes its claws at you!')).to eq(pronoun: 'its')
    end

    it 'matches a {weapon} placeholder against any weapon name' do
      expect(messaging.match(:attack, 'A shan ranger swings a diamond-hilted longsword at you!'))
        .not_to be_nil
    end

    it 'returns nil when nothing matches' do
      expect(messaging.match(:bite, 'A wolf yawns.')).to be_nil
    end

    it 'renders every variant through display' do
      expect(messaging.display(:claw)).to include('A wolf claws at you!')
    end
  end

  describe 'has_blood? / has_bones? / muggable?' do
    it 'default to nil (unknown) rather than false when uncatalogued' do
      template = described_class.new(name: 'unknown creature')

      expect(template.has_blood?).to be_nil
      expect(template.has_bones?).to be_nil
      expect(template.muggable?).to be_nil
    end

    it 'return the catalogued true/false value without coercion' do
      template = described_class.new(name: 'skeleton', blood: false, bones: true, muggable: false)

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
      stale = Lich::Gemstone::CreatureInstance.register('departed thing', 9)
      stale.sync_crtr_status('hostile' => '1')
      # Registered and hostile, but no longer in the room roster (e.g. it left
      # or died and the room refreshed) - only the sticky dropdown still names it.
      Lich::Gemstone::CreatureInstance.clear_room
      XMLData.current_target_ids = ['9']

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
      Lich::Gemstone::CreatureInstance.register('departed thing', 9)
      Lich::Gemstone::CreatureInstance.clear_room # registered, but not in the room roster
      XMLData.current_target_ids = ['9']

      expect(described_class.in_room.map(&:id)).to eq([])
    end
  end
end

RSpec.describe Lich::Gemstone::CreatureInstance, 'roster defensive copy (F1)' do
  before { described_class.clear }

  it 'returns a copy of current_room_ids so callers cannot corrupt the live roster' do
    hostile = described_class.register('sea nymph', 1)
    hostile.sync_crtr_status('hostile' => '1')

    described_class.current_room_ids << 999 # a stray external append
    described_class.current_room_ids.clear  # and an external clear

    expect(described_class.current_room_ids).to eq([1])
    expect(Lich::Gemstone::Creature.targets.map(&:id)).to eq([1])
  end

  it 'returns a fresh array on each call' do
    described_class.register('sea nymph', 1)

    expect(described_class.current_room_ids).not_to equal(described_class.current_room_ids)
  end
end

RSpec.describe Lich::Gemstone::Creature, 'facade delegation and cleanup_old (F4)' do
  let(:instance_class) { Lich::Gemstone::CreatureInstance }

  before do
    instance_class.clear
    instance_class.configure # reset to documented defaults
  end

  # #configure mutates per-class state on CreatureInstance; restore defaults so a
  # disabled-auto_register or shrunken max_size never leaks into another example.
  after { instance_class.configure }

  describe '.cleanup_old' do
    it 'accepts a positional age - the exact form Combat::Tracker#cleanup_creatures passes' do
      old = described_class.register('old thing', 1)
      old.created_at = Time.now - 10_800 # 3 hours old
      described_class.register('fresh thing', 2)

      # Mirrors tracker.rb: `removed = Creature.cleanup_old(max_age)`. Before the
      # F4 fix the keyword-only facade raised ArgumentError here, which the
      # tracker's rescue swallowed - so registry cleanup silently never ran.
      removed = nil
      expect { removed = described_class.cleanup_old(600) }.not_to raise_error

      expect(removed).to eq(1)
      expect(described_class[1]).to be_nil
      expect(described_class[2]).not_to be_nil
    end

    it 'defaults to a 600s cutoff when called with no argument' do
      old = described_class.register('old thing', 1)
      old.created_at = Time.now - 601
      described_class.register('fresh thing', 2)

      expect(described_class.cleanup_old).to eq(1)
    end

    it 'removes nothing when everything is newer than the cutoff' do
      described_class.register('fresh thing', 1)

      expect(described_class.cleanup_old(600)).to eq(0)
      expect(described_class[1]).not_to be_nil
    end
  end

  describe 'delegation to CreatureInstance' do
    it 'registers through the facade into the shared registry' do
      registered = described_class.register('sea nymph', 42, 'nymph')

      expect(instance_class[42]).to equal(registered)
      expect(described_class[42]).to equal(registered)
    end

    it 'clears every instance and the roster via .clear' do
      described_class.register('sea nymph', 1)

      described_class.clear

      expect(instance_class.all).to be_empty
      expect(described_class.in_room).to be_empty
    end

    it 'clears only the roster via .clear_room, keeping the registry' do
      described_class.register('sea nymph', 1)

      described_class.clear_room

      expect(instance_class[1]).not_to be_nil
      expect(described_class.in_room).to be_empty
    end

    it 'forwards configure(**options) to the shared registry' do
      described_class.configure(max_size: 3, auto_register: false)

      expect(instance_class.max_size).to eq(3)
      expect(instance_class.auto_register?).to be false
    end

    it 'reports registry stats sourced from the shared registry' do
      described_class.register('sea nymph', 1)

      stats = described_class.stats

      expect(stats[:instances]).to eq(1)
      expect(stats[:max_size]).to eq(1000)
      expect(stats[:auto_register]).to be true
      expect(stats).to have_key(:templates)
    end
  end
end
