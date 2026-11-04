# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/overwatch'

RSpec.describe Lich::Gemstone::Overwatch do
  let(:term) { described_class::Observer::Term }

  describe 'Term::REVEALED_VOLN_SLEEP (Order of Voln Symbol of Sleep)' do
    let(:line) do
      '<pushBold/>A <a exist="12345678" noun="plunderer">masked goliath plunderer</a><popBold/> is revealed by the pattern!'
    end

    it 'captures the revealed creature id, noun and name' do
      match = line.match(term::REVEALED_VOLN_SLEEP)
      expect(match).not_to be_nil
      expect(match[:id]).to eq('12345678')
      expect(match[:noun]).to eq('plunderer')
      expect(match[:name]).to eq('masked goliath plunderer')
    end

    it 'is part of ANY_REVEALED and ANY so the observer sees it' do
      expect(line).to match(term::ANY_REVEALED)
      expect(described_class::Observer.wants?(line)).to be_truthy
    end

    it 'does not match the follow-up sleep line' do
      sleep_line = %(<pushBold/>A <a exist="12345678" noun="plunderer">masked goliath plunderer</a><popBold/>'s eyes roll up into his head as he slumps to the ground.)
      expect(sleep_line).not_to match(term::ANY)
    end

    it 'pushes the creature into the target list via Observer.consume' do
      expect(described_class).to receive(:push_revealed_targets)
        .with('12345678', 'plunderer', 'masked goliath plunderer')
      described_class::Observer.consume(line, described_class::Observer.wants?(line))
    end
  end
end
