# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/overwatch'

RSpec.describe Lich::Gemstone::Overwatch do
  let(:term) { described_class::Observer::Term }

  describe 'Term::REVEALED_VOLN_SLEEP (Order of Voln Symbol of Sleep)' do
    # Raw XML captured from a live `sym of sleep` cast (logxml.lic).
    let(:line) do
      '<pushBold/>A <a exist="356982" noun="cannibal">bloody halfling cannibal</a><popBold/> is revealed by the pattern!'
    end

    it 'captures the revealed creature id, noun and name' do
      match = line.match(term::REVEALED_VOLN_SLEEP)
      expect(match).not_to be_nil
      expect(match[:id]).to eq('356982')
      expect(match[:noun]).to eq('cannibal')
      expect(match[:name]).to eq('bloody halfling cannibal')
    end

    it 'is part of ANY_REVEALED and ANY so the observer sees it' do
      expect(line).to match(term::ANY_REVEALED)
      expect(described_class::Observer.wants?(line)).to be_truthy
    end

    it 'does not match the cast line or the follow-up sleep line' do
      [
        'You draw a glowing pattern in the air before you.',
        %(<pushBold/>A <a exist="356982" noun="cannibal">bloody halfling cannibal's</a><popBold/> eyes glass over as a distant look takes over <pushBold/><a exist="356982" noun="cannibal">his</a><popBold/> expression.)
      ].each { |other| expect(other).not_to match(term::ANY) }
    end

    it 'pushes the creature into the target list via Observer.consume' do
      expect(described_class).to receive(:push_revealed_targets)
        .with('356982', 'cannibal', 'bloody halfling cannibal')
      described_class::Observer.consume(line, described_class::Observer.wants?(line))
    end
  end
end
