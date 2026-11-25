# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/overwatch'
require_relative '../../../lib/common/gameobj'

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

  describe 'Term::SILENT_STALKER_SAVAGE (kiramon stalker)' do
    # Raw XML captured live; player name and id anonymized. The stalker is linked only as "it", so the
    # observer reports it as an unknown assailant.
    {
      '1st-person view (attacking you)'            => [
        '26577119',
        'Catching you unaware, <pushBold/><a exist="26577119" noun="stalker">it</a><popBold/> ' \
          'carves into you with cruel and ruthless savagery!'
      ],
      '3rd-person view (attacking another player)' => [
        '24776474',
        'Catching <a exist="-1234567" noun="Examplechar">him</a> unaware, <pushBold/><a exist="24776474" noun="stalker">it</a><popBold/> ' \
          'carves into <a exist="-1234567" noun="Examplechar">Examplechar</a> with cruel and ruthless savagery!'
      ],
    }.each do |view, (id, raw)|
      context view do
        let(:line) { raw }

        it 'captures the creature id and noun' do
          match = line.match(term::SILENT_STALKER_SAVAGE)
          expect(match).not_to be_nil
          expect(match[:id]).to eq(id)
          expect(match[:noun]).to eq('stalker')
        end

        it 'is part of ANY_SILENT_STRIKE and ANY so the observer sees it' do
          expect(line).to match(term::ANY_SILENT_STRIKE)
          expect(described_class::Observer.wants?(line)).to be_truthy
        end

        it 'pushes the creature as a silent strike via Observer.consume' do
          expect(described_class).to receive(:push_revealed_targets)
            .with(id, 'stalker', 'unknown assailant', silent_strike: true)
          described_class::Observer.consume(line, described_class::Observer.wants?(line))
        end
      end
    end
  end

  describe 'kiramon stalker ambushes and Thorn Barrier blocks (Term::REVEALED_*)' do
    # Raw XML captured live; player names and ids anonymized.
    stalker = '<pushBold/>a <a exist="%<id>s" noun="stalker">sleek black kiramon stalker</a><popBold/>'
    you     = 'you'
    player  = '<a exist="-1234567" noun="Examplechar">Examplechar</a>'
    {
      'stalker bite'    => [:REVEALED_STALKER_BITE, '24776471', 'sleek black kiramon stalker',
                            "Without warning, #{stalker} glides from the shadows and aims a preternaturally swift bite at %<target>s!"],
      'stalker slash'   => [:REVEALED_STALKER_SLASH, '24997331', 'sleek black kiramon stalker',
                            "Without warning, #{stalker} glides from the shadows and skitters mercilessly forward " \
                            'to slash at %<target>s with a razor-sharp foreleg!'],
      'stalker stinger' => [:REVEALED_STALKER_STINGER, '26283744', 'sleek black kiramon stalker',
                            "Without warning, #{stalker} glides from the shadows and twists fluidly to spear %<target>s with " \
                            '<pushBold/><a exist="%<id>s" noun="stalker">its</a><popBold/> barbed stinger!'],
      'Thorn Barrier'   => [:REVEALED_WALL_THORNS, '26290917', 'kiramon stalker',
                            'The thorny barrier surrounding %<target>s blocks the attack from the ' \
                            '<pushBold/><a exist="%<id>s" noun="stalker">kiramon stalker</a><popBold/>!'],
    }.each do |what, (const, id, name, template)|
      {
        '1st-person view (attacking you)'            => you,
        '3rd-person view (attacking another player)' => player,
      }.each do |view, target|
        context "#{what}, #{view}" do
          let(:line) { format(template, id: id, target: target) }

          it 'captures the revealed creature id, noun and name' do
            match = line.match(term.const_get(const))
            expect(match).not_to be_nil
            expect(match[:id]).to eq(id)
            expect(match[:noun]).to eq('stalker')
            expect(match[:name]).to eq(name)
          end

          it 'is part of ANY_REVEALED and ANY so the observer sees it' do
            expect(line).to match(term::ANY_REVEALED)
            expect(described_class::Observer.wants?(line)).to be_truthy
          end

          it 'pushes the creature into the target list via Observer.consume' do
            expect(described_class).to receive(:push_revealed_targets).with(id, 'stalker', name)
            described_class::Observer.consume(line, described_class::Observer.wants?(line))
          end
        end
      end
    end
  end

  describe 'kiramon stalker stumble, miss and interpose reveals (Term::REVEALED_STALKER_*)' do
    # Raw XML captured live; player names and ids anonymized. The misses link the stalker only by
    # its pronoun, so no name is captured.
    player = '<a exist="-1234567" noun="Examplechar">%s</a>'
    its    = '<pushBold/><a exist="%<id>s" noun="stalker">%<word>s</a><popBold/>'
    {
      'stumble (sleek black stalker)'             => [
        '24776474', 'sleek black kiramon stalker',
        '<pushBold/>A <a exist="%<id>s" noun="stalker">sleek black kiramon stalker</a><popBold/> stumbles slightly as ' \
          "#{format(its, id: '%<id>s', word: 'it')} leaps from hiding, revealing #{format(its, id: '%<id>s', word: 'itself')} in the process."
      ],
      'stumble (grizzled stalker)'                => [
        '26221097', 'grizzled kiramon stalker',
        '<pushBold/>A <a exist="%<id>s" noun="stalker">grizzled kiramon stalker</a><popBold/> stumbles slightly as ' \
          "#{format(its, id: '%<id>s', word: 'it')} leaps from hiding, revealing #{format(its, id: '%<id>s', word: 'itself')} in the process."
      ],
      'missed ambush, 1st-person view'            => [
        '24776477', nil,
        "Caught unaware, you can only stare in fascination as #{format(its, id: '%<id>s', word: 'it')} manages to completely " \
          "miss you while nearly losing #{format(its, id: '%<id>s', word: 'its')} balance in the process."
      ],
      'missed ambush, bystander view'             => [
        '24776477', nil,
        "Though #{format(player, 'Examplechar')} is caught unaware, #{format(player, 'his')} attacker manages to completely ruin " \
          "#{format(its, id: '%<id>s', word: 'its')} opportunity by missing #{format(its, id: '%<id>s', word: 'its')} strike, " \
          "nearly losing #{format(its, id: '%<id>s', word: 'its')} balance in the process."
      ],
      'interpose, 1st-person view (you hide)'     => [
        '39571586', 'sleek black kiramon stalker',
        'As you attempt to hide, <pushBold/>a <a exist="%<id>s" noun="stalker">sleek black kiramon stalker</a><popBold/> ' \
          'glides past you in a single fluid motion, interposing between you and the safety of the shadows.'
      ],
      'interpose, 3rd-person view (player hides)' => [
        '39571586', 'sleek black kiramon stalker',
        "As #{format(player, 'Examplechar')} attempts to hide, " \
          '<pushBold/>a <a exist="%<id>s" noun="stalker">sleek black kiramon stalker</a><popBold/> ' \
          "glides past #{format(player, 'him')} in a single fluid motion, interposing between #{format(player, 'him')} " \
          'and the safety of the shadows.'
      ],
    }.each do |what, (id, name, template)|
      context what do
        let(:line) { format(template, id: id) }

        it 'captures the creature id and noun' do
          match = line.match(term::ANY_REVEALED)
          expect(match).not_to be_nil
          expect(match[:id]).to eq(id)
          expect(match[:noun]).to eq('stalker')
        end

        it 'is seen by the observer' do
          expect(described_class::Observer.wants?(line)).to be_truthy
        end

        it 'pushes the creature into the target list via Observer.consume' do
          expect(described_class).to receive(:push_revealed_targets).with(id, 'stalker', name)
          described_class::Observer.consume(line, described_class::Observer.wants?(line))
        end
      end
    end

    it 'does not treat a player missing a hidden attack on a creature as a stalker miss' do
      # Live capture; the attacker is a hidden player and the victim a creature.
      line = 'Though <pushBold/>a <a exist="11755131" noun="rogue">human rogue</a><popBold/> is caught unaware, ' \
             'you manage to completely miss your strike and nearly drop your ' \
             '<a exist="11755140" noun="greatsword">mithril greatsword</a> in the process.  Not your smoothest move.'
      expect(line).not_to match(term::ANY)
    end

    it 'does not treat a visible stalker stinger attack as a reveal' do
      # Live capture; no "Without warning, ... glides from the shadows", so the stalker was not hidden.
      line = '<pushBold/>A <a exist="26227914" noun="stalker">sleek black kiramon stalker</a><popBold/> twists fluidly to spear you ' \
             'with <pushBold/><a exist="26227914" noun="stalker">its</a><popBold/> barbed stinger!'
      expect(line).not_to match(term::ANY)
    end
  end

  describe '.push_revealed_targets with a nameless reveal (real GameObj registry)' do
    # Live captures; player name and id anonymized. The bystander miss names the stalker only by its
    # pronoun; the Thorn Barrier block names it.
    let(:id) { '24776477' }
    let(:miss) do
      'Though <a exist="-1234567" noun="Examplechar">Examplechar</a> is caught unaware, ' \
        '<a exist="-1234567" noun="Examplechar">his</a> attacker manages to completely ruin ' \
        "<pushBold/><a exist=\"#{id}\" noun=\"stalker\">its</a><popBold/> opportunity by missing " \
        "<pushBold/><a exist=\"#{id}\" noun=\"stalker\">its</a><popBold/> strike, nearly losing " \
        "<pushBold/><a exist=\"#{id}\" noun=\"stalker\">its</a><popBold/> balance in the process."
    end
    let(:block) do
      "The thorny barrier surrounding you blocks the attack from the <pushBold/><a exist=\"#{id}\" noun=\"stalker\">kiramon stalker</a><popBold/>!"
    end

    def feed(line)
      described_class::Observer.consume(line, described_class::Observer.wants?(line))
    end

    before do
      GameObj.clear_npcs
      XMLData.current_target_ids.clear
    end

    after do
      GameObj.clear_npcs
      XMLData.current_target_ids.clear
    end

    it 'targets the id without registering a placeholder NPC' do
      feed(miss)
      expect(XMLData.current_target_ids).to eq([id])
      expect(GameObj.npcs).to be_nil
    end

    it 'registers the real name when a later line names the stalker' do
      feed(miss)
      feed(block)
      expect(GameObj.npcs.map { |npc| [npc.id, npc.name] }).to eq([[id, 'kiramon stalker']])
      expect(GameObj['kiramon stalker']&.id).to eq(id)
      expect(GameObj.targets.map(&:name)).to eq(['kiramon stalker'])
      expect(XMLData.current_target_ids).to eq([id])
    end

    it 'keeps the known name when the nameless line comes second' do
      feed(block)
      feed(miss)
      expect(GameObj.npcs.map { |npc| [npc.id, npc.name] }).to eq([[id, 'kiramon stalker']])
      expect(GameObj.targets.map(&:name)).to eq(['kiramon stalker'])
      expect(XMLData.current_target_ids).to eq([id])
    end
  end
end
