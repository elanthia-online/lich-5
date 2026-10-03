# frozen_string_literal: true

require_relative 'psm_spec_helper'

RSpec.describe Lich::Gemstone::Armor do
  it_behaves_like 'a PSM technique table', described_class, verb: 'armor'

  include_context 'psm game state'

  let(:armor) { described_class }

  describe 'result messaging' do
    it "matches the armor adjustments on the character's own and another's armor" do
      expect(armor.regexp('support')).to match('You adjust your full plate, improving its ability to support the weight of your gear.')
      expect(armor.regexp('reinforcement')).to match("Dissonance adjusts Dissonance's full plate, reinforcing weak spots.")
      expect(armor.regexp('blessing')).to match("As you pray over Dissonance's full plate, you sense that the Arkati's blessing will be granted against magical attacks.")
    end

    it 'hears the no-armor refusal as well as the extra lines asked for' do
      regex = armor.results_regex('blessing', results_of_interest: /an extra line/)
      expect(regex).to match('Dissonance is not wearing any armor that you can work with.')
      expect(regex).to match('an extra line')
    end
  end

  describe 'costs' do
    it 'costs no stamina, but still needs the character to have some' do
      XMLData.stamina = 1
      expect(armor.affordable?('blessing')).to be(true)
      XMLData.stamina = 0
      expect(armor.affordable?('blessing')).to be(false)
    end
  end

  describe '.use' do
    it 'sends ARMOR <usage> at a character' do
      ranks('armor.support' => 1)
      sent = game_replies("You adjust Dissonance's full plate, improving its ability to support the weight of her gear.")
      armor.use('Armor Support', 'Dissonance')
      expect(sent).to eq(['armor support Dissonance'])
    end
  end
end
