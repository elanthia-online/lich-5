# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/creature'

# Specs for the Gemstone <crtrStatus .../> XML tag parsing that hangs off of
# the existing Lich::Gemstone::Creature module.
#
# CrtrStatus is intentionally flag-agnostic -- it does not enumerate the
# set of possible flag names, because Simu may add new ones at any time.
# Anything on the tag other than metadata (see NON_FLAG_ATTRIBUTES) is
# treated as a boolean flag, active iff its value is exactly "1".
describe Lich::Gemstone::CrtrStatus do
  subject(:status) { described_class.new }

  it 'starts with no flags and no updated_at' do
    expect(status.flags).to eq({})
    expect(status.active_flags).to eq([])
    expect(status.stale?).to eq(true)
    expect(status.updated_at).to be_nil
  end

  it "sets flags whose value is '1'" do
    status.update({ 'exist' => '166660193', 'hostile' => '1', 'inferior' => '1' })
    expect(status.flag?('hostile')).to eq(true)
    expect(status.flag?('inferior')).to eq(true)
    expect(status.flag?('dead')).to eq(false)
    expect(status.active_flags).to match_array(%w[hostile inferior])
    expect(status.updated_at).to be_a(Time)
    expect(status.stale?).to eq(false)
  end

  it 'clears previously-set flags that are omitted on a subsequent update' do
    status.update({ 'exist' => '1', 'hostile' => '1', 'prone' => '1' })
    expect(status.active_flags).to match_array(%w[hostile prone])

    # Sparse follow-up: Simu only enumerates active statuses, so a creature
    # that stood up and stopped being hostile arrives with those flags absent
    # entirely. Both must revert to false.
    status.update({ 'exist' => '1' })
    expect(status.flag?('hostile')).to eq(false)
    expect(status.flag?('prone')).to eq(false)
    expect(status.active_flags).to eq([])
  end

  it 'keeps flags true across updates when they are resent' do
    status.update({ 'exist' => '1', 'hostile' => '1' })
    status.update({ 'exist' => '1', 'hostile' => '1', 'stunned' => '1' })
    expect(status.flag?('hostile')).to eq(true)
    expect(status.flag?('stunned')).to eq(true)
  end

  it 'ignores non-flag metadata attributes like exist' do
    status.update({ 'exist' => '166660193' })
    expect(status.flags).not_to include('exist')
    expect(status.active_flags).to eq([])
  end

  it 'treats an unrecognized non-"1" value as an inactive flag' do
    status.update({ 'hostile' => '0', 'prone' => 'true', 'dead' => '' })
    expect(status.flag?('hostile')).to eq(false)
    expect(status.flag?('prone')).to eq(false)
    expect(status.flag?('dead')).to eq(false)
    expect(status.active_flags).to eq([])
  end

  it 'accepts arbitrary future flag names without any code change' do
    # Simu could add flags we have never heard of; they should just work.
    status.update({ 'brand_new_flag_2027' => '1', 'AnotherWeirdOne' => '1' })
    expect(status.flag?('brand_new_flag_2027')).to eq(true)
    expect(status.flag?('AnotherWeirdOne')).to eq(true)
    expect(status.active_flags).to match_array(%w[brand_new_flag_2027 AnotherWeirdOne])
  end

  describe '#flag? / #is?' do
    before do
      status.update({ 'hostile' => '1', 'AscensionBoss' => '1' })
    end

    it 'accepts String and Symbol equivalently' do
      expect(status.flag?('hostile')).to eq(true)
      expect(status.flag?(:hostile)).to eq(true)
      expect(status.flag?('AscensionBoss')).to eq(true)
      expect(status.flag?(:AscensionBoss)).to eq(true)
    end

    it 'returns false for flags that have never been observed' do
      expect(status.flag?('never_seen')).to eq(false)
      expect(status.flag?(:also_never_seen)).to eq(false)
    end

    it 'is? is a straightforward alias for flag?' do
      expect(status.is?('hostile')).to eq(true)
      expect(status.is?(:hostile)).to eq(true)
      expect(status.is?('AscensionBoss')).to eq(true)
      expect(status.is?(:AscensionBoss)).to eq(true)
      expect(status.is?('prone')).to eq(false)
      expect(status.is?(:prone)).to eq(false)
    end

    it 'is case-sensitive to match the raw XML attribute names' do
      # Simu emits camelCase flag names for some flags; we preserve them as-is
      # and do not fold case.
      expect(status.is?('ascensionboss')).to eq(false)
      expect(status.is?('AscensionBoss')).to eq(true)
    end
  end
end

describe Lich::Gemstone::Creature, 'crtrStatus integration' do
  before(:each) { Lich::Gemstone::Creature.clear }

  describe '.track' do
    it 'creates a CreatureInstance the first time an id is seen' do
      inst = described_class.track('166660193', 'a snarling goblin', 'goblin')
      expect(inst).to be_a(Lich::Gemstone::CreatureInstance)
      expect(inst.id).to eq(166660193)
      expect(inst.name).to eq('a snarling goblin')
      expect(inst.noun).to eq('goblin')
    end

    it 'returns the same instance on subsequent calls for the same id' do
      a = described_class.track(1, 'thing', 'thing')
      b = described_class.track(1)
      expect(a).to be(b)
    end

    it 'backfills name / noun when they were previously nil, without overwriting' do
      described_class.track(1)                          # created with nil name / noun
      described_class.track(1, 'a goblin', 'goblin')    # backfilled
      inst = described_class[1]
      expect(inst.name).to eq('a goblin')
      expect(inst.noun).to eq('goblin')

      described_class.track(1, 'something else', 'else')
      expect(inst.name).to eq('a goblin') # existing non-nil values preserved
      expect(inst.noun).to eq('goblin')
    end

    it 'ignores the auto_register setting (unlike .register)' do
      Lich::Gemstone::CreatureInstance.configure(auto_register: false)
      begin
        expect(described_class.register('x', 42, 'x')).to be_nil
        expect(described_class.track(42, 'x', 'x')).to be_a(Lich::Gemstone::CreatureInstance)
      ensure
        Lich::Gemstone::CreatureInstance.configure(auto_register: true)
      end
    end
  end

  describe 'CreatureInstance#crtr_status' do
    it 'is initialized empty on a fresh instance' do
      inst = described_class.track(1)
      expect(inst.crtr_status).to be_a(Lich::Gemstone::CrtrStatus)
      expect(inst.crtr_status.stale?).to eq(true)
      expect(inst.crtr_status.active_flags).to eq([])
    end

    it 'reads back the flags of a raw <crtrStatus> attributes hash' do
      inst = described_class.track(1)
      inst.crtr_status.update({
        'exist' => '1', 'hostile' => '1', 'prone' => '1', 'inferior' => '1'
      })
      expect(inst.crtr_status.is?('hostile')).to eq(true)
      expect(inst.crtr_status.is?(:prone)).to eq(true)
      expect(inst.crtr_status.is?('inferior')).to eq(true)
    end

    it 'does not interfere with the HP-based CreatureInstance#dead?' do
      inst = described_class.track(1)
      inst.crtr_status.update({ 'exist' => '1', 'dead' => '1' })
      # HP-based dead? on the instance -- damage_taken is 0 so current_hp > 0
      expect(inst.dead?).to eq(false)
      # crtrStatus "dead" flag on the value object -- reflects the XML tag
      expect(inst.crtr_status.is?('dead')).to eq(true)
    end
  end
end
