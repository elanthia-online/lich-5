# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/overwatch'

RSpec.describe Lich::Gemstone::Overwatch do
  let(:term) { described_class::Observer::Term }

  describe 'creature reveals with no 1st-person target (Term::REVEALED_*)' do
    # Raw XML captured live; player names and ids anonymized.
    {
      'another player discovers a hider' => [
        :REVEALED_PLAYER_DISCOVERS, '171513983', 'boarrat', 'beady-eyed scrub boarrat',
        '<a exist="-1234567" noun="Examplechar">Examplechar</a> discovers the hiding place of ' \
          '<pushBold/>a <a exist="171513983" noun="boarrat">beady-eyed scrub boarrat</a><popBold/>!'
      ],
      'forced out of hiding'             => [
        :REVEALED_FORCED_OUT, '10488885', 'assassin', 'triton assassin',
        '<pushBold/>A <a exist="10488885" noun="assassin">triton assassin</a><popBold/> is forced out of hiding.'
      ],
      'forced out of hiding (bang)'      => [
        # spec/fixtures/bloom_forced_out_of_hiding.txt:24
        :REVEALED_FORCED_OUT, '128104042', 'cannibal', 'bloody halfling cannibal',
        '<pushBold/>A <a exist="128104042" noun="cannibal">bloody halfling cannibal</a><popBold/> is forced out of hiding!'
      ],
      'falls out of hiding'              => [
        :REVEALED_FALLS_OUT, '148417050', 'warden', 'radiant triton warden',
        '<pushBold/>A <a exist="148417050" noun="warden">radiant triton warden</a><popBold/> falls out of hiding!'
      ],
      'knocked from hiding'              => [
        :REVEALED_KNOCKED, '24952721', 'stalker', 'sleek black kiramon stalker',
        '<pushBold/>A <a exist="24952721" noun="stalker">sleek black kiramon stalker</a><popBold/> is knocked from hiding.'
      ],
      'bandit jumps out of the shadows'  => [
        :REVEALED_JUMPS_OUT, '210393802', 'robber', 'gnomish robber',
        '<pushBold/>A <a exist="210393802" noun="robber">gnomish robber</a><popBold/> suddenly jumps out of the shadows!'
      ],
    }.each do |what, (const, id, noun, name, raw)|
      context what do
        let(:line) { raw }

        it 'captures the revealed creature id, noun and name' do
          match = line.match(term.const_get(const))
          expect(match).not_to be_nil
          expect(match[:id]).to eq(id)
          expect(match[:noun]).to eq(noun)
          expect(match[:name]).to eq(name)
        end

        it 'is part of ANY_REVEALED and ANY so the observer sees it' do
          expect(line).to match(term::ANY_REVEALED)
          expect(described_class::Observer.wants?(line)).to be_truthy
        end

        it 'pushes the creature into the target list via Observer.consume' do
          expect(described_class).to receive(:push_revealed_targets).with(id, noun, name)
          described_class::Observer.consume(line, described_class::Observer.wants?(line))
        end
      end
    end

    it 'ignores a player being forced out of hiding' do
      line = '<a exist="-1234567" noun="Examplechar">Examplechar</a> is forced out of hiding.'
      expect(line).not_to match(term::ANY)
    end
  end

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

  describe 'Term::REVEALED_EXPLODES (Ascension onslaught plunderer)' do
    # Raw XML captured live; player name anonymized.
    let(:first_person) do
      '<pushBold/>A <a exist="2168386" noun="plunderer">masked goliath plunderer</a><popBold/> explodes from the shadows!  ' \
        '<pushBold/><a exist="2168386" noun="plunderer">His</a><popBold/> shining eyes agleam with cunning, ' \
        '<pushBold/>a <a exist="2168386" noun="plunderer">masked goliath plunderer</a><popBold/> lashes out at you with ' \
        '<pushBold/><a exist="2168386" noun="plunderer">his</a><popBold/> <a exist="2168388" noun="sword-breaker">rainbow glaes sword-breaker</a>!'
    end

    let(:third_person) do
      '<pushBold/>A <a exist="57655053" noun="plunderer">masked goliath plunderer</a><popBold/> explodes from the shadows!  ' \
        '<pushBold/><a exist="57655053" noun="plunderer">His</a><popBold/> shining eyes agleam with cunning, ' \
        '<pushBold/>a <a exist="57655053" noun="plunderer">masked goliath plunderer</a><popBold/> lashes out at ' \
        '<a exist="-1234567" noun="Examplechar">Examplechar</a> with ' \
        '<pushBold/><a exist="57655053" noun="plunderer">his</a><popBold/> <a exist="57655057" noun="poignard">rainbow glaes poignard</a>!'
    end

    {
      'the 1st-person view (attacking you)'            => [:first_person, '2168386'],
      'the 3rd-person view (attacking another player)' => [:third_person, '57655053'],
    }.each do |desc, (line_name, id)|
      context desc do
        let(:line) { send(line_name) }

        it 'captures the revealed creature id, noun and name' do
          match = line.match(term::REVEALED_EXPLODES)
          expect(match).not_to be_nil
          expect(match[:id]).to eq(id)
          expect(match[:noun]).to eq('plunderer')
          expect(match[:name]).to eq('masked goliath plunderer')
        end

        it 'is part of ANY_REVEALED and ANY so the observer sees it' do
          expect(line).to match(term::ANY_REVEALED)
          expect(described_class::Observer.wants?(line)).to be_truthy
        end

        it 'pushes the creature into the target list via Observer.consume' do
          expect(described_class).to receive(:push_revealed_targets)
            .with(id, 'plunderer', 'masked goliath plunderer')
          described_class::Observer.consume(line, described_class::Observer.wants?(line))
        end
      end
    end
  end

  describe 'Term::SILENT_CANNIBAL_SWING / SILENT_CANNIBAL_GRAPPLE (bloody halfling cannibal)' do
    # Raw XML captured live (two characters in the same fight); player names anonymized.
    {
      'swing, 1st-person view (attacking you)'              => [
        :SILENT_CANNIBAL_SWING, '1312018',
        'With an ululating shriek, <pushBold/>a <a exist="1312018" noun="cannibal">bloody halfling cannibal</a><popBold/> ' \
          'leaps from the shadows and hurtles at you, swinging wildly with a ' \
          '<a exist="1312019" noun="dagger">twisted obsidian dagger</a>!'
      ],
      'swing, 3rd-person view (attacking another player)'   => [
        :SILENT_CANNIBAL_SWING, '1312018',
        'With an ululating shriek, <pushBold/>a <a exist="1312018" noun="cannibal">bloody halfling cannibal</a><popBold/> ' \
          'leaps from the shadows and hurtles at <a exist="-1234567" noun="Examplechar">Examplechar</a>, swinging wildly with a ' \
          '<a exist="1312019" noun="dagger">twisted obsidian dagger</a>!'
      ],
      'grapple, 1st-person view (attacking you)'            => [
        :SILENT_CANNIBAL_GRAPPLE, '1312024',
        'With an ululating shriek, <pushBold/>a <a exist="1312024" noun="cannibal">bloody halfling cannibal</a><popBold/> ' \
          'leaps from the shadows and throws <pushBold/><a exist="1312024" noun="cannibal">his</a><popBold/> ' \
          'wiry arms around you, fueled by panicked hunger!'
      ],
      'grapple, 3rd-person view (attacking another player)' => [
        :SILENT_CANNIBAL_GRAPPLE, '1312024',
        'With an ululating shriek, <pushBold/>a <a exist="1312024" noun="cannibal">bloody halfling cannibal</a><popBold/> ' \
          'leaps from the shadows and throws <pushBold/><a exist="1312024" noun="cannibal">his</a><popBold/> ' \
          'wiry arms around <a exist="-7654321" noun="Otherchar">Otherchar</a>, fueled by panicked hunger!'
      ],
    }.each do |desc, (const, id, raw)|
      context desc do
        let(:line) { raw }

        it 'captures the creature id, noun and name' do
          match = line.match(term.const_get(const))
          expect(match).not_to be_nil
          expect(match[:id]).to eq(id)
          expect(match[:noun]).to eq('cannibal')
          expect(match[:name]).to eq('bloody halfling cannibal')
        end

        it 'is part of ANY_SILENT_STRIKE and ANY so the observer sees it' do
          expect(line).to match(term::ANY_SILENT_STRIKE)
          expect(described_class::Observer.wants?(line)).to be_truthy
        end

        it 'pushes the creature as a silent strike via Observer.consume' do
          expect(described_class).to receive(:push_revealed_targets)
            .with(id, 'cannibal', 'bloody halfling cannibal', silent_strike: true)
          described_class::Observer.consume(line, described_class::Observer.wants?(line))
        end
      end
    end
  end
end
