# frozen_string_literal: true

# spec/spec_helper.rb - Shared test configuration and mocks for lich-5 specs
#
# This file provides:
# 1. RSpec configuration
# 2. Shared mock definitions for game infrastructure (XMLData, Script, Effects, etc.)
# 3. Fixture loading (effect-list.xml)
# 4. Path constants for consistent file resolution
#
# Usage: Add `require 'spec_helper'` at the top of each spec file
#
# =============================================================================
# FIXTURE: effect-list.xml
# =============================================================================
# The effect-list.xml file in spec/fixtures/ is a LOCAL COPY of the upstream
# file from elanthia-online/scripts. This eliminates network dependencies
# during test runs.
#
# IMPORTANT: This file must be kept in sync with upstream!
#
# The canonical source is:
#   https://github.com/elanthia-online/scripts/blob/master/scripts/effect-list.xml
#
# To update the fixture manually:
#   curl -o spec/fixtures/effect-list.xml \
#     https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts/effect-list.xml
#
# TODO: Set up automated sync via GitHub Actions or pre-commit hook to ensure
# the fixture stays current with upstream changes. See spec/fixtures/README.md
# for detailed update procedures.
# =============================================================================

require 'rspec'
require 'tmpdir'
require 'ostruct'

# =============================================================================
# Path Constants
# =============================================================================
SPEC_ROOT = File.expand_path(__dir__)
LIB_DIR = File.join(SPEC_ROOT, '..', 'lib')
FIXTURE_DIR = File.join(SPEC_ROOT, 'fixtures')
DATA_DIR = Dir.tmpdir # Used by settings.rb for database storage

# Add lib directory to load path for require statements
$LOAD_PATH.unshift(LIB_DIR) unless $LOAD_PATH.include?(LIB_DIR)

# =============================================================================
# RSpec Configuration
# =============================================================================
RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = File.join(SPEC_ROOT, '.rspec_status')

  # NOTE: We can't use disable_monkey_patching! because existing specs use bare `describe`
  # and the NilClass extension interferes with RSpec internals

  # Enable more verbose output when running a single spec file
  config.default_formatter = 'doc' if config.files_to_run.one?

  # Reset shared state before each example to ensure test isolation.
  # This prevents state leakage between tests and allows random ordering.
  config.before do
    # Core game state
    XMLData.reset if defined?(XMLData) && XMLData.respond_to?(:reset)
    Script.current = nil if defined?(Script)
    $_SERVERBUFFER_&.clear
    $_CLIENTBUFFER_&.clear
    $_LASTUPSTREAM_ = nil

    # Lich messaging
    Lich::Messaging.clear_messages! if defined?(Lich::Messaging) && Lich::Messaging.respond_to?(:clear_messages!)
    Lich.reset_display_expgains! if defined?(Lich) && Lich.respond_to?(:reset_display_expgains!)
    Lich.db.reset! if defined?(Lich) && Lich.respond_to?(:db) && Lich.db.respond_to?(:reset!)

    # DR production classes - only if they're loaded (may override mocks)
    Lich::DragonRealms::DRExpMonitor.reset! if defined?(Lich::DragonRealms::DRExpMonitor) && Lich::DragonRealms::DRExpMonitor.respond_to?(:reset!)

    # Game objects
    Lich::Common::GameObj.clear_npcs if defined?(Lich::Common::GameObj) && Lich::Common::GameObj.respond_to?(:clear_npcs)
    Lich::Common::GameObj.clear_hands if defined?(Lich::Common::GameObj) && Lich::Common::GameObj.respond_to?(:clear_hands)

    # DR mocks from spec_helper (reset both top-level and namespaced)
    Flags.reset! if defined?(Flags) && Flags.respond_to?(:reset!)
    UserVars.reset! if defined?(UserVars) && UserVars.respond_to?(:reset!)
    DRC.reset! if defined?(DRC) && DRC.respond_to?(:reset!)
    DRStats.reset! if defined?(DRStats) && DRStats.respond_to?(:reset!)
    DRSkill.reset! if defined?(DRSkill) && DRSkill.respond_to?(:reset!)
    DRSpells.reset! if defined?(DRSpells) && DRSpells.respond_to?(:reset!)
    DRRoom.reset! if defined?(DRRoom) && DRRoom.respond_to?(:reset!)
  end

  # Random ordering now enabled - the before hook resets shared state
  config.order = :random
  Kernel.srand config.seed
end

# =============================================================================
# Shared Examples and Contexts
# =============================================================================
# Reusable test patterns to reduce duplication across specs.

# Guild predicate shared examples - use with include_examples
# Example: include_examples 'guild predicate', 'Barbarian', :barbarian?
RSpec.shared_examples 'guild predicate' do |guild_name, method_name|
  describe ".#{method_name}" do
    it "returns true when guild is #{guild_name}" do
      described_class.guild = guild_name
      expect(described_class.send(method_name)).to be true
    end

    it "returns false when guild is not #{guild_name}" do
      described_class.guild = 'Other Guild'
      expect(described_class.send(method_name)).to be false
    end

    it 'returns false when guild is nil' do
      described_class.guild = nil
      expect(described_class.send(method_name)).to be false
    end
  end
end

# XMLData stub context for common delegator patterns
RSpec.shared_context 'XMLData stubs' do
  before do
    allow(XMLData).to receive(:name).and_return('TestChar')
    allow(XMLData).to receive(:health).and_return(100)
    allow(XMLData).to receive(:mana).and_return(50)
    allow(XMLData).to receive(:stamina).and_return(75)
    allow(XMLData).to receive(:spirit).and_return(80)
    allow(XMLData).to receive(:concentration).and_return(90)
  end
end

# DRSpells XMLData stub context
RSpec.shared_context 'DRSpells XMLData stubs' do
  before do
    allow(XMLData).to receive(:dr_active_spells).and_return({ 'Protection' => 120, 'Shield' => 60 })
    allow(XMLData).to receive(:dr_active_spells_slivers).and_return(3)
    allow(XMLData).to receive(:dr_active_spells_stellar_percentage).and_return(45)
  end
end

# =============================================================================
# Global Output Methods
# =============================================================================
# These methods are used throughout lich-5 for output to the game client.
# In tests, they either suppress output or print to stdout (if DEBUG=1).

def respond(first = "", *messages)
  return unless ENV['DEBUG']

  if first.is_a?(Array)
    first.flatten.each { |ln| puts ln.to_s.chomp }
  else
    puts first.to_s.chomp
  end
  messages.flatten.each { |message| puts message.to_s.chomp }
end

def _respond(first = "", *messages)
  respond(first, *messages)
end

# =============================================================================
# XMLData Mock
# =============================================================================
# Central game state container. Most specs need this.
# Methods are additive - specs can extend with additional attributes as needed.

module XMLData
  @dialogs = {}
  @injuries = {}
  @game = "rspec"
  @name = "testing"
  @server_time = Time.at(1234567890)

  @room_title = ''
  @room_description = ''
  @room_exits = []

  # DR-specific active spell tracking
  @dr_active_spells = {}
  @dr_active_spells_slivers = 0
  @dr_active_spells_stellar_percentage = 0

  class << self
    attr_accessor :game, :name, :room_id, :room_title, :room_description, :room_exits, :injury_mode, :stamina, :server_time
    attr_accessor :dr_active_spells, :dr_active_spells_slivers, :dr_active_spells_stellar_percentage

    def indicator
      { 'IconSTUNNED' => 'n', 'IconDEAD' => 'n', 'IconWEBBED' => false }
    end

    def dialogs
      @dialogs ||= {}
    end

    def save_dialogs(kind, attributes)
      @dialogs ||= {}
      @dialogs[kind] = attributes
    end

    def reset_dialogs
      @dialogs = {}
    end

    def injuries
      @injuries ||= {}
    end

    def injuries=(value)
      @injuries = value
    end

    def reset
      @game = "rspec"
      @name = "testing"
      @dialogs = {}
      @injuries = {}
      @room_id = 0
      @room_title = ''
      @room_description = ''
      @room_exits = []
      @injury_mode = 2
      @stamina = 100
      @server_time = Time.at(1234567890)
      @dr_active_spells = {}
      @dr_active_spells_slivers = 0
      @dr_active_spells_stellar_percentage = 0
      # Clear any dynamically added attributes (e.g., prepared_spell from arcana specs)
      @prepared_spell = nil if instance_variable_defined?(:@prepared_spell)
    end
  end
end

# =============================================================================
# Script Mock
# =============================================================================
# Represents running scripts. Full implementation for testing pause/unpause.

class Script
  attr_accessor :paused, :no_pause_all, :name

  def paused?
    @paused || false
  end

  def pause; end

  def unpause; end

  class << self
    attr_accessor :current

    # NOTE: Production uses Script.self (not Script.current) to get the running script
    def self
      @current || OpenStruct.new(name: 'test')
    end

    def exist?(_name)
      false
    end

    def exists?(_name)
      true
    end

    def running
      []
    end

    def running?(_name)
      false
    end

    def hidden
      []
    end

    def start(_name)
      # Mock implementation
    end

    def new_downstream_xml(_data)
      # Mock implementation
    end

    def new_downstream(_data)
      # Mock implementation
    end
  end
end

# =============================================================================
# ExecScript Mock
# =============================================================================
# Script execution wrapper used by DRInfomon.startup

class ExecScript
  class << self
    def start(script_body, **_opts)
      # Mock implementation - does nothing in tests
    end
  end
end unless defined?(ExecScript)

# =============================================================================
# Lich Module Mock
# =============================================================================
# Core Lich namespace. Only define if not already defined (allows real code to load).

module Lich
  # Mock database for testing
  class MockDB
    def initialize
      @data = {}
    end

    def reset!
      @data = {}
    end

    def get_first_value(query)
      # Extract key from query like "SELECT value FROM lich_settings WHERE name='display_inline_exp'"
      if (match = query.match(/WHERE name\s*=\s*'([^']+)'/))
        @data[match[1]]
      end
    end

    def execute(query, params = [])
      # Handle INSERT INTO lich_settings VALUES ('key', ?)
      if query.include?('INSERT INTO lich_settings VALUES')
        if (match = query.match(/VALUES\s*\('([^']+)'/))
          key = match[1]
          value = params[0]
          @data[key] = value
        end
      # Handle INSERT OR REPLACE INTO lich_settings(name,value) values('key',?)
      elsif query.include?('INSERT OR REPLACE')
        if (match = query.match(/values\s*\('([^']+)'/i))
          key = match[1]
          value = params[0]
          @data[key] = value
        elsif params.length >= 2
          # Format: execute(query, [name, value])
          @data[params[0]] = params[1]
        end
      end
    end
  end

  @db = MockDB.new

  class << self
    attr_accessor :display_lichid, :display_uid, :hide_uid_flag, :display_stringprocs, :display_exits
    attr_accessor :display_expgains

    def db
      @db ||= MockDB.new
    end

    def log(msg)
      puts "[Lich.log] #{msg}" if ENV['DEBUG']
    end

    def reset_display_expgains!
      @display_expgains = nil
    end
  end

  module Messaging
    @messages = []

    class << self
      def msg_format(_format, _msg)
        # Mock implementation
      end

      def mono(_msg)
        # Mock implementation
      end

      def msg(type, message, **_opts)
        @messages ||= []
        @messages << { type: type, message: message }
        puts "[Lich::Messaging] #{message}" if ENV['DEBUG']
      end

      def messages
        @messages ||= []
      end

      def clear_messages!
        @messages = []
      end
    end
  end
end unless defined?(Lich) && Lich.respond_to?(:log)

# =============================================================================
# Effects Mock
# =============================================================================
# Game effects (buffs, debuffs, spells, cooldowns).
# Uses a Registry class that reads from XMLData.dialogs for realistic behavior.

module Effects
  class Registry
    include Enumerable

    def initialize(dialog)
      @dialog = dialog
    end

    def to_h
      XMLData.dialogs.fetch(@dialog, {})
    end

    def each(&block)
      to_h.each(&block)
    end

    def active?(effect)
      expiry = to_h.fetch(effect, 0)
      expiry.to_f > Time.now.to_f
    end

    def time_left(effect)
      expiry = to_h.fetch(effect, 0)
      return 0 if expiry.zero?

      ((expiry - Time.now) / 60.0)
    end
  end

  # Remove old constants if redefined (needed when specs run together)
  remove_const(:Spells) if const_defined?(:Spells)
  remove_const(:Buffs) if const_defined?(:Buffs)
  remove_const(:Debuffs) if const_defined?(:Debuffs)
  remove_const(:Cooldowns) if const_defined?(:Cooldowns)

  Spells    = Registry.new("Active Spells")
  Buffs     = Registry.new("Buffs")
  Debuffs   = Registry.new("Debuffs")
  Cooldowns = Registry.new("Cooldowns")
end

# =============================================================================
# NilClass Extension
# =============================================================================
# Match production behavior where nil.method returns nil instead of raising.
# This is controversial but matches what lich-5 expects.
#
# NOTE: This extension is DISABLED in specs because it interferes with RSpec
# and standard Ruby library internals (File.expand_path, etc.).
# Specs that depend on this behavior should mock it locally.
#
# class NilClass
#   def method_missing(*)
#     nil
#   end
#
#   def respond_to_missing?(*)
#     true
#   end
# end

# =============================================================================
# Room and Map Mocks
# =============================================================================
# Navigation infrastructure. Provides minimal implementation for testing.

class Room
  class << self
    attr_writer :current

    def current
      @current ||= OpenStruct.new(tags: [], id: 1234, dijkstra: [nil, {}])
    end

    def id
      1234
    end

    def [](_key)
      OpenStruct.new(tags: [], id: 1234, dijkstra: [nil, {}])
    end
  end
end unless defined?(Room)

class Map
  class << self
    def current
      self
    end

    def [](_key)
      nil
    end

    def id
      1234
    end

    def list
      []
    end

    def dijkstra(_id, _target = nil)
      [nil, {}]
    end

    def findpath(_room, _target)
      []
    end

    def wayto
      { 1 => 'north', 2 => 'south', 3 => proc {} }
    end

    def timeto
      { 1 => 10, 2 => 20, 3 => 30 }
    end

    def title
      ['[Test Room]']
    end
  end
end unless defined?(Map)

# =============================================================================
# DownstreamHook Mock
# =============================================================================

module DownstreamHook
  def self.run(data)
    data
  end
end unless defined?(DownstreamHook)

# =============================================================================
# Char Mock
# =============================================================================
# Character information module.

module Char
  def self.name
    XMLData.name || "testing"
  end
end unless defined?(Char)

# =============================================================================
# Global Variables
# =============================================================================
# These are used by various parts of lich-5 for game communication.

$_SERVERBUFFER_ ||= []
$_CLIENTBUFFER_ ||= []
$_LASTUPSTREAM_ ||= nil
$SEND_CHARACTER ||= '>'
$cmd_prefix ||= ''
$frontend ||= 'stormfront'
$fake_stormfront ||= false
$_CLIENT_ ||= Object.new.tap do |obj|
  def obj.write(_data); end
  def obj.closed?; false; end
end
$_DETACHABLE_CLIENT_ ||= nil
$pause_all_lock ||= Mutex.new
$safe_pause_lock ||= Mutex.new
$ORDINALS ||= %w[first second third fourth fifth sixth seventh eighth ninth tenth]

# =============================================================================
# Spell Data Loading
# =============================================================================
# Load effect-list.xml from fixtures for realistic spell testing.
# This file is committed to the repo to avoid network dependencies.
# See spec/fixtures/README.md for update procedures.

def load_spell_data
  require 'rexml/document'
  require 'rexml/streamlistener'
  require "common/spell"

  effect_list_path = File.join(FIXTURE_DIR, 'effect-list.xml')

  if File.exist?(effect_list_path)
    Lich::Common::Spell.load(effect_list_path)
  else
    warn "WARNING: effect-list.xml not found at #{effect_list_path}"
    warn "Run: curl -o spec/fixtures/effect-list.xml https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts/effect-list.xml"
  end
end

# =============================================================================
# Spellsong Mock
# =============================================================================
# Bard spellsong tracking.

module Lich
  module Gemstone
    class Spellsong
      @@renewed = Time.at(Time.now.to_i - 1200)

      def self.renewed
        @@renewed = Time.now
      end

      def self.timeleft
        8
      end
    end
  end
end unless defined?(Lich::Gemstone::Spellsong)

# =============================================================================
# GameObj Mock
# =============================================================================
# Game object tracking (NPCs, items, etc.).

# Mock hand item for testing
class MockGameObj
  attr_accessor :id, :noun, :name, :type

  def initialize(id: nil, noun: nil, name: nil, type: nil)
    @id = id
    @noun = noun
    @name = name || "Empty"
    @type = type
  end
end

module Lich
  module Common
    class GameObj
      @@npcs = []
      @right_hand = MockGameObj.new
      @left_hand = MockGameObj.new

      def initialize(id, noun, name, before = nil, after = nil)
        @id = id
        @noun = noun
        @name = name
        @before_name = before
        @after_name = after
      end

      class << self
        attr_accessor :right_hand, :left_hand

        def npcs
          @@npcs.empty? ? nil : @@npcs.dup
        end

        def clear_npcs
          @@npcs = []
        end

        def set_right_hand(obj)
          @right_hand = obj
        end

        def set_left_hand(obj)
          @left_hand = obj
        end

        def clear_hands
          @right_hand = MockGameObj.new
          @left_hand = MockGameObj.new
        end
      end
    end
  end

  # Gemstone uses the same GameObj class
  module Gemstone
    GameObj = Lich::Common::GameObj
  end
end unless defined?(Lich::Common::GameObj)

# Top-level alias
GameObj = Lich::Common::GameObj unless defined?(GameObj)

# =============================================================================
# Flags Mock
# =============================================================================
# Game event flag tracking. Matches production API from events.rb.
# NOTE: Production defines this as a CLASS, not module.

class Flags
  @@flags = {}
  @@pending = {}
  @@matchers = {}

  class << self
    def add(name, *patterns)
      @@flags[name] = nil unless @@pending.key?(name)
      @@matchers[name] = patterns.map { |p| p.is_a?(Regexp) ? p : /#{p}/i }
    end

    def delete(name)
      @@flags.delete(name)
      @@matchers.delete(name)
    end

    def []=(name, val)
      @@flags[name] = val
    end

    def [](name)
      if @@pending.key?(name)
        @@flags[name] = @@pending.delete(name)
      end
      @@flags[name]
    end

    def flags
      @@flags
    end

    def matchers
      @@matchers
    end

    def reset(name)
      @@flags[name] = nil
    end

    # For tests: set a flag that survives Flags.add calls
    def set_pending(name, val)
      @@pending[name] = val
    end

    def reset!
      @@flags = {}
      @@pending = {}
      @@matchers = {}
    end
  end
end unless defined?(Flags)

# =============================================================================
# UserVars Mock
# =============================================================================
# User-defined variables for scripts.

module UserVars
  @data = {}
  @moons = {}
  @sun = nil
  @friends = []
  @hunting_nemesis = []

  class << self
    attr_accessor :discerns, :avtalia, :moons
    attr_accessor :song, :climbing_song, :instrument
    attr_accessor :friends, :hunting_nemesis
    attr_accessor :slack_token

    def sun
      @sun || { 'night' => false, 'day' => true }
    end

    def sun=(val)
      @sun = val
    end

    def method_missing(name, *args)
      if name.to_s.end_with?('=')
        @data[name.to_s.chomp('=')] = args.first
      else
        @data[name.to_s]
      end
    end

    def respond_to_missing?(_name, _include_private = false)
      true
    end

    def reset!
      @data = {}
      @moons = {}
      @sun = nil
      @discerns = nil
      @avtalia = nil
      @song = nil
      @climbing_song = nil
      @instrument = nil
      @friends = []
      @hunting_nemesis = []
    end
  end
end unless defined?(UserVars)

# =============================================================================
# DR-Specific Mocks
# =============================================================================
# These are the DragonRealms commons modules used by most DR scripts.
# Defined at top level first, then aliased into Lich::DragonRealms namespace.

# Ensure namespace exists
module Lich; module DragonRealms; end; end

# -----------------------------------------------------------------------------
# DRC - Common module (bput, hands, messaging)
# -----------------------------------------------------------------------------
module DRC
  @right_hand = nil
  @left_hand = nil

  class << self
    attr_accessor :right_hand, :left_hand

    def bput(_command, *_patterns)
      'default'
    end

    def message(_msg); end

    def retreat(*_args); end

    def fix_standing; end

    def release_invisibility; end

    def set_stance(_stance); end

    def get_noun(item)
      item.to_s.split.last
    end

    def text2num(*_args)
      0
    end

    def rummage(*_args)
      []
    end

    def reset!
      @right_hand = nil
      @left_hand = nil
    end
  end

  # Mock DRC::Item class for in_hand? method in DRCI
  class Item
    attr_reader :short_regex

    def initialize(text)
      @short_regex = /#{Regexp.escape(text.to_s)}/i
    end

    def self.from_text(text)
      return nil if text.nil? || text.to_s.strip.empty?

      new(text)
    end
  end
end unless defined?(DRC)

# -----------------------------------------------------------------------------
# DRCI - Common items module
# -----------------------------------------------------------------------------
module DRCI
  class << self
    def get_item?(_item, _container = nil)
      true
    end

    def get_item(_item, _container = nil)
      true
    end

    def get_item_if_not_held?(_item, _container = nil)
      true
    end

    def put_away_item?(_item, _container = nil)
      true
    end

    def put_away_item_unsafe?(_item, _container = nil, _preposition = 'in')
      true
    end

    def stow_item?(_item)
      true
    end

    def wear_item?(_item)
      true
    end

    def remove_item?(_item)
      true
    end

    def tie_item?(_item, _container = nil)
      true
    end

    def untie_item?(_item, _container = nil)
      true
    end

    def in_hands?(_item)
      false
    end

    def in_left_hand?(_item)
      false
    end

    def in_right_hand?(_item)
      false
    end

    def inside?(_item, _container)
      true
    end

    def dispose_trash(_item, _container = nil, _verb = nil); end

    def stow_hand(_hand)
      true
    end
  end
end unless defined?(DRCI)

# -----------------------------------------------------------------------------
# DRStats - Character stats module
# -----------------------------------------------------------------------------
module DRStats
  @mana = 100
  @concentration = 100
  @guild = 'Warrior Mage'
  @encumbrance = 'None'
  @race = 'Human'
  @gender = 'male'

  class << self
    attr_accessor :mana, :concentration, :guild, :encumbrance, :race, :gender

    def barbarian?
      @guild == 'Barbarian'
    end

    def bard?
      @guild == 'Bard'
    end

    def cleric?
      @guild == 'Cleric'
    end

    def commoner?
      @guild == 'Commoner'
    end

    def empath?
      @guild == 'Empath'
    end

    def moon_mage?
      @guild == 'Moon Mage'
    end

    def necromancer?
      @guild == 'Necromancer'
    end

    def paladin?
      @guild == 'Paladin'
    end

    def ranger?
      @guild == 'Ranger'
    end

    def thief?
      @guild == 'Thief'
    end

    def trader?
      @guild == 'Trader'
    end

    def warrior_mage?
      @guild == 'Warrior Mage'
    end

    def reset!
      @mana = 100
      @concentration = 100
      @guild = 'Warrior Mage'
      @encumbrance = 'None'
      @race = 'Human'
      @gender = 'male'
    end
  end
end unless defined?(DRStats)

# -----------------------------------------------------------------------------
# DRSkill - Skill ranks/xp tracking
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# DRSpells - Active spells tracking
# -----------------------------------------------------------------------------
module DRSpells
  @@known_spells = {}
  @@known_feats = {}
  @@spellbook_format = nil
  @@grabbing_known_spells = false
  @@grabbing_known_barbarian_abilities = false
  @@grabbing_known_khri = false

  class << self
    def active_spells
      XMLData.dr_active_spells
    end

    def active_spells=(val)
      XMLData.dr_active_spells = val
    end

    def slivers
      XMLData.dr_active_spells_slivers
    end

    def stellar_percentage
      XMLData.dr_active_spells_stellar_percentage
    end

    def known_spells
      @@known_spells
    end

    def known_feats
      @@known_feats
    end

    def spellbook_format
      @@spellbook_format
    end

    def spellbook_format=(val)
      @@spellbook_format = val
    end

    def grabbing_known_spells
      @@grabbing_known_spells
    end

    def grabbing_known_spells=(val)
      @@grabbing_known_spells = val
    end

    def check_known_barbarian_abilities
      @@grabbing_known_barbarian_abilities
    end

    def check_known_barbarian_abilities=(val)
      @@grabbing_known_barbarian_abilities = val
    end

    def grabbing_known_khri
      @@grabbing_known_khri
    end

    def grabbing_known_khri=(val)
      @@grabbing_known_khri = val
    end

    def reset!
      @@known_spells = {}
      @@known_feats = {}
      @@spellbook_format = nil
      @@grabbing_known_spells = false
      @@grabbing_known_barbarian_abilities = false
      @@grabbing_known_khri = false
      XMLData.dr_active_spells = {}
    end
  end
end unless defined?(DRSpells)

# -----------------------------------------------------------------------------
# DRRoom - Room information (class in production)
# -----------------------------------------------------------------------------
class DRRoom
  @npcs = []
  @pcs = []
  @group_members = []
  @room_objs = []

  class << self
    attr_accessor :npcs, :pcs, :group_members, :room_objs

    def reset!
      @npcs = []
      @pcs = []
      @group_members = []
      @room_objs = []
    end
  end
end unless defined?(DRRoom)

# -----------------------------------------------------------------------------
# DRCA - Arcana module
# -----------------------------------------------------------------------------
module DRCA
  class << self
    def perc_mana
      0
    end
  end
end unless defined?(DRCA)

# -----------------------------------------------------------------------------
# DRCT - Travel module
# -----------------------------------------------------------------------------
module DRCT
  class << self
    def walk_to(_room_id, *_args)
      true
    end
  end
end unless defined?(DRCT)

# -----------------------------------------------------------------------------
# DRCMM - Moon mage module
# -----------------------------------------------------------------------------
module DRCMM
  class << self
    def update_astral_data(data, _settings)
      data
    end

    def set_moon_data(_data)
      true
    end
  end
end unless defined?(DRCMM)

# -----------------------------------------------------------------------------
# DRCTH - Theurgy module
# -----------------------------------------------------------------------------
module DRCTH
  # Minimal mock - extend as needed
end unless defined?(DRCTH)

# =============================================================================
# Namespace Aliases
# =============================================================================
# Production code lives in Lich::DragonRealms::*
# Aliases ensure both bare names and namespaced names resolve to same object.

Lich::DragonRealms::DRC = DRC unless defined?(Lich::DragonRealms::DRC)
Lich::DragonRealms::DRCI = DRCI unless defined?(Lich::DragonRealms::DRCI)
Lich::DragonRealms::DRStats = DRStats unless defined?(Lich::DragonRealms::DRStats)
Lich::DragonRealms::DRSkill = DRSkill unless defined?(Lich::DragonRealms::DRSkill)
Lich::DragonRealms::DRSpells = DRSpells unless defined?(Lich::DragonRealms::DRSpells)
Lich::DragonRealms::DRRoom = DRRoom unless defined?(Lich::DragonRealms::DRRoom)
Lich::DragonRealms::DRCA = DRCA unless defined?(Lich::DragonRealms::DRCA)
Lich::DragonRealms::DRCT = DRCT unless defined?(Lich::DragonRealms::DRCT)
Lich::DragonRealms::DRCMM = DRCMM unless defined?(Lich::DragonRealms::DRCMM)
Lich::DragonRealms::DRCTH = DRCTH unless defined?(Lich::DragonRealms::DRCTH)
Lich::DragonRealms::Flags = Flags unless defined?(Lich::DragonRealms::Flags)
Lich::DragonRealms::UserVars = UserVars unless defined?(Lich::DragonRealms::UserVars)

# =============================================================================
# Additional Infrastructure Mocks
# =============================================================================

# -----------------------------------------------------------------------------
# Frontend - Game client detection
# -----------------------------------------------------------------------------
module Frontend
  class << self
    def wizard?
      false
    end

    def stormfront?
      true
    end

    def supports_gsl?
      false
    end
  end
end unless defined?(Frontend)

# -----------------------------------------------------------------------------
# StringProc - Delayed command execution
# -----------------------------------------------------------------------------
class StringProc
  def initialize(string = '')
    @string = string
  end

  def call
    # Mock - does nothing in tests
  end

  def to_s
    @string
  end
end unless defined?(StringProc)

# -----------------------------------------------------------------------------
# Lich::Util - Utility functions
# -----------------------------------------------------------------------------
module Lich
  module Util
    class << self
      def issue_command(*_args, **_kwargs)
        []
      end

      def quiet_command_xml(*_args, **_kwargs)
        []
      end
    end
  end
end unless defined?(Lich::Util)

# =============================================================================
# Kernel Helper Methods
# =============================================================================
# Game interaction methods that are available at top level in scripts.
# These are idempotent - safe to call multiple times.

module Kernel
  def pause(_seconds = nil); end unless method_defined?(:pause)

  def waitrt?; end unless method_defined?(:waitrt?)

  def waitcastrt?; end unless method_defined?(:waitcastrt?)

  def echo(_msg); end unless method_defined?(:echo)

  def fput(_cmd); end unless method_defined?(:fput)

  def put(_cmd); end unless method_defined?(:put)

  # NOTE: `clear` MUST be private — a public Kernel `clear` is inherited by all objects,
  # causing `Effects::Buffs.respond_to?(:clear)` to return true in qstrike_spec,
  # which breaks buff cleanup.
  def clear; end unless method_defined?(:clear)
  private :clear

  def get?
    nil
  end unless method_defined?(:get?)

  def move(_dir)
    true
  end unless method_defined?(:move)

  def start_script(_name, _args = [], **_opts)
    Object.new
  end unless method_defined?(:start_script)

  def kill_script(_handle); end unless method_defined?(:kill_script)

  def checkprep
    'None'
  end unless method_defined?(:checkprep)

  def checkcastrt
    0
  end unless method_defined?(:checkcastrt)

  def reget(_count, _pattern = nil)
    nil
  end unless method_defined?(:reget)

  def kneeling?
    false
  end unless method_defined?(:kneeling?)

  def sitting?
    false
  end unless method_defined?(:sitting?)

  def standing?
    true
  end unless method_defined?(:standing?)

  def hiding?
    false
  end unless method_defined?(:hiding?)

  def invisible?
    false
  end unless method_defined?(:invisible?)

  def stunned?
    false
  end unless method_defined?(:stunned?)

  def webbed?
    false
  end unless method_defined?(:webbed?)

  def _respond(*_args); end unless method_defined?(:_respond)

  def custom_require
    proc { |_name| nil }
  end unless method_defined?(:custom_require)

  def get_data(_type)
    OpenStruct.new(
      prep_messages: ['You begin to'],
      cast_messages: ['You gesture'],
      invoke_messages: ['Your cambrinth absorbs'],
      charge_messages: ['Your cambrinth absorbs all of the energy'],
      segue_messages: ['You segue'],
      khri_preps: ['You focus your mind'],
      spell_data: {},
      barb_abilities: {}
    )
  end unless method_defined?(:get_data)

  def checkname
    'TestChar'
  end unless method_defined?(:checkname)

  def get
    nil
  end unless method_defined?(:get)
end
