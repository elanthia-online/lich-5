# frozen_string_literal: true

require_relative '../../../spec_helper'

# Helper class for GameObj mock - used with stub_const in tests
# NOTE: GameObj is NOT defined at top level to avoid conflicts with qstrike_spec
DRC_MOCK_GAME_OBJ = Class.new do
  attr_accessor :name, :noun

  define_method(:initialize) do |name: 'Empty', noun: nil|
    @name = name
    @noun = noun
  end
end unless defined?(DRC_MOCK_GAME_OBJ)

# Global variables required by common.rb (test data, not mocks)
$HOMETOWN_REGEX_MAP = {
  "Crossing" => /^(cross(ing)?)$/i, "Riverhaven" => /^(river|haven|riverhaven)$/i,
  "Shard" => /^(shard)$/i, "Therenborough" => /^(theren(borough)?)$/i,
  "Mer'Kresh" => /^(mer'?kresh)$/i, "Ain Ghazal" => /^(ain( )?ghazal)$/i
} unless defined?($HOMETOWN_REGEX_MAP)

$NUM_MAP = {
  'zero' => 0, 'one' => 1, 'two' => 2, 'three' => 3, 'four' => 4, 'five' => 5,
  'six' => 6, 'seven' => 7, 'eight' => 8, 'nine' => 9, 'ten' => 10, 'eleven' => 11,
  'twelve' => 12, 'thirteen' => 13, 'fourteen' => 14, 'fifteen' => 15, 'sixteen' => 16,
  'seventeen' => 17, 'eighteen' => 18, 'nineteen' => 19, 'twenty' => 20, 'thirty' => 30,
  'forty' => 40, 'fifty' => 50, 'sixty' => 60, 'seventy' => 70, 'eighty' => 80, 'ninety' => 90
} unless defined?($NUM_MAP)

$ENC_MAP = {
  'None' => 0, 'Light Burden' => 1, 'Somewhat Burdened' => 2, 'Burdened' => 3,
  'Heavy Burden' => 4, 'Very Heavy Burden' => 5, 'Overburdened' => 6,
  'Very Overburdened' => 7, 'Extremely Overburdened' => 8, 'Tottering Under Burden' => 9,
  'Are you even able to move?' => 10, "It's amazing you aren't squashed!" => 11
} unless defined?($ENC_MAP)

$box_regex = /((?:brass|copper|deobar|driftwood|iron|ironwood|mahogany|oaken|pine|steel|wooden) (?:box|caddy|casket|chest|coffer|crate|skippet|strongbox|trunk))/ unless defined?($box_regex)
$fake_stormfront = false unless defined?($fake_stormfront)

# Box vocabulary constants normally provided by drvariables.rb (not loaded here);
# box_list_to_adj_and_noun builds its match regex from these.
module Lich
  module DragonRealms
    BOX_WOODS = %w[brass copper deobar driftwood iron ironwood mahogany oaken pine steel wooden].freeze unless defined?(BOX_WOODS)
    BOX_CONTAINERS = %w[box caddy casket chest coffer crate skippet strongbox trunk].freeze unless defined?(BOX_CONTAINERS)
  end
end

# Load production code
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common.rb')
DRC = Lich::DragonRealms::DRC unless defined?(DRC)

RSpec.describe Lich::DragonRealms::DRC do
  before(:each) do
    Lich::Messaging.clear_messages!
    # Rebuild memoized custom-substitution lists so a stub in one example does
    # not leak its merged list into the next (see CustomSubstitutions.reset!).
    Lich::DragonRealms::CustomSubstitutions.reset!
    # Stub GameObj with a temporary mock if not already defined by other specs
    stub_const('GameObj', DRC_MOCK_GAME_OBJ) unless defined?(::GameObj)
  end

  describe 'constants' do
    it('WAIT_RESPONSE_PATTERN is frozen') { expect(described_class::WAIT_RESPONSE_PATTERN).to be_frozen }
    it('COLLECT_MESSAGES is frozen') { expect(described_class::COLLECT_MESSAGES).to be_frozen }
    it('RETREAT_ESCAPE_MESSAGES is frozen') { expect(described_class::RETREAT_ESCAPE_MESSAGES).to be_frozen }
    it('RETREAT_MESSAGES is frozen') { expect(described_class::RETREAT_MESSAGES).to be_frozen }
    it('ASSESS_TEACH_TEACHER_PATTERN is frozen') { expect(described_class::ASSESS_TEACH_TEACHER_PATTERN).to be_frozen }
    it('ASSESS_TEACH_SKILL_FILTER_PATTERN is frozen') { expect(described_class::ASSESS_TEACH_SKILL_FILTER_PATTERN).to be_frozen }
    it('COMMON_RANGED_WEAPONS_PATTERN is frozen') { expect(described_class::COMMON_RANGED_WEAPONS_PATTERN).to be_frozen }
    it('RACIAL_RANGED_WEAPONS_PATTERN is frozen') { expect(described_class::RACIAL_RANGED_WEAPONS_PATTERN).to be_frozen }
    it('FLAVOR_TEXT_PATTERN is frozen') { expect(described_class::FLAVOR_TEXT_PATTERN).to be_frozen }
    it('CANNOT_STAND_PATTERN is frozen') { expect(described_class::CANNOT_STAND_PATTERN).to be_frozen }
    it('IMMOBILE_PATTERN is frozen') { expect(described_class::IMMOBILE_PATTERN).to be_frozen }

    it 'CANNOT_STAND_PATTERN matches the immobile reply only at the start of the line' do
      expect("You don't seem to be able to move to do that.").to match(described_class::CANNOT_STAND_PATTERN)
      expect("Bob says, \"You don't seem to be able to move to do that.\"").not_to match(described_class::CANNOT_STAND_PATTERN)
    end

    it 'WAIT_RESPONSE_PATTERN is the core pattern fput uses' do
      expect(described_class::WAIT_RESPONSE_PATTERN).to equal(Lich::Common::WAIT_RESPONSE_PATTERN)
    end

    it 'WAIT_RESPONSE_PATTERN matches wait responses with seconds capture' do
      match = "...wait 3 seconds.".match(described_class::WAIT_RESPONSE_PATTERN)
      expect(match).not_to be_nil
      expect(match[:seconds]).to eq('3')
    end

    it 'WAIT_RESPONSE_PATTERN matches the singular, appended and tagged forms the game sends' do
      # 'sec.' is newly accepted here (dothis/move already allowed it before the pattern was shared)
      ['...wait 1 second.', 'as he...wait 2 seconds.', '...wait 4 seconds.<popBold/>', '...wait 5 sec.'].each do |line|
        expect(line).to match(described_class::WAIT_RESPONSE_PATTERN)
      end
    end

    it 'WAIT_RESPONSE_PATTERN ignores player text and other wait messages' do
      ['Bob says, "Wait 3600."', 'Bob whispers, "...wait 5 seconds."', '[Private]-DR:Bob: "...wait 5 seconds."',
       'The janitor was recently summoned to this room.  Please wait 299 seconds.'].each do |line|
        expect(line).not_to match(described_class::WAIT_RESPONSE_PATTERN)
      end
    end
  end

  describe '.list_to_array' do
    it('parses single item (strip removes leading space)') { expect(described_class.list_to_array(' a sword')).to eq(['a sword']) }
    it('parses two items with "and"') { expect(described_class.list_to_array(' a sword and a shield')).to eq(['a sword', ' a shield']) }
    it('parses multiple items with commas and "and"') { expect(described_class.list_to_array(' a sword, some coins and a box')).to eq(['a sword', ' some coins', ' a box']) }
    it('handles items with "the" article') { expect(described_class.list_to_array(' a sword and the shield')).to eq(['a sword', ' the shield']) }
    it('returns single-element array for item with no delimiters') { expect(described_class.list_to_array(' a longsword')).to eq(['a longsword']) }
  end

  describe '.list_to_nouns' do
    it('extracts nouns from a basic list') { expect(described_class.list_to_nouns(' a sword, some coins and a box')).to eq(%w[sword coins box]) }
    it('returns empty array for empty string') { expect(described_class.list_to_nouns('')).to eq([]) }
    it('extracts nouns from multi-word items') { expect(described_class.list_to_nouns(' a steel sword and a wooden shield')).to eq(%w[sword shield]) }
    it('strips flavor text before extracting nouns') { expect(described_class.list_to_nouns(' a sword adorned with rubies')).to eq(%w[sword]) }
  end

  describe '.get_noun' do
    it('extracts noun from simple item') { expect(described_class.get_noun(' a sword')).to eq('sword') }
    it('extracts noun from multi-word item') { expect(described_class.get_noun(' a steel sword')).to eq('sword') }
    it('extracts hyphenated noun') { expect(described_class.get_noun(' a long-sword')).to eq('long-sword') }
    it('extracts noun with apostrophe') { expect(described_class.get_noun(" a thief's pick")).to eq("pick") }
    it('returns nil when the name does not end in a word') { expect(described_class.get_noun('a 5')).to be_nil }
  end

  describe '.remove_flavor_text' do
    def stub_flavor_patterns(patterns)
      allow(Lich::DragonRealms::CustomSubstitutions)
        .to receive(:get_settings)
        .and_return(OpenStruct.new(custom_flavor_text_patterns: patterns))
    end

    it('returns item unchanged when no flavor text') { expect(described_class.remove_flavor_text('a sword')).to eq('a sword') }
    it('strips "adorned with" flavor text') { expect(described_class.remove_flavor_text('a sword adorned with rubies of deep crimson')).to eq('a sword') }
    it('strips "decorated with" flavor text') { expect(described_class.remove_flavor_text('a shield decorated with a golden crest')).to eq('a shield') }
    it('strips "carved with" flavor text') { expect(described_class.remove_flavor_text('a staff carved with runes of ancient design')).to eq('a staff') }

    it 'strips flavor the built-in pattern misses using a player-added pattern' do
      # A marker the built-in FLAVOR_TEXT_PATTERN does not touch, so this isolates
      # the user-pattern path.
      stub_flavor_patterns(['\s?::.*'])
      expect(described_class.remove_flavor_text('a sword ::soulbound::')).to eq('a sword')
    end

    it 'still applies the built-in pattern when a user pattern is invalid, and warns' do
      stub_flavor_patterns(['(unclosed'])
      expect(described_class.remove_flavor_text('a sword adorned with rubies of deep crimson')).to eq('a sword')
      expect(Lich::Messaging.messages.map { |m| m[:message] }.join)
        .to include('custom_flavor_text_patterns[0] skipped')
    end
  end

  describe '.box_list_to_adj_and_noun' do
    def stub_box_settings(**values)
      allow(Lich::DragonRealms::CustomSubstitutions).to receive(:get_settings).and_return(OpenStruct.new(values))
    end

    it('parses a single box') { expect(described_class.box_list_to_adj_and_noun('a wooden strongbox')).to eq(['wooden strongbox']) }
    it('converts ironwood to iron') { expect(described_class.box_list_to_adj_and_noun('an ironwood crate')).to eq(['iron crate']) }
    it('returns empty array for empty string') { expect(described_class.box_list_to_adj_and_noun('')).to eq([]) }

    it 'recognizes a player-added box wood' do
      stub_box_settings(custom_box_woods: ['faenor'])
      expect(described_class.box_list_to_adj_and_noun('a polished faenor chest')).to eq(['faenor chest'])
    end

    it 'recognizes a player-added box container' do
      stub_box_settings(custom_box_containers: ['reliquary'])
      expect(described_class.box_list_to_adj_and_noun('a battered steel reliquary')).to eq(['steel reliquary'])
    end

    it 'applies a player-added box substitution to a recognized box' do
      stub_box_settings(custom_box_woods: ['faenor'], custom_box_substitutions: [%w[faenor faewood]])
      expect(described_class.box_list_to_adj_and_noun('a polished faenor chest')).to eq(['faewood chest'])
    end

    it 'still parses built-in boxes when a custom wood entry is malformed' do
      stub_box_settings(custom_box_woods: [123])
      expect(described_class.box_list_to_adj_and_noun('an ironwood crate')).to eq(['iron crate'])
      expect(Lich::Messaging.messages.map { |m| m[:message] }.join).to include('custom_box_woods[0] skipped')
    end
  end

  describe '.scroll_list_to_adj_and_noun' do
    # Lets an example supply user additions the way get_settings would.
    def stub_scroll_settings(additions)
      allow(Lich::DragonRealms::CustomSubstitutions)
        .to receive(:get_settings)
        .and_return(OpenStruct.new(custom_scroll_substitutions: additions))
    end

    it('removes article from single scroll') { expect(described_class.scroll_list_to_adj_and_noun(' a blue scroll')).to eq(['blue scroll']) }
    it('removes label text') { expect(described_class.scroll_list_to_adj_and_noun(' a blue scroll labeled with runes')).to eq(['blue scroll']) }
    it('converts papyrus roll to papyrus.roll') { expect(described_class.scroll_list_to_adj_and_noun(' a papyrus roll')).to eq(['papyrus.roll']) }
    it('simplifies icy blue to blue') { expect(described_class.scroll_list_to_adj_and_noun(' an icy blue parchment')).to eq(['blue parchment']) }

    it 'reduces the built-in symbol-torn scale scroll to its gettable noun' do
      expect(described_class.scroll_list_to_adj_and_noun(' a large midnight-blue scale torn with symbols'))
        .to eq(['midnight-blue scale'])
    end

    it 'applies a user-added scroll substitution from settings' do
      stub_scroll_settings([['weird prismatic scroll of doom', 'doom scroll']])
      expect(described_class.scroll_list_to_adj_and_noun(' a weird prismatic scroll of doom'))
        .to eq(['doom scroll'])
    end

    it 'applies a user addition before the keyword-collapse would mangle it' do
      # Without a pre-collapse rewrite, "aqua blue vellum scroll" collapses on
      # the "vellum" keyword to "aqua blue vellum"; the user rule fixes it.
      stub_scroll_settings([['aqua blue vellum scroll', 'aqua scroll']])
      expect(described_class.scroll_list_to_adj_and_noun(' an aqua blue vellum scroll'))
        .to eq(['aqua scroll'])
    end

    it 'skips a malformed user entry, warns, and still applies the defaults' do
      stub_scroll_settings([['only one element']])
      expect(described_class.scroll_list_to_adj_and_noun(' a papyrus roll')).to eq(['papyrus.roll'])
      warning = Lich::Messaging.messages.find { |m| m[:message].include?('custom_scroll_substitutions[0] skipped') }
      expect(warning).not_to be_nil
      expect(warning[:message]).to include('expected a [from, to] pair')
    end

    it 'falls back to defaults when the settings value is not a list' do
      allow(Lich::DragonRealms::CustomSubstitutions)
        .to receive(:get_settings)
        .and_return(OpenStruct.new(custom_scroll_substitutions: 'not-a-list'))
      expect(described_class.scroll_list_to_adj_and_noun(' an icy blue parchment')).to eq(['blue parchment'])
      expect(Lich::Messaging.messages.map { |m| m[:message] }.join)
        .to include('custom_scroll_substitutions ignored')
    end
  end

  describe '.text2num' do
    it('converts simple number word') { expect(described_class.text2num('five')).to eq(5) }
    it('converts compound number with space') { expect(described_class.text2num('twenty three')).to eq(23) }
    it('converts compound number with hyphen') { expect(described_class.text2num('twenty-three')).to eq(23) }
    it('converts hundred') { expect(described_class.text2num('five hundred')).to eq(500) }
    it('converts single "one"') { expect(described_class.text2num('one')).to eq(1) }

    it 'returns nil for unknown word and logs message' do
      expect(described_class.text2num('banana')).to be_nil
      expect(Lich::Messaging.messages.last[:message]).to include("Unknown number word 'banana'")
    end
  end

  describe '.fix_dr_bullshit' do
    it('returns two-word string unchanged') { expect(described_class.fix_dr_bullshit('steel sword')).to eq('steel sword') }
    it('collapses three-word string to first and last') { expect(described_class.fix_dr_bullshit('beautiful steel sword')).to eq('beautiful sword') }
    it('returns single-word string unchanged') { expect(described_class.fix_dr_bullshit('sword')).to eq('sword') }
    it('strips "and chain" from ball-and-chain with prefix words') { expect(described_class.fix_dr_bullshit('large iron ball and chain')).to eq('large ball') }
  end

  describe '.get_town_name' do
    it('returns canonical name for exact match') { expect(described_class.get_town_name('Crossing')).to eq('Crossing') }
    it('returns canonical name for partial match') { expect(described_class.get_town_name('Theren')).to eq('Therenborough') }
    it('returns nil for unknown town') { expect(described_class.get_town_name('FakeCity')).to be_nil }
    it('is case insensitive') { expect(described_class.get_town_name('crossing')).to eq('Crossing') }
    it('handles alternate name "haven" for Riverhaven') { expect(described_class.get_town_name('haven')).to eq('Riverhaven') }
  end

  describe '.parse_assess_teach_lines' do
    it('parses single teacher') { expect(described_class.parse_assess_teach_lines(['Foo is teaching a class on Sorcery which is still open to new students'])).to eq({ 'Foo' => 'Sorcery' }) }
    it('returns empty hash for empty lines') { expect(described_class.parse_assess_teach_lines([])).to eq({}) }
    it('ignores non-matching lines') { expect(described_class.parse_assess_teach_lines(['Some random text'])).to eq({}) }

    it 'parses multiple teachers' do
      lines = [
        'Foo is teaching a class on Sorcery which is still open to new students',
        'Bar is teaching a class on Scholarship which is still open to new students'
      ]
      expect(described_class.parse_assess_teach_lines(lines)).to eq({ 'Foo' => 'Sorcery', 'Bar' => 'Scholarship' })
    end

    it 'filters difficulty text from skill name' do
      lines = ['Foo is teaching a class on easy (compared to what you already know) First Aid which is still open to new students']
      expect(described_class.parse_assess_teach_lines(lines)).to eq({ 'Foo' => 'First Aid' })
    end
  end

  describe Lich::DragonRealms::DRC::Item do
    describe '#initialize' do
      it 'sets default values' do
        item = described_class.new(name: 'sword')
        expect(item.name).to eq('sword')
        expect(item.worn).to be false
        expect(item.lodges).to be true
        expect(item.swappable).to be false
        expect(item.bound).to be false
        expect(item.wield).to be false
        expect(item.skip_repair).to be false
      end

      it('auto-detects ranged for "bow"') { expect(described_class.new(name: 'bow').ranged).to be true }
      it('auto-detects ranged for "crossbow"') { expect(described_class.new(name: 'crossbow').ranged).to be true }
      it('defaults needs_unloading to true when ranged') { expect(described_class.new(name: 'bow').needs_unloading).to be true }
      it('defaults needs_unloading to false when not ranged') { expect(described_class.new(name: 'sword').needs_unloading).to be false }
      it('allows explicit ranged override') { expect(described_class.new(name: 'sword', ranged: true).ranged).to be true }
      it('sets ranged false for non-ranged weapon') { expect(described_class.new(name: 'sword').ranged).to be false }
      it('handles nil name without error') { expect(described_class.new(name: nil).ranged).to be false }

      it 'allows explicit needs_unloading override' do
        item = described_class.new(name: 'bow', needs_unloading: false)
        expect(item.ranged).to be true
        expect(item.needs_unloading).to be false
      end
    end

    describe '#short_name' do
      it('returns adjective.name when adjective is present') { expect(described_class.new(name: 'sword', adjective: 'steel').short_name).to eq('steel.sword') }
      it('returns name alone when no adjective') { expect(described_class.new(name: 'sword').short_name).to eq('sword') }
    end

    describe '#short_regex' do
      it('matches adjective and name as separate words') { expect('a steel sword').to match(described_class.new(name: 'sword', adjective: 'steel').short_regex) }
      it('matches adjective with intervening text') { expect('a steel bastard sword').to match(described_class.new(name: 'sword', adjective: 'steel').short_regex) }
      it('matches name alone when no adjective') { expect('a sword').to match(described_class.new(name: 'sword').short_regex) }
      it('is case insensitive') { expect('a Steel Sword').to match(described_class.new(name: 'sword', adjective: 'steel').short_regex) }
    end

    describe '#ranged_weapon?' do
      let(:item) { described_class.new(name: 'test') }
      it('returns true for "bow"') { expect(item.ranged_weapon?('bow')).to be true }
      it('returns true for "crossbow"') { expect(item.ranged_weapon?('crossbow')).to be true }
      it('returns true for "sling"') { expect(item.ranged_weapon?('sling')).to be true }
      it('returns true for racial weapon "jranoki"') { expect(item.ranged_weapon?('jranoki')).to be true }
      it('returns false for "sword"') { expect(item.ranged_weapon?('sword')).to be false }
      it('returns false for nil') { expect(item.ranged_weapon?(nil)).to be false }
      it('is case insensitive') { expect(item.ranged_weapon?('BOW')).to be true }
    end

    describe '.from_text' do
      it('returns nil for nil input') { expect(described_class.from_text(nil)).to be_nil }
      it('returns nil for empty string') { expect(described_class.from_text('')).to be_nil }
      it('returns nil for whitespace-only string') { expect(described_class.from_text('   ')).to be_nil }

      it 'parses single word into Item with name only' do
        item = described_class.from_text('sword')
        expect(item.name).to eq('sword')
        expect(item.adjective).to be_nil
      end

      it 'parses two words into Item with adjective and name' do
        item = described_class.from_text('steel sword')
        expect(item.adjective).to eq('steel')
        expect(item.name).to eq('sword')
      end

      it 'parses dot notation into Item with adjective and name' do
        item = described_class.from_text('small.rucksack')
        expect(item.adjective).to eq('small')
        expect(item.name).to eq('rucksack')
      end

      it 'handles leading/trailing whitespace' do
        item = described_class.from_text('  steel sword  ')
        expect(item.adjective).to eq('steel')
        expect(item.name).to eq('sword')
      end
    end
  end

  describe '.check_encumbrance' do
    it('returns mapped value with refresh=true') { allow(described_class).to receive(:bput).and_return('Encumbrance : Light Burden'); expect(described_class.check_encumbrance(true)).to eq(1) }
    it('returns 0 for None encumbrance') { allow(described_class).to receive(:bput).and_return('Encumbrance : None'); expect(described_class.check_encumbrance(true)).to eq(0) }
    it('uses DRStats.encumbrance when refresh=false') { allow(DRStats).to receive(:encumbrance).and_return('Burdened'); expect(described_class.check_encumbrance(false)).to eq(3) }

    it 'falls back to DRStats when bput result does not match pattern' do
      allow(DRStats).to receive(:encumbrance).and_return('Heavy Burden')
      allow(described_class).to receive(:bput).and_return('something unexpected')
      expect(described_class.check_encumbrance(true)).to eq(4)
    end
  end

  describe '.listen?' do
    it('returns false for nil teacher') { expect(described_class.listen?(nil)).to be false }
    it('returns false for empty teacher') { expect(described_class.listen?('')).to be false }
    it('returns true for a good class') { allow(described_class).to receive(:bput).and_return('begin to listen to Foo teach the Scholarship skill'); expect(described_class.listen?('Foo')).to be true }
    it('returns true when already listening') { allow(described_class).to receive(:bput).and_return('already listening'); expect(described_class.listen?('Foo')).to be true }

    it 'returns false for Thievery class and stops listening' do
      n = 0
      allow(described_class).to receive(:bput) { |_c, *_p| (n += 1) == 1 ? 'begin to listen to Foo teach the Thievery skill' : 'You stop listening' }
      expect(described_class.listen?('Foo')).to be false
    end

    it 'returns false for Sorcery class and stops listening' do
      n = 0
      allow(described_class).to receive(:bput) { |_c, *_p| (n += 1) == 1 ? 'begin to listen to Foo teach the Sorcery skill' : 'You stop listening' }
      expect(described_class.listen?('Foo')).to be false
    end

    it 'returns false and stops listening for "but you don\'t see any harm"' do
      n = 0
      allow(described_class).to receive(:bput) { |_c, *_p| (n += 1) == 1 ? "but you don't see any harm in listening" : 'You stop listening' }
      expect(described_class.listen?('Foo')).to be false
    end

    it 'adds magic bad classes for barbarian' do
      allow(DRStats).to receive(:barbarian?).and_return(true)
      allow(DRStats).to receive(:thief?).and_return(false)
      n = 0
      allow(described_class).to receive(:bput) { |_c, *_p| (n += 1) == 1 ? 'begin to listen to Foo teach the Arcana skill' : 'You stop listening' }
      expect(described_class.listen?('Foo')).to be false
    end

    it 'passes "observe" with observe_flag' do
      allow(described_class).to receive(:bput) { |cmd, *_p| expect(cmd).to eq('listen to Foo observe'); 'already listening' }
      described_class.listen?('Foo', true)
    end
  end

  describe '.can_see_sky?' do
    it('returns false when indoor with no sky') { allow(described_class).to receive(:bput).and_return("That's a bit hard to do while inside."); expect(described_class.can_see_sky?).to be false }
    it('returns true when indoor with window') { allow(described_class).to receive(:bput).and_return('You glance outside'); expect(described_class.can_see_sky?).to be true }
    it('returns true when outdoor') { allow(described_class).to receive(:bput).and_return('You glance up at the sky'); expect(described_class.can_see_sky?).to be true }
  end

  describe '.retreat' do
    it('returns nil when no NPCs present') { allow(DRRoom).to receive(:npcs).and_return([]); expect(described_class.retreat).to be_nil }
    it('filters out ignored NPCs') { allow(DRRoom).to receive(:npcs).and_return(%w[goblin companion]); expect(described_class.retreat(%w[goblin companion])).to be_nil }

    it 'returns true on escape message' do
      allow(DRRoom).to receive(:npcs).and_return(['goblin'])
      allow(described_class).to receive(:bput).and_return('You retreat from combat')
      expect(described_class.retreat).to be true
    end
  end

  describe '.set_stance' do
    before do
      allow(described_class).to receive(:bput).and_return('Setting your')
    end

    context 'guild divisors' do
      it('uses divisor 50 for Paladin') do
        allow(DRStats).to receive(:guild).and_return('Paladin')
        allow(DRSkill).to receive(:getrank).and_return(500)
        described_class.set_stance('evasion')
        expect(described_class).to have_received(:bput).with('stance set 100 90 0', /Setting your/)
      end

      it('uses divisor 60 for Barbarian') do
        allow(DRStats).to receive(:guild).and_return('Barbarian')
        allow(DRSkill).to receive(:getrank).and_return(600)
        described_class.set_stance('evasion')
        expect(described_class).to have_received(:bput).with('stance set 100 90 0', /Setting your/)
      end

      it('uses divisor 60 for Ranger') do
        allow(DRStats).to receive(:guild).and_return('Ranger')
        allow(DRSkill).to receive(:getrank).and_return(1750)
        described_class.set_stance('evasion')
        expect(described_class).to have_received(:bput).with('stance set 100 100 9', /Setting your/)
      end

      it('uses divisor 60 for Trader') do
        allow(DRStats).to receive(:guild).and_return('Trader')
        allow(DRSkill).to receive(:getrank).and_return(600)
        described_class.set_stance('evasion')
        expect(described_class).to have_received(:bput).with('stance set 100 90 0', /Setting your/)
      end

      it('uses divisor 60 for Commoner') do
        allow(DRStats).to receive(:guild).and_return('Commoner')
        allow(DRSkill).to receive(:getrank).and_return(600)
        described_class.set_stance('evasion')
        expect(described_class).to have_received(:bput).with('stance set 100 90 0', /Setting your/)
      end

      it('uses divisor 70 for other guilds') do
        allow(DRStats).to receive(:guild).and_return('Warrior Mage')
        allow(DRSkill).to receive(:getrank).and_return(700)
        described_class.set_stance('evasion')
        expect(described_class).to have_received(:bput).with('stance set 100 90 0', /Setting your/)
      end
    end

    context 'skill priority placement (STANCE SET <evasion> <parry> <shield>)' do
      before do
        allow(DRStats).to receive(:guild).and_return('Warrior Mage')
        allow(DRSkill).to receive(:getrank).and_return(700)
      end

      it 'places 100 in evasion slot for evasion' do
        described_class.set_stance('evasion')
        expect(described_class).to have_received(:bput).with('stance set 100 90 0', /Setting your/)
      end

      it 'places 100 in parry slot for parry' do
        described_class.set_stance('parry')
        expect(described_class).to have_received(:bput).with('stance set 90 100 0', /Setting your/)
      end

      it 'places 100 in shield slot for shield' do
        described_class.set_stance('shield')
        expect(described_class).to have_received(:bput).with('stance set 90 0 100', /Setting your/)
      end

      it 'defaults to evasion for unknown skill' do
        described_class.set_stance('stealth')
        expect(described_class).to have_received(:bput).with('stance set 100 90 0', /Setting your/)
      end
    end

    context 'secondary/tertiary overflow' do
      before do
        allow(DRStats).to receive(:guild).and_return('Warrior Mage')
      end

      it 'caps secondary at 100 and puts overflow into tertiary' do
        allow(DRSkill).to receive(:getrank).and_return(2100)
        described_class.set_stance('evasion')
        expect(described_class).to have_received(:bput).with('stance set 100 100 10', /Setting your/)
      end

      it 'distributes overflow correctly for parry priority' do
        allow(DRSkill).to receive(:getrank).and_return(2100)
        described_class.set_stance('parry')
        expect(described_class).to have_received(:bput).with('stance set 100 100 10', /Setting your/)
      end

      it 'distributes overflow correctly for shield priority' do
        allow(DRSkill).to receive(:getrank).and_return(2100)
        described_class.set_stance('shield')
        expect(described_class).to have_received(:bput).with('stance set 100 10 100', /Setting your/)
      end
    end

    context 'edge cases' do
      before do
        allow(DRStats).to receive(:guild).and_return('Empath')
      end

      it 'handles zero Defending rank' do
        allow(DRSkill).to receive(:getrank).and_return(0)
        described_class.set_stance('parry')
        expect(described_class).to have_received(:bput).with('stance set 80 100 0', /Setting your/)
      end

      it 'handles exact boundary where points equal 100' do
        allow(DRSkill).to receive(:getrank).and_return(1400)
        described_class.set_stance('shield')
        expect(described_class).to have_received(:bput).with('stance set 100 0 100', /Setting your/)
      end

      it 'is case-insensitive for skill name' do
        allow(DRSkill).to receive(:getrank).and_return(700)
        described_class.set_stance('PARRY')
        expect(described_class).to have_received(:bput).with('stance set 90 100 0', /Setting your/)
      end

      it 'handles mixed case skill name' do
        allow(DRSkill).to receive(:getrank).and_return(700)
        described_class.set_stance('Shield')
        expect(described_class).to have_received(:bput).with('stance set 90 0 100', /Setting your/)
      end

      it 'handles very high Defending rank' do
        allow(DRSkill).to receive(:getrank).and_return(5000)
        described_class.set_stance('evasion')
        expect(described_class).to have_received(:bput).with('stance set 100 100 51', /Setting your/)
      end
    end

    context 'verified in-game values' do
      it 'Ranger 1750 Defending, evasion priority' do
        allow(DRStats).to receive(:guild).and_return('Ranger')
        allow(DRSkill).to receive(:getrank).and_return(1750)
        described_class.set_stance('evasion')
        expect(described_class).to have_received(:bput).with('stance set 100 100 9', /Setting your/)
      end

      it 'Moon Mage 1750 Defending, parry priority' do
        allow(DRStats).to receive(:guild).and_return('Moon Mage')
        allow(DRSkill).to receive(:getrank).and_return(1750)
        described_class.set_stance('parry')
        expect(described_class).to have_received(:bput).with('stance set 100 100 5', /Setting your/)
      end

      it 'Empath 1527 Defending, shield priority' do
        allow(DRStats).to receive(:guild).and_return('Empath')
        allow(DRSkill).to receive(:getrank).and_return(1527)
        described_class.set_stance('shield')
        expect(described_class).to have_received(:bput).with('stance set 100 1 100', /Setting your/)
      end
    end
  end

  describe '.capture_reply' do
    it 'asks issue_command for the end line, quietly, with the given stream and timeout' do
      allow(Lich::Util).to receive(:issue_command).and_return([])
      described_class.capture_reply('commune sense', /benevolent/, /Roundtime/, usexml: false, timeout: 7)
      expect(Lich::Util).to have_received(:issue_command).with(
        'commune sense', /benevolent/, /Roundtime/,
        usexml: false, quiet: true, include_end: true, timeout: 7
      )
    end

    it 'defaults the timeout to 5 seconds' do
      allow(Lich::Util).to receive(:issue_command).and_return([])
      described_class.capture_reply('assess teach', /teaching/, /Roundtime/, usexml: false)
      expect(Lich::Util).to have_received(:issue_command).with(anything, anything, anything, hash_including(timeout: 5))
    end

    it 'requires usexml to be given' do
      expect { described_class.capture_reply('assess teach', /teaching/, /Roundtime/) }.to raise_error(ArgumentError, /usexml/)
    end

    it 'drops the end line and reports complete when the reply ends on it' do
      allow(Lich::Util).to receive(:issue_command).and_return(['Foo is teaching a class', 'Roundtime: 3 sec.'])
      expect(described_class.capture_reply('assess teach', /teaching/, /Roundtime/, usexml: false))
        .to eq([['Foo is teaching a class'], true])
    end

    it 'keeps every line and reports incomplete when the end line never arrived' do
      allow(Lich::Util).to receive(:issue_command).and_return(['Foo is teaching a class', 'Bar is teaching a class'])
      expect(described_class.capture_reply('assess teach', /teaching/, /Roundtime/, usexml: false))
        .to eq([['Foo is teaching a class', 'Bar is teaching a class'], false])
    end

    it 'returns [[], false] on a timeout before the start line ([])' do
      allow(Lich::Util).to receive(:issue_command).and_return([])
      expect(described_class.capture_reply('assess teach', /teaching/, /Roundtime/, usexml: false)).to eq([[], false])
    end

    it 'treats nil from issue_command the same as a timeout' do
      allow(Lich::Util).to receive(:issue_command).and_return(nil)
      expect(described_class.capture_reply('assess teach', /teaching/, /Roundtime/, usexml: false)).to eq([[], false])
    end

    it 'does not count a lone start line that matches the end pattern as complete' do
      allow(Lich::Util).to receive(:issue_command).and_return(['Roundtime teaching'])
      expect(described_class.capture_reply('assess teach', /teaching/, /Roundtime/, usexml: false))
        .to eq([['Roundtime teaching'], false])
    end

    it 'judges completeness against the end pattern it was given, not the prompt' do
      prompt = '<prompt time="1700000000">&gt;</prompt>'
      allow(Lich::Util).to receive(:issue_command).and_return(['Foo is teaching a class', prompt])
      expect(described_class.capture_reply('assess teach', /teaching/, /Roundtime/, usexml: false))
        .to eq([['Foo is teaching a class', prompt], false])
    end
  end

  describe '.capture_to_prompt' do
    let(:prompt) { '<prompt time="1700000000">&gt;</prompt>' }

    it 'asks issue_command for the prompt line, quietly, over XML, with the given timeout' do
      allow(Lich::Util).to receive(:issue_command).and_return([])
      described_class.capture_to_prompt('wealth', /^Wealth:/, timeout: 12)
      expect(Lich::Util).to have_received(:issue_command).with(
        'wealth', /^Wealth:/, /<prompt/,
        usexml: true, quiet: true, include_end: true, timeout: 12
      )
    end

    it 'defaults the timeout to 5 seconds' do
      allow(Lich::Util).to receive(:issue_command).and_return([])
      described_class.capture_to_prompt('health', /^Your body feels/)
      expect(Lich::Util).to have_received(:issue_command).with(anything, anything, anything, hash_including(timeout: 5))
    end

    it 'drops the prompt line and reports complete when the reply ends on the prompt' do
      allow(Lich::Util).to receive(:issue_command).and_return(['Wealth:', '  5 copper Kronars.', prompt])
      expect(described_class.capture_to_prompt('wealth', /^Wealth:/)).to eq([['Wealth:', '  5 copper Kronars.'], true])
    end

    it 'returns [[], false] on a timeout before the start line ([])' do
      allow(Lich::Util).to receive(:issue_command).and_return([])
      expect(described_class.capture_to_prompt('wealth', /^Wealth:/)).to eq([[], false])
    end

    it 'treats nil from issue_command the same as a timeout' do
      allow(Lich::Util).to receive(:issue_command).and_return(nil)
      expect(described_class.capture_to_prompt('wealth', /^Wealth:/)).to eq([[], false])
    end

    it 'keeps every line and reports incomplete when the prompt never arrived' do
      allow(Lich::Util).to receive(:issue_command).and_return(['Wealth:', '  5 copper Kronars.'])
      expect(described_class.capture_to_prompt('wealth', /^Wealth:/)).to eq([['Wealth:', '  5 copper Kronars.'], false])
    end

    it 'does not count a lone prompt line as a complete reply' do
      allow(Lich::Util).to receive(:issue_command).and_return([prompt])
      expect(described_class.capture_to_prompt('wealth', /^Wealth:/)).to eq([[prompt], false])
    end

    it 'does not mutate the array issue_command returned' do
      raw = ['Wealth:', prompt].freeze
      allow(Lich::Util).to receive(:issue_command).and_return(raw)
      expect { described_class.capture_to_prompt('wealth', /^Wealth:/) }.not_to raise_error
      expect(raw).to eq(['Wealth:', prompt])
    end
  end

  describe '.assess_teach' do
    # Lich::Util.issue_command returns [] on a timeout; it never returns nil.
    it('returns empty hash on timeout') { allow(Lich::Util).to receive(:issue_command).and_return([]); expect(described_class.assess_teach).to eq({}) }

    it 'prints a timeout message when issue_command returns []' do
      allow(Lich::Util).to receive(:issue_command).and_return([])
      expect(Lich::Messaging).to receive(:msg).with('bold', 'DRC: Failed to capture ASSESS TEACH output (timeout).')
      described_class.assess_teach
    end

    it 'treats nil from issue_command the same as a timeout' do
      allow(Lich::Util).to receive(:issue_command).and_return(nil)
      expect(Lich::Messaging).to receive(:msg).with('bold', /DRC: Failed to capture ASSESS TEACH output/)
      expect(described_class.assess_teach).to eq({})
    end

    it 'prints no timeout message when no one is teaching' do
      allow(Lich::Util).to receive(:issue_command).and_return(['No one seems to be teaching'])
      expect(Lich::Messaging).not_to receive(:msg)
      described_class.assess_teach
    end
    it('returns empty hash when no one is teaching') { allow(Lich::Util).to receive(:issue_command).and_return(['No one seems to be teaching']); expect(described_class.assess_teach).to eq({}) }
    it('returns empty hash when "You are teaching"') { allow(Lich::Util).to receive(:issue_command).and_return(['You are teaching a class']); expect(described_class.assess_teach).to eq({}) }

    it 'returns parsed hash when teachers found' do
      allow(Lich::Util).to receive(:issue_command).and_return([
                                                                'Foo is teaching a class on Sorcery which is still open to new students',
                                                                'Bar is teaching a class on Scholarship which is still open to new students',
                                                                'Roundtime: 2 sec.'
                                                              ])
      expect(described_class.assess_teach).to eq({ 'Foo' => 'Sorcery', 'Bar' => 'Scholarship' })
    end

    it 'asks issue_command for the Roundtime line so a cut-off reply can be told apart' do
      allow(Lich::Util).to receive(:issue_command).and_return([])
      described_class.assess_teach
      expect(Lich::Util).to have_received(:issue_command).with(
        'assess teach', anything, /Roundtime/,
        usexml: false, quiet: true, include_end: true, timeout: 5
      )
    end

    it 'prints no message on a complete reply' do
      allow(Lich::Util).to receive(:issue_command).and_return([
                                                                'Foo is teaching a class on Sorcery which is still open to new students',
                                                                'Roundtime: 2 sec.'
                                                              ])
      expect(Lich::Messaging).not_to receive(:msg)
      described_class.assess_teach
    end

    context 'when the reply is cut off before its Roundtime line' do
      before do
        allow(Lich::Util).to receive(:issue_command).and_return([
                                                                  'Foo is teaching a class on Sorcery which is still open to new students'
                                                                ])
      end

      it 'prints a cut-off message' do
        expect(Lich::Messaging).to receive(:msg).with('bold', 'DRC: ASSESS TEACH output was cut off (timeout); the result is incomplete.')
        described_class.assess_teach
      end

      it 'returns the classes that did arrive' do
        allow(Lich::Messaging).to receive(:msg)
        expect(described_class.assess_teach).to eq({ 'Foo' => 'Sorcery' })
      end
    end

    it 'prints no cut-off message for a "no one is teaching" reply without a Roundtime line' do
      allow(Lich::Util).to receive(:issue_command).and_return(['No one seems to be teaching.'])
      expect(Lich::Messaging).not_to receive(:msg)
      expect(described_class.assess_teach).to eq({})
    end
  end

  describe '.message' do
    it('delegates bold message') { described_class.message('test', true); expect(Lich::Messaging.messages.last).to eq({ type: 'bold', message: 'test' }) }
    it('delegates plain message') { described_class.message('test', false); expect(Lich::Messaging.messages.last).to eq({ type: 'plain', message: 'test' }) }
  end

  describe '.verify_script' do
    it('returns true when script exists') { allow(Script).to receive(:exists?).and_return(true); expect(described_class.verify_script('test')).to be true }
    it('returns false when script missing') { allow(Script).to receive(:exists?).and_return(false); expect(described_class.verify_script('missing')).to be false }
    it('accepts array of script names') { allow(Script).to receive(:exists?).and_return(true); expect(described_class.verify_script(%w[foo bar])).to be true }
    it('returns false if any script missing') { allow(Script).to receive(:exists?).with('foo').and_return(true); allow(Script).to receive(:exists?).with('bar').and_return(false); expect(described_class.verify_script(%w[foo bar])).to be false }
  end

  describe '.left_hand' do
    it 'returns nil when empty' do
      allow(GameObj).to receive(:left_hand).and_return(DRC_MOCK_GAME_OBJ.new(name: 'Empty'))
      expect(described_class.left_hand).to be_nil
    end

    it 'returns item name when holding something' do
      allow(GameObj).to receive(:left_hand).and_return(DRC_MOCK_GAME_OBJ.new(name: 'steel sword'))
      expect(described_class.left_hand).to eq('steel sword')
    end
  end

  describe '.right_hand' do
    it 'returns nil when empty' do
      allow(GameObj).to receive(:right_hand).and_return(DRC_MOCK_GAME_OBJ.new(name: 'Empty'))
      expect(described_class.right_hand).to be_nil
    end

    it 'returns item name when holding something' do
      allow(GameObj).to receive(:right_hand).and_return(DRC_MOCK_GAME_OBJ.new(name: 'steel sword'))
      expect(described_class.right_hand).to eq('steel sword')
    end
  end

  describe '.bold' do
    it 'wraps text in pushBold/popBold tags' do
      result = described_class.bold('hello')
      expect(result).to include('<pushBold/>').and include('hello').and include('<popBold/>')
    end
  end

  describe '.kick_pile?' do
    it('returns nil when no pile in room') { allow(DRRoom).to receive(:room_objs).and_return([]); expect(described_class.kick_pile?).to be_nil }
    it('returns true when kick succeeds') { allow(DRRoom).to receive(:room_objs).and_return(['pile']); allow(described_class).to receive(:bput).and_return('take a step back and run up to'); expect(described_class.kick_pile?).to be true }
    it('returns false when pile not found') { allow(DRRoom).to receive(:room_objs).and_return(['pile']); allow(described_class).to receive(:bput).and_return('I could not find'); expect(described_class.kick_pile?).to be false }
  end

  describe '.bput' do
    before do
      allow(described_class).to receive(:waitrt?)
      allow(described_class).to receive(:clear)
      allow(described_class).to receive(:put)
      allow(described_class).to receive(:pause)
    end

    it 'returns matching string when response matches' do
      allow(described_class).to receive(:get?).and_return('You swing your sword')
      expect(described_class.bput('swing sword', 'You swing your sword')).to eq('You swing your sword')
    end

    it 'returns empty string on timeout with no match and logs messages' do
      allow(described_class).to receive(:get?).and_return(nil)
      expect(described_class.bput('test', { 'timeout' => 0.1 }, 'no match')).to eq('')
      expect(Lich::Messaging.messages.any? { |m| m[:message].include?("No match was found") }).to be true
    end

    it 'suppresses no-match message when suppress_no_match is set' do
      allow(described_class).to receive(:get?).and_return(nil)
      described_class.bput('test', { 'timeout' => 0.1, 'suppress_no_match' => true }, 'no match')
      expect(Lich::Messaging.messages).to be_empty
    end

    it 'converts string patterns to case-insensitive regex' do
      allow(described_class).to receive(:get?).and_return('you swing your SWORD')
      expect(described_class.bput('swing sword', 'You swing your sword')).to eq('you swing your SWORD')
    end

    # A small model of the game stream: each send queues that send's replies,
    # and get? reads them back in order. clear empties the queue, as the real
    # clear empties the script's buffer.
    context 'roundtime (...wait) replies' do
      let(:buffer) { [] }
      let(:sent) { [] }

      def game(*replies_per_send)
        allow(described_class).to receive(:clear) { buffer.clear }
        allow(described_class).to receive(:put) do |message|
          sent << message
          buffer.concat(Array(replies_per_send[sent.size - 1]))
        end
        allow(described_class).to receive(:get?) { buffer.shift }
        # The real pause ends in Kernel.sleep, which raises on a negative interval.
        allow(described_class).to receive(:pause) do |seconds|
          raise ArgumentError, 'time interval must not be negative' if seconds.to_f.negative?

          sleep(0.001)
        end
      end

      it 'resends once after a real "...wait N seconds." refusal' do
        game(['...wait 1 seconds.'], ['You get a gem from inside your pouch.'])
        expect(described_class.bput('get my gem from my pouch', 'You get')).to eq('You get')
        expect(sent).to eq(['get my gem from my pouch'] * 2)
      end

      it 'resends once when a second wait line is already queued during the hold' do
        # Two refusals queued together: an earlier command's and this one's.
        game(['...wait 1 seconds.', '...wait 1 seconds.'], ['You get a gem from inside your pouch.'])
        expect(described_class.bput('get my gem from my pouch', 'You get')).to eq('You get')
        expect(sent).to eq(['get my gem from my pouch'] * 2)
      end

      it 'still resends when a broad pattern matches a line during the hold' do
        # The command was refused, so "Bob waves at you." can't be its reply.
        game(['...wait 1 seconds.', 'Bob waves at you.'], ['You get a gem from inside your pouch.'])
        described_class.bput('get my gem from my pouch', 'You', 'What were')
        expect(sent).to eq(['get my gem from my pouch'] * 2)
      end

      it 'resends once when two refusals and a broadly matching line are queued during the hold' do
        game(['...wait 1 seconds.', '...wait 1 seconds.', 'The goblin swings at you.'],
             ['You get a gem from inside your pouch.'])
        described_class.bput('get my gem from my pouch', 'You', 'What were')
        expect(sent).to eq(['get my gem from my pouch'] * 2)
      end

      it 'reads the lines held during the wait before the reply to the resend' do
        # The wait line answered another command and this one was accepted:
        # bput resends anyway, then returns the first reply, as before the hold.
        game(['...wait 1 seconds.', 'You get a gem from inside your pouch.'], ['What were you referring to?'])
        expect(described_class.bput('get my gem from my pouch', 'You get', 'What were')).to eq('You get')
        expect(sent).to eq(['get my gem from my pouch'] * 2)
      end

      it 'handles a line held during the wait like any other reply' do
        allow(described_class).to receive(:stand_before?).and_return(true)
        game(['...wait 1 seconds.', 'You must be standing to do that.'], ['You get a gem from inside your pouch.'])
        expect(described_class.bput('get my gem from my pouch', 'You get')).to eq('You get')
        expect(described_class).to have_received(:stand_before?).once
        # Resent once for the wait line, then once more after standing.
        expect(sent.size).to eq(3)
      end

      it 'lists the wait lines it skipped when reporting no match' do
        game(['...wait 1 seconds.', '...wait 2 seconds.'])
        expect(described_class.bput('get my gem from my pouch', { 'timeout' => 0 }, 'You get')).to eq('')
        expect(sent).to eq(['get my gem from my pouch'] * 2)
        reported = Lich::Messaging.messages.map { |m| m[:message] }.join("\n")
        expect(reported).to include('...wait 1 seconds.').and include('...wait 2 seconds.')
      end

      it 'resends again when the resend itself is refused' do
        game(['...wait 1 seconds.'], ['...wait 1 seconds.'], ['You get a gem from inside your pouch.'])
        expect(described_class.bput('get my gem from my pouch', 'You get')).to eq('You get')
        expect(sent).to eq(['get my gem from my pouch'] * 3)
      end

      it 'honors a wait line appended to the end of earlier text' do
        game(["Icy blue frost crackles up a jeol moradu's arms with the ferocity of a blizzard as he...wait 1 seconds."],
             ['You drop a gem.'])
        expect(described_class.bput('drop my gem', 'You drop')).to eq('You drop')
        expect(sent).to eq(['drop my gem'] * 2)
      end

      it "ignores another player's speech that mentions a wait" do
        game(['Bob says, "Wait 3600."', 'You drop a gem.'])
        expect(described_class).not_to receive(:pause).with(3599.5)
        expect(described_class.bput('drop my gem', 'You drop')).to eq('You drop')
        expect(sent).to eq(['drop my gem'])
      end

      it 'does not crash on speech saying "Wait 0"' do
        game(['Bob whispers, "Wait 0"', 'You drop a gem.'])
        expect { described_class.bput('drop my gem', 'You drop') }.not_to raise_error
        expect(sent).to eq(['drop my gem'])
      end
    end

    # The same model of the game stream, answering by command. get? raises
    # when no reply has arrived for a second, so a reply bput skips fails
    # the example at once instead of waiting out the 15 s timeout.
    context "the immobile reply (\"You don't seem to be able to move to do that.\")" do
      let(:immobile) { "You don't seem to be able to move to do that." }
      let(:buffer) { [] }
      let(:sent) { [] }

      def game(replies)
        last_reply = Time.now
        allow(described_class).to receive(:clear) { buffer.clear }
        allow(described_class).to receive(:put) do |message|
          sent << message
          raise "#{message.inspect} sent #{sent.count(message)} times" if sent.count(message) > 5

          reply = replies[message]
          buffer.concat(Array(reply.respond_to?(:call) ? reply.call : reply))
          last_reply = Time.now
        end
        allow(described_class).to receive(:get?) do
          raise 'bput skipped the reply and waited for another' if buffer.empty? && Time.now - last_reply > 1

          buffer.shift
        end
        allow(described_class).to receive(:pause) { sleep(0.001) }
      end

      it 'returns it when a String pattern lists it' do
        game('get my gem' => immobile)
        expect(described_class.bput('get my gem', 'You get', "You don't seem to be able to move to do that"))
          .to eq("You don't seem to be able to move to do that")
        expect(sent).to eq(['get my gem'])
      end

      it 'returns it when a Regexp pattern lists it' do
        game('get my gem' => immobile)
        expect(described_class.bput('get my gem', /^You get/, /^You don't seem to be able to move/))
          .to eq("You don't seem to be able to move")
        expect(sent).to eq(['get my gem'])
      end

      it "returns it to a broad 'You' pattern instead of waiting out the timeout" do
        game('invoke my orb' => immobile)
        expect(described_class.bput('invoke my orb', 'You')).to eq('You')
        expect(sent).to eq(['invoke my orb'])
      end

      it 'waits out the timeout without resending when no pattern lists it' do
        game('get my gem' => immobile)
        expect(described_class.bput('get my gem', { 'timeout' => 0.2 }, 'You get')).to eq('')
        expect(sent).to eq(['get my gem'])
        expect(Lich::Messaging.messages.map { |m| m[:message] }).to include("DRC: > #{immobile}")
      end

      it 'does not return a quoted copy in speech to an anchored pattern' do
        game('get my gem' => ["Bob says, \"#{immobile}\"", 'You get a gem from inside your pouch.'])
        expect(described_class.bput('get my gem', /^You get/, /^You don't seem to be able to move/)).to eq('You get')
      end

      it 'returns it when it was read during a roundtime hold' do
        game('get my gem' => -> { sent.size == 1 ? ['...wait 1 seconds.', immobile] : ['You get a gem.'] })
        expect(described_class.bput('get my gem', /^You get/, /^You don't seem to be able to move/))
          .to eq("You don't seem to be able to move")
        expect(sent).to eq(['get my gem'] * 2)
      end

      context 'when a command needs the character standing' do
        before { allow(described_class).to receive(:standing?).and_return(false) }

        it 'does not resend the command when standing fails for being overburdened' do
          game('get my gem' => 'You must be standing to do that.',
               'stand'      => 'You are overburdened and cannot manage to stand.')
          expect(described_class.bput('get my gem', { 'timeout' => 0.3 }, 'You get')).to eq('')
          expect(sent).to eq(['get my gem', 'stand'])
        end

        it 'resends the command once standing succeeds' do
          standing = false
          allow(described_class).to receive(:standing?) { standing }
          game('get my gem' => -> { standing ? ['You get a gem.'] : ['You must be standing to do that.'] },
               'stand'      => -> { standing = true; ['You stand back up.'] })
          expect(described_class.bput('get my gem', 'You get')).to eq('You get')
          expect(sent).to eq(['get my gem', 'stand', 'get my gem'])
        end
      end

      # The command draws a posture line and the STAND draws the immobile
      # reply until the hold ends. A virtual clock runs bput's 15 s timeout
      # and the 1 s pauses at once; every reply arrives 0.3 s after its send.
      context 'when a command needs the character standing and a hold refuses the STAND' do
        let(:log) { [] }
        let(:clock) { { now: 0.0 } }

        # posture_line_at delays the reply to the first send of the command,
        # a posture line that arrives late.
        def held_game(hold_for:, stand_refusal: immobile, posture_line_at: nil)
          standing = false
          queue = []
          allow(Time).to receive(:now) { Time.at(1_000_000 + clock[:now]) }
          allow(described_class).to receive(:pause) { |seconds = 1| clock[:now] += seconds.to_f }
          allow(described_class).to receive(:standing?) { standing }
          allow(described_class).to receive(:clear) { queue.reject! { |at, _| at <= clock[:now] } }
          allow(described_class).to receive(:get?) do
            index = queue.index { |at, _| at <= clock[:now] }
            index && queue.delete_at(index).last
          end
          allow(described_class).to receive(:put) do |message|
            log << [clock[:now], message]
            raise "#{log.size} sends" if log.size > 100

            at = clock[:now] + 0.3
            reply = if message == 'stand'
                      next queue << [at, stand_refusal] if at < hold_for

                      standing = true
                      'You stand back up.'
                    else
                      at = posture_line_at if posture_line_at && log.size == 1
                      standing ? 'You get a gem.' : 'You must be standing to do that.'
                    end
            queue << [at, reply]
          end
        end

        def sent_at(message) = log.select { |_, m| m == message }.map(&:first)

        it 'keeps trying to stand and resends the command when the hold ends within the timeout' do
          held_game(hold_for: 5)
          expect(described_class.bput('get my gem', 'You get')).to eq('You get')
          expect(log.map(&:last).uniq).to eq(['get my gem', 'stand', 'get my gem'].uniq)
          expect(log.first.last).to eq('get my gem')
          expect(log.last.last).to eq('get my gem')
          expect(sent_at('get my gem').size).to eq(2)
          expect(sent_at('stand').size).to be_between(4, 6)
          expect(clock[:now]).to be < 7
        end

        it 'still resends when the hold ends 2 s before the timeout' do
          held_game(hold_for: 13)
          expect(described_class.bput('get my gem', 'You get')).to eq('You get')
          expect(sent_at('get my gem').size).to eq(2)
        end

        # The posture line comes 1.1 s before the timeout and the hold ends
        # 0.5 s after it, so the next STAND has to go out at the deadline.
        [[13.9, 14.4], [14.2, 14.7]].each do |posture_at, hold_end|
          it "resends when a late posture line (#{posture_at} s) leaves under 1 s of a hold that ends at #{hold_end} s" do
            held_game(hold_for: hold_end, posture_line_at: posture_at)
            expect(described_class.bput('get my gem', 'You get')).to eq('You get')
            expect(sent_at('get my gem').size).to eq(2)
            expect(sent_at('stand').size).to eq(2)
            expect(sent_at('stand').last).to be_within(0.001).of(15)
          end
        end

        it 'sends no STAND after the deadline when a late posture line comes as the timeout runs out' do
          held_game(hold_for: 1_000, posture_line_at: 14.8)
          expect(described_class.bput('get my gem', 'You get')).to eq('')
          expect(sent_at('stand').size).to eq(1)
          expect(sent_at('get my gem').size).to eq(1)
        end

        it 'tries about once a second until the timeout, then gives up without resending' do
          held_game(hold_for: 1_000)
          expect(described_class.bput('get my gem', 'You get')).to eq('')
          stands = sent_at('stand')
          expect(sent_at('get my gem').size).to eq(1)
          expect(stands.size).to be_between(10, 16)
          # Only the last STAND, sent at the deadline, may come sooner.
          expect(stands[0..-2].each_cons(2).map { |a, b| b - a }.min).to be >= 1
          expect(stands.last).to be <= 15
          expect(clock[:now]).to be < 17
          expect(Lich::Messaging.messages.map { |m| m[:message] }).to include(a_string_including('No match was found'))
        end

        it 'stands only once over the whole timeout when unconscious' do
          held_game(hold_for: 1_000, stand_refusal: "You're unconscious!")
          expect(described_class.bput('get my gem', 'You get')).to eq('')
          expect(sent_at('stand').size).to eq(1)
          expect(sent_at('get my gem').size).to eq(1)
        end
      end
    end
  end

  describe '.fix_standing' do
    it 'does nothing when already standing' do
      allow(described_class).to receive(:standing?).and_return(true)
      expect(described_class).not_to receive(:bput)
      described_class.fix_standing
    end

    it 'calls stand when not standing' do
      n = 0
      allow(described_class).to receive(:standing?) { (n += 1) > 1 }
      allow(described_class).to receive(:bput).and_return('You stand')
      described_class.fix_standing
      expect(described_class).to have_received(:bput).at_least(:once)
    end

    # Issue #3668: these states are in the STAND match list but never make
    # standing? true, so the pre-fix loop spammed STAND forever. Each helper
    # here raises on a second STAND, turning an infinite loop into a failure
    # instead of a hang.
    shared_examples 'a non-recoverable posture' do |message|
      it "issues STAND exactly once then stops when the game says #{message.inspect}" do
        allow(described_class).to receive(:standing?).and_return(false)
        stand_attempts = 0
        allow(described_class).to receive(:bput) do |*_args|
          stand_attempts += 1
          raise "fix_standing looped: STAND spammed on #{message.inspect}" if stand_attempts > 1
          message
        end
        described_class.fix_standing
        expect(stand_attempts).to eq(1)
      end
    end

    include_examples 'a non-recoverable posture', "You're unconscious"
    include_examples 'a non-recoverable posture', "You're plummeting to your death"
    include_examples 'a non-recoverable posture', 'prevents you from standing'
    include_examples 'a non-recoverable posture', "You don't seem to be able to move to do that"
    include_examples 'a non-recoverable posture', 'You are overburdened and cannot'
    include_examples 'a non-recoverable posture', 'weight of all your possessions'
    include_examples 'a non-recoverable posture', "There's no room to do much of anything here"

    it 'keeps retrying on a recoverable state (unbalanced) until standing succeeds' do
      standing_checks = [false, false, true]
      allow(described_class).to receive(:standing?) { standing_checks.shift }
      stand_results = ['You are so unbalanced', 'You stand']
      allow(described_class).to receive(:bput) { stand_results.shift }
      described_class.fix_standing
      expect(described_class).to have_received(:bput).twice
    end

    it 'does not treat a plain "You stand" success as a non-recoverable state' do
      expect('You stand').not_to match(described_class::CANNOT_STAND_PATTERN)
    end

    # Through the real bput: only put, get?, clear and pause are stubbed.
    context 'through the real bput' do
      let(:sent) { [] }

      def stand_replies(*replies)
        buffer = []
        last_reply = Time.now
        allow(described_class).to receive(:waitrt?)
        allow(described_class).to receive(:clear) { buffer.clear }
        allow(described_class).to receive(:pause) { sleep(0.001) }
        allow(described_class).to receive(:put) do |message|
          sent << message
          raise 'fix_standing looped: STAND sent again' if sent.size > replies.size

          buffer << replies[sent.size - 1]
          last_reply = Time.now
        end
        allow(described_class).to receive(:get?) do
          raise 'bput skipped the reply to STAND' if buffer.empty? && Time.now - last_reply > 1

          buffer.shift
        end
      end

      it "stands once and returns false on \"You don't seem to be able to move to do that.\"" do
        allow(described_class).to receive(:standing?).and_return(false)
        stand_replies("You don't seem to be able to move to do that.")
        expect(described_class.fix_standing).to be false
        expect(sent).to eq(['stand'])
      end

      # A caller that loops on fix_standing with no delay of its own would
      # otherwise send STAND as fast as the game answers for the whole hold.
      it 'pauses 1 s before returning false on the immobile reply' do
        allow(described_class).to receive(:standing?).and_return(false)
        stand_replies("You don't seem to be able to move to do that.")
        expect(described_class.fix_standing).to be false
        expect(described_class).to have_received(:pause).with(1).once
      end

      it 'sends at most one STAND per 1 s pause to a caller that loops on it while held' do
        allow(described_class).to receive(:standing?).and_return(false)
        stand_replies(*["You don't seem to be able to move to do that."] * 5)
        5.times { described_class.fix_standing }
        expect(sent).to eq(['stand'] * 5)
        expect(described_class).to have_received(:pause).with(1).exactly(5).times
      end

      it 'returns false on another state that prevents standing' do
        allow(described_class).to receive(:standing?).and_return(false)
        stand_replies("You're unconscious!")
        expect(described_class.fix_standing).to be false
      end

      it 'does not pause on the other states that prevent standing' do
        allow(described_class).to receive(:standing?).and_return(false)
        stand_replies("You're unconscious!")
        described_class.fix_standing
        expect(described_class).not_to have_received(:pause).with(1)
      end

      it 'returns true once standing, after an unbalanced attempt' do
        standing = [false, false, true]
        allow(described_class).to receive(:standing?) { standing.shift }
        stand_replies('You are so unbalanced you cannot manage to stand.', 'You stand back up.')
        expect(described_class.fix_standing).to be true
        expect(sent).to eq(%w[stand stand])
      end

      it 'returns true without standing when already standing' do
        allow(described_class).to receive(:standing?).and_return(true)
        stand_replies
        expect(described_class.fix_standing).to be true
        expect(sent).to be_empty
      end
    end
  end

  describe '.stand_before?' do
    let(:deadline) { Time.at(1_000_000) }

    before { allow(described_class).to receive(:stand_result).and_return(:immobile) }

    # The deadline passes between the check and the pause. A pause of a
    # negative interval raises ArgumentError, as Kernel#sleep does.
    it 'gives up without a negative pause when the deadline passes during the check' do
      reads = [deadline - 1e-6, deadline + 1e-6]
      allow(Time).to receive(:now) { reads.shift || deadline + 1 }
      paused = []
      allow(described_class).to receive(:pause) do |seconds|
        raise ArgumentError, 'time interval must not be negative' if seconds.negative?

        paused << seconds
      end
      result = nil
      expect { result = described_class.stand_before?(deadline) }.not_to raise_error
      expect(paused).to all(be >= 0)
      expect(result).to be false
    end

    it 'gives up at once at the deadline, without a pause' do
      allow(Time).to receive(:now).and_return(deadline)
      allow(described_class).to receive(:pause)
      expect(described_class.stand_before?(deadline)).to be false
      expect(described_class).not_to have_received(:pause)
      expect(described_class).to have_received(:stand_result).once
    end

    it 'pauses only the time left when the deadline is under 1 s away' do
      now = deadline - 0.25
      allow(Time).to receive(:now) { now }
      allow(described_class).to receive(:pause) { |seconds| now += seconds }
      expect(described_class.stand_before?(deadline)).to be false
      expect(described_class).to have_received(:pause).once.with(be_within(1e-9).of(0.25))
      expect(described_class).to have_received(:stand_result).twice
    end
  end

  describe '.hide?' do
    it('returns true when already hiding') { allow(described_class).to receive(:hiding?).and_return(true); expect(described_class.hide?).to be true }

    it 'attempts to hide and returns final hiding status' do
      n = 0
      allow(described_class).to receive(:hiding?) { (n += 1) > 1 }
      allow(described_class).to receive(:bput).and_return('Roundtime')
      allow(described_class).to receive(:pause)
      allow(described_class).to receive(:waitrt?)
      expect(described_class.hide?).to be true
    end

    it 'returns false when hide attempt fails' do
      allow(described_class).to receive(:hiding?).and_return(false)
      allow(described_class).to receive(:bput).and_return("can't see any place to hide yourself")
      allow(described_class).to receive(:pause)
      allow(described_class).to receive(:waitrt?)
      expect(described_class.hide?).to be false
    end
  end

  describe '.beep' do
    it('calls echo with bell character') { expect(described_class).to receive(:echo).with("\a"); described_class.beep }
  end

  describe '.stop_playing' do
    it 'sends stop play command' do
      allow(described_class).to receive(:bput).and_return('You stop playing your song')
      described_class.stop_playing
      expect(described_class).to have_received(:bput).with('stop play', 'You stop playing your song', 'In the name of', "But you're not performing")
    end
  end

  describe '.forage?' do
    before do
      allow(described_class).to receive(:waitrt?)
      allow(described_class).to receive(:right_hand).and_return(nil)
      allow(described_class).to receive(:left_hand).and_return(nil)
    end

    it 'returns true when forage succeeds (hands change)' do
      n = 0
      allow(described_class).to receive(:right_hand) { (n += 1) > 1 ? 'rock' : nil }
      allow(described_class).to receive(:bput).and_return('Roundtime')
      expect(described_class.forage?('rock')).to be true
    end

    it 'returns false after exhausting tries' do
      allow(described_class).to receive(:bput).and_return('Roundtime')
      expect(described_class.forage?('rock', 1)).to be false
    end

    it 'returns false when area is futile' do
      allow(described_class).to receive(:bput).and_return('You survey the area and realize that any foraging efforts would be futile')
      expect(described_class.forage?('rock')).to be false
    end

    it 'calls DRCI.stow_hand on hand-full message' do
      allow(described_class).to receive(:bput).and_return('You really need to have at least one hand free to forage properly')
      allow(DRCI).to receive(:stow_hand).and_return(false)
      expect(described_class.forage?('rock', 1)).to be false
      expect(DRCI).to have_received(:stow_hand).with('right')
    end

    it 'handles cluttered room with kick_pile?' do
      n = 0
      allow(described_class).to receive(:bput) { |_, *_| (n += 1) == 1 ? 'The room is too cluttered to find anything here' : 'Roundtime' }
      allow(described_class).to receive(:kick_pile?).and_return(false)
      expect(described_class.forage?('rock', 2)).to be false
    end
  end

  describe '.collect' do
    before do
      allow(described_class).to receive(:waitrt?)
    end

    it 'issues collect command with practice by default' do
      allow(described_class).to receive(:bput).and_return('You begin to forage around')
      described_class.collect('rock')
      expect(described_class).to have_received(:bput).with('collect rock practice', described_class::COLLECT_MESSAGES)
    end

    it 'issues collect without practice when false' do
      allow(described_class).to receive(:bput).and_return('You begin to forage around')
      described_class.collect('rock', false)
      expect(described_class).to have_received(:bput).with('collect rock', described_class::COLLECT_MESSAGES)
    end

    it 'sends no trailing whitespace when practice is nil' do
      allow(described_class).to receive(:bput).and_return('You begin to forage around')
      described_class.collect('rock', nil)
      expect(described_class).to have_received(:bput).with('collect rock', described_class::COLLECT_MESSAGES)
    end

    it 'waits out roundtime once on an uncluttered collect' do
      allow(described_class).to receive(:bput).and_return('You begin to forage around')
      described_class.collect('rock', false)
      expect(described_class).to have_received(:waitrt?).once
    end

    it 'calls kick_pile? when room is cluttered' do
      n = 0
      allow(described_class).to receive(:bput) { |_, *_| (n += 1) == 1 ? 'The room is too cluttered' : 'You begin' }
      allow(described_class).to receive(:kick_pile?).and_return(true)
      described_class.collect('rock')
      expect(described_class).to have_received(:kick_pile?)
    end

    context 'when the room is cluttered' do
      # Real kick_pile? runs; only bput, the room's objects, fix_standing and waitrt? are stubbed.
      # Each bput call pops the next scripted reply and records the command sent.
      let(:sent) { [] }

      def script_replies(*replies)
        allow(described_class).to receive(:fix_standing)
        allow(described_class).to receive(:bput) do |command, *_patterns|
          sent << command
          replies.shift || raise("unexpected extra bput: #{command.inspect}")
        end
      end

      context 'with a kickable pile in the room' do
        before { allow(DRRoom).to receive(:room_objs).and_return(['a pile of rocks']) }

        it 'retries without practice when practice is false' do
          script_replies('The room is too cluttered', 'take a step back and run up to', 'You begin to forage around,')
          described_class.collect('rock', false)
          expect(sent).to eq(['collect rock', 'kick pile', 'collect rock'])
          expect(described_class).to have_received(:waitrt?).once
        end

        it 'retries with practice by default' do
          script_replies('The room is too cluttered', 'take a step back and run up to', 'You begin to forage around,')
          described_class.collect('rock')
          expect(sent).to eq(['collect rock practice', 'kick pile', 'collect rock practice'])
          expect(described_class).to have_received(:waitrt?).once
        end

        it 'retries with practice when practice is explicitly true' do
          script_replies('The room is too cluttered', 'take a step back and run up to', 'You begin to forage around,')
          described_class.collect('rock', true)
          expect(sent).to eq(['collect rock practice', 'kick pile', 'collect rock practice'])
          expect(described_class).to have_received(:waitrt?).once
        end

        it 'keeps practice off across repeated cluttered retries' do
          script_replies('The room is too cluttered', 'take a step back and run up to',
                         'The room is too cluttered', 'take a step back and run up to',
                         'You begin to forage around,')
          described_class.collect('rock', false)
          expect(sent).to eq(['collect rock', 'kick pile', 'collect rock', 'kick pile', 'collect rock'])
          expect(described_class).to have_received(:waitrt?).once
        end

        it 'does not retry when the kick misses the pile' do
          script_replies('The room is too cluttered', 'I could not find')
          expect(described_class.collect('rock')).to be_nil
          expect(sent).to eq(['collect rock practice', 'kick pile'])
          expect(described_class).to have_received(:waitrt?).once
        end

        it 'waits out roundtime once when a later kick misses the pile' do
          script_replies('The room is too cluttered', 'take a step back and run up to',
                         'The room is too cluttered', 'I could not find')
          expect(described_class.collect('rock', false)).to be_nil
          expect(sent).to eq(['collect rock', 'kick pile', 'collect rock', 'kick pile'])
          expect(described_class).to have_received(:waitrt?).once
        end
      end

      context 'with no pile in the room' do
        before { allow(DRRoom).to receive(:room_objs).and_return(['a granite boulder']) }

        it 'gives up without kicking or retrying' do
          script_replies('The room is too cluttered')
          expect(described_class.collect('rock')).to be_nil
          expect(sent).to eq(['collect rock practice'])
          expect(described_class).to have_received(:waitrt?).once
        end
      end

      context 'when the room stays cluttered after every successful kick' do
        # Every collect is refused, a pile is always in the room and every kick lands.
        # The cap is the only thing that can stop it; the guard turns a runaway loop
        # into a plain failure instead of a SystemStackError.
        before do
          allow(DRRoom).to receive(:room_objs).and_return(['a pile of rocks'])
          allow(described_class).to receive(:fix_standing)
          allow(Lich::Messaging).to receive(:msg)
        end

        def endless_clutter(success_on_attempt: nil)
          attempts = 0
          allow(described_class).to receive(:bput) do |command, *_patterns|
            sent << command
            raise "runaway collect: #{sent.length} commands sent" if sent.length > 50

            if command.start_with?('kick')
              'take a step back and run up to'
            else
              attempts += 1
              attempts == success_on_attempt ? 'You begin to forage around,' : 'The room is too cluttered'
            end
          end
        end

        it 'gives up after the fifth refused collect without a fifth kick' do
          endless_clutter
          expect(described_class.collect('rock')).to be_nil
          expect(sent.count('collect rock practice')).to eq(5)
          expect(sent.count('kick pile')).to eq(4)
          expect(sent.last).to eq('collect rock practice')
          expect(described_class).to have_received(:waitrt?).once
        end

        it 'keeps the caller mode on every capped attempt' do
          endless_clutter
          described_class.collect('rock', false)
          expect(sent.uniq).to eq(['collect rock', 'kick pile'])
          expect(sent.length).to eq(9)
        end

        it 'says why it gave up' do
          endless_clutter
          described_class.collect('rock')
          expect(Lich::Messaging).to have_received(:msg)
            .with('bold', "DRC: Room still too cluttered to collect rock after 5 tries, giving up.").once
        end

        it 'still collects when the last allowed attempt goes through' do
          endless_clutter(success_on_attempt: 5)
          allow(described_class).to receive(:waitrt?).and_return(true)
          expect(described_class.collect('rock')).to be(true)
          expect(sent.count('kick pile')).to eq(4)
          expect(described_class).to have_received(:waitrt?).once
          expect(Lich::Messaging).not_to have_received(:msg)
        end

        it 'gives every call its own budget' do
          endless_clutter
          described_class.collect('rock')
          sent.clear
          described_class.collect('rock')
          expect(sent.count('collect rock practice')).to eq(5)
        end
      end

      context 'when the last pile is kicked just before the cap' do
        # Four piles, each destroyed by its kick, and every collect refused. The fifth
        # refusal hits the cap before kick_pile? would find the room empty, so the
        # give-up is the loud one.
        before do
          room_states = Array.new(4) { ['a pile of rocks'] }
          allow(DRRoom).to receive(:room_objs) { room_states.shift || [] }
          allow(Lich::Messaging).to receive(:msg)
        end

        it 'gives up at the cap with the message and without looking for a fifth pile' do
          script_replies(*(['The room is too cluttered', 'take a step back and run up to'] * 4), 'The room is too cluttered')
          expect(described_class.collect('rock')).to be_nil
          expect(sent.count('collect rock practice')).to eq(5)
          expect(sent.count('kick pile')).to eq(4)
          expect(DRRoom).to have_received(:room_objs).exactly(4).times
          expect(Lich::Messaging).to have_received(:msg)
            .with('bold', "DRC: Room still too cluttered to collect rock after 5 tries, giving up.").once
          expect(described_class).to have_received(:waitrt?).once
        end
      end

      context 'when it gives up before the cap' do
        # Only the cap prints a message; a missing pile or a missed kick stays silent.
        before { allow(Lich::Messaging).to receive(:msg) }

        it 'prints nothing when there is no pile to kick' do
          allow(DRRoom).to receive(:room_objs).and_return(['a granite boulder'])
          script_replies('The room is too cluttered')
          expect(described_class.collect('rock')).to be_nil
          expect(Lich::Messaging).not_to have_received(:msg)
        end

        it 'prints nothing when the kick misses' do
          allow(DRRoom).to receive(:room_objs).and_return(['a pile of rocks'])
          script_replies('The room is too cluttered', 'take a step back and run up to',
                         'The room is too cluttered', 'I could not find')
          expect(described_class.collect('rock')).to be_nil
          expect(Lich::Messaging).not_to have_received(:msg)
        end
      end

      context 'when the pile is gone on a later attempt' do
        before do
          room_states = [['a pile of rocks'], []]
          allow(DRRoom).to receive(:room_objs) { room_states.shift || [] }
        end

        it 'waits out the kick roundtime once when it gives up after the first kick succeeded' do
          script_replies('The room is too cluttered', 'take a step back and run up to',
                         'The room is too cluttered')
          expect(described_class.collect('rock', false)).to be_nil
          expect(sent).to eq(['collect rock', 'kick pile', 'collect rock'])
          expect(described_class).to have_received(:waitrt?).once
        end
      end
    end
  end

  describe '.rummage' do
    it 'returns empty array when container is closed' do
      allow(described_class).to receive(:bput).and_return("While it's closed")
      expect(described_class.rummage('G', 'backpack')).to eq([])
    end

    it 'returns empty array when nothing found' do
      allow(described_class).to receive(:bput).and_return('but there is nothing in there like that.')
      expect(described_class.rummage('G', 'backpack')).to eq([])
    end

    it 'returns empty array when container not found' do
      allow(described_class).to receive(:bput).and_return("I don't know what you are referring to")
      expect(described_class.rummage('G', 'backpack')).to eq([])
    end

    it 'retries after releasing invisibility on "You feel about"' do
      n = 0
      allow(described_class).to receive(:bput) { |_, *_| (n += 1) == 1 ? 'You feel about' : 'but there is nothing in there like that.' }
      allow(described_class).to receive(:release_invisibility)
      expect(described_class.rummage('G', 'backpack')).to eq([])
      expect(described_class).to have_received(:release_invisibility)
    end

    it 'parses box list with B parameter' do
      allow(described_class).to receive(:bput).and_return('looking for boxes and see a wooden strongbox.')
      expect(described_class.rummage('B', 'backpack')).to eq(['wooden strongbox'])
    end

    it 'parses scroll list with SC parameter' do
      allow(described_class).to receive(:bput).and_return('looking for scrolls and see a blue scroll.')
      expect(described_class.rummage('SC', 'backpack')).to eq(['blue scroll'])
    end

    it 'parses gem list to nouns' do
      allow(described_class).to receive(:bput).and_return('looking for gems and see a ruby and an emerald.')
      expect(described_class.rummage('G', 'backpack')).to eq(%w[ruby emerald])
    end

    # At runtime lich.rbw loads lib/common/class_exts/nilclass.rb, whose
    # NilClass#strip lets the parsers turn nil into [] anyway; this suite does
    # not load it. Asserting the parsers are never reached pins the guard
    # itself, so the result does not depend on which nil the process has.
    context 'when the reply has no parseable list' do
      before do
        allow(described_class).to receive(:list_to_array).and_call_original
        allow(described_class).to receive(:box_list_to_adj_and_noun).and_call_original
      end

      %w[G B SC].each do |parameter|
        it "returns empty array without parsing when bput times out with #{parameter} parameter" do
          allow(described_class).to receive(:bput).and_return('')
          expect(described_class.rummage(parameter, 'backpack')).to eq([])
          expect(described_class).not_to have_received(:list_to_array)
          expect(described_class).not_to have_received(:box_list_to_adj_and_noun)
        end
      end

      it 'returns empty array without parsing when the list line lacks its closing period' do
        allow(described_class).to receive(:bput).and_return('looking for gems and see a ruby')
        expect(described_class.rummage('G', 'backpack')).to eq([])
        expect(described_class).not_to have_received(:list_to_array)
      end

      it 'reports no response when bput times out' do
        allow(described_class).to receive(:bput).and_return('')
        described_class.rummage('G', 'backpack')
        expect(Lich::Messaging.messages.map { |m| m[:message] }.join)
          .to include("No response to 'rummage /G my backpack', treating container as empty.")
      end

      it 'reports an unrecognized response when a reply matched but could not be parsed' do
        allow(described_class).to receive(:bput).and_return('looking for gems and see a ruby')
        described_class.rummage('G', 'backpack')
        expect(Lich::Messaging.messages.map { |m| m[:message] }.join)
          .to include("Unrecognized response to 'rummage /G my backpack', treating container as empty.")
      end
    end
  end

  describe '.get_skins / .get_gems / .get_materials' do
    before { allow(described_class).to receive(:rummage).and_return([]) }

    it('.get_skins calls rummage with S') { described_class.get_skins('bag'); expect(described_class).to have_received(:rummage).with('S', 'bag') }
    it('.get_gems calls rummage with G') { described_class.get_gems('bag'); expect(described_class).to have_received(:rummage).with('G', 'bag') }
    it('.get_materials calls rummage with M') { described_class.get_materials('bag'); expect(described_class).to have_received(:rummage).with('M', 'bag') }
  end

  describe '.release_invisibility' do
    before do
      allow(described_class).to receive(:get_data).and_return(OpenStruct.new(spell_data: {}))
      allow(described_class).to receive(:fput)
      allow(described_class).to receive(:bput)
      allow(DRSpells).to receive(:active_spells).and_return({})
      allow(DRStats).to receive(:guild).and_return('Thief')
      allow(described_class).to receive(:invisible?).and_return(false)
    end

    it 'does nothing when no invisibility spells active' do
      described_class.release_invisibility
      expect(described_class).not_to have_received(:fput)
    end

    it 'releases active invisibility spells' do
      allow(described_class).to receive(:get_data).and_return(
        OpenStruct.new(spell_data: { 'Invisibility' => { 'invisibility' => true, 'abbrev' => 'invis' } })
      )
      allow(DRSpells).to receive(:active_spells).and_return({ 'Invisibility' => 300 })
      described_class.release_invisibility
      expect(described_class).to have_received(:fput).with('release invis')
    end

    it 'stops Khri Silence when active' do
      allow(DRSpells).to receive(:active_spells).and_return({ 'Khri Silence' => 300 })
      described_class.release_invisibility
      expect(described_class).to have_received(:bput).with('khri stop silence', 'You attempt to relax')
    end

    it 'stops Khri Vanish for invisible thief' do
      allow(described_class).to receive(:invisible?).and_return(true)
      described_class.release_invisibility
      expect(described_class).to have_received(:bput).with('khri stop vanish', /^You would need to start Vanish/, /^Your control over the limited subversion of reality falters/, /^You are not trained in the Vanish meditation/)
    end
  end

  describe '.wait_for_script_to_complete' do
    before do
      allow(described_class).to receive(:verify_script).and_return(true)
      allow(described_class).to receive(:start_script).and_return(nil)
      allow(described_class).to receive(:pause)
    end

    it 'verifies script exists' do
      described_class.wait_for_script_to_complete('test')
      expect(described_class).to have_received(:verify_script).with('test')
    end

    it 'starts script with quoted args containing spaces' do
      allow(Script).to receive(:running).and_return([])
      described_class.wait_for_script_to_complete('test', ['arg with space'])
      expect(described_class).to have_received(:start_script).with('test', ['"arg with space"'], {})
    end

    it 'waits for script to finish running' do
      mock_script = double('Script', name: 'test')
      n = 0
      allow(described_class).to receive(:start_script).and_return(mock_script)
      allow(Script).to receive(:running) { (n += 1) > 2 ? [] : [mock_script] }
      described_class.wait_for_script_to_complete('test')
      expect(described_class).to have_received(:pause).at_least(3).times
    end
  end

  describe '.pause_all / .unpause_all' do
    let(:mock_script) { Script.new.tap { |s| s.name = 'test'; s.paused = false; s.no_pause_all = false } }

    before do
      allow(Script).to receive(:current).and_return(nil)
      allow(Script).to receive(:running).and_return([mock_script])
      allow(mock_script).to receive(:pause)
      allow(mock_script).to receive(:unpause)
      allow(described_class).to receive(:pause)
    end

    describe '.pause_all' do
      after { $pause_all_lock.unlock if $pause_all_lock.owned? }

      it 'returns false if lock already held' do
        $pause_all_lock.lock
        expect(described_class.pause_all).to be false
      end

      it 'pauses running scripts' do
        expect(described_class.pause_all).to be true
        expect(mock_script).to have_received(:pause)
      end

      it 'skips scripts with no_pause_all set' do
        mock_script.no_pause_all = true
        described_class.pause_all
        expect(mock_script).not_to have_received(:pause)
      end
    end

    describe '.unpause_all' do
      it 'returns false if lock not owned' do
        expect(described_class.unpause_all).to be false
      end

      it 'unpauses paused scripts and releases lock' do
        described_class.pause_all
        mock_script.paused = true
        described_class.unpause_all
        expect(mock_script).to have_received(:unpause)
        expect($pause_all_lock.owned?).to be false
      end
    end
  end

  describe '.smart_pause_all' do
    let(:mock_script) { Script.new.tap { |s| s.name = 'other'; s.paused = false; s.no_pause_all = false } }

    before do
      allow(Script).to receive(:running).and_return([mock_script])
      allow(mock_script).to receive(:pause)
    end

    it 'pauses running scripts and returns their names' do
      result = described_class.smart_pause_all
      expect(result).to eq(['other'])
      expect(mock_script).to have_received(:pause)
    end

    it 'logs the paused scripts' do
      described_class.smart_pause_all
      expect(Lich::Messaging.messages.any? { |m| m[:message].include?('Pausing') }).to be true
    end
  end

  describe '.unpause_all_list' do
    let(:mock_script) { Script.new.tap { |s| s.name = 'other'; s.paused = true; s.no_pause_all = false } }

    before do
      allow(Script).to receive(:running).and_return([mock_script])
      allow(mock_script).to receive(:unpause)
    end

    it 'unpauses listed scripts' do
      described_class.unpause_all_list(['other'])
      expect(mock_script).to have_received(:unpause)
    end

    it 'does not unpause unlisted scripts' do
      described_class.unpause_all_list(['different'])
      expect(mock_script).not_to have_received(:unpause)
    end

    context 'when list is empty' do
      it 'logs simple completion message without unpausing' do
        Lich::Messaging.clear_messages!
        described_class.unpause_all_list([])
        expect(Lich::Messaging.messages.any? { |m| m[:message].include?('Unpausing') }).to be false
        expect(Lich::Messaging.messages.any? { |m| m[:message].include?('has finished') }).to be true
      end

      it 'does not attempt to unpause scripts' do
        described_class.unpause_all_list([])
        expect(mock_script).not_to have_received(:unpause)
      end
    end
  end

  describe '.safe_pause_list / .safe_unpause_list' do
    let(:mock_script) { Script.new.tap { |s| s.name = 'other'; s.paused = false; s.no_pause_all = false } }

    before do
      allow(Script).to receive(:running).and_return([mock_script])
      allow(mock_script).to receive(:pause)
      allow(mock_script).to receive(:unpause)
    end

    after { $safe_pause_lock.unlock if $safe_pause_lock.owned? }

    describe '.safe_pause_list' do
      it 'returns false if lock already held' do
        $safe_pause_lock.lock
        expect(described_class.safe_pause_list).to be false
      end

      it 'pauses scripts and returns the paused Script objects' do
        result = described_class.safe_pause_list
        expect(result).to eq([mock_script])
      end
    end

    describe '.safe_unpause_list' do
      it 'returns false if lock not owned' do
        expect(described_class.safe_unpause_list(['other'])).to be false
      end

      it 'unpauses scripts and releases lock' do
        paused = described_class.safe_pause_list
        mock_script.paused = true
        described_class.safe_unpause_list(paused)
        expect(mock_script).to have_received(:unpause)
        expect($safe_pause_lock.owned?).to be false
      end

      # Regression: safe_pause_list used to hand back script *names* and
      # safe_unpause_list re-derived the unpause set from a fresh
      # Script.running scan, matching by name. Any script that left
      # Script.running between pause and unpause (gone hidden, or mid
      # start/teardown) was silently dropped and stranded paused forever,
      # while the log still claimed it was unpaused. Capturing and restoring
      # the exact objects fixes this.
      it 'unpauses a paused script even after it leaves Script.running' do
        paused = described_class.safe_pause_list
        expect(paused).to eq([mock_script])
        mock_script.paused = true
        # The script goes hidden / deregisters: no longer visible to a live
        # Script.running rescan.
        allow(Script).to receive(:running).and_return([])
        described_class.safe_unpause_list(paused)
        expect(mock_script).to have_received(:unpause)
      end

      context 'when list is empty' do
        it 'logs simple completion message without unpausing' do
          described_class.safe_pause_list
          Lich::Messaging.clear_messages!
          described_class.safe_unpause_list([])
          expect(Lich::Messaging.messages.any? { |m| m[:message].include?('Unpausing') }).to be false
          expect(Lich::Messaging.messages.any? { |m| m[:message].include?('has finished') }).to be true
        end

        it 'still releases the lock' do
          described_class.safe_pause_list
          described_class.safe_unpause_list([])
          expect($safe_pause_lock.owned?).to be false
        end
      end
    end

    # Regression: a script that gets pause_script'd while holding
    # $safe_pause_lock is a live-but-suspended thread that keeps the mutex, so
    # every peer deadlocks on try_lock. The holder must be made immune to pause
    # (ignore_pause) for as long as it owns the lock, then restored.
    describe 'lock holder pause immunity' do
      let(:holder) { Script.new.tap { |s| s.name = 'holder'; s.ignore_pause = false } }

      before { allow(Script).to receive(:self).and_return(holder) }

      it 'makes the lock holder immune to pause while it holds the lock' do
        described_class.safe_pause_list
        expect(holder.ignore_pause).to be true
      end

      it 'restores the holder pause setting when the lock is released' do
        paused = described_class.safe_pause_list
        described_class.safe_unpause_list(paused)
        expect(holder.ignore_pause).to be false
      end

      it 'restores a pre-existing ignore_pause=true rather than clobbering it' do
        holder.ignore_pause = true
        described_class.safe_pause_list
        expect(holder.ignore_pause).to be true
        described_class.safe_unpause_list([])
        expect(holder.ignore_pause).to be true
      end

      it 'does not grant immunity when the lock cannot be acquired' do
        $safe_pause_lock.lock
        expect(described_class.safe_pause_list).to be false
        expect(holder.ignore_pause).to be false
      end
    end
  end

  describe '.log_window' do
    before { allow(described_class).to receive(:_respond) }

    it 'sends stream tags with window name' do
      described_class.log_window('test', 'mywindow')
      expect(described_class).to have_received(:_respond).with(
        /<pushStream id="mywindow"\/>/,
        /<popStream id="mywindow"/
      )
    end

    it 'creates window when create_window is true' do
      described_class.log_window('test', 'mywindow', true, true)
      expect(described_class).to have_received(:_respond).with(/<streamWindow id="mywindow"/)
    end

    it 'clears window when pre_clear_window is true' do
      described_class.log_window('test', 'mywindow', true, false, true)
      expect(described_class).to have_received(:_respond).with(/<clearStream id="mywindow"/)
    end
  end

  describe '.atmo' do
    it 'delegates to log_window with atmospherics' do
      allow(described_class).to receive(:log_window)
      described_class.atmo('test', true)
      expect(described_class).to have_received(:log_window).with('test', 'atmospherics', true)
    end
  end

  describe '.play_song?' do
    let(:settings) do
      OpenStruct.new(
        worn_instrument: 'lute',
        instrument: nil,
        cleaning_cloth: 'cloth'
      )
    end
    # Single-song list to avoid recursion
    let(:song_list) { { 'song1' => 'song1' } }

    before do
      # 'slightest hint of difficulty' returns true without recursion
      allow(described_class).to receive(:bput).and_return('slightest hint of difficulty')
      allow(described_class).to receive(:fput)
      allow(described_class).to receive(:waitrt?)
      allow(DRSpells).to receive(:active_spells).and_return({})
      allow(DRSkill).to receive(:getrank).and_return(100)
      UserVars.song = 'song1'
      UserVars.climbing_song = 'song1'
      UserVars.instrument = 'lute'
    end

    it 'returns true on successful play (slightest hint of difficulty)' do
      expect(described_class.play_song?(settings, song_list)).to be true
    end

    it 'releases Eillies Cry if active' do
      allow(DRSpells).to receive(:active_spells).and_return({ "Eillie's Cry" => 100 })
      described_class.play_song?(settings, song_list)
      expect(described_class).to have_received(:fput).with('release ecry')
    end

    it 'returns false on "now isn\'t the best time to be playing"' do
      allow(described_class).to receive(:bput).and_return("now isn't the best time to be playing")
      expect(described_class.play_song?(settings, song_list)).to be false
    end

    it 'uses DRCI.get_item? on missing instrument' do
      allow(described_class).to receive(:bput).and_return('Play on what instrument')
      allow(DRCI).to receive(:get_item?).and_return(false)
      expect(described_class.play_song?(settings, song_list)).to be false
      expect(DRCI).to have_received(:get_item?).with('lute')
    end

    it 'uses DRCI.wear_item? on worn instrument' do
      allow(described_class).to receive(:bput).and_return('Play on what instrument')
      allow(DRCI).to receive(:get_item?).and_return(true)
      allow(DRCI).to receive(:wear_item?).and_return(false)
      expect(described_class.play_song?(settings, song_list)).to be false
      expect(DRCI).to have_received(:wear_item?).with('lute')
    end

    # Avoid recursion-prone tests - focus on non-recursive paths

    context 'with a held performance instrument and a worn climbing instrument' do
      let(:settings) { OpenStruct.new(worn_instrument: 'zills', instrument: 'lute', cleaning_cloth: 'cloth') }
      let(:song_list) { { 'scales halt' => 'scales', 'scales' => 'scales', 'rondo' => 'rondo' } }

      before do
        UserVars.song = 'scales'
        UserVars.climbing_song = 'rondo'
        UserVars.instrument = 'lute'
      end

      it 'keeps both songs when alternating performance and climbing' do
        described_class.play_song?(settings, song_list, false)
        described_class.play_song?(settings, song_list, true, true, true)
        described_class.play_song?(settings, song_list, false)
        described_class.play_song?(settings, song_list, true, true, true)

        expect(UserVars.song).to eq('scales')
        expect(UserVars.climbing_song).to eq('rondo')
        expect(described_class).to have_received(:bput).with('play scales on my lute', any_args).twice
        expect(described_class).to have_received(:bput).with('play rondo on my zills', any_args).twice
      end

      it 'resets only the performance song when the performance instrument changes' do
        settings.instrument = 'flute'
        described_class.play_song?(settings, song_list, false)

        expect(UserVars.song).to eq('scales halt')
        expect(UserVars.instrument).to eq('flute')
        expect(UserVars.climbing_song).to eq('rondo')
      end

      it 'keeps both songs when the climbing instrument changes' do
        settings.worn_instrument = 'bells'
        described_class.play_song?(settings, song_list, true, true, true)

        expect(UserVars.climbing_song).to eq('rondo')
        expect(UserVars.song).to eq('scales')
        expect(UserVars.instrument).to eq('lute')
        expect(described_class).to have_received(:bput).with('play rondo on my bells', any_args)
      end

      it 'keeps the climbing song when no instrument has been recorded yet' do
        UserVars.instrument = nil
        described_class.play_song?(settings, song_list, true, true, true)

        expect(UserVars.climbing_song).to eq('rondo')
      end

      it 'does not seed an empty climbing song from a performance call' do
        UserVars.climbing_song = nil
        described_class.play_song?(settings, song_list, false)

        expect(UserVars.climbing_song).to be_nil
      end

      it 'does not seed an empty performance song from a climbing call' do
        UserVars.song = nil
        described_class.play_song?(settings, song_list, true, true, true)

        expect(UserVars.song).to be_nil
      end
    end
  end

  describe '.clean_instrument' do
    let(:settings) { OpenStruct.new(worn_instrument: 'lute', instrument: nil, cleaning_cloth: 'cloth') }

    before do
      allow(DRCI).to receive(:get_item?).and_return(true)
      allow(DRCI).to receive(:remove_item?).and_return(true)
      allow(DRCI).to receive(:wear_item?).and_return(true)
      allow(DRCI).to receive(:stow_item?).and_return(true)
      allow(described_class).to receive(:stop_playing)
      # clean_instrument has 3 bput calls:
      # 1. "wipe my ... with my ..." -> 'not in need of drying' breaks outer loop
      # 2. "wring my ..." -> 'you wring a dry' breaks inner loop (skipped if wipe returns 'not in need of drying')
      # 3. "clean my ... with my ..." -> 'not in need of cleaning' breaks final loop
      allow(described_class).to receive(:bput) do |cmd, *_patterns|
        case cmd
        when /^wipe my/
          'not in need of drying'
        when /^clean my/
          'not in need of cleaning'
        when /^wring my/
          'you wring a dry'
        else
          'Roundtime'
        end
      end
      allow(described_class).to receive(:waitrt?)
      allow(described_class).to receive(:pause)
      allow(described_class).to receive(:fix_standing)
    end

    it 'returns true on successful clean' do
      expect(described_class.clean_instrument(settings, true)).to be true
    end

    it 'returns false when cloth cannot be gotten' do
      allow(DRCI).to receive(:get_item?).with('cloth').and_return(false)
      expect(described_class.clean_instrument(settings)).to be false
    end

    it 'returns false when worn instrument cannot be removed' do
      allow(DRCI).to receive(:remove_item?).and_return(false)
      expect(described_class.clean_instrument(settings, true)).to be false
    end

    it 'uses get_item for non-worn instrument' do
      settings.worn_instrument = nil
      settings.instrument = 'lute'
      allow(DRCI).to receive(:get_item?).with('lute').and_return(false)
      allow(DRCI).to receive(:stow_item?).and_return(true)
      expect(described_class.clean_instrument(settings, false)).to be false
    end
  end

  describe '.tune_instrument' do
    let(:settings) { OpenStruct.new(worn_instrument: 'lute', instrument: nil) }

    before do
      allow(described_class).to receive(:stop_playing)
      allow(described_class).to receive(:left_hand).and_return(nil)
      allow(described_class).to receive(:right_hand).and_return(nil)
      allow(DRCI).to receive(:remove_item?).and_return(true)
      allow(DRCI).to receive(:in_hands?).and_return(true)
      allow(DRCI).to receive(:wear_item?).and_return(true)
      allow(described_class).to receive(:do_tune).and_return(true)
      allow(described_class).to receive(:waitrt?)
      allow(described_class).to receive(:pause)
    end

    it 'returns true on successful tune' do
      expect(described_class.tune_instrument(settings)).to be true
    end

    it 'returns false when no instrument configured' do
      settings.worn_instrument = nil
      settings.instrument = nil
      expect(described_class.tune_instrument(settings)).to be false
    end

    it 'returns false when hands not free and instrument not in hands' do
      allow(described_class).to receive(:left_hand).and_return('sword')
      allow(DRCI).to receive(:in_hands?).and_return(false)
      expect(described_class.tune_instrument(settings)).to be false
    end

    it 'returns false when worn instrument cannot be removed' do
      allow(DRCI).to receive(:remove_item?).and_return(false)
      allow(DRCI).to receive(:in_hands?).and_return(false)
      expect(described_class.tune_instrument(settings)).to be false
    end
  end

  describe '.do_tune' do
    before do
      allow(described_class).to receive(:beep)
      allow(DRCI).to receive(:in_hands?).and_return(true)
      allow(described_class).to receive(:fix_standing)
    end

    it 'returns false when instrument not in hands' do
      allow(DRCI).to receive(:in_hands?).and_return(false)
      expect(described_class.do_tune('lute')).to be false
    end

    it 'returns true when already in tune' do
      allow(described_class).to receive(:bput).and_return('After a moment, you find it in tune')
      expect(described_class.do_tune('lute')).to be true
    end

    it 'retunes sharp when flat' do
      n = 0
      allow(described_class).to receive(:bput) { |_, *_| (n += 1) == 1 ? 'After a moment, you hear it flat' : 'After a moment, you find it in tune' }
      expect(described_class.do_tune('lute')).to be true
    end

    it 'retunes flat when sharp' do
      n = 0
      allow(described_class).to receive(:bput) { |_, *_| (n += 1) == 1 ? 'After a moment, you hear it sharp' : 'After a moment, you find it in tune' }
      expect(described_class.do_tune('lute')).to be true
    end

    it 'fixes standing when needed' do
      n = 0
      allow(described_class).to receive(:bput) { |_, *_| (n += 1) == 1 ? 'You should be sitting up' : 'After a moment, you find it in tune' }
      described_class.do_tune('lute')
      expect(described_class).to have_received(:fix_standing)
    end
  end
end
