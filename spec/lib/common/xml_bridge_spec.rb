# frozen_string_literal: true

require_relative '../../spec_helper'
require 'rexml/document'
require 'common/xml_bridge'

# Records the REXML-style stream callbacks the bridge is expected to emit. Used
# for both Ox (via the bridge) and REXML. Note: do NOT include
# REXML::StreamListener -- its no-op defaults would shadow these methods, and
# REXML.parse_stream calls whatever the listener responds to regardless.
class RecordingListener
  attr_reader :events

  def initialize
    @events = []
  end

  def tag_start(name, attributes)
    @events << [:start, name, attributes.to_h]
  end

  def text(value)
    @events << [:text, value]
  end

  def tag_end(name)
    @events << [:end, name]
  end
end

RSpec.describe Lich::Common::OxStreamBridge do
  def ox_events(fragment)
    listener = RecordingListener.new
    Ox.sax_parse(described_class.new(listener), "<root>#{fragment}</root>",
                 convert_special: true, symbolize: false, skip: :skip_none)
    listener.events
  end

  def rexml_events(fragment)
    listener = RecordingListener.new
    REXML::Document.parse_stream("<root>#{fragment}</root>", listener)
    listener.events
  end

  it 'emits tag_start with a string-keyed attribute hash' do
    events = ox_events(%(<a exist="123" noun="sword">a fine sword</a>))
    expect(events).to include([:start, 'a', { 'exist' => '123', 'noun' => 'sword' }])
  end

  it 'fires tag_start for attribute-less and self-closing tags' do
    events = ox_events('<pushBold/>hi<popBold/>')
    expect(events).to eq([
                           [:start, 'root', {}],
                           [:start, 'pushBold', {}], [:end, 'pushBold'],
                           [:text, 'hi'],
                           [:start, 'popBold', {}], [:end, 'popBold'],
                           [:end, 'root']
                         ])
  end

  it 'decodes entities in text' do
    events = ox_events('<prompt>&gt;</prompt>')
    expect(events).to include([:text, '>'])
  end

  it 'returns UTF-8 text matching REXML (not Ox-default ASCII-8BIT)' do
    fragment = '<component id="room desc">a caf&#233; in the corner</component>'
    text = ox_events(fragment).find { |e| e[0] == :text }[1]
    expect(text.encoding).to eq(Encoding::UTF_8)
    expect(text).to eq('a caf' + [233].pack('U') + ' in the corner') # cafe-with-accent
    # and it concatenates cleanly into a UTF-8 buffer (the XMLData.text pattern)
    expect { (+'desc: ').concat(text) }.not_to raise_error
  end

  it 'parses multiple top-level elements without a root wrapper' do
    # process_xml_data feeds the raw server string (often several top-level
    # elements, or bare text) directly -- no <root> wrapper, unlike REXML.
    listener = RecordingListener.new
    Ox.sax_parse(described_class.new(listener),
                 '<pushStream id="combat"/><pushBold/>You swing!<popBold/><popStream/>',
                 convert_special: true, symbolize: false, skip: :skip_none)
    expect(listener.events).to eq([
                                    [:start, 'pushStream', { 'id' => 'combat' }], [:end, 'pushStream'],
                                    [:start, 'pushBold', {}], [:end, 'pushBold'],
                                    [:text, 'You swing!'],
                                    [:start, 'popBold', {}], [:end, 'popBold'],
                                    [:start, 'popStream', {}], [:end, 'popStream']
                                  ])
  end

  it 'passes element names to tag_end as strings' do
    events = ox_events('<dialogData id="minivitals"></dialogData>')
    expect(events).to include([:start, 'dialogData', { 'id' => 'minivitals' }], [:end, 'dialogData'])
  end

  describe 'equivalence with REXML (ignoring REXML trailing-whitespace text nodes)' do
    # Trailing whitespace after the final close tag: REXML emits an extra text
    # node, Ox does not. XMLData ignores it, so strip those for comparison.
    def normalize(events)
      events.reject { |e| e[0] == :text && e[1].strip.empty? }
    end

    [
      %(<streamWindow id='room' title='Room' subtitle=" - [Town Square]"/>\r\n),
      %(<component id='room objs'>You also see a <a exist="1" noun="gem">gem</a>.</component>\r\n),
      %(<dialogData id='minivitals'><progressBar id='health' value='100' text='health 100%'/></dialogData>\r\n),
      %(  ... and hits for 47 points of damage!\r\n)
    ].each do |fragment|
      it "matches REXML for: #{fragment[0, 40].strip}" do
        expect(normalize(ox_events(fragment))).to eq(normalize(rexml_events(fragment)))
      end
    end
  end
end
