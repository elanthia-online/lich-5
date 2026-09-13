# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/parser'
require 'gemstone/combat/processor'
require 'gemstone/combat/observers'

# Synthetic stream envelopes use attack text already covered by native parser
# fixtures. No live session, socket, saved settings or character commands.
RSpec.describe 'Combat observation provenance' do
  let(:processor) { Lich::Gemstone::Combat::Processor }
  let(:observers) { Lich::Gemstone::Combat::Observers }
  let(:source) { { connection_id: 123, game: 'GSIV', character: 'Testmage', room_epoch: 4, sequence: 8, received_at: 10.0 } }
  let(:attack) { 'You swing a broadsword at <pushBold/><a exist="123" noun="rat">a giant rat</a><popBold/>!' }
  let(:chunk) { [attack, 'A clean miss.'] }

  before do
    stub_const('Lich::Gemstone::Combat::Tracker', Module.new)
    allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(
      track_statuses: false, track_ucs: false, emit_attacks: false,
      track_damage: false, track_wounds: false
    )
    allow(Lich::Gemstone::Combat::Tracker).to receive(:debug?).and_return(false)
    stub_const('Lich::Gemstone::Combat::Creature', Class.new { def self.[](_id); end })
    %i[@death_watch @death_announced @held_cast @held_pre_flares @deferred_emits @observation_batch_id].each do |iv|
      processor.instance_variable_set(iv, nil)
    end
    observers.clear!
  end

  after { observers.clear! }

  it 'requests complete attack outcomes only while a transient attack subscriber exists' do
    expect(processor.parse_events(chunk)).to be_empty
    seen = []
    handler = observers.on(:attack) { |_type, event| seen << event }
    processor.process(chunk, source: source)
    expect(seen.length).to eq(1)
    expect(seen.first).to include(_attack_born: true, source: source, outcomes: [:miss])
    expect(Lich::Gemstone::Combat::Tracker.settings[:emit_attacks]).to be(false)
    observers.off(handler)
    expect(processor.parse_events(chunk)).to be_empty
  end

  it 'snapshots transient attack demand once for the whole processing invocation' do
    seen = []
    observers.on(:attack) { |_type, event| seen << event }
    expect(processor).to receive(:attack_events_requested?).once.and_return(true)

    processor.process(chunk, source: source)

    expect(seen.length).to eq(1)
    expect(seen.first).to include(outcomes: [:miss])
  end

  it 'marks the whole emission batch before the first callback and assigns a new id next time' do
    seen = []
    observers.on(:attack) { |_type, event| seen << event }
    processor.process(chunk + chunk, source: source)
    expect(seen.map { |event| event[:observation_batch].slice(:index, :size) }).to eq([{ index: 0, size: 2 }, { index: 1, size: 2 }])
    first_id = seen.first[:observation_batch][:id]
    expect(seen.last[:observation_batch][:id]).to eq(first_id)
    expect(seen.first[:observation_batch]).to be_frozen
    processor.process(chunk)
    expect(seen.last[:observation_batch][:id]).to be > first_id
    expect(seen.last[:source]).to be_nil
  end

  it 'rejects malformed provenance instead of manufacturing a current binding' do
    observers.on(:attack) { |_type, _event| }
    [source.merge(sequence: 0), source.merge(received_at: Float::NAN), source.merge(character: ''), {}].each do |invalid|
      expect(processor.parse_events(chunk, source: invalid).first[:source]).to be_nil
    end
  end

  describe 'pre-flares held across chunks' do
    let(:pre_flare) do
      [
        ' ** Your <a exist="456" noun="bow">glowbark long bow</a> glows brightly for a moment, consuming the magical energies around the <pushBold/><a exist="123" noun="rat">giant rat</a><popBold/>! **',
        '   ... 20 points of damage!'
      ]
    end
    let(:later_source) { source.merge(sequence: 9, received_at: 20.0) }

    before { observers.on(:attack) { |_type, _event| } }

    it 'keeps the oldest receipt when the next attack claims the flare' do
      expect(processor.parse_events(pre_flare, source: source)).to be_empty
      event = processor.parse_events(chunk, source: later_source).first
      expect(event[:source]).to eq(source)
      expect(event[:source]).to be_frozen
      expect(event[:flares].first[:hits].map { |hit| hit[:damage] }).to eq([20])
    end

    it 'retains the original receipt when an unclaimed flare emits in the next batch' do
      seen = []
      observers.on(:attack) { |_type, event| seen << event }
      processor.process(pre_flare, source: source)
      expect(seen).to be_empty
      processor.process(['You are now in a defensive stance.'], source: later_source)
      expect(seen.first).to include(name: :dispel, source: source)
      expect(seen.first[:observation_batch]).to include(index: 0, size: 1)
    end

    it 'invalidates claimed and unclaimed held flares across changed or unknown bindings' do
      [source.merge(room_epoch: 5), source.merge(connection_id: 456), source.merge(character: 'Other'), nil].each do |later|
        [chunk, ['You are now in a defensive stance.']].each do |following|
          expect(processor.parse_events(pre_flare, source: source)).to be_empty
          event = processor.parse_events(following, source: later).first
          expect(event[:source]).to be_nil
          expect(event[:flares].first[:hits].map { |hit| hit[:damage] }).to eq([20])
        end
      end
    end

    it 'does not attach a verified source to a flare retained from a legacy call' do
      expect(processor.parse_events(pre_flare)).to be_empty
      expect(processor.parse_events(chunk, source: later_source).first[:source]).to be_nil
    end
  end

  it 'includes source on upstream outcome-only inbound and outbound events' do
    observers.on(:attack) { |_type, _event| }
    inbound = 'The thorny barrier surrounding you blocks the attack from the <pushBold/><a exist="123" noun="skald">gigas skald</a><popBold/>!'
    outbound = 'With preternatural speed, the <pushBold/><a exist="123" noun="rat">giant rat</a><popBold/> bounds to safety as you move to attack <pushBold/><a exist="123" noun="rat">it</a><popBold/>, leaving you off-balance!'
    [inbound, outbound].each do |line|
      event = processor.parse_events([line], source: source).first
      expect(event).to include(source: source)
    end
  end
end
