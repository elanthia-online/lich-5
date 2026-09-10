# frozen_string_literal: true

require_relative '../../../spec_helper'

require 'util/util'
require 'gemstone/psms'

# The spec GameObj keeps its id but does not read it back; production does.
class PsmTargetObj < GameObj
  attr_reader :id
end

# The command and result regex each PSM category's +use+ sends and waits on,
# exposed so a caller can send and confirm on its own terms.
RSpec.describe Lich::Gemstone::PSMS do
  describe '.command' do
    it 'joins verb and usage, and sends a GameObj or id as #id' do
      target = PsmTargetObj.new('12345', 'orc', 'an orc')
      expect(described_class.command('cman', 'bullrush', target)).to eq('cman bullrush #12345')
      expect(described_class.command('cman', 'bullrush', 12_345)).to eq('cman bullrush #12345')
    end

    it 'sends a String target as given and appends FORCERT' do
      expect(described_class.command('shield', 'bash', 'Dissonance', forcert_count: 2)).to eq('shield bash Dissonance forcert')
      expect(described_class.command('shield', 'bash')).to eq('shield bash')
    end

    it 'sends a bare usage with no verb' do
      expect(described_class.command(nil, 'guard', 'Dissonance')).to eq('guard Dissonance')
    end
  end

  describe '.results_regex' do
    let(:regex) { described_class.results_regex('bullrush', /You dip your shoulder/, /^Roundtime: [0-9]+ sec\.$/, results_of_interest: /extra line/) }

    it 'matches the shared failures, the technique refusals, its patterns and the extras' do
      expect(regex).to match('You are still stunned.')
      expect(regex).to match('Bullrush what?')
      expect(regex).to match('bullrush is still in cooldown.')
      expect(regex).to match('You dip your shoulder and rush towards an orc!')
      expect(regex).to match('Roundtime: 5 sec.')
      expect(regex).to match('an extra line here')
      expect(regex).not_to match('You swing a broadsword at an orc!')
    end

    it 'skips nil patterns' do
      expect(described_class.results_regex('holler', nil)).to match('Holler what?')
    end
  end
end

RSpec.describe 'PSM category commands' do
  let(:orc) { PsmTargetObj.new('12345', 'orc', 'an orc') }

  it 'CMan sends CMAN <usage>' do
    expect(Lich::Gemstone::CMan.command('bullrush', orc)).to eq('cman bullrush #12345')
    expect(Lich::Gemstone::CMan.command('bull_rush', orc, forcert_count: 1)).to eq('cman bullrush #12345 forcert')
    expect(Lich::Gemstone::CMan.results_regex('bullrush')).to match('You dip your shoulder and rush towards an orc!')
    expect(Lich::Gemstone::CMan.results_regex('bullrush')).to match('Roundtime: 3 sec.')
  end

  it 'Shield sends SHIELD <usage>' do
    expect(Lich::Gemstone::Shield.command('bash', orc)).to eq('shield bash #12345')
    expect(Lich::Gemstone::Shield.results_regex('bash')).to match('You lunge forward at an orc with your shield and attempt a shield bash!')
  end

  it 'Armor sends ARMOR <usage> and hears the no-armor refusal' do
    expect(Lich::Gemstone::Armor.command('blessing')).to start_with('armor ')
    expect(Lich::Gemstone::Armor.results_regex('blessing')).to match('Dissonance is not wearing any armor that you can work with.')
  end

  it 'Feat sends FEAT <usage>, and GUARD / PROTECT bare' do
    expect(Lich::Gemstone::Feat.command('guard', 'Dissonance')).to eq('guard Dissonance')
    expect(Lich::Gemstone::Feat.command('protect', orc)).to eq('protect #12345')
    expect(Lich::Gemstone::Feat.results_regex('guard')).to match('You are already guarding Dissonance.')
  end

  it 'Warcry sends WARCRY <name>' do
    expect(Lich::Gemstone::Warcry.command('holler', orc)).to eq('warcry holler #12345')
    expect(Lich::Gemstone::Warcry.results_regex('holler')).to match('You throw back your head and let out a thundering holler!')
  end

  it 'Weapon sends WEAPON <usage> and waits on the assault line for assault techniques' do
    expect(Lich::Gemstone::Weapon.command('twinhammer', orc)).to eq('weapon twinhammer #12345')
    expect(Lich::Gemstone::Weapon.results_regex('twinhammer')).to match('Roundtime: 5 sec.')
    expect(Lich::Gemstone::Weapon.command('twinhammer', orc, forcert_count: 1)).to eq('weapon twinhammer #12345 forcert')
    expect(Lich::Gemstone::Weapon.command('barrage', orc, forcert_count: 1)).to eq('weapon barrage #12345')
    assault = Lich::Gemstone::Weapon.results_regex('barrage')
    expect(assault).to match('Your satisfying display of dexterity bolsters you and inspires those around you!')
    expect(assault).not_to match('Roundtime: 5 sec.')
  end
end
