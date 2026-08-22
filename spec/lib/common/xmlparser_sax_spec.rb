# frozen_string_literal: true

require_relative '../../spec_helper'
require 'ox'
require 'common/xmlparser'

# XMLData (Lich::Common::XMLParser) implements the Ox::Sax interface directly, so
# Ox parses the server stream straight into it (no separate bridge object). These
# specs verify the SAX callbacks translate to the REXML-style tag_start/text/
# tag_end the rest of the parser is built on, that the standard XML entities are
# decoded (Ox runs with convert_special: false), and that attr/text values --
# which Ox hands back tagged ASCII-8BIT even though the fragment handed to it is
# already real UTF-8 (see Game.process_xml_data / WireEncoding.decode) -- are
# retagged to UTF-8 (see XMLParser#retag_ox_utf8!) before anything downstream
# (fake tags, XmlEntities.decode) treats them as text.
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

  # Regression: reviewer-flagged P1. Game.process_xml_data only ever hands Ox an
  # already-UTF-8-decoded server line (read_server_string runs WireEncoding.decode
  # first), so a real Windows-1252-representable character reaches these callbacks
  # as genuine multibyte UTF-8 bytes -- e.g. U+2019 (right single quote) as
  # "\xE2\x80\x99" -- merely mistagged ASCII-8BIT by Ox. Before the retag fix,
  # WireEncoding.encode's codepoint-by-codepoint walk (used by the spell/right/left
  # fake tags) would treat those three raw bytes as three separate codepoints
  # instead of the one real U+2019, corrupting it to "?" bytes on the wire.
  it 'retags attribute values to UTF-8 so a real multibyte character round-trips to its single Windows-1252 byte' do
    rec = recorder_class.new
    def rec.text(_value); end
    smart = "’" # rubocop:disable Custom/AsciiOnlySource
    parse(rec, "<a noun='Tsetem#{smart}s'>x</a>")
    attrs = rec.events.find { |e| e[0] == :start && e[1] == 'a' }[2]
    expect(attrs['noun']).to eq("Tsetem#{smart}s")
    expect(attrs['noun'].encoding).to eq(Encoding::UTF_8)
    expect(Lich::Common::WireEncoding.encode(attrs['noun'])).to eq("Tsetem\x92s".b) # rubocop:disable Custom/AsciiOnlySource
  end

  it 'retags text to UTF-8 so a real multibyte character round-trips to its single Windows-1252 byte (the exact Pal\'din/Membrach\'s Greed repro)' do
    xml = Lich::Common::XMLParser.new
    smart = "’" # rubocop:disable Custom/AsciiOnlySource
    # <spell> text sets prepared_spell, a simple readable field
    parse(xml, "<spell>Pal#{smart}din</spell>")
    expect(xml.prepared_spell).to eq("Pal#{smart}din")
    expect(xml.prepared_spell.encoding).to eq(Encoding::UTF_8)
    expect(Lich::Common::WireEncoding.encode(xml.prepared_spell)).to eq("Pal\x92din".b) # rubocop:disable Custom/AsciiOnlySource
  end

  it 'scrubs a genuinely invalid/truncated UTF-8 byte sequence rather than raising' do
    rec = recorder_class.new
    def rec.text(_value); end
    # A lone continuation byte (0x92) with no lead byte -- not valid UTF-8 under
    # any interpretation, unlike the real multibyte case above. This can only
    # happen on a truncated/desynced fragment (see check_stream_desync!).
    parse(rec, "<a noun='Tsetem#{146.chr}s'>x</a>".b)
    attrs = rec.events.find { |e| e[0] == :start && e[1] == 'a' }[2]
    expect(attrs['noun']).to eq('Tsetem?s')
    expect(attrs['noun'].valid_encoding?).to be true
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
