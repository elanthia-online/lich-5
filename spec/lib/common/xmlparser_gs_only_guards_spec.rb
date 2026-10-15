# frozen_string_literal: true

require_relative '../../spec_helper'
require 'ox'
require 'common/gameobj'
require 'common/xmlparser'

# The shared parser calls two GemStone-only modules, ActiveSpell (effects
# dialogs) and Gift (the next-level bar). Without them loaded (DragonRealms, or
# GemStone before GameLoader finishes) those calls must be skipped: a NameError
# would reset the parser and discard every staged GameObj refresh. With them
# loaded (GemStone after GameLoader) the calls must still be made.
RSpec.describe 'Lich::Common::XMLParser GemStone-only module guards' do
  subject(:parser) { Lich::Common::XMLParser.new }

  def feed(fragment)
    Ox.sax_parse(parser, fragment, convert_special: false, symbolize: false, skip: :skip_none)
  end

  context 'without the modules loaded' do
    before do
      # Production resolves the bare constants through `include Lich::Gemstone`
      # on Object, and other spec files do the same at load time. hide_const on
      # the bare name cannot remove a constant that is only reachable through an
      # included module, so hide the namespaced definitions too, then assert the
      # bare names really are gone (otherwise these examples pass vacuously).
      %w[ActiveSpell Gift].each do |name|
        hide_const(name)
        hide_const("Lich::Gemstone::#{name}")
        raise "#{name} still resolvable; guard spec would be vacuous" if Object.const_defined?(name)
      end
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

  context 'with the modules loaded' do
    # Stand-ins on the bare names, which is how the parser looks them up.
    let(:active_spell) { stub_const('ActiveSpell', Module.new) }
    let(:gift) { stub_const('Gift', Module.new) }

    before do
      allow(active_spell).to receive(:request_update)
      allow(gift).to receive(:pulse)
      expect(parser).not_to receive(:reset)
    end

    it 'asks ActiveSpell for an update on a clear and on each effect bar' do
      # GemStone's shape: an empty clearing dialogData, then the refill.
      feed(%(<dialogData id='Buffs' clear='t'></dialogData><dialogData id='Buffs'><progressBar id='401' value='90' text="Spell One" left='22%' top='0' width='76%' height='15' time='00:20:00'/><label id='l401' value='20:00 ' top='0' left='0' justify='2' anchor_right=''/><progressBar id='402' value='40' text="Spell Two" left='22%' top='16' width='76%' height='15' time='00:08:00'/></dialogData>))
      expect(active_spell).to have_received(:request_update).exactly(3).times
    end

    it 'pulses Gift only when the next-level text changes' do
      %w[42 42 43].each do |pct|
        feed(%(<progressBar id='nextLvlPB' value='#{pct}' text='#{pct}% to next' left='0%' top='0%' width='100%' height='100%'/>))
      end
      expect(gift).to have_received(:pulse).twice
      expect(parser.next_level_value).to eq(43)
    end
  end
end
