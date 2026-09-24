# frozen_string_literal: true

require_relative 'psm_spec_helper'

RSpec.describe Lich::Gemstone::Feat do
  # Weighting and Padding are separate feats sent with the one FEAT WPS command.
  it_behaves_like 'a PSM technique table', described_class, verb: 'feat', shared_short_names: ['wps']

  include_context 'psm game state'

  let(:feat) { described_class }

  describe 'result messaging' do
    it 'matches excoriate (combat: smite)' do
      line = 'You level your steel mace at a kobold and call down the excoriating power of Lorminstra to smite it!'
      expect(combat_attack(line)).to eq(:smite)
      expect(feat.regexp('excoriate')).to match(line)
    end

    it 'matches silent strike (combat: silent_strike)' do
      line = 'You quickly leap from hiding to deliver your attack!'
      expect(combat_attack(line)).to eq(:silent_strike)
      expect(feat.results_regex('silentstrike')).to match(line)
    end
  end

  describe '.command' do
    it 'sends GUARD and PROTECT bare, every other feat as FEAT <usage>' do
      expect(feat.command('guard', 'Dissonance')).to eq('guard Dissonance')
      expect(feat.command('protect', orc)).to eq('protect #12345')
      expect(feat.command('Mystic Strike')).to eq('feat mysticstrike')
      expect(feat.command('excoriate', orc)).to eq('feat excoriate #12345')
    end

    it 'has no command for WPS feats, which take their own arguments' do
      expect(feat.command('weighting')).to be_nil
      expect(feat.command('padding')).to be_nil
    end
  end

  describe 'costs' do
    it 'prices excoriate in mana, not stamina' do
      expect(feat.cost('excoriate')).to eq(mana: 10)
      XMLData.stamina = 0
      allow(XMLData).to receive(:mana).and_return(10)
      expect(feat.affordable?('excoriate')).to be(false)
      allow(XMLData).to receive(:mana).and_return(11)
      expect(feat.affordable?('excoriate')).to be(true)
    end
  end

  describe '.use' do
    it 'guards a character by name' do
      ranks('feat.guard' => 1)
      sent = game_replies('You move over to Dissonance and prepare to guard her from attack.')
      expect(feat.use('guard', 'Dissonance')).to eq('You move over to Dissonance and prepare to guard her from attack.')
      expect(sent).to eq(['guard Dissonance'])
    end
  end
end
