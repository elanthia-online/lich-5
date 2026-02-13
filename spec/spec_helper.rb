# frozen_string_literal: true

# RSpec configuration for Lich 5 test suite
# Provides common setup, mocks, and helpers for all spec files

require 'rspec'
require 'ostruct'
require 'json'

# Add lib directory to load path
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

# Require application modules needed for testing
require_relative '../lib/common/watchable'

# Define LIB_DIR constant needed by gameloader
LIB_DIR = File.expand_path('../lib', __dir__) unless defined?(LIB_DIR)

# Require core gems if available
begin
  require 'os'
rescue LoadError
  # OS gem not available, tests that need it should mock it
end

# Mock global constants used throughout Lich
# XMLData may be defined as a module by other specs with attr_accessor (which returns nil
# by default). We ALWAYS define our methods to ensure they return test values, not nil.
# The last definition wins, so our values override nil defaults from attr_accessor.
XMLData = OpenStruct.new(
  game: 'DR',
  name: 'TestChar',
  room_id: 12345,
  room_count: 1,
  room_title: '[Test Room]',
  room_description: 'A test room description.',
  room_exits_string: 'Obvious paths: north, south',
  room_window_disabled: false,
  previous_nav_rm: 11111
) unless defined?(XMLData)

# Always define methods on XMLData to ensure they return test values, not nil.
# Other specs may have defined attr_accessor which creates methods that return nil.
# Our define_singleton_method overwrites those to return actual test values.
XMLData.define_singleton_method(:game) { 'DR' }
XMLData.define_singleton_method(:name) { 'TestChar' }
XMLData.define_singleton_method(:room_id) { 12345 }
XMLData.define_singleton_method(:room_title) { '[Test Room]' }
XMLData.define_singleton_method(:room_description) { 'A test room description.' }
XMLData.define_singleton_method(:room_exits_string) { 'Obvious paths: north, south' }
XMLData.define_singleton_method(:room_exits) { [] }
XMLData.singleton_class.attr_accessor(:prepared_spell) unless XMLData.respond_to?(:prepared_spell=)

# Mock global variables
$clean_lich_char = ';' unless defined?($clean_lich_char)
$frontend = 'stormfront' unless defined?($frontend)
$DREXPMONITOR_DEBUG = false unless defined?($DREXPMONITOR_DEBUG)

# Mock Lich module with database and logging functionality
module Lich
  # Logging - captures log messages for testing
  @log_messages = []

  def self.log(message)
    @log_messages << message
  end

  def self.clear_logs
    @log_messages = []
  end

  def self.log_messages
    @log_messages
  end

  # Display settings
  @@display_expgains = nil

  def self.display_expgains
    @@display_expgains
  end

  def self.display_expgains=(val)
    @@display_expgains = (val.to_s =~ /on|true|yes/ ? true : false)
  end

  def self.reset_display_expgains!
    @@display_expgains = nil
  end

  # State tracking stubs
  def self.track_autosort_state
    false
  end

  def self.track_layout_state
    false
  end

  def self.track_dark_mode
    false
  end

  # Mutex stubs
  def self.mutex_lock
    yield if block_given?
  end

  def self.mutex_unlock; end

  # Mock database
  def self.db
    @db ||= MockDB.new
  end

  # Mock Messaging module
  module Messaging
    def self.msg(type, message, **_opts)
      # Capture messages for test assertions
      @messages ||= []
      @messages << { type: type, message: message }
    end

    def self.messages
      @messages ||= []
    end

    def self.clear_messages!
      @messages = []
    end
  end
end

# Load the real GameLoader now that dependencies are mocked
require_relative '../lib/common/gameloader'

# Load DRInfomon startup module for testing
require_relative '../lib/dragonrealms/drinfomon/startup'

# Mock database for testing
class MockDB
  def initialize
    @data = {}
  end

  def get_first_value(query)
    if query.include?('display_inline_exp')
      @data['display_inline_exp']
    elsif query.include?('display_expgains')
      @data['display_expgains']
    end
  end

  def execute(query, params = [])
    if query.include?('display_inline_exp')
      @data['display_inline_exp'] = params[0]
    elsif query.include?('display_expgains')
      @data['display_expgains'] = params[0]
    end
  end

  def reset!
    @data = {}
  end
end

# Mock Script class (must be class, not module, to match existing test suite)
class Script
  def self.running?(name)
    @running_scripts ||= []
    @running_scripts.include?(name)
  end

  def self.set_running(name)
    @running_scripts ||= []
    @running_scripts << name
  end

  def self.clear_running!
    @running_scripts = []
  end
end unless defined?(Script)

# DragonRealms-specific constants
DR_LONGEST_LEARNING_RATE_LENGTH = 13 unless defined?(DR_LONGEST_LEARNING_RATE_LENGTH)

DR_SKILLS_DATA = {
  skillsets: {
    'Armor'    => ['Shield Usage', 'Light Armor', 'Chain Armor', 'Brigandine', 'Plate Armor', 'Defending'],
    'Weapon'   => ['Parry Ability', 'Small Edged', 'Large Edged', 'Twohanded Edged', 'Small Blunt', 'Large Blunt', 'Twohanded Blunt', 'Slings', 'Bow', 'Crossbow', 'Staves', 'Polearms', 'Light Thrown', 'Heavy Thrown', 'Brawling', 'Offhand Weapon', 'Melee Mastery', 'Missile Mastery'],
    'Magic'    => ['Attunement', 'Arcana', 'Targeted Magic', 'Augmentation', 'Debilitation', 'Utility', 'Warding', 'Sorcery', 'Theurgy', 'Inner Magic', 'Inner Fire', 'Elemental Magic', 'Holy Magic', 'Life Magic', 'Lunar Magic', 'Arcane Magic', 'Primary Magic'],
    'Survival' => ['Evasion', 'Athletics', 'Perception', 'Stealth', 'Locksmithing', 'Thievery', 'First Aid', 'Outdoorsmanship', 'Skinning', 'Backstab', 'Thanatology'],
    'Lore'     => ['Forging', 'Engineering', 'Outfitting', 'Alchemy', 'Enchanting', 'Scholarship', 'Appraisal', 'Performance', 'Tactics', 'Empathy', 'Trading', 'Bardic Lore', 'Mechanical Lore']
  },
  guild_skill_aliases: {
    'Barbarian'    => { 'Primary Magic' => 'Inner Fire' },
    'Bard'         => {},
    'Cleric'       => {},
    'Empath'       => {},
    'Moon Mage'    => {},
    'Necromancer'  => {},
    'Paladin'      => {},
    'Ranger'       => {},
    'Thief'        => {},
    'Trader'       => {},
    'Warrior Mage' => {}
  }
} unless defined?(DR_SKILLS_DATA)

# Mock GameBase module for games.rb specs
module GameBase
  class Game
    @@autostarted = false
    @@settings_init_needed = false

    def self.autostarted?
      @@autostarted
    end

    def self.settings_init_needed?
      @@settings_init_needed
    end
  end
end unless defined?(GameBase)

# Mock respond function used by watcher threads
def respond(message)
  # Capture for testing
end unless defined?(respond)

# Mock ExecScript for DRInfomon specs
module ExecScript
  def self.start(script, options = {})
    # Mock implementation for testing
  end
end unless defined?(ExecScript)

# ═══════════════════════════════════════════════════════════════════════════════
# CONSOLIDATED MOCKS FOR COMMONS SPECS
# All commons spec files share these mocks to avoid isolation issues.
# Individual specs can override methods using allow().to receive() as needed.
# ═══════════════════════════════════════════════════════════════════════════════

# ─── Global Variables ─────────────────────────────────────────────────────────
$pause_all_lock ||= Mutex.new
$safe_pause_lock ||= Mutex.new
$fake_stormfront ||= false

# ─── Lich::Util ───────────────────────────────────────────────────────────────
module Lich
  module Util
    def self.issue_command(_command, _start, _end_pattern, **_opts)
      []
    end
  end unless defined?(Lich::Util)
end

# ─── DRC (Common module) ──────────────────────────────────────────────────────
module DRC
  class << self
    attr_accessor :right_hand_item, :left_hand_item

    def bput(_command, *_patterns)
      nil
    end

    def right_hand
      @right_hand_item
    end

    def left_hand
      @left_hand_item
    end

    def get_noun(item)
      item.to_s.split.last
    end

    def bold(text)
      "<pushBold/>#{text}<popBold/>"
    end

    def retreat(*_args); end
    def fix_standing; end
    def release_invisibility; end
    def set_stance(_stance); end
    def wait_for_script_to_complete(_name, *_args); end
    def standing?; true; end
    def hiding?; false; end
    def invisible?; false; end
    def stunned?; false; end
    def webbed?; false; end
    def kneeling?; false; end

    def message(text, make_bold = true)
      Lich::Messaging.msg(make_bold ? 'bold' : 'plain', text)
    end
  end
end unless defined?(DRC)

# DRC::Item class (must be defined separately with its own guard)
class DRC::Item
  attr_accessor :name, :adjective, :ranged, :needs_unloading, :wield, :lodges,
                :bound, :swappable, :skip_repair, :worn

  def initialize(name: nil, adjective: nil, ranged: false, needs_unloading: false)
    @name = name
    @adjective = adjective
    @ranged = ranged
    @needs_unloading = needs_unloading
    @worn = false
    @lodges = true
    @swappable = false
    @bound = false
    @wield = false
    @skip_repair = false
  end

  def short_name
    @adjective ? "#{@adjective} #{@name}" : @name
  end

  def short_regex
    Regexp.new(short_name.to_s, Regexp::IGNORECASE)
  end

  def self.from_text(text)
    return nil if text.nil? || text.empty?
    new(name: text.split.last)
  end
end unless defined?(DRC::Item)

# ─── DRCI (Common Items module) ───────────────────────────────────────────────
module DRCI
  class << self
    def get_item?(*_args); true; end
    def put_away_item?(*_args); true; end
    def stow_item?(*_args); true; end
    def tie_item?(*_args); true; end
    def untie_item?(*_args); true; end
    def wear_item?(*_args); true; end
    def remove_item?(*_args); true; end
    def dispose_trash(*_args); end
    def get_item(*_args); end
    def get_item_if_not_held?(*_args); true; end
    def in_hands?(*_args); false; end
    def in_left_hand?(*_args); false; end
    def in_right_hand?(*_args); false; end
    def inside?(*_args); false; end
    def put_away_item_unsafe?(*_args); true; end
    def have_item_by_look?(*_args); false; end
  end
end unless defined?(DRCI)

# ─── DRRoom (must be class, not module) ───────────────────────────────────────
class DRRoom
  @npcs = []
  @pcs = []
  @room_objs = []
  @dead_npcs = []
  @group_members = []

  class << self
    attr_accessor :npcs, :pcs, :room_objs, :dead_npcs, :group_members

    def reset!
      @npcs = []
      @pcs = []
      @room_objs = []
      @dead_npcs = []
      @group_members = []
    end
  end
end unless defined?(DRRoom)

# ─── DRStats ──────────────────────────────────────────────────────────────────
module DRStats
  @guild = 'Warrior Mage'
  @encumbrance = 'None'
  @mana = 100
  @concentration = 100

  class << self
    attr_accessor :guild, :encumbrance, :mana, :concentration

    def barbarian?; @guild == 'Barbarian'; end
    def thief?; @guild == 'Thief'; end
    def trader?; @guild == 'Trader'; end
    def commoner?; @guild == 'Commoner'; end
    def moon_mage?; @guild == 'Moon Mage'; end
    def warrior_mage?; @guild == 'Warrior Mage'; end
    def empath?; @guild == 'Empath'; end
    def paladin?; @guild == 'Paladin'; end
    def ranger?; @guild == 'Ranger'; end
    def cleric?; @guild == 'Cleric'; end
    def bard?; @guild == 'Bard'; end
    def necromancer?; @guild == 'Necromancer'; end

    def reset!
      @guild = 'Warrior Mage'
      @encumbrance = 'None'
      @mana = 100
      @concentration = 100
    end
  end
end unless defined?(DRStats)

# ─── DRSkill (must be class, not module) ──────────────────────────────────────
class DRSkill
  @ranks = {}
  @xps = {}

  class << self
    def getrank(skill = nil, *_rest)
      @ranks ||= {}
      @ranks[skill] || 0
    end

    def getxp(skill = nil, *_rest)
      @xps ||= {}
      @xps[skill] || 0
    end

    def set_rank(skill, rank)
      @ranks ||= {}
      @ranks[skill] = rank
    end

    def set_xp(skill, xp)
      @xps ||= {}
      @xps[skill] = xp
    end

    def reset!
      @ranks = {}
      @xps = {}
    end
  end
end unless defined?(DRSkill)

# ─── DRSpells ─────────────────────────────────────────────────────────────────
module DRSpells
  @active_spells = {}

  class << self
    attr_accessor :active_spells

    def reset!
      @active_spells = {}
    end
  end
end unless defined?(DRSpells)

# Ensure DRSpells has active_spells= even if defined elsewhere (drparser_spec.rb)
unless DRSpells.respond_to?(:active_spells=)
  DRSpells.instance_variable_set(:@active_spells, {})
  DRSpells.define_singleton_method(:active_spells) { @active_spells }
  DRSpells.define_singleton_method(:active_spells=) { |val| @active_spells = val }
  DRSpells.define_singleton_method(:reset!) { @active_spells = {} }
end

# ─── UserVars ─────────────────────────────────────────────────────────────────
module UserVars
  @vars = {}
  @moons = {}
  @sun = { 'night' => false, 'day' => true }

  class << self
    attr_accessor :song, :climbing_song, :instrument, :discerns, :avtalia, :moons

    def method_missing(name, *args)
      name_str = name.to_s
      if name_str.end_with?('=')
        @vars[name_str.chomp('=')] = args.first
      else
        @vars[name_str]
      end
    end

    def respond_to_missing?(_name, _include_private = false)
      true
    end

    def sun
      @sun || { 'night' => false, 'day' => true }
    end

    def sun=(val)
      @sun = val
    end

    def friends
      @vars['friends'] || []
    end

    def hunting_nemesis
      @vars['hunting_nemesis'] || []
    end

    def reset!
      @vars = {}
      @moons = {}
      @sun = { 'night' => false, 'day' => true }
      @song = nil
      @climbing_song = nil
      @instrument = nil
    end
  end
end unless defined?(UserVars)

# ─── Flags (must be class, not module) ────────────────────────────────────────
class Flags
  @flags = {}
  @pending = {}
  @matchers = {}

  class << self
    def add(name, *patterns)
      @matchers[name] = patterns
      @flags[name] = nil unless @pending.key?(name)
    end

    def delete(name)
      @matchers.delete(name)
      @flags.delete(name)
    end

    def [](name)
      if @pending.key?(name)
        @flags[name] = @pending.delete(name)
      end
      @flags[name]
    end

    def []=(name, val)
      @flags[name] = val
    end

    def set_pending(name, val)
      @pending[name] = val
    end

    def reset(name)
      @flags[name] = nil
    end

    def reset!
      @flags = {}
      @pending = {}
      @matchers = {}
    end

    # Accessors for drparser_spec.rb compatibility
    def flags
      @flags
    end

    def matchers
      @matchers
    end
  end
end unless defined?(Flags)

# ─── Room ─────────────────────────────────────────────────────────────────────
class Room
  class << self
    def current
      nil
    end
  end
end unless defined?(Room)

# ─── Map ──────────────────────────────────────────────────────────────────────
module Map
  class << self
    def dijkstra(*_args)
      [nil, {}]
    end
  end
end unless defined?(Map)

# ─── Frontend ─────────────────────────────────────────────────────────────────
module Frontend
  def self.supports_gsl?
    false
  end
end unless defined?(Frontend)

# ─── Enhanced Script class ────────────────────────────────────────────────────
# Reopen to add instance methods needed by pause_all tests
class Script
  attr_accessor :paused, :no_pause_all, :name

  def paused?
    @paused || false
  end

  def pause; end
  def unpause; end

  class << self
    def running
      []
    end unless method_defined?(:running)

    def exists?(_name)
      true
    end unless method_defined?(:exists?)

    def current
      nil
    end unless method_defined?(:current)

    def hidden
      []
    end unless method_defined?(:hidden)
  end
end

# ─── DRCA (Arcana module) - basic mock ────────────────────────────────────────
module DRCA
  class << self
    def perc_mana
      0
    end
  end
end unless defined?(DRCA)

# ─── DRCM (Money module) - basic mock ─────────────────────────────────────────
module DRCM
  class << self
    def check_wealth(_currency = nil)
      0
    end
  end
end unless defined?(DRCM)

# ─── DRCMM (Moonmage module) - basic mock ─────────────────────────────────────
module DRCMM
  class << self
    def hold_moon_weapon?
      false
    end

    def is_moon_weapon?(*_args)
      false
    end

    def update_astral_data(data, _settings)
      data
    end

    def set_moon_data(_data); end
  end
end unless defined?(DRCMM)

# ─── DRCT (Travel module) - basic mock ────────────────────────────────────────
module DRCT
  class << self
    def walk_to(*_args)
      true
    end
  end
end unless defined?(DRCT)

# ─── Kernel methods (game engine functions) ───────────────────────────────────
module Kernel
  def pause(_seconds = nil); end
  def waitrt?; end
  def waitcastrt?; end
  def fput(_cmd); end
  def put(_cmd); end
  def get?; nil; end
  def echo(_msg); end
  def standing?; true; end
  def hiding?; false; end
  def invisible?; false; end
  def stunned?; false; end
  def webbed?; false; end
  def kneeling?; false; end
  def checkprep; 'None'; end
  def checkcastrt; 0; end
  def reget(*_args); nil; end
  def start_script(_name, _args = [], _flags = {}); nil; end
  def kill_script(_handle); end
  def _respond(*_args); end
  def custom_require; proc { |_name| nil }; end

  def get_data(key)
    case key
    when 'town'
      { 'Crossing' => { 'locksmithing' => { 'id' => 19_073 } } }
    when 'spells'
      OpenStruct.new(
        prep_messages: ['You begin to', "But you've already prepared", 'Your desire to prepare this offensive spell suddenly slips away', 'Something in the area interferes with your spell preparations'],
        cast_messages: ['You gesture', 'Your target pattern dissipates'],
        invoke_messages: ['Your cambrinth absorbs', 'you find it too clumsy', 'Invoke what?'],
        charge_messages: ['Your cambrinth absorbs all of the energy', 'You are in no condition to do that', "You'll have to hold it", 'you find it too clumsy'],
        segue_messages: ['You segue', 'You must be performing a cyclic spell to segue from', 'It is too soon to segue'],
        khri_preps: ['You focus your mind', 'Your mind and body are willing', 'Your body is willing'],
        spell_data: {},
        barb_abilities: {
          'Famine' => { 'type' => 'meditation', 'start_command' => 'meditate famine', 'activated_message' => 'You feel hungry' }
        }
      )
    else
      OpenStruct.new(spell_data: {}, observe_finished_messages: [], constellations: [])
    end
  end

  # clear must be private to avoid interfering with respond_to? checks
  def clear; end
  private :clear
end

# ─── Namespace Aliases ────────────────────────────────────────────────────────
# Ensure all modules are accessible from both top level and Lich::DragonRealms
# ALWAYS overwrite to ensure our mocks take precedence over any earlier definitions
# (e.g., drparser_spec.rb may define incomplete mocks before spec_helper loads)
module Lich
  module DragonRealms
    # Remove existing constants first to avoid "already initialized" warnings
    remove_const(:DRC) if const_defined?(:DRC, false)
    remove_const(:DRCI) if const_defined?(:DRCI, false)
    remove_const(:DRRoom) if const_defined?(:DRRoom, false)
    remove_const(:DRStats) if const_defined?(:DRStats, false)
    remove_const(:DRSkill) if const_defined?(:DRSkill, false)
    remove_const(:DRSpells) if const_defined?(:DRSpells, false)
    remove_const(:DRCA) if const_defined?(:DRCA, false)
    remove_const(:DRCM) if const_defined?(:DRCM, false)

    DRC = ::DRC
    DRCI = ::DRCI
    DRRoom = ::DRRoom
    DRStats = ::DRStats
    DRSkill = ::DRSkill
    DRSpells = ::DRSpells
    DRCA = ::DRCA
    DRCM = ::DRCM
    remove_const(:DRCMM) if const_defined?(:DRCMM, false)
    remove_const(:DRCT) if const_defined?(:DRCT, false)
    # Only replace Flags if it's a mock (no @@flags class variable) - don't replace real implementation
    if const_defined?(:Flags, false)
      existing_flags = const_get(:Flags)
      is_real_impl = existing_flags.class_variables.include?(:@@flags) rescue false
      remove_const(:Flags) unless is_real_impl
    end
    DRCMM = ::DRCMM
    DRCT = ::DRCT
    Flags = ::Flags unless const_defined?(:Flags, false)

    # Ensure namespaced DRSkill has set_xp/set_rank methods (may have been defined by drparser_spec.rb)
    unless DRSkill.respond_to?(:set_xp)
      DRSkill.instance_variable_set(:@ranks, {})
      DRSkill.instance_variable_set(:@xps, {})
      DRSkill.define_singleton_method(:getrank) { |skill = nil, *_rest| (@ranks ||= {})[skill] || 0 }
      DRSkill.define_singleton_method(:getxp) { |skill = nil, *_rest| (@xps ||= {})[skill] || 0 }
      DRSkill.define_singleton_method(:set_rank) { |skill, rank| (@ranks ||= {})[skill] = rank }
      DRSkill.define_singleton_method(:set_xp) { |skill, xp| (@xps ||= {})[skill] = xp }
      DRSkill.define_singleton_method(:reset!) { @ranks = {}; @xps = {} }
    end

    # Ensure namespaced DRStats has guild check methods (may have been defined by drparser_spec.rb)
    unless DRStats.respond_to?(:barbarian?)
      DRStats.define_singleton_method(:barbarian?) { @guild == 'Barbarian' }
      DRStats.define_singleton_method(:thief?) { @guild == 'Thief' }
      DRStats.define_singleton_method(:trader?) { @guild == 'Trader' }
      DRStats.define_singleton_method(:commoner?) { @guild == 'Commoner' }
      DRStats.define_singleton_method(:moon_mage?) { @guild == 'Moon Mage' }
      DRStats.define_singleton_method(:warrior_mage?) { @guild == 'Warrior Mage' }
      DRStats.define_singleton_method(:empath?) { @guild == 'Empath' }
      DRStats.define_singleton_method(:paladin?) { @guild == 'Paladin' }
      DRStats.define_singleton_method(:ranger?) { @guild == 'Ranger' }
      DRStats.define_singleton_method(:cleric?) { @guild == 'Cleric' }
      DRStats.define_singleton_method(:bard?) { @guild == 'Bard' }
      DRStats.define_singleton_method(:necromancer?) { @guild == 'Necromancer' }
    end

    # Ensure namespaced DRStats has mana accessor (may have been defined by drparser_spec.rb)
    unless DRStats.respond_to?(:mana)
      DRStats.instance_variable_set(:@mana, 100)
      DRStats.define_singleton_method(:mana) { @mana }
      DRStats.define_singleton_method(:mana=) { |val| @mana = val }
    end

    # Ensure UserVars has moons accessor (drparser_spec.rb doesn't define it)
    unless UserVars.respond_to?(:moons=)
      UserVars.instance_variable_set(:@moons, {})
      UserVars.define_singleton_method(:moons) { @moons }
      UserVars.define_singleton_method(:moons=) { |val| @moons = val }
    end

    # Ensure UserVars has sun accessor (drparser_spec.rb doesn't define it)
    unless UserVars.respond_to?(:sun=)
      UserVars.instance_variable_set(:@sun, { 'night' => false, 'day' => true })
      UserVars.define_singleton_method(:sun) { @sun || { 'night' => false, 'day' => true } }
      UserVars.define_singleton_method(:sun=) { |val| @sun = val }
    end

    # Ensure UserVars has song/instrument accessors (drparser_spec.rb doesn't define them)
    unless UserVars.respond_to?(:song=)
      UserVars.instance_variable_set(:@song, nil)
      UserVars.instance_variable_set(:@instrument, nil)
      UserVars.instance_variable_set(:@climbing_song, nil)
      UserVars.define_singleton_method(:song) { @song }
      UserVars.define_singleton_method(:song=) { |val| @song = val }
      UserVars.define_singleton_method(:instrument) { @instrument }
      UserVars.define_singleton_method(:instrument=) { |val| @instrument = val }
      UserVars.define_singleton_method(:climbing_song) { @climbing_song }
      UserVars.define_singleton_method(:climbing_song=) { |val| @climbing_song = val }
    end

    # Ensure namespaced DRSpells has active_spells= (may have been defined by drparser_spec.rb)
    unless DRSpells.respond_to?(:active_spells=)
      DRSpells.instance_variable_set(:@active_spells, {})
      DRSpells.define_singleton_method(:active_spells) { @active_spells }
      DRSpells.define_singleton_method(:active_spells=) { |val| @active_spells = val }
      DRSpells.define_singleton_method(:reset!) { @active_spells = {} }
    end

    # Ensure namespaced Flags has all needed methods
    # Real Flags (from events.rb) has `reset` method; drparser's mock doesn't
    is_real_flags = Flags.respond_to?(:reset) && !Flags.respond_to?(:reset!)

    # Add set_pending support to real Flags for commons spec compatibility
    # We override `add` (not `[]`) to inject pending values after initialization,
    # preserving the original `[]` behavior that accesses @@flags correctly.
    if is_real_flags && !Flags.respond_to?(:set_pending)
      original_add = Flags.method(:add)
      Flags.instance_variable_set(:@pending, {})

      Flags.define_singleton_method(:set_pending) do |name, val|
        @pending[name] = val
      end

      # Override add to inject pending values after the original initialization
      Flags.define_singleton_method(:add) do |name, *patterns|
        original_add.call(name, *patterns)
        # If there's a pending value, overwrite the false initialization
        if @pending&.key?(name)
          Flags.class_variable_get(:@@flags)[name] = @pending.delete(name)
        end
      end

      # Add reset! for spec cleanup
      Flags.define_singleton_method(:reset!) do
        Flags.class_variable_set(:@@flags, {})
        Flags.class_variable_set(:@@matchers, {})
        @pending = {}
      end
    end

    # Add full mock Flags methods if it's not the real implementation
    unless is_real_flags
      # Mock Flags (defined by drparser_spec.rb) - add all methods
      unless Flags.respond_to?(:reset!)
        Flags.instance_variable_set(:@flags, {})
        Flags.instance_variable_set(:@pending, {})
        Flags.instance_variable_set(:@matchers, {})

        Flags.define_singleton_method(:add) do |name, *patterns|
          @matchers[name] = patterns
          @flags[name] = nil unless @pending.key?(name)
        end

        Flags.define_singleton_method(:delete) do |name|
          @matchers.delete(name)
          @flags.delete(name)
        end

        Flags.define_singleton_method(:[]) do |name|
          if @pending.key?(name)
            @flags[name] = @pending.delete(name)
          end
          @flags[name]
        end

        Flags.define_singleton_method(:[]=) do |name, val|
          @flags[name] = val
        end

        Flags.define_singleton_method(:set_pending) do |name, val|
          @pending[name] = val
        end

        Flags.define_singleton_method(:reset) do |name|
          @flags[name] = nil
        end

        Flags.define_singleton_method(:reset!) do
          @flags = {}
          @pending = {}
          @matchers = {}
        end
      end # unless Flags.respond_to?(:reset!)
    end # unless is_real_flags
  end
end

# ─── RSpec Configuration ──────────────────────────────────────────────────────
RSpec.configure do |config|
  config.before(:each) do
    # Reset mutable state before each test
    Lich::Messaging.clear_messages!
    DRStats.reset! if DRStats.respond_to?(:reset!)
    DRSkill.reset! if DRSkill.respond_to?(:reset!)
    DRSpells.reset! if DRSpells.respond_to?(:reset!)
    Flags.reset! if Flags.respond_to?(:reset!)
    UserVars.reset! if UserVars.respond_to?(:reset!)
    DRRoom.reset! if DRRoom.respond_to?(:reset!)
    DRC.right_hand_item = nil if DRC.respond_to?(:right_hand_item=)
    DRC.left_hand_item = nil if DRC.respond_to?(:left_hand_item=)
  end
end

# NOTE: Individual spec files can still define additional mocks or override
# methods using allow().to receive(). The mocks above provide a baseline that
# works for all specs when run together.
