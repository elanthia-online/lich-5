# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'timeout'
require 'ox'
require 'common/gameobj'
require 'dragonrealms/commons/common'
require 'dragonrealms/commons/common-items'
require 'dragonrealms/commons/common-travel'

# DRCT.order_item_result through the real DRC.bput and the real DRCI hand
# readers, against a small model of the game stream: each send queues that
# send's lines and get? reads them back in order. The hands are the real
# GameObj hands, set as the XML parser sets them; an empty hand is the
# parser's placeholder (id nil, noun nil, name 'Empty').
#
# Verbatim from Barrask's 2026-11-04 logs (tm-leftover sweep): the right hand
# rat-pelt leather 2222485 and left hand burlap cloth 2227674 held when every
# later "order 8" got "You realize your hands are full, and stop.", and the
# burlap cloth 2161092 whose hand tag came before "takes some coins". For the
# merchant's quote and the sale only the fragments order_item matches are
# used, as in common_travel_order_item_real_bput_spec.rb, because the wording
# around them varies by shop; 'The clerk looks up.' is an unrelated line.
RSpec.describe 'DRCT.order_item_result' do
  let(:drc) { Lich::DragonRealms::DRC }
  let(:drci) { Lich::DragonRealms::DRCI }
  let(:drct) { Lich::DragonRealms::DRCT }
  let(:gameobj) { Lich::Common::GameObj }
  let(:buffer) { [] }
  let(:sent) { [] }

  let(:leather) { ['2222485', 'leather', 'rat-pelt leather'] }
  let(:cloth) { ['2227674', 'cloth', 'burlap cloth'] }
  let(:bought_cloth) { ['2161092', 'cloth', 'burlap cloth'] }
  let(:bought_leather) { ['63721991', 'leather', 'rat-pelt leather'] }

  let(:quote) { 'Just order it again' }
  let(:sold) { 'takes some coins from you' }
  let(:hands_full) { 'You realize your hands are full, and stop.' }
  let(:no_coins) { "you don't have enough coins" }

  let(:results) { %i[bought hands_full unreachable no_coins timeout] }

  def hands(right: nil, left: nil)
    gameobj.new_right_hand(*(right || [nil, nil, 'Empty']))
    gameobj.new_left_hand(*(left || [nil, nil, 'Empty']))
  end

  # The game: the lines each successive send answers with (a String, an
  # Array of lines, or nil for silence). on_send runs before the lines are
  # queued, with the send's 1-based index, as DR sends the hand tag before
  # the reply text.
  def game(*replies, &on_send)
    allow(drc).to receive(:put) do |message|
      sent << message
      on_send&.call(sent.size)
      buffer.concat(Array(replies[sent.size - 1]))
    end
  end

  # Bounded well below BPUT_DEFAULT_TIMEOUT (15 s), so an example where bput
  # waits out its timeout fails instead of passing slowly.
  def result(room = 8860, number = 8)
    Timeout.timeout(3) { drct.order_item_result(room, number) }
  end

  def messages
    Lich::Messaging.messages.map { |m| m[:message] }
  end

  before do
    allow(drct).to receive(:walk_to).and_return(true)
    allow(drc).to receive(:waitrt?)
    allow(drc).to receive(:clear) { buffer.clear }
    allow(drc).to receive(:pause) { |_seconds| sleep(0.001) }
    allow(drc).to receive(:get?) { buffer.shift }
    allow(drc).to receive(:put).and_raise('sent a command the example did not expect')
    Lich::Messaging.clear_messages!
    gameobj.clear_inv
    hands
  end

  describe 'before walking' do
    it 'returns :hands_full without walking or ordering when both hands hold something' do
      hands(right: leather, left: cloth)
      expect(result).to eq(:hands_full)
      expect(drct).not_to have_received(:walk_to)
      expect(drc).not_to have_received(:put)
      expect(messages).to include('DRCT: Both hands are full, so not ordering 8.')
    end

    it 'counts Integer ids in both hands as full' do
      hands(right: [2_222_485, 'leather', 'rat-pelt leather'], left: [2_227_674, 'cloth', 'burlap cloth'])
      expect(result).to eq(:hands_full)
      expect(drct).not_to have_received(:walk_to)
    end

    it "orders with one hand free (left 'Empty')" do
      hands(right: leather)
      game([quote], [sold])
      expect(result).to eq(:bought)
      expect(sent).to eq(['order 8', 'order 8'])
    end

    it "orders with one hand free (right 'Empty')" do
      hands(left: cloth)
      game([quote], [sold])
      expect(result).to eq(:bought)
    end

    it 'orders with both hands empty' do
      game([quote], [sold])
      expect(result).to eq(:bought)
      expect(messages).not_to include(a_string_matching(/Both hands are full/))
    end

    it 'orders before any hand tag has been seen (GameObj hands nil)' do
      gameobj.class_variable_set(:@@right_hand, nil)
      gameobj.class_variable_set(:@@left_hand, nil)
      game([quote], [sold])
      expect(result).to eq(:bought)
    end

    it 'returns :unreachable without ordering when the walk fails' do
      allow(drct).to receive(:walk_to).and_return(false)
      expect(result).to eq(:unreachable)
      expect(drc).not_to have_received(:put)
      expect(messages).to include('DRCT: Could not reach room 8860, so not ordering 8.')
    end

    it 'checks the hands before the walk, so a failed walk with full hands is :hands_full' do
      hands(right: leather, left: cloth)
      allow(drct).to receive(:walk_to).and_return(false)
      expect(result).to eq(:hands_full)
    end
  end

  describe 'the replies' do
    it 'returns :bought when the paying order goes through' do
      game([quote], [sold])
      expect(result).to eq(:bought)
      expect(sent).to eq(['order 8', 'order 8'])
    end

    it 'returns :bought for the success text in another case' do
      game(['JUST ORDER IT AGAIN'], ['Takes some coins from you'])
      expect(result).to eq(:bought)
    end

    it 'returns :hands_full at once when the paying order finds the hands full' do
      game([quote], ['The clerk looks up.', hands_full])
      expect(result).to eq(:hands_full)
      expect(sent).to eq(['order 8', 'order 8'])
    end

    it 'returns :hands_full without paying when the first order finds the hands full' do
      game([hands_full])
      expect(result).to eq(:hands_full)
      expect(sent).to eq(['order 8'])
    end

    it 'is not stopped by the refusal quoted in speech' do
      game([quote], ["Mahtra says, \"#{hands_full}\"", sold])
      expect(result).to eq(:bought)
    end

    it 'returns :no_coins without paying when the coins are short' do
      game([no_coins])
      expect(result).to eq(:no_coins)
      expect(sent).to eq(['order 8'])
    end

    it 'returns :no_coins without paying when the coins reply is capitalized' do
      game(["You don't have enough coins"])
      expect(result).to eq(:no_coins)
      expect(sent).to eq(['order 8'])
    end

    # The paying ORDER waits only for the sale or the anchored hands-full
    # refusal, as order_item does: the coins text is unanchored, so on the
    # paying ORDER speech quoting it could hide a sale that went through.
    it 'is not stopped by the coins reply quoted in speech on the paying order' do
      game([quote], ['Bob says, "you don\'t have enough coins"', "The clerk #{sold}."])
      expect(result).to eq(:bought)
      expect(sent).to eq(['order 8', 'order 8'])
    end

    it 'sends the menu number as given, Integer or String' do
      game([quote], [sold], [quote], [sold])
      expect(result(8860, 8)).to eq(:bought)
      expect(result(8860, '8')).to eq(:bought)
      expect(sent).to eq(['order 8'] * 4)
    end

    context 'when bput times out' do
      before { stub_const('Lich::DragonRealms::DRC::BPUT_DEFAULT_TIMEOUT', 0.05) }

      it 'returns :timeout without paying when the first order gets no reply' do
        game(nil)
        expect(result).to eq(:timeout)
        expect(sent).to eq(['order 8'])
      end

      it 'returns :timeout without paying when the first order gets only other lines' do
        game(['The clerk looks up.'])
        expect(result).to eq(:timeout)
        expect(sent).to eq(['order 8'])
      end

      it 'returns :timeout, not :bought, when the paying order gets no reply' do
        game([quote], nil)
        expect(result).to eq(:timeout)
        expect(sent).to eq(['order 8', 'order 8'])
      end

      it 'returns :timeout, like order_item, when the paying order finds the coins short' do
        game([quote], ["You don't have enough coins"])
        expect(result).to eq(:timeout)
        expect(sent).to eq(['order 8', 'order 8'])
      end
    end

    it 'returns only the documented Symbols' do
      replies = [[[quote], [sold]], [[quote], [hands_full]], [[hands_full]], [[no_coins]]]
      replies.each do |script|
        buffer.clear
        sent.clear
        game(*script)
        expect(results).to include(result), script.inspect
      end
    end
  end

  # :bought is exactly when order_item returns its success text, for the
  # same replies with a free hand. The documented exception: after a
  # first-ORDER timeout order_item still sends the paying ORDER (and can buy);
  # order_item_result does not.
  describe 'against DRCT.order_item' do
    before { stub_const('Lich::DragonRealms::DRC::BPUT_DEFAULT_TIMEOUT', 0.05) }

    def run(method, script)
      buffer.clear
      sent.clear
      game(*script)
      Timeout.timeout(3) { drct.public_send(method, 8860, 8) }
    end

    table = {
      'quote then sale'                 => [['Just order it again'], ['takes some coins from you']],
      'capitalized sale'                => [['Just order it again'], ['Takes some coins from you']],
      'hands full on the paying order'  => [['Just order it again'], ['You realize your hands are full, and stop.']],
      'hands full on the first order'   => [['You realize your hands are full, and stop.']],
      'coins short'                     => [["you don't have enough coins"]],
      'coins short, capitalized'        => [["You don't have enough coins"]],
      'coins short on the paying order' => [['Just order it again'], ["You don't have enough coins"]],
      'paying order silent'             => [['Just order it again'], nil],
      'speech, then sale'               => [['Just order it again'], ['Mahtra says, "You realize your hands are full, and stop."', 'takes some coins from you']],
      'coins speech, then sale'         => [['Just order it again'], ['Bob says, "you don\'t have enough coins"', 'The clerk takes some coins from you.']]
    }

    table.each do |label, script|
      it "agrees on success for: #{label}" do
        legacy = run(:order_item, script)
        current = run(:order_item_result, script)
        expect(current == :bought).to eq(legacy.to_s.match?(/\Atakes some coins from you\z/i)), "order_item=#{legacy.inspect} order_item_result=#{current.inspect}"
      end
    end

    it 'differs only after a first-order timeout: order_item pays anyway, order_item_result does not' do
      script = [nil, ['takes some coins from you']]
      expect(run(:order_item, script)).to eq('takes some coins from you')
      expect(sent).to eq(['order 8', 'order 8'])
      expect(run(:order_item_result, script)).to eq(:timeout)
      expect(sent).to eq(['order 8'])
    end
  end

  # The composition DESIGN.md gives for the bought item's id.
  describe 'inside DRCI.id_into_hand' do
    before { allow(drci).to receive(:sleep) }

    def buy_id(name: 'cloth')
      Timeout.timeout(3) do
        drci.id_into_hand(name: name) { drct.order_item_result(8860, 8) == :bought }
      end
    end

    it 'gives the id of the item the paying order put in hand' do
      hands(right: leather)
      game([quote], [sold]) { |n| hands(right: leather, left: bought_cloth) if n == 2 }
      expect(buy_id).to eq('2161092')
    end

    it 'gives the new leather, not the leather already held' do
      hands(right: leather)
      game([quote], [sold]) { |n| hands(right: leather, left: bought_leather) if n == 2 }
      expect(buy_id(name: 'leather')).to eq('63721991')
    end

    it 'gives the id when speech quoting the coins reply comes before the sale' do
      hands(right: leather)
      game([quote], ['Bob says, "you don\'t have enough coins"', "The clerk #{sold}."]) do |n|
        hands(right: leather, left: bought_cloth) if n == 2
      end
      expect(buy_id).to eq('2161092')
    end

    it 'gives nil without walking or ordering when both hands are full' do
      hands(right: leather, left: cloth)
      expect(buy_id).to be_nil
      expect(drc).not_to have_received(:put)
      expect(drci).not_to have_received(:sleep)
    end

    it 'gives nil without polling when the paying order finds the hands full' do
      hands(right: leather)
      game([quote], [hands_full])
      expect(buy_id).to be_nil
      expect(drci).not_to have_received(:sleep)
    end

    it 'gives nil without polling when the coins are short' do
      hands(right: leather)
      game([no_coins])
      expect(buy_id).to be_nil
      expect(drci).not_to have_received(:sleep)
    end

    it 'gives nil when the sale went through but nothing matching arrived' do
      hands(right: leather)
      game([quote], [sold])
      expect(buy_id).to be_nil
      expect(drci).to have_received(:sleep).at_least(:once)
    end
  end
end
