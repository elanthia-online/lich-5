# frozen_string_literal: true

require_relative '../../spec_helper'
require 'ox'
require 'gemstone/creature'
require 'common/gameobj'
require 'common/xmlparser'

# The shared parser registers GemStone room creatures through the GemStone-only
# Creature module, which GameLoader loads (via the combat tracker) only once the
# game is known. Without it loaded (GemStone before GameLoader finishes, or a
# session whose game was never identified) a creature link must be skipped: a
# NameError would reset the parser, drop every staged GameObj refresh and lose
# the rest of the fragment. With it loaded the creature must still be registered.
RSpec.describe 'Lich::Common::XMLParser GemStone Creature guard' do
  subject(:parser) { Lich::Common::XMLParser.new }

  # GemStone's shape: crtrStatus ahead of the bold creature link, then a second
  # creature and a loot item later in the same component.
  let(:room_objs) do
    %(<component id='room objs'>You also see<crtrStatus exist="5001" hostile="1"/><b> <pushBold/>a <a exist="5001" noun="rat">giant rat</a><popBold/></b>, <pushBold/>a <a exist="5002" noun="kobold">kobold</a><popBold/> and <a exist="5003" noun="dagger">a dagger</a>.</component>)
  end

  def feed(fragment)
    Ox.sax_parse(parser, fragment, convert_special: false, symbolize: false, skip: :skip_none)
  end

  before do
    stub_const('XMLData', double(current_target_ids: ['5002'], game: 'GSF'))
    allow(Lich::Common::GameObj).to receive(:new_npc)
    allow(Lich::Common::GameObj).to receive(:new_loot)
    allow(Lich::Common::GameObj).to receive(:clear_loot)
    allow(Lich::Common::GameObj).to receive(:begin_room_objs)
    expect(parser).not_to receive(:reset)
  end

  context 'without the Creature module loaded' do
    before do
      # Production resolves the bare constant through `include Lich::Gemstone`
      # on Object, and other spec files do the same at load time. hide_const on
      # the bare name cannot remove a constant that is only reachable through an
      # included module, so hide the namespaced definition too, then assert the
      # bare name really is gone (otherwise these examples pass vacuously).
      hide_const('Creature')
      hide_const('Lich::Gemstone::Creature')
      raise 'Creature still resolvable; guard spec would be vacuous' if Object.const_defined?(:Creature)
    end

    it 'stages every creature and the loot in the component without a parser reset' do
      feed(room_objs)

      expect(Lich::Common::GameObj).to have_received(:new_npc).with('5001', 'rat', 'giant rat')
      expect(Lich::Common::GameObj).to have_received(:new_npc).with('5002', 'kobold', 'kobold')
      expect(Lich::Common::GameObj).to have_received(:new_loot).with('5003', 'dagger', 'a dagger')
    end
  end

  context 'with the Creature module loaded' do
    before do
      # Production resolution: the bare name is the GemStone module.
      stub_const('Creature', Lich::Gemstone::Creature)
      @saved_config = Lich::Gemstone::Creature.stats.slice(:max_size, :auto_register, :cleanup_max_age)
      Lich::Gemstone::Creature.clear
      Lich::Gemstone::Creature.configure
    end

    # Leave the shared registry as we found it: no ids registered here leak
    # into later specs, and any configuration another spec set is restored.
    after do
      Lich::Gemstone::Creature.clear
      Lich::Gemstone::Creature.configure(**@saved_config)
    end

    it 'registers the crtrStatus creature and the targeted creature, but not the loot' do
      feed(room_objs)

      rat = Lich::Gemstone::Creature[5001]
      expect(rat&.name).to eq('giant rat')
      expect(rat.crtr_flag?(:hostile)).to be true
      expect(Lich::Gemstone::Creature[5002]&.name).to eq('kobold')
      expect(Lich::Gemstone::Creature[5003]).to be_nil
    end
  end
end
