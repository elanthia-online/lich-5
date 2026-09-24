# frozen_string_literal: true

# Drives the real Ox SAX pipeline with fragments captured from a live GST
# session (a sea nymph, exist=607736, arriving/getting stunned/dying, plus a
# carrion worm, exist=607744) to verify <crtrStatus> registers and updates
# Lich::Gemstone::CreatureInstance the same way production will see it.

require_relative '../../spec_helper'
require 'ox'
require 'gemstone/creature'
require 'common/xmlparser'

# Bare `Creature`/`GameObj` references inside XMLParser resolve through this,
# same as production (lib/main/main.rb includes Lich::Gemstone the same way).
include Lich::Gemstone

RSpec.describe 'Lich::Common::XMLParser <crtrStatus> handling' do
  subject(:parser) { Lich::Common::XMLParser.new }

  before do
    Lich::Gemstone::Creature.clear
    # game is consulted by the <crtrStatus> handler to route GS vs DR; these
    # fixtures are GemStone captures, so it must report a GS instance.
    stub_const('XMLData', double(current_target_ids: [], game: 'GSIV'))
    allow(Lich::Common::GameObj).to receive(:new_npc)
    allow(Lich::Common::GameObj).to receive(:new_loot)
    allow(Lich::Common::GameObj).to receive(:clear_loot)
  end

  def feed(fragment)
    Ox.sax_parse(parser, fragment, convert_special: false, symbolize: false, skip: :skip_none)
  end

  it 'registers a creature on first sight via crtrStatus, ahead of the current_target_ids gate' do
    feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b>.</component>))

    nymph = Lich::Gemstone::Creature[607736]
    expect(nymph).not_to be_nil
    expect(nymph.name).to eq('sea nymph')
    expect(nymph.crtr_flag?(:hostile)).to be true
  end

  it 'applies a crtrStatus update once the creature is already registered' do
    feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b>.</component>))
    feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1" stunned="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b> (stunned).</component>))

    expect(Lich::Gemstone::Creature[607736].has_status?('stunned')).to be true
  end

  it 'registers and updates two creatures independently from a single line' do
    feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b>.</component>))
    feed(%(<component id='room objs'>  You notice<crtrStatus exist="607744" hostile="1"/><b> <pushBold/>a <a exist="607744" noun="worm">carrion worm</a><popBold/></b> and<crtrStatus exist="607736" hostile="1" stunned="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b> (stunned).</component>))

    expect(Lich::Gemstone::Creature[607744].crtr_flag?(:hostile)).to be true
    expect(Lich::Gemstone::Creature[607736].has_status?('stunned')).to be true
  end

  it 'reconciles as a full snapshot end-to-end: stunned clears once the dead snapshot arrives' do
    feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1" stunned="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b> (stunned).</component>))
    feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1" dead="1" prone="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b> (dead).</component>))

    nymph = Lich::Gemstone::Creature[607736]
    expect(nymph.has_status?('stunned')).to be false
    expect(nymph.crtr_flag?(:dead)).to be true
    expect(nymph.has_status?('prone')).to be true
  end

  it 'still registers via the pre-existing current_target_ids path when crtrStatus is absent' do
    stub_const('XMLData', double(current_target_ids: ['614999'], game: 'GSIV'))

    feed(%(<component id='room objs'>  You notice <pushBold/>a <a exist="614999" noun="ooze">gelatinous ooze</a><popBold/>.</component>))

    expect(Lich::Gemstone::Creature[614999]).not_to be_nil
  end

  describe 'room roster (Creature.targets), independent of GameObj' do
    before do
      allow(Lich::Common::GameObj).to receive(:clear_npcs)
      allow(Lich::Common::GameObj).to receive(:clear_pcs)
      allow(Lich::Common::GameObj).to receive(:clear_room_desc)
    end

    it 'tracks who is in the room from crtrStatus alone, with no GameObj involvement' do
      feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b> and<crtrStatus exist="607744" hostile="1"/><b> <pushBold/>a <a exist="607744" noun="worm">carrion worm</a><popBold/></b>.</component>))

      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to contain_exactly(607736, 607744)
      expect(Lich::Gemstone::Creature.targets.map(&:name)).to contain_exactly('sea nymph', 'carrion worm')
    end

    it 'excludes non-hostile room creatures from targets but keeps them in the roster' do
      feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b> and<crtrStatus exist="999001" hostile="0"/><b> <pushBold/>a <a exist="999001" noun="rabbit">field rabbit</a><popBold/></b>.</component>))

      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to contain_exactly(607736, 999001)
      expect(Lich::Gemstone::Creature.targets.map(&:name)).to eq(['sea nymph'])
    end

    it 'clears the roster on a room-objs refresh, dropping creatures that left even though the registry still remembers them' do
      feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b>.</component>))
      feed(%(<component id='room objs'>  You notice<crtrStatus exist="607744" hostile="1"/><b> <pushBold/>a <a exist="607744" noun="worm">carrion worm</a><popBold/></b>.</component>))

      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to eq([607744])
      expect(Lich::Gemstone::Creature.targets.map(&:name)).to eq(['carrion worm'])
      expect(Lich::Gemstone::Creature[607736]).not_to be_nil # still remembered for wound reporting
    end

    it 'clears the roster on nav (room change), same as GameObj.clear_npcs' do
      stub_const('XMLData', double(current_target_ids: [], game: 'GSIV'))
      feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b>.</component>))
      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to eq([607736])

      feed(%(<nav rm='7355'/>))

      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to be_empty
      expect(Lich::Gemstone::Creature.targets).to be_empty
    end

    it 'filters targets by status/flag name, ANDed on top of the hostile baseline' do
      feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b> and<crtrStatus exist="607744" hostile="1" prone="1"/><b> <pushBold/>a <a exist="607744" noun="worm">carrion worm</a><popBold/></b>.</component>))

      expect(Lich::Gemstone::Creature.targets(:prone).map(&:name)).to eq(['carrion worm'])
      expect(Lich::Gemstone::Creature.targets(:not_prone).map(&:name)).to eq(['sea nymph'])
    end

    it 'marks an already-known creature back into the roster when it reappears after a clear_room' do
      # Regression: crtrStatus used to sync flags directly on an already-known
      # creature and skip Creature.register entirely for that case, since
      # register (and the room-marking it does) only ever ran from the <a>
      # text path. The creature's flags stayed correct, but it silently
      # dropped out of the room roster forever after the next clear_room -
      # sync'd but never reappearing in Creature.targets/.in_room.
      stub_const('XMLData', double(current_target_ids: [], game: 'GSIV'))
      feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b>.</component>))
      feed(%(<nav rm='7355'/>))
      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to be_empty

      # She's still around - same shape as her first appearance, same id,
      # and Creature already has an instance for her from before the nav.
      feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b>.</component>))

      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to eq([607736])
      expect(Lich::Gemstone::Creature.targets.map(&:id)).to eq([607736])
    end
  end

  describe 'pending crtrStatus does not leak across a reused exist id' do
    it 'reset clears it, so a fragment abandoned mid-parse cannot misapply to a later creature with the same id' do
      feed(%(<crtrStatus exist="999999" hostile="1" dead="1"/>)) # arrives, but its matching <a> never does - fragment truncated
      expect(parser.instance_variable_get(:@pending_crtr_status)).to have_key('999999')

      parser.reset # malformed/truncated fragment recovery

      expect(parser.instance_variable_get(:@pending_crtr_status)).to be_empty

      # Id reused later by an unrelated creature via the current_target_ids path.
      stub_const('XMLData', double(current_target_ids: ['999999'], game: 'GSIV'))
      feed(%(<component id='room objs'>  You notice <pushBold/>a <a exist="999999" noun="crab">giant crab</a><popBold/>.</component>))

      expect(Lich::Gemstone::Creature[999999].crtr_flag?(:dead)).to be false
    end

    it 'nav clears it too, so a fragment abandoned mid-room cannot survive into the next room' do
      feed(%(<crtrStatus exist="999999" hostile="1" dead="1"/>))
      expect(parser.instance_variable_get(:@pending_crtr_status)).to have_key('999999')

      stub_const('XMLData', double(current_target_ids: [], game: 'GSIV'))
      feed(%(<nav rm='7355'/>))

      expect(parser.instance_variable_get(:@pending_crtr_status)).to be_empty
    end

    it 'a room-objs refresh clears it too' do
      feed(%(<crtrStatus exist="999999" hostile="1" dead="1"/>))
      expect(parser.instance_variable_get(:@pending_crtr_status)).to have_key('999999')

      feed(%(<component id='room objs'>  You notice a <a exist="-2294" noun="gate">wrought iron gate</a>.</component>))

      expect(parser.instance_variable_get(:@pending_crtr_status)).to be_empty
    end
  end
  # Live GST capture: a mount sends no <crtrStatus> of its own until first
  # harmed; only its rider's tag arrives, carrying rider="1".
  describe 'ridden mounts with no <crtrStatus> of their own' do
    let(:rider_line) do
      %(<compDef id='room objs'>  You also see<crtrStatus exist="436658124" health="900" maxhealth="900" hostile="1" ascended="1" rider="1"/><b> <pushBold/>a <a exist="436658124" noun="shield-maiden">brawny gigas shield-maiden</a><popBold/></b> who is riding <pushBold/>a <a exist="436656696" noun="mastodon">heavily armored battle mastodon</a><popBold/> and an <a exist="435609879" noun="lyre">ornate ruic lyre</a> with shimmering silver strings.</compDef>)
    end

    it 'infers the mount as a hostile mount from its rider, without claiming a real tag' do
      feed(rider_line)

      mount = Lich::Gemstone::Creature[436656696]
      expect(mount).not_to be_nil
      expect(mount.crtr_flag?(:mount)).to be true
      expect(mount.crtr_flag?(:hostile)).to be true
      expect(mount.crtr_flags?).to be false
      expect(Lich::Gemstone::Creature.targets.map(&:id)).to contain_exactly(436658124, 436656696)
    end

    it 'lets the first real <crtrStatus> for the mount win over the inference' do
      feed(rider_line)
      feed(%(<compDef id='room objs'>  You also see<crtrStatus exist="436658124" hostile="1" rider="1"/><b> <pushBold/>a <a exist="436658124" noun="shield-maiden">brawny gigas shield-maiden</a><popBold/></b> who is riding<crtrStatus exist="436656696" hostile="0" mount="1"/> <pushBold/>a <a exist="436656696" noun="mastodon">heavily armored battle mastodon</a><popBold/>.</compDef>))

      mount = Lich::Gemstone::Creature[436656696]
      expect(mount.crtr_flags?).to be true
      expect(mount.crtr_flag?(:hostile)).to be false
    end

    it 'does not infer a mount unless the game flagged the preceding creature rider="1"' do
      feed(%(<compDef id='room objs'>  You also see<crtrStatus exist="436658124" hostile="1"/><b> <pushBold/>a <a exist="436658124" noun="shield-maiden">brawny gigas shield-maiden</a><popBold/></b> who is riding <pushBold/>a <a exist="436656696" noun="mastodon">heavily armored battle mastodon</a><popBold/>.</compDef>))

      expect(Lich::Gemstone::Creature[436656696]).to be_nil
    end

    it 'falls back to the target dropdown for a creature the feed has said nothing about' do
      stub_const('XMLData', double(current_target_ids: ['614999'], game: 'GSIV'))
      feed(%(<component id='room objs'>  You notice <pushBold/>a <a exist="614999" noun="ooze">gelatinous ooze</a><popBold/>.</component>))

      expect(Lich::Gemstone::Creature.targets.map(&:id)).to eq([614999])
    end

    it 'trusts a real hostile="0" over the target dropdown' do
      stub_const('XMLData', double(current_target_ids: ['999001'], game: 'GSIV'))
      feed(%(<component id='room objs'>  You notice<crtrStatus exist="999001" hostile="0"/><b> <pushBold/>a <a exist="999001" noun="rabbit">field rabbit</a><popBold/></b>.</component>))

      expect(Lich::Gemstone::Creature.targets).to be_empty
    end
  end
end
