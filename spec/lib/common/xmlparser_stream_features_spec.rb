# frozen_string_literal: true

require_relative '../../spec_helper'
require 'ox'
require 'common/gameobj'
require 'common/xmlparser'

# XMLParser#stream_feature? records which stream dialect the session is getting.
# On DragonRealms the Saga identity (Frontend::CLIENT_STRING since #1700) gets
# object links and the <room> block; front ends that send their own Wrayth
# handshake get the legacy stream, which has neither. Fragments follow the
# shapes in the DR captures under spec/fixtures/streams, with ids and text
# substituted. One shape is not in those captures: the URL <a href> line,
# which GemStone sends.
RSpec.describe 'Lich::Common::XMLParser stream features' do
  subject(:parser) { Lich::Common::XMLParser.new }

  def feed(*fragments)
    fragments.each do |fragment|
      Ox.sax_parse(parser, fragment, convert_special: false, symbolize: false, skip: :skip_none)
    end
  end

  it 'starts with no features' do
    expect(parser.stream_features).to eq([])
  end

  it 'observes nothing in legacy-dialect DR lines' do
    feed("<component id='room objs'>You also see <pushBold/>a jeol moradu<popBold/> (dead) and some junk.</component>",
         "<clearContainer id=\"stow\"/><inv id='stow'>In the pack:</inv><inv id='stow'> a soft gem pouch</inv>",
         "  <d cmd='remove #195648608'>a diacan lamellar helm</d>",
         '<right exist="195429158" noun="knackstone">heraldic knackstone</right>')

    expect(parser.stream_features).to eq([])
  end

  it 'observes :links from an <a exist> object link' do
    feed('<a exist="-10700003" noun="Brenna">Brenna</a> drums his fingers on his bucket rhythmically.')
    expect(parser.stream_feature?(:links)).to be true
  end

  it 'does not treat an <a> without exist (a URL link) as an object link' do
    feed('Visit <a href="https://www.play.net/">the website</a>.')
    expect(parser.stream_feature?(:links)).to be false
  end

  it 'takes room_name from the Saga <room><name> child, as from the legacy roomName style' do
    feed('<resource picture="0"/><room><name>[Bosque Deriel, Burial Ground] (230007)</name><description>D.</description></room>')
    expect(parser.room_name).to eq('[Bosque Deriel, Burial Ground]')
  end

  # Not in the captures (every Saga <name> there carries a bracketed title), but
  # the game can send one without it. room_name then holds the name as sent,
  # minus the room-number suffix, rather than going nil.
  it 'takes room_name from a Saga <name> without a bracketed title, minus the room number' do
    parser.instance_variable_set(:@room_name, '[Bosque Deriel, Burial Ground]')
    feed('<resource picture="0"/><room><name>Somewhere Unbracketed (230009)</name><description>D.</description></room>')
    expect(parser.room_name).to eq('Somewhere Unbracketed')
  end

  it 'takes room_name from a Saga <name> without a bracketed title or room number' do
    feed('<resource picture="0"/><room><name>Somewhere Unbracketed</name><description>D.</description></room>')
    expect(parser.room_name).to eq('Somewhere Unbracketed')
  end

  # The legacy roomName style gets the same fallback. Every real roomName text
  # (DR legacy captures, GemStone logs) carries a bracketed title, so these
  # shapes are synthetic.
  it 'takes room_name from the legacy roomName style, minus the room number' do
    feed(%(<style id="roomName" />[Town Square, Central] (4216009)\r\n), %(<style id=""/>))
    expect(parser.room_name).to eq('[Town Square, Central]')
  end

  it 'takes room_name from a legacy roomName without a bracketed title, minus the room number' do
    parser.instance_variable_set(:@room_name, '[Town Square, Central]')
    feed(%(<style id="roomName" />Somewhere Unbracketed (4216010)\r\n), %(<style id=""/>))
    expect(parser.room_name).to eq('Somewhere Unbracketed')
  end

  it 'takes room_name from a legacy roomName without a bracketed title or room number' do
    feed(%(<style id="roomName" />Somewhere Unbracketed\r\n), %(<style id=""/>))
    expect(parser.room_name).to eq('Somewhere Unbracketed')
  end

  it 'observes :room_element from the Saga <room> block' do
    feed('<resource picture="0"/><room><name>[Bosque Deriel, Burial Ground] (230007)</name><description>An Elven burial ground.</description><exits>Obvious paths: <d>north</d>.</exits><extra></extra></room>')
    expect(parser.stream_features).to eq([:room_element])
  end

  it 'keeps features across a mid-stream reset (a desync does not change the dialect)' do
    feed('<a exist="1" noun="leopard">leopard</a>')
    parser.reset
    expect(parser.stream_feature?(:links)).to be true
  end

  it 'clears features at login so a reconnect re-learns the dialect' do
    feed('<a exist="1" noun="leopard">leopard</a>')
    feed("<settingsInfo  client=\"1.0.1.28\" major=\"32\" crc='1009451187' instance='DR'/>")
    expect(parser.stream_features).to eq([])
  end

  it 'returns a copy that callers cannot use to change the parser' do
    feed('<a exist="1" noun="leopard">leopard</a>')
    parser.stream_features.clear
    expect(parser.stream_feature?(:links)).to be true
  end
end
