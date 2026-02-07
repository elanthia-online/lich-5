# frozen_string_literal: true

require 'rspec'
require 'ostruct'

# Setup load path (standalone spec, no spec_helper dependency)
LIB_DIR = File.join(File.expand_path('../../../..', __dir__), 'lib') unless defined?(LIB_DIR)

# Ensure Lich::DragonRealms namespace exists
module Lich; module DragonRealms; end; end

# Mock Lich::Messaging — always reopen (no guard) because other specs
# may define Lich::Messaging without msg/messages/clear_messages!.
module Lich
  module Messaging
    @messages = []

    class << self
      def messages
        @messages ||= []
      end

      def clear_messages!
        @messages = []
      end

      def msg(type, message, **_opts)
        @messages ||= []
        @messages << { type: type, message: message }
      end
    end
  end
end

# Mock Lich::Util for issue_command
module Lich
  module Util
    def self.issue_command(_command, _start, _end_pattern, **_opts)
      []
    end
  end
end unless defined?(Lich::Util)

module DRStats
  def self.guild; 'Warrior Mage'; end
  def self.encumbrance; 'None'; end
  def self.barbarian?; false; end
  def self.thief?; false; end
end unless defined?(DRStats)
Lich::DragonRealms::DRStats = DRStats unless defined?(Lich::DragonRealms::DRStats)

class DRSkill
  def self.getrank(_skill); 0; end
end unless defined?(DRSkill)
Lich::DragonRealms::DRSkill = DRSkill unless defined?(Lich::DragonRealms::DRSkill)

class DRRoom
  def self.npcs; []; end
  def self.room_objs; []; end
end unless defined?(DRRoom)
Lich::DragonRealms::DRRoom = DRRoom unless defined?(Lich::DragonRealms::DRRoom)

module DRSpells
  def self.active_spells; {}; end
end unless defined?(DRSpells)
Lich::DragonRealms::DRSpells = DRSpells unless defined?(Lich::DragonRealms::DRSpells)

module DRCI
  def self.in_hands?(_item); false; end
  def self.get_item?(_item, _container = nil); true; end
  def self.put_away_item?(_item, _container = nil); true; end
  def self.stow_item?(_item, _container = nil); true; end
  def self.tie_item?(_item, _container = nil); true; end
  def self.untie_item?(_item, _container = nil); true; end
  def self.wear_item?(_item); true; end
  def self.remove_item?(_item); true; end
end unless defined?(DRCI)
Lich::DragonRealms::DRCI = DRCI unless defined?(Lich::DragonRealms::DRCI)

# NOTE: GameObj is intentionally NOT defined at the top level here.
# Defining it prevents qstrike_spec's alias (GameObj = Lich::Gemstone::GameObj)
# from working, causing cross-spec failures. Tests that need GameObj
# use stub_const to create a temporary mock scoped to each test.
#
# Helper class used by stub_const in tests — NOT assigned to ::GameObj.
DRC_MOCK_GAME_OBJ = Class.new do
  attr_accessor :name, :noun

  define_method(:initialize) do |name: 'Empty', noun: nil|
    @name = name
    @noun = noun
  end
end

class Script
  attr_accessor :paused, :no_pause_all, :name

  def self.running; []; end
  def self.running?(_name); false; end
  def self.exists?(_name); true; end
  def self.current; nil; end
  def self.self; OpenStruct.new(name: 'test'); end
  def paused?; @paused || false; end
end unless defined?(Script)

module UserVars
  @vars = {}
  class << self
    def method_missing(name, *args)
      name.to_s.end_with?('=') ? @vars[name.to_s.chomp('=')] = args.first : @vars[name.to_s]
    end

    def respond_to_missing?(_name, _include_private = false); true; end
  end
end unless defined?(UserVars)

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

# Mock Frontend module (added in PR #1170)
module Frontend
  def self.supports_gsl?; false; end
end unless defined?(Frontend)
$pause_all_lock = Mutex.new unless defined?($pause_all_lock)
$safe_pause_lock = Mutex.new unless defined?($safe_pause_lock)

# NOTE: `clear` MUST be private — a public Kernel `clear` is inherited by all objects,
# causing `Effects::Buffs.respond_to?(:clear)` to return true in qstrike_spec,
# which breaks buff cleanup. Private methods don't appear in `respond_to?` checks
# but are still callable as bare method calls within module_function methods like bput.
module Kernel
  def clear; end
  private :clear

  def pause(_seconds = nil); end
  def waitrt?; end
  def fput(_cmd); end
  def put(_cmd); end
  def get?; nil; end
  def echo(_msg); end
  def standing?; true; end
  def hiding?; false; end
  def invisible?; false; end
  def stunned?; false; end
  def webbed?; false; end
  def start_script(_name, _args = [], _flags = {}); nil; end
  def get_data(_key); OpenStruct.new(spell_data: {}); end
  def _respond(*_args); end
  def custom_require; proc { |_name| nil }; end
end

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common.rb')
DRC = Lich::DragonRealms::DRC unless defined?(DRC)

RSpec.describe Lich::DragonRealms::DRC do
  before(:each) do
    Lich::Messaging.clear_messages!
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

    it 'WAIT_RESPONSE_PATTERN matches wait responses with seconds capture' do
      match = "...wait 3".match(described_class::WAIT_RESPONSE_PATTERN)
      expect(match).not_to be_nil
      expect(match[:seconds]).to eq('3')
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
  end

  describe '.remove_flavor_text' do
    it('returns item unchanged when no flavor text') { expect(described_class.remove_flavor_text('a sword')).to eq('a sword') }
    it('strips "adorned with" flavor text') { expect(described_class.remove_flavor_text('a sword adorned with rubies of deep crimson')).to eq('a sword') }
    it('strips "decorated with" flavor text') { expect(described_class.remove_flavor_text('a shield decorated with a golden crest')).to eq('a shield') }
    it('strips "carved with" flavor text') { expect(described_class.remove_flavor_text('a staff carved with runes of ancient design')).to eq('a staff') }
  end

  describe '.box_list_to_adj_and_noun' do
    it('parses a single box') { expect(described_class.box_list_to_adj_and_noun('a wooden strongbox')).to eq(['wooden strongbox']) }
    it('converts ironwood to iron') { expect(described_class.box_list_to_adj_and_noun('an ironwood crate')).to eq(['iron crate']) }
    it('returns empty array for empty string') { expect(described_class.box_list_to_adj_and_noun('')).to eq([]) }
  end

  describe '.scroll_list_to_adj_and_noun' do
    it('removes article from single scroll') { expect(described_class.scroll_list_to_adj_and_noun(' a blue scroll')).to eq(['blue scroll']) }
    it('removes label text') { expect(described_class.scroll_list_to_adj_and_noun(' a blue scroll labeled with runes')).to eq(['blue scroll']) }
    it('converts papyrus roll to papyrus.roll') { expect(described_class.scroll_list_to_adj_and_noun(' a papyrus roll')).to eq(['papyrus.roll']) }
    it('simplifies icy blue to blue') { expect(described_class.scroll_list_to_adj_and_noun(' an icy blue parchment')).to eq(['blue parchment']) }
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
    before { allow(described_class).to receive(:bput).and_return('Setting your') }

    it('uses divisor 50 for Paladin') { allow(DRStats).to receive(:guild).and_return('Paladin'); allow(DRSkill).to receive(:getrank).and_return(200); described_class.set_stance('parry'); expect(described_class).to have_received(:bput).with('stance set 100 84 0', /Setting your/) }
    it('uses divisor 60 for Barbarian') { allow(DRStats).to receive(:guild).and_return('Barbarian'); allow(DRSkill).to receive(:getrank).and_return(300); described_class.set_stance('parry'); expect(described_class).to have_received(:bput).with('stance set 100 85 0', /Setting your/) }
    it('uses divisor 70 for other guilds') { allow(DRStats).to receive(:guild).and_return('Warrior Mage'); allow(DRSkill).to receive(:getrank).and_return(700); described_class.set_stance('parry'); expect(described_class).to have_received(:bput).with('stance set 100 90 0', /Setting your/) }
    it('swaps secondary and tertiary for shield') { allow(DRStats).to receive(:guild).and_return('Warrior Mage'); allow(DRSkill).to receive(:getrank).and_return(1400); described_class.set_stance('shield'); expect(described_class).to have_received(:bput).with('stance set 100 0 100', /Setting your/) }
    it('handles overflow points for shield') { allow(DRStats).to receive(:guild).and_return('Warrior Mage'); allow(DRSkill).to receive(:getrank).and_return(2100); described_class.set_stance('shield'); expect(described_class).to have_received(:bput).with('stance set 100 10 100', /Setting your/) }
  end

  describe '.assess_teach' do
    it('returns empty hash on timeout') { allow(Lich::Util).to receive(:issue_command).and_return(nil); expect(described_class.assess_teach).to eq({}) }
    it('returns empty hash when no one is teaching') { allow(Lich::Util).to receive(:issue_command).and_return(['No one seems to be teaching']); expect(described_class.assess_teach).to eq({}) }
    it('returns empty hash when "You are teaching"') { allow(Lich::Util).to receive(:issue_command).and_return(['You are teaching a class']); expect(described_class.assess_teach).to eq({}) }

    it 'returns parsed hash when teachers found' do
      allow(Lich::Util).to receive(:issue_command).and_return([
                                                                'Foo is teaching a class on Sorcery which is still open to new students',
                                                                'Bar is teaching a class on Scholarship which is still open to new students'
                                                              ])
      expect(described_class.assess_teach).to eq({ 'Foo' => 'Sorcery', 'Bar' => 'Scholarship' })
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
end
