# frozen_string_literal: true

# Spec for Lich::Common::XMLParser assess (combat situation) stream parsing.
#
# Two layers of coverage:
#   * #parse_assess_line  -- pure, global-free parsing of a single reconstructed
#                            assess line plus its ordered look-target ids.
#   * stream integration  -- drives the real REXML::StreamListener pipeline with
#                            the raw XML exactly as the game emits it (the same
#                            corpus a player sees from ASSESS), confirming the
#                            tag_start / text / popStream / clearStream wiring
#                            reassembles each line and the d-tag ids correctly.
#
# The assess_corpus below is verbatim game output: each combat line arrives in
# its own pushStream/popStream, ids live in <d cmd='look #id'> attributes
# (subject first, then target), and the trailing "  | F" is a <d cmd='face #id'>
# face hint that must be discarded.

require_relative '../../spec_helper'
require 'rexml/document'
require 'rexml/streamlistener'
require_relative '../../../lib/common/xmlparser'

RSpec.describe Lich::Common::XMLParser do
  subject(:parser) { described_class.new }

  # Raw assess stream, wrapped per-line in pushStream/popStream as the game sends it.
  let(:assess_corpus) { <<~'__ASSESS__' }
  <pushStream id="assess"/><clearStream id="assess"/>You assess your combat situation...
  <popStream/><pushStream id="assess"/>You (adeptly balanced) are facing <d cmd='look #89513914'>a jeol moradu</d> (4) at melee range.
  <popStream/><pushStream id="assess"/><d cmd='look #89511379'>A jeol moradu</d> (1: cursed and nimbly balanced) is behind <d cmd='look #-10592168'>Tenuk</d> at melee range.  | <d cmd='face #89511379'>F</d>
  <popStream/><pushStream id="assess"/><d cmd='look #89511387'>A jeol moradu</d> (2: cursed and nimbly balanced) is facing <d cmd='look #-10592168'>Tenuk</d> at melee range.  | <d cmd='face #89511387'>F</d>
  <popStream/><pushStream id="assess"/><d cmd='look #89511391'>A jeol moradu</d> (3: cursed and nimbly balanced) is behind <d cmd='look #-10592168'>Tenuk</d> at melee range.  | <d cmd='face #89511391'>F</d>
  <popStream/><pushStream id="assess"/><d cmd='look #89513914'>A jeol moradu</d> (4: nimbly balanced) is facing you at melee range.  | <d cmd='face #89513914'>F</d>
  <popStream/><pushStream id="assess"/><d cmd='look #89513926'>A jeol moradu</d> (5: slightly off balance) is behind you at melee range.  | <d cmd='face #89513926'>F</d>
  <popStream/><pushStream id="assess"/><d cmd='look #89513942'>A jeol moradu</d> (6: solidly balanced) is behind you at melee range.  | <d cmd='face #89513942'>F</d>
  <popStream/><pushStream id="assess"/><d cmd='look #89511371'>A jeol moradu</d> (7: cursed and off balance) is moving to flank <d cmd='look #-10592168'>Tenuk</d> at pole weapon range.  | <d cmd='face #89511371'>F</d>
  <popStream/><pushStream id="assess"/><d cmd='look #-10592168'>Tenuk</d> (incredibly balanced) is facing <d cmd='look #89511387'>a jeol moradu</d> (2) at melee range.  | <d cmd='face #89511387'>F</d>
  <popStream/><pushStream id="assess"/><d cmd='look #-10581503'>Byd</d> (hidden and incredibly balanced) is moving to flank <d cmd='look #89511379'>a jeol moradu</d> (1) at missile range.  | <d cmd='face #89511379'>F</d>
  <popStream/><prompt time="1782253647">R&gt;</prompt>
  __ASSESS__

  describe '#parse_assess_line' do
    it 'returns nil for the header line' do
      expect(parser.parse_assess_line('You assess your combat situation...', [])).to be_nil
    end

    it 'returns nil for blank input' do
      expect(parser.parse_assess_line('   ', [])).to be_nil
    end

    it 'parses the self line, using the lone look id as the target' do
      entry = parser.parse_assess_line(
        'You (adeptly balanced) are facing a jeol moradu (4) at melee range.', ['89513914']
      )
      expect(entry).to include(
        name: 'You', id: nil, number: nil, self: true, pc: false,
        status: 'adeptly balanced', relation: 'facing',
        target: 'a jeol moradu', target_id: '89513914', target_number: 4,
        range: :melee
      )
    end

    it 'parses a creature line, subject id first then target id, and strips the face hint' do
      entry = parser.parse_assess_line(
        'A jeol moradu (1: cursed and nimbly balanced) is behind Tenuk at melee range.  | F',
        ['89511379', '-10592168']
      )
      expect(entry).to include(
        name: 'A jeol moradu', id: '89511379', number: 1,
        status: 'cursed and nimbly balanced', relation: 'behind',
        target: 'Tenuk', target_id: '-10592168',
        range: :melee, self: false, pc: false
      )
    end

    it 'treats a "you" target as nil target_id' do
      entry = parser.parse_assess_line(
        'A jeol moradu (4: nimbly balanced) is facing you at melee range.  | F', ['89513914']
      )
      expect(entry).to include(target: 'you', target_id: nil, number: 4)
    end

    it 'normalizes "moving to flank" to "flanking" and maps pole weapon range' do
      entry = parser.parse_assess_line(
        'A jeol moradu (7: cursed and off balance) is moving to flank Tenuk at pole weapon range.  | F',
        ['89511371', '-10592168']
      )
      expect(entry).to include(relation: 'flanking', target: 'Tenuk', range: :pole)
    end

    it 'flags a PC subject (negative id) and captures the targeted creature number' do
      entry = parser.parse_assess_line(
        'Tenuk (incredibly balanced) is facing a jeol moradu (2) at melee range.  | F',
        ['-10592168', '89511387']
      )
      expect(entry).to include(
        name: 'Tenuk', id: '-10592168', pc: true, number: nil,
        relation: 'facing', target: 'a jeol moradu', target_id: '89511387',
        target_number: 2, range: :melee
      )
    end

    it 'maps missile range' do
      entry = parser.parse_assess_line(
        'Byd (hidden and incredibly balanced) is moving to flank a jeol moradu (1) at missile range.  | F',
        ['-10581503', '89511379']
      )
      expect(entry).to include(pc: true, relation: 'flanking', range: :missile, target_number: 1)
    end
  end

  describe 'assess stream integration (full REXML feed)' do
    before { REXML::Document.parse_stream("<root>#{assess_corpus}</root>", parser) }

    it 'captures every assessed entity except the header' do
      expect(parser.assess.length).to eq(10)
    end

    it 'records the self line with no subject id' do
      me = parser.assess.find { |e| e[:self] }
      expect(me).to include(name: 'You', id: nil, target_id: '89513914', range: :melee)
    end

    it 'reassembles creature lines with correct ids from the <d> tags' do
      creatures = parser.assess_creatures
      expect(creatures.length).to eq(7)
      expect(creatures.map { |c| c[:number] }).to eq([1, 2, 3, 4, 5, 6, 7])
      expect(creatures.map { |c| c[:id] }).to eq(
        %w[89511379 89511387 89511391 89513914 89513926 89513942 89511371]
      )
    end

    it 'classifies PCs by negative id and excludes them from assess_creatures' do
      pcs = parser.assess.select { |e| e[:pc] }
      expect(pcs.map { |e| e[:name] }).to eq(%w[Tenuk Byd])
      expect(parser.assess_creatures.map { |c| c[:name] }.uniq).to eq(['A jeol moradu'])
    end

    it 'captures the three distinct ranges present in the corpus' do
      expect(parser.assess.map { |e| e[:range] }.uniq).to contain_exactly(:melee, :pole, :missile)
    end

    it 'discards the trailing face hint (no stray "| F" in any field)' do
      expect(parser.assess.none? { |e| e.values.grep(String).any? { |v| v.include?('|') } }).to be(true)
    end

    it 'resets the list on a fresh clearStream' do
      expect(parser.assess.length).to eq(10)
      REXML::Document.parse_stream(
        %(<root><pushStream id="assess"/><clearStream id="assess"/>You assess your combat situation...<popStream/></root>),
        parser
      )
      expect(parser.assess).to be_empty
    end
  end

  # The mindState progressBar carries the experience fields shown in the game's
  # exp bar. field_exp/max_field_exp/ascension_exp/exp/until_next are always
  # present; fashlonae/lumnis/rpa are only emitted while those bonuses are
  # active and must fall back to nil when a fresh bar omits them.
  describe 'mindState progressBar experience fields' do
    # Verbatim bar as emitted while the ascension bonuses are active.
    let(:active_bar) do
      "<progressBar id='mindState' value='100' text='must rest' top='45' left='3' field_exp='1077' max_field_exp='1077' ascension_exp='5438' fashlonae='1' lumnis='3' rpa='2' exp='53915957' until_next='1543' align='n' width='160' height='15'/>"
    end

    # Same bar with the active-only bonuses dropped (the game omits them when
    # they are not active).
    let(:inactive_bar) do
      "<progressBar id='mindState' value='34' text='clear as a bell' top='45' left='3' field_exp='500' max_field_exp='1010' ascension_exp='6000' exp='53920000' until_next='999' align='n' width='160' height='15'/>"
    end

    def feed(parser, fragment)
      REXML::Document.parse_stream("<root>#{fragment}</root>", parser)
    end

    it 'absorbs every always-present experience field' do
      feed(parser, active_bar)
      expect(parser.mind_text).to eq('must rest')
      expect(parser.mind_value).to eq(100)
      expect(parser.field_exp).to eq(1077)
      expect(parser.max_field_exp).to eq(1077)
      expect(parser.ascension_exp).to eq(5438)
      expect(parser.exp).to eq(53_915_957)
      expect(parser.until_next).to eq(1543)
    end

    it 'absorbs the active-only bonus fields when present' do
      feed(parser, active_bar)
      expect(parser.fashlonae).to eq(1)
      expect(parser.lumnis).to eq(3)
      expect(parser.rpa).to eq(2.0)
      expect(parser.rpa).to be_a(Float)
    end

    it 'preserves a fractional rpa value without truncating it' do
      feed(parser, "<progressBar id='mindState' value='100' text='must rest' field_exp='1077' max_field_exp='1077' ascension_exp='5438' lumnis='3' rpa='1.5' exp='53915957' until_next='1543'/>")
      expect(parser.rpa).to eq(1.5)
      expect(parser.rpa).to be_a(Float)
    end

    it 'leaves active-only bonus fields nil when the bar omits them' do
      feed(parser, inactive_bar)
      expect(parser.fashlonae).to be_nil
      expect(parser.lumnis).to be_nil
      expect(parser.rpa).to be_nil
      # always-present fields still populate from the omitting bar
      expect(parser.ascension_exp).to eq(6000)
      expect(parser.until_next).to eq(999)
    end

    it 'clears previously-set bonus fields back to nil on a fresh bar without them' do
      feed(parser, active_bar)
      expect([parser.fashlonae, parser.lumnis, parser.rpa]).to eq([1, 3, 2.0])

      feed(parser, inactive_bar)
      expect(parser.fashlonae).to be_nil
      expect(parser.lumnis).to be_nil
      expect(parser.rpa).to be_nil
      # and the always-present fields reflect the newer bar
      expect(parser.field_exp).to eq(500)
      expect(parser.max_field_exp).to eq(1010)
      expect(parser.exp).to eq(53_920_000)
    end
  end

  # The roommeta tag carries integer room-metadata fields. climate/terrain were
  # already ingested; weather/bonfire/inside/water/sanctuary/realm mirror them.
  describe 'roommeta room-metadata fields' do
    def feed(parser, fragment)
      REXML::Document.parse_stream("<root>#{fragment}</root>", parser)
    end

    it 'defaults every field to 0 before any roommeta is seen' do
      expect(parser.room_climate).to eq(0)
      expect(parser.room_terrain).to eq(0)
      expect(parser.room_weather).to eq(0)
      expect(parser.room_bonfire).to eq(0)
      expect(parser.room_inside).to eq(0)
      expect(parser.room_water).to eq(0)
      expect(parser.room_sanctuary).to eq(0)
      expect(parser.room_realm).to eq(0)
    end

    it 'absorbs every field from the roommeta tag' do
      feed(parser, %(<roommeta weather="0" bonfire="0" inside="1" water="0" sanctuary="0" realm="57" climate="12" terrain="1"/>))
      expect(parser.room_climate).to eq(12)
      expect(parser.room_terrain).to eq(1)
      expect(parser.room_weather).to eq(0)
      expect(parser.room_bonfire).to eq(0)
      expect(parser.room_inside).to eq(1)
      expect(parser.room_water).to eq(0)
      expect(parser.room_sanctuary).to eq(0)
      expect(parser.room_realm).to eq(57)
    end
  end
end
