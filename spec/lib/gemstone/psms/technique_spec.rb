# frozen_string_literal: true

require_relative '../../../spec_helper'

load_spell_data

require 'util/util'
require 'gemstone/psms'
require 'gemstone/overwatch'
require 'gemstone/infomon'
require 'gemstone/creature'
require 'attributes/skills'

Skills = Lich::Gemstone::Skills unless defined?(Skills)

module Kernel
  def dothistimeout(_action, _timeout, _success_line); end unless method_defined?(:dothistimeout)
end

# The spec GameObj keeps its id but does not read it back; production does.
class PsmTechniqueTarget < GameObj
  attr_reader :id
end

# Shared technique behaviour every PSM category gets from PSMS::Technique.
RSpec.describe Lich::Gemstone::PSMS::Technique do
  let(:cman) { Lich::Gemstone::CMan }
  let(:weapon) { Lich::Gemstone::Weapon }
  let(:warcry) { Lich::Gemstone::Warcry }
  let(:orc) { PsmTechniqueTarget.new('12345', 'orc', 'an orc') }

  def effects(kind, *names)
    XMLData.save_dialogs(kind, names.to_h { |n| [n, Time.now.to_f + 600] })
  end

  def ranks(ranks)
    Lich::Gemstone::Infomon.setup!
    ranks.each { |key, rank| Lich::Gemstone::Infomon.set(key, rank) }
    Lich::Gemstone::Infomon.flush
  end

  before do
    ranks('cman.burst' => 1, 'cman.surge' => 1, 'cman.bullrush' => 1, 'cman.coupdegrace' => 2,
          'weapon.thrash' => 1, 'skill.multi_opponent_combat' => 0)
    XMLData.stamina = 100
    %w[Buffs Debuffs Cooldowns].each { |kind| effects(kind) }
    allow(Script).to receive(:current).and_return(double('Script', name: 'test_script'))
  end

  describe 'cooldowns' do
    it 'finds a cooldown by the long name when asked by the short one' do
      effects('Cooldowns', 'Bull Rush')
      expect(cman.available?('bullrush')).to be(false)
    end

    it 'honors ignore_cooldown for techniques that allow it' do
      effects('Cooldowns', 'Burst of Swiftness')
      expect(cman.available?('burst')).to be(false)
      expect(cman.available?('burst', ignore_cooldown: true)).to be(true)
    end

    it 'does not ignore the cooldown of techniques that do not allow it' do
      effects('Cooldowns', 'Bull Rush')
      expect(cman.available?('bullrush', ignore_cooldown: true)).to be(false)
    end

    it 'is unavailable while overexerted' do
      effects('Debuffs', 'Overexerted')
      expect(cman.available?('bullrush')).to be(false)
    end
  end

  describe '.cost' do
    it 'prices a technique at its cooldown cost while its cooldown is active' do
      expect(cman.cost('burst')).to eq(stamina: 30)
      effects('Cooldowns', 'Burst of Swiftness')
      expect(cman.cost('surge')).to eq(stamina: 30)
      expect(cman.cost('burst')).to eq(stamina: 60)
    end

    it 'prices a warcry at its single target cost when aimed at one target' do
      expect(warcry.cost('bellow')).to eq(stamina: 20)
      expect(warcry.cost('bellow', target: 'all')).to eq(stamina: 20)
      expect(warcry.cost('bellow', target: orc)).to eq(stamina: 10)
      expect(warcry.cost('growl', target: 12_345)).to eq(stamina: 7)
      expect(warcry.cost('holler', target: orc)).to eq(stamina: 20)
    end

    it 'checks affordability against the current cost' do
      XMLData.stamina = 45
      expect(cman.affordable?('burst')).to be(true)
      effects('Cooldowns', 'Burst of Swiftness')
      expect(cman.affordable?('burst')).to be(false)
      expect(Lich::Gemstone::PSMS.assess('burst', 'CMan', true)).to be(false)
    end
  end

  describe '.buff_active?' do
    it 'reads a CMan buff, by name or pattern' do
      expect(cman.buff_active?('burst')).to be(false)
      effects('Buffs', 'Enh. Dexterity (+10)', 'Empowered (+20)')
      expect(cman.buff_active?('burst')).to be(true)
      expect(cman.buff_active?('coup_de_grace')).to be(true)
      expect(cman.buff_active?('bullrush')).to be(false)
    end

    it 'reads the thrash buff' do
      effects('Buffs', 'Forceful Blows')
      expect(weapon.buff_active?('thrash')).to be(true)
    end

    it 'ignores an expired buff' do
      XMLData.save_dialogs('Buffs', { 'Forceful Blows' => Time.now.to_f - 1 })
      expect(weapon.buff_active?('thrash')).to be(false)
    end
  end

  describe 'commands' do
    it 'sends a warcry by its short name whatever name it was asked by' do
      expect(warcry.command("Seanette's Shout")).to eq('warcry shout')
      expect(warcry.command('carns_cry', orc)).to eq('warcry cry #12345')
    end

    it 'treats every assault, including thrash and guardant thrusts, as an assault' do
      %w[barrage flurry fury gthrusts pummel thrash].each { |name| expect(weapon.assault?(name)).to be(true) }
      expect(weapon.command('thrash', orc, forcert_count: 1)).to eq('weapon thrash #12345')
      regex = weapon.results_regex('thrash')
      expect(regex).to match('You complete your assault.')
      expect(regex).to match('Guardant Thrusts may not be activated within 60 seconds of a Multi-Strike.')
      expect(regex).not_to match('Roundtime: 5 sec.')
    end

    it 'hears the roundtime refusal' do
      expect(cman.results_regex('bullrush')).to match('...wait 3 seconds.')
      expect(cman.results_regex('bullrush')).to match('Wait 1 sec.')
    end

    it 'still rejects an unknown technique by name' do
      expect { cman.use('bullrus') }.to raise_error(ArgumentError, /The referenced CMan skill bullrus is invalid/)
    end
  end

  describe '.use' do
    it 'sends again after a roundtime refusal' do
      replies = ['...wait 2 seconds.', 'You dip your shoulder and rush towards an orc!']
      sent = []
      allow(Lich::Gemstone::PSMS).to receive(:dothistimeout) { |cmd, _t, _rx| sent << cmd; replies.shift }
      expect(cman.use('bullrush', orc)).to eq('You dip your shoulder and rush towards an orc!')
      expect(sent).to eq(['cman bullrush #12345'] * 2)
    end

    it 'does not send an unavailable technique' do
      effects('Debuffs', 'Overexerted')
      expect(Lich::Gemstone::PSMS).not_to receive(:dothistimeout)
      expect(cman.use('bullrush', orc)).to be_nil
    end
  end

  describe 'CMan.coup_ready?' do
    it 'asks the tracked creature at the trained rank' do
      creature = double('CreatureInstance')
      allow(Lich::Gemstone::Creature).to receive(:[]).with('12345').and_return(creature)
      expect(creature).to receive(:coup_eligible?).with(2).and_return(true)
      expect(cman.coup_ready?(orc)).to be(true)
    end

    it 'is nil for an untracked target' do
      allow(Lich::Gemstone::Creature).to receive(:[]).and_return(nil)
      expect(cman.coup_ready?(orc)).to be_nil
    end
  end

  describe 'PSMS.mstrike_available?' do
    it 'needs 5 ranks of Multi Opponent Combat open, 30 focused' do
      expect(Lich::Gemstone::PSMS.mstrike_available?).to be(false)
      ranks('skill.multi_opponent_combat' => 10)
      expect(Lich::Gemstone::PSMS.mstrike_available?).to be(true)
      expect(Lich::Gemstone::PSMS.mstrike_available?(focused: true)).to be(false)
      ranks('skill.multi_opponent_combat' => 30)
      expect(Lich::Gemstone::PSMS.mstrike_available?(focused: true)).to be(true)
    end

    it 'is unavailable while overexerted' do
      ranks('skill.multi_opponent_combat' => 30)
      effects('Debuffs', 'Overexerted')
      expect(Lich::Gemstone::PSMS.mstrike_available?).to be(false)
    end
  end
end
