# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/readylist'

RSpec.describe Lich::Gemstone::ReadyList do
  let(:item) { Struct.new(:id) }

  before do
    described_class.reset(all: true)
    described_class.checked = true
    described_class.weapon = item.new('123456')
    # Empty hands carry a nil id.
    allow(Lich::Common::GameObj).to receive_messages(inv: [], containers: {}, left_hand: item.new(nil))
  end

  after { described_class.reset(all: true) }

  describe '.valid?' do
    it 'rejects a ready item whose id is only a substring of a held item id' do
      allow(Lich::Common::GameObj).to receive(:right_hand).and_return(item.new('9123456'))
      expect(described_class.valid?).to be(false)
      expect(described_class.checked?).to be(false)
    end

    it 'accepts a ready item held in the left hand by exact id' do
      allow(Lich::Common::GameObj).to receive(:right_hand).and_return(item.new(nil))
      allow(Lich::Common::GameObj).to receive(:left_hand).and_return(item.new('123456'))
      expect(described_class.valid?).to be(true)
    end

    it 'accepts a ready item held in the right hand by exact id' do
      allow(Lich::Common::GameObj).to receive(:right_hand).and_return(item.new('123456'))
      expect(described_class.valid?).to be(true)
    end
  end
end
