# frozen_string_literal: true

require 'ostruct'
require 'timeout'
require_relative '../../../spec_helper'
require_relative '../../../../lib/dragonrealms/commons/common'
require_relative '../../../../lib/dragonrealms/commons/common-items'

# DRCI.dispose_trash with a worn bucket that may not flush.
#
# The bucket's lines are verbatim from game logs (Defileous,
# 2026-11-10_21-07-20.log):
#   You drum your fingers on the bucket rhythmically.
#   [OOC: TAP the bucket again within the next 30 seconds to flush it.].
#   After a moment, a dull *THUD* echoes from within the bucket.
# and, for an hour and a half on 2026-11-10, a TAP that did nothing:
#   You tap a portable silversteel bucket with a flared rim that you are wearing.
# An item left in the bucket unflushed came flying out about five minutes later
# ("Some wool yarn comes flying out of the bucket as a voice within says, ...")
# onto the floor where its wearer was, and was later picked up again.
RSpec.describe 'DRCI.dispose_trash with a worn trash can that may not flush' do
  let(:drci) { Lich::DragonRealms::DRCI }

  let(:primed) { '[OOC: TAP the bucket again within the next 30 seconds to flush it.].' }
  let(:no_effect) { 'You tap a portable silversteel bucket with a flared rim that you are wearing.' }

  # The game: two hands, the worn bucket's contents, the floor, room bins.
  # Each TAP's reply comes from +taps+ in order (what bput would return: the
  # line after the drum); :flush clears the bucket. A GET by id or from the
  # bucket takes the item back. Everything sent is in +commands+.
  let(:game_class) do
    Class.new do
      attr_reader :commands, :bucket, :floor, :binned, :hands
      attr_accessor :taps, :get_reply

      def initialize(item)
        @hands = { 'right' => item, 'left' => nil }
        @bucket = []
        @floor = []
        @binned = []
        @commands = []
        @taps = []
        @get_reply = nil
      end

      def hand_obj(hand)
        obj = @hands[hand]
        obj ? OpenStruct.new(id: obj[:id], name: obj[:name], noun: obj[:noun]) : OpenStruct.new(id: nil, name: 'Empty', noun: nil)
      end

      def hand_name(hand)
        @hands[hand] && @hands[hand][:name]
      end

      def held(ref)
        %w[right left].find do |hand|
          obj = @hands[hand]
          obj && (ref == "##{obj[:id]}" || ref == "my #{obj[:noun]}")
        end
      end

      def handle(command)
        @commands << command
        case command
        when /^put (.+) in my bucket$/ then put_in(Regexp.last_match(1), @bucket, 'You drop the yarn into a portable silversteel bucket with a flared rim.')
        when /^put (.+) in (.+)$/ then put_in(Regexp.last_match(1), @binned, "You put your yarn in the #{Regexp.last_match(2)}.")
        when /^drop (.+)$/ then put_in(Regexp.last_match(1), @floor, 'You drop some wool yarn.')
        when /^tap my bucket$/ then tap
        when /^get #(\d+)$/ then take_back(:id, Regexp.last_match(1))
        when /^get my (\S+) from my bucket$/ then take_back(:noun, Regexp.last_match(1))
        else ''
        end
      end

      def put_in(ref, place, reply)
        hand = held(ref)
        return 'What were you referring to?' unless hand

        place << @hands[hand]
        @hands[hand] = nil
        reply
      end

      def tap
        reply = @taps.shift || ''
        if reply == :flush
          @bucket.clear
          return 'After a moment, a dull *THUD* echoes from within the bucket.'
        end
        reply
      end

      def take_back(key, value)
        return @get_reply if @get_reply

        item = @bucket.find { |obj| obj[key] == value }
        return 'What were you referring to?' unless item

        free = %w[right left].find { |hand| @hands[hand].nil? }
        return 'You need a free hand to pick that up.' unless free

        @bucket.delete(item)
        @hands[free] = item
        'You get some wool yarn from inside your silversteel bucket.'
      end
    end
  end

  let(:yarn) { { id: '25735696', name: 'some wool yarn', noun: 'yarn' } }
  let(:game) { game_class.new(yarn) }
  let(:room_objs) { [] }
  let(:worn) { [OpenStruct.new(id: '900', name: 'portable silversteel bucket with a flared rim', noun: 'bucket')] }

  before do
    Lich::Messaging.clear_messages!
    allow(DRC).to receive(:bput) { |command, *_patterns| game.handle(command) }
    allow(DRC).to receive(:left_hand) { game.hand_name('left') }
    allow(DRC).to receive(:right_hand) { game.hand_name('right') }
    allow(DRC).to receive(:get_noun) { |name| name.to_s.split.last }
    allow(GameObj).to receive(:left_hand) { game.hand_obj('left') }
    allow(GameObj).to receive(:right_hand) { game.hand_obj('right') }
    allow(GameObj).to receive(:inv) { worn }
    allow(Room).to receive(:current).and_return(OpenStruct.new(tags: []))
    allow(DRRoom).to receive(:room_objs) { room_objs }
    allow(XMLData).to receive(:room_title).and_return('[Crossing Forging Society, A Private Forge]')
  end

  def dispose(item = '#25735696')
    drci.dispose_trash(item, 'bucket', 'tap')
  end

  def messages
    Lich::Messaging.messages.map { |m| m[:message] }
  end

  def taps
    game.commands.grep(/^tap /).size
  end

  context 'when the bucket flushes on the second TAP' do
    before { game.taps = [primed, :flush] }

    it 'taps twice and reports the item disposed, with nothing taken back or said' do
      expect(dispose).to be true
      expect(game.commands).to eq(['put #25735696 in my bucket', 'tap my bucket', 'tap my bucket'])
      expect(game.bucket).to be_empty
      expect(messages).to be_empty
    end
  end

  context 'when the first TAP flushes (a TAP within 30 seconds of the last)' do
    before { game.taps = [:flush] }

    it 'stops after the TAP that flushed' do
      expect(dispose).to be true
      expect(taps).to eq(1)
    end
  end

  context 'when one pair does nothing and the next flushes' do
    before { game.taps = [no_effect, primed, :flush] }

    it 'tries another pair and does not take the item back' do
      expect(dispose).to be true
      expect(taps).to eq(3)
      expect(game.commands.grep(/^get /)).to be_empty
      expect(game.floor).to be_empty
    end
  end

  context 'when the bucket never flushes and there is no trash in the room' do
    before { game.taps = [no_effect, no_effect] }

    it 'takes the item back out by id and drops it here' do
      expect(dispose).to be true
      expect(game.commands).to eq(['put #25735696 in my bucket', 'tap my bucket', 'tap my bucket', 'get #25735696', 'drop #25735696'])
      expect(game.bucket).to be_empty
      expect(game.floor.map { |obj| obj[:id] }).to eq(['25735696'])
    end

    it 'says it took the item back and why, quoting the reply' do
      dispose
      expect(messages.first).to include('Your bucket did not flush', no_effect, 'thrown out onto the floor in about 5 minutes', 'Took it back out')
    end

    it 'says it is dropping the item on the floor here, where, and why, before the drop' do
      dispose
      drop_message = messages.find { |m| m.include?('Dropping') }
      expect(drop_message).to include('Dropping the wool yarn on the floor here (Crossing Forging Society, A Private Forge)', 'did not flush')
      expect(messages.index(drop_message)).to eq(messages.size - 1)
    end

    it 'never taps more than two pairs' do
      game.taps = Array.new(10, no_effect)
      dispose
      expect(taps).to eq(2)
    end
  end

  context 'when the TAPs go unanswered' do
    before { game.taps = ['', ''] }

    it 'treats that as not flushed and says there was no reply' do
      expect(dispose).to be true
      expect(game.floor.size).to eq(1)
      expect(messages.first).to include('did not flush (no reply)')
    end
  end

  context 'when only the second TAP of each pair is missing' do
    before { game.taps = [primed, '', primed, ''] }

    it 'still gives up after two pairs and takes the item back' do
      expect(dispose).to be true
      expect(taps).to eq(4)
      expect(game.commands).to include('get #25735696')
    end
  end

  context 'when the bucket fails and the room has a trash bin' do
    let(:room_objs) { ['waste bin'] }

    before { game.taps = [no_effect, no_effect] }

    it 'puts the item in the bin, without a drop or a drop message' do
      expect(dispose).to be true
      expect(game.commands.last).to eq('put #25735696 in waste bin')
      expect(game.binned.size).to eq(1)
      expect(game.floor).to be_empty
      expect(messages.join).not_to include('Dropping')
    end
  end

  context 'when the bucket fails and the room trash is also a bucket' do
    let(:room_objs) { ['large waste bucket'] }

    before { game.taps = [no_effect, no_effect] }

    it 'skips the room bucket, says why, and drops the item' do
      expect(dispose).to be true
      expect(game.commands).not_to include('put #25735696 in bucket')
      expect(game.floor.size).to eq(1)
      expect(messages.join("\n")).to include("Not using the room's bucket", 'could reach your bucket again')
    end
  end

  context 'when the room trash is a gloop bucket, put in as "bucket"' do
    let(:room_objs) { ['bucket of viscous gloop'] }

    before do
      game.taps = [no_effect, no_effect]
      allow(DRC).to receive(:get_noun).and_return('gloop')
    end

    it 'skips it as well' do
      expect(dispose).to be true
      expect(game.commands).not_to include('put #25735696 in bucket')
      expect(game.commands.last).to eq('drop #25735696')
    end
  end

  context 'when the worn trash can is not on the worn list' do
    let(:room_objs) { ['large waste bucket'] }
    let(:worn) { [] }

    before { game.taps = [no_effect, no_effect] }

    it 'has no noun to compare, so it uses the room bucket as before' do
      expect(dispose).to be true
      expect(game.commands.last).to eq('put #25735696 in bucket')
    end
  end

  context 'when a room tag names the trash can and it shares the bucket noun' do
    before do
      game.taps = [no_effect, no_effect]
      allow(Room).to receive(:current).and_return(OpenStruct.new(tags: ['meta:trashcan:waste bucket']))
    end

    it 'skips it too' do
      expect(dispose).to be true
      expect(game.commands).not_to include('put #25735696 in waste bucket')
      expect(game.commands.last).to eq('drop #25735696')
    end
  end

  context 'when the item is gone by the time it is taken back' do
    before do
      game.taps = [no_effect, no_effect]
      game.get_reply = 'What were you referring to?'
    end

    it 'treats it as disposed and drops nothing' do
      expect(dispose).to be true
      expect(game.commands.last).to eq('get #25735696')
      expect(messages.join).to include('no longer there; treating it as disposed')
    end
  end

  context 'when taking the item back gets no reply' do
    before do
      game.taps = [no_effect, no_effect]
      game.get_reply = ''
    end

    it 'says the item will be thrown out where the character is in about 5 minutes' do
      expect(dispose).to be true
      expect(game.commands.last).to eq('get #25735696')
      expect(messages.join).to include('could not be taken back out', 'no reply', 'about 5 minutes')
    end
  end

  context 'when the GET answers but the item is not in hand afterwards' do
    before do
      game.taps = [no_effect, no_effect]
      game.get_reply = 'You get some wool yarn from inside your silversteel bucket.'
    end

    it 'does not drop or bin by a reference that holds nothing' do
      expect(dispose).to be true
      expect(game.commands.grep(/^drop|in waste/)).to be_empty
      expect(messages.join).to include('could not be taken back out')
    end
  end

  context 'when the noun is held in both hands and the bucket fails' do
    before do
      game.hands['left'] = { id: '25735697', name: 'some wool yarn', noun: 'yarn' }
      game.taps = [no_effect, no_effect]
    end

    it 'takes back the one that went in, not the one still held' do
      expect(dispose('yarn')).to be true
      expect(game.commands).to include('get #25735696')
      expect(game.commands).not_to include('get #25735697')
      expect(game.hand_name('left')).to eq('some wool yarn')
    end
  end

  context 'when the item is named by noun and the hand shows no id' do
    let(:yarn) { { id: nil, name: 'some wool yarn', noun: 'yarn' } }

    before { game.taps = [no_effect, no_effect] }

    it 'takes it back by name from the bucket' do
      expect(dispose('yarn')).to be true
      expect(game.commands).to include('get my yarn from my bucket')
    end
  end

  context 'when the item is named by noun and the hand gives its id' do
    before { game.taps = [no_effect, no_effect] }

    it 'takes it back by that id, never by name' do
      expect(dispose('yarn')).to be true
      expect(game.commands).to include('get #25735696')
      expect(game.commands.grep(/from my bucket/)).to be_empty
      expect(game.commands.last).to eq('drop #25735696')
    end
  end

  context 'when the drop is answered with a warning and sent again' do
    before do
      game.taps = [no_effect, no_effect]
      warned = false
      allow(DRC).to receive(:bput) do |command, *_patterns|
        if command.start_with?('drop') && !warned
          warned = true
          game.commands << command
          'If you still wish to drop it, you will need to DROP it again.'
        else
          game.handle(command)
        end
      end
    end

    it 'drops it and says so only once' do
      expect(dispose).to be true
      expect(game.commands.grep(/^drop /).size).to eq(2)
      expect(messages.count { |m| m.include?('Dropping') }).to eq(1)
    end
  end

  context 'with a trash can whose verb reply has no confirming line' do
    before { game.taps = ['You pull a lever on the bin.'] }

    it 'uses the verb twice and counts it as emptied, as before' do
      expect(dispose).to be true
      expect(taps).to eq(2)
      expect(game.commands.grep(/^get /)).to be_empty
      expect(messages).to be_empty
    end
  end

  describe 'remembering what was thrown away' do
    it 'records the id of an item the bucket flushed' do
      game.taps = [primed, :flush]
      dispose('yarn')
      expect(drci.thrown_away?('25735696')).to be true
      expect(drci.thrown_away?('#25735696')).to be true
    end

    it 'records the id of an item taken back and dropped' do
      game.taps = [no_effect, no_effect]
      dispose
      expect(game.floor.size).to eq(1)
      expect(drci.thrown_away?('25735696')).to be true
    end

    it 'records the id of an item that could not be taken back out of the bucket' do
      game.taps = [no_effect, no_effect]
      game.get_reply = ''
      dispose
      expect(drci.thrown_away?('25735696')).to be true
    end

    it 'records nothing when the item could not be disposed of' do
      allow(DRC).to receive(:bput) do |command, *_patterns|
        game.commands << command
        'What were you referring to?'
      end
      expect(drci.dispose_trash('#25735696')).to be false
      expect(drci.thrown_away?('25735696')).to be false
    end

    it 'records only the item that left the hands when another with its noun stays held' do
      game.hands['left'] = { id: '25735697', name: 'some wool yarn', noun: 'yarn' }
      game.taps = [primed, :flush]
      dispose('yarn')
      expect(drci.thrown_away?('25735696')).to be true
      expect(drci.thrown_away?('25735697')).to be false
    end

    it 'keeps the newest THROWN_AWAY_IDS_MAX ids' do
      (1..(drci::THROWN_AWAY_IDS_MAX + 1)).each { |n| drci.note_thrown_away(n) }
      expect(drci.thrown_away?(1)).to be false
      expect(drci.thrown_away?(2)).to be true
      expect(drci.thrown_away?(drci::THROWN_AWAY_IDS_MAX + 1)).to be true
    end

    it 'starts each example empty (spec_helper clears it)' do
      expect(drci.instance_variable_get(:@thrown_away_ids)).to eq([])
    end

    it 'ignores an empty id' do
      drci.note_thrown_away('#')
      drci.note_thrown_away(nil)
      expect(drci.thrown_away?('')).to be false
      expect(drci.instance_variable_get(:@thrown_away_ids)).to be_empty
    end
  end

  context 'with no verb for the worn trash can' do
    it 'only puts the item in it' do
      expect(drci.dispose_trash('#25735696', 'bucket')).to be true
      expect(game.commands).to eq(['put #25735696 in my bucket'])
    end
  end
end

# The flush wait through the real DRC.bput: the drum line comes first, so the
# wait must read past it to the line that says whether the bucket flushed,
# and end there rather than after the 15 second timeout.
RSpec.describe 'DRCI worn trash can flush through the real DRC.bput' do
  let(:drc) { Lich::DragonRealms::DRC }
  let(:drci) { Lich::DragonRealms::DRCI }
  let(:buffer) { [] }
  let(:sent) { [] }
  let(:drum) { 'You drum your fingers on the bucket rhythmically.' }

  before do
    allow(drc).to receive(:waitrt?)
    allow(drc).to receive(:clear) { buffer.clear }
    allow(drc).to receive(:pause) { |_seconds| sleep(0.001) }
    allow(drc).to receive(:get?) { buffer.shift }
  end

  def game(*replies)
    allow(drc).to receive(:put) do |message|
      sent << message
      buffer.concat(Array(replies[sent.size - 1]))
    end
  end

  def flush
    Timeout.timeout(3) { drci.flush_worn_trashcan('bucket', 'tap') }
  end

  it 'reads past the drum line to the prompt and the THUD' do
    game([drum, '[OOC: TAP the bucket again within the next 30 seconds to flush it.].'], [drum, 'After a moment, a dull *THUD* echoes from within the bucket.'])
    expect(flush).to eq(:flushed)
    expect(sent).to eq(['tap my bucket', 'tap my bucket'])
  end

  it 'is not fooled by another player tapping their bucket' do
    game(['Rhodium taps a portable silversteel bucket with a flared rim that he is wearing.', drum, 'After a moment, a dull *THUD* echoes from within the bucket.'])
    expect(flush).to eq(:flushed)
    expect(sent.size).to eq(1)
  end

  it 'takes a THUD without asterisks as a flush too' do
    game([drum, 'After a moment, a dull THUD echoes from within the bucket.'])
    expect(flush).to eq(:flushed)
  end

  it 'does not take a THUD quoted in speech for a flush' do
    reply = 'You tap a portable silversteel bucket with a flared rim that you are wearing.'
    game(['Rhodium says, "After a moment, a dull *THUD* echoes from within the bucket."', reply], [reply])
    expect(flush).to eq(reply)
  end

  it 'ends at the no-effect reply and returns it' do
    reply = 'You tap a portable silversteel bucket with a flared rim that you are wearing.'
    game([reply], [reply])
    expect(flush).to eq(reply)
    expect(sent.size).to eq(2)
  end
end
