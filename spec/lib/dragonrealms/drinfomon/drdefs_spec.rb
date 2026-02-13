# frozen_string_literal: true

require_relative '../../../spec_helper'

# Mock $ORDINALS global
$ORDINALS = %w[first second third fourth fifth sixth seventh eighth ninth tenth eleventh twelfth thirteenth fourteenth fifteenth sixteenth seventeenth eighteenth nineteenth twentieth].freeze unless defined?($ORDINALS)

# Load the module under test
require_relative '../../../../lib/dragonrealms/drinfomon/drdefs'

# Create a test class that includes the module
class DRDefsTestHelper
  include Lich::DragonRealms
end

RSpec.describe Lich::DragonRealms do
  let(:helper) { DRDefsTestHelper.new }

  describe 'DRDefsPattern constants' do
    describe 'TRAILING_AND' do
      it 'matches trailing " and X" with named capture' do
        match = "Mahtra and Quilsilgas".match(Lich::DragonRealms::DRDefsPattern::TRAILING_AND)
        expect(match).not_to be_nil
        expect(match[:last]).to eq('Quilsilgas')
      end

      it 'captures multiple words after and' do
        match = "Mahtra and Quilsilgas who is sitting".match(Lich::DragonRealms::DRDefsPattern::TRAILING_AND)
        expect(match[:last]).to eq('Quilsilgas who is sitting')
      end

      it 'matches at end of complex player list' do
        match = "Mahtra, Quilsilgas and Player3".match(Lich::DragonRealms::DRDefsPattern::TRAILING_AND)
        expect(match[:last]).to eq('Player3')
      end

      it 'matches greedily to end of string' do
        # Matches " and X" all the way to end of string
        match = "Mahtra and Quilsilgas, Player3".match(Lich::DragonRealms::DRDefsPattern::TRAILING_AND)
        expect(match[:last]).to eq('Quilsilgas, Player3')
      end
    end

    describe 'PLAYER_STATUS' do
      let(:pattern) { Lich::DragonRealms::DRDefsPattern::PLAYER_STATUS }

      it 'matches "who is sitting"' do
        expect(' who is sitting').to match(pattern)
      end

      it 'matches "who is lying down"' do
        expect(' who is lying down').to match(pattern)
      end

      it 'matches "who appears dead"' do
        expect(' who appears dead').to match(pattern)
      end

      it 'matches "who has a pet"' do
        expect(' who has a pet following').to match(pattern)
      end

      it 'matches "who glows with"' do
        expect(' who glows with a faint aura').to match(pattern)
      end

      it 'matches "whose body is"' do
        expect(' whose body is covered in blood').to match(pattern)
      end
    end

    describe 'CREATURE_NAME' do
      let(:pattern) { Lich::DragonRealms::DRDefsPattern::CREATURE_NAME }

      it 'matches simple creature names' do
        expect('goblin'.scan(pattern).first).to eq('goblin')
      end

      it 'matches hyphenated names' do
        expect('shadow-spider'.scan(pattern).first).to eq('shadow-spider')
      end

      it 'matches apostrophe names' do
        expect("will-o'-wisp".scan(pattern).first).to eq("will-o'-wisp")
      end

      it 'matches multi-hyphen names' do
        expect('shadow-web-spider'.scan(pattern).first).to eq('shadow-web-spider')
      end

      it 'extracts name from end of string' do
        expect('a large green goblin'.scan(pattern).first).to eq('goblin')
      end

      it 'does not match brackets (fixed [A-z] bug)' do
        expect('test]bracket'.scan(pattern).first).to eq('bracket')
      end

      it 'does not match underscores (fixed [A-z] bug)' do
        expect('test_underscore'.scan(pattern).first).to eq('underscore')
      end

      it 'does not match carets (fixed [A-z] bug)' do
        expect('test^caret'.scan(pattern).first).to eq('caret')
      end

      it 'does not match backslashes (fixed [A-z] bug)' do
        expect('test\\backslash'.scan(pattern).first).to eq('backslash')
      end
    end

    describe 'LYING_DOWN' do
      let(:pattern) { Lich::DragonRealms::DRDefsPattern::LYING_DOWN }

      it 'matches "who is lying down"' do
        expect('Mahtra who is lying down').to match(pattern)
      end

      it 'is case insensitive' do
        expect('Mahtra WHO IS LYING DOWN').to match(pattern)
      end
    end

    describe 'SITTING' do
      let(:pattern) { Lich::DragonRealms::DRDefsPattern::SITTING }

      it 'matches "who is sitting"' do
        expect('Mahtra who is sitting').to match(pattern)
      end

      it 'is case insensitive' do
        expect('Mahtra WHO IS SITTING').to match(pattern)
      end
    end

    describe 'NPC_SCAN' do
      let(:pattern) { Lich::DragonRealms::DRDefsPattern::NPC_SCAN }

      it 'matches live NPC' do
        matches = '<pushBold/>goblin<popBold/>'.scan(pattern)
        expect(matches.first).to eq('<pushBold/>goblin<popBold/>')
      end

      it 'matches dead NPC with "which appears dead"' do
        matches = '<pushBold/>goblin<popBold/> which appears dead'.scan(pattern)
        expect(matches.first).to include('which appears dead')
      end

      it 'matches dead NPC with "(dead)"' do
        matches = '<pushBold/>goblin<popBold/> (dead)'.scan(pattern)
        expect(matches.first).to include('(dead)')
      end

      it 'matches multiple NPCs' do
        input = '<pushBold/>goblin<popBold/> and <pushBold/>spider<popBold/>'
        matches = input.scan(pattern)
        expect(matches.size).to eq(2)
      end
    end

    describe 'DEAD_NPC' do
      let(:pattern) { Lich::DragonRealms::DRDefsPattern::DEAD_NPC }

      it 'matches "which appears dead"' do
        expect('goblin which appears dead').to match(pattern)
      end

      it 'matches "(dead)"' do
        expect('goblin (dead)').to match(pattern)
      end

      it 'does not match live NPC' do
        expect('goblin').not_to match(pattern)
      end
    end

    describe 'GELAPOD' do
      it 'is a frozen string constant' do
        expect(Lich::DragonRealms::DRDefsPattern::GELAPOD).to be_frozen
      end

      it 'contains the gelapod HTML' do
        expect(Lich::DragonRealms::DRDefsPattern::GELAPOD).to eq('<pushBold/>a domesticated gelapod<popBold/>')
      end
    end
  end

  describe '#convert2copper' do
    context 'with platinum' do
      it 'converts 1 platinum to 10000 copper' do
        expect(helper.convert2copper(1, 'platinum')).to eq(10_000)
      end

      it 'converts 5 platinum to 50000 copper' do
        expect(helper.convert2copper(5, 'platinum')).to eq(50_000)
      end

      it 'converts 100 platinum to 1000000 copper' do
        expect(helper.convert2copper(100, 'platinum')).to eq(1_000_000)
      end
    end

    context 'with gold' do
      it 'converts 1 gold to 1000 copper' do
        expect(helper.convert2copper(1, 'gold')).to eq(1000)
      end

      it 'converts 10 gold to 10000 copper' do
        expect(helper.convert2copper(10, 'gold')).to eq(10_000)
      end
    end

    context 'with silver' do
      it 'converts 1 silver to 100 copper' do
        expect(helper.convert2copper(1, 'silver')).to eq(100)
      end

      it 'converts 25 silver to 2500 copper' do
        expect(helper.convert2copper(25, 'silver')).to eq(2500)
      end
    end

    context 'with bronze' do
      it 'converts 1 bronze to 10 copper' do
        expect(helper.convert2copper(1, 'bronze')).to eq(10)
      end

      it 'converts 50 bronze to 500 copper' do
        expect(helper.convert2copper(50, 'bronze')).to eq(500)
      end
    end

    context 'with copper' do
      it 'returns copper amount unchanged' do
        expect(helper.convert2copper(100, 'copper')).to eq(100)
      end
    end

    context 'with string amounts' do
      it 'converts string to integer' do
        expect(helper.convert2copper('5', 'platinum')).to eq(50_000)
      end
    end

    context 'with unknown denomination' do
      it 'returns the original amount' do
        expect(helper.convert2copper(100, 'unknown')).to eq(100)
      end
    end
  end

  describe '#convert2plats' do
    it 'converts 12345 copper correctly' do
      result = helper.convert2plats(12_345)
      expect(result).to eq('1 platinum, 2 gold, 3 silver, 4 bronze, 5 copper')
    end

    it 'handles exact platinum amount' do
      expect(helper.convert2plats(10_000)).to eq('1 platinum')
    end

    it 'handles exact gold amount' do
      expect(helper.convert2plats(1000)).to eq('1 gold')
    end

    it 'handles exact silver amount' do
      expect(helper.convert2plats(100)).to eq('1 silver')
    end

    it 'handles exact bronze amount' do
      expect(helper.convert2plats(10)).to eq('1 bronze')
    end

    it 'handles exact copper amount' do
      expect(helper.convert2plats(1)).to eq('1 copper')
    end

    it 'handles zero' do
      expect(helper.convert2plats(0)).to eq('')
    end

    it 'handles large amounts' do
      result = helper.convert2plats(999_999_999)
      expect(result).to include('platinum')
    end

    it 'skips zero denominations' do
      # 10010 = 1 plat, 0 gold, 0 silver, 1 bronze, 0 copper
      result = helper.convert2plats(10_010)
      expect(result).to eq('1 platinum, 1 bronze')
    end
  end

  describe '#normalize_trailing_and' do
    it 'converts trailing "and X" to ", X"' do
      result = helper.normalize_trailing_and('Mahtra and Quilsilgas')
      expect(result).to eq('Mahtra, Quilsilgas')
    end

    it 'returns original if no trailing and' do
      result = helper.normalize_trailing_and('Mahtra, Quilsilgas')
      expect(result).to eq('Mahtra, Quilsilgas')
    end

    it 'handles single name' do
      result = helper.normalize_trailing_and('Mahtra')
      expect(result).to eq('Mahtra')
    end

    it 'handles complex player descriptions' do
      result = helper.normalize_trailing_and('Mahtra who is sitting and Quilsilgas who is lying down')
      expect(result).to eq('Mahtra who is sitting, Quilsilgas who is lying down')
    end

    it 'handles multiple players with statuses' do
      input = 'Mahtra, Player2 and Quilsilgas'
      result = helper.normalize_trailing_and(input)
      expect(result).to eq('Mahtra, Player2, Quilsilgas')
    end
  end

  describe '#find_pcs' do
    context 'with nil or empty input' do
      it 'returns empty array for nil' do
        expect(helper.find_pcs(nil)).to eq([])
      end

      it 'returns empty array for empty string' do
        expect(helper.find_pcs('')).to eq([])
      end
    end

    context 'with single player' do
      it 'extracts player name' do
        expect(helper.find_pcs('Mahtra')).to eq(['Mahtra'])
      end
    end

    context 'with two players' do
      it 'extracts both names with "and"' do
        result = helper.find_pcs('Mahtra and Quilsilgas')
        expect(result).to contain_exactly('Mahtra', 'Quilsilgas')
      end

      it 'extracts both names with comma' do
        result = helper.find_pcs('Mahtra, Quilsilgas')
        expect(result).to contain_exactly('Mahtra', 'Quilsilgas')
      end
    end

    context 'with multiple players' do
      it 'extracts all names' do
        result = helper.find_pcs('Mahtra, Player2, Player3 and Quilsilgas')
        expect(result).to contain_exactly('Mahtra', 'Player2', 'Player3', 'Quilsilgas')
      end
    end

    context 'with player statuses' do
      it 'strips "who is sitting"' do
        result = helper.find_pcs('Mahtra who is sitting')
        expect(result).to eq(['Mahtra'])
      end

      it 'strips "who is lying down"' do
        result = helper.find_pcs('Mahtra who is lying down')
        expect(result).to eq(['Mahtra'])
      end

      it 'strips "who appears dead"' do
        result = helper.find_pcs('Mahtra who appears dead')
        expect(result).to eq(['Mahtra'])
      end

      it 'strips "who has a pet"' do
        result = helper.find_pcs('Mahtra who has a pet following')
        expect(result).to eq(['Mahtra'])
      end

      it 'strips "who glows with"' do
        result = helper.find_pcs('Mahtra who glows with a faint aura')
        expect(result).to eq(['Mahtra'])
      end

      it 'strips multiple different statuses from different players' do
        result = helper.find_pcs('Mahtra who is sitting and Quilsilgas who is lying down')
        expect(result).to contain_exactly('Mahtra', 'Quilsilgas')
      end
    end

    context 'with parenthetical info' do
      it 'strips (Premium)' do
        result = helper.find_pcs('Mahtra (Premium)')
        expect(result).to eq(['Mahtra'])
      end

      it 'strips (dead)' do
        result = helper.find_pcs('Mahtra (dead)')
        expect(result).to eq(['Mahtra'])
      end

      it 'strips complex parenthetical' do
        result = helper.find_pcs('Mahtra (Group Leader)')
        expect(result).to eq(['Mahtra'])
      end
    end

    context 'with titles' do
      it 'extracts last name from titled player' do
        result = helper.find_pcs('Lord Mahtra')
        expect(result).to eq(['Mahtra'])
      end
    end
  end

  describe '#find_pcs_prone' do
    context 'with nil or empty input' do
      it 'returns empty array for nil' do
        expect(helper.find_pcs_prone(nil)).to eq([])
      end

      it 'returns empty array for empty string' do
        expect(helper.find_pcs_prone('')).to eq([])
      end
    end

    context 'with prone players' do
      it 'returns player who is lying down' do
        result = helper.find_pcs_prone('Mahtra who is lying down')
        expect(result).to eq(['Mahtra'])
      end

      it 'filters out non-prone players' do
        result = helper.find_pcs_prone('Mahtra who is lying down and Quilsilgas who is sitting')
        expect(result).to eq(['Mahtra'])
      end

      it 'returns multiple prone players' do
        result = helper.find_pcs_prone('Mahtra who is lying down and Quilsilgas who is lying down')
        expect(result).to contain_exactly('Mahtra', 'Quilsilgas')
      end
    end

    context 'with no prone players' do
      it 'returns empty array' do
        result = helper.find_pcs_prone('Mahtra and Quilsilgas')
        expect(result).to eq([])
      end

      it 'returns empty for sitting players' do
        result = helper.find_pcs_prone('Mahtra who is sitting')
        expect(result).to eq([])
      end
    end
  end

  describe '#find_pcs_sitting' do
    context 'with nil or empty input' do
      it 'returns empty array for nil' do
        expect(helper.find_pcs_sitting(nil)).to eq([])
      end

      it 'returns empty array for empty string' do
        expect(helper.find_pcs_sitting('')).to eq([])
      end
    end

    context 'with sitting players' do
      it 'returns player who is sitting' do
        result = helper.find_pcs_sitting('Mahtra who is sitting')
        expect(result).to eq(['Mahtra'])
      end

      it 'filters out non-sitting players' do
        result = helper.find_pcs_sitting('Mahtra who is sitting and Quilsilgas who is lying down')
        expect(result).to eq(['Mahtra'])
      end

      it 'returns multiple sitting players' do
        result = helper.find_pcs_sitting('Mahtra who is sitting and Quilsilgas who is sitting')
        expect(result).to contain_exactly('Mahtra', 'Quilsilgas')
      end
    end

    context 'with no sitting players' do
      it 'returns empty array' do
        result = helper.find_pcs_sitting('Mahtra and Quilsilgas')
        expect(result).to eq([])
      end
    end
  end

  describe '#add_ordinals_to_duplicates' do
    context 'with unique NPCs' do
      it 'returns single NPC without ordinal' do
        expect(helper.add_ordinals_to_duplicates(['goblin'])).to eq(['goblin'])
      end

      it 'returns multiple unique NPCs without ordinals' do
        result = helper.add_ordinals_to_duplicates(%w[goblin spider])
        expect(result).to eq(%w[goblin spider])
      end
    end

    context 'with duplicate NPCs' do
      it 'adds ordinals to duplicates' do
        result = helper.add_ordinals_to_duplicates(%w[goblin goblin])
        expect(result).to eq(['goblin', 'second goblin'])
      end

      it 'handles three duplicates' do
        result = helper.add_ordinals_to_duplicates(%w[goblin goblin goblin])
        expect(result).to eq(['goblin', 'second goblin', 'third goblin'])
      end

      it 'handles many duplicates' do
        result = helper.add_ordinals_to_duplicates(Array.new(10, 'goblin'))
        expect(result[0]).to eq('goblin')
        expect(result[1]).to eq('second goblin')
        expect(result[9]).to eq('tenth goblin')
      end
    end

    context 'with mixed NPCs' do
      it 'handles mixed unique and duplicate' do
        result = helper.add_ordinals_to_duplicates(%w[goblin spider goblin])
        expect(result).to include('goblin', 'second goblin', 'spider')
      end

      it 'handles multiple different duplicates' do
        result = helper.add_ordinals_to_duplicates(%w[goblin spider goblin spider])
        expect(result).to include('goblin', 'second goblin', 'spider', 'second spider')
      end
    end

    context 'with more than 20 duplicates' do
      it 'generates ordinals beyond $ORDINALS array' do
        npcs = Array.new(25, 'goblin')
        result = helper.add_ordinals_to_duplicates(npcs)
        expect(result.size).to eq(25)
        expect(result[0]).to eq('goblin')
        expect(result[1]).to eq('second goblin')
        expect(result[19]).to eq('twentieth goblin')
        expect(result[20]).to eq('21th goblin')
        expect(result[21]).to eq('22th goblin')
        expect(result[24]).to eq('25th goblin')
      end
    end

    context 'with empty list' do
      it 'returns empty array' do
        expect(helper.add_ordinals_to_duplicates([])).to eq([])
      end
    end
  end

  describe '#find_objects' do
    context 'with frozen strings' do
      it 'does not mutate frozen strings' do
        frozen_input = "You also see a sword.".freeze
        expect { helper.find_objects(frozen_input) }.not_to raise_error
      end

      it 'does not raise FrozenError' do
        frozen_input = "You also see <pushBold/>a domesticated gelapod<popBold/> and a sword.".freeze
        expect { helper.find_objects(frozen_input) }.not_to raise_error
      end
    end

    context 'extracting objects' do
      it 'extracts single object' do
        result = helper.find_objects("You also see a sword.")
        expect(result).to include('sword')
      end

      it 'extracts multiple objects with "and"' do
        result = helper.find_objects("You also see a sword and a shield.")
        expect(result).to include('sword', 'shield')
      end

      it 'extracts multiple objects with comma' do
        result = helper.find_objects("You also see a sword, a shield.")
        expect(result).to include('sword', 'shield')
      end

      it 'extracts many objects' do
        result = helper.find_objects("You also see a sword, a shield, a helm and a chest.")
        expect(result.size).to eq(4)
      end
    end

    context 'stripping articles' do
      it 'strips "a" article' do
        result = helper.find_objects("You also see a sword.")
        expect(result).to eq(['sword'])
      end

      it 'strips "some" article' do
        result = helper.find_objects("You also see some coins.")
        expect(result).to eq(['coins'])
      end
    end

    context 'handling NPCs (bold tags)' do
      it 'excludes NPCs with bold tags' do
        result = helper.find_objects("You also see a <pushBold/>goblin<popBold/> and a sword.")
        expect(result.any? { |r| r.include?('goblin') }).to be false
        expect(result).to include('sword')
      end
    end

    context 'gelapod replacement' do
      it 'handles domesticated gelapod' do
        result = helper.find_objects("You also see <pushBold/>a domesticated gelapod<popBold/>.")
        expect(result).to include('domesticated gelapod')
      end
    end

    context 'stripping trailing period' do
      it 'removes trailing period from objects' do
        result = helper.find_objects("You also see a sword.")
        expect(result.first).not_to end_with('.')
      end
    end
  end

  describe '#find_npcs' do
    context 'extracting NPCs' do
      it 'extracts single NPC' do
        result = helper.find_npcs("You also see a <pushBold/>goblin<popBold/>.")
        expect(result).to include('goblin')
      end

      it 'extracts multiple NPCs' do
        result = helper.find_npcs("You also see a <pushBold/>goblin<popBold/> and a <pushBold/>spider<popBold/>.")
        expect(result).to include('goblin', 'spider')
      end
    end

    context 'excluding dead NPCs' do
      it 'excludes "which appears dead" NPCs' do
        result = helper.find_npcs("You also see a <pushBold/>goblin<popBold/> which appears dead.")
        expect(result).to be_empty
      end

      it 'excludes "(dead)" NPCs' do
        result = helper.find_npcs("You also see a <pushBold/>goblin<popBold/> (dead).")
        expect(result).to be_empty
      end

      it 'includes live NPCs when dead ones present' do
        result = helper.find_npcs("You also see a <pushBold/>goblin<popBold/> which appears dead and a <pushBold/>spider<popBold/>.")
        expect(result).not_to include('goblin')
        expect(result).to include('spider')
      end
    end

    context 'with ordinals' do
      it 'adds ordinals to duplicate NPCs' do
        result = helper.find_npcs("You also see a <pushBold/>goblin<popBold/> and a <pushBold/>goblin<popBold/>.")
        expect(result).to include('goblin', 'second goblin')
      end
    end
  end

  describe '#find_dead_npcs' do
    context 'extracting dead NPCs' do
      it 'extracts "which appears dead" NPCs' do
        result = helper.find_dead_npcs("You also see a <pushBold/>goblin<popBold/> which appears dead.")
        expect(result).to include('goblin')
      end

      it 'extracts "(dead)" NPCs' do
        result = helper.find_dead_npcs("You also see a <pushBold/>goblin<popBold/> (dead).")
        expect(result).to include('goblin')
      end

      it 'extracts multiple dead NPCs' do
        result = helper.find_dead_npcs("You also see a <pushBold/>goblin<popBold/> (dead) and a <pushBold/>spider<popBold/> which appears dead.")
        expect(result).to include('goblin', 'spider')
      end
    end

    context 'excluding live NPCs' do
      it 'excludes live NPCs' do
        result = helper.find_dead_npcs("You also see a <pushBold/>goblin<popBold/> which appears dead and a <pushBold/>spider<popBold/>.")
        expect(result).to include('goblin')
        expect(result).not_to include('spider')
      end
    end

    context 'with ordinals' do
      it 'adds ordinals to duplicate dead NPCs' do
        result = helper.find_dead_npcs("You also see a <pushBold/>goblin<popBold/> (dead) and a <pushBold/>goblin<popBold/> which appears dead.")
        expect(result).to include('goblin', 'second goblin')
      end
    end
  end

  describe '#clean_and_split' do
    it 'removes "You also see" prefix' do
      result = helper.clean_and_split("You also see a sword and a shield")
      expect(result.join).not_to include('You also see')
    end

    it 'removes mount descriptions' do
      result = helper.clean_and_split("You also see a horse with a rider sitting astride its back")
      expect(result.join).not_to include('sitting astride')
    end

    it 'splits on comma' do
      result = helper.clean_and_split("a sword, a shield, a helm")
      expect(result.size).to eq(3)
    end

    it 'splits on "and"' do
      result = helper.clean_and_split("a sword and a shield")
      expect(result.size).to eq(2)
    end

    it 'handles mixed comma and "and"' do
      result = helper.clean_and_split("a sword, a shield and a helm")
      expect(result.size).to eq(3)
    end
  end

  describe '#find_all_npcs' do
    it 'finds NPCs in bold tags' do
      result = helper.find_all_npcs("You also see a <pushBold/>goblin<popBold/>.")
      expect(result.size).to eq(1)
    end

    it 'finds dead and live NPCs' do
      result = helper.find_all_npcs("You also see a <pushBold/>goblin<popBold/> and a <pushBold/>spider<popBold/> which appears dead.")
      expect(result.size).to eq(2)
    end

    it 'removes mount descriptions before scanning' do
      result = helper.find_all_npcs("You also see a horse with a rider sitting astride its back and a <pushBold/>goblin<popBold/>.")
      expect(result.size).to eq(1)
    end
  end

  describe '#normalize_creature_names' do
    it 'normalizes alfar warrior variants' do
      expect(helper.normalize_creature_names('a savage alfar warrior')).to eq('alfar warrior')
    end

    it 'normalizes sinewy leopard variants' do
      expect(helper.normalize_creature_names('a massive sinewy leopard')).to eq('sinewy leopard')
    end

    it 'normalizes lesser naga variants' do
      expect(helper.normalize_creature_names('an ancient lesser naga')).to eq('lesser naga')
    end

    it 'leaves other creatures unchanged' do
      expect(helper.normalize_creature_names('goblin')).to eq('goblin')
    end
  end

  describe '#remove_html_tags' do
    it 'removes pushBold tag' do
      result = helper.remove_html_tags('<pushBold/>goblin<popBold/>')
      expect(result).not_to include('<pushBold/>')
    end

    it 'removes popBold and everything after' do
      result = helper.remove_html_tags('<pushBold/>goblin<popBold/> which appears dead')
      expect(result).to eq('goblin')
    end
  end

  describe '#extract_last_creature' do
    it 'extracts creature after "and"' do
      result = helper.extract_last_creature('a large spider and a goblin')
      expect(result).to eq('a goblin')
    end

    it 'removes "glowing with" modifiers' do
      result = helper.extract_last_creature('a goblin glowing with a faint aura')
      expect(result).to eq('a goblin')
    end

    it 'removes "with" modifiers' do
      result = helper.extract_last_creature('a goblin with a sword')
      expect(result).to eq('a goblin')
    end

    it 'handles creature without modifiers' do
      result = helper.extract_last_creature('a goblin')
      expect(result).to eq('a goblin')
    end
  end

  describe '#extract_final_name' do
    it 'extracts creature name from end' do
      expect(helper.extract_final_name('a large goblin')).to eq('goblin')
    end

    it 'handles hyphenated names' do
      expect(helper.extract_final_name('a shadow-spider')).to eq('shadow-spider')
    end

    it 'handles apostrophe names' do
      expect(helper.extract_final_name("a will-o'-wisp")).to eq("will-o'-wisp")
    end

    it 'handles leading whitespace' do
      expect(helper.extract_final_name('  goblin')).to eq('goblin')
    end

    it 'handles trailing whitespace' do
      expect(helper.extract_final_name('goblin  ')).to eq('goblin')
    end
  end

  describe '#clean_npc_string' do
    it 'processes array of NPC strings' do
      input = ['<pushBold/>goblin<popBold/>', '<pushBold/>spider<popBold/>']
      result = helper.clean_npc_string(input)
      expect(result).to include('goblin', 'spider')
    end

    it 'sorts NPCs alphabetically' do
      input = ['<pushBold/>spider<popBold/>', '<pushBold/>goblin<popBold/>']
      result = helper.clean_npc_string(input)
      expect(result).to eq(%w[goblin spider])
    end

    it 'adds ordinals to duplicates' do
      input = ['<pushBold/>goblin<popBold/>', '<pushBold/>goblin<popBold/>']
      result = helper.clean_npc_string(input)
      expect(result).to eq(['goblin', 'second goblin'])
    end

    it 'handles empty array' do
      expect(helper.clean_npc_string([])).to eq([])
    end
  end
end
