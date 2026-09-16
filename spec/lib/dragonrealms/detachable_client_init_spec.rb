# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/xml_entities'
require 'dragonrealms/detachable_client_init'

RSpec.describe Lich::DragonRealms::DetachableClientInit do
  # DragonRealms sends a bare percent in text ("health 100%"), which the parser
  # stores in the current field with a nil max.
  let(:vitals) do
    { :health => 100, :max_health => nil, :mana => 87, :max_mana => nil,
      :stamina => 42, :max_stamina => nil, :spirit => 100, :max_spirit => nil,
      :concentration => 95, :max_concentration => nil }
  end
  let(:indicators) { { 'IconSTANDING' => 'y', 'IconJOINED' => 'n' } }
  let(:right_hand) { MockGameObj.new(:name => 'Empty') }
  let(:left_hand) { MockGameObj.new(:name => 'Empty') }

  before do
    vitals.each { |name, value| allow(XMLData).to receive(name).and_return(value) }
    allow(XMLData).to receive_messages(
      :indicator      => indicators,
      :prepared_spell => 'None',
      :room_exits     => %w[north south]
    )
    allow(Lich::Common::GameObj).to receive(:right_hand).and_return(right_hand)
    allow(Lich::Common::GameObj).to receive(:left_hand).and_return(left_hand)
  end

  subject(:init_string) { described_class.init_string }

  describe '.ready?' do
    it 'is false before the first prompt of the login feed has been parsed' do
      allow(XMLData).to receive(:prompt).and_return('')

      expect(described_class.ready?).to be(false)
    end

    it 'is true once a prompt has been parsed' do
      allow(XMLData).to receive(:prompt).and_return(">")

      expect(described_class.ready?).to be(true)
    end
  end

  describe 'vitals progress bars' do
    it 'sends percent text with a matching value, labelling stamina as fatigue' do
      expect(init_string).to include("<progressBar id='health' value='100' text='health 100%'/>")
      expect(init_string).to include("<progressBar id='mana' value='87' text='mana 87%'/>")
      expect(init_string).to include("<progressBar id='stamina' value='42' text='fatigue 42%'/>")
      expect(init_string).to include("<progressBar id='spirit' value='100' text='spirit 100%'/>")
    end

    it 'never sends GemStone current/max text' do
      expect(init_string).not_to match(%r{text='[a-z]+ -?\d*/})
    end

    it 'sends the concentration bar' do
      expect(init_string).to include("<progressBar id='concentration' value='95' text='concentration 95%'/>")
    end

    context 'with a percent outside 0..100' do
      let(:vitals) { super().merge(:health => -10) }

      it 'clamps value while keeping the raw percent in text' do
        expect(init_string).to include("<progressBar id='health' value='0' text='health -10%'/>")
      end
    end
  end

  describe 'GemStone-only content' do
    it 'does not send stance, mind, encumbrance, or injuries' do
      expect(init_string).not_to include("id='pbarStance'")
      expect(init_string).not_to include("id='mindState'")
      expect(init_string).not_to include("id='encumlevel'")
      expect(init_string).not_to include('<image')
    end
  end

  describe 'spell' do
    it 'sends the prepared spell' do
      expect(init_string).to include('<spell>None</spell>')
    end
  end

  describe 'hands' do
    let(:right_hand) { MockGameObj.new(:name => 'steel broadsword') }

    it 'sends the held item names' do
      expect(init_string).to include('<right>steel broadsword</right><left>Empty</left>')
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
    it 'sends every indicator, defaulting ones not yet seen to not visible' do
      expect(init_string).to include("<indicator id='IconSTANDING' visible='y'/>")
      (described_class::INDICATORS - %w[IconSTANDING]).each do |indicator|
        expect(init_string).to include("<indicator id='#{indicator}' visible='n'/>")
      end
      expect(init_string).not_to include("visible=''")
    end
  end

  describe 'compass' do
    it 'sends the short form of each room exit' do
      expect(init_string).to end_with("<compass><dir value='n'/><dir value='s'/></compass>")
    end
  end
end
