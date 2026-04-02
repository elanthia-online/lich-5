# frozen_string_literal: true

require 'ostruct'

# Minimal stubs for testing global_defs functions in isolation.
# These mirror the game runtime just enough to exercise the functions.

SCRIPT_DIR = '/tmp/lich-test-scripts' unless defined?(SCRIPT_DIR)

module Lich
  module Common
    # SetupFiles stub -- verifies $setupfiles lazy init and delegation
    class SetupFiles
      def initialize(debug = false); end

      def get_settings(_character_suffixes = [])
        OpenStruct.new(hometown: 'Crossing', autostarts: %w[esp afk])
      end

      def get_data(_type)
        OpenStruct.new(spell_data: {})
      end
    end
  end
end unless defined?(Lich::Common::SetupFiles)

module Script
  @running = {}

  def self.running?(name)
    @running[name] || false
  end

  def self.exists?(_name)
    true
  end

  def self.start(name, *_args)
    @running[name] = true
  end

  def self.set_running(name, val)
    @running[name] = val
  end

  def self.reset!
    @running = {}
  end

  def self.current
    OpenStruct.new(name: 'test')
  end
end unless defined?(Script)

# Stubs must be defined at TOPLEVEL_BINDING so eval'd global_defs code can find them.
eval(<<~'STUBS', TOPLEVEL_BINDING)
  def pause(num = 1); end unless defined?(pause)
  def echo(*_msgs); end unless defined?(echo)
  def start_script(script_name, cli_vars = [], flags = {})
    Script.start(script_name, Array(cli_vars).join(' '), flags)
  end
STUBS

# Load only the functions we're testing, not the entire global_defs
# (which has dependencies on XMLData, GameObj, etc.)
dep_path = File.join(File.dirname(__FILE__), '..', '..', '..', 'lib', 'global_defs.rb')
dep_lines = File.readlines(dep_path)

# Extract the sentinel constants block
sentinel_start = dep_lines.index { |l| l =~ /Sentinel constants for dependency/ }
if sentinel_start
  dep_lines[sentinel_start..].index { |l| l.strip == 'end' }
  # Need to find the double-end (module Lich; module Common; ...; end; end)
  ends_found = 0
  sentinel_end = nil
  (sentinel_start..dep_lines.length - 1).each do |i|
    ends_found += 1 if dep_lines[i].strip == 'end'
    if ends_found == 2
      sentinel_end = i
      break
    end
  end
  eval(dep_lines[sentinel_start..sentinel_end].join, TOPLEVEL_BINDING, dep_path, sentinel_start + 1)
end

# Extract start_scripts_if_available
fn_start = dep_lines.index { |l| l =~ /^def start_scripts_if_available/ }
fn_end = dep_lines[fn_start + 1..].index { |l| l =~ /^end\s*$/ }
eval(dep_lines[fn_start..fn_start + 1 + fn_end].join, TOPLEVEL_BINDING, dep_path, fn_start + 1)

# Extract get_settings
fn_start = dep_lines.index { |l| l =~ /^def get_settings/ }
fn_end = dep_lines[fn_start + 1..].index { |l| l =~ /^end\s*$/ }
eval(dep_lines[fn_start..fn_start + 1 + fn_end].join, TOPLEVEL_BINDING, dep_path, fn_start + 1)

# Extract get_data
fn_start = dep_lines.index { |l| l =~ /^def get_data/ }
fn_end = dep_lines[fn_start + 1..].index { |l| l =~ /^end\s*$/ }
eval(dep_lines[fn_start..fn_start + 1 + fn_end].join, TOPLEVEL_BINDING, dep_path, fn_start + 1)

RSpec.describe 'Sentinel Constants' do
  describe 'CORE_GET_SETTINGS' do
    it 'is defined in Lich::Common' do
      expect(Lich::Common.const_defined?(:CORE_GET_SETTINGS, false)).to be true
    end
  end

  describe 'CORE_SCRIPT_LOADER' do
    it 'is defined in Lich::Common' do
      expect(Lich::Common.const_defined?(:CORE_SCRIPT_LOADER, false)).to be true
    end
  end
end

RSpec.describe '#get_settings' do
  before { $setupfiles = nil }

  it 'lazy-initializes $setupfiles on first call' do
    expect($setupfiles).to be_nil
    get_settings
    expect($setupfiles).to be_a(Lich::Common::SetupFiles)
  end

  it 'reuses $setupfiles on subsequent calls' do
    get_settings
    first = $setupfiles
    get_settings
    expect($setupfiles).to equal(first)
  end

  it 'returns an OpenStruct with settings' do
    result = get_settings
    expect(result).to respond_to(:hometown)
  end

  it 'passes character_suffixes through to SetupFiles' do
    sf = instance_double(Lich::Common::SetupFiles)
    $setupfiles = sf
    expect(sf).to receive(:get_settings).with(['hunt']).and_return(OpenStruct.new)
    get_settings(['hunt'])
  end
end

RSpec.describe '#get_data' do
  before { $setupfiles = nil }

  it 'lazy-initializes $setupfiles on first call' do
    expect($setupfiles).to be_nil
    get_data('spells')
    expect($setupfiles).to be_a(Lich::Common::SetupFiles)
  end

  it 'passes type through to SetupFiles' do
    sf = instance_double(Lich::Common::SetupFiles)
    $setupfiles = sf
    expect(sf).to receive(:get_data).with('items').and_return(OpenStruct.new)
    get_data('items')
  end
end

RSpec.describe '#start_scripts_if_available' do
  before { Script.reset! }

  it 'starts a script that exists and is not running' do
    start_scripts_if_available('moonwatch')
    expect(Script.running?('moonwatch')).to be true
  end

  it 'accepts an array of script names' do
    start_scripts_if_available(%w[moonwatch textsubs])
    expect(Script.running?('moonwatch')).to be true
    expect(Script.running?('textsubs')).to be true
  end

  it 'skips scripts that are already running' do
    Script.set_running('moonwatch', true)
    # Should not raise or start again
    expect { start_scripts_if_available('moonwatch') }.not_to raise_error
  end

  it 'skips scripts that do not exist' do
    allow(Script).to receive(:exists?).with('nonexistent').and_return(false)
    start_scripts_if_available('nonexistent')
    expect(Script.running?('nonexistent')).to be false
  end

  it 'handles empty array without error' do
    expect { start_scripts_if_available([]) }.not_to raise_error
  end

  it 'handles single string argument' do
    start_scripts_if_available('moonwatch')
    expect(Script.running?('moonwatch')).to be true
  end
end
