# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'timeout'
require_relative '../../../../lib/dragonrealms/commons/common'
require_relative '../../../../lib/dragonrealms/commons/common-items'

# DRCI.remove_item? through the real DRC.bput, against a small model of the
# game stream: each send queues that send's replies and get? reads them back
# in order. common_items_spec.rb stubs DRC.bput; this file pins what only the
# real bput decides: which line ends the wait and which list it matched, so a
# reply no pattern knows shows up as a hang (bounded here well below
# BPUT_DEFAULT_TIMEOUT) instead of a quiet false.
#
# Replies are verbatim from game logs.
RSpec.describe 'DRCI.remove_item? through the real DRC.bput' do
  let(:drc) { Lich::DragonRealms::DRC }
  let(:drci) { Lich::DragonRealms::DRCI }
  let(:buffer) { [] }
  let(:sent) { [] }
  let(:sling_yank) do
    'You yank your sling off your belt and place the finger loop of the retention cord over one of your fingers.  ' \
      'You let the release cord rest lightly in the palm of your hand and the pouch dangle loose, ready for loading.'
  end

  before do
    allow(drc).to receive(:waitrt?)
    allow(drc).to receive(:clear) { buffer.clear }
    allow(drc).to receive(:pause) { |_seconds| sleep(0.001) }
    allow(drc).to receive(:get?) { buffer.shift }
    allow(drc).to receive(:put) do |message|
      sent << message
      buffer.concat(replies)
    end
  end

  def remove(item)
    Timeout.timeout(3) { drci.remove_item?(item) }
  end

  context 'when the game yanks a sling off the belt' do
    let(:replies) { [sling_yank] }

    it 'returns true at once' do
      expect(remove('spidersilk.sling')).to be(true)
      expect(sent).to eq(['remove my spidersilk.sling'])
    end
  end

  context 'when the item is not worn' do
    let(:replies) { ["You aren't wearing that."] }

    it 'returns false' do
      expect(remove('spidersilk.sling')).to be(false)
    end
  end
end
