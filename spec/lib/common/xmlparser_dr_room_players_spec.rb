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
      expect(pcs[3][2]).to eq('Druid Delphine')
      expect(pcs.map { |pc| pc[2] }).not_to include('.', '')
    end

    it 'replaces the previous room\'s players on the next refresh' do
      feed(saga)
      feed("<component id='room players'>Also here: <a exist=\"-10700004\" noun=\"Corwin\">Corwin</a>.</component>")

      expect(pcs.map(&:first)).to eq(%w[-10700004])
    end

    # Titles: the text before a player's link, after the run's last list
    # separator (#2416 P1, P2, P4). Real shapes from the indexed logs.
    describe 'titles and statuses' do
      def link(name, id) = %(<a exist="-#{id}" noun="#{name}">#{name}</a>)

      def players(text)
        feed("<component id='room players'>Also here: #{text}</component>")
        pcs.map { |pc| [pc[2], pc[3]] }
      end

      it 'keeps the title of a GameMaster listed after " and "' do
        expect(players("#{link('Bob', 10700002)} and GameMaster #{link('Avaari', 10700003)}."))
          .to eq([['Bob', nil], ['GameMaster Avaari', nil]])
      end

      it 'keeps the title after " and " when the player before it has a status' do
        expect(players("#{link('Bob', 10700002)} who is sitting and GameMaster #{link('Avaari', 10700003)}."))
          .to eq([['Bob', 'sitting'], ['GameMaster Avaari', nil]])
      end

      it 'keeps the title after a parenthesised status and " and "' do
        expect(players("#{link('Bob', 10700002)} (prone) and Druid #{link('Corwin', 10700004)} who is sitting."))
          .to eq([['Bob', 'prone'], ['Druid Corwin', 'sitting']])
      end

      it 'ends a status at the " and " before an untitled last player' do
        expect(players("#{link('Bob', 10700002)} who is engulfed by a tsunami of cerulean light and #{link('Corwin', 10700004)}."))
          .to eq([['Bob', 'engulfed by a tsunami of cerulean light'], ['Corwin', nil]])
      end

      it 'keeps a description\'s own " and " in the status, before ", "' do
        expect(players("#{link('Bob', 10700002)} who is coated in grime and surrounded by a swirling cloud of filth, " \
                       "Avatar of Forging #{link('Corwin', 10700004)}."))
          .to eq([['Bob', 'coated in grime and surrounded by a swirling cloud of filth'], ['Avatar of Forging Corwin', nil]])
      end

      it 'keeps a description\'s own " and " in the last player\'s status' do
        expect(players("Trader #{link('Bob', 10700002)} and #{link('Corwin', 10700004)} who is coated in soot and wrapped in a cloud of ash."))
          .to eq([['Trader Bob', nil], ['Corwin', 'coated in soot and wrapped in a cloud of ash']])
      end

      it 'keeps the title after "the body of" and "a stunned", with the status' do
        expect(players("the body of Chronicler #{link('Coogs', 10700002)} (prone), a stunned Vizier #{link('Emes', 10700003)} " \
                       "and the body of Serial Killer #{link('Damiza', 10700004)} (prone)."))
          .to eq([['Chronicler Coogs', 'dead prone'], ['Vizier Emes', 'stunned'], ['Serial Killer Damiza', 'dead prone']])
      end

      it 'keeps titles with apostrophes, hyphens and lower-case words' do
        expect(players("War 'Tog #{link('Bob', 10700002)}, Dikka'staho Ashu #{link('Corwin', 10700004)}, " \
                       "Iron-Tide Corsair #{link('Delphine', 10700005)} and Master of Shadows #{link('Edric', 10700006)}."))
          .to eq([["War 'Tog Bob", nil], ["Dikka'staho Ashu Corwin", nil], ['Iron-Tide Corsair Delphine', nil], ['Master of Shadows Edric', nil]])
      end

      it 'reads "who appears" as a status (a GameMaster in the 2026-11-21 logs)' do
        expect(players("GameMaster #{link('Cordulia', 10700002)} who appears in triplicate."))
          .to eq([['GameMaster Cordulia', 'in triplicate']])
      end

      # Shared with GemStone, whose lists have no closing period. "Dr. Peter"
      # is a real GemStone title (GS-15 captures, gs_saga_players.xml).
      it 'keeps a GemStone title that contains a period' do
        parser.instance_variable_set(:@game, 'GS')
        expect(players("#{link('Bob', 10700002)}, Dr. Peter #{link('Corwin', 10700004)}, #{link('Delphine', 10700005)} who is sleeping"))
          .to eq([['Bob', nil], ['Dr. Peter Corwin', nil], ['Delphine', 'sleeping']])
      end

      # #2416 P3. While a refresh is open, GameObj#status= writes only to the
      # staging pool, which holds no pc until this refresh links one, so the
      # previous refresh's last pc cannot take a status from the new list.
      it 'does not give the previous refresh\'s last pc a status from the next refresh' do
        feed("<component id='room players'>Also here: #{link('Bob', 10700002)}.</component>")
        parser.tag_start('component', { 'id' => 'room players' })
        parser.text(' (prone) and ')
        parser.tag_start('a', { 'exist' => '-10700002', 'noun' => 'Bob' })
        parser.text('Bob')
        parser.tag_end('a')
        parser.text('.')
        parser.tag_end('component')

        expect(pcs.map { |pc| [pc[2], pc[3]] }).to eq([['Bob', nil]])
      end
    end
  end
end
