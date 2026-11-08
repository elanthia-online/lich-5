# frozen_string_literal: true

require_relative '../spec_helper'
require 'stash'

# A GameObj the production code recognises as one (is_a? GameObj) whose contents
# a spec controls, so a container can hold a stale listing.
class StashHandsItem < Lich::Common::GameObj
  attr_accessor :id, :noun, :name, :type, :contents

  def initialize(id: nil, noun: nil, name: 'Empty', type: nil, contents: nil)
    super(id, noun, name)
    @type = type
    @contents = contents
  end
end

RSpec.describe Lich::Stash, 'stash_hands' do
  let(:handaxe) { StashHandsItem.new(id: '27021754', noun: 'handaxe', name: 'xazkruvrixis handaxe', type: 'weapon') }
  let(:other_item) { StashHandsItem.new(id: '27000001', noun: 'orb', name: 'green orb', type: 'gem') }
  let(:empty) { StashHandsItem.new }

  # contents is a non-nil listing that never gains the item: the game does not
  # report the put, so add_to_bag cannot confirm it. The containers entry keeps
  # the belt out of @weapon_displayer, as it was in the failing session.
  let(:belt)  { StashHandsItem.new(id: '22255243', noun: 'swordbelt', name: 'leather swordbelt', type: 'container', contents: []) }
  let(:bag)   { StashHandsItem.new(id: '22255205', noun: 'bag', name: 'indigo bag', type: 'container', contents: []) }
  let(:cloak) { StashHandsItem.new(id: '22255278', noun: 'cloak', name: 'stalking cloak', type: 'container', contents: []) }

  let(:hands) { { right: empty, left: empty } }
  let(:sent) { [] }
  let(:issued) { [] }
  # Called with the command for each fput; models what the game does with it.
  let(:game) { ->(_command) {} }

  def hold(hand, item)
    hands[hand] = item
  end

  def drags
    sent.grep(/\A_drag /)
  end

  before do
    described_class.instance_variable_set(:@weapon_displayer, [])
    described_class.instance_variable_set(:@bandolier_weapon, {})
    described_class.instance_variable_set(:@worn_items, {})
    $fill_hands_actions = []
    $fill_left_hand_actions = []
    $fill_right_hand_actions = []

    allow(GameObj).to receive(:right_hand) { hands[:right] }
    allow(GameObj).to receive(:left_hand) { hands[:left] }
    allow(GameObj).to receive(:inv).and_return([bag, belt, cloak])
    allow(GameObj).to receive(:containers).and_return([belt, bag, cloak].to_h { |c| [c.id, c.contents] })

    stub_const('ReadyList', Module.new do
      def self.valid? = true
      def self.sheath = @sheath

      def self.sheath=(value)
        @sheath = value
      end

      def self.secondary_sheath = nil
      def self.ready_list = @ready_list ||= {}
      def self.store_list = @store_list ||= {}
    end)
    ReadyList.sheath = belt
    stub_const('StowList', Module.new do
      def self.valid? = true
      def self.default = nil
    end)
    stub_const('UserVars', Module.new do
      def self.weapon = nil
      def self.weaponsack = nil
      def self.lootsack = nil
    end)

    listing = [
      %(<a exist="#{bag.id}" noun="bag">indigo bag</a>),
      %(<a exist="#{belt.id}" noun="swordbelt">leather swordbelt</a>),
      %(<a exist="#{cloak.id}" noun="cloak">stalking cloak</a>)
    ]
    stub_const('Lich::Util', Module.new)
    allow(Lich::Util).to receive(:issue_command) do |command, *_rest, **_opts|
      issued << command
      listing
    end

    allow(described_class).to receive(:waitrt?)
    allow(described_class).to receive(:sleep)
    allow(described_class).to receive(:wait_until) { |&check| check.call }
    allow(described_class).to receive(:fput) do |command|
      sent << command
      game.call(command)
      'You put something somewhere.'
    end
  end

  %i[left right].each do |hand|
    context "when the #{hand} hand's drag lands but the container listing stays stale" do
      let(:game) { ->(command) { hold(hand, empty) if command.start_with?('_drag') } }

      before { hold(hand, handaxe) }

      it 'sends the one drag and no drag with a blank id' do
        described_class.stash_hands(hand => true)
        expect(drags).to eq(["_drag #27021754 #22255243"])
      end

      it 'does not list containers to look for another home' do
        described_class.stash_hands(hand => true)
        expect(issued).not_to include('inventory containers')
      end

      it 'still queues the restore for the item it stashed' do
        described_class.stash_hands(hand => true)
        stack = hand == :left ? $fill_left_hand_actions : $fill_right_hand_actions
        expect(stack.length).to eq(1)

        sent.clear
        allow(described_class).to receive(:dothistimeout)
        stack.pop.each(&:call)
        expect(sent).to include('get #27021754')
      end
    end
  end

  it 'stops after the ready-list sheath drag when the item came from there' do
    ReadyList.ready_list[:secondary] = handaxe
    ReadyList.store_list[:secondary] = 'put in sheath'
    hold(:left, handaxe)
    allow(described_class).to receive(:fput) do |command|
      sent << command
      hold(:left, empty)
    end

    described_class.stash_hands(both: true)
    expect(drags).to eq(["_drag #27021754 #22255243"])
  end

  it 'stashes both hands without a blank drag when neither listing updates' do
    broadsword = StashHandsItem.new(id: '27004004', noun: 'broadsword', name: 'xazkruvrixis broadsword', type: 'weapon')
    hold(:left, handaxe)
    hold(:right, broadsword)
    allow(described_class).to receive(:fput) do |command|
      sent << command
      hold(:left, empty) if command.include?('#27021754')
      hold(:right, empty) if command.include?('#27004004')
    end

    described_class.stash_hands(both: true)
    expect(drags).to contain_exactly('_drag #27021754 #22255243', '_drag #27004004 #22255243')
    expect(issued).not_to include('inventory containers')
  end

  it 'sends no drag when the hand empties before the first attempt' do
    hold(:left, handaxe)
    allow(described_class).to receive(:waitrt?) { hold(:left, empty) }

    described_class.stash_hands(left: true)
    expect(sent).to be_empty
    expect(issued).to be_empty
  end

  context 'when the drag really fails and the item stays in hand' do
    before { hold(:left, handaxe) }

    it 'walks the other containers by the original id and stops at the first that takes it' do
      allow(described_class).to receive(:fput) do |command|
        sent << command
        if command == '_drag #27021754 #22255205'
          hold(:left, empty)
          bag.contents = [handaxe]
        end
      end

      described_class.stash_hands(left: true)
      expect(issued).to include('inventory containers')
      expect(drags).to eq(['_drag #27021754 #22255243', '_drag #27021754 #22255205'])
    end

    it 'keeps trying every container while the item is still held' do
      described_class.stash_hands(left: true)
      expect(drags).to eq([
                            '_drag #27021754 #22255243',
                            '_drag #27021754 #22255205',
                            '_drag #27021754 #22255243',
                            '_drag #27021754 #22255278'
                          ])
    end

    it 'stops the walk when a fallback drag lands but cannot be confirmed' do
      allow(described_class).to receive(:fput) do |command|
        sent << command
        hold(:left, empty) if command == '_drag #27021754 #22255205'
      end

      described_class.stash_hands(left: true)
      expect(drags).to eq(['_drag #27021754 #22255243', '_drag #27021754 #22255205'])
    end

    it 'does not stash a different item that replaced the original in that hand' do
      allow(described_class).to receive(:fput) do |command|
        sent << command
        hold(:left, other_item)
      end

      described_class.stash_hands(left: true)
      expect(drags).to eq(['_drag #27021754 #22255243'])
      expect(issued).not_to include('inventory containers')
    end
  end

  it 'stops the right hand walk when a fallback drag lands but cannot be confirmed' do
    hold(:right, handaxe)
    allow(described_class).to receive(:fput) do |command|
      sent << command
      hold(:right, empty) if command == '_drag #27021754 #22255205'
    end

    described_class.stash_hands(right: true)
    expect(drags).to eq(['_drag #27021754 #22255243', '_drag #27021754 #22255205'])
  end

  { left: :right, right: :left }.each do |hand, other_hand|
    it "keeps dragging the original when it moved to the #{other_hand} hand and another item took the #{hand}" do
      hold(hand, handaxe)
      allow(described_class).to receive(:fput) do |command|
        sent << command
        hold(other_hand, handaxe)
        hold(hand, other_item)
      end

      described_class.stash_hands(hand => true)
      expect(drags).to eq([
                            '_drag #27021754 #22255243',
                            '_drag #27021754 #22255205',
                            '_drag #27021754 #22255243',
                            '_drag #27021754 #22255278'
                          ])
    end
  end

  describe '.add_to_bag' do
    it 'sends nothing and looks in nothing for an empty hand' do
      bag.contents = nil
      expect(described_class.add_to_bag(bag, empty)).to be(false)
      expect(sent).to be_empty
      expect(issued).to be_empty
    end

    it 'sends nothing for a nil item' do
      expect(described_class.add_to_bag(bag, nil)).to be(false)
      expect(sent).to be_empty
    end

    it 'returns false when the item left the hand but never appeared in the listing' do
      hold(:left, handaxe)
      allow(described_class).to receive(:fput) { hold(:left, empty) }
      expect(described_class.add_to_bag(belt, handaxe)).to be(false)
    end

    it 'returns true once the item is out of the hand and in the listing' do
      hold(:left, handaxe)
      allow(described_class).to receive(:fput) do
        hold(:left, empty)
        belt.contents = [handaxe]
      end
      expect(described_class.add_to_bag(belt, handaxe)).to be(true)
    end
  end
end
