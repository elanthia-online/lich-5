# frozen_string_literal: true

# Drives the real Ox SAX pipeline with fragments captured from a live
# DragonRealms session (five "a jeol moradu", exist 99353095..99355351) to
# verify that the DragonRealms creature layer is fed end-to-end the way
# production sees it:
#
#   * the room-objs component + the <crtrStatus> batch that follows it build an
#     id-keyed hostile roster with flags (no names yet), and
#   * the assess stream backfills each id's name, assess number, relation and
#     range.
#
# Contrast spec/lib/common/xmlparser_crtr_status_spec.rb, which covers the
# GemStone path where <crtrStatus> is interleaved with an <a exist> name tag.

require_relative '../../spec_helper'
require 'ox'
require 'dragonrealms/creature'
require 'common/xmlparser'

# The room-objs component followed by the standalone <crtrStatus> batch, verbatim
# shape from the live stream (five jeol moradu, the first immobile, the last
# three disengaged). Kept at file scope so it is a normal constant.
DR_ROOM_AND_CRTR = <<~XML.delete("\n")
  <component id='room objs'>You also see <pushBold/>a jeol moradu<popBold/> (immobile), <pushBold/>a jeol moradu<popBold/>, <pushBold/>a jeol moradu<popBold/>, a medium steel bar, a small pewter bar, <pushBold/>a jeol moradu<popBold/>, <pushBold/>a jeol moradu<popBold/> and some junk.</component>
  <crtrStatus exist="99353095" hostile="1" immobile="1"/><crtrStatus exist="99353135" hostile="1"/><crtrStatus exist="99355263" hostile="1" disengaged="1"/><crtrStatus exist="99355283" hostile="1" disengaged="1"/><crtrStatus exist="99355351" hostile="1" disengaged="1"/><prompt time="1785273427">R&gt;</prompt>
XML

# One assess cycle per creature/PC (pushStream .. popStream), including the
# trailing "| F" face hint the parser is expected to strip.
DR_ASSESS = <<~XML.delete("\n")
  <pushStream id="assess"/><clearStream id="assess"/>You assess your combat situation...<popStream/>
  <pushStream id="assess"/><d cmd='look #99353095'>A jeol moradu</d> (1: cursed and solidly balanced) is behind you at melee range.  | <d cmd='face #99353095'>F</d><popStream/>
  <pushStream id="assess"/><d cmd='look #99355263'>A jeol moradu</d> (3: solidly balanced) is moving to flank <d cmd='look #-10544759'>Kythkani</d> at pole weapon range.  | <d cmd='face #99355263'>F</d><popStream/>
  <pushStream id="assess"/><d cmd='look #-10544759'>Kythkani</d> (incredibly balanced) is behind <d cmd='look #99353095'>a jeol moradu</d> (1) at missile range.  | <d cmd='face #99353095'>F</d><popStream/>
  <prompt time="1785273425">R&gt;</prompt>
XML

RSpec.describe 'Lich::Common::XMLParser DragonRealms creature feed' do
  subject(:parser) { Lich::Common::XMLParser.new }

  before do
    Lich::DragonRealms::Creature.clear
    $creature_debug = nil
    allow(XMLData).to receive(:game).and_return('DRF')
    allow(XMLData).to receive(:current_target_ids).and_return([])
    # The parser refers to GameObj unqualified, which resolves to
    # Lich::Common::GameObj (its lexical scope), so it must be stubbed there.
    # DragonRealms room-objs carry no <a> tag, so GameObj is only touched for
    # clear_* housekeeping and the status-annotation path (npcs[-1].status=).
    # Stubbing keeps those harmless; an unstubbed npcs[-1] on the "(immobile)"
    # annotation would raise and the parser would silently rescue+reset,
    # skipping the very roster-clear these tests assert on.
    %i[clear_loot clear_npcs clear_pcs clear_room_desc new_npc new_loot].each do |m|
      allow(Lich::Common::GameObj).to receive(m)
    end
    allow(Lich::Common::GameObj).to receive(:npcs).and_return([double('npc').as_null_object])
  end

  def feed(fragment)
    Ox.sax_parse(parser, fragment, convert_special: false, symbolize: false, skip: :skip_none)
  end

  describe 'the <crtrStatus> batch after the room-objs component' do
    it 'builds an id-keyed hostile roster from crtrStatus alone, with no names yet' do
      feed(DR_ROOM_AND_CRTR)

      expect(Lich::DragonRealms::Creature.targets.map(&:id)).to contain_exactly(
        99353095, 99353135, 99355263, 99355283, 99355351
      )
      expect(Lich::DragonRealms::Creature[99353095].name).to be_nil
    end

    it 'applies each creature\'s flags from its own tag' do
      feed(DR_ROOM_AND_CRTR)

      expect(Lich::DragonRealms::Creature[99353095].has_status?('immobilized')).to be true
      expect(Lich::DragonRealms::Creature[99353095].crtr_flag?(:disengaged)).to be false
      expect(Lich::DragonRealms::Creature[99355263].crtr_flag?(:disengaged)).to be true
      expect(Lich::DragonRealms::Creature[99355263].has_status?('immobilized')).to be false
    end

    it 'rebuilds the roster on each room-objs refresh (departed creatures drop out)' do
      feed(DR_ROOM_AND_CRTR)
      # A later refresh in which only the first creature remains.
      feed(%(<component id='room objs'>You also see <pushBold/>a jeol moradu<popBold/> (immobile).</component><crtrStatus exist="99353095" hostile="1" immobile="1"/><prompt time="1785273500">R&gt;</prompt>))

      expect(Lich::DragonRealms::Creature.targets.map(&:id)).to eq([99353095])
    end
  end

  describe 'the assess stream backfilling names and position' do
    it 'ties each exist id to its name, assess number, relation and range' do
      feed(DR_ROOM_AND_CRTR)
      feed(DR_ASSESS)

      melee = Lich::DragonRealms::Creature[99353095]
      expect(melee.name).to eq('a jeol moradu') # downcased from "A jeol moradu"
      expect(melee.assess_number).to eq(1)
      # parse_assess_line splits "behind you" into relation + target ("you"),
      # so the stored relation is the bare positional word.
      expect(melee.relation).to eq('behind')
      expect(melee.range).to eq(:melee)

      flanker = Lich::DragonRealms::Creature[99355263]
      expect(flanker.assess_number).to eq(3)
      expect(flanker.relation).to eq('flanking') # "moving to flank" normalized
      expect(flanker.range).to eq(:pole)
      expect(flanker.target_id).to eq('-10544759')
    end

    it 'preserves the crtrStatus flags through the assess backfill' do
      feed(DR_ROOM_AND_CRTR)
      feed(DR_ASSESS)

      melee = Lich::DragonRealms::Creature[99353095]
      expect(melee.crtr_flag?(:hostile)).to be true
      expect(melee.has_status?('immobilized')).to be true
      expect(melee.name).to eq('a jeol moradu')
    end

    it 'does not register the player (a negative-id assess subject) as a creature' do
      feed(DR_ROOM_AND_CRTR)
      feed(DR_ASSESS)

      expect(Lich::DragonRealms::Creature[-10544759]).to be_nil
      expect(Lich::DragonRealms::Creature.all.map(&:id)).to all(be > 0)
    end
  end
end
