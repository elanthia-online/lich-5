# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/parser'
require 'gemstone/combat/processor'

# Meteor Swarm (525) since its 2026-11 update: the cast, then meteor cycles
# every 3 seconds in later chunks, each line naming the creature it hits but
# never the caster.
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

  def bolded(id, noun, name, article = 'a') = %(<pushBold/>#{article} <a exist="#{id}" noun="#{noun}">#{name}</a><popBold/>)
  def prompt(t) = %(<prompt time="#{t}">&gt;</prompt>)
  def meteors(lines) = described_class.parse_events(lines, include_attack_events: true).select { |e| e[:name] == :meteor_swarm }
  def whose(e) = e[:foreign_caster] ? :theirs : (e[:unowned] ? :nobodys : :ours)

  let(:ravager) { bolded(6_936_599, 'ravager', 'corpulent kresh ravager') }
  let(:thrall) { bolded(6_941_623, 'thrall', 'disfigured hive thrall') }

  # Real lines from a GS4 log (2026-11-28).
  let(:cast) do
    ["You gesture at #{ravager}.",
     'Celestial sigils scintillate in the air around you as you gesture heavenward, reaching into the blackness beyond the skies.',
     'An ominous roar of parting air resounds in the distance, making the ground underfoot tremble.',
     '[MDR result: 251 (Open d100: 88, Bonus: 103)]',
     "#{bolded(6_936_599, 'ravager', 'corpulent kresh ravager', 'A')} casts about wildly, too panicked to act!",
     'Cast Roundtime 1 Second.', prompt(100)]
  end
  let(:cycle) do
    ['A deafening crash from above rocks the area.  Massive chunks of debris rain down around you!', '',
     '[SMR result: 144 (Open d100: 22, Bonus: 72)]',
     "Blazing meteorite fragments crash down onto #{ravager}, dealing 43 damage!",
     '   ... 20 points of damage!', '   Left hand smashed into a pulpy mass.', '',
     '[SMR result: 155 (Open d100: 68, Bonus: 26)]',
     "Blazing meteorite fragments crash down onto #{thrall}, dealing 47 damage!",
     '   ... 20 points of damage!', '   Right kneecap smashed into pulp.', '   It is knocked to the ground!',
     '   The <pushBold/><a exist="6941623" noun="thrall">hive thrall</a><popBold/> is stunned!']
  end
  let(:later) { ['Huge chunks of debris continue to fall in a deadly rain!', *cycle.drop(2)] }

  it 'counts both the inline damage and the damage line, which the creature loses both of (real lines)' do
    meteors(cast)
    events = meteors([*cycle, prompt(103)])
    expect(events.map { |e| [e[:target][:id], e[:hits].map { |h| h[:damage] }, whose(e)] })
      .to eq([[6_936_599, [43, 20], :ours], [6_941_623, [47, 20], :ours]])
  end

  it 'gives each hit the roll printed before it' do
    meteors(cast)
    expect(meteors([*cycle, prompt(103)]).map { |e| e[:resolutions].map { |r| r[:total] || r[:result] } }).to eq([[144], [155]])
  end

  it 'keeps a cycle late in the swarm ours (up to ten cycles, one every 3 seconds)' do
    meteors(cast)
    expect(meteors([*later, prompt(129)]).map { |e| whose(e) }).to eq(%i[ours ours])
  end

  it "files meteors with no cast on record as nobody's (someone else's swarm)" do
    expect(meteors([*later, prompt(100)]).map { |e| whose(e) }).to eq(%i[nobodys nobodys])
  end

  it 'forgets the swarm when the meteors cease' do
    meteors(cast)
    meteors(['Terrible silence blankets the area as the meteors cease to fall.', prompt(110)])
    expect(meteors([*later, prompt(111)]).map { |e| whose(e) }).to eq(%i[nobodys nobodys])
  end

  it 'forgets the swarm once its cycles are over' do
    meteors(cast)
    later_at = 100 + described_class::RUNNING_SPELL_SECONDS[:meteor_swarm] + 1
    expect(meteors([*later, prompt(later_at)]).map { |e| whose(e) }).to eq(%i[nobodys nobodys])
  end
end
