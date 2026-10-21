# frozen_string_literal: true

require_relative '../../spec_helper'
require 'ox'
require 'common/gameobj'
require 'common/xmlparser'

# DragonRealms room players in both stream dialects, through the real GameObj.
# Legacy (front ends sending their own Wrayth handshake): one plain-text run.
# Saga identity (Frontend::CLIENT_STRING since #1700): every player linked, so
# the text arrives as fragments between links. Names pseudonymized.
RSpec.describe 'Lich::Common::XMLParser DragonRealms room players' do
  subject(:parser) { Lich::Common::XMLParser.new }

  legacy = "<component id='room players'>Also here: Monster Aldric, Daydreamer Brenna who is surrounded by a pale electrical sphere, Corwin and Druid Delphine.</component>"
  saga = "<component id='room players'>Also here: Monster <a exist=\"-10700002\" noun=\"Aldric\">Aldric</a>, " \
         "Daydreamer <a exist=\"-10700003\" noun=\"Brenna\">Brenna</a> who is surrounded by a pale electrical sphere, " \
         "<a exist=\"-10700004\" noun=\"Corwin\">Corwin</a> and Druid <a exist=\"-10700005\" noun=\"Delphine\">Delphine</a>.</component>"

  before do
    allow(XMLData).to receive(:game).and_return('DR')
    parser.instance_variable_set(:@game, 'DR')
    Lich::Common::GameObj.clear_pcs
  end

  def feed(fragment)
    Ox.sax_parse(parser, fragment, convert_special: false, symbolize: false, skip: :skip_none)
  end

  def pcs
    (Lich::Common::GameObj.pcs || []).map { |pc| [pc.id, pc.noun, pc.name, pc.status] }
  end

  context 'legacy dialect' do
    # GameObj keys pc status by id, so the id-less legacy players cannot carry
    # it (pre-existing); the Saga dialect's linked players can (see below).
    it 'splits the plain-text list into id-less players with titles' do
      feed(legacy)

      expect(pcs).to eq([
                          [nil, 'Aldric', 'Monster Aldric', nil],
                          [nil, 'Brenna', 'Daydreamer Brenna', nil],
                          [nil, 'Corwin', 'Corwin', nil],
                          [nil, 'Delphine', 'Druid Delphine', nil]
                        ])
    end

    # The gate is the run's shape alone, not the session-long :links flag, so
    # one stray <a exist> elsewhere in the stream cannot stop every later
    # link-free list from splitting until the next login.
    it 'still splits a complete list after a link elsewhere in the stream' do
      feed('<a exist="-10700002" noun="Aldric">Aldric</a> waves.')
      expect(parser.stream_feature?(:links)).to be true

      feed(legacy)

      expect(pcs.map { |pc| pc[1] }).to eq(%w[Aldric Brenna Corwin Delphine])
    end
  end

  context 'Saga dialect' do
    # No earlier linked line primes the session: this is the first linked line.
    it 'registers every linked player with its id, title and status and no junk entries' do
      feed(saga)

      expect(pcs.map(&:first)).to eq(%w[-10700002 -10700003 -10700004 -10700005])
      expect(pcs.map { |pc| pc[1] }).to eq(%w[Aldric Brenna Corwin Delphine])
      expect(pcs[0][2]).to eq('Monster Aldric')
      expect(pcs[1][2]).to eq('Daydreamer Brenna')
      expect(pcs[1][3]).to eq('surrounded by a pale electrical sphere')
      expect(pcs[2][2]).to eq('Corwin')
      expect(pcs.map { |pc| pc[2] }).not_to include('.', '')
    end

    it 'replaces the previous room\'s players on the next refresh' do
      feed(saga)
      feed("<component id='room players'>Also here: <a exist=\"-10700004\" noun=\"Corwin\">Corwin</a>.</component>")

      expect(pcs.map(&:first)).to eq(%w[-10700004])
    end

    # Shared with GemStone and parked until a GemStone capture exists
    # (docs/xml-stream/saga-stream-deferred.md, P1): a title after " and " is not captured.
    it 'documents the parked " and <title>" gap' do
      feed(saga)
      expect(pcs[3][2]).to eq('Delphine')
    end
  end
end
