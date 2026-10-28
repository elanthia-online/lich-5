# frozen_string_literal: true

require_relative '../../spec_helper'
require 'webui/protocol'

RSpec.describe Lich::WebUI::Protocol, '.secure_compare' do
  [nil, ''].product([nil, '', 'token']).each do |expected, actual|
    it "rejects missing or empty expected credentials against #{actual.inspect} (expected #{expected.inspect})" do
      expect(described_class.secure_compare(expected, actual)).to be(false)
    end
  end

  it 'accepts an equal nonempty token and rejects missing, short and equal-length mismatched tokens' do
    expect(described_class.secure_compare('token', 'token')).to be(true)
    [nil, '', 'toke', 'Token', 'tokeo'].each do |actual|
      expect(described_class.secure_compare('token', actual)).to be(false)
    end
  end

  it 'compares every byte of equal-length nonempty tokens' do
    expected = 'token'.dup
    expect(expected).to receive(:bytes).and_call_original
    expect(described_class.secure_compare(expected, 'Token')).to be(false)
  end
end
