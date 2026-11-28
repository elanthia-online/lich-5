# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/parser'
require 'gemstone/combat/processor'

# Sandstorm (914): one opening engulfs the room, then one round per creature,
# its name never linked, and again at each surge (lich-5#2415: the creatures
# it killed never got a recorder row).
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
    %i[@death_watch @death_announced @held_cast @held_pre_flares @deferred_emits @running_spells @spell_victims_dead].each do |iv|
      described_class.instance_variable_set(iv, nil)
    end
    room(*creatures)
  end

  let(:creature) do
    Struct.new(:id, :noun, :name) do
      def crtr_flag?(_flag) = false
      def dead? = false
    end
  end
  let(:creatures) do
    [creature.new(31_726_976, 'ravager', 'corpulent kresh ravager'), creature.new(31_730_293, 'ravager', 'corpulent kresh ravager'),
     creature.new(31_721_305, 'myrmidon', 'chitinous kiramon myrmidon')]
  end

  def room(*list)
    registry = Class.new do
      define_singleton_method(:in_room) { |*_filters| list }
      define_singleton_method(:[]) { |_id| nil }
    end
    stub_const('Lich::Gemstone::Combat::Creature', registry)
  end

  def bolded(id, noun, name, article = 'a') = %(<pushBold/>#{article} <a exist="#{id}" noun="#{noun}">#{name}</a><popBold/>)
  def prompt(t) = %(<prompt time="#{t}">&gt;</prompt>)
  def storms(lines) = described_class.parse_events(lines, include_attack_events: true).select { |e| e[:name] == :sandstorm }
  def whose(e) = e[:foreign_caster] ? :theirs : (e[:unowned] ? :nobodys : :ours)

  let(:aimed) { bolded(31_726_976, 'ravager', 'corpulent kresh ravager') }
  let(:opening) { 'Sand bursts from the ground at your feet, spiraling up on a rising wind as it builds into a shrieking cyclone that engulfs the area!' }
  let(:surge) { 'The sandstorm surges, flinging another wall of stinging sand across the area!' }
  let(:myrmidon_round) do
    ['[SMR result: 102 (Open d100: 21, Bonus: 13)]', 'The sandstorm scours a chitinous kiramon myrmidon with a blast of sand!', '   ... 5 points of damage!']
  end

  # A real cast from a GS4 log: the wand aims at one ravager, the storm hits
  # both ravagers and a myrmidon, and kills the second ravager.
  let(:cast) do
    ["You wave your <a exist=\"31730357\" noun=\"corndog\">glitter-coated corndog</a> at #{aimed}.",
     '  1d100: 48 + Modifiers: 385 == 433', '', opening, '',
     '[SMR result: 217 (Open d100: 69, Bonus: 74)]',
     'The sandstorm buffets a corpulent kresh ravager with violent, swirling winds!',
     '   ... 45 points of damage!',
     "   Strike to stomach sends #{bolded(31_726_976, 'ravager', 'kresh ravager', 'the')} doubling over to the ground.",
     '   It is knocked to the ground!', '',
     *myrmidon_round,
     '   Blow connects with abdomen.',
     "The windblown sand blinds #{bolded(31_721_305, 'myrmidon', 'chitinous kiramon myrmidon')}!", '',
     '[SMR result: 218 (Open d100: 59, Bonus: 78)]',
     'The sandstorm scours a corpulent kresh ravager with a blast of sand!',
     '   ... 50 points of damage!',
     '   Hard strike removes the right eye and a goodly bit of skull!',
     "With a thunderous crash, #{bolded(31_730_293, 'ravager', 'corpulent kresh ravager')} falls to the ground, tiny legs kicking at the air before going still.",
     'Cast Roundtime 1 Second.', prompt(100)]
  end

  it 'gives each creature in the room its own round and damage, ours (real lines)' do
    events = storms(cast)
    expect(events.map { |e| [e[:target][:id], e[:hits].map { |h| h[:damage] }, whose(e)] })
      .to eq([[31_726_976, [45], :ours], [31_721_305, [5], :ours], [31_730_293, [50], :ours]])
  end

  it 'keeps the storm damage off the creature the wand aimed at' do
    wand = described_class.parse_events(cast, include_attack_events: true).find { |e| e[:name] == :wand }
    expect(wand[:hits]).to be_empty
  end

  it 'keeps a surge a few seconds after our cast ours (real lines)' do
    storms(cast)
    expect(storms([surge, '', *myrmidon_round, prompt(104)]).map { |e| [e[:target][:id], whose(e)] }).to eq([[31_721_305, :ours]])
  end

  it 'binds a linked miss to its creature (real lines)' do
    storms(cast)
    miss = "The sandstorm whips around #{bolded(31_721_305, 'myrmidon', 'chitinous kiramon myrmidon')}, but finds no purchase."
    expect(storms([surge, '[SMR result: 99 (Open d100: 26)]', miss, prompt(103)]).map { |e| [e[:target][:id], e[:hits], whose(e)] })
      .to eq([[31_721_305, [], :ours]])
  end

  it "files a surge with no cast on record as nobody's (walked into someone's storm)" do
    expect(storms([surge, *myrmidon_round, prompt(100)]).map { |e| whose(e) }).to eq([:nobodys])
  end

  it 'forgets the storm once its surges are over' do
    storms(cast)
    later = 100 + described_class::RUNNING_SPELL_SECONDS[:sandstorm] + 1
    expect(storms([surge, *myrmidon_round, prompt(later)]).map { |e| whose(e) }).to eq([:nobodys])
  end

  it 'forgets the storm when it blows itself out' do
    storms(cast)
    storms(['The sandstorm blows itself out, and the last of the windblown sand settles to the ground.', prompt(102)])
    expect(storms([surge, *myrmidon_round, prompt(103)]).map { |e| whose(e) }).to eq([:nobodys])
  end
end
