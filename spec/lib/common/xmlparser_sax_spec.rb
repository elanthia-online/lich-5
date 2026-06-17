# frozen_string_literal: true

require_relative '../../spec_helper'
require 'ox'
require 'common/xmlparser'

# XMLData (Lich::Common::XMLParser) implements the Ox::Sax interface directly, so
# Ox parses the server stream straight into it (no separate bridge object). These
# specs verify the SAX callbacks translate to the REXML-style tag_start/text/
# tag_end the rest of the parser is built on, that the standard XML entities are
# decoded (Ox runs with convert_special: false), and that values are left in Ox's
# native encoding (REXML produced UTF-8/ASCII for this stream; retagging was a
# divergence).
RSpec.describe 'Lich::Common::XMLParser Ox SAX interface' do
  # Records how start_element/attr/attrs_done/text/end_element are translated.
  let(:recorder_class) do
    Class.new(Lich::Common::XMLParser) do
      attr_reader :events

      def initialize
        super
        @events = []
      end

      def tag_start(name, attributes)
        @events << [:start, name, attributes.to_h]
      end

      def tag_end(name)
        @events << [:end, name]
      end
    end
  end

  # Mirror production (Game.process_xml_data): convert_special: false so Ox never
  # turns a numeric entity into UTF-8; XMLData decodes the standard entities itself.
  def parse(handler, fragment)
    Ox.sax_parse(handler, fragment, convert_special: false, symbolize: false, skip: :skip_none)
  end

  it 'accumulates attributes and flushes them to tag_start' do
    rec = recorder_class.new
    # tag_start records, but text still runs the real handler; capture just structure
    def rec.text(_value); end
    parse(rec, '<a exist="123" noun="sword">a fine sword</a>')
    expect(rec.events).to include([:start, 'a', { 'exist' => '123', 'noun' => 'sword' }], [:end, 'a'])
  end

  it 'fires tag_start for attribute-less and self-closing tags, and parses multiple top-level elements' do
    rec = recorder_class.new
    def rec.text(_value); end
    parse(rec, '<pushStream id="combat"/><pushBold/>x<popBold/><popStream/>')
    expect(rec.events).to eq([
                               [:start, 'pushStream', { 'id' => 'combat' }], [:end, 'pushStream'],
                               [:start, 'pushBold', {}], [:end, 'pushBold'],
                               [:start, 'popBold', {}], [:end, 'popBold'],
                               [:start, 'popStream', {}], [:end, 'popStream']
                             ])
  end

  it 'decodes the five standard XML entities (Ox runs with convert_special: false)' do
    # &amp; is decoded last, so an encoded entity round-trips to its literal form
    # (&amp;gt; -> &gt;) rather than being double-decoded to >.
    decoded = Lich::Common::XmlEntities.decode(%q{&lt;b&gt; &amp; &quot;q&quot; it&apos;s &amp;gt;})
    expect(decoded).to eq(%q{<b> & "q" it's &gt;})
  end

  it 'routes decoded entities in text through the real handler' do
    xml = Lich::Common::XMLParser.new
    # <spell> text sets prepared_spell, a simple readable field
    parse(xml, '<spell>Cure &amp; Heal</spell>')
    expect(xml.prepared_spell).to eq('Cure & Heal')
  end

  it 'leaves attribute values in Ox native encoding with bytes intact' do
    rec = recorder_class.new
    def rec.text(_value); end
    smart = 146.chr # 0x92 == right single quote in Windows-1252, left untouched
    parse(rec, "<a noun='Tsetem#{smart}s'>x</a>".b)
    attrs = rec.events.find { |e| e[0] == :start && e[1] == 'a' }[2]
    expect(attrs['noun'].bytes).to eq('Tsetem'.bytes + [146] + 's'.bytes)
    expect(attrs['noun'].encoding).to eq(Encoding::ASCII_8BIT)
  end

  it 'leaves text in Ox native encoding with bytes intact' do
    xml = Lich::Common::XMLParser.new
    smart = 146.chr
    # <spell> text sets prepared_spell, a simple readable field
    parse(xml, "<spell>Pal#{smart}din</spell>".b)
    expect(xml.prepared_spell.bytes).to eq('Pal'.bytes + [146] + 'din'.bytes)
    expect(xml.prepared_spell.encoding).to eq(Encoding::ASCII_8BIT)
  end

  # Ox synthesizes an end for a stray closing tag (a close with no matching open,
  # e.g. a desynced </prompt>). tag_start never pushed it, so tag_end must ignore
  # it rather than popping the wrong tag or running end-handlers spuriously.
  it 'ignores a stray closing tag whose element was never opened' do
    xml = Lich::Common::XMLParser.new
    xml.instance_variable_set(:@last_tag, 'sentinel')
    parse(xml, '</prompt>')
    expect(xml.instance_variable_get(:@last_tag)).to eq('sentinel')
    expect(xml.instance_variable_get(:@active_tags)).to be_empty
  end

  it 'still processes a properly matched closing tag' do
    xml = Lich::Common::XMLParser.new
    parse(xml, '<spell>Fire</spell>')
    expect(xml.instance_variable_get(:@active_tags)).to be_empty
    expect(xml.instance_variable_get(:@last_tag)).to eq('spell')
  end
end
