# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/parser'
require 'gemstone/combat/processor'

# Message statuses are applied while the chunk is being PARSED; crit-derived
# statuses are applied later, in persist_event. A creature knocked down by a
# crit and then standing up in the same chunk was therefore left prone: the
# stand-up removed the position during parsing, and the earlier knockdown
# re-applied it afterwards. State must end where the LAST message in the
# chunk left it.
RSpec.describe Lich::Gemstone::Combat::Processor do
  let(:creature) do
    Class.new do
      attr_reader :id, :name, :noun, :statuses

      def initialize
        @id = 777
        @name = 'a cave lizard'
        @noun = 'lizard'
        @statuses = []
      end

      def add_status(status, _value = nil) = @statuses |= [status.to_s]
      def remove_status(status) = @statuses.delete(status.to_s)
      def has_status?(status) = @statuses.include?(status.to_s)
      def add_damage(_amount); end
      def add_injury(_part, _rank); end
      def injuries = {}
      def add_stun_estimate(_rounds, at: nil); end
      def dead? = false
      def crtr_flag?(_flag) = false
      def prone? = has_status?('prone')
    end.new
  end

  before do
    stub_const('Lich::Gemstone::Combat::Tracker', Module.new)
    allow(Lich::Gemstone::Combat::Tracker).to receive(:settings).and_return(
      track_statuses: true, track_ucs: false, emit_attacks: false,
      track_damage: true, track_wounds: true
    )
    allow(Lich::Gemstone::Combat::Tracker).to receive(:debug?).and_return(false)
    stub_const('Lich::Gemstone::Combat::Observers', Module.new)
    allow(Lich::Gemstone::Combat::Observers).to receive(:emit)
    allow(Lich::Gemstone::Combat::Observers).to receive(:any_for?).and_return(false)
    subject_creature = creature
    registry = Class.new do
      define_singleton_method(:[]) { |_id| subject_creature }
      define_singleton_method(:all) { [subject_creature] }
    end
    stub_const('Lich::Gemstone::Combat::Creature', registry)
    %i[@death_watch @death_announced @held_cast @held_pre_flares @deferred_emits].each do |iv|
      described_class.instance_variable_set(iv, nil)
    end
  end

  def bolded(id, noun, name)
    %(<pushBold/><a exist="#{id}" noun="#{noun}">#{name}</a><popBold/>)
  end

  it 'leaves a creature that stood up after a knockdown crit standing' do
    lizard = bolded(777, 'lizard', 'a cave lizard')
    chunk = [
      "You swing a broadsword at #{lizard}!",
      '  AS: +300 vs DS: +100 with AvD: +30 + d100 roll: +50 = +280',
      '   ... and hit for 40 points of damage!',
      '   Hit on the leg chars the skin and eats into the underlying muscles.',
      "#{lizard} stands up.",
      '<prompt time="100">&gt;</prompt>'
    ]
    events = described_class.parse_events(chunk)
    events.each { |event| described_class.persist_event(event) }

    expect(creature.statuses).not_to include('prone'),
                                     'the earlier knockdown was re-applied over the later stand-up'
  end

  it 'lets a knockdown message after the stand-up win, being later still' do
    lizard = bolded(777, 'lizard', 'a cave lizard')
    chunk = [
      "You swing a broadsword at #{lizard}!",
      '  AS: +300 vs DS: +100 with AvD: +30 + d100 roll: +50 = +280',
      '   ... and hit for 40 points of damage!',
      '   Hit on the leg chars the skin and eats into the underlying muscles.',
      "#{lizard} stands up.",
      "#{lizard} is knocked to the ground!",
      '<prompt time="100">&gt;</prompt>'
    ]
    events = described_class.parse_events(chunk)
    events.each { |event| described_class.persist_event(event) }

    expect(creature.statuses).to include('prone')
  end

  it 'does not carry a recovery into the next chunk' do
    lizard = bolded(777, 'lizard', 'a cave lizard')
    described_class.parse_events(["#{lizard} stands up.", '<prompt time="100">&gt;</prompt>'])
    chunk = [
      "You swing a broadsword at #{lizard}!",
      '  AS: +300 vs DS: +100 with AvD: +30 + d100 roll: +50 = +280',
      '   ... and hit for 40 points of damage!',
      '   Hit on the leg chars the skin and eats into the underlying muscles.',
      '<prompt time="200">&gt;</prompt>'
    ]
    events = described_class.parse_events(chunk)
    events.each { |event| described_class.persist_event(event) }

    expect(creature.statuses).to include('prone')
  end

  # A single per-chunk flag could not tell a crit that came BEFORE the
  # stand-up from one that came after it, so a second genuine knockdown was
  # dropped - the mirror image of the bug above. Ordering is compared by
  # line, so each crit is judged against where the recovery actually sat.
  it 'lets a knockdown crit after the stand-up win, being later still' do
    lizard = bolded(777, 'lizard', 'a cave lizard')
    chunk = [
      "You swing a broadsword at #{lizard}!",
      '  AS: +300 vs DS: +100 with AvD: +30 + d100 roll: +50 = +280',
      '   ... and hit for 40 points of damage!',
      '   Hit on the leg chars the skin and eats into the underlying muscles.',
      "#{lizard} stands up.",
      "You swing a broadsword at #{lizard}!",
      '  AS: +300 vs DS: +100 with AvD: +30 + d100 roll: +50 = +280',
      '   ... and hit for 40 points of damage!',
      '   Hit on the leg chars the skin and eats into the underlying muscles.',
      '<prompt time="100">&gt;</prompt>'
    ]
    events = described_class.parse_events(chunk)
    events.each { |event| described_class.persist_event(event) }

    expect(creature.statuses).to include('prone'),
                                 'the later knockdown crit was suppressed by the earlier stand-up'
  end

  it 'still applies a knockdown crit when nothing later reverses it' do
    lizard = bolded(777, 'lizard', 'a cave lizard')
    chunk = [
      "You swing a broadsword at #{lizard}!",
      '  AS: +300 vs DS: +100 with AvD: +30 + d100 roll: +50 = +280',
      '   ... and hit for 40 points of damage!',
      '   Hit on the leg chars the skin and eats into the underlying muscles.',
      '<prompt time="100">&gt;</prompt>'
    ]
    events = described_class.parse_events(chunk)
    events.each { |event| described_class.persist_event(event) }

    expect(creature.statuses).to include('prone')
  end
end
