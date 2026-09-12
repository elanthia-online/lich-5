# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/parser'
require 'gemstone/combat/processor'

# Holy Weapon (1625) infusion release: the proc line is a pre-flare on the
# swing, the spell it releases runs as the swing's child, and the swing
# resumes for its own roll. Two shapes a review of 056ff899 caught:
#   1. one flare releases ONE spell - a later swing in the same chunk must
#      not be read as "released" (it stole the swing's roll and damage);
#   2. the released spell may be a BOLT, whose own AS/DS arrives before the
#      swing's - the swing must resume on the SECOND physical roll.
RSpec.describe 'Holy Weapon release' do
  processor = Lich::Gemstone::Combat::Processor
  troll = '<pushBold/>a <a exist="212657781" noun="troll">bog troll</a><popBold/>'
  mace  = '<a exist="212333157" noun="mace">mithril mace</a>'

  before do
    stub_const('Lich::Gemstone::Combat::Tracker', Module.new)
    allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(
      emit_attacks: true, track_statuses: true, track_ucs: true, track_wounds: true
    )
    allow(Lich::Gemstone::Combat::Tracker).to receive(:debug?).and_return(false)
    stub_const('Lich::Gemstone::Combat::Observers', Module.new)
    allow(processor).to receive(:apply_status_to_target)
    allow(processor).to receive(:apply_ucs_to_target)
    allow(Lich::Gemstone::Combat::Observers).to receive(:emit)
    processor.instance_variable_set(:@active_assault, nil)
  end

  def summary(events)
    events.map do |e|
      [e[:name], e[:resolutions].map { |r| r[:type] }, e[:hits].map { |h| h[:damage] },
       e[:parent_ref] ? e[:parent_ref][:name] : nil]
    end
  end

  let(:pummel_with_verdict) do
    [
      "You take a menacing step toward #{troll}, sweeping your #{mace} out low to your side in your advance.",
      '[SMR result: 165 (Open d100: 43, Bonus: 65)]',
      "With deliberate brutality, you bring your #{mace} around to pummel #{troll}!",
      "As you attempt to strike with your #{mace}, it sends a surge of power through you that quickly leaps out at #{troll}!",
      "Violet flames erupt from beneath #{troll}.",
      '  CS: +149 - TD: +120 + CvA: +17 + d100: +85 == +131',
      '  Warding failed!',
      "A column of seething violet flame envelops #{troll} in its searing embrace!",
      '   ... 20 points of damage!',
      '  AS: +273 vs DS: +80 with AvD: +35 + d100 roll: +2 = +230',
      '   ... and hit for 79 points of damage!'
    ]
  end

  it 'parents the released spell to the swing and returns the swing its roll' do
    events = processor.parse_events(pummel_with_verdict + ['<prompt time="1">&gt;</prompt>'])
    expect(summary(events)).to eq([
                                    [:pummel, %i[smr as_ds], [79], nil],
                                    [:templars_verdict, %i[cs_td], [20], :pummel]
                                  ])
  end

  it 'does not read a later swing in the chunk as another released spell' do
    chunk = pummel_with_verdict + [
      "You swing a perfect #{mace} at #{troll}!",
      '  AS: +280 vs DS: +90 with AvD: +35 + d100 roll: +50 = +275',
      '   ... and hit for 40 points of damage!',
      '<prompt time="1">&gt;</prompt>'
    ]
    events = processor.parse_events(chunk)
    expect(summary(events)).to eq([
                                    [:pummel, %i[smr as_ds], [79], nil],
                                    [:templars_verdict, %i[cs_td], [20], :pummel],
                                    [:attack, %i[as_ds], [40], nil]
                                  ])
    expect(events.last[:_released]).to be_falsey
  end

  # Second review round (3c3f1bfe): the release -> spell -> swing ordering.
  let(:release_then_verdict) do
    [
      "As you attempt to strike with your #{mace}, it sends a surge of power through you that quickly leaps out at #{troll}!",
      "Violet flames erupt from beneath #{troll}.",
      '  CS: +149 - TD: +120 + CvA: +17 + d100: +85 == +131',
      '  Warding failed!',
      "A column of seething violet flame envelops #{troll} in its searing embrace!",
      '   ... 20 points of damage!'
    ]
  end

  it 'lets a swing with a LINKED weapon claim the pending release and adopt the cast' do
    chunk = release_then_verdict + [
      "You swing a perfect #{mace} at #{troll}!",
      '  AS: +273 vs DS: +80 with AvD: +35 + d100 roll: +2 = +230',
      '   ... and hit for 79 points of damage!',
      '<prompt time="1">&gt;</prompt>'
    ]
    events = processor.parse_events(chunk)
    expect(summary(events)).to eq([
                                    [:attack, %i[as_ds], [79], nil],
                                    [:templars_verdict, %i[cs_td], [20], :attack]
                                  ])
    expect(events.first[:flares].map { |f| f[:name] }).to eq([:weapon_cast])
    expect(events.first[:weapon]).to eq('perfect mithril mace')
  end

  it 'consumes the release on the release-before-swing path so a later bolt is not adopted' do
    chunk = release_then_verdict + [
      "You swing a perfect mithril mace at #{troll}!",
      '  AS: +273 vs DS: +80 with AvD: +35 + d100 roll: +2 = +230',
      '   ... and hit for 79 points of damage!',
      "You hurl a fiery bolt at #{troll}!",
      '  AS: +120 vs DS: +80 with AvD: +25 + d100 roll: +60 = +125',
      '   ... and hit for 15 points of damage!',
      '<prompt time="1">&gt;</prompt>'
    ]
    events = processor.parse_events(chunk)
    expect(summary(events)).to eq([
                                    [:attack, %i[as_ds], [79], nil],
                                    [:templars_verdict, %i[cs_td], [20], :attack],
                                    [:bolt, %i[as_ds], [15], nil]
                                  ])
    expect(events.last[:_released]).to be_falsey
  end

  it 'holds a release that follows a settled swing for the NEXT swing' do
    chunk = [
      "You swing a perfect mithril mace at #{troll}!",
      '  AS: +260 vs DS: +80 with AvD: +35 + d100 roll: +10 = +225',
      '   ... and hit for 10 points of damage!'
    ] + release_then_verdict + [
      "You swing a perfect mithril mace at #{troll}!",
      '  AS: +273 vs DS: +80 with AvD: +35 + d100 roll: +2 = +230',
      '   ... and hit for 79 points of damage!',
      '<prompt time="1">&gt;</prompt>'
    ]
    events = processor.parse_events(chunk)
    expect(summary(events)).to eq([
                                    [:attack, %i[as_ds], [10], nil],
                                    [:attack, %i[as_ds], [79], nil],
                                    [:templars_verdict, %i[cs_td], [20], :attack]
                                  ])
    expect(events[0][:flares]).to be_empty
    expect(events[1][:flares].map { |f| f[:name] }).to eq([:weapon_cast])
    expect(events[2][:parent_ref]).to equal(events[1])
  end

  it 'lets a released BOLT keep its own AS/DS and damage' do
    chunk = [
      "You take a menacing step toward #{troll}, sweeping your #{mace} out low to your side in your advance.",
      '[SMR result: 165 (Open d100: 43, Bonus: 65)]',
      "With deliberate brutality, you bring your #{mace} around to pummel #{troll}!",
      "As you attempt to strike with your #{mace}, it sends a surge of power through you that quickly leaps out at #{troll}!",
      "You hurl a fiery bolt at #{troll}!",
      '  AS: +120 vs DS: +80 with AvD: +25 + d100 roll: +60 = +125',
      '   ... and hit for 15 points of damage!',
      '  AS: +273 vs DS: +80 with AvD: +35 + d100 roll: +2 = +230',
      '   ... and hit for 79 points of damage!',
      '<prompt time="1">&gt;</prompt>'
    ]
    events = processor.parse_events(chunk)
    expect(summary(events)).to eq([
                                    [:pummel, %i[smr as_ds], [79], nil],
                                    [:bolt, %i[as_ds], [15], :pummel]
                                  ])
  end
end
