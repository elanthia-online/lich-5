# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/util/deep_freeze'

RSpec.describe Lich::Util do
  describe '.deep_freeze' do
    it 'freezes a self-referential array without recursing indefinitely' do
      value = []
      value << value

      expect(described_class.deep_freeze(value)).to equal(value)
      expect(value).to be_frozen
      expect(value.first).to equal(value)
    end

    it 'freezes every value in mutually recursive containers' do
      mapping = {}
      sequence = [mapping, 'nested']
      mapping[:sequence] = sequence

      described_class.deep_freeze(mapping)

      expect(mapping).to be_frozen
      expect(sequence).to be_frozen
      expect(sequence.last).to be_frozen
      expect(mapping[:sequence]).to equal(sequence)
      expect(sequence.first).to equal(mapping)
    end
  end
end
