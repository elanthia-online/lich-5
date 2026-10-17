# frozen_string_literal: true

# Drives the real Ox SAX pipeline with fragments captured from a live GST
# session (a sea nymph, exist=607736, arriving/getting stunned/dying, plus a
# carrion worm, exist=607744) to verify <crtrStatus> registers and updates
# Lich::Gemstone::CreatureInstance the same way production will see it.

require_relative '../../spec_helper'
require 'ox'
require 'gemstone/creature'
require 'common/xmlparser'
require 'gemstone/xml_delta'
require 'common/gameobj'

# Bare `Creature`/`GameObj` references inside XMLParser resolve through this,
# same as production (lib/main/main.rb includes Lich::Gemstone the same way).
include Lich::Gemstone

RSpec.describe 'Lich::Common::XMLParser <crtrStatus> handling' do
  subject(:parser) { Lich::Common::XMLParser.new }

  before do
    Lich::Gemstone::Creature.clear
    Lich::Gemstone::Creature.configure
    # game is consulted by the <crtrStatus> handler to route GS vs DR; these
    # fixtures are GemStone captures, so it must report a GS instance.
    stub_const('XMLData', double(current_target_ids: [], game: 'GSIV'))
    allow(Lich::Common::GameObj).to receive(:new_npc)
    allow(Lich::Common::GameObj).to receive(:new_loot)
    allow(Lich::Common::GameObj).to receive(:clear_loot)
    allow(Lich::Common::GameObj).to receive(:begin_room_objs)
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

  it 'populates exact positive health values while registering a new creature' do
    feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1" health="75" maxhealth="120"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b>.</component>))

    nymph = Lich::Gemstone::Creature[607736]
    expect(nymph.health).to eq(75)
    expect(nymph.max_health).to eq(120)
    expect(nymph.current_hp).to eq(75)
    expect(nymph.max_hp).to eq(120)
    expect(nymph.hp_percent).to eq(62.5)
  end

  it 'applies a crtrStatus update once the creature is already registered' do
    feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b>.</component>))
    feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1" stunned="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b> (stunned).</component>))

    expect(Lich::Gemstone::Creature[607736].has_status?('stunned')).to be true
  end

  it 'updates existing exact health, preserving negative values' do
    feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1" health="75" maxhealth="120"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b>.</component>))
    feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1" health="-16" maxhealth="120"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b>.</component>))

    nymph = Lich::Gemstone::Creature[607736]
    expect(nymph.health).to eq(-16)
    expect(nymph.max_health).to eq(120)
    expect(nymph.current_hp).to eq(-16)
    expect(nymph.max_hp).to eq(120)
    expect(nymph.hp_percent).to eq(-13.3)
    expect(nymph.dead?).to be true
  end

  it 'preserves zero/zero and then clears both values when the next snapshot omits them' do
    feed(%(<component id='room objs'>  You notice<crtrStatus exist="356889321" health="0" maxhealth="0" inferior="1"/><b> <pushBold/>a <a exist="356889321" noun="toucan">black-necked hooded toucan</a><popBold/></b>.</component>))

    toucan = Lich::Gemstone::Creature[356889321]
    expect(toucan.health).to eq(0)
    expect(toucan.max_health).to eq(0)
    expect(toucan.current_hp).to eq(toucan.max_hp)
    expect(toucan.max_hp).to be_positive

    feed(%(<component id='room objs'>  You notice<crtrStatus exist="356889321" inferior="1"/><b> <pushBold/>a <a exist="356889321" noun="toucan">black-necked hooded toucan</a><popBold/></b>.</component>))

    expect(toucan.health).to be_nil
    expect(toucan.max_health).to be_nil
    expect(toucan.current_hp).to eq(toucan.max_hp)
    expect(toucan.max_hp).to be_positive
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

    # Captured pair from elanthia-online/scripts#2478: Sympathy (1120) swaps
    # hostile for sympathetic on the same exist id mid-fight.
    it 'keeps targeting a creature the feed flips from hostile to sympathetic' do
      feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1" inferior="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b>.</component>))
      feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" sympathetic="1" inferior="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b>.</component>))

      expect(Lich::Gemstone::Creature.targets.map(&:id)).to eq([607736])
      expect(Lich::Gemstone::Creature.targets(:hostile)).to eq([])
      expect(Lich::Gemstone::Creature.targets(:not_sympathetic)).to eq([])
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

  # GemStone also sends <crtrStatus> outside room objs: runs of combat updates
  # for one creature (one tag per hit, often several to a line), the main-text
  # "You also see" listing of LOOK/arrival, and just before a room players
  # component. Shapes from GS Shattered captures, ids and names pseudonymised;
  # verbatim captured lines are in the next describe.
  describe 'standalone <crtrStatus> outside room objs' do
    before do
      allow(Lich::Common::GameObj).to receive(:clear_npcs)
      allow(Lich::Common::GameObj).to receive(:clear_pcs)
      allow(Lich::Common::GameObj).to receive(:clear_room_desc)
    end

    let(:viper_in_room) do
      %(<component id='room objs'>You also see<crtrStatus exist="700100" health="240" maxhealth="240" hostile="1"/><b> <pushBold/>a <a exist="700100" noun="viper">dune viper</a><popBold/></b>.</component>)
    end

    it 'applies a combat run to a creature already in the room, last snapshot winning' do
      feed(viper_in_room)
      feed(%(<crtrStatus exist="700100" health="176" maxhealth="240" hostile="1"/><crtrStatus exist="700100" health="131" maxhealth="240" hostile="1" stunned="1" prone="1"/><crtrStatus exist="700100" health="56" maxhealth="240" hostile="1" stunned="1" prone="1"/><dialogData id='Buffs' clear='t'></dialogData>))

      viper = Lich::Gemstone::Creature[700100]
      expect(viper.health).to eq(56)
      expect(viper.max_health).to eq(240)
      expect(viper.has_status?('stunned')).to be true
      expect(viper.has_status?('prone')).to be true
    end

    it 'treats each standalone tag as a full snapshot, clearing a flag the next one omits' do
      feed(viper_in_room)
      feed(%(<crtrStatus exist="700100" health="131" maxhealth="240" hostile="1" stunned="1"/>))
      feed(%(<crtrStatus exist="700100" health="-12" maxhealth="240" hostile="1" dead="1" prone="1"/>))

      viper = Lich::Gemstone::Creature[700100]
      expect(viper.has_status?('stunned')).to be false
      expect(viper.crtr_flag?(:dead)).to be true
      expect(viper.health).to eq(-12)
    end

    it 'applies the tag in a main-text "You also see" listing to a creature already in the room' do
      feed(viper_in_room)
      feed(%(<style id=""/><style id="roomDesc"/>Sandstone tiles cover the floor.  <style id=""/>You also see <crtrStatus exist="700100" health="201" maxhealth="240" hostile="1" prone="1"/><pushBold/>a <a exist="700100" noun="viper">dune viper</a><popBold/>.))

      viper = Lich::Gemstone::Creature[700100]
      expect(viper.health).to eq(201)
      expect(viper.has_status?('prone')).to be true
    end

    it 'leaves the room roster and GameObj alone when it applies' do
      feed(viper_in_room)
      expect(Lich::Common::GameObj).not_to receive(:new_npc)
      feed(%(<crtrStatus exist="700100" health="176" maxhealth="240" hostile="1"/>))

      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to eq([700100])
      expect(parser.instance_variable_get(:@pending_crtr_status)).to be_empty
    end

    it 'does not register an id the room has never linked' do
      feed(viper_in_room)
      feed(%(<crtrStatus exist="700200" health="90" maxhealth="90" hostile="1"/>))

      expect(Lich::Gemstone::Creature[700200]).to be_nil
      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to eq([700100])
    end

    it 'does not apply to a creature the registry remembers but the current room does not list' do
      feed(viper_in_room)
      feed(%(<nav rm='7355'/>))
      feed(%(<crtrStatus exist="700100" health="12" maxhealth="240" hostile="1" stunned="1"/>))

      viper = Lich::Gemstone::Creature[700100]
      expect(viper.health).to eq(240)
      expect(viper.has_status?('stunned')).to be false
      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to be_empty
    end

    # The 15 GS captures of 2026-10-15 never sent a tag without health or a
    # flag set to "0", but the older live GST fragments in this file do
    # (hostile="0"; health omitted). A standalone tag like that follows the
    # same full-snapshot rule as a room-objs one: health clears, "0" is off.
    it 'applies a standalone tag without health, or with a "0" flag, as a full snapshot' do
      feed(viper_in_room)
      feed(%(<crtrStatus exist="700100" hostile="0" prone="1"/>))

      viper = Lich::Gemstone::Creature[700100]
      expect(viper.health).to be_nil
      expect(viper.max_health).to be_nil
      expect(viper.crtr_flag?(:hostile)).to be false
      expect(viper.has_status?('prone')).to be true
    end

    it 'still defers a room-objs tag for a known creature to its link' do
      feed(viper_in_room)
      feed(%(<component id='room objs'>You also see<crtrStatus exist="700100" health="99" maxhealth="240" hostile="1"/> a <a exist="-4401" noun="statue">cobra statue</a>.</component>))

      # The refresh no longer lists the viper, so its tag never reaches it.
      viper = Lich::Gemstone::Creature[700100]
      expect(viper.health).to eq(240)
      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to be_empty
    end
  end

  # Verbatim server lines from a GemStone Shattered capture (2026-10-15, Saga
  # client string), fed one line at a time as Game.process_xml_data does. The
  # fixture's source and line map are in spec/fixtures/README.md:
  #   1  <nav> + room window: room-objs compDef, tag before sentinel A's link
  #   2  main-text room description: "You also see" with A's tag inline
  #   3  combat: two standalone tags for A (the second dead/prone), then a
  #      room-objs refresh on the same line
  #   4  <nav> + room window for the next room: sentinel B, tag before link
  #   5  main-text "You also see" with B's tag inline
  #   6  room-objs component: B's tag after a non-creature link, before B's
  describe 'captured GemStone lines (crtr_status/gs_saga_crtr_status.xml)' do
    let(:lines) do
      File.readlines(File.expand_path('../../fixtures/crtr_status/gs_saga_crtr_status.xml', __dir__))
    end
    let(:sentinel_a) { 784142402 }
    let(:sentinel_b) { 784142399 }

    before do
      %i[clear_npcs clear_pcs clear_room_desc begin_room_desc commit_room_desc
         begin_room_players commit_room_players commit_room_objs].each do |m|
        allow(Lich::Common::GameObj).to receive(m)
      end
    end

    def snapshot(id)
      creature = Lich::Gemstone::Creature[id]
      [creature.health, creature.max_health, creature.crtr_flag?(:dead), creature.has_status?('prone')]
    end

    it 'registers each room-objs creature from the tag that precedes its link' do
      feed(lines[0])

      sentinel = Lich::Gemstone::Creature[sentinel_a]
      expect(sentinel.name).to eq('lithe veiled sentinel')
      expect(sentinel.crtr_flag?(:hostile)).to be true
      expect(snapshot(sentinel_a)).to eq([300, 300, false, false])
      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to eq([sentinel_a])

      feed(lines[3])
      feed(lines[5])

      expect(Lich::Gemstone::Creature[sentinel_b].name).to eq('lithe veiled sentinel')
      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to eq([sentinel_b])
      expect(Lich::Common::GameObj).to have_received(:new_loot).with('781927405', 'disk', 'purple Aldric disk')
      expect(parser.instance_variable_get(:@pending_crtr_status)).to be_empty
    end

    it 'applies a combat run before the room-objs refresh on the same line opens' do
      feed(lines[0])
      at_refresh = nil
      allow(Lich::Common::GameObj).to receive(:begin_room_objs) { at_refresh ||= snapshot(sentinel_a) }

      feed(lines[2])

      # main left the creature at its last room-objs state (300, alive) until
      # the refresh re-sent the tag.
      expect(at_refresh).to eq([177, 300, true, true])
      expect(snapshot(sentinel_a)).to eq([177, 300, true, true])
      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to eq([sentinel_a])
    end

    it 'applies the main-text "You also see" tag to the creature already in the room' do
      [[0, 1, sentinel_a], [3, 4, sentinel_b]].each do |room_line, listing_line, id|
        feed(lines[room_line])
        creature = Lich::Gemstone::Creature[id]
        # A stale state the listing's tag must overwrite (full snapshot).
        creature.sync_crtr_status('health' => '120', 'maxhealth' => '300', 'hostile' => '1', 'stunned' => '1')

        feed(lines[listing_line])

        expect(creature.health).to eq(300)
        expect(creature.has_status?('stunned')).to be false
        expect(creature.crtr_flag?(:hostile)).to be true
        expect(Lich::Gemstone::CreatureInstance.current_room_ids).to eq([id])
        expect(parser.instance_variable_get(:@pending_crtr_status)).to be_empty
      end
    end

    it 'ends the window with A dead in the registry and only B in the room' do
      lines.each { |line| feed(line) }

      expect(snapshot(sentinel_a)).to eq([177, 300, true, true])
      expect(snapshot(sentinel_b)).to eq([300, 300, false, false])
      expect(Lich::Gemstone::CreatureInstance.current_room_ids).to eq([sentinel_b])
      expect(parser.instance_variable_get(:@pending_crtr_status)).to be_empty
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
    # The dropdown fallback delegates to the real GameObj.targets, so these
    # need real GameObj npc records rather than the stubbed new_npc.
    before do
      allow(Lich::Common::GameObj).to receive(:new_npc).and_call_original
      Lich::Common::GameObj.clear_npcs
    end

    let(:rider_line) do
      %(<compDef id='room objs'>  You also see<crtrStatus exist="436658124" health="900" maxhealth="900" hostile="1" ascended="1" rider="1"/><b> <pushBold/>a <a exist="436658124" noun="shield-maiden">brawny gigas shield-maiden</a><popBold/></b> who is riding <pushBold/>a <a exist="436656696" noun="mastodon">heavily armored battle mastodon</a><popBold/> and an <a exist="435609879" noun="lyre">ornate ruic lyre</a> with shimmering silver strings.</compDef>)
    end

    it 'infers the mount from its rider, without claiming a real tag' do
      stub_const('XMLData', double(current_target_ids: %w[436656696 436658124], game: 'GSIV'))
      feed(rider_line)

      mount = Lich::Gemstone::Creature[436656696]
      expect(mount).not_to be_nil
      expect(mount.crtr_flag?(:mount)).to be true
      # Hostility is not inferred; the dropdown fallback targets it instead.
      expect(mount.crtr_flag?(:hostile)).to be false
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

    it 'still applies a rider status annotation in the same text run as "who is riding"' do
      feed(%(<compDef id='room objs'>  You also see<crtrStatus exist="436658124" hostile="1" rider="1" dead="1"/><b> <pushBold/>a <a exist="436658124" noun="shield-maiden">brawny gigas shield-maiden</a><popBold/></b> (dead) who is riding <pushBold/>a <a exist="436656696" noun="mastodon">heavily armored battle mastodon</a><popBold/>.</compDef>))

      expect(Lich::Common::GameObj['436658124'].status).to eq('dead')
      expect(Lich::Gemstone::Creature[436656696].crtr_flag?(:mount)).to be true
    end

    it 'drops the inferred mount flag once the mount is no longer ridden' do
      stub_const('XMLData', double(current_target_ids: ['436656696'], game: 'GSIV'))
      feed(rider_line)
      feed(%(<compDef id='room objs'>  You also see <pushBold/>a <a exist="436656696" noun="mastodon">heavily armored battle mastodon</a><popBold/>.</compDef>))

      expect(Lich::Gemstone::Creature[436656696].crtr_flag?(:mount)).to be false
    end

    it 'does not infer a mount unless the game flagged the preceding creature rider="1"' do
      feed(%(<compDef id='room objs'>  You also see<crtrStatus exist="436658124" hostile="1"/><b> <pushBold/>a <a exist="436658124" noun="shield-maiden">brawny gigas shield-maiden</a><popBold/></b> who is riding <pushBold/>a <a exist="436656696" noun="mastodon">heavily armored battle mastodon</a><popBold/>.</compDef>))

      expect(Lich::Gemstone::Creature[436656696]).to be_nil
    end

    it 'does not carry flags over to a different creature that reuses a known id' do
      feed(%(<component id='room objs'>  You notice<crtrStatus exist="436656696" hostile="0"/><b> <pushBold/>a <a exist="436656696" noun="rabbit">field rabbit</a><popBold/></b>.</component>))
      feed(%(<nav rm='7355'/>))
      feed(rider_line)

      mount = Lich::Gemstone::Creature[436656696]
      expect(mount.name).to eq('heavily armored battle mastodon')
      expect(mount.crtr_flags?).to be false
      expect(mount.crtr_flag?(:mount)).to be true
    end

    it 'keeps reported flags across an ordinary refresh of the same creature' do
      feed(%(<component id='room objs'>  You notice<crtrStatus exist="607736" hostile="1" stunned="1"/><b> <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/></b> (stunned).</component>))
      first = Lich::Gemstone::Creature[607736]
      feed(%(<component id='room objs'>  You notice <pushBold/>a <a exist="607736" noun="nymph">sea nymph</a><popBold/>.</component>))

      expect(Lich::Gemstone::Creature[607736]).to equal(first)
      expect(first.crtr_flag?(:hostile)).to be true
    end

    it 'falls back to the target dropdown for a creature the feed has said nothing about' do
      stub_const('XMLData', double(current_target_ids: ['614999'], game: 'GSIV'))
      feed(%(<component id='room objs'>  You notice <pushBold/>a <a exist="614999" noun="ooze">gelatinous ooze</a><popBold/>.</component>))

      expect(Lich::Gemstone::Creature.targets.map(&:id)).to eq([614999])
    end

    it 'targets a fresh mount once room-objs staging is committed, as in production' do
      # The file-level before stubs begin_room_objs, so the other examples
      # write npcs straight into the published list; this one goes through
      # the real staging -> commit_room_objs swap.
      allow(Lich::Common::GameObj).to receive(:begin_room_objs).and_call_original
      expect(Lich::Common::GameObj).to receive(:commit_room_objs).and_call_original
      stub_const('XMLData', double(current_target_ids: %w[436656696 436658124], game: 'GSIV'))
      feed(rider_line)

      expect(Lich::Gemstone::Creature.targets.map(&:id)).to contain_exactly(436658124, 436656696)
    end

    it 'does not target an untagged creature the room shows as dead, even if the dropdown lists it' do
      stub_const('XMLData', double(current_target_ids: ['614998'], game: 'GSIV'))
      feed(%(<component id='room objs'>  You notice <pushBold/>a <a exist="614998" noun="ooze">gelatinous ooze</a><popBold/> that appears dead.</component>))

      expect(Lich::Gemstone::Creature.targets).to be_empty
    end

    it 'does not let a non-bold link after "who is riding" arm the next bold creature' do
      feed(%(<compDef id='room objs'>  You also see<crtrStatus exist="436658124" hostile="1" rider="1"/><b> <pushBold/>a <a exist="436658124" noun="shield-maiden">brawny gigas shield-maiden</a><popBold/></b> who is riding a <a exist="436656696" noun="mastodon">battle mastodon</a> and <pushBold/>a <a exist="614997" noun="kobold">kobold</a><popBold/>.</compDef>))

      expect(Lich::Gemstone::Creature[614997]).to be_nil
    end

    it 'trusts a real hostile="0" over the target dropdown' do
      stub_const('XMLData', double(current_target_ids: ['999001'], game: 'GSIV'))
      feed(%(<component id='room objs'>  You notice<crtrStatus exist="999001" hostile="0"/><b> <pushBold/>a <a exist="999001" noun="rabbit">field rabbit</a><popBold/></b>.</component>))

      expect(Lich::Gemstone::Creature.targets).to be_empty
    end
  end
end
