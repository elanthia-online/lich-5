# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'timeout'
require_relative '../../../../lib/dragonrealms/commons/common'
require_relative '../../../../lib/dragonrealms/commons/common-travel'

# DRCT.order_item through the real DRC.bput, against a small model of the
# game stream: each send queues that send's replies and get? reads them back
# in order. common_travel_spec.rb stubs DRC.bput; this file pins what only the
# real bput decides: that the hands-full refusal ends the wait at once rather
# than after BPUT_DEFAULT_TIMEOUT (15 seconds), so each example is bounded
# well below that.
#
# The refusal is verbatim from a game log. For the merchant's quote and the
# sale only the fragments order_item matches are used, because the wording
# around them varies by shop; 'The clerk looks up.' is an unrelated line.
RSpec.describe 'DRCT.order_item through the real DRC.bput' do
  let(:drc) { Lich::DragonRealms::DRC }
  let(:drct) { Lich::DragonRealms::DRCT }
  let(:buffer) { [] }
  let(:sent) { [] }
  let(:hands_full) { 'You realize your hands are full, and stop.' }

  before do
    allow(drct).to receive(:walk_to).and_return(true)
    allow(drc).to receive(:waitrt?)
    allow(drc).to receive(:clear) { buffer.clear }
    allow(drc).to receive(:pause) { |_seconds| sleep(0.001) }
    allow(drc).to receive(:get?) { buffer.shift }
  end

  # Replies to each successive send, in order.
  def game(*replies)
    allow(drc).to receive(:put) do |message|
      sent << message
      buffer.concat(Array(replies[sent.size - 1]))
    end
  end

  def order(number)
    Timeout.timeout(3) { drct.order_item(8860, number) }
  end

  it 'returns nil without waiting out the timeout when the confirming order finds the hands full' do
    game(['Just order it again'], ['The clerk looks up.', hands_full])
    expect(order(8)).to be_nil
    expect(sent).to eq(['order 8', 'order 8'])
  end

  it 'returns nil without confirming when the first order finds the hands full' do
    game([hands_full])
    expect(order(8)).to be_nil
    expect(sent).to eq(['order 8'])
  end

  it 'returns the success match when the order goes through' do
    game(['Just order it again'], ['takes some coins from you'])
    expect(order(8)).to eq('takes some coins from you')
    expect(sent).to eq(['order 8', 'order 8'])
  end

  it 'is not stopped by the refusal quoted in speech' do
    game(['Just order it again'], ["Mahtra says, \"#{hands_full}\"", 'takes some coins from you'])
    expect(order(8)).to eq('takes some coins from you')
  end

  it 'still returns nil when the coins are short' do
    game(["you don't have enough coins"])
    expect(order(8)).to be_nil
    expect(sent).to eq(['order 8'])
  end

  # bput matches its String patterns case-insensitively, so a capitalized
  # reply still ends the first wait; order_item must not then confirm.
  it 'returns nil without confirming when the coins reply is capitalized' do
    game(["You don't have enough coins"])
    expect(order(8)).to be_nil
    expect(sent).to eq(['order 8'])
  end
end
