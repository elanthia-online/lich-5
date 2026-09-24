# frozen_string_literal: true

require_relative 'psm_spec_helper'

RSpec.describe Lich::Gemstone::Warcry do
  it_behaves_like 'a PSM technique table', described_class, verb: 'warcry'

  include_context 'psm game state'

  let(:warcry) { described_class }

  before do
    allow(Lich::Gemstone::Status).to receive(:cutthroat?).and_return(false)
    allow(Lich::Gemstone::Status).to receive(:silenced?).and_return(false)
  end

  describe 'result messaging' do
    {
      'holler' => 'You throw back your head and let out a thundering holler!',
      'bellow' => 'You glare at an orc and let out a nerve-shattering bellow!',
      'growl'  => 'Your face contorts as you unleash a guttural, deep-throated growl at an orc!'
    }.each do |name, line|
      it "matches #{name}" do
        expect(warcry.results_regex(name)).to match(line)
      end
    end
  end

  describe '.cost' do
    it 'charges bellow and growl less at a single target than at ALL or the room' do
      { 'bellow' => [20, 10], 'growl' => [14, 7] }.each do |name, (all, single)|
        expect(warcry.cost(name)).to eq(stamina: all)
        expect(warcry.cost(name, target: 'all')).to eq(stamina: all)
        expect(warcry.cost(name, target: 'ALL')).to eq(stamina: all)
        expect(warcry.cost(name, target: orc)).to eq(stamina: single)
        expect(warcry.cost(name, target: 12_345)).to eq(stamina: single)
        expect(warcry.cost(name, target: 'Dissonance')).to eq(stamina: single)
      end
    end

    it 'charges other warcries the same at any target' do
      expect(warcry.cost('holler', target: orc)).to eq(warcry.cost('holler'))
    end
  end

  describe '.available?' do
    before { ranks('warcry.bellow' => 1) }

    it 'checks the cost at the intended target' do
      XMLData.stamina = 15
      expect(warcry.available?('bellow')).to be(false)
      expect(warcry.available?('bellow', target: orc)).to be(true)
    end

    it 'is unavailable while silenced or with a cut throat' do
      expect(warcry.available?('bellow')).to be(true)
      allow(Lich::Gemstone::Status).to receive(:silenced?).and_return(true)
      expect(warcry.available?('bellow')).to be(false)
      allow(Lich::Gemstone::Status).to receive(:silenced?).and_return(false)
      allow(Lich::Gemstone::Status).to receive(:cutthroat?).and_return(true)
      expect(warcry.available?('bellow')).to be(false)
    end
  end

  describe '.buff_active?' do
    it "reads each buffing warcry's buff" do
      { 'yowlp' => "Yertie's Yowlp", 'shout' => 'Empowered (+20)', 'holler' => 'Enh. Health (+20)' }.each do |name, buff|
        effects('Buffs', buff)
        expect(warcry.buff_active?(name)).to be(true), name
      end
      expect(warcry.buff_active?('bellow')).to be(false)
    end
  end

  describe '.use' do
    before { ranks('warcry.shout' => 1, 'warcry.bellow' => 1) }

    it 'sends WARCRY <short name> whatever name it is given' do
      sent = game_replies('You let loose an echoing shout!')
      warcry.use("Seanette's Shout")
      expect(sent).to eq(['warcry shout'])
    end

    it 'does not use a warcry whose buff is already active' do
      effects('Buffs', 'Empowered (+20)')
      sent = game_replies
      expect(warcry.use('shout')).to be_nil
      expect(sent).to be_empty
    end

    it 'bellows at a single target on the single target stamina' do
      XMLData.stamina = 15
      sent = game_replies('You glare at an orc and let out a nerve-shattering bellow!')
      warcry.use('bellow', orc)
      expect(sent).to eq(['warcry bellow #12345'])
    end
  end

  describe '.buffActive? (deprecated)' do
    it 'answers as buff_active?' do
      allow(Lich).to receive(:deprecated)
      effects('Buffs', 'Enh. Health (+20)')
      expect(warcry.buffActive?('holler')).to be(true)
    end
  end
end
