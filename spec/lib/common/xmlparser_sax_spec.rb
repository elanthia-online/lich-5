# frozen_string_literal: true

require_relative '../../spec_helper'
require 'ox'
require 'common/xmlparser'

# XMLData (Lich::Common::XMLParser) implements the Ox::Sax interface directly, so
# Ox parses the server stream straight into it (no separate bridge object). These
# specs verify the SAX callbacks translate to the REXML-style tag_start/text/
# tag_end the rest of the parser is built on, and that the Windows-1252 game
# stream is tagged correctly.
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

  def parse(handler, fragment)
    Ox.sax_parse(handler, fragment, convert_special: true, symbolize: false, skip: :skip_none)
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

  it 'decodes entities in text' do
    rec = recorder_class.new
    texts = []
    rec.define_singleton_method(:text) { |v| texts << v }
    parse(rec, '<prompt>&gt;</prompt>')
    expect(texts).to include('>')
  end

  it 'tags attribute values as Windows-1252 (the stream encoding)' do
    rec = recorder_class.new
    def rec.text(_value); end
    smart = 146.chr # 0x92 == right single quote in Windows-1252
    parse(rec, "<a noun='Tsetem#{smart}s'>x</a>".b)
    attrs = rec.events.find { |e| e[0] == :start && e[1] == 'a' }[2]
    expect(attrs['noun'].encoding).to eq(Encoding::WINDOWS_1252)
    expect(attrs['noun'].bytes).to eq('Tsetem'.bytes + [146] + 's'.bytes)
  end

  it 'tags text as Windows-1252 and routes it through the real handler' do
    xml = Lich::Common::XMLParser.new
    smart = 146.chr
    # <spell> text sets prepared_spell, a simple readable field
    parse(xml, "<spell>Pal#{smart}din</spell>".b)
    expect(xml.prepared_spell.encoding).to eq(Encoding::WINDOWS_1252)
    expect(xml.prepared_spell.bytes).to eq('Pal'.bytes + [146] + 'din'.bytes)
  end
end
