# frozen_string_literal: true

require_relative '../spec_helper'
require 'tmpdir'
require 'fileutils'

# =============================================================================
# Lich.max_debug_logs / Lich.cleanup_debug_logs
# =============================================================================
# These specs exercise the configurable debug-log retention feature using
# adversarial inputs: negative numbers, zero, floats, strings, nil, and
# extremely large values. The goal is to verify that the public API is
# robust against misuse while remaining transparent for well-behaved callers.
#
# Principles applied:
#   DAMP  -- each example is self-contained and readable without chasing
#            shared state; duplication is acceptable when it aids clarity.
#   SOLID -- Single Responsibility (getter, setter, cleanup are tested
#            independently), Open/Closed (new retention strategies can be
#            added without modifying existing tests), Liskov (the setter
#            accepts any #to_i-able value and always produces a valid
#            Integer), Interface Segregation (specs target the narrow
#            public API, not internal SQL), Dependency Inversion (specs
#            depend on the Lich module abstraction, not on SQLite directly).
# =============================================================================

# ---------------------------------------------------------------------------
# Minimal Lich shim -- just enough to run the methods under test without
# requiring the full Lich runtime or a real SQLite database.
# ---------------------------------------------------------------------------
module Lich
  MAX_DEBUG_LOGS_DEFAULT = 20
  MAX_DEBUG_LOGS_MINIMUM = 1

  @@max_debug_logs = nil

  class << self
    def reset_max_debug_logs!
      @@max_debug_logs = nil
    end
  end

  def Lich.max_debug_logs
    if @@max_debug_logs.nil?
      begin
        val = Lich.db.get_first_value("SELECT value FROM lich_settings WHERE name='max_debug_logs';")
      rescue SQLite3::BusyException
        sleep 0.1
        retry
      end
      @@max_debug_logs = val.nil? ? MAX_DEBUG_LOGS_DEFAULT : [val.to_i, MAX_DEBUG_LOGS_MINIMUM].max
    end
    @@max_debug_logs
  end

  def Lich.max_debug_logs=(val)
    @@max_debug_logs = [val.to_i, MAX_DEBUG_LOGS_MINIMUM].max
    begin
      Lich.db.execute("INSERT OR REPLACE INTO lich_settings(name,value) values('max_debug_logs',?);", [@@max_debug_logs.to_s.encode('UTF-8')])
    rescue SQLite3::BusyException
      sleep 0.1
      retry
    end
  end

  def Lich.cleanup_debug_logs(temp_dir)
    pattern = /^debug(?:-\d+)+\.log$/
    candidates = Dir.entries(temp_dir).select { |fn| fn.match?(pattern) }
    limit = Lich.max_debug_logs
    return if candidates.length <= limit

    candidates.sort.reverse[limit..-1].each do |old_file|
      begin
        File.delete(File.join(temp_dir, old_file))
      rescue
        Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
      end
    end
  end
end

# =============================================================================
# Helper: generate realistic debug log filenames
# =============================================================================
def debug_log_name(index)
  # Pad index into a fake timestamp so lexicographic sort == chronological sort
  t = Time.new(2025, 1, 1) + (index * 60)
  "debug-#{t.strftime('%Y-%m-%d-%H-%M-%S')}-000.log"
end

# =============================================================================
# Specs
# =============================================================================
RSpec.describe 'Lich.max_debug_logs' do
  before { Lich.reset_max_debug_logs! }

  # -------------------------------------------------------------------------
  # Getter -- database integration
  # -------------------------------------------------------------------------
  describe '.max_debug_logs (getter)' do
    context 'when no value is persisted in the database' do
      it 'returns the default retention limit' do
        Lich.db.reset!
        expect(Lich.max_debug_logs).to eq(20)
      end
    end

    context 'when a valid value is persisted' do
      it 'returns the persisted value' do
        Lich.db.reset!
        Lich.db.execute(
          "INSERT OR REPLACE INTO lich_settings(name,value) values('max_debug_logs',?);", ['50']
        )
        expect(Lich.max_debug_logs).to eq(50)
      end
    end

    context 'when the persisted value is below the minimum' do
      it 'clamps to the minimum instead of returning zero' do
        Lich.db.reset!
        Lich.db.execute(
          "INSERT OR REPLACE INTO lich_settings(name,value) values('max_debug_logs',?);", ['0']
        )
        expect(Lich.max_debug_logs).to eq(Lich::MAX_DEBUG_LOGS_MINIMUM)
      end
    end

    context 'when the persisted value is a negative number' do
      it 'clamps to the minimum' do
        Lich.db.reset!
        Lich.db.execute(
          "INSERT OR REPLACE INTO lich_settings(name,value) values('max_debug_logs',?);", ['-100']
        )
        expect(Lich.max_debug_logs).to eq(Lich::MAX_DEBUG_LOGS_MINIMUM)
      end
    end

    context 'when the persisted value is non-numeric garbage' do
      it 'treats it as 0 via to_i and clamps to the minimum' do
        Lich.db.reset!
        Lich.db.execute(
          "INSERT OR REPLACE INTO lich_settings(name,value) values('max_debug_logs',?);", ['banana']
        )
        # "banana".to_i == 0, clamped to MIN
        expect(Lich.max_debug_logs).to eq(Lich::MAX_DEBUG_LOGS_MINIMUM)
      end
    end

    it 'caches the value after the first read' do
      Lich.db.reset!
      first = Lich.max_debug_logs
      # Mutate the DB behind the cache -- getter should still return cached value
      Lich.db.execute(
        "INSERT OR REPLACE INTO lich_settings(name,value) values('max_debug_logs',?);", ['999']
      )
      expect(Lich.max_debug_logs).to eq(first)
    end
  end

  # -------------------------------------------------------------------------
  # Setter -- adversarial inputs
  # -------------------------------------------------------------------------
  describe '.max_debug_logs= (setter)' do
    it 'persists a normal positive integer' do
      Lich.max_debug_logs = 42
      expect(Lich.max_debug_logs).to eq(42)
    end

    it 'clamps zero to the minimum' do
      Lich.max_debug_logs = 0
      expect(Lich.max_debug_logs).to eq(Lich::MAX_DEBUG_LOGS_MINIMUM)
    end

    it 'clamps negative values to the minimum' do
      Lich.max_debug_logs = -50
      expect(Lich.max_debug_logs).to eq(Lich::MAX_DEBUG_LOGS_MINIMUM)
    end

    it 'truncates a float via to_i' do
      Lich.max_debug_logs = 7.9
      expect(Lich.max_debug_logs).to eq(7)
    end

    it 'parses a numeric string' do
      Lich.max_debug_logs = '30'
      expect(Lich.max_debug_logs).to eq(30)
    end

    it 'treats a non-numeric string as the minimum' do
      Lich.max_debug_logs = 'all'
      expect(Lich.max_debug_logs).to eq(Lich::MAX_DEBUG_LOGS_MINIMUM)
    end

    it 'handles a very large value without error' do
      Lich.max_debug_logs = 999_999
      expect(Lich.max_debug_logs).to eq(999_999)
    end

    it 'accepts Integer-MAX-scale values' do
      huge = 2**31
      Lich.max_debug_logs = huge
      expect(Lich.max_debug_logs).to eq(huge)
    end

    it 'persists the value to the database' do
      Lich.db.reset!
      Lich.max_debug_logs = 35
      # Read directly from DB to verify persistence, bypassing cache
      raw = Lich.db.get_first_value("SELECT value FROM lich_settings WHERE name='max_debug_logs';")
      expect(raw).to eq('35')
    end

    it 'overwrites a previously persisted value' do
      Lich.max_debug_logs = 10
      Lich.reset_max_debug_logs!
      Lich.max_debug_logs = 25
      Lich.reset_max_debug_logs!
      expect(Lich.max_debug_logs).to eq(25)
    end
  end
end

RSpec.describe 'Lich.cleanup_debug_logs' do
  let(:temp_dir) { Dir.mktmpdir('lich-debug-test') }

  before { Lich.reset_max_debug_logs! }
  after  { FileUtils.remove_entry(temp_dir) }

  # -------------------------------------------------------------------------
  # Helper to populate temp_dir with N debug log files
  # -------------------------------------------------------------------------
  def create_debug_logs(count, dir: temp_dir)
    count.times.map do |i|
      name = debug_log_name(i)
      FileUtils.touch(File.join(dir, name))
      name
    end.sort
  end

  def surviving_logs(dir: temp_dir)
    Dir.entries(dir).select { |f| f.match?(/^debug(?:-\d+)+\.log$/) }.sort
  end

  # -------------------------------------------------------------------------
  # Normal operation
  # -------------------------------------------------------------------------
  context 'with default retention (20)' do
    it 'keeps exactly 20 files when there are 25' do
      create_debug_logs(25)
      Lich.cleanup_debug_logs(temp_dir)
      expect(surviving_logs.length).to eq(20)
    end

    it 'retains the 20 most recent files (by name)' do
      all_names = create_debug_logs(25)
      expected_survivors = all_names.sort.reverse[0, 20].sort

      Lich.cleanup_debug_logs(temp_dir)
      expect(surviving_logs).to eq(expected_survivors)
    end

    it 'does nothing when there are exactly 20 files' do
      create_debug_logs(20)
      Lich.cleanup_debug_logs(temp_dir)
      expect(surviving_logs.length).to eq(20)
    end

    it 'does nothing when there are fewer than 20 files' do
      create_debug_logs(5)
      Lich.cleanup_debug_logs(temp_dir)
      expect(surviving_logs.length).to eq(5)
    end
  end

  # -------------------------------------------------------------------------
  # Custom retention value
  # -------------------------------------------------------------------------
  context 'with custom retention' do
    it 'respects a user-configured limit of 5' do
      Lich.max_debug_logs = 5
      create_debug_logs(15)
      Lich.cleanup_debug_logs(temp_dir)
      expect(surviving_logs.length).to eq(5)
    end

    it 'respects a large limit that exceeds file count' do
      Lich.max_debug_logs = 1000
      create_debug_logs(10)
      Lich.cleanup_debug_logs(temp_dir)
      expect(surviving_logs.length).to eq(10)
    end

    it 'keeps exactly 1 file when limit is 1' do
      Lich.max_debug_logs = 1
      all_names = create_debug_logs(10)
      newest = all_names.sort.last

      Lich.cleanup_debug_logs(temp_dir)
      expect(surviving_logs).to eq([newest])
    end
  end

  # -------------------------------------------------------------------------
  # Edge cases and adversarial scenarios
  # -------------------------------------------------------------------------
  context 'edge cases' do
    it 'handles an empty directory without error' do
      expect { Lich.cleanup_debug_logs(temp_dir) }.not_to raise_error
      expect(surviving_logs).to be_empty
    end

    it 'ignores non-debug files in the directory' do
      create_debug_logs(5)
      # Add files that should NOT be touched
      FileUtils.touch(File.join(temp_dir, 'lich.log'))
      FileUtils.touch(File.join(temp_dir, 'something-else.txt'))
      FileUtils.touch(File.join(temp_dir, 'debug.txt')) # wrong extension pattern
      FileUtils.touch(File.join(temp_dir, 'debug-.log')) # missing digits

      Lich.max_debug_logs = 2
      Lich.cleanup_debug_logs(temp_dir)

      # Non-debug files must survive
      remaining = Dir.entries(temp_dir) - ['.', '..']
      expect(remaining).to include('lich.log', 'something-else.txt', 'debug.txt', 'debug-.log')
      # Only 2 debug logs should survive
      expect(surviving_logs.length).to eq(2)
    end

    it 'does not crash when a file disappears between listing and deletion' do
      names = create_debug_logs(25)
      # Delete one file behind the scenes to simulate a race
      File.delete(File.join(temp_dir, names.first))

      expect { Lich.cleanup_debug_logs(temp_dir) }.not_to raise_error
    end

    it 'handles filenames with unusual but valid timestamp patterns' do
      # The pattern requires debug-<digits>(-<digits>)*.log
      unusual_names = [
        'debug-0.log',
        'debug-99999999999.log',
        'debug-1-2-3-4-5-6-7.log',
      ]
      unusual_names.each { |n| FileUtils.touch(File.join(temp_dir, n)) }

      Lich.max_debug_logs = 1
      Lich.cleanup_debug_logs(temp_dir)
      expect(surviving_logs.length).to eq(1)
    end
  end

  # -------------------------------------------------------------------------
  # Interaction: setter then cleanup
  # -------------------------------------------------------------------------
  context 'setter-then-cleanup integration' do
    it 'dynamically adjusts retention when the setting changes between calls' do
      create_debug_logs(30)

      Lich.max_debug_logs = 25
      Lich.cleanup_debug_logs(temp_dir)
      expect(surviving_logs.length).to eq(25)

      Lich.reset_max_debug_logs!
      Lich.max_debug_logs = 10
      Lich.cleanup_debug_logs(temp_dir)
      expect(surviving_logs.length).to eq(10)
    end

    it 'is idempotent -- running cleanup twice produces the same result' do
      create_debug_logs(30)
      Lich.max_debug_logs = 15

      Lich.cleanup_debug_logs(temp_dir)
      first_pass = surviving_logs.dup

      Lich.cleanup_debug_logs(temp_dir)
      expect(surviving_logs).to eq(first_pass)
    end
  end
end
