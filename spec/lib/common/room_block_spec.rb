# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/room_block'
require 'common/markup'
require_relative '../../support/global_defs_spec_source'

# Saga-identity <room> blocks (verbatim shape, names pseudonymized) and the
# legacy layout they map to.
RSpec.describe Lich::Common::RoomBlock do
  saga = '<resource picture="0"/><room><name>[Bosque Deriel, Hermit\'s Shacks] (230008)</name>' \
         '<description>Here on the route between the sacred sites is a semi-circular clearing.</description>' \
         '<exists>You also see <pushBold/><pushBold/>a <a exist="191009754" noun="leopard">white-tailed leopard</a><popBold/><popBold/>.</exists>' \
         '<crtrStatus exist="191009754" disengaged="1"/>' \
         '<players>Also here: Monster <a exist="-10700002" noun="Aldric">Aldric</a> and Druid <a exist="-10700005" noun="Delphine">Delphine</a>.</players>' \
         "<exits>Obvious paths: <d>north</d>, <d>south</d>.</exits><extra></extra></room>\r\n"

  describe '.legacy_shape' do
    it 'rewrites the block into the legacy roomName/roomDesc layout, one line per part' do
      expect(described_class.legacy_shape(saga)).to eq(
        '<resource picture="0"/><style id="roomName" />[Bosque Deriel, Hermit\'s Shacks] (230008)' + "\r\n" \
        '<style id=""/><preset id=\'roomDesc\'>Here on the route between the sacred sites is a semi-circular clearing.</preset>' \
        '  You also see <pushBold/><pushBold/>a <a exist="191009754" noun="leopard">white-tailed leopard</a><popBold/><popBold/>.' + "\r\n" \
        '<crtrStatus exist="191009754" disengaged="1"/>Also here: Monster <a exist="-10700002" noun="Aldric">Aldric</a> and Druid <a exist="-10700005" noun="Delphine">Delphine</a>.' + "\r\n" \
        "Obvious paths: <d>north</d>, <d>south</d>.\r\n"
      )
    end

    it 'omits empty parts as the legacy stream does, leading the exits line with any between-part tags' do
      block = '<room><name>[Bosque Deriel, Burial Ground] (230007)</name><description>An Elven burial ground.</description>' \
              '<exists></exists><crtrStatus exist="1" hostile="1"/><players></players><exits>Obvious paths: <d>north</d>.</exits><extra></extra></room>'
      expect(described_class.legacy_shape(block)).to eq(
        "<style id=\"roomName\" />[Bosque Deriel, Burial Ground] (230007)\r\n" \
        "<style id=\"\"/><preset id='roomDesc'>An Elven burial ground.</preset>  \r\n" \
        '<crtrStatus exist="1" hostile="1"/>Obvious paths: <d>north</d>.'
      )
    end

    it 'omits an empty exits part instead of leaving a blank line' do
      block = '<room><name>[A] (1)</name><description>D.</description><exists></exists>' \
              '<players>Also here: Corwin.</players><exits></exits><extra>A sign hangs here.</extra></room>'
      expect(described_class.legacy_shape(block).split("\r\n", -1)).to eq([
                                                                            '<style id="roomName" />[A] (1)',
                                                                            %(<style id=""/><preset id='roomDesc'>D.</preset>  ),
                                                                            'Also here: Corwin.',
                                                                            'A sign hangs here.'
                                                                          ])
    end

    it 'keeps the between-part tags on their own line when players and exits are both empty' do
      block = '<room><name>[A] (1)</name><description>D.</description><crtrStatus exist="1" hostile="1"/>' \
              '<players></players><exits></exits><extra></extra></room>'
      expect(described_class.legacy_shape(block).lines.last).to eq('<crtrStatus exist="1" hostile="1"/>')
    end

    # The legacy description line is <style id=""/>, the roomDesc preset when
    # there is a description, two spaces, then the objects (dr_legacy_hunt.xml
    # sends "<style id=""/>  You also see ..." and "<style id=""/>  " with room
    # descriptions off; room_block/dr_legacy_desc_no_objects.xml sends
    # "...</preset>  " for a room without objects).
    {
      'an empty description'                => ['', 'You also see a rock.', %(<style id=""/>  You also see a rock.)],
      'an empty description and no objects' => ['', '', %(<style id=""/>  )],
      'no objects'                          => ['D.', '', %(<style id=""/><preset id='roomDesc'>D.</preset>  )]
    }.each do |label, (description, exists, line)|
      it "gives the description line the legacy shape for #{label}" do
        block = "<room><name>[A] (1)</name><description>#{description}</description><exists>#{exists}</exists>" \
                '<players></players><exits>Obvious paths: <d>north</d>.</exits><extra></extra></room>'
        expect(described_class.legacy_shape(block).split("\r\n", -1)).to eq(['<style id="roomName" />[A] (1)', line, 'Obvious paths: <d>north</d>.'])
      end
    end

    # The same room (230007, no objects) captured in both dialects:
    # spec/fixtures/room_block/dr_legacy_desc_no_objects.xml is the legacy view
    # (2026-10-07) and the Saga block is the one in dr_saga_locate_descflag.xml
    # (2026-10-16). The rewrite gives the legacy lines byte for byte, including
    # the description line's two trailing spaces when there are no objects.
    it 'rewrites a captured Saga block into the captured legacy lines for the same room' do
      fixtures = File.expand_path('../../fixtures', __dir__)
      legacy_view = File.read(File.join(fixtures, 'room_block/dr_legacy_desc_no_objects.xml')).lines.map(&:chomp)
      saga_block = File.foreach(File.join(fixtures, 'streams/dr_saga_locate_descflag.xml')).find { |l| l.include?('(230007)</name>') }

      expect(legacy_view[1]).to end_with('</preset>  ')
      expect(described_class.legacy_shape(saga_block.chomp).split("\r\n", -1)).to eq(legacy_view)
    end

    it 'keeps a non-empty extra part as its own line' do
      block = '<room><name>[A] (1)</name><description>D.</description><exists></exists><players></players>' \
              '<exits>Obvious paths: none.</exits><extra>A sign hangs here.</extra></room>'
      expect(described_class.legacy_shape(block).lines.last).to eq('A sign hangs here.')
    end

    it 'returns a string without a block unchanged, as the same object' do
      line = +"<style id=\"roomName\" />[Jeol'gelvmoraen, Ice Grottos] (4217404)\r\n"
      expect(described_class.legacy_shape(line)).to equal(line)
    end

    it 'leaves a block cut off before </room> alone' do
      cut = '<room><name>[A] (1)</name><description>D.</description>'
      expect(described_class.legacy_shape(cut)).to eq(cut)
    end
  end

  describe 'Markup.strip_xml on a <room> block' do
    legacy_lines = [
      "<resource picture=\"0\"/><style id=\"roomName\" />[Bosque Deriel, Hermit's Shacks] (230008)\r\n",
      "<style id=\"\"/><preset id='roomDesc'>Here on the route between the sacred sites is a semi-circular clearing.</preset>  You also see <pushBold/>a white-tailed leopard<popBold/>.\r\n",
      "<crtrStatus exist=\"191009754\" disengaged=\"1\"/>Also here: Monster Aldric and Druid Delphine.\r\n",
      "Obvious paths: <d>north</d>, <d>south</d>.\r\n"
    ]

    it 'gives scripts the same room lines as the legacy stream' do
      legacy = legacy_lines.map { |l| Lich::Common::Markup.strip_xml(l) }.join
      expect(Lich::Common::Markup.strip_xml(saga)).to eq(legacy)
      expect(Lich::Common::Markup.strip_xml(saga).split("\r\n")).to eq([
                                                                         "[Bosque Deriel, Hermit's Shacks] (230008)",
                                                                         'Here on the route between the sacred sites is a semi-circular clearing.  You also see a white-tailed leopard.',
                                                                         'Also here: Monster Aldric and Druid Delphine.',
                                                                         'Obvious paths: north, south.'
                                                                       ])
    end

    it 'gives scripts the legacy lines for a room sent without a description' do
      block = "<room><name>[Area, Grotto] (1)</name><description></description><exists>You also see <pushBold/>a moradu<popBold/>.</exists>" \
              "<players></players><exits>Obvious exits: <d>north</d>.</exits><extra></extra></room>\r\n"
      legacy = ["<style id=\"roomName\" />[Area, Grotto] (1)\r\n",
                "<style id=\"\"/>  You also see <pushBold/>a moradu<popBold/>.\r\n",
                "Obvious exits: <d>north</d>.\r\n"].map { |l| Lich::Common::Markup.strip_xml(l) }.join
      expect(Lich::Common::Markup.strip_xml(block)).to eq(legacy)
    end

    # The legacy "<style id=""/>  " line (room descriptions off, no objects)
    # strips to whitespace, so strip_xml drops it and scripts never see it.
    it 'gives scripts no whitespace-only line for a room sent without a description or objects' do
      block = "<room><name>[Area, Grotto] (1)</name><description></description><exists></exists>" \
              "<players></players><exits>Obvious exits: <d>north</d>.</exits><extra></extra></room>\r\n"
      legacy = ["<style id=\"roomName\" />[Area, Grotto] (1)\r\n",
                "<style id=\"\"/>  \r\n",
                "Obvious exits: <d>north</d>.\r\n"].map { |l| Lich::Common::Markup.strip_xml(l) }.join
      expect(Lich::Common::Markup.strip_xml(block)).to eq(legacy)
      expect(Lich::Common::Markup.strip_xml(block).split("\r\n")).to eq(['[Area, Grotto] (1)', 'Obvious exits: north.'])
    end

    it 'drops that whitespace-only line when it ends the string' do
      block = '<room><name>[Area, Grotto] (1)</name><description></description><exists></exists>' \
              '<players></players><exits></exits><extra></extra></room>'
      expect(Lich::Common::Markup.strip_xml(block)).to eq("[Area, Grotto] (1)\r\n")
    end

    # With no players and no exits the <crtrStatus> batch keeps its own line,
    # which strips to an empty one; the legacy stream would send it as its own
    # string, and strip_xml would drop it.
    it 'drops the empty line left by between-part tags on their own line' do
      block = '<room><name>[A, B] (1)</name><description>Desc.</description><exists>You also see a rock.</exists>' \
              "<crtrStatus exist=\"1\" hostile=\"1\"/><players></players><exits></exits><extra></extra></room>\r\n"
      expect(Lich::Common::Markup.strip_xml(block)).to eq("[A, B] (1)\r\nDesc.  You also see a rock.\r\n")
    end

    it 'leaves the whitespace of a string without a <room> block alone' do
      text = "<pushBold/>You walk north.<popBold/>\r\n  \r\nObvious paths: <d>north</d>.\r\n"
      expect(Lich::Common::Markup.strip_xml(text)).to eq("You walk north.\r\n  \r\nObvious paths: north.\r\n")
    end
  end
end

RSpec.describe Lich::Common::RoomBlock, 'in multi-line strings' do
  block = ->(title) { "<room><name>[Area, #{title}] (1)</name><description>D.</description><exits>Obvious paths: <d>north</d>.</exits><extra></extra></room>" }

  it 'rewrites every block, not only the first' do
    out = described_class.legacy_shape("#{block.call('One')}\r\nYou walk north.\r\n#{block.call('Two')}\r\n")
    expect(out).not_to include('<room>')
    expect(out.scan('<style id="roomName" />').size).to eq(2)
  end

  it 'does not let a block cut off before </room> swallow the next one' do
    out = described_class.legacy_shape("<room><name>[Area, Cut] (1)</name>\r\nYou walk north.\r\n#{block.call('Two')}\r\n")
    expect(out).to start_with("<room><name>[Area, Cut] (1)</name>\r\nYou walk north.\r\n")
    expect(out).to include('<style id="roomName" />[Area, Two] (1)')
  end
end

# The legacy stream followed the exits line of a view of the character's own
# room with a top-level <compass>; the Saga-identity stream sends none.
RSpec.describe Lich::Common::RoomBlock, '.legacy_shape_with_compass' do
  block = lambda do |exits, name: '[Bosque Deriel, Burial Ground] (230007)', extra: ''|
    "<resource picture=\"0\"/><room><name>#{name}</name><description>An Elven burial ground.</description>" \
      "<exists></exists><players></players><exits>#{exits}</exits><extra>#{extra}</extra></room>\r\n"
  end
  two_exits = 'Obvious paths: <d>north</d>, <d>southeast</d>.'
  fixtures = File.expand_path('../../fixtures', __dir__)

  it 'follows the exits line with the legacy compass, on its own line' do
    out = described_class.legacy_shape_with_compass(block.call(two_exits))
    expect(out).to eq(
      %(<resource picture="0"/><style id="roomName" />[Bosque Deriel, Burial Ground] (230007)\r\n) +
      %(<style id=""/><preset id='roomDesc'>An Elven burial ground.</preset>  \r\n) +
      %(Obvious paths: <d>north</d>, <d>southeast</d>.\r\n) +
      %(<compass><dir value="n"/><dir value="se"/></compass>\r\n)
    )
  end

  it 'maps every exit name the game lists, in the order it lists them' do
    names = %w[out down up northwest west southwest south southeast east northeast north]
    exits = "Obvious paths: #{names.map { |n| "<d>#{n}</d>" }.join(', ')}."
    out = described_class.legacy_shape_with_compass(block.call(exits))
    expect(out.lines.last).to eq(
      '<compass><dir value="out"/><dir value="down"/><dir value="up"/><dir value="nw"/><dir value="w"/>' \
      '<dir value="sw"/><dir value="s"/><dir value="se"/><dir value="e"/><dir value="ne"/><dir value="n"/></compass>' + "\r\n"
    )
  end

  it 'leaves out an exit name that has no compass value' do
    out = described_class.legacy_shape_with_compass(block.call('Obvious paths: <d>north</d>, <d>gate</d>.'))
    expect(out.lines.last).to eq(%(<compass><dir value="n"/></compass>\r\n))
  end

  it 'reads the text of an attributed <d> exit' do
    out = described_class.legacy_shape_with_compass(block.call('Obvious paths: <d cmd="go gate">gate</d>, <d cmd="west">west</d>.'))
    expect(out.lines.last).to eq(%(<compass><dir value="w"/></compass>\r\n))
  end

  # "Obvious exits: none." and the fog wording are synthetic: no capture has
  # either in a <room> block (the fog text's real wording is not known).
  ['Obvious paths: none.', 'Obvious exits: none.', 'Obvious paths: obscured by a thick fog'].each do |exits|
    it "sends an empty compass, clearing the last room's, for #{exits.inspect}" do
      out = described_class.legacy_shape_with_compass(block.call(exits))
      expect(out.lines.last(2)).to eq(["#{exits}\r\n", "<compass></compass>\r\n"])
    end
  end

  # A captured Saga block with "Obvious paths: none." gives the lines a captured
  # legacy view of a room without exits ends with (room_block/README section in
  # spec/fixtures/README.md).
  it 'gives a captured Saga room without exits the legacy view\'s exits line and empty compass' do
    saga_block = File.foreach(File.join(fixtures, 'room_block/dr_saga_no_exits.xml')).find { |l| l.include?('<room>') }
    legacy_tail = File.readlines(File.join(fixtures, 'room_block/dr_legacy_no_exits.xml'), chomp: true).last(2)
    out = described_class.legacy_shape_with_compass(saga_block.chomp).split("\r\n")
    expect(out.last(2)).to eq(legacy_tail)
  end

  it 'puts the compass before a non-empty extra part, right after the exits line' do
    out = described_class.legacy_shape_with_compass(block.call(two_exits, extra: 'A sign hangs here.'))
    expect(out.lines.last(3)).to eq(["#{two_exits}\r\n", %(<compass><dir value="n"/><dir value="se"/></compass>\r\n), "A sign hangs here.\r\n"])
  end

  # A Moon Mage's Locate shows the target's room as a bare <room> block. The
  # legacy stream followed that view with the located room's compass
  # (room_block/dr_legacy_locate.xml), not the character's.
  it 'gives a block of a room the character is not in the compass of that room' do
    remote = block.call('Obvious paths: <d>north</d>, <d>south</d>.', name: "[Bosque Deriel, Hermit's Shacks] (230008)")
    expect(described_class.legacy_shape_with_compass(remote).lines.last).to eq(%(<compass><dir value="n"/><dir value="s"/></compass>\r\n))
  end

  # The same located room (230008) in both dialects: the legacy Locate view in
  # dr_legacy_locate.xml (character in 230007) and the Saga Locate view in
  # streams/dr_saga_locate_descflag.xml (character in 230007).
  it 'sends after a captured Saga Locate view the exits line and compass the legacy stream sent after its Locate view' do
    legacy = File.readlines(File.join(fixtures, 'room_block/dr_legacy_locate.xml'), chomp: true)
    cast = legacy.index { |l| l.include?('the equation of the Locate spell') }
    exits_at = legacy.each_index.find { |i| i > cast && legacy[i].start_with?('Obvious paths:') }
    legacy_exits = legacy[exits_at]
    legacy_compass = legacy[exits_at + 1][%r{\A<compass>.*?</compass>}]
    expect(legacy[exits_at - 3]).to include("[Bosque Deriel, Hermit's Shacks] (230008)")

    saga_lines = File.readlines(File.join(fixtures, 'streams/dr_saga_locate_descflag.xml'), chomp: true)
    saga_block = saga_lines.find { |l| l.include?('(230008)</name>') }
    out = described_class.legacy_shape_with_compass(saga_block).split("\r\n")
    expect(out.last(2)).to eq([legacy_exits, legacy_compass])
  end

  # PEER into a neighbouring room gets the same answer as a Locate: "You peer
  # <dir> and see ..." and a bare <room> block of that room
  # (room_block/dr_saga_peer.xml: from 230008, PEER SOUTH shows 230007 and
  # PEER NORTH 230009, then LOOK shows 230008).
  describe 'on a captured PEER' do
    peer = File.readlines(File.join(fixtures, 'room_block/dr_saga_peer.xml'), chomp: true)
    blocks = peer.select { |l| l.include?('<room>') }

    it 'gives each PEER view the compass of the room peered into, and the own room view its own' do
      expect(blocks.map { |b| b[%r{\((\d+)\)</name>}, 1] }).to eq(%w[230007 230009 230008])
      expect(peer[peer.index(blocks[0]) - 2]).to eq('You peer south and see ...')
      expect(peer[peer.index(blocks[1]) - 2]).to eq('You peer north and see ...')
      compasses = [
        %(<compass><dir value="n"/><dir value="se"/></compass>),
        %(<compass><dir value="s"/><dir value="nw"/></compass>),
        %(<compass><dir value="n"/><dir value="s"/></compass>)
      ]
      expect(blocks.map { |b| described_class.legacy_shape_with_compass(b).lines.last }).to eq(compasses)
    end

    # No capture has a legacy PEER, so the comparison is with the legacy view
    # of the same room from inside it (230007 in dr_legacy_locate.xml).
    it 'sends after the PEER view of 230007 the exits line and compass the legacy stream sent in 230007' do
      legacy = File.readlines(File.join(fixtures, 'room_block/dr_legacy_locate.xml'), chomp: true)
      arrival = legacy.index("<nav rm='230007'/>")
      exits_at = legacy.each_index.find { |i| i > arrival && legacy[i].start_with?('Obvious paths:') }
      out = described_class.legacy_shape_with_compass(blocks[0]).split("\r\n")
      expect(out.last(2)).to eq([legacy[exits_at], legacy[exits_at + 1][%r{\A<compass>.*?</compass>}]])
    end
  end

  it 'gives each block in a multi-block string the compass of its own exits' do
    here = block.call(two_exits)
    there = block.call('Obvious paths: <d>west</d>.', name: '[Bosque Deriel, Dense Woods] (230010)')
    out = described_class.legacy_shape_with_compass("#{here}#{there}")
    expect(out.scan(%r{<compass>.*?</compass>})).to eq([%(<compass><dir value="n"/><dir value="se"/></compass>), %(<compass><dir value="w"/></compass>)])
    expect(out).to include(%(<compass><dir value="n"/><dir value="se"/></compass>\r\n<resource picture="0"/><style id="roomName" />[Bosque Deriel, Dense Woods]))
  end

  it 'returns a string without a block unchanged, as the same object' do
    line = +"Obvious paths: <d>north</d>.\r\n"
    expect(described_class.legacy_shape_with_compass(line)).to equal(line)
  end

  it 'never reaches scripts: legacy_shape and strip_xml add no compass' do
    expect(described_class.legacy_shape(block.call(two_exits))).not_to include('<compass>')
    expect(Lich::Common::Markup.strip_xml(block.call(two_exits)).split("\r\n").last).to eq('Obvious paths: north, southeast.')
  end

  # Every legacy exits line in the legacy captures is followed by a compass;
  # the compass built from that exits line must be the one the game sent. The
  # captures include a Locate view of another room and a room without exits.
  it 'rebuilds the compass the legacy stream sent after every exits line in the legacy captures' do
    files = Dir[File.join(fixtures, 'streams/dr_legacy_*.xml')] +
            %w[dr_legacy_locate.xml dr_legacy_no_exits.xml].map { |f| File.join(fixtures, 'room_block', f) } +
            Dir[File.expand_path('../../../benchmark/fixtures/dr_{sample,inventory_sample}.xml', __dir__)]
    pairs = files.flat_map do |file|
      lines = File.readlines(file, chomp: true)
      # The crtrStatus batch leads the exits line when no one else is here.
      lines.each_index.select { |i| lines[i].match?(/\A(?:<crtrStatus[^>]*>)*Obvious (?:paths|exits):/) }
                      .map { |i| [lines[i].sub(/\A(?:<crtrStatus[^>]*>)*/, ''), lines[i + 1][%r{\A<compass>.*?</compass>}]] }
    end
    expect(pairs.size).to be >= 43
    expect(pairs.map(&:last)).to include('<compass></compass>', '<compass><dir value="n"/><dir value="s"/></compass>')
    pairs.each do |exits, sent|
      out = described_class.legacy_shape_with_compass(block.call(exits))
      expect(out.lines.last.chomp).to eq(sent), exits
    end
  end
end

# One arrival in the Saga logs had no room exits component
# (room_block/dr_saga_arrival_without_exits_component.xml): the parser keeps
# the last room's exits, so the compass has to come from the block itself.
RSpec.describe Lich::Common::RoomBlock, 'on a captured arrival without a room exits component' do
  require 'rexml/document'
  require 'rexml/streamlistener'
  require 'common/gameobj'
  require 'common/xmlparser'

  it 'sends the compass of the block, not the exits XMLParser kept from the last room' do
    parser = Lich::Common::XMLParser.new
    lines = File.readlines(File.expand_path('../../fixtures/room_block/dr_saga_arrival_without_exits_component.xml', __dir__), chomp: true)
    lines.each { |line| REXML::Document.parse_stream("<root>#{line}</root>", parser) }
    block = lines.reverse.find { |l| l.include?('<room>') }

    expect(block).to include('(2108013)</name>')
    expect(parser.room_id).to eq(2_108_013)
    expect(parser.room_exits).to eq(%w[southeast west])
    expect(described_class.legacy_shape_with_compass(block).lines.last).to eq('<compass><dir value="sw"/><dir value="nw"/></compass>')
  end
end

# reget/regetall strip the server-buffer history themselves rather than through
# Markup.strip_xml. Evaluate the real method from lib/global_defs.rb (which this
# suite does not load whole) so the spec exercises the shipped code.
RSpec.describe 'reget on Saga-identity <room> blocks' do
  let(:reget_host) do
    Object.new.tap { |o| GlobalDefsSpecSource.define(o.singleton_class, 'reget') }
  end

  before do
    stub_const('Script', Class.new)
    allow(Script).to receive(:current).and_return(double('script', want_downstream_xml: false))
    room = %(<resource picture="0"/><room><name>[Bosque Deriel, Hermit's Shacks] (230008)</name><description>A clearing.</description><exists>You also see a <a exist="1" noun="leopard">leopard</a>.</exists><players>Also here: <a exist="-2" noun="Corwin">Corwin</a>.</players><exits>Obvious paths: <d>north</d>.</exits><extra></extra></room>\r\n)
    prompt = %(<prompt time="1">&gt;</prompt>\r\n)
    $_SERVERBUFFER_.replace([room, prompt])
  end

  after { $_SERVERBUFFER_.clear }

  it 'returns the legacy room lines a script would match against' do
    lines = reget_host.reget.map(&:strip)
    expect(lines).to eq([
                          "[Bosque Deriel, Hermit's Shacks] (230008)",
                          'A clearing.  You also see a leopard.',
                          'Also here: Corwin.',
                          'Obvious paths: north.'
                        ])
  end
end
