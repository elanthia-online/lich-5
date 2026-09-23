# frozen_string_literal: true

require_relative 'psm_spec_helper'

RSpec.describe Lich::Gemstone::CMan do
  it_behaves_like 'a PSM technique table', described_class, verb: 'cman'

  include_context 'psm game state'

  let(:cman) { described_class }

  # Opening lines lifted from real session logs (spec/fixtures/replay).
  describe 'result messaging from real session logs' do
    {
      'coupdegrace' => ['coup_de_grace', /intending to finish/],
      'eviscerate'  => ['eviscerate', /poised to eviscerate/],
      'hamstring'   => ['hamstring', /try to hamstring/],
      'subdue'      => ['subdue', /aim a blow at/],
      'mug'         => ['kick', /boldly accost/]
    }.each do |name, (fixture, pattern)|
      it "matches #{name}'s opening line" do
        expect(cman.results_regex(name)).to match(replay_line(fixture, pattern))
      end
    end
  end

  # Opening lines written from the combat module's log-derived attack
  # definitions; each is checked against combat's parser as well, so the
  # sample cannot drift from what the game actually sends.
  describe 'result messaging shared with the combat definitions' do
    {
      'tackle'      => [:tackle, 'You hurl yourself at a kobold and connect!'],
      'haymaker'    => [:haymaker, 'You clench your right fist and bring your arm back for a roundhouse punch aimed at a kobold!'],
      'headbutt'    => [:headbutt, 'You charge towards a kobold and attempt to headbutt it!'],
      'mug'         => [:mug, 'You boldly accost a kobold, your attack masking your larcenous intent!'],
      'gkick'       => [:groin_kick, "You attempt to deliver a kick to a kobold's groin!"],
      'feint'       => [:feint, 'You feint high.  A kobold buys the ruse'],
      'sweep'       => [:leg_sweep, 'You crouch and sweep a leg at a kobold!'],
      'trip'        => [:trip, 'With a fluid whirl, you plant a steel spear firmly into the ground near a kobold and jerk the weapon sharply sideways.'],
      'sbash'       => [:shield_bash, 'You lunge forward at a kobold with your steel shield and attempt a shield bash!'],
      'eviscerate'  => [:eviscerate, 'You uncoil from the shadows, your steel dagger poised to eviscerate a kobold!'],
      'coupdegrace' => [:coup_de_grace, 'You lunge towards a kobold, intending to finish it off!'],
      'subdue'      => [:subdue, "You spring from hiding and aim a blow at a kobold's head!"],
      'hamstring'   => [:hamstring, 'You lunge forward and try to hamstring a kobold with your steel dagger!'],
      'garrote'     => [:garrote, "You fling your wire garrote around a kobold's neck and snap it taut."],
      'disarm'      => [:disarm_weapon, "Choosing your opening, you attempt to disarm a kobold's scimitar with your broadsword and connect!"]
    }.each do |name, (attack, line)|
      it "matches #{name} (combat: #{attack})" do
        expect(combat_attack(line)).to eq(attack)
        expect(cman.regexp(name)).to match(line)
      end
    end

    it 'matches both cutthroat openers' do
      ["You spring from hiding and attempt to cut a kobold's throat!",
       'You spring from hiding and attempt to grasp a kobold by the chin while slitting its throat with your dagger!'].each do |line|
        expect(combat_attack(line)).to eq(:cutthroat)
        expect(cman.regexp('cutthroat')).to match(line)
      end
      expect(cman.regexp('cutthroat')).to match("You spring from hiding and attempt to slit a kobold's throat with your dagger!")
    end

    it 'matches bull rush on any target, not only one that starts with "an"' do
      expect(cman.regexp('bullrush')).to match('You dip your shoulder and rush towards a kobold!')
      expect(cman.regexp('bullrush')).to match('You dip your shoulder and rush towards an orc!')
    end

    it 'matches garrote with any garrote noun, with or without the success tail' do
      expect(cman.regexp('garrote')).to match("You fling your garrote around a kobold's neck and snap it taut.  Success!")
      expect(cman.regexp('garrote')).to match("You fling your wire around a kobold's neck and snap it taut.")
    end

    it 'matches disarm with a weapon or an empty hand' do
      expect(cman.regexp('disarm')).to match("Choosing your opening, you attempt to disarm a kobold's scimitar with your empty hand!")
      expect(cman.regexp('disarm')).to match('You swing your broadsword at a kobold!')
    end
  end

  describe '.affordable?' do
    it 'needs more stamina than the cost' do
      XMLData.stamina = 14
      expect(cman.affordable?('bullrush')).to be(false)
      XMLData.stamina = 15
      expect(cman.affordable?('bullrush')).to be(true)
    end

    it 'adds the FORCERT surcharge (25% + 10% per FORCERT) and needs the MOC training for it' do
      XMLData.stamina = 100
      expect(cman.affordable?('bullrush', forcert_count: 1)).to be(false) # no MOC ranks
      ranks('skill.multi_opponent_combat' => 10)
      XMLData.stamina = 18 # 14 * 1.35 = 18.9, truncated to 18
      expect(cman.affordable?('bullrush', forcert_count: 1)).to be(false)
      XMLData.stamina = 19
      expect(cman.affordable?('bullrush', forcert_count: 1)).to be(true)
      expect(cman.affordable?('bullrush', forcert_count: 2)).to be(false) # 10 ranks allow one FORCERT
    end

    it 'prices Surge of Strength at 60 while its cooldown is active' do
      XMLData.stamina = 45
      expect(cman.affordable?('surge')).to be(true)
      effects('Cooldowns', 'Surge of Strength')
      expect(cman.affordable?('surge')).to be(false)
    end
  end

  describe '.available?' do
    before { ranks('cman.bullrush' => 2, 'cman.swiftkick' => 1) }

    it 'needs the technique known at the requested rank' do
      expect(cman.available?('bullrush')).to be(true)
      expect(cman.available?('bullrush', min_rank: 3)).to be(false)
      expect(cman.available?('tackle')).to be(false)
    end

    it 'lets swiftkick ignore its cooldown on request' do
      effects('Cooldowns', 'Swiftkick')
      expect(cman.available?('swiftkick')).to be(false)
      expect(cman.available?('swiftkick', ignore_cooldown: true)).to be(true)
    end
  end

  describe '.buff_active?' do
    it 'reads the buff each buffing maneuver grants' do
      {
        'surge'       => 'Enh. Strength (+10)',
        'bearhug'     => 'Enh. Strength (+20)',
        'garrote'     => 'Enh. Agility (+10)',
        'coupdegrace' => 'Empowered (+10)',
        'burst'       => 'Enh. Dexterity (+10)'
      }.each do |name, buff|
        effects('Buffs')
        expect(cman.buff_active?(name)).to be(false), name
        effects('Buffs', buff)
        expect(cman.buff_active?(name)).to be(true), "#{name} with #{buff}"
      end
    end

    it 'is false for a maneuver that grants no buff' do
      effects('Buffs', 'Enh. Strength (+10)')
      expect(cman.buff_active?('tackle')).to be(false)
    end
  end

  describe '.use' do
    before { ranks('cman.bullrush' => 1) }

    it 'waits out roundtime and sends CMAN <usage> at the target' do
      sent = game_replies('You dip your shoulder and rush towards an orc!')
      expect(cman).to receive(:waitrt?)
      expect(cman.use('Bull Rush', orc)).to eq('You dip your shoulder and rush towards an orc!')
      expect(sent).to eq(['cman bullrush #12345'])
    end

    it 'sends FORCERT without waiting out roundtime' do
      ranks('skill.multi_opponent_combat' => 10)
      sent = game_replies('You dip your shoulder and rush towards an orc!')
      expect(cman).not_to receive(:waitrt?)
      cman.use('bullrush', orc, forcert_count: 1)
      expect(sent).to eq(['cman bullrush #12345 forcert'])
    end

    it 'returns false when the game does not answer' do
      sent = game_replies
      expect(cman.use('bullrush', orc)).to be(false)
      expect(sent.size).to eq(1)
    end

    it 'gives up after three roundtime refusals' do
      sent = game_replies('...wait 1 seconds.', '...wait 1 seconds.', '...wait 1 seconds.', 'never sent')
      expect(cman.use('bullrush', orc)).to eq('...wait 1 seconds.')
      expect(sent.size).to eq(3)
    end

    it 'does not send an unknown or unaffordable maneuver' do
      sent = game_replies
      expect(cman.use('tackle', orc)).to be_nil
      XMLData.stamina = 5
      expect(cman.use('bullrush', orc)).to be_nil
      expect(sent).to be_empty
    end
  end

  describe '.coup_ready?' do
    let(:creature) { Lich::Gemstone::CreatureInstance.new(12_345, 'orc', 'orc') }

    before do
      ranks('cman.coupdegrace' => 2)
      allow(creature).to receive(:max_hp).and_return(400)
      allow(Lich::Gemstone::Creature).to receive(:[]).with('12345').and_return(creature)
    end

    it 'is ready at or below rank * 5% of max HP' do
      creature.add_damage(359) # 41 of 400 left, over the 40 (10%) threshold
      expect(cman.coup_ready?(orc)).to be(false)
      creature.add_damage(1)
      expect(cman.coup_ready?(orc)).to be(true)
    end

    it 'doubles the threshold while the target is incapacitated' do
      creature.add_damage(321) # 79 left: over 10%, under 20%
      expect(cman.coup_ready?(orc)).to be(false)
      allow(creature).to receive(:has_status?) { |status| status == 'stunned' }
      expect(cman.coup_ready?(orc)).to be(true)
    end

    it 'takes a creature instance directly' do
      creature.add_damage(400)
      expect(cman.coup_ready?(creature)).to be(true)
    end
  end
end
