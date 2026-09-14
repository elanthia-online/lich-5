# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/parser'
require 'gemstone/combat/processor'

# Replay-fidelity regression net.
#
# The PR's headline claim is that the processor reassembles recorded combat
# facts with no loss. That was verified with an external harness + a 1000-blob
# corpus that don't live in this repo (they are the author's working apparatus).
# This spec lands a slim, curated slice of that corpus - the single most-common
# real-feed shape per attack def, plus extra flare-bearing shapes - as a
# fixture, and drives each blob through the REAL Processor.parse_events, then
# asserts the events reproduce the facts the def layer recorded in that blob's
# "# expect:" header (attacks / resolutions / flares / outcomes / damage count
# / statuses). Missing facts fail; incidental extras are tolerated (the header
# is a floor, not an exact set), matching the harness contract.
#
# Fixtures: spec/fixtures/replay/<def>.txt - each blob is a real captured feed
# chunk with its expect header. Regenerate/extend from the full corpus via the
# curation: the single most-common shape per attack def (by wild occurrence
# count) plus extra flare-bearing shapes, scrubbed of volatile provenance.
RSpec.describe 'Combat replay fidelity' do
  processor = Lich::Gemstone::Combat::Processor
  fixture_dir = File.join(__dir__, '..', '..', '..', 'fixtures', 'replay')

  before do
    stub_const('Lich::Gemstone::Combat::Tracker', Module.new)
    allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(
      emit_attacks: true, track_statuses: true, track_ucs: true, track_wounds: true
    )
    allow(Lich::Gemstone::Combat::Tracker).to receive(:debug?).and_return(false)

    # Headless: capture status/UCS application instead of touching the (absent)
    # Creature registry, and capture self-statuses that arrive via Observers.
    stub_const('Lich::Gemstone::Combat::Observers', Module.new)
    @statuses = []
    statuses = @statuses
    allow(processor).to receive(:apply_status_to_target) do |status, _name, _id = nil, action = :add|
      statuses << "#{status}/#{action}"
    end
    allow(processor).to receive(:apply_ucs_to_target)
    allow(Lich::Gemstone::Combat::Observers).to receive(:emit) do |type, data|
      statuses << "#{data[:status]}/#{data[:action]}" if type == :status && data[:name] == 'self'
    end
  end

  def parse_expect(line)
    h = {}
    line.sub('# expect: ', '').split(' | ').each do |part|
      k, v = part.split('=', 2)
      h[k] = (v || '').split(',').reject { |x| x == 'none' || x.empty? }
    end
    h['dmg'] = h['dmg'].first.to_i
    h
  end

  # What the processor produced, reduced to the expect-header vocabulary.
  def summarize(events, statuses)
    attacks = events.flat_map { |e| [e[:name].to_s, e[:via]&.to_s, (e[:ambush] ? 'ambush' : nil)] }.compact.uniq
    res = []
    flares = []
    outs = []
    dmg = 0
    events.each do |e|
      res.concat(e[:resolutions].map { |r| r[:type].to_s })
      outs.concat(e[:outcomes].map(&:to_s))
      dmg += e[:hits].size
      e[:flares].each do |f|
        flares << f[:name].to_s
        res.concat(f[:resolutions].map { |r| r[:type].to_s })
        outs.concat(f[:outcomes].map(&:to_s))
        dmg += f[:hits].size
      end
    end
    { 'attacks' => attacks.uniq, 'res' => res.uniq.sort, 'flares' => flares.uniq.sort,
      'outcomes' => outs.uniq.sort, 'dmg' => dmg, 'statuses' => statuses.uniq.sort }
  end

  # Load every blob from every fixture file as [label, expect, lines].
  def self.load_blobs(dir)
    Dir[File.join(dir, '*.txt')].sort.flat_map do |path|
      blobs = []
      header = nil
      expect = nil
      lines = []
      flush = lambda do
        blobs << [header, expect, lines] if header && expect && !lines.empty?
      end
      File.foreach(path, chomp: true) do |l|
        if l.start_with?('##### ')
          flush.call
          header = l.sub('##### ', '')
          expect = nil
          lines = []
        elsif l.start_with?('# expect:')
          expect = l
        elsif l.strip.empty?
          flush.call
          header = nil
          expect = nil
          lines = []
        elsif header
          lines << l
        end
      end
      flush.call
      blobs
    end
  end

  blobs = load_blobs(fixture_dir)
  it 'has a non-empty curated fixture set' do
    expect(blobs.size).to be >= 50
  end

  blobs.each do |header, expect_line, lines|
    it "reproduces the recorded facts for #{header}" do
      expected = parse_expect(expect_line)
      events = processor.parse_events(lines)
      got = summarize(events, @statuses)

      # numeric: exact. set fields: every expected fact must be present
      # (extras tolerated - the header is a floor).
      expect(got['dmg']).to eq(expected['dmg']),
                            -> { "dmg: want #{expected['dmg']} got #{got['dmg']} for #{header}" }
      %w[attacks res flares outcomes statuses].each do |field|
        missing = expected[field] - got[field]
        expect(missing).to be_empty,
                           -> { "#{field}: missing #{missing.join(',')} (got #{got[field].join(',')}) for #{header}" }
      end
    end
  end
end
