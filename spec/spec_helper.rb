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

  # NOTE: Random ordering disabled due to pre-existing order-dependent tests.
  # The settings and PSMS specs have shared state issues that cause failures
  # when run in certain orders. These should be fixed separately.
  # config.order = :random
  # Kernel.srand config.seed
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

  class << self
    attr_accessor :game, :name, :room_id, :room_title, :injury_mode, :stamina

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
      @room_title = nil
      @injury_mode = 2
      @stamina = 100
    end
  end
end

# =============================================================================
# Script Mock
# =============================================================================
# Represents running scripts. Minimal implementation for testing.

class Script
  class << self
    attr_accessor :current

    def exist?(_name)
      false
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
# Lich Module Mock
# =============================================================================
# Core Lich namespace. Only define if not already defined (allows real code to load).

module Lich
  class << self
    attr_accessor :display_lichid, :display_uid, :hide_uid_flag, :display_stringprocs, :display_exits

    def log(msg)
      puts "[Lich.log] #{msg}" if ENV['DEBUG']
    end
  end

  module Messaging
    def self.msg_format(_format, _msg)
      # Mock implementation
    end

    def self.mono(_msg)
      # Mock implementation
    end

    def self.msg(_type, msg)
      puts "[Lich::Messaging] #{msg}" if ENV['DEBUG']
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
    def current
      self
    end

    def id
      1234
    end

    def [](_key)
      self
    end
  end
end unless defined?(Room)

class Map
  class << self
    def current
      self
    end

    def [](_key)
      self
    end

    def id
      1234
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
$_CLIENT_ ||= Object.new.tap do |obj|
  def obj.write(_data); end
  def obj.closed?; false; end
end
$_DETACHABLE_CLIENT_ ||= nil

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

module Lich
  module Common
    class GameObj
      @@npcs = []

      def initialize(id, noun, name, before = nil, after = nil)
        @id = id
        @noun = noun
        @name = name
        @before_name = before
        @after_name = after
      end

      def self.npcs
        @@npcs.empty? ? nil : @@npcs.dup
      end

      def self.clear_npcs
        @@npcs = []
      end
    end
  end
end unless defined?(Lich::Common::GameObj)

# Top-level alias
GameObj = Lich::Common::GameObj unless defined?(GameObj)
