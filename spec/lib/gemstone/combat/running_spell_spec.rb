# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/parser'
require 'gemstone/combat/processor'

# Whose Earthen Fury an eruption is, remembered across chunks from its
# opening line (Processor::RUNNING_SPELL_SECONDS).
RSpec.describe Lich::Gemstone::Combat::Processor do
  before do
    stub_const('Lich::Gemstone::Combat::Tracker', Module.new)
    allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(
      track_statuses: false, track_ucs: false, emit_attacks: true, track_damage: true, track_wounds: false
    )
    allow(Lich::Gemstone::Combat::Tracker).to receive(:debug?).and_return(false)
    stub_const('Lich::Common::Events', Module.new)
    allow(Lich::Common::Events).to receive(:emit)
    allow(Lich::Common::Events).to receive(:any_for?).with('combat.attack').and_return(false)
    %i[@death_watch @death_announced @held_cast @held_pre_flares @deferred_emits @running_spells @spell_victims_dead @running_room].each do |iv|
      described_class.instance_variable_set(iv, nil)
    end
  end

  def bolded(id, noun, name) = %(<pushBold/>a <a exist="#{id}" noun="#{noun}">#{name}</a><popBold/>)
  def prompt(t) = %(<prompt time="#{t}">&gt;</prompt>)
  def fury(lines) = described_class.parse_events(lines, include_attack_events: true).select { |e| e[:name] == :earthen_fury }
  def whose(e) = e[:foreign_caster] ? :theirs : (e[:unowned] ? :nobodys : :ours)

  let(:masto) { bolded(248_970_422, 'mastodon', 'heavily armored battle mastodon') }
  let(:masto2) { bolded(248_970_412, 'mastodon', 'heavily armored battle mastodon') }
  let(:wizard) { '<a exist="-10000001" noun="Wizard">Wizard</a>' }
  let(:opening) { "The ground beneath #{masto} suddenly frosts and rumbles violently!" }
  let(:eruption) do
    ['The earth cracks beneath a heavily armored battle mastodon, releasing a column of frigid air!',
     '[SMR result: 196 (Open d100: 72, Bonus: 43)]', '   ... 35 points of damage!']
  end

  it "keeps a nearby player's later eruption theirs, bound to the creature (real lines)" do
    first = fury(["#{wizard} gestures at #{masto}.", opening, *eruption, prompt(100)])
    later = fury([*eruption, prompt(103)])
    expect(first.map { |e| whose(e) }).to eq([:theirs])
    expect(later.map { |e| [whose(e), e[:target][:id]] }).to eq([[:theirs, 248_970_422]])
  end

  it 'makes our own later eruption ours, bound to the creature (first-person cast from a GS4 log)' do
    fanatic = bolded(183_810_038, 'fanatic', 'triton fanatic')
    hit = ['Craggy debris explodes from the ground beneath a triton fanatic!', '[SMR result: 165 (Open d100: 26)]', '   ... 35 points of damage!']
    first = fury(["You gesture at #{fanatic}.", "The ground beneath #{fanatic} begins to boil violently!", *hit, prompt(100)])
    later = fury([*hit, prompt(103)])
    expect(first.map { |e| whose(e) }).to eq([:ours])
    expect(later.map { |e| [whose(e), e[:target][:id], e[:hits].map { |h| h[:damage] }] }).to eq([[:ours, 183_810_038, [35]]])
  end

  it "files an eruption with no opening on record as nobody's (walked into a running spell)" do
    expect(fury([*eruption, prompt(100)]).map { |e| whose(e) }).to eq([:nobodys])
  end

  it 'forgets the spell at its closing line' do
    fury(["You gesture at #{masto}.", opening, *eruption, prompt(100)])
    fury(["The ground beneath #{masto} suddenly calms.", prompt(101)])
    expect(fury([*eruption, prompt(102)]).map { |e| whose(e) }).to eq([:nobodys])
  end

  it 'keeps the sixth cycle, 10 seconds after the opening, ours' do
    fury(["You gesture at #{masto}.", opening, *eruption, prompt(100)])
    expect(fury([*eruption, prompt(110)]).map { |e| whose(e) }).to eq([:ours])
  end

  it 'forgets the spell once its cycles are over, however recent the last eruption' do
    fury(["You gesture at #{masto}.", opening, *eruption, prompt(100)])
    fury([*eruption, prompt(110)])
    expect(fury([*eruption, prompt(100 + described_class::RUNNING_SPELL_SECONDS[:earthen_fury] + 1)]).map { |e| whose(e) }).to eq([:nobodys])
  end

  it "keeps our eruption ours when another player's gesture is in the chunk (the chunk latch does not take it)" do
    fury(["You gesture at #{masto}.", opening, *eruption, prompt(100)])
    warg = bolded(5, 'warg', 'niveous giant warg')
    later = fury(["#{wizard} gestures at #{warg}.", *eruption, prompt(102)])
    expect(later.map { |e| whose(e) }).to eq([:ours])
  end

  it "is nobody's when same-named creatures carry spells of different casters and nothing says which" do
    fury(["You gesture at #{masto}.", opening, prompt(100)])
    fury(["#{wizard} gestures at #{masto2}.", "The ground beneath #{masto2} suddenly frosts and rumbles violently!", prompt(101)])
    expect(fury([*eruption, prompt(102)]).map { |e| whose(e) }).to eq([:nobodys])
  end

  it "files a creature's eruption on a groupmate as the groupmate's, never ours (real lines)" do
    pal = '<a exist="-11202358" noun="Pal">Pal</a>'
    grotesque = '<pushBold/>A <a exist="122350349" noun="grotesque">horned basalt grotesque</a><popBold/>'
    hit = ['Fiery debris explodes from the ground beneath Pal!', '[SMR result: 160 (Open d100: 39)]', '   ... 20 points of damage!']
    first = fury(["You swing a broadsword at #{masto}!", "#{grotesque} twists a stony claw toward #{pal}!",
                  "The ground beneath #{pal} begins to boil violently!", *hit, prompt(100)])
    later = fury([*hit, prompt(102)])
    expect((first + later).map { |e| [e[:foreign_target], e[:target][:id]] }).to eq([[true, nil], [true, nil]])
  end

  it 'takes the one owner when same-named creatures all carry the same caster\'s spell' do
    fury(["You gesture at #{masto}.", opening, prompt(100)])
    fury(["You gesture at #{masto2}.", "The ground beneath #{masto2} suddenly frosts and rumbles violently!", prompt(101)])
    expect(fury([*eruption, prompt(102)]).map { |e| whose(e) }).to eq([:ours])
  end
end
