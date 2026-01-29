# frozen_string_literal: true

# RSpec configuration for Lich 5 test suite
# Provides common setup, mocks, and helpers for all spec files

require 'rspec'
require 'ostruct'
require 'json'

# Add lib directory to load path
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

# Require core gems if available
begin
  require 'os'
rescue LoadError
  # OS gem not available, tests that need it should mock it
end

# Mock global constants used throughout Lich
XMLData = OpenStruct.new(game: 'DR', name: 'TestChar') unless defined?(XMLData)

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
    def self.msg(type, message)
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

# NOTE: No RSpec.configure block here to avoid affecting other specs in the test suite.
# This file only provides mock objects and constants needed by drexpmonitor and drskill specs.
