# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/parser'
require 'gemstone/combat/processor'

# The bard fear cry rolls one SSR per creature, each printed BEFORE the line
# naming that creature. Each creature's roll must land on that creature's
# event, not pile up on the first one (review of #2499). The chunk is from a
# GS4 XML log; the cries are ours, so no player names appear.
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
    %i[@death_watch @death_announced @held_cast @held_pre_flares @deferred_emits].each do |iv|
      described_class.instance_variable_set(iv, nil)
    end
  end

  def bolded(id, noun, name) = %(<pushBold/>A <a exist="#{id}" noun="#{noun}">#{name}</a><popBold/>)

  def rolls_by_creature(lines)
    described_class.parse_events(lines, include_attack_events: true)
                   .map { |e| [e[:name], e[:target][:id], e[:resolutions].map { |r| r[:result] }] }
  end

  let(:myrmidon) { bolded(41_417_963, 'myrmidon', 'chitinous kiramon myrmidon') }
  let(:broodtender) { bolded(41_297_447, 'broodtender', 'bloated kiramon broodtender') }

  it 'gives each creature its own roll in a real four-creature cry' do
    other = bolded(41_314_214, 'myrmidon', 'chitinous kiramon myrmidon')
    stalker = bolded(41_415_867, 'stalker', 'sleek black kiramon stalker')
    lines = [
      "<roundTime value='1795627765'/>You let loose an eerie, modulating cry!",
      '[SSR result: 152 (Open d100: 23)]',
      "#{myrmidon} looks at you in utter terror!",
      "#{myrmidon} freezes in place, shaking with terror!",
      '[SSR result: 89 (Open d100: -25)]',
      "#{broodtender} is unaffected!",
      '[SSR result: 145 (Open d100: 16)]',
      "#{other} looks at you in utter terror!",
      "#{other} casts about wildly, too panicked to act!",
      '[SSR result: 185 (Open d100: 74)]',
      "#{stalker} is forced from hiding!",
      "#{stalker} looks at you in utter terror!",
      "#{stalker} freezes in place, shaking with terror!"
    ]
    expect(rolls_by_creature(lines)).to eq([
                                             [:fear_cry, 41_417_963, [152]],
                                             [:fear_cry, 41_297_447, [89]],
                                             [:fear_cry, 41_314_214, [145]],
                                             [:fear_cry, 41_415_867, [185]]
                                           ])
  end

  it 'splits two creatures\' rolls when each has a status line' do
    lines = [
      'You let loose an eerie, modulating cry!',
      '[SSR result: 152 (Open d100: 23)]', "#{myrmidon} looks at you in utter terror!", "#{myrmidon} freezes in place, shaking with terror!",
      '[SSR result: 120 (Open d100: 9)]', "#{broodtender} looks at you in utter terror!", "#{broodtender} freezes in place, shaking with terror!"
    ]
    expect(rolls_by_creature(lines)).to eq([[:fear_cry, 41_417_963, [152]], [:fear_cry, 41_297_447, [120]]])
  end

  it 'splits two creatures\' rolls when the first has no status line' do
    lines = [
      'You let loose an eerie, modulating cry!',
      '[SSR result: 152 (Open d100: 23)]', "#{myrmidon} looks at you in utter terror!", "#{myrmidon} casts about wildly, too panicked to act!",
      '[SSR result: 120 (Open d100: 9)]', "#{broodtender} looks at you in utter terror!", "#{broodtender} casts about wildly, too panicked to act!"
    ]
    expect(rolls_by_creature(lines)).to eq([[:fear_cry, 41_417_963, [152]], [:fear_cry, 41_297_447, [120]]])
  end

  # A nearby player's cry is a foreign_caster event, which by design never
  # switches targets (it is recorded for observers only), so its rolls stay
  # together, untargeted, as on main.
  it 'leaves a nearby player\'s cry as it was: one untargeted event' do
    bard = '<a exist="-10000001" noun="Bard">Bard</a>'
    lines = [
      "#{bard} lets loose an eerie, modulating cry!",
      '[SSR result: 152 (Open d100: 23)]', "#{myrmidon} looks at #{bard} in utter terror!",
      '[SSR result: 120 (Open d100: 9)]', "#{broodtender} looks at #{bard} in utter terror!"
    ]
    expect(rolls_by_creature(lines)).to eq([[:fear_cry, nil, [152, 120]]])
  end
end
