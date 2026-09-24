# frozen_string_literal: true

require_relative 'psm_spec_helper'

RSpec.describe Lich::Gemstone::Shield do
  it_behaves_like 'a PSM technique table', described_class, verb: 'shield'

  include_context 'psm game state'

  let(:shield) { described_class }

  describe 'result messaging' do
    it 'matches shield strike from a real session log' do
      expect(shield.results_regex('strike')).to match(replay_line('shield_strike', /launch a quick bash/))
    end

    {
      'bash'   => [:shield_bash, 'You lunge forward at a kobold with your steel shield and attempt a shield bash!'],
      'pin'    => [:shield_pin, 'You attempt to expose a vulnerability with a diversionary shield bash on a kobold!'],
      'push'   => [:shield_push, 'You raise your steel shield before you and attempt to push a kobold away!'],
      'strike' => [:shield_strike, 'You launch a quick bash with your steel shield at a kobold!'],
      'charge' => [:shield_charge, 'You charge forward at a kobold with your steel shield and attempt a shield charge!']
    }.each do |name, (attack, line)|
      it "matches #{name} (combat: #{attack})" do
        expect(combat_attack(line)).to eq(attack)
        expect(shield.regexp(name)).to match(line)
      end
    end

    it 'tells shield charge and shield trample apart' do
      trample = 'You raise your steel shield before you and charge headlong towards a kobold!'
      expect(shield.regexp('trample')).to match(trample)
      expect(shield.regexp('charge')).not_to match(trample)
    end

    it 'shares its shield bash messaging with the CMan version' do
      line = 'You lunge forward at a kobold with your steel shield and attempt a shield bash!'
      expect(Lich::Gemstone::CMan.regexp('sbash')).to match(line)
      expect(shield.command('bash', orc)).to eq('shield bash #12345')
      expect(Lich::Gemstone::CMan.command('sbash', orc)).to eq('cman sbash #12345')
    end
  end

  describe 'Glorious Momentum' do
    before { ranks('shield.throw' => 1, 'shield.bash' => 1) }

    it 'makes area of effect techniques free' do
      XMLData.stamina = 1
      expect(shield.affordable?('throw')).to be(false)
      effects('Buffs', 'Glorious Momentum')
      expect(shield.affordable?('throw')).to be(true)
      expect(shield.affordable?('trample')).to be(true)
      expect(shield.affordable?('bash')).to be(false)
    end

    it 'does not lift their cooldown, unlike Weapon' do
      effects('Buffs', 'Glorious Momentum')
      effects('Cooldowns', 'Shield Throw')
      expect(shield.available?('throw')).to be(false)
    end
  end

  describe '.use' do
    it 'sends SHIELD <usage> at the target' do
      ranks('shield.bash' => 1)
      sent = game_replies('You lunge forward at an orc with your steel shield and attempt a shield bash!')
      expect(shield.use('Shield Bash', orc)).to start_with('You lunge forward')
      expect(sent).to eq(['shield bash #12345'])
    end
  end
end
