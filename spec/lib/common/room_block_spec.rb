# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/room_block'
require 'common/markup'

# Saga-identity <room> blocks (verbatim shape, names pseudonymized) and the
# legacy layout they map to.
RSpec.describe Lich::Common::RoomBlock do
  saga = '<resource picture="0"/><room><name>[Bosque Deriel, Hermit\'s Shacks] (230008)</name>' \
         '<description>Here on the route between the sacred sites is a semi-circular clearing.</description>' \
         '<exists>You also see <pushBold/><pushBold/>a <a exist="191009754" noun="leopard">white-tailed leopard</a><popBold/><popBold/>.</exists>' \
         '<crtrStatus exist="191009754" disengaged="1"/>' \
         '<players>Also here: Monster <a exist="-10514490" noun="Aldric">Aldric</a> and Druid <a exist="-10614301" noun="Delphine">Delphine</a>.</players>' \
         "<exits>Obvious paths: <d>north</d>, <d>south</d>.</exits><extra></extra></room>\r\n"

  describe '.legacy_shape' do
    it 'rewrites the block into the legacy roomName/roomDesc layout, one line per part' do
      expect(described_class.legacy_shape(saga)).to eq(
        '<resource picture="0"/><style id="roomName" />[Bosque Deriel, Hermit\'s Shacks] (230008)' + "\r\n" \
        '<style id=""/><preset id=\'roomDesc\'>Here on the route between the sacred sites is a semi-circular clearing.</preset>' \
        '  You also see <pushBold/><pushBold/>a <a exist="191009754" noun="leopard">white-tailed leopard</a><popBold/><popBold/>.' + "\r\n" \
        '<crtrStatus exist="191009754" disengaged="1"/>Also here: Monster <a exist="-10514490" noun="Aldric">Aldric</a> and Druid <a exist="-10614301" noun="Delphine">Delphine</a>.' + "\r\n" \
        "Obvious paths: <d>north</d>, <d>south</d>.\r\n"
      )
    end

    it 'omits empty parts as the legacy stream does, leading the exits line with any between-part tags' do
      block = '<room><name>[Bosque Deriel, Burial Ground] (230007)</name><description>An Elven burial ground.</description>' \
              '<exists></exists><crtrStatus exist="1" hostile="1"/><players></players><exits>Obvious paths: <d>north</d>.</exits><extra></extra></room>'
      expect(described_class.legacy_shape(block)).to eq(
        "<style id=\"roomName\" />[Bosque Deriel, Burial Ground] (230007)\r\n" \
        "<style id=\"\"/><preset id='roomDesc'>An Elven burial ground.</preset>\r\n" \
        '<crtrStatus exist="1" hostile="1"/>Obvious paths: <d>north</d>.'
      )
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

# reget/regetall strip the server-buffer history themselves rather than through
# Markup.strip_xml. Evaluate the real method from lib/global_defs.rb (which this
# suite does not load whole) so the spec exercises the shipped code.
RSpec.describe 'reget on Saga-identity <room> blocks' do
  let(:reget_host) do
    source = File.read(File.join(LIB_DIR, 'global_defs.rb'))[/^def reget\(.*?^end\n/m]
    Object.new.tap { |o| o.singleton_class.class_eval(source) }
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
