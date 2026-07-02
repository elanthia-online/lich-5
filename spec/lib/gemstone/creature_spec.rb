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
end
