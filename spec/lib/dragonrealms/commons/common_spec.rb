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

# Always reopen Script to add attributes/methods needed by common.rb tests.
# Other specs may define Script first (spec_helper.rb has a minimal version),
# so we augment rather than replace to avoid cross-spec failures.
class Script
  attr_accessor :paused, :no_pause_all, :name

  def paused?; @paused || false; end

  # Only define class methods if they don't exist (spec_helper.rb may have its own)
  class << self
    def running
      []
    end unless method_defined?(:running)

    def running?(_name)
      false
    end unless method_defined?(:running?)

    def exists?(_name)
      true
    end unless method_defined?(:exists?)

    def current
      nil
    end unless method_defined?(:current)

    def self
      OpenStruct.new(name: 'test')
    end unless method_defined?(:self)
  end
end

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

# Mock XMLData for log_window
# XMLData may be a module (from this file) or OpenStruct (from spec_helper.rb).
# Always add server_time if missing, using define_singleton_method to work with both.
module XMLData; end unless defined?(XMLData)
XMLData.define_singleton_method(:server_time) { Time.at(1234567890) } unless XMLData.respond_to?(:server_time)
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
      expect(described_class).to have_received(:bput).with('collect rock ', described_class::COLLECT_MESSAGES)
    end

    it 'calls kick_pile? when room is cluttered' do
      n = 0
      allow(described_class).to receive(:bput) { |_, *_| (n += 1) == 1 ? 'The room is too cluttered' : 'You begin' }
      allow(described_class).to receive(:kick_pile?).and_return(true)
      described_class.collect('rock')
      expect(described_class).to have_received(:kick_pile?)
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

      it 'pauses scripts and returns their names' do
        result = described_class.safe_pause_list
        expect(result).to eq(['other'])
      end
    end

    describe '.safe_unpause_list' do
      it 'returns false if lock not owned' do
        expect(described_class.safe_unpause_list(['other'])).to be false
      end

      it 'unpauses scripts and releases lock' do
        described_class.safe_pause_list
        mock_script.paused = true
        described_class.safe_unpause_list(['other'])
        expect(mock_script).to have_received(:unpause)
        expect($safe_pause_lock.owned?).to be false
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
