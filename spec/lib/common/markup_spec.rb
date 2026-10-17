# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/markup'

# These behaviors had no coverage while they lived in global_defs.rb: that
# file cannot be required from a spec without redefining the script-facing
# DSL against production game infrastructure (see the note atop
# spec/lib/global_defs_spec.rb). Extracting the module is what makes them
# reachable.
RSpec.describe Lich::Common::Markup do
  before do
    $sftowiz_multiline = nil
    $strip_xml_multiline = {}
    $link_highlight_start = ''
    $link_highlight_end = ''
    $speech_highlight_start = ''
    $speech_highlight_end = ''
  end

  describe '.fb_to_sf' do
    it 'passes a bare newline through untouched' do
      expect(described_class.fb_to_sf("\r\n")).to eq("\r\n")
    end

    it 'strips the <c> marker' do
      expect(described_class.fb_to_sf("<c>look\r\n")).to eq("look\r\n")
    end

    it 'returns nil when only line endings remain' do
      expect(described_class.fb_to_sf("<c>\r\n")).to be_nil
    end
  end

  describe '.strip_xml' do
    it 'removes tags and decodes entities' do
      expect(described_class.strip_xml("<b>a &amp; b</b>\r\n")).to eq("a & b\r\n")
    end

    it 'returns nil for a bare newline' do
      expect(described_class.strip_xml("\r\n")).to be_nil
    end

    it 'returns nil when stripping leaves only whitespace' do
      expect(described_class.strip_xml("<pushBold/><popBold/>\r\n")).to be_nil
    end

    it 'drops streams presented elsewhere in the frontend' do
      line = %(<pushStream id="inv"/>a sack<popStream/>kept\r\n)
      expect(described_class.strip_xml(line)).to eq("kept\r\n")
    end

    it 'drops paired data elements with their content' do
      expect(described_class.strip_xml("<right>sword</right>kept\r\n")).to eq("kept\r\n")
    end

    context 'with a multiline type' do
      it 'buffers an unbalanced pushStream and strips once it closes' do
        expect(described_class.strip_xml(%(<pushStream id="talk"/>partial), type: 'main')).to be_nil
        expect(described_class.strip_xml("<popStream/>done\r\n", type: 'main')).to eq("done\r\n")
      end

      it 'keeps buffers for different types independent' do
        described_class.strip_xml(%(<pushStream id="a"/>one), type: 'first')
        expect(described_class.strip_xml("plain\r\n", type: 'second')).to eq("plain\r\n")
        expect($strip_xml_multiline['first']).to include('one')
      end

      it 'clears the buffer after a balanced line' do
        described_class.strip_xml(%(<pushStream id="talk"/>x), type: 'main')
        described_class.strip_xml("<popStream/>y\r\n", type: 'main')
        expect($strip_xml_multiline['main']).to be_nil
      end
    end
  end

  describe '.sf_to_wiz' do
    it 'passes a bare newline through untouched' do
      expect(described_class.sf_to_wiz("\r\n")).to eq("\r\n")
    end

    it 'converts bold markers to GSL escapes' do
      expect(described_class.sf_to_wiz("<pushBold/>orc<popBold/>\r\n"))
        .to eq("\034GSL\r\norc\034GSM\r\n\r\n")
    end

    it 'rewrites a thoughts stream into ESP prose' do
      line = %(<pushStream id="thoughts"/>[General] Someone: "hi"<popStream/>\r\n)
      expect(described_class.sf_to_wiz(line))
        .to include('You hear the faint thoughts of [General]-ESP echo in your mind:')
    end

    # Regression: the channel and the message must both be bound before
    # either is rewritten. gsub runs a match of its own, which resets $~, so
    # reading $2 after calling gsub on $1 yields nil -- and the rescue in
    # sf_to_wiz turns the resulting NoMethodError into a silently dropped
    # line. A multi-word channel is what forces the rewrite to happen.
    it 'hyphenates a multi-word thought channel and keeps the message' do
      line = %(<pushStream id="thoughts"/>[Rogue Guild] A: "x"<popStream/>\r\n)
      result = described_class.sf_to_wiz(line)
      expect(result).to include('[Rogue-Guild]-ESP')
      expect(result).to include('A: "x"')
    end

    it 'strips bold markers from inside a thought message' do
      line = %(<pushStream id="thoughts"/>[Gen] <pushBold/>A<popBold/>: "x"<popStream/>\r\n)
      result = described_class.sf_to_wiz(line)
      expect(result).to include('A: "x"')
      expect(result).not_to include('GSL')
    end

    it 'rewrites a Voln stream' do
      line = %(<pushStream id="voln"/>[Voln - Bob] "greetings"<popStream/>\r\n)
      expect(described_class.sf_to_wiz(line))
        .to include('The Symbol of Thought begins to burn in your mind and you hear Bob thinking, "greetings"')
    end

    it 'wraps a death stream in its GSL channel' do
      line = %(<pushStream id="death"/>Bob just died!<popStream/>\r\n)
      expect(described_class.sf_to_wiz(line))
        .to eq("\034GSw00003\r\nBob just died!\034GSw00004\r\n\r\n")
    end

    it 'wraps a room name in its GSL channel' do
      line = %(<style id="roomName" />[Town Square]<style id=""/>\r\n)
      expect(described_class.sf_to_wiz(line))
        .to eq("\034GSo\r\n[Town Square]\034GSp\r\n\r\n")
    end

    # The highlight markers land inside the description, but the generic
    # tag sweep at the end of sf_to_wiz removes anything angle-bracketed --
    # so a marker has to be non-tag-shaped to survive. That is existing
    # behavior, pinned here so the ordering is not changed by accident.
    it 'applies link highlights inside a room description' do
      $link_highlight_start = '>>'
      $link_highlight_end = '<<'
      line = %(<style id="roomDesc"/>You see a <a exist="1">door</a>.<style id=""/>\r\n)
      expect(described_class.sf_to_wiz(line)).to include('You see a >>door<<.')
    end

    it 'applies speech highlights' do
      $speech_highlight_start = '['
      $speech_highlight_end = ']'
      expect(described_class.sf_to_wiz(%(<preset id='speech'>hello</preset>\r\n)))
        .to eq("[hello]\r\n")
    end

    it 'decodes entities' do
      expect(described_class.sf_to_wiz("a &amp; b &lt;c&gt;\r\n")).to eq("a & b <c>\r\n")
    end

    it 'returns nil when nothing printable remains' do
      expect(described_class.sf_to_wiz("<prompt>&gt;</prompt>\r\n")).to be_nil
    end

    context 'buffering split elements' do
      it 'holds an unbalanced pushStream until it closes' do
        expect(described_class.sf_to_wiz(%(<pushStream id="death"/>Bob))).to be_nil
        expect(described_class.sf_to_wiz("just died!<popStream/>\r\n"))
          .to eq("\034GSw00003\r\nBobjust died!\034GSw00004\r\n\r\n")
      end

      it 'holds an unbalanced style element until it closes' do
        expect(described_class.sf_to_wiz(%(<style id="roomName" />[Town))).to be_nil
        expect(described_class.sf_to_wiz(%( Square]<style id=""/>\r\n)))
          .to eq("\034GSo\r\n[Town Square]\034GSp\r\n\r\n")
      end

      it 'bypasses the buffer when asked' do
        described_class.sf_to_wiz(%(<pushStream id="death"/>stuck))
        expect(described_class.sf_to_wiz("plain\r\n", bypass_multiline: true)).to eq("plain\r\n")
      end
    end
  end

  # Pre-existing behavior relocated by the extraction, previously unpinned.
  # The rescue exists so a malformed line can never take down the read loop:
  # it reports and drops the line rather than raising into the caller. The
  # return must be nil specifically -- callers feed it to String#split, which
  # NilClass#split makes safe (lib/common/class_exts/nilclass.rb).
  describe 'the rescue path' do
    # The shared $_CLIENT_ from spec_helper has no public #puts and
    # report_error calls one, so swap in a collector for the duration rather
    # than adding a singleton to the global object other specs rely on. A
    # plain object, not an rspec double: the swap happens in an around hook,
    # which runs outside the per-test mock lifecycle.
    let(:client) do
      Object.new.tap do |obj|
        obj.instance_variable_set(:@lines, [])
        def obj.puts(line) = @lines << line
        def obj.lines = @lines
      end
    end

    around do |example|
      previous = $_CLIENT_
      $_CLIENT_ = client
      example.run
    ensure
      $_CLIENT_ = previous
    end

    before { allow(Lich).to receive(:log) }

    # The failure is forced rather than provoked by a crafted input: these are
    # pure string ops with no naturally-reachable failure, so the honest way
    # to pin the handler is to make a call inside the body raise. Unary + is
    # required because this file is frozen_string_literal and a frozen string
    # cannot take the singleton that stubbing #gsub defines.
    let(:line) { +"text\r\n" }

    it 'reports and returns nil when fb_to_sf raises' do
      allow(line).to receive(:gsub).and_raise(StandardError, 'boom')
      expect(described_class.fb_to_sf(line)).to be_nil
      expect(client.lines).to include(a_string_matching(/Error: fb_to_sf/))
    end

    it 'reports and returns nil when sf_to_wiz raises' do
      allow(line).to receive(:gsub).and_raise(StandardError, 'boom')
      expect(described_class.sf_to_wiz(line)).to be_nil
      expect(client.lines).to include(a_string_matching(/Error: sf_to_wiz/))
    end

    it 'does not let the error escape to the caller' do
      allow(line).to receive(:gsub).and_raise(StandardError, 'boom')
      expect { described_class.fb_to_sf(line) }.not_to raise_error
    end
  end

  describe '.monsterbold_start / .monsterbold_end' do
    # Markup calls ::Frontend explicitly, so stub the methods on that exact
    # object. Replacing the constant with stub_const is not enough: whether
    # the real ::Frontend already exists depends on which specs ran first,
    # and once it does, a constant stub on a different object is ignored.
    before do
      stub_const('Frontend', Module.new) unless defined?(::Frontend)
      allow(::Frontend).to receive(:supports_gsl?).and_return(false)
      allow(::Frontend).to receive(:supports_xml?).and_return(false)
    end

    it 'emits GSL escapes for a GSL frontend' do
      allow(::Frontend).to receive(:supports_gsl?).and_return(true)
      expect(described_class.monsterbold_start).to eq("\034GSL\r\n")
      expect(described_class.monsterbold_end).to eq("\034GSM\r\n")
    end

    it 'emits bold tags for an XML frontend' do
      allow(::Frontend).to receive(:supports_xml?).and_return(true)
      expect(described_class.monsterbold_start).to eq('<pushBold/>')
      expect(described_class.monsterbold_end).to eq('<popBold/>')
    end

    it 'emits nothing for a plain frontend' do
      expect(described_class.monsterbold_start).to eq('')
      expect(described_class.monsterbold_end).to eq('')
    end
  end
end

# DragonRealms' Saga-identity stream links objects and doubles the bold around
# linked creatures; the legacy stream did neither. Shapes are verbatim from
# the stream (names pseudonymized).
RSpec.describe Lich::Common::Markup, 'legacy line shape' do
  describe '.strip_game_links' do
    it 'removes an object link, keeping its text' do
      expect(described_class.strip_game_links(%(Also here: Universalist <a exist="-10700003" noun="Corwin">Corwin</a>.\r\n)))
        .to eq("Also here: Universalist Corwin.\r\n")
    end

    it 'removes every link in the string' do
      line = %(You also see a <a exist="195648374" noun="shield">morgawr leather shield</a> and a <a exist="1" noun="bar">brass bar</a>.)
      expect(described_class.strip_game_links(line)).to eq('You also see a morgawr leather shield and a brass bar.')
    end

    it 'removes a link inside a <d> command link, keeping the <d>' do
      line = %(<d cmd='look #195769088'><pushBold/>a <a exist="195769088" noun="moradu">jeol moradu</a><popBold/></d>)
      expect(described_class.strip_game_links(line)).to eq(%(<d cmd='look #195769088'><pushBold/>a jeol moradu<popBold/></d>))
    end

    it "accepts single-quoted attributes and exist after another attribute" do
      expect(described_class.strip_game_links(%(<a noun='bar' exist='1'>bar</a>))).to eq('bar')
    end

    # dr-scripts' textsubs injects <a href> from a downstream hook.
    it 'keeps a script link and its end tag, around or inside a game link' do
      expect(described_class.strip_game_links(%(<a href="x">see the <a exist="1" noun="bar">bar</a></a>)))
        .to eq(%(<a href="x">see the bar</a>))
      expect(described_class.strip_game_links(%(<a exist="1" noun="bar">a <a href="x">brass</a> bar</a>)))
        .to eq(%(a <a href="x">brass</a> bar))
    end

    it 'keeps an </a> that closes nothing opened in the string' do
      expect(described_class.strip_game_links(%(bar</a> and <a exist="2" noun="rock">rock</a>))).to eq('bar</a> and rock')
    end

    it 'leaves other elements whose name starts with a alone' do
      expect(described_class.strip_game_links(%(<abbr exist="1">x</abbr> <a exist="1" noun="x">x</a>))).to eq(%(<abbr exist="1">x</abbr> x))
      # Inside a link too: the link's </a> still closes the link.
      expect(described_class.strip_game_links(%(<a exist="1" noun="x"><abbr>x</abbr></a>))).to eq(%(<abbr>x</abbr>))
    end

    it 'returns a string without a game link unchanged, as the same object' do
      line = +%(<a href="x">bar</a> exist=1\r\n)
      expect(described_class.strip_game_links(line)).to equal(line)
    end
  end

  describe '.strip_link_bold' do
    # Verbatim shapes from dr_saga_hunt.xml; the legacy stream sends these
    # names plain (dr_legacy_hunt.xml:135-137 for assess).
    it 'removes the single bold around a linked creature in an action line, keeping the link' do
      line = %(The <pushBold/><a exist="195762664" noun="moradu">jeol moradu</a><popBold/> moves into a position to parry.)
      expect(described_class.strip_link_bold(line)).to eq(%(The <a exist="195762664" noun="moradu">jeol moradu</a> moves into a position to parry.))
    end

    it 'removes it with the article inside the bold, and around a linked pronoun' do
      line = %(Appearing to have lost sight of <pushBold/><a exist="1" noun="moradu">its</a><popBold/> target, <pushBold/>a <a exist="1" noun="moradu">jeol moradu</a><popBold/> stops advancing.)
      expect(described_class.strip_link_bold(line))
        .to eq(%(Appearing to have lost sight of <a exist="1" noun="moradu">its</a> target, a <a exist="1" noun="moradu">jeol moradu</a> stops advancing.))
    end

    it 'removes it inside an assess <d> command link' do
      line = %(<d cmd='look #195758165'><pushBold/>A <a exist="195758165" noun="moradu">jeol moradu</a><popBold/></d> (1: cursed) is flanking you.)
      expect(described_class.strip_link_bold(line)).to eq(%(<d cmd='look #195758165'>A <a exist="195758165" noun="moradu">jeol moradu</a></d> (1: cursed) is flanking you.))
    end

    it 'keeps the doubled bold of a room-object listing' do
      line = %(<component id='room objs'>You also see <pushBold/><pushBold/>a <a exist="1" noun="moradu">jeol moradu</a><popBold/><popBold/>.</component>)
      expect(described_class.strip_link_bold(line)).to equal(line)
    end

    # The legacy stream bolds whole combat damage lines; one with more text
    # than an article and a link inside the bold keeps it.
    it 'keeps a bold that holds more than an article and one link' do
      line = %(<pushBold/>The <a exist="1" noun="moradu">jeol moradu</a> lands a heavy hit.  <popBold/>)
      expect(described_class.strip_link_bold(line)).to equal(line)
      two = %(<pushBold/><a exist="1" noun="a">a</a> and <a exist="2" noun="b">b</a><popBold/>)
      expect(described_class.strip_link_bold(two)).to equal(two)
    end

    it 'keeps a bold around a script link or plain text' do
      line = %(<pushBold/>a <a href="x">jeol moradu</a><popBold/> and <pushBold/>a jeol moradu<popBold/>)
      expect(described_class.strip_link_bold(line)).to equal(line)
    end

    it 'returns a string without such a bold unchanged, as the same object' do
      line = +%(<pushBold/>A jeol moradu<popBold/> gestures.\r\n)
      expect(described_class.strip_link_bold(line)).to equal(line)
    end
  end

  describe '.collapse_double_bold' do
    it 'collapses the doubled bold around a linked creature to one pair' do
      line = %(You also see <pushBold/><pushBold/>a <a exist="1" noun="moradu">jeol moradu</a><popBold/><popBold/>, an ice-edged sword.)
      expect(described_class.collapse_double_bold(line))
        .to eq(%(You also see <pushBold/>a <a exist="1" noun="moradu">jeol moradu</a><popBold/>, an ice-edged sword.))
    end

    it 'returns a string without doubled bold unchanged, as the same object' do
      line = +%(<pushBold/>A jeol moradu<popBold/> gestures.\r\n)
      expect(described_class.collapse_double_bold(line)).to equal(line)
    end
  end

  # Fixture-backed: the transforms must turn the rich captures into lines the
  # legacy captures actually contain, and leave nothing of either feature.
  describe 'on the committed DragonRealms captures' do
    root = File.expand_path('../../..', __dir__)
    read = ->(glob) { Dir[File.join(root, glob)].flat_map { |f| File.readlines(f, chomp: true) } }
    no_time = ->(line) { line.gsub(/time="\d+"/, 'time="T"') }
    legacy = (read.call('spec/fixtures/streams/dr_legacy_*.xml') + read.call('benchmark/fixtures/dr_{sample,inventory_sample}.xml')).to_set { |l| no_time.call(l) }
    rich = read.call('spec/fixtures/streams/dr_saga_*.xml').select { |l| l.include?('<a exist') || l.include?('<pushBold/><pushBold/>') }
    legacy_shape = ->(l) { described_class.collapse_double_bold(described_class.strip_game_links(described_class.strip_link_bold(l))) }
    let(:shaped) { rich.map { |l| no_time.call(legacy_shape.call(l)) } }
    # A single bold pair holding a game link and no other bold.
    link_bold = %r{(?<!<pushBold/>)<pushBold/>(?:(?!<pushBold/>|<popBold/>).)*?<a\s[^>]*exist=(?:(?!<pushBold/>|<popBold/>).)*?<popBold/>(?!<popBold/>)}

    it 'leaves no game link and no doubled bold' do
      expect(rich.size).to be > 800
      expect(shaped.grep(/<a exist|<pushBold\/><pushBold\/>|<popBold\/><popBold\/>/)).to be_empty
    end

    # 217 single bold pairs around a linked creature, all in action and
    # assess lines (room-object listings double theirs).
    it 'leaves no single bold around a linked creature, and keeps every doubled one for collapsing' do
      spans = rich.sum { |l| l.scan(link_bold).size }
      expect(spans).to be > 200
      expect(rich.sum { |l| described_class.strip_link_bold(l).scan(link_bold).size }).to eq(0)
      expect(rich.sum { |l| described_class.strip_link_bold(l).scan('<pushBold/><pushBold/>').size }).to eq(rich.sum { |l| l.scan('<pushBold/><pushBold/>').size })
    end

    it 'changes no line of the legacy captures' do
      legacy_lines = read.call('spec/fixtures/streams/dr_legacy_*.xml') + read.call('benchmark/fixtures/dr_{sample,inventory_sample}.xml')
      expect(legacy_lines.reject { |l| described_class.strip_link_bold(l).equal?(l) }).to be_empty
    end

    # Of the 928 rich lines, 460 (46 distinct) were legacy lines byte for byte
    # with the links stripped and the doubled bold collapsed; also removing
    # the creature bold makes it 569 (68 distinct), and loses none.
    it 'reproduces legacy lines byte for byte' do
      expect(rich.count { |l| legacy.include?(no_time.call(l)) }).to eq(0)
      expect(shaped.uniq.count { |l| legacy.include?(l) }).to be >= 68
      expect(shaped.count { |l| legacy.include?(l) }).to be >= 569
      without_link_bold = rich.map { |l| no_time.call(described_class.collapse_double_bold(described_class.strip_game_links(l))) }
      expect(without_link_bold.each_index.select { |i| legacy.include?(without_link_bold[i]) && !legacy.include?(shaped[i]) }).to be_empty
    end

    # Genie4 counts creatures with one bold pair per creature over the room
    # objs component as .NET serializes it (Core/Game.cs CountMonsters).
    it 'lets a one-pair-per-creature matcher find every bold creature in room objs' do
      monster = %r{<pushBold />([^<]*)<popBold />([^,.]*)}
      genie_count = lambda do |line|
        inner = line[%r{<component id='room objs'>(.*?)</component>}, 1].to_s.gsub('<pushBold/>', '<pushBold />').gsub('<popBold/>', '<popBold />')
        inner.gsub(' and ', ', ').scan(monster).size
      end
      objs = rich.grep(/<component id='room objs'>.*<pushBold/)
      creatures = objs.sum { |l| l[%r{<component id='room objs'>(.*?)</component>}, 1].scan('<pushBold/><pushBold/>').size }
      expect(creatures).to be > 30
      expect(objs.sum { |l| genie_count.call(l) }).to eq(0)
      expect(objs.sum { |l| genie_count.call(legacy_shape.call(l)) }).to eq(creatures)
    end
  end
end
