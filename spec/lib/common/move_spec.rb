# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/common/move'

# A harness for the top-level move() in lib/global_defs.rb: the method is
# extracted from the source and defined on a class that supplies every game
# primitive it touches (get?, put, fput, waitrt?, ...) as a scripted fake.
# Constants (XMLData, Script, Spell) resolve to the harness's own stand-ins
# because class_eval on a String sets the constant scope to the class.
#
# The stream is a queue of lines the "game" answers with. `put` records what
# was sent and may bump the room count to simulate arrival.
module MoveHarnessLich
  def self.log(msg); (@logged ||= []) << msg; end

  def self.logged = @logged ||= []
end

module Lich
  def self.log(msg) = MoveHarnessLich.log(msg) unless respond_to?(:log)
end

class MoveHarness
  module XMLData
    class << self
      attr_accessor :room_count, :encumbrance_text
    end
    self.room_count = 0
    self.encumbrance_text = ''
  end

  module Script
    Current = Struct.new(:downstream_buffer)
    def self.current = (@current ||= Current.new([]))
  end

  module Spell
    def self.[](_num) = nil
  end

  attr_reader :sent, :echoed, :lines

  def initialize(lines, arrive_after: nil)
    @lines = lines.dup
    @sent = []
    @echoed = []
    @arrive_after = arrive_after # send count at which the room changes
    XMLData.room_count = 0
    XMLData.encumbrance_text = ''
    Script.current.downstream_buffer.clear
    Lich::Common::Move.clear_failure
  end

  # --- game primitives -----------------------------------------------------
  def get? = @lines.shift

  def put(cmd)
    @sent << cmd.dup # move rewrites dir in place; keep what was actually sent
    XMLData.room_count += 1 if @arrive_after && @sent.length >= @arrive_after
  end

  def fput(cmd) = @sent << cmd.dup
  def echo(msg) = @echoed << msg
  def waitrt?; end
  def wait_while; end
  def wait_until; end
  def stunned? = false
  def standing? = true
  def checkleft = nil
  def checkright = nil
  def fill_hands; end
  def empty_hands; end
  def clear = []
  def reget = []
  def sleep(*); end
end

src = File.read(File.join(__dir__, '../../../lib/global_defs.rb'))
start = src.index("def move(dir = 'none'")
stop  = src.index("\ndef watchhealth")
MoveHarness.class_eval(src[start...stop], 'global_defs.rb#move')

RSpec.describe 'move()' do
  let(:move) { Lich::Common::Move }

  it 'returns true once the room count advances' do
    h = MoveHarness.new(['You walk north.'], arrive_after: 1)
    expect(h.move('north')).to be(true)
    expect(h.sent).to eq(['north'])
    expect(move.last_failure).to be_nil
  end

  it 'returns false on a bad exit and records a :map failure' do
    h = MoveHarness.new(["You can't go there."])
    expect(h.move('go hole')).to be(false)
    f = move.last_failure
    expect(f.dir).to eq('go hole')
    expect(f.line).to eq("You can't go there.")
    expect(f.cause).to eq(:map)
    expect(f.attempts).to eq(1)
    expect(f).to be_frozen
  end

  it 'returns nil (keep the exit) when an NPC refuses and records :denied' do
    h = MoveHarness.new(['An unseen force prevents you.'])
    expect(h.move('north')).to be_nil
    expect(move.last_failure.cause).to eq(:denied)
  end

  describe 'the stand loop' do
    let(:cannot) { 'You must be standing to do that.' }

    it 'used to retry forever; now gives up after MAX_REMEDIES stands' do
      h = MoveHarness.new([cannot] * 10)
      expect(h.move('north')).to be_nil
      stands = h.sent.count('stand')
      expect(stands).to eq(Lich::Common::Move::MAX_REMEDIES)
      expect(h.sent.count('north')).to eq(Lich::Common::Move::MAX_REMEDIES + 1)
      expect(h.echoed.last).to match(/stand did not help after 3 tries/)
    end

    it 'succeeds if a stand eventually works' do
      h = MoveHarness.new([cannot, cannot], arrive_after: 3)
      expect(h.move('north')).to be(true)
    end

    it 'blames the pack when overburdened' do
      h = MoveHarness.new([cannot] * 10)
      stub_const('XMLData', Class.new { def self.encumbrance_text = 'Overburdened' })
      h.move('north')
      expect(move.last_failure.cause).to eq(:encumbered)
    end

    it 'blames wounds when a limb is wounded' do
      h = MoveHarness.new([cannot] * 10)
      stub_const('XMLData', Class.new do
        def self.encumbrance_text = 'None'
        def self.injuries = { 'leftLeg' => { 'wound' => 2 } }
      end)
      stub_const('Lich::Gemstone::Wounds', Class.new { def self.limbs = 2 })
      h.move('north')
      expect(move.last_failure.cause).to eq(:injured)
    end

    it 'is :position when neither applies' do
      h = MoveHarness.new([cannot] * 10)
      h.move('north')
      expect(move.last_failure.cause).to eq(:position)
    end
  end

  it 'bounds every remedy independently' do
    h = MoveHarness.new(["You can't do that while engaged!"] * 10)
    expect(h.move('north')).to be_nil
    expect(h.sent.count('retreat')).to eq(2 * Lich::Common::Move::MAX_REMEDIES)
    expect(move.last_failure.cause).to eq(:engaged)
  end

  it 'gives climb rolls a longer leash' do
    fall = 'You start up the cliff but slip after a few feet and fall to the ground.'
    h = MoveHarness.new([fall] * 30)
    expect(h.move('climb cliff')).to be_nil
    expect(h.sent.count('climb cliff')).to eq(Lich::Common::Move::MAX_ROLLS + 1)
    expect(move.last_failure.cause).to eq(:climb)
  end

  it 'lets a climb succeed on a late roll' do
    fall = 'You start up the cliff but slip after a few feet and fall to the ground.'
    h = MoveHarness.new([fall] * 5, arrive_after: 6)
    expect(h.move('climb cliff')).to be(true)
  end

  it 'does not cap roundtime waits' do
    h = MoveHarness.new(['...wait 1 seconds.'] * 8, arrive_after: 9)
    expect(h.move('north')).to be(true)
    expect(h.sent.count('north')).to eq(9)
  end

  it 'no longer mutates the caller string when swapping go for climb' do
    way = 'go ledge'
    h = MoveHarness.new(['You will have to climb that.'], arrive_after: 2)
    expect(h.move(way)).to be(true)
    expect(way).to eq('go ledge')
    expect(h.sent).to eq(['go ledge', 'climb ledge'])
  end

  it 'records the injured cause when too hurt to climb and no Resolve' do
    h = MoveHarness.new(['You are too injured to be doing any climbing!'])
    expect(h.move('climb rope')).to be_nil
    expect(move.last_failure.cause).to eq(:injured)
  end

  it 'restores the consumed lines to the downstream buffer on failure' do
    h = MoveHarness.new(['Some chatter.', "You can't go there."])
    h.move('north')
    expect(MoveHarness::Script.current.downstream_buffer).to include('Some chatter.', "You can't go there.")
  end

  it 'emits move.failed on the Events board when present' do
    events = Class.new do
      class << self
        attr_reader :seen

        def emit(topic, payload) = (@seen ||= []) << [topic, payload]
      end
    end
    stub_const('Lich::Common::Events', events)
    h = MoveHarness.new(["You can't go there."])
    h.move('north')
    expect(events.seen.map(&:first)).to eq(['move.failed'])
    expect(events.seen.first.last.cause).to eq(:map)
  end

  it 'survives a raising Events.emit' do
    stub_const('Lich::Common::Events', Class.new { def self.emit(*) = raise('skew') })
    h = MoveHarness.new(["You can't go there."])
    expect(h.move('north')).to be(false)
    expect(move.last_failure.cause).to eq(:map)
  end

  describe Lich::Common::Move do
    it 'classifies the lines move already knows' do
      {
        'You are in far too much agony to do that.'                => :injured,
        'You are overburdened and cannot manage to stand.'         => :encumbered,
        'You need to retreat out of combat first!'                 => :engaged,
        "You can't enter the shop and remain hidden or invisible." => :hidden,
        "You'll need empty hands to climb that."                   => :hands,
        "Shouldn't you be standing first?"                         => :position,
        'The gate appears to be closed.'                           => :closed,
        'You may not pass.'                                        => :denied,
        'I could not find what you were referring to.'             => :map,
        '...wait 3 seconds.'                                       => :roundtime,
        'Something new the game said.'                             => :unknown,
        nil                                                        => :unknown
      }.each { |line, cause| expect(described_class.classify(line)).to eq(cause), line.inspect }
    end
  end
end
