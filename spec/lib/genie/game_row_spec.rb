# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Game.ParseGameRow's character loop (Game.cs:567-860 R) and the XmlDocument view of one
# buffer (Game.cs:950-965 R). End-to-end goldens over real rows: game_state_spec and the
# genieflow flow fixtures t86/t87.
RSpec.describe Lich::Genie::GameRow do
  describe Lich::Genie::GameRow::Scanner do
    subject(:scanner) { described_class.new }

    def events(row)
      out = []
      scanner.scan(row) { |kind, payload| out << [kind, payload] }
      out
    end

    it 'cuts one buffer per depth-0 element, text before it handed on first' do
      expect(events("a<b x='1'/>c<d>e<f/>g</d>\r\n"))
        .to eq([[:text, 'a'], [:xml, "<b x='1'/>"], [:text, 'c'], [:xml, '<d>e<f/>g</d>'], [:text, "\r\n"]])
    end

    it 'reports whether the row had any XML' do
      expect(scanner.scan("plain\r\n") { |*| nil }).to be(false)
      expect(scanner.scan("<x/>\r\n") { |*| nil }).to be(true)
    end

    it 'passes a short entity into XML raw and translates it in text (Utility.TranslateHTMLChar)' do
      expect(events('<p>&gt;</p>&lt;&amp;&quot;&nbsp;&apos;')).to eq([[:xml, '<p>&gt;</p>'], [:text, %(<&" )]])
    end

    it 'aborts an entity longer than 6 characters: its & escaped inside XML, its ; dropped' do
      expect(events('<p>wait&hellip; done</p>')).to eq([[:xml, '<p>wait&amp;hellip done</p>']])
      expect(events('wait&hellip; done')).to eq([[:text, 'wait&hellip done']])
    end

    it 'drops every ; outside an entity, in text and inside XML' do
      expect(events('a; b<p>c;d</p>')).to eq([[:text, 'a b'], [:xml, '<p>cd</p>']])
    end

    it 'loses a short & tail at the end of the row (the entity buffer is never flushed)' do
      expect(events('Tom & Al')).to eq([[:text, 'Tom ']])
    end

    it 'skips the GSL char 28 and nothing else' do
      expect(events("a#{28.chr}b")).to eq([[:text, 'ab']])
    end

    it 'rewrites every "< " of a row that starts with one, then "> " only if the row still starts with it' do
      # Game.cs:582-591 R: the second test runs on the rewritten row, so "> " survives here
      # and the bare '>' at depth 0 is a one-character buffer XmlDocument reads as text.
      expect(events('< x > y <b/>')).to eq([[:text, '< x '], [:xml, '>'], [:text, ' y '], [:xml, '<b/>']])
      expect(events('> a > b')).to eq([[:text, '> a > b']])
      expect(events('x < y <b/>')).to eq([[:text, 'x ']]) # no rewrite: "< y <b/>" stays open
    end

    it 'carries an element left open at row end into the next row, replacing (not appending to) the carry' do
      expect(events('<a>one')).to eq([])
      expect(events('<b>two')).to eq([]) # replaces "<a>one"
      # depth restarts at 0 per row: "</b>" ends at depth -1, which is not > 0, so the
      # carry plus this row is processed (Game.cs:833-850 R) -- as the row-end remainder, which
      # ParseGameRow appends with no stream flush / roomDesc / bold check
      expect(events('</b>')).to eq([[:xml_end, '<b>two</b>']])
      expect(events("<c/>\r\n")).to eq([[:xml, '<c/>'], [:text, "\r\n"]])
    end
  end

  describe Lich::Genie::GameRow::Fragment do
    def parse(xml) = described_class.parse(xml)

    it 'gives InnerText with entities decoded, attributes by name, "" for a missing one' do
      root = parse(%(<left exist="41807070" noun='sword'>steel &amp; &#65;&#x42; sword</left>))
      left = root.elements.first
      expect([left.name, left.attr('exist'), left.attr('noun'), left.attr('missing'), left.inner_text])
        .to eq(['left', '41807070', 'sword', '', 'steel & AB sword'])
    end

    it 'serializes InnerXml the XmlDocument way (empty element " />", double quotes, & < > escaped)' do
      node = parse(%(<c id='room objs'>You see <pushBold/>Tom &amp; Jerry<popBold/> <d cmd='x "y"'>a &gt; b</d></c>)).elements.first
      # Probed on .NET 8: the whitespace-only " " before <d> is dropped.
      expect(node.inner_xml).to eq('You see <pushBold />Tom &amp; Jerry<popBold /><d cmd="x &quot;y&quot;">a &gt; b</d>')
    end

    it 'drops whitespace-only text nodes (PreserveWhitespace=false) but keeps mixed text' do
      node = parse('<c><b/> <i/>  x </c>').elements.first
      expect(node.children.map { |c| c.is_a?(String) ? c : c.name }).to eq(['b', 'i', '  x '])
    end

    it 'keeps an explicitly closed empty element non-empty in InnerXml' do
      expect(parse('<c><b></b></c>').elements.first.inner_xml).to eq('<b></b>')
    end

    it 'keeps CR/LF in text and tabs in attribute values as sent (probed on .NET 8)' do
      node = parse(%(<c a="x\ty">l1\r\nl2\rl3</c>)).elements.first
      expect([node.attr('a'), node.inner_text]).to eq(["x\ty", "l1\r\nl2\rl3"])
    end

    it "decodes &apos; and leaves an apostrophe unescaped when serializing (probed on .NET 8)" do
      node = parse(%(<w><c a='it&apos;s &lt;'/>&apos;n&apos;</w>)).elements.first
      expect([node.inner_xml, node.inner_text]).to eq([%(<c a="it's &lt;" />'n'), "'n'"])
    end

    it 'returns nil wherever XmlDocument throws' do
      ['<c>&nbsp;</c>', '<c>a & b</c>', '<c>', '<c></d>', '</c>', '<c a="1" a="2"/>', '<c a=1/>',
       '<1c/>', '<c a="<"/>', '<c', '<c>&#xZZ;</c>', '<c>&#0;</c>', '<c>&#xD800;</c>', '<c>&#x110000;</c>'].each do |bad|
        expect(parse(bad)).to be_nil, bad
      end
    end

    it 'links each element to its parent (the <dir> handler checks for a <compass> parent)' do
      dir = parse('<compass><dir value="n"/></compass>').elements.first.elements.first
      expect(dir.parent.name).to eq('compass')
    end
  end
end
