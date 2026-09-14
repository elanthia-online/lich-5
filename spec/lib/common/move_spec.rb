# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/common/move'

# Lich::Common::Move.move reads the game through the script-context
# primitives (get?, put, fput, waitrt?, ...) that global_defs defines at top
# level. The fake below is prepended to Move's singleton so those calls hit
# a scripted stream instead: a queue of lines the "game" answers with, and a
# record of what was sent. `put` may bump the room count to simulate arrival.
module Lich
  def self.log(msg); (@logged ||= []) << msg; end unless respond_to?(:log)
end

class MoveGame
  attr_reader :sent, :echoed, :buffer
  attr_accessor :room_count, :encumbrance_text

  def initialize(lines, arrive_after: nil)
    @lines = lines.dup
    @sent = []
    @echoed = []
    @arrive_after = arrive_after # put count (remedies included) at which the room changes
    @room_count = 0
    @encumbrance_text = ''
    @buffer = []
  end

  def get? = @lines.shift

  def put(cmd)
    @sent << cmd.dup # move rewrites dir in place; keep what was actually sent
    @room_count += 1 if @arrive_after && @sent.length >= @arrive_after
  end
end

module MoveFakePrimitives
  def game = Thread.current[:move_game]
  def get? = game.get?
  def put(cmd) = game.put(cmd)
  # The real fput answers "You struggle, but fail to stand." by calling
  # fput('stand') again, forever. Move must never route a remedy through it.
  def fput(cmd) = raise("move routed #{cmd.inspect} through fput")
  def echo(msg) = game.echoed << msg
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
Lich::Common::Move.singleton_class.prepend(MoveFakePrimitives)

RSpec.describe Lich::Common::Move do
  let(:move) { described_class }

  # Wire a scripted game up for one example and run move against it.
  def game(lines, arrive_after: nil)
    g = MoveGame.new(lines, arrive_after: arrive_after)
    Thread.current[:move_game] = g
    stub_const('XMLData', Class.new)
    XMLData.define_singleton_method(:room_count) { g.room_count }
    XMLData.define_singleton_method(:encumbrance_text) { g.encumbrance_text }
    stub_const('Script', Class.new)
    Script.define_singleton_method(:current) { Struct.new(:downstream_buffer).new(g.buffer) }
    # Spell resolves lexically to Lich::Common::Spell when lib/common/spell.rb
    # is loaded (the full suite) and to ::Spell when it is not (standalone).
    no_spell = Class.new { def self.[](_n) = nil }
    stub_const('Spell', no_spell)
    stub_const('Lich::Common::Spell', no_spell)
    described_class.clear_failure
    g
  end

  it 'returns true once the room count advances' do
    g = game(['You walk north.'], arrive_after: 1)
    expect(move.move('north')).to be(true)
    expect(g.sent).to eq(['north'])
    expect(move.last_failure).to be_nil
  end

  it 'returns false on a bad exit and records a :map failure' do
    game(["You can't go there."])
    expect(move.move('go hole')).to be(false)
    f = move.last_failure
    expect(f.dir).to eq('go hole')
    expect(f.line).to eq("You can't go there.")
    expect(f.cause).to eq(:map)
    expect(f.attempts).to eq(1)
    expect(f).to be_frozen
  end

  it 'returns nil (keep the exit) when an NPC refuses and records :denied' do
    game(['An unseen force prevents you.'])
    expect(move.move('north')).to be_nil
    expect(move.last_failure.cause).to eq(:denied)
  end

  describe 'the stand loop' do
    let(:cannot) { 'You must be standing to do that.' }

    let(:struggle) { 'You struggle, but fail to stand.' }

    it 'used to retry forever; now gives up after MAX_REMEDIES stands' do
      # each cycle: "must be standing" -> stand -> "struggle" -> re-send
      g = game([cannot, struggle] * 10)
      expect(move.move('north')).to be_nil
      expect(g.sent.count('stand')).to eq(described_class::MAX_REMEDIES)
      expect(g.sent.count('north')).to eq(described_class::MAX_REMEDIES + 1)
      expect(g.echoed.last).to match(/stand did not help after 3 tries/)
      expect(move.last_failure.line).to eq(struggle)
    end

    it 'sends stand once per remedy and reads the reply itself (never via fput)' do
      g = game([cannot, struggle, cannot, 'You stand back up.'], arrive_after: 5)
      expect(move.move('north')).to be(true)
      expect(g.sent).to eq(['north', 'stand', 'north', 'stand', 'north'])
    end

    it 'honors one roundtime reply to the stand itself' do
      g = game([cannot, '...wait 2 seconds.', 'You stand back up.'], arrive_after: 4)
      expect(move.move('north')).to be(true)
      expect(g.sent).to eq(['north', 'stand', 'stand', 'north'])
    end

    it 'succeeds if a stand eventually works' do
      game([cannot, struggle, cannot, 'You stand back up.'], arrive_after: 5)
      expect(move.move('north')).to be(true)
    end

    it 'blames the pack when overburdened' do
      g = game([cannot, struggle] * 10)
      g.encumbrance_text = 'Overburdened'
      move.move('north')
      expect(move.last_failure.cause).to eq(:encumbered)
    end

    it 'blames wounds when a limb is wounded' do
      game([cannot, struggle] * 10)
      XMLData.define_singleton_method(:injuries) { { 'leftLeg' => { 'wound' => 2 } } }
      stub_const('Lich::Gemstone::Wounds', Class.new { def self.limbs = 2 })
      move.move('north')
      expect(move.last_failure.cause).to eq(:injured)
    end

    it 'is :position when neither applies' do
      game([cannot, struggle] * 10)
      move.move('north')
      expect(move.last_failure.cause).to eq(:position)
    end
  end

  it 'bounds every remedy independently' do
    g = game(["You can't do that while engaged!"] * 10)
    expect(move.move('north')).to be_nil
    expect(g.sent.count('retreat')).to eq(2 * described_class::MAX_REMEDIES)
    expect(move.last_failure.cause).to eq(:engaged)
  end

  it 'names a swim, drag or guard failure from the shared roll branch' do
    nook = 'Tentatively, you attempt to swim through the nook.  After only a few feet, you begin to sink!  Your lungs burn from lack of air, and you begin to panic!  You frantically paddle back to safety!'
    game([nook] * 30)
    expect(move.move('swim nook')).to be_nil
    expect(move.last_failure.cause).to eq(:swim)

    game(['You grab Bob and try to drag him, but he is too heavy.'] * 30)
    expect(move.move('go gate')).to be_nil
    expect(move.last_failure.cause).to eq(:drag)

    game(['Guardsman Ralof stops you and says, "Halt!  You need to make sure you check in first."'] * 30)
    expect(move.move('go gate')).to be_nil
    expect(move.last_failure.cause).to eq(:denied)
  end

  it 'gives climb rolls a longer leash' do
    fall = 'You start up the cliff but slip after a few feet and fall to the ground.'
    g = game([fall] * 30)
    expect(move.move('climb cliff')).to be_nil
    expect(g.sent.count('climb cliff')).to eq(described_class::MAX_ROLLS + 1)
    expect(move.last_failure.cause).to eq(:climb)
  end

  it 'lets a climb succeed on a late roll' do
    fall = 'You start up the cliff but slip after a few feet and fall to the ground.'
    game([fall] * 5, arrive_after: 6)
    expect(move.move('climb cliff')).to be(true)
  end

  it 'does not cap roundtime waits' do
    g = game(['...wait 1 seconds.'] * 8, arrive_after: 9)
    expect(move.move('north')).to be(true)
    expect(g.sent.count('north')).to eq(9)
  end

  it 'no longer mutates the caller string when swapping go for climb' do
    way = 'go ledge'
    g = game(['You will have to climb that.'], arrive_after: 2)
    expect(move.move(way)).to be(true)
    expect(way).to eq('go ledge')
    expect(g.sent).to eq(['go ledge', 'climb ledge'])
  end

  it 'records the injured cause when too hurt to climb and no Resolve' do
    game(['You are too injured to be doing any climbing!'])
    expect(move.move('climb rope')).to be_nil
    expect(move.last_failure.cause).to eq(:injured)
  end

  it 'restores the consumed lines to the downstream buffer on failure' do
    g = game(['Some chatter.', "You can't go there."])
    move.move('north')
    expect(g.buffer).to include('Some chatter.', "You can't go there.")
  end

  it 'emits move.failed on the Events board when present' do
    events = Class.new do
      class << self
        attr_reader :seen

        def emit(topic, payload) = (@seen ||= []) << [topic, payload]
      end
    end
    stub_const('Lich::Common::Events', events)
    game(["You can't go there."])
    move.move('north')
    expect(events.seen.map(&:first)).to eq(['move.failed'])
    expect(events.seen.first.last.cause).to eq(:map)
  end

  it 'survives a raising Events.emit' do
    stub_const('Lich::Common::Events', Class.new { def self.emit(*) = raise('skew') })
    game(["You can't go there."])
    expect(move.move('north')).to be(false)
    expect(move.last_failure.cause).to eq(:map)
  end

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
      "You can't swim in that direction."                        => :map,
      'You flounder around in the water.'                        => :swim,
      '...wait 3 seconds.'                                       => :roundtime,
      'Something new the game said.'                             => :unknown,
      nil                                                        => :unknown
    }.each { |line, cause| expect(described_class.classify(line)).to eq(cause), line.inspect }
  end
end
