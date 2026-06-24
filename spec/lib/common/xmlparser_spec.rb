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
# The ASSESS_CORPUS below is verbatim game output: each combat line arrives in
# its own pushStream/popStream, ids live in <d cmd='look #id'> attributes
# (subject first, then target), and the trailing "  | F" is a <d cmd='face #id'>
# face hint that must be discarded.

require_relative '../../spec_helper'
require 'rexml/document'
require 'rexml/streamlistener'
require_relative '../../../lib/common/xmlparser'

# Raw assess stream, wrapped per-line in pushStream/popStream as the game sends it.
ASSESS_CORPUS = <<~'__ASSESS__'
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

RSpec.describe Lich::Common::XMLParser do
  subject(:parser) { described_class.new }

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
        name: 'You', id: nil, self: true, pc: false,
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
    before { REXML::Document.parse_stream("<root>#{ASSESS_CORPUS}</root>", parser) }

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
end
