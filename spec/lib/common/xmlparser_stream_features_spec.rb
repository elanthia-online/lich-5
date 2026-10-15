# frozen_string_literal: true

require_relative '../../spec_helper'
require 'ox'
require 'common/gameobj'
require 'common/xmlparser'

# XMLParser#stream_feature? records which stream dialect the session is getting.
# The Saga identity (Frontend::CLIENT_STRING since #1700) gets object links and
# the <room> block; front ends that send their own Wrayth handshake get the
# legacy stream. Fragments follow the shapes in the DR captures under
# spec/fixtures/streams, with ids and text substituted. Two shapes are not in
# those captures: the URL <a href> line, and the <container> lines, which use
# GemStone's <container id='stow'> shape.
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
    feed('<a exist="-10604318" noun="Brenna">Brenna</a> drums his fingers on his bucket rhythmically.')
    expect(parser.stream_feature?(:links)).to be true
  end

  it 'does not treat an <a> without exist (a URL link) as an object link' do
    feed('Visit <a href="https://www.play.net/">the website</a>.')
    expect(parser.stream_feature?(:links)).to be false
  end

  it 'observes :room_element from the Saga <room> block' do
    feed('<resource picture="0"/><room><name>[Bosque Deriel, Burial Ground] (230007)</name><description>An Elven burial ground.</description><exits>Obvious paths: <d>north</d>.</exits><extra></extra></room>')
    expect(parser.stream_features).to eq([:room_element])
  end

  it 'observes :stow_container_tag only for the stow container' do
    feed("<container id='pack' title='Pack' target='#1' location='right' save='' resident='true'/>")
    expect(parser.stream_feature?(:stow_container_tag)).to be false

    feed("<container id='stow' title='My Pack' target='#195648378' location='right' save='' resident='true'/>")
    expect(parser.stream_feature?(:stow_container_tag)).to be true
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
