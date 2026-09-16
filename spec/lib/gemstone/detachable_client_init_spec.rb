# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/xml_entities'
require 'gemstone/detachable_client_init'

RSpec.describe Lich::Gemstone::DetachableClientInit do
  let(:vitals) do
    { :mana => 50, :max_mana => 75, :health => 355, :max_health => 355,
      :spirit => 10, :max_spirit => 10, :stamina => 29, :max_stamina => 100 }
  end
  let(:indicators) { { 'IconSTANDING' => 'y', 'IconJOINED' => 'n' } }
  let(:right_hand) { MockGameObj.new(:name => 'Empty') }
  let(:left_hand) { MockGameObj.new(:name => 'Empty') }
  let(:wounds) { {} }
  let(:scars) { {} }

  before do
    vitals.each { |name, value| allow(XMLData).to receive(name).and_return(value) }
    allow(XMLData).to receive_messages(
      :indicator         => indicators,
      :prepared_spell    => 'None',
      :stance_value      => 80,
      :mind_value        => 100,
      :mind_text         => 'must rest',
      :encumbrance_value => 0,
      :encumbrance_text  => 'None',
      :room_exits        => %w[north out]
    )
    allow(Lich::Common::GameObj).to receive(:right_hand).and_return(right_hand)
    allow(Lich::Common::GameObj).to receive(:left_hand).and_return(left_hand)
    areas = described_class::INJURY_AREAS
    stub_const('Lich::Gemstone::Wounds', double('Wounds', areas.to_h { |area| [area.to_sym, wounds.fetch(area, 0)] }))
    stub_const('Lich::Gemstone::Scars', double('Scars', areas.to_h { |area| [area.to_sym, scars.fetch(area, 0)] }))
  end

  subject(:init_string) { described_class.init_string }

  describe '.ready?' do
    it 'is false before the first prompt of the login feed has been parsed' do
      allow(XMLData).to receive(:prompt).and_return('')

      expect(described_class.ready?).to be(false)
    end

    it 'is true once a prompt has been parsed' do
      allow(XMLData).to receive(:prompt).and_return("I>")

      expect(described_class.ready?).to be(true)
    end
  end

  describe 'vitals progress bars' do
    it 'sends a truncated integer percent value alongside current/max text' do
      expect(init_string).to include("<progressBar id='mana' value='66' text='mana 50/75'/>")
      expect(init_string).to include("<progressBar id='health' value='100' text='health 355/355'/>")
      expect(init_string).to include("<progressBar id='spirit' value='100' text='spirit 10/10'/>")
      expect(init_string).to include("<progressBar id='stamina' value='29' text='stamina 29/100'/>")
    end

    context 'with a negative current' do
      let(:vitals) { super().merge(:health => -5) }

      it 'clamps value to 0 while keeping the raw negative text' do
        expect(init_string).to include("<progressBar id='health' value='0' text='health -5/355'/>")
      end
    end

    context 'with a zero max' do
      let(:vitals) { super().merge(:mana => 0, :max_mana => 0) }

      it 'sends value 0 instead of dividing by zero' do
        expect(init_string).to include("<progressBar id='mana' value='0' text='mana 0/0'/>")
      end
    end

    it 'does not send the DragonRealms concentration bar' do
      expect(init_string).not_to include("id='concentration'")
    end
  end

  describe 'GemStone-only bars' do
    it 'sends stance, mind, and encumbrance' do
      expect(init_string).to include("<progressBar id='pbarStance' value='80'/>")
      expect(init_string).to include("<progressBar id='mindState' value='100' text='must rest'/>")
      expect(init_string).to include("<progressBar id='encumlevel' value='0' text='None'/>")
    end
  end

  describe 'spell' do
    it 'sends the prepared spell' do
      expect(init_string).to include('<spell>None</spell>')
    end
  end

  describe 'hands' do
    let(:right_hand) { MockGameObj.new(:name => 'dagger') }

    it 'sends the held item names' do
      expect(init_string).to include('<right>dagger</right><left>Empty</left>')
    end

    context 'when the game has not sent the hands yet' do
      let(:right_hand) { nil }
      let(:left_hand) { nil }

      it 'reports them as Empty instead of failing' do
        expect(init_string).to include('<right>Empty</right><left>Empty</left>')
      end
    end
  end

  describe 'indicators' do
    let(:indicators) { { 'IconSTANDING' => 'y', 'IconHIDDEN' => 'y', 'IconJOINED' => 'n' } }

    it 'sends every indicator, defaulting ones not yet seen to not visible' do
      expect(init_string).to include("<indicator id='IconSTANDING' visible='y'/>")
      expect(init_string).to include("<indicator id='IconHIDDEN' visible='y'/>")
      expect(init_string).to include("<indicator id='IconJOINED' visible='n'/>")
      (described_class::INDICATORS - %w[IconSTANDING IconHIDDEN IconJOINED]).each do |indicator|
        expect(init_string).to include("<indicator id='#{indicator}' visible='n'/>")
      end
      expect(init_string).not_to include("visible=''")
    end
  end

  describe 'injuries' do
    let(:wounds) { { 'neck' => 2 } }
    let(:scars) { { 'neck' => 1, 'leftArm' => 3 } }

    it 'sends a wound over a scar on the same area, and a scar where there is no wound' do
      expect(init_string).to include('<image id="neck" name="Injury2"/>')
      expect(init_string).to include('<image id="leftArm" name="Scar3"/>')
      expect(init_string).not_to include('name="Scar1"')
    end

    it 'sends nothing for an uninjured area' do
      expect(init_string).not_to include('<image id="head"')
    end
  end

  describe 'compass' do
    it 'sends the short form of each room exit' do
      expect(init_string).to end_with("<compass><dir value='n'/><dir value='out'/></compass>")
    end
  end
end
