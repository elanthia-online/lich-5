# frozen_string_literal: true

require_relative '../../spec_helper'
require 'ox'
require 'common/gameobj'
require 'common/xmlparser'

# The shared parser calls two GemStone-only modules, ActiveSpell (effects
# dialogs) and Gift (the next-level bar). Without them loaded (DragonRealms, or
# GemStone before GameLoader finishes) those calls must be skipped: a NameError
# would reset the parser and discard every staged GameObj refresh.
RSpec.describe 'Lich::Common::XMLParser GemStone-only module guards' do
  subject(:parser) { Lich::Common::XMLParser.new }

  def feed(fragment)
    Ox.sax_parse(parser, fragment, convert_special: false, symbolize: false, skip: :skip_none)
  end

  before do
    hide_const('ActiveSpell')
    hide_const('Gift')
    expect(parser).not_to receive(:reset)
  end

  it 'clears an effects dialog without ActiveSpell loaded' do
    feed(%(<dialogData id='Active Spells' clear='t'></dialogData>))
    expect(parser.dialogs['Active Spells']).to eq({})
  end

  it 'records an effects progress bar without ActiveSpell loaded' do
    feed(%(<dialogData id='Buffs'><progressBar id='115' value='74' text="Fasthr's Reward" left='22%' top='0' width='76%' height='15' time='00:43:12'/></dialogData>))
    expect(parser.dialogs['Buffs']).not_to be_empty
  end

  it 'reads the next-level bar without Gift loaded' do
    feed(%(<progressBar id='nextLvlPB' value='42' text='42% to next' left='0%' top='0%' width='100%' height='100%'/>))
    expect(parser.next_level_value).to eq(42)
  end
end
