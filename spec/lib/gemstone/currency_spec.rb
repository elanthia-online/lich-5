# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/currency'

RSpec.describe Lich::Gemstone::Currency do
  before do
    stub_const('Lich::Gemstone::Infomon', Module.new do
      def self.get(_key) = @silver

      def self.silver=(v)
        @silver = v
      end
    end)
    stub_const('Lich::Gemstone::Infomon::Parser::Pattern::WealthSilver', /^You have (?<silver>no|[,\d]+|but one) silver with you\./)
    Lich::Gemstone::Infomon.silver = 1500
    allow(Lich::Util).to receive(:issue_command).and_return([])
  end

  it 'reads Infomon without sending anything by default' do
    expect(Lich::Util).not_to receive(:issue_command)
    expect(described_class.silver).to eq(1500)
  end

  it 'sends WEALTH quietly when asked to refresh' do
    expect(Lich::Util).to receive(:issue_command).with('wealth', Lich::Gemstone::Infomon::Parser::Pattern::WealthSilver, silent: true, quiet: true) do
      Lich::Gemstone::Infomon.silver = 2000
      ['You have 2,000 silver with you.']
    end
    expect(described_class.silver(refresh: true)).to eq(2000)
  end

  it 'sends WEALTH ALL for the alternative currencies' do
    expect(Lich::Util).to receive(:issue_command).with('wealth all', anything, silent: true, quiet: true)
    described_class.refresh(all: true)
  end

  it 'reads the total and note figures, refreshing on request' do
    stub_const('Lich::Gemstone::Infomon', Module.new do
      def self.get(key) = { 'currency.silver_total' => 15_571, 'currency.notes' => 100_000 }[key]
    end)
    expect(described_class.silver_total).to eq(15_571)
    expect(described_class.notes).to eq(100_000)
    expect(Lich::Util).to receive(:issue_command).with('wealth notes', anything, anything, silent: true, quiet: true)
    expect(described_class.notes(refresh: true)).to eq(100_000)
  end

  it 'refresh returns the re-read value' do
    expect(Lich::Util).to receive(:issue_command) { Lich::Gemstone::Infomon.silver = 7 }
    expect(described_class.refresh).to eq(7)
  end
end
