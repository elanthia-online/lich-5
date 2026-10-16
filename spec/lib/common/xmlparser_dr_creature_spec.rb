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
require 'common/gameobj'
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

# Saga-identity DR stream (Frontend::CLIENT_STRING since #1700), verbatim shape
# with ids kept: creatures are linked GemStone-style, but the article sits
# outside the link inside the bold (currently sent doubled), and the crtrStatus
# batch follows the component (GemStone sends it before each link).
DR_SAGA_ROOM_OBJS = <<~XML.delete("\n")
  <component id='room objs'>You also see <pushBold/><pushBold/>a <a exist="4001" noun="moradu">jeol moradu</a><popBold/><popBold/> (immobile), a <a exist="31028" noun="register">deed register</a>, <pushBold/><pushBold/>an <a exist="4002" noun="kobold">old kobold</a><popBold/><popBold/> and some junk.</component>
  <crtrStatus exist="4001" hostile="1" immobile="1"/><crtrStatus exist="4002" hostile="1"/><prompt time="1785273999">R&gt;</prompt>
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
    # Legacy-dialect DR room-objs carry no <a> tag, so GameObj is only touched
    # for clear_* housekeeping and the status-annotation path; the Saga-dialect
    # examples' new_npc/new_loot calls land on these stubs too.
    %i[clear_loot clear_npcs clear_pcs clear_room_desc new_npc new_loot].each do |m|
      allow(Lich::Common::GameObj).to receive(m)
    end
    # nil is the real DragonRealms value: GameObj.npcs is registry_or_nil over an
    # empty registry (nothing populates it from DR room-objs). The parser now
    # guards the annotation against nil, so a "(immobile)"/"(dead)" run no longer
    # raises + resets mid-fragment (which would drop the room-objs<->crtrStatus
    # name pairing). Returning nil here exercises that real condition.
    allow(Lich::Common::GameObj).to receive(:npcs).and_return(nil)
  end

  def feed(fragment)
    Ox.sax_parse(parser, fragment, convert_special: false, symbolize: false, skip: :skip_none)
  end

  describe 'the <crtrStatus> batch after the room-objs component' do
    it 'builds an id-keyed hostile roster from crtrStatus, named from room-objs order' do
      feed(DR_ROOM_AND_CRTR)

      expect(Lich::DragonRealms::Creature.targets.map(&:id)).to contain_exactly(
        99353095, 99353135, 99355263, 99355283, 99355351
      )
      # Stream-order backfill: each id is named from its bold room-objs slot,
      # before any assess has run.
      expect(Lich::DragonRealms::Creature[99353095].name).to eq('a jeol moradu')
      expect(Lich::DragonRealms::Creature[99353095].noun).to eq('moradu')
    end

    it 'names every id in the batch from its stream-order room-objs slot' do
      feed(DR_ROOM_AND_CRTR)

      names = [99353095, 99353135, 99355263, 99355283, 99355351].map do |id|
        Lich::DragonRealms::Creature[id].name
      end
      expect(names).to all(eq('a jeol moradu'))
      expect(Lich::DragonRealms::Creature[99355351].noun).to eq('moradu')
    end

    it 'count-guard (all-or-nothing): more crtrStatus than bold names -> no names applied' do
      feed(%(<component id='room objs'>You also see <pushBold/>a jeol moradu<popBold/>, <pushBold/>a kobold<popBold/> and some junk.</component><crtrStatus exist="1" hostile="1"/><crtrStatus exist="2" hostile="1"/><crtrStatus exist="3" hostile="1"/><prompt time="1785273999">R&gt;</prompt>))

      # 3 crtrStatus vs 2 bold names: counts differ, so NONE are positionally
      # named (assess would backfill). Roster/flags still built from crtrStatus.
      expect(Lich::DragonRealms::Creature.in_room.map(&:id)).to contain_exactly(1, 2, 3)
      expect(Lich::DragonRealms::Creature.in_room.map(&:name)).to all(be_nil)
    end

    it 'count-guard (all-or-nothing): more bold names than crtrStatus -> no names applied' do
      feed(%(<component id='room objs'>You also see <pushBold/>a jeol moradu<popBold/>, <pushBold/>a kobold<popBold/>, <pushBold/>an orc<popBold/> and some junk.</component><crtrStatus exist="1" hostile="1"/><crtrStatus exist="2" hostile="1"/><prompt time="1785274111">R&gt;</prompt>))

      expect(Lich::DragonRealms::Creature.in_room.map(&:id)).to contain_exactly(1, 2)
      expect(Lich::DragonRealms::Creature.in_room.map(&:name)).to all(be_nil)
    end

    it 'count-guard: a bold entity with no crtrStatus never mis-names the real mob' do
      # The mid-list-gap case: a bold room entity that emits no crtrStatus (a
      # gelapod-like object) would shift a positional pairing. The all-or-nothing
      # gate refuses to name on the count mismatch, so the real mob is NOT named
      # after the odd entity - it stays nil until assess ties it by id.
      feed(%(<component id='room objs'>You also see <pushBold/>a domesticated gelapod<popBold/>, <pushBold/>a jeol moradu<popBold/> and some junk.</component><crtrStatus exist="42" hostile="1"/><prompt time="1785274444">R&gt;</prompt>))

      moradu = Lich::DragonRealms::Creature[42]
      expect(moradu).not_to be_nil # tracked by crtrStatus (id + flags)
      expect(moradu.name).to be_nil # NOT mis-named "a domesticated gelapod"
    end

    it 'derives the noun for a multi-word bold name via the positional path' do
      feed(%(<component id='room objs'>You also see <pushBold/>a void-black umbral moth<popBold/> and some junk.</component><crtrStatus exist="7" hostile="1"/><prompt time="1785274222">R&gt;</prompt>))

      moth = Lich::DragonRealms::Creature[7]
      expect(moth.name).to eq('a void-black umbral moth')
      expect(moth.noun).to eq('moth')
    end

    it 'resets the name buffer on each room-objs refresh (no stale carry-over)' do
      feed(DR_ROOM_AND_CRTR) # five jeol moradu captured
      feed(%(<component id='room objs'>You also see <pushBold/>a kobold<popBold/> and some junk.</component><crtrStatus exist="500" hostile="1"/><prompt time="1785274333">R&gt;</prompt>))

      # the new room's crtrStatus pairs with the fresh buffer, not a leftover name
      expect(Lich::DragonRealms::Creature[500].name).to eq('a kobold')
    end

    it 'reset clears the room-objs name buffer and collected crtrStatus ids' do
      feed(%(<component id='room objs'>You also see <pushBold/>a jeol moradu<popBold/> and some junk.</component>))
      expect(parser.instance_variable_get(:@dr_room_npc_names)).not_to be_empty

      parser.reset

      expect(parser.instance_variable_get(:@dr_room_npc_names)).to eq([])
      expect(parser.instance_variable_get(:@dr_crtr_ids)).to eq([])
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
      expect(melee.target).to eq('you')
      expect(melee.range).to eq(:melee)
      # parenthetical "(1: cursed and solidly balanced)" -> balance + conditions
      expect(melee.balance).to eq('solidly')
      expect(melee.off_balance?).to be false
      expect(melee.conditions).to eq(['cursed'])
      expect(melee.cursed?).to be true
      expect(melee.enriched?).to be true

      flanker = Lich::DragonRealms::Creature[99355263]
      expect(flanker.assess_number).to eq(3)
      expect(flanker.relation).to eq('flanking') # "moving to flank" normalized
      expect(flanker.range).to eq(:pole)
      expect(flanker.target).to eq('Kythkani')
      expect(flanker.target_id).to eq('-10544759')
      expect(flanker.balance).to eq('solidly') # "(3: solidly balanced)" -> no conditions
      expect(flanker.conditions).to eq([])
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

  # The Saga-identity assess stream wraps each look target's name in a link
  # inside the <d cmd='look #id'> tag (verbatim shape, names pseudonymised):
  #   <d cmd='look #ID'><pushBold/>A <a exist="ID" noun="moradu">jeol moradu</a><popBold/></d> (1: ...) is facing you ...
  # The link's exist always equals the look id, and its noun= is the server's
  # noun, so the assess backfill keeps that noun instead of re-deriving the
  # last word of the name.
  describe 'Saga dialect: the linked assess stream' do
    def saga_assess(id, noun, text, tail = 'is facing you at melee range.')
      %(<pushStream id="assess"/><d cmd='look ##{id}'><pushBold/>A <a exist="#{id}" noun="#{noun}">#{text}</a><popBold/></d> ) +
        %((1: solidly balanced) #{tail}  | <d cmd='face ##{id}'>F</d><popStream/>)
    end

    it 'keeps the link noun when it is not the last word of the name (room objs first)' do
      feed("<component id='room objs'>You also see <pushBold/><pushBold/>a " \
           '<a exist="4003" noun="hound">grizzled hound with a notched ear</a><popBold/><popBold/>.</component>' \
           '<crtrStatus exist="4003" hostile="1"/><prompt time="1785273999">R&gt;</prompt>')
      feed(saga_assess(4003, 'hound', 'grizzled hound with a notched ear'))

      c = Lich::DragonRealms::Creature[4003]
      expect(c.name).to eq('a grizzled hound with a notched ear')
      expect(c.noun).to eq('hound')
      expect(c.assess_number).to eq(1)
    end

    it 'takes the link noun for a creature first seen in assess' do
      feed(saga_assess(4003, 'hound', 'grizzled hound with a notched ear'))

      expect(Lich::DragonRealms::Creature[4003].noun).to eq('hound')
    end

    it 'trims a padded link noun (noun=" moth")' do
      feed(saga_assess(4004, ' moth', 'void-black umbral moth'))

      expect(Lich::DragonRealms::Creature[4004].noun).to eq('moth')
    end

    # A PC subject's target link names a creature; the noun belongs to the
    # subject (looked up by its exist id), never to whichever link came first
    # or last on the line.
    it 'takes the noun from the subject\'s own link, not the target\'s' do
      feed(%(<pushStream id="assess"/><d cmd='look #4003'><pushBold/>A <a exist="4003" noun="hound">grizzled hound with a notched ear</a><popBold/></d> ) +
           %((2: solidly balanced) is behind <d cmd='look #4007'><pushBold/>a <a exist="4007" noun="moradu">jeol moradu</a><popBold/></d> (1) at melee range.  | ) +
           %(<d cmd='face #4003'>F</d> | <d cmd='face #4007'>F</d><popStream/>))

      expect(Lich::DragonRealms::Creature[4003].noun).to eq('hound')
      expect(Lich::DragonRealms::Creature[4007]).to be_nil
    end

    it 'does not carry a previous line\'s link noun onto a link-less (legacy) line' do
      feed(saga_assess(4003, 'hound', 'grizzled hound with a notched ear'))
      feed(%(<pushStream id="assess"/><d cmd='look #4003'>A grizzled hound with a notched ear</d> ) +
           %((1: solidly balanced) is facing you at melee range.  | <d cmd='face #4003'>F</d><popStream/>))

      # Legacy shape: no link, so the noun is derived from the name as before.
      expect(Lich::DragonRealms::Creature[4003].noun).to eq('ear')
    end
  end

  describe 'Saga dialect: linked room-objs creatures' do
    # No earlier linked line primes the session here, so this also covers the
    # very first linked room-objs line of a session.
    it 'registers id + noun + flags and keeps the article in the name, as the legacy stream does' do
      expect { feed(DR_SAGA_ROOM_OBJS) }.not_to raise_error

      c1 = Lich::DragonRealms::Creature[4001]
      expect(c1.name).to eq('a jeol moradu')
      expect(c1.noun).to eq('moradu')
      expect(c1.has_status?('immobilized')).to be true

      c2 = Lich::DragonRealms::Creature[4002]
      expect(c2.name).to eq('an old kobold')
      expect(c2.noun).to eq('kobold')
      expect(c2.crtr_flag?(:hostile)).to be true
    end

    it 'never renames a creature to the bare article at the prompt' do
      feed(DR_SAGA_ROOM_OBJS)

      names = Lich::DragonRealms::Creature.all.map(&:name)
      expect(names).not_to include('a ', 'an ')
      expect(Lich::DragonRealms::Creature.all.map(&:noun)).not_to include('a', 'an')
    end

    it 'keeps the article-prefixed names on a later refresh, once the session is known to be linked' do
      # The first feed is the session's first linked line (decided by shape);
      # the second runs with stream_feature?(:links) already set.
      feed(DR_SAGA_ROOM_OBJS)
      feed(DR_SAGA_ROOM_OBJS)

      expect(Lich::DragonRealms::Creature[4001].name).to eq('a jeol moradu')
      expect(Lich::DragonRealms::Creature[4002].name).to eq('an old kobold')
      expect(Lich::DragonRealms::Creature[4002].noun).to eq('kobold')
    end

    it 'ties both creatures into the room roster' do
      feed(DR_SAGA_ROOM_OBJS)

      expect(Lich::DragonRealms::Creature.targets.map(&:id)).to contain_exactly(4001, 4002)
    end

    # The link's noun= is the server's noun and need not be the last word of
    # the link text: the live stream sends long descriptive names such as
    # "a <a noun=\"panther\">sleek golden panther with enigmatic violet eyes</a>".
    it 'keeps the link noun when it is not the last word of the name, across a refresh' do
      line = "<component id='room objs'>You also see <pushBold/><pushBold/>a " \
             '<a exist="4003" noun="hound">grizzled hound with a notched ear</a><popBold/><popBold/>.</component>' \
             '<crtrStatus exist="4003" hostile="1"/><prompt time="1785273999">R&gt;</prompt>'
      feed(line)
      feed(line)

      c = Lich::DragonRealms::Creature[4003]
      expect(c.name).to eq('a grizzled hound with a notched ear')
      expect(c.noun).to eq('hound')
    end

    it 'takes the link noun for a creature crtrStatus registered first, with no noun' do
      feed('<crtrStatus exist="4003" hostile="1"/><prompt time="1785273998">R&gt;</prompt>')
      expect(Lich::DragonRealms::Creature[4003].noun).to be_nil

      feed("<component id='room objs'>You also see <pushBold/><pushBold/>a " \
           '<a exist="4003" noun="hound">grizzled hound with a notched ear</a><popBold/><popBold/>.</component>')

      expect(Lich::DragonRealms::Creature[4003].noun).to eq('hound')
    end

    # The live stream occasionally pads the attribute (noun=" moth").
    it 'trims whitespace around the link noun' do
      feed("<component id='room objs'>You also see <pushBold/><pushBold/>a " \
           '<a exist="4004" noun=" moth">void-black umbral moth</a><popBold/><popBold/>.</component>')

      expect(Lich::DragonRealms::Creature[4004].noun).to eq('moth')
    end

    it 'keeps a "the" article (named NPCs: "the Sentinel X")' do
      feed("<component id='room objs'>You also see <pushBold/><pushBold/>the " \
           '<a exist="4005" noun="Varnel">Sentinel Varnel</a><popBold/><popBold/>, a ' \
           '<a exist="-28812" noun="ladder">ladder to the top of the wall</a>.</component>')

      c = Lich::DragonRealms::Creature[4005]
      expect(c.name).to eq('the Sentinel Varnel')
      expect(c.noun).to eq('Varnel')
    end

    it 'names an article-less linked NPC without carrying the previous room\'s article' do
      feed(DR_SAGA_ROOM_OBJS)
      feed("<component id='room objs'>You also see <pushBold/><pushBold/>" \
           '<a exist="4006" noun="Orlan">Mastersmith Orlan</a><popBold/><popBold/> and a ' \
           '<a exist="31029" noun="sign">large sign</a>.</component>')

      c = Lich::DragonRealms::Creature[4006]
      expect(c.name).to eq('Mastersmith Orlan')
      expect(c.noun).to eq('Orlan')
    end

    # The stream currently doubles the bold; a single bold must work the same.
    it 'handles the single-bold form of the same line' do
      feed(DR_SAGA_ROOM_OBJS.gsub('<pushBold/><pushBold/>', '<pushBold/>').gsub('<popBold/><popBold/>', '<popBold/>'))

      expect(Lich::DragonRealms::Creature[4001].name).to eq('a jeol moradu')
      expect(Lich::DragonRealms::Creature[4002].name).to eq('an old kobold')
      expect(Lich::DragonRealms::Creature.all.map(&:name)).not_to include('a ', 'an ')
    end

    context 'GameObj npc status (real GameObj)' do
      before do
        %i[clear_npcs clear_loot new_npc new_loot npcs].each do |m|
          allow(Lich::Common::GameObj).to receive(m).and_call_original
        end
        Lich::Common::GameObj.clear_npcs
        Lich::Common::GameObj.clear_loot
      end

      after do
        Lich::Common::GameObj.clear_npcs
        Lich::Common::GameObj.clear_loot
      end

      def npc_status(id)
        Lich::Common::GameObj.npcs.find { |npc| npc.id == id }&.status
      end

      # DR words a corpse two ways in room objs: "(dead)" and "which appears dead".
      it 'marks a linked creature dead from either DR wording' do
        feed("<component id='room objs'>You also see <pushBold/><pushBold/>a " \
             '<a exist="4007" noun="cougar">cougar</a><popBold/><popBold/> which appears dead, ' \
             '<pushBold/><pushBold/>a <a exist="4008" noun="cougar">cougar</a><popBold/><popBold/> (dead) and ' \
             '<pushBold/><pushBold/>a <a exist="4009" noun="cougar">cougar</a><popBold/><popBold/>.</component>')

        expect(npc_status('4007')).to eq('dead')
        expect(npc_status('4008')).to eq('dead')
        expect(npc_status('4009')).to be_nil
      end

      it 'stops the status at "and" when the room-objs tail follows in the same run' do
        feed("<component id='room objs'>You also see <pushBold/><pushBold/>a " \
             '<a exist="4007" noun="cougar">cougar</a><popBold/><popBold/> which appears dead and some junk.</component>')

        expect(npc_status('4007')).to eq('dead')
      end

      # spec/fixtures/creature/dr_saga_room_objs_shapes.xml holds a room objs line
      # captured verbatim from a 2026-10-16 Saga session (see
      # spec/fixtures/README.md): one corpse "which appears dead", caged
      # creatures "that is caught in ...", plain ones, and the " and some junk."
      # tail after the last creature's own run.
      it 'reads every status on a captured Saga room objs line' do
        path = File.expand_path('../../fixtures/creature/dr_saga_room_objs_shapes.xml', __dir__)
        feed(File.read(path).lines.grep(/which appears dead/).first.chomp)

        expect(npc_status('197119614')).to eq('dead')
        expect(npc_status('197119654')).to eq('caught in a cage of swirling darkness')
        expect(npc_status('197115095')).to be_nil
        expect(npc_status('197122645')).to be_nil
        expect(Lich::Common::GameObj.npcs.size).to eq(14)
      end
    end
  end
end
