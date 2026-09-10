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
    %i[@death_watch @death_announced @held_cast @deferred_emits @observation_batch_id].each do |iv|
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
end
