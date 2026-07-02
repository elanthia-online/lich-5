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
end
