# frozen_string_literal: true

require_relative 'psm_spec_helper'

RSpec.describe Lich::Gemstone::Weapon do
  it_behaves_like 'a PSM technique table', described_class, verb: 'weapon'

  include_context 'psm game state'

  let(:weapon) { described_class }
  let(:assaults) { Lich::Gemstone::Combat::Definitions::Assaults }

  describe 'result messaging from real session logs' do
    it 'matches whirlwind' do
      expect(weapon.results_regex('whirlwind')).to match(replay_line('whirlwind', /reaping whirlwind/))
    end

    it 'matches the pummel opener' do
      expect(weapon.regexp('pummel')).to match(replay_line('weapon_cast', /menacing step/))
    end

    it "hears barrage's ending and its buff line" do
      expect(weapon.results_regex('barrage')).to match(replay_line('barrage', /Upon firing your last arrow/))
      expect(weapon.results_regex('barrage')).to match(replay_line('barrage', /satisfying display of dexterity/))
    end
  end

  describe 'result messaging shared with the combat definitions' do
    {
      'charge'        => [:charge, 'You rush forward at a kobold with your steel spear and attempt a charge!'],
      'cripple'       => [:cripple, 'You reverse your grip on your steel dagger and dart toward a kobold at an angle!'],
      'dizzyingswing' => [:dizzying_swing, "You heft your steel mace and, looping it once to build momentum, lash out in a strike at a kobold's head!"],
      'twinhammer'    => [:twinhammer, 'You raise your hands high, lace them together and bring them crashing down towards a kobold!'],
      'fury'          => [:fury, 'With a percussive snap, you shake out your arms in quick succession and bear down on a kobold in a fury!'],
      'pulverize'     => [:pulverize, 'You wheel your steel maul overhead before slamming it around in a wide arc to pulverize your foes!'],
      'clash'         => [:clash, 'Steeling yourself for a brawl, you plunge into the fray!'],
      'whirlwind'     => [:whirlwind, 'Twisting and spinning among your foes, you lash out again and again with the force of a reaping whirlwind!'],
      'wblade'        => [:wblade, 'With a broad flourish, you weave your steel longsword and steel main gauche into a whirling display of coordination and menace!']
    }.each do |name, (attack, line)|
      it "matches #{name} (combat: #{attack})" do
        expect(combat_attack(line)).to eq(attack)
        expect(weapon.regexp(name)).to match(line)
      end
    end

    it 'matches twin hammerfists on any target, not only one that starts with "the"' do
      expect(weapon.regexp('twinhammer')).to match('You raise your hands high, lace them together and bring them crashing down towards the kobold!')
    end

    it 'matches both whirling blade openers' do
      expect(weapon.regexp('wblade')).to match('With a broad flourish, you sweep your steel longsword into a whirling display of keen-edged menace!')
    end
  end

  describe 'assaults' do
    # PSM short name => combat assault name
    combat_names = {
      'barrage' => :barrage, 'flurry' => :flurry, 'pummel' => :pummel,
      'gthrusts' => :guardant_thrust, 'thrash' => :thrash, 'fury' => nil
    }

    # Opening and closing lines written from combat's assault definitions.
    openers = {
      'flurry'   => ['You rotate your wrist, your steel longsword executing a casual spin to establish your flow as you advance upon a kobold!',
                     'You rotate your wrists, your steel longsword and steel main gauche executing a casual spin to establish your flow as you advance upon a kobold!'],
      'barrage'  => ['Drawing several arrows from your quiver, you grip them loosely between your fingers in preparation for a rapid barrage.'],
      'pummel'   => ['You take a menacing step toward a kobold, sweeping your steel mace out low to your side in your advance.'],
      'gthrusts' => ['Retaining a defensive profile, you raise your steel spear in a hanging guard and prepare to unleash a barrage of guardant thrusts upon a kobold!'],
      'thrash'   => ['You rush a kobold, raising your steel katana high to deliver a sound thrashing!']
    }
    endings = {
      'flurry'   => ['The mesmerizing sway of body and blade glides to its inevitable end with one final twirl of your steel longsword.',
                     'Distracted, you hesitate, and your assault is broken.  You give your blades a quick, sweeping flick of annoyance as you lower them.'],
      'barrage'  => ['Upon firing your last arrow, you release a measured breath and lower your ruic longbow.',
                     'Distracted, you hesitate, and your assault is broken.  Frustrated, you return your remaining arrows.'],
      'pummel'   => ['With a final snap of your wrist, you sweep your steel mace back to the ready, your assault complete.',
                     'Distracted, you hesitate, and in doing so lose the rhythm of your assault.  You return to the ready with a final, frustrated flick of your steel mace.'],
      'gthrusts' => ['You complete your assault, your weight on your rear foot as you snap your steel spear back to a defensive angle.',
                     'Distracted, you hesitate, and in doing so lose the rhythm of your assault.  You shift your grip on your steel spear to a more neutral position and watch for new opportunities.'],
      'thrash'   => ['With a final, explosive breath, you pull your steel katana back to a ready position.',
                     'Distracted, you hesitate, and in doing so lose the rhythm of your assault.  You pull your steel katana back to a ready position with a wary eye to your environs.']
    }

    it 'are exactly the techniques of type :assault' do
      expect(weapon.lookups.map { |l| l[:short_name] }.select { |n| weapon.assault?(n) }).to match_array(combat_names.keys)
    end

    openers.each do |name, lines|
      it "match #{name}'s opening line(s)" do
        lines.each do |line|
          expect(assaults.parse_start(line)&.dig(:name)).to eq(combat_names[name])
          expect(weapon.regexp(name)).to match(line)
        end
      end
    end

    endings.each do |name, lines|
      it "wait on #{name}'s ending, completed or broken" do
        lines.each do |line|
          expect(assaults.parse_end(line)).to eq(combat_names[name])
          expect(weapon.results_regex(name)).to match(line)
        end
      end
    end

    it 'wait on the ending, not the opening line or roundtime' do
      expect(weapon.results_regex('thrash')).not_to match(openers['thrash'].first)
      expect(weapon.results_regex('thrash')).not_to match('Roundtime: 3 sec.')
    end

    it 'stop on the assault-specific refusals' do
      regex = weapon.results_regex('barrage')
      expect(regex).to match('Barrage can not be used with attack as the attack type.')
      expect(regex).to match('Barrage may not be activated within 60 seconds of a Multi-Strike.')
    end

    it 'never take FORCERT' do
      expect(weapon.command('pummel', orc, forcert_count: 2)).to eq('weapon pummel #12345')
    end

    it 'send once and return the ending' do
      ranks('weapon.thrash' => 1)
      sent = game_replies(endings['thrash'].first)
      expect(weapon.use('thrash', orc, forcert_count: 1)).to eq(endings['thrash'].first)
      expect(sent).to eq(['weapon thrash #12345'])
    end

    it 'send again after a roundtime refusal' do
      ranks('weapon.pummel' => 1)
      sent = game_replies('...wait 1 seconds.', endings['pummel'].first)
      expect(weapon.use('pummel', orc)).to eq(endings['pummel'].first)
      expect(sent.size).to eq(2)
    end

    it 'grant their buffs' do
      { 'barrage' => 'Enh. Dexterity (+10)', 'flurry' => 'Slashing Strikes', 'fury' => 'Enh. Constitution (+10)',
        'pummel' => 'Concussive Blows', 'thrash' => 'Forceful Blows' }.each do |name, buff|
        effects('Buffs', buff)
        expect(weapon.buff_active?(name)).to be(true), name
      end
      expect(weapon.buff_active?('gthrusts')).to be(false)
    end
  end

  describe 'Glorious Momentum and Ardor of the Scourge' do
    before { ranks('weapon.cyclone' => 1, 'weapon.cripple' => 1, 'weapon.flurry' => 1) }

    it 'makes area of effect techniques free and lifts their cooldown under Glorious Momentum' do
      XMLData.stamina = 1
      effects('Cooldowns', 'Cyclone')
      expect(weapon.available?('cyclone')).to be(false)
      effects('Buffs', 'Glorious Momentum')
      expect(weapon.affordable?('cyclone')).to be(true)
      expect(weapon.available?('cyclone')).to be(true)
      expect(weapon.affordable?('cripple')).to be(false)
    end

    it "lifts assaults' cooldown under Ardor of the Scourge" do
      effects('Cooldowns', 'Flurry')
      expect(weapon.available?('flurry')).to be(false)
      effects('Buffs', 'Ardor of the Scourge')
      expect(weapon.available?('flurry')).to be(true)
    end

    it 'does not make assaults free under Ardor of the Scourge' do
      XMLData.stamina = 1
      effects('Buffs', 'Ardor of the Scourge')
      expect(weapon.affordable?('flurry')).to be(false)
    end
  end

  describe 'reactions' do
    it 'are free' do
      weapon.lookups.select { |l| weapon.technique(l[:long_name])[:type] == :reaction }.each do |l|
        expect(l[:cost]).to eq(stamina: 0), l[:long_name]
      end
    end
  end

  describe '.command' do
    it 'sends a technique without a usage word by its short name' do
      expect(weapon.command('Pin Down', orc)).to eq('weapon pindown #12345')
      expect(weapon.command('Whirling Blade')).to eq('weapon wblade')
      expect(weapon.command('Cyclone', orc, forcert_count: 1)).to eq('weapon cyclone #12345 forcert')
    end
  end

  describe '.active? (deprecated)' do
    it 'answers as buff_active?' do
      allow(Lich).to receive(:deprecated)
      effects('Buffs', 'Forceful Blows')
      expect(weapon.active?('thrash')).to be(true)
    end
  end
end
